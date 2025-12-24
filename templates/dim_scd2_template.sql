-- ============================================================================
-- Doris维度表拉链表模板（SCD Type 2）
-- ============================================================================
-- 说明：本模板用于DIM层维度表的拉链表设计
-- 版本：v1.0
-- 数据库：Apache Doris
-- ============================================================================

-- ============================================================================
-- 一、建表语句（DDL）
-- ============================================================================

-- 创建维度拉链表
CREATE TABLE IF NOT EXISTS {database}.dim_{dimension_name} (
    -- 维度主键
    {dimension_key} BIGINT COMMENT '维度主键，如：用户ID、产品ID',
    
    -- 维度属性字段（根据实际业务调整）
    {attribute_1} VARCHAR(100) COMMENT '维度属性1',
    {attribute_2} VARCHAR(100) COMMENT '维度属性2',
    {attribute_3} INT COMMENT '维度属性3',
    {attribute_4} DECIMAL(10,2) COMMENT '维度属性4',
    
    -- 拉链表必须字段（重要！）
    start_date DATE COMMENT '生效日期，记录开始生效的日期',
    end_date DATE COMMENT '失效日期，当前记录为9999-12-31，历史记录为实际失效日期',
    is_current TINYINT COMMENT '当前有效标识：1=当前有效记录，0=历史记录',
    
    -- ETL控制字段
    create_time DATETIME COMMENT '记录创建时间',
    update_time DATETIME COMMENT '记录更新时间'
)
-- 主键定义：维度主键 + 生效日期
UNIQUE KEY({dimension_key}, start_date)
COMMENT '【{业务名称}】维度拉链表'
DISTRIBUTED BY HASH({dimension_key}) BUCKETS 10
PROPERTIES (
    "replication_num" = "3",
    "storage_format" = "DEFAULT",
    "compression" = "LZ4"
);

-- ============================================================================
-- 二、初始化数据加载（首次全量）
-- ============================================================================

-- 场景：首次从源系统加载所有维度数据
INSERT INTO {database}.dim_{dimension_name}
SELECT
    {dimension_key},
    {attribute_1},
    {attribute_2},
    {attribute_3},
    {attribute_4},
    '1970-01-01' AS start_date,           -- 历史开始日期
    '9999-12-31' AS end_date,             -- 当前有效记录
    1 AS is_current,                      -- 标识为当前有效
    NOW() AS create_time,
    NOW() AS update_time
FROM {source_database}.{source_table};

-- ============================================================================
-- 三、增量更新逻辑（DML）- 核心逻辑
-- ============================================================================

-- 前提：
--   1. 有一个临时表或源表包含最新的维度数据：{source_database}.{source_table}_new
--   2. 该表包含所有可能变更的维度记录

-- ----------------------------------------------------------------------------
-- 步骤1：识别变更的记录（新增和更新）
-- ----------------------------------------------------------------------------

-- 创建临时表存储变更记录
CREATE TABLE IF NOT EXISTS {database}.dim_{dimension_name}_changes AS
SELECT
    n.{dimension_key},
    n.{attribute_1},
    n.{attribute_2},
    n.{attribute_3},
    n.{attribute_4}
FROM {source_database}.{source_table}_new n
LEFT JOIN {database}.dim_{dimension_name} o
    ON n.{dimension_key} = o.{dimension_key}
    AND o.is_current = 1
WHERE
    -- 新增记录：在新数据中存在但在维度表中不存在
    o.{dimension_key} IS NULL
    OR
    -- 更新记录：属性值发生变化
    (
        o.{attribute_1} != n.{attribute_1}
        OR o.{attribute_2} != n.{attribute_2}
        OR o.{attribute_3} != n.{attribute_3}
        OR o.{attribute_4} != n.{attribute_4}
    );

-- ----------------------------------------------------------------------------
-- 步骤2：关闭变更记录的旧版本（将is_current设置为0）
-- ----------------------------------------------------------------------------

-- 使用UPDATE语句关闭旧记录
UPDATE {database}.dim_{dimension_name}
SET
    end_date = DATE_SUB(CURDATE(), INTERVAL 1 DAY),  -- 失效日期为昨天
    is_current = 0,                                   -- 标记为历史记录
    update_time = NOW()
WHERE {dimension_key} IN (
    SELECT {dimension_key}
    FROM {database}.dim_{dimension_name}_changes
)
AND is_current = 1;

-- ----------------------------------------------------------------------------
-- 步骤3：插入新版本记录
-- ----------------------------------------------------------------------------

-- 插入变更后的新记录
INSERT INTO {database}.dim_{dimension_name}
SELECT
    c.{dimension_key},
    c.{attribute_1},
    c.{attribute_2},
    c.{attribute_3},
    c.{attribute_4},
    CURDATE() AS start_date,              -- 生效日期为今天
    '9999-12-31' AS end_date,             -- 当前有效记录
    1 AS is_current,                      -- 标识为当前有效
    NOW() AS create_time,
    NOW() AS update_time
FROM {database}.dim_{dimension_name}_changes c;

-- ----------------------------------------------------------------------------
-- 步骤4：清理临时表
-- ----------------------------------------------------------------------------

DROP TABLE IF EXISTS {database}.dim_{dimension_name}_changes;

-- ============================================================================
-- 四、增量更新逻辑（DML）- 简化版（适用于Doris UNIQUE KEY）
-- ============================================================================

-- 说明：Doris的UNIQUE KEY模型支持直接INSERT覆盖，可以简化拉链逻辑
-- 但为了保留历史，仍建议使用完整的SCD Type 2逻辑

-- 简化版本（仅供参考，不推荐用于拉链表）：
-- INSERT INTO {database}.dim_{dimension_name}
-- SELECT ... FROM {source}
-- ON DUPLICATE KEY UPDATE ...;

-- ============================================================================
-- 五、查询示例
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 5.1 查询当前所有有效记录
-- ----------------------------------------------------------------------------
SELECT
    {dimension_key},
    {attribute_1},
    {attribute_2},
    {attribute_3},
    {attribute_4},
    start_date,
    end_date
FROM {database}.dim_{dimension_name}
WHERE is_current = 1;

-- ----------------------------------------------------------------------------
-- 5.2 查询某个维度的完整历史
-- ----------------------------------------------------------------------------
SELECT
    {dimension_key},
    {attribute_1},
    {attribute_2},
    start_date,
    end_date,
    is_current
FROM {database}.dim_{dimension_name}
WHERE {dimension_key} = {specific_key}
ORDER BY start_date;

-- ----------------------------------------------------------------------------
-- 5.3 查询指定日期的维度快照（时间点查询）
-- ----------------------------------------------------------------------------
SELECT
    {dimension_key},
    {attribute_1},
    {attribute_2},
    {attribute_3},
    {attribute_4}
FROM {database}.dim_{dimension_name}
WHERE '{target_date}' BETWEEN start_date AND end_date;

-- 示例：查询2024年1月15日的维度快照
SELECT
    {dimension_key},
    {attribute_1},
    {attribute_2}
FROM {database}.dim_{dimension_name}
WHERE '2024-01-15' BETWEEN start_date AND end_date;

-- ----------------------------------------------------------------------------
-- 5.4 事实表关联维度表（获取当前维度属性）
-- ----------------------------------------------------------------------------
SELECT
    f.fact_key,
    f.fact_metric,
    d.{attribute_1},
    d.{attribute_2}
FROM {database}.{fact_table} f
LEFT JOIN {database}.dim_{dimension_name} d
    ON f.{dimension_key} = d.{dimension_key}
    AND d.is_current = 1
WHERE f.data_date = '{target_date}';

-- ----------------------------------------------------------------------------
-- 5.5 事实表关联维度表（获取历史时间点的维度属性）
-- ----------------------------------------------------------------------------
SELECT
    f.fact_key,
    f.fact_date,
    f.fact_metric,
    d.{attribute_1},
    d.{attribute_2}
FROM {database}.{fact_table} f
LEFT JOIN {database}.dim_{dimension_name} d
    ON f.{dimension_key} = d.{dimension_key}
    AND f.fact_date BETWEEN d.start_date AND d.end_date
WHERE f.data_date = '{target_date}';

-- ============================================================================
-- 六、数据质量检查SQL
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 6.1 检查每个维度主键只有一条当前记录
-- ----------------------------------------------------------------------------
SELECT
    {dimension_key},
    COUNT(*) as current_count
FROM {database}.dim_{dimension_name}
WHERE is_current = 1
GROUP BY {dimension_key}
HAVING COUNT(*) > 1;
-- 预期结果：无记录返回

-- ----------------------------------------------------------------------------
-- 6.2 检查历史记录的end_date不应为'9999-12-31'
-- ----------------------------------------------------------------------------
SELECT COUNT(*) as invalid_history_count
FROM {database}.dim_{dimension_name}
WHERE is_current = 0
  AND end_date = '9999-12-31';
-- 预期结果：0

-- ----------------------------------------------------------------------------
-- 6.3 检查当前记录的end_date应为'9999-12-31'
-- ----------------------------------------------------------------------------
SELECT COUNT(*) as invalid_current_count
FROM {database}.dim_{dimension_name}
WHERE is_current = 1
  AND end_date != '9999-12-31';
-- 预期结果：0

-- ----------------------------------------------------------------------------
-- 6.4 检查时间重叠（同一主键不应有重叠的有效期）
-- ----------------------------------------------------------------------------
SELECT
    a.{dimension_key},
    a.start_date as a_start,
    a.end_date as a_end,
    b.start_date as b_start,
    b.end_date as b_end
FROM {database}.dim_{dimension_name} a
JOIN {database}.dim_{dimension_name} b
    ON a.{dimension_key} = b.{dimension_key}
    AND a.start_date < b.start_date
WHERE a.end_date >= b.start_date
  AND NOT (a.start_date = b.start_date AND a.end_date = b.end_date);
-- 预期结果：无记录返回

-- ----------------------------------------------------------------------------
-- 6.5 检查有效期连续性（可选）
-- ----------------------------------------------------------------------------
SELECT
    a.{dimension_key},
    a.end_date as prev_end,
    b.start_date as next_start,
    DATEDIFF(b.start_date, a.end_date) as gap_days
FROM {database}.dim_{dimension_name} a
JOIN {database}.dim_{dimension_name} b
    ON a.{dimension_key} = b.{dimension_key}
    AND b.start_date = (
        SELECT MIN(start_date)
        FROM {database}.dim_{dimension_name}
        WHERE {dimension_key} = a.{dimension_key}
          AND start_date > a.start_date
    )
WHERE a.end_date != '9999-12-31'
  AND DATEDIFF(b.start_date, a.end_date) != 1;
-- 预期结果：无记录或在允许范围内

-- ============================================================================
-- 七、性能优化建议
-- ============================================================================

-- 1. 分桶键选择：使用维度主键作为分桶键，确保数据均匀分布
-- 2. 分桶数量：根据数据量调整，建议：数据量(GB) * 0.8 ~ 1.2
-- 3. 索引优化：
--    - UNIQUE KEY已包含{dimension_key}和start_date，查询时会自动使用
--    - 可以考虑在is_current字段上创建BITMAP索引（如果Doris版本支持）
-- 4. 查询优化：
--    - 查询当前记录时使用is_current=1，性能优于end_date='9999-12-31'
--    - 时间点查询使用BETWEEN，确保索引生效
-- 5. 数据压缩：维度表通常不大，使用LZ4压缩即可

-- ============================================================================
-- 八、注意事项
-- ============================================================================

-- 1. **拉链表三要素缺一不可**：
--    - start_date：生效日期
--    - end_date：失效日期
--    - is_current：当前标识
--
-- 2. **UNIQUE KEY必须包含维度主键+start_date**：
--    - 错误示例：UNIQUE KEY({dimension_key})
--    - 正确示例：UNIQUE KEY({dimension_key}, start_date)
--
-- 3. **更新顺序很重要**：
--    - 必须先UPDATE关闭旧记录
--    - 再INSERT新记录
--    - 顺序反了会导致数据错误
--
-- 4. **时间处理**：
--    - start_date和end_date使用DATE类型，不要使用DATETIME
--    - 当前记录的end_date统一使用'9999-12-31'
--    - 关闭记录时，end_date = 新记录start_date - 1天
--
-- 5. **属性比较时注意NULL值**：
--    - 比较字段变化时要考虑NULL的情况
--    - 建议使用COALESCE或IS NULL判断
--
-- 6. **性能考虑**：
--    - 对于大批量更新，考虑分批处理
--    - 定期清理过期的历史数据（如果业务允许）
--
-- 7. **事务性**：
--    - Doris支持事务，建议将UPDATE和INSERT放在同一个事务中
--    - 确保数据一致性

-- ============================================================================
-- 九、完整示例：用户维度表
-- ============================================================================

-- 创建用户维度拉链表
CREATE TABLE IF NOT EXISTS dw.dim_user_info (
    user_id BIGINT COMMENT '用户ID',
    user_name VARCHAR(100) COMMENT '用户名',
    user_level VARCHAR(20) COMMENT '用户等级：VIP/SVIP/普通',
    user_status VARCHAR(20) COMMENT '用户状态：活跃/沉睡/流失',
    register_channel VARCHAR(50) COMMENT '注册渠道',
    start_date DATE COMMENT '生效日期',
    end_date DATE COMMENT '失效日期，当前记录为9999-12-31',
    is_current TINYINT COMMENT '当前有效标识：1=当前，0=历史',
    create_time DATETIME COMMENT '创建时间',
    update_time DATETIME COMMENT '更新时间'
)
UNIQUE KEY(user_id, start_date)
COMMENT '用户信息维度拉链表'
DISTRIBUTED BY HASH(user_id) BUCKETS 10
PROPERTIES (
    "replication_num" = "3"
);

-- ============================================================================
-- 模板结束
-- ============================================================================


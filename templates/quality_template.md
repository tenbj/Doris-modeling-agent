# {表名}数据质量检验方案

## 一、概述

### 1.1 检验目标
确保 `{database}.{table_name}` 表的数据质量符合业务要求，包括完整性、准确性、一致性和及时性。

### 1.2 检验范围
- **表名**：`{database}.{table_name}`
- **数据层级**：{ODS/DWD/DWS/ADS/DIM}
- **检验频率**：{每日/每小时/实时}
- **检验时间**：{具体时间点}

## 二、数据完整性检验

### 2.1 表存在性检查

**检查项**：验证目标表是否存在

**检查SQL**：
```sql
-- 检查表是否存在
SELECT COUNT(*) as table_exists
FROM information_schema.tables
WHERE table_schema = '{database}'
  AND table_name = '{table_name}';
-- 预期结果：1
```

**阈值**：table_exists = 1

**异常处理**：如表不存在，发送告警并停止后续检查

---

### 2.2 分区存在性检查

**检查项**：验证当日分区是否创建

**检查SQL**：
```sql
-- 检查指定日期分区是否存在
SHOW PARTITIONS FROM {database}.{table_name}
WHERE PartitionName = 'p{yyyyMMdd}';
-- 预期结果：返回分区信息
```

**阈值**：分区存在

**异常处理**：如分区不存在，发送告警

---

### 2.3 数据量检查

**检查项**：验证数据量是否在合理范围内

**检查SQL**：
```sql
-- 检查当日数据量
SELECT
    data_date,
    COUNT(*) as row_count
FROM {database}.{table_name}
WHERE data_date = '{target_date}'
GROUP BY data_date;
```

**阈值**：
- 最小行数：{min_rows}
- 最大行数：{max_rows}
- 与昨日相比波动：< ±{threshold}%

**异常处理**：
- 如数据量为0，发送严重告警
- 如数据量超出阈值，发送警告

---

### 2.4 主键唯一性检查

**检查项**：验证主键字段唯一性

**检查SQL**：
```sql
-- 检查主键重复
SELECT
    {primary_key_columns},
    COUNT(*) as dup_count
FROM {database}.{table_name}
WHERE data_date = '{target_date}'
GROUP BY {primary_key_columns}
HAVING COUNT(*) > 1;
-- 预期结果：无返回记录
```

**阈值**：重复记录数 = 0

**异常处理**：如有重复，输出重复的主键值并发送告警

---

### 2.5 必填字段非空检查

**检查项**：验证必填字段无NULL值

**检查SQL**：
```sql
-- 检查必填字段是否有NULL
SELECT
    SUM(CASE WHEN {required_column_1} IS NULL THEN 1 ELSE 0 END) as null_count_col1,
    SUM(CASE WHEN {required_column_2} IS NULL THEN 1 ELSE 0 END) as null_count_col2,
    SUM(CASE WHEN {required_column_3} IS NULL THEN 1 ELSE 0 END) as null_count_col3
FROM {database}.{table_name}
WHERE data_date = '{target_date}';
-- 预期结果：所有null_count = 0
```

**阈值**：NULL值数量 = 0

**异常处理**：如有NULL值，记录字段名和NULL值数量，发送告警

---

### 2.6 数据关联完整性检查

**检查项**：验证外键关联的完整性

**检查SQL**：
```sql
-- 检查是否有孤儿记录（在事实表中存在但维度表中不存在）
SELECT COUNT(*) as orphan_count
FROM {database}.{table_name} t
LEFT JOIN {database}.{dim_table} d
  ON t.{foreign_key} = d.{primary_key}
  AND d.is_current = 1  -- 如果是拉链表
WHERE t.data_date = '{target_date}'
  AND d.{primary_key} IS NULL;
-- 预期结果：0
```

**阈值**：孤儿记录数 = 0 或 < {threshold}%

**异常处理**：如有孤儿记录，输出统计信息并发送告警

---

## 三、数据准确性检验

### 3.1 数值范围检查

**检查项**：验证数值字段在合理范围内

**检查SQL**：
```sql
-- 检查数值字段是否超出合理范围
SELECT
    COUNT(*) as total_rows,
    SUM(CASE WHEN {numeric_column} < {min_value} OR {numeric_column} > {max_value} THEN 1 ELSE 0 END) as out_of_range_count,
    MIN({numeric_column}) as min_value,
    MAX({numeric_column}) as max_value,
    AVG({numeric_column}) as avg_value
FROM {database}.{table_name}
WHERE data_date = '{target_date}';
```

**阈值**：out_of_range_count = 0 或 < {threshold}%

**异常处理**：如有超出范围的值，记录统计信息并发送告警

---

### 3.2 枚举值检查

**检查项**：验证枚举字段值在有效范围内

**检查SQL**：
```sql
-- 检查枚举字段是否有非法值
SELECT
    {enum_column},
    COUNT(*) as count
FROM {database}.{table_name}
WHERE data_date = '{target_date}'
  AND {enum_column} NOT IN ('{valid_value1}', '{valid_value2}', '{valid_value3}')
GROUP BY {enum_column};
-- 预期结果：无返回记录
```

**阈值**：非法值数量 = 0

**异常处理**：如有非法值，输出非法值列表并发送告警

---

### 3.3 日期逻辑检查

**检查项**：验证日期字段逻辑正确性

**检查SQL**：
```sql
-- 检查日期逻辑（如：结束日期应大于等于开始日期）
SELECT COUNT(*) as invalid_date_count
FROM {database}.{table_name}
WHERE data_date = '{target_date}'
  AND {end_date_column} < {start_date_column};
-- 预期结果：0
```

**阈值**：逻辑错误数量 = 0

**异常处理**：如有逻辑错误，输出错误记录并发送告警

---

### 3.4 业务规则校验

**检查项**：验证业务规则

**业务规则1**：{描述具体业务规则}

**检查SQL**：
```sql
-- 示例：订单金额应等于所有明细金额之和
SELECT
    t.order_id,
    t.order_amount,
    SUM(d.item_amount) as total_item_amount,
    ABS(t.order_amount - SUM(d.item_amount)) as diff
FROM {database}.{table_name} t
JOIN {database}.{detail_table} d
  ON t.order_id = d.order_id
WHERE t.data_date = '{target_date}'
GROUP BY t.order_id, t.order_amount
HAVING ABS(t.order_amount - SUM(d.item_amount)) > 0.01;
-- 预期结果：无返回记录
```

**阈值**：违反规则的记录数 = 0

**异常处理**：如有违规记录，输出详细信息并发送告警

---

## 四、数据一致性检验

### 4.1 上下游数据量一致性

**检查项**：验证与上游表的数据量一致性

**检查SQL**：
```sql
-- 比对上下游数据量
SELECT
    '{table_name}' as table_name,
    (SELECT COUNT(*) FROM {database}.{table_name} WHERE data_date = '{target_date}') as current_count,
    (SELECT COUNT(*) FROM {database}.{source_table} WHERE data_date = '{target_date}') as source_count,
    ABS((SELECT COUNT(*) FROM {database}.{table_name} WHERE data_date = '{target_date}') -
        (SELECT COUNT(*) FROM {database}.{source_table} WHERE data_date = '{target_date}')) as diff_count;
```

**阈值**：差异率 < {threshold}%（考虑过滤和聚合场景）

**异常处理**：如差异超出阈值，记录差异并发送告警

---

### 4.2 汇总一致性检查

**检查项**：验证汇总数据与明细数据一致

**检查SQL**：
```sql
-- 比对汇总表与明细表的指标
SELECT
    ABS(
        (SELECT SUM({metric}) FROM {database}.{summary_table} WHERE stat_date = '{target_date}') -
        (SELECT SUM({metric}) FROM {database}.{detail_table} WHERE data_date = '{target_date}')
    ) as diff_amount;
-- 预期结果：diff_amount = 0 或在允许误差范围内
```

**阈值**：差异 < {threshold}（绝对值）或 < {threshold}%（相对值）

**异常处理**：如差异超出阈值，发送告警

---

### 4.3 维度一致性检查

**检查项**：验证维度值与维度表一致

**检查SQL**：
```sql
-- 检查维度值是否都能在维度表中找到
SELECT DISTINCT t.{dimension_column}
FROM {database}.{table_name} t
LEFT JOIN {database}.{dim_table} d
  ON t.{dimension_column} = d.{dimension_key}
  AND d.is_current = 1
WHERE t.data_date = '{target_date}'
  AND d.{dimension_key} IS NULL
  AND t.{dimension_column} IS NOT NULL;
-- 预期结果：无返回记录
```

**阈值**：不匹配的维度值数量 = 0

**异常处理**：如有不匹配，输出不匹配的值并发送告警

---

## 五、数据及时性检验

### 5.1 数据就绪时间检查

**检查项**：验证数据是否按时产出

**检查SQL**：
```sql
-- 检查最新数据日期
SELECT MAX(data_date) as latest_date
FROM {database}.{table_name};
-- 预期结果：= {expected_date}
```

**阈值**：latest_date >= {expected_date}

**异常处理**：如数据延迟，发送告警并标注延迟时长

---

### 5.2 数据更新时间检查

**检查项**：验证数据更新时间

**检查SQL**：
```sql
-- 检查数据更新时间
SELECT
    data_date,
    MAX(create_time) as last_update_time,
    TIMESTAMPDIFF(MINUTE, MAX(create_time), NOW()) as delay_minutes
FROM {database}.{table_name}
WHERE data_date = '{target_date}'
GROUP BY data_date;
```

**阈值**：delay_minutes < {sla_minutes}

**异常处理**：如超过SLA时间，发送告警

---

## 六、拉链表专项检验（仅DIM层）

### 6.1 当前记录唯一性检查

**检查项**：每个维度主键只能有一条is_current=1的记录

**检查SQL**：
```sql
-- 检查当前记录唯一性
SELECT
    {dimension_key},
    COUNT(*) as current_count
FROM {database}.{table_name}
WHERE is_current = 1
GROUP BY {dimension_key}
HAVING COUNT(*) > 1;
-- 预期结果：无返回记录
```

**阈值**：重复的当前记录数 = 0

**异常处理**：如有重复，输出重复的维度键并发送严重告警

---

### 6.2 历史记录end_date检查

**检查项**：历史记录的end_date不应为'9999-12-31'

**检查SQL**：
```sql
-- 检查历史记录的end_date
SELECT COUNT(*) as invalid_history_count
FROM {database}.{table_name}
WHERE is_current = 0
  AND end_date = '9999-12-31';
-- 预期结果：0
```

**阈值**：invalid_history_count = 0

**异常处理**：如有异常，发送告警

---

### 6.3 当前记录end_date检查

**检查项**：当前记录的end_date应为'9999-12-31'

**检查SQL**：
```sql
-- 检查当前记录的end_date
SELECT COUNT(*) as invalid_current_count
FROM {database}.{table_name}
WHERE is_current = 1
  AND end_date != '9999-12-31';
-- 预期结果：0
```

**阈值**：invalid_current_count = 0

**异常处理**：如有异常，发送告警

---

### 6.4 有效期重叠检查

**检查项**：同一维度主键不应有时间重叠的记录

**检查SQL**：
```sql
-- 检查时间重叠
SELECT
    a.{dimension_key},
    a.start_date as a_start,
    a.end_date as a_end,
    b.start_date as b_start,
    b.end_date as b_end
FROM {database}.{table_name} a
JOIN {database}.{table_name} b
  ON a.{dimension_key} = b.{dimension_key}
  AND a.start_date < b.start_date
WHERE a.end_date >= b.start_date
  AND NOT (a.start_date = b.start_date AND a.end_date = b.end_date);
-- 预期结果：无返回记录
```

**阈值**：重叠记录数 = 0

**异常处理**：如有重叠，输出重叠记录并发送告警

---

### 6.5 有效期连续性检查（可选）

**检查项**：同一维度主键的记录时间应连续（前一条end_date = 后一条start_date - 1天）

**检查SQL**：
```sql
-- 检查时间连续性
SELECT
    a.{dimension_key},
    a.end_date as prev_end,
    b.start_date as next_start,
    DATEDIFF(b.start_date, a.end_date) as gap_days
FROM {database}.{table_name} a
JOIN {database}.{table_name} b
  ON a.{dimension_key} = b.{dimension_key}
  AND b.start_date > a.end_date
  AND NOT EXISTS (
      SELECT 1 FROM {database}.{table_name} c
      WHERE c.{dimension_key} = a.{dimension_key}
        AND c.start_date > a.end_date
        AND c.start_date < b.start_date
  )
WHERE a.end_date != '9999-12-31'
  AND DATEDIFF(b.start_date, a.end_date) != 1;
-- 预期结果：无返回记录或在允许范围内
```

**阈值**：间隔天数 = 1

**异常处理**：如有间隔，记录并根据业务需求决定是否告警

---

## 七、检验执行计划

### 7.1 检验流程

```
开始
  ↓
1. 表存在性检查 → 失败 → 发送告警 → 结束
  ↓ 成功
2. 数据完整性检验 → 失败 → 记录问题 → 继续
  ↓
3. 数据准确性检验 → 失败 → 记录问题 → 继续
  ↓
4. 数据一致性检验 → 失败 → 记录问题 → 继续
  ↓
5. 数据及时性检验 → 失败 → 记录问题 → 继续
  ↓
6. 拉链表专项检验 → 失败 → 记录问题 → 继续
  ↓
生成检验报告
  ↓
发送汇总告警（如有问题）
  ↓
结束
```

### 7.2 检验时间安排

| 检验类别 | 执行时间 | 执行频率 |
|----------|----------|----------|
| 数据完整性检验 | 数据加载后 | 每日 |
| 数据准确性检验 | 数据加载后 | 每日 |
| 数据一致性检验 | 数据加载后 | 每日 |
| 数据及时性检验 | SLA时间点 | 每日 |
| 拉链表专项检验 | 数据加载后 | 每日 |

---

## 八、告警策略

### 8.1 告警级别

| 级别 | 说明 | 触发条件 | 通知方式 |
|------|------|----------|----------|
| 严重 | 阻塞性问题 | 表不存在、数据量为0、主键重复 | 电话+短信+邮件 |
| 警告 | 需要关注 | 数据量异常波动、业务规则校验失败 | 短信+邮件 |
| 提示 | 一般信息 | 数据延迟、边界值 | 邮件 |

### 8.2 告警模板

```
【{级别}】{表名}数据质量告警

检验项：{检验项名称}
检验时间：{检验时间}
数据日期：{数据日期}

问题描述：{问题描述}
实际值：{实际值}
阈值：{阈值}
影响范围：{影响的记录数或百分比}

处理建议：{处理建议}

详细信息：{SQL查询结果或详细错误信息}
```

---

## 九、质量报告

### 9.1 日报模板

```
{表名}数据质量日报 - {日期}

一、检验概况
- 执行时间：{执行时间}
- 数据日期：{数据日期}
- 检验项数量：{总检验项数量}
- 通过项数量：{通过数量}
- 失败项数量：{失败数量}

二、数据概况
- 数据量：{行数}
- 分区数：{分区数}
- 数据大小：{MB/GB}

三、问题汇总
{问题列表}

四、趋势分析
{与历史数据对比}
```

---

## 十、持续改进

### 10.1 质量指标监控

- **数据质量得分** = (通过检验项数 / 总检验项数) × 100%
- **目标**：质量得分 >= 95%

### 10.2 问题追踪

建立问题追踪机制，记录：
- 问题发现时间
- 问题类型
- 问题原因
- 解决方案
- 解决时间

### 10.3 规则优化

定期（如每月）review检验规则：
- 评估规则有效性
- 调整阈值
- 新增检验项
- 删除冗余检验

---

## 附录：检验脚本

### A.1 一键执行脚本

```sql
-- 完整质量检验脚本
-- 使用方法：替换{变量}后执行

-- 设置变量
SET @target_date = '{target_date}';
SET @database = '{database}';
SET @table_name = '{table_name}';

-- 执行所有检验项
-- （此处可以整合上述所有检验SQL）
```

### A.2 自动化执行

建议将质量检验集成到ETL流程中：
1. 数据加载完成后自动触发检验
2. 检验结果写入质量监控表
3. 根据结果发送告警
4. 生成质量报告

---

**文档版本**：v1.0  
**创建日期**：{date}  
**维护人**：{owner}


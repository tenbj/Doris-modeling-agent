# Doris数据建模Agent系统 - 工作流详解

本文档详细说明Doris数据建模Agent系统的完整工作流程、使用方法和技术细节。

## 📋 目录

1. [系统架构](#系统架构)
2. [完整工作流程](#完整工作流程)
3. [Agent详细说明](#agent详细说明)
4. [拉链表设计详解](#拉链表设计详解)
5. [实际使用案例](#实际使用案例)
6. [故障排查](#故障排查)

---

## 系统架构

### 多Agent协作模式

本系统采用5个专业Agent协作的架构：

```
┌─────────────────────────────────────────────────┐
│              用户输入                            │
│  业务文档 (docs/business/)                       │
│  数据源文档 (docs/source/)                       │
└──────────────────┬──────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────┐
│          编排Agent (Orchestrator)                │
│  - 协调5个Agent的执行顺序                        │
│  - 检查输入输出                                  │
│  - 生成汇总报告                                  │
└──────────────────┬──────────────────────────────┘
                   ↓
      ┌────────────┴────────────┐
      ↓                         ↓
┌──────────┐            ┌──────────┐
│ Agent 1  │            │ Agent 2  │
│需求分析   │ ────────→ │数据建模   │
└──────────┘            └──────────┘
                               ↓
                        ┌──────────┐
                        │ Agent 3  │
                        │表结构设计 │
                        └──────────┘
                         ↓         ↓
                ┌────────┴───┐  ┌─────────┐
                │ Agent 4    │  │ Agent 5 │
                │ SQL生成    │  │质量检验  │
                └────────────┘  └─────────┘
                         ↓         ↓
      ┌──────────────────┴─────────┴────────────┐
      │                输出文件                   │
      │  设计方案 | 表结构 | SQL | 质量检验       │
      └─────────────────────────────────────────┘
```

### 数据流转

```
业务需求文档 ──┐
             ├─→ 需求分析报告 ──→ 模型设计方案 ──→ YAML表结构 ──┬─→ DDL/DML SQL
数据源文档 ──┘                                              └─→ 质量检验方案
```

---

## 完整工作流程

### 阶段0：准备工作

#### 0.1 准备输入文档

**业务需求文档**（放入 `docs/business/`）：

必须包含的内容：
- ✅ 业务目标和背景
- ✅ 业务场景描述
- ✅ 核心业务实体（用户、订单、商品等）
- ✅ 业务指标定义（GMV、订单量等）
- ✅ 业务规则（计算规则、过滤规则）
- ✅ 时间维度说明
- ✅ 数据质量要求

**数据源文档**（放入 `docs/source/`）：

必须包含的内容：
- ✅ 源系统清单
- ✅ 源表结构（表名、字段列表、数据类型）
- ✅ 字段说明和示例值
- ✅ 数据量级（存量、日增量）
- ✅ 数据更新频率
- ✅ 数据关系说明
- ✅ 数据质量问题说明

**提示**：可参考 `docs/examples/` 中的示例文档。

#### 0.2 检查系统文件

确保以下文件存在：
- `.cursorrules` - Cursor AI规则
- `config/layer_rules.yaml` - 分层规范
- `templates/` 下的所有模板
- `prompts/` 下的所有Agent提示词

---

### 阶段1：需求分析

**执行Agent**：`prompts/01_requirement_analyst.md`

**输入**：
- `docs/business/` 下的所有业务文档
- `docs/source/` 下的所有数据源文档

**处理流程**：
1. 通读所有业务和数据源文档
2. 识别核心业务实体（Who、What、When、Where）
3. 提取业务指标和计算逻辑
4. 映射业务实体到源表字段
5. 识别需要使用拉链表的维度
6. 提出数据分层建议

**输出**：
- `out/design/requirement_analysis_{YYYYMMDD}.md` - 需求分析报告

**输出内容**：
- 业务背景分析
- 业务实体识别（维度实体 vs 事实实体）
- 主题域划分（交易域、用户域、产品域等）
- 业务指标梳理（核心指标 + 派生指标）
- 数据源分析（源表清单、字段映射）
- 业务规则提取（数据清洗、转换、计算规则）
- **缓慢变化维度识别**（哪些维度需要拉链表）
- 数据分层建议

**质量检查**：
- [ ] 是否识别出所有核心实体
- [ ] 是否明确了主题域
- [ ] 是否列出了所有业务指标
- [ ] 是否识别出需要拉链表的维度

---

### 阶段2：数据建模

**执行Agent**：`prompts/02_data_modeler.md`

**输入**：
- `out/design/requirement_analysis_{YYYYMMDD}.md`
- `config/layer_rules.yaml`

**处理流程**：
1. 按数据分层规范设计表模型
2. ODS层：按源系统和源表1:1映射
3. DWD层：按业务主题设计明细表
4. DWS层：按汇总粒度设计汇总表
5. ADS层：按应用场景设计指标表
6. **DIM层：设计拉链表（必须包含start_date、end_date、is_current）**
7. 定义字段清单和数据加工逻辑

**输出**：
- `out/design/{layer}_{table_name}_design_{YYYYMMDD}.md`（每张表一个文件）

**示例输出**：
- `ods_erp_order_design_20240115.md`
- `dwd_trade_order_detail_design_20240115.md`
- `dim_user_info_design_20240115.md`（拉链表）

**输出内容**（每个设计文档）：
- 业务背景
- 数据分层设计（所属层级、主题域）
- 数据模型设计（粒度、主键）
- **字段设计**（含维度、度量、ETL控制字段）
- **DIM层拉链表字段**（start_date、end_date、is_current）
- 数据来源和加工逻辑
- Doris表设计（表模型、分区分桶）
- 数据更新策略（全量/增量/拉链）

**质量检查**：
- [ ] 表名符合命名规范
- [ ] 数据粒度定义清晰
- [ ] 主键设计合理
- [ ] DIM层包含拉链表字段
- [ ] 字段清单完整

---

### 阶段3：表结构设计

**执行Agent**：`prompts/03_schema_designer.md`

**输入**：
- `out/design/{layer}_{table_name}_design_*.md`
- `templates/schema_template.yaml`
- `config/layer_rules.yaml`

**处理流程**：
1. 读取每张表的模型设计
2. 将字段定义转换为YAML格式
3. 选择合适的Doris表模型（DUPLICATE/AGGREGATE/UNIQUE KEY）
4. 设计分区策略（RANGE分区，按日期）
5. 设计分桶策略（HASH分桶，选择高基数字段）
6. **DIM层特殊处理**：
   - 表模型必须为UNIQUE KEY
   - UNIQUE KEY必须包含：维度主键 + start_date
   - 必须包含：start_date、end_date、is_current字段
7. 配置表属性（副本数、压缩、动态分区）

**输出**：
- `out/schema/{layer}_{table_name}_schema.yaml`（每张表一个文件）

**YAML结构**：
```yaml
table:
  database: "dw"
  name: "dim_user_info"
  layer: "DIM"

model:
  type: "UNIQUE"
  keys:
    - user_id
    - start_date  # 拉链表必须包含

columns:
  - name: "user_id"
    is_key: true
  - name: "start_date"
    is_key: true  # 拉链表必须为true
  - name: "end_date"
    default: "'9999-12-31'"
  - name: "is_current"
    default: 1

partition:
  enabled: false  # DIM层通常不分区

distribution:
  type: "HASH"
  columns: ["user_id"]
  buckets: 10
```

**质量检查**：
- [ ] YAML格式正确
- [ ] 表模型选择合理
- [ ] DIM层UNIQUE KEY包含start_date
- [ ] 分区分桶配置合理
- [ ] 字段类型选择准确

---

### 阶段4：SQL生成

**执行Agent**：`prompts/04_sql_generator.md`

**输入**：
- `out/schema/{layer}_{table_name}_schema.yaml`
- `templates/dim_scd2_template.sql`（DIM层参考）

**处理流程**：
1. 读取YAML表结构定义
2. 生成DDL建表语句
3. 生成DML数据更新语句
4. **DIM层特殊处理**：
   - DDL包含拉链表字段定义
   - DML包含完整的拉链表更新逻辑（3步）

**输出**：
- `out/sql/ddl/{layer}_{table_name}_ddl.sql`
- `out/sql/dml/{layer}_{table_name}_dml.sql`

**DDL示例**（DIM层拉链表）：
```sql
CREATE TABLE IF NOT EXISTS dw.dim_user_info (
    user_id BIGINT NOT NULL COMMENT '用户ID',
    user_name VARCHAR(100) NOT NULL COMMENT '用户名',
    user_level VARCHAR(20) NOT NULL COMMENT '用户等级',
    -- 拉链表必须字段
    start_date DATE NOT NULL COMMENT '生效日期',
    end_date DATE NOT NULL DEFAULT '9999-12-31' COMMENT '失效日期',
    is_current TINYINT NOT NULL DEFAULT 1 COMMENT '当前有效标识',
    create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间'
)
UNIQUE KEY(user_id, start_date)  -- 必须包含start_date
COMMENT '用户信息维度拉链表'
DISTRIBUTED BY HASH(user_id) BUCKETS 10
PROPERTIES (
    "replication_num" = "3"
);
```

**DML示例**（DIM层拉链表更新）：
```sql
-- 步骤1：识别变更记录
CREATE TABLE tmp AS ...;

-- 步骤2：关闭旧记录
UPDATE dim_user_info
SET end_date = DATE_SUB(CURDATE(), INTERVAL 1 DAY),
    is_current = 0
WHERE user_id IN (SELECT user_id FROM tmp)
  AND is_current = 1;

-- 步骤3：插入新记录
INSERT INTO dim_user_info
SELECT ..., CURDATE() as start_date, '9999-12-31' as end_date, 1 as is_current
FROM tmp;
```

**质量检查**：
- [ ] SQL语法符合Doris规范
- [ ] DIM层DDL包含拉链表字段
- [ ] DIM层UNIQUE KEY包含start_date
- [ ] DIM层DML包含3步更新逻辑
- [ ] UPDATE在INSERT之前（顺序很重要！）

---

### 阶段5：质量检验方案设计

**执行Agent**：`prompts/05_quality_checker.md`

**输入**：
- `out/schema/{layer}_{table_name}_schema.yaml`
- `out/design/{layer}_{table_name}_design_*.md`
- `templates/quality_template.md`

**处理流程**：
1. 设计数据完整性检验（主键唯一性、非空、数据量）
2. 设计数据准确性检验（数值范围、枚举值、业务规则）
3. 设计数据一致性检验（上下游、汇总、维度一致性）
4. 设计数据及时性检验（SLA时间、延迟监控）
5. **DIM层特殊处理**：设计5项拉链表专项检验

**输出**：
- `out/quality/{layer}_{table_name}_quality_{YYYYMMDD}.md`

**DIM层拉链表专项检验**（5项）：

1. **当前记录唯一性**：每个维度主键只能有1条is_current=1的记录
2. **历史记录end_date检查**：历史记录的end_date不应为'9999-12-31'
3. **当前记录end_date检查**：当前记录的end_date必须为'9999-12-31'
4. **有效期重叠检查**：同一主键不应有时间重叠的记录
5. **有效期连续性检查**：记录时间应连续（可选）

**质量检查**：
- [ ] 检验SQL可执行
- [ ] DIM层包含5项拉链表检验
- [ ] 阈值设定合理
- [ ] 告警级别明确

---

### 阶段6：生成汇总报告

**执行内容**：
1. 统计生成的文件数量
2. 生成文件清单
3. 输出汇总信息

**输出示例**：
```
========================================
数据建模全流程执行完成！
========================================

📊 执行汇总：
  - 需求分析：1 个报告
  - 模型设计：10 个表设计
  - 表结构：10 个YAML文件
  - DDL文件：10 个SQL文件
  - DML文件：10 个SQL文件
  - 质量检验：10 个方案

📋 表清单：
  ODS层（4张）：
    - ods_erp_order
    - ods_erp_order_detail
    - ods_crm_user
    - ods_pms_product
  
  DWD层（2张）：
    - dwd_trade_order_detail
    - dwd_user_behavior_log
  
  DWS层（2张）：
    - dws_trade_user_order_1d
    - dws_trade_product_sales_1d
  
  ADS层（1张）：
    - ads_dashboard_gmv_summary
  
  DIM层（1张拉链表）：
    - dim_user_info （包含start_date, end_date, is_current）

✅ 下一步建议：
  1. 审核模型设计方案
  2. 在Doris中执行DDL建表
  3. 配置调度执行DML
  4. 实施质量检验方案
========================================
```

---

## Agent详细说明

### Agent 1: 需求分析Agent

**核心能力**：
- 业务语言 → 数据术语翻译
- 实体关系识别
- 指标计算逻辑提取
- **缓慢变化维度识别**

**关键输出**：
- 业务实体清单
- 主题域划分
- 业务指标定义
- **需要拉链表的维度列表**

**提示词位置**：`prompts/01_requirement_analyst.md`

---

### Agent 2: 数据建模Agent

**核心能力**：
- 数据分层设计（ODS/DWD/DWS/ADS/DIM）
- 字段设计（维度、度量、ETL控制）
- **拉链表设计**（start_date、end_date、is_current）
- 数据加工逻辑描述

**关键原则**：
- ODS层：1:1映射源表，DUPLICATE KEY
- DWD层：数据清洗，DUPLICATE/UNIQUE KEY
- DWS层：轻度汇总，AGGREGATE KEY
- ADS层：高度聚合，AGGREGATE KEY
- **DIM层：拉链表，UNIQUE KEY(dimension_key, start_date)**

**提示词位置**：`prompts/02_data_modeler.md`

---

### Agent 3: 表结构设计Agent

**核心能力**：
- Doris表模型选择
- 数据类型映射
- 分区分桶策略设计
- **拉链表YAML结构设计**

**DIM层特殊处理**：
```yaml
model:
  type: "UNIQUE"
  keys:
    - dimension_key
    - start_date  # 必须包含！

columns:
  - name: "start_date"
    is_key: true   # 必须为true！
  - name: "end_date"
    default: "'9999-12-31'"
  - name: "is_current"
    default: 1
```

**提示词位置**：`prompts/03_schema_designer.md`

---

### Agent 4: SQL生成Agent

**核心能力**：
- Doris DDL语法生成
- Doris DML语法生成
- **拉链表UPDATE/INSERT逻辑生成**

**拉链表SQL生成要点**：
1. DDL包含3个拉链字段
2. UNIQUE KEY包含start_date
3. DML包含3步逻辑，且**UPDATE必须在INSERT之前**

**错误示例**（避免）：
```sql
-- 错误：先INSERT后UPDATE会导致新记录被误关闭
INSERT INTO dim_user ...;  -- 错误顺序！
UPDATE dim_user SET is_current = 0 ...;
```

**正确示例**：
```sql
-- 正确：先UPDATE关闭旧记录，再INSERT新记录
UPDATE dim_user SET is_current = 0 ...;  -- 正确顺序
INSERT INTO dim_user ...;
```

**提示词位置**：`prompts/04_sql_generator.md`

---

### Agent 5: 质量检验Agent

**核心能力**：
- 数据完整性检验SQL设计
- 数据准确性检验SQL设计
- 数据一致性检验SQL设计
- **拉链表专项检验SQL设计**

**拉链表5项检验**：

```sql
-- 1. 当前记录唯一性
SELECT dimension_key, COUNT(*)
FROM dim_table
WHERE is_current = 1
GROUP BY dimension_key
HAVING COUNT(*) > 1;  -- 预期：无记录

-- 2. 历史记录end_date检查
SELECT COUNT(*)
FROM dim_table
WHERE is_current = 0 AND end_date = '9999-12-31';  -- 预期：0

-- 3. 当前记录end_date检查
SELECT COUNT(*)
FROM dim_table
WHERE is_current = 1 AND end_date != '9999-12-31';  -- 预期：0

-- 4. 有效期重叠检查
SELECT a.dimension_key, a.start_date, a.end_date, b.start_date, b.end_date
FROM dim_table a
JOIN dim_table b ON a.dimension_key = b.dimension_key
WHERE a.start_date < b.start_date
  AND a.end_date >= b.start_date;  -- 预期：无记录

-- 5. 有效期连续性检查
SELECT dimension_key, end_date, next_start_date
FROM (
    SELECT dimension_key, end_date,
           LEAD(start_date) OVER (PARTITION BY dimension_key ORDER BY start_date) as next_start_date
    FROM dim_table
)
WHERE end_date != '9999-12-31'
  AND DATEDIFF(next_start_date, end_date) != 1;  -- 预期：无记录或在允许范围
```

**提示词位置**：`prompts/05_quality_checker.md`

---

## 拉链表设计详解

### 为什么需要拉链表？

**问题场景**：
- 用户等级会变化：普通 → VIP → SVIP
- 商品价格会调整：8999 → 7999（促销）
- 需要回答："这个用户在2023年1月1日时是什么等级？"

**传统方案的问题**：
- 全量快照：每天存储一份全量数据，存储成本极高
- 只保留当前：无法追溯历史
- 增加版本号：查询复杂，无法按时间点查询

**拉链表方案**：
- 只保存变化的记录
- 通过start_date和end_date标识有效期
- 支持时间点查询
- 存储成本低

### 拉链表三要素

| 字段 | 类型 | 说明 | 当前记录 | 历史记录 |
|-----|------|------|---------|---------|
| start_date | DATE | 生效日期 | 最新的日期 | 历史日期 |
| end_date | DATE | 失效日期 | '9999-12-31' | 实际失效日期 |
| is_current | TINYINT | 当前标识 | 1 | 0 |

### 拉链表更新示例

**场景**：用户88888888的等级从"VIP"升级为"SVIP"

**更新前**：
```sql
user_id  | user_level | start_date | end_date    | is_current
---------|------------|------------|-------------|------------
88888888 | VIP        | 2024-01-01 | 9999-12-31  | 1
```

**执行更新**（2024-01-15）：
```sql
-- 步骤1：关闭旧记录
UPDATE dim_user_info
SET end_date = '2024-01-14',
    is_current = 0
WHERE user_id = 88888888 AND is_current = 1;

-- 步骤2：插入新记录
INSERT INTO dim_user_info
VALUES (88888888, 'SVIP', '2024-01-15', '9999-12-31', 1);
```

**更新后**：
```sql
user_id  | user_level | start_date | end_date    | is_current
---------|------------|------------|-------------|------------
88888888 | VIP        | 2024-01-01 | 2024-01-14  | 0
88888888 | SVIP       | 2024-01-15 | 9999-12-31  | 1
```

### 拉链表查询技巧

**查询当前记录**：
```sql
SELECT * FROM dim_user_info WHERE is_current = 1;
-- 性能优于 WHERE end_date = '9999-12-31'
```

**查询历史时间点**：
```sql
-- 查询2024-01-10用户的等级（答案：VIP）
SELECT * FROM dim_user_info
WHERE user_id = 88888888
  AND '2024-01-10' BETWEEN start_date AND end_date;
```

**查询完整历史**：
```sql
-- 查询用户等级变化历史
SELECT user_id, user_level, start_date, end_date
FROM dim_user_info
WHERE user_id = 88888888
ORDER BY start_date;
```

**事实表关联维度表**（时间点查询）：
```sql
-- 查询订单下单时用户的等级
SELECT 
    o.order_id,
    o.order_date,
    d.user_level  -- 订单下单时的用户等级
FROM fact_order o
LEFT JOIN dim_user_info d
    ON o.user_id = d.user_id
    AND o.order_date BETWEEN d.start_date AND d.end_date;
```

---

## 实际使用案例

### 案例：电商用户订单分析

#### 输入准备

**1. 业务需求文档**（`docs/business/requirement.md`）：
```markdown
# 业务需求

## 业务目标
分析用户购买行为，统计GMV、订单量等指标。

## 业务实体
- 用户：user_id, user_name, user_level（会变化）
- 订单：order_id, user_id, amount, status
- 商品：product_id, product_name, price（会变化）

## 核心指标
- GMV = SUM(订单金额) WHERE 订单状态 IN ('已付款','已完成')
- 订单量 = COUNT(DISTINCT 订单ID)

## 特殊需求
- 用户等级会变化，需要追踪历史
- 商品价格会调整，需要知道订单下单时的价格
```

**2. 数据源文档**（`docs/source/tables.md`）：
```markdown
# 数据源

## t_user（用户表）
- user_id BIGINT - 用户ID
- user_name VARCHAR - 用户名
- user_level VARCHAR - 用户等级（普通/VIP/SVIP）
- update_time DATETIME - 每日凌晨更新

## t_order（订单表）
- order_id BIGINT - 订单ID
- user_id BIGINT - 用户ID
- amount DECIMAL - 订单金额
- create_time DATETIME - 下单时间
```

#### 执行建模

在Cursor中输入：
```
开始数据建模
```

#### 输出结果

**1. 需求分析报告**（`out/design/requirement_analysis_20240115.md`）：
- 识别出2个需要拉链表的维度：用户、商品
- 建议ODS 2张 + DWD 1张 + DWS 1张 + DIM 2张

**2. 模型设计**（共6个文件）：
- `ods_erp_order_design_20240115.md`
- `ods_crm_user_design_20240115.md`
- `dwd_trade_order_detail_design_20240115.md`
- `dws_trade_user_order_1d_design_20240115.md`
- `dim_user_info_design_20240115.md`（拉链表）
- `dim_product_info_design_20240115.md`（拉链表）

**3. 表结构**（6个YAML文件）：
- `dim_user_info_schema.yaml` 包含拉链表字段和UNIQUE KEY配置

**4. SQL文件**（12个文件）：
- DDL：`dim_user_info_ddl.sql` - 包含拉链表字段定义
- DML：`dim_user_info_dml.sql` - 包含3步更新逻辑

**5. 质量检验**（6个文件）：
- `dim_user_info_quality_20240115.md` - 包含5项拉链表检验

#### 在Doris中执行

```sql
-- 1. 执行DDL创建表
SOURCE out/sql/ddl/dim_user_info_ddl.sql;

-- 2. 初次加载数据
-- （修改DML中的初始化SQL并执行）

-- 3. 每日增量更新
-- （配置调度任务执行DML中的拉链更新SQL）

-- 4. 查询验证
-- 查询当前所有用户
SELECT * FROM dim_user_info WHERE is_current = 1;

-- 查询某用户历史
SELECT * FROM dim_user_info WHERE user_id = 88888888 ORDER BY start_date;
```

---

## 故障排查

### 问题1：生成的YAML格式错误

**症状**：阅读YAML文件时报错

**原因**：
- 缩进不一致（混用空格和Tab）
- 特殊字符未转义
- 布尔值格式错误

**解决**：
1. 检查YAML文件格式
2. 使用YAML验证工具
3. 重新执行Agent 3

---

### 问题2：DIM层缺少拉链表字段

**症状**：DDL中没有start_date、end_date或is_current

**原因**：
- Agent 2模型设计时遗漏
- Agent 3转换时遗漏
- Agent 4生成SQL时遗漏

**解决**：
1. 检查模型设计文档是否包含拉链表字段
2. 检查YAML是否包含拉链表字段
3. 重新执行对应Agent
4. 或手动补充字段

---

### 问题3：UNIQUE KEY没有包含start_date

**症状**：DDL中 `UNIQUE KEY(user_id)` 缺少start_date

**原因**：Agent 3或Agent 4处理错误

**解决**：
1. 修改YAML文件，确保keys包含start_date
2. 重新执行Agent 4生成SQL
3. 或手动修改SQL：`UNIQUE KEY(user_id, start_date)`

---

### 问题4：拉链表UPDATE和INSERT顺序错误

**症状**：执行DML后数据异常

**原因**：先INSERT后UPDATE导致新记录被误关闭

**解决**：
1. 检查DML文件，确保UPDATE在INSERT之前
2. 重新执行Agent 4
3. 或手动调整SQL顺序

---

### 问题5：SQL在Doris中执行报错

**症状**：执行DDL或DML时报语法错误

**常见错误**：
```sql
-- 错误1：分区语法缺少()
PARTITION BY RANGE(date_column)  -- 错误
PARTITION BY RANGE(date_column) ()  -- 正确

-- 错误2：AGGREGATE KEY缺少聚合函数
CREATE TABLE t (
    id INT,
    amount DECIMAL  -- 错误：缺少聚合函数
) AGGREGATE KEY(id);

-- 正确：
CREATE TABLE t (
    id INT,
    amount DECIMAL SUM  -- 添加聚合函数
) AGGREGATE KEY(id);
```

**解决**：
1. 检查SQL语法
2. 参考Doris官方文档
3. 重新执行Agent 4

---

## 最佳实践

### 1. 输入文档准备

✅ **做好充分的准备**：
- 业务文档要详细，包含所有业务规则
- 数据源文档要完整，包含字段示例和数据问题

❌ **避免输入不足**：
- 缺少关键业务规则会导致模型不准确
- 数据源字段不全会导致遗漏

### 2. 分批审核

✅ **分层审核**：
1. 先审核ODS层和DIM层（基础层）
2. 再审核DWD层（明细层）
3. 最后审核DWS和ADS层（汇总层）

❌ **避免一次性审核所有表**：
- 工作量大，容易遗漏
- 基础层错误会影响上层

### 3. 拉链表测试

✅ **测试拉链表逻辑**：
1. 执行DDL创建表
2. 插入初始数据
3. 执行更新SQL（模拟等级变化）
4. 查询验证数据正确性

❌ **避免直接上生产**：
- 拉链表逻辑复杂，需充分测试
- 一旦数据错误，修复困难

### 4. 增量执行

✅ **分阶段实施**：
- 第一阶段：核心ODS和DIM
- 第二阶段：关键DWD
- 第三阶段：DWS和ADS

❌ **避免一次性上线所有表**：
- 风险大，问题难定位
- 调度依赖复杂

---

## 附录

### A. 快速命令参考

```
# 全流程执行
开始数据建模

# 单独执行
只执行需求分析
只执行数据建模
为 dim_user_info 生成SQL
为 dim_user_info 生成质量检验方案

# 查看示例
查看业务文档示例
查看数据源文档示例
```

### B. 文件命名规范

| 类型 | 命名规范 | 示例 |
|-----|---------|------|
| 模型设计 | `{layer}_{table}_design_{date}.md` | `dim_user_info_design_20240115.md` |
| 表结构 | `{layer}_{table}_schema.yaml` | `dim_user_info_schema.yaml` |
| DDL | `{layer}_{table}_ddl.sql` | `dim_user_info_ddl.sql` |
| DML | `{layer}_{table}_dml.sql` | `dim_user_info_dml.sql` |
| 质量检验 | `{layer}_{table}_quality_{date}.md` | `dim_user_info_quality_20240115.md` |

### C. 拉链表检查清单

在DIM层表上线前，必须检查：

- [ ] DDL包含start_date（DATE类型）
- [ ] DDL包含end_date（DATE类型，默认'9999-12-31'）
- [ ] DDL包含is_current（TINYINT类型，默认1）
- [ ] UNIQUE KEY包含维度主键和start_date
- [ ] DML包含3步更新逻辑
- [ ] UPDATE在INSERT之前
- [ ] UPDATE设置end_date和is_current=0
- [ ] INSERT设置start_date=今天，end_date='9999-12-31'，is_current=1
- [ ] 质量检验包含5项拉链表检验

---

**文档版本**：v1.0  
**最后更新**：2024-01-15  

更多问题请参考 [README.md](README.md) 或查看示例文档 `docs/examples/`。


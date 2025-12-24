# Doris数据建模AI Agent系统

> 一个基于多Agent协作的Apache Doris数据建模自动化模板系统，帮助您快速完成从业务需求到SQL代码的全流程数据建模工作。

## 🎯 系统简介

本系统通过5个专业AI Agent的协作，自动完成数据仓库建模的全流程工作：

1. **需求分析Agent** - 解析业务需求和数据源，生成需求分析报告
2. **数据建模Agent** - 设计数据分层模型（ODS/DWD/DWS/ADS/DIM）
3. **表结构设计Agent** - 生成Doris表结构定义（YAML格式）
4. **SQL生成Agent** - 生成DDL建表语句和DML数据更新语句
5. **质量检验Agent** - 设计数据质量检验方案

### ✨ 核心特性

- ✅ **全自动化流程**：从需求文档到可执行SQL，一键生成
- ✅ **符合Doris语法**：所有SQL符合Apache Doris规范，可直接执行
- ✅ **拉链表支持**：DIM层自动生成SCD Type 2拉链表设计和更新逻辑
- ✅ **质量保证**：自动生成完整的数据质量检验方案
- ✅ **标准化输出**：统一的文档结构和SQL代码规范

### 📊 数据分层规范

- **ODS层**：原始数据接入，保持源数据原貌
- **DWD层**：明细数据清洗、标准化、整合
- **DWS层**：按主题轻度汇总，构建宽表
- **ADS层**：面向业务场景的应用层数据
- **DIM层**：维度数据管理（使用SCD Type 2拉链表）

## 📁 目录结构

```
/
├── .cursorrules                   # Cursor AI项目规则（自动指导AI）
├── docs/
│   ├── business/              # 📝 放置业务理解文档
│   ├── source/               # 📋 放置数据源文档（含字段样例）
│   └── examples/             # 📚 示例文档
│       ├── business_example.md
│       └── source_example.md
├── out/
│   ├── design/               # 📄 模型设计方案输出
│   ├── schema/               # 📐 表结构文档输出（YAML格式）
│   ├── sql/
│   │   ├── ddl/             # 🔨 建表语句（.sql）
│   │   └── dml/             # 🔄 数据更新语句（.sql）
│   └── quality/              # ✅ 数据质量检验方案
├── prompts/
│   ├── 01_requirement_analyst.md    # 需求分析Agent提示词
│   ├── 02_data_modeler.md          # 数据建模Agent提示词
│   ├── 03_schema_designer.md       # 表结构设计Agent提示词
│   ├── 04_sql_generator.md         # SQL生成Agent提示词
│   ├── 05_quality_checker.md       # 质量检验Agent提示词
│   └── orchestrator.md             # 编排Agent（协调其他Agent）
├── templates/
│   ├── design_template.md          # 设计方案模板
│   ├── schema_template.yaml        # 表结构模板
│   ├── quality_template.md         # 质量检验模板
│   └── dim_scd2_template.sql       # 拉链表SQL模板
├── config/
│   └── layer_rules.yaml            # 分层规范（ODS/DWD/DWS/ADS/DIM）
├── README.md                       # 使用说明（本文档）
└── WORKFLOW.md                     # 工作流详解
```

## 🚀 快速开始

### 前置准备

1. 在Cursor中打开本项目
2. 确保 `.cursorrules` 文件存在（系统会自动加载规则）

### 第一步：准备输入文档

将您的文档放入对应目录：

1. **业务需求文档** → `docs/business/`
   - 业务目标、业务场景、指标定义等
   - 可参考 `docs/examples/business_example.md`

2. **数据源文档** → `docs/source/`
   - 源表结构、字段说明、数据样例
   - 可参考 `docs/examples/source_example.md`

### 第二步：启动建模流程

在Cursor中输入以下任一指令：

```
开始数据建模
```

或

```
执行数据建模全流程
```

系统会自动依次执行5个Agent，生成所有输出文件。

### 第三步：查看输出结果

执行完成后，查看 `out/` 目录下的输出：

```
out/
├── design/          # 查看模型设计方案
├── schema/          # 查看YAML表结构定义
├── sql/
│   ├── ddl/         # ⭐ 在Doris中执行建表语句
│   └── dml/         # ⭐ 配置调度任务执行数据更新
└── quality/         # 查看质量检验方案
```

## 📖 使用示例

### 示例场景：电商订单分析

**输入**：
- 业务需求：需要分析用户购买行为，统计GMV、订单量等指标
- 数据源：ERP订单表、CRM用户表、PMS商品表

**输出**：
- 需求分析报告
- 10张表的模型设计（ODS 4张 + DWD 2张 + DWS 2张 + ADS 1张 + DIM 1张）
- 10个YAML表结构定义
- 10个DDL文件 + 10个DML文件
- 10个质量检验方案

**DIM层拉链表**：
- `dim_user_info` - 追踪用户等级和状态变化
- 自动生成包含 `start_date`, `end_date`, `is_current` 字段
- 自动生成拉链表更新SQL（识别变更→关闭旧记录→插入新记录）

完整示例文档见 `docs/examples/`。

## 🔧 高级用法

### 单独执行某个Agent

除了全流程执行，您也可以单独执行某个Agent：

```
只执行需求分析
```

```
只执行数据建模
```

```
为 dim_user_info 生成SQL
```

### 重新执行某个阶段

如果某个阶段的输出需要调整：

1. 修改输入文档或前置输出
2. 在Cursor中指定重新执行该Agent
3. 系统会覆盖之前的输出

## 📋 输出文件说明

### 1. 模型设计方案（Markdown）

**位置**：`out/design/{layer}_{table_name}_design_{YYYYMMDD}.md`

**内容**：
- 业务背景
- 数据粒度定义
- 字段设计
- 数据来源和加工逻辑
- Doris表设计
- 数据更新策略

### 2. 表结构定义（YAML）

**位置**：`out/schema/{layer}_{table_name}_schema.yaml`

**内容**：
- 表基本信息
- 表模型配置（DUPLICATE/AGGREGATE/UNIQUE KEY）
- 字段定义（类型、注释、约束）
- 分区分桶配置
- 表属性

### 3. DDL建表语句（SQL）

**位置**：`out/sql/ddl/{layer}_{table_name}_ddl.sql`

**内容**：
- CREATE TABLE语句
- 符合Doris语法
- 可直接在Doris中执行

### 4. DML数据更新语句（SQL）

**位置**：`out/sql/dml/{layer}_{table_name}_dml.sql`

**内容**：
- INSERT INTO语句
- DIM层包含完整的拉链表更新逻辑
- 参数化日期（${target_date}）

### 5. 质量检验方案（Markdown）

**位置**：`out/quality/{layer}_{table_name}_quality_{YYYYMMDD}.md`

**内容**：
- 数据完整性检验（主键唯一性、非空检查等）
- 数据准确性检验（数值范围、枚举值等）
- 数据一致性检验（上下游一致性等）
- DIM层拉链表专项检验（5项检查）

## 🎯 拉链表设计说明

### 什么是拉链表？

拉链表（SCD Type 2）用于追踪维度数据的历史变化，支持时间点查询。

### 拉链表必须字段

所有DIM层表必须包含以下三个字段：

1. **start_date**（DATE） - 记录生效日期
2. **end_date**（DATE） - 记录失效日期，当前记录为 `'9999-12-31'`
3. **is_current**（TINYINT） - 当前有效标识，`1`=当前有效，`0`=历史记录

### 拉链表更新逻辑

系统自动生成三步更新逻辑：

```sql
-- 步骤1：识别变更记录
-- 步骤2：UPDATE关闭旧记录（end_date=昨天, is_current=0）
-- 步骤3：INSERT插入新记录（start_date=今天, is_current=1）
```

### 拉链表查询示例

```sql
-- 查询当前记录
SELECT * FROM dim_user_info WHERE is_current = 1;

-- 查询历史时间点记录（2023-01-01的用户等级）
SELECT * FROM dim_user_info 
WHERE '2023-01-01' BETWEEN start_date AND end_date;

-- 查询某用户的完整历史
SELECT * FROM dim_user_info 
WHERE user_id = 88888888 
ORDER BY start_date;
```

## ✅ 质量保证

### 自动质量检查

系统在生成过程中会自动检查：

- [ ] DIM层表是否包含拉链表字段
- [ ] UNIQUE KEY是否包含 `start_date`
- [ ] SQL语法是否符合Doris规范
- [ ] 字段定义是否完整
- [ ] 分区分桶配置是否合理

### 数据质量检验方案

系统为每张表生成完整的质量检验SQL：

- **完整性检验**：主键唯一性、非空检查、数据量检查
- **准确性检验**：数值范围、枚举值、业务规则
- **一致性检验**：上下游一致性、汇总一致性
- **及时性检验**：数据就绪时间、SLA监控
- **拉链表专项检验**（DIM层）：当前记录唯一性、时间重叠检查等

## 🛠️ 配置说明

### .cursorrules

项目级AI规则文件，Cursor会自动加载。包含：

- 项目识别和工作流程
- Doris SQL语法规范
- 拉链表设计规范
- 数据分层规范
- 输出文件格式要求

### config/layer_rules.yaml

数据分层规范配置文件，定义：

- 各层级的命名规范
- 表模型选择规则
- 必须字段清单
- 分区分桶策略
- ETL更新策略

## 📚 参考文档

- [WORKFLOW.md](WORKFLOW.md) - 详细的工作流程说明
- [prompts/orchestrator.md](prompts/orchestrator.md) - 编排Agent使用说明
- [docs/examples/](docs/examples/) - 完整的示例文档
- [templates/](templates/) - 输出文档模板

## ❓ 常见问题

### Q1: 生成的SQL可以直接执行吗？

**A**: 是的！所有生成的SQL都符合Apache Doris语法规范，可以直接在Doris中执行。

### Q2: DIM层一定要使用拉链表吗？

**A**: 是的。本系统强制要求所有DIM层维度表使用SCD Type 2拉链表设计，以支持历史追溯和时间点查询。

### Q3: 如何调整生成的结果？

**A**: 您可以：
1. 修改输入文档后重新执行
2. 修改Agent提示词（`prompts/`目录）
3. 直接编辑输出文件

### Q4: 支持哪些数据库？

**A**: 本系统专为Apache Doris设计，生成的SQL仅保证在Doris中可用。

### Q5: 可以用于其他业务场景吗？

**A**: 当然可以！只要提供相应的业务需求文档和数据源文档，系统可以处理各种业务场景。

## 🤝 贡献

欢迎提交Issue和Pull Request改进本系统！

## 📄 许可证

本项目仅供学习和参考使用。

---

**系统版本**：v1.0  
**创建日期**：2024-01-15  
**技术栈**：Apache Doris + AI Agent

## 🎉 开始使用

现在就将您的业务文档放入 `docs/business/` 和 `docs/source/`，然后在Cursor中输入：

```
开始数据建模
```

让AI帮您完成数据建模工作！


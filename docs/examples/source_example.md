# 电商数据源文档（示例）

## 一、数据源概述

### 1.1 源系统清单

| 源系统 | 系统说明 | 数据库类型 | 同步方式 | 同步频率 |
|--------|---------|-----------|---------|---------|
| ERP系统 | 订单管理系统 | MySQL | 增量同步 | 每5分钟 |
| CRM系统 | 客户关系管理 | PostgreSQL | 全量同步 | 每日凌晨 |
| PMS系统 | 商品管理系统 | MySQL | 增量同步 | 每小时 |

### 1.2 数据同步时间
- ERP订单数据：实时同步（延迟5分钟）
- CRM用户数据：每日00:30开始同步，01:00完成
- PMS商品数据：每小时整点同步

## 二、源表结构说明

### 2.1 ERP系统 - 订单表（t_order）

**表说明**：订单主表，记录订单基本信息

**数据量级**：
- 存量：5000万条
- 日增量：约10万条
- 数据保留：永久

**字段清单**：

| 字段名 | 数据类型 | 是否必填 | 字段说明 | 示例值 | 备注 |
|--------|---------|---------|---------|--------|------|
| order_id | BIGINT | Y | 订单ID，主键 | 1234567890123 | 唯一标识 |
| user_id | BIGINT | Y | 用户ID | 88888888 | 关联用户表 |
| order_amount | DECIMAL(18,2) | Y | 订单金额（元） | 299.00 | 订单总金额 |
| pay_amount | DECIMAL(18,2) | N | 实付金额（元） | 279.00 | 扣除优惠后 |
| order_status | TINYINT | Y | 订单状态 | 2 | 见状态枚举 |
| province | VARCHAR(50) | N | 收货省份 | 北京市 | |
| city | VARCHAR(50) | N | 收货城市 | 北京市 | |
| district | VARCHAR(50) | N | 收货区县 | 朝阳区 | |
| create_time | DATETIME | Y | 创建时间 | 2024-01-15 10:30:00 | 下单时间 |
| pay_time | DATETIME | N | 支付时间 | 2024-01-15 10:35:00 | 可能为空 |
| finish_time | DATETIME | N | 完成时间 | 2024-01-16 15:00:00 | 可能为空 |
| update_time | DATETIME | Y | 更新时间 | 2024-01-15 10:35:00 | 最后更新时间 |

**订单状态枚举**：
- 0：待付款
- 1：已付款
- 2：已发货
- 3：已完成
- 4：已取消
- 5：已退款

**数据样例**：
```sql
order_id     | 1234567890123
user_id      | 88888888
order_amount | 299.00
pay_amount   | 279.00
order_status | 2
province     | 北京市
city         | 北京市
district     | 朝阳区
create_time  | 2024-01-15 10:30:00
pay_time     | 2024-01-15 10:35:00
finish_time  | NULL
update_time  | 2024-01-15 10:35:00
```

**数据质量问题**：
- 部分老数据province、city、district为空
- 极少数订单order_amount为负数（退款订单）
- 待付款订单的pay_time为NULL

---

### 2.2 ERP系统 - 订单明细表（t_order_detail）

**表说明**：订单明细表，记录订单中的商品明细

**数据量级**：
- 存量：1.5亿条
- 日增量：约30万条
- 数据保留：永久

**字段清单**：

| 字段名 | 数据类型 | 是否必填 | 字段说明 | 示例值 | 备注 |
|--------|---------|---------|---------|--------|------|
| detail_id | BIGINT | Y | 明细ID，主键 | 9876543210123 | 唯一标识 |
| order_id | BIGINT | Y | 订单ID | 1234567890123 | 关联订单表 |
| product_id | BIGINT | Y | 商品ID | 55555555 | 关联商品表 |
| product_name | VARCHAR(200) | Y | 商品名称 | iPhone 15 Pro 256GB 蓝色 | 快照 |
| quantity | INT | Y | 购买数量 | 1 | 件数 |
| price | DECIMAL(18,2) | Y | 商品单价（元） | 8999.00 | 下单时价格 |
| amount | DECIMAL(18,2) | Y | 小计金额（元） | 8999.00 | quantity × price |
| create_time | DATETIME | Y | 创建时间 | 2024-01-15 10:30:00 | |

**数据样例**：
```sql
detail_id    | 9876543210123
order_id     | 1234567890123
product_id   | 55555555
product_name | iPhone 15 Pro 256GB 蓝色
quantity     | 1
price        | 8999.00
amount       | 8999.00
create_time  | 2024-01-15 10:30:00
```

**数据质量问题**：
- product_name可能与商品表中的名称不一致（商品表可能改名）
- 极少数记录quantity为0（已删除的商品）

---

### 2.3 CRM系统 - 用户表（t_user）

**表说明**：用户主表，记录用户基本信息

**数据量级**：
- 存量：500万条
- 日增量：约5000条
- 数据保留：永久

**字段清单**：

| 字段名 | 数据类型 | 是否必填 | 字段说明 | 示例值 | 备注 |
|--------|---------|---------|---------|--------|------|
| user_id | BIGINT | Y | 用户ID，主键 | 88888888 | 唯一标识 |
| user_name | VARCHAR(100) | N | 用户姓名 | 张三 | 可能为空 |
| mobile | VARCHAR(20) | Y | 手机号 | 13800138000 | 脱敏后 |
| gender | TINYINT | N | 性别 | 1 | 0=女, 1=男, 2=未知 |
| birthday | DATE | N | 生日 | 1990-01-01 | 可能为空 |
| register_channel | VARCHAR(50) | Y | 注册渠道 | APP | APP/小程序/PC |
| register_time | DATETIME | Y | 注册时间 | 2023-05-10 12:00:00 | |
| user_level | VARCHAR(20) | Y | 用户等级 | VIP | 普通/VIP/SVIP |
| user_status | VARCHAR(20) | Y | 用户状态 | 活跃 | 活跃/沉睡/流失 |
| total_order_count | INT | N | 累计订单数 | 25 | 统计字段 |
| total_amount | DECIMAL(18,2) | N | 累计消费金额 | 15888.00 | 统计字段 |
| last_order_time | DATETIME | N | 最后下单时间 | 2024-01-10 08:00:00 | |
| create_time | DATETIME | Y | 创建时间 | 2023-05-10 12:00:00 | |
| update_time | DATETIME | Y | 更新时间 | 2024-01-15 02:00:00 | 每日凌晨更新 |

**数据样例**：
```sql
user_id           | 88888888
user_name         | 张三
mobile            | 138****8000
gender            | 1
birthday          | 1990-01-01
register_channel  | APP
register_time     | 2023-05-10 12:00:00
user_level        | VIP
user_status       | 活跃
total_order_count | 25
total_amount      | 15888.00
last_order_time   | 2024-01-10 08:00:00
create_time       | 2023-05-10 12:00:00
update_time       | 2024-01-15 02:00:00
```

**重要说明**：
- user_level和user_status每日凌晨会根据业务规则重新计算并更新
- total_order_count和total_amount也是每日更新
- **需要使用拉链表追踪user_level和user_status的变化历史**

**数据质量问题**：
- 部分老用户user_name为空
- 部分用户birthday为NULL或明显异常（如：1900-01-01）

---

### 2.4 PMS系统 - 商品表（t_product）

**表说明**：商品主表，记录商品基本信息

**数据量级**：
- 存量：100万条
- 日增量：约1000条
- 数据保留：永久

**字段清单**：

| 字段名 | 数据类型 | 是否必填 | 字段说明 | 示例值 | 备注 |
|--------|---------|---------|---------|--------|------|
| product_id | BIGINT | Y | 商品ID，主键 | 55555555 | 唯一标识 |
| product_name | VARCHAR(200) | Y | 商品名称 | iPhone 15 Pro 256GB 蓝色 | |
| product_code | VARCHAR(50) | Y | 商品编码 | IP15P-256-BLUE | SKU编码 |
| category_id_1 | INT | Y | 一级类目ID | 1 | 电子产品 |
| category_name_1 | VARCHAR(50) | Y | 一级类目名称 | 电子产品 | |
| category_id_2 | INT | Y | 二级类目ID | 101 | 手机 |
| category_name_2 | VARCHAR(50) | Y | 二级类目名称 | 手机 | |
| brand_id | INT | Y | 品牌ID | 10 | |
| brand_name | VARCHAR(50) | Y | 品牌名称 | Apple | |
| price | DECIMAL(18,2) | Y | 售价（元） | 8999.00 | 当前售价 |
| cost | DECIMAL(18,2) | N | 成本价（元） | 6500.00 | 敏感字段 |
| stock_quantity | INT | Y | 库存数量 | 1500 | 实时库存 |
| product_status | TINYINT | Y | 商品状态 | 1 | 0=下架, 1=上架 |
| create_time | DATETIME | Y | 创建时间 | 2023-09-20 10:00:00 | |
| update_time | DATETIME | Y | 更新时间 | 2024-01-14 15:30:00 | |

**数据样例**：
```sql
product_id      | 55555555
product_name    | iPhone 15 Pro 256GB 蓝色
product_code    | IP15P-256-BLUE
category_id_1   | 1
category_name_1 | 电子产品
category_id_2   | 101
category_name_2 | 手机
brand_id        | 10
brand_name      | Apple
price           | 8999.00
cost            | 6500.00
stock_quantity  | 1500
product_status  | 1
create_time     | 2023-09-20 10:00:00
update_time     | 2024-01-14 15:30:00
```

**重要说明**：
- price字段会调整（促销、调价）
- category_id_2可能会调整（商品重新分类）
- product_status会变化（上下架）
- **需要使用拉链表追踪price和category的变化历史**

**数据质量问题**：
- 极少数商品category_id_2与category_name_2不匹配
- 部分商品cost为NULL

---

### 2.5 基础数据 - 地区表（d_region）

**表说明**：地区维度表，相对稳定

**数据量级**：约3000条（全国省市区）

**字段清单**：

| 字段名 | 数据类型 | 是否必填 | 字段说明 | 示例值 | 备注 |
|--------|---------|---------|---------|--------|------|
| region_id | INT | Y | 地区ID，主键 | 110105 | |
| province | VARCHAR(50) | Y | 省份 | 北京市 | |
| city | VARCHAR(50) | Y | 城市 | 北京市 | |
| district | VARCHAR(50) | Y | 区县 | 朝阳区 | |
| region_level | VARCHAR(20) | Y | 地区等级 | 一线 | 一线/二线/三线/四线 |

**数据样例**：
```sql
region_id    | 110105
province     | 北京市
city         | 北京市
district     | 朝阳区
region_level | 一线
```

**说明**：
- 地区表相对稳定，变化很少
- 可以不使用拉链表

## 三、数据关系

### 3.1 实体关系图

```
用户表 (t_user)
    ↓ 1:N
订单表 (t_order)
    ↓ 1:N
订单明细表 (t_order_detail)
    ↓ N:1
商品表 (t_product)

订单表 (t_order) → 地区表 (d_region)（通过province, city, district关联）
```

### 3.2 关联关系

**订单与用户**：
- 关联字段：t_order.user_id = t_user.user_id
- 关联类型：N:1
- 数据完整性：订单表的user_id在用户表中100%存在

**订单与订单明细**：
- 关联字段：t_order.order_id = t_order_detail.order_id
- 关联类型：1:N
- 数据完整性：每个订单至少有1条明细

**订单明细与商品**：
- 关联字段：t_order_detail.product_id = t_product.product_id
- 关联类型：N:1
- 数据完整性：约99%的product_id能关联到商品表（极少数商品已删除）

**订单与地区**：
- 关联字段：t_order.province, city, district 与 d_region.province, city, district
- 关联类型：N:1
- 数据完整性：约90%能关联（部分订单地址为空）

## 四、数据变化说明

### 4.1 用户表变化
**变化字段**：user_level、user_status、total_order_count、total_amount、last_order_time

**变化频率**：每日凌晨批量更新

**变化逻辑**：
1. 根据累计消费金额更新user_level
2. 根据最后下单时间更新user_status
3. 更新统计字段

**历史追踪需求**：需要知道用户在任意历史时间点的等级和状态

### 4.2 商品表变化
**变化字段**：price、category_id_2、category_name_2、product_status、stock_quantity

**变化频率**：
- price：不定期调整（促销、季节性调价）
- category：偶尔调整
- product_status：频繁变化（上下架）
- stock_quantity：实时变化

**历史追踪需求**：需要知道商品在历史订单下单时的价格和类目

### 4.3 订单表变化
**变化字段**：order_status、pay_time、finish_time、update_time

**变化类型**：订单状态流转（待付款→已付款→已发货→已完成）

**变化频率**：实时

## 五、数据质量问题汇总

### 5.1 完整性问题
- 用户表：user_name约5%为空，birthday约20%为空
- 订单表：province、city、district约10%为空
- 商品表：cost约30%为空

### 5.2 准确性问题
- 订单表：极少数order_amount为负数（退款订单）
- 订单明细表：极少数quantity为0
- 用户表：部分birthday明显异常（1900-01-01）

### 5.3 一致性问题
- 订单明细表的product_name可能与商品表不一致（商品改名）
- 部分订单的product_id在商品表中不存在（商品已删除）
- 极少数订单的order_amount ≠ SUM(明细amount)

### 5.4 及时性问题
- ERP订单数据：实时同步，延迟5分钟内
- CRM用户数据：每日凌晨同步，延迟约1小时
- PMS商品数据：每小时同步，延迟10分钟内

## 六、数据样例脚本

### 6.1 查询用户最近订单
```sql
SELECT 
    o.order_id,
    o.user_id,
    u.user_name,
    u.user_level,
    o.order_amount,
    o.order_status,
    o.create_time
FROM t_order o
LEFT JOIN t_user u ON o.user_id = u.user_id
WHERE u.user_id = 88888888
ORDER BY o.create_time DESC
LIMIT 10;
```

### 6.2 查询订单明细
```sql
SELECT 
    d.detail_id,
    d.order_id,
    d.product_id,
    d.product_name,
    p.brand_name,
    p.category_name_2,
    d.quantity,
    d.price,
    d.amount
FROM t_order_detail d
LEFT JOIN t_product p ON d.product_id = p.product_id
WHERE d.order_id = 1234567890123;
```

### 6.3 统计每日订单量
```sql
SELECT 
    DATE(create_time) as order_date,
    COUNT(DISTINCT order_id) as order_count,
    SUM(order_amount) as total_amount
FROM t_order
WHERE order_status IN (1, 2, 3)  -- 已付款、已发货、已完成
  AND DATE(create_time) >= '2024-01-01'
GROUP BY DATE(create_time)
ORDER BY order_date;
```

## 七、注意事项

### 7.1 数据同步
- 确保同步任务的稳定性和及时性
- 监控同步延迟，及时告警

### 7.2 数据清洗
- 处理空值、异常值
- 统一编码和格式
- 去重处理

### 7.3 拉链表设计
- **用户维度表**：必须使用拉链表追踪user_level和user_status变化
- **商品维度表**：必须使用拉链表追踪price和category变化
- **地区维度表**：相对稳定，可以不用拉链表

### 7.4 历史数据处理
- 初次加载时，所有记录的start_date设置为'1970-01-01'
- end_date设置为'9999-12-31'
- is_current设置为1

---

**文档版本**：v1.0  
**创建日期**：2024-01-15  
**维护人**：数据组


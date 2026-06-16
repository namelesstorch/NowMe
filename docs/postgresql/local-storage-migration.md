# 本地 `events` 到 PostgreSQL 迁移说明

当前快应用原型仍把核心数据存放在 `@system.storage` 的 `events` key 中。后续切换到 PostgreSQL 时，应按本文把旧结构拆分到新的 `events` 与 `transactions` 主链路中。

## 旧结构

当前本地单条记录大致如下：

```js
{
  id: '1710000000000',
  date: '2026-05-27',
  startHour: 8,
  startMinute: 0,
  endHour: 9,
  endMinute: 0,
  title: '开会',
  location: '办公室',
  amount: 25.5,
  category: '餐饮',
  color: '#2196F3',
  type: 'expense'
}
```

## 迁移目标

- 日程信息进入 `events`
- 交易流水进入 `transactions`
- 标签、预算、提醒、AI 上下文不从旧版本地数据强制推断
- 旧版 `amount/category` 仅作为迁移来源，不再长期保留在 `events`

## 字段映射

### 1. 日程映射

| 本地字段 | PostgreSQL 字段 | 说明 |
| --- | --- | --- |
| `id` | 迁移脚本中的 `legacy_event_id` | 仅作迁移映射，不直接保留到正式表 |
| `title` | `events.title` | 直接映射 |
| `location` | `events.location` | 直接映射 |
| `color` | `events.color` | 直接映射 |
| `date + startHour + startMinute` | `events.start_at` | 拼接为 `TIMESTAMPTZ` |
| `date + endHour + endMinute` | `events.end_at` | 拼接为 `TIMESTAMPTZ` |
| `type` | 不直接映射到 `events` | 旧版 `type` 主要用于记账 |

### 2. 全天日程规则

旧版本地结构没有显式 `allDay` 字段，迁移时默认按非全天日程处理：

- `all_day = false`
- `start_date/end_date = NULL`
- `start_at/end_at` 根据本地时间生成

若后续导入数据中存在“全天”标记，应改为：

- `all_day = true`
- `start_date/end_date` 赋值
- `start_at/end_at = NULL`

### 3. 交易映射

只有满足以下条件的旧记录才额外生成 `transactions`：

- `amount` 可解析为数字
- `amount > 0`

| 本地字段 | PostgreSQL 字段 | 说明 |
| --- | --- | --- |
| `amount` | `transactions.amount` | 支出或收入金额 |
| `type` | `transactions.type` | `income` 保留为收入，否则按 `expense` 处理 |
| `date + startHour + startMinute` | `transactions.occurred_at` | 默认取日程开始时间 |
| `title` | `transactions.description` | 作为描述回填 |
| `location` | `transactions.location` | 直接映射 |
| `category` | `transactions.category_id` | 先查找或创建分类，再关联 |

## 迁移步骤

1. 建立目标用户、偏好、财务总览与默认分类。
2. 将旧 `events` 数组导出为中间表 `staging_local_events`。
3. 先插入 `events`，为每条旧记录生成新的 `events.id`。
4. 对有金额的记录补建 `categories` 与 `transactions`。
5. 更新 `user_financial_profiles.current_balance`。
6. 按月或按日重算 `spending_summaries`。

## 迁移注意事项

- 旧版 `id` 是字符串时间戳，不建议直接进入正式主键。
- 旧版分类可能为空；空分类允许先写入 `transactions.category_id = NULL`。
- 同一条旧记录可能既代表一个日程，也代表一笔消费；迁移后会拆成两条主表记录并用 `transactions.event_id` 连接。
- 旧版本地记录没有 AI 来源，因此 `events.source_input_id` 与 `transactions.source_input_id` 默认置空。
- 旧版本地记录没有提醒规则，因此 `event_reminders` 由后续用户操作或后端补建。

## 迁移后验收

- 周视图能按 `events.start_at` 正常查询与展示
- 月度记账能按 `transactions.occurred_at` 与 `transactions.type` 正常聚合
- 同一条带金额的旧记录，应形成一条 `events` 和一条 `transactions`
- `user_financial_profiles.current_balance` 与历史流水结果一致
- `spending_summaries` 只是缓存，允许在迁移完成后重刷

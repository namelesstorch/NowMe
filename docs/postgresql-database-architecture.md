# 我在 PostgreSQL 数据库架构指导

本文档是“我在”项目数据库设计的最终总说明。目标不是立即替换快应用当前的本地原型，而是把数据库、迁移、后端契约和比赛答辩口径一次性固定下来，让后续开发能直接开工。

## 1. 项目定位

- PostgreSQL 是服务端数据中心，快应用前端不直接连库。
- 当前快应用继续使用 `@system.storage` 作为原型数据源，后续通过后端 API 迁移。
- 数据库设计按未来 `Node API + pg`、手机号登录、简单登录用户模式倒推。
- 数据层必须同时支撑四条主线：
  日程管理、记账管理、AI 输入与解析、个性化建议与习惯画像。

## 2. 本轮交付范围

### 交付内容

- 最终架构说明：
  本文件 [postgresql-database-architecture.md](./postgresql-database-architecture.md)
- 最终 ER Mermaid：
  [postgresql-er-diagram.mmd](./postgresql-er-diagram.mmd)
- 最终架构示意图：
  [postgresql-er-diagram.svg](./postgresql-er-diagram.svg)
- 数据字典：
  [postgresql/data-dictionary.md](./postgresql/data-dictionary.md)
- 本地迁移说明：
  [postgresql/local-storage-migration.md](./postgresql/local-storage-migration.md)
- SQL 设计包：
  [postgresql/README.md](./postgresql/README.md)

### 明确不做

- 多账户钱包
- 转账流水
- 多人分账
- 日程参与者
- 共享权限
- 前端切换到真实 API
- 后端服务代码实现

## 3. 设计结论

- `users.phone` 是第一版核心登录标识。
- 新增 `auth_verification_codes` 与 `user_sessions`，满足手机号验证码登录的数据库基础能力。
- 日程独立存储在 `events`，交易独立存储在 `transactions`。
- 若一个日程伴随消费或收入，只通过 `transactions.event_id` 做可选关联。
- 用户总金额统一保存在 `user_financial_profiles.current_balance`，不引入 `accounts`。
- 保留 `spending_summaries` 作为统计缓存表，不作为原始真相来源。
- 保留 AI 审计链：
  `ai_inputs -> ai_extractions -> events/transactions`
- 保留情境与习惯链：
  `context_snapshots -> user_habit_signals -> ai_context_packages -> ai_recommendation_feedback`

## 4. 领域模型

### 4.1 用户与认证

- `users`
- `auth_verification_codes`
- `user_sessions`
- `user_preferences`
- `user_financial_profiles`
- `notification_settings`

### 4.2 日程

- `events`
- `event_reminders`
- `event_tags`

### 4.3 记账

- `categories`
- `tags`
- `transactions`
- `transaction_tags`
- `budgets`
- `financial_goals`
- `spending_summaries`

### 4.4 AI 与上下文

- `ai_inputs`
- `ai_extractions`
- `ai_insights`
- `context_snapshots`
- `user_habit_signals`
- `ai_context_packages`
- `ai_recommendation_feedback`

## 5. 与旧设计相比的最终取舍

| 项目 | 最终方案 |
| --- | --- |
| 多账户钱包 | 删除，用 `user_financial_profiles.current_balance` 表示总金额 |
| 转账 `transfer` | 删除，`transactions.type` 仅保留 `income/expense` |
| 多人分账 | 删除 `transaction_splits` |
| 日程参与者 | 删除 `event_participants` |
| 标签体系 | 统一为 `tags + event_tags + transaction_tags` |
| 全天日程 | 采用 `all_day + start_date/end_date` |
| AI 上云 | 云端 Agent 不直接访问数据库，只接收脱敏上下文包 |
| 登录模式 | 第一版按手机号验证码登录建模 |

## 6. 认证与登录设计

### 登录模式

- `POST /auth/request-code`
- `POST /auth/verify-code`
- `POST /auth/logout`

### 核心设计

- `users.phone` 必填且唯一
- `auth_verification_codes` 记录验证码请求、用途、设备、IP、过期时间和核销状态
- `user_sessions` 保存会话 token 哈希、设备、版本、过期时间和撤销时间
- 不在数据库中保存短信验证码明文，只保存 `code_hash`

### 为什么这样设计

- 贴合移动端和比赛展示语境
- 后续接短信服务商时只需补后端发送与校验逻辑
- 既能支持新用户首次登录，也能支持老用户登录态续期与审计

## 7. 日程与记账主链路

### 事件模型

- `events` 用于承载日程与待办
- 支持两种时间表示：
  全天日程使用 `start_date/end_date`
  普通日程使用 `start_at/end_at`
- `event_type` 只保留 `schedule/todo`
- `event_reminders` 独立管理提醒，不把提醒作为事件类型

### 交易模型

- `transactions` 只保留 `income/expense`
- `amount` 必须大于 0
- `event_id` 可为空，用于“该消费是否和某个日程绑定”
- `category_id` 可为空，允许先记账后补分类

### 总金额维护规则

- 新增收入：
  `current_balance += amount`
- 新增支出：
  `current_balance -= amount`
- 修改交易：
  先撤销旧影响，再应用新影响
- 删除交易：
  软删除流水并撤销余额影响

这些操作必须放在同一个数据库事务中执行。

## 8. AI 与个性化建议链路

### AI 输入链

1. 用户输入文本、语音或图片，先写 `ai_inputs`
2. AI 结构化结果写 `ai_extractions`
3. 用户确认后再落 `events` 或 `transactions`
4. AI 建议与分析写 `ai_insights`

### 情境链

- `context_snapshots` 记录天气、时间段、周末/工作日、地点场景、活动场景等特征
- `user_habit_signals` 用于沉淀“在什么情境下通常会做什么”
- `ai_context_packages` 记录每次发往云端 Agent 的脱敏上下文摘要
- `ai_recommendation_feedback` 用于把用户反馈反哺到习惯信号

### 为什么必须保留这些表

因为比赛里的核心创新不是“会记账”或“会建日程”，而是：

- 一句话创建日程并预测支出
- 根据时间安排判断预算风险
- 在雨天、晚课后、某地点场景下提供个性化建议
- 从长期行为中形成用户生活节奏画像

这些能力都需要数据库保存结构化上下文与习惯证据，而不只是保存原始文本。

## 9. 软删除与一致性策略

### 软删除表

- `events`
- `transactions`
- `categories`
- `tags`
- `budgets`
- `financial_goals`
- `ai_insights`

### 追加审计表

- `auth_verification_codes`
- `user_sessions`
- `ai_inputs`
- `ai_extractions`
- `context_snapshots`
- `ai_context_packages`
- `ai_recommendation_feedback`

### 一致性原则

- `event_tags`、`transaction_tags`、`event_reminders` 使用复合外键，避免跨用户误关联
- `transactions.event_id` 与 `transactions.category_id` 保持单列外键，跨用户一致性由后端服务校验
- `spending_summaries` 允许重算，不得反向修改 `transactions`

## 10. SQL 设计包

SQL 设计包位于 [postgresql/README.md](./postgresql/README.md)，执行顺序如下：

1. `sql/001_extensions_and_types.sql`
2. `sql/002_core_tables.sql`
3. `sql/003_ai_and_context_tables.sql`
4. `sql/004_indexes.sql`
5. `sql/005_seed_demo_user.sql`
6. `sql/006_migrate_local_events.sql`

### 脚本职责

- `001`
  扩展与统一枚举值
- `002`
  用户、认证、日程、记账核心主表
- `003`
  AI 与上下文链路主表
- `004`
  索引、部分唯一索引与检索优化
- `005`
  演示用户与基础分类种子数据
- `006`
  旧版本地 `events` 迁移模板

## 11. 本地 `events` 到 PostgreSQL 的映射

旧前端本地 event 结构：

```js
{
  date,
  startHour,
  startMinute,
  endHour,
  endMinute,
  title,
  location,
  amount,
  category,
  color
}
```

迁移规则：

1. 每条旧记录都创建一条 `events`
2. `date + startHour/startMinute` 映射到 `events.start_at`
3. `date + endHour/endMinute` 映射到 `events.end_at`
4. `title/location/color` 直接映射
5. `amount > 0` 时，额外创建一条 `transactions`
6. `transactions.event_id` 指向刚创建的 `events.id`
7. `category` 先查找或创建 `categories`
8. 最后重算 `user_financial_profiles.current_balance` 与 `spending_summaries`

详细过程见 [postgresql/local-storage-migration.md](./postgresql/local-storage-migration.md)。

## 12. 未来 Node API 契约

### 认证

| 接口 | 作用 | 关键写表 |
| --- | --- | --- |
| `POST /auth/request-code` | 发送验证码 | `auth_verification_codes` |
| `POST /auth/verify-code` | 校验验证码并建立登录态 | `auth_verification_codes`、`user_sessions`、`users` |
| `POST /auth/logout` | 注销当前登录态 | `user_sessions` |

### 业务

| 接口 | 作用 | 关键读写表 |
| --- | --- | --- |
| `GET /api/events` | 周视图或月视图日程查询 | `events`, `event_reminders`, `event_tags` |
| `POST /api/events` | 创建日程 | `events`, `event_reminders`, `context_snapshots` |
| `PUT /api/events/:id` | 修改日程 | `events`, `event_reminders`, `context_snapshots` |
| `DELETE /api/events/:id` | 软删除日程 | `events` |
| `GET /api/transactions` | 账单列表或统计查询 | `transactions`, `categories`, `transaction_tags` |
| `POST /api/transactions` | 创建账单 | `transactions`, `user_financial_profiles`, `spending_summaries` |
| `PUT /api/transactions/:id` | 修改账单 | `transactions`, `user_financial_profiles`, `spending_summaries` |
| `DELETE /api/transactions/:id` | 软删除账单 | `transactions`, `user_financial_profiles`, `spending_summaries` |
| `GET /api/categories` | 分类列表 | `categories` |
| `GET /api/user/financial-profile` | 财务总览 | `user_financial_profiles` |
| `GET /api/spending-summaries` | 统计缓存 | `spending_summaries` |
| `POST /api/ai/inputs` | 提交 AI 输入 | `ai_inputs`, `ai_extractions` |
| `GET /api/ai/insights` | 获取 AI 建议 | `ai_insights` |
| `POST /api/ai/context-packages` | 记录上云上下文包 | `ai_context_packages` |
| `GET /api/ai/habit-signals` | 获取习惯证据 | `user_habit_signals` |
| `POST /api/ai/recommendation-feedback` | 提交用户反馈 | `ai_recommendation_feedback` |

## 13. 验收口径

### DDL

- 全量建表可按 001-005 一次执行成功
- 扩展、类型、表创建和索引脚本重复执行不会破坏现有结构

### 约束

- 非法时间区间不能进入 `events`
- 负金额不能进入 `transactions`
- 错误枚举值不能进入主表
- 重复手机号不能重复建用户
- 已软删除分类和标签允许以相同名称重建

### 查询

- 能支撑周视图日程查询
- 能支撑月度收支统计
- 能支撑提醒待发送任务
- 能支撑按天气/时间段/地点场景检索历史上下文
- 能支撑按习惯信号做个性化建议

### 比赛叙事

数据库层必须能解释以下四类场景：

1. 一句话创建日程并预计支出
2. 预算提醒
3. 雨天下午吃什么
4. 本周安排是否合理

## 14. 结论

这套 PostgreSQL 设计不是单独一张 ER 图，而是一份可直接交给后端实现的数据库交付包。它已经把范围、表结构、迁移、认证、AI 审计链、未来接口契约和比赛叙事统一到了同一个版本里。后续开发只需要在此基础上补 Node API 与前端联调，不需要再重画数据库边界。

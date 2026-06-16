# “我在” PostgreSQL 数据字典

本文档与 SQL 脚本保持一致，是后续 Node API、数据迁移、联调与答辩说明的字段权威来源。

## 1. 用户与认证

### `users`

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `id` | `UUID` | PK | 用户主键 |
| `username` | `VARCHAR(50)` | NOT NULL | 展示昵称 |
| `phone` | `VARCHAR(20)` | NOT NULL | 手机号，第一版核心登录标识 |
| `email` | `CITEXT` | NULL | 邮箱，可选 |
| `avatar_url` | `TEXT` | NULL | 头像地址 |
| `last_login_at` | `TIMESTAMPTZ` | NULL | 最近登录时间 |
| `created_at` | `TIMESTAMPTZ` | NOT NULL | 创建时间 |
| `updated_at` | `TIMESTAMPTZ` | NOT NULL | 更新时间 |

### `auth_verification_codes`

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `id` | `UUID` | PK | 验证码请求主键 |
| `user_id` | `UUID` | FK, NULL | 已存在用户时可回填 |
| `phone` | `VARCHAR(20)` | NOT NULL | 本次验证码对应手机号 |
| `purpose` | `verification_purpose_enum` | NOT NULL | `login/register/reset_phone` |
| `channel` | `verification_channel_enum` | NOT NULL | `sms/voice` |
| `code_hash` | `TEXT` | NOT NULL | 验证码哈希，不存明文 |
| `request_ip` | `INET` | NULL | 请求 IP |
| `device_id` | `VARCHAR(100)` | NULL | 请求设备标识 |
| `expires_at` | `TIMESTAMPTZ` | NOT NULL | 过期时间 |
| `consumed_at` | `TIMESTAMPTZ` | NULL | 核销时间 |
| `attempt_count` | `SMALLINT` | NOT NULL | 验证尝试次数 |
| `status` | `verification_code_status_enum` | NOT NULL | `pending/verified/expired/cancelled` |
| `created_at` | `TIMESTAMPTZ` | NOT NULL | 创建时间 |

### `user_sessions`

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `id` | `UUID` | PK | 会话主键 |
| `user_id` | `UUID` | FK | 所属用户 |
| `session_token_hash` | `TEXT` | NOT NULL | 登录态 token 哈希 |
| `device_id` | `VARCHAR(100)` | NULL | 设备标识 |
| `device_name` | `VARCHAR(100)` | NULL | 设备名称 |
| `client_platform` | `VARCHAR(30)` | NULL | `quickapp/android/web` 等 |
| `app_version` | `VARCHAR(30)` | NULL | 应用版本 |
| `login_ip` | `INET` | NULL | 登录 IP |
| `last_seen_at` | `TIMESTAMPTZ` | NULL | 最近活跃时间 |
| `expires_at` | `TIMESTAMPTZ` | NOT NULL | 过期时间 |
| `revoked_at` | `TIMESTAMPTZ` | NULL | 失效时间 |
| `created_at` | `TIMESTAMPTZ` | NOT NULL | 创建时间 |

### `user_preferences`

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `user_id` | `UUID` | PK, FK | 与用户一对一 |
| `currency` | `VARCHAR(10)` | NOT NULL | 默认币种 |
| `timezone` | `VARCHAR(50)` | NOT NULL | 默认时区 |
| `default_view` | `default_view_enum` | NOT NULL | `week/month/agenda` |
| `reminder_setting` | `JSONB` | NOT NULL | 默认提醒偏好 |
| `created_at` | `TIMESTAMPTZ` | NOT NULL | 创建时间 |
| `updated_at` | `TIMESTAMPTZ` | NOT NULL | 更新时间 |

### `user_financial_profiles`

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `user_id` | `UUID` | PK, FK | 与用户一对一 |
| `currency` | `VARCHAR(10)` | NOT NULL | 默认币种 |
| `initial_balance` | `NUMERIC(14,2)` | NOT NULL | 初始总金额 |
| `current_balance` | `NUMERIC(14,2)` | NOT NULL | 当前总金额快照 |
| `created_at` | `TIMESTAMPTZ` | NOT NULL | 创建时间 |
| `updated_at` | `TIMESTAMPTZ` | NOT NULL | 更新时间 |

### `notification_settings`

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `id` | `UUID` | PK | 通知设置主键 |
| `user_id` | `UUID` | FK | 所属用户 |
| `channel` | `notification_channel_enum` | NOT NULL | `push/email/sms/voice` |
| `quiet_start` | `TIME` | NULL | 免打扰开始时间 |
| `quiet_end` | `TIME` | NULL | 免打扰结束时间 |
| `enabled` | `BOOLEAN` | NOT NULL | 是否启用 |
| `created_at` | `TIMESTAMPTZ` | NOT NULL | 创建时间 |
| `updated_at` | `TIMESTAMPTZ` | NOT NULL | 更新时间 |

## 2. 日程域

### `events`

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `id` | `UUID` | PK | 日程主键 |
| `user_id` | `UUID` | FK | 所属用户 |
| `title` | `VARCHAR(200)` | NOT NULL | 标题 |
| `description` | `TEXT` | NULL | 描述 |
| `all_day` | `BOOLEAN` | NOT NULL | 是否全天 |
| `start_date` | `DATE` | NULL | 全天日程开始日期 |
| `end_date` | `DATE` | NULL | 全天日程结束日期 |
| `start_at` | `TIMESTAMPTZ` | NULL | 非全天开始时间 |
| `end_at` | `TIMESTAMPTZ` | NULL | 非全天结束时间 |
| `timezone` | `VARCHAR(50)` | NOT NULL | 日程时区 |
| `location` | `VARCHAR(255)` | NULL | 地点 |
| `event_type` | `event_type_enum` | NOT NULL | `schedule/todo` |
| `priority` | `event_priority_enum` | NOT NULL | `low/medium/high` |
| `status` | `event_status_enum` | NOT NULL | `active/completed/cancelled` |
| `color` | `VARCHAR(20)` | NULL | 前端展示色 |
| `is_recurring` | `BOOLEAN` | NOT NULL | 是否重复 |
| `recurrence_rule` | `JSONB` | NULL | 重复规则 |
| `source_input_id` | `UUID` | FK, NULL | 来源 AI 输入 |
| `created_at` | `TIMESTAMPTZ` | NOT NULL | 创建时间 |
| `updated_at` | `TIMESTAMPTZ` | NOT NULL | 更新时间 |
| `deleted_at` | `TIMESTAMPTZ` | NULL | 软删除时间 |

### `event_reminders`

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `id` | `UUID` | PK | 提醒主键 |
| `user_id` | `UUID` | FK | 所属用户 |
| `event_id` | `UUID` | FK | 所属日程 |
| `remind_at` | `TIMESTAMPTZ` | NOT NULL | 提醒时间 |
| `method` | `notification_channel_enum` | NOT NULL | 提醒方式 |
| `is_sent` | `BOOLEAN` | NOT NULL | 是否已发送 |
| `created_at` | `TIMESTAMPTZ` | NOT NULL | 创建时间 |

### `event_tags`

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `user_id` | `UUID` | FK | 所属用户 |
| `event_id` | `UUID` | PK, FK | 日程 ID |
| `tag_id` | `UUID` | PK, FK | 标签 ID |
| `created_at` | `TIMESTAMPTZ` | NOT NULL | 创建时间 |

## 3. 记账域

### `categories`

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `id` | `UUID` | PK | 分类主键 |
| `user_id` | `UUID` | FK | 所属用户 |
| `name` | `VARCHAR(50)` | NOT NULL | 分类名称 |
| `type` | `category_type_enum` | NOT NULL | `income/expense/both` |
| `parent_id` | `UUID` | FK, NULL | 父分类 |
| `icon` | `VARCHAR(50)` | NULL | 图标编码 |
| `color` | `VARCHAR(20)` | NULL | 展示色 |
| `created_at` | `TIMESTAMPTZ` | NOT NULL | 创建时间 |
| `updated_at` | `TIMESTAMPTZ` | NOT NULL | 更新时间 |
| `deleted_at` | `TIMESTAMPTZ` | NULL | 软删除时间 |

### `tags`

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `id` | `UUID` | PK | 标签主键 |
| `user_id` | `UUID` | FK | 所属用户 |
| `name` | `VARCHAR(50)` | NOT NULL | 标签名 |
| `color` | `VARCHAR(20)` | NULL | 展示色 |
| `created_at` | `TIMESTAMPTZ` | NOT NULL | 创建时间 |
| `updated_at` | `TIMESTAMPTZ` | NOT NULL | 更新时间 |
| `deleted_at` | `TIMESTAMPTZ` | NULL | 软删除时间 |

### `transactions`

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `id` | `UUID` | PK | 流水主键 |
| `user_id` | `UUID` | FK | 所属用户 |
| `event_id` | `UUID` | FK, NULL | 可选关联日程 |
| `category_id` | `UUID` | FK, NULL | 交易分类 |
| `type` | `transaction_type_enum` | NOT NULL | `income/expense` |
| `amount` | `NUMERIC(14,2)` | NOT NULL | 金额，必须大于 0 |
| `currency` | `VARCHAR(10)` | NOT NULL | 币种 |
| `description` | `TEXT` | NULL | 描述 |
| `occurred_at` | `TIMESTAMPTZ` | NOT NULL | 发生时间 |
| `payment_method` | `VARCHAR(30)` | NULL | 支付方式文本 |
| `location` | `VARCHAR(255)` | NULL | 地点 |
| `is_manual` | `BOOLEAN` | NOT NULL | 是否手动录入 |
| `source_input_id` | `UUID` | FK, NULL | 来源 AI 输入 |
| `created_at` | `TIMESTAMPTZ` | NOT NULL | 创建时间 |
| `updated_at` | `TIMESTAMPTZ` | NOT NULL | 更新时间 |
| `deleted_at` | `TIMESTAMPTZ` | NULL | 软删除时间 |

### `transaction_tags`

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `user_id` | `UUID` | FK | 所属用户 |
| `transaction_id` | `UUID` | PK, FK | 流水 ID |
| `tag_id` | `UUID` | PK, FK | 标签 ID |
| `created_at` | `TIMESTAMPTZ` | NOT NULL | 创建时间 |

### `budgets`

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `id` | `UUID` | PK | 预算主键 |
| `user_id` | `UUID` | FK | 所属用户 |
| `category_id` | `UUID` | FK, NULL | 预算分类，可为空表示总预算 |
| `period` | `budget_period_enum` | NOT NULL | `day/week/month/year` |
| `start_date` | `DATE` | NOT NULL | 预算周期开始日期 |
| `end_date` | `DATE` | NOT NULL | 预算周期结束日期 |
| `limit_amount` | `NUMERIC(14,2)` | NOT NULL | 预算上限 |
| `alert_threshold` | `NUMERIC(5,2)` | NOT NULL | 提醒阈值，0 到 1 |
| `created_at` | `TIMESTAMPTZ` | NOT NULL | 创建时间 |
| `updated_at` | `TIMESTAMPTZ` | NOT NULL | 更新时间 |
| `deleted_at` | `TIMESTAMPTZ` | NULL | 软删除时间 |

### `financial_goals`

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `id` | `UUID` | PK | 财务目标主键 |
| `user_id` | `UUID` | FK | 所属用户 |
| `name` | `VARCHAR(100)` | NOT NULL | 目标名称 |
| `target_amount` | `NUMERIC(14,2)` | NOT NULL | 目标金额 |
| `current_amount` | `NUMERIC(14,2)` | NOT NULL | 当前进度金额 |
| `start_date` | `DATE` | NULL | 开始日期 |
| `end_date` | `DATE` | NULL | 截止日期 |
| `status` | `goal_status_enum` | NOT NULL | `active/paused/achieved` |
| `created_at` | `TIMESTAMPTZ` | NOT NULL | 创建时间 |
| `updated_at` | `TIMESTAMPTZ` | NOT NULL | 更新时间 |
| `deleted_at` | `TIMESTAMPTZ` | NULL | 软删除时间 |

### `spending_summaries`

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `id` | `UUID` | PK | 缓存主键 |
| `user_id` | `UUID` | FK | 所属用户 |
| `period_type` | `spending_period_enum` | NOT NULL | `day/month/year` |
| `period_start` | `DATE` | NOT NULL | 统计开始日期 |
| `period_end` | `DATE` | NOT NULL | 统计结束日期 |
| `total_income` | `NUMERIC(14,2)` | NOT NULL | 收入总额 |
| `total_expense` | `NUMERIC(14,2)` | NOT NULL | 支出总额 |
| `balance` | `NUMERIC(14,2)` | NOT NULL | 收支差额 |
| `category_breakdown` | `JSONB` | NOT NULL | 分类统计明细 |
| `created_at` | `TIMESTAMPTZ` | NOT NULL | 创建时间 |
| `updated_at` | `TIMESTAMPTZ` | NOT NULL | 更新时间 |

## 4. AI 与上下文

### `ai_inputs`

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `id` | `UUID` | PK | AI 输入主键 |
| `user_id` | `UUID` | FK | 所属用户 |
| `input_type` | `ai_input_type_enum` | NOT NULL | `text/voice/image` |
| `content` | `TEXT` | NULL | 原始输入内容 |
| `raw_text` | `TEXT` | NULL | 识别后的纯文本 |
| `image_url` | `TEXT` | NULL | 图片地址或对象存储地址 |
| `recognized_json` | `JSONB` | NOT NULL | 多模态识别结果 |
| `created_at` | `TIMESTAMPTZ` | NOT NULL | 创建时间 |

### `ai_extractions`

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `id` | `UUID` | PK | 结构化解析主键 |
| `input_id` | `UUID` | FK | 来源 AI 输入 |
| `entity_type` | `ai_entity_type_enum` | NOT NULL | `event/transaction/task` |
| `parsed_data` | `JSONB` | NOT NULL | 结构化候选内容 |
| `confidence` | `NUMERIC(5,4)` | NULL | 置信度 |
| `created_at` | `TIMESTAMPTZ` | NOT NULL | 创建时间 |

### `ai_insights`

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `id` | `UUID` | PK | 洞察主键 |
| `user_id` | `UUID` | FK | 所属用户 |
| `insight_type` | `ai_insight_type_enum` | NOT NULL | `analysis/budget/advice/reminder` |
| `title` | `VARCHAR(200)` | NOT NULL | 标题 |
| `content` | `TEXT` | NOT NULL | 内容 |
| `related_data` | `JSONB` | NOT NULL | 关联摘要 |
| `is_read` | `BOOLEAN` | NOT NULL | 是否已读 |
| `created_at` | `TIMESTAMPTZ` | NOT NULL | 创建时间 |
| `deleted_at` | `TIMESTAMPTZ` | NULL | 软删除时间 |

### `context_snapshots`

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `id` | `UUID` | PK | 情境快照主键 |
| `user_id` | `UUID` | FK | 所属用户 |
| `source_type` | `context_source_type_enum` | NOT NULL | `event/transaction/ai_input/manual` |
| `event_id` | `UUID` | FK, NULL | 关联日程 |
| `transaction_id` | `UUID` | FK, NULL | 关联交易 |
| `input_id` | `UUID` | FK, NULL | 关联 AI 输入 |
| `occurred_at` | `TIMESTAMPTZ` | NOT NULL | 发生时间 |
| `date_local` | `DATE` | NOT NULL | 本地日期 |
| `timezone` | `VARCHAR(50)` | NOT NULL | 时区 |
| `day_of_week` | `SMALLINT` | NOT NULL | 1 到 7 |
| `is_weekend` | `BOOLEAN` | NOT NULL | 是否周末 |
| `time_bucket` | `time_bucket_enum` | NOT NULL | 时间段桶 |
| `weather_condition` | `weather_condition_enum` | NOT NULL | 天气桶 |
| `temperature_bucket` | `temperature_bucket_enum` | NOT NULL | 温度桶 |
| `location_text` | `VARCHAR(255)` | NULL | 原始地点 |
| `location_scene` | `VARCHAR(50)` | NULL | 场景标签 |
| `activity_scene` | `VARCHAR(50)` | NULL | 活动场景 |
| `mood` | `VARCHAR(30)` | NULL | 情绪或状态 |
| `features` | `JSONB` | NOT NULL | 额外特征 |
| `created_at` | `TIMESTAMPTZ` | NOT NULL | 创建时间 |

### `user_habit_signals`

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `id` | `UUID` | PK | 习惯信号主键 |
| `user_id` | `UUID` | FK | 所属用户 |
| `signal_type` | `habit_signal_type_enum` | NOT NULL | 习惯信号类型 |
| `subject_type` | `habit_subject_type_enum` | NOT NULL | 偏好对象类型 |
| `subject_value` | `VARCHAR(100)` | NOT NULL | 偏好对象值 |
| `context_filter` | `JSONB` | NOT NULL | 命中的情境过滤条件 |
| `evidence_count` | `INTEGER` | NOT NULL | 证据数量 |
| `confidence` | `NUMERIC(5,4)` | NOT NULL | 置信度 |
| `first_observed_at` | `TIMESTAMPTZ` | NULL | 首次出现时间 |
| `last_observed_at` | `TIMESTAMPTZ` | NULL | 最近出现时间 |
| `example_refs` | `JSONB` | NOT NULL | 少量证据引用 |
| `status` | `habit_signal_status_enum` | NOT NULL | `active/stale/rejected` |
| `created_at` | `TIMESTAMPTZ` | NOT NULL | 创建时间 |
| `updated_at` | `TIMESTAMPTZ` | NOT NULL | 更新时间 |

### `ai_context_packages`

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `id` | `UUID` | PK | 上下文包主键 |
| `user_id` | `UUID` | FK | 所属用户 |
| `input_id` | `UUID` | FK, NULL | 对应 AI 输入 |
| `package_type` | `ai_package_type_enum` | NOT NULL | `parse/recommendation/budget/schedule_summary/monthly_summary` |
| `context_keys` | `JSONB` | NOT NULL | 实际包含的上下文键 |
| `payload_summary` | `JSONB` | NOT NULL | 脱敏摘要 |
| `token_estimate` | `INTEGER` | NULL | 估算 token 数 |
| `privacy_level` | `privacy_level_enum` | NOT NULL | `minimal/standard/sensitive` |
| `created_at` | `TIMESTAMPTZ` | NOT NULL | 创建时间 |

### `ai_recommendation_feedback`

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `id` | `UUID` | PK | 反馈主键 |
| `user_id` | `UUID` | FK | 所属用户 |
| `insight_id` | `UUID` | FK | 对应 AI 洞察 |
| `feedback_type` | `feedback_type_enum` | NOT NULL | `accepted/dismissed/modified/negative` |
| `feedback_text` | `TEXT` | NULL | 用户说明 |
| `created_at` | `TIMESTAMPTZ` | NOT NULL | 创建时间 |

## 5. 软删除策略

- 软删除表：
  `events`、`transactions`、`categories`、`tags`、`budgets`、`financial_goals`、`ai_insights`
- 追加审计或桥接表：
  `auth_verification_codes`、`user_sessions`、`event_tags`、`transaction_tags`、`context_snapshots`、`ai_context_packages`、`ai_recommendation_feedback`
- 统计缓存：
  `spending_summaries` 允许重算重写，不作为原始数据真相来源。

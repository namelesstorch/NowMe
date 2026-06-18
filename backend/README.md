# NowMe Backend

这个目录是“我在”快应用的独立后端服务，只负责把快应用和 PostgreSQL 连起来。

## 作用范围

- 提供快应用可调用的 REST API。
- 复用 `../db/postgres/migrations` 初始化数据库。
- 维护 `events`、`transactions`、`categories`、`user_financial_profiles`、`spending_summaries`。
- 保留 AI 输入、洞察、上下文包、习惯信号、反馈等后端接口。

不包含：

- 快应用页面修改。
- 原有交互流程调整。
- 鉴权体系扩展。

## 启动

1. 复制 `.env.example` 为 `.env`，填好 `DATABASE_URL`。
2. 安装依赖：`npm install`
3. 执行迁移：`npm run migrate`
4. 启动服务：`npm run start`

## 默认单用户模式

为了适配当前原型阶段的快应用，本服务支持默认单用户模式：

- 若请求没有传 `x-user-id`，后端会使用 `.env` 中的 `DEFAULT_USER_ID`。
- 该用户不存在时会自动创建，并补齐 `user_preferences` 和 `user_financial_profiles`。

## 主要接口

- `GET /health`
- `GET|POST|PUT|DELETE /api/events`
- `GET|POST|PUT|DELETE /api/transactions`
- `GET|POST /api/categories`
- `GET|PUT /api/user/financial-profile`
- `GET /api/spending-summaries`
- `POST /api/ai/inputs`
- `GET /api/ai/insights`
- `POST /api/ai/context-packages`
- `GET /api/ai/habit-signals`
- `POST /api/ai/recommendation-feedback`

## 与当前快应用数据的兼容

`/api/events` 在返回结果里会补齐当前快应用使用的字段：

- `date`
- `startHour`
- `startMinute`
- `endHour`
- `endMinute`
- `amount`
- `category`

这样后续快应用把本地存储替换成接口调用时，不需要先改数据库结构认知。

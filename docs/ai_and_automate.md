# AI 与自动化任务记录

更新时间：2026-06-04 16:26

用途：记录本轮关于蓝心九问 Bot、数据库说明和模型调用策略的任务状态。若任务中断，新的对话可以先阅读本文件，再继续未完成项。

## 当前任务目标

让“我在”系统在后续只要接入数据库和后端 API 后，就具备可落地的 AI 解析、日程/记账结构化返回、预算预测、历史习惯建议和端云协同调用方案。

## 已阅读资料

- `PROJECT_CONTEXT.md`
- `README.md`
- `docs/blueheart-jiuwen-knowledge-base.md`
- `docs/ai-model-calling-strategy.md`
- `docs/postgresql-database-architecture.md`
- `docs/quickapp-knowledge-base.md`
- 用户提供的流程图截图：文本/语音输入 -> 云端 Agent 判断意图 -> 日程/记账结构化输出 -> 本地数据库保存 -> 历史记录与天气日期特征检索 -> 个性化建议

## 任务清单

| 编号 | 任务 | 状态 | 说明 |
| --- | --- | --- | --- |
| 1 | 创建并维护本任务记录文件 | 已完成 | 文件已创建，后续完成每个阶段时更新。 |
| 2 | 在 Chrome 已打开的蓝心九问工作台中配置流程编排 Bot | 已完成 | Bot 名称：`我在生活规划Agent`；ID：`2495`；模型：`通义千问-Plus`；发布渠道：API。 |
| 3 | 更新 PostgreSQL 数据库架构指导 | 已完成 | 已补充 `context_snapshots`、`user_habit_signals`、`ai_context_packages`、`ai_recommendation_feedback`。 |
| 4 | 改写端侧与云端 Agent 调用策略 | 已完成 | 已补充本地数据库上下文提取、脱敏、打包、调用、校验和回写方案。 |
| 5 | 优化云端 Agent 安全边界和回归测试 | 已完成 | 已升级 Bot 输出规则到 `wozai-ai-agent-v1.1`，并完成日程+记账、模糊日程、情境建议三类调试。 |
| 6 | 最终复核并交付 | 已完成 | 已检查标题编号、关键字段和 git 状态。`PROJECT_CONTEXT.md` 为本轮开始前已有改动。 |

## 当前设计方向

- 日程和记账原始数据仍以 `events`、`transactions` 为准。
- 用独立结构保存“记录发生时的情境特征”，例如天气、时间段、工作日/周末、地点场景、消费/日程场景。
- 用统计或证据表沉淀“用户在什么情境下倾向做什么”，避免每次建议都扫描全量原始记录。
- 云端蓝心九问 Agent 不直接访问数据库；调用端或后端先从本地/服务端数据库检索相关上下文，再脱敏打包给 Agent。
- Agent 输出必须是可校验 JSON；写入数据库前由本地或后端做 schema、时间、金额、预算等确定性校验。

## 蓝心九问 Bot 配置记录

- Bot 名称：`我在生活规划Agent`
- Bot ID：`2495`
- Bot 类型：流程编排
- 模型节点：`通义千问-Plus`
- 流程连线：开始节点 `query` -> 大模型节点 `query` -> 结束节点 `output`
- 结束节点回答内容：`{{output}}`
- API 发布状态：已发布，API 渠道已选中
- Base URL：`https://jiuwen.vivo.com.cn/v1`
- 调试输入：包含 `user_text`、`now`、`timezone`、`budget_snapshot`、`deterministic_checks` 的 JSON 包
- 当前输出协议：`wozai-ai-agent-v1.1`
- 调试结果：成功返回结构化 JSON；能识别创建日程和支出，能把 `2026-06-04T16:10:00+08:00` 的“明天下午三点”解析为 `2026-06-05T15:00:00+08:00`，并把候选金额 `80` 同步写入 `budgetPrediction.expectedTotal`
- 注意：调用端必须传 `now` 和 `timezone`。如果只传纯文本且包含相对日期，Bot 规则要求返回澄清，不应猜日期。

## 2026-06-04 云端 Agent 优化记录

已在蓝心九问工作台 Bot `2495` 中完成以下优化，并重新发布：

- 强化“候选优先”边界：云端 Agent 不直接写库，不输出“已保存、已创建、已删除、已扣款、已写入”等措辞；确认按钮也避免使用“保存、写入、创建、删除、扣款”等暗示数据库动作的词。
- 增加 `timeResolutionStatus`、`persistenceStatus`、`confirmationCard`、`agentMeta`，输出版本升级为 `wozai-ai-agent-v1.1`。
- 缺少写库必需字段时，只返回澄清问题，不输出可写库草案；例如“下周找一天去买东西”会返回 `needClarification=true`、`eventDrafts=[]`。
- 明确金额合计规则：只要 `eventDrafts.expectedAmount` 或 `transactionDrafts.amount` 有金额，`budgetPrediction.expectedTotal` 必须等于候选金额合计。
- 预算预测必须有 `budget_snapshot` 和 `deterministic_checks.budget_risk`，否则 `available=false`、`riskLevel=none`，不编造余额。
- 个性化建议必须引用 `habit_evidence`、`weather_context`、`temporal_context`、`budget_snapshot` 等证据；没有证据时不说“你通常/你经常/你偏好”。

本轮复测结果：

- 日程+记账：`明天下午三点去超市买露营用品，大概花80` -> 生成候选日程、候选支出，`expectedTotal=80`，预算风险为 `low`。
- 模糊日程：`下周找一天去买东西` -> 返回澄清问题，`eventDrafts=[]`、`transactionDrafts=[]`，按钮为“补充信息”。
- 情境建议：`今天下午下雨，吃点什么好？` + 雨天/下午/习惯证据 -> 返回热汤面等建议，并在 `personalizedAdvice.evidence` 中列出依据。

## 待接手提示

如果中断后继续：

1. 先查看本文件的任务清单状态。
2. 再查看 `docs/postgresql-database-architecture.md` 和 `docs/ai-model-calling-strategy.md` 的最新修改。
3. 若需要继续调整蓝心九问 Bot，使用 Chrome 控制能力进入工作台，打开 Bot `2495`，按本文和模型策略文档中的 Bot 规则继续配置。
4. 后续写代码时，优先实现 `contextPackager`、`aiRouter`、云端返回 schema 校验和确认卡片，不要让云端输出直接写库。

# 端侧与云端 Agent 调用策略

更新时间：2026-06-05

用途：这份文档用于指导后续把 `src/components/AIAssistant.ux` 从本地 mock 逻辑改造成真实 AI 调用逻辑。后续实现时，应优先按本文拆分端侧蓝心 3B 纯文本/多模态模型、云端蓝心九问 Agent、第三方云能力和本地规则代码的职责。

## 1. 项目 AI 定位

本项目“我在”的 AI 能力不应定位为单纯聊天助手，也不应把所有任务都交给云端大模型处理。推荐定位为：

> 面向年轻用户的端云协同生活决策助手，在安排事情之前，帮助用户同时看见时间冲突、预算压力和生活节奏影响。

核心思路：

- 端侧模型负责快速、低成本、隐私友好的文本理解和轻量图文理解。
- 本地规则负责准确、可验证的时间和金额计算。
- 云端 Agent 负责复杂、多轮、需要解释和建议的任务。
- 第三方云能力只作为专项增强或兜底，不作为默认主路径。

## 2. 可用能力分层

### 2.1 端侧蓝心 3B 模型

主办方 2026-06-05 文档更新后，端侧 3B 蓝心模型不再只按文本模型理解。当前应按两个模式拆分：

- 纯文本模式：`BlueLM_3B`。
- 多模态模式：`BlueLM_V_3B`，通过 `multimodal=true` 初始化，支持图文理解。

适合任务：

- 短文本意图识别。
- 日期、时间、标题、地点、金额、类别等信息抽取。
- 消费类别、日程类型分类。
- 活动海报、课程表截图、小票/支付截图、聊天截图等轻量图像理解。
- 图片中的标题、日期、地点、总金额、商家、类别等候选字段提取。
- 用户输入脱敏、摘要和云端调用前的上下文压缩。
- 低延迟确认卡片生成。
- 云端不可用时的基础兜底。

不适合任务：

- 长上下文多轮规划。
- 复杂预算和时间推理。
- 原始语音识别。
- 高精度票据 OCR、复杂表格、长文档、多图批处理。
- 需要调用外部工具或知识库的任务。

实现原则：

- 端侧 3B 输出必须尽量结构化，不能只返回自然语言。
- 端侧抽取结果必须经过本地规则校验后才能写入日程或账本。
- 如果端侧结果置信度低，应进入澄清或云端 Agent 流程。
- 图片输入优先走端侧多模态；如图像质量差、字段缺失、金额不确定，再进入云端或专项 OCR 兜底。
- 多模态模式需要先 `init(multimodal=true)`，再 `callVit()` 编码图片，最后使用带 `<im_start><image><im_end>` 标记的 prompt 调用 `generate()`。
- 当前快应用不能假设可直接调用 Android AAR/native SDK；实现时应先通过 native bridge、独立 native demo 或服务封装暴露统一接口。
- SDK 参数、运行环境和调用模板详见 `docs/blueheart-edge-3b-multimodal-knowledge-base.md`。

### 2.2 蓝心九问云端 Agent

适合任务：

- 多轮对话和模糊信息追问。
- 多事件拆分和复杂自然语言理解。
- 周报、月报、生活节奏总结。
- 预算压力解释和行动建议。
- 接入知识库、工作流、插件或后端工具。
- 根据用户历史摘要生成个性化建议。

不适合任务：

- 直接承担金额汇总、时间冲突判断等确定性计算。
- 高频、低价值、可在端侧完成的短文本解析。
- 在没有脱敏和授权的情况下处理完整隐私数据。

Agent 类型建议：

- 流程编排型 Bot：用于固定流程，例如“解析输入 -> 查询日程 -> 检测预算 -> 生成建议”。
- 自主规划型 Bot：用于开放式对话，例如“帮我看看这周安排是否合理”。

实现原则：

- 快应用前端不应直接保存蓝心九问 API Key。
- 推荐通过自有后端代理调用云端 Agent。
- 上传云端的数据应最小化，只传任务所需字段或摘要。
- 云端输出必须经过本地 schema 校验和业务规则校验。

### 2.3 第三方云模型或专项服务

适合任务：

- 高精度图片小票 OCR。
- 复杂多图、多页文档、多表格理解。
- 复杂长文本报告。
- 蓝心九问不可用时的云端兜底。
- 某些模型在 JSON、函数调用、长上下文或视觉识别上有明显优势时的专项调用。

不适合作为：

- 默认聊天入口。
- 项目核心卖点。
- 端侧和蓝心云端能力的替代品。

实现原则：

- 第三方能力应做成可插拔接口。
- 比赛展示时优先强调 vivo 端云协同能力。
- 端侧多模态已覆盖的轻量图片理解任务，不再默认交给第三方。
- 只有在端侧多模态或蓝心云端能力覆盖不足时，再说明第三方模型作为增强方案。

### 2.4 本地规则与业务代码

必须由本地规则完成的任务：

- 日期合法性校验。
- 开始时间和结束时间校验。
- 时间冲突检测。
- 预算余额计算。
- 月度、周度、类别消费汇总。
- 日程和账单写入、更新、删除。
- API 返回结构校验。
- 用户确认前的数据暂存。

原则：

- 大模型可以理解和解释，但不能作为金额与时间计算的最终依据。
- 所有写入本地存储的数据都要经过确定性校验。
- 所有 AI 结果都应先进入确认状态，再由用户或规则确认落库。

## 3. 调用路由总原则

推荐调用顺序：

1. 本地规则先做轻量预处理，例如去空格、长度限制、基础日期识别。
2. 判断输入模态：纯文本走端侧 3B 纯文本模式；图片 + 文本走端侧 3B 多模态模式。
3. 端侧 3B 先解析用户输入，产出结构化候选结果。
4. 本地规则校验候选结果，并计算冲突、预算、统计等确定性结果。
5. 如果结果完整且置信度足够，展示确认卡片。
6. 如果信息缺失、低置信度、多意图、图片解析不可靠或用户要求建议，再调用云端 Agent/专项 OCR 兜底。
7. 云端 Agent 返回建议或澄清问题后，仍需本地校验，再展示给用户。

默认策略：

- 能本地完成的，不上云。
- 能端侧完成的，不调用云端 Agent。
- 能用规则算清楚的，不让模型自由判断。
- 能端侧多模态处理的轻量图片，不默认交给第三方 OCR。
- 需要自然语言解释、复杂规划和多轮对话时，再调用云端 Agent。

## 4. 云端调用触发条件

满足以下任一条件时，可以考虑调用云端 Agent：

- 端侧 3B 抽取置信度低。
- 端侧多模态图像解析置信度低，或关键字段缺失。
- 用户输入包含多个事件或跨天安排。
- 用户表达中有明显模糊信息，需要追问。
- 用户要求“帮我安排”“帮我优化”“看看是否合理”“给我建议”。
- 需要结合一周或一个月的历史日程和消费。
- 需要生成总结、报告、解释性文本。
- 本地检测到时间冲突或预算超支，需要生成替代方案。
- 小票、课程表、海报等图片需要跨多条历史数据解释或生成复杂建议。
- 用户主动选择“云端深度分析”。

不应调用云端 Agent 的情况：

- 只是在当前日程中改标题、改金额、改类别。
- 只需要计算本月总支出。
- 只需要判断两个时间段是否重叠。
- 输入文本很短且端侧 3B 已高置信度解析完成。
- 图片输入清晰、字段完整，且端侧多模态已生成可确认候选卡片。
- 用户关闭云端分析或处于离线模式。

## 5. 推荐功能分配表

| 功能 | 首选处理方 | 备用处理方 | 说明 |
| --- | --- | --- | --- |
| 一句话创建日程 | 端侧 3B | 云端 Agent | 端侧先抽取字段，复杂输入再上云。 |
| 日期和时间标准化 | 本地规则 | 端侧 3B | 规则负责最终格式，例如 `YYYY-MM-DD`。 |
| 多事件拆分 | 云端 Agent | 端侧 3B | 简单并列句可端侧处理，复杂表达上云。 |
| 消费金额识别 | 端侧 3B | 本地规则 | 金额写入前必须转成数字并校验。 |
| 消费类别分类 | 端侧 3B | 云端 Agent | 常见类别端侧处理，陌生场景上云。 |
| 时间冲突检测 | 本地规则 | 无 | 不交给模型做最终判断。 |
| 预算超支检测 | 本地规则 | 无 | 金额和预算必须由代码计算。 |
| 冲突解释和调整建议 | 云端 Agent | 端侧 3B | 有上下文时云端更适合。 |
| 周报和月报 | 本地规则 + 云端 Agent | 端侧 3B | 本地先聚合数据，云端负责表达和建议。 |
| 隐私脱敏 | 本地规则 + 端侧 3B | 无 | 上云前必须处理。 |
| 语音输入 | ASR 能力 + 端侧 3B | 云端 Agent | 语音先转文字，再进入文本解析。 |
| 小票/支付截图轻量识别 | 端侧 3B 多模态 + 本地规则 | 云端 Agent 或专项 OCR | 端侧先识别商家、总金额、时间、类别；复杂票据再兜底。 |
| 活动海报识别 | 端侧 3B 多模态 | 云端 Agent | 提取标题、时间、地点、费用，生成候选日程。 |
| 课程表/值班表截图识别 | 端侧 3B 多模态 | 云端 Agent 或专项 OCR | 单图优先端侧，多行多列复杂表格可上云复核。 |
| 聊天截图计划识别 | 端侧 3B 多模态 | 云端 Agent | 优先只在端侧处理隐私截图，必要时只上传脱敏摘要。 |
| UI 截图理解 | 端侧 3B 多模态 | 无或云端 Agent | 用于解释当前页面状态，不直接执行操作。 |
| App 使用帮助问答 | 云端 Agent + 知识库 | 端侧 3B | 可挂载项目说明和 FAQ。 |

## 6. 推荐数据流

### 6.1 创建日程

用户输入：

```text
明天下午三点去超市买露营用品，大概花 80
```

处理流程：

1. 本地规则做输入长度和敏感词初筛。
2. 端侧 3B 抽取结构化结果。
3. 本地规则标准化日期和时间。
4. 本地规则检测时间冲突和预算状态。
5. 展示确认卡片。
6. 用户确认后写入 `events`。
7. 如有冲突或超预算，可调用云端 Agent 生成调整建议。

### 6.2 获取智能建议

用户输入：

```text
帮我看看这周安排是否合理
```

处理流程：

1. 本地读取本周日程和消费。
2. 本地聚合关键指标，例如忙碌天数、冲突数、预计消费、预算剩余。
3. 本地脱敏和压缩上下文。
4. 调用云端 Agent 生成建议。
5. 本地检查返回结构。
6. 展示建议，必要时提供可执行操作，例如“调整时间”“降低预算”“保持原计划”。

### 6.3 记账和预算提醒

处理流程：

1. 创建日程时记录预计消费。
2. 本地预算规则判断是否超支。
3. 日程结束后提醒用户确认实际消费。
4. 实际消费写入后，本地更新统计。
5. 周报或月报时调用云端 Agent 生成解释。

### 6.4 图片输入

用户输入：

```text
选择一张活动海报 / 小票 / 课程表截图，并补充一句“帮我加入日程”或“帮我记账”
```

处理流程：

1. 快应用端选择图片，并生成本地临时图片引用。
2. 如果已接入 native bridge，将图片转为 RGB 三通道数据。
3. 端侧 3B 多模态使用 `init(multimodal=true)` 初始化。
4. 调用 `callVit(rgbData, width, height)` 完成图像编码。
5. 使用带 `<im_start><image><im_end>` 标记的 prompt 调用 `generate()`。
6. 端侧模型输出结构化候选字段，例如标题、日期、时间、地点、商家、总金额、类别。
7. 本地规则校验日期、金额、时间区间和预算。
8. 展示确认卡片，用户确认后才写入 `events` 或交易数据。
9. 如果端侧识别低置信度、图片质量差、字段缺失或需要复杂建议，再调用云端 Agent 或专项 OCR。

图片场景要求：

- 原始图片默认只在端侧处理。
- 如需云端复核，优先上传端侧提取后的脱敏摘要，而不是原图。
- 小票金额、课程表时间和活动费用必须由用户确认后才能落库。
- 端侧多模态结果应保留 `visionEvidence`，标记哪些字段来自图片文字，哪些只是模型推测。

## 7. 本地上下文检索与云端打包方案

对于需要“基于过往记录”的云端任务，不能让云端 Agent 自己猜数据库内容，也不应把全量历史记录直接发给云端。推荐方案是：

> 端侧或后端先解析意图和情境，再从本地/服务端数据库检索相关上下文，脱敏压缩成上下文包，最后调用蓝心九问流程 Bot。

### 7.1 调用侧职责

调用侧应负责：

- 写入 `ai_inputs`，保留用户本次输入来源。
- 标准化 `now`、`timezone`、本地日期、工作日/周末、时间段。
- 获取天气、节假日、当前位置场景等可验证情境。
- 从数据库读取日程、交易、预算、统计缓存和习惯信号。
- 做时间冲突、预算余额、分类汇总等确定性计算。
- 上云前脱敏和压缩。
- 将上下文包摘要写入 `ai_context_packages`。
- 校验云端 JSON，必要时写入 `ai_extractions` 和 `ai_insights`。

云端 Agent 负责：

- 复杂自然语言理解。
- 多意图拆分。
- 生成候选日程、候选交易、澄清问题。
- 解释预算压力。
- 基于调用侧提供的 `habit_evidence` 生成建议。
- 输出稳定 JSON 和简短用户可读文案。

### 7.2 上下文包格式

后端调用蓝心九问 Bot 时，建议把以下 JSON 序列化为字符串，作为流程 Bot 的 `query` 传入。

```json
{
  "user_text": "明天下午三点去超市买露营用品，大概花80",
  "now": "2026-06-04T15:50:00+08:00",
  "timezone": "Asia/Kuala_Lumpur",
  "locale": "zh-CN",
  "request_intent_hint": "create_event",
  "weather_context": {
    "condition": "rainy",
    "temperature_bucket": "warm",
    "source": "backend_weather_api"
  },
  "temporal_context": {
    "date_local": "2026-06-04",
    "day_of_week": 4,
    "is_weekend": false,
    "time_bucket": "afternoon"
  },
  "schedule_snapshot": {
    "range": "2026-06-04/2026-06-11",
    "events": [],
    "conflicts": []
  },
  "budget_snapshot": {
    "currency": "CNY",
    "monthly_remaining": 1200,
    "category_remaining": {
      "购物": 300
    }
  },
  "habit_evidence": [
    {
      "signal_type": "food_preference",
      "subject_value": "热汤面",
      "context_filter": {
        "weather_condition": "rainy",
        "time_bucket": "afternoon",
        "is_weekend": false
      },
      "evidence_count": 5,
      "confidence": 0.78
    }
  ],
  "deterministic_checks": {
    "schedule_conflicts": [],
    "budget_risk": "low"
  },
  "privacy": {
    "redacted": true,
    "sent_precise_location": false,
    "max_records_sent": 20
  }
}
```

必要字段：

- `user_text`
- `now`
- `timezone`

包含相对日期时必须传 `now` 和 `timezone`。如果缺失，云端 Bot 已配置为不得猜测具体日期，应返回澄清。

### 7.3 检索策略

创建日程或记账：

- 查询目标日期附近 1-7 天日程，供冲突检查和建议解释。
- 查询当前月预算、相关类别预算和当前余额。
- 如果输入含金额或消费场景，查询同类最近消费摘要。
- 如果输入含地点或活动场景，查询匹配 `context_snapshots` 的少量历史摘要。

询问建议：

- 先标准化当前情境，例如 `weather_condition=rainy`、`time_bucket=afternoon`、`is_weekend=false`。
- 优先查 `user_habit_signals`，获取高置信度习惯证据。
- 信号不足时，再查最近 30-90 天 `context_snapshots` 关联的日程和交易。
- 只发送摘要、计数、类别、场景和少量脱敏例子，不发送全量明细。

周报/月报：

- 本地先从 `events`、`transactions`、`spending_summaries` 聚合统计。
- 云端只接收统计摘要、异常点和少量代表性记录。
- 云端生成解释和建议，本地保留最终确认与展示。

### 7.4 推荐实现流程

```text
用户输入
-> 保存 ai_inputs
-> 端侧 3B 或本地规则做意图和情境粗解析
-> 后端读取数据库上下文
-> 本地规则计算冲突、预算、统计
-> 生成脱敏上下文包
-> 写入 ai_context_packages 摘要
-> 调用蓝心九问 Bot
-> 校验云端 JSON
-> 写入 ai_extractions / ai_insights
-> 前端展示确认卡片或建议
-> 用户确认后写入 events / transactions
```

### 7.5 蓝心九问 Bot 配置

本轮已在蓝心九问工作台配置流程编排 Bot：

- Bot 名称：`我在生活规划Agent`
- Bot ID：`2495`
- 模型：`通义千问-Plus`
- 发布渠道：API
- Base URL：`https://jiuwen.vivo.com.cn/v1`
- 流程：开始 `query` -> 大模型 `query` -> 结束 `output`
- 输出：结束节点回答内容为 `{{output}}`
- 当前输出协议：`wozai-ai-agent-v1.1`

调用时仍要通过自有后端代理，不要在快应用前端保存 API Key。

## 8. 结构化返回建议

端侧 3B 和云端 Agent 都应尽量返回可校验结构。后续实现时，可约定以下字段：

```json
{
  "intent": "create_event",
  "confidence": 0.86,
  "needClarification": false,
  "clarificationQuestion": "",
  "inputModalities": ["text"],
  "timeResolutionStatus": "exact",
  "persistenceStatus": "candidate_only",
  "detectedContext": {
    "timeHints": ["明天下午三点"],
    "weatherHints": [],
    "sceneHints": ["购物"],
    "locationHints": ["超市"],
    "moodHints": []
  },
  "visionEvidence": {
    "available": false,
    "imageType": "",
    "recognizedText": [],
    "fieldEvidence": [],
    "uncertainFields": []
  },
  "eventDrafts": [
    {
      "clientTempId": "evt_1",
      "title": "买露营用品",
      "description": "",
      "allDay": false,
      "startAt": "2026-06-05T15:00:00+08:00",
      "endAt": "2026-06-05T16:00:00+08:00",
      "startDate": "2026-06-05",
      "endDate": "2026-06-05",
      "timezone": "Asia/Kuala_Lumpur",
      "location": "超市",
      "eventType": "schedule",
      "priority": "medium",
      "expectedAmount": 80,
      "categoryName": "购物",
      "contextFeatures": {}
    }
  ],
  "transactionDrafts": [
    {
      "clientTempId": "txn_1",
      "relatedEventClientTempId": "evt_1",
      "type": "expense",
      "amount": 80,
      "currency": "CNY",
      "description": "露营用品采购",
      "occurredAt": "2026-06-05T15:30:00+08:00",
      "categoryName": "购物",
      "paymentMethod": "",
      "location": "超市",
      "contextFeatures": {}
    }
  ],
  "budgetPrediction": {
    "available": true,
    "expectedTotal": 80,
    "budgetRemaining": 1120,
    "riskLevel": "low",
    "reason": "预算充足",
    "alternatives": []
  },
  "retrievalPlan": {
    "needed": [],
    "usedContextKeys": ["budget_snapshot", "deterministic_checks"],
    "suggestedFilters": []
  },
  "personalizedAdvice": {
    "summary": "",
    "evidence": [],
    "suggestions": []
  },
  "confirmationCard": {
    "title": "已生成候选日程和账目",
    "subtitle": "明日15:00超市采购，预计80元",
    "primaryActionLabel": "确认候选信息",
    "editableFields": ["location", "paymentMethod"]
  },
  "userFacingMessage": "已生成候选日程和预计支出，请确认候选信息。",
  "warnings": [],
  "agentMeta": {
    "agentId": "2495",
    "agentName": "我在生活规划Agent",
    "modelHint": "通义千问-Plus"
  },
  "schemaVersion": "wozai-ai-agent-v1.1"
}
```

字段要求：

- `intent` 必须来自预定义枚举。
- `confidence` 取值范围为 `0` 到 `1`。
- `persistenceStatus` 固定为 `candidate_only`；云端结果永远不是已落库结果。
- `inputModalities` 用于标记输入来源，建议取值为 `text`、`image`、`voice_transcript`；图片输入必须包含 `image`。
- `timeResolutionStatus` 用于标记时间解析状态，取值建议为 `exact`、`partial`、`ambiguous`、`missing_context`、`not_applicable`。
- 图片输入必须返回 `visionEvidence`；其中 `fieldEvidence` 标明字段来源，`uncertainFields` 标明模型无法确认的字段。
- `needClarification` 为 `true` 且缺少写库必需字段时，不应输出可写库草案；`eventDrafts` 和 `transactionDrafts` 应为空数组。
- `eventDrafts` 和 `transactionDrafts` 可以为空数组，但不能缺失。
- 金额字段必须是数字或 `null`。
- 只要 `eventDrafts.expectedAmount` 或 `transactionDrafts.amount` 出现明确金额，`budgetPrediction.expectedTotal` 必须等于候选金额合计；没有明确金额时才允许为 `null`。
- 日期和时间必须由本地规则二次校验。
- 云端输出中的预算、冲突和统计解释必须和本地 `deterministic_checks` 对齐。
- `budgetPrediction.available=true` 必须有 `budget_snapshot` 和 `deterministic_checks.budget_risk`，或有可由本地上下文确定计算的预算余额；否则应为 `false`，`riskLevel` 为 `none`。
- 个性化建议必须有 `personalizedAdvice.evidence`；没有证据时，不应使用“你通常”“你经常”“你偏好”等历史习惯表述。
- `confirmationCard.primaryActionLabel` 不应使用“保存、写入、创建、删除、扣款”等暗示云端已能操作数据库的词，建议使用“确认候选信息”“补充信息”“查看建议”“采纳建议”。
- `userFacingMessage` 不能说“已保存、已创建、已删除、已扣款、已写入”；只能表达“候选记录/待确认/需补充信息”。

## 9. 建议意图枚举

后续实现模型路由时，可先支持以下意图：

- `create_event`：创建日程。
- `create_event_from_image`：从海报、课程表、聊天截图等图片创建候选日程。
- `update_event`：修改日程。
- `delete_event`：删除日程。
- `query_schedule`：查询日程。
- `create_transaction`：创建收入或支出记录。
- `create_transaction_from_image`：从小票、支付截图等图片创建候选账目。
- `query_transaction`：查询账目记录。
- `analyze_schedule`：分析日程安排。
- `analyze_budget`：分析预算。
- `recommendation`：基于情境和历史习惯给出建议。
- `weekly_summary`：生成周总结。
- `monthly_summary`：生成月总结。
- `small_talk`：普通对话。
- `unknown`：无法识别。

## 10. 置信度和兜底策略

推荐阈值：

- `confidence >= 0.8`：可展示确认卡片。
- `0.5 <= confidence < 0.8`：展示结果，但标记需要用户重点确认，或调用云端 Agent 复核。
- `confidence < 0.5`：不生成日程，改为追问用户。

兜底顺序：

1. 端侧 3B 纯文本失败时，尝试本地规则解析常见表达。
2. 端侧 3B 多模态失败时，提示用户重拍/裁剪图片，或补充文字说明。
3. 本地规则仍不完整时，询问用户缺失字段。
4. 用户选择深度分析、输入复杂或图片识别低置信度时，调用云端 Agent 或专项 OCR。
5. 云端 Agent 失败时，提示用户稍后重试，并保留当前输入草稿和本地候选结果。

## 11. 隐私和安全策略

必须遵守：

- API Key 不写入快应用前端代码。
- 云端调用通过后端代理完成。
- 不在日志中记录完整用户输入、API Key、精确地点、完整账单明细。
- 不在日志中记录原始图片、完整小票、完整聊天截图。
- 上云前优先做脱敏，例如把姓名替换为“联系人 A”，把精确地点压缩为场景类别。
- 图片输入优先在端侧多模态处理；如需云端复核，默认只发送端侧抽取后的摘要和字段置信度。
- 用户关闭云端分析时，只使用端侧和本地规则。
- 云端返回内容只作为建议，不直接执行删除、修改、支付等高影响操作。

高风险操作：

- 删除日程。
- 批量修改日程。
- 覆盖实际消费。
- 基于预算给出强制性判断。
- 从图片中识别出的账单、课程表或海报信息直接落库。

这些操作必须有用户确认。

## 12. 后续实现建议

建议按以下顺序落地：

1. 建立统一 `aiRouter`，输入用户文本、`now`、`timezone` 和可用上下文，输出结构化结果。
2. 接入端侧 3B 的短文本解析，用于意图、实体和情境粗抽取。
3. 抽象端侧多模态接口，用于活动海报、课程表、小票和聊天截图的候选字段抽取。
4. 增加本地 schema 校验、时间校验、金额校验和图片字段置信度校验。
5. 将原来的自动添加改成确认卡片。
6. 接入本地冲突检测、预算检测和上下文包生成。
7. 通过后端代理调用蓝心九问 Bot `2495`，用于复杂建议、多轮追问和历史习惯解释。
8. 将云端返回写入 `ai_extractions` / `ai_insights`，用户确认后再写入 `events` / `transactions`。
9. 增加上云前脱敏、`ai_context_packages` 审计、图片临时文件清理和云端失败兜底。
10. 预留第三方 OCR 或多模态接口，用于端侧多模态覆盖不足的高精度票据和复杂文档。

## 13. 和当前代码的关系

当前 `src/components/AIAssistant.ux` 中的 `mockExtractEvent()` 只是演示规则解析。后续替换时建议：

- 不直接在组件里写完整模型调用逻辑。
- 将模型路由、请求封装、schema 校验放到 helper 层。
- 组件只负责输入、展示消息、展示确认卡片和触发保存。
- `Calendar.ux` 和 `Accounting.ux` 继续依赖经过校验后的本地数据。
- 图片多模态 SDK 是 Android native/AAR 形态；当前快应用需要先确认 native bridge、独立 native demo 或服务封装接入方式。

可优先新增的逻辑模块：

- `aiRouter`：判断走端侧、云端还是本地规则。
- `edgeTextService`：端侧纯文本推理封装。
- `edgeVisionService`：端侧多模态图文理解封装。
- `imagePreprocessor`：图片解码、裁剪、RGB 数据转换和临时文件清理。
- `eventExtractor`：统一日程字段抽取。
- `receiptExtractor`：统一小票/支付截图候选账单抽取。
- `privacySanitizer`：上云前脱敏。
- `eventValidator`：日期、时间、金额和类别校验。
- `contextPackager`：从数据库检索日程、交易、预算、情境快照和习惯信号，生成云端上下文包。
- `adviceService`：云端建议和总结生成。

## 14. 参考资料

- `docs/blueheart-jiuwen-knowledge-base.md`：蓝心九问平台、Bot、工具、工作流、知识库、API 和安全注意事项。
- `docs/blueheart-edge-3b-multimodal-knowledge-base.md`：端侧蓝心 3B 纯文本/多模态 SDK、调用流程和比赛接入注意事项。
- `PROJECT_CONTEXT.md`：当前项目结构、核心数据结构和现有 AI mock 逻辑说明。
- vivo 蓝心大模型开放平台：https://developers.vivo.com/product/ai/bluelm
- 蓝心智能体平台文档：https://agents.vivo.com.cn/documents/gpts?id=1778
- 主办方端侧 3B 模型文档：https://aigc.vivo.com.cn/#/document/index?id=1802
- Hugging Face Paper：BlueLM-2.5-3B Technical Report：https://huggingface.co/papers/2507.05934
- arXiv：BlueLM-2.5-3B Technical Report：https://arxiv.org/abs/2507.05934

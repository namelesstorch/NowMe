# 项目上下文说明

更新时间：2026-05-27

用途：这份文档用于在新的对话窗口、交接给其他开发者或让 AI 快速接手时，快速理解当前项目。建议新窗口先阅读本文件，再按需查看 `src/pages`、`src/components` 和 `docs` 下的细节资料。

## 1. 项目一句话概览

这是一个基于快应用的智能日程应用，应用名为“我在”，包名为 `com.example.smartcalendar`。当前核心能力是：

- 周视图日程管理。
- 在日程中记录金额，并自动汇总为记账本。
- 一个本地模拟版 AI 助手，用规则从自然语言中提取日程，并检查时间冲突。

当前项目更像原型或课程/比赛演示版本：界面和本地数据流已具备，真正的语音识别、图像识别、云端 AI、账号同步等能力尚未接入。

## 2. 技术栈与运行方式

项目类型：快应用。

主要工具：

- `hap-toolkit`：快应用构建、调试和打包工具。
- `.ux`：快应用页面和组件文件。
- `@system.storage`：本地持久化。
- `@system.router`：页面跳转。
- `@system.prompt`：Toast 提示，目前在编辑页使用。
- `prettier-plugin-ux`：格式化 `.ux` 文件。

常用命令：

```bash
npm run start
npm run build
npm run release
npm run debug
npm run gen PageName
npm run prettier
```

说明：

- `npm run start` 会执行 `hap server --watch`，通常用于开发时生成二维码并用快应用引擎扫码预览。
- `npm run build` 用于生成调试构建。
- `npm run release` 用于生成发布包。
- `npm run gen PageName` 会按模板生成新页面，并写入 `src/manifest.json` 的路由配置。

## 3. 目录结构

```text
.
├── README.md
├── PROJECT_CONTEXT.md
├── package.json
├── package-lock.json
├── docs/
│   ├── quickapp-knowledge-base.md
│   ├── blueheart-jiuwen-knowledge-base.md
│   ├── ai-model-calling-strategy.md
│   ├── postgresql-database-architecture.md
│   ├── postgresql-er-diagram.mmd
│   └── postgresql-er-diagram.svg
├── scripts/
│   ├── selfCloseInputTag.js
│   └── gen/
│       ├── index.js
│       └── template.ux
└── src/
    ├── app.ux
    ├── manifest.json
    ├── sitemap.json
    ├── config-phone.json
    ├── global.js
    ├── assets/
    │   ├── images/
    │   │   ├── I_am_here.png
    │   │   └── logo.png
    │   └── styles/
    │       ├── style.scss
    │       ├── variables.scss
    │       └── mixins.scss
    ├── helper/
    │   ├── ajax.js
    │   ├── utils.js
    │   └── apis/
    ├── pages/
    │   ├── Demo/
    │   │   └── index.ux
    │   └── EditEvent/
    │       └── index.ux
    ├── components/
    │   ├── Calendar.ux
    │   ├── Accounting.ux
    │   └── AIAssistant.ux
    └── widgets/
        └── CardDemo/
```

补充：

- `build/`、`dist/`、`node_modules/` 是生成物或依赖目录，已在 `.gitignore` 中忽略。
- `src/widgets/CardDemo` 是快应用卡片示例，当前业务主流程没有使用。

## 4. 应用入口与路由

应用入口配置在 `src/manifest.json`：

```json
{
  "router": {
    "entry": "pages/Demo",
    "pages": {
      "pages/Demo": { "component": "index" },
      "pages/EditEvent": { "component": "index" }
    }
  }
}
```

已注册页面：

- `src/pages/Demo/index.ux`：首页和底部 Tab 容器。
- `src/pages/EditEvent/index.ux`：新建/编辑/删除日程页面。

`src/app.ux` 只定义了应用生命周期日志：

- `onCreate()` 输出“智能日程表启动”。
- `onDestroy()` 输出“应用退出”。

## 5. 页面与组件职责

### `src/pages/Demo/index.ux`

首页容器，包含三个底部 Tab：

- `日程`：渲染 `Calendar.ux`。
- `记账`：渲染 `Accounting.ux`。
- `AI助手`：渲染 `AIAssistant.ux`。

主要职责：

- 从 `@system.storage` 的 `events` key 读取日程数组。
- 在 `onInit` 和 `onShow` 时刷新日程。
- 响应 AI 助手的 `add-event` 事件，把 AI 提取出的日程写入本地存储。
- 管理当前 Tab 状态 `currentIndex`。

### `src/components/Calendar.ux`

周视图日程组件。

主要职责：

- 计算当前周从周一到周日的日期。
- 生成 0-23 点的小时网格。
- 显示传入的 `events`。
- 点击空白单元格时，把默认日程对象写入 `tempEditEvent`，再跳转 `pages/EditEvent`。
- 点击已有日程时，把该日程写入 `tempEditEvent`，再跳转编辑页。
- 支持上一周、下一周和点击日期列展开。

### `src/pages/EditEvent/index.ux`

新建/编辑/删除日程页面。

主要职责：

- 从 `@system.storage` 的 `tempEditEvent` 读取待编辑数据。
- 编辑字段：标题、地点、开始时间、结束时间、消费金额、消费类别、日期。
- 保存时读取 `events`，根据 `id` 判断新增还是更新。
- 删除时从 `events` 中移除对应日程。
- 保存或删除后返回首页。

注意：当前通过 `router.back()` 加 `setTimeout(router.replace)` 做返回兜底。

### `src/components/Accounting.ux`

记账页组件。

主要职责：

- 自己从本地 `events` key 读取数据，不依赖父组件 props。
- 把带有 `amount > 0` 的日程当作消费记录。
- 显示全部消费记录列表。
- 计算当月消费总额 `monthlyTotal`。

当前没有独立账本数据结构，记账完全派生自日程。

### `src/components/AIAssistant.ux`

AI 助手页组件。

主要职责：

- 展示简单聊天列表。
- 输入自然语言后，通过 `mockExtractEvent()` 用正则提取日期、时间、标题、地点。
- 通过 `$emit('addEvent', extracted)` 把提取结果交给首页保存。
- `getAdvice()` 根据当前 `events` 检查时间重叠冲突。
- `startVoice()` 是模拟录音：1.5 秒后固定填入“明天下午3点去超市”。
- `pickImage()` 目前只提示“图像识别功能暂未开启”。

注意：这里还没有接入真实大模型或蓝心九问 API。

## 6. 核心数据结构

本项目最核心的数据是 `events`，存储在快应用本地存储：

```js
storage.set({
  key: 'events',
  value: JSON.stringify(events)
})
```

单个 event 当前约定字段：

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
  color: '#2196F3'
}
```

字段说明：

- `id`：字符串，通常由 `Date.now().toString()` 生成。
- `date`：日期字符串，格式为 `YYYY-MM-DD`。
- `startHour` / `endHour`：整数小时。
- `startMinute` / `endMinute`：分钟。
- `title`：事件标题，保存时必填。
- `location`：地点，可选。
- `amount`：消费金额，可选；存在且大于 0 时会进入记账页。
- `category`：消费类别，可选。
- `color`：日程卡片背景色，新增时随机生成。

另一个临时 key：

```js
tempEditEvent
```

用途：Calendar 跳转到 EditEvent 前，把新建默认值或待编辑事件临时存在这里。EditEvent 初始化时读取这个 key。

## 7. 功能流程

### 新建日程

1. 用户在日程周视图点击某天某小时格子。
2. `Calendar.ux` 生成默认 event，并写入 `tempEditEvent`。
3. 跳转到 `pages/EditEvent`。
4. 用户填写标题、地点、时间、金额、类别。
5. `EditEvent.ux` 保存到 `events`。
6. 返回 `Demo`，`onShow()` 重新读取并刷新页面。

### 编辑日程

1. 用户点击已有日程块。
2. `Calendar.ux` 把完整 event 写入 `tempEditEvent`。
3. 跳转到 `pages/EditEvent`。
4. 编辑页根据 `id` 判断为编辑模式。
5. 保存时在 `events` 数组中找到同 id 项并替换。

### 删除日程

1. 编辑已有日程时显示“删除日程”按钮。
2. 点击后从 `events` 中移除同 id 项。
3. 保存新数组并返回首页。

### 自动记账

1. 用户在日程里填写 `amount`。
2. `Accounting.ux` 读取所有 `events`。
3. 过滤 `amount > 0` 的事件作为消费记录。
4. 当月总额按当前系统年月筛选并求和。

### AI 添加日程

1. 用户在 AI 助手输入文本，例如“明天下午3点去超市”。
2. `AIAssistant.ux` 使用正则提取日期和时间。
3. 生成 event 对象。
4. 通过 `add-event` 事件交给 `Demo/index.ux`。
5. 首页补充 `id` 和 `color` 后写入 `events`。

## 8. 配置与权限

`src/manifest.json` 当前主要配置：

- `package`: `com.example.smartcalendar`
- `name`: `我在`
- `versionName`: `1.0.0`
- `versionCode`: `1`
- `minPlatformVersion`: `1060`
- `icon`: `/assets/images/I_am_here.png`
- `router.entry`: `pages/Demo`

当前 source manifest 声明的 features：

- `system.storage`
- `system.fetch`
- `system.media`
- `system.photo`
- `system.router`

需要注意：

- `EditEvent.ux` 使用了 `@system.prompt`，建议在 `src/manifest.json` 的 `features` 中补充 `{ "name": "system.prompt" }`，避免真机或构建环境出现权限/能力声明问题。
- `system.media` 和 `system.photo` 已声明，但当前真实媒体能力没有接入。
- `system.fetch` 已声明，但主业务目前没有真实网络请求。

## 9. 工具与辅助代码

### `src/helper/ajax.js`

封装 `@system.fetch` 的 `get/post/put`。当前看起来是模板遗留代码，主业务没有直接使用。

注意点：

- `requestHandle` 的 `finally` 中调用了 `resolve()`，可能会覆盖前面的 resolve 结果。若未来要接真实 API，建议先重构这里。

### `src/helper/apis/example.js`

示例 API 模块，`baseUrl` 是 `https://api.exampel.com/`，拼写也明显是模板占位。当前不应视为真实接口。

### `src/global.js`

提供 `setGlobalData` 和 `getGlobalData`，并挂到全局对象上。当前业务没有明显依赖。

### `scripts/gen/index.js`

生成新页面并写入 `manifest.json` 路由。页面名要求类似 `XyzAbcde` 的大驼峰格式。

### `scripts/selfCloseInputTag.js`

格式化前把 `.ux` 里的 `<input></input>` 转成 `<input />`，配合 `npm run prettier` 使用。

## 10. 文档资料

已有项目内知识库和设计资料：

- `docs/quickapp-knowledge-base.md`：快应用开发速查资料，包含 manifest、路由、生命周期、组件、样式、存储、媒体、打包发布等内容。
- `docs/blueheart-jiuwen-knowledge-base.md`：蓝心九问平台资料，包含 Bot、工具库、知识库、API 发布、鉴权、限制、错误码等信息。
- `docs/ai-model-calling-strategy.md`：端侧蓝心 3B、蓝心九问云端 Agent、第三方云能力和本地规则的调用分工与路由策略。

后续如果要把 AI 助手从本地 mock 改成真实智能体，优先阅读蓝心九问知识库和端云模型调用策略文档。

## 11. 当前已知问题与后续优先级

建议优先处理：

1. 在 `src/manifest.json` 补充 `system.prompt`。
2. 统一数据读写：现在 `Demo` 和 `Accounting` 都直接读写 `events`，后续可抽出 `eventStore`，减少重复解析和保存逻辑。
3. 强化时间校验：当前可以输入非法小时/分钟、结束时间早于开始时间等。
4. 优化路由返回：多处使用 `router.back()` 加延迟 `router.replace()` 兜底，后续可统一成更稳定的导航策略。
5. 改进 AI 提取：当前 `mockExtractEvent()` 只支持少量中文日期和整点时间，且标题清洗比较粗糙。
6. 接入真实语音/图片/AI 能力：`startVoice()` 和 `pickImage()` 仍是演示逻辑。
7. 改造记账能力：如果后续要做完整账本，应建立独立账单数据结构，而不是只依赖日程金额字段。
8. 添加测试或至少构建校验流程：目前没有单元测试，主要依赖 `npm run build` 和真机/模拟器预览。

## 12. 给新对话窗口的建议提示词

如果要在新窗口继续开发，可以这样开头：

```text
请先阅读 PROJECT_CONTEXT.md，并结合 src/manifest.json、src/pages/Demo/index.ux、src/pages/EditEvent/index.ux、src/components/Calendar.ux、src/components/Accounting.ux、src/components/AIAssistant.ux 理解项目。这个项目是一个快应用“我在”，核心数据存在 system.storage 的 events key。请在不破坏现有原型功能的前提下继续开发。
```

如果要接入真实 AI 能力，可以补充：

```text
请同时阅读 docs/blueheart-jiuwen-knowledge-base.md 和 docs/ai-model-calling-strategy.md，评估如何把 AIAssistant.ux 从本地 mock 改为端侧蓝心 3B、本地规则与蓝心九问 Agent 协同调用，并注意快应用端鉴权、网络请求、隐私和错误兜底。
```

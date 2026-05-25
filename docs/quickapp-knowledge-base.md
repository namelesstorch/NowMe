# 快应用知识库

更新时间：2026-05-25

用途：本文件整理自快应用联盟官方文档，作为当前工程后续开发、排错、打包发布时的本地速查资料。遇到具体接口参数、版本兼容或审核规则不确定时，应优先打开文末官方链接复核最新内容。

## 1. 快应用是什么

快应用是一种无需传统安装、可即点即用的应用形态。开发方式接近前端技术栈，但运行在快应用框架中，可以调用大量系统能力和服务能力。

官方框架的核心组成：

- `manifest.json`：应用描述、功能权限声明、系统配置、页面路由等。
- `app.ux`：应用级入口，可定义应用生命周期和全局逻辑。
- 页面或组件 `.ux` 文件：由 `template`、`style`、`script` 三部分组成。
- 系统接口：通过 `@system.*` 或 `@service.*` 模块导入，通常需要先在 `manifest.json` 的 `features` 中声明。

## 2. 标准工程结构

官方推荐结构通常类似：

```text
src/
  assets/          公共图片、字体、样式等资源
  helper/          工具函数、接口封装
  pages/           页面级代码
  app.ux           应用入口
  manifest.json    应用配置
package.json       依赖与脚本
```

`.ux` 文件是快应用主要开发单元：

```ux
<template>
  <div>
    <text>{{ message }}</text>
  </div>
</template>

<style>
  text {
    font-size: 32px;
  }
</style>

<script>
export default {
  private: {
    message: 'Hello Quick App'
  }
}
</script>
```

注意：

- `template` 下只能有一个根节点，常用 `div`。
- 快应用环境不是 Node.js 环境，不能直接引入 `fs` 等 Node 原生模块。
- 页面必须在 `manifest.json` 的 `router.pages` 中注册，否则不会参与项目编译。

## 3. manifest.json 关键字段

常见字段：

```json
{
  "package": "com.example.demo",
  "name": "示例应用",
  "versionName": "1.0",
  "versionCode": 1,
  "minPlatformVersion": 1070,
  "icon": "/assets/images/logo.png",
  "features": [{ "name": "system.fetch" }],
  "router": {
    "entry": "pages/Home",
    "pages": {
      "pages/Home": { "component": "index" }
    }
  }
}
```

字段要点：

- `package`：应用唯一标识，推荐 `com.company.module`。
- `name`：应用名称，官方文档建议 6 个汉字以内，并与应用商店名称一致。
- `icon`：应用图标路径，官方示例要求正方形，避免圆角和白边。
- `versionCode`：整数，从 1 开始；每次上传新版本建议递增。
- `minPlatformVersion`：最小平台版本。使用高版本能力时必须提高此值，否则低版本运行可能出错。
- `features`：多数系统接口必须声明后才能调用。
- `router.entry`：应用首页。
- `router.pages`：页面注册表，key 是页面名或目录，`component` 指向页面内主 `.ux` 文件。

当前项目提示：

- 当前 `src/manifest.json` 的 `minPlatformVersion` 是 `1060`，如果使用 `1070+`、`1080+`、`1090+` 文档能力，需要同步评估并提高。
- 当前已声明：`system.storage`、`system.fetch`、`system.media`、`system.photo`、`system.router`。
- 当前首页是 `pages/Demo`，另有 `pages/EditEvent`。

## 4. 路由与页面跳转

导入：

```js
import router from '@system.router'
```

常用方法：

- `router.push({ uri, params })`：跳转到应用内页面或支持的 schema。
- `router.replace({ uri, params })`：替换当前页面。
- `router.back()`：返回上一页。
- `router.clear()`：清空页面栈。
- `router.getState()`：获取当前页面状态。
- `router.getPages()`：获取页面栈列表，官方标注为 `1070+`。

`uri` 常见写法：

```js
router.push({
  uri: '/pages/EditEvent',
  params: {
    id: '123'
  }
})
```

要点：

- `router.push` 不能跳到 `tabBar` 页面。
- 以 `/` 开头表示应用内页面路径。
- 快应用内部打开另一个快应用时应使用 `hap://app/...`，`http` 和 `https` 在快应用内会被当作 Web 页面打开。
- Deeplink 可从外部打开快应用，常见格式包含 `hap://app/<package>/<path>?key=value`。

## 5. 生命周期

页面生命周期常见顺序：

- 打开页面 A：`onInit()` -> `onReady()` -> `onShow()`
- A 打开 B：A 触发 `onHide()`
- 从 B 返回 A：A 触发 `onShow()`
- A 页面返回退出：`onBackPress()` -> `onHide()` -> `onDestroy()`

常用页面生命周期：

- `onInit(query)`：页面初始化完成，只触发一次；`1060+` 可拿到 query。
- `onReady()`：页面创建完成，只触发一次。
- `onShow()`：页面显示。
- `onHide()`：页面隐藏。
- `onDestroy()`：页面销毁。
- `onBackPress()`：监听返回；返回 `true` 表示自行处理返回逻辑。
- `onConfigurationChanged(event)`：`1060+`，系统语言、主题、屏幕方向或屏幕大小变化。
- `onReachTop()`、`onReachBottom()`、`onPageScroll(event)`：`1080+` 页面滚动相关。

应用生命周期定义在 `app.ux`：

- `onCreate()`
- `onRequest()`，`1070+`
- `onIntentExecute(intelligentIntent)`
- `onShow()`，`1070+`
- `onHide()`，`1070+`
- `onDestroy()`
- `onError()`，`1030+`
- `onPageNotFound()`，`1060+`

当前项目已经在 `src/app.ux` 中定义了 `onCreate` 和 `onDestroy`。

## 6. 数据、模板与组件

数据声明推荐使用：

- `private`：私有数据，不允许被外部覆盖，适合敏感或内部状态。
- `protected`：受保护数据。
- `public`：允许外部传入或覆盖的数据，页面参数需要显式声明时常用。

`data` 已被官方标注为不推荐/废弃方向，原因是可能被外部数据覆盖，存在安全风险。

模板能力：

- 文本绑定：`{{ message }}`
- 事件绑定：`onclick="press"` 或 `@click="press"`
- 条件渲染：`if`、`elif`、`else`
- 显隐：`show`
- 循环：`for`
- 逻辑容器：`block`
- 自定义组件：`<import name="my-component" src="./myComponent"></import>`
- 插槽：`<slot></slot>`
- 动态组件：`component is="{{componentName}}"`，官方标注 `1070+`
- `app.ux` 全局自定义组件：官方标注 `1090+`，并要求 `hap-toolkit >= 1.8.0`

组件事件命名注意：

- 绑定自定义子组件事件可用 `onevent1` 或 `@event-type1`。
- 标签事件名建议使用连字符，不要使用驼峰，例如 `event-type1` 对应方法或事件 `eventType1`。

## 7. 样式与布局

快应用样式接近 CSS，但不是完整 Web CSS。

关键规则：

- 布局采用 Flexbox。
- 与大小相关的样式会基于设计宽度缩放，官方示例默认基准宽度为 `750px`。
- 支持内联 `style` 和 `class`。
- 支持 `<style src="./style.css"></style>`。
- 支持 `@import './style.css';`。
- 支持 Less 与 Sass 预编译。
- 支持部分选择器、伪类和媒体查询，但属于 Web CSS 子集。

通用属性：

- `id`
- `style`
- `class`
- `disabled`
- `aria-label`
- `aria-unfocusable`
- `forcedark`，`1070+`

通用样式高频项：

- 尺寸：`width`、`height`、`min-width`、`max-width`
- 盒模型：`padding`、`margin`、`border`
- 颜色：`color`、`background-color`
- 背景：`background-image`、`background-size`、`background-repeat`
- 显隐：`display: flex|none`、`visibility`
- Flex：`flex`、`flex-grow`、`flex-shrink`

常用组件：

- `div`：基本容器，支持 Flex 相关样式。
- `text`：文本。
- `input`：输入控件，支持 `text`、`email`、`date`、`time`、`number`、`password`、`tel` 等类型。
- `list`、`list-item`：列表。
- `tabs`、`tab-bar`、`tab-content`：标签页。
- `slider`：滑动选择器。
- `image`、`video`：媒体展示。

## 8. 常用系统接口

### 8.1 storage

声明：

```json
{ "name": "system.storage" }
```

导入：

```js
import storage from '@system.storage'
```

方法：

- `storage.get({ key, default, success, fail, complete })`
- `storage.set({ key, value, success, fail, complete })`
- `storage.delete({ key, success, fail, complete })`
- `storage.clear({ success, fail, complete })`
- `storage.key({ index, success, fail, complete })`，`1050+`
- `storage.length`，`1050+`

注意：`storage.set` 中 `value` 为空字符串时，会删除该 key 对应数据。

### 8.2 fetch

声明：

```json
{ "name": "system.fetch" }
```

导入：

```js
import fetch from '@system.fetch'
```

示例：

```js
fetch.fetch({
  url: 'https://example.com/api',
  method: 'GET',
  responseType: 'json',
  success(response) {
    console.log(response.code, response.data)
  },
  fail(data, code) {
    console.log(data, code)
  }
})
```

要点：

- `method` 默认 `GET`。
- `responseType` 可为 `text`、`json`、`file`、`arraybuffer`；`json`、`arraybuffer` 等有版本要求。
- `data` 与 `Content-Type` 的组合会影响请求体编码方式。
- `PATCH` 官方标注为 `1200+`。

### 8.3 prompt

声明：

```json
{ "name": "system.prompt" }
```

导入：

```js
import prompt from '@system.prompt'
```

方法：

- `prompt.showToast({ message, duration })`
- `prompt.showDialog({ title, message, buttons, autocancel, success, cancel, complete })`
- `prompt.showContextMenu({ itemList, itemColor, success, cancel, complete })`

限制：官方文档标注后台运行时禁止使用。

### 8.4 file

声明：

```json
{ "name": "system.file" }
```

导入：

```js
import file from '@system.file'
```

常见能力：

- `file.move`
- `file.copy`
- 文件列表、读写、删除等更多能力以官方接口页为准。

文件 URI 常见分区：

- `internal://cache/`：缓存文件，可能被系统删除。
- `internal://files/`：应用管理的较小永久文件。

### 8.5 app

导入：

```js
import app from '@system.app'
```

无需在 `features` 声明。

常见用途：

- `app.getInfo()` 获取当前应用包名、名称、版本、来源等。

### 8.6 package、device、request、exchange

按需查官方文档并声明：

- `system.package`：检测、安装应用等。
- `system.device`：设备品牌、型号、屏幕、设备类型等。
- `system.request`：上传下载。
- `service.exchange`：不同快应用间数据交互，官方标注 `1050+`。

## 9. 分包加载

适用场景：快应用体积较大，需要优化首次启动时间和模块解耦。

核心概念：

- 通过 `manifest.json` 的 `subpackages` 规则拆分。
- 编译工具会生成基础包和若干分包。
- 运行时优先加载基础包与当前页面所在分包，其余分包可后台预加载。

官方当前限制：

- 普通包 `rpk`：不超过 `2M`。
- 分包 `rpks`：所有分包总大小不超过 `20M`。
- 单个分包或基础包不超过 `2M`。

## 10. IDE、调试与预览

官方推荐使用快应用 IDE，提供：

- 新建工程。
- 安装依赖、编译预览。
- Data 面板查看页面数据，如 `.ux` 文件中的 `private`、`protected`、`public` 字段。
- 真机 USB 调试。
- 远程预览。
- 打包、上传。
- 生成骨架屏。
- 代码静态依赖分析插件。

远程预览：

- 需要登录平台账号。
- 通常需要先新建签名。
- 点击远程预览后会打包上传 rpk 到云端并生成二维码。
- 二维码有效期官方文档写为 24 小时。

当前项目脚本：

```bash
npm run start    # hap server --watch
npm run build    # hap build
npm run release  # hap release
npm run watch    # hap watch
npm run debug    # hap debug
```

## 11. 打包、签名、上传与发布

打包流程：

1. IDE 顶部工具栏点击“打包”，或使用项目脚本。
2. 检查 `sign` 目录中是否存在 `certificate.pem` 和 `private.pem`。
3. 打包成功后，在 `dist` 目录生成带 release 签名的 `rpk`。

环境：

- 正式包：`NODE_ENV=production`
- 测试包：`NODE_ENV=development`
- 预发包：`NODE_ENV=pre`
- 自定义：可添加自定义 `NODE_ENV` 和其他变量。

签名注意：

- 正式包必须使用同一份证书文件。
- 证书不一致会导致签名校验失败，可能无法通过上线审核。

上传注意：

- 需要登录快应用官网账号。
- 需要开发者在官网完善个人或企业信息。
- 第一次上传成功后，需要到官网补充相关信息。
- 上传新版本前检查 `versionName` 和 `versionCode`；尤其 `versionCode` 应递增，否则可能审核不通过。
- 首次上传时，开发工具可在快应用开发中心创建应用。

## 12. H5 跳转快应用与 Deeplink

官方推荐 H5 使用“点击组件”跳转指定快应用，必须由用户主动点击触发。

引入示例：

```html
<script src="//statres.quickapp.cn/quickapp/js/qa_router.min.js"></script>
```

注意：

- vivo 快应用官方文档页标注“不支持 H5 点击组件能力”，需按目标厂商实际能力复核。
- 旧的 URL 跳转配置官方已标注不再推荐。
- 快应用内打开其他快应用时，应使用 `hap://` 链接。

## 13. 常见错误码

接口常见错误码：

- `200`：一般性错误。
- `201`：用户拒绝。
- `202`：参数非法。
- `203`：服务不可用。
- `204`：请求超时。

排查顺序：

1. 是否在 `manifest.json` 的 `features` 中声明接口。
2. `minPlatformVersion` 是否满足接口或属性的版本要求。
3. 是否需要用户授权，以及用户是否拒绝。
4. 参数类型、必填字段、URI 格式是否正确。
5. 是否处于后台运行限制场景。
6. 厂商或设备是否支持该能力。

## 14. 本项目开发检查清单

改页面：

- 新页面目录建在 `src/pages/xxx/index.ux`。
- 在 `src/manifest.json` 的 `router.pages` 注册页面。
- 如作为首页，更新 `router.entry`。
- 页面参数若要通过外部传入，按需在页面中显式声明 `public`。

调接口：

- 先查接口文档是否需要 `features` 声明。
- 确认当前 `minPlatformVersion: 1060` 是否够用。
- 对 `success`、`fail` 都加日志，保留错误码。

做样式：

- 优先 Flex 布局。
- 不假设完整浏览器 CSS 能力。
- 检查不同屏幕宽度下尺寸缩放效果。

发布前：

- `versionCode` 自增。
- 检查 `versionName`。
- 检查 `sign/certificate.pem` 和 `sign/private.pem`。
- 确认 rpk 体积，必要时分包。
- 正式包保持同一证书。

## 15. 官方资料索引

- 快速开始开发：https://doc.quickapp.cn/tutorial/overview/quick-start.html
- 项目结构讲解：https://doc.quickapp.cn/tutorial/overview/project-structure.html
- 框架简介：https://doc.quickapp.cn/framework/
- 文件组织：https://doc.quickapp.cn/framework/file-organization.html
- UX 文件：https://doc.quickapp.cn/framework/source-file.html
- manifest 文件：https://doc.quickapp.cn/framework/manifest.html
- template 模板：https://doc.quickapp.cn/framework/template.html
- script 脚本与生命周期：https://doc.quickapp.cn/framework/script.html
- 生命周期教程：https://doc.quickapp.cn/tutorial/framework/lifecycle.html
- style 样式：https://doc.quickapp.cn/framework/style-sheet.html
- 通用属性：https://doc.quickapp.cn/widgets/common-attributes.html
- 通用样式：https://doc.quickapp.cn/widgets/common-styles.html
- 页面路由 router：https://doc.quickapp.cn/features/system/router.html
- 数据请求 fetch：https://doc.quickapp.cn/features/system/fetch.html
- 数据存储 storage：https://doc.quickapp.cn/features/system/storage.html
- 弹窗 prompt：https://doc.quickapp.cn/features/system/prompt.html
- 文件存储 file：https://doc.quickapp.cn/features/system/file.html
- 应用上下文 app：https://doc.quickapp.cn/features/system/app.html
- 分包加载：https://doc.quickapp.cn/framework/subpackage.html
- 远程预览：https://doc.quickapp.cn/ide/remote-preview.html
- 打包：https://doc.quickapp.cn/ide/package.html
- 上传：https://doc.quickapp.cn/ide/upload-quickapp.html
- H5 点击组件：https://doc.quickapp.cn/tutorial/platform/jump-component.html

# 蓝心端侧 3B 多模态知识库

更新时间：2026-06-05

用途：这份文档用于记录比赛主办方开放的端侧 3B 蓝心模型能力，重点覆盖纯文本与多模态（图文理解）模式、SDK 调用流程、当前快应用项目的接入边界，以及“我在”项目可以优先使用的视觉场景。

## 1. 能力概览

主办方文档 `id=1802` 说明，端侧 3B 蓝心大模型 BlueLM 已开放移动端推理能力，支持两种模式：

- 纯文本对话。
- 多模态图文理解。

官方 SDK 侧的模型类型命名：

- 纯文本模式：`BlueLM_3B`。
- 多模态模式：`BlueLM_V_3B`。

对本项目的关键影响：

- 原先策略中“端侧 3B 不处理原始图片”的判断需要更新。
- 图片小票、活动海报、课程表截图、聊天截图等轻量图像理解任务，应优先考虑端侧多模态。
- 高精度票据 OCR、复杂表格、长文档、多图推理仍应保留云端或专项 OCR 兜底。

## 2. 公开模型情况

公开资料中，与本次能力最接近的是 vivo AI Lab 的 `BlueLM-2.5-3B` / `BlueLM-V-3B` 端侧多模态模型线。

从 Hugging Face paper page 和 arXiv 技术报告看，`BlueLM-2.5-3B` 是面向端侧部署的紧凑多模态大模型，约 2.9B 参数，支持 thinking 与 non-thinking 两种模式，并支持显式控制 thinking token budget。公开摘要称其在保持纯文本能力的同时提升多模态能力：thinking 模式下文本基准接近 Qwen3-4B，多模态平均表现距离更大规模 Kimi-VL-A3B-16B 约 5%；non-thinking 模式在多数多模态基准上优于 Qwen2.5-VL-3B。

注意：

- 比赛实际接入以主办方 `id=1802` 文档和 SDK 为准。
- Hugging Face/arXiv 资料用于判断能力边界和模型定位，不等同于比赛 SDK 的完整接口说明。

## 3. SDK 与运行环境

主办方文档说明：

- SDK 以 C++ so 库、头文件和 Android AAR 的形式提供。
- 推荐使用 Android Studio 开发 native 工程，或基于官方 demo 源码二次开发。
- 复赛云真机 X300 Pro 默认在 `/sdcard/1225/` 内置模型。
- 禁止修改模型文件夹内各文件名，否则可能无法读取模型。

已验证开发环境：

| 条件 | 要求 |
| --- | --- |
| Android 目标平台 | `arm64-v8a` |
| Android SDK | API 28+ |
| NDK | r23 |
| CMake | 3.22.1+ |
| Gradle | 8.5 |
| AGP | 8.2.2 |
| 芯片 | MediaTek DX5（如 MT6993 等） |

权限与依赖要点：

- 需要读取 `/sdcard/` 下模型文件。
- Android 13+ 读取模型目录通常需要 `MANAGE_EXTERNAL_STORAGE`。
- 需要声明 `mediatek.permission.ACCESS_APU_SYS`。
- 需要声明相关 native library，例如 `libdmabufheap.so` 和 `libvcap_npu_network_v1.so`。

## 4. LlmConfig 参数要点

官方 Java 封装类为 `LlmManager`，初始化参数通过 `LlmConfig` 提供。

| 参数 | 说明 |
| --- | --- |
| `modelPath` | 必填，模型目录路径，例如 `/sdcard/1225` |
| `multimodal` | 是否启用多模态模式；`false` 为纯文本，`true` 为图文理解 |
| `nCtx` | 上下文长度，支持 2048、4096、8192 |
| `nThreads` | CPU 线程数，默认 4 |
| `npuPower` | NPU 档位，MTK 取值 10-100，越高性能越好 |
| `temperature` | 采样随机性，0 为贪心解码 |
| `topP` | 累计概率采样阈值 |
| `topK` | 单步最多考虑 token 数 |

建议：

- 结构化抽取、账单解析、日程解析应使用低随机性配置。
- 创意表达、建议文案可以适当提高随机性，但仍要经过本地规则校验。
- 比赛演示优先保证稳定，建议先用低温度、较小 `topK` 验证结构化输出。

## 5. LlmManager 接口要点

主要接口：

- `init(LlmConfig config)`：初始化模型，返回 0 表示成功。耗时操作，需要在子线程调用。
- `callVit(byte[] rgbData, int width, int height)`：多模态专用，对图像进行 VIT 编码，返回 0 表示成功。
- `generate(String prompt, TokenCallback callback)`：执行推理，流式回调 token。
- `interrupt()`：中断当前推理。
- `release()`：释放原生资源，Activity 销毁时必须调用。

多模态调用顺序：

```text
init(multimodal=true)
-> callVit(图片 RGB 数据)
-> generate(带图像标记的 prompt)
-> release()
```

注意事项：

- `callVit()` 必须在 `init()` 成功且 `multimodal=true` 后调用。
- 图片数据格式为 RGB 三通道，无 Alpha 通道，长度为 `width * height * 3`。
- VIT 编码结果会缓存到模型实例内部，下一次 `generate()` 可直接引用。
- 每次 `callVit()` 会覆盖上一次图像编码结果。
- 多模态模型文件夹需要包含 VIT 相关文件。
- 纯文本模式下调用 `callVit()` 会返回错误。

## 6. Prompt 模板

官方模板：

纯文本模式：

```text
[|Human|]:用户输入
[|AI|]:
```

多模态模式：

```text
[|Human|]:<im_start><image><im_end>用户输入
[|AI|]:
```

对本项目的建议：

- 模型 prompt 应要求输出 JSON 或严格字段列表。
- 图片解析 prompt 应要求模型区分“看到的文字”“推测的场景”和“不确定内容”。
- 小票和账单场景必须要求输出置信度，并提示“金额以用户确认和本地计算为准”。

## 7. 和当前快应用项目的关系

当前项目是快应用，主流程代码位于 `.ux` 文件中。主办方端侧 SDK 是 Android native / AAR / C++ so 形态，不能假设可以直接在快应用 JS 层 `import` 使用。

后续可能接入方式：

- 方案 A：保留快应用前端，新增 native 能力桥接层，由快应用调用本地 native 推理能力。
- 方案 B：将 AI demo 能力做成独立 Android native 原型，比赛演示时与快应用主流程做产品级联动说明。
- 方案 C：快应用端先保留图片选择和候选卡片交互，实际推理通过后端或云真机服务模拟，等 native 接入路径确定后替换。

文档策略：

- 在没有确认 native bridge 前，不应在 `.ux` 组件中直接写端侧 SDK 调用伪代码。
- 应先抽象出 `edgeTextService`、`edgeVisionService`、`aiRouter` 等接口，前端只依赖统一结果。

## 8. 对“我在”的优先视觉场景

最适合端侧多模态优先处理的场景：

- 活动海报识别：从海报中提取活动标题、日期、时间、地点、票价或报名费。
- 课程表/值班表截图识别：提取时间块，生成候选日程。
- 小票/支付截图轻量解析：识别商家、总金额、时间、类别，生成候选账单。
- 聊天截图计划识别：从聊天截图中提取约饭、会议、出行等候选日程。
- UI 截图理解：识别用户当前页面状态，辅助解释“下一步该点哪里”。

仍建议云端或专项 OCR 兜底的场景：

- 多张小票批量识别。
- 长表格和复杂票据。
- 需要逐项税费、折扣、发票抬头的高精度票据解析。
- 图片质量差、反光、遮挡、手写严重的输入。
- 端侧 VIT 编码失败或置信度低的情况。

## 9. 安全与合规注意

- 端侧推理仍需接入系统文本审核能力，避免非法文本生成。
- 图片原始数据优先只在端侧处理，不应默认上传云端。
- 如需云端复核，只发送端侧提取后的摘要和必要字段。
- 不在日志中保存原始图片、完整小票、完整聊天截图。
- AI 识别结果永远作为候选，必须由用户确认后才能写入日程或账单。

## 10. 参考资料

- 主办方端侧 3B 模型文档：https://aigc.vivo.com.cn/#/document/index?id=1802
- 主办方文档详情接口：https://aigc.vivo.com.cn/vstack/webapi/service/doc/info/v1?docId=1802&businessCode=9b2ca654118cac5b4eb2883515326b8d
- Hugging Face Paper：BlueLM-2.5-3B Technical Report：https://huggingface.co/papers/2507.05934
- arXiv：BlueLM-2.5-3B Technical Report：https://arxiv.org/abs/2507.05934
- Hugging Face Paper：BlueLM-V-3B：https://huggingface.co/papers/2411.10640

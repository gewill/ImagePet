# V0.16 Desktop Pet Theme Visual QA

更新日期：2026-06-27

## 范围

本次验收覆盖当前可选内置主题：

- `Dog`
- `Pufferfish`
- `Squirrel`
- `Hamster`
- `Cat`
- `Rabbit`
- `Clownfish`

每个主题覆盖 9 个运行时状态：

- `idle`
- `eating`
- `done`
- `issues`
- `dragHover`
- `petting`
- `stretch`
- `yawn`
- `sleep`

## 产物

每个主题目录包含：

- `review.json`：validator 机器校验结果
- `contact-sheet.png`：逐状态逐帧 contact sheet
- `previews/*.gif`：逐状态 motion preview，作为轻量 QA 产物提交到 Git

全局辅助检查图：

- `_contact-sheets-overview.png`：本地生成用于快速总览，不默认提交到 Git
- `_motion-preview-samples.png`：本地生成用于 motion 抽样检查，不默认提交到 Git

## 验收方法

1. 使用仓库内 validator 为每个主题生成 `review.json`、`contact-sheet.png` 和 `previews/*.gif`。
2. 检查全部 `review.json` 均为 `ok=true`，且 `errors=[]`、`warnings=[]`。
3. 模型视觉检查 `_contact-sheets-overview.png`，确认每个主题和状态都有完整帧序列，没有空帧、明显裁切、白底残留、帧数缺失或主题身份漂移。
4. 模型视觉检查 `_motion-preview-samples.png`，抽查每个主题/状态的首帧、中间帧和尾帧，确认没有明显尺寸跳变、基线跳变、时间顺序反转或状态语义错位。
5. 小型庆祝粒子、疑问符号、汗滴、爱心等反馈元素属于当前 ImagePet 主题既有状态表达；本次只在它们造成裁切、遮挡、背景污染或状态误读时标记为失败。

## 机器校验结果

| 主题 | Validator | Errors | Warnings | 主题大小 |
| --- | --- | ---: | ---: | ---: |
| Dog | Pass | 0 | 0 | 1006572 bytes |
| Pufferfish | Pass | 0 | 0 | 654170 bytes |
| Squirrel | Pass | 0 | 0 | 1053030 bytes |
| Hamster | Pass | 0 | 0 | 1007595 bytes |
| Cat | Pass | 0 | 0 | 998256 bytes |
| Rabbit | Pass | 0 | 0 | 779384 bytes |
| Clownfish | Pass | 0 | 0 | 2938997 bytes |

## 模型视觉验收记录

| 主题 | idle | eating | done | issues | dragHover | petting | stretch | yawn | sleep | 结论 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Dog | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass |
| Pufferfish | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass |
| Squirrel | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass |
| Hamster | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass |
| Cat | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass |
| Rabbit | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass |
| Clownfish | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass | Pass |

## 备注

- 所有主题都保持同一角色身份、相近比例和一致的视觉风格。
- `done`、`issues`、`petting` 等状态存在轻量反馈元素，但未发现遮挡主体、污染透明背景或破坏状态阅读的问题。
- `stretch`、`yawn`、`sleep` 状态有预期的姿态变化和横向/纵向轮廓变化；未发现由帧处理导致的明显尺寸跳变。
- 本记录只覆盖当前 bundled themes。未来新增、替换或重绘主题时，需要重新生成本目录下对应 QA 产物并更新本记录。

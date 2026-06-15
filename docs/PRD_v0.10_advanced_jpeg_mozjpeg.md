# ImagePet PRD v0.10: Advanced JPEG 与 mozjpeg

## 1. 版本定位

v0.9 已经把 ImagePet 从基础本地压缩工具推进到：

- 支持 `JPG / JPEG / PNG / HEIC / WebP` 输入。
- 支持 `Original / JPEG / PNG / HEIC / WebP` 输出。
- 支持自定义质量、WebP capability gate、输出变大 skipped、Overwrite 禁止格式转换。
- 已引入第一条非系统 codec 路径：Swift-WebP / libwebp。

v0.10 的核心价值是：

```text
在不扩大格式范围的前提下，让 JPEG 输出获得更好的体积/视觉质量比。
```

v0.10 不应该变成通用 codec 插件系统，也不应该引入一组专业 JPEG 参数面板。用户可理解的产品承诺只有一个：

```text
JPEG 输出可以选择 Advanced JPEG，通常更小，仍然兼容普通浏览器和图片查看器。
```

## 2. 我的理解

Advanced JPEG 的价值不是“多一个编码器”，而是补齐 ImagePet 最常见的现实场景：

- 用户把 iPhone HEIC / PNG / WebP 转成 JPEG 给网站、CMS、邮件或旧系统使用。
- 用户保留 JPEG 格式，但希望比系统 ImageIO JPEG 更小。
- 用户不想理解 trellis、progressive scan、quantization table、chroma subsampling 等 codec 术语。

因此 v0.10 的正确产品形态是：

- 一个清晰的 JPEG 输出增强选项。
- 一个可关闭、可隐藏、可回退的 mozjpeg capability gate。
- 一套严格的 dependency / license / notarization 治理。
- 一组 benchmark fixture 证明它值得引入。

不应该做：

- 不把所有 JPEG 参数暴露给用户。
- 不做目标文件大小。
- 不做批量试算多质量档。
- 不允许用户选择外部 `cjpeg` / `jpegtran` 路径。
- 不把 WebP、HEIC、PNG 的实现顺手重构成插件体系。

## 3. 最终范围

### P0

- Advanced JPEG toggle，仅影响 JPEG 输出。
- mozjpeg dependency spike。
- `MozJPEGEncodingEngine`，只负责写入 compressor 提供的 temporary URL。
- JPEG encoder capability gate。
- Third Party Notices 扩展，覆盖 mozjpeg、libjpeg-turbo license roll-up、IJG attribution 和 zlib/SIMD 相关许可。
- Universal macOS build 验证：arm64 + x86_64。
- App Sandbox、codesign、notarization smoke。
- Benchmark fixtures：ImageIO JPEG vs Advanced JPEG。
- 输出变大仍然 skipped。
- Overwrite Original 继续禁止格式转换。

### P1 / v0.10.x

- Advanced JPEG 在 Overwrite Original 模式下启用的产品评估。
- Lossless JPEG optimize / `jpegtran` path spike。
- 更细的 progressive / baseline 兼容性策略。
- 安全更新自动检查。
- 可视质量回归 fixture 扩展。

### v1.0+

- 通用 `ImageEncodingEngine` protocol / composite routing。
- 多 codec policy engine。
- 目标文件大小。
- JPEG XL / AVIF。
- 专业 JPEG 参数面板。

## 4. 非目标

v0.10 明确不做：

- 新增输入或输出格式。
- AVIF、JPEG XL、GIF、PDF、TIFF。
- WebP lossless。
- 目标文件大小，例如“压到 500 KB 以下”。
- 暴露 trellis、scan optimization、quantization table、arithmetic coding、subsampling 等高级参数。
- 运行时下载 codec、插件或二进制。
- 用户自定义外部 `mozjpeg`、`cjpeg`、`jpegtran` 路径。
- 依赖 Homebrew、MacPorts 或系统已安装命令。
- 把 `ImageCompressor` 保存事务交给 encoder。
- 在 v0.10 首发中实现完整 encoder plugin abstraction。

## 5. Phase 0 Dependency Spike 与决策门

v0.10 必须先证明 mozjpeg 可以稳定进入 macOS app 构建链，再进入产品实现。

### 5.1 候选路线

首选路线：

```text
SwiftPM package awxkee/mozjpeg.swift -> bundled libturbojpeg.xcframework -> ImagePet MozJPEGEncodingEngine
```

理由：

- 不依赖用户机器上的 Homebrew。
- 不在运行时下载任何 codec。
- 通过 SwiftPM 锁定版本和 revision。
- 仓库内已包含 macOS arm64+x86_64 的 `libturbojpeg.xcframework`。
- ImagePet 可以复用 package wrapper，同时保留自己的 capability gate、integration tests 和 notice 治理。

备选路线：

```text
upstream mozjpeg source -> reproducible local build script -> static universal XCFramework -> Swift wrapper
```

备选路线只在 `mozjpeg.swift` 不满足发布要求时启用。进入实现前必须满足：

- 版本仍在维护。
- 能明确追踪到底层 mozjpeg/libjpeg-turbo 版本。
- 能生成或提供 macOS universal binary。
- License notice 可完整归档。
- 不引入 CocoaPods 作为新构建系统。
- 不提交来源不清的二进制产物。

明确不接受：

- 运行时调用 `/opt/homebrew/bin/cjpeg`。
- 让用户安装 `mozjpeg`。
- CI 或正常 Xcode build 依赖未锁定的系统全局工具。
- 只提交一个来源不清的 `.a` 或 `.dylib`。

### 5.2 Spike 必须验证

- mozjpeg source version / tag 已固定。
- source archive checksum 已记录。
- 构建产物为 macOS universal static library 或 XCFramework。
- arm64 本机运行通过。
- x86_64 slice 存在，`lipo -info` 或 `file` 可验证。
- App Sandbox 内可调用 encode。
- Debug codesign 后可运行。
- Developer ID / Hardened Runtime / notarization smoke 不因 mozjpeg 失败。
- `swift test`、`xcodebuild ... test`、`./script/build_and_run.sh --verify` 通过。
- `docs/THIRD_PARTY_NOTICES.md` 覆盖全部新增第三方组件和必要 attribution。
- 没有新增网络访问、临时外部进程调用或用户目录写入。

### 5.3 依赖快照

截至 2026-06-15 的外部信息：

- `awxkee/mozjpeg.swift` 最新 release 为 `1.1.3`，Package.swift 使用 Swift tools 5.6，声明支持 macOS 11、iOS 12 和 Mac Catalyst 14。
- `mozjpeg.swift` 的 package product 为 `mozjpeg`，内部依赖 `mozjpegc` target 和本地 binaryTarget `libturbojpeg.xcframework`。
- `libturbojpeg.xcframework` 包含 macOS `arm64` + `x86_64` 静态库 slice。
- `mozjpeg.swift` README 的 TODO 仍写有 file handling 和 tests，因此 ImagePet 不能只依赖上游测试结论，必须保留自己的 encode/decode integration tests。
- `mozilla/mozjpeg` README 描述其目标是提升 JPEG 压缩效率，同时保持 JPEG 标准兼容和主流 decoder 兼容。
- mozjpeg 是基于 libjpeg-turbo 的 patch，兼容 libjpeg API / ABI，官方建议图形程序链接 library，而不是把 demo `cjpeg` 当严肃集成方式。
- GitHub releases 页面显示最新 release 为 `v4.1.1`，发布日期为 2022-08-15，说明更新到 libjpeg-turbo `2.1.3`。
- mozjpeg / libjpeg-turbo license roll-up 包含 IJG License、Modified BSD License；SIMD 源码还涉及 zlib license，但在 license roll-up 中说明其分发条件关系。
- license 文档明确二进制分发或静态链接时，产品文档必须包含 IJG attribution：

```text
This software is based in part on the work of the Independent JPEG Group.
```

该快照只用于 v0.10 PRD 评估。真正发布前必须以本仓库 spike 记录和锁定版本为准。

### 5.4 Spike 记录模板

```text
macOS version:
hardware / runner:
Swift / Xcode version:
mozjpeg version / tag:
mozjpeg revision:
libjpeg-turbo base version:
source URL:
source checksum:
build method:
build script path:
artifact path:
architectures:
SPM / Xcode integration:
swift test:
xcodebuild test:
app sandbox smoke:
codesign smoke:
notarization smoke:
ImageIO JPEG baseline benchmark:
Advanced JPEG benchmark:
visual fixture review:
Third Party Notices:
notes:
```

### 5.5 决策结果

Spike 后只能进入以下方案之一：

#### 方案 A: mozjpeg 可发布

- v0.10 引入 Advanced JPEG。
- mozjpeg 作为 JPEG 输出的可选 encoder。
- Advanced JPEG 通过 capability gate 显示。
- dependency、license、binary、codesign、notarization smoke 全部进入发布检查。

#### 方案 B: mozjpeg 构建风险过高

- v0.10 不发布 Advanced JPEG。
- 保留 PRD 和 spike 结果。
- 可以只发布 benchmark fixture / notice 体系 / 内部 encoder seam，不暴露 UI。
- 不用半成品二进制污染主 app。

## 6. 产品行为

### 6.1 Advanced JPEG 控件

Advanced JPEG 只在以下条件同时满足时显示：

- 当前输出格式会解析为 JPEG。
- mozjpeg write capability 可用。
- 当前保存模式不是 Overwrite Original。

v0.10 首发建议不在 Overwrite Original 中启用 Advanced JPEG。原因：

- Advanced JPEG 是新增 native dependency path。
- Overwrite Original 是破坏性保存模式。
- 先让 Advanced JPEG 在非覆盖输出中稳定，再评估是否进入覆盖原图路径。

UI 文案建议：

```text
Advanced JPEG
Smaller JPEG output for web sharing.
```

如果 capability 不可用，不显示该控件。不要显示一个永久 disabled 的专业选项。

### 6.2 Quality 行为

v0.10 继续使用 v0.9 的 quality model：

- High。
- Balanced。
- Small。
- Custom 30...95。

Advanced JPEG 不新增第二套 quality 控件。它只改变 JPEG encoder implementation。

映射原则：

- `CompressionQuality` 继续输出 0.30...0.95 的质量。
- mozjpeg wrapper 内部转换为 30...95 的 integer quality。
- 不因为 Advanced JPEG 自动改变用户选择的 quality。

### 6.3 Output Format 行为

Advanced JPEG 只影响最终 output format 为 JPEG 的 job：

- Output Format = JPEG。
- Output Format = Original 且源格式为 JPEG。

v0.10 首发不影响：

- PNG 输出。
- HEIC 输出。
- WebP 输出。
- Original 且源格式不是 JPEG。

### 6.4 Skipped 行为

保留 v0.9 统一策略：

```text
任何格式输出大于输入，默认 skipped。
```

Advanced JPEG 不能绕过该策略。

用户可见 reason 沿用：

```text
Skipped: output would be larger than source
```

v0.10 不新增“允许输出更大文件”开关。

### 6.5 Compatibility 行为

Advanced JPEG 输出必须是普通 JPEG 文件：

- Preview 可打开。
- Safari 可打开。
- Chrome 可打开。
- ImageIO 可重新 decode。
- 文件扩展名仍为 `.jpg`。
- UTType 仍为 JPEG。

如果 progressive JPEG 在某些 fixture 或系统版本存在兼容风险，v0.10 应优先选择 conservative settings，而不是追求最大压缩率。

## 7. 架构边界

### 7.1 Core 选项

建议新增：

```swift
public enum JPEGEncodingMode: String, Sendable, Equatable, Codable {
    case standard
    case advanced
}
```

`CompressionOptions` 可以新增：

```swift
public var jpegEncodingMode: JPEGEncodingMode
```

这属于 encoder 行为，放在 `CompressionOptions` 内合理。

不要把以下字段塞进 `CompressionOptions`：

- 保存位置。
- 后缀。
- overwrite policy。
- UI 展开状态。
- benchmark/debug flag。

### 7.2 Capability

建议扩展 `EncoderCapabilities`：

```swift
public var jpegEncodingModes: Set<JPEGEncodingMode>
```

基础能力：

- `.standard` 永远代表 ImageIO JPEG 可用。
- `.advanced` 只有 mozjpeg smoke 通过后才出现。

不要用一个全局 `supportsAdvancedJPEG: Bool` 替代 per-format/per-mode capability。v0.9 已经证明 read/write/capability gate 需要可测试、可注入。

### 7.3 Engine 边界

新增：

```swift
public struct MozJPEGEncodingEngine: Sendable {
    public func encode(
        image: CGImage,
        metadata: ImageSourceMetadata,
        quality: CompressionQuality,
        destinationTemporaryURL: URL
    ) throws
}
```

约束：

- `MozJPEGEncodingEngine` 只能写入 `destinationTemporaryURL`。
- 不能决定最终文件名。
- 不能覆盖原文件。
- 不能移动文件。
- 不能读取 UserDefaults。
- 不能弹 UI。
- 不能调用外部 command-line tool。

`ImageCompressor` 仍然负责：

- 输入权限和读取。
- decode / transform。
- temporary URL 分配。
- 输出变大检查。
- move / replace。
- save options。
- job result。

### 7.4 Decode 与颜色

v0.10 不用 mozjpeg 接管 decode。

Decode 继续由 ImageIO / 现有 WebP path 负责，然后统一渲染为 JPEG encoder 输入。Advanced JPEG 的输入应是明确的 pixel buffer：

- 标准 sRGB。
- 无 alpha。
- orientation 已应用或由现有 metadata strategy 处理。
- alpha 输入输出 JPEG 时继续按既有白底/不透明策略处理，不新增透明 JPEG 概念。

### 7.5 最小抽象

v0.10 可以有两个 JPEG encode path：

```text
ImageIO JPEG encode
MozJPEG encode
```

但不需要立刻做全格式 plugin system。

允许的最小 routing：

```swift
if outputFormat == .jpeg && options.jpegEncodingMode == .advanced {
    try mozJPEGEncodingEngine.encode(...)
} else {
    try writeWithImageIO(...)
}
```

只有当 v1.0 继续引入更多 native engines 时，再抽通用 protocol。

## 8. Third Party Notices 扩展

v0.10 必须扩展 `docs/THIRD_PARTY_NOTICES.md`，并把 notice 完整性列为发布阻断项。

新增条目至少包括：

### mozjpeg

- Library: `mozjpeg`
- Version / tag。
- Revision。
- Source URL。
- Source checksum。
- Build method。
- Artifact path。
- Linked as static library or XCFramework。
- License summary。

### libjpeg-turbo base

- Upstream relationship。
- Base version。
- License roll-up URL。
- IJG License notice requirement。
- Modified BSD License text。
- zlib/SIMD note if SIMD source is included。

### Required attribution

必须包含：

```text
This software is based in part on the work of the Independent JPEG Group.
```

### Binary governance

Notices 里必须记录：

- 是否静态链接。
- 是否包含 SIMD。
- 是否包含 command-line tools。
- 是否包含 dynamic library。
- 是否修改 upstream source。
- 如果修改 source，修改点和 patch path。

v0.10 不应把 `cjpeg`、`jpegtran`、`djpeg` 等命令行工具打包进 app，除非 PRD 另行升级并解释 sandbox/codesign/notarization 影响。

## 9. Build、Signing 与 Sandbox

### 9.1 Build 产物

可接受的产物：

- `Vendor/MozJPEG/MozJPEG.xcframework`。
- 或等价的静态 library + module map + headers，并由 Xcode project 明确引用。

必须验证：

```bash
lipo -info ...
file ...
otool -L ...
codesign --verify ...
```

如果采用静态链接，`otool -L` 不应出现未预期的 `libjpeg.dylib` 或外部 dylib 依赖。

### 9.2 Sandbox

Advanced JPEG 不改变 entitlements：

```text
com.apple.security.app-sandbox = true
com.apple.security.files.user-selected.read-write = true
```

不新增：

- network entitlement。
- downloads folder entitlement。
- automation entitlement。
- external executable exception。

### 9.3 Notarization

v0.10 发布前必须完成至少一次 Developer ID / notarization smoke。原因是 mozjpeg 引入 native binary，Debug adhoc codesign 不能替代发布验证。

## 10. Benchmark 与验收

### 10.1 Benchmark fixture

至少覆盖：

- 5 张 iPhone HEIC 转 JPEG。
- 5 张已压缩 JPEG 再输出 JPEG。
- 5 张 PNG screenshot / UI image 转 JPEG。
- 5 张高细节照片。
- 2 张带 EXIF orientation 的照片。
- 2 张含 alpha 的 PNG 转 JPEG。

所有 fixture 不提交到仓库，除非使用可再分发的小型合成 fixture。

### 10.2 指标

Advanced JPEG 必须和 ImageIO JPEG baseline 比较：

| 指标 | P0 验收 |
| --- | --- |
| 文件体积 | 同 quality 下，测试集总输出体积不大于 ImageIO baseline；目标是至少 5% median saving |
| 兼容性 | Preview / Safari / Chrome / ImageIO decode 通过 |
| 性能 | Apple Silicon 本机批量 wall-clock 不超过 ImageIO JPEG 3x；硬上限 60 秒 / 20 张 12MP 图片 |
| 内存 | 不超过既有性能测试上限 1.5GB |
| 稳定性 | 单图失败不影响批次 |
| 回退 | mozjpeg capability 不可用时 UI 隐藏 Advanced JPEG，标准 JPEG 仍可用 |

如果体积收益低于 5% median saving，v0.10 不应默认推荐 Advanced JPEG；可以作为隐藏实验或推迟。

### 10.3 视觉检查

v0.10 不做复杂感知质量评分系统，但必须有人工视觉检查清单：

- 大面积渐变。
- 文字 / UI screenshot。
- 人像肤色。
- 高细节树叶 / 建筑。
- 暗部噪声。
- 红色和蓝色饱和区域。

## 11. 测试计划

### Unit Tests

- `CompressionOptions` 默认 `jpegEncodingMode == .standard`。
- Advanced JPEG 只对 JPEG output 生效。
- Output Format = Original + JPEG input 时可选择 Advanced JPEG。
- Output Format = Original + PNG/HEIC/WebP input 时忽略 Advanced JPEG。
- capability 没有 `.advanced` 时，store 不显示 Advanced JPEG。
- 保存的 Advanced JPEG 偏好在 capability 不可用时只做内存回退，不写坏 UserDefaults。
- 输出变大仍 skipped。
- encoder 只写 temporary URL。
- mozjpeg encode 失败映射为短错误信息。
- non-overwrite 输出命名仍不覆盖已有文件。

### Integration Tests

- HEIC -> JPEG standard。
- HEIC -> JPEG advanced。
- JPEG -> JPEG advanced。
- PNG alpha -> JPEG advanced。
- WebP -> JPEG advanced。
- Advanced JPEG output 可被 ImageIO 重新 decode。
- Advanced JPEG output extension / UTType 正确。
- Advanced JPEG capability smoke 可注入 false。

### UI Tests

- JPEG 输出时显示 Advanced JPEG toggle。
- WebP/PNG/HEIC 输出时不显示 Advanced JPEG toggle。
- capability 不可用时不显示 Advanced JPEG toggle。
- Overwrite Original 时 v0.10 首发不显示 Advanced JPEG toggle。
- Custom Quality + Advanced JPEG 同时工作。
- Job skipped 时显示 `Skipped: output would be larger than source`。

### Manual Tests

- Preview 打开输出 JPEG。
- Safari 打开输出 JPEG。
- Chrome 打开输出 JPEG。
- Finder Quick Look 预览。
- `./script/build_and_run.sh --verify`。
- Developer ID / notarization smoke。

## 12. UI 草图

非覆盖模式，JPEG 输出：

```text
Quality
[ High | Balanced | Small | Custom ]

Output Format
[ Original | JPEG | PNG | HEIC | WebP ]

[x] Advanced JPEG
    Smaller JPEG output for web sharing.
```

Custom mode：

```text
[ Custom ]  Quality 82
[--------------------]

[x] Advanced JPEG
```

PNG / HEIC / WebP 输出：

```text
Advanced JPEG hidden
```

Overwrite Original：

```text
Advanced JPEG hidden in v0.10
```

## 13. Rollout 与回退

### Rollout

- 默认 `jpegEncodingMode = .standard`。
- 用户手动打开 Advanced JPEG。
- 保存用户偏好。
- capability 不可用时内存回退到 `.standard`，不清除用户偏好。

### 回退

如果 mozjpeg 在部分机器失败：

- UI 隐藏 Advanced JPEG。
- 标准 JPEG 路径继续可用。
- 已保存偏好不导致崩溃。
- Core 测试可注入 capability false。

如果发布后发现 Advanced JPEG 风险：

- 通过 capability gate 下线。
- 不影响 WebP / PNG / HEIC / standard JPEG。
- Third Party Notices 保留到移除依赖后的版本。

## 14. 发布阻断清单

- Phase 0 mozjpeg dependency spike 完成并记录。
- mozjpeg source / revision / checksum 已锁定。
- Universal binary 验证通过。
- App Sandbox 不新增权限。
- Debug codesign smoke 通过。
- Developer ID / notarization smoke 通过。
- `docs/THIRD_PARTY_NOTICES.md` 完整扩展。
- `swift test` 通过。
- `xcodebuild ... test` 通过。
- `./script/build_and_run.sh --verify` 通过。
- Benchmark 证明 Advanced JPEG 相对 ImageIO baseline 有实际收益。
- Preview / Safari / Chrome / ImageIO decode 验证通过。
- 输出变大 skipped 覆盖 Advanced JPEG。
- Overwrite Original 不暴露 Advanced JPEG，除非 PRD 明确升级。

## 15. 参考资料

- [mozjpeg README](https://github.com/mozilla/mozjpeg)
- [mozjpeg releases](https://github.com/mozilla/mozjpeg/releases)
- [mozjpeg BUILDING](https://github.com/mozilla/mozjpeg/blob/master/BUILDING.md)
- [mozjpeg / libjpeg-turbo LICENSE](https://github.com/mozilla/mozjpeg/blob/master/LICENSE.md)
- [libjpeg-turbo documentation](https://libjpeg-turbo.org/)

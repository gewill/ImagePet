# ImagePet MVP PRD v0.2

## 定位

ImagePet 是一个 macOS 本地图片压缩小工具。

核心 workflow：

```text
拖图片进去 -> 小宠物吃掉 -> 本地压缩 -> 输出更小 JPG -> 显示节省体积
```

第一版只解决一个问题：批量把图片压缩成更小的 JPG。

## 目标系统

- macOS 13 Ventura+
- SwiftUI
- App Sandbox enabled
- Distribution: Developer ID notarized first, Mac App Store later optional

## MVP 范围

### 支持输入

- JPG / JPEG
- PNG
- HEIC

### 输出格式

第一版只输出：

- JPG

暂不支持 WebP / AVIF，避免 ImageIO 写入兼容性和色彩问题。

## 核心功能

- 拖拽图片到窗口
- 通过 `Add Images` 选择图片，作为拖拽之外的桌面入口
- 支持批量图片
- 支持选择输出目录
- 支持 3 个压缩预设：
  - High: quality 0.9
  - Balanced: quality 0.8
  - Small: quality 0.65
- 显示每张图：
  - 原始大小
  - 输出大小
  - 节省比例
  - 状态
  - 错误原因
- 显示总计：
  - Ate: 原始总大小
  - Pooped: 输出总大小
  - Saved: 节省大小和比例
- 不覆盖原文件
- 全程本地处理，不上传

## 暂不做

- WebP
- AVIF
- Finder Extension
- Raycast Extension
- Shortcuts
- 文件夹监听
- AI 格式判断
- 裁剪
- 水印
- PDF
- 登录 / 订阅 / 云同步

## Sandbox & 权限策略

必须开启 App Sandbox。

Entitlements：

```text
com.apple.security.app-sandbox = true
com.apple.security.files.user-selected.read-write = true
```

输入文件：

- 通过拖拽进入 App 的文件，使用 drag session 提供的 security-scoped URL。
- 处理每个文件前调用：

```swift
let access = url.startAccessingSecurityScopedResource()
defer {
    if access {
        url.stopAccessingSecurityScopedResource()
    }
}
```

输出目录：

- 首次启动时要求用户选择输出目录。
- 使用 `NSOpenPanel`，只允许选择目录。
- 保存 security-scoped bookmark 到 `UserDefaults` / `AppStorage`。
- 每次启动恢复 bookmark。
- 如果 bookmark 失效，要求用户重新选择目录。

默认建议目录名：

```text
ImagePet Output
```

但不要默认直接写入 `~/Pictures/ImagePet/`，除非用户授权。

## 内存与并发策略

图片处理必须限制并发。

第一版要求：

```text
maxConcurrentJobs = 2
```

每张图的解码、压缩、写入必须包裹：

```swift
autoreleasepool {
    // decode / encode image
}
```

禁止把所有任务一次性丢进无限并发 `TaskGroup`。

处理策略：

- 批量任务排队
- 最多 2 张同时处理
- 每张完成后立即释放中间对象
- 每张完成后即时更新 UI

## 色彩与 HEIC 策略

第一版输出统一转为 sRGB JPG。

要求：

- 读取 HEIC / PNG / JPG 时保留基本方向信息。
- 输出 JPG 时使用 sRGB。
- 避免保留 HDR 作为 MVP 目标。
- 如果检测到 HDR / wide-gamut 资源，可接受转换到 sRGB，但不得崩溃。
- UI 可显示轻提示：

```text
HDR or wide-gamut images will be exported as standard sRGB JPG.
```

第一版目标是稳定压缩，不追求专业级 HDR 保真。

## 文件名规则

输出文件名：

```text
{originalNameWithoutExtension}-{inputExtension}_compressed.jpg
```

如果同一批次或磁盘已有冲突：

```text
{originalNameWithoutExtension}-{inputExtension}_compressed-2.jpg
{originalNameWithoutExtension}-{inputExtension}_compressed-3.jpg
```

示例：

```text
photo.heic -> photo-heic_compressed.jpg
photo.png  -> photo-png_compressed.jpg
photo.jpg  -> photo-jpg_compressed.jpg
```

永远不覆盖已有文件。

## 任务模型

```swift
struct ImageJob: Identifiable, Equatable {
    let id: UUID
    let inputURL: URL
    var outputURL: URL?
    var originalSize: Int64
    var compressedSize: Int64?
    var status: JobStatus
    var errorMessage: String?
}

enum JobStatus: Equatable {
    case pending
    case processing
    case done
    case failed
}

enum CompressionPreset: String, CaseIterable {
    case high
    case balanced
    case small

    var quality: Double {
        switch self {
        case .high: return 0.9
        case .balanced: return 0.8
        case .small: return 0.65
        }
    }
}

enum PetState {
    case idle
    case eating
    case happy
    case error
}
```

## 压缩服务接口

```swift
protocol ImageCompressing {
    func compress(
        inputURL: URL,
        outputDirectory: URL,
        preset: CompressionPreset
    ) async throws -> CompressionResult
}

struct CompressionResult {
    let inputURL: URL
    let outputURL: URL
    let originalSize: Int64
    let compressedSize: Int64
}
```

## UI 状态

### Idle

```text
🐡
Drop images here
Eat more, poop less.
Quality: Balanced
Output: JPG
Output Folder: [Choose Folder]
```

### Processing

```text
😋 nom nom nom...
Processing 8 / 24
```

下方显示任务列表：

```text
filename.heic    Processing...
filename.png     Done  4.2 MB -> 680 KB
broken.heic      Failed: Unsupported image
```

### Completed 全部成功

```text
🥳 Done!
Ate: 128.4 MB
Pooped: 18.7 MB
Saved: 109.7 MB / 85.4%
[Reveal in Finder]
[Clear List]
```

### Completed 部分失败

```text
😵 Done with issues
17 succeeded, 3 failed
Ate: 128.4 MB
Pooped: 21.3 MB
Saved: 107.1 MB / 83.4%
[Reveal in Finder]
[Retry Failed]
[Clear List]
```

## 宠物状态机

| 当前状态 | 触发条件 | 下一个状态 |
| --- | --- | --- |
| idle | 用户拖入图片且开始处理 | eating |
| eating | 全部成功 | happy |
| eating | 部分或全部失败 | error |
| happy | 用户点击 Clear List | idle |
| error | 用户点击 Clear List | idle |
| error | 用户点击 Retry Failed | eating |

`happy` 不自动消失，直到用户点击 `Clear List`。

## 按钮行为

### Reveal in Finder

打开输出目录。

### Clear List

- 清空任务队列
- 保留上次设置：
  - quality
  - output directory
- 回到 idle 状态
- 如果输出目录 bookmark 失效，提示重新选择

### Retry Failed

- 只重新处理失败任务
- 成功任务不重复处理
- 保留原设置

## 错误处理

每张图失败时不得中断整个批次。

常见错误映射：

- Unsupported image format
- Permission denied
- Output folder unavailable
- Failed to decode image
- Failed to write output file
- Not enough disk space
- Unknown error

UI 必须显示失败文件名和简短原因。

## 性能验收

测试集：

- 20 张 12MP iPhone HEIC
- Balanced preset
- 输出 JPG
- Apple Silicon Mac

目标：

- 30 秒内完成
- App 内存峰值低于 1.5GB
- 失败不崩溃

## 第一版完成标准

作者自己可以完成：

```text
拖入或通过 Add Images 选择 20 张 iPhone HEIC / PNG / JPG
-> 选择 Balanced
-> 输出 JPG 到授权目录
-> 看到每张图压缩结果
-> 看到总共节省多少空间
-> Reveal in Finder 查看结果
```

第一版不追求格式多，不追求动画复杂，不追求极限压缩率。

目标只有一个：

```text
做一个可爱、稳定、顺手的本地 JPG 压缩 workflow。
```

关键边界：

- 第一版别碰 WebP
- 第一版别碰默认写 Pictures
- 第一版别无限并发

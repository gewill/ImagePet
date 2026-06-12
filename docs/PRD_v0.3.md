# ImagePet PRD v0.3: Core Extension & Advanced Customization

## 1. 概述与设计目标

ImagePet 在 v0.2 (MVP) 阶段成功建立了**“拖拽 - 压缩 - 输出 JPG - 宠物吞吐”**的基础流程，并通过了并发与内存压力测试。

在 **v0.3** 版本中，ImagePet 的核心目标是**从 MVP 走向实用性更强、更灵活的专业级本地图片处理小工具**。我们将着重扩展以下三个维度的能力：
1. **联动性增强**：实现桌面宠物小浮窗与主应用主界面的无缝双向激活。
2. **灵活的输出策略**：支持多种目标格式（包括原格式、PNG、HEIC、JPEG），并提供原路径保存、覆盖原图、自定义文件后缀等多样化存储选项。
3. **极限体积优化**：探索并集成更深入的 JPEG 本地压缩手段（包括元数据剥离、尺寸上限缩放等），在保留画质的同时进一步缩减文件体积。

---

## 2. 核心功能需求

### 功能一：桌面宠物快速返回主 App
*   **背景**：用户在桌面上拖拽压缩时，可能需要调整预设、查看历史任务详情，或管理输出路径，当前只能手动在 Dock 栏或 Launchpad 中寻找主应用窗口。
*   **设计方案**：
    *   在桌面宠物浮窗 (`DesktopPetView`) 的底部操作区，增加一个**“返回主应用”**按钮。
    *   **图标**：使用 `macwindow` 或 `arrow.up.right.square` 系统图标。
    *   **交互行为**：
        1. 点击按钮后，调用 `NSApp.activate(ignoringOtherApps: true)`。
        2. 如果主窗口已被关闭，利用 SwiftUI 的 `openWindow(id: "main")` 重新实例化并显示主窗口。
        3. 如果主窗口已在后台或被最小化，直接将其带回最前（Focus）。
    *   **快捷键支持**：在主应用处于激活状态下，支持 `⌘ + 1` 在主界面和宠物浮窗间快速切换。

---

### 功能二：指定输出格式（支持多种格式输出）
*   **背景**：v0.2 强制将所有输入统一转为 `.jpg`，这导致 PNG 图像失去透明通道，HEIC 图像失去高效率编码优势。
*   **设计方案**：
    *   在主界面的控制区增加 **Output Format (输出格式)** 选择器。
    *   **可选格式**：
        1.  **Original (原格式 - 默认)**：输入什么格式，就输出什么格式（如 PNG 进，PNG 出）。
        2.  **JPEG (.jpg)**：适合兼容性要求高的场景。
        3.  **PNG (.png)**：无损压缩，保留透明度通道。
        4.  **HEIC (.heic)**：高压缩比，适合苹果生态链。
    *   **压缩适配逻辑**：
        *   **JPEG / HEIC**：属于有损格式，在压缩时应用 Quality 预设（High: 0.9, Balanced: 0.8, Small: 0.65）传参给 ImageIO 编码器。
        *   **PNG**：属于无损格式。当用户选择 PNG 格式时，**UI 上的 Quality Segment Control 应自动置灰并显示提示 `PNG uses lossless compression`**。压缩引擎通过移除不必要的数据块（如 ICC Profile, Metadata）来进行体积压缩。
        *   **原格式模式**：根据每个输入文件的原始 UTType 动态匹配其对应的编码与 Quality 逻辑。

---

### 功能三：自定义保存路径与文件后缀

#### 1. 保存路径模式 (Output Location Modes)
用户可以在设置/控制区选择三种保存路径：
1.  **Designated Folder (指定文件夹 - 默认)**：输出到用户统一选定的授权文件夹（同 v0.2）。
2.  **Original Folder (保存到原文件夹)**：将压缩后的文件直接输出到输入文件所在的目录中。
3.  **Overwrite Original (直接覆盖原文件)**：直接覆盖输入的源文件。

> [!CAUTION]
> **直接覆盖原文件 (Overwrite)** 是破坏性操作。
> - 在用户切换到此模式时，主界面和设置项中应显示醒目的**红色警告图标与文本**。
> - 首次在覆盖模式下启动压缩时，必须弹出**二次确认弹窗**：`"Are you sure you want to overwrite the original images? This action cannot be undone."`

#### 2. 沙盒与权限处理策略 (Sandbox & Permissions)
在 App Sandbox 启用的状态下，将文件写入“原文件夹”或“覆盖原文件”存在不同的权限限制：
*   **直接覆盖原文件**：用户拖入/选择输入文件时，系统已赋予了对该特定文件 URL 的 read-write 权限，因此**直接覆盖在沙盒内是安全的，无需额外授权**。
*   **保存到原文件夹（创建新文件）**：拖入 `photo.jpg` 时，App 只有该文件的读写权，**没有其父目录的写入权**。
    *   **自动提权机制**：若 App 检测到没有父目录的写权限，在开始处理时自动弹出系统 `NSOpenPanel` 指向该父目录，提示用户：`"ImagePet needs permission to write new files to the original folder."`。用户点击授权（Open）后，App 获得该文件夹权限，并将其安全书签记录，避免重复弹窗。
    *   **父目录合并授权**：如果批量任务中的多张图片属于同一个文件夹，仅在第一张图处理时弹窗一次，后续自动复用权限。

#### 3. 非覆盖模式下的自定义后缀 (Filename Suffix)
当选择“指定文件夹”或“保存到原文件夹”（非覆盖）时，允许用户自定义输出文件后缀。
*   **配置项**：文本输入框 `Filename Suffix`（字符限制：仅允许字母、数字、下划线和连字符）。默认值为 `_compressed`。
*   **实时命名预览 (Live Preview)**：
    *   在后缀输入框下方，提供一个动态变化的示例展示，根据当前选择的**输出格式**和**后缀文本**实时更新。
    *   **示例效果**：
        *   *配置*：输出格式 = `JPEG`，后缀 = `_min`。
        *   *预览*：`photo.png` $\rightarrow$ `photo_min.jpg`
        *   *配置*：输出格式 = `Original`，后缀 = `_shrunk`。
        *   *预览*：`my_pic.heic` $\rightarrow$ `my_pic_shrunk.heic`
        *   *配置*：输出格式 = `PNG`，后缀 = `(无后缀)`。
        *   *预览*：`avatar.png` $\rightarrow$ `avatar.png` (如果目标文件夹存在同名文件，自动追加数字，如 `avatar-2.png`)。

---

### 功能四：极限 JPEG 压缩技术探索 (JPEG Optimization)
为了在不牺牲画质的前提下追求极致的压缩率，v0.3 引入以下两项本地优化手段：

#### 1. 深度元数据剥离 (Deep Metadata Stripping)
*   **技术细节**：默认情况下，iPhone 拍摄的照片包含丰富的 EXIF、TIFF、GPS 以及彩色 ICC Profile 等元数据。这些数据块在小分辨率图片中占比可达 10% - 50%（约 10KB - 150KB）。
*   **设计方案**：
    *   在设置中增加一个 Switch 开关：`[x] Strip Metadata (移除元数据)`，默认**开启**。
    *   **开启时**：在 ImageIO 写入 JPEG 时，不复制源文件的 Metadata Dictionary。只保留对显示至关重要的色彩空间信息 (sRGB) 以及已经旋转校正过的图像方向。
    *   **关闭时**：压缩时尽量保留源 EXIF 数据。

#### 2. 最大边长尺寸缩放 (Long-edge Constraint / Downscaling)
*   **技术细节**：日常分享到网页或社群的图片，往往不需要 4K 或 1200 万像素以上的超高分辨率。在解码阶段进行等比例缩放是降低体积最快捷、最有效的手段。
*   **设计方案**：
    *   在主界面提供 `Max Edge (最大边长限制)` 选择器：
        *   `No Resize (不限尺寸 - 默认)`
        *   `1024 px` (轻量分享)
        *   `1920 px` (全高清 Web)
        *   `2048 px` (平板高清)
        *   `3840 px` (4K 演示)
    *   **极致性能实现**：使用 `CGImageSourceCreateThumbnailAtIndex` 的 `kCGImageSourceThumbnailMaxPixelSize` 属性。
        *   **优势**：在底层解码时就进行硬件加速缩放，不仅生成的小尺寸图片更加平滑，还能**极大地降低内存占用**，避免大图完全解码到内存中。

---

## 3. UI/UX 界面设计变更

### 主界面 (ContentView) 布局调整
主界面的 `ControlsView` 将划分为三个优雅的控制分区：
```text
+--------------------------------------------------------------------------------+
|  [ Preset Picker: High | Balanced | Small ]   [ Max Edge: No Resize / 1024 / 2048 ]    |
|                                                                                |
|  [ Format: Original / JPEG / PNG / HEIC ]     [ Location: Designated / Source / Overwrite ] |
|                                                                                |
|  Save Directory: /Users/.../ImagePet Output [Choose Folder]                    |
|  Suffix: [_compressed]    Example: photo.png -> photo_compressed.jpg           |
+--------------------------------------------------------------------------------+
```
1.  **置灰与联动逻辑**：
    *   如果 `Format` 选择 `PNG`：`Preset Picker` 自动置灰，下方提示 `"PNG is compressed losslessly"`.
    *   如果 `Location` 选择 `Overwrite`：`Suffix` 输入框置灰，`Save Directory` 选择按钮隐藏，并在下方显示红色警告：`"⚠️ Mode Overwrite will replace your source files directly."`

### 桌面宠物浮窗 (DesktopPetView) 布局调整
增加返回主应用按钮：
```text
+-----------------------+
|  [<- Main App]     (X)|  <-- 左上角增加主应用返回按钮，右上角保留隐藏按钮
|                       |
|          🐡           |
|      Ate: 4.8MB       |
|     Saved: 2.1MB      |
|                       |
|   [+]Add    [Folder]  |
+-----------------------+
```

---

## 4. 技术与架构设计

### 4.1 数据模型扩展

```swift
/// 输出格式枚举
public enum OutputFormat: String, CaseIterable, Identifiable, Codable {
    case original
    case jpeg
    case png
    case heic
    
    public var id: String { self.rawValue }
    
    public var displayName: String {
        switch self {
        case .original: return "Original"
        case .jpeg: return "JPEG"
        case .png: return "PNG"
        case .heic: return "HEIC"
        }
    }
}

/// 保存路径模式枚举
public enum SaveLocationMode: String, CaseIterable, Identifiable, Codable {
    case designated
    case originalFolder
    case overwrite
    
    public var id: String { self.rawValue }
    
    public var displayName: String {
        switch self {
        case .designated: return "Designated Folder"
        case .originalFolder: return "Original Folder"
        case .overwrite: return "Overwrite Original"
        }
    }
}

/// 尺寸缩放限制枚举
public enum MaxDimensionLimit: String, CaseIterable, Identifiable, Codable {
    case none
    case p1024 = "1024"
    case p1920 = "1920"
    case p2048 = "2048"
    case p3840 = "3840"
    
    public var id: String { self.rawValue }
    
    public var intValue: Int? {
        switch self {
        case .none: return nil
        case .p1024: return 1024
        case .p1920: return 1920
        case .p2048: return 2048
        case .p3840: return 3840
        }
    }
    
    public var displayName: String {
        switch self {
        case .none: return "No Resize"
        default: return "\(self.rawValue)px"
        }
    }
}

/// 完整的压缩配置选项，向下传递给 ImageCompressor
public struct CompressionOptions: Sendable, Equatable {
    public let preset: CompressionPreset
    public let format: OutputFormat
    public let locationMode: SaveLocationMode
    public let suffix: String
    public let maxDimension: MaxDimensionLimit
    public let stripMetadata: Bool
    
    public init(
        preset: CompressionPreset = .balanced,
        format: OutputFormat = .original,
        locationMode: SaveLocationMode = .designated,
        suffix: String = "_compressed",
        maxDimension: MaxDimensionLimit = .none,
        stripMetadata: Bool = true
    ) {
        self.preset = preset
        self.format = format
        self.locationMode = locationMode
        self.suffix = suffix
        self.maxDimension = maxDimension
        self.stripMetadata = stripMetadata
    }
}
```

### 4.2 核心压缩服务接口更新
`ImageCompressing` 协议需要支持传递复杂的 `CompressionOptions`。同时由于输出路径可能取决于每个文件本身，我们需要支持在压缩时动态处理写入目标。

```swift
public protocol ImageCompressing: Sendable {
    func compress(
        inputURL: URL,
        outputDirectory: URL?, // 在 overwrite 或 originalFolder 模式下可为 nil
        options: CompressionOptions
    ) async throws -> CompressionResult
}
```

---

## 5. 非功能性需求与性能指标

1.  **压缩时间**：对于 20 张 12MP 的 iPhone HEIC 图片进行 Balanced 压缩，耗时必须限制在 **25秒内**（开启缩放限制至 2048px 时，耗时应缩短至 **10秒内**）。
2.  **内存指标**：在批量压缩期间，得益于 `autoreleasepool` 和 `kCGImageSourceThumbnailMaxPixelSize` 的硬解缩放，App 内存峰值应维持在 **200MB 以下**（上限指标仍为 1.5GB）。
3.  **并发性限制**：保持 `maxConcurrentJobs = 2` 的限制，以维护多核 CPU 散热平衡与极佳的内存曲线。
4.  **鲁棒性**：
    *   在“覆盖原图”模式下，如果写入中途发生断电或崩溃，必须保证原图文件的完整性（采用“写出临时文件 $\rightarrow$ 校验成功 $\rightarrow$ 替换原图”的事务性写入方案，切忌直接截断源文件写入）。

---

## 6. 版本 0.3 交付验收标准 (Acceptance Criteria)

### 6.1 桌面宠物联动测试
*   启动应用，开启桌面宠物浮窗。
*   关闭主 App 窗口。
*   点击浮窗上的 `<- Main App` 按钮。
*   **期望结果**：主 App 界面重新弹出并处于激活（Focus）状态。

### 6.2 输出格式与后缀预览测试
*   在主界面更改输出格式为 `HEIC`，后缀为 `_shrunk`。
*   **期望结果**：下方预览区正确显示 `photo.png -> photo_shrunk.heic`。
*   拖入一张 PNG 图片，完成压缩。
*   **期望结果**：输出目录下多出后缀为 `_shrunk.heic` 的高压缩比 HEIC 图片。

### 6.3 覆盖原图与二次确认测试
*   在主界面将保存路径切换为 `Overwrite Original`。
*   **期望结果**：界面背景/前景色显示警告色，后缀输入框置灰。
*   拖入测试图片开始压缩。
*   **期望结果**：弹出模态弹窗要求用户确认风险。用户点击取消，压缩终止；用户点击确认，压缩开始，并在完成后直接替换了源文件（文件大小减少，文件名不变）。

### 6.4 元数据剥离与尺寸上限缩放测试
*   拖入 4000x3000 (12MP) 的带有 EXIF GPS 信息的照片。
*   设置 `Max Edge = 2048px`，开启 `Strip Metadata`，格式为 `JPEG`。
*   **期望结果**：
    *   压缩完成。
    *   输出图片的最长边长度精确为 `2048px`。
    *   使用 Finder 查看输出图片信息，EXIF 照相机、GPS 定位等隐私元数据已被完全清空。
    *   压缩体积相比单纯调整质量有大幅度骤减。

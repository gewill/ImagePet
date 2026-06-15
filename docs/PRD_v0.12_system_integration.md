# ImagePet PRD v0.12: 系统级集成与自动化工作流

## 1. 版本定位

ImagePet 在 v0.9-v0.11 中逐步补齐了 WebP 格式支持、Advanced JPEG/mozjpeg 引擎以及包含离线帮助中心、全局快捷键在内的 App 完整性能力。当前，应用在单一窗口拖拽、桌面 Pet 互动和常规设置方面已达到发布标准。

v0.12 的核心目标是：
```text
打破“只能手动拖拽或选择图片”的交互局限，将 ImagePet 的核心压缩引擎延伸到 macOS 系统级生态中，提供 CLI 工具、文件夹监听、Finder 快速操作和快捷指令（Shortcuts）支持，使 ImagePet 成为一个高效、自动化的后台图片处理服务。
```

v0.12 包含以下核心功能：
1. **P0: 独立 CLI 命令行工具 (`imagepet`)**：基于 `ImagePetCore` 编译，不依赖 GUI 层。支持自定义质量、预设、尺寸限制、元数据剥离、输出格式等，利用 `swift-argument-parser` 构建。
2. **P0: 文件夹监听 (Folder Watching)**：用户可在设置中添加需要监听的文件夹。当有新图片移入时，自动触发后台静默压缩并保存到指定位置。
3. **P1: Finder 快速操作 (Finder Quick Action / NSServices)**：用户在 Finder 中右键点击多张图片，可直接选择 "Compress with ImagePet" 进行一键压缩。
4. **P1: 快捷指令 (Apple Shortcuts) 动作集成**：提供原生的 macOS Shortcuts Action，支持用户在系统快捷指令中拼装图片压缩流。
5. **P2/延期候选: 自定义宠物主题导入**：支持导入 `.zip` 主题包并包含 `theme.json` 语法校验，音效自定义等。

---

## 2. 需求拆分与技术设计

### 2.1 P0：CLI 命令行工具 (`imagepet`)

- **独立编译目标**：
  - 新增 Xcode 命令行 Target `ImagePetCLI`，并同步在 `Package.swift` 中定义 `imagepet` 可执行产品（executable product）。
  - 严格依赖 `ImagePetCore`，禁止引入 AppKit/SwiftUI 的 GUI 组件。
- **参数规范**：
  - `inputs`：位置参数，支持传入一个或多个图片文件路径，或文件夹路径（递归扫描）。
  - `--output -o`：指定输出文件夹。如果不指定，则默认输出到原文件同级目录下。
  - `--preset -p`：预设模式，支持 `high`、`balanced`、`small`，默认 `balanced`。
  - `--quality -q`：自定义压缩质量 (1-100)，与预设互斥。
  - `--format -f`：输出格式，支持 `jpg`、`webp`、`png`、`heic`、`original`，默认 `jpg`（Overwrite 模式下强制 `original`）。
  - `--max-dim -m`：最大边长限制（像素值），超出则等比缩放。
  - `--keep-metadata`：显式声明保留元数据（默认剥离）。
  - `--overwrite`：允许直接覆盖原图（默认分配不冲突的文件名）。
- **运行环境**：
  - 提供标准错误输出与退出码（0 表示完全成功，非 0 表示部分或全部失败）。
  - 提供紧凑的终端进度条或百分比进度打印。

### 2.2 P0：文件夹监听 (Folder Watching)

- **监听引擎**：
  - 在 `Sources/ImagePet/Services` 中引入 `FolderMonitor`，利用 `DispatchSourceFileSystemObject` 监听指定目录的 `.write` 行为。
  - 监听文件夹列表通过 `NSOpenPanel` 交互式获取权限，并保存为 security-scoped bookmarks 以实现持久化。
- **工作流细节**：
  - 自动防抖处理：新图片移入时，通常会有连续的写入事件。需实现 0.5s ~ 1.0s 的防抖机制，等待文件写入完成（通过检查文件大小是否变化或尝试专属只读打开方式）后再触发压缩。
  - 压缩输出：默认压缩参数采用主 App 当前设置的 Quality 预设与尺寸限制，输出至该监听任务绑定的输出文件夹。
  - 宠物反馈：如果桌面 Pet 处于启用状态，文件夹监听后台静默压缩时，Pet 应进入 `eating` 状态并显示简易滚动进度，随后在完成后自动退出。
- **安全与防死循环**：
  - 禁止将监听文件夹与输出文件夹设为同一个文件夹（防止输出压缩后的图片再次触发监听，形成无限死循环）。

### 2.3 P1：Finder 快速操作 (Finder Quick Action)

- **实现机制**：
  - 在 App 的 `Generated/Info.plist` 中声明 `NSServices`（macOS 服务菜单项）。
  - 支持的发送类型（Send Types）：`NSFilenamesPboardType` 或 `public.image`。
  - 注册后，用户在 Finder 中选中图片并右键 -> 快速操作 (Quick Actions) / 服务 (Services) -> 出现 "Compress with ImagePet"。
- **交互边界**：
  - 触发后，如果 App 未运行则启动 App，直接将选中的文件加入 `ImagePetStore` 的压缩队列，并在后台静默开始压缩。
  - 若已设置输出目录，可完全在后台静默运行并弹出系统 Notification 告知节省体积；若未授权输出目录，则前置主窗口要求授权。

### 2.4 P1：Apple Shortcuts (快捷指令) 动作集成

- **实现机制**：
  - 使用 macOS 13+ 推荐的 `AppIntents` 框架定义 `CompressImagesIntent`。
  - 动作输入：接收一个或多个图片文件。
  - 动作参数：允许在 Shortcuts 编辑器中配置预设、输出格式、是否保留元数据等。
  - 动作输出：返回压缩后的新图片文件对象，供 Shortcuts 下游节点（如保存文件、发送邮件）使用。

---

## 3. 非目标 (Non-Goals)

- 不为 CLI 工具提供独立的自动更新程序（由 Homebrew 或 App 主包更新）。
- 文件夹监听不监视网络驱动器或外部云盘挂载点（仅限本地 APFS/HFS+ 分区）。
- Finder 快速操作不支持除图片格式（JPG/PNG/HEIC/WebP）以外的文件，对不支持的文件直接过滤不予提示。
- 不提供跨平台的 CLI（仅支持 macOS 13+）。

---

## 4. 性能与能耗指标

- **监听状态 CPU 占用**：在没有任何文件移入时，文件夹监听服务（File System Monitor）的 CPU 占用必须为 `0.0%`（无轮询，完全由 OS 内核事件通知驱动）。
- **内存占用**：后台静默监听和压缩时，App 内存峰值同样遵循不超过 `1.5 GB` 的限制。
- **资源释放**：文件夹监听解绑或 App 退出时，必须注销所有 FSEvent 或 DispatchSource 句柄，无内存 and 描述符泄漏。

---

## 5. 测试与验证计划

### 5.1 自动化测试
- **CLI 单测**：验证 `ImagePetCLI` 参数解析，对无效格式或非法数值抛出正确 exit code，且能成功链接 `ImagePetCore` 压缩输出。
- **监听防抖单测**：模拟文件夹中图片文件分块写入，验证防抖计时器不重复触发压缩任务。
- **循环避免测试**：检测到监听目录与输出目录相同时，验证抛出 `invalidConfiguration` 错误。

### 5.2 手工验收要点
- 在终端运行 `imagepet --preset small -o ./Output input.png`，核对压缩比例。
- 绑定文件夹 A 作为监听源，输出到文件夹 B。拖入 5 张大图到 A，确认 B 中生成压缩图，且 App 主窗口保持隐藏，但桌面 Pet 播放咀嚼动画。
- 在 Finder 右键一张 JPG 图片，选择服务中的 "Compress with ImagePet"，检查是否启动压缩。
- 在系统“快捷指令”App 中创建一个工作流，读取照片图库最新照片，调用 ImagePet 动作压缩，并成功保存。

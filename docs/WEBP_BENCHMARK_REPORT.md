# WebP 编解码引擎性能测试报告 (WebP Performance Benchmark Report)

本报告记录了 ImagePet 在 macOS 13+ 环境下对 WebP 编码（写路径）与解码（读路径）引擎的性能评估结果，重点对比了系统原生 ImageIO 与第三方 libwebp (`webp-spm` 1.6.0) 的执行耗时与内存开销。

---

## 1. 测试环境与评测方法

- **测试系统**：macOS 13+ (本机运行环境：macOS 14.0 arm64e)
- **依赖库版本**：**`gewill/webp-spm` 1.6.0** (集成 NEON 汇编指令集优化与 Release 级静态编译库)
- **评测工具**：集成于单元测试套件中，参见 [WebPBenchmarkTests.swift](file:///Users/rxwill/git/MyApps/ImagePet/Tests/ImagePetCoreTests/WebPBenchmarkTests.swift)。
- **强制解压（栅格化）方法**：
  - 默认情况下，ImageIO 的 `CGImageSource` 采用延迟解压（Deferred Decompression）机制（Lazy Open），仅读取元数据和编码状态（耗时仅 `0.04 ms`）。
  - 为了对比真实的解码性能，ImageIO 解码测试中引入了 `Self.forceDecompression(of:)` 逻辑，通过 `CGContext.draw()` 将 CGImage 绘制到内存 bitmap 上以强迫像素被完全栅格化和解压。
  - `libwebp` 采用直接解码（`WebPDecoder().decodeCGImage`），其底层会自动完成熵解码并直接分配 RGBA 像素缓冲区。
- **超大图测试样本 (FreeLarge)**：`TestImages/FreeLarge/kepler-16b.png` ($8100 \times 11700$ 像素)。

---

## 2. WebP 编码 (写路径) 性能

对比 `Swift-WebP` (使用 `webp-spm` 1.6.0 后) 与 Apple 原生 WebP 写入能力。在 macOS 13/14 本机测试环境下，系统 `CGImageDestination` 并不原生支持 WebP 编码输出 (`canWriteWebP = false`)。

| 文件尺寸/类型 | 引擎 | 平均耗时 (ms) | 输出文件体积 (Bytes) | 循环次数 | 峰值内存 (MB) | 说明 |
| --- | --- | --- | --- | --- | --- | --- |
| small (128x128, alpha: true) | Swift-WebP | 1.58 | 154 | 10 | 1.70 | CPU 编码 (NEON 优化) |
| | Apple-WebP | N/A | N/A | N/A | N/A | 原生不支持 WebP 写入 |
| medium (800x600, alpha: false) | Swift-WebP | 15.61 | 946 | 10 | 5.22 | CPU 编码 (NEON 优化) |
| | Apple-WebP | N/A | N/A | N/A | N/A | 原生不支持 WebP 写入 |
| large (2048x1536, alpha: true) | Swift-WebP | 221.51 | 5852 | 10 | 80.09 | CPU 编码 (NEON 优化) |
| | Apple-WebP | N/A | N/A | N/A | N/A | 原生不支持 WebP 写入 |
| FreeLarge (8100x11700) | Swift-WebP | 3898.19 | 1056250 | 2 | 1267.58 | CPU 编码 (NEON 优化) |
| | Apple-WebP | N/A | N/A | N/A | N/A | 原生不支持 WebP 写入 |

### 评估结论：不采用 Apple 原生写入；充分利用 `webp-spm` 高效编码
1. **支持性限制**：由于系统底层在 macOS 13/14 下不支持 WebP 编码写入，我们继续使用 `Swift-WebP` (基于 `webp-spm` 1.6.0) 作为 WebP 写入的主路径。
2. **20x+ 速度提升**：在引入 `webp-spm` (1.6.0) 预编译静态库后，由于启用了 NEON 优化与 O3 级别 Release 编译，大图（$8100 \times 11700$）的编码时间从原先的 **87.5秒** 大幅缩减至 **3.89秒**，效率提升了 **22.4 倍**。
3. **并发与限流**：即使编码时间大幅下降，大图编码的峰值内存依然在 **1.27 GB** 左右。为避免极限场景下系统内存耗尽，依然必须保持 `maxConcurrentJobs = 2` 的并发限制策略。

---

## 3. WebP 解码 (读路径) 性能

对比 ImageIO（强制像素解压）与 libwebp（1.6.0 直接解码）。

| 文件尺寸/类型 | 引擎 | 平均耗时 (ms) | 循环次数 | 峰值内存增量 (MB) | 测试说明 |
| --- | --- | --- | --- | --- | --- |
| small (128x128, alpha: true) | ImageIO | 0.18 | 10 | 0.02 | 强制解压 (Forced Decompression) |
| | libwebp | 0.05 | 10 | 0.12 | 直接解码 (Direct Decode) |
| medium (800x600, alpha: false) | ImageIO | 1.08 | 10 | 13.33 | 强制解压 (Forced Decompression) |
| | libwebp | 0.45 | 10 | 0.08 | 直接解码 (Direct Decode) |
| large (2048x1536, alpha: true) | ImageIO | 10.85 | 10 | 0.00 | 强制解压 (Forced Decompression) |
| | libwebp | 4.22 | 10 | 15.02 | 直接解码 (Direct Decode) |
| FreeLarge (8100x11700) | ImageIO | 306.15 | 2 | 723.64 | 强制解压 (Forced Decompression) |
| | libwebp | 159.96 | 2 | 452.62 | 直接解码 (Direct Decode) |

### 并发解码吞吐量 (10 并发任务, 中等尺寸 800x600):
- **ImageIO** 总时间：**3.11 ms** (Forced Decompression)
- **libwebp** 总时间：**1.09 ms** (Direct Decode)

### 评估结论：ImageIO 优先作为 Fast Path，libwebp 作高性能备用与解码加速
1. **跨越式性能提升**：
   - 升级至 `webp-spm` 1.6.0 后，`libwebp` 的同步解码速度相比此前 Debug 模式源码编译提升了约 **17 倍**。
   - 在 FreeLarge 超大图（$8100 \times 11700$）同步解码时，libwebp（直接解码）耗时仅 **159.96 ms**，优于 ImageIO（强解压绘制）的 **306.15 ms**。
   - 并发场景下，libwebp 吞吐耗时仅 **1.09 ms**，性能优势明显。
2. **决策选择**：
   - **ImageIO Fast Path** 仍作为主读取路径：因为 ImageIO 的 `Lazy Open`（0.04 ms）极具优势，在 UI 列表展示与元数据初检时极其节省内存与 CPU 资源；
   - **libwebp Fallback 通道**：`libwebp` (WebPDecoder) 在 1.6.0 的加持下成为了名副其实的“高性能高保真”备选通道，特别是在需要直接获取完整像素矩阵（如编码与重新调整大小）时，可以极大提供系统运行吞吐量。

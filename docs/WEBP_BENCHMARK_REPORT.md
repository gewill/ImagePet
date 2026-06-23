# WebP 编解码引擎性能测试报告 (WebP Performance Benchmark Report)

本报告记录了 ImagePet 在 macOS 13+ 环境下对 WebP 编码（写路径）与解码（读路径）引擎的性能评估结果，重点对比了系统原生 ImageIO 与第三方 libwebp (`Swift-WebP`) 的执行耗时与内存开销。

---

## 1. 测试环境与评测方法

- **测试系统**：macOS 13+ (本机运行环境：macOS 14.0 arm64e)
- **评测工具**：集成于单元测试套件中，参见 [WebPBenchmarkTests.swift](file:///Users/rxwill/git/MyApps/ImagePet/Tests/ImagePetCoreTests/WebPBenchmarkTests.swift)。
- **强制解压（栅格化）方法**：
  - 默认情况下，ImageIO 的 `CGImageSource` 采用延迟解压（Deferred Decompression）机制（Lazy Open），仅读取元数据和编码状态（耗时仅 `0.04 ms`）。
  - 为了对比真实的解码性能，ImageIO 解码测试中引入了 `Self.forceDecompression(of:)` 逻辑，通过 `CGContext.draw()` 将 CGImage 绘制到内存 bitmap 上以强迫像素被完全栅格化和解压。
  - `libwebp` 采用直接解码（`WebPDecoder().decodeCGImage`），其底层会自动完成熵解码并直接分配 RGBA 像素缓冲区。
- **超大图测试样本 (FreeLarge)**：`TestImages/FreeLarge/kepler-16b.png` ($8100 \times 11700$ 像素)。

---

## 2. WebP 编码 (写路径) 性能

对比 `Swift-WebP` (libwebp) 与 Apple 原生 WebP 写入能力。在 macOS 13/14 本机测试环境下，系统 `CGImageDestination` 并不原生支持 WebP 编码输出 (`canWriteWebP = false`)。

| 文件尺寸/类型 | 引擎 | 平均耗时 (ms) | 输出文件体积 (Bytes) | 循环次数 | 峰值内存 (MB) | 说明 |
| --- | --- | --- | --- | --- | --- | --- |
| small (128x128, alpha: true) | Swift-WebP | 12.52 | 154 | 10 | 1.56 | CPU 编码 |
| | Apple-WebP | N/A | N/A | N/A | N/A | 原生不支持 WebP 写入 |
| medium (800x600, alpha: false) | Swift-WebP | 325.07 | 946 | 10 | 5.00 | CPU 编码 |
| | Apple-WebP | N/A | N/A | N/A | N/A | 原生不支持 WebP 写入 |
| large (2048x1536, alpha: true) | Swift-WebP | 2310.34 | 5852 | 10 | 76.48 | CPU 编码 |
| | Apple-WebP | N/A | N/A | N/A | N/A | 原生不支持 WebP 写入 |
| FreeLarge (8100x11700) | Swift-WebP | 87529.53 | 1056250 | 2 | 1267.78 | CPU 编码 |
| | Apple-WebP | N/A | N/A | N/A | N/A | 原生不支持 WebP 写入 |

### 评估结论：不采用 (DO NOT ADOPT) Apple 原生 WebP 写入
1. **支持性限制**：由于系统底层在 macOS 13/14 下不支持 WebP 编码写入，我们**不采用** Apple native 写入路线，继续保留 `Swift-WebP` (libwebp) 作为 WebP 写入的唯一与主路径。
2. **资源与并发规划**：测试表明，在 $8100 \times 11700$ 的超大图编码场景下，CPU 单图压缩耗时长达 **87.5 秒**，峰值物理内存 RSS 增量达 **1.27 GB**。这强力佐证了项目设计中将并发数限制在 `maxConcurrentJobs = 2` 的必要性，以完全避免多任务高负荷大图压缩时系统发生 Out Of Memory (OOM) 或崩溃卡死。

---

## 3. WebP 解码 (读路径) 性能

对比 ImageIO（强制像素解压）与 libwebp（直接解码）。

| 文件尺寸/类型 | 引擎 | 平均耗时 (ms) | 循环次数 | 峰值内存增量 (MB) | 测试说明 |
| --- | --- | --- | --- | --- | --- |
| small (128x128, alpha: true) | ImageIO | 0.23 | 10 | 0.00 | 强制解压 (Forced Decompression) |
| | libwebp | 0.37 | 10 | 0.06 | 直接解码 (Direct Decode) |
| medium (800x600, alpha: false) | ImageIO | 1.04 | 10 | 7.64 | 强制解压 (Forced Decompression) |
| | libwebp | 7.47 | 10 | 0.00 | 直接解码 (Direct Decode) |
| large (2048x1536, alpha: true) | ImageIO | 9.86 | 10 | 0.00 | 强制解压 (Forced Decompression) |
| | libwebp | 56.64 | 10 | 15.38 | 直接解码 (Direct Decode) |
| FreeLarge (8100x11700) | ImageIO | 255.99 | 2 | 723.33 | 强制解压 (Forced Decompression) |
| | libwebp | 2749.26 | 2 | 452.41 | 直接解码 (Direct Decode) |

### 并发解码吞吐量 (10 并发任务, 中等尺寸 800x600):
- **ImageIO** 总时间：**2.26 ms** (Forced Decompression)
- **libwebp** 总时间：**9.74 ms** (Direct Decode)

### 评估结论：采用 (ADOPT) ImageIO 作为解码首选 Fast Path
1. **性能表现**：在排除了 Lazy Open 延迟解压的干扰、强制进行完整的像素栅格化解压后，**ImageIO 仍然表现出极具压倒性的性能优势**。对于 $8100 \times 11700$ 像素的超大图，ImageIO 栅格化解码耗时为 **255.99 ms**，而 libwebp 耗时为 **2749.26 ms**，ImageIO 相比 libwebp 提升了 **10.7 倍** 的解码速度。多核并发调度下，ImageIO 同样以数倍优势领先。
2. **资源与内存开销**：
   - libwebp 解码超大图的 RSS 物理内存增量为 **452.41 MB**，代表其解出的纯像素 RGBA 数据在内存中的真实占用（$8100 \times 11700 \times 4 \text{ Bytes} \approx 379 \text{ MB}$）。
   - ImageIO 强制解压后的 RSS 增量为 **723.33 MB**，包含绘制所需的 CGContext 画布缓存及解码器内部缓存。
3. **决策选择**：我们**全面采用 ImageIO 作为 WebP 读取的 Fast Path**。这会在生成预览缩略图、图像重新编码与渲染时带来 10 倍的速度提升。同时，我们保留 `libwebp` (`WebPDecoder`) 作为鲁棒的回退通道，在原生检测不可用时降级使用。

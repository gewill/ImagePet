# 自动质量搜索与有损 PNG 离线实验

2026-11-05，计划第 5 阶段。结论：**本轮均不纳入产品**。保存有限候选实验、数据及纳入门槛；App 的质量档位、PNG 无损行为及依赖保持不变。

## 借鉴与边界

参考 pngdeer `a02d35ee15e99ee67a0677937f2ae66e23e691af` 的 `src/quality.rs`、`src/jpeg.rs`、`src/search.rs`：按图搜索、有限候选、编码后解码评分、结果不得增大，并计算评分成本。没有直接采用其针对 TinyPNG 拟合的目标分数，也没有把生成图当作真实照片收益。

先跑 JPEG/PNG，再独立跑 WebP。JPEG 使用 ImagePet 已有 mozjpeg，WebP 使用现有 Swift-WebP picture 配置。二进制来自第 4 阶段 Core/CLI 副本，源码基线为 `abd637e`，关闭实验环境变量后使用现有产品路径。PNG 使用离线环境已有 Pillow FASTOCTREE、无抖动；**不是 pngdeer 的量化算法**，也不是为产品选择了该依赖。

评分使用原生方向变换、sRGB 预乘 RGBA 和黑/白底 RGB SSIM 最小值，**不是 SSIMULACRA2，也不是视觉验收**。本轮检验有限候选的收益与筛选盲点，不比较 pngdeer 的最终压缩效率。Python 评分进程的启动、导入和计算均计时，不能直接外推为未来原生评分器的耗时。

## 冻结协议

- 既有 103 张清单全部作为调参来源，按清单顺序取每类别前 3 张符合条件的 PNG，最多 1 MP。JPEG 排除非全不透明图。实际 JPEG 12 张、WebP 12 张、PNG 21 张；每候选编码及评分重复 3 次。
- JPEG/WebP：基线 q80，尝试 q70、q75；更小且 SSIM ≥ `max(0.98, 基线分数−0.002)` 才选择最小文件。这是有限网格，不声称找到连续质量空间的最优解，也不假定质量与分数严格单调。
- PNG：现有无损 PNG 路径作基线，尝试 64/128/256 色；更小且黑/白底最小 SSIM ≥ 0.995 才作为“评分选中候选”。这些门槛是未经人工校准的筛选假设。
- 无候选通过时保留当前结果；未变小沿用 CLI 保留原文件的行为。基线低于门槛也只是回退，不把它报告为达标。
- 预设纳入门槛：真实素材额外节省至少 5%，附加搜索 P95 ≤ 0.5 s，单 worker 峰值 RSS ≤ 256 MiB；还需新留出集、文字/渐变/边缘/透明度人工复核。PNG 有损必须另有显式选择，不能替换默认无损模式。

## 结果

候选体积是假设采用评分选中项的大小，**没有被产品采用**；有效字节包含保留的原文件。存在桌面后台负载，资源数据仅为本机筛选观察。

| 指标 | JPEG | WebP | PNG |
| --- | ---: | ---: | ---: |
| 图数 / 其中真实素材 | 12 / 3 | 12 / 3 | 21 / 12 |
| 基线有效字节 | 508,090 | 483,976 | 9,879,961 |
| 评分选中后有效字节 | 503,684 | 455,568 | 9,407,443 |
| 总量额外减少 | 0.867% | 5.870% | 4.783% |
| 真实素材额外减少 | 0% | 0% | 3.026% |
| 更小且评分过线图数 | 3 | 9 | 4 |
| 附加耗时 P50 / P95 | 1.897 / 2.261 s | 1.986 / 2.375 s | 2.576 / 3.134 s |
| 最大 worker 峰值 RSS | 179.1 MiB | 179.7 MiB | 204.1 MiB |

附加耗时包含新增候选编码、所有候选评分及基线评分，不包含原本需要的基线编码。RSS 是编码/评分子进程各自生命周期峰值的最大值，不是进程树同时驻留总量，也不是 App 内集成后的内存。没有运行新增并行候选或更改产品双任务队列。

468 次编码和 468 次评分全部完成；每候选三个重复的输出哈希与评分一致，输入/输出哈希复核通过。JPEG 收益仅来自 3 张生成渐变图；WebP 收益来自生成文字、渐变和透明图。真实照片样本均回退基线，小样本不能代表全部照片。

PNG 收益来自 3 张生成文字图和 `bicycle-diagram-es.png`。后者从 273,122 降至 63,103 字节，黑/白底最小 SSIM 为 0.996458，却出现 **alpha 最大相差 60/255**。平均结构评分不足以保护局部透明边缘，不能称为画质合格。新留出集和人工验收未进行，不能声称已通过。

## 决策

三条路径均未满足本轮真实素材收益和耗时门槛，不进入产品实现。PNG 还暴露出透明度保护缺口。保留实验脚本与汇总，不新增 Rust、量化或评分运行时到 App。

后续若重开：先做受限的原生评分原型，独立测量评分/编码成本；以人工评价校准阈值，加入局部边缘、透明度检查；内容预筛后冻结策略与预算，再用从未调参的新留出集验证。PNG 有损需明确选项及回退。本轮只否决这些候选和原型的产品纳入，不证明所有自动质量搜索或 pngdeer 算法都无价值。

## 复现与证据

[脚本](../script/benchmark/experiments/screen_quality.py)、[整合复现协议](../script/benchmark/experiments/quality-search-plan.json)、[逐图结果及当时冻结协议](../script/benchmark/experiments/quality-search-results.json)。依赖仅使用 `script/benchmark/requirements-quality.txt`，不进入 App。

```sh
swiftc -O -parse-as-library script/benchmark/compare_pixels.swift -o "$NORMALIZER"
"$QUALITY_PYTHON" script/benchmark/experiments/screen_quality.py \
  --benchmark-dir "$REPO/script/benchmark" --kinds jpeg png webp \
  --normalizer "$NORMALIZER" --cli "$CLI" --manifest "$MANIFEST" \
  --plan "$REPO/script/benchmark/experiments/quality-search-plan.json" \
  --output "$EVIDENCE"
```

变量为实际绝对路径；`QUALITY_PYTHON` 指向安装上述依赖的独立环境，CLI 为 Release 构建，清单生成见评测 README。默认运行 JPEG/PNG，`--kinds webp` 可单独运行 WebP。输出目录必须新建且在仓库外。脚本冻结 CLI、normalizer 与协议并记录哈希，不复用用户输出目录。

本地原件：`~/Library/Application Support/Codex/compression-evidence/ImagePet/2026-11-05/quality-search/`，含 `evaluation/`、`evaluation-webp/`、原脚本、计划、日志及 `summary.json`。首次启动误用不支持 RGBA 导出的旧 normalizer，在首个样本前失败；保留失败目录，重新编译后完整重跑。JPEG/PNG 使用原脚本；后续版本只增加格式选择、参数/输出路径保护并移除未使用变量，选择和评分公式一致。WebP 使用已提交脚本版本。媒体、素材、二进制未进入 Git。

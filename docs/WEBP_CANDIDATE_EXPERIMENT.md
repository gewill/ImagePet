# WebP 有限候选实验

2026-11-05，计划第 4 阶段。结论：**本轮不纳入产品**。借鉴 pngdeer 的同格式候选择优，但保留 ImagePet 当前依赖、ImageIO 标准化和双任务队列。没有增加 App 依赖或改变默认编码。

## 方法

- 源码：PR #1 的 `abd637e4755736557741ffd9c911e409de7ff771`；其产品代码已随 squash `7e268ab43b0de06f0eabbbe47807ddf6320f4930` 合并。
- 在仓库外复制 Core/CLI，应用 [实验补丁](../script/benchmark/experiments/webp-candidate.patch)，Release 构建。Swift-WebP 0.7.1 / libwebp 1.6.1，与产品一致。
- 同一二进制：基线为 picture/q80；实验在不超过 1 MP 的输入上增加一个 lossless preset 0 或 3、exact=1 候选。候选更小且单次编码不超过 250 ms 才选用。250 ms 是结果接纳预算，不能抢占正在执行的 libwebp C 调用。
- 103 张既有样本全部降为调参集，不把上一阶段留出样本重复当作本阶段留出。每策略 309 次单图测量、3 次并发数为 2 的整批测量；输入、输出、二进制和实验协议有哈希。有效字节包含未变小而保留的原文件。
- 原生像素检查使用现有 `compare_pixels.swift`：ImageIO 方向变换、sRGB、8 位预乘 RGBA。它检查最终显示信号，不证明原始隐藏 RGB 相同。
- 本机桌面后台有其他活动，耗时仅作为本轮筛选观察，不能推广为稳定性能承诺；正式纳入仍需安静环境复测、新留出集和人工视觉验收。

## 结果

| 每轮指标 | 基线 | preset 0 | preset 3 |
| --- | ---: | ---: | ---: |
| 有效字节 | 5,888,607 | 5,827,187 | 5,809,174 |
| 额外减少 | — | 1.043% | 1.349% |
| 80 张真实素材额外减少 | — | 0% | 0.335% |
| 写出 / 保留原图 / 失败 | 89 / 14 / 0 | 92 / 11 / 0 | 102 / 1 / 0 |
| 批量耗时中位数 | 3.298 s | 3.694 s | 7.030 s |
| 最大批量峰值 RSS | 473.8 MiB | 496.1 MiB | 503.3 MiB |

三个重复的输出哈希与有效字节均稳定，单图和批量无编码失败。preset 0 只改善 3 张生成调色板图，显示像素检查全部相同。preset 3 改善 3 张生成调色板图和 16 张真实图标；19 对检查中 6 对显示像素相同，13 对最多相差 1 级、alpha 均相同。差异与现有预乘/反预乘整数处理相符，但本轮没有证明其唯一原因，不能称为原图像素无损。

详细逐图字节、哈希、三次耗时和像素差异见 [机器可读结果](../script/benchmark/experiments/webp-candidate-results.json)。初步 cwebp 1.6.0 探索及带诊断日志的失败测量仅保留本地，不用于上表；后者的并发 stderr 混入 CLI 状态行，移除诊断输出后完整重跑，未放宽失败判定。

## 决策

preset 0 缺少真实素材收益；preset 3 的真实素材收益不足以支持约 113% 的批量时间增长，且未满足显示像素相等检查。筛选阶段停止纳入，不消耗新留出集、不宣称视觉验收通过。后续若有明确图标工作负载，可以先研究内容预筛和整数转换，再冻结策略并用新素材验证；不根据生成图的突出收益默认启用。

## 复现

使用 `script/benchmark/README.md` 生成带来源和 SHA-256 的清单，将所有 `split` 设为 `tuning`。在仓库外的新目录复制以下文件，不修改产品 checkout：

```sh
mkdir -p "$EXPERIMENT/Sources" "$EXPERIMENT/Tests"
cp Package.swift Package.resolved "$EXPERIMENT/"
cp -R Sources/ImagePetCore Sources/ImagePetCLI "$EXPERIMENT/Sources/"
cp -R Tests/ImagePetCoreTests Tests/ImagePetCLITests "$EXPERIMENT/Tests/"
patch -d "$EXPERIMENT" -p1 < script/benchmark/experiments/webp-candidate.patch
swift build --package-path "$EXPERIMENT" -c release
env -u IMAGEPET_WEBP_LOSSLESS_PRESET python3 script/benchmark/run.py \
  --manifest "$MANIFEST" --executable "$EXPERIMENT/.build/release/imagepet" \
  --output "$EVIDENCE/reference" --repeat 3 --format webp
IMAGEPET_WEBP_LOSSLESS_PRESET=0 python3 script/benchmark/run.py \
  --manifest "$MANIFEST" --executable "$EXPERIMENT/.build/release/imagepet" \
  --output "$EVIDENCE/level0" --repeat 3 --format webp
IMAGEPET_WEBP_LOSSLESS_PRESET=3 python3 script/benchmark/run.py \
  --manifest "$MANIFEST" --executable "$EXPERIMENT/.build/release/imagepet" \
  --output "$EVIDENCE/level3" --repeat 3 --format webp
```

`EXPERIMENT`、`EVIDENCE` 为新的绝对路径，`MANIFEST` 为实际素材清单。保留补丁、源码快照哈希、Package.resolved、二进制哈希及冻结协议；通用 runner 的 `source_commit` 是原仓库标识，不能单独代表实验二进制源码。不要使用只针对 PNG 的 `compare_runs.py` 验证 WebP。

完整本地证据：`~/Library/Application Support/Codex/compression-evidence/ImagePet/2026-11-05/webp-swift-spike/`，包括 `evaluation-plan.json`、`snapshot.json`、`spike.patch`、`evaluation/`、`summary.json`。这是本机路径，远程审查使用本 PR 的汇总与补丁；没有上传或提交素材、二进制及媒体。

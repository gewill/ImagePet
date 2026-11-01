# Offline compression evaluation

Run the release CLI with a fixed manifest. Inputs and generated outputs stay outside the repository; nothing is uploaded. The runner rejects changed input hashes, duplicate input stems and an existing run directory.

```sh
swift build -c release
python3 script/benchmark/test_runner.py
python3 script/benchmark/run.py \
  --manifest /absolute/path/manifest.json \
  --executable .build/release/imagepet \
  --output /absolute/path/new-run-directory \
  --repeat 3 --format original
```

Manifest schema:

```json
{
  "schema_version": 1,
  "images": [{
    "path": "/absolute/path/icon.png",
    "sha256": "actual SHA-256 of input bytes",
    "category": "icons",
    "split": "holdout",
    "source": "Original source URL or documented local provenance",
    "license": "Actual fixture license",
    "notes": "Optional fixture-specific expectations"
  }]
}
```

Freeze the tuning/holdout assignment before changing algorithms. Compare runs using the same manifest hash and parameters. Preserve each image's license and attribution; fixtures are evaluation inputs, not application resources.

Each run saves environment/version information, input/output hashes, individual CLI logs, per-image JSON/CSV, batch measurements and a category/split report. Time includes CLI startup. Every individual image runs in a separate process; batches use the existing CLI's maximum of two concurrent jobs. `wait4` collects the child's lifetime high-water RSS, including startup and runtime overhead, rather than subtracting before/after snapshots. The current CLI uses Advanced JPEG, balanced quality, no resize and metadata stripping; it is not identical to GUI defaults.

An optional `--metric /absolute/path/scorer` invokes an executable with `ORIGINAL OUTPUT` arguments, without a shell. It must print one finite numeric score. Record the scorer's normalization, alpha composition and score semantics separately; the runner hashes the executable. An unavailable scorer leaves quality explicitly `not_measured`. Metric failure is recorded and makes the run fail. Neither missing scores nor favorable file sizes imply visual approval. For PNG adoption, add normalized pixel/alpha equality and human comparison, not just a perceptual score.

`skipped_not_smaller` means no output was written. It is not included as a successful compressed file; keep it in denominators when comparing effectiveness. Existing CLI exit 1 also covers skips, so individual logs distinguish this one known skip reason from errors. Batch logs preserve the existing CLI summary verbatim.

The first real-image manifest is a starting corpus. Add small-text screenshots, gradients, HEIC, EXIF orientation and wide-gamut fixtures before making the full adoption decision. Do not compare only successful output files or present this initial PNG corpus as coverage of all supported formats.

The runner freezes a copy of the CLI executable before measuring, records its hash, and captures untracked Swift/Python source alongside the tracked diff. Do not build or run other tests during an acceptance timing run. The first candidate pilot overlapped subsequent development and is diagnostic only.

For a displayed-pixel oracle (independent ImageIO decode, orientation applied, standard sRGB, premultiplied RGBA):

```sh
swiftc -parse-as-library -O script/benchmark/compare_pixels.swift -o /outside/repository/compare-pixels
/outside/repository/compare-pixels original.png result.png
```

It prints JSON and returns 0 only for equal dimensions and pixels, 1 for a mismatch, and errors for unreadable/oversized inputs. It caps each image at 16 MP. This is not the scalar `--metric` interface: save its JSON as separate correctness evidence. Premultiplied comparison does not validate hidden RGB in fully transparent pixels or original high-bit-depth samples. The optimizer works on the already standardized ImageIO output; compare against that output when testing the optimizer alone.

## Matched PNG baseline and candidate

Use the same frozen release executable for both runs. The reference disables only the new PNG optimizer; other encoders and file-size accounting remain identical.

```sh
python3 script/benchmark/run.py --manifest /outside/manifest.json \
  --executable .build/release/imagepet --output /outside/reference \
  --repeat 3 --png-imageio-only
python3 script/benchmark/run.py --manifest /outside/manifest.json \
  --executable .build/release/imagepet --output /outside/candidate --repeat 3
python3 script/benchmark/compare_runs.py /outside/reference /outside/candidate \
  --output /outside/comparison --pixel-oracle /outside/compare-pixels
```

The comparator checks matching executable/manifest/parameters and measurement keys, verifies the saved output hashes, includes skips at original size, and rejects failures or larger outputs. Successful non-PNG outputs must remain byte-identical. PNG checks compare displayed pixels against the reference output (or original input when the reference skipped). Missing pixel or perceptual scores are not a passing quality result.

Create generated text, palette, gradient, alpha, EXIF-orientation, P3 and HEIC coverage without downloading fixtures:

```sh
swiftc -parse-as-library -O script/benchmark/generate_fixtures.swift -o /outside/generate-fixtures
/outside/generate-fixtures /outside/new-fixtures
```

Generated fixtures exercise particular cases; their savings do not represent real-world category averages. For an untouched real-image evaluation set after development, import a separate corpus:

```sh
python3 script/benchmark/import_pngdeer.py /absolute/path/pngdeer /outside/new-holdout.json \
  --corpus images-holdout --split holdout --per-category 6
```

If a previously held-out set informed a strategy change, relabel it as tuning before the next evaluation. Keep the newly selected holdout unchanged. Do not run acceptance measurements while builds, test suites, or other heavy local work are active; report residual system load and avoid treating small timing differences as decisive.

## Structural-quality baseline after timing

For PNG/JPEG/HEIC/WebP displayed-image scores on macOS, the optional postprocessor uses pinned development-only Python packages. It does not change the app, its dependencies, or the timed runs. Tested with Python 3.9.6:

```sh
python3 -m venv /outside/quality-venv
/outside/quality-venv/bin/python -m pip install -r script/benchmark/requirements-quality.txt
swiftc -parse-as-library -O script/benchmark/compare_pixels.swift -o /outside/normalize-rgba
/outside/quality-venv/bin/python script/benchmark/test_quality.py
/outside/quality-venv/bin/python script/benchmark/quality_report.py /outside/reference /outside/candidate \
  --normalizer /outside/normalize-rgba --output /outside/new-quality-report
```

ImageIO applies EXIF orientation and renders full-resolution sRGB 8-bit premultiplied RGBA (16 MP limit, no downscaling). SSIM averages the three RGB channels after compositing over black and white, keeping the lower background score; this exposes transparency loss. Parameters follow [scikit-image structural_similarity](https://scikit-image.org/docs/0.24.x/api/skimage.metrics.html#skimage.metrics.structural_similarity): Gaussian sigma 1.5, explicit data range 255 and population covariance. A score of 1 denotes identical displayed signals. This is SSIM, **not SSIMULACRA2**, and it is not a universal threshold for human-visible quality.

The postprocessor verifies input/output hashes, records tool hashes and package versions, reports each unique input/output pair including retained originals, and makes any scoring failure explicit. Dimensions must match; resized images are not silently aligned for scoring. Use the app comparison and independent pixel/raw-sample tests alongside scores. High-bit-depth/HDR fidelity and hidden RGB are outside this displayed-image metric.

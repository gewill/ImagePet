#!/usr/bin/env python3
"""Post-score frozen runs; never include scoring work in compression timings."""
import argparse
import hashlib
import json
from pathlib import Path
import statistics
import struct
import subprocess
import sys
import tempfile

import numpy as np
import scipy
import skimage
from skimage.metrics import structural_similarity


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def score_rgba(a, b):
    if a.shape != b.shape or min(a.shape[:2]) < 11:
        raise ValueError('SSIM requires equal dimensions and at least 11 pixels on each edge')
    scores = []
    for background in [0, 255]:
        # Native normalizer produces premultiplied sRGB RGBA. Composite before SSIM;
        # hidden RGB is not a visual signal, and alpha changes affect both backgrounds.
        rgb = []
        for image in [a, b]:
            value = image[:, :, :3].astype(np.uint16)
            if background:
                value += 255 - image[:, :, 3:4].astype(np.uint16)
            rgb.append(np.minimum(value, 255).astype(np.uint8))
        channel_scores = [structural_similarity(rgb[0][:, :, c], rgb[1][:, :, c],
                          data_range=255, gaussian_weights=True, sigma=1.5,
                          use_sample_covariance=False) for c in range(3)]
        scores.append(float(np.mean(channel_scores)))
    return dict(ssim=min(scores), black_background_ssim=scores[0], white_background_ssim=scores[1])


def decode(path, normalizer, destination):
    subprocess.run([str(normalizer), '--dump-rgba', str(path), str(destination)], check=True,
                   stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    data = destination.read_bytes()
    width, height = struct.unpack('>II', data[:8])
    return np.frombuffer(data[8:], dtype=np.uint8).reshape(height, width, 4)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('runs', type=Path, nargs='+')
    parser.add_argument('--normalizer', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    normalizer = args.normalizer.resolve()
    metadata = dict(metric='Minimum of black/white-composited RGB-channel mean SSIM; Gaussian sigma 1.5, population covariance, data range 255',
                    normalization='ImageIO EXIF transform, full-size sRGB 8-bit premultiplied RGBA; <=16 MP; no downscaling',
                    interpretation='1 means identical displayed signals; no universal visual-acceptance threshold. This is not SSIMULACRA2.',
                    python=sys.version, numpy=np.__version__, scipy=scipy.__version__, skimage=skimage.__version__,
                    normalizer_sha256=sha(normalizer), script_sha256=sha(__file__))
    (args.output/'environment.json').write_text(json.dumps(metadata, indent=2)+'\n')
    cache, rows = {}, []
    for run in args.runs:
        measured = json.loads((run/'results.json').read_text())
        seen = set()
        for row in measured:
            if row['status'] not in ('done', 'skipped_not_smaller'):
                raise ValueError('Resolve compression failures before quality scoring')
            source = Path(row['path'])
            output = Path(row['output_path']) if row['status'] == 'done' else source
            key = (row['sha256'], row.get('output_sha256') or row['sha256'])
            if key in seen:
                continue
            seen.add(key)
            if (sha(source), sha(output)) != key:
                raise ValueError('A measured input/output changed')
            record = dict(run=str(run.resolve()), path=str(source), output=str(output), category=row['category'],
                          split=row['split'], input_sha256=key[0], output_sha256=key[1], status='measured')
            try:
                if key not in cache:
                    if key[0] == key[1]:
                        cache[key] = dict(ssim=1.0, black_background_ssim=1.0, white_background_ssim=1.0)
                    else:
                        with tempfile.TemporaryDirectory() as directory:
                            a = decode(source, normalizer, Path(directory)/'a.rgba')
                            b = decode(output, normalizer, Path(directory)/'b.rgba')
                            cache[key] = score_rgba(a, b)
                record.update(cache[key])
            except Exception as error:
                record.update(status='failed', error=str(error))
            rows.append(record)
            (args.output/'scores.json').write_text(json.dumps(rows, indent=2)+'\n')
    lines = ['# Displayed-image SSIM baseline', '', metadata['metric'], '', metadata['interpretation'], '',
             'Unique input/output pairs per run; retained originals score 1. Scoring is separate from performance measurements.', '',
             '| Run / split / category | Pairs | SSIM median | SSIM minimum | Failed |',
             '| --- | ---: | ---: | ---: | ---: |']
    for run, split, category in sorted({(r['run'],r['split'],r['category']) for r in rows}):
        group = [r for r in rows if (r['run'],r['split'],r['category'])==(run,split,category)]
        scores = [r['ssim'] for r in group if r['status']=='measured']
        median = f'{statistics.median(scores):.6f}' if scores else 'not measured'
        minimum = f'{min(scores):.6f}' if scores else 'not measured'
        lines.append(f'| {Path(run).name} / {split} / {category} | {len(group)} | {median} | {minimum} | {len(group)-len(scores)} |')
    (args.output/'report.md').write_text('\n'.join(lines)+'\n')
    print(args.output/'report.md')
    return int(any(r['status']=='failed' for r in rows))


if __name__ == '__main__':
    raise SystemExit(main())

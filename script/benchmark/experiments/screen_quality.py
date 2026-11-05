#!/usr/bin/env python3
"""Offline bounded quality screening. Never changes ImagePet defaults."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read_rgba(path):
    import numpy as np
    data = Path(path).read_bytes()
    width, height = struct.unpack('>II', data[:8])
    return np.frombuffer(data[8:], dtype=np.uint8).reshape(height, width, 4)


def worker(args):
    import numpy as np
    from PIL import Image
    a = read_rgba(args.source)
    if args.worker == 'quantize':
        rgba = a.astype(np.uint32).copy()
        alpha = rgba[:, :, 3:4]
        rgba[:, :, :3] = np.minimum(255, rgba[:, :, :3] * 255 // np.maximum(alpha, 1))
        image = Image.fromarray(rgba.astype(np.uint8))
        image.quantize(colors=args.colors, method=Image.Quantize.FASTOCTREE,
                       dither=Image.Dither.NONE).save(args.destination, optimize=True)
    else:
        from quality_report import decode, score_rgba
        b = decode(args.destination, args.normalizer, args.dump)
        score = score_rgba(a, b)
        score['alpha_max_difference'] = int(np.abs(a[:, :, 3].astype(int) - b[:, :, 3].astype(int)).max())
        print(json.dumps(score))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--benchmark-dir', type=Path, required=True)
    parser.add_argument('--kinds', nargs='+', choices=['jpeg', 'png', 'webp'], default=['jpeg', 'png'])
    parser.add_argument('--worker', choices=['quantize', 'score'])
    parser.add_argument('--source', type=Path)
    parser.add_argument('--destination', type=Path)
    parser.add_argument('--dump', type=Path)
    parser.add_argument('--colors', type=int)
    parser.add_argument('--normalizer', type=Path, required=True)
    parser.add_argument('--manifest', type=Path)
    parser.add_argument('--cli', type=Path)
    parser.add_argument('--plan', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    sys.path.insert(0, str(args.benchmark_dir.resolve()))
    if args.worker:
        worker(args)
        return
    if any(value is None for value in [args.manifest, args.cli, args.plan, args.output]):
        parser.error('--manifest, --cli, --plan and --output are required')
    repository = args.benchmark_dir.resolve().parents[1]
    if args.output.resolve() == repository or repository in args.output.resolve().parents:
        parser.error('experiment outputs must be outside the repository')
    from run import measure
    from PIL import Image, __version__ as pillow_version
    args.output.mkdir(parents=True, exist_ok=False)
    root = args.output.resolve()
    shutil.copy2(args.cli, root/'imagepet')
    shutil.copy2(args.normalizer, root/'compare-pixels')
    args.cli = root/'imagepet'; args.normalizer = root/'compare-pixels'
    # The frozen CLI may include the isolated WebP spike; disable it for screening.
    os.environ.pop('IMAGEPET_WEBP_LOSSLESS_PRESET', None)
    manifest = json.loads(args.manifest.read_text())
    plan = json.loads(args.plan.read_text())
    (root/'plan.json').write_text(json.dumps(plan, indent=2)+'\n')
    metadata = dict(cli_sha256=digest(args.cli), normalizer_sha256=digest(args.normalizer),
                    script_sha256=digest(__file__), manifest_sha256=digest(args.manifest),
                    plan_sha256=digest(args.plan), pillow=pillow_version,
                    python=sys.version, load_average=os.getloadavg(),
                    note='Screening only; 3 first eligible images per category, all tuning; child wait4 peak RSS.')
    (root/'environment.json').write_text(json.dumps(metadata, indent=2)+'\n')
    selected = []
    for kind in args.kinds:
        counts = {}
        for item in manifest['images']:
            cat = item['category']
            if cat not in plan[kind]['categories'] or counts.get(cat, 0) >= 3:
                continue
            source = Path(item['path'])
            if source.suffix.lower() != '.png':
                continue
            assert digest(source) == item['sha256']
            with Image.open(source) as image:
                if image.width*image.height > plan[kind]['pixel_limit']:
                    continue
                if kind == 'jpeg' and image.convert('RGBA').getextrema()[3] != (255,255):
                    continue
            counts[cat] = counts.get(cat, 0)+1
            selected.append(dict(item, experiment=kind, split='tuning'))
    (root/'manifest.json').write_text(json.dumps({'images':selected}, indent=2)+'\n')
    records = []
    script = str(Path(__file__).resolve())
    common = [sys.executable, script, '--benchmark-dir', str(args.benchmark_dir.resolve()),
              '--normalizer', str(args.normalizer)]
    for index, item in enumerate(selected):
        kind = item['experiment']; source = Path(item['path'])
        directory = root/str(index); directory.mkdir()
        rgba = directory/'source.rgba'
        subprocess.run([args.normalizer,'--dump-rgba',source,rgba], check=True)
        candidates = []
        values = plan[kind]['qualities'] if kind!='png' else ['baseline']+plan[kind]['colors']
        for value in values:
            measurements = []
            for repeat in range(3):
                output = directory/f'{value}-{repeat}'; output.mkdir()
                log = output/'encode.log'
                if kind!='png' or value=='baseline':
                    files = output/'files'; files.mkdir()
                    command = [args.cli,'-f',kind,'-o',files]
                    if kind!='png': command += ['-q',str(value)]
                    command += [source]
                    encoded = measure(command, log)
                    products = list(files.iterdir())
                    if encoded['exit_code']==0 and len(products)==1:
                        result = products[0]
                    elif encoded['exit_code']==1 and not products and 'Skipped: output would be larger than source' in log.read_text():
                        result = source
                    else:
                        raise RuntimeError(log.read_text())
                else:
                    result = output/'candidate.png'
                    encoded = measure(common+['--worker','quantize','--source',rgba,
                                      '--destination',result,'--colors',str(value)], log)
                    if encoded['exit_code']!=0: raise RuntimeError(log.read_text())
                scorelog = output/'score.log'
                scored = measure(common+['--worker','score','--source',rgba,'--destination',result,
                                 '--dump',output/'decoded.rgba'], scorelog)
                if scored['exit_code']!=0: raise RuntimeError(scorelog.read_text())
                scores = json.loads(scorelog.read_text())
                measurements.append(dict(repeat=repeat, bytes=result.stat().st_size,
                    output_sha256=digest(result), output_path=str(result), scores=scores,
                    encode_seconds=encoded['seconds'], score_seconds=scored['seconds'],
                    peak_rss_bytes=max(encoded['peak_rss_bytes'], scored['peak_rss_bytes'])))
            assert len({m['output_sha256'] for m in measurements})==1
            assert len({m['scores']['ssim'] for m in measurements})==1
            candidates.append(dict(value=value, measurements=measurements))
        baseline = candidates[0]['measurements'][0]
        threshold = max(.98, baseline['scores']['ssim']-.002) if kind!='png' else .995
        eligible = [c for c in candidates[1:] if c['measurements'][0]['bytes'] < baseline['bytes']
                    and c['measurements'][0]['scores']['ssim'] >= threshold]
        winner = min(eligible, key=lambda c:c['measurements'][0]['bytes']) if eligible else candidates[0]
        record = dict(item, threshold=threshold, selected=winner['value'], candidates=candidates,
                      effective_bytes=winner['measurements'][0]['bytes'], baseline_bytes=baseline['bytes'],
                      additional_seconds=[sum(c['measurements'][r]['encode_seconds']+c['measurements'][r]['score_seconds'] for c in candidates[1:]) + candidates[0]['measurements'][r]['score_seconds'] for r in range(3)])
        records.append(record)
        (root/'results.json').write_text(json.dumps(records,indent=2)+'\n')
        print(index,kind,source.name,'selected',winner['value'],flush=True)


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Offline CLI benchmark. No uploads, shell execution, or image dependencies."""
import argparse
import csv
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import subprocess
import sys
import shutil
import time
from datetime import datetime, timezone


def sha(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def command(args, cwd=None):
    return subprocess.check_output(args, cwd=cwd, text=True).strip()


def measure(args, log):
    # File descriptors avoid pipe deadlock; wait4 reports this child's lifetime high-water RSS.
    start = time.monotonic()
    with Path(log).open('wb') as stream:
        pid = os.posix_spawn(str(args[0]), [str(a) for a in args], os.environ,
                             file_actions=[(os.POSIX_SPAWN_DUP2, stream.fileno(), 1),
                                           (os.POSIX_SPAWN_DUP2, stream.fileno(), 2)])
        _, status, usage = os.wait4(pid, 0)
    return {'exit_code': os.waitstatus_to_exitcode(status),
            'seconds': time.monotonic() - start,
            'peak_rss_bytes': usage.ru_maxrss * (1 if sys.platform == 'darwin' else 1024)}


def percentile(values, p):
    return sorted(values)[max(0, math.ceil(len(values) * p) - 1)] if values else None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--manifest', type=Path, required=True)
    parser.add_argument('--executable', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True, help='New directory outside repository')
    parser.add_argument('--repeat', type=int, default=3)
    parser.add_argument('--format', choices=['original', 'png', 'jpeg', 'webp', 'heic'], default='original')
    parser.add_argument('--png-imageio-only', action='store_true', help='Disable PNG optimization for the matched baseline')
    parser.add_argument('--metric', type=Path, help='Optional executable: ORIGINAL OUTPUT; prints a numeric score')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    output = args.output.expanduser().resolve()
    executable = args.executable.expanduser().resolve()
    if root == output or root in output.parents or args.repeat < 1:
        parser.error('output must be outside the repository; repeat must be positive')
    manifest = json.loads(args.manifest.read_text())
    entries = manifest['images']
    if not entries:
        parser.error('manifest must contain images')
    for item in entries:
        if item['split'] not in ('tuning', 'holdout') or not item['category'] or not item['source'] or not item['license']:
            parser.error('each image requires category, split, source and license')
        path = Path(item['path']).expanduser().resolve()
        if sha(path) != item['sha256']:
            parser.error(f'fixture changed: {path}')
        item['path'] = str(path)
    if len({Path(i['path']).stem for i in entries}) != len(entries):
        parser.error('unique input stems are required for batch output attribution')
    output.mkdir(parents=True, exist_ok=False)
    metadata = {'schema_version': 1, 'started_utc': datetime.now(timezone.utc).isoformat(),
                'platform': platform.platform(), 'architecture': platform.machine(),
                'python': platform.python_version(), 'load_average_at_start': os.getloadavg(),
                'xcode': command(['xcodebuild', '-version']),
                'source_commit': command(['git', 'rev-parse', 'HEAD'], root),
                'worktree_status': command(['git', 'status', '--porcelain'], root),
                'executable': str(executable), 'executable_sha256': sha(executable),
                'runner_sha256': sha(__file__), 'manifest_sha256': sha(args.manifest),
                'package_resolved_sha256': sha(root / 'Package.resolved'),
                'metric': str(args.metric) if args.metric else None,
                'metric_sha256': sha(args.metric) if args.metric else None,
                'memory_method': 'wait4 child lifetime high-water RSS; includes process startup',
                'timing_method': 'wall time including CLI startup; no warmup excluded',
                'cli_policy': 'balanced, advanced JPEG, strip metadata, no resize; batch concurrency 2',
                'format': args.format, 'repeat': args.repeat, 'png_imageio_only': args.png_imageio_only}
    # Freeze the executable so later builds cannot mix implementations within one run.
    shutil.copy2(executable, output / 'imagepet-benchmark')
    executable = output / 'imagepet-benchmark'
    if sha(executable) != metadata['executable_sha256']:
        raise RuntimeError('executable changed while snapshotting')
    for relative in command(['git', 'ls-files', '--others', '--exclude-standard'], root).splitlines():
        path = Path(relative)
        if path.suffix in ('.swift', '.py') and path.parts[0] in ('Sources', 'Tests', 'script'):
            target = output / 'untracked-source' / path
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(root / path, target)
    (output / 'environment.json').write_text(json.dumps(metadata, indent=2) + '\n')
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    (output / 'runner.py').write_text(Path(__file__).read_text())
    (output / 'source.diff').write_text(command(['git', 'diff', 'HEAD'], root) + '\n')
    rows = []
    batches = []
    for repeat in range(args.repeat):
        for index, item in enumerate(entries):
            destination = output / f'single-{repeat}-{index}'
            destination.mkdir()
            log = output / f'single-{repeat}-{index}.log'
            argv = [executable, '-f', args.format, '-o', destination, item['path']] + (['--png-imageio-only'] if args.png_imageio_only else [])
            row = dict(item, repeat=repeat, input_bytes=Path(item['path']).stat().st_size,
                       **measure(argv, log))
            row['command'] = [str(a) for a in argv]
            files = list(destination.iterdir())
            message = log.read_text()
            row.update(output_bytes=None, output_sha256=None, quality_score=None, quality_status='not_measured')
            if row['exit_code'] == 0 and len(files) == 1:
                row.update(status='done', output_bytes=files[0].stat().st_size, output_sha256=sha(files[0]), output_path=str(files[0]))
                if args.metric:
                    score = subprocess.run([str(args.metric.resolve()), item['path'], str(files[0])], capture_output=True, text=True)
                    (output / f'metric-{repeat}-{index}.log').write_text(score.stdout + score.stderr)
                    try:
                        value = float(score.stdout.strip())
                        if score.returncode or not math.isfinite(value):
                            raise ValueError()
                        row.update(quality_score=value, quality_status='measured')
                    except ValueError:
                        row['quality_status'] = 'metric_failed'
            elif row['exit_code'] == 1 and not files and 'Skipped: output would be larger than source' in message:
                row.update(status='skipped_not_smaller')
            else:
                row.update(status='failed', error=message.strip())
            rows.append(row)
            (output / 'results.json').write_text(json.dumps(rows, indent=2) + '\n')
        destination = output / f'batch-{repeat}'
        destination.mkdir()
        argv = [executable, '-f', args.format, '-o', destination] + (['--png-imageio-only'] if args.png_imageio_only else []) + [i['path'] for i in entries]
        batch = dict(repeat=repeat, command=[str(a) for a in argv],
                     **measure(argv, output / f'batch-{repeat}.log'))
        batch_log = (output / f'batch-{repeat}.log').read_text()
        failures = [line for line in batch_log.splitlines() if line.startswith('  [Failed] ')]
        batch['done_count'] = sum(line.startswith('  [Done] ') for line in batch_log.splitlines())
        batch['skipped_count'] = sum('Skipped: output would be larger than source' in line for line in failures)
        batch['failed_count'] = len(failures) - batch['skipped_count']
        batch['accounted_count'] = batch['done_count'] + len(failures)
        batch['output_bytes'] = sum(p.stat().st_size for p in destination.iterdir())
        batch['output_count'] = len(list(destination.iterdir()))
        batches.append(batch)
    (output / 'batches.json').write_text(json.dumps(batches, indent=2) + '\n')
    keys = ['path', 'category', 'split', 'repeat', 'status', 'input_bytes', 'output_bytes', 'seconds', 'peak_rss_bytes', 'quality_score', 'quality_status', 'output_sha256']
    with (output / 'results.csv').open('w') as stream:
        writer = csv.DictWriter(stream, fieldnames=keys, extrasaction='ignore')
        writer.writeheader()
        writer.writerows(rows)
    lines = ['# Compression baseline', '', 'CLI end-to-end measurements; includes startup. Missing quality scores are not quality approval.', '',
             '| Split / category | Runs | Done / skipped / failed | Total byte reduction | Time P50 / P95 (s) | Maximum process peak RSS (MiB) | Quality measured / failed |',
             '| --- | ---: | --- | ---: | --- | ---: | --- |']
    for split, category in sorted({(r['split'], r['category']) for r in rows}):
        group = [r for r in rows if (r['split'], r['category']) == (split, category)]
        counts = [sum(r['status'] == s for r in group) for s in ['done', 'skipped_not_smaller', 'failed']]
        times = [r['seconds'] for r in group]
        total = sum(r['input_bytes'] for r in group)
        effective = sum(r['output_bytes'] if r['status'] == 'done' else r['input_bytes'] for r in group)
        reduction = f'{1 - effective/total:.2%}' if not counts[2] else 'invalid (failed images)'
        quality = [sum(r['quality_status'] == state for r in group) for state in ['measured', 'metric_failed']]
        lines.append(f'| {split} / {category} | {len(group)} | {counts[0]} / {counts[1]} / {counts[2]} | {reduction} | {percentile(times, .5):.3f} / {percentile(times, .95):.3f} | {max(r["peak_rss_bytes"] for r in group)/1048576:.1f} | {quality[0]} / {quality[1]} |')
    (output / 'report.md').write_text('\n'.join(lines) + '\n')
    print(output / 'report.md')
    return int(any(r['status'] == 'failed' or r['quality_status'] == 'metric_failed' for r in rows)
               or any(b['exit_code'] not in (0, 1) or b['failed_count'] or b['accounted_count'] != len(entries) or b['done_count'] != b['output_count'] for b in batches))


if __name__ == '__main__':
    sys.exit(main())

#!/usr/bin/env python3
"""Compare matched manifests without dropping skipped/failed images from denominators."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import statistics
import subprocess


def percentile(values, p):
    return sorted(values)[max(0, math.ceil(len(values) * p) - 1)]


def effective_bytes(row):
    if row['status'] == 'done':
        return row['output_bytes']
    if row['status'] == 'skipped_not_smaller':
        return row['input_bytes']
    raise ValueError('Failed image must be resolved before comparing compression effectiveness')


def load(directory):
    environment = json.loads((directory / 'environment.json').read_text())
    rows = json.loads((directory / 'results.json').read_text())
    indexed = {(r['sha256'], r['path'], r['repeat']): r for r in rows}
    if len(indexed) != len(rows):
        raise ValueError('Duplicate measurement keys')
    return environment, indexed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('reference', type=Path)
    parser.add_argument('candidate', type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--pixel-oracle', type=Path)
    args = parser.parse_args()
    reference_env, reference = load(args.reference)
    candidate_env, candidate = load(args.candidate)
    for key in ['manifest_sha256', 'format', 'repeat', 'executable_sha256', 'cli_policy']:
        if reference_env[key] != candidate_env[key]:
            parser.error(f'Unmatched {key}; this comparator requires one binary and one manifest')
    if reference.keys() != candidate.keys():
        parser.error('Measurements are missing or unmatched')
    args.output.mkdir(parents=True, exist_ok=False)
    groups = []
    for split, category in sorted({(r['split'], r['category']) for r in reference.values()}):
        keys = [key for key, row in reference.items() if (row['split'], row['category']) == (split, category)]
        old = [reference[k] for k in keys]
        new = [candidate[k] for k in keys]
        before, after = sum(map(effective_bytes, old)), sum(map(effective_bytes, new))
        groups.append(dict(split=split, category=category, measurements=len(keys),
                           reference_effective_bytes=before, candidate_effective_bytes=after,
                           reduction=1-after/before,
                           median_file_reduction=statistics.median(1-effective_bytes(b)/effective_bytes(a) for a,b in zip(old,new)),
                           reference_seconds_p50=percentile([r['seconds'] for r in old],.5),
                           candidate_seconds_p50=percentile([r['seconds'] for r in new],.5),
                           reference_seconds_p95=percentile([r['seconds'] for r in old],.95),
                           candidate_seconds_p95=percentile([r['seconds'] for r in new],.95),
                           reference_peak_rss_bytes=max(r['peak_rss_bytes'] for r in old),
                           candidate_peak_rss_bytes=max(r['peak_rss_bytes'] for r in new),
                           size_regressions=sum(effective_bytes(b)>effective_bytes(a) for a,b in zip(old,new))))
    checks = []
    seen = set()
    for key, row in candidate.items():
        old = reference[key]
        if row['status'] != 'done':
            continue
        output = Path(row['output_path'])
        source = Path(old['output_path']) if old['status']=='done' else Path(old['path'])
        pair_key = (old.get('output_sha256') or old['sha256'], row['output_sha256'])
        if (hashlib.sha256(source.read_bytes()).hexdigest(), hashlib.sha256(output.read_bytes()).hexdigest()) != pair_key:
            raise ValueError('Reference or candidate output changed after measurement')
        if pair_key in seen:
            continue
        seen.add(pair_key)
        check = {'input':row['path'], 'reference':str(source), 'candidate':str(output), 'same_bytes':pair_key[0]==pair_key[1]}
        if args.pixel_oracle and output.suffix.lower()=='.png':
            result = subprocess.run([str(args.pixel_oracle.resolve()), str(source), str(output)], capture_output=True, text=True)
            check.update(oracle_exit_code=result.returncode, oracle_stdout=result.stdout, oracle_stderr=result.stderr)
        check['unchanged_format_regression'] = output.suffix.lower() != '.png' and not check['same_bytes']
        checks.append(check)
    batches = {}
    for name, folder in [('reference',args.reference),('candidate',args.candidate)]:
        data = json.loads((folder/'batches.json').read_text())
        if any(r.get('failed_count',0) or r['exit_code'] not in (0,1) for r in data):
            raise ValueError('Batch failures prevent acceptance')
        batches[name] = {'median_seconds':statistics.median(r['seconds'] for r in data),
                         'maximum_peak_rss_bytes':max(r['peak_rss_bytes'] for r in data)}
    report = {'groups':groups,'batches':batches,'pixel_checks':checks,
              'pixel_oracle_sha256':hashlib.sha256(args.pixel_oracle.read_bytes()).hexdigest() if args.pixel_oracle else None,
              'reference':str(args.reference.resolve()),'candidate':str(args.candidate.resolve()),
              'note':'Effective bytes include original bytes for skips. Sums include all repetitions. Pixel oracle checks normalized displayed RGBA, not hidden RGB.'}
    (args.output/'comparison.json').write_text(json.dumps(report,indent=2)+'\n')
    lines=['# Matched PNG optimization comparison','','Skipped images count at original size. No failed image is silently excluded.','',
           '| Split / category | Runs | Total byte reduction | Median file reduction | P95 seconds before → after | Size regressions |',
           '| --- | ---: | ---: | ---: | --- | ---: |']
    for g in groups:
        lines.append(f'| {g["split"]} / {g["category"]} | {g["measurements"]} | {g["reduction"]:.2%} | {g["median_file_reduction"]:.2%} | {g["reference_seconds_p95"]:.3f} → {g["candidate_seconds_p95"]:.3f} | {g["size_regressions"]} |')
    lines += ['', 'Batch measurements:', '', json.dumps(batches,indent=2), '',
              f'Unique output pairs: {len(checks)}. Pixel oracle checked: {sum("oracle_exit_code" in c for c in checks)}; mismatches/errors: {sum(c.get("oracle_exit_code",0)!=0 for c in checks)}.',
              f'Non-PNG changed outputs: {sum(c["unchanged_format_regression"] for c in checks)}.',
              'No automatic visual approval is inferred from this report.']
    (args.output/'comparison.md').write_text('\n'.join(lines)+'\n')
    print(args.output/'comparison.md')
    return int(any(g['size_regressions'] for g in groups) or any(c.get('oracle_exit_code',0)!=0 or c['unchanged_format_regression'] for c in checks))


if __name__ == '__main__':
    raise SystemExit(main())

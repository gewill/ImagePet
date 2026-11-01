#!/usr/bin/env python3
"""Create a frozen, attributed manifest from pngdeer's existing local fixture corpus."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('repository', type=Path)
parser.add_argument('output', type=Path)
parser.add_argument('--per-category', type=int, default=6)
parser.add_argument('--offset-per-category', type=int, default=0)
parser.add_argument('--corpus', choices=['images', 'images-holdout'], default='images')
parser.add_argument('--split', choices=['tuning', 'holdout'], help='Assign the entire selection to one split')
args = parser.parse_args()
if args.offset_per_category < 0:
    parser.error('offset must be nonnegative')
if args.per_category < 3:
    parser.error('use at least 3 per category to include tuning and holdout')
base = args.repository.resolve() / 'bench' / args.corpus
rows = []
seen = {}
for line in (base / 'SOURCES.md').read_text().splitlines():
    match = re.match(r'\| `([^`]+)` \| (.+) \| (.+) \|', line)
    if not match:
        continue
    relative, source, license_name = match.groups()
    path = (base / relative).resolve()
    if base not in path.parents or not path.is_file() or path.suffix.lower() != '.png':
        continue
    category = relative.split('/')[0]
    seen[category] = seen.get(category, 0) + 1
    if seen[category] <= args.offset_per_category:
        continue
    count = sum(row['category'] == category for row in rows)
    if count >= args.per_category:
        continue
    rows.append(dict(path=str(path), category=category, split=args.split or ('holdout' if count % 3 == 2 else 'tuning'),
                     source=source, license=license_name,
                     sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
if not rows:
    parser.error('no documented local PNG fixtures found')
manifest = {'schema_version': 1,
            'source_repository_commit': subprocess.check_output(['git', '-C', str(args.repository), 'rev-parse', 'HEAD'], text=True).strip(),
            'selection': f'{args.per_category} existing PNGs after offset {args.offset_per_category} per category in {args.corpus}/SOURCES.md order; split={args.split or "every third held out"}',
            'images': rows}
with args.output.open('x') as stream:
    json.dump(manifest, stream, indent=2)
    stream.write('\n')
print(f'{len(rows)} fixtures: {args.output}')

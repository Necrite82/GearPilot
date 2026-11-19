"""Download AllTheThings' WoW Forever dungeon and raid files (MIT) for GearPilot's dungeon data.

Writes the files below OUT (default: work/att) as AllTheThings has them in .contrib/.db/forever/:
  dungeons & raids/*.lua   instances, encounters (bosses), their creatures and loot
  .config/constants/maps.lua  MAP names -> UI map IDs (dungeon entrances)
plus att.json with the commit, so the build can name its source. Set GITHUB_TOKEN for a higher API limit.
"""
import argparse
import json
import os
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

UA = 'GearPilot-dungeons/1.0 (+https://github.com/Necrite82/GearPilot)'
REPO = 'ATTWoWAddon/AllTheThings'
ROOT = '.contrib/.db/forever/'
WANTED = ('dungeons & raids/', '.config/constants/maps.lua')


def get(url, api=False, tries=4):
    headers = {'User-Agent': UA}
    if api:
        headers['Accept'] = 'application/vnd.github+json'
        token = os.environ.get('GITHUB_TOKEN')
        if token:
            headers['Authorization'] = 'Bearer ' + token
    for attempt in range(tries):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=120) as r:
                return r.read()
        except Exception as err:  # network hiccups: retry with a pause, then give up loudly
            if attempt == tries - 1:
                raise
            print(f'  retry {attempt + 1} for {url}: {err}', file=sys.stderr)
            time.sleep(5 * (attempt + 1))


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--out', type=Path, default=Path('work/att'))
    args = ap.parse_args()
    head = json.loads(get(f'https://api.github.com/repos/{REPO}/commits/HEAD', api=True))['sha']
    tree = json.loads(get(f'https://api.github.com/repos/{REPO}/git/trees/{head}?recursive=1', api=True))
    if tree.get('truncated'):
        print('warning: the tree listing is truncated', file=sys.stderr)
    paths = sorted(t['path'] for t in tree['tree'] if t['type'] == 'blob' and t['path'].startswith(ROOT)
                   and t['path'][len(ROOT):].startswith(WANTED) and t['path'].endswith('.lua'))
    if not any(p.endswith('maps.lua') for p in paths) or len(paths) < 10:
        raise SystemExit(f'AllTheThings layout changed: found {len(paths)} files under {ROOT}')
    for path in paths:
        target = args.out / path[len(ROOT):]
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(get('https://raw.githubusercontent.com/%s/%s/%s' % (REPO, head, urllib.parse.quote(path))))
    (args.out / 'att.json').write_text(json.dumps({'repo': REPO, 'commit': head, 'files': len(paths)}, indent=1))
    print(f'AllTheThings {head[:7]}: {len(paths)} files in {args.out}')


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Upload dist/GearPilot-<version>.zip to CurseForge (WoW Forever).

    CF_API_TOKEN=... python3 tools/upload_curseforge.py v1.0.0 [--dry-run]

The project ID is the TOC field "## X-Curse-Project-ID". The changelog is docs/RELEASE_<version>.md. ForeverDB is a
required dependency (the CurseForge app installs it with GearPilot); Auctionator and TomTom are optional. The release
type is "release" so the CurseForge app offers the file to everyone. Game version: WoW Forever (CurseForge ID 17053,
the same ID CraftPilot and QuestieDB upload with).
"""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
TOC = ROOT / 'GearPilotPro' / 'GearPilotPro.toc'
API = 'https://wow.curseforge.com/api'
FOREVER_GAME_VERSION = 17053
RELATIONS = [
    {'slug': 'forever-db', 'type': 'requiredDependency'},
    {'slug': 'auctionator', 'type': 'optionalDependency'},
    {'slug': 'tomtom', 'type': 'optionalDependency'},
]


def toc_field(name):
    for line in TOC.read_text(encoding='utf-8').splitlines():
        if line.startswith(f'## {name}:'):
            return line.split(':', 1)[1].strip()
    return None


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('tag')
    p.add_argument('--dry-run', action='store_true')
    args = p.parse_args()
    m = re.fullmatch(r'v(\d+\.\d+\.\d+)', args.tag)
    if not m:
        raise SystemExit('Tag must look like v1.2.3')
    version = m.group(1)
    if toc_field('Version') != version:
        raise SystemExit(f'TOC version {toc_field("Version")} does not match {args.tag}')
    project = toc_field('X-Curse-Project-ID')
    if not project or not project.isdigit():
        raise SystemExit('Set "## X-Curse-Project-ID: <id>" in GearPilotPro.toc first')
    archive = ROOT / 'dist' / f'GearPilot-{version}.zip'
    notes = ROOT / 'docs' / f'RELEASE_{version}.md'
    if not archive.is_file() or not notes.is_file():
        raise SystemExit(f'Missing {archive.name} or {notes.name}')
    metadata = {
        'displayName': f'GearPilot {version}',
        'releaseType': 'release',
        'changelog': notes.read_text(encoding='utf-8'),
        'changelogType': 'markdown',
        'gameVersions': [FOREVER_GAME_VERSION],
        'relations': {'projects': RELATIONS},
    }
    if args.dry_run:
        print(json.dumps({k: v for k, v in metadata.items() if k != 'changelog'}, indent=2))
        print(f'Dry run: would upload {archive.name} to project {project}')
        return
    token = os.environ.get('CF_API_TOKEN')
    if not token:
        raise SystemExit('CF_API_TOKEN is required')
    result = subprocess.run(
        ['curl', '-sS', '--fail-with-body', '--connect-timeout', '30', '--max-time', '600',
         '-H', f'X-Api-Token: {token}', '--form-string', f'metadata={json.dumps(metadata)}',
         '-F', f'file=@{archive}', f'{API}/projects/{project}/upload-file'],
        capture_output=True, text=True)
    if result.returncode != 0:
        raise SystemExit(f'Upload failed: {result.stdout or result.stderr}')
    print(f'Uploaded {archive.name}: {result.stdout.strip()}')


if __name__ == '__main__':
    main()

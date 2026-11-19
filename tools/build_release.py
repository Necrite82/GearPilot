"""Build or verify the install archive dist/GearPilot-<version>.zip (folder GearPilotPro inside)."""
import argparse
from pathlib import Path
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / 'GearPilotPro'
EXTRA = ['LICENSE', 'README.md']


def files():
    names = sorted(p.relative_to(ADDON).as_posix() for p in ADDON.rglob('*') if p.is_file())
    # Every file the TOC loads must be in the package, or the addon breaks in game.
    toc = (ADDON / 'GearPilotPro.toc').read_text(encoding='utf-8').splitlines()
    loaded = {line.strip().replace('\\', '/') for line in toc if line.strip() and not line.startswith('#')}
    missing = sorted(loaded - set(names))
    if missing:
        raise SystemExit('TOC loads missing files: ' + ', '.join(missing))
    return [('GearPilotPro/' + n, ADDON / n) for n in names] + [('GearPilotPro/' + n, ROOT / n) for n in EXTRA]


def source_bytes(path):
    data = path.read_bytes()
    return data if path.suffix in ('.tga', '.png', '.blp') else data.replace(b'\r\n', b'\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='only verify the committed archive')
    parser.add_argument('--out', type=Path, default=ROOT / 'dist')
    args = parser.parse_args()
    version = next(line.split(':', 1)[1].strip() for line in
                   (ADDON / 'GearPilotPro.toc').read_text(encoding='utf-8').splitlines()
                   if line.startswith('## Version:'))
    entries = files()
    args.out.mkdir(parents=True, exist_ok=True)
    archive = args.out / f'GearPilot-{version}.zip'
    if not args.check:
        for old in args.out.glob('GearPilot-*.zip'):
            old.unlink()
        with ZipFile(archive, 'w', compression=ZIP_DEFLATED) as output:
            for name, path in entries:
                info = ZipInfo(name, (2026, 11, 19, 0, 0, 0))
                info.compress_type = ZIP_DEFLATED
                info.external_attr = 0o644 << 16
                output.writestr(info, source_bytes(path))
    if not archive.exists():
        raise SystemExit(f'{archive.name} is missing: run python3 tools/build_release.py')
    with ZipFile(archive) as output:
        assert output.testzip() is None
        names = set(output.namelist())
        expected = {name for name, _ in entries}
        if names != expected:
            raise SystemExit(f'{archive.name} is out of date (files differ): run python3 tools/build_release.py')
        for name, path in entries:
            if output.read(name) != source_bytes(path):
                raise SystemExit(f'{archive.name} is out of date ({name}): run python3 tools/build_release.py')
    print(f'PASS: {archive.name}, {len(entries)} files match the source')


if __name__ == '__main__':
    main()

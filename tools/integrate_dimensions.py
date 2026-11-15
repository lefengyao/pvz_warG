"""One-shot, manifest-backed integration; defaults to a read-only mapping preview."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OLD = ROOT / 'pvz_warG'
TEXT = {'.gd', '.gdshader', '.tscn', '.tres', '.godot', '.import', '.ps1', '.md', '.py', '.cfg'}
EXCLUDED = {'.git', '.godot', '.codex', '.superpowers', '.specloom', '__pycache__', 'logs'}
SHARED_FILES = {
    'src/autoload/audiomanager.gd': 'shared/src/audio/audiomanager.gd',
    'src/autoload/event_bus.gd': 'shared/src/events/event_bus.gd',
    'src/core/general_character.gd': 'shared/src/characters/general_character.gd',
    'src/core/state_base.gd': 'shared/src/state_machine/state_base.gd',
    'src/core/state_machine.gd': 'shared/src/state_machine/state_machine.gd',
    'src/ui/scene_transition.gd': 'shared/src/ui/scene_transition.gd',
    'src/ui/screen_fade.gd': 'shared/src/ui/screen_fade.gd',
    'src/ui/music/music_setting.gd': 'shared/src/audio/music_setting.gd',
    'scenes/ui/screen_fade.tscn': 'shared/scenes/ui/screen_fade.tscn',
}
SHARED_PREFIXES = {
    'assets/audio/': 'shared/assets/audio/',
    'assets/fonts/': 'shared/assets/fonts/',
    'resources/audio/': 'shared/resources/audio/',
    'resources/shaders/': 'shared/resources/shaders/',
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def files(root):
    return sorted(p for p in root.rglob('*') if p.is_file()
                  and not any(part in EXCLUDED for part in p.relative_to(root).parts))


def map_2d(rel):
    base = rel.removesuffix('.uid')
    if base in SHARED_FILES:
        return SHARED_FILES[base] + ('.uid' if rel.endswith('.uid') else '')
    for prefix, target in SHARED_PREFIXES.items():
        if rel.startswith(prefix):
            return target + rel[len(prefix):]
    return '2d/' + rel


def map_3d(rel):
    # These unreferenced prototypes have the same UIDs as newer 2D scenes,
    # including one scene with missing script paths. Keep them in the archive.
    if rel.startswith('UI/') and rel.endswith(('.gd', '.tscn')) and not rel.startswith('UI/FPSLabel.gd'):
        return None
    if rel.startswith('Map/FrontYard/'):
        name = rel[len('Map/FrontYard/'):]
        if name.endswith('.ps1') or 'runtime_test.gd' in name:
            return 'tests/3d/front_yard/' + name
        return '3d/scenes/maps/front_yard/' + name
    for prefix, target in {
        'Manager/': '3d/src/managers/',
        'Scene/CardsBox/': '3d/scenes/cards_box/',
        'Scene/Settings/': 'shared/scenes/settings/',
        'Assets/Textures/': '3d/assets/environment/',
        'Assets/Music/': 'shared/assets/audio/prototype/',
        'Assets/Font/': 'shared/assets/fonts/prototype/',
        'Tool/StateMachine/': 'shared/src/state_machine/',
        'UI/': '2d/scenes/ui/prototype/',
        'Plants/': '2d/assets/textures/prototype/plants/',
        'Special/': 'shared/assets/textures/special/',
        'Zombies/': '3d/scenes/zombies/',
        'addons/': 'addons/',
    }.items():
        if rel.startswith(prefix):
            if rel.startswith('Scene/Settings/setting_scene_structure_test.gd'):
                return 'tests/shared/' + rel.rsplit('/', 1)[-1]
            if rel.startswith('UI/FPSLabel.gd'):
                return 'shared/src/ui/' + rel.rsplit('/', 1)[-1]
            return target + rel[len(prefix):]
    if rel in ('test.tscn',):
        return '3d/scenes/sandbox/' + rel
    if rel.startswith('icon.svg'):
        return '3d/assets/' + rel
    return None


def resource_uid(path):
    sidecar = Path(str(path) + '.uid')
    if sidecar.is_file():
        return sidecar.read_text(encoding='utf-8-sig').strip()
    metadata = Path(str(path) + '.import')
    owner = metadata if metadata.is_file() else path
    if owner.suffix not in {'.import', '.tscn', '.tres'}:
        return None
    match = re.search(r'\buid="(uid://[^"\s]+)"', owner.read_text(encoding='utf-8-sig'))
    return match[1] if match else None


def mapping():
    entries = []
    maps = {'2d': {}, '3d': {}}
    sources = {}
    for folder in ('src', 'scenes', 'assets', 'resources'):
        for path in files(ROOT / folder):
            rel = path.relative_to(ROOT).as_posix()
            target = map_2d(rel)
            maps['2d'][rel] = target
            sources[target] = path
            entries.append({'origin': '2d', 'source': rel, 'target': target,
                            'sha256': digest(path), 'source_uid': resource_uid(path)})
    aliases = {
        'AutoLoads/AudioManager.gd': 'src/autoload/audiomanager.gd',
        'AutoLoads/EventBus.gd': 'src/autoload/event_bus.gd',
        'Tool/Character/Character.gd': 'src/core/general_character.gd',
    }
    uids = {}
    media_by_hash = {}
    media_ext = {'.png', '.svg', '.jpg', '.jpeg', '.webp', '.wav', '.mp3', '.ogg', '.ttf', '.otf'}
    for target, source in sources.items():
        if source.suffix.lower() in media_ext:
            media_by_hash.setdefault(digest(source), (target, source))
    old_files = [p for p in files(OLD) if p.relative_to(OLD).parts[0] != 'pvz_warG']
    for path in old_files:
        rel = path.relative_to(OLD).as_posix()
        if path.suffix in {'.uid', '.import'}:
            continue
        target = map_3d(rel)
        canonical = None
        if rel in aliases:
            canonical = ROOT / aliases[rel]
            if digest(path) != digest(canonical):
                raise RuntimeError('Shared source differs: ' + rel)
            target = maps['2d'][aliases[rel]]
        elif path.suffix.lower() in media_ext and digest(path) in media_by_hash:
            target, canonical = media_by_hash[digest(path)]
        if target is None:
            continue
        maps['3d'][rel] = target
        entries.append({'origin': '3d', 'source': rel, 'target': target, 'sha256': digest(path),
                        'source_uid': resource_uid(path), 'alias': canonical is not None})
        if canonical:
            old_uid, new_uid = resource_uid(path), resource_uid(canonical)
            if old_uid and new_uid and old_uid != new_uid:
                uids[old_uid] = new_uid
        elif target in sources:
            raise RuntimeError('Destination collision: ' + target)
        else:
            sources[target] = path
        for suffix in ('.uid', '.import'):
            sidecar = Path(str(path) + suffix)
            if sidecar.is_file():
                maps['3d'][rel + suffix] = target + suffix
                entries.append({'origin': '3d', 'source': rel + suffix, 'target': target + suffix,
                                'sha256': digest(sidecar), 'alias': canonical is not None})
                if canonical is None:
                    sources[target + suffix] = sidecar
    return entries, maps, sources, uids


def rewriter(paths, uid_map=None):
    replacements = {'res://' + key: 'res://' + value for key, value in paths.items()}
    replacements.update(uid_map or {})
    pattern = re.compile('|'.join(re.escape(key) for key in sorted(replacements, key=len, reverse=True)))
    return lambda content: pattern.sub(lambda match: replacements[match[0]], content)


def execute(backup):
    if (ROOT / 'docs/maintenance/integration_manifest.json').exists():
        raise RuntimeError('Integration is already recorded; do not replay this one-shot migration')
    if not backup.is_dir() or backup.resolve().is_relative_to(ROOT):
        raise RuntimeError('Existing backup outside the active project is required')
    entries, maps, sources, uids = mapping()
    for folder in ('src', 'scenes', 'assets', 'resources', 'pvz_warG'):
        if (backup / ('archived_' + folder)).exists():
            raise RuntimeError('Archive already exists: ' + folder)
    for target in sources:
        destination = ROOT / target
        if destination.exists():
            raise RuntimeError('Refusing to overwrite: ' + str(destination))
        if not destination.resolve().is_relative_to(ROOT):
            raise RuntimeError('Destination escapes project root')
    # Copy first, hash-check everything, then relocate the preserved originals.
    for target, source in sources.items():
        destination = ROOT / target
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
        if digest(source) != digest(destination):
            raise RuntimeError('Copy hash mismatch: ' + target)
    shared_prefixes = dict(SHARED_PREFIXES)
    shared_prefixes.update({p: '2d/' + p for p in ('src/', 'assets/', 'scenes/', 'resources/')})
    # Prefixes handle runtime-composed resource paths; specific file mappings take precedence.
    root_paths = {**shared_prefixes, **maps['2d']}
    rewrite_2d = rewriter(root_paths)
    rewrite_3d = rewriter(maps['3d'], uids)
    for target, source in sources.items():
        destination = ROOT / target
        if destination.suffix.lower() not in TEXT:
            continue
        content = destination.read_text(encoding='utf-8-sig')
        new_content = (rewrite_3d if source.is_relative_to(OLD) else rewrite_2d)(content)
        if target.startswith('tests/3d/front_yard/') and destination.suffix == '.ps1':
            new_content = new_content.replace('$PSScriptRoot', '$frontYardModule')
            new_content = "$integrationRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))\n$frontYardModule = Join-Path $integrationRoot '3d/scenes/maps/front_yard'\n" + new_content
            new_content = new_content.replace("Join-Path $frontYard '..\\..\\Assets\\Textures\\Road\\Brick'", "Join-Path $integrationRoot '3d/assets/environment/Road/Brick'")
            new_content = new_content.replace("Join-Path $root 'front_yard_lawn_optimization_runtime_test.gd'", "Join-Path $PSScriptRoot 'front_yard_lawn_optimization_runtime_test.gd'")
        if new_content != content:
            destination.write_text(new_content, encoding='utf-8', newline='\n')
    for path in [ROOT / 'project.godot', *files(ROOT / 'tests')]:
        if path.suffix not in TEXT or path.is_relative_to(ROOT / 'tests/3d') or path.is_relative_to(ROOT / 'tests/shared'):
            continue
        content = path.read_text(encoding='utf-8-sig')
        new_content = rewrite_2d(content)
        if content != new_content:
            path.write_text(new_content, encoding='utf-8', newline='\n')
    archived = [{'source': p.relative_to(OLD).as_posix(), 'sha256': digest(p)}
                for p in files(OLD) if p.relative_to(OLD).parts[0] != 'pvz_warG'
                and p.relative_to(OLD).as_posix() not in maps['3d']]
    manifest = {'root': str(ROOT), 'backup': str(backup), 'moves': maps,
                'uid_aliases': uids, 'files': entries, 'archived_3d_files': archived}
    manifest_path = ROOT / 'docs/maintenance/integration_manifest.json'
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    for folder in ('src', 'scenes', 'assets', 'resources', 'pvz_warG'):
        source = ROOT / folder
        target = backup / ('archived_' + folder)
        if not source.resolve().is_relative_to(ROOT) or target.exists():
            raise RuntimeError('Archive path is unsafe or already exists: ' + str(target))
        archive_directory(source, target)
    print(json.dumps({'copied': len(sources), 'mapped': len(entries), 'uid_aliases': uids,
                      'manifest': str(manifest_path)}, ensure_ascii=False))


def archive_directory(source, target):
    if source.resolve().parent != ROOT or target.exists():
        raise RuntimeError('Archive paths are unsafe or already exist')
    try:
        source.rename(target)
    except PermissionError:
        # Windows can hold the workspace directory as a process cwd. Preserve
        # every child in the archive while leaving that empty directory open.
        target.mkdir()
        for child in source.iterdir():
            if os.name == 'nt':
                # Native -Force also handles hidden directories such as .git.
                environment = dict(os.environ, PVZ_ARCHIVE_SOURCE=str(child),
                                   PVZ_ARCHIVE_TARGET=str(target))
                subprocess.run(['powershell.exe', '-NoProfile', '-Command',
                                'Move-Item -LiteralPath $env:PVZ_ARCHIVE_SOURCE '
                                '-Destination $env:PVZ_ARCHIVE_TARGET -Force -ErrorAction Stop'],
                               env=environment, check=True)
            else:
                child.rename(target / child.name)
        try:
            source.rmdir()
        except PermissionError:
            print('Empty workspace directory remains open: ' + str(source))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--backup', type=Path)
    args = parser.parse_args()
    if args.apply:
        if args.backup is None:
            parser.error('--backup is required with --apply')
        execute(args.backup.resolve())
    else:
        recorded_manifest = ROOT / 'docs/maintenance/integration_manifest.json'
        if recorded_manifest.is_file():
            recorded = json.loads(recorded_manifest.read_text(encoding='utf-8'))
            print(json.dumps({'status': 'already_integrated', 'mapped_files': len(recorded['files']),
                              'manifest': str(recorded_manifest)}, ensure_ascii=False, indent=2))
            return
        entries, _, sources, uids = mapping()
        counts = {}
        for target in sources:
            category = target.split('/')[0]
            counts[category] = counts.get(category, 0) + 1
        print(json.dumps({'mapped_files': len(entries), 'active_files': len(sources),
                          'categories': counts, 'uid_aliases': uids}, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()

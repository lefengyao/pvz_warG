"""Check integrated resource links, UID ownership and both migration baselines."""
from pathlib import Path, PurePosixPath
import hashlib
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
ACTIVE_ROOTS = ("2d", "3d", "shared", "addons", "tests", "tools")
TEXT = {".gd", ".gdshader", ".tscn", ".tres", ".godot", ".import", ".cfg"}
MEDIA = {".png", ".svg", ".jpg", ".jpeg", ".webp", ".wav", ".mp3", ".ogg",
         ".ttf", ".otf", ".glb", ".gltf", ".bin", ".obj", ".fbx"}
IGNORED = {".godot", ".git", ".codex", ".superpowers", "__pycache__", "logs"}
UID = r"uid://[a-z0-9]+"
# Removed by menu refactor 721ccab, before integration plan a2720ef. Match both
# historical source and previous target so other missing files remain errors.
RETIRED_HISTORY_PATHS = {
    "Scrips/maps/general/map_button.gd": "src/levels/general/map_button.gd",
    "Scrips/maps/general/map_button.gd.uid": "src/levels/general/map_button.gd.uid",
}
# Lex comments before examining quoted strings. A '#' inside a music filename
# is data, while documentation examples are not resource links.
STRINGS = re.compile(
    r'''(?P<comment>\#[^\r\n]*|//[^\r\n]*|^[ \t]*;[^\r\n]*)'''
    r'''|(?P<doc>"""[\s\S]*?"""|\x27\x27\x27[\s\S]*?\x27\x27\x27)'''
    r'''|(?P<quote>["'])(?P<value>(?:\\.|(?!(?P=quote))[^\\\r\n])*)(?P=quote)''',
    re.MULTILINE,
)


def declared_uid(rel, content):
    """External resource UIDs belong to their dependencies, not the scene."""
    suffix = PurePosixPath(rel).suffix.lower()
    if suffix == ".uid":
        return content.strip() if re.fullmatch(UID, content.strip()) else None
    if suffix == ".import":
        pattern = rf'^uid\s*=\s*"({UID})"'
    elif suffix in {".tscn", ".tres"}:
        pattern = rf'^\[gd_(?:scene|resource)\b[^\r\n]*\buid="({UID})"'
    else:
        return None
    match = re.search(pattern, content, re.MULTILINE)
    return match[1] if match else None


def resource_links(content):
    """Yield static paths or the known prefix of a constructed resource path."""
    for match in STRINGS.finditer(content):
        value = match["value"]
        if value is None:
            continue
        value = value.removeprefix("*")
        if not value.startswith("res://"):
            continue
        target = value[6:].split("::", 1)[0]
        if target in {".godot", "tools/logs"} or target.startswith((".godot/", "tools/logs/")):
            continue
        marker = re.search(r'%[-+0 #\d.]*[sdifuxXobceEgGv]|\{|\[|\*|\?', target)
        tail = content[match.end():]
        dynamic = bool(marker or re.match(r"\s*(?:\+|%|\.format\s*\(|\.path_join\s*\()", tail))
        if marker:
            target = target[:marker.start()]
        yield target, dynamic


def verify():
    errors = []
    files = []
    directories = {""}
    # Explicit roots keep the old nested projects and backup/history files out
    # of active UID ownership checks.
    for base in [ROOT / "project.godot", *(ROOT / name for name in ACTIVE_ROOTS)]:
        if base.is_dir():
            directories.add(base.relative_to(ROOT).as_posix())
        candidates = [base] if base.is_file() else base.rglob("*")
        for path in candidates:
            relative = path.relative_to(ROOT)
            if any(part in IGNORED for part in relative.parts):
                continue
            if path.is_dir():
                directories.add(relative.as_posix())
            elif path.is_file():
                files.append(path)
    by_path = {p.relative_to(ROOT).as_posix(): p for p in files}
    for rel in by_path:
        directories.update(p.as_posix() for p in PurePosixPath(rel).parents if p.as_posix() != ".")
    paths = set(by_path) | directories
    texts = {}
    owned_uids = {}
    uids = {}
    for rel, path in sorted(by_path.items()):
        if path.suffix.lower() not in TEXT | {".uid"}:
            continue
        try:
            content = path.read_text(encoding="utf-8-sig")
        except (OSError, UnicodeError) as error:
            errors.append(f"Cannot read resource: {rel}: {error}")
            continue
        texts[rel] = content
        uid = declared_uid(rel, content)
        if path.suffix.lower() == ".uid" and uid is None:
            errors.append(f"Invalid UID sidecar: {rel}")
        if uid:
            owned_uids[rel] = uid
            owner = rel.removesuffix(".uid").removesuffix(".import")
            if uid in uids and uids[uid] != owner:
                errors.append(f"Duplicate UID {uid}: {uids[uid]} / {owner}")
            uids[uid] = owner

    links = 0
    skipped_link_files = 0
    skipped_bridge_files = 0
    for rel, content in texts.items():
        if rel.endswith(".uid"):
            continue
        parts = PurePosixPath(rel).parts
        plugin_test = parts[0] == "addons" and (
            "tests" in parts[2:-1] or PurePosixPath(rel).stem.endswith("_test")
            or PurePosixPath(rel).stem.startswith("test_"))
        if rel.startswith("addons/godot_mcp/"):
            # The local editor bridge contains templates, optional config and
            # output paths. Its UID owners and references are still checked.
            skipped_bridge_files += 1
        elif plugin_test:
            # Negative fixtures may reference missing files. Their UIDs still
            # participate in ownership and reference validation.
            skipped_link_files += 1
        else:
            for target, dynamic in resource_links(content):
                links += 1
                found = target.rstrip("/") in paths
                if dynamic and not found:
                    found = any(path.startswith(target) for path in paths)
                if not found:
                    errors.append(f"Missing or wrong-case resource: {rel} -> {target}")
        for uid in set(re.findall(UID, content)):
            if uid not in uids:
                errors.append(f"Unknown UID: {rel} -> {uid}")

    for legacy in ("assets", "src", "scenes", "resources", "Scrips", "UI", "plant",
                   "plants", "maps", "object", "bullet", "zombies", "autoloads"):
        if (ROOT / legacy).exists():
            errors.append(f"Legacy directory still exists: {legacy}")
    for required in (*ACTIVE_ROOTS, "docs"):
        if not (ROOT / required).is_dir():
            errors.append(f"Required directory missing: {required}")
    if "project.godot" not in by_path:
        errors.append("Project configuration missing: project.godot")

    def load_manifest(name):
        try:
            return json.loads((ROOT / "docs/maintenance" / name).read_text(encoding="utf-8-sig"))
        except (OSError, ValueError) as error:
            errors.append(f"Cannot read {name}: {error}")
            return {}

    integration = load_manifest("integration_manifest.json")
    history = load_manifest("migration_manifest.json")
    moves = integration.get("moves", {})
    aliases = integration.get("uid_aliases", {})
    canonical_uids = {}
    for original in aliases:
        current = original
        seen = set()
        while current in aliases and current not in seen:
            seen.add(current)
            current = aliases[current]
        if current in seen:
            errors.append(f"Cyclic UID alias: {original}")
        else:
            canonical_uids[original] = current
            if current not in uids:
                errors.append(f"UID alias target missing: {original} -> {current}")

    def resource_uid(rel):
        for candidate in (rel + ".uid", rel + ".import", rel):
            if candidate in owned_uids:
                return owned_uids[candidate]
        # Both manifests recorded the first external UID for UID-less scenes
        # and resources. Check that reference without registering an owner.
        if PurePosixPath(rel).suffix.lower() in {".tscn", ".tres"}:
            match = re.search(rf'\buid="({UID})"', texts.get(rel, ""))
            return match[1] if match else None
        return None

    def check_uid(rel, expected):
        expected = canonical_uids.get(expected, expected)
        current = resource_uid(rel)
        if current != expected:
            errors.append(f"Original UID changed: {rel}: {expected} -> {current}")
            return False
        return True

    hashes = {}

    def check_hash(rel, expected):
        if rel not in hashes:
            hashes[rel] = hashlib.sha256(by_path[rel].read_bytes()).hexdigest()
        if hashes[rel] == expected:
            return True
        if rel.endswith(".uid"):
            # Only a declared alias may change sidecar bytes. Reconstruct the
            # original UID and require the original complete byte hash to match.
            data = by_path[rel].read_bytes()
            current = owned_uids.get(rel)
            for original, canonical in canonical_uids.items():
                if canonical == current:
                    restored = data.replace(canonical.encode("ascii"), original.encode("ascii"))
                    if hashlib.sha256(restored).hexdigest() == expected:
                        return True
        errors.append(f"Original data changed: {rel}")
        return False

    preserved = 0
    preserved_uids = 0
    integrated_preserved = 0
    integrated_uids = 0
    entries = integration.get("files", [])
    for entry in entries:
        origin, source, target = entry["origin"], entry["source"], entry["target"]
        if moves.get(origin, {}).get(source) != target:
            errors.append(f"Integration mapping mismatch: {origin}:{source} -> {target}")
        if target not in by_path:
            errors.append(f"Integration target missing: {origin}:{source} -> {target}")
            continue
        if PurePosixPath(target).suffix.lower() in MEDIA | {".uid"}:
            integrated_preserved += check_hash(target, entry["sha256"])
        if entry.get("source_uid"):
            integrated_uids += check_uid(target, entry["source_uid"])

    recorded = {(entry["origin"], entry["source"], entry["target"]) for entry in entries}
    for origin, mapping in moves.items():
        for source, target in mapping.items():
            if (origin, source, target) not in recorded:
                errors.append(f"Integration file record missing: {origin}:{source} -> {target}")
    archived = integration.get("archived_3d_files", [])
    for entry in archived:
        if entry["source"] in moves.get("3d", {}):
            errors.append(f"Archived 3D file is also mapped active: {entry['source']}")

    # Compose the old restructure with the integration map. Root project
    # configuration and historical documentation intentionally stay at the root.
    historical_targets = {}
    retired_history_paths = []
    retired_sources = set()
    for old, previous in history.get("moves", {}).items():
        if RETIRED_HISTORY_PATHS.get(old) == previous:
            if previous in moves.get("2d", {}) or "2d/" + previous in by_path:
                errors.append(f"Retired historical file is also mapped active: {old} -> {previous}")
            retired_sources.add(old)
            retired_history_paths.append({
                "source": old, "previous_target": previous,
                "reason": "Deleted by menu refactor 721ccab before integration plan a2720ef",
            })
            continue
        target = moves.get("2d", {}).get(previous, previous)
        historical_targets[old] = target
        if target not in by_path and not (ROOT / target).is_file():
            errors.append(f"Migration target missing: {old} -> {previous} -> {target}")
            continue
        if PurePosixPath(target).suffix.lower() in MEDIA | {".uid"}:
            if target not in by_path:
                errors.append(f"Migration target outside active roots: {target}")
                continue
            preserved += check_hash(target, history["sha256_before"][old])
    for old, expected in history.get("resource_uids_before", {}).items():
        if old in retired_sources:
            continue
        target = historical_targets.get(old)
        if target is None:
            errors.append(f"Historical UID mapping missing: {old}")
        else:
            preserved_uids += check_uid(target, expected)

    summary = {
        "files": len(files), "resource_links": links, "registered_uids": len(uids),
        "unchanged_media_and_uid_files": preserved, "preserved_original_uids": preserved_uids,
        "integration_files": len(entries), "integration_unchanged_media_and_uid_files": integrated_preserved,
        "integration_preserved_uids": integrated_uids, "uid_aliases": len(aliases),
        "archived_3d_files": len(archived), "plugin_test_link_files_skipped": skipped_link_files,
        "mcp_bridge_link_files_skipped": skipped_bridge_files,
        "retired_history_paths": retired_history_paths,
        "errors": sorted(set(errors)),
    }
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(verify())

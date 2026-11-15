class_name EcsSnapshotStore
extends RefCounted

const SNAPSHOT = preload("res://addons/ecsmini/runtime/persistence/ecs_snapshot.gd")
const CODEC = preload("res://addons/ecsmini/runtime/persistence/ecs_variant_codec.gd")
const FORMAT := "ecsmini.snapshot"
const MAX_FILE_BYTES := 64 * 1024 * 1024
var _migrations: Dictionary = {}

func register_migration(from_version: int, callback: Callable) -> bool:
	if from_version < 0 or from_version >= SNAPSHOT.VERSION or not callback.is_valid() or _migrations.has(from_version):
		return false
	_migrations[from_version] = callback
	return true

func migrate(snapshot: Dictionary) -> Dictionary:
	var copied := CODEC.copy(snapshot)
	if not copied.ok:
		return _error(copied.error)
	var data: Dictionary = copied.value
	if data.get("version") is not int or data.version < 0 or data.version > SNAPSHOT.VERSION:
		return _error("Unknown snapshot version.")
	while data.version < SNAPSHOT.VERSION:
		var version: int = data.version
		if not _migrations.has(version):
			return _error("No migration registered for schema version %d." % version)
		var changed: Variant = _migrations[version].call(data)
		var checked := CODEC.copy(changed)
		if not checked.ok or checked.value is not Dictionary or checked.value.get("version") is not int or checked.value.version != version + 1:
			return _error("Migration must return a safe dictionary with the next schema version.")
		data = checked.value
	return SNAPSHOT.validate(data)

func save(world: EcsWorld, path: String) -> Dictionary:
	var captured := SNAPSHOT.capture(world)
	if not captured.ok:
		return captured
	var encoded := CODEC.encode(captured.snapshot)
	var text := JSON.stringify({"format": FORMAT, "version": SNAPSHOT.VERSION, "data": encoded.value})
	if text.to_utf8_buffer().size() > MAX_FILE_BYTES:
		return _error("Snapshot file exceeds size limit.")
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _error("Cannot open temporary save file: %s" % FileAccess.get_open_error())
	file.store_string(text)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return _error("Cannot write snapshot file.")
	var result := DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))
	if result != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return _error("Cannot replace snapshot file: %s" % result)
	return {"ok": true, "error": "", "path": path}

func load_snapshot(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _error("Cannot open snapshot file.")
	if file.get_length() > MAX_FILE_BYTES:
		file.close()
		return _error("Snapshot file exceeds size limit.")
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		return _error("Malformed snapshot JSON: " + parser.get_error_message())
	var envelope: Variant = parser.data
	if envelope is not Dictionary or envelope.size() != 3 or envelope.get("format") != FORMAT or not envelope.has("data") or envelope.get("version") is not float or envelope.version != floor(envelope.version) or envelope.version < 0 or envelope.version > SNAPSHOT.VERSION:
		return _error("Unknown or malformed snapshot file format/version.")
	var decoded := CODEC.decode(envelope.data)
	if not decoded.ok or decoded.value is not Dictionary:
		return _error(decoded.error if not decoded.ok else "Snapshot data is not a dictionary.")
	if decoded.value.get("version") != int(envelope.version):
		return _error("Envelope and snapshot schema versions disagree.")
	return migrate(decoded.value)

func load_into(world: EcsWorld, path: String) -> Dictionary:
	var loaded := load_snapshot(path)
	return SNAPSHOT.restore(world, loaded.snapshot) if loaded.ok else loaded

func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message, "snapshot": {}, "id_map": {}}

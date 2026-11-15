class_name EcsVariantCodec
extends RefCounted

## Explicit JSON-compatible Variant tags. Never instantiates objects or scripts.
const MAX_DEPTH := 64
const MAX_ITEMS := 1000000

static func encode(value: Variant) -> Dictionary:
	return _encode(value, [], 0, [0])

static func decode(value: Variant) -> Dictionary:
	return _decode(value, 0, [0])

static func copy(value: Variant) -> Dictionary:
	var encoded := encode(value)
	return decode(encoded.value) if encoded.ok else encoded

static func _ok(value: Variant) -> Dictionary:
	return {"ok": true, "error": "", "value": value}

static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message, "value": null}

static func _encode(value: Variant, ancestors: Array, depth: int, budget: Array) -> Dictionary:
	budget[0] += 1
	if depth > MAX_DEPTH or budget[0] > MAX_ITEMS:
		return _error("Variant nesting or item limit exceeded.")
	var tag: String
	var payload: Variant
	match typeof(value):
		TYPE_NIL: return _ok({"t": "nil"})
		TYPE_BOOL:
			tag = "bool"
			payload = value
		TYPE_INT:
			tag = "int"
			payload = str(value)
		TYPE_FLOAT:
			if not is_finite(value):
				return _error("Non-finite float cannot be persisted.")
			tag = "float"
			var bytes := PackedByteArray()
			bytes.resize(8)
			bytes.encode_double(0, value)
			payload = bytes.hex_encode()
		TYPE_STRING:
			tag = "string"
			payload = value
		TYPE_STRING_NAME:
			tag = "name"
			payload = String(value)
		TYPE_ARRAY, TYPE_DICTIONARY:
			for ancestor: Variant in ancestors:
				if is_same(value, ancestor):
					return _error("Cyclic Variant containers cannot be persisted.")
			ancestors.append(value)
			payload = []
			if value is Array:
				tag = "array"
				for item: Variant in value:
					var result := _encode(item, ancestors, depth + 1, budget)
					if not result.ok:
						return result
					payload.append(result.value)
			else:
				tag = "dict"
				for key: Variant in value:
					var encoded_key := _encode(key, ancestors, depth + 1, budget)
					if not encoded_key.ok:
						return encoded_key
					var encoded_value := _encode(value[key], ancestors, depth + 1, budget)
					if not encoded_value.ok:
						return encoded_value
					payload.append([encoded_key.value, encoded_value.value])
				payload.sort_custom(func(a: Array, b: Array) -> bool: return JSON.stringify(a[0]) < JSON.stringify(b[0]))
			ancestors.pop_back()
		TYPE_VECTOR2, TYPE_VECTOR3, TYPE_VECTOR4, TYPE_VECTOR2I, TYPE_VECTOR3I, TYPE_QUATERNION, TYPE_COLOR, TYPE_BASIS, TYPE_TRANSFORM3D:
			tag = type_string(typeof(value))
			var entries: Array = []
			match typeof(value):
				TYPE_VECTOR2, TYPE_VECTOR2I: entries = [value.x, value.y]
				TYPE_VECTOR3, TYPE_VECTOR3I: entries = [value.x, value.y, value.z]
				TYPE_QUATERNION, TYPE_VECTOR4: entries = [value.x, value.y, value.z, value.w]
				TYPE_COLOR: entries = [value.r, value.g, value.b, value.a]
				TYPE_BASIS: entries = [value.x, value.y, value.z]
				TYPE_TRANSFORM3D: entries = [value.basis, value.origin]
			var encoded_entries := _encode(entries, ancestors, depth + 1, budget)
			if not encoded_entries.ok:
				return encoded_entries
			payload = encoded_entries.value
		TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY, TYPE_PACKED_VECTOR4_ARRAY:
			tag = type_string(typeof(value))
			var encoded_entries := _encode(Array(value), ancestors, depth + 1, budget)
			if not encoded_entries.ok:
				return encoded_entries
			payload = encoded_entries.value
		_:
			return _error("Unsupported Variant type: " + type_string(typeof(value)))
	return _ok({"t": tag, "v": payload})

static func _decode(value: Variant, depth: int, budget: Array) -> Dictionary:
	budget[0] += 1
	if depth > MAX_DEPTH or budget[0] > MAX_ITEMS:
		return _error("Variant nesting or item limit exceeded.")
	if value is not Dictionary or value.get("t") is not String:
		return _error("Malformed Variant tag.")
	var tag: String = value.t
	if tag == "nil":
		return _ok(null) if value.size() == 1 else _error("Malformed nil tag.")
	if value.size() != 2 or not value.has("v"):
		return _error("Malformed Variant payload.")
	var payload: Variant = value.v
	match tag:
		"bool": return _ok(payload) if payload is bool else _error("Malformed bool.")
		"string", "name":
			if payload is not String:
				return _error("Malformed text.")
			return _ok(StringName(payload) if tag == "name" else payload)
		"int":
			if payload is not String or not payload.is_valid_int():
				return _error("Malformed integer.")
			var integer: int = payload.to_int()
			return _ok(integer) if str(integer) == payload else _error("Integer outside int64 range or noncanonical.")
		"float":
			if payload is not String or payload.length() != 16 or not payload.is_valid_hex_number():
				return _error("Malformed float bytes.")
			var number: float = payload.hex_decode().decode_double(0)
			return _ok(number) if is_finite(number) else _error("Non-finite float.")
		"array":
			if payload is not Array:
				return _error("Malformed array.")
			var output: Array = []
			for item: Variant in payload:
				var result := _decode(item, depth + 1, budget)
				if not result.ok:
					return result
				output.append(result.value)
			return _ok(output)
		"dict":
			if payload is not Array:
				return _error("Malformed dictionary.")
			var output: Dictionary = {}
			for pair: Variant in payload:
				if pair is not Array or pair.size() != 2:
					return _error("Malformed dictionary pair.")
				var key := _decode(pair[0], depth + 1, budget)
				var item := _decode(pair[1], depth + 1, budget)
				if not key.ok or not item.ok:
					return key if not key.ok else item
				if output.has(key.value):
					return _error("Duplicate dictionary key.")
				output[key.value] = item.value
			return _ok(output)
	var entries := _decode(payload, depth + 1, budget)
	if not entries.ok or entries.value is not Array:
		return _error("Malformed math or packed payload: " + tag)
	var parts: Array = entries.value
	match tag:
		"Vector2", "Vector3", "Vector4", "Quaternion", "Color":
			var count := 2 if tag == "Vector2" else (3 if tag == "Vector3" else 4)
			if parts.size() != count or not _all_type(parts, TYPE_FLOAT):
				return _error("Malformed " + tag)
			match tag:
				"Vector2": return _finite_result(Vector2(parts[0], parts[1]))
				"Vector3": return _finite_result(Vector3(parts[0], parts[1], parts[2]))
				"Vector4": return _finite_result(Vector4(parts[0], parts[1], parts[2], parts[3]))
				"Quaternion": return _finite_result(Quaternion(parts[0], parts[1], parts[2], parts[3]))
				"Color": return _finite_result(Color(parts[0], parts[1], parts[2], parts[3]))
		"Vector2i", "Vector3i":
			if parts.size() != (2 if tag == "Vector2i" else 3) or not _all_type(parts, TYPE_INT):
				return _error("Malformed " + tag)
			for part: int in parts:
				if part < -2147483648 or part > 2147483647:
					return _error("Vector integer outside int32 range.")
			return _ok(Vector2i(parts[0], parts[1]) if tag == "Vector2i" else Vector3i(parts[0], parts[1], parts[2]))
		"Basis":
			return _ok(Basis(parts[0], parts[1], parts[2])) if parts.size() == 3 and _all_type(parts, TYPE_VECTOR3) else _error("Malformed Basis.")
		"Transform3D":
			return _ok(Transform3D(parts[0], parts[1])) if parts.size() == 2 and parts[0] is Basis and parts[1] is Vector3 else _error("Malformed Transform3D.")
		"PackedByteArray", "PackedInt32Array", "PackedInt64Array":
			if not _all_type(parts, TYPE_INT):
				return _error("Malformed packed integers.")
			for part: int in parts:
				if (tag == "PackedByteArray" and (part < 0 or part > 255)) or (tag == "PackedInt32Array" and (part < -2147483648 or part > 2147483647)):
					return _error("Packed integer outside range.")
			match tag:
				"PackedByteArray": return _ok(PackedByteArray(parts))
				"PackedInt32Array": return _ok(PackedInt32Array(parts))
				"PackedInt64Array": return _ok(PackedInt64Array(parts))
		"PackedFloat32Array", "PackedFloat64Array":
			if not _all_type(parts, TYPE_FLOAT):
				return _error("Malformed packed floats.")
			return _finite_result(PackedFloat32Array(parts) if tag == "PackedFloat32Array" else PackedFloat64Array(parts))
		"PackedStringArray": return _ok(PackedStringArray(parts)) if _all_type(parts, TYPE_STRING) else _error("Malformed packed strings.")
		"PackedVector2Array": return _ok(PackedVector2Array(parts)) if _all_type(parts, TYPE_VECTOR2) else _error("Malformed packed Vector2.")
		"PackedVector3Array": return _ok(PackedVector3Array(parts)) if _all_type(parts, TYPE_VECTOR3) else _error("Malformed packed Vector3.")
		"PackedVector4Array": return _ok(PackedVector4Array(parts)) if _all_type(parts, TYPE_VECTOR4) else _error("Malformed packed Vector4.")
		"PackedColorArray": return _ok(PackedColorArray(parts)) if _all_type(parts, TYPE_COLOR) else _error("Malformed packed colors.")
	return _error("Unknown Variant type: " + tag)

static func _finite_result(value: Variant) -> Dictionary:
	if value is PackedFloat32Array or value is PackedFloat64Array:
		for number: float in value:
			if not is_finite(number):
				return _error("Packed float conversion overflowed.")
	else:
		var checked := encode(value)
		if not checked.ok:
			return _error("Math value conversion overflowed.")
	return _ok(value)

static func _all_type(values: Array, type: int) -> bool:
	for value: Variant in values:
		if typeof(value) != type:
			return false
	return true

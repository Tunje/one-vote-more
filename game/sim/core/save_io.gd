class_name SaveIO
extends RefCounted
## Versioned save files (project §17.5). Uses Godot's var_to_str/str_to_var so ints stay ints (JSON would turn them into floats).
## File layout: line 1 = header "PCS_SAVE <version>", rest = serialized state dictionary.

const MAGIC := "PCS_SAVE"


static func save(sim: Simulation, path: String) -> Error:
	var dir := path.get_base_dir()
	if dir != "" and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_line("%s %d" % [MAGIC, WorldState.SAVE_VERSION])
	f.store_string(var_to_str(encode_ordered(sim.to_dict())))
	f.close()
	return OK


## Loads into an already-constructed Simulation (with providers registered). Returns OK or an error.
static func load_into(sim: Simulation, path: String) -> Error:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return FileAccess.get_open_error()
	var header := f.get_line().split(" ")
	if header.size() != 2 or header[0] != MAGIC:
		return ERR_FILE_UNRECOGNIZED
	var d = str_to_var(f.get_as_text().substr(f.get_position()))
	f.close()
	d = decode_ordered(d)
	if typeof(d) != TYPE_DICTIONARY:
		return ERR_PARSE_ERROR
	d = migrate(d, int(header[1]))
	sim.load_dict(d)
	return OK


## var_to_str writes Dictionary keys SORTED, which would change table iteration order after a load and
## break determinism (found by a9's staff tests). Every Dictionary is therefore saved as an ordered
## key/value list: {"__od": [k1, v1, k2, v2, ...]}, recursively.
const OD := "__od"


static func encode_ordered(v):
	match typeof(v):
		TYPE_DICTIONARY:
			var flat: Array = []
			for k in v:
				flat.append(k)
				flat.append(encode_ordered(v[k]))
			return {OD: flat}
		TYPE_ARRAY:
			var out: Array = []
			for x in v:
				out.append(encode_ordered(x))
			return out
	return v


static func decode_ordered(v):
	match typeof(v):
		TYPE_DICTIONARY:
			if v.size() == 1 and v.has(OD):
				var flat: Array = v[OD]
				var d := {}
				for i in range(0, flat.size(), 2):
					d[flat[i]] = decode_ordered(flat[i + 1])
				return d
			var plain := {}
			for k in v:
				plain[k] = decode_ordered(v[k])
			return plain
		TYPE_ARRAY:
			var out: Array = []
			for x in v:
				out.append(decode_ordered(x))
			return out
	return v


## Migration hook: upgrade old save dictionaries step by step to SAVE_VERSION.
static func migrate(d: Dictionary, from_version: int) -> Dictionary:
	var v := from_version
	while v < WorldState.SAVE_VERSION:
		# match v: 1: d = _v1_to_v2(d)
		v += 1
	d["version"] = WorldState.SAVE_VERSION
	return d

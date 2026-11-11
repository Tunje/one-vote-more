class_name IndicatorStore
extends RefCounted
## Indicator registry and values (planning/pic-core.md §3).
## Values are ints in milli-units (×1000). Keys: "COLONY", a district id, or a voter-cell key "district|OCC|BAND".
## Enforces: an indicator is written only in its declared phase, and only by its owner.

const SCALE := 1000

var defs: Dictionary = {}     # id -> def dict (pic-core §3 schema)
var values: Dictionary = {}   # id -> {key: int}
var history: Dictionary = {}  # id -> {month: {key: int}}
var _written_this_month: Dictionary = {}  # id -> true


func define(def: Dictionary) -> void:
	for k in ["id", "owner", "unit", "range", "granularity", "polarity", "concerns", "normalize", "phase", "visibility"]:
		assert(def.has(k), "indicator def missing '%s': %s" % [k, def.get("id", "?")])
	assert(not defs.has(def["id"]), "duplicate indicator " + def["id"])
	defs[def["id"]] = def
	values[def["id"]] = {}
	history[def["id"]] = {}


## Called by providers. `phase` is the currently executing phase (passed by WorldState).
func write(id: String, key: String, value: int, phase: int, writer: String) -> void:
	assert(defs.has(id), "unknown indicator " + id)
	var d: Dictionary = defs[id]
	assert(d["phase"] == phase, "%s must be written in phase %s, not %s" % [id, TickPhase.name_of(d["phase"]), TickPhase.name_of(phase)])
	assert(d["owner"] == writer, "%s owned by %s, written by %s" % [id, d["owner"], writer])
	values[id][key] = value
	_written_this_month[id] = true


func read(id: String, key: String = "COLONY", default_value: int = 0) -> int:
	return values.get(id, {}).get(key, default_value)


## Value as perceived with lag: reads history `perceptionLag` months back when available.
func read_perceived(id: String, key: String, month: int) -> int:
	var lag: int = defs[id].get("perceptionLag", 0)
	if lag == 0:
		return read(id, key)
	var h: Dictionary = history[id]
	var m := month - lag
	return h[m].get(key, read(id, key)) if h.has(m) else read(id, key)


## 0..100000 (milli) satisfaction for a raw value via the def's normalize {good, bad}, linear and clamped.
func normalized(id: String, raw: int) -> int:
	var n: Dictionary = defs[id]["normalize"]
	var good: int = n["good"]
	var bad: int = n["bad"]
	if good == bad:
		return 50 * SCALE
	var t := float(raw - bad) / float(good - bad)
	return int(round(clampf(t, 0.0, 1.0) * 100.0 * SCALE))


func record(month: int) -> void:
	for id in values:
		history[id][month] = values[id].duplicate()
	_written_this_month.clear()


func written_this_month(id: String) -> bool:
	return _written_this_month.has(id)


func to_dict() -> Dictionary:
	# Defs are code/data-defined and re-registered on load; only values and history are state.
	return {"values": values.duplicate(true), "history": history.duplicate(true)}


func load_state(d: Dictionary) -> void:
	for id in d["values"]:
		if defs.has(id):
			values[id] = d["values"][id].duplicate(true)
			history[id] = d["history"][id].duplicate(true)

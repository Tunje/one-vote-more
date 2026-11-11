class_name RngStreams
extends RefCounted
## Named, independently seeded RNG streams (project §17.4).
## Each stream's seed is derived from (master_seed, name), so stream creation order never affects results,
## and adding a new subsystem stream doesn't perturb existing ones.
## Convention: one stream per subsystem concern, e.g. "pol.polling", "econ.market", "law.verdict".

var master_seed: int = 0
var _streams: Dictionary = {}  # name -> RandomNumberGenerator


func _init(seed_value: int = 0) -> void:
	master_seed = seed_value


func stream(stream_name: String) -> RandomNumberGenerator:
	if not _streams.has(stream_name):
		var r := RandomNumberGenerator.new()
		r.seed = derive_seed(stream_name)
		_streams[stream_name] = r
	return _streams[stream_name]


func derive_seed(stream_name: String) -> int:
	# sha256-based derivation: stable across platforms and Godot versions (unlike String.hash()).
	var h := ("%d/%s" % [master_seed, stream_name]).sha256_text()
	return h.substr(0, 15).hex_to_int()  # 60 bits, always positive


func to_dict() -> Dictionary:
	var s := {}
	for n in _streams:
		s[n] = _streams[n].state
	return {"master_seed": master_seed, "states": s}


static func from_dict(d: Dictionary) -> RngStreams:
	var r := RngStreams.new(d["master_seed"])
	var states: Dictionary = d["states"]
	for n in states:
		var g := r.stream(n)  # seeds from name
		g.state = states[n]   # then restore exact position
	return r

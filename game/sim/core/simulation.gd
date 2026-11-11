class_name Simulation
extends RefCounted
## Turn manager: owns the WorldState and runs the fixed monthly phase order (pic-core §7).
## Usage:
##   var sim := Simulation.new(seed, [providers...])
##   sim.new_game()   # or sim.load_dict(d)
##   sim.step()       # one month

var world: WorldState
var providers: Array = []
var _by_phase: Dictionary = {}  # phase -> [providers in registration order]


func _init(seed_value: int = 0, provider_list: Array = []) -> void:
	world = WorldState.new(seed_value)
	for p in provider_list:
		register(p)


func register(p: PicProvider) -> void:
	providers.append(p)
	for d in p.indicator_defs():
		world.indicators.define(d)
	for d in p.lever_defs():
		world.define_lever(d)
	for ph in p.phases():
		assert(ph in TickPhase.ORDER, "bad phase %s from %s" % [ph, p.owner_id()])
		if not _by_phase.has(ph):
			_by_phase[ph] = []
		_by_phase[ph].append(p)


func new_game() -> void:
	world.current_phase = 0
	for p in providers:
		p.init_world(world)


## Advance one month: run every phase in order, then advance the calendar.
func step() -> void:
	for ph in TickPhase.ORDER:
		world.current_phase = ph
		for p in _by_phase.get(ph, []):
			p.run_phase(ph, world)
		if ph == TickPhase.RECORD:
			_record()
	world.current_phase = 0
	world.month += 1


func run(months: int) -> void:
	for _i in months:
		step()


func _record() -> void:
	world.indicators.record(world.month)
	world.facts.compact(world.month)
	world.ledger.compact(world.month)
	var total := world.ledger.total()
	if total != 0:
		# Recorded in state (not only an assert) so tests and soak runs can detect it in any build.
		var v: Array = world.meta.get("violations", [])
		v.append("month %d: money conservation broken, total=%d" % [world.month, total])
		world.meta["violations"] = v
		push_error(v[-1])


func to_dict() -> Dictionary:
	return world.to_dict()


## Load into this simulation (providers must already be registered so defs exist).
func load_dict(d: Dictionary) -> void:
	world.load_dict(d)

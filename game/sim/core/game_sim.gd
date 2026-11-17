class_name GameSim
extends RefCounted
## Builds the game (rebuild step 1). Until the new economy exists the world is the stand-in one politics was first
## built on (StubWorldProvider: a census and nine indicators); law, staff, the planet's month and politics are real.
## The old economy's EconSim did this job; the rebuild adds its parts to _register as they are built.

static func make(seed_value: int, scenario: String = "BALANCED", persona: Dictionary = {}, autoplay: bool = true) -> Simulation:
	var sim := Simulation.new(seed_value)
	sim.world.meta["scenario"] = scenario
	sim.world.meta["persona"] = persona
	sim.world.meta["autoplay_player"] = autoplay
	if not sim.world.meta.has("on"):
		sim.world.meta["on"] = []
	_register(sim)
	sim.new_game()
	return sim


## Registration order: law before staff and politics within DECISIONS.
static func _register(sim: Simulation) -> void:
	sim.register(preload("res://sim/law/law_provider.gd").new())
	sim.register(preload("res://sim/staff/staff_provider.gd").new())
	sim.register(StubWorldProvider.new())
	sim.register(PlanetProvider.new())
	sim.register(preload("res://sim/population/population_provider.gd").new())   # the Landing area (after the planet, before politics)
	sim.register(preload("res://sim/economy/landing.gd").new())   # step 2: month one's government side and the purse's payments (after the settlers)
	sim.register(preload("res://sim/economy/month.gd").new())   # step 3: the economy's month, the one conductor
	sim.register(preload("res://sim/economy/econ_publish.gd").new())   # what politics reads (Ella): last in SOCIAL, after the households' month (joins)
	sim.register(PoliticsProvider.new())


static func for_load() -> Simulation:
	var sim := Simulation.new(0)
	_register(sim)
	return sim

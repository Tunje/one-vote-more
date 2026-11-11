class_name EconSim
extends RefCounted
## Factories for configurations that include the real economy (M4).
##   make_econ_only(): economy + caretaker autopilot (econ soak gate).
##   make():           law + staff + economy + politics: the integrated game (replaces StubWorldProvider).

const LawProvider := preload("res://sim/law/law_provider.gd")
const StaffProvider := preload("res://sim/staff/staff_provider.gd")


static func make_econ_only(seed_value: int) -> Simulation:
	var sim := Simulation.new(seed_value)
	sim.world.meta["econ_caretaker_fiscal"] = true
	_register_econ_only(sim)
	sim.new_game()
	return sim


static func _register_econ_only(sim: Simulation) -> void:
	sim.register(StubLawProvider.new())   # applies the caretaker's enactments (A8: law writes levers)
	sim.register(EconAutopilot.new())
	sim.register(EconProvider.new())


static func econ_only_for_load() -> Simulation:
	var sim := Simulation.new(0)
	_register_econ_only(sim)
	return sim


static func make(seed_value: int, scenario: String = "BALANCED", persona: Dictionary = {}, autoplay: bool = true) -> Simulation:
	var sim := Simulation.new(seed_value)
	sim.world.meta["scenario"] = scenario
	sim.world.meta["persona"] = persona
	sim.world.meta["autoplay_player"] = autoplay
	_register(sim)
	sim.new_game()
	return sim


## Registration order: law before staff and politics within DECISIONS (A8); autopilot until the AI government commissions projects.
static func _register(sim: Simulation) -> void:
	sim.register(LawProvider.new())
	sim.register(StaffProvider.new())
	# No EconAutopilot in the integrated game: the AI government (GovBuilder) and the companies decide what is
	# built; when the human player governs, nothing is ordered behind their back (user decision 2026-11-11).
	sim.register(EconProvider.new())
	sim.register(PoliticsProvider.new())


static func for_load() -> Simulation:
	var sim := Simulation.new(0)
	_register(sim)
	return sim

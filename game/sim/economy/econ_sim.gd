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


## v9 (Wilma, 2026-11-14; Bob's per-flag check, 5 seeds x 30 years, each arm on the v8 base): added M2 (bank credit; best
## arm), WAREHOUSE, POLICE, PRISONS, FLEET (the v8 death spiral is fixed; the seed-3 dip did not reproduce) and CARE (the
## seed-4 collapse is an energy-to-food trap, not care; S7 owns it) and E140 (annual budgeting: firms judged on 12 months,
## a credit line; profitable firms entering distress 57 -> 1-4 in 5 seeds; without E140P, the yearly payout, which cost
## adults). Off: S7F/S7C (no gain on the v9 base), E141 (office hiring priority; costs jobs and food), SUPPORT_S (no gain, higher tax), E136-E138
## (lowest real income; wait for the private-firm work), SUPPORT_D/E (failed earlier A/Bs). Econ-only test worlds
## (make_econ_only) stay opt-in. meta["off"] still switches any of these off.
const DEFAULT_ON := ["E134", "PAYOUT", "SUPPORT_T", "WORKLOAD", "SUPPORT_A", "CONDUCT", "CRIME", "SCANDAL_REVIVAL",
	"M2", "WAREHOUSE", "POLICE", "PRISONS", "FLEET", "CARE", "E140"]


static func make(seed_value: int, scenario: String = "BALANCED", persona: Dictionary = {}, autoplay: bool = true) -> Simulation:
	var sim := Simulation.new(seed_value)
	sim.world.meta["scenario"] = scenario
	sim.world.meta["persona"] = persona
	sim.world.meta["autoplay_player"] = autoplay
	sim.world.meta["voters"] = "LEAVES"  # M10 S3c: the population blocks are the voters (old saves keep CELLS)
	if not sim.world.meta.has("on"):
		sim.world.meta["on"] = DEFAULT_ON.duplicate()
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
	sim.register(PlanetProvider.new())   # Terra: climate, storms, phenomena, pollution drift (TickPhase.NATURE)
	sim.register(PoliticsProvider.new())


static func for_load() -> Simulation:
	var sim := Simulation.new(0)
	_register(sim)
	return sim

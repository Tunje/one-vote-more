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
## v10 (Wilma, 2026-11-14/15; Bob's candidate run, 10 seeds x 30 years: adults 4695 -> 4761, unemployment 18.0 -> 16.0%,
## food shortfall 24 -> 10 permille, real income 2.79 -> 3.45, food price 277 -> 195% of base, bank capital x2.8): added
## E146/E147 (bread as everyday food, start-up capital), E148 (supplier credit), E149 (cost-plus prices, FOOD exempt),
## E150 (self-funding public companies), PAYOUT12 (firms keep 12 months of costs before paying owners), E157 (planners
## read deliverable capacity, not nameplate) and E161 (farms work by hand without power at 60%). Tested as exactly this
## list. Off: E156 (bread price cuts; not in the candidate run), E143, E151-E155 (money arms: starve the colony until
## supply responds), E158/E159 (job switching; no gain on top of E157), E160/E162 (family farms and bakeries; waiting for
## the need-tested grants).
## v11 (Wilma, 2026-11-16; the user's decisions: family farms in, Ella's politics in, the three crops out). Chosen on
## the code with the credit fix (credit follows expected sales, never a ceiling of past sales, public enterprises
## included; in every game), 10 seeds x 30 years: base 4487 adults / unemployment 20.9 % / food shortfall 19.7 permille
## / real wage 2.52; food 4840 / 16.9 / 8.3 / 3.21; food + politics (this list) 4875 / 18.3 / 13.9 / 3.01; food + plan
## stage 4620 / 19.4 / 47.3 (seed 1 collapses: 2146 adults, 347 permille); all three 4832 / 18.6 / 22.7 / 2.91.
## Added: E160 / E162 (family farms and bakeries), R8 with R8_FREIGHT, R8_MATERIAL and R8_FOOD (the eight rules: depots
## follow full trucks; buyers bid what an input or food is worth to them, no price rules; farms follow their sales),
## TREND2, RULE_COST3 and RIVALRY (approval moves only outside its 12-month range, a lower cost of ruling, campaigns aim
## by rivalry). Also in every game since the same day: a stuck public project is re-tendered once a year.
## Off: E165 / E165B (the plan stage: ahead before the credit fix, behind after it), R8_BUILDERS (a price loop with
## materials and food), R8_HOUSING (the bank's room), E166 / E169, FREIGHT_ROADS, ROAD_WORKS, PRIVATE_ROADS,
## ROAD_SAFETY, SITING, TOWN_GRID, ECO, SEASONS, DELEGATION, AGRI_MIN (not run in full games or not ahead).
const DEFAULT_ON := ["E134", "PAYOUT", "SUPPORT_T", "WORKLOAD", "SUPPORT_A", "CONDUCT", "CRIME", "SCANDAL_REVIVAL",
	"M2", "WAREHOUSE", "POLICE", "PRISONS", "FLEET", "CARE", "E140",
	"E146", "E147", "E148", "E149", "E150", "PAYOUT12", "E157", "E161",
	"E160", "E162", "R8", "R8_FREIGHT", "R8_MATERIAL", "R8_FOOD", "TREND2", "RULE_COST3", "RIVALRY"]


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

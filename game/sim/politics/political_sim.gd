class_name PoliticalSim
extends RefCounted
## Factory for the M2 configuration: stub world + stub law + politics.
## Real subsystems replace the stubs as they land (M3 law/staff, M4 economy).

static func make(seed_value: int, scenario: String = "BALANCED", persona: Dictionary = {}, autoplay: bool = true) -> Simulation:
	var sim := Simulation.new(seed_value)
	sim.world.meta["scenario"] = scenario
	sim.world.meta["persona"] = persona
	sim.world.meta["autoplay_player"] = autoplay
	_register(sim)
	sim.new_game()
	return sim


## Providers in registration order (law before politics within DECISIONS).
## M3: real law (lever pipeline, charter) + staff (drafting, implementation) replace StubLawProvider.
static func _register(sim: Simulation) -> void:
	sim.register(preload("res://sim/law/law_provider.gd").new())
	sim.register(preload("res://sim/staff/staff_provider.gd").new())
	sim.register(StubWorldProvider.new())
	sim.register(PoliticsProvider.new())


## Same providers but empty world, for loading a save.
static func for_load() -> Simulation:
	var sim := Simulation.new(0)
	_register(sim)
	return sim


static func summary(sim: Simulation) -> String:
	var w := sim.world
	var lines: Array = []
	var st: Dictionary = w.table("pol")["state"]
	for eid in st["elections"]:
		var e: Dictionary = w.table("election")[eid]
		var parts: Array = []
		for pid in e["seats"]:
			if e["seats"][pid] > 0:
				var p: Dictionary = w.table("party")[pid]
				parts.append("%s%s %d (%.1f%%)" % [p["name"], "*" if p["is_player"] else "", e["seats"][pid], 100.0 * e["votes"][pid] / maxf(1.0, e["total"])])
		lines.append("  Election m%d (Y%d): %s" % [e["month"], e["month"] / 12 + 1, ", ".join(parts)])
	var g: Dictionary = st["government"]
	if not g.is_empty():
		var names: Array = g["members"].map(func(pid): return w.table("party")[pid]["name"])
		lines.append("  Government: %s, PM %s, %d seats (support: %d parties)" % [" + ".join(names), w.table("party")[g["pm_party"]]["name"], g["yes"], g["support"].size()])
	var passed := 0
	var failed := 0
	for b in w.table("bill").values():
		if b["status"] == "PASSED": passed += 1
		else: failed += 1
	lines.append("  Bills: %d passed, %d defeated. Approval %.1f%%" % [passed, failed, w.indicators.read("POL_GOV_APPROVAL") / 1000.0])
	return "\n".join(lines)

extends TestCase
## Laws of a switched-off feature must not reach party commitments or coalition deals (Anni's probe, 2026-11-15).

const EconSim := preload("res://sim/economy/econ_sim.gd")


func test_switched_off_laws_are_nobodys_commitment() -> void:
	var sim: Simulation = EconSim.make(1, "BALANCED", {}, true)
	sim.run(30)
	var w := sim.world
	var gated := {}
	for lid in w.lever_defs:
		if not Legislature.lever_available(w, w.lever_defs[lid]):
			gated[lid] = true
	check(gated.has("ECON_FAMILY_FARM_GRANT"), "the family farm grant is switched off in a default game")
	var held := 0
	for pid in w.table("party"):
		for c in w.table("party")[pid].get("commitments", []):
			if gated.has(c["lever"]):
				held += 1
	check_eq(held, 0, "no party holds a commitment on a switched-off law")
	for lid in gated:
		check(not Coalition.feasible(w, String(lid), 1) and not Coalition.feasible(w, String(lid), -1), "%s can't be part of a deal" % lid)
	var pos: Dictionary = w.table("party")[w.table("party").keys()[0]]["positions"]
	var all := PartyGen.commitments(pos, w.lever_defs).size()
	check(PartyGen.commitments(pos, w.lever_defs, w).size() <= all, "with the world, never more")
	(w.meta["on"] as Array).append("E160")
	check(Legislature.lever_available(w, w.lever_defs["ECON_FAMILY_FARM_GRANT"]), "switched on, it is available again")

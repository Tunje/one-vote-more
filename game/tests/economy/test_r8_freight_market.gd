extends TestCase
## Freight rules 1-4 on the carrier's own market (R8FR_MARKET, with R8_FREIGHT; EconRules).

var SAVE_PATH: String = TestCase.save_path("r8_freight_market.sav")
const S := EconUtil.S
const LV := "ECON_FREIGHT_TARIFF"


func _sim(extra: Array, months: int) -> Simulation:
	var sim := EconSim.make_econ_only(1)
	var on: Array = EconSim.DEFAULT_ON.duplicate()
	on.append_array(extra)
	sim.world.meta["on"] = on
	sim.run(months)
	return sim


func test_off_depots_run_full_and_e150_keeps_the_tariff() -> void:
	var sim := _sim([], 3)
	check_eq(EconRules.depot_target(sim.world), -1.0, "rules 3/4 off")
	check(not EconRules.freight_market_on(sim.world), "off by default")
	for fid in sim.world.table("facility"):
		var f: Dictionary = sim.world.table("facility")[fid]
		if f["type"] == "DEPOT" and not f["mothball"]:
			check_eq(int(f["T"]), 1000, "a depot at full output as before")


func _tariff_after(w: WorldState, cap: int, used: int, deferred: int, start: int) -> int:
	var s := EconUtil.st(w)
	w.levers[LV] = start
	s["r8_fr_q"] = [[cap, used, deferred], [cap, used, deferred], [cap, used, deferred]]
	EconRules._freight_tariff(w, s, EconFinance.org_by_key(w, "CTA"))
	return int(EconUtil.lever(w, LV, 0))


func test_rules_1_2_deferred_freight_raises_idle_trucks_lower() -> void:
	var sim := _sim(["R8FR_MARKET"], 3)
	var w := sim.world
	if EconFinance.org_by_key(w, "CTA") == "":
		check(false, "the transport authority exists")
		return
	check(_tariff_after(w, 1000 * S, 1000 * S, 100 * S, 5) > 5, "rule 1: freight left behind raises the tariff")
	check(_tariff_after(w, 1000 * S, 500 * S, 0, 5) < 5, "rule 2: idle trucks and nothing deferred lower it")
	check_eq(_tariff_after(w, 1000 * S, 1000 * S, 0, 5), 5, "full and nothing deferred: unchanged")
	check_eq(_tariff_after(w, 1000 * S, 1000 * S, 100 * S, 20), 20, "within the lever's range (top)")
	check_eq(_tariff_after(w, 1000 * S, 0, 0, 1), 1, "within the lever's range (bottom)")
	w.meta["on"].append("R8FR_NOPX")
	check_eq(_tariff_after(w, 1000 * S, 1000 * S, 100 * S, 5), 5, "R8FR_NOPX takes rules 1/2 out")


func test_rules_3_4_depots_run_at_the_freight_demanded() -> void:
	var sim := _sim(["R8FR_MARKET"], 3)
	var w := sim.world
	var full := float(EconRules._depot_full(w))
	if full <= 0.0:
		check(false, "open depots")
		return
	var s := EconUtil.st(w)
	s["r8_fr_demand"] = int(full * 0.5)
	check(absf(EconRules.depot_target(w) - 0.5) < 0.01, "half the fleet's capacity demanded: half output")
	s["r8_fr_demand"] = 0
	check_eq(EconRules.depot_target(w), 0.2, "no freight: the core crew only (rule 4)")
	s["r8_fr_demand"] = int(full * 3.0)
	check_eq(EconRules.depot_target(w), 1.0, "more than it can carry: full output")
	w.meta["on"].append("R8FR_NOOUT")
	check_eq(EconRules.depot_target(w), -1.0, "R8FR_NOOUT takes rules 3/4 out")


func test_runs_closed_and_save_load_identically() -> void:
	var ref := _sim(["R8FR_MARKET"], 14)
	check_eq(SaveIO.save(ref, SAVE_PATH), OK, "save")
	ref.run(10)
	var loaded := EconSim.econ_only_for_load()
	check_eq(SaveIO.load_into(loaded, SAVE_PATH), OK, "load")
	loaded.run(10)
	check_eq(loaded.world.state_hash(), ref.world.state_hash(), "continued state hash")
	check_eq(ref.world.ledger.total(), 0, "ledger closed")
	check(EconPop.check(ref.world).is_empty(), "jobs equal people")
	check(EconUtil.st(ref.world).has("r8_fr_demand"), "the freight demanded is measured")

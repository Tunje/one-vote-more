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


func _quarter(w: WorldState, cap: int, used: int, deferred: int) -> int:
	var s := EconUtil.st(w)
	s["r8_fr_q"] = [[cap, used, deferred], [cap, used, deferred], [cap, used, deferred]]
	EconRules._freight_tariff(w, s, EconFinance.org_by_key(w, "CTA"))
	return int(EconUtil.lever(w, LV, 0))


func _start(w: WorldState, lever: int) -> void:
	w.levers[LV] = lever
	EconUtil.st(w).erase("r8_fr_tariff_x")


func test_rules_1_2_the_tariff_moves_in_proportion() -> void:
	var sim := _sim(["R8FR_MARKET"], 3)
	var w := sim.world
	var s := EconUtil.st(w)
	if EconFinance.org_by_key(w, "CTA") == "":
		check(false, "the transport authority exists")
		return
	_start(w, 5)
	check_eq(_quarter(w, 1000 * S, 1000 * S, 10 * S), 5, "a handful of units left behind (1%): the lever stays")
	check(int(s["r8_fr_tariff_x"]) > 5 * S, "but the tariff's fraction moved up a little")
	_start(w, 5)
	var lv := 5
	for i in 4:
		lv = _quarter(w, 1000 * S, 1000 * S, 1000 * S)
	check_eq(lv, 6, "as much left behind as carried: +5% a quarter, 5 → 6.08 in a year")
	_start(w, 5)
	for i in 12:
		lv = _quarter(w, 1000 * S, 500 * S, 0)
	check(lv < 5, "half the trucks idle: down 3% a quarter (%d after 3 years)" % lv)
	_start(w, 5)
	check_eq(_quarter(w, 1000 * S, 1000 * S, 0), 5, "full and nothing left behind: unchanged")
	_start(w, 20)
	check_eq(_quarter(w, 1000 * S, 1000 * S, 1000 * S), 20, "within the lever's range (top)")
	_start(w, 1)
	check_eq(_quarter(w, 1000 * S, 0, 0), 1, "within the lever's range (bottom)")
	_start(w, 5)
	_quarter(w, 1000 * S, 1000 * S, 1000 * S)
	w.levers[LV] = 9  # the government sets it
	_quarter(w, 1000 * S, 1000 * S, 0)
	check_eq(int(s["r8_fr_tariff_x"]), 9 * S, "a lever set by the government restarts the fraction")
	w.meta["on"].append("R8FR_NOPX")
	_start(w, 5)
	check_eq(_quarter(w, 1000 * S, 1000 * S, 1000 * S), 5, "R8FR_NOPX takes rules 1/2 out")


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

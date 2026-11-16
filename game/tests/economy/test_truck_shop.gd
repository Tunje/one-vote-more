extends TestCase
## TRUCKSHOP (Ella, opt-in): truck workshops: repairs that sell speed, trucks built to order, rule nine on the fee and
## the price, founding on the average of all the work in reach, the grant's need.

const EconTruckShop := preload("res://sim/economy/econ_truck_shop.gd")

const S := EconUtil.S


func _sim(on: bool, seed_v: int = 3) -> Simulation:
	var sim := EconSim.make_econ_only(seed_v)
	if on:
		var fl: Array = (sim.world.meta.get("on", []) as Array).duplicate()
		fl.append("TRUCKSHOP")
		sim.world.meta["on"] = fl
	return sim


func _org(w: WorldState, d: String, cash: int) -> String:
	var gid := ""
	for g in EconUtil.sorted_keys(w.table("hh")):
		if String(w.table("hh")[g]["district"]) == d:
			gid = g
			break
	var oid := EconFamily._make_org(w, "TRUCKSHOP", d, gid, d)
	w.table("org")[oid]["status"] = "ACTIVE"
	if cash > 0:
		w.ledger.transfer(Ledger.EXTERNAL, EconUtil.acct(oid), cash, "TEST", w.month)
	return oid


func _shop(w: WorldState, d: String, cap_units: int) -> Dictionary:
	var oid := _org(w, d, 0)
	var fid := EconSetup.add_facility(w, "TRUCKSHOP", oid, d, false)
	var f: Dictionary = w.table("facility")[fid]
	f["tw_cap"] = cap_units * S
	EconUtil.inv_add(w, oid, "COMPONENT", d, 10 * EconTruckShop.REPAIR_PARTS * S, 0)  # parts for repairs
	return f


func _truck(w: WorldState, owner: String, d: String, repair_m: int, earn_m: int) -> Dictionary:
	var tid := w.new_id("truck")
	w.table("truck")[tid] = {"id": tid, "owner": owner, "district": d, "age_m": 12, "cond": 700, "quality": 500, "maker": "WORKS",
		"maker_org": "", "repair_m": repair_m, "carry": 400 * S, "earn_m": earn_m}
	return w.table("truck")[tid]


func test_off_touches_nothing() -> void:
	var sim := _sim(false)
	sim.run(6)
	check(not sim.world.entities.has("truck"), "no truck table")
	check(not EconUtil.st(sim.world).has("tw_work_hist"), "no workshop state")
	for fid in sim.world.table("facility"):
		check(sim.world.table("facility")[fid]["type"] != "TRUCKSHOP", "no workshop founded")


func test_a_repair_sells_speed() -> void:
	var sim := _sim(true)
	sim.run(2)
	var w := sim.world
	var f := _shop(w, "d:1", 6)
	var owner := _org(w, "d:1", 100000 * S)
	var fee := EconTruckShop.fee_of(w, f)
	var t := _truck(w, owner, "d:1", 4, fee)  # four months off the road cost 4 × fee: the shop pays
	var bal := w.ledger.balance(EconUtil.acct(f["org"]))
	EconTruckShop.monthly(w)
	check_eq(int(t["repair_m"]), 0, "fixed now")
	check_eq(w.ledger.balance(EconUtil.acct(f["org"])) - bal, fee, "the fee paid to the workshop")
	check_eq(int(f["tw_used"]), EconTruckShop.REPAIR_WORK * S, "one repair's bay work")
	check_eq(int(t["quality"]), 500, "a repair never changes quality")
	check_eq(int(t["cond"]), 950, "it resets the wear, 5% under new")
	t["repair_m"] = 4
	t["cond"] = 300
	f["tw_cap"] = 6 * S
	EconTruckShop.monthly(w)
	check_eq(int(t["cond"]), 902, "the next repair 5% under the last")


func test_no_parts_no_repair_and_no_signal() -> void:
	var sim := _sim(true)
	sim.run(2)
	var w := sim.world
	var f := _shop(w, "d:1", 6)
	var stock := EconUtil.inv_get(w, f["org"], "COMPONENT", f["district"])
	EconUtil.inv_take(w, f["org"], "COMPONENT", f["district"], stock)
	var owner := _org(w, "d:1", 100000 * S)
	var t := _truck(w, owner, "d:1", 4, 1000000 * S)
	EconTruckShop.monthly(w)
	check_eq(int(t["repair_m"]), 4, "no parts: he fixes it himself")
	check_eq(int(t["cond"]), 700, "a self-repair leaves the wear")
	check_eq(int(f["tw_turned"]), 0, "no price signal")
	var posted := false
	for od in EconUtil.st(w)["orders"]:
		if od["buyer"] == f["org"] and od["good"] == "COMPONENT":
			posted = true
	check(posted, "it orders parts")


func test_a_driver_fixes_it_himself_when_the_fee_is_dear() -> void:
	var sim := _sim(true)
	sim.run(2)
	var w := sim.world
	var f := _shop(w, "d:1", 6)
	var owner := _org(w, "d:1", 100000 * S)
	var t := _truck(w, owner, "d:1", 4, EconTruckShop.fee_of(w, f) / 8)  # four months cost him half the fee
	EconTruckShop.monthly(w)
	check_eq(int(t["repair_m"]), 4, "he fixes it himself")
	check_eq(int(f["tw_turned"]), 0, "price-stopped: not turned away")


func test_no_money_and_no_workshop_are_no_signal() -> void:
	var sim := _sim(true)
	sim.run(2)
	var w := sim.world
	var f := _shop(w, "d:1", 6)
	var poor := _org(w, "d:1", 0)
	var t := _truck(w, poor, "d:1", 4, 1000000 * S)
	var far := _truck(w, poor, "d:7", 4, 1000000 * S)
	var p0 := EconTruckShop.fee_of(w, f)
	EconTruckShop.monthly(w)
	check_eq(int(t["repair_m"]), 4, "no money: no repair")
	check_eq(int(f["tw_turned"]), 0, "no money: no raise signal")
	check(int(f["tw_fee"]) <= p0, "the fee does not rise (%d -> %d)" % [p0, int(f["tw_fee"])])
	if not ("d:1" in EconUtil.neighbours("d:7")):
		check_eq(int(far["repair_m"]), 4, "no workshop in reach: it waits for its own repair")
		check(EconTruckShop.need_at(w, "d:7") > 0, "the grant's need: a broken truck no workshop could take")


func test_turned_away_raises_the_fee_below_cost() -> void:
	var sim := _sim(true)
	sim.run(2)
	var w := sim.world
	var f := _shop(w, "d:1", 0)  # no bay free
	f["tw_fee"] = int(EconTruckShop.fee_cost(w) * 0.5)
	var owner := _org(w, "d:1", 100000 * S)
	var t := _truck(w, owner, "d:1", 4, 1000000 * S)
	var p0 := int(f["tw_fee"])
	EconTruckShop.monthly(w)
	check(int(f["tw_turned"]) > 0, "turned away")
	check(int(f["tw_fee"]) > p0, "the fee rises (%d -> %d)" % [p0, int(f["tw_fee"])])
	check_eq(int(t["repair_m"]), 4, "the truck waits for its own repair")


func test_rule_nine_step() -> void:
	var cap := 6000.0
	var p := 1000.0
	check(EconTruckShop.step(p, 2000.0, 1000, 1000, cap) > p, "below cost, both signals: the raise has priority")
	check(EconTruckShop.step(p, 500.0, 1000, 1000, cap) < p, "above cost, both signals: the cut has priority")
	check(EconTruckShop.step(p, 500.0, 1000, 0, cap) > p, "above cost, only the raise signal: it rises")
	check(EconTruckShop.step(p, 2000.0, 0, 1000, cap) < p, "below cost, only the cut signal: it falls")
	check_eq(int(EconTruckShop.step(p, 500.0, 0, 0, cap)), int(p), "no signal: it holds")
	check_eq(int(round(EconTruckShop.step(p, 2000.0, 60000, 0, cap))), 1050, "at most 5% up")
	check_eq(int(round(EconTruckShop.step(p, 500.0, 0, 60000, cap))), 950, "the same limit down")


func test_a_truck_built_to_order() -> void:
	var sim := _sim(true)
	sim.run(2)
	var w := sim.world
	var f := _shop(w, "d:1", 6)
	EconUtil.inv_take(w, f["org"], "COMPONENT", f["district"], EconUtil.inv_get(w, f["org"], "COMPONENT", f["district"]))
	var owner := _org(w, "d:1", 10000000 * S)
	var price := EconTruckShop.price_of(w, f)
	check(EconTruckShop.quotes(w, "d:1").size() >= 1, "a quote in reach")
	check(EconTruckShop.order(w, String(f["id"]), owner, "d:1"), "ordered and paid")
	var n0 := w.table("truck").size()
	EconTruckShop.monthly(w)
	check_eq(w.table("truck").size(), n0, "no parts yet: not built")
	var posted := false
	for od in EconUtil.st(w)["orders"]:
		if od["buyer"] == f["org"] and od["good"] == "COMPONENT":
			posted = true
	check(posted, "the parts ordered on the market")
	EconUtil.inv_add(w, f["org"], "COMPONENT", f["district"], EconTruckShop.TRUCK_PARTS * S, 0)
	f["tw_cap"] = EconTruckShop.BUILD_WORK * S
	EconTruckShop.monthly(w)
	check_eq(w.table("truck").size(), n0 + 1, "built")
	var built: Dictionary = {}
	for tid in w.table("truck"):
		if String(w.table("truck")[tid]["maker"]) == "WORKSHOP":
			built = w.table("truck")[tid]
	check(int(built["quality"]) >= EconTruckShop.Q_MIN and int(built["quality"]) <= 1000, "quality set once (%d)" % int(built["quality"]))
	check_eq(String(built["owner"]), owner, "to the driver who ordered it")
	check(price > 0, "it had a price")
	check(not w.facts.query("ECON_TRUCK_BUILT", w.month, w.month).is_empty(), "the fact")


func test_quality_follows_the_workers_stress_never_below_the_works() -> void:
	var sim := _sim(true)
	sim.run(2)
	var w := sim.world
	var f := _shop(w, "d:1", 6)
	f["stress_pm"] = 0
	check_eq(EconTruckShop.quality(w, f), 1000, "calm workers: the best truck")
	f["stress_pm"] = 400
	var tense := EconTruckShop.quality(w, f)
	check(tense < 1000 and tense > EconTruckShop.Q_MIN, "stressed workers build worse trucks (%d)" % tense)
	f["stress_pm"] = 1000
	check_eq(EconTruckShop.quality(w, f), EconTruckShop.Q_MIN, "never below the works' trucks")
	f["condition"] = 10 * S
	f["stress_pm"] = 0
	check_eq(EconTruckShop.quality(w, f), 1000, "the plant's condition does not set it")


func test_founding_reads_the_average_of_all_the_work() -> void:
	var sim := _sim(true)
	sim.run(2)
	var w := sim.world
	var s := EconUtil.st(w)
	s["tw_work_hist"] = []
	check(EconTruckShop.forecast(w, "d:1", 1000)["reasons"].has("no_work"), "rule 8: no breakdowns or orders in reach")
	var h: Array = []
	for i in 12:
		h.append({"d:1": 60 * S})
	s["tw_work_hist"] = h
	var fc := EconTruckShop.forecast(w, "d:1", 1000)
	var cap := 6.0 * S
	var share := 60.0 * S * cap / (EconTruckShop.cap_in_reach(w, "d:1") + cap)
	check(absi(int(fc["volume"]) - int(minf(share, cap))) <= 1, "volume = its share of all the work in reach")
	_shop(w, "d:1", 6)
	check(int(EconTruckShop.forecast(w, "d:1", 1000)["volume"]) <= int(fc["volume"]), "another workshop in reach: a share no bigger")


func test_grant_need_published() -> void:
	var sim := _sim(true)
	sim.run(2)
	var w := sim.world
	var owner := _org(w, "d:1", 0)
	_truck(w, owner, "d:1", 4, 100 * S)
	EconTruckShop.monthly(w)
	check(EconTruckShop.need_any(w), "a broken truck with no workshop")
	check_eq(int(EconUtil.st(w)["lever_need"].get("ECON_TRUCK_WORKSHOP_GRANT", 0)), 1000, "the legislature sees the need")


func test_runs_closes_and_saves_identically() -> void:
	var path := "user://test_truck_shop.save"
	var ref := _sim(true, 7)
	ref.run(3)
	var owner := _org(ref.world, "d:1", 5000000 * S)
	for i in 6:
		_truck(ref.world, owner, "d:1" if i % 2 == 0 else "d:2", 4, 2000 * S)
	ref.run(24)
	check_eq(ref.world.ledger.total(), 0, "ledger closed")
	check(EconPop.check(ref.world).is_empty(), "jobs equal people")
	check_eq(SaveIO.save(ref, path), OK, "save")
	ref.run(12)
	var loaded := EconSim.econ_only_for_load()
	check_eq(SaveIO.load_into(loaded, path), OK, "load")
	loaded.run(12)
	check_eq(loaded.world.state_hash(), ref.world.state_hash(), "continued state hash with TRUCKSHOP on")

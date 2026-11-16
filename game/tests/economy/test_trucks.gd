extends TestCase
## TRUCKERS (Bob, opt-in): family truck drivers and their trucks: wear, breakdowns by quality, the owner's own repair,
## the room on the road, special orders at the components works, home-world trucks by ship, founding on a truck's share
## of all the freight, the grant's need.

const EconTrucks := preload("res://sim/economy/econ_trucks.gd")
const EconTruckShop := preload("res://sim/economy/econ_truck_shop.gd")

const S := EconUtil.S
const FR := ["R8FR_MARKET", "R8FR_PRIVATE", "TRUCKERS"]


func _sim(extra: Array, months: int, sd: int = 3) -> Simulation:
	var sim := EconSim.make_econ_only(sd)
	var on: Array = EconSim.DEFAULT_ON.duplicate()
	on.append_array(extra)
	sim.world.meta["on"] = on
	sim.run(months)
	return sim


## A driver's business in d with `cash`: [org id, facility id].
func _driver(w: WorldState, d: String, cash: int) -> Array:
	var gid := ""
	for g in EconUtil.sorted_keys(w.table("hh")):
		if String(w.table("hh")[g]["district"]) == d:
			gid = g
			break
	var oid := EconFamily._make_org(w, "TRUCKER", d, gid, d)
	w.table("org")[oid]["status"] = "ACTIVE"
	if cash > 0:
		w.ledger.transfer(Ledger.EXTERNAL, EconUtil.acct(oid), cash, "TEST", w.month)
	var fid := EconSetup.add_facility(w, "TRUCKER", oid, d, false)
	return [oid, fid]


func _truck(w: WorldState, oid: String, fid: String, quality: int, cond: int, repair_m: int) -> Dictionary:
	var tid := w.new_id("truck")
	w.table("truck")[tid] = {"id": tid, "owner": oid, "fac": fid, "district": "d:1", "age_m": 0, "cond": cond, "cond_max": 1000,
		"quality": quality, "maker": "WORKS", "maker_org": "", "repair_m": repair_m, "carry": EconTrucks.CARRY * S, "earn_m": 0}
	return w.table("truck")[tid]


func test_off_touches_nothing() -> void:
	var sim := _sim(["R8FR_MARKET", "R8FR_PRIVATE"], 6)
	check(not sim.world.entities.has("truck"), "no truck table")
	check(not EconUtil.st(sim.world).has("trk_work_hist"), "no drivers' state")
	for fid in sim.world.table("facility"):
		check(sim.world.table("facility")[fid]["type"] != "TRUCKER", "no driver founded")


func test_needs_the_private_carriers() -> void:
	var sim := _sim(["TRUCKERS"], 1)
	check(not EconTrucks.on(sim.world), "without R8FR_PRIVATE a driver could not be paid for what it carries: off")
	sim.world.meta["on"].append_array(["R8FR_MARKET", "R8FR_PRIVATE"])
	check(EconTrucks.on(sim.world), "on with the private carriers")


func test_quality_governs_breakdowns() -> void:
	for c in [1000, 500, 0]:
		check(absf(EconTrucks.break_pm(500, c) - 2.0 * EconTrucks.break_pm(1000, c)) < 0.001, "a 500 truck breaks down twice as often (cond %d)" % c)
	check(EconTrucks.break_pm(1000, 200) > EconTrucks.break_pm(1000, 900), "a worn truck breaks down more often")
	check(EconTrucks.uptime(1000) > EconTrucks.uptime(EconTruckShop.Q_MIN), "a better truck is on the road more of its life")


func test_the_owners_own_repair_takes_four_months_and_leaves_the_wear() -> void:
	var sim := _sim(FR, 2)
	var w := sim.world
	var dr := _driver(w, "d:1", 0)
	var t := _truck(w, dr[0], dr[1], 1000, 800, EconTruckShop.SELF_M)
	var off := 1  # the month it broke down
	for i in 6:
		EconTrucks._wear(w)
		if int(t["repair_m"]) > 0:
			off += 1
		else:
			break
	check_eq(off, EconTruckShop.SELF_M, "off the road four months in all")
	check(int(t["cond"]) < 800, "the wear stays (and grows), no reset by the owner's repair")


func test_the_room_is_the_trucks_on_the_road() -> void:
	var sim := _sim(FR, 2)
	var w := sim.world
	var dr := _driver(w, "d:1", 0)
	_truck(w, dr[0], dr[1], 1000, 1000, 0)
	_truck(w, dr[0], dr[1], 1000, 1000, 0)
	_truck(w, dr[0], dr[1], 1000, 1000, 3)
	var f: Dictionary = w.table("facility")[dr[1]]
	check_eq(EconTrucks.room(w, f, 1.0), 2 * EconTrucks.CARRY * S, "two on the road carry, the broken one does not")
	check_eq(EconTrucks.room(w, f, 0.5), EconTrucks.CARRY * S, "half a month's driving, half the room")
	EconTrucks._scale(w)
	check_eq(int(f["scale"]), 3000, "one driver for each truck it owns")


func test_a_special_order_at_the_components_works() -> void:
	var sim := _sim(FR, 6)
	var w := sim.world
	var q := {}
	for qq in EconTrucks.quotes(w, "d:1"):
		if String(qq["kind"]) == "WORKS":
			q = qq
	if q.is_empty():
		check(false, "a components works quotes a truck")
		return
	check_eq(int(q["quality"]), EconTruckShop.Q_MIN, "the works' trucks are always the lowest quality")
	var wf: Dictionary = w.table("facility")[q["seller"]]
	EconUtil.inv_add(w, wf["org"], "COMPONENT", wf["district"], EconTruckShop.TRUCK_PARTS * S, 0)
	var stock0 := EconUtil.inv_get(w, wf["org"], "COMPONENT", wf["district"])
	var dr := _driver(w, "d:1", int(q["price"]) * 2)
	var cash0 := w.ledger.balance(EconUtil.acct(wf["org"]))
	check(EconTrucks.buy(w, q, dr[0], dr[1], "d:1"), "ordered and paid")
	check_eq(w.ledger.balance(EconUtil.acct(wf["org"])) - cash0, int(q["price"]), "the works is paid on order")
	check_eq(EconTrucks.on_order(w, dr[0]), 1, "on order")
	EconTrucks._works_orders(w)
	var got := 0
	for tid in w.table("truck"):
		var t: Dictionary = w.table("truck")[tid]
		if String(t["owner"]) == dr[0]:
			got += 1
			check_eq(String(t["maker"]), "WORKS", "made by the works")
			check_eq(String(t["fac"]), dr[1], "to the driver's business")
	check_eq(got, 1, "built from its stock")
	check_eq(stock0 - EconUtil.inv_get(w, wf["org"], "COMPONENT", wf["district"]), EconTruckShop.TRUCK_PARTS * S, "its parts taken")
	check_eq(EconTrucks.on_order(w, dr[0]), 0, "delivered")


func test_a_home_world_truck_goes_out_on_one_ship_and_comes_on_the_next() -> void:
	var sim := _sim(FR, 2)
	var w := sim.world
	var price := EconTrucks.home_price(w)
	var dr := _driver(w, "d:1", price * 2)
	var q := {"kind": "HOME", "seller": "home", "quality": EconTrucks.Q_HOME, "price": price, "wait_m": 2}
	var ext0 := w.ledger.balance(Ledger.EXTERNAL)
	check(EconTrucks.buy(w, q, dr[0], dr[1], "d:1"), "ordered and paid")
	check_eq(w.ledger.balance(Ledger.EXTERNAL) - ext0, price, "paid to the home world")
	var n0 := w.table("truck").size()
	EconTrucks.on_ship(w)
	check_eq(w.table("truck").size(), n0, "the order goes out on the ship in port")
	EconTrucks.on_ship(w)
	check_eq(w.table("truck").size(), n0 + 1, "the truck comes on the next ship")


func test_the_home_world_only_without_a_maker_in_the_colony() -> void:
	var sim := _sim(FR, 6)
	var w := sim.world
	var kinds := []
	for q in EconTrucks.quotes(w, "d:1"):
		kinds.append(String(q["kind"]))
	check("WORKS" in kinds, "a works runs")
	check(not ("HOME" in kinds), "no home-world truck while a works makes components")


func test_founding_on_a_trucks_share_of_all_the_freight() -> void:
	var sim := _sim(FR, 4)
	var w := sim.world
	var s := EconUtil.st(w)
	var big := 40 * EconTrucks.CARRY * S
	s["trk_work_hist"] = [[big, big / 2], [big, big / 2], [big, big / 2]]
	var q := EconTrucks.best_quote(w, "d:1")
	check(not q.is_empty(), "a truck to buy")
	var fc := EconTrucks.forecast(w, q)
	var n0 := 0
	for fid in w.table("facility"):
		if w.table("facility")[fid]["type"] == "TRUCKER":
			n0 += 1
	EconTrucks.found(w)
	var n1 := 0
	for fid in w.table("facility"):
		if w.table("facility")[fid]["type"] == "TRUCKER":
			n1 += 1
	if int(fc["profit"]) > 0:
		check(n1 > n0, "a share that pays: a family starts driving (%d)" % (n1 - n0))
		var ordered := 0
		for fid in w.table("facility"):
			var f: Dictionary = w.table("facility")[fid]
			if f["type"] == "TRUCKER":
				ordered += EconTrucks.on_order(w, String(f["org"])) + int(f.get("trk_own", 0))
		check(ordered >= n1 - n0, "each with a truck on order")
		var share_after := EconTrucks.forecast(w, q)
		check(int(share_after["volume"]) < int(fc["volume"]), "each new driver counts in the next one's competitors")
	else:
		check(n1 == n0, "no share that pays: nobody starts")
	s["trk_work_hist"] = [[0, 0], [0, 0], [0, 0]]
	var n2 := n1
	EconTrucks.found(w)
	var n3 := 0
	for fid in w.table("facility"):
		if w.table("facility")[fid]["type"] == "TRUCKER":
			n3 += 1
	check_eq(n3, n2, "no freight asked: nobody starts")


func test_the_grants_need_is_freight_left_behind() -> void:
	var sim := _sim(FR, 2)
	var w := sim.world
	var s := EconUtil.st(w)
	s["trk_work_hist"] = [[1000, 10], [1000, 10], [1000, 10]]
	check(EconTrucks.need_any(w), "left behind three months running: a need")
	s["trk_work_hist"] = [[1000, 10], [1000, 0], [1000, 10]]
	check(not EconTrucks.need_any(w), "a month with nothing left behind: no need")
	EconTrucks._publish_need(w)
	check_eq(int(s["lever_need"][EconTrucks.LEVER]), 0, "no need, no grant offered: 0")


func test_runs_18_months() -> void:
	var sim := _sim(FR, 18)
	var w := sim.world
	check(w.table("truck").size() >= 0, "ran 18 months with the drivers on")
	var v := EconTrucks.view(w)
	check(v.has("drivers"), "a view")

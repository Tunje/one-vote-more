extends TestCase
## Ships are the home world's (flag SHIPPING; user 2026-11-15 and 2026-11-16): it can build a larger ship or one more
## ship that calls on its own interval, takes a higher price until the ship is paid off, and then the ship stays.

const EconSim := preload("res://sim/economy/econ_sim.gd")
const LQ := preload("res://sim/law/law_query.gd")


func _world(on: bool) -> WorldState:
	var sim: Simulation = EconSim.make(4, "BALANCED", {}, true)
	sim.run(24)
	if on:
		(sim.world.meta["on"] as Array).append("SHIPPING")
	return sim.world


func _port_full(w: WorldState) -> void:
	w.add_fact({"type": "ECON_PORT_FULL", "owner": "econ", "subjects": [], "responsible": [], "impact": {}, "magnitude": 25,
		"visibility": "PUBLIC", "data": {}})


## Calls ships until the home world builds (a needy home world that trusts the colony); returns the HOME_SHIP_BUILT data.
func _until_built(w: WorldState, h: Dictionary) -> Dictionary:
	var sv: Dictionary = LQ.sovereignty(w)
	var r := w.rng.stream("pol.home")
	h["need"] = 100
	h["loyalty"] = 100
	for i in 12:
		_port_full(w)
		HomeWorld._shipping_pressure(w, h)
		w.month += 20
		HomeWorld._shipping(w, h, sv, r)
		var b: Array = w.facts.query("HOME_SHIP_BUILT")
		if not b.is_empty():
			return b[b.size() - 1]["data"]
	return {}


func test_off_without_the_flag() -> void:
	var w := _world(false)
	var h := HomeWorld.state(w)
	var keys := h.keys().size()
	_port_full(w)
	HomeWorld._shipping_pressure(w, h)
	HomeWorld._shipping(w, h, LQ.sovereignty(w), w.rng.stream("pol.home"))
	check_eq(h.keys().size(), keys, "nothing written")
	check(w.facts.query("HOME_SHIPPING_REQUESTED").is_empty(), "no request")
	check(not w.values.has("SHIP_HOLD") and not w.values.has("HOME_TARIFF") and EconTrade.fleet(w).is_empty(), "the ship is unchanged")


## No word reaches the home world without a ship (the user, 2026-11-16): the request goes with the ship in port, the
## answer comes back with the same ship on its next call, and a ship calling in between knows nothing.
func test_a_request_travels_with_the_ship_and_the_answer_comes_back_with_it() -> void:
	var w := _world(true)
	var h := HomeWorld.state(w)
	var sv: Dictionary = LQ.sovereignty(w)
	var r := w.rng.stream("pol.home")
	h["need"] = 100
	h["loyalty"] = 100
	_port_full(w)
	HomeWorld._shipping_pressure(w, h)
	w.month += 5
	_port_full(w)
	HomeWorld._shipping_pressure(w, h)
	check(w.facts.query("HOME_SHIPPING_REQUESTED").is_empty(), "a full port between ships: nobody to ask")
	w.month += 15
	HomeWorld._shipping(w, h, sv, r)
	check_eq(w.facts.query("HOME_SHIPPING_REQUESTED").size(), 1, "the ship is in port: the request goes with it")
	check(w.facts.query("HOME_SHIP_BUILT").is_empty() and w.facts.query("HOME_SHIPPING_REFUSED").is_empty(), "no answer on the same call")
	# another ship calls in between: it left home before the request arrived
	CoreUtil.econ_state(w)["ship_idx"] = 1
	w.month += 10
	_port_full(w)
	HomeWorld._shipping_pressure(w, h)
	HomeWorld._shipping(w, h, sv, r)
	check_eq(w.facts.query("HOME_SHIPPING_REQUESTED").size(), 1, "one request under way, no second one")
	check(w.facts.query("HOME_SHIP_BUILT").is_empty() and w.facts.query("HOME_SHIPPING_REFUSED").is_empty(), "the other ship carries no answer")
	# the ship that carried it is back
	CoreUtil.econ_state(w)["ship_idx"] = 0
	w.month += 10
	HomeWorld._shipping(w, h, sv, r)
	check_eq(w.facts.query("HOME_SHIP_BUILT").size() + w.facts.query("HOME_SHIPPING_REFUSED").size(), 1, "the answer comes back with the ship that took the request")
	check(not h.has("ship_ask"), "and the request is settled")


func test_the_home_world_builds_and_takes_a_higher_price_until_it_is_paid() -> void:
	var w := _world(true)
	var h := HomeWorld.state(w)
	var hold0 := EconTrade.ship_hold(w)
	var gap0: Array = EconTrade.ship_interval(w)
	var d := _until_built(w, h)
	check(not d.is_empty(), "a needy home world that trusts the colony builds")
	if d.is_empty():
		return
	if String(d["what"]) == "LARGER_SHIP":
		check_eq(EconTrade.ship_hold(w), int(ceil(float(hold0) * HomeWorld.SHIP_HOLD_STEP)), "the ship on the route is larger")
		check(EconTrade.fleet(w).is_empty(), "and it is still one ship")
	else:
		check_eq(EconTrade.fleet(w).size(), 1, "one more ship")
		check_eq(EconTrade.ship_hold(w), hold0, "the first ship is as it was")
		check(int(EconTrade.fleet(w)[0]["next"]) > w.month, "it calls on its own clock")
	check_eq(str(EconTrade.ship_interval(w)), str(gap0), "no ship comes round faster than before")
	check_eq(EconTrade.home_tariff(w), HomeWorld.SHIP_PAYOFF_PM, "a higher price while the ship is paid off")
	check(int(h["ship_debt"]) > 0, "the cost is owed (%d)" % int(h.get("ship_debt", 0)))
	# nothing more is built while it is being paid off
	var built := w.facts.query("HOME_SHIP_BUILT").size()
	var sv: Dictionary = LQ.sovereignty(w)
	var r := w.rng.stream("pol.home")
	for i in 5:
		_port_full(w)
		HomeWorld._shipping_pressure(w, h)
		w.month += 20
		HomeWorld._shipping(w, h, sv, r)
	check_eq(w.facts.query("HOME_SHIP_BUILT").size(), built, "no second ship while the first is being paid off")
	# paid off: the charge ends, the ship stays
	h["ship_debt"] = 1
	(CoreUtil.econ_state(w)["trade"]["ships"] as Array).append({"month": w.month, "exports": {}, "export_value": 900000 * CoreUtil.S, "tax": 0, "levy": 0,
		"imports": {}, "import_value": 0, "by_org": {}})
	HomeWorld._shipping(w, h, sv, r)
	check(not h.has("ship_debt"), "paid off")
	check_eq(EconTrade.home_tariff(w), 0, "the higher price ends")
	check_eq(w.facts.query("HOME_SHIP_PAID_OFF").size(), 1, "and it is news")
	if String(d["what"]) == "LARGER_SHIP":
		check(EconTrade.ship_hold(w) > hold0, "the larger ship stays")
	else:
		check_eq(EconTrade.fleet(w).size(), 1, "the extra ship stays")


func test_an_extra_ship_calls_on_its_own_interval() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	sim.run(2)
	var s := CoreUtil.econ_state(w)
	var first_next := int(s["ship_next"])
	EconTrade.add_ship(w, w.month + 3, 500)
	var calls: Array = []
	for _m in 40:
		var before := int(s.get("ship_last", 0))
		sim.run(1)
		if int(s.get("ship_last", 0)) != before:
			calls.append([w.month - 1, int(s.get("ship_idx", 0))])
	var extra_calls := calls.filter(func(x): return int(x[1]) == 1)
	var first_calls := calls.filter(func(x): return int(x[1]) == 0)
	check(extra_calls.size() >= 2, "the extra ship called (%s)" % str(calls))
	check(first_calls.size() >= 1 and int(first_calls[0][0]) == first_next, "the first ship kept its own date (%d)" % first_next)
	if extra_calls.size() >= 2:
		var gap: int = int(extra_calls[1][0]) - int(extra_calls[0][0])
		check(gap >= int(EconData.SHIP_INTERVAL[0]) and gap <= int(EconData.SHIP_INTERVAL[1]) + 1, "its round trip is a ship's round trip (%d months)" % gap)
	check_eq(EconTrade.hold_of(w, 1), 500, "with its own hold")


func test_a_defiant_colony_is_mostly_refused() -> void:
	var w := _world(true)
	var h := HomeWorld.state(w)
	var r := w.rng.stream("pol.home")
	h["need"] = 10
	h["loyalty"] = 0
	for i in 12:
		_port_full(w)
		HomeWorld._shipping_pressure(w, h)
		w.month += 20
		HomeWorld._shipping(w, h, {"refusal": true}, r)
	var refused := w.facts.query("HOME_SHIPPING_REFUSED").size()
	check(refused >= 5, "mostly no (%d of 6 answers: a request and its answer take two calls)" % refused)
	if refused > 0:
		var f: Dictionary = w.facts.query("HOME_SHIPPING_REFUSED")[0]
		check(int(f["impact"].get("COLONIAL_BURDEN", 0)) < 0, "a refusal is felt as colonial burden")


func test_in_the_game_deterministic_and_save_load() -> void:
	var sims: Array = []
	for i in 2:
		var sim: Simulation = EconSim.make(3, "BALANCED", {}, true)
		(sim.world.meta["on"] as Array).append("SHIPPING")
		sim.run(36)
		EconTrade.add_ship(sim.world, sim.world.month + 6, 1000)
		_port_full(sim.world)
		sim.run(48)
		sims.append(sim)
	check_eq(sims[0].world.state_hash(), sims[1].world.state_hash(), "deterministic")
	var path := "user://test_shipping.sav"
	check_eq(SaveIO.save(sims[0], path), OK, "saved")
	var c := EconSim.for_load()
	check_eq(SaveIO.load_into(c, path), OK, "loaded")
	sims[0].run(12)
	c.run(12)
	check_eq(c.world.state_hash(), sims[0].world.state_hash(), "a saved game continues the same")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

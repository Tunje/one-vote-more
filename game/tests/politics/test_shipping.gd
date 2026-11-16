extends TestCase
## More ships and larger ships come from the home world, asked for by the colony (flag SHIPPING; user 2026-11-16).

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


func test_off_without_the_flag() -> void:
	var w := _world(false)
	var h := HomeWorld.state(w)
	_port_full(w)
	HomeWorld._shipping_request(w, h, false)
	check(not h.has("ship_request"), "no request")
	check(w.facts.query("HOME_SHIPPING_REQUESTED").is_empty(), "no fact")
	check(not w.values.has("SHIP_HOLD") and not w.values.has("SHIP_INTERVAL"), "the ship is unchanged")


func test_a_full_port_makes_the_colony_ask_once() -> void:
	var w := _world(true)
	var h := HomeWorld.state(w)
	HomeWorld._shipping_request(w, h, false)
	check(not h.has("ship_request"), "nothing to ask for while the port has room")
	_port_full(w)
	HomeWorld._shipping_request(w, h, false)
	check(h.has("ship_request"), "a full port: the government asks for shipping")
	HomeWorld._shipping_request(w, h, false)
	check_eq(w.facts.query("HOME_SHIPPING_REQUESTED").size(), 1, "one open request at a time")


func test_the_home_world_answers_on_a_later_ship() -> void:
	var w := _world(true)
	var h := HomeWorld.state(w)
	var sv: Dictionary = LQ.sovereignty(w)
	var r := w.rng.stream("pol.home")
	_port_full(w)
	HomeWorld._shipping_request(w, h, false)
	HomeWorld._answer_shipping(w, h, sv, r)
	check(h.has("ship_request"), "not answered in the month it was asked")
	w.month += 20
	h["need"] = 100
	h["loyalty"] = 100
	var hold0 := EconTrade.ship_hold(w)
	var gap0: Array = EconTrade.ship_interval(w)
	var granted := 0
	for i in 12:
		if not h.has("ship_request"):
			h["ship_request"] = {"month": w.month - 1, "left": 0, "port_full": true}
		HomeWorld._answer_shipping(w, h, sv, r)
		granted = w.facts.query("HOME_SHIPPING_GRANTED").size()
	check(granted >= 6, "a needy home world that trusts the colony mostly says yes (%d of 12)" % granted)
	check(EconTrade.ship_hold(w) > hold0, "larger ships (%d -> %d)" % [hold0, EconTrade.ship_hold(w)])
	check(int(EconTrade.ship_interval(w)[0]) < int(gap0[0]), "and more of them (%s -> %s)" % [str(gap0), str(EconTrade.ship_interval(w))])
	check(int(EconTrade.ship_interval(w)[0]) >= HomeWorld.SHIP_GAP_FLOOR, "never faster than a ship can turn round")


func test_a_defiant_colony_is_mostly_refused() -> void:
	var w := _world(true)
	var h := HomeWorld.state(w)
	var r := w.rng.stream("pol.home")
	h["need"] = 10
	h["loyalty"] = 0
	w.month += 20
	for i in 12:
		h["ship_request"] = {"month": w.month - 1, "left": 0, "port_full": true}
		HomeWorld._answer_shipping(w, h, {"refusal": true}, r)
	var refused := w.facts.query("HOME_SHIPPING_REFUSED").size()
	check(refused >= 9, "mostly no (%d of 12)" % refused)
	var f: Dictionary = w.facts.query("HOME_SHIPPING_REFUSED")[0]
	check(int(f["impact"].get("COLONIAL_BURDEN", 0)) < 0, "a refusal is felt as colonial burden")


func test_in_the_game_deterministic_and_save_load() -> void:
	var sims: Array = []
	for i in 2:
		var sim: Simulation = EconSim.make(3, "BALANCED", {}, true)
		(sim.world.meta["on"] as Array).append("SHIPPING")
		sim.run(48)
		_port_full(sim.world)
		sim.run(36)
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

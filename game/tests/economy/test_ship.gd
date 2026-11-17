extends TestCase
## The ship (sim/economy/ship.gd): nothing is ordered without a ship in port; an order comes back with the same ship
## on its next call, the full round trip; it is paid on the dock; nothing appears or vanishes.

const Ship := preload("res://sim/economy/ship.gd")
const Landing := preload("res://sim/economy/landing.gd")
const Company := preload("res://sim/economy/company.gd")
const TypeTable := preload("res://sim/economy/type_table.gd")
const S := CoreUtil.S


func _game() -> Simulation:
	return GameSim.make(1)


func _stores(w: WorldState) -> String:
	return String(Landing.land(w, AreaStore.found_landing(w))["stores"])


## Runs until the ship in port has left and a ship is in port again; returns the months run.
func _run_to_next_call(sim: Simulation) -> int:
	var n := 0
	while not Ship.in_port(sim.world).is_empty() and n < 5:
		sim.step()
		n += 1
	while Ship.in_port(sim.world).is_empty() and n < 60:
		sim.step()
		n += 1
	return n


func test_the_landing_ship_is_in_port_in_month_one_and_then_gone() -> void:
	var sim := _game()
	var w := sim.world
	check_eq(Ship.in_port(w), ["ship:1"], "the ship that brought the colony lies in port")
	check_eq(Ship.next_call(w), w.month, "a ship in port counts as now")
	sim.step()
	check_eq(Ship.in_port(w), ["ship:1"], "it lies in port through the first month")
	sim.step()
	check(Ship.in_port(w).is_empty(), "then it has left")
	var gap: Array = EconFace.trade_ship_interval(w)
	var back := Ship.next_call(w)
	check(back >= int(gap[0]) and back <= int(gap[1]), "back after a round trip inside the interval (month %d)" % back)
	check_eq(Logbook.rows(w, {"kind": "SHIP", "what": "left port"}).size(), 1, "its leaving is in the log")


func test_no_ship_in_port_no_order() -> void:
	var sim := _game()
	var w := sim.world
	var stores := _stores(w)
	sim.step()
	sim.step()
	var r := Ship.order(w, stores, "FOOD", 100 * S)
	check(not r["ok"], "refused")
	check_eq(String(r["why"]), "no ship in port", "because no ship is there to take it")
	check_eq(Logbook.rows(w, {"what": "order NOT taken"}).size(), 1, "the refusal is in the log")


func test_what_cannot_be_ordered() -> void:
	var w := _game().world
	var stores := _stores(w)
	check_eq(String(Ship.order(w, "company:999", "FOOD", S)["why"]), "unknown company", "a buyer that does not exist")
	check_eq(String(Ship.order(w, stores, "ENERGY", S)["why"]), "not something a ship carries", "a grid good")
	check_eq(String(Ship.order(w, stores, "FOOD", 0)["why"]), "nothing ordered", "nothing")
	var a := Ship.order(w, stores, "FOOD", (Ship.HOLD_START - 10) * S)
	check(a["ok"], "most of the hold")
	var b := Ship.order(w, stores, "MATERIAL", 50 * S)
	check_eq(int(b["qty"]), 10 * S, "only what room is left is taken")
	check_eq(String(Ship.order(w, stores, "FOOD", S)["why"]), "the hold is full", "then the hold is full")


func test_an_order_comes_back_with_the_same_ship_and_is_paid_on_the_dock() -> void:
	var sim := _game()
	var w := sim.world
	var stores := _stores(w)
	var r := Ship.order(w, stores, "FOOD", 200 * S, {"why": "test"})
	check(r["ok"], "taken by the ship in port")
	var price := Ship.home_price(w, "FOOD")
	check_eq(price, 2 * TypeTable.start_price("FOOD"), "at the home world's price")
	var food := int(Company.stock_of(w, stores, "FOOD")["qty"])
	var months := _run_to_next_call(sim)
	var gap: Array = EconFace.trade_ship_interval(w)
	check(months >= int(gap[0]), "nothing came before the full round trip (%d months)" % months)
	check_eq(Logbook.rows(w, {"kind": "IMPORT", "what": "landed and paid on the dock"}).size(), 0, "unpaid: the Stores hold no money")
	check_eq(Logbook.rows(w, {"kind": "IMPORT", "what": "landed IN PART: short of money"}).size(), 1, "a buyer with no money gets nothing, and the log says why")
	check_eq(int(Company.stock_of(w, stores, "FOOD")["qty"]), food, "no food from nowhere")
	check_eq(int(Ship.last(w)["returned"]["FOOD"]), 200 * S, "it all went back")


func test_a_buyer_with_money_gets_its_goods_and_the_money_leaves_the_colony() -> void:
	var sim := _game()
	var w := sim.world
	# a state company with no staff: nothing else touches its account
	var buyer := String(Landing.land(w, AreaStore.found_landing(w))["unbuilt"]["POWER"])
	var acct := CoreUtil.acct(buyer)
	var price := Ship.home_price(w, "MATERIAL")
	w.ledger.transfer(Ledger.EXTERNAL, acct, 15 * price, "TEST", w.month)
	var r := Ship.order(w, buyer, "MATERIAL", 10 * S)
	check(r["ok"], "ordered")
	check_eq(w.ledger.balance(acct), 15 * price, "nothing is paid when ordering")
	var n := 0
	while not Ship.in_port(w).is_empty() and n < 5:
		sim.step()
		n += 1
	check_eq(int(Company.stock_of(w, buyer, "MATERIAL")["qty"]), 0, "nothing while the ship is away")
	var total := -w.ledger.balance(Ledger.EXTERNAL)
	_run_to_next_call(sim)
	check_eq(int(Company.stock_of(w, buyer, "MATERIAL")["qty"]), 10 * S, "ten units landed in its stock")
	check_eq(int(Company.stock_of(w, buyer, "MATERIAL")["value"]), 10 * price, "booked at what it paid")
	check_eq(w.ledger.balance(acct), 5 * price, "paid on the dock from its own account")
	check_eq(-w.ledger.balance(Ledger.EXTERNAL), total - 10 * price, "the payment left the colony aboard the ship, and nothing else did")
	check_eq(Logbook.rows(w, {"kind": "IMPORT", "what": "landed and paid on the dock"}).size(), 1, "in the log, once")
	check_eq(w.facts.query("ECON_IMPORT_ARRIVED", 0).size(), 1, "and published")
	check_eq(Logbook.rows(w, {"ref": String(r["order"])}).size(), 2, "the order's two rows: taken and landed")


func test_the_home_world_can_enlarge_a_ship_or_send_another() -> void:
	var w := _game().world
	check_eq(Ship.hold_of(w, 0), Ship.HOLD_START, "the first ship's hold")
	Ship.set_hold(w, 0, 5000)
	check_eq(Ship.hold_of(w, 0), 5000, "enlarged")
	Ship.add_ship(w, 9, 1200)
	check_eq(Ship.fleet(w).size(), 2, "one more ship")
	check_eq(Ship.next_call(w), w.month, "the first is still in port")
	Ship.fleet(w)[0]["hold"] = 1
	check_eq(Ship.hold_of(w, 0), 5000, "a reader cannot change a ship")


func test_a_ship_that_leaves_is_never_back_the_same_month() -> void:
	var sim := _game()
	var w := sim.world
	w.values["SHIP_INTERVAL"] = [1, 1]   # the shortest a treaty could make it
	var buyer := String(Landing.land(w, AreaStore.found_landing(w))["unbuilt"]["POWER"])
	w.ledger.transfer(Ledger.EXTERNAL, CoreUtil.acct(buyer), 1000000 * S, "TEST", w.month)
	check(Ship.order(w, buyer, "MATERIAL", 5 * S)["ok"], "ordered in month 0")
	sim.step()
	sim.step()   # month 1's TRADE: it leaves
	check(Ship.in_port(w).is_empty(), "it has left and is not back in the same month")
	check_eq(int(Company.stock_of(w, buyer, "MATERIAL")["qty"]), 0, "so nothing has landed yet")
	sim.step()
	check_eq(int(Company.stock_of(w, buyer, "MATERIAL")["qty"]), 5 * S, "it lands the month after")


func test_a_ships_facts_say_where_the_port_is() -> void:
	var w := _game().world
	var sim2 := _game()
	_run_to_next_call(sim2)
	var f: Array = sim2.world.facts.query("ECON_SHIP_ARRIVED", 0)
	check_eq(f.size(), 1, "the ship's return is published")
	var l := Terrain.landing(w)
	check_eq(f[0]["data"]["tile"], [l.x, l.y], "at the landfall tile")
	check_eq(int(f[0]["data"]["hex"]), Planet.landing(w), "and its hex on the globe")


func test_ships_save_and_load_the_same() -> void:
	var a := _game()
	Ship.order(a.world, _stores(a.world), "FOOD", 50 * S)
	for i in 4:
		a.step()
	var b := GameSim.for_load()
	b.load_dict(a.to_dict())
	for i in 30:
		a.step()
		b.step()
	check_eq(a.world.state_hash(), b.world.state_hash(), "a loaded game sails the same")
	check_eq(Ship.next_call(a.world), Ship.next_call(b.world), "and the ship is due the same month")

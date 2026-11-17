extends TestCase
## What politics reads of the economy at step 3 (planning/rebuild-politics-face.md; EconFace, econ_publish): the
## economy runs once the market has cleared; the food market as the legislature reads it; a firm's yearly revenue for
## the law's fines; the markets and shortages the screens show; the reference wage. Read from Bob's market and record.

const Market := preload("res://sim/economy/market.gd")
const Company := preload("res://sim/economy/company.gd")
const EconPublish := preload("res://sim/economy/econ_publish.gd")
const S := 1000
const HW := {"kind": "HOME_WORLD", "holders": {"home_world": 1000}}


func _farm(w: WorldState, food: int, price: int) -> String:
	var id := Company.create(w, "FARM", "SMALL", HW, "Greenacre", {"area": "landing"})
	Company.add_plant(w, id, "SMALL")
	if food > 0:
		Company.stock_add(w, id, "FOOD", food * S, 20 * S, "OUTPUT", "harvest")
	Company.set_price(w, id, "FOOD", price)
	return id


func _buyer(w: WorldState, id: String, cash: int) -> Dictionary:
	var acct := "hh:" + id
	w.ledger.open_account(acct)
	if cash > 0:
		w.ledger.transfer(Ledger.EXTERNAL, acct, cash, "TEST", w.month)
	return {"kind": "POOL", "id": id, "acct": acct, "area": "landing"}


## 30 food on offer, 40 asked for by a buyer who can pay, 10 by one who cannot: one clear.
func _a_month(w: WorldState) -> String:
	var f := _farm(w, 30, 60 * S)
	Market.order(w, _buyer(w, "pool:a", 10000 * S), "FOOD", 40 * S, 70 * S)
	Market.order(w, _buyer(w, "pool:b", 0), "FOOD", 10 * S, 70 * S)
	Market.clear(w)
	return f


func test_the_economy_runs_once_the_market_has_cleared() -> void:
	var w := WorldState.new(1)
	check(not EconFace.running(w), "not before the first clear")
	var h := w.state_hash()
	EconFace.running(w)
	check_eq(w.state_hash(), h, "asking changes nothing")
	_a_month(w)
	check(EconFace.running(w), "running after it")


func test_the_food_market_as_the_legislature_reads_it() -> void:
	var w := WorldState.new(1)
	_a_month(w)
	var m := EconFace.market_month(w, "FOOD")
	check_eq(int(m["wanted"]), 50 * S, "50 asked for")
	check_eq(int(m["filled"]), 30 * S, "30 supplied")
	check_eq(int(m["unfilled"]["NO_MONEY"]), 10 * S, "10 with no money behind them")
	check_eq(int(m["unfilled"]["SOLD_OUT"]), 10 * S, "10 the seller had sold out of")
	check_eq(Legislature.food_scarce(w), 0.2, "scarce: only the 10 the seller had sold out of, not the 10 nobody could pay for")


func test_a_firms_year_for_the_fines() -> void:
	var w := WorldState.new(1)
	var f := _a_month(w)
	var a := EconFace.annual_revenue(w, f)
	check_eq(int(a["months"]), Company.months_on_books(w, f), "its months on the books")
	check_eq(int(a["rev_12"]), Company.revenue_12(w, f), "its revenue over them")
	check_eq(EconFace.annual_revenue(w, "company:none"), {"months": 0, "rev_12": 0}, "no company, nothing")


func test_the_markets_and_shortages_the_screens_show() -> void:
	var w := WorldState.new(1)
	_a_month(w)
	var mk := EconFace.query_market_overview(w)
	check_eq(mk.size(), 1, "one item traded")
	var r: Dictionary = mk[0]
	check_eq(String(r["good"]), "FOOD", "food")
	check_eq(float(r["price"]), 60.0, "at 60 credits")
	check_eq(float(r["wanted"]), 50.0, "50 wanted")
	check_eq(float(r["offered"]), 30.0, "30 offered")
	check_eq(float(r["seller_share_pct"]["Greenacre"]), 100.0, "all from one seller")
	check(float(r["base_price"]) > 0.0, "with the starting price beside it")
	var sh := EconFace.query_shortages(w)
	check_eq(sh.size(), 1, "food is short")
	check_eq(float(sh[0]["filled_pct"]), 60.0, "60% of demand met")
	var prs: Array = sh[0]["producers"]
	check_eq(prs.size(), 1, "one producer")
	if prs.size() == 1:
		var pr: Dictionary = prs[0]
		check_eq(String(pr["type"]), "FARM", "a farm")
		check_eq(String(pr["facility"]), String(Company.plant_ids_of(w, String(Company.ids(w)[0]))[0]), "its plant")
		check_eq(String(pr["district"]), preload("res://sim/economy/grants.gd")._district(w, "landing"), "the district by the grants' rule")
		check_eq(float(pr["utilization_pct"]), 100.0, "it sold all it offered")
		check_eq(String(pr["owner"]), "Greenacre", "and who owns it")


func test_nothing_to_show_before_the_market_runs() -> void:
	var w := WorldState.new(1)
	check(EconFace.query_market_overview(w).is_empty(), "no markets yet")
	check(EconFace.query_shortages(w).is_empty(), "no shortages yet")


func test_the_reference_wage_is_published_when_people_are_paid() -> void:
	var w := WorldState.new(1)
	EconPublish.publish_w_ref(w)
	check(not w.values.has("ECON_W_REF"), "nobody paid: the readers keep their own fallback")
	var sim := GameSim.make(3)   # the landing: the builders and the administration employ people
	sim.run(1)
	var wr := Company.reference_wage(sim.world)
	check(wr > 0, "people are paid in month one")
	check_eq(int(sim.world.values.get("ECON_W_REF", 0)), wr, "the average pay, colony-wide")

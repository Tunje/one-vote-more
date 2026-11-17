extends TestCase
## The market (plan 9.3; 12.3, 23a and 27; 12.8, 50b): one sale to the last credit and unit; cheapest first; a short
## good shared in proportion; why an order is short (no money, refusing the price, sold out, no seller); what each
## seller learns for its rules; nothing appears or vanishes.

const Market := preload("res://sim/economy/market.gd")
const Company := preload("res://sim/economy/company.gd")
const S := 1000
const HW := {"kind": "HOME_WORLD", "holders": {"home_world": 1000}}


func _w() -> WorldState:
	return WorldState.new(1)


func _farm(w: WorldState, food: int, price: int, area: String = "landing") -> String:
	var id := Company.create(w, "FARM", "SMALL", HW, "Farm", {"area": area})
	if food > 0:
		Company.stock_add(w, id, "FOOD", food * S, 20 * S, "OUTPUT", "harvest")
	Company.set_price(w, id, "FOOD", price)
	return id


func _buyer(w: WorldState, id: String, cash: int, area: String = "landing") -> Dictionary:
	var acct := "hh:" + id
	w.ledger.open_account(acct)
	if cash > 0:
		w.ledger.transfer(Ledger.EXTERNAL, acct, cash, "TEST", w.month)
	return {"kind": "POOL", "id": id, "acct": acct, "area": area}


func _money(w: WorldState) -> int:
	return w.ledger.total()


func test_one_sale_to_the_last_credit_and_unit() -> void:
	var w := _w()
	var f := _farm(w, 100, 60 * S)
	var b := _buyer(w, "pool:a", 10000 * S)
	var m0 := _money(w)
	var oid := Market.order(w, b, "FOOD", 40 * S, 70 * S)
	check(oid != "", "an order")
	check_eq(Market.last_settled_month(w), -1, "never settled yet")
	check_eq(Market.clear(w), 1, "one sale")
	check_eq(Market.filled(w, oid), {"qty": 40 * S, "paid": 40 * 60 * S, "why": "", "cleared": true}, "40 at the seller's price, not the buyer's most")
	check_eq(w.ledger.balance(CoreUtil.acct(f)), 40 * 60 * S, "the seller was paid")
	check_eq(w.ledger.balance("hh:pool:a"), 10000 * S - 40 * 60 * S, "the buyer paid")
	check_eq(int(Company.stock_of(w, f, "FOOD")["qty"]), 60 * S, "60 left with the seller")
	check_eq(_money(w), m0, "no money appeared or vanished")
	var sales := w.peek("sale")
	check_eq(sales.size(), 1, "one sale record")
	var s: Dictionary = sales.values()[0]
	check_eq([s["seller"], s["buyer"], s["qty"], s["price"], s["order"]], [f, "pool:a", 40 * S, 60 * S, oid], "the record says who, what and how much")
	check_eq(int(Company.books_month(w, f)["rev"]), 40 * 60 * S, "booked as revenue")
	check_eq(Market.last_settled_month(w), 0, "settled this month")


func test_the_cheapest_offer_fills_first() -> void:
	var w := _w()
	var cheap := _farm(w, 30, 50 * S)
	var dear := _farm(w, 30, 60 * S)
	var oid := Market.order(w, _buyer(w, "p", 100000 * S), "FOOD", 40 * S, 70 * S)
	Market.clear(w)
	check_eq(int(Company.stock_of(w, cheap, "FOOD")["qty"]), 0, "all of the cheaper")
	check_eq(int(Company.stock_of(w, dear, "FOOD")["qty"]), 20 * S, "then 10 of the dearer")
	check_eq(int(Market.filled(w, oid)["paid"]), 30 * 50 * S + 10 * 60 * S, "each at its own price")


func test_a_short_good_is_shared_in_proportion() -> void:
	var w := _w()
	_farm(w, 30, 60 * S)
	var a := Market.order(w, _buyer(w, "a", 100000 * S), "FOOD", 40 * S, 70 * S)
	var b := Market.order(w, _buyer(w, "b", 100000 * S), "FOOD", 20 * S, 60 * S, "AHEAD")
	Market.clear(w)
	check_eq(int(Market.filled(w, a)["qty"]), 20 * S, "two thirds to the one who wanted twice as much")
	check_eq(int(Market.filled(w, b)["qty"]), 10 * S, "a third: stocking up is an order like any other; no class goes first")
	check_eq(Market.filled(w, a)["why"], "SOLD_OUT", "short because it was sold out")


func test_why_an_order_is_short() -> void:
	var w := _w()
	var f := _farm(w, 50, 60 * S)
	var refuse := Market.order(w, _buyer(w, "r", 100000 * S), "FOOD", 20 * S, 50 * S)
	var broke := Market.order(w, _buyer(w, "n", 0), "FOOD", 10 * S, 0)
	var poor := Market.order(w, _buyer(w, "q", 600 * S), "FOOD", 30 * S, 70 * S)
	var none := Market.order(w, _buyer(w, "x", 100000 * S), "MEDICAL", S, 100 * S)
	Market.clear(w)
	check_eq(Market.filled(w, refuse)["why"], "PRICE", "could pay something, less than the asking price: a refusal")
	check_eq(Market.filled(w, broke)["why"], "NO_MONEY", "could pay nothing")
	check_eq(Market.filled(w, poor)["qty"], 10 * S, "what its money reached")
	check_eq(Market.filled(w, poor)["why"], "PRICE", "it paid for some and could not pay THIS price for the rest: a refusal of the price (23a)")
	check_eq(Market.filled(w, none)["why"], "NO_SELLER", "nobody offers it")
	var sg := Market.seller_signal(w, f, "FOOD")
	check_eq([sg["offered"], sg["sold"]], [50 * S, 10 * S], "the seller offered 50 and sold 10")
	check_eq(int(sg["refused"]), 40 * S, "20 + 20 refused its price: a signal for a cut (23a)")
	check_eq(int(sg["unmet_above"]), 0, "nobody went unserved at its price")
	var sm := Market.summary(w, "FOOD")
	check_eq(sm["unfilled"], {"NO_MONEY": 10 * S, "PRICE": 40 * S, "SOLD_OUT": 0, "NO_SELLER": 0}, "the month's summary by why")


func test_a_seller_with_no_stock_still_learns_what_it_was_asked_for() -> void:
	var w := _w()
	var empty := _farm(w, 0, 60 * S)
	Company.add_plant(w, empty, "SMALL")
	var oid := Market.order(w, _buyer(w, "a", 100000 * S), "FOOD", 30 * S, 80 * S)
	Market.clear(w)
	check_eq(Market.filled(w, oid)["why"], "NO_SELLER", "nobody had any to offer")
	check_eq(Market.seller_signal(w, empty, "FOOD")["unmet_above"], 30 * S, "the farm with nothing to sell learns 30 were wanted at its price (rules 1, 3)")


func test_a_shortfall_is_shared_among_the_sellers_not_counted_for_each() -> void:
	var w := _w()
	var a := _farm(w, 10, 50 * S)
	var b := _farm(w, 30, 60 * S)
	Market.order(w, _buyer(w, "x", 100000 * S), "FOOD", 80 * S, 70 * S)
	Market.clear(w)
	var ua := int(Market.seller_signal(w, a, "FOOD")["unmet_above"])
	var ub := int(Market.seller_signal(w, b, "FOOD")["unmet_above"])
	check_eq(ua + ub, 40 * S, "the 40 short are shared, not counted twice")
	check(ua > 0 and ub > 0, "both sold out at or under its price get a share")


func test_a_company_does_not_buy_from_its_own_offer() -> void:
	var w := _w()
	var stores := Company.create(w, "SHOP", "LARGE", HW, "Stores", {"area": "landing"})
	Company.stock_add(w, stores, "MATERIAL", 10 * S, 37 * S, "LANDING", "x")
	Company.offer(w, stores, "MATERIAL", 37 * S)
	w.ledger.transfer(Ledger.EXTERNAL, CoreUtil.acct(stores), 1000 * S, "TEST", 0)
	var oid := Market.order(w, {"kind": "COMPANY", "id": stores, "acct": CoreUtil.acct(stores), "area": "landing"}, "MATERIAL", 5 * S, 40 * S)
	Market.clear(w)
	check_eq(int(Market.filled(w, oid)["qty"]), 0, "it does not meet its own offer")


func test_a_sold_out_seller_learns_what_it_turned_away() -> void:
	var w := _w()
	var f := _farm(w, 10, 60 * S)
	Market.order(w, _buyer(w, "a", 100000 * S), "FOOD", 30 * S, 80 * S)
	Market.clear(w)
	var sg := Market.seller_signal(w, f, "FOOD")
	check_eq([sg["offered"], sg["sold"], sg["unmet_above"]], [10 * S, 10 * S, 20 * S], "sold all, 20 more wanted at or above its price (rule 1)")


func test_an_offer_with_no_orders_still_tells_its_seller() -> void:
	var w := _w()
	var f := _farm(w, 25, 60 * S)
	Market.clear(w)
	check_eq(Market.seller_signal(w, f, "FOOD")["offered"], 25 * S, "offered 25")
	check_eq(Market.seller_signal(w, f, "FOOD")["sold"], 0, "and sold nothing")


func test_hold_back_and_other_areas_are_not_offered() -> void:
	var w := _w()
	var f := _farm(w, 50, 60 * S)
	Company.set_hold(w, f, "FOOD", 30 * S)
	_farm(w, 50, 10 * S, "elsewhere")
	var oid := Market.order(w, _buyer(w, "a", 100000 * S), "FOOD", 40 * S, 70 * S)
	Market.clear(w)
	check_eq(int(Market.filled(w, oid)["qty"]), 20 * S, "only what is not held back, and not the cheaper food in another area")
	check_eq(int(Company.stock_of(w, f, "FOOD")["qty"]), 30 * S, "the held stock stays")


func test_a_company_buyer_gets_the_goods_in_its_stock() -> void:
	var w := _w()
	var f := _farm(w, 50, 60 * S)
	var bakery := Company.create(w, "BAKERY", "SMALL", HW, "Bakery", {"area": "landing"})
	w.ledger.transfer(Ledger.EXTERNAL, CoreUtil.acct(bakery), 100000 * S, "TEST", w.month)
	Market.order(w, {"kind": "COMPANY", "id": bakery, "acct": CoreUtil.acct(bakery), "area": "landing"}, "FOOD", 20 * S, 70 * S)
	Market.clear(w)
	check_eq(int(Company.stock_of(w, bakery, "FOOD")["qty"]) + int(Company.stock_of(w, f, "FOOD")["qty"]), 50 * S, "the goods moved, none appeared")
	check_eq(int(Company.stock_of(w, bakery, "FOOD")["value"]), 20 * 60 * S, "at what it paid")
	check_eq(int(Company.books_month(w, bakery)["bought"]), 20 * 60 * S, "booked as bought")


func test_orders_last_until_the_next_clear_and_the_summary_twelve_months() -> void:
	var w := _w()
	_farm(w, 1000, 60 * S)
	var b := _buyer(w, "a", 10000000 * S)
	var first := Market.order(w, b, "FOOD", S, 70 * S)
	Market.clear(w)
	for m in range(1, 15):
		w.month = m
		Market.order(w, b, "FOOD", S, 70 * S)
		Market.clear(w)
	check(Market.filled(w, first).is_empty(), "an old order is dropped at a later clear")
	check_eq(Market.history(w, "FOOD", "landing").size(), 12, "twelve months of summaries kept")
	check_eq(int(Market.history(w, "FOOD", "landing")[-1]["m"]), 14, "the newest last")
	check_eq(w.peek("sale").size(), 12, "and twelve months of sale records")


func test_a_budget_keeps_each_order_to_its_own_money() -> void:
	var w := _w()
	var f := _farm(w, 100, 60 * S)
	var tex := Company.create(w, "TEXTILE", "SMALL", HW, "T", {"area": "landing"})
	Company.stock_add(w, tex, "CLOTHING", 100 * S, 10 * S, "OUTPUT", "made")
	Company.set_price(w, tex, "CLOTHING", 20 * S)
	var b := _buyer(w, "pool", 400 * S)
	# food first: 300 set aside for it, 100 for clothing; CLOTHING's book clears before FOOD's ("C" before "F")
	var food := Market.order(w, b, "FOOD", 10 * S, 70 * S, "NEED", 300 * S)
	var cloth := Market.order(w, b, "CLOTHING", 10 * S, 30 * S, "NEED", 100 * S)
	Market.clear(w)
	check_eq(Market.filled(w, cloth), {"qty": 5 * S, "paid": 100 * S, "why": "PRICE", "cleared": true}, "clothing spends only its 100: 5 at 20")
	check_eq(Market.filled(w, food), {"qty": 5 * S, "paid": 300 * S, "why": "PRICE", "cleared": true}, "food still has its 300: 5 at 60, not nothing")
	check_eq(int(Market.seller_signal(w, f, "FOOD")["refused"]), 5 * S, "the 5 it could not afford tell the farm its price was refused (23a)")
	check_eq(w.ledger.balance("hh:pool"), 0, "it spent exactly what it set aside")
	var none := Market.order(w, _buyer(w, "z", 1000 * S), "FOOD", S, 70 * S, "NEED", 0)
	Market.clear(w)
	check_eq(Market.filled(w, none)["why"], "NO_MONEY", "a budget of 0 is no money")
	check_eq(Market.order(w, b, "FOOD", S, S, "NEED", -2), "", "a budget below -1 is refused")


func test_goods_for_a_building_site_never_go_into_a_companys_stock() -> void:
	var w := _w()
	var stores := Company.create(w, "SHOP", "LARGE", HW, "Stores", {"area": "landing"})
	Company.stock_add(w, stores, "MATERIAL", 100 * S, 37 * S, "LANDING", "x")
	Company.offer(w, stores, "MATERIAL", 37 * S)
	var client := Company.create(w, "FARM", "SMALL", HW, "F", {"area": "landing"})
	w.ledger.transfer(Ledger.EXTERNAL, CoreUtil.acct(client), 10000 * S, "TEST", 0)
	var oid := Market.order(w, {"kind": "SITE", "id": "contract:1", "acct": CoreUtil.acct(client), "area": "landing"}, "MATERIAL", 40 * S, 40 * S)
	Market.clear(w)
	check_eq(int(Market.filled(w, oid)["qty"]), 40 * S, "the site got 40")
	check_eq(int(Company.stock_of(w, client, "MATERIAL")["qty"]), 0, "the company paying holds none of it: the site books it")
	check_eq(int(Company.stock_of(w, stores, "MATERIAL")["qty"]), 60 * S, "out of the seller as SOLD")
	check_eq(w.ledger.balance(CoreUtil.acct(client)), 10000 * S - 40 * 37 * S, "paid from the client's account")


func test_bad_orders_are_refused() -> void:
	var w := _w()
	var b := _buyer(w, "a", 100 * S)
	check_eq(Market.order(w, b, "ENERGY", S, S), "", "not a grid good")
	check_eq(Market.order(w, b, "BW", S, S), "", "not building work")
	check_eq(Market.order(w, b, "FOOD", 0, S), "", "not nothing")
	check_eq(Market.order(w, {"kind": "ALIEN", "acct": "x"}, "FOOD", S, S), "", "not an unknown buyer")
	check_eq(Market.order(w, b, "FOOD", S, S, "MAYBE"), "", "not an unknown kind")

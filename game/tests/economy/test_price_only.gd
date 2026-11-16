extends TestCase
## Price rules read only what price explains (the user, 2026-11-16: "If something else than price stops sales it should
## not count on adjusting price"): EconMarket._fill tags why each part of an order was not filled (no goods / over limit
## / stopped by freight, road or the buyer's money) and what of each offer was left unsold at the price.

const S := EconUtil.S


func _world() -> WorldState:
	var sim := EconSim.make_econ_only(1)
	sim.run(3)
	return sim.world


func _two_orgs(w: WorldState) -> Array:
	var out := []
	for oid in EconUtil.sorted_keys(w.table("org")):
		var o: Dictionary = w.table("org")[oid]
		if o["type"] == "PRIVATE" and o["status"] == "ACTIVE" and not bool(o.get("is_contractor", false)):
			out.append(oid)
		if out.size() == 2:
			break
	return out


## One seller with `q` MATERIAL in `sd` at `ask`, one buyer in `bd` wanting `want` at `limit`, buyer cash `cash`.
func _market(w: WorldState, sd: String, q: int, ask: int, bd: String, want: int, limit: int, cash: int) -> Array:
	var two := _two_orgs(w)
	var seller: String = two[0]
	var buyer: String = two[1]
	var s := EconUtil.st(w)
	EconUtil.inv_add(w, seller, "MATERIAL", sd, q, ask)
	var bal := w.ledger.balance(EconUtil.acct(buyer))
	if bal > cash:
		w.ledger.transfer(EconUtil.acct(buyer), Ledger.EXTERNAL, bal - cash, "TEST", w.month)
	else:
		w.ledger.transfer(Ledger.EXTERNAL, EconUtil.acct(buyer), cash - bal, "TEST", w.month)
	s["offers"] = [{"seller": seller, "acct": EconUtil.acct(seller), "district": sd, "good": "MATERIAL", "qty": q, "ask": ask}]
	s["orders"] = [{"buyer": buyer, "acct": EconUtil.acct(buyer), "district": bd, "good": "MATERIAL", "qty": want, "limit": limit,
		"class": EconMarket.C_FIRM, "kind": "org"}]
	s["unsold_px_by"] = {}
	s["fill_last"] = {}  # a quiet market: no reserve release, no backstop (they would add offers of their own)
	s["mat_hot_m"] = 0
	s["mat_hot_m_on"] = false
	var gov_q := EconUtil.inv_get(w, "gov", "MATERIAL", "d:1")
	if gov_q > 0:
		EconUtil.inv_take(w, "gov", "MATERIAL", "d:1", gov_q)
	var imp_q := EconUtil.inv_get(w, EconTrade.IMPORTER, "MATERIAL", "d:1")
	if imp_q > 0:
		EconUtil.inv_take(w, EconTrade.IMPORTER, "MATERIAL", "d:1", imp_q)
	s["freight_used"] = 0
	s["freight_deferred"] = {}
	EconMarket._clear(w, "MATERIAL", int(EconUtil.lever(w, "ECON_FREIGHT_TARIFF", 5)) * S)
	return [s["market_stats"]["MATERIAL"], seller]


func test_no_goods_is_the_shortage() -> void:
	var w := _world()
	var r := _market(w, "d:1", 0, 300 * S, "d:1", 50 * S, 1000 * S, 1000000 * S)
	var m: Dictionary = r[0]
	check_eq(int(m["nogoods"]), 50 * S, "an able buyer found no goods: shortage")
	check_eq(int(m["stopped"]), 0, "nothing stopped it")


func test_freight_full_is_not_a_shortage_and_its_offer_not_unsold() -> void:
	var w := _world()
	EconUtil.st(w)["freight_cap"] = 0  # the trucks are full
	var r := _market(w, "d:1", 50 * S, 300 * S, "d:3", 50 * S, 1000 * S, 1000000 * S)
	var m: Dictionary = r[0]
	check_eq(int(m["stopped"]), 50 * S, "freight full: stopped")
	check_eq(int(m["nogoods"]), 0, "not a shortage")
	check_eq(int(m["unsold_px"]), 0, "the offer its buyer could not take is not unsold at the price")
	check_eq(int(EconUtil.st(w)["unsold_px_by"].get(String(r[1]) + "|MATERIAL", 0)), 0, "nor for the seller's stock cut")


func test_no_money_is_not_a_shortage() -> void:
	var w := _world()
	var r := _market(w, "d:1", 50 * S, 300 * S, "d:1", 50 * S, 1000 * S, 0)
	var m: Dictionary = r[0]
	check_eq(int(m["stopped"]), 50 * S, "the buyer had no money at fill time: stopped")
	check_eq(int(m["nogoods"]), 0, "not a shortage")
	check_eq(int(m["unsold_px"]), 0, "and the offer it wanted is not unsold at the price")


func test_over_the_limit_is_the_price_and_its_offer_is_unsold() -> void:
	var w := _world()
	var r := _market(w, "d:1", 50 * S, 900 * S, "d:1", 50 * S, 500 * S, 1000000 * S)
	var m: Dictionary = r[0]
	check_eq(int(m["overlimit"]), 50 * S, "the ask is over the buyer's limit")
	check_eq(int(m["nogoods"]), 0, "not a shortage of goods")
	check_eq(int(m["unsold_px"]), 50 * S, "the offer buyers would not take at its price is unsold stock")
	check_eq(int(EconUtil.st(w)["unsold_px_by"].get(String(r[1]) + "|MATERIAL", 0)), 50 * S, "for the seller too")

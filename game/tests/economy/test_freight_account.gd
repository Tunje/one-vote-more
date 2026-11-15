extends TestCase
## Freight on account (E148): a cross-district purchase uses the trucks and earns the transport operator its freight,
## whether the freight is paid in cash or invoiced.


func _two_firms(w: WorldState) -> Array:
	var out: Array = []
	for oid in EconUtil.sorted_keys(w.table("org")):
		var o: Dictionary = w.table("org")[oid]
		if o["type"] == "PRIVATE" and o["status"] == "ACTIVE" and not bool(o.get("is_contractor", false)):
			out.append(oid)
		if out.size() == 2:
			break
	return out


func _trade(on_account: bool) -> Dictionary:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	sim.run(2)
	w.meta["on"] = ["E148"] if on_account else []
	var f := _two_firms(w)
	var seller: String = f[0]
	var buyer: String = f[1]
	EconUtil.inv_add(w, seller, "MATERIAL", "d:2", 50 * EconUtil.S, 100 * EconUtil.S)
	w.ledger.transfer(Ledger.EXTERNAL, EconUtil.acct(buyer), 100000 * EconUtil.S, "TEST", w.month)
	var s := EconUtil.st(w)
	s["freight_cap"] = 100000 * EconUtil.S
	s["freight_used"] = 0
	var cta := EconFinance.org_by_key(w, "CTA")
	var rev0 := int(w.table("org")[cta]["pl"].get("rev", 0))
	var offer := {"seller": seller, "acct": EconUtil.acct(seller), "good": "MATERIAL", "district": "d:2", "qty": 50 * EconUtil.S, "ask": 200 * EconUtil.S}
	var bid := {"buyer": buyer, "acct": EconUtil.acct(buyer), "district": "d:1", "good": "MATERIAL", "qty": 10 * EconUtil.S,
		"limit": 1000 * EconUtil.S, "class": EconMarket.C_FIRM, "kind": "org"}
	var tariff := 5 * EconUtil.S
	EconMarket._fill(w, bid, 10 * EconUtil.S, [offer], tariff)
	var h := EconUtil.hops("d:2", "d:1")
	return {"used": int(s["freight_used"]), "rev": int(w.table("org")[cta]["pl"].get("rev", 0)) - rev0, "h": h,
		"expect_rev": EconUtil.val(10 * EconUtil.S, h * tariff), "ledger": w.ledger.total()}


func test_cash_and_account_count_alike() -> void:
	for acct in [false, true]:
		var r := _trade(acct)
		check(int(r["h"]) > 0, "a cross-district trade")
		check_eq(int(r["used"]), 10 * EconUtil.S * int(r["h"]), "%s: the trucks are used" % ("on account" if acct else "cash"))
		check_eq(int(r["rev"]), int(r["expect_rev"]), "%s: the transport operator earns the freight" % ("on account" if acct else "cash"))
		check_eq(int(r["ledger"]), 0, "ledger closed")

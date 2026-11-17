extends SceneTree
## Wilma (user 2026-11-14: "what is it we are missing? Something is all wrong here" -> money audit): where the colony's
## money sits, how fast it moves and how much bank lending creates, year by year. Full game on the default switches.
## Usage: godot --headless --path game --script res://tools/money_audit.gd -- <seed> <years> [every=5]
## Columns (millions of credits; milli internally):
##   holders: treasury, households, private firms, public enterprises, public institutions, unions/parties/papers, bank
##   money = all colony accounts except the bank's own and EXTERNAL; loans by borrower kind; bank limit and room
##   flows over the year (journal): wages, household spending, taxes, government spending, in/out of the colony
##   velocity = household spending / household money; G wage, CPI-ish food price, adults, unemployment
const M := 1000000000.0   # milli -> millions


func _kind(w: WorldState, acct: String) -> String:
	if acct == EconUtil.TREASURY:
		return "treasury"
	if acct == EconUtil.BANK:
		return "bank"
	if acct == "EXTERNAL":
		return "external"
	if acct.begins_with("hh:"):
		return "households"
	if acct.begins_with("union:") or acct.begins_with("party:") or acct.begins_with("media:"):
		return "civil"
	if acct.begins_with("co:"):
		var oid := acct.substr(3)
		var o: Dictionary = w.peek("org").get(oid, {})
		match String(o.get("type", "")):
			"PUBLIC_ENTERPRISE":
				return "pe"
			"PUBLIC_INSTITUTION":
				return "inst"
			_:
				return "firms"
	return "other"


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sd := int(a[0])
	var years := int(a[1])
	var every := int(a[2]) if a.size() > 2 else 5
	var sim: Simulation = EconSim.make(sd, "BALANCED", {}, true)
	var w := sim.world
	print("seed %d, switches: %s" % [sd, str(w.meta.get("on", []))])
	for y in years:
		sim.run(12)
		if (y + 1) % every != 0 and y != 0:
			continue
		var held := {}
		var neg := {}
		for acct in w.ledger.balances:
			var k := _kind(w, String(acct))
			var b := int(w.ledger.balances[acct])
			if b >= 0:
				held[k] = int(held.get(k, 0)) + b
			else:
				neg[k] = int(neg.get(k, 0)) + b
		var money := 0
		for k in held:
			if not (k in ["bank", "external"]):
				money += int(held[k])
		var loans := {}
		for lid in w.peek("loan"):
			var l: Dictionary = w.peek("loan")[lid]
			var bk := "gov" if String(l["borrower"]) == "gov" else _kind(w, EconUtil.acct(String(l["borrower"])))
			loans[bk] = int(loans.get(bk, 0)) + maxi(0, int(l["principal"]))
		var flows := {}
		var lo := w.month - 12
		for e in w.ledger.journal:
			if int(e["m"]) < lo:
				continue
			var fk := _kind(w, String(e["from"]))
			var tk := _kind(w, String(e["to"]))
			var amt := int(e["amt"])
			if fk == "households" and tk != "households":
				flows["hh_spend"] = int(flows.get("hh_spend", 0)) + amt
			if tk == "households" and fk != "households":
				flows["hh_income"] = int(flows.get("hh_income", 0)) + amt
			if tk == "treasury" and fk != "treasury":
				flows["gov_in"] = int(flows.get("gov_in", 0)) + amt
			if fk == "treasury" and tk != "treasury":
				flows["gov_out"] = int(flows.get("gov_out", 0)) + amt
			if fk == "external" and tk != "external":
				flows["colony_in"] = int(flows.get("colony_in", 0)) + amt
			if tk == "external" and fk != "external":
				flows["colony_out"] = int(flows.get("colony_out", 0)) + amt
			if tk == "bank" and fk != "bank":
				flows["to_bank"] = int(flows.get("to_bank", 0)) + amt
			if fk == "bank" and tk != "bank":
				flows["from_bank"] = int(flows.get("from_bank", 0)) + amt
		var s: Dictionary = EconUtil.peek_st(w)
		var hh := float(held.get("households", 0))
		var lab: Dictionary = EconQuery.labour(w)
		var lf := float(lab.get("labour_force", 1))
		var un := float(lab.get("unemployed", 0))
		print("Y%d money=%.0f | treasury=%.0f (%d%%) households=%.0f firms=%.0f pe=%.0f inst=%.0f civil=%.0f other=%.0f | bank_own=%.0f neg=%s" % [y + 1,
			money / M, held.get("treasury", 0) / M, int(100.0 * float(held.get("treasury", 0)) / maxf(1.0, float(money))), hh / M,
			held.get("firms", 0) / M, held.get("pe", 0) / M, held.get("inst", 0) / M, held.get("civil", 0) / M, held.get("other", 0) / M,
			held.get("bank", 0) / M, str(neg.keys())])
		print("    loans: gov=%.0f firms=%.0f pe=%.0f other=%.0f | bank on=%s limit=%.0f room=%.0f util=%d‰ failed=%s" % [loans.get("gov", 0) / M,
			loans.get("firms", 0) / M, loans.get("pe", 0) / M, (loans.get("households", 0) + loans.get("inst", 0) + loans.get("other", 0)) / M,
			str(EconBank.active(w)), EconBank.limit(w) / M, EconBank.room(w) / M, EconBank.utilisation_pm(w), str(s.get("bank_failed", false))])
		print("    year flows: hh_income=%.0f hh_spend=%.0f velocity=%.2f gov_in=%.0f gov_out=%.0f colony_in=%.0f colony_out=%.0f to_bank=%.0f from_bank=%.0f" % [
			flows.get("hh_income", 0) / M, flows.get("hh_spend", 0) / M, float(flows.get("hh_spend", 0)) / maxf(1.0, hh),
			flows.get("gov_in", 0) / M, flows.get("gov_out", 0) / M, flows.get("colony_in", 0) / M, flows.get("colony_out", 0) / M,
			flows.get("to_bank", 0) / M, flows.get("from_bank", 0) / M])
		print("    wageG=%d food_price=%d adults=%d unemp=%.1f%%" % [int(s["wage"]["G"]) / 1000, int(s["prices"]["FOOD"]) / 1000,
			int(lab.get("labour_force", 0)), 100.0 * un / maxf(1.0, lf)])
	quit()

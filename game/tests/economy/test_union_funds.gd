extends TestCase
## E133: a union fund above FUND_CAP_WEEKS of strike pay charges maintenance dues only and rebates the excess to its
## members' households, so dues do not take money out of circulation for good.


func test_full_fund_rebates_and_cuts_dues() -> void:
	var sim := EconSim.make_econ_only(5)
	sim.run(16)
	var w := sim.world
	var u: Dictionary = {}
	for x in Unions.active(w):
		if not x["federation"] and int(x["members"]) > 0:
			u = x
			break
	check(not u.is_empty(), "an active union with members exists")
	if u.is_empty():
		return
	var cap := int(Unions.FUND_CAP_WEEKS / 4.33 * float(u["members"]) / EconUtil.S * float(Unions.strike_pay(w)))
	var windfall := cap * 3 + 1000000
	w.ledger.transfer("EXTERNAL", String(u["acct"]), windfall, "TEST_WINDFALL", w.month)
	var hh_before := 0
	for gid in w.table("hh"):
		hh_before += w.ledger.balance(EconUtil.hh_acct(gid))
	var full_due := int(float(EconUtil.st(w)["wage"]["G"]) * Unions.DUES_SHARE)
	sim.run(1)
	check(int(u["dues_pm"]) < full_due, "maintenance dues while the fund is full (%d < %d)" % [int(u["dues_pm"]), full_due])
	var cap_now := int(Unions.FUND_CAP_WEEKS / 4.33 * float(u["members"]) / EconUtil.S * float(Unions.strike_pay(w)))
	check(Unions.fund(w, u["id"]) <= cap_now + EconUtil.S * 10, "the excess went back (fund %d, cap %d)" % [Unions.fund(w, u["id"]) / 1000, cap_now / 1000])
	check(Unions.strike_weeks(w, u["id"]) >= 8.0, "the union keeps a full strike chest (%.1f weeks)" % Unions.strike_weeks(w, u["id"]))
	check_eq(w.ledger.total(), 0, "ledger closed")

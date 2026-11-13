extends TestCase
## Repeat offenders: a prior conviction for the same kind of offence within 5 years doubles the fine; a SERIOUS
## repeat suspends licences, a SEVERE repeat suspends them twice as long.

const F := preload("res://tests/support/staff_fixture.gd")
const LawOps := preload("res://sim/law/law_ops.gd")
const JO := preload("res://sim/law/justice_ops.gd")
const Det := preload("res://sim/staff/det.gd")


func _world() -> WorldState:
	var w := F.bare_world()
	LawOps.init_world(w)
	w.month = 100
	w.table("org")["org:1"] = {"id": "org:1", "pl_last": {"rev": 10000000}}   # revenue: fines scale with it (v8)
	w.table("licence")["lic:1"] = {"id": "lic:1", "holder_id": "org:1", "status": "ACTIVE"}
	for id in ["v:1", "v:2", "v:3"]:
		w.table("violation_track")[id] = {"company": "org:1", "kind": "SAFETY_CORNERS"}
	w.table("violation_track")["v:x"] = {"company": "org:1", "kind": "DUMPING"}
	return w


func test_second_conviction_of_same_kind_is_doubled() -> void:
	var w := _world()
	var first := JO._fine(w, "org:1", "SERIOUS", "v:1")
	check_eq(String(w.peek("licence")["lic:1"]["status"]), "ACTIVE", "a first SERIOUS conviction suspends nothing")
	w.month += 12
	check(JO.repeat_offender(w, "org:1", "v:2"), "same kind within 5 years")
	check(not JO.repeat_offender(w, "org:1", "v:x"), "another kind is not a repeat")
	var second := JO._fine(w, "org:1", "SERIOUS", "v:2")
	check_eq(second, 2 * first, "doubled")
	check_eq(String(w.peek("licence")["lic:1"]["status"]), "SUSPENDED", "a SERIOUS repeat suspends licences")
	check_eq(int(w.peek("licence")["lic:1"]["suspended_until"]), w.month + JO.SUSPEND_MONTHS, "for the normal term")


func test_old_convictions_lapse_and_severe_repeats_suspend_longer() -> void:
	var w := _world()
	JO._fine(w, "org:1", "SEVERE", "v:1")
	w.month += JO.REPEAT_WINDOW + 1
	check(not JO.repeat_offender(w, "org:1", "v:2"), "older than 5 years: lapsed")
	JO._fine(w, "org:1", "SEVERE", "v:2")
	w.table("licence")["lic:1"]["status"] = "ACTIVE"
	w.month += 6
	JO._fine(w, "org:1", "SEVERE", "v:3")
	check_eq(int(w.peek("licence")["lic:1"]["suspended_until"]), w.month + 2 * JO.SUSPEND_MONTHS, "SEVERE repeat: twice as long")


func _private_orgs(w: WorldState) -> Array:
	var out: Array = []
	for oid in Det.ordered(w.table("org")):
		var o: Dictionary = w.table("org")[oid]
		if not (o["type"] in EconData.PUBLIC_TYPES) and String(o["status"]) == "ACTIVE":
			out.append(oid)
	return out


## v8: the third conviction within 5 years revokes the licences and the court winds the firm up.
func test_third_conviction_winds_the_firm_up() -> void:
	var w := EconSim.make(3, "BALANCED", {}, true).world
	var orgs := _private_orgs(w)
	check(orgs.size() >= 2, "private firms to test with")
	if orgs.size() < 2:
		return
	var a := String(orgs[0])
	JO._repeat_ladder(w, a)
	w.month += 10
	JO._repeat_ladder(w, a)
	check(String(w.table("org")[a]["status"]) != "LIQUIDATION", "two convictions: still trading")
	w.month += 10
	JO._repeat_ladder(w, a)
	check_eq(String(w.table("org")[a]["status"]), "LIQUIDATION", "the third: wound up")
	check_eq(w.facts.query("LAW_LICENCE_REVOKED", 0, w.month).size(), 1, "licences revoked")
	var b := String(orgs[1])
	w.levers["LAW_REVOKE_AFTER_CONVICTIONS"] = 0
	for i in 5:
		JO._repeat_ladder(w, b)
	check(String(w.table("org")[b]["status"]) != "LIQUIDATION", "0 = never")


## v8: a fine more than a year past due brings a creditor petition and a court liquidation.
func test_unpaid_fines_bring_a_petition() -> void:
	var w := EconSim.make(3, "BALANCED", {}, true).world
	var orgs := _private_orgs(w)
	if orgs.is_empty():
		check(false, "no private firm")
		return
	var a := String(orgs[0])
	var lid := w.new_id("liability")
	w.table("liability")[lid] = {"id": lid, "debtor": a, "creditor": "gov", "amount": 5000, "due_month": w.month - 6,
		"kind": "FINE", "status": "OPEN"}
	JO._petitions(w)
	check(String(w.table("org")[a]["status"]) != "LIQUIDATION", "6 months late: not yet")
	w.month += 7
	JO._petitions(w)
	check_eq(String(w.table("org")[a]["status"]), "LIQUIDATION", "13 months late: wound up")
	check_eq(w.facts.query("LAW_LIQUIDATION_PETITION", 0, w.month).size(), 1, "the petition is news")


## v8: fines scale with the firm (share of revenue, small floor, capped), and small firms pay unpaid fines in instalments.
func test_fines_scale_with_the_firm_and_small_firms_get_a_plan() -> void:
	var w := _world()
	w.values["ECON_W_REF"] = 1000000
	w.table("org")["org:big"] = {"id": "org:big", "pl_last": {"rev": 100000000}}   # 1,200 W_ref a year
	w.table("org")["org:small"] = {"id": "org:small", "pl_last": {"rev": 5000000}}  # 60 W_ref a year
	w.table("violation_track")["v:b"] = {"company": "org:big", "kind": "SAFETY_CORNERS"}
	w.table("violation_track")["v:s"] = {"company": "org:small", "kind": "SAFETY_CORNERS"}
	var big := JO._fine(w, "org:big", "SERIOUS", "v:b")
	var small := JO._fine(w, "org:small", "SERIOUS", "v:s")
	check_eq(big, 48000000, "4% of a big firm's revenue")
	check_eq(small, 2400000, "4% of a bakery's revenue, above the 2 W_ref floor")
	check(small * 10 < big, "the bakery is not fined like the mine")
	var rows: Array = []
	for li in w.peek("liability").values():
		if String(li["debtor"]) == "org:small":
			rows.append(li)
	check_eq(rows.size(), JO.PLAN_PARTS, "an unpaid fine: %d instalments" % JO.PLAN_PARTS)
	var tot := 0
	var last := 0
	for li in rows:
		tot += int(li["amount"])
		last = maxi(last, int(li["due_month"]))
	check_eq(tot, small, "the whole fine, rescheduled not forgiven")
	check(last >= w.month + JO.PLAN_MONTHS - 3, "spread over two years")
	var big_rows := 0
	for li in w.peek("liability").values():
		if String(li["debtor"]) == "org:big":
			big_rows += 1
	check_eq(big_rows, 1, "a big firm owes it next month")
	w.table("org")["org:zero"] = {"id": "org:zero", "pl_last": {"rev": 0}}
	w.table("violation_track")["v:z"] = {"company": "org:zero", "kind": "SAFETY_CORNERS"}
	check_eq(JO._fine(w, "org:zero", "SEVERE", "v:z"), 5000000, "no revenue: the small floor only")

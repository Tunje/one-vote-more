extends TestCase
## The court collects what is owed (Wilma, 2026-11-17) and the pay owed after a layoff (the user, rebuild-company.md
## 9.2). Anni's; reviewed by Ella.

const F := preload("res://tests/support/staff_fixture.gd")
const LawOps := preload("res://sim/law/law_ops.gd")
const J := preload("res://sim/law/justice_ops.gd")
const WK := preload("res://sim/law/work_law.gd")
const Households := preload("res://sim/population/households.gd")

const S := 1000
const CO := "company:1"
const ACCT := "co:company:1"
const POOL := "pool:p1"


func _world() -> WorldState:
	var w := F.bare_world()
	LawOps.init_world(w)
	J.init_courts(w)
	F.company(w, CO)
	for a in [ACCT, POOL, CoreUtil.TREASURY, CoreUtil.FINES]:
		w.ledger.open_account(a)
	w.month = 10
	return w


func _fund(w: WorldState, acct: String, amount: int) -> void:
	w.ledger.transfer(Ledger.EXTERNAL, acct, amount, "TEST", w.month)


## A liability row as _owe writes it, due in `due`.
func _debt(w: WorldState, kind: String, amount: int, due: int, creditor: String = "gov", creditor_acct: String = "") -> String:
	var lid := w.new_id("liability")
	var row := {"id": lid, "debtor": CO, "creditor": creditor, "amount": amount, "due_month": due, "kind": kind,
		"status": "OPEN", "plan": false}
	if creditor_acct != "":
		row["creditor_acct"] = creditor_acct
	w.table("liability")[lid] = row
	return lid


func test_the_layoff_pay_lever() -> void:
	var w := _world()
	var d: Dictionary = w.lever_defs["LAW_LAYOFF_PAY_MONTHS"]
	check(String(d["type"]) == "NUMBER" and bool(d["legislative"]), "a law the government can change")
	check_eq(d["range"], [0, 12], "a sensible range")
	check_eq(WK.layoff_pay_months(w), 3, "three months to start")
	check(float(d["ideology"]["LABOR"]) > 0.0 and int(d["concerns"]["JOBS"]) < 0, "pro-worker; dearer hiring")
	w.levers["LAW_LAYOFF_PAY_MONTHS"] = 6
	check_eq(WK.layoff_pay_months(w), 6, "as the law stands on the day")
	w.levers["LAW_LAYOFF_PAY_MONTHS"] = 40
	check_eq(WK.layoff_pay_months(w), 12, "held to its range")


func test_debts_are_paid_oldest_first_as_the_balance_allows() -> void:
	var w := _world()
	var old := _debt(w, "FINE", 300 * S, 4)
	var rent := _debt(w, "LAND_RENT", 500 * S, 7, "gov", CoreUtil.TREASURY)
	var later := _debt(w, "LAYOFF_PAY", 200 * S, 11, POOL, POOL)
	_fund(w, ACCT, 600 * S)
	J.collect_debts(w)
	var t := w.peek("liability")
	check_eq(String(t[old]["status"]), "PAID", "the oldest is paid in full")
	check_eq(int(t[old]["paid"]), 300 * S, "and says what was paid")
	check_eq(w.ledger.balance(CoreUtil.FINES), 300 * S, "a fine goes to the fines account")
	check_eq(int(t[rent]["amount"]), 200 * S, "the next is paid in part: the amount is lowered")
	check_eq(String(t[rent]["status"]), "OPEN", "and stays open")
	check_eq(w.ledger.balance(CoreUtil.TREASURY), 300 * S, "into its creditor's account")
	check_eq(int(t[later]["amount"]), 200 * S, "a debt not yet due waits")
	check_eq(w.ledger.balance(ACCT), 0, "the balance is spent, never below 0")
	var memos: Array = []
	for e in w.ledger.journal:
		memos.append(String(e["memo"]))
	check(memos.has("DEBT:FINE") and memos.has("DEBT:LAND_RENT"), "the memo names the kind (%s)" % [memos])
	var rows := Logbook.rows(w, {"kind": "LAW", "what": "debt paid", "who": CO})
	check_eq(rows.size(), 2, "a row for each payment")
	check_eq(J.paid_this_month(w, CO), 600 * S, "what it paid on its debts this month, for its books")
	check_eq(J.paid_this_month(w, "company:2"), 0, "another paid nothing")
	w.month += 1
	check_eq(J.paid_this_month(w, CO), 0, "a new month starts at 0")


func test_layoff_pay_reaches_the_pool_and_can_end_the_company() -> void:
	var w := _world()
	J.owe(w, CO, POOL, POOL, 90 * S, "LAYOFF_PAY", "plant:1")
	var ids: Array = w.peek("liability").keys()
	check(ids.size() >= 1 and String(w.peek("liability")[ids[0]].get("ref", "")) == "plant:1", "the debt keeps its ref")
	w.month += 30
	_fund(w, ACCT, 30 * S)
	J.collect_debts(w)
	check_eq(w.ledger.balance(POOL), 30 * S, "what the company had went to the pool")
	var open := 0
	for li in w.peek("liability").values():
		if String(li["status"]) == "OPEN":
			open += int(li["amount"])
	check_eq(open, 60 * S, "the rest is still owed")
	w.month += J.PETITION_MONTHS
	J._petitions(w)
	check(Logbook.rows(w, {"what": "petition", "who": CO}).size() >= 1, "unpaid layoff pay: the pool petitions")
	var refused := Logbook.rows(w, {"what": "wind up refused", "who": CO})
	check(refused.size() >= 1, "(the doorway refuses endings before step 5)")
	check_eq(String(refused[0]["why"]["reason"]), "UNPAID_LAYOFF_PAY", "logged under the debt's own kind, not as fines")
	check_eq([J.unpaid_reason("FINE"), J.unpaid_reason("UNPAID_WAGES"), J.unpaid_reason("COMPENSATION")],
		["UNPAID_FINE", "UNPAID_WAGES", "UNPAID_COMPENSATION"], "each kind names itself")


func test_a_debt_without_an_account_waits() -> void:
	var w := _world()
	var lid := _debt(w, "LAND_RENT", 50 * S, 5, "gov", "acct:none")
	_fund(w, ACCT, 100 * S)
	J.collect_debts(w)
	check_eq(int(w.peek("liability")[lid]["amount"]), 50 * S, "no creditor account: nothing moves")
	check_eq(w.ledger.balance(ACCT), 100 * S, "the debtor keeps its money")
	w.table("liability")[lid]["debtor"] = "person:9"
	w.table("liability")[lid]["creditor_acct"] = CoreUtil.TREASURY
	J.collect_debts(w)
	check_eq(String(w.peek("liability")[lid]["status"]), "OPEN", "no debtor account: it waits")


func test_collected_layoff_pay_is_booked_in_the_pool() -> void:
	var w := _world()
	w.table("pool")[POOL] = {}
	var lid := _debt(w, "LAYOFF_PAY", 80 * S, 9, POOL, POOL)
	_debt(w, "FINE", 10 * S, 3)
	_fund(w, ACCT, 50 * S)
	J.collect_debts(w)
	check_eq(int(w.peek("liability")[lid]["paid"]), 40 * S, "the fine first, then what is left")
	check_eq(int(Households.income(w, POOL).get("layoff_pay", 0)), 40 * S, "booked as layoff pay in the month it arrives (Maja)")


func test_carried_debts_stay_open_and_are_not_collected() -> void:
	var w := _world()
	var who := "founder:7"
	w.ledger.open_account(who)
	var a := _debt(w, "GRANT", 60 * S, 5)
	var b := _debt(w, "FINE", 15 * S, 6)
	var other := _debt(w, "FINE", 5 * S, 6)
	for lid in [a, b]:
		w.table("liability")[lid]["debtor"] = who
	var gone := _debt(w, "FINE", 9 * S, 2)
	w.table("liability")[gone]["debtor"] = who
	w.table("liability")[gone]["status"] = "PAID"
	check_eq(J.carry_debts(w, who, POOL), 75 * S, "the total still owed")
	var t := w.peek("liability")
	for lid in [a, b]:
		check(bool(t[lid]["carried"]) and String(t[lid]["carried_to"]) == POOL, "marked carried, to the pool")
		check_eq(String(t[lid]["status"]), "OPEN", "still owed, for step 5's court")
	check(not t[other].has("carried") and not t[gone].has("carried"), "another's debt and a paid one are left alone")
	check_eq(Logbook.rows(w, {"kind": "LAW", "what": "debts carried", "who": who}).size(), 1, "one row with the total")
	_fund(w, who, 100 * S)
	J.collect_debts(w)
	check_eq(int(t[a]["amount"]), 60 * S, "a carried debt is not collected")
	check_eq(w.ledger.balance(who), 100 * S, "even when there is money")
	check_eq(J.carry_debts(w, who, POOL), 75 * S, "asked again: the same total")
	check_eq(Logbook.rows(w, {"kind": "LAW", "what": "debts carried", "who": who}).size(), 1, "and no new row")
	check_eq(J.carry_debts(w, "founder:8", POOL), 0, "nothing open: 0")


func test_a_small_firms_layoff_pay_is_owed_whole_like_unpaid_wages() -> void:
	# the user, rebuild-company.md 9.2: unpaid layoff pay is "a debt like unpaid wages"; unpaid wages are owed whole
	var w := _world()
	check(J.annual_rev(w, CO) < J.SMALL_FIRM_REV_WREF * float(J.w_ref(w)), "a small firm (no revenue yet)")
	J.owe(w, CO, POOL, POOL, 90 * S, "LAYOFF_PAY")
	J.owe(w, CO, POOL, POOL, 40 * S, "UNPAID_WAGES")
	J.owe(w, CO, "gov", CoreUtil.TREASURY, 80 * S, "LAND_RENT")
	var rows := {}
	for li in w.peek("liability").values():
		var k := String(li["kind"])
		if not rows.has(k):
			rows[k] = []
		rows[k].append([int(li["amount"]), int(li["due_month"]), bool(li["plan"])])
	check_eq(rows["LAYOFF_PAY"], [[90 * S, w.month + 1, false]], "layoff pay: one row, whole, due next month")
	check_eq(rows["UNPAID_WAGES"], [[40 * S, w.month + 1, false]], "as unpaid wages")
	check_eq((rows["LAND_RENT"] as Array).size(), J.PLAN_PARTS, "the other kinds keep the small-firm instalments")


func test_a_debt_long_overdue_files_one_petition_not_one_a_month() -> void:
	# Wilma, 2026-11-18: one petition per company until the court answers; the run had filed one a month
	var w := _world()
	_debt(w, "UNPAID_WAGES", 50 * S, 1, POOL, POOL)
	_debt(w, "LAYOFF_PAY", 70 * S, 2, POOL, POOL)
	w.month = 1 + J.PETITION_MONTHS
	for m in 10:
		J._petitions(w)
		w.month += 1
	check_eq(Logbook.rows(w, {"what": "petition", "who": CO}).size(), 1, "one petition over ten months, for two overdue debts")
	check_eq(Logbook.rows(w, {"what": "wind up refused", "who": CO}).size(), 1, "and the refusal logged once")
	var p: Dictionary = w.peek("law_state")["s"]["justice"]["petitioned"][CO]
	check_eq([int(p["month"]), String(p["kind"])], [1 + J.PETITION_MONTHS, "UNPAID_WAGES"], "the petition is kept: when, for what")

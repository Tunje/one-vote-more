class_name EconPlanRescue
extends RefCounted
## E166 part 1: rescues of plans in trouble (user via Wilma 2026-11-15: "if a company in the planning stage is about to
## die it should be able to sell shares of itself to save it, or if it's a company necessary for the colony the
## government could give a bailout, and banks give extensions for first payments or buy part of the company"). Design
## Bob (agreed by Wilma), built by Otto from Bob's draft on Anni's share register (EconShares); planning/
## design-e166-e169.md. OPT-IN "E166", on top of E165 (plans). Young opened firms (part 2) are a separate, later flag.
## Second version (Wilma 2026-11-15, after the A/Bs in planning/ab-r8-builders.md §5: the first version's paper-gap
## trigger and 4-month withdrawal cost 188 adults, and its rescued plans almost all died):
##
## In trouble: a plan whose build has started and that has MISSED a payment (a gap on paper is not trouble). Shortfall
## = what is left to pay − cash − undrawn plan credit (at least 1 credit while a payment is missed). The rescue need is
## the shortfall plus WC_M months of the plan's forecast running costs (the opening buffer). (A plan without a builder
## isn't rescued: money doesn't make a builder appear.) One window per plan, RESCUE_M months, in this order, each the
## other side's choice, judged from what it can see that month: the founders' forecast EconForecast.first_year (never
## the plan's true future, so a rescue may still fail):
##   1. SHARES: buyers pledge until the whole need is covered, else no money moves. Buyers: profitable firms with free
##      cash beyond BUYER_CASH_M months of their costs (same output good first), then I3–I5 households risking up to a
##      third of their savings. Stake = need ÷ (value built + cash + need), outside holders ≤ 490‰ (EconShares). Each
##      buyer wants its share of the forecast profit to be ≥ HURDLE_PM ‰ a year of what it pays.
##   2. THE BANK (from the 2nd month): interest-only first payments for EXT_M months after opening; a debt-for-equity
##      swap of up to SWAP_PCT of the loan into a bank stake (≤ 300‰); a top-up loan of the need if its room and capital
##      floor allow and the forecast profit repays all the plan's debt within DEBT_YEARS.
##   3. THE GOVERNMENT (not routed yet: a decision type for the delegation desk later; only for a plant the colony
##      needs, after shares and the bank were tried): ECON_RESCUE_PLAN {org, form GRANT | LOAN | STAKE, amount
##      (credits)}; public fact ECON_PLAN_BAILOUT.
## No rescue in the window: the plan is NOT withdrawn; it waits under E165's own rules (stalled, limit), which may still
## end it (with E169 the half-built work then stays on the market).
## Pure query for the chooser: in_trouble(world).

const S := EconUtil.S
const RESCUE_M := 4
const EXT_M := 12
const SWAP_PCT := 30
const BUYER_CASH_M := 6
const WC_M := 3  # the rescue also pays this many months of the forecast's running costs (the opening buffer)
const HURDLE_PM := 100  # a stake buyer wants its share of the forecast profit to be ≥ 10% a year of what it pays
const DEBT_YEARS := 5  # the bank lends only if the forecast profit repays all the plan's debt within this many years
const GOV_RATE_PPM := 4000  # 0.4% a month
const GOV_TERM_M := 120
const STRATEGIC := ["FARM", "FAMFARM", "WATERWORKS", "POWER", "MINE", "PROCESSING", "COMPONENTS", "CLINIC", "DEPOT", "MEDWORKS", "BAKERY", "FAMBAKERY"]


static func active(world: WorldState) -> bool:
	return EconInsolvency.planning_stage(world) and (world.meta.get("on", []) as Array).has("E166") and not EconUtil.off(world, "E166")


static func _count(world: WorldState, key: String, n: int = 1) -> void:
	var s := EconUtil.st(world)
	var r: Dictionary = s.get("rescue_stats", {})
	r[key] = int(r.get(key, 0)) + n
	s["rescue_stats"] = r


# ------------------------------------------------------------------ reads

static func plant_type(world: WorldState, oid: String) -> String:
	var o: Dictionary = world.peek("org").get(oid, {})
	if o.has("entry_type"):
		return String(o["entry_type"])
	for pid in EconUtil.sorted_keys(world.peek("project")):
		var p: Dictionary = world.peek("project")[pid]
		if p["owner"] == oid and p["status"] == "ACTIVE":
			return String(p["type"])
	return ""


static func _value(world: WorldState, oid: String) -> int:
	var v := maxi(0, world.ledger.balance(EconUtil.acct(oid)))
	for pid in world.peek("project"):
		var p: Dictionary = world.peek("project")[pid]
		if p["owner"] == oid and p["status"] == "ACTIVE":
			v += int(p["paid"])
	return maxi(v, S)


## 0 unless a started build has a missed payment; then what is missing (at least S).
static func shortfall(world: WorldState, oid: String) -> int:
	var o: Dictionary = world.peek("org").get(oid, {})
	if o.is_empty() or o["status"] != "FORMING":
		return 0
	var left := 0
	var missed := false
	for pid in EconUtil.sorted_keys(world.peek("project")):
		var p: Dictionary = world.peek("project")[pid]
		if p["owner"] == oid and p["status"] == "ACTIVE" and int(p["start_month"]) <= world.month:
			left += int(p["price"]) - int(p["paid"])
			missed = missed or int(p.get("unpaid_m", 0)) >= 1
	if not missed:
		return 0
	return maxi(S, left - world.ledger.balance(EconUtil.acct(oid)) - int(o.get("plan_credit", 0)))


## The founders' forecast for the plan's plant, as anyone can make it this month.
static func forecast(world: WorldState, oid: String) -> Dictionary:
	var ft := plant_type(world, oid)
	if ft == "":
		return {}
	return EconForecast.first_year(world, ft, String(world.peek("org")[oid]["hq"]))


## The rescue need: the shortfall plus WC_M months of the forecast's running costs.
static func need_of(shortfall_v: int, f: Dictionary) -> int:
	if shortfall_v <= 0:
		return 0
	return shortfall_v + WC_M * maxi(0, int(f.get("costs", 0))) / 12


## The colony needs this plant: a strategic type, or its good is short (the essentials history, E157 margin).
static func needed(world: WorldState, ftype: String) -> bool:
	if ftype in STRATEGIC:
		return true
	var r: Dictionary = EconData.RECIPES.get(ftype, {})
	if r.is_empty():
		return false
	var a: Array = EconUtil.peek_st(world).get("ess_hist", {}).get(String(r["out"][0]), [])
	return not a.is_empty() and int(a[a.size() - 1]) < 10


## Pure read for the government's chooser.
static func in_trouble(world: WorldState) -> Array:
	var out: Array = []
	for oid in EconUtil.sorted_keys(world.peek("org")):
		var o: Dictionary = world.peek("org")[oid]
		if not o.has("rescue"):
			continue
		var rs: Dictionary = o["rescue"]
		var ft := plant_type(world, oid)
		out.append({"org": oid, "type": ft, "district": o["hq"], "shortfall": int(rs["shortfall"]) / S, "needed": needed(world, ft),
			"months_left": int(rs["since"]) + RESCUE_M - world.month, "offers_tried": (rs.get("tried", []) as Array).duplicate(),
			"outside_pm": EconShares.outside_pm(o)})
	return out


# ------------------------------------------------------------------ the monthly round (start of the insolvency check)

static func monthly(world: WorldState) -> void:
	if not active(world):
		return
	_gov_loans(world)
	for oid in EconUtil.sorted_keys(world.table("org")):
		var o: Dictionary = world.table("org")[oid]
		if o["type"] != "PRIVATE" or o["status"] != "FORMING" or bool(o.get("is_contractor", false)):
			if o.has("rescue") and o["status"] != "FORMING":
				o.erase("rescue")
			continue
		if o.has("rescue"):
			_step(world, oid, o)
		elif o.has("rescue_done"):
			continue  # one window per plan
		elif shortfall(world, oid) > 0:
			o["rescue"] = {"since": world.month, "shortfall": shortfall(world, oid), "tried": []}
			_count(world, "windows")
			_step(world, oid, o)


static func _step(world: WorldState, oid: String, o: Dictionary) -> void:
	var rs: Dictionary = o["rescue"]
	rs["shortfall"] = shortfall(world, oid)
	if int(rs["shortfall"]) <= 0:
		_saved(world, o, String(rs.get("kind", "self")))
		return
	var age := world.month - int(rs["since"])
	var f := forecast(world, oid)
	if _sell_stake(world, oid, o, plant_type(world, oid), f):
		return
	if not ("shares" in rs["tried"]):
		(rs["tried"] as Array).append("shares")
	if age >= 1:
		if _bank(world, oid, o, f):
			return
		if not ("bank" in rs["tried"]):
			(rs["tried"] as Array).append("bank")
	if age >= RESCUE_M:
		# nobody rescued it: the plan is not withdrawn, it waits under E165's own rules (stalled, limit)
		o.erase("rescue")
		o["rescue_done"] = true
		_count(world, "failed")


static func _saved(world: WorldState, o: Dictionary, kind: String) -> void:
	o.erase("rescue")
	o["rescue_done"] = true
	if kind != "self":
		o["rescued"] = {"kind": kind, "month": world.month}
		_count(world, "saved_" + kind)
	else:
		_count(world, "saved_self")


# ------------------------------------------------------------------ 1. shares

## Buyers pledge until the whole need is covered; only then does money move. Every buyer's return is the same:
## (its ‰ × forecast profit) ÷ what it pays = profit ÷ (value + need), tested against HURDLE_PM. `f` is the forecast.
static func _sell_stake(world: WorldState, oid: String, o: Dictionary, ft: String, f: Dictionary) -> bool:
	var rs: Dictionary = o["rescue"]
	var room_pm := EconShares.OUTSIDE_MAX_PM - EconShares.outside_pm(o)
	var need := need_of(int(rs["shortfall"]), f)
	if room_pm <= 0 or need <= 0:
		return false
	if f.is_empty() or int(f.get("profit", 0)) <= 0:
		_count(world, "shares_no_profit")
		return false
	var v := _value(world, oid)
	var pm := int(float(need) * 1000.0 / float(v + need))
	if pm > room_pm:
		_count(world, "shares_too_big")
		return false
	if int(f["profit"]) * 1000 / maxi(1, v + need) < HURDLE_PM:
		_count(world, "shares_hurdle")
		return false
	var good := String(EconData.RECIPES.get(ft, {"out": [""]})["out"][0])
	var cands: Array = []  # [rank, -spare, holder key, most it gives]
	for bid in EconUtil.sorted_keys(world.table("org")):
		if bid == oid:
			continue
		var b: Dictionary = world.table("org")[bid]
		if b["type"] != "PRIVATE" or b["status"] != "ACTIVE" or bool(b.get("is_contractor", false)) or EconPublicCo.result12(b) <= 0:
			continue
		var spare := world.ledger.balance(EconUtil.acct(bid)) - BUYER_CASH_M * maxi(1, EconFinance._monthly_costs(b))
		if spare <= 0:
			continue
		var bt := plant_type(world, bid)
		var rank := 0 if good != "" and bt != "" and String(EconData.RECIPES.get(bt, {"out": [""]})["out"][0]) == good else 1
		cands.append([rank, -spare, "co:" + bid, spare])
	for gid in EconUtil.sorted_keys(world.table("hh")):
		if not (String(world.table("hh")[gid].get("band", "")) in ["I3", "I4", "I5"]):
			continue
		var sav := world.ledger.balance(EconUtil.hh_acct(gid)) / 3  # a household risks up to a third of its savings
		if sav > 0:
			cands.append([2, -sav, "hh:" + gid, sav])
	cands.sort_custom(_cand_before)
	var pledges: Array = []
	var got := 0
	for c in cands:
		if got >= need:
			break
		var give := mini(int(c[3]), need - got)
		pledges.append([String(c[2]), give])
		got += give
	if got < need:
		_count(world, "shares_no_buyers")
		return false
	var kind := "shares_hh" if String(pledges[0][0]).begins_with("hh:") else "shares_firm"
	var left_pm := pm
	for i in pledges.size():
		var h: String = pledges[i][0]
		var amt: int = pledges[i][1]
		var hp: int = left_pm if i == pledges.size() - 1 else pm * amt / need
		left_pm -= hp
		var src := EconUtil.acct(h.substr(3)) if h.begins_with("co:") else EconUtil.hh_acct(h.substr(3))
		world.ledger.transfer(src, EconUtil.acct(oid), amt, "EQUITY_STAKE", world.month)
		EconShares.add_stake(o, h, hp)
		EconFacts.emit(world, "COMP_STAKE_SOLD", o["hq"], [["COMPANY", oid]], [["COMPANY", oid, 1.0]], {}, 15, "PUBLIC",
			{"org": oid, "buyer": h, "permille": hp, "amount": amt / S, "rescue": true})
	_count(world, kind)
	_count(world, "shares_amount", need)
	_count(world, "shares_buyers", pledges.size())
	rs["kind"] = kind
	_saved(world, o, kind)
	return true


## Buyer order: same output good first, then other firms, then households; within a rank the most spare cash first.
static func _cand_before(x: Array, y: Array) -> bool:
	if int(x[0]) != int(y[0]):
		return int(x[0]) < int(y[0])
	if int(x[1]) != int(y[1]):
		return int(x[1]) < int(y[1])
	return String(x[2]) < String(y[2])


# ------------------------------------------------------------------ 2. the bank

static func _bank(world: WorldState, oid: String, o: Dictionary, f: Dictionary) -> bool:
	var rs: Dictionary = o["rescue"]
	var ext := false
	for lid in EconUtil.sorted_keys(world.table("loan")):
		var l: Dictionary = world.table("loan")[lid]
		if l["borrower"] == oid and int(l["principal"]) > 0 and not bool(l.get("revolving", false)) and not bool(l.get("ext_given", false)):
			l["grace_after_open"] = EXT_M  # interest-only from the opening (EconInsolvency._open_plan)
			l["ext_given"] = true
			ext = true
	if ext:
		_count(world, "extensions")
	var need := need_of(int(rs["shortfall"]), f)
	if need <= 0:
		return false
	# the forecast profit must repay all the plan's debt (with the top-up) within DEBT_YEARS, at the bank's monthly rate
	var debt := EconFinance.debt_of(world, oid) + need
	var service_y := debt / DEBT_YEARS + int(float(debt) * EconData.BANK_FIRM_BASE_PM * 12.0)
	if f.is_empty() or int(f.get("profit", 0)) < service_y:
		_count(world, "bank_no_cover")
		return false
	var floor_c := maxi(EconData.BANK_CASH * S, EconBank.loans(world) * EconMoney.CAPITAL_LOAN_PCT / 100)
	var room := EconBank.room(world) if EconBank.active(world) else world.ledger.balance(EconUtil.BANK) - EconData.BANK_MIN_CASH * S
	if need > room or EconBank.capital(world) < floor_c:
		return false
	var v := _value(world, oid)
	var swapped := 0
	for lid in EconUtil.sorted_keys(world.table("loan")):
		var l: Dictionary = world.table("loan")[lid]
		if l["borrower"] != oid or int(l["principal"]) <= 0 or bool(l.get("revolving", false)):
			continue
		var c := int(l["principal"]) * SWAP_PCT / 100
		var pm := EconShares.add_stake(o, "bank", int(float(c) * 1000.0 / float(v + c)))
		if pm <= 0:
			continue
		c = int(float(v) * float(pm) / float(1000 - pm))
		c = mini(c, int(l["principal"]))
		l["principal"] = int(l["principal"]) - c
		swapped += c
	if swapped > 0:
		_count(world, "bank_swaps")
		_count(world, "bank_swap_amount", swapped)
	if EconFinance.new_loan(world, oid, need, 0, true):
		for lid in EconUtil.sorted_keys(world.table("loan")):
			var l: Dictionary = world.table("loan")[lid]
			if l["borrower"] == oid and not bool(l.get("ext_given", false)):
				l["grace_after_open"] = EXT_M
				l["ext_given"] = true
		_count(world, "bank_topups")
		_count(world, "bank_topup_amount", need)
		rs["kind"] = "bank"
		EconFacts.emit(world, "COMP_BANK_RESCUE", o["hq"], [["COMPANY", oid]], [["COMPANY", oid, 1.0]], {}, 15, "OFFICIAL",
			{"org": oid, "lent": need / S, "swapped": swapped / S})
		_saved(world, o, "bank")
		return true
	return false


## The state's rescue loans: an annuity to the treasury once the grace after opening is over. Unpaid months wait; a firm
## that dies leaves the rest unrecovered (counted).
static func _gov_loans(world: WorldState) -> void:
	for oid in EconUtil.sorted_keys(world.table("org")):
		var o: Dictionary = world.table("org")[oid]
		if not o.has("gov_loan"):
			continue
		var gl: Dictionary = o["gov_loan"]
		if o["status"] in ["LIQUIDATION", "DISSOLVED"]:
			_count(world, "public_lost", int(gl["principal"]))
			o.erase("gov_loan")
			continue
		if o["status"] == "FORMING" or gl.has("grace_after_open") or world.month < int(gl.get("grace_until", -1)):
			continue
		var r := float(gl["rate_ppm"]) / 1000000.0
		var n := maxi(1, int(gl["term_left"]))
		var pr := int(gl["principal"])
		var interest := int(float(pr) * r)
		var annuity := int(float(pr) * r / (1.0 - pow(1.0 + r, -n))) if r > 0.0 else pr / n
		var due := mini(pr + interest, annuity)
		var acc := EconUtil.acct(oid)
		if due <= 0 or world.ledger.balance(acc) < due:
			continue
		world.ledger.transfer(acc, EconUtil.TREASURY, due, "RESCUE_LOAN_SERVICE", world.month)
		EconFinance._gov_rev(world, due)
		EconFinance.pl_add(world, oid, "interest", interest)
		gl["principal"] = maxi(0, pr - (due - interest))
		gl["term_left"] = n - 1
		_count(world, "public_recovered", due)
		if int(gl["principal"]) <= 0:
			o.erase("gov_loan")


## EconInsolvency._open_plan: the bank's (and the state's) interest-only months start when the plant opens.
static func on_open(world: WorldState, oid: String) -> void:
	var o: Dictionary = world.table("org").get(oid, {})
	if o.has("gov_loan") and (o["gov_loan"] as Dictionary).has("grace_after_open"):
		o["gov_loan"]["grace_until"] = world.month + int(o["gov_loan"]["grace_after_open"])
		(o["gov_loan"] as Dictionary).erase("grace_after_open")
	for lid in EconUtil.sorted_keys(world.table("loan")):
		var l: Dictionary = world.table("loan")[lid]
		if l["borrower"] == oid and l.has("grace_after_open"):
			l["grace_until"] = maxi(int(l.get("grace_until", -1)), world.month + int(l["grace_after_open"]))
			l.erase("grace_after_open")


# ------------------------------------------------------------------ 3. ECON_RESCUE_PLAN (the government)

static func validate_action(world: WorldState, p: Dictionary) -> String:
	if not active(world):
		return "No rescue scheme"
	var oid := String(p.get("org", ""))
	var o: Dictionary = world.table("org").get(oid, {})
	if o.is_empty() or not o.has("rescue"):
		return "'%s' is not in trouble" % oid
	if not needed(world, plant_type(world, oid)):
		return "The colony does not need this plant"
	var tried: Array = o["rescue"].get("tried", [])
	if not ("shares" in tried and "bank" in tried):
		return "Shares and the bank have not been tried yet"
	var form := String(p.get("form", ""))
	if not (form in ["GRANT", "LOAN", "STAKE"]):
		return "Form must be GRANT, LOAN or STAKE"
	var amount := int(p.get("amount", 0)) * S
	if amount <= 0 or amount > int(o["rescue"]["shortfall"]) * 11 / 10:
		return "Amount must be positive and at most the shortfall (+10%)"
	if form == "GRANT" and amount > EconActions.headroom(world, "ECON_BUDGET_SUBSIDIES"):
		return "Not enough room in the subsidy line"
	if form == "STAKE" and EconShares.outside_pm(o) >= EconShares.OUTSIDE_MAX_PM:
		return "No stake left to take"
	return ""


static func apply_action(world: WorldState, p: Dictionary) -> bool:
	if validate_action(world, p) != "":
		return false
	var oid := String(p["org"])
	var o: Dictionary = world.table("org")[oid]
	var form := String(p["form"])
	var amount := int(p["amount"]) * S
	var v := _value(world, oid)
	var paid := EconFinance.gov_pay(world, EconUtil.acct(oid), amount, "RESCUE_" + form)
	if form == "GRANT":
		EconFinance._spend_line(world, "ECON_BUDGET_SUBSIDIES", paid)
	elif form == "LOAN":
		# the state's loan is kept on the firm, not in the bank's loan table (its repayments go to the treasury and it
		# is no part of the bank's capital); serviced by _gov_loans after a grace of EXT_M months from the opening
		o["gov_loan"] = {"principal": paid, "rate_ppm": GOV_RATE_PPM, "term_left": GOV_TERM_M, "grace_after_open": EXT_M}
	else:
		EconShares.add_stake(o, "gov", maxi(1, int(float(paid) * 1000.0 / float(v + paid))))
	_count(world, "gov_" + form)
	_count(world, "public_spent", paid)
	EconFacts.emit(world, "ECON_PLAN_BAILOUT", o["hq"], [["COMPANY", oid], ["GOVERNMENT", "government"]],
		[["GOVERNMENT", "government", 1.0]], {}, 30, "PUBLIC",
		{"org": oid, "type": plant_type(world, oid), "district": o["hq"], "form": form, "amount": paid / S, "needed": true},
		{"districts": [o["hq"]]})
	o["rescue"]["kind"] = "gov_" + form
	o["rescue"]["shortfall"] = shortfall(world, oid)
	if int(o["rescue"]["shortfall"]) <= 0:
		_saved(world, o, "gov_" + form)
	return true

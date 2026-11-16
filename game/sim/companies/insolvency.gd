class_name EconInsolvency
extends RefCounted
## The one insolvency state machine (spec §11, X9):
## FORMING → ACTIVE ⇄ DISTRESSED → ADMINISTRATION → ACTIVE (restructured) | LIQUIDATION → DISSOLVED.
## Public enterprises are never liquidated: distress triggers an automatic support transfer + funding-request fact (E44).

const BUYOUT_GAP_M := 60  # E121: months before a plant can be rescued by its workers again
## E135 (v8 chronicles, Wilma: the same firm insolvent every ~5 months for decades — 97 times in seed 3): a workout cut
## the bank debt but left unpaid fines and other liabilities due, so the firm missed them again at once. Now a
## restructuring puts open liabilities on a PLAN_M-month payment plan (fines are not written off), and a firm entering
## administration ZOMBIE_N times within ZOMBIE_M months gets no further workout: it is liquidated (its strategic plants
## still pass to the public operator, E47).
const PLAN_M := 12
const ZOMBIE_N := 3
const ZOMBIE_M := 36
const S := EconUtil.S


## Fixed monthly obligations F (mcr): wages + loan service + upkeep at last month's levels + liabilities due.
static func obligations(world: WorldState, oid: String) -> int:
	var o: Dictionary = world.table("org")[oid]
	var pl: Dictionary = o["pl"]
	var f: int = pl.get("wages", 0) + pl.get("interest", 0)
	for lid in world.table("loan"):
		var l: Dictionary = world.table("loan")[lid]
		if bool(l.get("family", false)):
			continue  # E160/E162 grant loans: paid from surplus, never "due" (default only after 12 months without payment)
		if l["borrower"] == oid and l["term_left"] > 0 and world.month >= int(l.get("grace_until", -1)):  # E136: no principal in grace
			f += l["principal"] / maxi(1, l["term_left"])
	for lid in world.table("liability"):
		var li: Dictionary = world.table("liability")[lid]
		if li["debtor"] == oid and li["status"] == "OPEN" and li["due_month"] <= world.month:
			f += li["amount"]
	return f


static func check_all(world: WorldState) -> void:
	_pay_liabilities(world)
	EconPlanRescue.monthly(world)  # E166 (opt-in): rescue windows for plans in trouble
	for oid in EconUtil.sorted_keys(world.table("org")):
		var o: Dictionary = world.table("org")[oid]
		match o["type"]:
			"PUBLIC_INSTITUTION":
				continue
			"PUBLIC_ENTERPRISE":
				_pe_support(world, oid)
				continue
		_step(world, oid)


static func _pay_liabilities(world: WorldState) -> void:
	for lid in EconUtil.sorted_keys(world.table("liability")):
		var li: Dictionary = world.table("liability")[lid]
		if li["status"] != "OPEN" or li["due_month"] > world.month:
			continue
		var from := EconUtil.acct(li["debtor"])
		var to: String = EconUtil.FINES if li["kind"] == "FINE" else (EconUtil.TREASURY if li["creditor"] == "gov" else EconUtil.acct(li["creditor"]))
		# Anni: the law's rows name the real payee (law:victim_fund, party:, media:, union, treasury, co:)
		var ca := String(li.get("creditor_acct", ""))
		if ca != "" and world.ledger.has_account(ca):
			to = ca
		var paid := EconUtil.pay_upto(world, from, to, li["amount"], li["kind"])
		li["amount"] -= paid
		if li["amount"] <= 0:
			li["status"] = "PAID"
		elif world.table("org").has(li["debtor"]):
			world.table("org")[li["debtor"]]["missed_this_month"] = true


static func _step(world: WorldState, oid: String) -> void:
	var o: Dictionary = world.table("org")[oid]
	var cash := world.ledger.balance(EconUtil.acct(oid))
	var f := obligations(world, oid)
	var missed: bool = o["missed_this_month"]
	for lid in world.table("loan"):
		var l: Dictionary = world.table("loan")[lid]
		if l["borrower"] == oid and l["missed"] >= 2:
			missed = true
	o["missed_streak"] = o["missed_streak"] + 1 if missed else 0
	o["ok_streak"] = 0 if missed else o["ok_streak"] + 1
	o["low_cash_streak"] = o["low_cash_streak"] + 1 if cash < f else 0
	match o["status"]:
		"FORMING":
			for fid in world.table("facility"):
				if world.table("facility")[fid]["org"] == oid:
					o["status"] = "ACTIVE"
					if planning_stage(world):
						_open_plan(world, oid, fid)
					EconStaple.startup_capital(world, oid, fid)  # E147 (opt-in): the founder funds the first months
					EconFamily.on_open(world, oid, fid)  # E160 / E162: the family goes to work
					break
			if o["status"] == "FORMING":
				var building := false
				for pid in world.table("project"):
					var p: Dictionary = world.table("project")[pid]
					if p["owner"] == oid and p["status"] == "ACTIVE":
						building = true
				o["forming_idle"] = 0 if building else o.get("forming_idle", 0) + 1
				if planning_stage(world):
					# E165 (the user 2026-11-16: "PLANS ARE MADE BEFORE THEY BECOME COMPANIES"): a plan cannot fail and no
					# count of months ends it. It waits for a builder, goes back to tender when its builder dies, and ends
					# only by its owner's decision (plan_withdrawal), a withdrawal, not a death.
					if plan_state(world, oid) == "building":
						o["build_started"] = true
					var why := plan_withdrawal(world, oid)
					if why != "":
						abandon_plan(world, oid, why)
				elif o["forming_idle"] >= 6:
					for pid in EconUtil.sorted_keys(world.table("project")):
						var p: Dictionary = world.table("project")[pid]
						if p["owner"] == oid and p["status"] in ["TENDER", "TENDERABLE"]:
							p["status"] = "CANCELLED"
					_waterfall(world, oid)
		"ACTIVE":
			var e140 := EconAnnual.distress(world, oid, missed, cash)  # -1: the old rule
			if (e140 == 1) if e140 >= 0 else (missed or o["low_cash_streak"] >= 2):
				EconAnnual.note_distress(world, o)
				o["status"] = "DISTRESSED"
				o["distress_months"] = 0
				EconFacts.emit(world, "COMP_DISTRESSED", o["hq"], [["COMPANY", oid]], [["COMPANY", oid, 1.0]], {}, 20, "OFFICIAL",
					{"cash": cash, "obligations": f})
		"DISTRESSED":
			o["distress_months"] += 1
			if (cash >= 2 * f and o["ok_streak"] >= 3) or EconAnnual.recovered(world, oid, cash, f):
				o["status"] = "ACTIVE"
				o["distress_months"] = 0
			elif o["missed_streak"] >= 3 or _loan_called(world, oid):
				_enter_administration(world, oid)
		"ADMINISTRATION":
			o["admin_months"] += 1
			if o["admin_months"] == 3:
				_rescue_strategic(world, oid)
			var zombie: bool = bool(o.get("no_workout", false)) and not EconUtil.off(world, "E135")
			if not zombie and EconFinance.profit(o["pl"]) > 0 and cash >= f and o["missed_streak"] == 0:
				if EconMoney.sound_bank(world):
					EconMoney.reschedule(world, oid)  # E152a: rescheduled, not written down
				else:
					for lid in EconUtil.sorted_keys(world.table("loan")):
						var l: Dictionary = world.table("loan")[lid]
						if l["borrower"] == oid:
							l["principal"] = int(l["principal"] * (1.0 - EconData.RESTRUCTURE_HAIRCUT))
							l["missed"] = 0
				o["status"] = "ACTIVE"
				o["admin_months"] = 0
				_payment_plan(world, oid)
				EconFacts.emit(world, "COMP_RESTRUCTURED", o["hq"], [["COMPANY", oid]], [["COMPANY", oid, 0.8], ["GOVERNMENT", "government", 0.2]],
					{"JOBS": 5}, 20, "PUBLIC")
			elif not zombie and o["admin_months"] >= 2 and _op_surplus(world, o) >= 0 and EconFinance.debt_of(world, oid) > 0:
				# E77 debt workout: the business covers its running costs, only the debt kills it → the bank writes
				# debt down to what ~24 months of surplus can carry (at least the normal haircut) and the firm continues
				var surplus := _op_surplus(world, o)
				var debt := EconFinance.debt_of(world, oid)
				var keep := mini(int(float(debt) * (1.0 - EconData.RESTRUCTURE_HAIRCUT)), 24 * surplus)
				var factor := float(keep) / float(maxi(1, debt))
				if EconMoney.sound_bank(world):
					EconMoney.reschedule(world, oid)  # E152a: the debt is spread over a longer term, not written down
				else:
					for lid in EconUtil.sorted_keys(world.table("loan")):
						var l: Dictionary = world.table("loan")[lid]
						if l["borrower"] == oid:
							l["principal"] = int(float(l["principal"]) * factor)
							l["missed"] = 0
				o["status"] = "ACTIVE"
				o["admin_months"] = 0
				o["missed_streak"] = 0
				o["low_cash_streak"] = 0
				_payment_plan(world, oid)
				EconFacts.emit(world, "COMP_RESTRUCTURED", o["hq"], [["COMPANY", oid]], [["COMPANY", oid, 0.8], ["NATURE", "market", 0.2]],
					{"JOBS": 5}, 25, "PUBLIC", {"debt_before": debt / S, "debt_after": keep / S, "workout": true})
			elif o["admin_months"] >= 6:
				o["status"] = "LIQUIDATION"
				o["liq_months"] = 0
				if o["is_contractor"]:
					EconConstruction.fail_contracts(world, oid)


## Court-ordered liquidation (Anni's justice side: a revoked licence for a repeat offender, or a creditor petition over
## unpaid fines): the firm goes straight to LIQUIDATION; its plants then follow the normal path (same-sector buyer,
## workers' co-op, public operator for strategic plants, or closure). Public bodies are never liquidated. -> done?
static func court_liquidation(world: WorldState, oid: String, reason: String) -> bool:
	var o: Dictionary = world.table("org").get(oid, {})
	if o.is_empty() or o["type"] in EconData.PUBLIC_TYPES or o["status"] in ["LIQUIDATION", "DISSOLVED"]:
		return false
	if o["status"] != "ADMINISTRATION":
		_enter_administration(world, oid)
	o["status"] = "LIQUIDATION"
	o["liq_months"] = 0
	o["no_workout"] = true
	if o["is_contractor"]:
		EconConstruction.fail_contracts(world, oid)
	EconFacts.emit(world, "COMP_COURT_LIQUIDATION", o["hq"], [["COMPANY", oid]], [["COMPANY", oid, 1.0]], {"FAIRNESS": 5, "JOBS": -5}, 45,
		"PUBLIC", {"reason": reason}, {"districts": [o["hq"]]})
	return true


## E135: a restructured firm's open liabilities (fines, awards, union and party claims) fall due over PLAN_M months
## instead of all at once — rescheduled, not forgiven.
static func _payment_plan(world: WorldState, oid: String) -> void:
	if EconUtil.off(world, "E135"):
		return
	for lid in EconUtil.sorted_keys(world.table("liability")):
		var li: Dictionary = world.table("liability")[lid]
		if li["debtor"] == oid and li["status"] == "OPEN" and int(li["due_month"]) <= world.month:
			li["due_month"] = world.month + PLAN_M


## E47: strategic facilities of a firm 3 months in administration pass to the public operator at 40% of book.
static func _rescue_strategic(world: WorldState, oid: String) -> void:
	var pe := EconFinance.org_by_key(world, "CPW")
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["org"] != oid or not (f["type"] in EconData.STRATEGIC):
			continue
		var paid := EconFinance.gov_pay(world, EconUtil.acct(oid), int(f["book"] * EconData.GOV_FIRST_PURCHASE), "LIQUIDATION")
		EconFinance._spend_line(world, "ECON_BUDGET_INFRASTRUCTURE", paid)
		# workforce and stock move with the facility
		f["org"] = pe
		f["book"] = paid
		f["mothball"] = false
		f["nationalized_month"] = world.month
		var r: Dictionary = EconData.RECIPES[f["type"]]
		var goods: Array = [r["out"][0]] + r["in"].keys()
		for g in goods:
			if g in EconData.MARKET_GOODS:
				var q := EconUtil.inv_get(world, oid, g, f["district"])
				var wac := EconUtil.inv_wac(world, oid, g, f["district"])
				EconUtil.inv_take(world, oid, g, f["district"], q)
				EconUtil.inv_add(world, pe, g, f["district"], q, wac)
		EconFacts.emit(world, "ECON_FACILITY_SOLD", f["district"], [["COMPANY", oid], ["GOVERNMENT", "government"]],
			[["GOVERNMENT", "government", 1.0]], {"JOBS": 5}, 30, "PUBLIC", {"facility": fid, "price": paid, "nationalized": true})


## E140: the year's average month under E140, else last month.
static func _op_surplus(world: WorldState, o: Dictionary) -> int:
	var e := EconAnnual.operating_surplus(world, o)
	return e if e != -2 else _operating_surplus(o)


## Revenue minus input costs and wages (no interest, no depreciation): the average month of the last year once there is
## history (E140 correction, 2026-11-16), else last month's.
static func _operating_surplus(o: Dictionary) -> int:
	var pl: Dictionary = o["pl_last"]
	if EconAnnual.months(o) >= EconAnnual.MIN_M:
		var y := EconAnnual.sum12(o)
		var n := EconAnnual.months(o)
		pl = {"rev": int(y.get("rev", 0)) / n, "subsidy": int(y.get("subsidy", 0)) / n, "cogs": int(y.get("cogs", 0)) / n, "wages": int(y.get("wages", 0)) / n, "freight": int(y.get("freight", 0)) / n}
	if pl.is_empty() or pl.get("rev", 0) <= 0:
		return -1
	return pl.get("rev", 0) + pl.get("subsidy", 0) - pl.get("cogs", 0) - pl.get("wages", 0) - pl.get("freight", 0)


static func _loan_called(world: WorldState, oid: String) -> bool:
	for lid in world.table("loan"):
		var l: Dictionary = world.table("loan")[lid]
		if l["borrower"] == oid and l["missed"] >= 2:
			return true
	return false


static func _enter_administration(world: WorldState, oid: String) -> void:
	var o: Dictionary = world.table("org")[oid]
	o["status"] = "ADMINISTRATION"
	o["admin_months"] = 0
	# E135: count recent administrations; the ZOMBIE_N-th within ZOMBIE_M months ends the workouts
	var hist: Array = []
	for m in o.get("admin_hist", []):
		if world.month - int(m) < ZOMBIE_M:
			hist.append(int(m))
	hist.append(world.month)
	o["admin_hist"] = hist
	o["no_workout"] = hist.size() >= ZOMBIE_N
	var employees := 0
	for fid in world.table("facility"):
		var f: Dictionary = world.table("facility")[fid]
		if f["org"] == oid:
			employees += EconLabor.staff_total(f["staff"])
	employees += EconLabor.staff_total(o["crew"])
	EconFacts.emit(world, "COMP_INSOLVENCY", o["hq"], [["COMPANY", oid]], [["COMPANY", oid, 0.7], ["GOVERNMENT", "government", 0.3]],
		{"JOBS": -mini(40, employees / S / 5)}, 30 + employees / S / 5, "PUBLIC", {"employees": employees / S}, {"districts": [o["hq"]]})


## Public enterprise distress → automatic support transfer (SUBSIDIES) + funding request (E44).
static func _pe_support(world: WorldState, oid: String) -> void:
	var o: Dictionary = world.table("org")[oid]
	var costs := maxi(EconFinance._monthly_costs(o), 1)
	var cash := world.ledger.balance(EconUtil.acct(oid))
	if cash >= costs / 2:
		return
	# E62: cap = SUBSIDIES line headroom, but never below the PE's utility/public-service payroll (lifeline)
	var lifeline := 0
	for fid in world.table("facility"):
		var f: Dictionary = world.table("facility")[fid]
		if f["org"] == oid and (f["type"] in ["POWER", "WATERWORKS", "DEPOT", "HOUSING"] or f["type"] in EconData.STRATEGIC):
			for t in f["staff"]:
				lifeline += EconLabor.tier_total(f["staff"], t) / EconUtil.S * EconFinance.wage_for(world, oid, t)
	if o["is_contractor"]:  # E107b: the public builder of last resort (CWD) keeps its crew paid too
		for t in o["crew"]:
			lifeline += EconLabor.tier_total(o["crew"], t) / EconUtil.S * EconFinance.wage_for(world, oid, t)
	var cap := maxi(lifeline, EconActions.headroom(world, "ECON_BUDGET_SUBSIDIES"))
	if EconPublicCo.b_on(world):
		o["pe_req_m"] = world.month  # E150B (a): a company that asked for money does not cut its prices
	if EconPublicCo.support_cap(world) >= 0:
		cap = EconPublicCo.support_cap(world)  # E150: only what the voted subsidy line allows
		if EconPublicCo.c_on(world):
			cap = maxi(cap, lifeline)  # E150C: a utility's payroll is never left unpaid
		if cap <= 0:
			EconFacts.emit(world, "ECON_PE_FUNDING_REQUEST", o["hq"], [["COMPANY", oid]], [["GOVERNMENT", "government", 1.0]], {}, 30, "OFFICIAL",
				{"amount": 0, "asked": maxi(0, costs - cash) / S})
			return
	var paid := EconFinance.gov_pay(world, EconUtil.acct(oid), mini(costs - cash, cap), "SUBSIDY")
	EconFinance._spend_line(world, "ECON_BUDGET_SUBSIDIES", paid)
	EconFinance.pl_add(world, oid, "subsidy", paid)
	EconFacts.emit(world, "ECON_PE_FUNDING_REQUEST", o["hq"], [["COMPANY", oid]], [["GOVERNMENT", "government", 1.0]], {}, 30, "OFFICIAL",
		{"amount": paid})


## E62: nationalized non-utility facilities are offered back to private firms after 12 months (60% of book), else kept.
static func reprivatize(world: WorldState) -> void:
	var pe := EconFinance.org_by_key(world, "CPW")
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["org"] != pe or f["type"] in ["POWER", "WATERWORKS"] or world.month - f.get("nationalized_month", world.month) < 12:
			continue
		if not EconUtil.off(world, "E118") and (f["mothball"] or f.get("abandoned", false)):
			continue  # E118: a closed plant is not passed on to a buyer who cannot run it either
		var opol := EconOwnership.policy(world)
		if EconOwnership.active(world) and opol == "STATE":
			continue  # E137: a state-leaning government keeps what it holds
		var reserve := int(f["book"] * (EconOwnership.REPRIV_MARKET if opol == "MARKET" else EconData.LIQUIDATION_RESERVE))
		var buyer := _find_buyer(world, pe, f, reserve)
		if buyer == "":
			continue
		world.ledger.transfer(EconUtil.acct(buyer), EconUtil.TREASURY, reserve, "ASSET_SALE", world.month)
		f["org"] = buyer
		f["book"] = reserve
		EconFacts.emit(world, "ECON_FACILITY_SOLD", f["district"], [["GOVERNMENT", "government"], ["COMPANY", buyer]],
			[["GOVERNMENT", "government", 1.0]], {}, 30, "PUBLIC", {"facility": fid, "price": reserve, "privatized": true})


## E91 (user decision 2026-11-11): a plant closed as unsafe or by law that its owner cannot afford to put right is
## sold after FORCED_SALE_MONTHS. Price = book − overhaul cost (− the debts if the whole company goes). Buyers in order:
## a firm of the same sector (or any firm with the cash, not for strategic plants), a workers' co-op of the district,
## the state (strategic plants). If it was the owner's only productive asset the whole company is sold: its debts
## move to the buyer and the empty shell is wound up. The buyer finishes the overhaul (E84) or re-licenses (E90).
static func forced_sale_round(world: WorldState) -> void:
	if EconUtil.off(world, "E91"):
		return
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		var closed: bool = f["mothball"] and (f.get("closed_unsafe", false) or f.get("law_closed", false))
		if not closed:
			f["closed_m"] = 0
			continue
		f["closed_m"] = int(f.get("closed_m", 0)) + 1
		if f["closed_m"] < EconData.FORCED_SALE_MONTHS:
			continue
		var oid: String = f["org"]
		var o: Dictionary = world.table("org").get(oid, {})
		if o.is_empty() or o["type"] in EconData.PUBLIC_TYPES or not (o["status"] in ["ACTIVE", "DISTRESSED", "ADMINISTRATION"]):
			continue
		var unfunded := false
		if f.get("closed_unsafe", false):
			unfunded = int(f.get("overhaul_frac", 0)) < 500
		if f.get("law_closed", false):
			unfunded = unfunded or world.ledger.balance(EconUtil.acct(oid)) < 3 * EconFinance._monthly_costs(o)
		if not unfunded:
			continue
		if not EconUtil.off(world, "E118") and int(f.get("forced_sales", 0)) >= 1:
			scrap(world, f, "UNREPAIRABLE_AFTER_SALE")  # E118: the buyer could not put it right either
			continue
		_forced_sale(world, f)


## E118 (review P0: plants were force-sold every year at halving prices down to 0). A closed plant that a forced
## sale did not save — or that would fetch nothing — is scrapped: written off, its crew laid off (no repair crew,
## no overhaul upkeep), never restarted automatically. The state may still buy and restore it deliberately
## (ECON_BUY_FACILITY clears the flag).
static func scrap(world: WorldState, f: Dictionary, reason: String) -> void:
	var jobs := EconLabor.staff_total(f["staff"]) / EconUtil.S
	f["abandoned"] = true
	f["scrapped"] = true
	f["mothball"] = true
	f["closed_unsafe"] = false
	f["law_closed"] = false
	f["closed_m"] = 0
	f["book"] = 0
	EconFacts.emit(world, "ECON_FACILITY_SCRAPPED", f["district"], [["COMPANY", f["org"]]], EconFacts.company_blame(world, f["org"], 0.7),
		{"JOBS": -5}, 35, "PUBLIC", {"facility": f["id"], "type": f["type"], "jobs": jobs, "reason": reason}, {"districts": [f["district"]]})


static func _forced_sale(world: WorldState, f: Dictionary) -> void:
	var seller: String = f["org"]
	var whole := true  # only productive asset → the whole company is sold
	for fid2 in world.table("facility"):
		var f2: Dictionary = world.table("facility")[fid2]
		if fid2 != f["id"] and f2["org"] == seller and not f2["mothball"]:
			whole = false
			break
	var overhaul := EconConstruction.estimate(f["type"]) / 4
	var debt := EconFinance.debt_of(world, seller) if whole else 0
	var price := maxi(0, f["book"] - overhaul - debt)
	if price <= 0 and not EconUtil.off(world, "E118"):
		scrap(world, f, "WORTHLESS")  # E118: no sales at 0 credits
		return
	var buyer := _find_buyer(world, seller, f, price)
	var kind := "FIRM"
	if buyer != "":
		if price > 0:
			world.ledger.transfer(EconUtil.acct(buyer), EconUtil.acct(seller), price, "ASSET_SALE", world.month)
		f["org"] = buyer
	elif not (f["type"] in ["HOUSING", "SERVICEHUB"]) and _worker_buyout(world, seller, f):
		buyer = f["org"]
		kind = "WORKERS_COOP"
		price = 0
		f["mothball"] = true  # still needs its overhaul / licence before it reopens
	elif f["type"] in EconData.STRATEGIC:
		buyer = EconFinance.org_by_key(world, "CPW")
		kind = "STATE"
		price = EconFinance.gov_pay(world, EconUtil.acct(seller), price, "ASSET_SALE")
		EconFinance._spend_line(world, "ECON_BUDGET_INFRASTRUCTURE", price)
		f["org"] = buyer
		f["nationalized_month"] = world.month
	else:
		return
	f["book"] = price
	f["forced_sales"] = int(f.get("forced_sales", 0)) + 1  # E118: a second time round it is scrapped
	f["closed_m"] = 0
	if whole:
		for lid in EconUtil.sorted_keys(world.table("loan")):
			var l: Dictionary = world.table("loan")[lid]
			if l["borrower"] == seller and l["principal"] > 0:
				l["borrower"] = buyer
		var so: Dictionary = world.table("org")[seller]
		so["status"] = "LIQUIDATION"
		so["liq_months"] = 0
	EconFacts.emit(world, "ECON_FACILITY_SOLD", f["district"], [["COMPANY", seller], ["COMPANY", buyer]],
		EconFacts.company_blame(world, seller, 0.7), {"JOBS": 3}, 35, "PUBLIC",
		{"facility": f["id"], "price": price, "reason": "UNREPAIRABLE", "buyer_kind": kind, "whole_company": whole})


## COMPANY_AI: liquidation auctions and dissolution (spec §11 LIQUIDATION).
static func liquidation_round(world: WorldState) -> void:
	for oid in EconUtil.sorted_keys(world.table("org")):
		var o: Dictionary = world.table("org")[oid]
		if o["status"] != "LIQUIDATION":
			continue
		o["liq_months"] += 1
		var remaining := 0
		for fid in EconUtil.sorted_keys(world.table("facility")):
			var f: Dictionary = world.table("facility")[fid]
			if f["org"] != oid or f.get("abandoned", false):
				continue
			var reserve := int(f["book"] * EconData.LIQUIDATION_RESERVE)
			var buyer := _find_buyer(world, oid, f, reserve)
			if buyer != "":
				world.ledger.transfer(EconUtil.acct(buyer), EconUtil.acct(oid), reserve, "LIQUIDATION", world.month)
				f["org"] = buyer
				f["book"] = reserve
				f["mothball"] = false
				EconFacts.emit(world, "ECON_FACILITY_SOLD", f["district"], [["COMPANY", oid], ["COMPANY", buyer]],
					[["COMPANY", oid, 0.6], ["GOVERNMENT", "government", 0.4]], {}, 30, "PUBLIC", {"facility": fid, "price": reserve})
			elif o["liq_months"] >= 3 and f["type"] in EconData.STRATEGIC:
				var pe := EconFinance.org_by_key(world, "CPW")
				var price := int(f["book"] * EconData.GOV_FIRST_PURCHASE)
				var paid := EconFinance.gov_pay(world, EconUtil.acct(oid), price, "LIQUIDATION")
				EconFinance._spend_line(world, "ECON_BUDGET_INFRASTRUCTURE", paid)
				f["org"] = pe
				f["book"] = paid
				f["mothball"] = false
				EconFacts.emit(world, "ECON_FACILITY_SOLD", f["district"], [["COMPANY", oid], ["GOVERNMENT", "government"]],
					[["GOVERNMENT", "government", 1.0]], {"JOBS": 5}, 30, "PUBLIC", {"facility": fid, "price": paid, "nationalized": true})
			elif o["liq_months"] >= 3 and f["type"] == "HOUSING" and EconFinance.org_by_key(world, "CHO") != "" and not EconUtil.off(world, "E120"):
				# E120 / spec-areas §9.6: people are never put out — homes of a failed landlord pass to the public housing
				# office at the state's first-purchase price (no unrelated buyer may take them, E119)
				var cho := EconFinance.org_by_key(world, "CHO")
				var hprice := int(f["book"] * EconData.GOV_FIRST_PURCHASE)
				var hpaid := EconFinance.gov_pay(world, EconUtil.acct(oid), hprice, "LIQUIDATION")
				EconFinance._spend_line(world, "ECON_BUDGET_HOUSING", hpaid)
				f["org"] = cho
				f["book"] = hpaid
				f["mothball"] = false
				EconFacts.emit(world, "ECON_FACILITY_SOLD", f["district"], [["COMPANY", oid], ["GOVERNMENT", "government"]],
					[["GOVERNMENT", "government", 1.0]], {"HOUSING": 5}, 30, "PUBLIC", {"facility": fid, "price": hpaid, "nationalized": true})
			elif o["liq_months"] >= 3 and not (f["type"] in ["HOUSING", "SERVICEHUB"]) and _worker_buyout(world, oid, f):
				pass  # E77: plant continues as a workers' co-op
			elif o["liq_months"] >= 3 and EconBankRisk.secured_sale(world, oid, f):
				pass  # BANK_SEC: the plant goes with its bank debt instead of being abandoned
			elif o["liq_months"] >= 3:
				f["abandoned"] = true
				f["mothball"] = true
			else:
				remaining += 1
		if remaining == 0 and o["liq_months"] >= 1:
			_waterfall(world, oid)


## E77 worker buyout: an unsold productive plant passes (for free) to a new workers' co-op owned by the largest
## household group of its district; the bank lends 3 months of wages as working capital. Jobs survive.
static func _worker_buyout(world: WorldState, seller: String, f: Dictionary) -> bool:
	# E121 (v5 review): one rescue per plant per BUYOUT_GAP_M — a co-op that failed within that time is not followed by
	# another (seed 3 chained 54 short-lived co-ops through the same plants); the plant closes instead
	if not EconUtil.off(world, "E121") and world.month - int(f.get("buyout_m", -9999)) < BUYOUT_GAP_M:
		return false
	f["buyout_m"] = world.month
	var d: String = f["district"]
	var best := ""
	var best_lf := 0
	for gid in EconUtil.sorted_keys(world.table("hh")):
		var g: Dictionary = world.table("hh")[gid]
		if g["district"] == d and g["lf"] > best_lf:
			best_lf = g["lf"]
			best = gid
	if best == "":
		return false
	var wages := 0
	for t in f["staff"]:
		wages += EconLabor.tier_total(f["staff"], t) / EconUtil.S * EconFinance.wage_for(world, seller, t)
	var id := world.new_id("org")
	world.table("org")[id] = {"id": id, "key": "COOP_" + id, "name": EconUtil.firm_name(world, d, "WORKERS", "Co-op"),
		"type": "COOPERATIVE", "hq": d, "status": "ACTIVE", "ceo": {"mgmt": 50, "risk": 30, "age_m": 40 * 12}, "reliability": 0,
		"is_contractor": false, "crew": {}, "crew_target": {}, "premium_m": {"G": 0, "S": 0, "Sp": 0}, "tax_loss_cf": 0, "profit_q": 0,
		"pl": EconFinance.empty_pl(), "pl_last": {}, "missed_streak": 0, "ok_streak": 0, "low_cash_streak": 0, "distress_months": 0,
		"admin_months": 0, "liq_months": 0, "missed_this_month": false, "owner_group": best, "sales_ema": {}, "contracts": [],
		"dividends_ytd": 0, "sold": {}}
	world.ledger.open_account(EconUtil.acct(id))
	EconFinance.new_loan(world, id, maxi(3 * wages, 10000 * EconUtil.S), 0, true)
	if EconMoney.sound_bank(world):
		# E152b: the co-op takes over the plant's share (by book value) of the failed firm's bank debt, rescheduled
		var total_book := 0
		for fid2 in world.table("facility"):
			if world.table("facility")[fid2]["org"] == seller:
				total_book += int(world.table("facility")[fid2]["book"])
		if total_book > 0:
			EconMoney.pass_debt(world, seller, id, clampi(int(f["book"]) * 1000 / total_book, 0, 1000))
	f["org"] = id
	f["book"] = 0
	f["mothball"] = false
	EconFacts.emit(world, "COMP_WORKER_BUYOUT", d, [["COMPANY", id], ["COMPANY", seller]], [["COMPANY", seller, 1.0]],
		{"JOBS": 5}, 30, "PUBLIC", {"facility": f["id"], "type": f["type"]}, {"districts": [d]})
	return true


static func _find_buyer(world: WorldState, seller: String, f: Dictionary, reserve: int) -> String:
	var best := ""
	for oid in EconUtil.sorted_keys(world.table("org")):
		var o: Dictionary = world.table("org")[oid]
		if oid == seller or o["status"] != "ACTIVE" or not (o["type"] in ["PRIVATE", "COOPERATIVE"]):
			continue
		if world.ledger.balance(EconUtil.acct(oid)) < reserve * 3 / 2:
			continue
		var same := false
		for fid in world.table("facility"):
			var f2: Dictionary = world.table("facility")[fid]
			if f2["org"] == oid and f2["type"] == f["type"]:
				same = true
		if same:
			return oid
		if best == "" and not (f["type"] in EconData.STRATEGIC) and EconUtil.off(world, "E119"):
			best = oid  # E65: strategic plants are not sold to unrelated firms (public operator takes them instead)
	# E119 (Wilma): no unrelated conglomerate either — only a firm of the same sector buys; otherwise the plant goes to
	# a workers' co-op of its district or closes (liquidation_round / _forced_sale fall back to those)
	return best


## E165 (user ruling via Wilma 2026-11-15: "a company that needs a building would not start without the building ...
## you can't fail before you exist"; opt-in): a new firm is a PLAN until its plant opens — no workers, office, wages or
## inspections (those already skip FORMING firms) and no loan service (EconFinance._loan_service skips plans; interest
## starts when the plant opens). COMP_COMPANY_PLANNED at creation, COMP_COMPANY_FOUNDED at opening; its age (the P&L
## ring) counts from opening. A plan is not a company (the user 2026-11-16: "PLANS ARE MADE BEFORE THEY BECOME
## COMPANIES"): it is not counted as founded, alive or dead. It cannot fail and no count of months ends it; it is
## WITHDRAWN only by its owner (plan_withdrawal) — tenders and projects cancelled, its cash repays the bank (the rest
## is written off), what is left goes back to the founder — not a liquidation, not a firm death, no sector cooling.


## Why the owner withdraws its plan this month, or "" (pure). Its own decisions only:
##   no_building: nothing is left to build (its project was cancelled; one whose builder failed is back in tender and
##       waits for a new builder);
##   no_reason: no builder has accepted the job yet and the reason it planned for has gone (its sector's entry signal is
##       off: the founder's own forecast no longer supports it; once a builder accepted, it has a contract).
static func plan_withdrawal(world: WorldState, oid: String) -> String:
	var o: Dictionary = world.peek("org")[oid]
	var job := false
	var accepted := false
	for pid in world.peek("project"):
		var p: Dictionary = world.peek("project")[pid]
		if p["owner"] != oid:
			continue
		if p["status"] in ["TENDER", "TENDERABLE", "ACTIVE"]:
			job = true
		if p["status"] == "ACTIVE":
			accepted = true
	if not job:
		return "no_building"
	if accepted or bool(o.get("build_started", false)) or not o.has("entry_type"):
		return ""
	var sig: Dictionary = EconUtil.peek_st(world).get("entry_signal", {})
	if sig.has(o["entry_type"]) and int(sig[o["entry_type"]]) == 0:
		return "no_reason"
	return ""


static func planning_stage(world: WorldState) -> bool:
	return (world.meta.get("on", []) as Array).has("E165") and not EconUtil.off(world, "E165")


## E165b (opt-in on top of E165, Wilma 2026-11-15, after the E165 A/B lost 4779 → 4595 adults and half the bank's
## capital): (a) no plan while every builder is booked (waiting tenders ≥ private builders); (b) a plan dropped for want
## of a builder cools its sector for NO_BUILDER_COOL_M months (not the full failure cooling, not zero); (c) the plan's
## bank loan is an approved credit drawn only as the builder is paid, so nothing idles and a stall loses only what was
## built.
const NO_BUILDER_COOL_M := 12


static func plan_b(world: WorldState) -> bool:
	return planning_stage(world) and ((world.meta.get("on", []) as Array).has("E165B") or (world.meta.get("on", []) as Array).has("E165Q"))


## E165b (a) only: no plan while every builder is booked (the order book E165Q replaces it).
static func plan_a(world: WorldState) -> bool:
	return planning_stage(world) and (world.meta.get("on", []) as Array).has("E165B")


## E165Q (user + Wilma 2026-11-15, "firms queue work up: we do this in three months"; opt-in, implies E165 and E165b
## (c)): builders quote a start date from their order book as well as a price; the founder takes the best offer; an
## accepted job waits in the builder's book and the plan waits with it at no cost. No plan is dropped for want of a
## builder: it is withdrawn only by its owner (plan_withdrawal). Builders enter when the books hold
## ENTRY_BOOK_YEARS of work for a standard entrant (EconConstruction.book_entry).


static func plan_q(world: WorldState) -> bool:
	return planning_stage(world) and (world.meta.get("on", []) as Array).has("E165Q")


## A plan's state under E165Q: "no_offer" (tender without an accepted bid), "queued" (accepted, not started), "building".
static func plan_state(world: WorldState, oid: String) -> String:
	var st := "no_offer"
	for pid in world.table("project"):
		var p: Dictionary = world.table("project")[pid]
		if p["owner"] != oid or p["status"] != "ACTIVE":
			continue
		if int(p["start_month"]) <= world.month:
			return "building"
		st = "queued"
	return st


static func builder_free(world: WorldState) -> bool:
	var waiting := 0
	for pid in world.table("project"):
		var p: Dictionary = world.table("project")[pid]
		if p["status"] == "TENDERABLE" or (p["status"] == "TENDER" and (p["bids"] as Array).is_empty()):
			waiting += 1
	var builders := 0
	for oid in world.table("org"):
		var o: Dictionary = world.table("org")[oid]
		if bool(o.get("is_contractor", false)) and o["type"] == "PRIVATE" and o["status"] in ["ACTIVE", "DISTRESSED"]:
			builders += 1
	return waiting < maxi(1, builders)


static func draw_plan_credit(world: WorldState, oid: String, amount: int) -> void:
	var o: Dictionary = world.table("org").get(oid, {})
	if o.is_empty() or int(o.get("plan_credit", 0)) <= 0 or o["status"] != "FORMING":
		return
	var short := amount - world.ledger.balance(EconUtil.acct(oid))
	if short <= 0:
		return
	var draw := mini(short, int(o["plan_credit"]))
	if EconFinance.new_loan(world, oid, draw, 0, true):
		o["plan_credit"] = int(o["plan_credit"]) - draw


static func _open_plan(world: WorldState, oid: String, fid: String) -> void:
	var o: Dictionary = world.table("org")[oid]
	o["opened_month"] = world.month
	o.erase("plan_credit")
	if EconPlanRescue.active(world):
		EconPlanRescue.on_open(world, oid)  # E166: interest-only months from the opening
	o["pl_ring"] = []
	var s := EconUtil.st(world)
	var ps: Dictionary = s.get("plan_stats", {})
	ps["opened"] = int(ps.get("opened", 0)) + 1
	ps["months_to_open"] = int(ps.get("months_to_open", 0)) + world.month - int(o.get("planned_month", world.month))
	s["plan_stats"] = ps
	var f: Dictionary = world.table("facility")[fid]
	EconFacts.emit(world, "COMP_COMPANY_FOUNDED", o["hq"], [["COMPANY", oid]], [["COMPANY", oid, 0.8], ["GOVERNMENT", "government", 0.2]],
		{"JOBS": 3}, 15, "PUBLIC", {"type": f["type"], "planned_month": int(o.get("planned_month", world.month))}, {"districts": [o["hq"]]})


static func abandon_plan(world: WorldState, oid: String, cause: String) -> void:
	var o: Dictionary = world.table("org")[oid]
	var acc := EconUtil.acct(oid)
	var left: Array = []  # E169: projects with work done become half-built buildings
	for pid in EconUtil.sorted_keys(world.table("project")):
		var p: Dictionary = world.table("project")[pid]
		if p["owner"] == oid and p["status"] in ["TENDER", "TENDERABLE", "ACTIVE"]:
			if p["status"] == "ACTIVE" and EconUnfinished.active(world):
				left.append(p)
			if p["status"] == "ACTIVE" and world.table("org").has(String(p.get("contractor", ""))):
				# the cancelled job leaves the builder's book (it inflated committed() for the builder's life; Otto + Bob)
				(world.table("org")[p["contractor"]]["contracts"] as Array).erase(pid)
			p["status"] = "CANCELLED"
	var repaid := 0
	var written := 0
	for lid in EconUtil.sorted_keys(world.table("loan")):
		var l: Dictionary = world.table("loan")[lid]
		if l["borrower"] == oid and int(l["principal"]) > 0:
			var paid := EconUtil.pay_upto(world, acc, EconUtil.BANK, int(l["principal"]), "PLAN_REPAY")
			repaid += paid
			written += int(l["principal"]) - paid
			l["principal"] = 0
	var rest := world.ledger.balance(acc)
	if rest > 0:
		var to := EconUtil.hh_acct(o["owner_group"]) if o["owner_group"] != "" and world.table("hh").has(o["owner_group"]) else EconUtil.TREASURY
		world.ledger.transfer(acc, to, rest, "PLAN_RETURN", world.month)
	var claim := written
	for p in left:
		# E169: the bank holds the shell up to what it wrote off; the rest belongs to the founder household
		var hold := EconUtil.hh_acct(o["owner_group"]) if o["owner_group"] != "" and world.table("hh").has(o["owner_group"]) else EconUtil.TREASURY
		if EconUnfinished.leave(world, p, hold, claim) != "":
			claim = 0  # one claim, on the first shell
	o["status"] = "DISSOLVED"
	o["plan_abandoned"] = true
	o.erase("plan_credit")
	o["entry_fail_noted"] = true  # no E128 cooling: a missing builder or money, not the market
	if plan_b(world) and cause == "no_builder" and o.has("entry_type"):
		# E165b (b): a shorter cooling — the full one minus what is left of NO_BUILDER_COOL_M
		var fails: Dictionary = EconUtil.st(world).get("entry_fail", {})
		fails[o["entry_type"]] = maxi(int(fails.get(o["entry_type"], -9999)), world.month - FirmAI.ENTRY_FAIL_COOL_M + NO_BUILDER_COOL_M)
		EconUtil.st(world)["entry_fail"] = fails
	var s := EconUtil.st(world)
	var ps: Dictionary = s.get("plan_stats", {})
	ps["abandoned_" + cause] = int(ps.get("abandoned_" + cause, 0)) + 1
	ps["withdrawn"] = int(ps.get("withdrawn", 0)) + 1
	ps["written_off"] = int(ps.get("written_off", 0)) + written
	ps["written_off_" + cause] = int(ps.get("written_off_" + cause, 0)) + written
	s["plan_stats"] = ps
	EconFacts.emit(world, "COMP_PLAN_ABANDONED", o["hq"], [["COMPANY", oid]], [["COMPANY", oid, 1.0]], {}, 20, "PUBLIC",
		{"cause": cause, "months": world.month - int(o.get("planned_month", world.month)), "repaid": repaid / S,
		"written_off": written / S, "returned": maxi(0, rest) / S}, {"districts": [o["hq"]]})


static func _waterfall(world: WorldState, oid: String) -> void:
	var o: Dictionary = world.table("org")[oid]
	var acc := EconUtil.acct(oid)
	for lid in EconUtil.sorted_keys(world.table("loan")):
		var l: Dictionary = world.table("loan")[lid]
		if l["borrower"] == oid and l["principal"] > 0:
			var paid := EconUtil.pay_upto(world, acc, EconUtil.BANK, l["principal"], "LIQUIDATION")
			l["principal"] = 0  # remainder written off by the bank
	var rest := world.ledger.balance(acc)
	if rest > 0:
		var to := EconUtil.hh_acct(o["owner_group"]) if o["owner_group"] != "" else EconUtil.TREASURY
		world.ledger.transfer(acc, to, rest, "LIQUIDATION", world.month)
	o["status"] = "DISSOLVED"
	EconFacts.emit(world, "COMP_LIQUIDATED", o["hq"], [["COMPANY", oid]], [["COMPANY", oid, 0.7], ["GOVERNMENT", "government", 0.3]],
		{"JOBS": -10}, 40, "PUBLIC", {}, {"districts": [o["hq"]]})

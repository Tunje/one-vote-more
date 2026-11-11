class_name EconFinance
extends RefCounted
## SETTLEMENT phase (spec §5 step order, §12 bank, §13 accounting & government finance).

const S := EconUtil.S
const PL_KEYS := ["rev", "cogs", "wages", "util", "freight", "rent", "dep", "interest", "royalty", "subsidy"]


static func empty_pl() -> Dictionary:
	var d := {}
	for k in PL_KEYS:
		d[k] = 0
	return d


static func pl_add(world: WorldState, org_id: String, key: String, amount: int) -> void:
	if world.table("org").has(org_id):
		var pl: Dictionary = world.table("org")[org_id]["pl"]
		pl[key] = pl.get(key, 0) + amount


static func profit(pl: Dictionary) -> int:
	return pl["rev"] + pl.get("subsidy", 0) - pl["cogs"] - pl["wages"] - pl["util"] - pl["freight"] - pl["rent"] - pl["dep"] - pl["interest"] - pl["royalty"]


# ---------- loans (spec §12) ----------

## Records a loan. If move_cash, the bank pays the principal to the borrower (returns false if the bank lacks cash).
static func new_loan(world: WorldState, borrower: String, amount: int, rate_ppm: int, move_cash: bool = false) -> bool:
	var to := EconUtil.TREASURY if borrower == "gov" else EconUtil.acct(borrower)
	if move_cash:
		if world.ledger.balance(EconUtil.BANK) - amount < EconData.BANK_MIN_CASH * S:
			return false
		world.ledger.transfer(EconUtil.BANK, to, amount, "LOAN_DRAW", world.month)
	if rate_ppm == 0:
		rate_ppm = int(EconData.BANK_GOV_RATE_PM * 1000000) if borrower == "gov" else int(EconData.BANK_FIRM_BASE_PM * 1000000)
	var lid := world.new_id("loan")
	world.table("loan")[lid] = {"id": lid, "borrower": borrower, "principal": amount, "rate_ppm": rate_ppm,
		"term_left": 0 if borrower == "gov" else 60, "missed": 0}
	return true


static func debt_of(world: WorldState, borrower: String) -> int:
	var d := 0
	for lid in world.peek("loan"):  # pure read (queries/UI)
		var l: Dictionary = world.peek("loan")[lid]
		if l["borrower"] == borrower:
			d += l["principal"]
	return d


## Origin Development Grant (charter): full for 48 months, then linear taper to 0 at month 120 (E58).
static func origin_grant(month: int) -> int:
	if month < EconData.ORIGIN_GRANT_MONTHS:
		return EconData.ORIGIN_GRANT * S
	if month >= EconData.ORIGIN_GRANT_TAPER_END:
		return 0
	var left := float(EconData.ORIGIN_GRANT_TAPER_END - month) / float(EconData.ORIGIN_GRANT_TAPER_END - EconData.ORIGIN_GRANT_MONTHS)
	return int(float(EconData.ORIGIN_GRANT * S) * left)


static func gov_revenue_12m(world: WorldState) -> int:
	var h: Array = EconUtil.peek_st(world).get("gov_rev_hist", [])
	var t := 0
	for v in h:
		t += v
	if h.size() < 12 and h.size() > 0:
		t = t * 12 / h.size()
	return maxi(t, EconData.ORIGIN_GRANT * S * 12)


static func gov_credit_headroom(world: WorldState) -> int:
	return maxi(0, int(EconData.BANK_GOV_LIMIT * gov_revenue_12m(world)) - debt_of(world, "gov"))


## Government borrowing (ECON_BORROW or automatic liquidity draw). Returns amount drawn.
static func gov_borrow(world: WorldState, amount: int) -> int:
	var s := EconUtil.st(world)
	var amt := mini(amount, gov_credit_headroom(world))
	amt = mini(amt, maxi(0, world.ledger.balance(EconUtil.BANK) - EconData.BANK_MIN_CASH * S))
	if amt <= 0:
		if not s.get("bank_freeze_noted", false) and world.ledger.balance(EconUtil.BANK) < EconData.BANK_MIN_CASH * S:
			s["bank_freeze_noted"] = true
			EconFacts.emit(world, "ECON_BANK_CREDIT_FREEZE", null, [], [["EXTERNAL", "bank", 0.7], ["GOVERNMENT", "government", 0.3]], {"JOBS": -5}, 50, "PUBLIC")
		return 0
	var existing := ""
	for lid in world.table("loan"):
		if world.table("loan")[lid]["borrower"] == "gov":
			existing = lid
	world.ledger.transfer(EconUtil.BANK, EconUtil.TREASURY, amt, "LOAN_DRAW", world.month)
	if existing == "":
		new_loan(world, "gov", amt, 0, false)
	else:
		world.table("loan")[existing]["principal"] += amt
	var ratio := int(100.0 * float(debt_of(world, "gov")) / float(maxi(1, gov_revenue_12m(world))))
	if ratio >= s["debt_threshold_pp"] + 25:
		s["debt_threshold_pp"] = ratio / 25 * 25
		EconFacts.emit(world, "ECON_GOV_BORROWED", null, [["GOVERNMENT", "government"]], [["GOVERNMENT", "government", 1.0]],
			{"GOVERNANCE": -5}, 30, "PUBLIC", {"debt_ratio_pct": ratio})
	return amt


## Government pays `amount`; draws on the credit line if needed. Returns amount paid.
static func gov_pay(world: WorldState, to_acct: String, amount: int, memo: String) -> int:
	if amount <= 0:
		return 0
	var short := amount - world.ledger.balance(EconUtil.TREASURY)
	if short > 0:
		gov_borrow(world, short + amount / 10)
	return EconUtil.pay_upto(world, EconUtil.TREASURY, to_acct, amount, memo)


static func _gov_rev(world: WorldState, amount: int) -> void:
	var s := EconUtil.st(world)
	s["gov_rev_m"] = s.get("gov_rev_m", 0) + amount


# ---------- SETTLEMENT ----------

static func settle(world: WorldState) -> void:
	var s := EconUtil.st(world)
	s["gov_rev_m"] = 0
	s["gov_spend_m"] = 0
	s["gov_capex_m"] = 0
	for oid in world.table("org"):
		world.table("org")[oid]["missed_this_month"] = false
	for gid in world.table("hh"):
		var g: Dictionary = world.table("hh")[gid]
		g["income"] = {"wages": 0, "gross": 0, "tax": 0, "benefit": 0, "pension": 0, "dividend": 0}
	_fund_institutions(world)
	_payroll(world)
	_utility_bills(world)
	_rent(world)
	EconConstruction.settle_payments(world)
	_benefits(world)
	_loan_service(world)
	_royalty(world)
	_strategic_subsidy(world)
	_depreciation(world)
	if world.month_of_year() % 3 == 0:
		_profit_tax_and_dividends(world)
	var grant := origin_grant(world.month)
	if grant > 0:
		world.ledger.transfer(Ledger.EXTERNAL, EconUtil.TREASURY, grant, "GRANT", world.month)
		_gov_rev(world, grant)
	if world.month == EconData.ORIGIN_GRANT_TAPER_END:
		EconFacts.emit(world, "ECON_GRANT_ENDED", null, [["EXTERNAL", "origin"]], [["EXTERNAL", "origin", 1.0]], {}, 40, "PUBLIC")
	var fines := world.ledger.balance(EconUtil.FINES)
	if fines > 0:
		world.ledger.transfer(EconUtil.FINES, EconUtil.TREASURY, fines, "SWEEP", world.month)
		_gov_rev(world, fines)
	if world.month_of_year() == 12:
		_bank_remit(world)
	var h: Array = s["gov_rev_hist"]
	h.append(s["gov_rev_m"])
	while h.size() > 12:
		h.pop_front()
	_publish_w_ref(world)
	_sovereign_check(world)
	EconInsolvency.check_all(world)


static func _fund_institutions(world: WorldState) -> void:
	for oid in EconUtil.sorted_keys(world.table("org")):
		var o: Dictionary = world.table("org")[oid]
		if o["type"] != "PUBLIC_INSTITUTION":
			continue
		var lever_id: String = EconData.INSTITUTION_BUDGET.get(o["key"], "")
		if lever_id == "":
			continue
		var monthly := int(EconUtil.lever(world, lever_id, 0)) * 1000 * S / 12
		# top up to one month of budget (unspent cash counts), so institutions never hoard
		var need := monthly - world.ledger.balance(EconUtil.acct(oid))
		if need > 0:
			var paid := gov_pay(world, EconUtil.acct(oid), need, "BUDGET_TRANSFER")
			_spend_line(world, lever_id, paid)
			if paid < need:
				EconUtil.st(world)["treasury_short"] = true  # the treasury itself could not fund appropriated public wages


const CAPEX_LINES := ["ECON_BUDGET_INFRASTRUCTURE", "ECON_BUDGET_HOUSING", "ECON_BUDGET_PUBLIC_WORKS", "FOUNDING"]


static func _spend_line(world: WorldState, lever_id: String, amount: int) -> void:
	var s := EconUtil.st(world)
	s["spent_ytd"][lever_id] = s["spent_ytd"].get(lever_id, 0) + amount
	s["gov_spend_m"] = s.get("gov_spend_m", 0) + amount
	if lever_id in CAPEX_LINES:
		s["gov_capex_m"] = s.get("gov_capex_m", 0) + amount


## Wage paid to one slot tier at an employer (mcr per worker-month).
static func wage_for(world: WorldState, org_id: String, t: String) -> int:
	var w := EconLabor.offer(world, org_id, t)
	var safety: String = str(EconUtil.lever(world, "LAW_SAFETY_STANDARD", "BASIC"))
	var mult := 1.0 + (0.03 if safety == "STANDARD" else (0.07 if safety == "STRICT" else 0.0))
	return int(w * mult)


static func _payroll(world: WorldState) -> void:
	var hh := world.table("hh")
	var rate := float(EconUtil.lever(world, "ECON_INCOME_TAX_RATE", 24)) / 100.0
	var allowance := int(EconUtil.lever(world, "ECON_TAX_ALLOWANCE", 300)) * S
	var skilled_bill := 0
	var skilled_n := 0
	var payers: Array = []  # [org_id, staff dict]
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if world.table("org").has(f["org"]):
			payers.append([f["org"], f["staff"]])
	for oid in EconUtil.sorted_keys(world.table("org")):
		var o: Dictionary = world.table("org")[oid]
		if o["is_contractor"]:
			payers.append([oid, o["crew"]])
	for p in payers:
		var oid: String = p[0]
		var staff: Dictionary = p[1]
		var lines: Array = []  # [gid, gross, tax]
		var bill := 0
		for t in staff:
			var w := wage_for(world, oid, t)
			var tax_pw := int(rate * maxi(0, w - allowance))
			for gid in staff[t]:
				var n: int = staff[t][gid]
				var gross := int(n * w / S)
				var tax := int(n * tax_pw / S)
				lines.append([gid, gross, tax])
				bill += gross
				if t == "S":
					skilled_bill += gross
					skilled_n += n
		if bill == 0:
			continue
		var acc := EconUtil.acct(oid)
		var frac := 1.0
		var have := world.ledger.balance(acc)
		if have < bill:
			frac = maxf(0.0, float(have) / float(bill))
			world.table("org")[oid]["missed_this_month"] = true
		var paid_total := 0
		for ln in lines:
			var gross := int(ln[1] * frac)
			var tax := int(ln[2] * frac)
			var net := gross - tax
			if net > 0:
				world.ledger.transfer(acc, EconUtil.hh_acct(ln[0]), net, "WAGE", world.month)
			if tax > 0:
				world.ledger.transfer(acc, EconUtil.TREASURY, tax, "INCOME_TAX", world.month)
				_gov_rev(world, tax)
			var inc: Dictionary = hh[ln[0]]["income"]
			inc["wages"] += net
			inc["gross"] += gross
			inc["tax"] += tax
			paid_total += gross
		pl_add(world, oid, "wages", paid_total)
	if skilled_n > 0:
		EconUtil.st(world)["w_ref_calc"] = int(float(skilled_bill) * S / float(skilled_n))


static func _publish_w_ref(world: WorldState) -> void:
	var s := EconUtil.st(world)
	if s.has("w_ref_calc"):
		world.values["ECON_W_REF"] = s["w_ref_calc"]


static func _cpw() -> String:
	return "CPW"


static func org_by_key(world: WorldState, key: String) -> String:
	for oid in world.peek("org"):  # pure read
		if world.peek("org")[oid]["key"] == key:
			return oid
	return ""


static func _utility_bills(world: WorldState) -> void:
	var cpw := org_by_key(world, "CPW")
	var te := int(EconUtil.lever(world, "ECON_UTILITY_TARIFF_ENERGY", 40)) * S
	var tw := int(EconUtil.lever(world, "ECON_UTILITY_TARIFF_WATER", 20)) * S
	var s := EconUtil.st(world)
	var used: Dictionary = s.get("util_used", {})  # payer acct -> [energy_mu, water_mu]
	for payer in EconUtil.sorted_keys(used):
		var u: Array = used[payer]
		var amt := EconUtil.val(u[0], te) + EconUtil.val(u[1], tw)
		if payer == EconUtil.acct(cpw) or amt <= 0:
			continue
		var paid := EconUtil.pay_upto(world, payer, EconUtil.acct(cpw), amt, "UTILITY")
		pl_add(world, cpw, "rev", paid)
		if payer.begins_with("co:"):
			var oid: String = payer.substr(3)
			pl_add(world, oid, "util", paid)
			if paid < amt:
				world.table("org")[oid]["missed_this_month"] = true
		elif payer.begins_with("hh:"):
			world.table("hh")[payer.substr(3)]["util_paid"] = paid
	s["util_used"] = {}


## District average rent per household (mcr), weighted by units of public vs private landlords.
static func district_rent(world: WorldState, d: String) -> int:
	var pub := int(EconUtil.lever(world, "ECON_PUBLIC_RENT", 250)) * S
	var units_pub := 0
	var units_priv := 0
	for fid in world.table("facility"):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] != "HOUSING" or f["district"] != d or f["mothball"]:
			continue
		var o: Dictionary = world.table("org").get(f["org"], {})
		if o.get("type", "") in EconData.PUBLIC_TYPES:
			units_pub += 50
		else:
			units_priv += 50
	if units_pub + units_priv == 0:
		return 0
	var priv: int = world.table("district")[d]["rent_private"]
	return int((float(units_pub) * pub + float(units_priv) * priv) / float(units_pub + units_priv))


static func _rent(world: WorldState) -> void:
	var landlords := {}  # d -> {org: units}
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] == "HOUSING" and not f["mothball"] and world.table("org").has(f["org"]):
			if not landlords.has(f["district"]):
				landlords[f["district"]] = {}
			landlords[f["district"]][f["org"]] = landlords[f["district"]].get(f["org"], 0) + 50
	var arrears := {}
	for gid in EconUtil.sorted_keys(world.table("hh")):
		var g: Dictionary = world.table("hh")[gid]
		var d: String = g["district"]
		if not landlords.has(d):
			g["rent_paid"] = 0
			continue
		var households := EconHouseholds.households(g)
		var due := int(households * district_rent(world, d) / S)
		var l: Dictionary = landlords[d]
		var total_units := 0
		for o in l:
			total_units += l[o]
		var paid := 0
		var have := world.ledger.balance(EconUtil.hh_acct(gid))
		var payable := mini(due, have)
		var orgs := EconUtil.sorted_keys(l)
		var parts := EconUtil.split_lr(payable, orgs.map(func(o): return float(l[o])))
		for i in orgs.size():
			if parts[i] > 0:
				world.ledger.transfer(EconUtil.hh_acct(gid), EconUtil.acct(orgs[i]), parts[i], "RENT", world.month)
				pl_add(world, orgs[i], "rev", parts[i])
				paid += parts[i]
		g["rent_paid"] = paid
		g["rent_due"] = due
		if paid < due:
			arrears[d] = arrears.get(d, 0) + (due - paid)
	EconUtil.st(world)["rent_arrears"] = arrears


static func _benefits(world: WorldState) -> void:
	var s := EconUtil.st(world)
	var wg: int = s["wage"]["G"]
	var brate := float(EconUtil.lever(world, "ECON_UNEMPLOYMENT_BENEFIT_RATE", 40)) / 100.0
	var dur := maxi(1, int(EconUtil.lever(world, "ECON_BENEFIT_DURATION", 12)))
	var prate := float(EconUtil.lever(world, "ECON_PENSION_RATE", 35)) / 100.0
	# E63 food assistance (demand floor): top up groups whose cash cannot buy their food need at current prices
	var fa := float(EconUtil.lever(world, "ECON_FOOD_ASSISTANCE", 100)) / 100.0
	var food_price := float(s["prices"]["FOOD"]) * 1.1 * (1.0 + float(EconUtil.lever(world, "ECON_SALES_TAX", 0)) / 100.0)
	for gid in EconUtil.sorted_keys(world.table("hh")):
		var g: Dictionary = world.table("hh")[gid]
		if fa <= 0.0:
			break
		var need := int(float(EconHouseholds.persons(g)) / S * EconData.NEED["FOOD"] * food_price * fa)
		var gap := need - world.ledger.balance(EconUtil.hh_acct(gid))
		if gap > 0:
			var paid := gov_pay(world, EconUtil.hh_acct(gid), gap, "FOOD_ASSISTANCE")
			g["income"]["benefit"] += paid
			s["gov_spend_m"] = s.get("gov_spend_m", 0) + paid
	for gid in EconUtil.sorted_keys(world.table("hh")):
		var g: Dictionary = world.table("hh")[gid]
		var unemp := maxi(0, g["lf"] - EconLabor.employed(g))
		# long-term unemployed stock: inflow 1/duration of the short-term stock, capped by current unemployment
		g["unemp_long"] = mini(unemp, g["unemp_long"] + (unemp - g["unemp_long"]) / dur)
		var short: int = unemp - g["unemp_long"]
		var ben := int((float(short) + 0.5 * float(g["unemp_long"])) * brate * wg / S)
		# E70 benefit floor: each unemployed adult receives at least ECON_BENEFIT_FLOOR % of an adult's essentials basket
		var floor_pct := float(EconUtil.lever(world, "ECON_BENEFIT_FLOOR", 50)) / 100.0
		if floor_pct > 0.0 and unemp > 0:
			var ess_pa := float(EconHouseholds.essentials_cost(world, g)) / maxf(1.0, float(EconHouseholds.adults(g)) / S)
			ben = maxi(ben, int(floor_pct * ess_pa * float(unemp) / S))
		var pen := int(float(g["retired"]) * prate * wg / S)
		if ben > 0:
			var paid := gov_pay(world, EconUtil.hh_acct(gid), ben, "BENEFIT")
			if paid < ben:
				s["treasury_short"] = true
			g["income"]["benefit"] += paid
			s["gov_spend_m"] = s.get("gov_spend_m", 0) + paid
		if pen > 0:
			var paidp := gov_pay(world, EconUtil.hh_acct(gid), pen, "PENSION")
			g["income"]["pension"] += paidp
			s["gov_spend_m"] = s.get("gov_spend_m", 0) + paidp


static func _loan_service(world: WorldState) -> void:
	var s := EconUtil.st(world)
	for lid in EconUtil.sorted_keys(world.table("loan")):
		var l: Dictionary = world.table("loan")[lid]
		if l["principal"] <= 0:
			continue
		var r := float(l["rate_ppm"]) / 1000000.0
		if l["borrower"] == "gov":
			var ratio := float(l["principal"]) / float(maxi(1, gov_revenue_12m(world)))
			if ratio > 1.0:
				r += 0.0025
			var interest := int(l["principal"] * r)
			var have := world.ledger.balance(EconUtil.TREASURY)
			var paid := EconUtil.pay_upto(world, EconUtil.TREASURY, EconUtil.BANK, interest, "LOAN_SERVICE")
			s["bank_profit_ytd"] += paid
			s["gov_spend_m"] = s.get("gov_spend_m", 0) + paid
			if paid < interest:
				s["gov_missed_debt"] += 1
			else:
				s["gov_missed_debt"] = 0
			continue
		var interest := int(l["principal"] * r)
		var n := maxi(1, l["term_left"])
		var annuity: int = int(l["principal"] * r / (1.0 - pow(1.0 + r, -n))) if r > 0 else l["principal"] / n
		var principal_part := clampi(annuity - interest, 0, l["principal"])
		var acc := EconUtil.acct(l["borrower"])
		var due := interest + principal_part
		if world.ledger.balance(acc) >= due:
			world.ledger.transfer(acc, EconUtil.BANK, due, "LOAN_SERVICE", world.month)
			l["principal"] -= principal_part
			l["term_left"] = maxi(0, l["term_left"] - 1)
			l["missed"] = 0
			s["bank_profit_ytd"] += interest
			pl_add(world, l["borrower"], "interest", interest)
		else:
			l["missed"] += 1
			if world.table("org").has(l["borrower"]):
				world.table("org")[l["borrower"]]["missed_this_month"] = true


## E65 lever ECON_STRATEGIC_SUBSIDY_RATE: % of sales value paid to private MINERAL/MATERIAL producers (SUBSIDIES line).
static func _strategic_subsidy(world: WorldState) -> void:
	var s := EconUtil.st(world)
	var rate := float(EconUtil.lever(world, "ECON_STRATEGIC_SUBSIDY_RATE", 0)) / 100.0
	var sales: Dictionary = s.get("strategic_sales_by", {})
	s["strategic_sales_by"] = {}
	if rate <= 0.0:
		return
	var room := EconActions.headroom(world, "ECON_BUDGET_SUBSIDIES")
	for oid in EconUtil.sorted_keys(sales):
		var due := mini(int(float(sales[oid]) * rate), room)
		if due <= 0:
			break
		var paid := gov_pay(world, EconUtil.acct(oid), due, "SUBSIDY")
		_spend_line(world, "ECON_BUDGET_SUBSIDIES", paid)
		pl_add(world, oid, "subsidy", paid)
		room -= paid


static func _royalty(world: WorldState) -> void:
	var s := EconUtil.st(world)
	var rate := float(EconUtil.lever(world, "LAW_EXTRACTION_ROYALTY", 800)) / 10000.0  # law lever in basis points
	var sales: Dictionary = s.get("mineral_sales_by", {})
	for oid in EconUtil.sorted_keys(sales):
		var due := int(sales[oid] * rate)
		var paid := EconUtil.pay_upto(world, EconUtil.acct(oid), EconUtil.TREASURY, due, "ROYALTY")
		_gov_rev(world, paid)
		pl_add(world, oid, "royalty", paid)
	s["mineral_sales_by"] = {}


static func _profit_tax_and_dividends(world: WorldState) -> void:
	var rate := float(EconUtil.lever(world, "ECON_PROFIT_TAX_RATE", 20)) / 100.0
	var pe_div := float(EconUtil.lever(world, "ECON_PE_DIVIDEND_RATE", 50)) / 100.0
	for oid in EconUtil.sorted_keys(world.table("org")):
		var o: Dictionary = world.table("org")[oid]
		if o["type"] == "PUBLIC_INSTITUTION" or o["status"] in ["LIQUIDATION", "DISSOLVED"]:
			o["profit_q"] = 0
			continue
		var p: int = o["profit_q"]
		var acc := EconUtil.acct(oid)
		var taxable: int = p - o["tax_loss_cf"]
		var tax := 0
		if taxable > 0:
			tax = EconUtil.pay_upto(world, acc, EconUtil.TREASURY, int(taxable * rate), "PROFIT_TAX")
			_gov_rev(world, tax)
			o["tax_loss_cf"] = 0
		else:
			o["tax_loss_cf"] = -taxable  # remaining loss carried forward indefinitely (E22)
		var after := p - tax
		o["profit_q"] = 0
		if after <= 0 or o["status"] != "ACTIVE":
			continue
		var monthly_costs := maxi(1, _monthly_costs(o))
		if o["type"] == "PUBLIC_ENTERPRISE":
			var d := mini(int(after * pe_div), maxi(0, world.ledger.balance(acc) - monthly_costs))
			if d > 0:
				world.ledger.transfer(acc, EconUtil.TREASURY, d, "DIVIDEND", world.month)
				_gov_rev(world, d)
		elif o["type"] == "PRIVATE" and o["owner_group"] != "":
			if world.ledger.balance(acc) >= 3 * monthly_costs:
				var d := int(after * 0.5)
				world.ledger.transfer(acc, EconUtil.hh_acct(o["owner_group"]), d, "DIVIDEND", world.month)
				world.table("hh")[o["owner_group"]]["income"]["dividend"] += d
		elif o["type"] == "COOPERATIVE":
			if world.ledger.balance(acc) >= 3 * monthly_costs:
				var d := int(after * 0.3)
				var members := _member_groups(world, oid)
				var keys := EconUtil.sorted_keys(members)
				var parts := EconUtil.split_lr(d, keys.map(func(k): return float(members[k])))
				for i in keys.size():
					if parts[i] > 0:
						world.ledger.transfer(acc, EconUtil.hh_acct(keys[i]), parts[i], "DIVIDEND", world.month)
						world.table("hh")[keys[i]]["income"]["dividend"] += parts[i]


static func _member_groups(world: WorldState, oid: String) -> Dictionary:
	var m := {}
	for fid in world.table("facility"):
		var f: Dictionary = world.table("facility")[fid]
		if f["org"] == oid:
			for t in f["staff"]:
				for gid in f["staff"][t]:
					m[gid] = m.get(gid, 0) + f["staff"][t][gid]
	var o: Dictionary = world.table("org")[oid]
	for t in o["crew"]:
		for gid in o["crew"][t]:
			m[gid] = m.get(gid, 0) + o["crew"][t][gid]
	return m


static func _monthly_costs(o: Dictionary) -> int:
	var pl: Dictionary = o["pl_last"] if not o["pl_last"].is_empty() else o["pl"]
	return pl.get("wages", 0) + pl.get("cogs", 0) + pl.get("util", 0) + pl.get("freight", 0) + pl.get("interest", 0)


static func _depreciation(world: WorldState) -> void:
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		var dep: int = f["book"] / maxi(1, EconData.DEPRECIATION_MONTHS)
		if dep <= 0:
			continue
		f["book"] -= dep
		pl_add(world, f["org"], "dep", dep)
	for oid in world.table("org"):
		var o: Dictionary = world.table("org")[oid]
		o["profit_q"] += profit(o["pl"])


static func _bank_remit(world: WorldState) -> void:
	var s := EconUtil.st(world)
	var r := int(s["bank_profit_ytd"] * 0.5)
	if r > 0:
		EconUtil.pay_upto(world, EconUtil.BANK, Ledger.EXTERNAL, r, "REMITTANCE")
	s["bank_profit_ytd"] = 0


static func _sovereign_check(world: WorldState) -> void:
	var s := EconUtil.st(world)
	if s["sovereign_default"]:
		return
	# only a treasury shortfall counts (an institution under-budgeted by its own line is not a sovereign default)
	var short: bool = s.get("treasury_short", false)
	s["treasury_short"] = false
	s["gov_missed_wages"] = s.get("gov_missed_wages", 0) + 1 if short else 0
	if s["gov_missed_debt"] >= 2 or s.get("gov_missed_wages", 0) >= 3:
		s["sovereign_default"] = true
		EconFacts.emit(world, "ECON_SOVEREIGN_DEFAULT", null, [["GOVERNMENT", "government"]], [["GOVERNMENT", "government", 1.0]],
			{"GOVERNANCE": -60, "JOBS": -10, "COST_OF_LIVING": -10}, 100, "PUBLIC")

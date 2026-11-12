class_name EconEssentials
extends RefCounted
## E110 (user decision A39): governments secure the essentials.
## - measure(): capacity vs demand for FOOD, ENERGY, WATER, MATERIAL, COMPONENT (one definition shared by the
##   planners and EconQuery.essentials).
## - The Colony Agricultural Board (key "CAB"): a public enterprise founded the first time the state needs a farm
##   (planner of last resort for food, or a commissioned FARM). Its investments are financed like CPW's.
## - Incentive offers (ECON_OFFER_INCENTIVE): a grant of grant_pct % of the build price, paid from
##   ECON_BUDGET_SUBSIDIES when a private plant of that type is completed while the offer is open (up to `cap`).
##   An open offer counts as co-financing in E102 (lower scarcity threshold).
## - labour_fill(): expected crew fill for a new plant, from the unemployed by skill (planners skip plants they
##   cannot staff — "fewer, better-staffed plants").

const S := EconUtil.S
const GOODS := ["FOOD", "ENERGY", "WATER", "MATERIAL", "COMPONENT"]
const PLANT := {"FOOD": "FARM", "ENERGY": "POWER", "WATER": "WATERWORKS", "MATERIAL": "PROCESSING", "COMPONENT": "COMPONENTS"}
const INCENTIVE_TYPES := ["FARM", "PROCESSING", "COMPONENTS", "POWER", "WATERWORKS", "HOUSING"]
const INCENTIVE_PCT := [10, 50]
const INCENTIVE_MONTHS := [6, 60]
const HIST := 13  # months of margin history kept (trend = now vs 12 months ago)
const MIN_LABOUR_FILL := 0.5  # a planner builds only if at least half the new crew can be hired from the unemployed
const OVERBUILT_PCT := 50  # E115b: no new capacity above this margin over demand ...
const OVERBUILT_FALL := 25  # ... unless the margin fell by more than this many points in a year


## {good: {capacity, demand, margin_pct}} in display units per month. margin_pct = 100 × (capacity / demand − 1).
## FOOD demand is household NEED (rationing at high prices hides demand from the market), utilities use metered
## demand, MATERIAL/COMPONENT the smoothed wanted quantity. Pure read.
static func measure(world: WorldState) -> Dictionary:
	var s := EconUtil.peek_st(world)
	var cap := {}
	for g in GOODS:
		cap[g] = 0.0
	for fid in EconUtil.sorted_keys(world.peek("facility")):
		var f: Dictionary = world.peek("facility")[fid]
		var r: Dictionary = EconData.RECIPES.get(f["type"], {})
		if r.is_empty() or f["mothball"] or f.get("closed_unsafe", false):
			continue
		var g: String = r["out"][0]
		if not cap.has(g):
			continue
		var per := 1200.0 if g == "ENERGY" else (1500.0 if g == "WATER" else float(r["out"][1]))
		cap[g] += per * EconUtil.fscale(f) * EconProduction._eff(world, f) * EconUtil.tier_out(f)
	var dem := {
		"FOOD": float(PopStore.total(world)) * float(EconData.NEED["FOOD"]),
		"ENERGY": float(s.get("util_demand", {}).get("E", 0)) / S,
		"WATER": float(s.get("util_demand", {}).get("W", 0)) / S,
		"MATERIAL": float(s.get("wanted_ema", {}).get("MATERIAL", 0)) / S,
		"COMPONENT": float(s.get("wanted_ema", {}).get("COMPONENT", 0)) / S}
	# E115a: the market only sees what is bought; owners that supply themselves (CPW runs mines, smelters and
	# component works and uses their output for its own upkeep and inputs) never bid. Real use is everything burned
	# (production inputs, upkeep, construction), smoothed; demand is the larger of the two.
	if not EconUtil.off(world, "E115"):
		for g2 in ["MATERIAL", "COMPONENT"]:
			dem[g2] = maxf(dem[g2], float(s.get("use_ema", {}).get(g2, 0)) / S)
	var out := {}
	for g in GOODS:
		out[g] = {"capacity": cap[g], "demand": dem[g],
			"margin_pct": 100.0 * (cap[g] / dem[g] - 1.0) if dem[g] > 0.0 else 100.0}
	return out


## Monthly (COMPANY_AI): keep margin history for the trend.
static func record(world: WorldState) -> void:
	var s := EconUtil.st(world)
	# E115a: monthly use (cumulative burned → delta), smoothed like wanted_ema
	var ue: Dictionary = s.get("use_ema", {})
	var prev: Dictionary = s.get("use_prev", {})
	for g2 in ["MATERIAL", "COMPONENT"]:
		var burned := int(s.get("qflow", {}).get(g2, {}).get("burned", 0))
		if prev.has(g2):
			var used := float(maxi(0, burned - int(prev[g2])))
			ue[g2] = int(0.9 * float(ue.get(g2, used)) + 0.1 * used)
		prev[g2] = burned
	s["use_ema"] = ue
	s["use_prev"] = prev
	var h: Dictionary = s.get("ess_hist", {})
	s["ess_hist"] = h
	var m := measure(world)
	for g in GOODS:
		var a: Array = h.get(g, [])
		a.append(int(round(m[g]["margin_pct"])))
		while a.size() > HIST:
			a.pop_front()
		h[g] = a


## Margin change in percentage points over the last 12 months (0 if not enough history).
static func trend(world: WorldState, good: String) -> int:
	var a: Array = EconUtil.peek_st(world).get("ess_hist", {}).get(good, [])
	if a.size() < 2:
		return 0
	return int(a[a.size() - 1]) - int(a[0])


## E115b: capacity is well above demand (margin > OVERBUILT_PCT) and not falling fast: no new plant or expansion
## of this good. Reads the margin recorded this month (no history → false).
static func overbuilt(world: WorldState, good: String) -> bool:
	if EconUtil.off(world, "E115") or not good in GOODS:
		return false
	var a: Array = EconUtil.peek_st(world).get("ess_hist", {}).get(good, [])
	if a.is_empty():
		return false
	return int(a[a.size() - 1]) > OVERBUILT_PCT and trend(world, good) > -OVERBUILT_FALL


## Expected fill (0..1) of a new plant's crew from the unemployed, worst skill tier.
static func labour_fill(world: WorldState, ftype: String) -> float:
	var fill := 1.0
	var lab: Dictionary = EconData.RECIPES[ftype]["labor"]
	for t in lab:
		var need := float(lab[t])
		if need <= 0.0:
			continue
		var free := float(PopStore.count(world, {"status": "UNEMPLOYED"}, "skill:" + t))
		fill = minf(fill, free / need)
	return clampf(fill, 0.0, 1.0)


## True while a human player governs (GovBuilder._actor is empty): automatic public investment may then not spend
## treasury money ("nothing built behind a human government's back"). Econ-only sims (no politics): false.
static func human_governs(world: WorldState) -> bool:
	var pol: Dictionary = world.peek("pol")
	if pol.is_empty() or not pol.has("state"):
		return false
	return GovBuilder._actor(world, pol["state"]).is_empty()


# ---------------------------------------------------------------- Colony Agricultural Board

## The Board's org id; founds it (no capital: the treasury finances its investments) on first use.
static func ag_board(world: WorldState) -> String:
	var oid := EconFinance.org_by_key(world, "CAB")
	if oid != "":
		return oid
	oid = world.new_id("org")
	world.table("org")[oid] = {"id": oid, "key": "CAB", "name": "Colony Agricultural Board", "type": "PUBLIC_ENTERPRISE", "hq": "d:2",
		"status": "ACTIVE", "ceo": {"mgmt": 55, "risk": 20, "age_m": 48 * 12}, "reliability": 0, "is_contractor": false,
		"crew": {}, "crew_target": {}, "premium_m": {"G": 0, "S": 0, "Sp": 0}, "tax_loss_cf": 0, "profit_q": 0,
		"pl": EconFinance.empty_pl(), "pl_last": {}, "missed_streak": 0, "ok_streak": 0, "low_cash_streak": 0, "distress_months": 0,
		"admin_months": 0, "liq_months": 0, "missed_this_month": false, "owner_group": "", "sales_ema": {}, "contracts": [],
		"dividends_ytd": 0, "sold": {}}
	world.ledger.open_account(EconUtil.acct(oid))
	EconFacts.emit(world, "COMP_COMPANY_FOUNDED", "d:2", [["COMPANY", oid], ["GOVERNMENT", "government"]],
		[["GOVERNMENT", "government", 1.0]], {"JOBS": 2}, 30, "PUBLIC", {"type": "FARM", "public": true})
	return oid


## Operator for a state-commissioned plant: the Board for farms, else the EconActions.OPERATOR table.
static func operator_for(world: WorldState, ftype: String) -> String:
	if ftype == "FARM":
		return ag_board(world)
	return EconFinance.org_by_key(world, EconActions.OPERATOR.get(ftype, "CPW"))


# ---------------------------------------------------------------- incentives

## Open offers: {type: {grant_pct, until, cap, paid}} (cap/paid in milli).
static func offers(world: WorldState) -> Dictionary:
	var out := {}
	var tbl: Dictionary = EconUtil.peek_st(world).get("incentives", {})
	for t in EconUtil.sorted_keys(tbl):
		var o: Dictionary = tbl[t]
		if world.month <= int(o["until"]) and int(o["paid"]) < int(o["cap"]):
			out[t] = o
	return out


static func offer_open(world: WorldState, ftype: String) -> bool:
	return offers(world).has(ftype)


static func validate_offer(world: WorldState, p: Dictionary) -> String:
	var t: String = str(p.get("type", ""))
	if not t in INCENTIVE_TYPES:
		return "Incentives are for %s" % ", ".join(INCENTIVE_TYPES)
	var pct := int(p.get("grant_pct", 0))
	if pct < INCENTIVE_PCT[0] or pct > INCENTIVE_PCT[1]:
		return "Grant must be %d–%d %% of the build price" % INCENTIVE_PCT
	var months := int(p.get("months", 0))
	if months < INCENTIVE_MONTHS[0] or months > INCENTIVE_MONTHS[1]:
		return "An offer runs %d–%d months" % INCENTIVE_MONTHS
	if int(p.get("cap", 0)) <= 0:
		return "Set a cap (credits) on the total grant"
	return ""


static func apply_offer(world: WorldState, p: Dictionary) -> bool:
	if validate_offer(world, p) != "":
		return false
	var s := EconUtil.st(world)
	var tbl: Dictionary = s.get("incentives", {})
	s["incentives"] = tbl
	var t: String = p["type"]
	tbl[t] = {"grant_pct": int(p["grant_pct"]), "until": world.month + int(p["months"]), "cap": int(p["cap"]) * S, "paid": 0,
		"offered_month": world.month}
	EconFacts.emit(world, "ECON_INCENTIVE_OFFERED", null, [["GOVERNMENT", "government"]], [["GOVERNMENT", "government", 1.0]],
		{"JOBS": 2, "INFRASTRUCTURE": 2}, 25, "PUBLIC", {"type": t, "grant_pct": int(p["grant_pct"]), "months": int(p["months"]),
		"cap": int(p["cap"])})
	return true


## Called when a project completes: pays the grant to a private owner if an offer for its type is open.
static func on_complete(world: WorldState, p: Dictionary) -> void:
	var owner: String = p["owner"]
	if owner == "gov" or not world.table("org").has(owner) or world.table("org")[owner]["type"] == "PUBLIC_ENTERPRISE":
		return
	var t: String = p["type"]
	if not offer_open(world, t):
		return
	var o: Dictionary = EconUtil.st(world)["incentives"][t]
	var amt := mini(int(p["price"]) * int(o["grant_pct"]) / 100, int(o["cap"]) - int(o["paid"]))
	amt = mini(amt, maxi(0, EconActions.headroom(world, "ECON_BUDGET_SUBSIDIES")))
	if amt <= 0:
		return
	var paid := EconFinance.gov_pay(world, EconUtil.acct(owner), amt, "INCENTIVE")
	EconFinance._spend_line(world, "ECON_BUDGET_SUBSIDIES", paid)
	EconFinance.pl_add(world, owner, "subsidy", paid)
	o["paid"] = int(o["paid"]) + paid
	EconFacts.emit(world, "ECON_INCENTIVE_CLAIMED", p["district"], [["GOVERNMENT", "government"], ["COMPANY", owner]],
		[["GOVERNMENT", "government", 0.6], ["COMPANY", owner, 0.4]], {"JOBS": 3, "INFRASTRUCTURE": 3}, 30, "PUBLIC",
		{"type": t, "project": p["id"], "amount": paid / S})

class_name EconQuery
extends RefCounted
## Read-only accessors for the M5 economy panels (planning/ui-econ.md). Never mutates WorldState.
## Returns display units: credits as floats, quantities as floats, percentages 0..100.
## Visibility: fields marked "official" are government-only (pic-core §3 OFFICIAL); the UI hides them in opposition.

const S := 1000.0

const LINE_LABELS := {
	"ECON_BUDGET_ADMIN": "Administration", "ECON_BUDGET_HEALTH": "Health", "ECON_BUDGET_EDUCATION": "Education",
	"ECON_BUDGET_TRAINING": "Training", "ECON_BUDGET_INFRASTRUCTURE": "Infrastructure", "ECON_BUDGET_HOUSING": "Public housing",
	"ECON_BUDGET_SUBSIDIES": "Subsidies", "ECON_BUDGET_PUBLIC_WORKS": "Public works (counter-cyclical)", "ECON_BUDGET_PUBLIC_EMPLOYMENT": "Public employment scheme", "ECON_BUDGET_RESERVE_PURCHASES": "Strategic reserve",
}


static func _cr(v) -> float:
	return float(v) / S


# =========================================================================  budget view

## Treasury, debt, budget lines, 12-month revenue and spending by category.
static func budget_view(world: WorldState) -> Dictionary:
	var lines: Array = []
	for lid in LINE_LABELS:
		lines.append({"lever": lid, "label": LINE_LABELS[lid], "annual": float(world.levers.get(lid, 0)) * 1000.0,
			"spent_ytd": _cr(EconUtil.peek_st(world)["spent_ytd"].get(lid, 0)), "headroom": _cr(EconActions.headroom(world, lid))})
	var rev := {}
	var out := {}
	for e in world.ledger.journal:
		if e["m"] < world.month - 12:
			continue
		var reason: String = e["memo"].split("#")[0]
		if e["to"] == EconUtil.TREASURY:
			rev[reason] = rev.get(reason, 0.0) + _cr(e["amt"])
		elif e["from"] == EconUtil.TREASURY:
			out[reason] = out.get(reason, 0.0) + _cr(e["amt"])
	var ind := world.indicators
	return {
		"treasury": _cr(world.ledger.balance(EconUtil.TREASURY)),
		"debt": _cr(EconFinance.debt_of(world, "gov")),
		"credit_headroom": _cr(EconFinance.gov_credit_headroom(world)),
		"runway_months": ind.read("ECON_TREASURY_RUNWAY") / S,          # official
		"debt_ratio_pct": ind.read("ECON_PUBLIC_DEBT_RATIO") / S,
		"balance_pct": ind.read("ECON_BUDGET_BALANCE") / S,
		"operating_balance_pct": ind.read("ECON_OPERATING_BALANCE") / S,  # official
		"grant_this_month": _cr(EconFinance.origin_grant(world.month)),
		"lines": lines,
		"revenue_12m": rev,
		"spending_12m": out,
		"tax_levers": {"income": world.levers.get("ECON_INCOME_TAX_RATE", 0), "allowance": world.levers.get("ECON_TAX_ALLOWANCE", 0),
			"profit": world.levers.get("ECON_PROFIT_TAX_RATE", 0), "tariff": world.levers.get("ECON_IMPORT_TARIFF", 0)},
	}


# =========================================================================  procurement

## Open and failed tenders, each with ranked bids (see bid_breakdown).
static func tenders(world: WorldState) -> Array:
	var out: Array = []
	for pid in EconUtil.sorted_keys(world.peek("project")):
		var p: Dictionary = world.peek("project")[pid]
		if p["status"] in ["TENDER", "TENDERABLE"]:
			out.append({"project": pid, "type": p["type"], "district": p["district"], "owner": p["owner"], "status": p["status"],
				"est_cost": _cr(p["est_cost"]), "min_months": p["min_months"], "size_class": p["size_class"],
				"tender_month": p["tender_month"], "bids": bid_breakdown(world, pid)})
	return out


## Score breakdown per bid (spec §10.2): price/reliability/duration parts, plus the contractor's distress flag (official).
static func bid_breakdown(world: WorldState, pid: String) -> Array:
	var p: Dictionary = world.peek("project")[pid]
	var wp := float(world.levers.get("ECON_PROCUREMENT_PRICE_WEIGHT", 50)) / 100.0
	var wr := 0.6 * (1.0 - wp)
	var wd := 0.4 * (1.0 - wp)
	var ranked := EconConstruction.ranked_bids(world, p)
	if ranked.is_empty():
		return []
	var min_price: float = INF
	var min_dur := 1 << 30
	for b in ranked:
		min_price = minf(min_price, float(b["price"]))
		min_dur = mini(min_dur, b["duration"])
	var out: Array = []
	for i in ranked.size():
		var b: Dictionary = ranked[i]
		var o: Dictionary = world.peek("org")[b["org"]]
		out.append({"rank": i + 1, "org": b["org"], "name": o["name"], "price": _cr(b["price"]), "duration": b["duration"],
			"reliability": b["reliability"], "score": b["score"] / S,
			"price_part": wp * min_price / float(b["price"]), "reliability_part": wr * float(b["reliability"]) / 100.0,
			"duration_part": wd * float(min_dur) / float(b["duration"]), "distressed": o["status"] != "ACTIVE"})
	return out


## Active and recent projects with progress, payments, delay and the main blocker.
static func projects(world: WorldState, owner: String = "gov") -> Array:
	var out: Array = []
	for pid in EconUtil.sorted_keys(world.peek("project")):
		var p: Dictionary = world.peek("project")[pid]
		if owner != "" and p["owner"] != owner:
			continue
		var late := 0
		if p["start_month"] >= 0 and p["status"] == "ACTIVE":
			late = maxi(0, world.month - (p["start_month"] + p["bid_duration"]))
		out.append({"project": pid, "type": p["type"], "district": p["district"], "status": p["status"],
			"progress_pct": 100.0 * float(p["wu_done"]) / maxf(1.0, float(p["wu_total"])), "contractor": p["contractor"],
			"price": _cr(p["price"]), "paid": _cr(p["paid"]), "months_late": late, "supervision": p["supervision"] / S,
			"blockers": explain_project(world, pid) if p["status"] == "ACTIVE" else []})
	return out


# =========================================================================  companies

## Company directory. Financial columns are official (government) data.
static func companies(world: WorldState, include_dissolved: bool = false) -> Array:
	var out: Array = []
	for oid in EconUtil.sorted_keys(world.peek("org")):
		var o: Dictionary = world.peek("org")[oid]
		if o["status"] == "DISSOLVED" and not include_dissolved:
			continue
		var sectors := {}
		var employees := EconLabor.staff_total(o["crew"])
		for fid in world.peek("facility"):
			var f: Dictionary = world.peek("facility")[fid]
			if f["org"] == oid:
				sectors[f["type"]] = true
				employees += EconLabor.staff_total(f["staff"])
		out.append({"id": oid, "name": o["name"], "type": o["type"], "status": o["status"], "hq": o["hq"],
			"sectors": sectors.keys(), "employees": employees / S, "reliability": o["reliability"],
			"cash": _cr(world.ledger.balance(EconUtil.acct(oid))), "debt": _cr(EconFinance.debt_of(world, oid)),  # official
			"profit_last_month": _cr(EconFinance.profit(o["pl_last"])) if not o["pl_last"].is_empty() else 0.0})   # official
	return out


static func company_profile(world: WorldState, oid: String) -> Dictionary:
	var o: Dictionary = world.peek("org")[oid]
	var facs: Array = []
	for fid in EconUtil.sorted_keys(world.peek("facility")):
		var f: Dictionary = world.peek("facility")[fid]
		if f["org"] == oid:
			facs.append({"id": fid, "type": f["type"], "district": f["district"], "utilization_pct": f["util"] / 10.0,
				"target_pct": f["T"] / 10.0, "staff": EconLabor.staff_total(f["staff"]) / S, "condition": f["condition"] / S,
				"scale": EconUtil.fscale(f), "mothballed": f["mothball"], "licensed": f["licensed"]})
	var pl := {}
	for k in o["pl_last"]:
		pl[k] = _cr(o["pl_last"][k])
	var history: Array = []
	for fct in world.facts.facts:
		for subj in fct["subjects"]:
			if subj.get("id", "") == oid:
				history.append({"month": fct["month"], "type": fct["type"], "fact": fct["id"]})
	return {"id": oid, "name": o["name"], "type": o["type"], "status": o["status"], "hq": o["hq"],
		"ceo": {"management": o["ceo"]["mgmt"], "risk": o["ceo"]["risk"], "age": o["ceo"]["age_m"] / 12},
		"reliability": o["reliability"], "facilities": facs, "crew": EconLabor.staff_total(o["crew"]) / S,
		"contracts": o["contracts"].duplicate(), "pl_last_month": pl, "cash": _cr(world.ledger.balance(EconUtil.acct(oid))),
		"debt": _cr(EconFinance.debt_of(world, oid)), "history": history.slice(-30)}


# =========================================================================  markets & districts

static func market_overview(world: WorldState) -> Array:
	var s := EconUtil.peek_st(world)
	var out: Array = []
	for good in EconData.MARKET_GOODS:
		var ms: Dictionary = s.get("market_stats", {}).get(good, {})
		var sellers := {}
		var tot := 0.0
		for oid in EconUtil.sorted_keys(world.peek("org")):
			var q := float(world.peek("org")[oid].get("sold", {}).get(good, 0))
			if q > 0.0:
				sellers[world.peek("org")[oid]["name"]] = q
				tot += q
		for k in sellers:
			sellers[k] = 100.0 * sellers[k] / tot
		out.append({"good": good, "price": _cr(s["prices"][good]), "base_price": _cr(s["base"][good]),
			"offered": _cr(ms.get("S", 0)), "demand": _cr(ms.get("D", 0)), "wanted": _cr(ms.get("wanted", 0)),
			"filled": _cr(ms.get("filled", 0)), "seller_share_pct": sellers})
	out.append({"good": "ENERGY", "tariff": float(world.levers.get("ECON_UTILITY_TARIFF_ENERGY", 40)),
		"supply": _cr(s.get("util_supply", {}).get("E", 0)), "demand": _cr(s.get("util_demand", {}).get("E", 0))})
	out.append({"good": "WATER", "tariff": float(world.levers.get("ECON_UTILITY_TARIFF_WATER", 20)),
		"supply": _cr(s.get("util_supply", {}).get("W", 0)), "demand": _cr(s.get("util_demand", {}).get("W", 0))})
	return out


## All district-level econ indicators for one district (display units).
static func district_economy(world: WorldState, d: String) -> Dictionary:
	var out := {"district": d, "name": EconData.DISTRICTS.get(d, {}).get("name", d)}
	for id in world.indicators.defs:
		var def: Dictionary = world.indicators.defs[id]
		if def["owner"] == "econ" and def["granularity"] == "DISTRICT":
			out[id] = world.indicators.read(id, d) / S
	var dr: Dictionary = world.peek("district").get(d, {})
	out["households"] = float(dr.get("households", 0)) / S
	out["housing_units"] = float(dr.get("units", 0)) / S
	out["private_rent"] = _cr(dr.get("rent_private", 0))
	return out


# =========================================================================  shortage explainer (econ Rule 10)

## Why is this facility below target? Returns causes sorted by severity (0..1 = share of output lost).
static func explain_facility(world: WorldState, fid: String) -> Dictionary:
	var f: Dictionary = world.peek("facility")[fid]
	var r: Dictionary = EconData.RECIPES[f["type"]]
	var causes: Array = []
	var o: Dictionary = world.peek("org").get(f["org"], {})
	if f["mothball"]:
		causes.append({"cause": "MOTHBALLED", "detail": "Facility idle (low demand, unsafe, or owner in %s)" % o.get("status", "?"), "severity": 1.0})
	if o.get("status", "ACTIVE") != "ACTIVE":
		causes.append({"cause": "OWNER_" + o["status"], "detail": "Operator status %s" % o["status"], "severity": 0.5})
	var t := float(f["T"]) / 1000.0
	if t < 0.95:
		causes.append({"cause": "LOW_DEMAND_TARGET", "detail": "Operator plans %.0f%% of capacity" % (t * 100.0), "severity": 1.0 - t})
	var req := EconLabor.required(f)
	for tier in req:
		if req[tier] > 0:
			var have := float(EconLabor.tier_total(f["staff"], tier))
			if have < float(req[tier]) * 0.95:
				causes.append({"cause": "LABOR_" + tier, "detail": "%d of %d %s workers" % [int(have / S), int(req[tier] / S), tier], "severity": 1.0 - have / float(req[tier])})
	for g in r["in"]:
		if g in EconData.MARKET_GOODS:
			var need := float(r["in"][g]) * S * t * EconUtil.fscale(f)
			var have := float(EconUtil.inv_get(world, f["org"], g, f["district"]))
			if need > 0.0 and have < need:
				causes.append({"cause": "INPUT_" + g, "detail": "%.0f of %.0f %s in stock" % [have / S, need / S, g], "severity": 1.0 - have / need})
	var es := float(f.get("e_served", 1000)) / 1000.0
	var ws := float(f.get("w_served", 1000)) / 1000.0
	if r["in"].has("ENERGY") and es < 0.99:
		causes.append({"cause": "ENERGY_RATIONED", "detail": "Grid served this facility %.0f%% of its demand" % (100.0 * es), "severity": 1.0 - es})
	if r["in"].has("WATER") and ws < 0.99:
		causes.append({"cause": "WATER_RATIONED", "detail": "Network served this facility %.0f%% of its demand" % (100.0 * ws), "severity": 1.0 - ws})
	if f["condition"] < 70 * EconUtil.S:
		causes.append({"cause": "CONDITION", "detail": "Condition %d/100 (upkeep shortfall)" % (f["condition"] / EconUtil.S), "severity": 0.4 - 0.004 * float(f["condition"]) / S})
	if not f["licensed"]:
		causes.append({"cause": "UNLICENSED", "detail": "Operating without a required licence", "severity": 0.1})
	causes.sort_custom(func(a, b): return a["severity"] > b["severity"])
	return {"facility": fid, "type": f["type"], "utilization_pct": f["util"] / 10.0, "causes": causes}


## Why is this project slow? (materials, components, crew, payment, supervision, contractor status)
static func explain_project(world: WorldState, pid: String) -> Array:
	var p: Dictionary = world.peek("project")[pid]
	var causes: Array = []
	if p["contractor"] == "":
		return [{"cause": "NO_CONTRACTOR", "detail": "Status %s, %d bids" % [p["status"], p["bids"].size()], "severity": 1.0}]
	var o: Dictionary = world.peek("org")[p["contractor"]]
	if o["status"] != "ACTIVE":
		causes.append({"cause": "CONTRACTOR_" + o["status"], "detail": o["name"], "severity": 0.6})
	if p["unpaid_m"] >= 2:
		causes.append({"cause": "WORK_SUSPENDED_UNPAID", "detail": "%d months unpaid" % p["unpaid_m"], "severity": 1.0})
	if o.get("blocked_last", false):
		var hq: String = o["hq"]
		causes.append({"cause": "MATERIALS", "detail": "%s holds %.0f MATERIAL, %.0f COMPONENT" % [o["name"],
			EconUtil.inv_get(world, p["contractor"], "MATERIAL", hq) / S, EconUtil.inv_get(world, p["contractor"], "COMPONENT", hq) / S], "severity": 0.7})
	if p["supervision"] < 500:
		causes.append({"cause": "UNSUPERVISED", "detail": "Supervision %.0f%%" % (p["supervision"] / 10.0), "severity": 0.1})
	if p["prog_m"] == 0 and causes.is_empty():
		causes.append({"cause": "NO_PROGRESS", "detail": "Crew %d" % (EconLabor.staff_total(o["crew"]) / EconUtil.S), "severity": 0.5})
	return causes


## Readable causal chain for any fact (pic-core §4 `causes`), newest first.
static func explain_fact(world: WorldState, fact_id: String) -> Array:
	var out: Array = []
	var root := world.facts.get_fact(fact_id)
	if root.is_empty():
		return out
	for f in [root] + world.facts.explain(fact_id):
		out.append({"fact": f["id"], "month": f["month"], "type": f["type"], "location": f["location"], "data": f["data"],
			"responsible": f["responsible"], "magnitude": f["magnitude"]})
	return out


# =========================================================================  actions

## Commission options with enable flag and reason. Each type lists the budget lines allowed to pay for it
## (`lines[]` with headroom); `line` is the first line with room (or the default line if none has room).
static func commission_options(world: WorldState) -> Array:
	var out: Array = []
	for ftype in EconActions.OPERATOR:
		if not EconData.BUILD.has(ftype):
			continue
		var est := EconConstruction.estimate(ftype)
		var lines: Array = []
		var pick := ""
		for ln in EconActions.lines_for(ftype):
			var room := EconActions.headroom(world, ln)
			var ok := room >= est * 11 / 10
			lines.append({"line": ln, "label": LINE_LABELS.get(ln, ln), "headroom": _cr(room), "enabled": ok})
			if ok and pick == "":
				pick = ln
		out.append({"type": ftype, "line": pick if pick != "" else lines[0]["line"], "estimate": _cr(est), "headroom": lines[0]["headroom"] if pick == "" else _cr(EconActions.headroom(world, pick)),
			"lines": lines, "enabled": pick != "", "reason": "" if pick != "" else "no budget line has %s uncommitted this year" % str(int(_cr(est * 11 / 10)))})
	return out


# =========================================================================  shortage list (entry point of the "why?" explainer)

## Goods and utilities that were short last month, worst first, each with its producing facilities and their causes.
## `filled_pct` = share of wanted quantity (market goods) or of demand (ENERGY/WATER) that was supplied.
## E106: kits the state may upgrade (UI and AI government). Pure read.
static func upgrade_options(world: WorldState) -> Array:
	var out: Array = []
	for fid in EconUtil.sorted_keys(world.peek("facility")):
		var f: Dictionary = world.peek("facility")[fid]
		if not (f["type"] in EconData.KIT_TYPES):
			continue
		var tier := int(f.get("tier", 2))
		if tier >= 3:
			continue
		var chk := EconActions.check(world, "ECON_UPGRADE_FACILITY", {"facility": fid})
		out.append({"facility": fid, "type": f["type"], "tier": tier, "next_tier": tier + 1,
			"est_cost": float(EconConstruction.upgrade_estimate(tier + 1)) / S,
			"output_gain_pct": int(round(100.0 * (EconData.TIER_OUT[tier + 1] / EconData.TIER_OUT[tier] - 1.0))),
			"waste_cut_pct": int(round(100.0 * (1.0 - EconData.TIER_IN[tier + 1] / EconData.TIER_IN[tier]))),
			"enabled": chk["ok"], "reason": chk["error"]})
	return out


## E110 (A39): the essentials at a glance, for GovBuilder's food-security response and the UI. Pure read.
## {good: {capacity, demand, margin_pct, trend, labour_fill, incentive}} for FOOD, ENERGY, WATER, MATERIAL, COMPONENT
## (units per month; margin_pct = 100 × (capacity/demand − 1); trend = margin change over 12 months in points;
## labour_fill = expected crew fill 0..1 of one new plant from the unemployed; incentive = open offer or {}),
## plus "HOUSING": {units, households, occupancy_pct}.
static func essentials(world: WorldState) -> Dictionary:
	var m: Dictionary = EconEssentials.measure(world)
	var offers: Dictionary = EconEssentials.offers(world)
	var out := {}
	for g in EconEssentials.GOODS:
		var ftype: String = EconEssentials.PLANT[g]
		var o: Dictionary = offers.get(ftype, {})
		out[g] = {"capacity": m[g]["capacity"], "demand": m[g]["demand"], "margin_pct": int(round(m[g]["margin_pct"])),
			"trend": EconEssentials.trend(world, g), "labour_fill": EconEssentials.labour_fill(world, ftype),
			"incentive": {} if o.is_empty() else {"grant_pct": o["grant_pct"], "until": o["until"], "cap": float(o["cap"]) / S,
				"paid": float(o["paid"]) / S}}
	var units := 0
	var hhs := 0
	for d in EconUtil.sorted_keys(world.peek("district")):
		var dr: Dictionary = world.peek("district")[d]
		units += int(dr.get("units", 0))
		hhs += int(dr.get("households", 0))
	out["HOUSING"] = {"units": float(units) / S, "households": float(hhs) / S, "occupancy_pct": int(round(100.0 * hhs / maxf(1.0, units)))}
	out["SKILLS"] = EconTraining.summary(world)  # E114
	return out


static func shortages(world: WorldState, threshold_pct: float = 97.0) -> Array:
	var s := EconUtil.peek_st(world)
	var out: Array = []
	for good in EconData.MARKET_GOODS:
		var ms: Dictionary = s.get("market_stats", {}).get(good, {})
		var wanted := float(ms.get("wanted", 0))
		if wanted <= 0.0:
			continue
		var pct := 100.0 * float(ms.get("filled", 0)) / wanted
		if pct < threshold_pct:
			out.append({"good": good, "filled_pct": pct, "wanted": wanted / S, "filled": float(ms.get("filled", 0)) / S,
				"price": _cr(s["prices"][good]), "base_price": _cr(s["base"][good]), "producers": _producers(world, good)})
	for pair in [["ENERGY", "E"], ["WATER", "W"]]:
		var dem := float(s.get("util_demand", {}).get(pair[1], 0))
		if dem <= 0.0:
			continue
		var pct := 100.0 * minf(1.0, float(s.get("util_supply", {}).get(pair[1], 0)) / dem)
		if pct < threshold_pct:
			out.append({"good": pair[0], "filled_pct": pct, "wanted": dem / S, "filled": dem * pct / 100.0 / S,
				"price": 0.0, "base_price": 0.0, "producers": _producers(world, pair[0])})
	out.sort_custom(func(a, b): return a["filled_pct"] < b["filled_pct"])
	return out


## Facilities producing `good`, lowest utilization first, with explain_facility causes.
static func _producers(world: WorldState, good: String) -> Array:
	var out: Array = []
	for fid in EconUtil.sorted_keys(world.peek("facility")):
		var f: Dictionary = world.peek("facility")[fid]
		var r: Dictionary = EconData.RECIPES.get(f["type"], {})
		if r.get("out", ["", 0])[0] != good:
			continue
		var ex := explain_facility(world, fid)
		ex["district"] = f["district"]
		ex["owner"] = world.peek("org").get(f["org"], {}).get("name", f["org"])
		out.append(ex)
	out.sort_custom(func(a, b): return a["utilization_pct"] < b["utilization_pct"] or (a["utilization_pct"] == b["utilization_pct"] and a["facility"] < b["facility"]))
	return out


## Recent public econ facts worth a "why?" click (magnitude ≥ min_mag), newest first.
static func recent_econ_facts(world: WorldState, months: int = 6, min_mag: int = 30) -> Array:
	var out: Array = []
	for f in world.facts.facts:
		if f["month"] >= world.month - months and f["magnitude"] >= min_mag and String(f["type"]).begins_with("ECON_"):
			out.append({"fact": f["id"], "month": f["month"], "type": f["type"], "location": f["location"], "data": f["data"], "magnitude": f["magnitude"]})
	out.reverse()
	return out

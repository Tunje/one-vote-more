class_name EconRulesMat
extends RefCounted
## R8 step 2b (Bob; planning/eight-rules.md): the eight rules for the materials chain, MINE (MINERAL), PROCESSING
## (MATERIAL) and COMPONENTS (COMPONENT). Switch R8 + R8_MATERIAL. Kill switches for the A/B take-apart (opt-in names in
## meta "on"): R8M_NOVALUE (value bids), R8M_NOOUT (rules 3/4), R8M_NOCAP (rules 5/6), R8M_NOENTRY (rules 7/8). Price rules 1/2 are opt-in only (R8M_PX): the A/B (planning/ab-r8-materials.md) dropped them; value bids replace
## them (user 2026-11-15: "That's a lot of hard rules, that's just going to lock up price. Why is no one paying the price?").
##
## Why (probe, seeds 1 and 4 × 30 years with E172): the materials markets were in a price deadlock, not short of plants.
## MINERAL sat at its floor (0.25 × base) for twenty years at a fifth of the mines' cost; MATERIAL sold at 0.6–0.7 × the
## smelters' cost while 8–26% of orders went unfilled and 4–6k units piled up. Sellers' ask floor (0.9 × full cost) was
## above buyers' limits (1.3 × price + freight), so stock could not sell, the market read the unsold stock as cover and
## the price kept falling. No plant could earn the margin that _investment and _new_plants wait for.
##
##   1 raise price: unfilled orders > 5% → up by ALPHA × shortage (≤ STEP_UP a month); any unfilled order while the
##     price is below the plants' full cost → creep up STEP a month, up to that cost
##   2 lower price: only with every order filled (≤ 2% unfilled), over 2 months of cover and plants under U_LOW use →
##     down by ALPHA × excess (≤ STEP); never below the plants' variable cost. Otherwise drift toward MARKUP × full cost
##     (E149's target), never down while orders go unfilled
##   3 produce more: a plant adds its capacity share of the unfilled orders it can reach (R8 reach), while its cover is
##     under 2 months
##   4 produce less: below variable cost, the core crew only (the 20% floor)
##   5 add capacity: use ≥ 85% in 6 of the last 12 months and reachable unfilled orders ≥ 5% of its capacity in 6 of the last 12, price ≥
##     1.1 × full cost, the owner not losing money over 12 months (public enterprises exempt), no open project of that
##     owner and type, a crew to be had → +25% (an EXPAND) or, at 3×, a new plant beside it. One step per good a
##     quarter. Replaces _investment, _expansion, _new_plants and the essentials planner for these three types.
##   6 reduce capacity: the old mothball rule, but never while the plant has reachable unfilled orders
##   7/8 a new company / no new company: E170's forecast (EconForecast.first_year) in the best district, profit > 0, no
##     "no_customers" or "competitors"; none while incumbents holding most of the capacity lose money. COMPONENTS gets an
##     entry path (it had none).

const S := EconUtil.S
const TYPE_FOR := {"MINERAL": "MINE", "MATERIAL": "PROCESSING", "COMPONENT": "COMPONENTS"}
const GOOD_FOR := {"MINE": "MINERAL", "PROCESSING": "MATERIAL", "COMPONENTS": "COMPONENT"}
## R8 step 3 (opt-in R8_FOOD): rules 3–6 also for the food companies' plants (families follow their sales instead:
## EconRulesFood). Kill switches R8F_NOOUT, R8F_NOCAP.
const FOOD_GOOD_FOR := {"FARM": "FOOD", "BAKERY": "FINE_FOOD"}
const STEP := 0.03
const STEP_UP := 0.05
const MARKUP := 1.2
const U_LOW := 700  # ‰ use below which a glut may lower the price
const HI_USE := 850
const HI_M := 6
const UNF_PM := 50  # ‰ of a plant's capacity in reachable unfilled orders
const UNF_M := 6
const ADD_MARGIN := 1.1
const MAX_SCALE := 3000
const COVER_MAX := 2000  # ‰ months of sales: no extra output beyond this stock


static func on(world: WorldState) -> bool:
	return EconRules.sector_on(world, "MATERIAL")


static func _part(world: WorldState, kill: String) -> bool:
	return on(world) and not (world.meta.get("on", []) as Array).has(kill)


static func prices_on(world: WorldState, good: String) -> bool:
	return TYPE_FOR.has(good) and on(world) and (world.meta.get("on", []) as Array).has("R8M_PX")


static func output_on(world: WorldState, ftype: String) -> bool:
	return _rule_on(world, ftype, "NOOUT")


static func capacity_on(world: WorldState, ftype: String) -> bool:
	return _rule_on(world, ftype, "NOCAP")


## The good a plant type makes under the eight rules' output and capacity rules ("" when its sector is off).
static func good_of(world: WorldState, ftype: String) -> String:
	if GOOD_FOR.has(ftype) and on(world):
		return String(GOOD_FOR[ftype])
	if FOOD_GOOD_FOR.has(ftype) and EconRulesFood.on(world):
		return String(FOOD_GOOD_FOR[ftype])
	return ""


static func _rule_on(world: WorldState, ftype: String, part: String) -> bool:
	if good_of(world, ftype) == "":
		return false
	var kill := ("R8M_" if GOOD_FOR.has(ftype) else "R8F_") + part
	return not (world.meta.get("on", []) as Array).has(kill)


static func entry_on(world: WorldState, ftype: String) -> bool:
	return GOOD_FOR.has(ftype) and _part(world, "R8M_NOENTRY")


# ------------------------------------------------------------------ rules 1/2 (EconMarket._update_prices)

## The new price for `good` from last month's shortage (unfilled share) and excess (cover beyond 2 months, 0..1).
static func price(world: WorldState, good: String, p: float, shortage: float, excess: float) -> float:
	var uc := FirmAI.unit_cost(world, String(TYPE_FOR[good]))
	var use := _mean_use(world, good)
	var var_c := _var_floor(world, good)
	if shortage > 0.05:
		return p * (1.0 + minf(STEP_UP, EconData.ALPHA * shortage))
	if shortage > 0.0 and p < uc:
		return minf(uc, p * (1.0 + STEP))
	if shortage <= 0.02 and excess > 0.0 and use < U_LOW:
		return maxf(minf(p, var_c), p * (1.0 - minf(STEP, EconData.ALPHA * excess)))
	var target := MARKUP * uc
	if p > target:
		if shortage > 0.0:
			return p  # never down while orders go unfilled
		return maxf(target, p * (1.0 - STEP))
	return minf(target, p * (1.0 + STEP))


## Mean use (‰) of the open plants making `good`, last month's R8 readings (1000 when none are measured).
static func _mean_use(world: WorldState, good: String) -> int:
	var t := 0
	var n := 0
	var pl: Dictionary = EconUtil.peek_st(world).get("r8", {}).get("plants", {})
	for fid in EconUtil.sorted_keys(pl):
		if String(pl[fid]["g"]) == good:
			t += int(pl[fid]["util"])
			n += 1
	return 1000 if n == 0 else t / n


## The lowest variable cost (mcr/unit) among the open plants making `good` (0 when none are measured).
static func _var_floor(world: WorldState, good: String) -> float:
	var best := -1
	var pl: Dictionary = EconUtil.peek_st(world).get("r8", {}).get("plants", {})
	for fid in EconUtil.sorted_keys(pl):
		if String(pl[fid]["g"]) == good and (best < 0 or int(pl[fid]["cost_var"]) < best):
			best = int(pl[fid]["cost_var"])
	return float(maxi(0, best))


# ------------------------------------------------------------------ rules 3/4 (FirmAI._set_target)

## The plant's target (0..1) given the old rule's t: its share of reachable unfilled orders on top of last month's
## output while its stock is under COVER_MAX; the core crew only below variable cost.
static func target(world: WorldState, f: Dictionary, good: String, t: float) -> float:
	var pl := EconRules.plant(world, String(f["id"]))
	if pl.is_empty():
		return t
	var s := EconUtil.st(world)
	if float(int(s["prices"].get(good, 0))) < float(int(pl["cost_var"])):
		return 0.2
	if int(pl["cover"]) >= COVER_MAX:
		return t
	var r: Dictionary = EconData.RECIPES[f["type"]]
	var cap := float(r["out"][1]) * float(S) * EconUtil.fscale(f)
	var all_cap := 0.0
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f2: Dictionary = world.table("facility")[fid]
		if f2["type"] == f["type"] and not f2["mothball"]:
			all_cap += float(r["out"][1]) * float(S) * EconUtil.fscale(f2)
	var extra := float(int(pl["reach"])) * cap / maxf(1.0, all_cap)
	var want := (float(int(f.get("out_last", 0))) + extra) / maxf(1.0, cap)
	return maxf(t, clampf(want, 0.2, 1.0))


# ------------------------------------------------------------------ monthly counters (EconRules.monthly)

static func monthly(world: WorldState) -> void:
	if not on(world) and not EconRulesFood.on(world):
		return
	var pl: Dictionary = EconUtil.st(world)["r8"].get("plants", {})
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if good_of(world, String(f["type"])) == "":
			continue
		var p: Dictionary = pl.get(fid, {})
		if p.is_empty():
			f["r8_hi_m"] = 0
			f["r8_unf_m"] = 0
			f["r8_hi_bits"] = 0
			f["r8_unf_bits"] = 0
			continue
		var r: Dictionary = EconData.RECIPES[f["type"]]
		var cap := int(float(r["out"][1]) * float(S) * EconUtil.fscale(f))
		# months in the last 12 (a 12-bit window; trace: unfilled orders come in bursts, so a run of 6 never formed)
		f["r8_hi_bits"] = ((int(f.get("r8_hi_bits", 0)) << 1) | (1 if int(p["util"]) >= HI_USE else 0)) & 0xFFF
		f["r8_unf_bits"] = ((int(f.get("r8_unf_bits", 0)) << 1) | (1 if int(p["reach"]) * 1000 >= cap * UNF_PM else 0)) & 0xFFF
		f["r8_hi_m"] = _bits(int(f["r8_hi_bits"]))
		f["r8_unf_m"] = _bits(int(f["r8_unf_bits"]))


static func _bits(x: int) -> int:
	var n := 0
	while x > 0:
		n += x & 1
		x >>= 1
	return n


## Rule 6: a plant with reachable unfilled orders in the last 12 months is not mothballed.
static func keeps(world: WorldState, f: Dictionary) -> bool:
	return capacity_on(world, String(f["type"])) and int(f.get("r8_unf_m", 0)) > 0


# ------------------------------------------------------------------ rule 5 (quarterly, FirmAI.run)

static func capacity(world: WorldState) -> void:
	if not on(world) and not EconRulesFood.on(world):
		return
	var s := EconUtil.st(world)
	var acts: Array = s.get("r8_mat_actions", [])
	var done := {}
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		var ftype := String(f["type"])
		if not capacity_on(world, ftype) or f["mothball"] or done.has(ftype):
			continue
		if int(f.get("r8_hi_m", 0)) < HI_M or int(f.get("r8_unf_m", 0)) < UNF_M:
			continue
		var o: Dictionary = world.table("org").get(f["org"], {})
		if o.is_empty() or o["status"] != "ACTIVE" or o["is_contractor"] or bool(o.get("family", false)):
			continue
		var pe: bool = o["type"] == "PUBLIC_ENTERPRISE"
		if not (o["type"] in ["PRIVATE", "COOPERATIVE"] or pe):
			continue
		var good := good_of(world, ftype)
		if float(int(s["prices"].get(good, 0))) < ADD_MARGIN * FirmAI.unit_cost(world, ftype):
			continue
		if not pe and EconPublicCo.result12(o) < 0:
			continue
		if EconConstruction.has_open_project(world, f["org"], ftype) or _expand_pending(world, fid):
			continue
		var grow := int(f.get("scale", 1000)) < MAX_SCALE and EconData.BUILD.has(ftype)
		if not grow and EconEssentials.labour_fill(world, ftype) < EconEssentials.MIN_LABOUR_FILL:
			continue
		var cost := EconConstruction.estimate(ftype) / 4 if grow else EconConstruction.estimate(ftype)
		if not grow and not LawBridge.allowed(world, f["org"], "BUILD_FACILITY", {"facility_type": ftype, "district": f["district"],
				"owner_kind": "COMPANY", "value_wref": cost / maxi(1, int(world.values.get("ECON_W_REF", 1200 * S)))}):
			continue
		if not _finance(world, String(f["org"]), cost, pe):
			continue
		if grow:
			EconConstruction.create_expansion(world, fid, f["org"])
			o["last_expand"] = world.month
		else:
			EconConstruction.create(world, ftype, f["district"], f["org"], f["org"], "")
			o["last_invest"] = world.month
		acts.append([world.month, ftype, "expand" if grow else "new"])
		done[ftype] = true
		for fid2 in world.table("facility"):
			var f2: Dictionary = world.table("facility")[fid2]
			if f2["type"] == ftype:
				f2["r8_hi_m"] = 0
				f2["r8_unf_m"] = 0
				f2["r8_hi_bits"] = 0
				f2["r8_unf_bits"] = 0
		EconFacts.emit(world, "COMP_INVESTMENT", f["district"], [["COMPANY", f["org"]]], [["COMPANY", f["org"], 1.0]], {"JOBS": 2}, 15,
			"PUBLIC", {"type": ftype, "reason": "orders", "good": good})
	s["r8_mat_actions"] = acts


static func _expand_pending(world: WorldState, fid: String) -> bool:
	for pid in world.table("project"):
		var p: Dictionary = world.table("project")[pid]
		if p["type"] == "EXPAND" and p.get("target", "") == fid and p["status"] in ["TENDER", "ACTIVE", "TENDERABLE"]:
			return true
	return false


## Cash first, then a bank loan (the owner puts in 30%); a public enterprise without bank room asks the treasury, as
## the essentials planner did (not behind a human government's back).
static func _finance(world: WorldState, oid: String, cost: int, pe: bool) -> bool:
	var cash := world.ledger.balance(EconUtil.acct(oid))
	if cash >= cost:
		return true
	if cash >= cost * 3 / 10 and EconFinance.new_loan(world, oid, mini(cost - cash, cost * 7 / 10), 0, true):
		return true
	if not pe or EconEssentials.human_governs(world):
		return false
	var paid := EconFinance.gov_pay(world, EconUtil.acct(oid), cost - cash, "PE_INVESTMENT")
	FirmAI.DecisionDesk.note(world, "PE_INVESTMENT")
	EconFinance._spend_line(world, "ECON_BUDGET_INFRASTRUCTURE", paid)
	return paid >= (cost - cash) / 2


# ------------------------------------------------------------------ rules 7/8 (FirmAI._entry)

## Whether founders see this sector as worth entering: the forecast in its best district, and incumbents not losing.
static func entry_hot(world: WorldState, ftype: String, founder_d: String) -> bool:
	if _incumbents_losing(world, ftype):
		return false
	var d := entry_district(world, ftype, founder_d)
	var fc := EconForecast.first_year(world, ftype, d)
	var why: Array = fc["reasons"]
	return int(fc["profit"]) > 0 and not why.has("no_customers") and not why.has("competitors")


## The district a founder would build in: mines where the ore is (d:3), other plants where the forecast is best.
static func entry_district(world: WorldState, ftype: String, founder_d: String) -> String:
	if ftype == "MINE":
		return "d:3"
	var best := founder_d
	var best_p := int(EconForecast.first_year(world, ftype, founder_d)["profit"])
	for d in EconUtil.sorted_keys(EconData.DISTRICTS):
		var pr := int(EconForecast.first_year(world, ftype, String(d))["profit"])
		if pr > best_p:
			best_p = pr
			best = String(d)
	return best


## Rule 8: incumbents holding more than half of the open capacity lost money over 12 months.
static func _incumbents_losing(world: WorldState, ftype: String) -> bool:
	var all_c := 0
	var losing := 0
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] != ftype or f["mothball"]:
			continue
		var o: Dictionary = world.table("org").get(f["org"], {})
		var c := int(f.get("scale", 1000))
		all_c += c
		if not o.is_empty() and EconPublicCo.result12(o) < 0:
			losing += c
	return all_c > 0 and losing * 2 > all_c


# ------------------------------------------------------------------ value bids (on with R8_MATERIAL, off with R8M_NOVALUE; user ruling via Wilma)
## "Why is no one paying the price?" Buyers' limits were a multiple of the market price (inputs 1.3×, builders 1.3×), so
## they fell with the price and nobody offered what an input is worth to them. A buyer of MINERAL,
## MATERIAL or COMPONENT bids up to its value (the old multiple stays as a floor; the price ceiling caps it):
## - a producer (private, co-op, public enterprise): its output at full load at today's price, less wages, the other
##   inputs, utilities and the rest of its upkeep, per unit of this good it uses (recipe input plus upkeep parts); the
##   best of its plant types that use it;
## - a builder: the material allowance its contracts pay for, base price × (contract price ÷ cost estimate).

static func value_on(world: WorldState) -> bool:
	return on(world) and not (world.meta.get("on", []) as Array).has("R8M_NOVALUE")


## {"org|good": mcr per unit} for the org's plant types that use the good; empty when off.
static func value_bids(world: WorldState) -> Dictionary:
	var out := {}
	if not value_on(world):
		return out
	var tv := {}
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		var o: Dictionary = world.table("org").get(f["org"], {})
		if o.is_empty() or not (o["type"] in ["PRIVATE", "COOPERATIVE", "PUBLIC_ENTERPRISE"]):
			continue
		for good in TYPE_FOR:
			var k := String(f["type"]) + "|" + String(good)
			if not tv.has(k):
				tv[k] = _type_value(world, String(f["type"]), String(good))
			if float(tv[k]) > 0.0:
				var ko := String(f["org"]) + "|" + String(good)
				out[ko] = maxi(int(out.get(ko, 0)), int(tv[k]))
	return out


## What one unit of `good` is worth to a plant of `ftype` running at full load (mcr; 0 when it doesn't use it).
static func _type_value(world: WorldState, ftype: String, good: String) -> float:
	var s := EconUtil.st(world)
	var r: Dictionary = EconData.RECIPES.get(ftype, {})
	if r.is_empty():
		return 0.0
	var units := float(r["in"].get(good, 0))
	if good == "MATERIAL":
		units += float(r["upkeep"])
	elif good == "COMPONENT":
		units += float(EconData.UPKEEP_COMPONENT.get(ftype, 0))
	if units <= 0.0:
		return 0.0
	var og := String(r["out"][0])
	var pout := 0.0
	if og in EconData.MARKET_GOODS:
		pout = float(int(s["prices"][og]))
	elif og == "SERVICES":
		var n := 0
		for d in s.get("svc_price", {}):
			pout += float(int(s["svc_price"][d]))
			n += 1
		pout /= maxf(1.0, float(n))
	else:
		return 0.0  # utilities and institutions: tariffs and budgets, not a market value
	var margin := float(r["out"][1]) * pout
	for t in r["labor"]:
		margin -= float(r["labor"][t]) * float(int(s["wage"].get(t, 0)))
	for g in r["in"]:
		if g == good:
			continue
		if g in EconData.MARKET_GOODS:
			margin -= float(r["in"][g]) * float(int(s["prices"][g]))
		elif g == "ENERGY":
			margin -= float(r["in"][g]) * float(EconUtil.lever(world, "ECON_UTILITY_TARIFF_ENERGY", 40)) * S
		elif g == "WATER":
			margin -= float(r["in"][g]) * float(EconUtil.lever(world, "ECON_UTILITY_TARIFF_WATER", 20)) * S
	if good != "MATERIAL":
		margin -= float(r["upkeep"]) * float(int(s["prices"]["MATERIAL"]))
	if good != "COMPONENT":
		margin -= float(EconData.UPKEEP_COMPONENT.get(ftype, 0)) * float(int(s["prices"]["COMPONENT"]))
	return maxf(0.0, margin / units)


## A buyer's limit for `good`: the old limit, raised to the value (+ the freight allowance), capped at the price ceiling.
static func value_limit(world: WorldState, good: String, old_lim: int, value: int, freight_allow: int) -> int:
	if value <= 0 or not TYPE_FOR.has(good):
		return old_lim
	var cap := int(float(EconUtil.st(world)["base"][good]) * EconData.PRICE_MAX_MULT * EconMarket.wage_level(world)) + freight_allow
	return maxi(old_lim, mini(value + freight_allow, cap))


## A builder's value per unit of MATERIAL / COMPONENT: the base price its contracts were priced on × contract price ÷
## cost estimate (its active contracts; 0 without one).
static func builder_value(world: WorldState, oid: String, good: String) -> int:
	if not value_on(world) or not TYPE_FOR.has(good):
		return 0
	var price := 0
	var est := 0
	for pid in world.table("org")[oid].get("contracts", []):
		var p: Dictionary = world.table("project").get(pid, {})
		if p.is_empty() or p["status"] != "ACTIVE":
			continue
		price += int(p["price"])
		est += int(p.get("est_cost", 0))
	if price <= 0 or est <= 0:
		return 0
	return int(float(EconData.BASE_PRICE[good]) * float(S) * float(price) / float(est))

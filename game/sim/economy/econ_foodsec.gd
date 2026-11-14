class_name EconFoodSec
extends RefCounted
## S7 food trap (backlog 18; Wilma's go 2026-11-14). OPT-IN: world.meta["on"] has "S7F", until the A/Bs.
## The v9 probes (seed 4) showed the "food trap" is mostly UNAFFORDABLE food, not SCARCE food: every order filled, farms
## on 1.3–1.6 months of stock, yet households order only 70–80% of their need (orders are budget-capped) at a price
## stuck at 2.3× base — so farms cut output to what sells. Four parts:
##   S7a  diagnosis: the household food gap split into SCARCE (ordered, not delivered) and UNAFFORDABLE (needed, not
##        ordered); facts ECON_FOOD_SCARCE / ECON_FOOD_UNAFFORDABLE; exception-only indicator ECON_FOOD_UNAFFORDABLE.
##   S7d  recovery: labour-only upkeep for running farms short of MATERIAL (decay is no longer permanent); under
##        INDUSTRY_FIRST energy rationing, industry is served after farms (EconProduction._prio); the rationing fact
##        says how many months it has lasted. (Idle-farm mothballing already exists: FirmAI §9.1 + E115b.)
##   S7b  food assistance = the existing E63 entitlement (lever ECON_FOOD_ASSISTANCE, % of food need, default 100;
##        merged with Wilma 2026-11-14 — one lever, one entitlement). E63 topped up cash in SETTLEMENT, and fares,
##        comfort, services and media then spent it before households ordered; under S7F it is paid right before the
##        orders instead, at the price households actually pay (incl. the shop margin). Like food stamps it reaches the
##        farms as real orders, so the price and the farm-building signal stay intact (E127/E139 cut prices instead).
##   S7c  perishable surplus price drift — later (A/B arm).

const FACT_PM := 50  # ‰ of colony food need: a gap this size makes a fact (quarterly)
const LEVER := "ECON_FOOD_ASSISTANCE"
const FARM_HAND_UPKEEP := 0.9  # S7d: share of the missing-material wear a full farm crew offsets by hand
const FARM_HAND_REPAIR := 150  # S7d: milli-condition a full crew restores a month without parts (net ≈ +0.04 pt/month; E84 with parts: 250)


static func active(world: WorldState) -> bool:
	return world.meta.has("on") and (world.meta["on"] as Array).has("S7F") and not EconUtil.off(world, "S7F")


## S7a: called by EconHouseholds._consume with per-district sums (milli-units): need, unaffordable gap, scarce gap.
static func record(world: WorldState, need_d: Dictionary, unaff_d: Dictionary, scarce_d: Dictionary) -> void:
	var s := EconUtil.st(world)
	var nt := 0
	var ut := 0
	var st := 0
	var ud := {}
	var sd := {}
	for d in EconUtil.sorted_keys(need_d):
		var n := int(need_d[d])
		nt += n
		ut += int(unaff_d.get(d, 0))
		st += int(scarce_d.get(d, 0))
		ud[d] = int(1000.0 * float(unaff_d.get(d, 0)) / maxf(1.0, float(n)))
		sd[d] = int(1000.0 * float(scarce_d.get(d, 0)) / maxf(1.0, float(n)))
	s["food_unaff_d"] = ud
	s["food_scarce_d"] = sd
	s["food_unaff"] = int(1000.0 * float(ut) / maxf(1.0, float(nt)))
	s["food_scarce"] = int(1000.0 * float(st) / maxf(1.0, float(nt)))
	if world.month % 3 != 0:
		return
	if int(s["food_unaff"]) >= FACT_PM:
		var worst := ""
		for d in EconUtil.sorted_keys(ud):
			if worst == "" or int(ud[d]) > int(ud[worst]):
				worst = d
		EconFacts.emit(world, "ECON_FOOD_UNAFFORDABLE", worst, [], [["GOVERNMENT", "government", 0.6], ["NATURE", "market", 0.4]],
			{"COST_OF_LIVING": -mini(60, int(s["food_unaff"]) / 4), "FAIRNESS": -mini(40, int(s["food_unaff"]) / 6)},
			mini(80, int(s["food_unaff"]) / 4), "PUBLIC",
			{"unaffordable_permille": int(s["food_unaff"]), "price": int(s["prices"]["FOOD"]), "base_price": int(s["base"]["FOOD"])})
	if int(s["food_scarce"]) >= FACT_PM:
		EconFacts.emit(world, "ECON_FOOD_SCARCE", null, [], [["GOVERNMENT", "government", 0.5], ["NATURE", "market", 0.5]],
			{"COST_OF_LIVING": -mini(60, int(s["food_scarce"]) / 4)}, mini(80, int(s["food_scarce"]) / 4), "PUBLIC",
			{"scarce_permille": int(s["food_scarce"]), "price": int(s["prices"]["FOOD"])})


## S7a: share (‰) of district d's household food need that went unbought for lack of money (0 when off).
static func unaffordable_pm(world: WorldState, d: String) -> int:
	return int(EconUtil.peek_st(world).get("food_unaff_d", {}).get(d, 0))


## S7d: share of the plant's required crew actually at work (0..1).
static func labour_fill(f: Dictionary) -> float:
	var req := EconLabor.required(f)
	var core := 0.0
	var have := 0.0
	for t in req:
		core += float(req[t])
		have += float(mini(int(req[t]), int(EconLabor.tier_total(f["staff"], t))))
	return clampf(have / maxf(1.0, core), 0.0, 1.0)


## S7b: E63 paid at the right moment — top up each group's cash to ECON_FOOD_ASSISTANCE % of its food need's cost.
static func assist(world: WorldState) -> void:
	if not active(world):
		return
	var s := EconUtil.st(world)
	s["food_assist_m"] = 0
	s["food_assist_hh"] = 0
	s["food_assist_pm"] = 0
	var fa := float(EconUtil.lever(world, LEVER, 100)) / 100.0
	if fa <= 0.0:
		return
	var pf_eff := EconHouseholds.food_price_eff(world)
	var paid_tot := 0
	var n := 0
	var bill := 0
	for gid in EconUtil.sorted_keys(world.table("hh")):
		var g: Dictionary = world.table("hh")[gid]
		var p := EconHouseholds.persons(g)
		if p <= 0:
			continue
		var full := EconUtil.val(int(p * EconData.NEED["FOOD"]), pf_eff)
		bill += full
		var cost := int(float(full) * fa)
		var gap := cost - maxi(0, world.ledger.balance(EconUtil.hh_acct(gid)))
		if gap <= 0:
			continue
		var paid := EconFinance.gov_pay(world, EconUtil.hh_acct(gid), gap, "FOOD_ASSISTANCE")
		if paid <= 0:
			continue
		g["income"]["benefit"] += paid
		EconPop.credit_status(world, gid, "", paid, "benefit")
		paid_tot += paid
		n += 1
	s["gov_spend_m"] = s.get("gov_spend_m", 0) + paid_tot
	s["food_assist_m"] = paid_tot
	s["food_assist_hh"] = n
	s["food_assist_pm"] = assist_pm(paid_tot, bill)


## Wilma's dependence guard (Legislature.protected_levers): ‰ of the colony's monthly food bill (full need at the price
## households pay) that food assistance paid this month. Written by both paths (here under S7F, EconFinance E63 when off).
static func assist_pm(paid: int, bill: int) -> int:
	return int(1000.0 * float(paid) / maxf(1.0, float(bill)))

class_name EconPolice
extends RefCounted
## P1b police (planning/design-p1-crime-police.md §2, §6–7; interface agreed with Anni 2026-11-13): the POLICE
## institution (key "POLICE", PUBLIC_INSTITUTION) and its POLICE_STATION sites (1 Sp + 8 S + 1 G per 10 officers).
##   STATIONS: always one in d:1 (HQ); another opens in any district with ≥ OPEN_POP residents and closes below
##     CLOSE_POP (hysteresis). A district without its own station is covered from d:1.
##   OFFICERS: Anni's law_state.s.police.crew_target[station district] when she writes it, else LAW_POLICE_BUDGET ‰ ×
##     OFFICERS_PER_10K per 10k of the covered population. No labour hoarding (f.no_hoard): a budget cut lets the crew
##     shrink by attrition (LAYOFF_RATE a month) — at 300‰ about 30% of the officers remain.
##   WAGES: the next month's bill topped up from the treasury, booked to spent_ytd["LAW_POLICE_BUDGET"].
##   CAPACITY for Anni's crime model: hours(world, d) = staff × OFFICER_HOURS × the stress sick factor, shared over the
##     station's covered districts by population.
##   WORKLOAD (P1d): Σ last month's need_h of the covered districts (Anni's crime state) ÷ (staff × OFFICER_HOURS);
##     stress, sick days and overload news from EconWorkload (service tag POLICE); WK.report_public_staffing with the
##     covered residents as clients.
## OPT-IN until its A/B (world.meta["on"] has "POLICE").

const S := EconUtil.S
const OFFICERS_PER_10K := 20
const OFFICER_HOURS := 130
const OPEN_POP := 2000
const CLOSE_POP := 1500
const UNIT := 10  # officers per 1000 scale
const HQ := "d:1"


static func active(world: WorldState) -> bool:
	return world.meta.has("on") and (world.meta["on"] as Array).has("POLICE") and not EconUtil.off(world, "POLICE")


static func org(world: WorldState) -> String:
	return EconFinance.org_by_key(world, "POLICE")


static func _found(world: WorldState) -> String:
	var oid := world.new_id("org")
	world.table("org")[oid] = {"id": oid, "key": "POLICE", "name": "Colony Police", "type": "PUBLIC_INSTITUTION", "hq": HQ,
		"status": "ACTIVE", "ceo": {"mgmt": 50, "risk": 10, "age_m": 50 * 12}, "reliability": 0, "is_contractor": false,
		"crew": {}, "crew_target": {}, "premium_m": {"G": 0, "S": 0, "Sp": 0}, "tax_loss_cf": 0, "profit_q": 0,
		"pl": EconFinance.empty_pl(), "pl_last": {}, "missed_streak": 0, "ok_streak": 0, "low_cash_streak": 0, "distress_months": 0,
		"admin_months": 0, "liq_months": 0, "missed_this_month": false, "owner_group": "", "sales_ema": {}, "contracts": [],
		"dividends_ytd": 0, "sold": {}}
	world.ledger.open_account(EconUtil.acct(oid))
	return oid


## The station facility of a district ({} if it has none, open or closed).
static func _station(world: WorldState, oid: String, d: String) -> Dictionary:
	for fid in EconUtil.sorted_keys(world.peek("facility")):
		var f: Dictionary = world.peek("facility")[fid]
		if f["org"] == oid and f["type"] == "POLICE_STATION" and f["district"] == d:
			return f
	return {}


static func _pop(world: WorldState) -> Dictionary:
	var out := {}
	for gid in EconUtil.sorted_keys(world.peek("hh")):
		var g: Dictionary = world.peek("hh")[gid]
		out[g["district"]] = int(out.get(g["district"], 0)) + EconHouseholds.persons(g) / S
	return out


## COMPANY_AI, before FirmAI.run: open/close stations, set each crew from the budget, fund next month's wages.
static func monthly(world: WorldState) -> void:
	if not active(world):
		return
	var oid := org(world)
	if oid == "":
		oid = _found(world)
	var pop := _pop(world)
	# which districts have an open station (hysteresis)
	var open := {}
	for d in EconUtil.sorted_keys(pop):
		var f := _station(world, oid, d)
		var was: bool = not f.is_empty() and not bool(f["mothball"])
		if d == HQ or int(pop[d]) >= OPEN_POP or (was and int(pop[d]) >= CLOSE_POP):
			open[d] = true
	open[HQ] = true
	# covered population per station
	var covers := {}
	for d in EconUtil.sorted_keys(pop):
		var st: String = d if open.has(d) else HQ
		var c: Array = covers.get(st, [])
		c.append(d)
		covers[st] = c
	var lever := int(world.levers.get("LAW_POLICE_BUDGET", 1000))
	var override: Dictionary = world.peek("law_state").get("s", {}).get("police", {}).get("crew_target", {})
	var crime_d: Dictionary = world.peek("law_state").get("s", {}).get("crime", {}).get("d", {})
	var bill := 0
	for d in EconUtil.sorted_keys(pop) + ([] if pop.has(HQ) else [HQ]):
		var f := _station(world, oid, d)
		if not open.has(d):
			if not f.is_empty():
				f["mothball"] = true
				f["scale"] = 0
			continue
		if f.is_empty():
			var fid := EconSetup.add_facility(world, "POLICE_STATION", oid, d, false)
			f = world.table("facility")[fid]
			f["book"] = 0
		var cov: Array = covers.get(d, [d])
		var cpop := 0
		var need_h := 0
		for cd in cov:
			cpop += int(pop.get(cd, 0))
			need_h += int(crime_d.get(cd, {}).get("need_h", 0))
		var target := int(override[d]) if override.has(d) else int(round(float(lever) / 1000.0 * float(OFFICERS_PER_10K) * float(cpop) / 10000.0))
		f["mothball"] = false
		f["no_hoard"] = true  # Anni: cuts must bite (no E49 70% floor)
		f["scale"] = target * 1000 / UNIT
		f["T"] = 1000
		f["covers"] = cov
		f["covered_pop"] = cpop
		f["officers_target"] = target
		f["police_need_h"] = need_h if need_h > 0 else int(float(cpop) / 10000.0 * 1700.0)  # P1a patrol need until need_h
		var req := EconLabor.required(f)
		for t in req:
			bill += int(req[t]) / S * EconFinance.wage_for(world, oid, t)
	var due := bill - world.ledger.balance(EconUtil.acct(oid))
	if due > 0:
		var paid := EconFinance.gov_pay(world, EconUtil.acct(oid), due, "POLICE_BUDGET")
		EconFinance._spend_line(world, "LAW_POLICE_BUDGET", paid)
		EconFinance.pl_add(world, oid, "subsidy", paid)


## Officer-hours on duty this month in district d (Anni's crime model; 0 when off or uncovered).
static func hours(world: WorldState, d: String) -> int:
	if not active(world):
		return 0
	var oid := org(world)
	if oid == "":
		return 0
	for fid in EconUtil.sorted_keys(world.peek("facility")):
		var f: Dictionary = world.peek("facility")[fid]
		if f["org"] != oid or f["type"] != "POLICE_STATION" or f["mothball"] or not (f.get("covers", []) as Array).has(d):
			continue
		var staff := float(EconLabor.staff_total(f["staff"])) / float(S)
		var sick := EconWorkload.sick_mult(f) if EconWorkload.active(world) else 1.0
		var share := 1.0
		var cpop := int(f.get("covered_pop", 0))
		if cpop > 0:
			share = float(_pop(world).get(d, 0)) / float(cpop)
		return int(staff * float(OFFICER_HOURS) * sick * share)
	return 0


## Station workload ‰ (EconWorkload hook): the hours the crime model needed ÷ the hours the staff can give.
static func workload_pm(f: Dictionary) -> int:
	var staff := float(EconLabor.staff_total(f["staff"])) / float(S)
	return clampi(int(1000.0 * float(int(f.get("police_need_h", 0))) / maxf(1.0, staff * float(OFFICER_HOURS))), 0, 2000)


## Stations for Anni, Terra and the UI: [{id, district, covers, covered_pop, officers_target, staff, workload_pm,
## stress_pm, sick_pm}] — open stations only, sorted by id.
static func stations(world: WorldState) -> Array:
	var out: Array = []
	var oid := org(world)
	if oid == "":
		return out
	for fid in EconUtil.sorted_keys(world.peek("facility")):
		var f: Dictionary = world.peek("facility")[fid]
		if f["org"] != oid or f["type"] != "POLICE_STATION" or f["mothball"]:
			continue
		out.append({"id": fid, "district": f["district"], "covers": (f.get("covers", []) as Array).duplicate(),
			"covered_pop": int(f.get("covered_pop", 0)), "officers_target": int(f.get("officers_target", 0)),
			"staff": EconLabor.staff_total(f["staff"]) / S, "workload_pm": int(f.get("workload_pm", 0)),
			"stress_pm": int(f.get("stress_pm", 0)), "sick_pm": int(1000.0 * (1.0 - EconWorkload.sick_mult(f)))})
	return out

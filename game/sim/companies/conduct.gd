class_name EconConduct
extends RefCounted
## E132 conduct pass (Anni's finding: nothing in the economy ever called LawOps.record_greed, so the whole M11
## company-misconduct chain — inspections, fines, licence suspension, whistleblowers, crisis-inquiry causes, press
## investigations — was dormant). Private firms now cut corners for real money and real risk:
##   DEFERRED_UPKEEP   skip a plant's upkeep orders (E116)  → condition decays → efficiency and accident risk
##   SAFETY_CORNERS    hazardous plants run without the safety margin → accident chance × SAFETY_ACC_MULT, a rare major
##                     (crisis) accident on a run-down plant; saving = SAFETY_SAVING of the plant's wage bill
##   DUMPING           polluting plants skip waste handling → emissions × DUMP_MULT; saving per unit of pollution
##   CONTRACT_CORNERS  builders skimp on material (× CONTRACT_MAT) → the finished building starts at CONTRACT_CONDITION
##   GOUGING           in a shortage (buyers got < 90% of orders), a seller with stock to spare asks × GOUGE_MULT
## Who: LawBridge._misconduct (spec §9.5: profitable and (CEO risk ≥ 70, distressed, or risk ≥ 45 with ≤ 4
## inspectors)) plus cash pressure; public firms never. Each month the conduct lasts it is reported with
## LawOps.record_greed (facility, hazard_ids, saving); when it ends LawOps.greed_stop. Accidents carry data.operator,
## data.facility, data.hazard and data.cause_records so inquiries find the cause. OPT-IN ("CONDUCT") until its A/B.

const S := EconUtil.S
const LawOps := preload("res://sim/law/law_ops.gd")
const SAFETY_ACC_MULT := 1.8
const SAFETY_SAVING := 0.03
const DUMP_MULT := 1.5
const DUMP_SAVING_PER_POLL := 2000  # mcr per unit of pollution a month
const CONTRACT_MAT := 0.9
const CONTRACT_CONDITION := 80
const GOUGE_MULT := 1.3
const MAJOR_P := 0.02  # monthly chance of a major accident on a run-down hazardous plant cutting corners
const MAJOR_COND := 40
const CALM_MONTHS := 6
const CAUGHT_COOL_M := 24
const RECKLESS_RISK := 90


static func active(world: WorldState) -> bool:
	return world.meta.has("on") and (world.meta["on"] as Array).has("CONDUCT") and not EconUtil.off(world, "CONDUCT")


static func hazard_key(fid: String) -> String:
	return "haz:" + fid


static func _tracks(world: WorldState) -> Dictionary:
	var s := EconUtil.st(world)
	if not s.has("conduct"):
		s["conduct"] = {}
	return s["conduct"]


## Active greed track ids at a facility (for data.cause_records on accidents).
static func causes_at(world: WorldState, fid: String) -> Array:
	return _causes_for(world, fid)


static func _report(world: WorldState, key: String, org: String, rec: Dictionary) -> void:
	var t := _tracks(world)
	t[key] = LawOps.record_greed(world, org, rec)


## Deterrence: once the law has revealed this conduct (inspection, whistleblower, press), the firm stops it for
## CAUGHT_COOL_M months unless its CEO is truly reckless. Without this a caught firm carried on and opened a new record
## every month (record_greed matches only unrevealed records): 5,000–8,500 records a game.
static func _deterred(world: WorldState, key: String, o: Dictionary) -> bool:
	var s := EconUtil.st(world)
	var cool: Dictionary = s.get("conduct_cool", {})
	s["conduct_cool"] = cool
	var t := _tracks(world)
	if t.has(key):
		var v: Dictionary = world.table("violation_track").get(str(t[key]), {})
		if bool(v.get("revealed", false)):
			# E135b (v8 chronicles: one firm convicted 161 times): each catch doubles the pause (24 → 48 → 96, ≤ 120
			# months); a reckless CEO ignores the first catch only
			var caught: Dictionary = s.get("conduct_caught_n", {})
			s["conduct_caught_n"] = caught
			var n := int(caught.get(key, 0)) + 1
			caught[key] = n
			if int(o["ceo"].get("risk", 50)) < RECKLESS_RISK or n >= 2:
				cool[key] = world.month + mini(120, CAUGHT_COOL_M * int(pow(2.0, float(mini(n, 4) - 1))))
				_stop(world, key)
	return world.month < int(cool.get(key, -1))


static func _stop(world: WorldState, key: String) -> void:
	var t := _tracks(world)
	if t.has(key):
		LawOps.greed_stop(world, str(t[key]))
		t.erase(key)


static func _cheats(world: WorldState, o: Dictionary) -> bool:
	if not (o["type"] in ["PRIVATE", "COOPERATIVE"]) or not (o["status"] in ["ACTIVE", "DISTRESSED"]):
		return false
	if not LawBridge._misconduct(world, o["id"]):
		return false
	var risk := int(o["ceo"].get("risk", 50))
	return risk >= 70 or o["status"] == "DISTRESSED" or int(o.get("low_cash_streak", 0)) >= 1


## COMPANY_AI, after FirmAI.run: decide and report each firm's conduct for the month.
static func monthly(world: WorldState) -> void:
	if not active(world):
		return
	var s := EconUtil.st(world)
	var short_goods := {}
	for g in EconData.MARKET_GOODS:
		if int(s.get("fill_last", {}).get(g, 1000)) < 900:
			short_goods[g] = true
	for oid in EconUtil.sorted_keys(world.table("org")):
		var o: Dictionary = world.table("org")[oid]
		# hysteresis: a firm that starts cutting corners keeps at it until CALM_MONTHS in a row without the temptation
		# (the A/B without it opened 5,000–6,800 records a game, the rule flipping with monthly profit)
		var cheat := _cheats(world, o)
		if cheat:
			o["c_on"] = true
			o["c_calm"] = 0
		elif bool(o.get("c_on", false)):
			o["c_calm"] = int(o.get("c_calm", 0)) + 1
			if int(o["c_calm"]) >= CALM_MONTHS or not (o["status"] in ["ACTIVE", "DISTRESSED"]):
				o["c_on"] = false
		cheat = bool(o.get("c_on", false)) and o["status"] in ["ACTIVE", "DISTRESSED"]
		# builders: contract corners
		if o["is_contractor"]:
			o["c_contract"] = cheat
			var ck: String = oid + "|CONTRACT_CORNERS"
			if cheat and not o["contracts"].is_empty() and not _deterred(world, ck, o):
				_report(world, ck, oid, {"kind": "CONTRACT_CORNERS", "project": str(o["contracts"][0]), "district": o["hq"],
					"saving": int(float(o["pl_last"].get("cogs", 0)) * (1.0 - CONTRACT_MAT)) if not o.get("pl_last", {}).is_empty() else 0})
			else:
				_stop(world, ck)
			continue
		var gouge: Dictionary = {}
		# per kind, aggregated over the firm's plants: the decision is the firm's, so ONE record per firm and kind
		# (facility = the plant where it matters most, hazard_ids = all affected hazardous plants, saving summed)
		var agg := {}  # kind -> {facility, district, hazard_ids, saving, weight}
		for fid in EconUtil.sorted_keys(world.table("facility")):
			var f: Dictionary = world.table("facility")[fid]
			if f["org"] != oid:
				continue
			if f["mothball"]:
				f["c_defer"] = false
				f["c_safety"] = false
				f["c_dump"] = false
				continue
			var r: Dictionary = EconData.RECIPES[f["type"]]
			var hazardous: bool = r["hazard"] in ["HIGH", "MEDIUM"] or f["type"] == "MINE"
			var wages := 0
			for t in r["labor"]:
				wages += int(float(r["labor"][t]) * float(s["wage"][t]) * EconUtil.fscale(f))
			f["c_defer"] = cheat and int(r["upkeep"]) > 0 and not _deterred(world, oid + "|DEFERRED_UPKEEP", o)
			if f["c_defer"]:
				_agg(agg, "DEFERRED_UPKEEP", f, hazardous, EconUtil.val(int(float(r["upkeep"]) * S * EconUtil.fscale(f)), s["prices"]["MATERIAL"]))
			f["c_safety"] = cheat and hazardous and not _deterred(world, oid + "|SAFETY_CORNERS", o)
			if f["c_safety"]:
				_agg(agg, "SAFETY_CORNERS", f, true, int(float(wages) * SAFETY_SAVING))
			f["c_dump"] = cheat and int(r["poll"]) > 0 and not _deterred(world, oid + "|DUMPING", o)
			if f["c_dump"]:
				_agg(agg, "DUMPING", f, false, int(float(r["poll"]) * float(DUMP_SAVING_PER_POLL) * EconUtil.fscale(f)))
			# gouging: a shortage, and this seller has stock to spare (never the market's own price rule)
			var good: String = r["out"][0]
			if cheat and short_goods.has(good):
				var stock := FirmAI._org_stock(world, oid, good)
				var ema := int(o["sales_ema"].get(good, 0))
				if ema > 0 and stock >= 2 * ema:
					gouge[good] = true
		for kind in ["DEFERRED_UPKEEP", "SAFETY_CORNERS", "DUMPING"]:
			var key: String = oid + "|" + kind
			if agg.has(kind):
				var a: Dictionary = agg[kind]
				_report(world, key, oid, {"kind": kind, "facility": a["facility"], "district": a["district"],
					"hazard_ids": a["hazard_ids"], "saving": int(a["saving"])})
			else:
				_stop(world, key)
		o["c_gouge"] = gouge
		for g in EconData.MARKET_GOODS:
			var gk: String = oid + "|GOUGING|" + g
			if gouge.has(g) and not _deterred(world, gk, o):
				var extra := int(float(s["prices"][g]) * (GOUGE_MULT - 1.0))
				_report(world, gk, oid, {"kind": "GOUGING", "good": g, "food": g == "FOOD", "district": o["hq"],
					"saving": EconUtil.val(int(o["sales_ema"].get(g, 0)), extra)})
			else:
				gouge.erase(g)  # deterred or no shortage: the ask goes back to normal (o.c_gouge is this dict)
				_stop(world, gk)


static func _agg(agg: Dictionary, kind: String, f: Dictionary, hazardous: bool, saving: int) -> void:
	if not agg.has(kind):
		agg[kind] = {"facility": f["id"], "district": f["district"], "hazard_ids": [], "saving": 0, "weight": -1}
	var a: Dictionary = agg[kind]
	a["saving"] = int(a["saving"]) + saving
	if hazardous:
		a["hazard_ids"].append(hazard_key(f["id"]))
	if saving > int(a["weight"]):  # the plant where it matters most names the record
		a["weight"] = saving
		a["facility"] = f["id"]
		a["district"] = f["district"]


## Active greed track ids touching a facility: firm-level records that name it or list its hazard.
static func _causes_for(world: WorldState, fid: String) -> Array:
	var out: Array = []
	var t: Dictionary = EconUtil.peek_st(world).get("conduct", {})
	var f: Dictionary = world.peek("facility").get(fid, {})
	if f.is_empty():
		return out
	for k in EconUtil.sorted_keys(t):
		if str(k).begins_with(String(f["org"]) + "|"):
			var v: Dictionary = world.peek("violation_track").get(str(t[k]), {})
			if v.get("facility", "") == fid or (v.get("hazard_ids", []) as Array).has(hazard_key(fid)):
				out.append(t[k])
	return out


## Production hook: the accident probability multiplier for a facility.
static func accident_mult(f: Dictionary) -> float:
	return SAFETY_ACC_MULT if bool(f.get("c_safety", false)) else 1.0


## Production hook: the emission multiplier for a facility.
static func emission_mult(f: Dictionary) -> float:
	return DUMP_MULT if bool(f.get("c_dump", false)) else 1.0


## Production hook: a major (crisis-size) accident on a run-down hazardous plant whose owner cuts corners.
static func major_accident(world: WorldState, f: Dictionary) -> void:
	if not active(world) or not (bool(f.get("c_safety", false)) or bool(f.get("c_defer", false))):
		return
	var r: Dictionary = EconData.RECIPES[f["type"]]
	if not (r["hazard"] == "HIGH" or f["type"] == "MINE") or int(f["condition"]) >= MAJOR_COND * S:
		return
	var rng := world.rng.stream("econ.major_accident")
	if rng.randf() >= MAJOR_P:
		return
	var affected := rng.randi_range(4, 12)
	EconFacts.emit(world, "COMP_WORKPLACE_ACCIDENT", f["district"], [["COMPANY", f["org"]]],
		EconFacts.company_blame(world, f["org"], 0.8), {"SAFETY": -60, "JOBS": -10}, 70, "PUBLIC",
		{"facility": f["id"], "district": f["district"], "operator": f["org"], "workers_affected": affected, "hazard_class": r["hazard"],
		"in_violation": true, "crisis": true, "hazard": hazard_key(f["id"]), "cause_records": causes_at(world, f["id"]),
		"condition": int(f["condition"]) / S}, {"districts": [f["district"]]})

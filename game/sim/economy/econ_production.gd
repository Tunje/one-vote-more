class_name EconProduction
extends RefCounted
## PRODUCTION phase (spec §4, §6.6): labor matching, utility allocation, facility output, capacity products,
## construction progress, accidents, emissions.

const S := EconUtil.S
const UTILITY_TYPES := ["POWER", "WATERWORKS"]


static func produce(world: WorldState) -> void:
	var s := EconUtil.st(world)
	EconLabor.match(world)
	var facs := EconUtil.sorted_keys(world.table("facility"))
	_pool_inputs(world, facs)
	var plan := {}  # fid -> {lab, mi, act}
	for fid in facs:
		var f: Dictionary = world.table("facility")[fid]
		plan[fid] = _plan(world, f)
	# ---- energy ----
	var pop_d := EconHouseholds.population_by_district(world)
	var e_supply := 0
	for fid in facs:
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] == "POWER":
			e_supply += int(1200 * S * plan[fid]["act"] * _eff(world, f) * EconUtil.fscale(f))
	var e_dem := []  # [tier, key, qty, payer_acct, fid_or_district]
	var hh_first: bool = str(EconUtil.lever(world, "ECON_ENERGY_PRIORITY", "HOUSEHOLDS_FIRST")) != "INDUSTRY_FIRST"
	for fid in facs:
		var f: Dictionary = world.table("facility")[fid]
		var need: float = float(EconData.RECIPES[f["type"]]["in"].get("ENERGY", 0)) * plan[fid]["act"] * EconUtil.fscale(f)
		if need > 0.0:
			e_dem.append([_prio(f["type"], hh_first), fid, int(need * S), EconUtil.acct(f["org"]), "fac"])
	for d in EconUtil.sorted_keys(pop_d):
		if EconUtil.connected(d) and pop_d[d] > 0:
			e_dem.append([1 if hh_first else 4, d, int(float(pop_d[d]) * EconData.NEED["ENERGY"]), "", "hh"])
	var e_served := _allocate(e_supply, e_dem)
	# ---- water (water works need their energy first) ----
	var w_supply := 0
	for fid in facs:
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] == "WATERWORKS":
			var re: float = e_served.get(fid, 1.0)
			w_supply += int(1500 * S * plan[fid]["act"] * re * _eff(world, f) * EconUtil.fscale(f))
	var w_dem := []
	for fid in facs:
		var f: Dictionary = world.table("facility")[fid]
		var need: float = float(EconData.RECIPES[f["type"]]["in"].get("WATER", 0)) * plan[fid]["act"] * EconUtil.fscale(f)
		if need > 0.0:
			w_dem.append([_prio(f["type"], true), fid, int(need * S), EconUtil.acct(f["org"]), "fac"])
	for d in EconUtil.sorted_keys(pop_d):
		if EconUtil.connected(d) and pop_d[d] > 0:
			w_dem.append([1, d, int(float(pop_d[d]) * EconData.NEED["WATER"]), "", "hh"])
	var w_served := _allocate(w_supply, w_dem)
	s["util_served_hh"] = {}
	for d in pop_d:
		s["util_served_hh"][d] = [e_served.get(d, 1.0), w_served.get(d, 1.0)]
	s["util_supply"] = {"E": e_supply, "W": w_supply}
	s["util_demand"] = {"E": _total(e_dem), "W": _total(w_dem)}
	# record utility consumption for billing
	var used := {}
	for row in e_dem:
		if row[4] == "fac":
			var a: String = row[3]
			if not used.has(a): used[a] = [0, 0]
			used[a][0] += int(row[2] * e_served.get(row[1], 1.0))
	for row in w_dem:
		if row[4] == "fac":
			var a: String = row[3]
			if not used.has(a): used[a] = [0, 0]
			used[a][1] += int(row[2] * w_served.get(row[1], 1.0))
	for gid in EconUtil.sorted_keys(world.table("hh")):
		var g: Dictionary = world.table("hh")[gid]
		var persons := EconHouseholds.persons(g)
		var sv: Array = s["util_served_hh"].get(g["district"], [1.0, 1.0])
		var a := EconUtil.hh_acct(gid)
		used[a] = [int(persons * EconData.NEED["ENERGY"] * sv[0]), int(persons * EconData.NEED["WATER"] * sv[1])]
	s["util_used"] = used
	if e_supply < _total(e_dem) * 98 / 100 or w_supply < _total(w_dem) * 98 / 100:
		var unserved := 1.0 - minf(float(e_supply) / maxf(1.0, float(_total(e_dem))), float(w_supply) / maxf(1.0, float(_total(w_dem))))
		var cpw := EconFinance.org_by_key(world, "CPW")
		EconFacts.emit(world, "ECON_UTILITY_OUTAGE", null, [["COMPANY", cpw]], [["COMPANY", cpw, 0.3], ["GOVERNMENT", "government", 0.7]],
			{"INFRASTRUCTURE": -int(400.0 * unserved), "PUBLIC_SERVICES": -int(100.0 * unserved)}, int(300.0 * unserved), "PUBLIC")
	# ---- facility output ----
	var health := {}
	var edu := {}
	var emissions := {}
	var freight := 0
	for fid in facs:
		var f: Dictionary = world.table("facility")[fid]
		var r: Dictionary = EconData.RECIPES[f["type"]]
		var u: float = plan[fid]["u"]
		if r["in"].has("ENERGY"): u = minf(u, e_served.get(fid, 1.0))
		if r["in"].has("WATER"): u = minf(u, w_served.get(fid, 1.0))
		if f["type"] == "WATERWORKS": u = minf(u, e_served.get(fid, 1.0))
		var t := float(f["T"]) / 1000.0
		if f["mothball"]: t = 0.0
		f["e_served"] = int(1000.0 * float(e_served.get(fid, 1.0)))
		f["w_served"] = int(1000.0 * float(w_served.get(fid, 1.0)))
		# E103: months without the power or water this plant needs (staffing drops to a core crew, see post_vacancies)
		var cut_off: bool = (r["in"].has("ENERGY") and f["e_served"] < 100) or (r["in"].has("WATER") and f["w_served"] < 100)
		f["dark_m"] = int(f.get("dark_m", 0)) + 1 if cut_off and not f["mothball"] else 0
		var act := t * u
		f["util"] = int(act * 1000)
		_consume_inputs(world, f, act)
		_upkeep(world, f, t > 0.0)
		var out_qty := int(float(r["out"][1]) * S * act * _eff(world, f) * EconUtil.fscale(f) * EconUtil.tier_out(f))  # E106 tier
		f["out_last"] = out_qty
		var good: String = r["out"][0]
		if good in EconData.MARKET_GOODS:
			if out_qty > 0:
				var unit_cost: int = f.get("_in_cost", 0) * S / maxi(1, out_qty)
				EconUtil.inv_add(world, f["org"], good, f["district"], out_qty, unit_cost)
				EconUtil.qflow(world, good, "made", out_qty)
		elif good == "SERVICES":
			f["svc_cap"] = out_qty
		elif good == "HEALTH":
			health[f["district"]] = health.get(f["district"], 0) + out_qty
		elif good == "EDUCATION":
			edu[f["district"]] = edu.get(f["district"], 0) + out_qty
		elif good == "FREIGHT":
			freight += out_qty
		var red := float(EconUtil.lever(world, "ECON_EMISSION_REDUCTION", 0)) / 100.0
		emissions[f["district"]] = emissions.get(f["district"], 0.0) + float(r["poll"]) * act * (1.0 - red)
		_accidents(world, f, act)
	s["freight_cap"] = freight
	s["emissions"] = {}
	for d in emissions:
		s["emissions"][d] = int(emissions[d] * 1000)
	_service_access(world, health, edu, pop_d)
	EconConstruction.progress(world)
	_cold_start(world)


## E101 (M12, no imports): after BLACKOUT_MONTHS with no power at all, the public operator cannibalises parts from its
## other dead plants to overhaul one power plant (+COLD_START_STEP condition a month, taken from the donors), so a
## total blackout is not a permanent dead end. Without donors the blackout stays.
static func _cold_start(world: WorldState) -> void:
	if EconUtil.off(world, "E101"):
		return
	var s := EconUtil.st(world)
	s["blackout_m"] = int(s.get("blackout_m", 0)) + 1 if int(s.get("util_supply", {}).get("E", 1)) <= 0 else 0
	if int(s["blackout_m"]) < EconData.BLACKOUT_MONTHS:
		return
	var plants: Array = []
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] == "POWER" and f["mothball"]:
			plants.append(f)
	if plants.size() < 2:
		return
	plants.sort_custom(func(a, b): return a["condition"] > b["condition"] or (a["condition"] == b["condition"] and a["id"] < b["id"]))
	var target: Dictionary = plants[0]
	var need := EconData.COLD_START_STEP * S
	for i in range(plants.size() - 1, 0, -1):
		var donor: Dictionary = plants[i]
		var take := mini(need, int(donor["condition"]))
		donor["condition"] -= take
		target["condition"] += take
		need -= take
		if need <= 0:
			break
	target["closed_unsafe"] = true  # the overhaul path (E84) reopens it at REOPEN_CONDITION
	if target["condition"] >= EconData.REOPEN_CONDITION * S:
		target["mothball"] = false
		target["closed_unsafe"] = false
		target["unsafe_m"] = 0
		EconFacts.emit(world, "ECON_FACILITY_REOPENED", target["district"], [["COMPANY", target["org"]]],
			[["GOVERNMENT", "government", 1.0]], {"INFRASTRUCTURE": 20, "JOBS": 10}, 50, "PUBLIC", {"facility": target["id"], "reason": "cold_start"})


## E93: an owner moves its own market inputs between its districts (internal transfer at book value) before
## production. Generalises E75 (upkeep pooling): a vertically integrated owner (e.g. the public operator holding
## both mines and processing after a takeover) cannot buy from itself on the market.
static func _pool_inputs(world: WorldState, facs: Array) -> void:
	if EconUtil.off(world, "E93"):
		return
	for fid in facs:
		var f: Dictionary = world.table("facility")[fid]
		if f["mothball"]:
			continue
		var r: Dictionary = EconData.RECIPES[f["type"]]
		var t := float(f["T"]) / 1000.0
		for g in EconUtil.sorted_keys(r["in"]):
			if not (g in EconData.MARKET_GOODS):
				continue
			var req := int(float(r["in"][g]) * S * t * EconUtil.fscale(f) * EconUtil.tier_in(f))
			var have := EconUtil.inv_get(world, f["org"], g, f["district"])
			if have >= req:
				continue
			for d2 in EconUtil.sorted_keys(EconData.DISTRICTS):
				if d2 == f["district"] or have >= req:
					continue
				var w2 := EconUtil.inv_wac(world, f["org"], g, d2)
				var t2 := EconUtil.inv_take(world, f["org"], g, d2, req - have)
				if t2 > 0:
					EconUtil.inv_add(world, f["org"], g, f["district"], t2, w2)
					have += t2


## Labor and market-input ratios before utilities. act = T × min(lab, inputs).
static func _plan(world: WorldState, f: Dictionary) -> Dictionary:
	var r: Dictionary = EconData.RECIPES[f["type"]]
	var t := 0.0 if f["mothball"] else float(f["T"]) / 1000.0
	var lab := 1.0
	for tier in r["labor"]:
		var req := float(r["labor"][tier]) * S * t
		if req > 0.0:
			# M10: staff are whole persons; a tier short by less than half a person counts as fully staffed
			var have := float(EconLabor.tier_total(f["staff"], tier)) + (float(f.get("named_sp", 0)) * S if tier == "Sp" else 0.0)
			lab = minf(lab, minf(1.0, have / maxf(req - 0.5 * S, 0.5 * req)))
	lab *= EconUnions.work_factor(world, f)  # M9: strike / lockout
	var mi := 1.0
	var soft_f := 1.0
	var soft: Array = EconData.SOFT_INPUTS.get(f["type"], [])
	for g in r["in"]:
		if g in EconData.MARKET_GOODS:
			var req := float(r["in"][g]) * S * t * EconUtil.fscale(f) * EconUtil.tier_in(f)
			if req > 0.0:
				var ratio := float(EconUtil.inv_get(world, f["org"], g, f["district"])) / req
				if g in soft:
					soft_f = minf(soft_f, 0.9 + 0.1 * minf(1.0, ratio))
				else:
					mi = minf(mi, ratio)
	var u := minf(1.0, minf(lab, mi)) * soft_f
	return {"u": u, "act": t * u}


static func _eff(world: WorldState, f: Dictionary) -> float:
	var cond := float(f["condition"]) / S
	var e_cond := minf(1.0, 0.6 + cond / 250.0)
	var mgmt := 50.0
	if world.table("org").has(f["org"]):
		mgmt = float(world.table("org")[f["org"]]["ceo"]["mgmt"])
	return e_cond * (0.9 + 0.002 * mgmt)


## Utility priority tier: lower = served first (spec §6.6).
static func _prio(ftype: String, hh_first: bool) -> int:
	if ftype == "CLINIC":
		return 0
	if ftype in ["FARM", "DEPOT"]:
		return 1  # E89: farms and freight share the household tier pro rata — strictly after households, a 20% shortage
		          # meant no food grown (farms) or none delivered (depot), i.e. famine with full warehouses
	if ftype in ["SCHOOL", "ADMIN"]:  # E66
		return 2
	if ftype == "WATERWORKS":
		return 0  # E81: water is everyone's input (households, farms, clinics); a power shortage must not cut it first
	return 4 if hh_first else 1


## Allocate supply to demand rows by priority tier, pro-rata within a tier. Returns key -> served ratio.
static func _allocate(supply: int, rows: Array) -> Dictionary:
	var out := {}
	var left := supply
	for tier in [0, 1, 2, 3, 4]:
		var tot := 0
		for r in rows:
			if r[0] == tier:
				tot += r[2]
		if tot == 0:
			continue
		var ratio := clampf(float(left) / float(tot), 0.0, 1.0)
		for r in rows:
			if r[0] == tier:
				out[r[1]] = ratio
		left = maxi(0, left - tot)
	return out


static func _total(rows: Array) -> int:
	var t := 0
	for r in rows:
		t += r[2]
	return t


static func _consume_inputs(world: WorldState, f: Dictionary, act: float) -> void:
	var r: Dictionary = EconData.RECIPES[f["type"]]
	var cost := 0
	for g in r["in"]:
		if g in EconData.MARKET_GOODS:
			var q := int(float(r["in"][g]) * S * act * EconUtil.fscale(f) * EconUtil.tier_in(f))
			var wac := EconUtil.inv_wac(world, f["org"], g, f["district"])
			var took := EconUtil.inv_take(world, f["org"], g, f["district"], q)
			EconUtil.qflow(world, g, "burned", took)
			cost += EconUtil.val(took, wac)
	var goods_out: String = r["out"][0]
	if goods_out in EconData.MARKET_GOODS:
		f["_in_cost"] = cost / S  # credits; folded into the product's WAC
	else:
		f["_in_cost"] = 0
		EconFinance.pl_add(world, f["org"], "cogs", cost)  # services/utilities/institutions expense inputs directly


static func _upkeep(world: WorldState, f: Dictionary, running: bool) -> void:
	var r: Dictionary = EconData.RECIPES[f["type"]]
	var cond: int = f["condition"]
	var frac := 1.0
	var e84 := not EconUtil.off(world, "E84")
	var repairing: bool = e84 and f["mothball"] and f.get("closed_unsafe", false)
	for pair in [["MATERIAL", float(r["upkeep"])], ["COMPONENT", float(EconData.UPKEEP_COMPONENT.get(f["type"], 0))]]:
		var need: float = pair[1] * S * (1.0 if running or repairing else 0.25) * EconUtil.fscale(f)
		if need <= 0.0:
			continue
		var wac := EconUtil.inv_wac(world, f["org"], pair[0], f["district"])
		var got := EconUtil.inv_take(world, f["org"], pair[0], f["district"], int(need))
		# E75: upkeep parts are pooled across the owner's districts (internal transfer; multi-site operators
		# like the public utility otherwise starve one site while stock sits at another)
		if got < int(need):
			for d2 in EconUtil.sorted_keys(EconData.DISTRICTS):
				if d2 == f["district"] or got >= int(need):
					continue
				var w2 := EconUtil.inv_wac(world, f["org"], pair[0], d2)
				var t2 := EconUtil.inv_take(world, f["org"], pair[0], d2, int(need) - got)
				if t2 > 0:
					wac = int((float(wac) * float(got) + float(w2) * float(t2)) / float(got + t2))
					got += t2
		EconUtil.qflow(world, pair[0], "burned", got)
		EconFinance.pl_add(world, f["org"], "cogs", EconUtil.val(got, wac))
		frac = minf(frac, clampf(float(got) / need, 0.0, 1.0))
	if not repairing:
		cond -= int(1.0 * S * (1.0 - frac))
	# E84: maintenance restores. Fully supplied upkeep slowly repairs a running plant; a plant closed as unsafe
	# is overhauled with full upkeep and reopens at REOPEN_CONDITION (before, condition could only fall).
	if e84 and running and frac >= 0.999:
		cond += EconData.REPAIR_PER_MONTH
	elif repairing:
		cond += int(float(EconData.OVERHAUL_PER_MONTH) * frac)
		# E104: the repair crew restores condition by labour alone (salvage, local craft) — slower without parts, but
		# a colony with no materials can still restart its essential plants from cold
		if not EconUtil.off(world, "E104"):
			var core := 0.0
			var have := 0.0
			for t in r["labor"]:
				core += float(r["labor"][t]) * EconData.REPAIR_CREW_SHARE * EconUtil.fscale(f)
				have += float(EconLabor.tier_total(f["staff"], t)) / S
			cond += int(float(EconData.LABOUR_REPAIR_PER_MONTH) * clampf(have / maxf(core, 1.0), 0.0, 1.0))
		f["overhaul_frac"] = int(frac * 1000.0)  # E84b (a9): a cash-starved owner overhauls more slowly
	f["condition"] = clampi(cond, 0, 100 * S)
	var hazardous: bool = r["hazard"] == "HIGH" or f["type"] == "MINE"
	if repairing and f["condition"] >= EconData.REOPEN_CONDITION * S:
		var o: Dictionary = world.table("org").get(f["org"], {})
		if o.get("status", "") in ["ACTIVE", "DISTRESSED", "ADMINISTRATION"]:
			f["mothball"] = false
			f["closed_unsafe"] = false
			f["unsafe_m"] = 0
			f["low_util_m"] = 0
			EconFacts.emit(world, "ECON_FACILITY_REOPENED", f["district"], [["COMPANY", f["org"]]],
				EconFacts.company_blame(world, f["org"], 0.7), {"JOBS": 10, "SAFETY": 5}, 30, "PUBLIC", {"facility": f["id"]})
		return
	if f["condition"] < 25 * S and hazardous:  # E64: only hazardous plants close; others just lose efficiency
		f["unsafe_m"] += 1
		if f["unsafe_m"] >= 3 and not f["mothball"]:
			f["mothball"] = true
			f["closed_unsafe"] = true
			EconFacts.emit(world, "ECON_FACILITY_CLOSED_UNSAFE", f["district"], [["COMPANY", f["org"]]],
				EconFacts.company_blame(world, f["org"], 0.7), {"JOBS": -10, "SAFETY": -10}, 35, "PUBLIC", {"facility": f["id"]})
	else:
		f["unsafe_m"] = 0


static func _accidents(world: WorldState, f: Dictionary, act: float) -> void:
	if act <= 0.0:
		return
	var r: Dictionary = EconData.RECIPES[f["type"]]
	var workers := float(EconLabor.staff_total(f["staff"])) / S
	var std: String = str(EconUtil.lever(world, "LAW_SAFETY_STANDARD", "BASIC"))
	var sm := 0.7 if std == "STANDARD" else (0.45 if std == "STRICT" else 1.0)
	var v := 1.5 if not f["licensed"] else 1.0
	var p := workers * float(r["acc"]) / 12.0 / 1000.0 * (1.0 + (100.0 - float(f["condition"]) / S) / 100.0) * sm * v
	var rng := world.rng.stream("econ.accident")
	var k := int(floor(p))
	if rng.randf() < p - floor(p):
		k += 1
	for _i in k:
		var affected := 1
		if r["hazard"] == "HIGH" or f["type"] == "MINE":
			affected = 1 + rng.randi_range(0, 2)
		EconFacts.emit(world, "COMP_WORKPLACE_ACCIDENT", f["district"], [["COMPANY", f["org"]]],
			EconFacts.company_blame(world, f["org"], 0.7), {"SAFETY": -mini(30, 5 * affected)}, 15 + 10 * affected, "PUBLIC",
			{"facility": f["id"], "district": f["district"], "operator": f["org"], "workers_affected": affected, "hazard_class": r["hazard"],
			"in_violation": not f["licensed"]}, {"districts": [f["district"]], "occupations": [EconLabor.occupation_of(world, f["org"], f["type"])]})


## Health/education access per district (spec §7.5): pooled capacity, 0.7 weight outside the host district.
static func _service_access(world: WorldState, health: Dictionary, edu: Dictionary, pop_d: Dictionary) -> void:
	var s := EconUtil.st(world)
	s["health_access"] = _access(health, pop_d, 1.0)
	var kids := {}
	for gid in world.table("hh"):
		var g: Dictionary = world.table("hh")[gid]
		kids[g["district"]] = kids.get(g["district"], 0) + int(g["children"] * 0.75)  # school-age share
	s["edu_access"] = _access(edu, kids, 1.0)


static func _access(cap: Dictionary, need: Dictionary, _w: float) -> Dictionary:
	var out := {}
	var spare := 0
	var host_need := 0
	for d in cap:
		var n: int = need.get(d, 0)
		spare += maxi(0, cap[d] - n)
		host_need += n
	var other_need := 0
	for d in need:
		if not cap.has(d):
			other_need += need[d]
	for d in EconUtil.sorted_keys(need):
		var n: int = need[d]
		if n <= 0:
			out[d] = 1000
		elif cap.has(d):
			out[d] = int(1000.0 * minf(1.0, float(cap[d]) / float(n)))
		else:
			var share := minf(1.0, float(spare) / maxf(1.0, float(other_need)))
			out[d] = int(1000.0 * 0.7 * share + 0.0)
	return out

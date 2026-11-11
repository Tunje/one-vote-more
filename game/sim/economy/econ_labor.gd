class_name EconLabor
extends RefCounted
## Labor market (spec §6.3, §6.5): vacancies, layoffs, tier-down matching, wage index.
## People are stored in milli-persons (×1000). Employment lives in facility["staff"][tier][group_id]
## and in contractor org["crew"][tier][group_id].

const S := EconUtil.S
const LOWER_TIERS := {"Sp": ["Sp"], "S": ["S", "Sp"], "G": ["G", "S", "Sp"]}


static func occupation_of(world: WorldState, org_id: String, ftype: String) -> String:
	var o: Dictionary = world.table("org")[org_id]
	if o["type"] in EconData.PUBLIC_TYPES:
		return "PUBLIC_SECTOR"
	if ftype == "CREW":
		return "INDUSTRY"
	return EconData.RECIPES[ftype]["occ"]


## Workforce slots required now (mu per tier) for a facility.
static func required(f: Dictionary) -> Dictionary:
	var out := {}
	var r: Dictionary = EconData.RECIPES[f["type"]]
	for t in r["labor"]:
		out[t] = 0 if f["mothball"] else int(float(r["labor"][t]) * S * float(f["T"]) / 1000.0 * EconUtil.fscale(f))
	return out


static func staff_total(staff: Dictionary) -> int:
	var n := 0
	for t in staff:
		for g in staff[t]:
			n += staff[t][g]
	return n


static func tier_total(staff: Dictionary, t: String) -> int:
	var n := 0
	for g in staff.get(t, {}):
		n += staff[t][g]
	return n


## Remove qty mu from a tier's staff records, largest holders first. Returns removed.
static func remove(staff: Dictionary, t: String, qty: int) -> int:
	var recs: Dictionary = staff.get(t, {})
	var gids := recs.keys()
	gids.sort_custom(func(a, b): return recs[a] > recs[b] or (recs[a] == recs[b] and a < b))
	var left := qty
	for g in gids:
		if left <= 0:
			break
		var take := mini(left, recs[g])
		recs[g] -= take
		left -= take
		if recs[g] <= 0:
			recs.erase(g)
	return qty - left


## Build this month's vacancy list and apply layoffs (COMPANY_AI; also at setup).
static func post_vacancies(world: WorldState) -> void:
	var s := EconUtil.st(world)
	var vacs: Array = []
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		var org: Dictionary = world.table("org")[f["org"]]
		if org["status"] in ["LIQUIDATION", "DISSOLVED"]:
			f["mothball"] = true
		var req := required(f)
		# labor hoarding (E49): keep ≥ 70% of a full crew unless under-used (< 70%) for 3 months
		f["under_m"] = f.get("under_m", 0) + 1 if f["T"] < 700 else 0
		var hoard: bool = not f["mothball"] and f["under_m"] < 3 and org["status"] == "ACTIVE"
		for t in ["G", "S", "Sp"]:
			if not f["staff"].has(t):
				f["staff"][t] = {}
			var cur := tier_total(f["staff"], t)
			var need: int = req.get(t, 0)
			if hoard:
				need = maxi(need, int(EconData.RECIPES[f["type"]]["labor"].get(t, 0) * S * 7 / 10))
			if cur > need * 11 / 10:
				var cap := cur if f["mothball"] else int(cur * EconData.LAYOFF_RATE)
				var cut := remove(f["staff"], t, mini(cur - need, maxi(cap, S)))
				_note_layoff(world, f["org"], f["district"], cut)
			elif need > cur:
				vacs.append({"emp": fid, "kind": "fac", "tier": t, "qty": need - cur, "district": f["district"],
					"org": f["org"], "wage": offer(world, f["org"], t), "target": staff_total(f["staff"]) + need - cur})
	for oid in EconUtil.sorted_keys(world.table("org")):
		var o: Dictionary = world.table("org")[oid]
		if not o["is_contractor"]:
			continue
		for t in ["G", "S", "Sp"]:
			if not o["crew"].has(t):
				o["crew"][t] = {}
			var cur := tier_total(o["crew"], t)
			var need: int = int(o["crew_target"].get(t, 0)) * S
			if o["status"] in ["LIQUIDATION", "DISSOLVED"]:
				need = 0
			if cur > need:
				var cap := cur if need == 0 and o["status"] in ["LIQUIDATION", "DISSOLVED"] else maxi(int(cur * EconData.LAYOFF_RATE), S)
				var cut := remove(o["crew"], t, mini(cur - need, cap))
				_note_layoff(world, oid, o["hq"], cut)
			elif need > cur:
				vacs.append({"emp": oid, "kind": "crew", "tier": t, "qty": need - cur, "district": o["hq"], "org": oid,
					"wage": offer(world, oid, t), "target": staff_total(o["crew"]) + need - cur})
	s["vacancies"] = vacs


static func _note_layoff(world: WorldState, org_id: String, district: String, qty: int) -> void:
	if qty <= 0:
		return
	var s := EconUtil.st(world)
	var lay: Dictionary = s.get("layoffs_m", {})
	var k := org_id + "|" + district
	lay[k] = lay.get(k, 0) + qty
	s["layoffs_m"] = lay


## Wage offer (mcr) for a tier at an employer (spec §6.5).
static func offer(world: WorldState, org_id: String, t: String) -> int:
	var s := EconUtil.st(world)
	var o: Dictionary = world.table("org")[org_id]
	var w := float(s["wage"][t])
	if o["type"] in EconData.PUBLIC_TYPES:
		w *= float(EconUtil.lever(world, "ECON_PUBLIC_PAY_INDEX", 100)) / 100.0
	else:
		w *= 1.0 + 0.05 * minf(3.0, float(o["premium_m"].get(t, 0)))
	w *= 1.0 + float(o.get("union_pm", 0)) / 1000.0  # M9: wage gains won by a strike (decay in EconUnions)
	var floor_w := float(world.values.get("ECON_W_REF", s["wage"]["S"])) * float(EconUtil.lever(world, "ECON_MIN_WAGE", 40)) / 100.0
	return int(maxf(w, floor_w))


## Employed mu per group (all slots) and per (group, occupation). Stored on each group as g["emp"].
static func recount(world: WorldState) -> void:
	var hh := world.table("hh")
	for gid in hh:
		hh[gid]["emp"] = {}
	# E67: Specialist-tier jobs → PROFESSIONAL; agricultural co-op member-farmers and micro co-op worker-owners → BUSINESS_OWNER
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		var occ := occupation_of(world, f["org"], f["type"])
		var o: Dictionary = world.table("org").get(f["org"], {})
		var owner_share := 0.0
		if o.get("type", "") == "COOPERATIVE":
			if f["type"] == "FARM":
				owner_share = EconData.COOP_FARM_OWNER_SHARE
			elif str(o.get("key", "")).begins_with("MICRO"):
				owner_share = 1.0
		for t in f["staff"]:
			for gid in f["staff"][t]:
				var e: Dictionary = hh[gid]["emp"]
				var n: int = f["staff"][t][gid]
				if t == "Sp":
					e["PROFESSIONAL"] = e.get("PROFESSIONAL", 0) + n
					continue
				var owners := int(float(n) * owner_share)
				if owners > 0:
					e["BUSINESS_OWNER"] = e.get("BUSINESS_OWNER", 0) + owners
				e[occ] = e.get(occ, 0) + n - owners
	for oid in EconUtil.sorted_keys(world.table("org")):
		var o: Dictionary = world.table("org")[oid]
		if not o["is_contractor"]:
			continue
		var occ := occupation_of(world, oid, "CREW")
		for t in o["crew"]:
			for gid in o["crew"][t]:
				var e: Dictionary = hh[gid]["emp"]
				var k := "PROFESSIONAL" if t == "Sp" else occ
				e[k] = e.get(k, 0) + o["crew"][t][gid]
	# sole proprietors (E67): self-employed adults count as employed, occupation BUSINESS_OWNER
	for gid in hh:
		var se: int = hh[gid].get("self_emp", 0)
		if se > 0:
			hh[gid]["emp"]["SELF_EMPLOYED"] = se


static func employed(g: Dictionary) -> int:
	var n := 0
	for occ in g["emp"]:
		n += g["emp"][occ]
	return n


## Effective labor available in a group (health reduces availability, spec §7.5).
static func available(world: WorldState, g: Dictionary) -> int:
	var health: float = float(EconUtil.st(world).get("health_access", {}).get(g["district"], 1000)) / 1000.0
	var lf := int(float(g["lf"]) * (1.0 - 0.08 * (1.0 - health)))
	return maxi(0, lf - employed(g))


## Match vacancies to unemployed workers (PRODUCTION; also at setup with no_limits = true).
static func match(world: WorldState, no_limits: bool = false) -> void:
	var s := EconUtil.st(world)
	recount(world)
	var hh := world.table("hh")
	var gids := EconUtil.sorted_keys(hh)
	var hired_by_emp := {}
	var unfilled := {"G": 0, "S": 0, "Sp": 0}
	var vacs: Array = s.get("vacancies", [])
	for t in EconData.TIERS:  # Sp, S, G
		var tv: Array = vacs.filter(func(v): return v["tier"] == t)
		tv.sort_custom(func(a, b): return a["wage"] > b["wage"] or (a["wage"] == b["wage"] and a["emp"] < b["emp"]))
		for v in tv:
			var cap: int = v["qty"]
			if not no_limits:
				var lim: int = maxi(EconData.HIRE_MIN * S, int(v["target"] * EconData.HIRE_RATE))
				cap = mini(cap, lim - hired_by_emp.get(v["emp"], 0))
			var left := maxi(cap, 0)
			for src_t in LOWER_TIERS[t]:
				if left <= 0:
					break
				var cands: Array = gids.filter(func(gid): return hh[gid]["tier"] == src_t)
				cands.sort_custom(func(a, b):
					var da: int = 0 if hh[a]["district"] == v["district"] else 1
					var db: int = 0 if hh[b]["district"] == v["district"] else 1
					return da < db or (da == db and a < b))
				for gid in cands:
					if left <= 0:
						break
					var g: Dictionary = hh[gid]
					var take := mini(left, available(world, g))
					if take <= 0:
						continue
					var rec: Dictionary = world.table("facility")[v["emp"]]["staff"] if v["kind"] == "fac" else world.table("org")[v["emp"]]["crew"]
					if not rec.has(t):
						rec[t] = {}
					rec[t][gid] = rec[t].get(gid, 0) + take
					var occ := occupation_of(world, v["org"], world.table("facility")[v["emp"]]["type"] if v["kind"] == "fac" else "CREW")
					g["emp"][occ] = g["emp"].get(occ, 0) + take
					left -= take
					hired_by_emp[v["emp"]] = hired_by_emp.get(v["emp"], 0) + take
			var hired := maxi(cap, 0) - left
			unfilled[t] += maxi(0, v["qty"] - hired)
			# vacancy premium memory for wage offers
			var o: Dictionary = world.table("org")[v["org"]]
			if left > 0:  # workers were not available (not merely the hiring-speed cap)
				o["premium_m"][t] = o["premium_m"].get(t, 0) + 1
			else:
				o["premium_m"][t] = 0
	s["vac_unfilled"] = unfilled
	s["vacancies"] = []
	recount(world)


## Wage index update (COMPANY_AI, spec §6.5) + unemployment rates.
static func update_wage_index(world: WorldState) -> void:
	var s := EconUtil.st(world)
	var lf := {"G": 0, "S": 0, "Sp": 0}
	var emp := {"G": 0, "S": 0, "Sp": 0}
	for gid in world.table("hh"):
		var g: Dictionary = world.table("hh")[gid]
		lf[g["tier"]] += g["lf"]
		emp[g["tier"]] += employed(g)
	for t in lf:
		var u := 0.0 if lf[t] == 0 else float(lf[t] - emp[t]) / float(lf[t])
		var v := float(s["vac_unfilled"].get(t, 0)) / maxf(1.0, float(emp[t] + s["vac_unfilled"].get(t, 0)))
		s["unemp_rate"][t] = int(u * 100000)
		var g := clampf(0.10 * (v - u + EconData.WAGE_NEUTRAL_U), -EconData.WAGE_MAX_CUT_PM, 0.01)  # E55 damped; E78 sticky downward
		s["wage"][t] = int(float(s["wage"][t]) * (1.0 + g))

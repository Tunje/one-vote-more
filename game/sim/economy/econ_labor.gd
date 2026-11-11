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
		return "CONSTRUCTION"
	return EconData.RECIPES[ftype]["occ"]


## Workforce slots required now (mu per tier) for a facility.
static func required(f: Dictionary) -> Dictionary:
	var out := {}
	var r: Dictionary = EconData.RECIPES[f["type"]]
	for t in r["labor"]:
		out[t] = 0 if f["mothball"] else int(float(r["labor"][t]) * S * float(f["T"]) / 1000.0 * EconUtil.fscale(f))
	if out.has("Sp"):
		out["Sp"] = maxi(0, out["Sp"] - int(f.get("named_sp", 0)) * S)  # J26 / PD §11.5: posts held by named senior staff
	return out


## J26 (a9) / PD §11.5: the named political staff, civil servants and judges hold senior public posts. They fill
## Specialist slots of the government administration (first ADMIN facility) so they are not counted twice.
static func assign_named_staff(world: WorldState) -> void:
	var named := 0
	if world.peek("person").size() > 0 or world.peek("judge").size() > 0:
		named = int(preload("res://sim/staff/staff_query.gd").named_headcount(world).get("public", 0))
	var first := true
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] != "ADMIN":
			continue
		f["named_sp"] = named if first else 0
		first = false


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
	assign_named_staff(world)
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
				var cut := _cut(world, f["org"], f["type"], f["staff"], t, mini(cur - need, maxi(cap, S)))
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
				var cut := _cut(world, oid, "CREW", o["crew"], t, mini(cur - need, cap))
				_note_layoff(world, oid, o["hq"], cut)
			elif need > cur:
				vacs.append({"emp": oid, "kind": "crew", "tier": t, "qty": need - cur, "district": o["hq"], "org": oid,
					"wage": offer(world, oid, t), "target": staff_total(o["crew"]) + need - cur})
	s["vacancies"] = vacs
	EconPop.sync(world)


## Lays off whole persons (rounded up, at most what is there) from a staff tier: the people become UNEMPLOYED
## in their leaves (M10). Returns milli-persons removed.
static func _cut(world: WorldState, org_id: String, ftype: String, staff: Dictionary, t: String, qty_mu: int) -> int:
	var persons := mini((qty_mu + S / 2) / S, tier_total(staff, t) / S)
	var cut := EconPop.remove_staff(staff, t, persons)
	var occ := EconPop.person_occ(world, org_id, ftype, t)
	var n := 0
	for k in EconUtil.sorted_keys(cut):
		var p := EconPop.lab_parts(k)
		EconPop.layoff(world, p[0], p[1], occ, cut[k])
		n += cut[k]
	return n * S


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


## Pool head counts from the population leaves (M10: the leaves are the only source of truth).
static func recount(world: WorldState) -> void:
	EconPop.sync(world)


static func employed(g: Dictionary) -> int:
	var n := 0
	for occ in g["emp"]:
		n += g["emp"][occ]
	return n


## Match vacancies to unemployed people (PRODUCTION; also at setup with no_limits = true). Supply is the
## UNEMPLOYED people per (housing block, skill) in the leaves, less those kept out by poor health (spec §7.5).
## Hires are PopStore transfers UNEMPLOYED → EMPLOYED; allocations are staff[slot tier]["hb|skill"] (whole persons).
static func match(world: WorldState, no_limits: bool = false) -> void:
	var s := EconUtil.st(world)
	EconPop.realign(world)
	var unemp := EconPop.people_by_lab(world, "UNEMPLOYED")
	var empl := EconPop.people_by_lab(world, "EMPLOYED")
	var health: Dictionary = s.get("health_access", {})
	var avail := {}
	for k in unemp:
		var p := EconPop.lab_parts(k)
		var h := float(health.get(EconPop.district_of(p[0]), 1000)) / 1000.0
		var lf: int = int(unemp[k]) + int(empl.get(k, 0))
		avail[k] = maxi(0, int(unemp[k]) - int(float(lf) * 0.08 * (1.0 - h)))
	var hbs: Array = []
	for d in EconUtil.sorted_keys(EconData.DISTRICTS):
		hbs.append(EconPop.hb_of(d))
	var hired_by_emp := {}
	var unfilled := {"G": 0, "S": 0, "Sp": 0}
	var vacs: Array = s.get("vacancies", [])
	for t in EconData.TIERS:  # Sp, S, G
		var tv: Array = vacs.filter(func(v): return v["tier"] == t)
		tv.sort_custom(func(a, b): return a["wage"] > b["wage"] or (a["wage"] == b["wage"] and a["emp"] < b["emp"]))
		for v in tv:
			var cap: int = (int(v["qty"]) + S / 2) / S  # whole persons, rounded (M10)
			if not no_limits:
				var lim: int = (maxi(EconData.HIRE_MIN * S, int(v["target"] * EconData.HIRE_RATE)) + S / 2) / S
				cap = mini(cap, lim - hired_by_emp.get(v["emp"], 0))
			var left := maxi(cap, 0)
			var home := EconPop.hb_of(v["district"])
			var order: Array = [home] + hbs.filter(func(x): return x != home)
			var ftype: String = world.table("facility")[v["emp"]]["type"] if v["kind"] == "fac" else "CREW"
			var occ := EconPop.person_occ(world, v["org"], ftype, t)
			for src_t in LOWER_TIERS[t]:
				if left <= 0:
					break
				for hb in order:
					if left <= 0:
						break
					var k := EconPop.lab_key(hb, src_t)
					var take := mini(left, int(avail.get(k, 0)))
					if take <= 0:
						continue
					var moved := EconPop.hire(world, hb, src_t, occ, take)
					if moved <= 0:
						continue
					var rec: Dictionary = world.table("facility")[v["emp"]]["staff"] if v["kind"] == "fac" else world.table("org")[v["emp"]]["crew"]
					if not rec.has(t):
						rec[t] = {}
					rec[t][k] = int(rec[t].get(k, 0)) + moved * S
					avail[k] = int(avail[k]) - moved
					left -= moved
					hired_by_emp[v["emp"]] = hired_by_emp.get(v["emp"], 0) + moved
			var hired := maxi(cap, 0) - left
			unfilled[t] += maxi(0, int(v["qty"]) - hired * S)
			# vacancy premium memory for wage offers
			var o: Dictionary = world.table("org")[v["org"]]
			if left > 0:  # workers were not available (not merely the hiring-speed cap)
				o["premium_m"][t] = o["premium_m"].get(t, 0) + 1
			else:
				o["premium_m"][t] = 0
	s["vac_unfilled"] = unfilled
	s["vacancies"] = []
	EconPop.sync(world)


## Wage index update (COMPANY_AI, spec §6.5) + unemployment rates.
static func update_wage_index(world: WorldState) -> void:
	var s := EconUtil.st(world)
	var lf := {"G": 0, "S": 0, "Sp": 0}
	var emp := {"G": 0, "S": 0, "Sp": 0}
	for st_name in ["EMPLOYED", "UNEMPLOYED"]:
		var by := EconPop.people_by_lab(world, st_name)
		for k in by:
			var sk: String = EconPop.lab_parts(k)[1]
			lf[sk] += int(by[k]) * S
			if st_name == "EMPLOYED":
				emp[sk] += int(by[k]) * S
	for t in lf:
		var u := 0.0 if lf[t] == 0 else float(lf[t] - emp[t]) / float(lf[t])
		var v := float(s["vac_unfilled"].get(t, 0)) / maxf(1.0, float(emp[t] + s["vac_unfilled"].get(t, 0)))
		s["unemp_rate"][t] = int(u * 100000)
		var g := clampf(0.10 * (v - u + EconData.WAGE_NEUTRAL_U), -EconData.WAGE_MAX_CUT_PM, 0.01)  # E55 damped; E78 sticky downward
		s["wage"][t] = int(float(s["wage"][t]) * (1.0 + g))

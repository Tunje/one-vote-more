class_name EconPop
extends RefCounted
## M10 S2: the economy on population leaves (spec-population-v1 §3, §13 A–F).
##
## POOLS: the "hh" table now holds one household pool per (housing block × income band), id "hb:d:1|I3",
## with account "hh:<pool id>". A pool is where money lives and where consumption, rent and bills happen.
## Its head counts (lf, nonpart, retired, children, owners, self_emp, emp{occ}, skill{}) are DERIVED from the
## leaves by sync() and stored in milli-persons (×S) so the rest of the economy keeps its units.
##
## JOBS: facility staff and contractor crews are keyed staff[slot tier][labor key], labor key = "hb|person skill"
## (§13 B). The occupation of the person follows from the workplace and slot: Specialist slots are
## PROFESSIONAL (E67), public employers PUBLIC_SECTOR, contractors CONSTRUCTION, else the recipe's occupation.
## Invariant (check()): for every (hb, occupation, skill) the EMPLOYED people in the leaves equal the
## allocated persons. Self-employed are BUSINESS_OWNER|EMPLOYED without an allocation; capital owners are
## BUSINESS_OWNER|NOT_IN_LF.

const S := EconUtil.S
const ARCH := "MIX"   # placeholder archetype until politics S3 assigns archetypes
const LF_STATUSES := ["EMPLOYED", "UNEMPLOYED"]


# ======================================================================= ids

static func hb_of(district: String) -> String:
	return "hb:" + district


static func district_of(hb: String) -> String:
	return hb.substr(3)


static func pool_id(hb: String, band: String) -> String:
	return hb + "|" + band


static func lab_key(hb: String, skill: String) -> String:
	return hb + "|" + skill


static func lab_parts(k: String) -> Array:
	var i := k.rfind("|")
	return [k.substr(0, i), k.substr(i + 1)]


## Occupation of a person working in a slot of tier `t` at an employer/facility type (ftype "CREW" = contractor crew).
static func person_occ(world: WorldState, org_id: String, ftype: String, t: String) -> String:
	if t == "Sp":
		return "PROFESSIONAL"
	return EconLabor.occupation_of(world, org_id, ftype)


# ======================================================================= pools

static func ensure_pools(world: WorldState) -> void:
	for d in EconUtil.sorted_keys(EconData.DISTRICTS):
		for band in PopStore.INCOME_BANDS:
			var gid := pool_id(hb_of(d), band)
			if world.table("hh").has(gid):
				continue
			world.table("hh")[gid] = {"id": gid, "district": d, "hb": hb_of(d), "band": band,
				"lf": 0, "nonpart": 0, "retired": 0, "children": 0, "owners": 0, "self_emp": 0, "unemployed": 0,
				"emp": {}, "skill": {"G": 0, "S": 0, "Sp": 0}, "unemp_long": 0, "bought": {}, "unmet": {}, "income": {},
				"income_last": {}, "rent_due": 0, "short": {}, "spent_goods": 0}
			world.ledger.open_account(EconUtil.hh_acct(gid))


## Recompute every pool's head counts from the leaves (milli-persons).
static func sync(world: WorldState) -> void:
	var hh := world.table("hh")
	for gid in hh:
		var g: Dictionary = hh[gid]
		for f in ["lf", "nonpart", "retired", "children", "owners", "self_emp", "unemployed"]:
			g[f] = 0
		g["emp"] = {}
		g["skill"] = {"G": 0, "S": 0, "Sp": 0}
	var pop := world.peek("pop")
	for k in pop:
		var l: Dictionary = pop[k]
		var g: Dictionary = hh[pool_id(l["hb"], l["inc"])]
		var n: int = int(l["n"]) * S
		match l["status"]:
			"EMPLOYED":
				g["lf"] += n
				g["emp"][l["occ"]] = int(g["emp"].get(l["occ"], 0)) + n
				if l["occ"] == "BUSINESS_OWNER":
					g["self_emp"] += n
			"UNEMPLOYED":
				g["lf"] += n
				g["unemployed"] += n
			"RETIRED":
				g["retired"] += n
			"CHILD":
				g["children"] += n
			_:
				if l["occ"] == "BUSINESS_OWNER" and l["status"] == "NOT_IN_LF":
					g["owners"] += n
				else:
					g["nonpart"] += n
		if l["status"] in LF_STATUSES:
			for sk in l["skill"]:
				g["skill"][sk] = int(g["skill"].get(sk, 0)) + int(l["skill"][sk]) * S


## Persons per "hb|skill" with a given status (and optional occupation).
static func people_by_lab(world: WorldState, status: String, occ: String = "") -> Dictionary:
	var out := {}
	var pop := world.peek("pop")
	for k in pop:
		var l: Dictionary = pop[k]
		if l["status"] != status or (occ != "" and l["occ"] != occ):
			continue
		for sk in l["skill"]:
			if int(l["skill"][sk]) > 0:
				var lk := lab_key(l["hb"], sk)
				out[lk] = int(out.get(lk, 0)) + int(l["skill"][sk])
	return out


# ======================================================================= hires and layoffs (PopStore transfers)

## n unemployed people of (hb, skill) take jobs as `occ`; people already trained in `occ` first. Returns persons moved.
static func hire(world: WorldState, hb: String, skill: String, occ: String, n: int) -> int:
	if n <= 0:
		return 0
	var moved := PopStore.move_group(world, {"hb": hb, "status": "UNEMPLOYED", "occ": occ}, n, {"status": "EMPLOYED"}, "HIRE", "skill:" + skill)
	if moved < n:
		moved += PopStore.move_group(world, {"hb": hb, "status": "UNEMPLOYED"}, n - moved, {"occ": occ, "status": "EMPLOYED"}, "HIRE", "skill:" + skill)
	return moved


## n employed people of (hb, occ, skill) lose their jobs (keep occupation and skill, PD §5.2).
static func layoff(world: WorldState, hb: String, skill: String, occ: String, n: int, reason: String = "LAYOFF") -> int:
	if n <= 0:
		return 0
	var moved := PopStore.move_group(world, {"hb": hb, "status": "EMPLOYED", "occ": occ}, n, {"status": "UNEMPLOYED"}, reason, "skill:" + skill)
	if moved < n:
		_mismatch(world, "layoff %s|%s|%s: %d of %d" % [hb, occ, skill, moved, n])
	return moved


## Removes `persons` whole people from a staff/crew tier, largest holders first. Returns {labor key: persons}.
static func remove_staff(staff: Dictionary, t: String, persons: int) -> Dictionary:
	var recs: Dictionary = staff.get(t, {})
	var keys := recs.keys()
	keys.sort_custom(func(a, b): return recs[a] > recs[b] or (recs[a] == recs[b] and a < b))
	var out := {}
	var left := persons
	for k in keys:
		if left <= 0:
			break
		var take := mini(left, int(recs[k]) / S)
		if take <= 0:
			continue
		recs[k] = int(recs[k]) - take * S
		left -= take
		out[k] = take
		if recs[k] <= 0:
			recs.erase(k)
	return out


## Releases a whole staff dict (facility closed / crew disbanded): everyone becomes unemployed.
static func release_all(world: WorldState, org_id: String, ftype: String, staff: Dictionary, reason: String = "LAYOFF") -> int:
	var n := 0
	for t in EconUtil.sorted_keys(staff):
		var cut := remove_staff(staff, t, EconLabor.tier_total(staff, t) / S)
		var occ := person_occ(world, org_id, ftype, t)
		for k in EconUtil.sorted_keys(cut):
			var p := lab_parts(k)
			layoff(world, p[0], p[1], occ, cut[k], reason)
			n += cut[k]
	return n


static func _mismatch(world: WorldState, msg: String) -> void:
	var s := EconUtil.st(world)
	var m: Array = s.get("pop_mismatch", [])
	if m.size() < 20:
		m.append("m%d %s" % [world.month, msg])
	s["pop_mismatch"] = m


# ======================================================================= money to people

## Index of working people for income attribution: "hb|occ|skill" -> [[leaf key, pool id, count]].
static func worker_index(world: WorldState) -> Dictionary:
	var idx := {}
	var pop := world.peek("pop")
	for k in EconUtil.sorted_keys(pop):
		var l: Dictionary = pop[k]
		if l["status"] != "EMPLOYED":
			continue
		for sk in EconUtil.sorted_keys(l["skill"]):
			var c: int = l["skill"][sk]
			if c > 0:
				var bk: String = "%s|%s|%s" % [l["hb"], l["occ"], sk]
				if not idx.has(bk):
					idx[bk] = []
				idx[bk].append([k, pool_id(l["hb"], l["inc"]), c])
	return idx


## Splits `amount` over the rows of an index bucket by count: returns {pool id: amount} and books the
## per-leaf income (kind: "wages" | "dividend" | ...) in econ.s["leaf_inc"].
static func split_to_pools(world: WorldState, rows: Array, amount: int, kind: String) -> Dictionary:
	var out := {}
	if amount <= 0 or rows.is_empty():
		return out
	var parts := EconUtil.split_lr(amount, rows.map(func(r): return float(r[2])))
	var st := EconUtil.st(world)
	if not st.has("leaf_inc"):
		st["leaf_inc"] = {}
	var li: Dictionary = st["leaf_inc"]
	for i in rows.size():
		if parts[i] <= 0:
			continue
		out[rows[i][1]] = int(out.get(rows[i][1], 0)) + parts[i]
		var rec: Dictionary = li.get(rows[i][0], {})
		rec[kind] = int(rec.get(kind, 0)) + parts[i]
		li[rows[i][0]] = rec
	return out


## Books per-leaf income for money already paid into a pool (benefits, pensions, dividends): split by n over
## the pool's leaves with `status` ("" = everyone) and optional occupation. If nobody matches, the whole pool.
static func credit_status(world: WorldState, gid: String, status: String, amount: int, kind: String, occ: String = "") -> void:
	if amount <= 0:
		return
	var g: Dictionary = world.table("hh")[gid]
	var rows: Array = []
	var all: Array = []
	var pop := world.peek("pop")
	for k in PopStore.select(world, {"hb": g["hb"], "inc": g["band"]}):  # indexed: this pool's leaves only
		var l: Dictionary = pop[k]
		all.append([k, gid, int(l["n"])])
		if (status == "" or l["status"] == status) and (occ == "" or l["occ"] == occ):
			rows.append([k, gid, int(l["n"])])
	split_to_pools(world, rows if not rows.is_empty() else all, amount, kind)


## Changes the composition of up to n people of a leaf from bucket `from_b` to `to_b` in field "age" or "skill"
## (growing up, ageing into retirement, training). n is unchanged, so conservation holds. Returns people changed.
static func recompose(world: WorldState, key: String, field: String, from_b: String, to_b: String, n: int) -> int:
	if n <= 0 or from_b == to_b or not world.peek("pop").has(key):
		return 0
	var c: Dictionary = world.table("pop")[key][field]
	var k := mini(n, int(c.get(from_b, 0)))
	c[from_b] = int(c.get(from_b, 0)) - k
	c[to_b] = int(c.get(to_b, 0)) + k
	return k


# ======================================================================= founding population

## Builds the founding leaves and pools (replaces the district × tier groups). Founding bands by skill tier:
## G → I2, S → I3, Sp → I4, capital owners → I5. Income reclassification moves people afterwards.
static func seed_founding(world: WorldState) -> void:
	ensure_pools(world)
	var dists: Array = []
	var dweights: Array = []
	for d in EconUtil.sorted_keys(EconData.DISTRICTS):
		if EconData.DISTRICTS[d]["pop"] > 0:
			dists.append(d)
			dweights.append(float(EconData.DISTRICTS[d]["pop"]))
	var lf_total := 0
	for t in EconData.LABOR_FORCE:
		lf_total += EconData.LABOR_FORCE[t]
	var nonpart_total: int = EconData.WORKING_AGE - lf_total
	var band_of := {"G": "I2", "S": "I3", "Sp": "I4"}
	for t in ["G", "S", "Sp"]:
		var tshare := float(EconData.LABOR_FORCE[t]) / float(lf_total)
		var lf := EconUtil.split_lr(EconData.LABOR_FORCE[t], dweights)
		var np := EconUtil.split_lr(int(round(nonpart_total * tshare)), dweights)
		var ret := EconUtil.split_lr(int(round(EconData.RETIRED * tshare)), dweights)
		var ch := EconUtil.split_lr(int(round(EconData.CHILDREN * tshare)), dweights)
		for i in dists.size():
			var hb := hb_of(dists[i])
			var band: String = band_of[t]
			_seed(world, hb, band, "NONE", "UNEMPLOYED", lf[i], _adult_ages(lf[i]), t)
			_seed(world, hb, band, "NONE", "NOT_IN_LF", np[i], _adult_ages(np[i]), t)
			_seed(world, hb, band, "NONE", "RETIRED", ret[i], {"O": ret[i]}, t)
			_seed(world, hb, band, "NONE", "CHILD", ch[i], {"C": ch[i]}, "G")
			var persons := float(lf[i] + np[i] + ret[i] + ch[i])
			world.ledger.transfer(Ledger.EXTERNAL, EconUtil.hh_acct(pool_id(hb, band)), int(persons * EconData.SAVINGS_PC[t]) * S, "GRANT", world.month)
	# capital owners: one per PRIVATE org, a Specialist adult of the HQ district (from non-participants), band I5
	for oid in EconUtil.sorted_keys(world.table("org")):
		var o: Dictionary = world.table("org")[oid]
		if o["type"] != "PRIVATE":
			continue
		var gid := make_owner(world, hb_of(o["hq"]), "I5", ["I4"])
		if gid == "":
			continue
		o["owner_group"] = gid
		world.ledger.transfer(Ledger.EXTERNAL, EconUtil.hh_acct(gid), EconData.OWNER_SAVINGS * S, "GRANT", world.month)
	sync(world)


static func _seed(world: WorldState, hb: String, band: String, occ: String, status: String, n: int, ages: Dictionary, skill: String) -> void:
	if n <= 0:
		return
	PopStore.seed_leaf(world, {"hb": hb, "inc": band, "occ": occ, "status": status, "arch": ARCH, "eff": "e0"}, n,
		{"age": ages, "skill": {skill: n}})


static func _adult_ages(n: int) -> Dictionary:
	var p := EconUtil.split_lr(n, [30, 45, 25])
	return {"Y": p[0], "A": p[1], "M": p[2]}


## One adult (a NOT_IN_LF Specialist, else any NOT_IN_LF adult) of the housing block becomes a capital owner
## (BUSINESS_OWNER|NOT_IN_LF) in pool (hb, band). from_bands: bands to take the person from (plus `band`).
## Returns the owner's pool id ("" if nobody was available).
static func make_owner(world: WorldState, hb: String, band: String, from_bands: Array = []) -> String:
	var bands: Array = [band] + from_bands
	for bucket in ["skill:Sp", ""]:
		var keys := PopStore.select(world, {"hb": hb, "inc": bands, "status": "NOT_IN_LF", "occ": ["NONE", "MINING", "CONSTRUCTION",
			"MANUFACTURING", "AGRICULTURE", "LOGISTICS", "SERVICES", "PROFESSIONAL", "PUBLIC_SECTOR"]})
		for k in keys:
			if PopStore._weight(world.peek("pop")[k], bucket) > 0:
				var only := {} if bucket == "" else {"skill": "Sp"}
				PopStore.transfer(world, k, PopStore.relabel(k, {"inc": band, "occ": "BUSINESS_OWNER"}), 1, "OWNER", only)
				return pool_id(hb, band)
	return ""


# ======================================================================= realign

## Allocated persons per "hb|occ|skill" from facility staff and contractor crews.
static func allocations(world: WorldState) -> Dictionary:
	var alloc := {}
	var errs: Array = []
	for fid in EconUtil.sorted_keys(world.peek("facility")):
		var f: Dictionary = world.peek("facility")[fid]
		_alloc_add(world, alloc, f["org"], f["type"], f["staff"], errs, fid)
	for oid in EconUtil.sorted_keys(world.peek("org")):
		var o: Dictionary = world.peek("org")[oid]
		if o["is_contractor"]:
			_alloc_add(world, alloc, oid, "CREW", o["crew"], errs, oid)
	return alloc


## Employed people per "hb|occ|skill" in the leaves (self-employed BUSINESS_OWNER excluded).
static func employed_buckets(world: WorldState) -> Dictionary:
	var have := {}
	var pop := world.peek("pop")
	for k in pop:
		var l: Dictionary = pop[k]
		if l["status"] != "EMPLOYED" or l["occ"] == "BUSINESS_OWNER":
			continue
		for sk in l["skill"]:
			if int(l["skill"][sk]) > 0:
				var bk: String = "%s|%s|%s" % [l["hb"], l["occ"], sk]
				have[bk] = int(have.get(bk, 0)) + int(l["skill"][sk])
	return have


## When a workplace changes owner (sale, takeover, buyout) its staff's occupation can change (e.g. a factory
## taken over by a public enterprise: MANUFACTURING → PUBLIC_SECTOR). Within each (hb, skill), employed people
## are relabelled from occupations with more people than jobs to occupations with more jobs than people.
static func realign(world: WorldState) -> void:
	var alloc := allocations(world)
	var have := employed_buckets(world)
	var by_hs := {}  # "hb|skill" -> {occ: diff (have - alloc)}
	var keys: Array = alloc.keys()
	for k in have:
		if not alloc.has(k):
			keys.append(k)
	keys.sort()
	for bk in keys:
		var diff := int(have.get(bk, 0)) - int(alloc.get(bk, 0))
		if diff == 0:
			continue
		var p: PackedStringArray = bk.split("|")  # hb ids contain no "|": [hb, occ, skill]
		var occ := p[1]
		var hs := p[0] + "|" + p[2]
		if not by_hs.has(hs):
			by_hs[hs] = {}
		by_hs[hs][occ] = diff
	for hs in EconUtil.sorted_keys(by_hs):
		var lp := lab_parts(hs)
		var d: Dictionary = by_hs[hs]
		var occs := EconUtil.sorted_keys(d)
		for src in occs:
			for dst in occs:
				if int(d[src]) <= 0:
					break
				if int(d[dst]) >= 0:
					continue
				var n := mini(int(d[src]), -int(d[dst]))
				var moved := PopStore.move_group(world, {"hb": lp[0], "status": "EMPLOYED", "occ": src}, n, {"occ": dst}, "REASSIGN", "skill:" + lp[1])
				d[src] = int(d[src]) - moved
				d[dst] = int(d[dst]) + moved
		for occ in occs:
			if int(d[occ]) != 0:
				_mismatch(world, "realign %s %s: %+d" % [hs, occ, d[occ]])


# ======================================================================= consistency

## Problems with the jobs ↔ people invariant (empty = consistent).
static func check(world: WorldState) -> Array:
	var errs: Array = []
	var alloc := {}
	for fid in EconUtil.sorted_keys(world.peek("facility")):
		var f: Dictionary = world.peek("facility")[fid]
		_alloc_add(world, alloc, f["org"], f["type"], f["staff"], errs, fid)
	for oid in EconUtil.sorted_keys(world.peek("org")):
		var o: Dictionary = world.peek("org")[oid]
		if o["is_contractor"]:
			_alloc_add(world, alloc, oid, "CREW", o["crew"], errs, oid)
	var have := employed_buckets(world)
	var keys: Array = alloc.keys()
	for k in have:
		if not alloc.has(k):
			keys.append(k)
	keys.sort()
	for k in keys:
		if int(alloc.get(k, 0)) != int(have.get(k, 0)):
			errs.append("%s: %d allocated, %d employed in leaves" % [k, alloc.get(k, 0), have.get(k, 0)])
	return errs


static func _alloc_add(world: WorldState, alloc: Dictionary, org_id: String, ftype: String, staff: Dictionary, errs: Array, where: String) -> void:
	for t in staff:
		var occ := person_occ(world, org_id, ftype, t)
		for k in staff[t]:
			var v: int = staff[t][k]
			if v % S != 0:
				errs.append("%s %s %s: %d not whole persons" % [where, t, k, v])
			var p := lab_parts(k)
			var bk: String = "%s|%s|%s" % [p[0], occ, p[1]]
			alloc[bk] = int(alloc.get(bk, 0)) + v / S


# ======================================================================= income bands (spec §3.2, §13 A)

const EMA_ALPHA := 2.0 / 7.0         # 6-month EMA
const BAND_MARGIN := 0.05            # hysteresis: past a quintile cut by more than 5%
const JUMP := 0.25                   # a > 25% change in monthly income resets the EMA at once (job loss, PD §4.6); the move follows in January (E92)
const DEPENDENTS := ["CHILD", "STUDENT", "NOT_IN_LF"]
const ADULT_EARNERS := ["EMPLOYED", "UNEMPLOYED", "RETIRED"]


static func is_owner(l: Dictionary) -> bool:
	return l["occ"] == "BUSINESS_OWNER" and l["status"] == "NOT_IN_LF"


## Adult-equivalents of a pool (OECD-style, applied per household): H + 0.5 (adults − H) + 0.3 children.
static func adult_equivalents(g: Dictionary) -> float:
	var adults := float(EconHouseholds.adults(g)) / S
	var children := float(g["children"]) / S
	var hh := maxf(1.0, (adults + children) / EconData.HOUSEHOLD_SIZE)
	return maxf(1.0, hh + 0.5 * maxf(0.0, adults - hh) + 0.3 * children)


## Monthly income classification (SOCIAL). Updates every earning adult leaf's inc_ema (milli-credits per
## adult-equivalent, blended 50/50 with its pool), moves leaves whose band changed (with their share of the
## pool's savings), and moves dependents along with their adults. Publishes colony cuts and stats in s["bands"].
static func reclassify(world: WorldState, move: bool = true) -> void:
	var s := EconUtil.st(world)
	sync(world)
	var hh := world.table("hh")
	var li: Dictionary = s.get("leaf_inc", {})
	var pool_eq := {}
	var pool_scale := {}  # adults / adult-equivalents
	for gid in hh:
		var g: Dictionary = hh[gid]
		var ae := adult_equivalents(g)
		pool_eq[gid] = float(EconHouseholds.disposable(g)) / ae
		pool_scale[gid] = maxf(0.0, float(EconHouseholds.adults(g)) / S) / ae
	# 1. blended equivalized income per earning adult leaf; EMA
	var pop := world.table("pop")
	var adults: Array = []   # [key, value, n]
	var values: Array = []   # [value, n] incl. dependents at pool level (for Gini)
	var values_d := {}       # district -> [[value, n]]
	var cur := {}            # key -> value used for banding
	for k in EconUtil.sorted_keys(pop):
		var l: Dictionary = pop[k]
		var gid := pool_id(l["hb"], l["inc"])
		if l["status"] in ADULT_EARNERS and not is_owner(l):
			var rec: Dictionary = li.get(k, {})
			var own := 0
			for kind in ["wages", "benefit", "pension", "dividend", "self"]:
				own += int(rec.get(kind, 0))
			var own_eq := float(own) / float(l["n"]) * float(pool_scale[gid])
			var x := 0.5 * own_eq + 0.5 * float(pool_eq[gid])
			var ema := float(l.get("inc_ema", -1))
			if ema < 0.0:
				ema = x
			elif li.has(k) and absf(x - ema) > JUMP * maxf(ema, 1.0):
				ema = x  # big change: classify on the new income at once
			else:
				ema += EMA_ALPHA * (x - ema)
			l["inc_ema"] = int(round(ema))
			adults.append([k, ema, int(l["n"])])
			cur[k] = ema
			values.append([ema, int(l["n"])])
		else:
			values.append([float(pool_eq[gid]), int(l["n"])])
		var dd := district_of(l["hb"])
		if not values_d.has(dd):
			values_d[dd] = []
		values_d[dd].append(values[-1])
	var cuts := _quantiles(adults.map(func(a): return [a[1], a[2]]), [0.2, 0.4, 0.6, 0.8])
	var gd := {}
	for dd in EconUtil.sorted_keys(values_d):
		gd[dd] = int(round(1000.0 * _gini(values_d[dd])))
	s["bands"] = {"cuts": cuts.map(func(c): return int(round(c))), "gini": int(round(1000.0 * _gini(values))), "gini_d": gd}
	if cuts.is_empty() or not move:
		return
	# 2. band moves for adults (whole leaves), with hysteresis
	var moves := {}  # src pool -> {dst band: adults moved}
	var flows: Array = []  # [key, dst band]
	for a in adults:
		var l: Dictionary = pop[a[0]]
		var b := PopStore.INCOME_BANDS.find(l["inc"])
		var t := _band_index(a[1], cuts)
		if t > b and a[1] <= cuts[b] * (1.0 + BAND_MARGIN):
			t = b
		elif t < b and a[1] >= cuts[b - 1] * (1.0 - BAND_MARGIN):
			t = b
		if t != b:
			flows.append([a[0], PopStore.INCOME_BANDS[t]])
	if flows.is_empty():
		return
	# pool sizes and balances before moving anyone (money moves per head)
	var size0 := {}
	var bal0 := {}
	var adults0 := {}
	var dep0 := {}  # gid -> {status: n}
	for gid in hh:
		size0[gid] = EconHouseholds.persons(hh[gid]) / S
		bal0[gid] = world.ledger.balance(EconUtil.hh_acct(gid))
		adults0[gid] = 0
		dep0[gid] = {}
	for k in pop:
		var l: Dictionary = pop[k]
		var gid := pool_id(l["hb"], l["inc"])
		if l["status"] in ADULT_EARNERS and not is_owner(l):
			adults0[gid] += int(l["n"])
		elif l["status"] in DEPENDENTS and not is_owner(l):
			dep0[gid][l["status"]] = int(dep0[gid].get(l["status"], 0)) + int(l["n"])
	for fl in flows:
		var l: Dictionary = pop[fl[0]]
		var src := pool_id(l["hb"], l["inc"])
		var n: int = l["n"]
		if not moves.has(src):
			moves[src] = {}
		moves[src][fl[1]] = int(moves[src].get(fl[1], 0)) + n
		PopStore.transfer(world, fl[0], PopStore.relabel(fl[0], {"inc": fl[1]}), n, "INCOME_BAND")
	# 3. dependents follow their adults; 4. savings follow people
	for src in EconUtil.sorted_keys(moves):
		var g: Dictionary = hh[src]
		var dsts := EconUtil.sorted_keys(moves[src])
		var moved_by_dst := {}
		for d in dsts:
			moved_by_dst[d] = moves[src][d]
		var a0: int = maxi(1, adults0[src])
		var out_adults := 0
		for d in dsts:
			out_adults += moves[src][d]
		for st_name in DEPENDENTS:
			var dn: int = dep0[src].get(st_name, 0)
			var total_dep := mini(dn, int(round(float(dn) * float(out_adults) / float(a0))))
			var parts := EconUtil.split_lr(total_dep, dsts.map(func(d): return float(moves[src][d])))
			for i in dsts.size():
				if parts[i] > 0:
					var m := PopStore.move_group(world, {"hb": g["hb"], "inc": g["band"], "status": st_name, "occ": ["NONE", "MINING",
						"CONSTRUCTION", "MANUFACTURING", "AGRICULTURE", "LOGISTICS", "SERVICES", "PROFESSIONAL", "PUBLIC_SECTOR"]},
						parts[i], {"inc": dsts[i]}, "INCOME_BAND")
					moved_by_dst[dsts[i]] += m
		for d in dsts:
			var amt := int(float(bal0[src]) * float(moved_by_dst[d]) / float(maxi(1, size0[src])))
			amt = mini(amt, world.ledger.balance(EconUtil.hh_acct(src)))
			if amt > 0 and not EconUtil.off(world, "BANDS_MONEY"):
				world.ledger.transfer(EconUtil.hh_acct(src), EconUtil.hh_acct(pool_id(g["hb"], d)), amt, "MOVE", world.month)
	sync(world)


static func _band_index(v: float, cuts: Array) -> int:
	var i := 0
	while i < cuts.size() and v > cuts[i]:
		i += 1
	return i


## Weighted quantiles of [[value, weight]] at the given fractions.
static func _quantiles(rows: Array, qs: Array) -> Array:
	if rows.is_empty():
		return []
	var r := rows.duplicate()
	r.sort_custom(func(a, b): return a[0] < b[0])
	var tot := 0.0
	for x in r:
		tot += float(x[1])
	var out: Array = []
	for q in qs:
		var target: float = q * tot
		var cum := 0.0
		var v: float = r[-1][0]
		for x in r:
			cum += float(x[1])
			if cum >= target:
				v = x[0]
				break
		out.append(v)
	return out


## Gini coefficient of [[value, weight]] (0..1).
static func _gini(rows: Array) -> float:
	var r := rows.filter(func(x): return x[1] > 0)
	if r.size() < 2:
		return 0.0
	r.sort_custom(func(a, b): return a[0] < b[0])
	var n := 0.0
	var tot := 0.0
	for x in r:
		n += float(x[1])
		tot += maxf(0.0, x[0]) * float(x[1])
	if tot <= 0.0:
		return 0.0
	var cum_w := 0.0
	var b := 0.0
	for x in r:
		var w := float(x[1])
		b += maxf(0.0, x[0]) * w * (n - cum_w - 0.5 * w)
		cum_w += w
	return clampf(1.0 - 2.0 * b / (n * tot), 0.0, 1.0)


## Deprivation (PD §4.4, absolute): share of persons in pools whose monthly disposable income is below their
## essentials cost and whose savings cover less than 2 months of essentials. {district: permille}
static func deprivation(world: WorldState) -> Dictionary:
	var dep := {}
	var tot := {}
	for gid in EconUtil.sorted_keys(world.table("hh")):
		var g: Dictionary = world.table("hh")[gid]
		var p := EconHouseholds.persons(g)
		if p <= 0:
			continue
		var ess := EconHouseholds.essentials_cost(world, g)
		var poor: bool = EconHouseholds.disposable(g) < ess and world.ledger.balance(EconUtil.hh_acct(gid)) < 2 * ess
		tot[g["district"]] = int(tot.get(g["district"], 0)) + p
		if poor:
			dep[g["district"]] = int(dep.get(g["district"], 0)) + p
	var out := {}
	for d in tot:
		out[d] = int(1000.0 * float(dep.get(d, 0)) / float(tot[d]))
	return out

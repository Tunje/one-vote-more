class_name DistrictPolitics
extends RefCounted
## M13 A4, politics side (planning/spec-areas-v1.md §5; law: Anni, districting.gd / LQ.districting_preview).
## Districts are drawn by law. Once a year an AI government reviews the district map:
##   - remedy: if the current map is out of balance (always allowed), it proposes a fair map;
##   - opportunity: otherwise, if a valid map would give the governing parties more districts where they lead,
##     a government with little regard for institutional norms (INSTITUTIONS < 0) proposes it: gerrymandering
##     within the constitutional rules.
## Candidate maps: geographic clusters of areas (k = 1..6), plus boundary swaps that help the government.
## Parliament votes: governing parties vote yes; every other party votes for a map only if it doesn't lose
## districts where it leads. A passed map goes to law (DL.enact), which may still reject it.
## Stateless; reads cells by area (cell["district"] holds the area id once the economy is keyed by area).

const DL := preload("res://sim/law/districting.gd")
const LQ := preload("res://sim/law/law_query.gd")
const REVIEW_MONTH := 5           # May
const MAX_K := 6
const SWAP_STEPS := 6


static func monthly(world: WorldState, st: Dictionary) -> void:
	if world.month_of_year() != REVIEW_MONTH or st.get("era", "") != "PARLIAMENTARY":
		return
	var g: Dictionary = st.get("government", {})
	if g.is_empty() or (st.get("player_party", "") in g.get("members", []) and not st.get("autoplay_player", true)):
		return
	var ids: Array = AreaStore.areas(world).map(func(a): return a["id"])
	if ids.size() < 2:
		return
	var remedy: bool = DL.current_unbalanced(world)
	var members: Array = g["members"]
	var cur := current_plan(world)
	var cur_score := score(world, cur, members)
	var best: Dictionary = {}
	var best_score := -INF
	for k in range(1, mini(MAX_K, ids.size()) + 1):
		var plan := _name_plan(world, cluster_plan(world, ids, k), cur)
		var pv: Dictionary = DL.preview(world, plan, "LAW")
		if not pv["ok"]:
			continue
		var sc := score(world, plan, members) + (0.0 if remedy else 0.0)
		if remedy:
			sc = -_imbalance(pv)  # a remedy aims for the fairest map
		if sc > best_score:
			best_score = sc
			best = plan
	if best.is_empty():
		return
	var inst := float(g["center"].get("INSTITUTIONS", 0)) / 1000.0
	if not remedy:
		if inst < 0.0:
			best = gerrymander(world, best, members)
		if score(world, best, members) < cur_score + 1.0:
			return  # nothing to gain
	vote_and_enact(world, st, best, cur, "REMEDY" if remedy else "REDRAW")


## The map in force: {district name: [area ids]}.
static func current_plan(world: WorldState) -> Dictionary:
	var plan := {}
	for a in AreaStore.areas(world):
		var dn: String = DL.district_name(world, String(a["district"]))
		if dn == "":
			dn = "The Colony"
		if not plan.has(dn):
			plan[dn] = []
		plan[dn].append(a["id"])
	return plan


## Geographic clusters of areas (resident-weighted k-means on centroids, deterministic).
static func cluster_plan(world: WorldState, ids: Array, k: int) -> Dictionary:
	var pts := {}
	for id in ids:
		pts[id] = AreaStore.centroid(world, id)
	var cents: Array = [pts[ids[0]]]
	while cents.size() < k:
		var far := ""
		var fd := -1.0
		for id in ids:
			var d := INF
			for c in cents:
				d = minf(d, pts[id].distance_to(c))
			if d > fd:
				fd = d
				far = id
		cents.append(pts[far])
	var assign := {}
	for _it in 6:
		for id in ids:
			var bi := 0
			var bd := INF
			for i in cents.size():
				var d: float = pts[id].distance_to(cents[i])
				if d < bd:
					bd = d
					bi = i
			assign[id] = bi
		for i in cents.size():
			var s := Vector2.ZERO
			var n := 0.0
			for id in ids:
				if assign[id] == i:
					var w := float(maxi(1, AreaStore.residents(world, id)))
					s += pts[id] * w
					n += w
			if n > 0.0:
				cents[i] = s / n
	var groups := {}
	for id in ids:
		var key := "g%d" % assign[id]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(id)
	return groups


## Name each group after the current district it overlaps most (names carry over, so district ids persist),
## otherwise after its largest area.
static func _name_plan(world: WorldState, groups: Dictionary, cur: Dictionary) -> Dictionary:
	var out := {}
	var keys: Array = groups.keys()
	keys.sort()
	for gk in keys:
		var areas: Array = groups[gk]
		var best := ""
		var bo := 0
		for dn in cur:
			var o := 0
			for a in areas:
				if a in cur[dn]:
					o += AreaStore.residents(world, a)
			if o > bo and not out.has(dn):
				bo = o
				best = dn
		if best == "":
			var big: String = areas[0]
			for a in areas:
				if AreaStore.residents(world, a) > AreaStore.residents(world, big):
					big = a
			best = "%s District" % String(AreaStore.get_area(world, big).get("name", big)).get_slice(" ", 0)
			var n := 2
			while out.has(best):
				best = "%s District %d" % [String(AreaStore.get_area(world, big).get("name", big)).get_slice(" ", 0), n]
				n += 1
		out[best] = areas.duplicate()
	return out


## Share of an area's voters that backed the given parties last election (0..1).
static func area_share(world: WorldState, area_id: String, parties: Array) -> float:
	var v := 0.0
	var n := 0.0
	for c in world.table("cell").values():
		if c["district"] != area_id or c["pop"] <= 0:
			continue
		var s := 0.0
		for pid in parties:
			s += float(c["prev_share"].get(pid, 0)) / 100000.0
		v += s * c["pop"]
		n += c["pop"]
	return v / n if n > 0.0 else 0.0


## How good a map is for a set of parties: districts they lead (share > 50%), plus a small margin tie-break.
static func score(world: WorldState, plan: Dictionary, parties: Array) -> float:
	var won := 0.0
	var margin := 0.0
	for dn in plan:
		var v := 0.0
		var n := 0.0
		for a in plan[dn]:
			var r := float(maxi(1, AreaStore.residents(world, a)))
			v += area_share(world, a, parties) * r
			n += r
		var sh := v / maxf(1.0, n)
		if sh > 0.5:
			won += 1.0
		margin += sh
	return won + margin * 0.01


static func _imbalance(pv: Dictionary) -> float:
	var x := 0.0
	for dn in pv["districts"]:
		x += absf(float(pv["districts"][dn]["deviation_pct"]))
	return x


## Boundary swaps: move single areas between districts while the map stays valid and the government gains.
static func gerrymander(world: WorldState, plan: Dictionary, members: Array) -> Dictionary:
	var best := plan.duplicate(true)
	var bs := score(world, best, members)
	for _step in SWAP_STEPS:
		var improved := false
		var names: Array = best.keys()
		names.sort()
		for src in names:
			for a in best[src]:
				for dst in names:
					if dst == src or best[src].size() <= 1:
						continue
					var trial := best.duplicate(true)
					trial[src].erase(a)
					trial[dst].append(a)
					if not DL.preview(world, trial, "LAW")["ok"]:
						continue
					var ts := score(world, trial, members)
					if ts > bs + 0.001:
						best = trial
						bs = ts
						improved = true
						break
				if improved:
					break
			if improved:
				break
		if not improved:
			break
	return best


## Parliament votes; a passed map goes to law.
static func vote_and_enact(world: WorldState, st: Dictionary, plan: Dictionary, cur: Dictionary, why: String) -> Dictionary:
	var g: Dictionary = st["government"]
	var yes := 0
	var no := 0
	var votes := {}
	var ids: Array = world.table("party").keys()
	ids.sort()
	for pid in ids:
		var p: Dictionary = world.table("party")[pid]
		if p["status"] != "ACTIVE" or int(p["seats"]) == 0:
			continue
		var y: bool = pid in g["members"] or why == "REMEDY" or score(world, plan, [pid]) >= score(world, cur, [pid]) - 0.001
		votes[pid] = "YES" if y else "NO"
		if y:
			yes += int(p["seats"])
		else:
			no += int(p["seats"])
	var passed := yes > no
	var res := {}
	if passed:
		res = DL.enact(world, plan, world.new_id("bill"), "LAW")
	world.add_fact({"type": "POL_DISTRICTING_VOTE", "owner": "pol", "subjects": [], "responsible": [{"actor": {"kind": "GOVERNMENT", "id": "government"}, "share": 1.0}],
		"impact": {}, "magnitude": 55, "visibility": "PUBLIC",
		"data": {"why": why, "passed": passed, "yes": yes, "no": no, "votes": votes, "districts": plan.size(), "enacted": res.get("ok", false)}})
	return {"passed": passed, "yes": yes, "no": no, "enacted": res.get("ok", false)}

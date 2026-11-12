extends RefCounted
## M13 A4: districts drawn by law (planning/spec-areas-v1.md §5; DECISIONS A35). Law is the single writer of area
## district membership (AreaStore.set_district). A districting act is a map {district name: [area ids]}:
## parliament by a LAW-level bill, the commander by ORDINANCE in the founding era; never the government by decree.
##
## Constitutional validity (always): complete (every active area exactly once), contiguous (connected in the area-link
## graph: centroids within LINK_TILES, or nearest neighbours), balanced (from 3 districts: residents within +-50% of
## the mean; single-area districts exempt). Frequency (parliament): one act per 24 months, none in the 12 months
## before an ordinary election, unless it remedies a map that is already unbalanced.
## Effect: 3 months after enactment (administrative transition). Areas founded meanwhile join their nearest
## area's district; areas split meanwhile pass their new district to their children.

const Det := preload("res://sim/staff/det.gd")
const LawOps := preload("res://sim/law/law_ops.gd")
const Names := preload("res://sim/law/names.gd")

const LINK_TILES := 8.0
const BALANCE_TOLERANCE := 0.5
const BALANCE_MIN_DISTRICTS := 3
const MAX_DISTRICTS := 12
const MIN_MONTHS_BETWEEN := 24
const NO_ACT_BEFORE_ELECTION := 12
const TRANSITION_MONTHS := 3


static func _st(world: WorldState) -> Dictionary:
	var s := LawOps.state(world)
	if not s.has("districting"):
		s["districting"] = {"last_act_month": -999, "seq": 0}
	return s["districting"]


static func _active_ids(world: WorldState) -> Array:
	return AreaStore.areas(world).map(func(a): return String(a["id"]))


# =====================================================================================  geometry

## Area-link graph: two areas are linked if their centroids are within LINK_TILES, or one is the other's nearest area.
static func links(world: WorldState, ids: Array) -> Dictionary:
	var c := {}
	for id in ids:
		c[id] = AreaStore.centroid(world, id)
	var out := {}
	for id in ids:
		out[id] = []
	for a in ids:
		var best := ""
		var bd := INF
		for b in ids:
			if a == b:
				continue
			var d: float = (c[a] as Vector2).distance_to(c[b])
			if d < bd:
				bd = d
				best = b
			if d <= LINK_TILES and not out[a].has(b):
				out[a].append(b)
				out[b].append(a)
		if best != "" and not out[a].has(best):
			out[a].append(best)
			out[best].append(a)
	return out


static func _connected(members: Array, graph: Dictionary) -> bool:
	if members.size() <= 1:
		return true
	var seen := {members[0]: true}
	var queue: Array = [members[0]]
	while not queue.is_empty():
		var x = queue.pop_front()
		for y in graph.get(x, []):
			if members.has(y) and not seen.has(y):
				seen[y] = true
				queue.append(y)
	return seen.size() == members.size()


# =====================================================================================  validity

## Preview a map: {ok, errors, districts: {name: {areas, residents, deviation_pct, contiguous}}, allowed_now, reason}.
## Pure (no writes). level = "LAW" (the Assembly) or "ORDINANCE" (commander, founding era).
static func preview(world: WorldState, plan: Dictionary, level: String = "LAW") -> Dictionary:
	var errors: Array = []
	var ids := _active_ids(world)
	var seen := {}
	var names: Array = plan.keys()
	names.sort()
	if names.is_empty() or names.size() > MAX_DISTRICTS:
		errors.append("a map needs 1 to %d districts" % MAX_DISTRICTS)
	for n in names:
		if String(n).strip_edges() == "":
			errors.append("every district needs a name")
		for a in plan[n]:
			if not ids.has(a):
				errors.append("%s is not an existing area" % a)
			elif seen.has(a):
				errors.append("%s is in two districts" % a)
			seen[a] = true
		if plan[n].is_empty():
			errors.append("district %s has no areas" % n)
	for a in ids:
		if not seen.has(a):
			errors.append("%s (%s) is in no district" % [a, AreaStore.get_area(world, a).get("name", "")])
	var graph := links(world, ids)
	var info := {}
	var total := 0
	for n in names:
		var r := 0
		for a in plan[n]:
			if ids.has(a):
				r += AreaStore.residents(world, a)
		total += r
		var ok_c := _connected(plan[n].filter(func(a): return ids.has(a)), graph)
		if not ok_c:
			errors.append("district %s is not contiguous" % n)
		info[n] = {"areas": plan[n].duplicate(), "residents": r, "contiguous": ok_c, "deviation_pct": 0}
	if names.size() > 0 and total > 0:
		var mean := float(total) / float(names.size())
		for n in names:
			info[n]["deviation_pct"] = int(round((float(info[n]["residents"]) - mean) / mean * 100.0))
			if names.size() >= BALANCE_MIN_DISTRICTS and plan[n].size() > 1 \
					and absf(float(info[n]["residents"]) - mean) > BALANCE_TOLERANCE * mean:
				errors.append("district %s is out of balance (%+d%% of the mean)" % [n, info[n]["deviation_pct"]])
	var when := allowed_now(world, level)
	return {"ok": errors.is_empty() and when["ok"], "errors": errors, "districts": info, "allowed_now": when["ok"],
		"reason": when["reason"]}


## Is the current map out of balance (so a remedy act may be passed at any time)?
static func current_unbalanced(world: WorldState) -> bool:
	return not preview_current(world)["errors"].filter(func(e): return String(e).contains("out of balance")).is_empty()


static func preview_current(world: WorldState) -> Dictionary:
	var plan := {}
	for d in Det.ordered(world.peek("law_district")):
		var row: Dictionary = world.peek("law_district")[d]
		if row["status"] == "ACTIVE":
			plan[row["name"]] = []
	for a in AreaStore.areas(world):
		var dn := district_name(world, String(a["district"]))
		if plan.has(dn):
			plan[dn].append(a["id"])
	if plan.is_empty():
		return {"errors": [], "districts": {}}
	var errors: Array = []
	var total := 0
	for n in plan:
		for a in plan[n]:
			total += AreaStore.residents(world, a)
	if plan.size() >= BALANCE_MIN_DISTRICTS and total > 0:
		var mean := float(total) / float(plan.size())
		for n in plan:
			var r := 0
			for a in plan[n]:
				r += AreaStore.residents(world, a)
			if plan[n].size() > 1 and absf(float(r) - mean) > BALANCE_TOLERANCE * mean:
				errors.append("district %s is out of balance" % n)
	return {"errors": errors, "districts": plan}


## Frequency limits (constitutional; the commander's founding ordinance is exempt).
static func allowed_now(world: WorldState, level: String) -> Dictionary:
	var era := String(world.peek("pol").get("state", {}).get("era", "FOUNDING"))
	if level == "ORDINANCE":
		return {"ok": era == "FOUNDING", "reason": "" if era == "FOUNDING" else "ordinances end with the founding era"}
	if level != "LAW":
		return {"ok": false, "reason": "districts are drawn by law (%s), never by Cabinet decree" % Names.assembly(world)}
	if current_unbalanced(world):
		return {"ok": true, "reason": "remedy: the current map is out of balance"}
	var since := world.month - int(_st(world)["last_act_month"])
	if since < MIN_MONTHS_BETWEEN:
		return {"ok": false, "reason": "the map was redrawn %d months ago (at most once every %d months)" % [since, MIN_MONTHS_BETWEEN]}
	var nxt := int(world.peek("pol").get("state", {}).get("next_election", -1))
	if nxt >= 0 and nxt - world.month < NO_ACT_BEFORE_ELECTION and nxt >= world.month:
		return {"ok": false, "reason": "no redistricting in the %d months before an election" % NO_ACT_BEFORE_ELECTION}
	return {"ok": true, "reason": ""}


# =====================================================================================  acts

## Enact a districting map (politics calls this when the bill passes, or for the commander's ordinance).
## Rejected maps emit LAW_DISTRICTING_REJECTED with the reasons. -> {ok, act, errors}
static func enact(world: WorldState, plan: Dictionary, bill_id: String = "", level: String = "LAW") -> Dictionary:
	var pv := preview(world, plan, level)
	var by := {"kind": "COMMANDER", "id": "commander"} if level == "ORDINANCE" else {"kind": "INSTITUTION", "id": "parliament"}
	if not pv["ok"]:
		var errs: Array = pv["errors"].duplicate()
		if not pv["allowed_now"]:
			errs.append(pv["reason"])
		LawOps.law_fact(world, "LAW_DISTRICTING_REJECTED", "PUBLIC", [by], [], {}, 25, {"bill": bill_id, "errors": errs})
		return {"ok": false, "act": "", "errors": errs}
	var st := _st(world)
	var id := world.new_id("dact")
	var due := world.month + (1 if level == "ORDINANCE" else TRANSITION_MONTHS)
	world.table("districting_act")[id] = {"id": id, "month": world.month, "due_month": due, "level": level, "bill": bill_id,
		"map": plan.duplicate(true), "previous_map": preview_current(world)["districts"], "status": "LEGAL"}
	st["last_act_month"] = world.month
	LawOps.law_fact(world, "LAW_DISTRICTING_ENACTED", "PUBLIC", [by], [{"actor": by, "share": 1.0}], {}, 45,
		{"act": id, "bill": bill_id, "districts": plan.keys(), "effective_month": due})
	return {"ok": true, "act": id, "errors": []}


## DECISIONS phase: acts whose transition is over take effect.
static func tick(world: WorldState) -> void:
	var acts := world.table("districting_act")
	for id in Det.ordered(acts):
		var a: Dictionary = acts[id]
		if a["status"] == "LEGAL" and world.month >= int(a["due_month"]):
			_apply(world, a)


static func _apply(world: WorldState, act: Dictionary) -> void:
	var dt := world.table("law_district")
	var by_name := {}
	for d in Det.ordered(dt):
		if dt[d]["status"] == "ACTIVE":
			by_name[dt[d]["name"]] = d
	var keep := {}
	for n in act["map"]:
		var did: String = by_name.get(n, "")
		if did == "":
			did = world.new_id("ldist")
			dt[did] = {"id": did, "name": n, "status": "ACTIVE", "since_month": world.month, "act": act["id"], "areas": []}
		keep[did] = true
		dt[did]["act"] = act["id"]
		dt[did]["areas"] = []
		for a in act["map"][n]:
			_assign(world, String(a), did)
	for d in by_name.values():
		if not keep.has(d):
			dt[d]["status"] = "ABOLISHED"
			dt[d]["abolished_month"] = world.month
	# areas founded during the transition: nearest area's district
	for a in AreaStore.areas(world):
		if not keep.has(String(a["district"])):
			AreaStore.set_district(world, a["id"], district_for_new_area(world, a["id"]))
	_refresh_lists(world)
	act["status"] = "EFFECTIVE"
	act["effective_month"] = world.month
	LawOps.law_fact(world, "LAW_DISTRICTING_EFFECTIVE", "PUBLIC", [{"kind": "INSTITUTION", "id": "parliament"}], [], {}, 40,
		{"act": act["id"], "districts": act["map"].keys()})


## An area in the map that was split or merged since the act: its successors get the district.
static func _assign(world: WorldState, area_id: String, did: String) -> void:
	var a := AreaStore.get_area(world, area_id)
	if a.is_empty():
		return
	if a["status"] == "ACTIVE":
		AreaStore.set_district(world, area_id, did)
	for ch in a.get("children", []):
		_assign(world, String(ch), did)


static func _refresh_lists(world: WorldState) -> void:
	var dt := world.table("law_district")
	for d in dt:
		dt[d]["areas"] = []
	for a in AreaStore.areas(world):
		var d := String(a["district"])
		if dt.has(d):
			dt[d]["areas"].append(a["id"])


## Between acts: a new area joins the district of its nearest area (AreaStore.district_resolver).
static func district_for_new_area(world: WorldState, area_id: String) -> String:
	var tiles := AreaStore.tiles_of(world, area_id)
	if tiles.is_empty():
		return ""
	var dt := world.peek("law_district")
	var best := ""
	var bd := INF
	var c := AreaStore.centroid(world, area_id)
	for a in AreaStore.areas(world):
		if a["id"] == area_id or not dt.has(String(a["district"])) or dt[String(a["district"])]["status"] != "ACTIVE":
			continue
		var d := AreaStore.centroid(world, a["id"]).distance_to(c)
		if d < bd:
			bd = d
			best = String(a["district"])
	if best == "":
		for d in Det.ordered(dt):   # no districted neighbour yet: the first active district
			if dt[d]["status"] == "ACTIVE":
				return d
	return best


static func district_name(world: WorldState, did: String) -> String:
	return String(world.peek("law_district").get(did, {}).get("name", ""))


## Founding: the charter puts every area in one district ("the Colony"). Also used once by saves that predate M13
## (any era); it is a charter act, not subject to validity or frequency limits, and does not count as a redraw.
static func ensure_founding_district(world: WorldState) -> void:
	if not world.peek("law_district").is_empty() or AreaStore.areas(world).is_empty():
		return
	var id := world.new_id("dact")
	var act := {"id": id, "month": world.month, "due_month": world.month, "level": "CHARTER", "bill": "",
		"map": {"The Colony": _active_ids(world)}, "previous_map": {}, "status": "LEGAL"}
	world.table("districting_act")[id] = act
	_apply(world, act)

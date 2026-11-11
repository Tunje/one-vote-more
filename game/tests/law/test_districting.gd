extends TestCase
## M13 A4: districts drawn by law (planning/spec-areas-v1.md §5).

const DL := preload("res://sim/law/districting.gd")
const LQ := preload("res://sim/law/law_query.gd")
const LawOps := preload("res://sim/law/law_ops.gd")


func _world(n_areas: int = 4) -> Array:
	var w := WorldState.new(17)
	Terrain.generate(w)
	LawOps.init_world(w)
	AreaStore.change_listeners = []
	AreaStore.district_resolver = func(world, area_id): return DL.district_for_new_area(world, area_id)
	var l := Terrain.landing(w)
	var ids: Array = []
	var offsets := [Vector2i(0, 0), Vector2i(6, 0), Vector2i(-14, 3), Vector2i(20, -4), Vector2i(-24, -8)]
	for i in n_areas:
		var t := Terrain.nearest_free(w, clampi(l.x + offsets[i].x, 0, Terrain.W - 1), l.y + offsets[i].y, Terrain.BUILDABLE_HOUSING, 6)
		var id := AreaStore.place_housing(w, t, 100, "GOV" if i == 0 else "COMPANY")
		if id != "" and not ids.has(id):
			ids.append(id)
	DL.ensure_founding_district(w)
	return [w, ids]


func _people(w: WorldState, hb: String, n: int) -> void:
	PopStore.seed_leaf(w, {"hb": hb, "inc": "I3", "occ": "SERVICES", "status": "EMPLOYED", "arch": "PRAG"}, n)


func test_founding_district_and_new_areas() -> void:
	var r := _world(3)
	var w: WorldState = r[0]
	var ids: Array = r[1]
	check_eq(LQ.districts(w).size(), 1, "one district at founding")
	check_eq(LQ.districts(w)[0]["name"], "The Colony", "named The Colony")
	for a in ids:
		check(LQ.district_of(w, a) == LQ.districts(w)[0]["id"], "%s in it" % a)
	var t := Terrain.nearest_free(w, Terrain.landing(w).x, Terrain.landing(w).y + 12, Terrain.BUILDABLE_HOUSING, 10)
	var nid := AreaStore.place_housing(w, t, 10, "COMPANY")
	if nid != "" and not ids.has(nid):
		check_eq(LQ.district_of(w, nid), LQ.districts(w)[0]["id"], "a new area joins its nearest area's district")


func test_act_passes_takes_effect_and_keeps_history() -> void:
	var r := _world(3)
	var w: WorldState = r[0]
	var ids: Array = r[1]
	if ids.size() < 3:
		return
	var plan := {"Landing": [ids[0]], "East": [ids[1]], "West": [ids[2]]}
	var pv := LQ.districting_preview(w, plan)
	check(pv["ok"], "valid map: %s %s" % [pv["errors"], pv["reason"]])
	var res := DL.enact(w, plan, "bill:9", "LAW")
	check(res["ok"], "enacted")
	DL.tick(w)
	check_eq(LQ.districts(w).size(), 1, "not yet: 3-month transition")
	w.month += DL.TRANSITION_MONTHS
	DL.tick(w)
	check_eq(LQ.districts(w).size(), 3, "three districts in force")
	var names := {}
	for d in LQ.districts(w):
		names[d["name"]] = d["areas"]
	check_eq(names.get("East", []), [ids[1]], "East holds its area")
	var acts := LQ.districting_acts(w)
	check(acts[0]["status"] == "EFFECTIVE" and acts[0]["previous_map"].has("The Colony"), "history: previous map kept")
	check(not w.facts.query("LAW_DISTRICTING_EFFECTIVE").is_empty(), "public fact")
	check_eq(w.peek("law_district").values().filter(func(d): return d["status"] == "ABOLISHED").size(), 1, "old district abolished")


func test_invalid_maps_rejected() -> void:
	var r := _world(4)
	var w: WorldState = r[0]
	var ids: Array = r[1]
	if ids.size() < 4:
		return
	check(not DL.preview(w, {"A": [ids[0]], "B": [ids[1]]})["ok"], "incomplete map rejected")
	check(not DL.preview(w, {"A": ids, "B": [ids[0]]})["ok"], "an area in two districts rejected")
	check(not DL.preview(w, {"A": ids}, "ADMIN")["allowed_now"], "the government cannot redistrict by decree")
	# non-contiguous: two areas that are not linked in the area graph
	var g := DL.links(w, ids)
	var pair: Array = []
	for a in ids:
		for b in ids:
			if a < b and not g[a].has(b) and pair.is_empty():
				pair = [a, b]
	if not pair.is_empty():
		var rest: Array = ids.filter(func(x): return not pair.has(x))
		var plan := {"Split": pair}
		for i in rest.size():
			plan["R%d" % i] = [rest[i]]
		var pv := DL.preview(w, plan)
		check(pv["errors"].any(func(e): return String(e).contains("not contiguous")), "non-contiguous district rejected: %s" % [pv["errors"]])
		check(not DL.enact(w, plan, "bill:x")["ok"] and not w.facts.query("LAW_DISTRICTING_REJECTED").is_empty(), "rejection fact")
	# unbalanced: a linked pair holding most people, against two small single-area districts
	var lp: Array = []
	for a in ids:
		for b in g[a]:
			if lp.is_empty() and a < b:
				lp = [a, b]
	if not lp.is_empty():
		var others: Array = ids.filter(func(x): return not lp.has(x))
		_people(w, lp[0], 900)
		_people(w, lp[1], 100)
		for o in others:
			_people(w, o, 100)
		var plan2 := {"Big": lp}
		for i in others.size():
			plan2["S%d" % i] = [others[i]]
		var pv2 := DL.preview(w, plan2)
		check(pv2["errors"].any(func(e): return String(e).contains("out of balance")), "unbalanced map rejected: %s" % [pv2["errors"]])


func test_frequency_and_remedy() -> void:
	var r := _world(3)
	var w: WorldState = r[0]
	var ids: Array = r[1]
	if ids.size() < 3:
		return
	var plan := {"A": [ids[0]], "B": [ids[1]], "C": [ids[2]]}
	check(DL.enact(w, plan, "bill:1")["ok"], "first act")
	w.month += DL.TRANSITION_MONTHS
	DL.tick(w)
	w.month += 6
	check(not DL.preview(w, plan)["allowed_now"], "no second act within 24 months: %s" % DL.preview(w, plan)["reason"])
	w.month += 24
	F_set_election(w, w.month + 6)
	check(not DL.preview(w, plan)["allowed_now"], "not in the 12 months before an election")
	F_set_election(w, w.month + 30)
	check(DL.preview(w, plan)["allowed_now"], "allowed again")


func F_set_election(w: WorldState, month: int) -> void:
	var pol := w.table("pol")
	if not pol.has("state"):
		pol["state"] = {}
	pol["state"]["next_election"] = month
	pol["state"]["era"] = "PARLIAMENTARY"


func test_split_children_follow_the_act() -> void:
	var r := _world(3)
	var w: WorldState = r[0]
	var ids: Array = r[1]
	if ids.size() < 3:
		return
	var tiles: Array = AreaStore.tiles_of(w, ids[0])
	check(DL.enact(w, {"A": [ids[0]], "B": [ids[1]], "C": [ids[2]]}, "bill:2")["ok"], "act")
	# the Landing area grows and splits during the transition
	var l := Terrain.landing(w)
	for d in [Vector2i(1, 0), Vector2i(2, 0)]:
		var t: Vector2i = l + d
		if Terrain.at(w, t.x, t.y) in Terrain.BUILDABLE_HOUSING:
			AreaStore.place_housing(w, t, 50, "GOV")
	tiles = AreaStore.tiles_of(w, ids[0])
	if tiles.size() < 2:
		return
	var child := AreaStore.split(w, ids[0], [tiles[tiles.size() - 1]], "SETTLEMENT", "SIZE")
	w.month += DL.TRANSITION_MONTHS
	DL.tick(w)
	var a_id := LQ.district_of(w, ids[0])
	check(a_id != "" and LQ.district_of(w, child) == a_id, "the split child follows its parent into district A")

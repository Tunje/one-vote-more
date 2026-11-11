extends TestCase
## M13 A4 politics side: AI districting proposals, gerrymandering within the rules, parliament votes.

const EconSim := preload("res://sim/economy/econ_sim.gd")
const DL := preload("res://sim/law/districting.gd")


## A parliamentary world with 4 areas far apart, residents in each, and voter cells tied to the areas.
func _world() -> WorldState:
	var sim: Simulation = EconSim.make(6, "BALANCED", {}, true)
	sim.run(60)
	var w := sim.world
	Terrain.generate(w)
	var l := Terrain.landing(w)
	var ids: Array = []
	for off in [Vector2i(0, 0), Vector2i(-20, -8), Vector2i(20, -8), Vector2i(0, 14)]:
		var t := Terrain.nearest_free(w, clampi(l.x + off.x, 0, Terrain.W - 1), clampi(l.y + off.y, 0, Terrain.H - 1), Terrain.BUILDABLE_HOUSING, 12)
		var a := AreaStore.place_housing(w, t, 200, "GOV")
		if a != "" and not (a in ids):
			ids.append(a)
	var i := 0
	for a in ids:
		PopStore.seed_leaf(w, {"hb": a, "inc": "I3", "occ": "SERVICES", "status": "EMPLOYED", "arch": "PRAG"}, 100 + 40 * i)
		i += 1
	# give each new area's people a party preference like the colony's established voters
	var pids: Array = PartyLife.active(w).map(func(p): return p["id"])
	var j := 0
	for c in PolVoters.all(w):
		if String(c.get("hb", "")) in ids:
			var ps := {}
			ps[pids[j % pids.size()]] = 100000
			c["prev_share"] = ps
			j += 1
	DL.ensure_founding_district(w)
	DL.tick(w)
	PolVoters.refresh(w)  # the new areas' people get their voter fields (area, district, pop)
	return w


func test_cluster_maps_cover_every_area_once() -> void:
	var w := _world()
	var ids: Array = AreaStore.areas(w).map(func(a): return a["id"])
	check(ids.size() >= 3, "areas built (%d)" % ids.size())
	for k in range(1, ids.size() + 1):
		var plan := DistrictPolitics.cluster_plan(w, ids, k)
		var seen := {}
		for g in plan:
			for a in plan[g]:
				check(not seen.has(a), "area in one district only")
				seen[a] = true
		check_eq(seen.size(), ids.size(), "k=%d covers every area" % k)


func test_gerrymander_never_hurts_the_government_and_stays_lawful() -> void:
	var w := _world()
	var st: Dictionary = w.table("pol")["state"]
	var members: Array = st["government"]["members"]
	var ids: Array = AreaStore.areas(w).map(func(a): return a["id"])
	var plan := DistrictPolitics._name_plan(w, DistrictPolitics.cluster_plan(w, ids, mini(3, ids.size())), DistrictPolitics.current_plan(w))
	var g := DistrictPolitics.gerrymander(w, plan, members)
	check(DistrictPolitics.score(w, g, members) >= DistrictPolitics.score(w, plan, members), "swaps only help the government")
	if DL.preview(w, plan, "LAW")["ok"]:
		check(DL.preview(w, g, "LAW")["ok"], "the gerrymandered map is still lawful")


func test_parliament_vote_enacts_a_new_map() -> void:
	var w := _world()
	var st: Dictionary = w.table("pol")["state"]
	var ids: Array = AreaStore.areas(w).map(func(a): return a["id"])
	var cur := DistrictPolitics.current_plan(w)
	var plan := DistrictPolitics._name_plan(w, DistrictPolitics.cluster_plan(w, ids, 2), cur)
	var r := DistrictPolitics.vote_and_enact(w, st, plan, cur, "REMEDY")
	check(r["passed"], "a fair remedy map passes")
	check(r["enacted"], "law accepted it")
	check_eq(w.facts.query("POL_DISTRICTING_VOTE").size(), 1, "vote recorded")
	w.month += DL.TRANSITION_MONTHS
	DL.tick(w)
	var names := {}
	for a in AreaStore.areas(w):
		names[DL.district_name(w, String(a["district"]))] = true
	check_eq(names.size(), 2, "after the transition the colony has two districts")

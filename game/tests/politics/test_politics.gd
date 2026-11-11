extends TestCase
## M2 exit criteria (MASTER-PLAN §4 M2): 5 consecutive elections on a stub world produce plausible, different outcomes.

const LEFT := {"REDISTRIBUTION": 70, "LABOR": 60, "ENVIRONMENT": 40, "ECON_ROLE": 50, "FISCAL": 40}
const RIGHT := {"REDISTRIBUTION": -70, "LABOR": -60, "ENVIRONMENT": -30, "ECON_ROLE": -60, "FISCAL": -50}
const ELECTIONS_5 := 240  # founding election m44, then m92, m140, m188, m236


func test_sainte_lague_threshold_and_total() -> void:
	var seats := VoteModel.allocate_seats({"a": 40000, "b": 30000, "c": 20000, "d": 7000, "e": 3000})
	var tot := 0
	for k in seats:
		tot += seats[k]
	check_eq(tot, 151, "total seats")
	check_eq(seats["e"], 0, "below 4% gets nothing")
	check(seats["a"] > seats["b"] and seats["b"] > seats["c"] and seats["c"] > seats["d"], "ordering %s" % [seats])


func test_sainte_lague_proportional() -> void:
	var seats := VoteModel.allocate_seats({"a": 50, "b": 50}, 10, 0)
	check_eq(seats["a"], 5, "even split")


func test_five_elections_full_cycle() -> void:
	var sim := PoliticalSim.make(11, "BALANCED", LEFT)
	sim.run(ELECTIONS_5)
	var w := sim.world
	var st: Dictionary = w.table("pol")["state"]
	check_eq(st["elections"].size(), 5, "five elections")
	check(w.table("party").size() >= 5, "at least five parties (got %d)" % w.table("party").size())
	for eid in st["elections"]:
		var e: Dictionary = w.table("election")[eid]
		var tot := 0
		for pid in e["seats"]:
			tot += e["seats"][pid]
		check_eq(tot, 151, "seats in %s" % eid)
	check(not st["government"].is_empty(), "a government exists")
	var passed := 0
	for b in w.table("bill").values():
		if b["status"] == "PASSED": passed += 1
	check(passed > 5, "parliament passes laws (got %d)" % passed)
	check(not w.meta.has("violations"), "no kernel violations")
	print(PoliticalSim.summary(sim))


func test_commander_persona_shapes_player_party() -> void:
	var a := PoliticalSim.make(5, "BALANCED", LEFT)
	var b := PoliticalSim.make(5, "BALANCED", RIGHT)
	a.run(30)
	b.run(30)
	var pa: Dictionary = a.world.table("party")[a.world.table("pol")["state"]["player_party"]]
	var pb: Dictionary = b.world.table("party")[b.world.table("pol")["state"]["player_party"]]
	check(pa["positions"]["REDISTRIBUTION"] > 20000, "left commander -> redistributive party (%d)" % pa["positions"]["REDISTRIBUTION"])
	check(pb["positions"]["REDISTRIBUTION"] < -20000, "right commander -> low-tax party (%d)" % pb["positions"]["REDISTRIBUTION"])
	# Mean distance is averaged over all 7 axes, but personas only act on the axes their levers touch.
	check(pa["positions"]["REDISTRIBUTION"] - pb["positions"]["REDISTRIBUTION"] > 40000, "redistribution gap")
	check(VoteModel.distance(pa["positions"], pb["positions"]) > 20.0, "identities differ (%.1f)" % VoteModel.distance(pa["positions"], pb["positions"]))


func test_pollution_scenario_boosts_green_vote() -> void:
	check(_green_vote(PoliticalSim.make(3, "POLLUTION", {})) > _green_vote(PoliticalSim.make(3, "BOOM", {})), "pollution should raise the pro-environment vote")


func _green_vote(sim: Simulation) -> float:
	sim.run(45)
	var e: Dictionary = sim.world.table("election")[sim.world.table("pol")["state"]["elections"][0]]
	var s := 0.0
	for pid in e["votes"]:
		s += float(e["votes"][pid]) / float(e["total"]) * float(sim.world.table("party")[pid]["positions"]["ENVIRONMENT"]) / 1000.0
	return s


func test_politics_deterministic_and_save_load() -> void:
	var ref := PoliticalSim.make(21, "RECESSION", LEFT)
	ref.run(50)
	check_eq(SaveIO.save(ref, save_path("pol.sav")), OK, "save")
	ref.run(60)
	var loaded := PoliticalSim.for_load()
	check_eq(SaveIO.load_into(loaded, save_path("pol.sav")), OK, "load")
	loaded.run(60)
	check_eq(loaded.world.state_hash(), ref.world.state_hash(), "save/load/continue identical")
	var twin := PoliticalSim.make(21, "RECESSION", LEFT)
	twin.run(110)
	check_eq(twin.world.state_hash(), ref.world.state_hash(), "same seed same history")

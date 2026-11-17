extends TestCase
## Month one's builders (rebuild-building.md 4.1): five from the home world, operating, plus the public works
## department, each with its crew hired from the Landing's settlers, a job recorded once, and every step in the log.

const HomeBuilders := preload("res://sim/economy/home_builders.gd")
const Company := preload("res://sim/economy/company.gd")
const TypeTable := preload("res://sim/economy/type_table.gd")
const Households := preload("res://sim/population/households.gd")
const NoiseProvider := preload("res://tests/support/noise_provider.gd")
const S := CoreUtil.S


func _world(g: int, s: int, sp: int) -> WorldState:
	var sim := Simulation.new(1, [NoiseProvider.new()])
	sim.new_game()
	var w := sim.world
	Households.seed_test(w, "area:L", "I2", "G", g)
	Households.seed_test(w, "area:L", "I3", "S", s)
	Households.seed_test(w, "area:L", "I4", "Sp", sp)
	return w


func _all(r: Dictionary) -> Array:
	var out: Array = (r["home_world"] as Array).duplicate()
	out.append(r["public_works"])
	return out


func test_five_from_the_home_world_and_the_public_works() -> void:
	var w := _world(400, 200, 70)
	var r := HomeBuilders.land(w, "area:L")
	var ids: Array = r["home_world"]
	check_eq(ids.size(), 5, "five building companies")
	var sizes: Array = []
	for cid in ids:
		var c := Company.record(w, cid)
		sizes.append(String(c["size"]))
		check_eq(String(c["type"]), "BUILDER", "a builder")
		check_eq(String(c["owner"]["kind"]), "HOME_WORLD", "owned by the home world")
		check(Company.plant_ids_of(w, cid).is_empty(), "no plant: it needs no building to exist")
		check_eq(Company.price(w, cid, "BW"), TypeTable.start_price("BW"), "the starting price per BW")
		check(absi(Company.price(w, cid, "BW") - 392 * S) < S, "about 392 a BW")
		check_eq(String(c["area"]), "area:L", "its home area is the Landing")
	check_eq(sizes, ["LARGE", "AVERAGE", "AVERAGE", "SMALL", "SMALL"], "one large, two average, two small")
	var pw := Company.record(w, r["public_works"])
	check_eq(String(pw["owner"]["kind"]), "STATE", "the public works department is the state's")
	check_eq(String(pw["size"]), "AVERAGE", "average size")


func test_crews_are_hired_whole_and_counted_once() -> void:
	var w := _world(400, 200, 70)
	var r := HomeBuilders.land(w, "area:L")
	var total := {"G": 0, "S": 0, "Sp": 0}
	for cid in _all(r):
		for t in total:
			total[t] += Company.staff_count(w, cid, t, "crew") / S
	check_eq(total, {"G": 132, "S": 66, "Sp": 22}, "220 crew: the five builders' 180 and the public works' 40")
	var five := 0
	for cid in r["home_world"]:
		five += Company.staff_count(w, cid, "", "crew") / S
	check_eq(five, 180, "the five builders' crews are 180, three full builder units")
	check_eq(HomeBuilders.bw_milli(w, r["home_world"][0]), 60 * 1000, "a large builder makes 60 BW a month")
	check_eq(HomeBuilders.bw_milli(w, r["home_world"][1]), 40 * 980, "an average one: 40 crew less 2%")
	var left := 0
	for t in ["G", "S", "Sp"]:
		for pid in Households.unemployed(w, "area:L", t):
			left += int(Households.unemployed(w, "area:L", t)[pid])
	check_eq(left, 670 - 220, "the rest of the settlers stay jobless")
	check_eq(Households.check(w), [], "jobs = people: every crew member is one employed person")


func test_every_step_is_in_the_log() -> void:
	var w := _world(400, 200, 70)
	var r := HomeBuilders.land(w, "area:L")
	for cid in _all(r):
		check_eq(Logbook.rows(w, {"who": cid, "kind": "OPEN"}).size(), 1, "made: one OPEN row")
		check_eq(Logbook.rows(w, {"who": cid, "kind": "LAND"}).size(), 1, "why it exists: one LAND row")
		check(Logbook.rows(w, {"who": cid, "kind": "HIRE"}).size() >= 3, "its crew hired, every tier logged")
	check_eq(Logbook.rows(w, {"kind": "CREW"}).size(), 0, "no crew short when the settlers suffice")


func test_too_few_settlers_hires_what_there_is_and_says_so() -> void:
	var w := _world(50, 20, 5)
	var r := HomeBuilders.land(w, "area:L")
	var first: String = r["home_world"][0]
	var second: String = r["home_world"][1]
	check_eq(Company.staff_count(w, first, "Sp", "crew") / S, 5, "the first builder takes the 5 specialists there are")
	check_eq(Company.staff_count(w, first, "S", "crew") / S, 18, "its skilled posts in full")
	check_eq(Company.staff_count(w, first, "G", "crew") / S, 36, "its general posts in full")
	check_eq(Company.staff_count(w, second, "S", "crew") / S, 2, "the next gets the 2 skilled left")
	check_eq(Company.staff_count(w, second, "G", "crew") / S, 14, "and the 14 general left")
	check_eq(Company.staff_count(w, r["home_world"][2], "", "crew"), 0, "the third gets none")
	check(Logbook.rows(w, {"kind": "CREW"}).size() >= 5, "every short crew is in the log")


func test_a_higher_skill_fills_a_lower_post_when_its_own_runs_out() -> void:
	var w := _world(30, 200, 70)
	var r := HomeBuilders.land(w, "area:L")
	var first: String = r["home_world"][0]
	check_eq(Company.staff_count(w, first, "G", "crew") / S, 36, "the large builder's 36 general posts are filled")
	var total := 0
	for cid in _all(r):
		total += Company.staff_count(w, cid, "", "crew") / S
	check_eq(total, 220, "every post filled: skilled settlers took general posts")


func test_in_a_real_new_game_the_settlers_fill_every_crew() -> void:
	var w := GameSim.make(3).world
	var landing := AreaStore.found_landing(w)
	var r := HomeBuilders.land(w, landing)
	var total := 0
	for cid in _all(r):
		total += Company.staff_count(w, cid, "", "crew") / S
	check_eq(total, 220, "the founding settlers fill all 220 posts")
	check_eq(Logbook.rows(w, {"kind": "CREW"}).size(), 0, "nobody short")
	check_eq(Households.check(w), [], "jobs = people")
	check_eq(Company.occupation(w, r["public_works"], "G"), "PUBLIC_SECTOR", "the public works crew are public sector")


func test_landing_twice_makes_nothing_new() -> void:
	var w := _world(400, 200, 70)
	var a := HomeBuilders.land(w, "area:L")
	var n := Company.ids(w).size()
	var b := HomeBuilders.land(w, "area:L")
	check_eq(b, a, "the same builders")
	check_eq(Company.ids(w).size(), n, "no second set")
	w.table("company")[a["home_world"][0]]["name"] = "Renamed Ltd"  # a test may write the record; game code may not
	check_eq(HomeBuilders.land(w, "area:L"), a, "found by what they are, not by name")
	check_eq(Company.ids(w).size(), n, "still no second set after a rename")

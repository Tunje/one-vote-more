extends TestCase
## M10 S1: population store (population.md §2, §26; planning/spec-population-v1.md §2, §13).


func _world() -> WorldState:
	return WorldState.new(7)


func _p(hb: String, inc: String, occ: String, status: String, arch: String, eff: String = "e0") -> Dictionary:
	return {"hb": hb, "inc": inc, "occ": occ, "status": status, "arch": arch, "eff": eff}


func _ok(w: WorldState) -> void:
	var errs := PopStore.reconcile(w)
	check(errs.is_empty(), "reconcile: %s" % str(errs))


## PD test 1: a 1,000-resident housing block divided through all five levels; every level totals 1,000.
func test_pd1_conservation_through_all_levels() -> void:
	var w := _world()
	var spec := [
		["I1", "MINING", "EMPLOYED", "LABOR", "e0", 120], ["I1", "MINING", "EMPLOYED", "LABOR", "e:POLL", 80],
		["I1", "MINING", "UNEMPLOYED", "MARKET", "e0", 50], ["I2", "SERVICES", "EMPLOYED", "STABILITY", "e0", 200],
		["I3", "PROFESSIONAL", "EMPLOYED", "ENVIRONMENT", "e0", 150], ["I3", "NONE", "CHILD", "LABOR", "e0", 250],
		["I5", "BUSINESS_OWNER", "EMPLOYED", "MARKET", "e0", 150]]
	for s in spec:
		PopStore.seed_leaf(w, _p("hb:A", s[0], s[1], s[2], s[3], s[4]), s[5])
	_ok(w)
	for level in ["HOUSING", "INCOME", "WORK", "PHILOSOPHY", "EFFECT"]:
		var t := 0
		for bk in PopQuery.blocks(w, level):
			t += PopQuery.blocks(w, level)[bk]
		check_eq(t, 1000, "level %s total" % level)
	var hb := PopQuery.block(w, "HOUSING", "hb:A")
	check_eq(hb["n"], 1000, "housing block")
	var ch := 0
	for c in hb["children"]:
		ch += hb["children"][c]
	check_eq(ch, 1000, "children of the housing block sum to it")
	check_eq(PopQuery.block(w, "WORK", "hb:A|I1|MINING|EMPLOYED")["n"], 200, "work block = both effect leaves")


## PD test 3: moving 100 residents between housing blocks.
func test_pd3_migration_moves_exactly() -> void:
	var w := _world()
	PopStore.seed_leaf(w, _p("hb:A", "I2", "SERVICES", "EMPLOYED", "LABOR"), 600)
	PopStore.seed_leaf(w, _p("hb:B", "I2", "SERVICES", "EMPLOYED", "LABOR"), 300)
	var moved := PopStore.move_group(w, {"hb": "hb:A"}, 100, {"hb": "hb:B"}, "MOVE")
	check_eq(moved, 100, "moved")
	check_eq(PopQuery.block(w, "HOUSING", "hb:A")["n"], 500, "source -100")
	check_eq(PopQuery.block(w, "HOUSING", "hb:B")["n"], 400, "destination +100")
	check_eq(PopStore.total(w), 900, "colony unchanged")
	_ok(w)
	var f := PopStore.flows(w, w.month)
	check_eq(f.size(), 1, "one ledger row")
	check_eq(int(f[0]["n"]), 100, "ledger records 100")


## PD test 8: two pressures on the same people are recorded without doubling them.
func test_pd8_overlapping_effects_do_not_duplicate() -> void:
	var w := _world()
	var k := PopStore.seed_leaf(w, _p("hb:A", "I1", "MINING", "EMPLOYED", "LABOR"), 45)
	PopStore.transfer(w, k, PopStore.relabel(k, {"eff": "e:POLL"}), 20, "EXPOSURE")
	PopStore.transfer(w, k, PopStore.relabel(k, {"eff": "e:POLL+UNSAFE"}), 15, "EXPOSURE")
	check_eq(PopQuery.block(w, "PHILOSOPHY", "hb:A|I1|MINING|EMPLOYED|LABOR")["n"], 45, "still 45 people")
	check_eq(PopQuery.blocks(w, "EFFECT").size(), 3, "three exposure groups (20/15/10)")
	_ok(w)


## PD test 19 / §1.2: people keep their beliefs and history when they move; beliefs mix by weight.
func test_pd19_beliefs_travel_with_people() -> void:
	var w := _world()
	var miners := PopStore.seed_leaf(w, _p("hb:A", "I2", "MINING", "EMPLOYED", "LABOR"), 100, {},
		{"ideology": {"LABOR": 80000}, "trust": {"gov": 20000}, "approval": 30000})
	var jobless := PopStore.seed_leaf(w, _p("hb:A", "I1", "MINING", "UNEMPLOYED", "LABOR"), 100, {},
		{"ideology": {"LABOR": 0}, "trust": {"gov": 60000}, "approval": 70000})
	PopStore.transfer(w, miners, jobless, 100, "LAYOFF")
	var l: Dictionary = w.table("pop")[jobless]
	check_eq(int(l["n"]), 200, "merged")
	check_eq(int(l["ideology"]["LABOR"]), 40000, "beliefs averaged by weight")
	check_eq(int(l["trust"]["gov"]), 40000, "trust averaged")
	check(not w.table("pop").has(miners), "empty leaf removed")
	# moving into an empty leaf copies the movers' beliefs exactly
	var dst := PopStore.relabel(jobless, {"hb": "hb:B"})
	PopStore.transfer(w, jobless, dst, 50, "MOVE")
	check_eq(int(w.table("pop")[dst]["approval"]), 50000, "movers keep their approval")
	_ok(w)


## Layoff by skill (88's review B): only skilled workers leave; age follows the leaf's mix.
func test_move_group_by_skill_bucket() -> void:
	var w := _world()
	PopStore.seed_leaf(w, _p("hb:A", "I2", "MINING", "EMPLOYED", "LABOR"), 60, {"age": {"Y": 30, "A": 30}, "skill": {"G": 40, "S": 20}})
	PopStore.seed_leaf(w, _p("hb:A", "I3", "MINING", "EMPLOYED", "MARKET"), 40, {"age": {"A": 40}, "skill": {"G": 20, "S": 20}})
	var n := PopStore.move_group(w, {"hb": "hb:A", "occ": "MINING", "status": "EMPLOYED"}, 30, {"status": "UNEMPLOYED"}, "LAYOFF", "skill:S")
	check_eq(n, 30, "30 laid off")
	check_eq(PopStore.count(w, {"status": "UNEMPLOYED"}, "skill:S"), 30, "all of them skilled")
	check_eq(PopStore.count(w, {"status": "UNEMPLOYED"}, "skill:G"), 0, "no general workers")
	check_eq(PopStore.count(w, {"status": "EMPLOYED"}, "skill:S"), 10, "10 skilled left")
	check_eq(PopStore.count(w, {"occ": "MINING"}), 100, "laid-off miners stay miners")
	check(PopStore.move_group(w, {"status": "UNEMPLOYED"}, 999, {"status": "EMPLOYED"}, "HIRE") == 30, "cannot move more than exist")
	_ok(w)


func test_births_deaths_arrivals_departures_reconcile() -> void:
	var w := _world()
	var k := PopStore.seed_leaf(w, _p("hb:A", "I2", "SERVICES", "EMPLOYED", "LABOR"), 500, {"age": {"Y": 200, "A": 200, "O": 100}}, {"approval": 40000})
	var kid := PopStore.relabel(k, {"occ": "NONE", "status": "CHILD"})
	PopStore.birth(w, kid, 12, w.table("pop")[k])
	PopStore.death(w, k, 7, {"age": "O"})
	check_eq(int(w.table("pop")[k]["age"]["O"]), 93, "deaths came from the old")
	PopStore.arrive(w, PopStore.relabel(k, {"hb": "hb:B"}), 40, {"age": {"Y": 40}, "skill": {"S": 40}})
	PopStore.depart(w, k, 5)
	check_eq(PopStore.total(w), 500 + 12 - 7 + 40 - 5, "total")
	check_eq(int(w.table("pop")[kid]["approval"]), 40000, "children inherit the parents' state")
	check_eq(PopStore.count(w, {"hb": "hb:B"}, "recent"), 40, "immigrants are recent")
	_ok(w)
	# tampering is detected
	w.table("pop")[k]["n"] = int(w.table("pop")[k]["n"]) + 1
	check(not PopStore.reconcile(w).is_empty(), "reconcile catches a created resident")


func test_split_over_and_flow_compaction() -> void:
	var w := _world()
	var s := PopStore.split_over(10, ["a", "b", "c"], [1, 1, 1])
	check_eq(int(s["a"]) + int(s["b"]) + int(s["c"]), 10, "largest remainder keeps the total")
	var k := PopStore.seed_leaf(w, _p("hb:A", "I2", "SERVICES", "EMPLOYED", "LABOR"), 100)
	PopStore.transfer(w, k, PopStore.relabel(k, {"inc": "I3"}), 10, "RAISE")
	w.month = 40
	PopStore.compact_flows(w)
	check(PopStore.flows(w, 0).is_empty(), "old monthly rows compacted")
	check_eq(int(w.table("pop_flow").get("Y1|hb:A|I2>hb:A|I3|RAISE", 0)), 10, "kept as a yearly level-2 row")


func test_determinism_and_save_round_trip() -> void:
	var a := _world()
	var b := _world()
	for w in [a, b]:
		var k := PopStore.seed_leaf(w, _p("hb:A", "I2", "MINING", "EMPLOYED", "LABOR"), 333, {"age": {"Y": 111, "A": 222}, "skill": {"G": 300, "Sp": 33}}, {"ideology": {"LABOR": 12345}})
		PopStore.move_group(w, {"occ": "MINING"}, 77, {"status": "UNEMPLOYED"}, "LAYOFF")
		PopStore.move_group(w, {"status": "UNEMPLOYED"}, 13, {"hb": "hb:B"}, "MOVE", "age:Y")
	check_eq(a.state_hash(), b.state_hash(), "deterministic")
	var c := _world()
	c.load_dict(a.to_dict())
	check_eq(c.state_hash(), a.state_hash(), "save/load round trip")
	_ok(c)

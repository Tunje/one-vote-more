extends TestCase
## M10 S3a: philosophy blocks (archetypes) on population leaves (population.md §6).


func _world() -> WorldState:
	var w := WorldState.new(21)
	w.table("pol")["state"] = {}
	PopStore.seed_leaf(w, {"hb": "hb:1", "inc": "I2", "occ": "MINING", "status": "EMPLOYED", "arch": "MIX"}, 400)
	PopStore.seed_leaf(w, {"hb": "hb:1", "inc": "I5", "occ": "BUSINESS_OWNER", "status": "EMPLOYED", "arch": "MIX"}, 100)
	PopStore.seed_leaf(w, {"hb": "hb:1", "inc": "I1", "occ": "MINING", "status": "UNEMPLOYED", "arch": "MIX"}, 60)
	return w


func test_everyone_gets_a_philosophy_and_nobody_is_lost() -> void:
	var w := _world()
	var n := Philosophy.assign(w)
	check_eq(n, 560, "all 560 assigned")
	check_eq(PopStore.count(w, {"arch": "MIX"}), 0, "no placeholders left")
	check_eq(PopStore.total(w), 560, "population conserved")
	check(PopStore.reconcile(w).is_empty(), "reconciles")
	for k in w.peek("pop"):
		check(w.peek("pop")[k].has("ideology"), "%s has beliefs" % k)


func test_miners_disagree_and_owners_lean_market() -> void:
	var w := _world()
	Philosophy.assign(w)
	var miner_archs := PopStore.select(w, {"occ": "MINING", "status": "EMPLOYED"}).size()
	check(miner_archs >= 3 and miner_archs <= Philosophy.MAX_PER_BLOCK, "miners hold several philosophies (%d)" % miner_archs)
	check(PopStore.count(w, {"occ": "BUSINESS_OWNER", "arch": "MARKET"}) > PopStore.count(w, {"occ": "BUSINESS_OWNER", "arch": "LABOR"}), "owners lean market")
	var m: Dictionary = w.peek("pop")[PopStore.select(w, {"occ": "BUSINESS_OWNER", "arch": "MARKET"})[0]]
	var l: Array = PopStore.select(w, {"occ": "MINING", "status": "EMPLOYED", "arch": "LABOR"})
	if not l.is_empty():
		check(int(w.peek("pop")[l[0]]["ideology"]["LABOR"]) > int(m["ideology"]["LABOR"]), "labour-minded miners are more pro-labour than market-minded owners")


func test_new_arrivals_join_existing_philosophy_groups() -> void:
	var w := _world()
	Philosophy.assign(w)
	var before := w.peek("pop").size()
	PopStore.arrive(w, "hb:1|I2|MINING|EMPLOYED|MIX|e0", 40)
	Philosophy.assign(w)
	check_eq(w.peek("pop").size(), before, "arrivals spread into the same groups")
	check_eq(PopStore.total(w), 600, "counted")


func test_deterministic() -> void:
	var a := _world()
	var b := _world()
	Philosophy.assign(a)
	Philosophy.assign(b)
	check_eq(a.state_hash(), b.state_hash(), "same seed, same philosophies")

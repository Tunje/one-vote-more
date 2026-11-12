extends TestCase
## A53: strategy genes (500 = today's behaviour) and the learning party.


func test_default_genome_changes_nothing() -> void:
	var a: Simulation = EconSim.make(5, "BALANCED", {}, true)
	a.run(60)
	var b: Simulation = EconSim.make(5, "BALANCED", {}, true)
	b.run(30)
	for pid in b.world.table("party"):
		var g := {}
		for gene in Learn.GENES:
			g[gene] = 500
		b.world.table("party")[pid]["strategy"] = g
	b.run(30)
	for pid in b.world.table("party"):
		b.world.table("party")[pid].erase("strategy")
	check_eq(b.world.state_hash(), a.world.state_hash(), "an explicit all-500 genome plays exactly like no genome")


func test_learning_party_moves_its_genome() -> void:
	var sim: Simulation = EconSim.make(6, "BALANCED", {}, true)
	sim.world.meta["learning_party"] = "auto"
	sim.run(120)
	var ls: Dictionary = sim.world.table("pol")["state"].get("learn", {})
	check(ls.get("history", []).size() >= 5, "it stepped each January and election (got %d)" % ls.get("history", []).size())
	check(typeof(ls.get("base_score")) == TYPE_INT, "integer state only")
	var p: Dictionary = sim.world.table("party")[ls["party"]]
	var moved := false
	for g in Learn.GENES:
		if Learn.gene(p, g) != 500:
			moved = true
	check(moved, "the genome moved away from the default")

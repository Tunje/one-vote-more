extends TestCase
## M4 gate item 2: the M2 election suite on the REAL economy (EconSim.make: law + staff + econ + politics).
## The stub-world versions stay in test_politics.gd.

const LEFT := {"REDISTRIBUTION": 70, "LABOR": 60, "ENVIRONMENT": 40, "ECON_ROLE": 50, "FISCAL": 40}
const ELECTIONS_5 := 240


func test_five_elections_on_real_economy() -> void:
	var sim := EconSim.make(11, "BALANCED", LEFT)
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
	check_eq(w.ledger.total(), 0, "money conserved")
	check(not w.meta.has("violations"), "no kernel violations")
	check(EconReport.goods_errors(w).is_empty(), "goods conserved")
	print(PoliticalSim.summary(sim))


func test_census_replaces_stub() -> void:
	var sim := EconSim.make(2, "BALANCED", {})
	sim.run(3)
	check(not sim.world.indicators.defs.has("STUB_UNEMPLOYMENT"), "no stub-world indicators registered")
	check(sim.world.table("census").size() >= 30, "econ census feeds politics")

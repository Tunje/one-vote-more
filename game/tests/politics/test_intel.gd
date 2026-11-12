extends TestCase
## A49: pictures of the electorate (noise and bubble by quality, slow uptake) and policy beliefs that learn.


func _sim() -> Simulation:
	var sim: Simulation = EconSim.make(4, "BALANCED", {}, true)
	sim.run(72)
	return sim


func _err(pic: Array, truth: Array) -> float:
	var e := 0.0
	for c in PolDefs.CONCERNS:
		e += absf(float(pic[0][c]) - float(truth[0][c]))
	return e / float(PolDefs.CONCERNS.size())


func test_pictures_exist_differ_and_err_by_quality() -> void:
	var sim := _sim()
	var w := sim.world
	var truth: Array = PoliticsProvider.new().colony_concerns(w)
	var intel: Dictionary = w.table("pol")["state"].get("intel", {})
	check(intel.has("gov"), "the government has a picture")
	var parties: Array = intel.keys().filter(func(k): return k != "gov")
	check(parties.size() >= 3, "parties have pictures")
	var errs: Array = []
	for pid in parties:
		errs.append([int(intel[pid]["q"]), _err(Intel.picture(w, pid), truth)])
	errs.sort_custom(func(a, b): return a[0] < b[0])
	check(_err(Intel.picture(w, String(parties[0])), truth) > 0.0, "pictures are not the truth")
	check(float(errs[0][1]) >= float(errs[errs.size() - 1][1]) * 0.5, "low-quality research errs at least comparably (got %s)" % str(errs))


func test_picture_is_a_pure_read() -> void:
	var sim := _sim()
	var h := sim.world.state_hash()
	Intel.picture(sim.world, "gov")
	Intel.belief(sim.world, "party:1", "ECON_BENEFIT_DURATION")
	check_eq(sim.world.state_hash(), h, "reads change nothing")


func test_beliefs_have_ideological_priors_and_learn() -> void:
	var sim := _sim()
	var w := sim.world
	var priors: Array = []
	for pid in w.table("party"):
		priors.append(Intel._prior(w, pid, "ECON_BENEFIT_DURATION"))
	priors.sort()
	check(priors[0] < priors[priors.size() - 1], "parties start with different beliefs (%s)" % str(priors))
	sim.run(60)
	var learned: Dictionary = w.table("pol")["state"].get("beliefs", {})
	var n := 0
	for pid in learned:
		n += learned[pid].size()
	check(n > 0, "beliefs were updated from the record")


func test_deterministic_and_save_load() -> void:
	var a: Simulation = EconSim.make(4, "BALANCED", {}, true)
	a.run(30)
	check_eq(SaveIO.save(a, save_path("intel.sav")), OK, "save")
	a.run(15)
	var b: Simulation = EconSim.for_load()
	check_eq(SaveIO.load_into(b, save_path("intel.sav")), OK, "load")
	b.run(15)
	check_eq(b.world.state_hash(), a.world.state_hash(), "save/load/continue identical")

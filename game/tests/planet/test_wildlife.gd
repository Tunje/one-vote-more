extends TestCase
## Terra: the planet's food pyramid (sim/planet/planet_wildlife.gd, ecology stage 2 under ECO): levels and cascades,
## culling, creatures per seed, attacks on people and their facts.


func _world(seed_v: int = 4) -> WorldState:
	var w := WorldState.new(seed_v)
	Planet.generate(w)
	CoreUtil.st(w)["emissions"] = {}
	var l := Planet.landing(w)
	w.table("planet")["uses"] = {str(l): {"kind": "COLONY"}}
	return w


## Months of the food web only, with the land's pollution and harm held where the test put them.
func _months(w: WorldState, n: int, eco: Dictionary = {}) -> void:
	for _m in n:
		w.month += 1
		w.table("planet")["eco"] = eco.duplicate(true)
		PlanetWildlife.step_month(w)


func test_untouched_land_stays_in_balance() -> void:
	var w := _world()
	w.levers[PlanetWildlife.POLICY_LEVER] = "PROTECT"   # no hunting, no pollution, no clearing
	_months(w, 60)
	check(w.peek("planet").get("web", {}).is_empty(), "nothing disturbed: nothing stored (%s)" % str(w.peek("planet").get("web", {})))
	var l := PlanetWildlife.levels(w, Planet.landing(w))
	for lv in PlanetWildlife.LEVELS:
		check_eq(int(l[lv]), 1000, "%s at natural balance" % lv)
	check_eq(PlanetWildlife.yield_loss(w, Planet.landing(w)), 0, "no yield lost")
	check_eq(PlanetWildlife.web_health(w, Planet.landing(w)), 1000, "a healthy web")


func test_pollution_wipes_insects_and_the_loss_climbs_the_pyramid() -> void:
	var w := _world()
	var l := Planet.landing(w)
	var cap := PlanetEcology.capacity(w, l)
	_months(w, 180, {str(l): [cap * 1000, 500]})   # loaded to capacity and half harmed
	var lv := PlanetWildlife.levels(w, l)
	check(int(lv["pol"]) < 400, "pollinators are wiped out first (%d‰)" % int(lv["pol"]))
	check(int(lv["forg"]) < 900, "fewer insects, fewer insect-eaters (%d‰)" % int(lv["forg"]))
	check(int(lv["pred"]) < 900, "and fewer predators (%d‰)" % int(lv["pred"]))
	check(PlanetWildlife.yield_loss(w, l) > 0, "farms miss the pollinators (%d%%)" % PlanetWildlife.yield_loss(w, l))
	for k in w.peek("planet")["web"]:
		for v in w.peek("planet")["web"][k]:
			check_eq(typeof(v), TYPE_INT, "integer state")
	# cleaned up: the web comes back
	_months(w, 600, {})
	var back := PlanetWildlife.levels(w, l)
	check(int(back["pol"]) > 900 and int(back["pred"]) > 850, "decades later the web has recovered (%s)" % str(back))


func test_culling_predators_lets_grazers_and_pests_boom() -> void:
	var w := _world()
	var l := Planet.landing(w)
	w.levers[PlanetWildlife.POLICY_LEVER] = "CULL"
	_months(w, 240)
	var lv := PlanetWildlife.levels(w, l)
	check(int(lv["pred"]) < 300, "predators culled (%d‰)" % int(lv["pred"]))
	check(int(lv["graz"]) > 1500, "grazers boom without predators (%d‰)" % int(lv["graz"]))
	check(int(lv["forg"]) > 1200, "insect-eaters boom (%d‰)" % int(lv["forg"]))
	check(int(lv["pol"]) < 1000, "and eat into the pollinators (%d‰)" % int(lv["pol"]))
	check(PlanetWildlife.yield_loss(w, l) >= 3, "crops pay for it (%d%%)" % PlanetWildlife.yield_loss(w, l))
	var w2 := _world()
	w2.levers[PlanetWildlife.POLICY_LEVER] = "PROTECT"
	_months(w2, 240)
	check_eq(int(PlanetWildlife.levels(w2, l)["pred"]), 1000, "PROTECT: predators stay at their natural level")
	var w3 := _world()
	_months(w3, 240)
	check(int(PlanetWildlife.levels(w3, l)["pred"]) < 1000 and int(PlanetWildlife.levels(w3, l)["pred"]) > 600, "MANAGE: some hunting at the colony")


func test_every_world_has_its_own_creatures() -> void:
	var dangers := {}
	var names := {}
	for sd in range(1, 21):
		var a := _world(sd)
		var ch := PlanetWildlife.character(a)
		check_eq(ch, PlanetWildlife.character(_world(sd)), "pure in the seed")
		check(int(ch["danger"]) >= 1 and int(ch["danger"]) <= 5, "danger 1..5")
		check(float(ch["dependence"]) >= 0.3 and float(ch["dependence"]) <= 1.0, "crop dependence 0.3..1")
		dangers[int(ch["danger"])] = true
		names[PlanetWildlife.creature(a, "pred")] = true
	check(dangers.size() >= 3, "dangers differ between worlds (%s)" % str(dangers.keys()))
	check(names.size() >= 3, "predators differ between worlds (%s)" % str(names.keys()))


func test_attacks_hit_the_wild_edge_and_report_the_place() -> void:
	var sim := GameSim.make(2, "BALANCED", {}, true)
	for _m in 24:
		sim.step()
	var w := sim.world
	var ss := PlanetWildlife.sites(w)
	check(not ss.is_empty(), "the colony has places that meet the wild")
	for s in ss:
		check(String(s["kind"]) in PlanetWildlife.OUTDOOR_SITES + ["SETTLEMENT"], "outdoor work or a settlement (%s)" % s["kind"])
		check(float(s["exposure"]) >= 0.0 and float(s["exposure"]) <= 1.0, "exposure in 0..1")
	# many hungry predators everywhere: attacks come, at exposed sites
	var web := {}
	for s in ss:
		web[str(int(s["hex"]))] = [1000, 1000, 1000, 1000, 3000]
	w.table("planet")["web"] = web
	var r := RandomNumberGenerator.new()
	r.seed = 7
	var n := 0
	var killed := 0
	var at_exposed := 0
	for _k in 600:
		for a in PlanetWildlife._attacks(w, r, PlanetWildlife.character(w)):
			n += 1
			killed += int(a["killed"])
			at_exposed += 1 if float(a["site"]["exposure"]) > 0.0 else 0
	check(n > 0, "attacks happen (%d in 600 months)" % n)
	check_eq(at_exposed, n, "only where people meet the wild")
	check(killed <= n, "not every attack kills (%d of %d)" % [killed, n])
	# the fact names the place, the creature and the farm's grant
	var site: Dictionary = ss[0]
	# WAITS FOR REBUILD STEP 11: a site's "org" is now a company id ("company:N"); the farm's grant is read from the
	# old "org" table here and in PlanetProvider._report_wild, and must come from Grants through the doorway instead.
	if String(site["org"]) != "" and w.table("org").has(String(site["org"])):
		w.table("org")[String(site["org"])]["family"] = true
		w.table("org")[String(site["org"])]["grant_paid"] = 5000
		w.table("org")[String(site["org"])]["grant_month"] = w.month - 3
	PlanetProvider.new()._report_wild(w, {"attacks": [{"site": site, "killed": 1, "injured": 0}], "crossed": [], "swarm": false})
	var f: Array = w.facts.query("PLANET_WILDLIFE_ATTACK", w.month, w.month)
	check_eq(f.size(), 1, "one attack fact")
	if f.size() == 1:
		var d: Dictionary = f[0]["data"]
		check_eq(String(d["creature"]), PlanetWildlife.creature(w, "pred"), "the world's predator")
		# WAITS FOR REBUILD STEP 3 (Wilma, 2026-11-17): who dies is taken from the people at the site, through
		# EconFace.pop_casualties, which answers 0 until staff and household pools exist. Then this is 1 again.
		check_eq(int(d["killed"]), EconFace.pop_casualties(w, String(site.get("district", "")), 1, "OUTDOOR", String(site.get("fid", ""))), "killed counted, as many as the people side says died")
		check_eq(String(d["site"]), String(site["kind"]), "what stood there")
		if String(site["org"]) != "" and w.table("org").has(String(site["org"])):   # WAITS FOR REBUILD STEP 11, as above
			check(bool(d["grant_funded"]) and bool(d["family_farm"]), "a grant-funded family farm")
			check_eq(int(d["grant_month"]), w.month - 3, "when the grant was paid")
		check_eq(f[0]["visibility"], "PUBLIC", "public")


func test_in_the_game_deterministic_and_save_load() -> void:
	var a := GameSim.make(3, "BALANCED", {}, true)
	var b := GameSim.make(3, "BALANCED", {}, true)
	for _m in 18:
		a.step()
		b.step()
	check_eq(var_to_str(a.world.peek("planet").get("web", {})), var_to_str(b.world.peek("planet").get("web", {})), "deterministic")
	check(a.world.levers.has(PlanetWildlife.POLICY_LEVER), "the wildlife lever exists")
	var path := "user://test_wildlife.sav"
	check_eq(SaveIO.save(a, path), OK, "saved")
	var c := GameSim.for_load()
	check_eq(SaveIO.load_into(c, path), OK, "loaded")
	check_eq(var_to_str(c.world.peek("planet").get("web", {})), var_to_str(a.world.peek("planet").get("web", {})), "the web survives save/load")
	a.step()
	c.step()
	check_eq(c.world.state_hash(), a.world.state_hash(), "save/load/continue stays identical")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_danger_by_district_follows_the_attacks_formula() -> void:
	var sim := GameSim.make(2, "BALANCED", {}, true)
	for _m in 3:
		sim.step()
	var w := sim.world
	var ds := {}
	for s in ColonyLayout.settlements(w):
		ds[String(s["district"])] = true
	check(not ds.is_empty(), "districts")
	var h := w.state_hash()
	var ch := PlanetWildlife.character(w)
	var season := 1.6 - 0.8 * PlanetSeasons.mean_activity(w, Planet.landing(w))
	var lam := 0.0   # the attack formula's monthly rate, summed over every site
	for s in PlanetWildlife.sites(w):
		lam += PlanetWildlife.ATTACK_BASE * float(ch["danger"]) * float(ch["boldness"]) * season * float(PlanetWildlife.levels(w, int(s["hex"]))["pred"]) / 1000.0 * float(s["exposure"])
	var total := 0
	for d in ds:
		total += PlanetWildlife.district_risk_pm(w, String(d))
	check(absi(total - roundi(lam * 12000.0)) <= ds.size(), "the districts add up to the colony's expected attacks a year (%d vs %d)" % [total, roundi(lam * 12000.0)])
	check_eq(w.state_hash(), h, "pure")
	# more predators: more risk at once (the memo key holds the food web), and the bar marks a district dangerous
	var before := {}
	for d in ds:
		before[d] = PlanetWildlife.district_risk_pm(w, String(d))
	var web := {}
	for s in PlanetWildlife.sites(w):
		web[str(int(s["hex"]))] = [1000, 1000, 1000, 1000, 3000]
	w.table("planet")["web"] = web
	var any := false
	for d in ds:
		var r := PlanetWildlife.district_risk_pm(w, String(d))
		check(r >= int(before[d]), "more predators, more risk in %s (%d -> %d)" % [d, int(before[d]), r])
		check_eq(PlanetWildlife.dangerous_district(w, String(d)), r >= PlanetWildlife.DANGER_PM, "dangerous from DANGER_PM")
		any = any or r > int(before[d])
	check(any, "the risk rose somewhere")
	# no predators: no danger anywhere
	for k in web:
		web[k] = [1000, 1000, 1000, 1000, 0]
	w.table("planet")["web"] = web.duplicate(true)
	for d in ds:
		check_eq(PlanetWildlife.district_risk_pm(w, String(d)), 0, "no predators, no risk in %s" % d)
		check(not PlanetWildlife.dangerous_district(w, String(d)), "and not dangerous")

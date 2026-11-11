extends SceneTree
## MEDIA v1 probe (Anni): runs one seed and reports outlets, editions, readership, news vectors and ms per month.
##   godot --headless --path game --script res://tools/probe_media.gd -- [seed] [months]


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var sd := int(a[0]) if a.size() > 0 else 1
	var months := int(a[1]) if a.size() > 1 else 72
	var sim := Simulation.new(sd)
	sim.world.meta["scenario"] = "BALANCED"
	sim.world.meta["persona"] = {}
	sim.world.meta["autoplay_player"] = true
	EconSim._register(sim)
	sim.new_game()
	var media_us := 0
	for m in months:
		sim.step()
		if m == 24:   # exercise a plural press: a labour paper and a business paper
			Media.found_outlet(sim.world, {"kind": "UNION", "id": "union:fed"}, {"name": "The Worker",
				"line": Media._vec([25, 40, 45, 0, 0, 25, 0, 5]), "price_mw": 1})
			Media.found_outlet(sim.world, {"kind": "COMPANY", "id": "org:1"}, {"name": "The Ledger",
				"line": Media._vec(PolDefs.OCC_IDEOLOGY["BUSINESS_OWNER"])})
		var t0 := Time.get_ticks_usec()
		var w: WorldState = sim.world
		# time a re-run of the reader pass only (the edition already ran in JUSTICE)
		Media._readers(w)
		media_us += Time.get_ticks_usec() - t0
		if (m + 1) % 12 == 0:
			var groups := PolVoters.all(w)
			var with_diet := 0
			var blame_sum := 0.0
			var pop := 0.0
			for c in groups:
				if not c.get("diet", {}).is_empty():
					with_diet += 1
				blame_sum += float(c.get("news_blame", 0)) * float(c.get("pop", 0))
				pop += float(c.get("pop", 0))
			for o in MediaQuery.outlets(w):
				var ed := MediaQuery.edition(w, o["id"], w.month - 1)
				print("Y%d %s %s circ %d cred %d stories %d" % [w.month / 12, o["id"], o["name"], o["circulation"], o["cred"],
					ed.get("stories", []).size()])
				for s in ed.get("stories", []).slice(0, 3):
					var f: Dictionary = w.facts.get_fact(String(s["fact"]))
					print("    #%d %s mag %d angle %s" % [s["rank"], f.get("type", "?"), int(f.get("magnitude", 0)), s["angle"]])
			print("  groups %d with diet %d mean news_blame %.1f" % [groups.size(), with_diet, blame_sum / maxf(1.0, pop)])
	print("reader pass: %.2f ms/month" % (float(media_us) / 1000.0 / months))
	quit(0)

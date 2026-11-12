extends SceneTree
## O-1 A/B: integrated runs with mechanisms switched off via world.meta["off"].
## Usage: godot --headless --path . --script res://tools/ab_o1.gd -- <label> <months> <seeds> [OFF1,OFF2,...]
## Prints per seed: in-band months (unemployment 3–25%), famine, default, mean unemployment.


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var label: String = a[0] if a.size() > 0 else "base"
	var months := int(a[1]) if a.size() > 1 else 120
	var seeds := int(a[2]) if a.size() > 2 else 6
	var off: Array = []
	if a.size() > 3 and a[3] != "-":
		off = Array(a[3].split(","))
	var tot := 0
	var fam := 0
	var dfl := 0
	var first := int(a[4]) if a.size() > 4 else 1
	for sd in range(first, first + seeds):
		var sim := Simulation.new(sd)
		sim.world.meta["scenario"] = "BALANCED"
		sim.world.meta["persona"] = {}
		sim.world.meta["autoplay_player"] = true
		sim.world.meta["off"] = off
		if off.has("SUPPORT_ON"):
			sim.world.meta["support"] = true  # M12 A/B: old home-world support model
		if off.has("AUTOPILOT_ON"):  # A/B: the pre-GovBuilder setup (econ caretaker autopilot instead of GovBuilder)
			sim.register(preload("res://sim/law/law_provider.gd").new())
			sim.register(preload("res://sim/staff/staff_provider.gd").new())
			sim.register(EconAutopilot.new())
			sim.register(EconProvider.new())
			sim.register(PoliticsProvider.new())
		else:
			EconSim._register(sim)
		sim.new_game()
		var inb := 0
		var usum := 0.0
		var fam_m := -1
		var gov := {"believer_m": 0, "high_u_m": 0, "high_u_believer_m": 0, "bsum": 0.0, "n": 0, "pm": {}, "pes_m": 0, "pes_posts": 0, "pes_max": 0, "pes50_m": 0, "pes50_by": {}}
		# where the money went (crowd-out A/B): budget line spending (banked at each yearly reset), tax rates, household spend
		var fin := {"lines": {}, "last": {}, "itax": 0.0, "stax": 0.0, "hh_spend": 0.0, "pop": 0.0}
		var LINES := ["ECON_BUDGET_PUBLIC_WORKS", "ECON_BUDGET_PUBLIC_EMPLOYMENT", "ECON_BUDGET_INFRASTRUCTURE", "ECON_BUDGET_HOUSING", "ECON_BUDGET_SUBSIDIES"]
		for m in months:
			sim.step()
			var u := FirmAI.colony_unemployment(sim.world)
			var ytd: Dictionary = EconUtil.st(sim.world).get("spent_ytd", {})
			for ln in LINES:
				var v := int(ytd.get(ln, 0))
				if v < int(fin["last"].get(ln, 0)):
					fin["lines"][ln] = int(fin["lines"].get(ln, 0)) + int(fin["last"][ln])
				fin["last"][ln] = v
			fin["itax"] += float(EconUtil.lever(sim.world, "ECON_INCOME_TAX_RATE", 24))
			fin["stax"] += float(EconUtil.lever(sim.world, "ECON_SALES_TAX", 0))
			for gid in sim.world.peek("hh"):
				var g: Dictionary = sim.world.peek("hh")[gid]
				fin["hh_spend"] += float(int(g.get("spent_goods", 0)) + int(g.get("svc_spent", 0)) + int(g.get("media_spent", 0)))
			fin["pop"] += float(PopStore.total(sim.world))
			if int(EconUtil.lever(sim.world, "ECON_BUDGET_PUBLIC_EMPLOYMENT", 0)) > 0:  # E117b: months the scheme was funded, posts held
				gov["pes_m"] += 1
			var pp := EconPublicJobs.posts(sim.world)
			gov["pes_posts"] += pp
			gov["pes_max"] = maxi(int(gov["pes_max"]), pp)
			if pp > 50:  # months the scheme held 50+ posts, and who governed then
				gov["pes50_m"] += 1
				var who50 := "none"
				var pol50: Dictionary = sim.world.peek("pol")
				if pol50.has("state"):
					var a50: Dictionary = GovBuilder._actor(sim.world, pol50["state"])
					if not a50.is_empty():
						who50 = str(a50["by"])
						if sim.world.peek("party").has(who50):
							who50 = str(sim.world.peek("party")[who50].get("name", who50))
				gov["pes50_by"][who50] = int(gov["pes50_by"].get(who50, 0)) + 1
			# who governed: GovBuilder's public-works test is ECON_ROLE + FISCAL > -0.2 (interventionist + spending)
			var pol: Dictionary = sim.world.peek("pol")
			if pol.has("state"):
				var who: Dictionary = GovBuilder._actor(sim.world, pol["state"])
				if not who.is_empty():
					var pos: Dictionary = who["pos"]
					var b := (float(pos.get("ECON_ROLE", 0)) + float(pos.get("FISCAL", 0))) / 100000.0
					gov["bsum"] += b
					gov["n"] += 1
					var pm := str(who["by"])
					gov["pm"][pm] = int(gov["pm"].get(pm, 0)) + 1
					if b > -0.2:
						gov["believer_m"] += 1
					if u > 0.12:
						gov["high_u_m"] += 1
						if b > -0.2:
							gov["high_u_believer_m"] += 1
					var side := "market" if b < -0.2 else "other"  # scheme funding by PM ideology (market: ECON_ROLE + FISCAL < -0.2)
					var sp: Dictionary = gov.get("pes_side", {})
					var row: Array = sp.get(side, [0, 0, 0])  # [governed months, funded months, months with 50+ posts]
					row[0] += 1
					if int(EconUtil.lever(sim.world, "ECON_BUDGET_PUBLIC_EMPLOYMENT", 0)) > 0:
						row[1] += 1
					if EconPublicJobs.posts(sim.world) > 50:
						row[2] += 1
					sp[side] = row
					gov["pes_side"] = sp
			usum += u
			if u >= 0.03 and u <= 0.25:
				inb += 1
			if fam_m < 0 and EconUtil.st(sim.world)["famine"]:
				fam_m = sim.world.month
			if months > 240 and (m + 1) % 120 == 0:
				var s0 := EconUtil.st(sim.world)
				print("%s seed %d y%d pop %d u %.1f%% food_short %d E %d/%d famine_m %d" % [label, sd, (m + 1) / 12, PopStore.total(sim.world), 100.0 * u, s0["food_shortfall"],
					s0["util_supply"]["E"] / 1000, s0["util_demand"]["E"] / 1000, fam_m])
		var s := EconUtil.st(sim.world)
		tot += inb
		fam += 1 if s["famine"] else 0
		dfl += 1 if s["sovereign_default"] else 0
		print("%s seed %d in_band %d famine %s default %s mean_u %.1f%%" % [label, sd, inb, str(s["famine"]), str(s["sovereign_default"]), 100.0 * usum / months])
		var pm_rows: Array = []
		for k in gov["pm"]:
			var nm: String = str(k)
			if sim.world.peek("party").has(k):
				nm = "%s(%s)" % [k, str(sim.world.peek("party")[k].get("name", k))]
			pm_rows.append([int(gov["pm"][k]), nm])
		pm_rows.sort_custom(func(a, b): return a[0] > b[0])
		print("%s seed %d gov: public-works-minded %d/%d months, mean ECON_ROLE+FISCAL %.2f; high-u months %d, of which a believer governed %d; PM months %s; public jobs scheme funded %d months, mean posts %.0f, max %d; 50+ posts in %d months, by PM %s; by ideology [governed, funded, 50+] %s" % [label, sd,
			gov["believer_m"], gov["n"], gov["bsum"] / maxf(1.0, float(gov["n"])), gov["high_u_m"], gov["high_u_believer_m"], str(pm_rows.slice(0, 4)), gov["pes_m"], float(gov["pes_posts"]) / float(months), gov["pes_max"], gov["pes50_m"], str(gov["pes50_by"]), str(gov.get("pes_side", {}))])
		for ln2 in LINES:
			fin["lines"][ln2] = int(fin["lines"].get(ln2, 0)) + int(fin["last"].get(ln2, 0))  # the unfinished last year
		var yrs := float(months) / 12.0
		var lrows: Array = []
		for ln3 in LINES:
			lrows.append("%s %.0f" % [str(ln3).replace("ECON_BUDGET_", ""), float(fin["lines"].get(ln3, 0)) / 1000.0 / yrs])
		print("%s seed %d money: spend per year (credits) %s; mean income tax %.1f%% sales tax %.1f%%; household spend per person-month %.1f" % [label, sd,
			", ".join(lrows), fin["itax"] / float(months), fin["stax"] / float(months), fin["hh_spend"] / 1000.0 / maxf(1.0, fin["pop"])])
	print("%s TOTAL in_band %d famine %d default %d" % [label, tot, fam, dfl])
	quit()

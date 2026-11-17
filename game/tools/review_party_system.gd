extends SceneTree
## Diagnostics for the outside review of the v4 chronicles (owner Ella): faction axes and splits,
## repeat single-issue foundings, and who gets scandals relative to donations.
##   godot --headless --path game --script res://tools/review_party_system.gd -- <months> <seed>
const EconSim := preload("res://sim/economy/econ_sim.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var months := int(args[0]) if args.size() > 0 else 1200
	var seed_v := int(args[1]) if args.size() > 1 else 1
	var sim: Simulation = EconSim.make(seed_v, "BALANCED", {}, true)
	var w := sim.world
	var axis_years := {}
	var score_sum := {}
	var score_n := 0
	var active_months := {}
	var seen_founded := 0
	for _m in months:
		sim.step()
		for p in PartyLife.active(w):
			active_months[p["name"]] = int(active_months.get(p["name"], 0)) + 1
		var fd: Array = w.facts.query("POL_PARTY_FOUNDED")
		for i in range(seen_founded, fd.size()):
			var d: Dictionary = fd[i]["data"]
			if String(d.get("kind", "")) != "SINGLE_ISSUE":
				continue
			var c: String = d["concern"]
			var own := ""
			for q in PartyLife.active(w):
				if q["id"] != d["party"] and int(q["ownership"].get(c, 0)) > 0:
					own += "%s(%s)=%d%s " % [q["name"], q.get("kind", ""), int(q["ownership"][c]), "*" if q["is_player"] else ""]
			var prior := ""
			for f in fd.slice(0, i):
				if String(f["data"].get("concern", "")) == c:
					var pp: Dictionary = w.peek("party").get(f["data"]["party"], {})
					prior += "%s[m%d %s own=%d] " % [pp.get("name", "?"), int(f["month"]), pp.get("status", "?"), int(pp.get("ownership", {}).get(c, 0))]
			print("SINGLE m%d Y%d %s sat=%d  others owning: %s  prior same-issue: %s" % [w.month, w.month / 12, c, PartyLife._colony_sat(w, c), own, prior])
		seen_founded = fd.size()
		if w.month_of_year() == 1 and w.month > PolDefs.PARTY_FORMATION_MONTH:
			for p in PartyLife.active(w):
				axis_years[p["faction_axis"]] = int(axis_years.get(p["faction_axis"], 0)) + 1
				var fs := PartyLife.faction_axis_scores(w, p)
				var tot := 0.0
				for ax in fs["scores"]:
					tot += float(fs["scores"][ax])
				for ax in fs["scores"]:
					score_sum[ax] = float(score_sum.get(ax, 0.0)) + float(fs["scores"][ax]) / maxf(0.001, tot)
				score_n += 1
	print("\n== seed %d, %d months" % [seed_v, months])
	print("faction axis, party-years: %s" % axis_years)
	var avg := {}
	for ax in score_sum:
		avg[ax] = snappedf(float(score_sum[ax]) / maxf(1, score_n), 0.001)
	print("mean normalised axis score: %s" % avg)
	var splits := {}
	for f in w.facts.query("POL_PARTY_SPLIT"):
		splits[f["data"]["axis"]] = int(splits.get(f["data"]["axis"], 0)) + 1
	print("splits by axis: %s" % splits)
	var motions := {}
	for f in w.facts.query("POL_CONGRESS_MOTION"):
		var ax := String(f["data"].get("axis", "?"))
		motions[ax] = int(motions.get(ax, 0)) + 1
	print("congress motions by axis: %s" % motions)
	# scandals vs donations
	var rows := {}
	var pname := func(pid: String) -> String: return String(w.peek("party").get(pid, {}).get("name", pid))
	for f in w.facts.query("POL_DONATION"):
		var n: String = pname.call(String(f["data"].get("party", "")))
		var r: Dictionary = rows.get(n, {"don": 0, "amt": 0, "secret": 0, "illegal": 0, "scandal": 0, "chan": {}})
		r["don"] += 1
		r["amt"] += int(f["data"].get("amount", 0)) / 1000
		r["secret"] += 1 if f["visibility"] == "SECRET" else 0
		rows[n] = r
	for t in w.peek("donation_track").values():
		var n: String = pname.call(String(t["party"]))
		var r: Dictionary = rows.get(n, {"don": 0, "amt": 0, "secret": 0, "illegal": 0, "scandal": 0, "chan": {}})
		r["illegal"] += 1
		rows[n] = r
	for f in w.facts.query("POL_SCANDAL_REVEALED"):
		var n: String = pname.call(String(f["data"].get("party", "")))
		var r: Dictionary = rows.get(n, {"don": 0, "amt": 0, "secret": 0, "illegal": 0, "scandal": 0, "chan": {}})
		r["scandal"] += 1
		var ch := String(f["data"].get("channel", "?"))
		r["chan"][ch] = int(r["chan"].get(ch, 0)) + 1
		rows[n] = r
	var names := rows.keys()
	names.sort()
	print("party | months active | donations (secret) | amount | illegal tracked | scandals {channel}")
	for n in names:
		var r: Dictionary = rows[n]
		print("  %-28s %4d  %4d (%3d)  %8d  %3d  %2d %s" % [n, int(active_months.get(n, 0)), r["don"], r["secret"], r["amt"], r["illegal"], r["scandal"], r["chan"]])
	quit(0)

extends SceneTree
## Does a press scandal draw fire? (owner Ella; Wilma/Anni review: 1 of 4 press-hit parties drew an attack ad in 24
## months.) Per scandal episode (a party's first POL_SCANDAL_REVEALED after 24 quiet months): was there a
## POL_ATTACK_AD at that party within 24 months, and was a campaign even running in that window?
##   godot --headless --path game --script res://tools/measure_scandal_fire.gd -- <months> <seed> [off,list] [on,list]
## A/B: off = SCANDAL_FIRE (no scandal targeting at all) or SCANDAL_FIRE_V2 (no floor, tone push or named line).
const EconSim := preload("res://sim/economy/econ_sim.gd")
const WIN := 24


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var months := int(args[0]) if args.size() > 0 else 1200
	var seed_v := int(args[1]) if args.size() > 1 else 1
	var off: Array = Array(args[2].split(",", false)) if args.size() > 2 else []
	var sim: Simulation = EconFace.sim_make(seed_v, "BALANCED", {}, true)
	sim.world.meta["off"] = off
	if args.size() > 3:   # extra opt-in systems on top of the full game's defaults (EconSim.DEFAULT_ON)
		var on: Array = sim.world.meta.get("on", []).duplicate()
		for k in args[3].split(",", false):
			if not on.has(k):
				on.append(k)
		sim.world.meta["on"] = on
	sim.run(months)
	var w := sim.world
	var elections: Array = w.facts.query("POL_ELECTION_HELD").map(func(f): return int(f["month"]))
	var ads: Array = w.facts.query("POL_ATTACK_AD")
	var neg: Array = w.facts.query("POL_CAMPAIGN_GOES_NEGATIVE")
	var last := {}
	var eps: Array = []
	for f in w.facts.query("POL_SCANDAL_REVEALED"):
		var pid := String(f["data"].get("party", ""))
		var m := int(f["month"])
		if pid != "" and (not last.has(pid) or m - int(last[pid]) > WIN):
			eps.append({"party": pid, "month": m, "channel": String(f["data"].get("channel", "")), "kind": String(f["data"].get("kind", "DONATION"))})
		last[pid] = m
	var n := {"all": 0, "press": 0}
	var hit := {"all": 0, "press": 0}
	var camp := {"all": 0, "press": 0}
	var camp_hit := {"all": 0, "press": 0}
	var rows := PackedStringArray()
	for e in eps:
		var m := int(e["month"])
		var in_camp := elections.any(func(x): return int(x) >= m and int(x) - 12 <= m + WIN)
		var attacked := ads.filter(func(a): return String(a["data"].get("target", "")) == e["party"] and int(a["month"]) >= m and int(a["month"]) <= m + WIN)
		var negs := neg.filter(func(a): return String(a["data"].get("target", "")) == e["party"] and int(a["month"]) >= m and int(a["month"]) <= m + WIN)
		for k in ["all", "press"]:
			if k == "press" and e["channel"] != "PRESS":
				continue
			n[k] += 1
			if not attacked.is_empty():
				hit[k] += 1
			if in_camp:
				camp[k] += 1
				if not attacked.is_empty():
					camp_hit[k] += 1
		rows.append("    Y%d %s %s/%s campaign=%s ads=%d negative=%d" % [m / 12, e["party"], e["kind"], e["channel"], str(in_camp), attacked.size(), negs.size()])
	var to_hit := 0
	for a in ads:
		var t := String(a["data"].get("target", ""))
		var am := int(a["month"])
		if eps.any(func(e): return e["party"] == t and am >= int(e["month"]) and am <= int(e["month"]) + WIN):
			to_hit += 1
	var recalls := ads.filter(func(a): return not a["data"].get("recalls", {}).is_empty()).size()
	print("== seed %d off=%s, %d months; %d attack ads (%d name an old scandal) (%d at a party within 24 months of its scandal), %d elections" % [seed_v, str(off), months, ads.size(), recalls, to_hit, elections.size()])
	for k in ["all", "press"]:
		print("  %-5s scandal episodes %d: attacked within 24m %d; with a campaign in the window %d, attacked %d" % [k, n[k], hit[k], camp[k], camp_hit[k]])
	# revivals (Anni's press, opt-in SCANDAL_REVIVAL): attacked within 24 months of the flare-up?
	var revs: Array = w.facts.query("MEDIA_SCANDAL_REVIVED")
	var rhit := 0
	var rcamp := 0
	var trig := {}
	for f in revs:
		var m := int(f["month"])
		var pid := String(f["data"].get("party", ""))
		var tg := String(f["data"].get("trigger", ""))
		trig[tg] = int(trig.get(tg, 0)) + 1
		if elections.any(func(x): return int(x) >= m and int(x) - 12 <= m + WIN):
			rcamp += 1
		if ads.any(func(a): return String(a["data"].get("target", "")) == pid and int(a["month"]) >= m and int(a["month"]) <= m + WIN):
			rhit += 1
	print("  revivals %d (buried %d, escalated %d): attacked within 24m %d; with a campaign in the window %d; triggers %s" % [revs.size(),
		w.facts.query("MEDIA_SCANDAL_BURIED").size(), revs.filter(func(f): return bool(f["data"].get("escalated", false))).size(), rhit, rcamp, str(trig)])
	print("\n".join(rows))
	quit()

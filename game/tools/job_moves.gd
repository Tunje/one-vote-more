extends SceneTree
## Where the staff come from. Per year: persons hired from the jobless and persons who moved from another job, by the
## type of company left and joined, with the raise each move gave (per cent over the old pay) and the bar it had to clear.
## usage: godot --headless --path game --script res://tools/job_moves.gd -- [months=60] [seed=1]

const Company := preload("res://sim/economy/company.gd")
const Households := preload("res://sim/population/households.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var months := int(args[0]) if args.size() > 0 else 60
	var seed_v := int(args[1]) if args.size() > 1 else 1
	var sim := GameSim.make(seed_v)
	var w := sim.world
	var outside := {}   # year -> type -> persons hired from the jobless
	var moves := {}     # year -> "FROM > TO" -> [persons, sum of raise pct * persons, min raise pct, max raise pct, sum bar pm * persons]
	var jobless := {}   # year -> sum over months of jobless persons
	for m in months:
		var ran := w.month
		var y := ran / 12 + 1
		sim.step()
		var j := 0
		for pid in Households.pools(w):
			j += Households.persons(w, pid, "UNEMPLOYED")
		jobless[y] = int(jobless.get(y, 0)) + j
		for r in Logbook.rows(w, {"kind": "HIRE", "from": ran, "to": ran}):
			if (r["change"] as Dictionary).has("staff") and String(r["what"]).begins_with("hired"):
				var t := Company.type_of(w, String(r["who"]))
				if not outside.has(y):
					outside[y] = {}
				outside[y][t] = int(outside[y].get(t, 0)) + int(r["change"]["staff"][1])
		for r in Logbook.rows(w, {"kind": "JOB", "from": ran, "to": ran}):
			if not (r["change"] as Dictionary).has("staff"):
				continue
			var k := int(r["change"]["staff"][1])
			var why: Dictionary = r["why"]
			var key := "%s > %s" % [Company.type_of(w, String(why["from"])), Company.type_of(w, String(r["who"]))]
			var old := int(why["old_pay"])
			var pct := ((int(why["new_pay"]) - old) * 100 / old) if old > 0 else 0
			if not moves.has(y):
				moves[y] = {}
			var e: Array = moves[y].get(key, [0, 0, 100000, -100000, 0])
			e[0] += k
			e[1] += pct * k
			e[2] = mini(int(e[2]), pct)
			e[3] = maxi(int(e[3]), pct)
			e[4] += int(why.get("bar_pm", 0)) * k
			moves[y][key] = e
	print("WHERE THE STAFF COME FROM  (seed %d, %d months; persons)" % [seed_v, months])
	for y in range(1, (months + 11) / 12 + 1):
		print("\nYEAR %d   jobless on average: %d" % [y, int(jobless.get(y, 0)) / 12])
		var o: Dictionary = outside.get(y, {})
		var ts: Array = o.keys()
		ts.sort()
		var parts: Array = []
		for t in ts:
			parts.append("%s %d" % [t, int(o[t])])
		print("  hired from the jobless: %s" % (", ".join(parts) if not parts.is_empty() else "none"))
		var mv: Dictionary = moves.get(y, {})
		var ks: Array = mv.keys()
		ks.sort()
		for key in ks:
			var e: Array = mv[key]
			print("  moved %-22s %4d persons, raise avg %d%% (least %d%%, most %d%%), bar avg %d per mille" % [key, int(e[0]),
				int(e[1]) / int(e[0]), int(e[2]), int(e[3]), int(e[4]) / int(e[0])])
	quit()

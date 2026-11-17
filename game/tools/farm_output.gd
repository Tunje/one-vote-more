extends SceneTree
## Are the farms making all they can? For chosen months: every farm's making row from the log, summed and averaged:
## what a farm makes at full use, and what cut it down (its output level under rules 3 and 4, how many of its posts
## are filled and trained, the plant's condition, the season's yield).
## usage: godot --headless --path game --script res://tools/farm_output.gd -- [months=36] [seed=1]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var months := int(args[0]) if args.size() > 0 else 36
	var seed_v := int(args[1]) if args.size() > 1 else 1
	var sim := GameSim.make(seed_v)
	var w := sim.world
	print("month | farms making | full use in all | made | made %% of full | avg level (rules 3,4) | avg posts filled and trained | avg condition | other keys of the row (first farm)")
	for m in months:
		sim.step()
		var rows: Array = Logbook.rows(w, {"kind": "MAKE", "what": "made FOOD", "from": w.month - 1, "to": w.month - 1})
		if rows.is_empty():
			continue
		var full := 0
		var made := 0
		var level := 0
		var staffed := 0
		var cond := 0
		for r in rows:
			var why: Dictionary = r["why"]
			full += int(why.get("full", 0))
			level += int(why.get("level_pm", 0))
			staffed += int(why.get("staffed_pm", 0))
			cond += int(why.get("condition_pm", 0))
			var ch: Dictionary = r["change"]
			for k in ch:
				if typeof(ch[k]) == TYPE_ARRAY and (ch[k] as Array).size() == 2 and String(k).contains("FOOD") or String(k) in ["made", "out", "stock"]:
					made += int(ch[k][1]) - int(ch[k][0])
					break
		var n := rows.size()
		var extra := {}
		for k in rows[0]["why"]:
			if not k in ["full", "level_pm", "staffed_pm", "condition_pm"]:
				extra[k] = rows[0]["why"][k]
		print("%5d | %3d | %7d | %7d | %3d%% | %4d | %4d | %4d | %s  change %s" % [w.month - 1, n, full / 1000, made / 1000,
			(made * 100 / full) if full > 0 else 0, level / n, staffed / n, cond / n, str(extra), str(rows[0]["change"]).left(80)])
	quit()

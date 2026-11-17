extends SceneTree
## Every effective lever change in an integrated run, with fiscal state and unemployment at the time.
##   godot --headless --path game --script res://tools/debug_lever_log.gd -- [seed] [months]
const EconSim := preload("res://sim/economy/econ_sim.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_v := int(args[0]) if args.size() > 0 else 1
	var months := int(args[1]) if args.size() > 1 else 96
	var sim: Simulation = EconSim.make(seed_v, "BALANCED", {}, true)
	var w := sim.world
	var seen := {}
	for _m in months:
		sim.step()
		var st: Dictionary = w.peek("pol")["state"]
		for e in w.peek("enactment").values():
			if e["status"] == "EFFECTIVE" and not seen.has(e["id"]):
				seen[e["id"]] = true
				var u := 0.0
				var n := 0.0
				for d in EconData.DISTRICTS:
					u += w.indicators.read("ECON_UNEMPLOYMENT_RATE", d) / 1000.0 * EconData.DISTRICTS[d]["pop"]
					n += EconData.DISTRICTS[d]["pop"]
				var gov: String = "commander" if st["era"] == "FOUNDING" else ",".join(st["government"].get("members", []).map(func(p): return w.peek("party")[p]["name"].get_slice(" ", 0)))
				print("m%3d %-28s %s -> %s | %s | stress %.2f room %.2f crisis %s | u %.0f%%" % [w.month, String(e["lever"]).trim_prefix("ECON_"), e.get("from", "?"), e["value"], gov,
					Legislature.fiscal_stress(w), Legislature.fiscal_room(w), st.get("crisis", false), u / n])
	quit(0)

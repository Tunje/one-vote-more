extends SceneTree
## Food-chain trace (century gate): every 6 months from month a to b, farms (count, running, mothballed, unsafe,
## condition, staff fill, output), food market (price vs base and unit cost, fill, E102 signal, FARM projects),
## population, births and migrants. Usage: godot --headless --path . --script res://tools/debug_food.gd -- [seed] [from_m] [to_m] [step]


const S := 1000


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sd := int(a[0]) if a.size() > 0 else 1
	var m0 := int(a[1]) if a.size() > 1 else 60
	var m1 := int(a[2]) if a.size() > 2 else 240
	var step := int(a[3]) if a.size() > 3 else 6
	var sim := Simulation.new(sd)
	sim.world.meta["scenario"] = "BALANCED"
	sim.world.meta["persona"] = {}
	sim.world.meta["autoplay_player"] = true
	sim.world.meta["off"] = []
	EconSim._register(sim)
	sim.new_game()
	var w := sim.world
	print("m    pop  short  farms run/mb/uns  cond  staff%  out   cap   pF/base  ucost  fill  sigQ lastFARM proj  owners")
	for m in m1:
		sim.step()
		if w.month < m0 or w.month % step != 0:
			continue
		var s := EconUtil.st(w)
		var n := 0
		var run := 0
		var mb := 0
		var uns := 0
		var cond := 0.0
		var need := 0
		var have := 0
		var out := 0
		var cap := 0
		var owners := {}
		for fid in w.table("facility"):
			var f: Dictionary = w.table("facility")[fid]
			if f["type"] != "FARM":
				continue
			n += 1
			owners[w.table("org").get(f["org"], {}).get("key", f["org"])] = true
			if f["mothball"]:
				mb += 1
			if f.get("closed_unsafe", false):
				uns += 1
			if not f["mothball"] and f["util"] > 0:
				run += 1
			cond += float(f["condition"])
			out += int(f["out_last"])
			cap += int(EconData.RECIPES["FARM"]["out"][1]) * S
			for tier in EconData.RECIPES["FARM"]["labor"]:
				need += int(EconData.RECIPES["FARM"]["labor"][tier])
			for k in f["staff"]:
				for kk in f["staff"][k]:
					have += int(f["staff"][k][kk])
		var proj := 0
		for pid in w.table("project"):
			var p: Dictionary = w.table("project")[pid]
			if p["type"] == "FARM" and p["status"] in ["TENDER", "TENDERABLE", "ACTIVE"]:
				proj += 1
		print("%3d %5d %4d   %2d %2d/%d/%d  %5.0f  %4.0f  %5d %5d  %5.2f/%4.2f %5.2f  %4d  %d  %4d  %d  %s" % [w.month, PopStore.total(w), s["food_shortfall"], n, run, mb, uns,
			cond / maxf(1, n), 100.0 * have / maxf(1, need), out / S, cap / S, float(s["prices"]["FOOD"]) / S, float(s["base"]["FOOD"]) / S,
			FirmAI.unit_cost(w, "FARM") / S / float(EconData.RECIPES["FARM"]["out"][1]), int(s.get("fill_last", {}).get("FOOD", -1)),
			int(s.get("scarce_q", {}).get("FOOD", 0)), int(s.get("new_plant_last", {}).get("FARM", -1)), proj, ",".join(owners.keys())])
	quit()

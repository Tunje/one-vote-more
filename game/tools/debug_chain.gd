extends SceneTree
## Production-chain trace (century gate): every `step` months, per plant type: count/running/mothballed/unsafe,
## staff fill %, mean condition, output vs nameplate; then market fill and price/base per good.
## Usage: godot --headless --path . --script res://tools/debug_chain.gd -- [seed] [months] [step]

const S := 1000
const TYPES := ["MINE", "PROCESSING", "COMPONENTS", "FARM", "POWER", "WATERWORKS", "CONSUMERF", "MEDWORKS", "DEPOT"]


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sd := int(a[0]) if a.size() > 0 else 1
	var months := int(a[1]) if a.size() > 1 else 240
	var step := int(a[2]) if a.size() > 2 else 12
	var sim := Simulation.new(sd)
	sim.world.meta["scenario"] = "BALANCED"
	sim.world.meta["persona"] = {}
	sim.world.meta["autoplay_player"] = true
	sim.world.meta["off"] = []
	EconSim._register(sim)
	sim.new_game()
	var w := sim.world
	for m in months:
		sim.step()
		if w.month % step != 0:
			continue
		var s := EconUtil.st(w)
		var parts: Array = []
		for t in TYPES:
			var n := 0
			var run := 0
			var mb := 0
			var need := 0
			var have := 0
			var cond := 0.0
			var out := 0
			var cap := 0
			for fid in w.table("facility"):
				var f: Dictionary = w.table("facility")[fid]
				if f["type"] != t:
					continue
				n += 1
				mb += 1 if f["mothball"] or f.get("closed_unsafe", false) else 0
				run += 1 if not f["mothball"] and int(f["util"]) > 0 else 0
				cond += float(f["condition"]) / 1000.0
				out += int(f["out_last"])
				cap += int(EconData.RECIPES[t]["out"][1]) * S
				for tier in EconData.RECIPES[t]["labor"]:
					need += int(EconData.RECIPES[t]["labor"][tier])
				for k in f["staff"]:
					for kk in f["staff"][k]:
						have += int(f["staff"][k][kk])
			parts.append("%s %d/%d/%d st%d c%d o%d%%" % [t.substr(0, 4), n, run, mb, int(100.0 * have / maxf(1, need)), int(cond / maxf(1, n)),
				int(100.0 * out / maxf(1, cap))])
		var mk: Array = []
		for g in ["FOOD", "MINERAL", "MATERIAL", "COMPONENT", "CONSUMER", "MEDICAL"]:
			if s["prices"].has(g):
				mk.append("%s f%d p%.1f" % [g.substr(0, 4), int(s.get("fill_last", {}).get(g, -1)), float(s["prices"][g]) / maxf(1.0, float(s["base"].get(g, 1)))])
		var proj := 0
		for pid in w.table("project"):
			if w.table("project")[pid]["status"] in ["ACTIVE", "TENDER", "TENDERABLE"]:
				proj += 1
		print("m%d pop %d short %d u %.0f%% proj %d | %s" % [w.month, PopStore.total(w), s["food_shortfall"], 100.0 * FirmAI.colony_unemployment(w), proj, " ".join(mk)])
		print("    ", " | ".join(parts))
	quit()

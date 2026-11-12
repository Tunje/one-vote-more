extends SceneTree
## Unemployment trace: every `step` months, unemployed and vacancies by skill, labour_fill per plant type,
## required posts by tier (plants + builder crews), essentials margins.
## Usage: godot --headless --path . --script res://tools/debug_unemp.gd -- [seed] [months] [step]

const S := 1000


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sd := int(a[0]) if a.size() > 0 else 1
	var months := int(a[1]) if a.size() > 1 else 480
	var step := int(a[2]) if a.size() > 2 else 24
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
		var un := {}
		var em := {}
		for t in ["G", "S", "Sp"]:
			un[t] = PopStore.count(w, {"status": "UNEMPLOYED"}, "skill:" + t)
			em[t] = PopStore.count(w, {"status": "EMPLOYED"}, "skill:" + t)
		var vac := EconTraining.vacancies(w)
		var req := {"G": 0, "S": 0, "Sp": 0}
		var nf := 0
		var nmb := 0
		for fid in w.table("facility"):
			var f: Dictionary = w.table("facility")[fid]
			nf += 1
			if f["mothball"]:
				nmb += 1
			var r := EconLabor.required(f)
			for t in r:
				req[t] = int(req[t]) + int(r[t]) / S
		var lf := []
		for ft in ["FARM", "PROCESSING", "COMPONENTS", "POWER", "CONSUMERF"]:
			if EconData.RECIPES.has(ft):
				lf.append("%s %.2f" % [ft.substr(0, 4), EconEssentials.labour_fill(w, ft)])
		var ess := EconEssentials.measure(w)
		var mg := []
		for g in ess:
			mg.append("%s %+d" % [g.substr(0, 3), int(ess[g]["margin_pct"])])
		var orgs := 0
		for oid in w.table("org"):
			if w.table("org")[oid]["status"] == "ACTIVE":
				orgs += 1
		print("m%d unemp %s emp %s vac %s req %s fac %d mb %d orgs %d | fill %s | %s | train %s" % [w.month, un, em, vac, req,
			nf, nmb, orgs, ", ".join(lf), ", ".join(mg), EconUtil.st(w).get("train_last", {})])
	quit()

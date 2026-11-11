extends SceneTree
## a9 balance probe: approval dynamics and concern satisfaction across the politics soak scenarios.
##   godot --headless --path game --script res://tools/measure_law_indicators.gd
const PERSONAS := {
	"LEFT": {"REDISTRIBUTION": 70, "LABOR": 60, "ENVIRONMENT": 40, "ECON_ROLE": 50, "FISCAL": 40},
	"RIGHT": {"REDISTRIBUTION": -70, "LABOR": -60, "ENVIRONMENT": -30, "ECON_ROLE": -60, "FISCAL": -50},
	"GREEN": {"ENVIRONMENT": 90, "AUTONOMY": 40},
}

func _initialize() -> void:
	var tot_std := 0.0
	var tot_changes := 0
	var sat_sum := {"GOVERNANCE": 0.0, "FAIRNESS": 0.0, "SAFETY": 0.0}
	var sat_sd := {"GOVERNANCE": 0.0, "FAIRNESS": 0.0, "SAFETY": 0.0}
	var runs := 0
	for scenario in ["BALANCED", "RECESSION", "POLLUTION"]:
		for pname in PERSONAS:
			for seed_value in [1, 2]:
				var sim := PoliticalSim.make(seed_value, scenario, PERSONAS[pname])
				var appr: Array = []
				var sats := {"GOVERNANCE": [], "FAIRNESS": [], "SAFETY": []}
				var last_pm := ""
				var changes := 0
				for m in 240:
					sim.step()
					appr.append(float(sim.world.indicators.read("POL_GOV_APPROVAL")) / 1000.0)
					var g: Dictionary = sim.world.table("pol")["state"].get("government", {})
					if g.get("pm_party", "") != last_pm and last_pm != "":
						changes += 1
					last_pm = g.get("pm_party", last_pm)
					for c in sats:
						var s := 0.0
						var n := 0
						for cell in sim.world.table("cell").values():
							if cell["pop"] > 0:
								s += float(cell["sat"][c]) / 1000.0
								n += 1
						sats[c].append(s / maxf(1.0, float(n)))
				var mean := 0.0
				for a in appr: mean += a
				mean /= appr.size()
				var v := 0.0
				for a in appr: v += (a - mean) * (a - mean)
				tot_std += sqrt(v / appr.size())
				tot_changes += changes
				for c in sats:
					var mu := 0.0
					for x in sats[c]: mu += x
					mu /= sats[c].size()
					var vv := 0.0
					for x in sats[c]: vv += (x - mu) * (x - mu)
					sat_sum[c] += mu
					sat_sd[c] += sqrt(vv / sats[c].size())
				runs += 1
	print("RUNS %d | approval std avg %.2f | PM changes total %d" % [runs, tot_std / runs, tot_changes])
	for c in sat_sum:
		print("SAT %s mean %.1f  std %.2f" % [c, sat_sum[c] / runs, sat_sd[c] / runs])
	quit(0)

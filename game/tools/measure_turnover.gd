extends SceneTree
## Political health metrics over many 20-year runs: changes of PM party, defeated bills, approval spread,
## and the player's party's best/worst result.
##   godot --headless --path game --script res://tools/measure_turnover.gd

const PERSONAS := {
	"LEFT": {"REDISTRIBUTION": 70, "LABOR": 60, "ENVIRONMENT": 40, "ECON_ROLE": 50, "FISCAL": 40},
	"RIGHT": {"REDISTRIBUTION": -70, "LABOR": -60, "ENVIRONMENT": -30, "ECON_ROLE": -60, "FISCAL": -50},
}


func _initialize() -> void:
	var tot_changes := 0
	var runs := 0
	var runs_with_change := 0
	var tot_def := 0
	var tot_bills := 0
	var crisis := {"POL_NO_CONFIDENCE_PASSED": 0, "POL_NO_CONFIDENCE_FAILED": 0, "POL_PARTNER_LEFT": 0, "POL_PM_VOTE_FAILED": 0, "POL_FORMATION_FAILED": 0}
	for scenario in ["BALANCED", "RECESSION", "POLLUTION", "BOOM"]:
		for pname in PERSONAS:
			for seed_v in [1, 2]:
				var sim := PoliticalSim.make(seed_v, scenario, PERSONAS[pname])
				var pms: Array = []
				var appr: Array = []
				var last := ""
				for _m in 240:
					sim.step()
					var g: Dictionary = sim.world.table("pol")["state"]["government"]
					var pm: String = g.get("pm_party", "")
					if pm != "" and pm != last:
						pms.append(sim.world.table("party")[pm]["name"].get_slice(" ", 0))
						last = pm
					if sim.world.month > 44:
						appr.append(sim.world.indicators.read("POL_GOV_APPROVAL") / 1000.0)
				var p := 0
				var d := 0
				for b in sim.world.table("bill").values():
					if b["status"] == "PASSED": p += 1
					elif b["status"] == "DEFEATED": d += 1
				for t in crisis:
					crisis[t] += sim.world.facts.query(t).size()
				var changes := pms.size() - 1
				tot_changes += changes
				runs += 1
				if changes > 0: runs_with_change += 1
				tot_def += d
				tot_bills += p + d
				var player_seats: Array = []
				var ppid: String = sim.world.table("pol")["state"]["player_party"]
				for eid in sim.world.table("pol")["state"]["elections"]:
					player_seats.append(sim.world.table("election")[eid]["seats"][ppid])
				print("%-9s %-5s s%d | PMs: %s | bills %d/%d defeated | approval %.0f-%.0f%% | player seats %s" % [
					scenario, pname, seed_v, " > ".join(pms), d, p + d, appr.min(), appr.max(), player_seats])
	print("\nRuns with a change of PM: %d/%d, total PM changes %d, defeated bills %d/%d" % [runs_with_change, runs, tot_changes, tot_def, tot_bills])
	print("Crisis events over all runs: ", crisis)
	quit(0)

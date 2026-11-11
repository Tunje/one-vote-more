extends SceneTree
## Prints 20 years (5 elections) of political history for each scenario and commander persona.
##   godot --headless --path game --script res://tools/soak_politics.gd

const PERSONAS := {
	"LEFT": {"REDISTRIBUTION": 70, "LABOR": 60, "ENVIRONMENT": 40, "ECON_ROLE": 50, "FISCAL": 40},
	"RIGHT": {"REDISTRIBUTION": -70, "LABOR": -60, "ENVIRONMENT": -30, "ECON_ROLE": -60, "FISCAL": -50},
	"GREEN": {"ENVIRONMENT": 90, "AUTONOMY": 40},
}


func _initialize() -> void:
	for scenario in ["BALANCED", "RECESSION", "POLLUTION"]:
		for pname in PERSONAS:
			var sim := PoliticalSim.make(1, scenario, PERSONAS[pname])
			sim.run(240)
			print("=== %s / commander %s: %d parties, violations: %s" % [scenario, pname, sim.world.table("party").size(), sim.world.meta.get("violations", "none")])
			print(PoliticalSim.summary(sim))
	quit(0)

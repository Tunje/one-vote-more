extends SceneTree
## Input-output feasibility of the colony recipes (no imports): for a population P, how many plants of each type
## are needed to meet household needs plus every plant's inputs and upkeep, and how many workers that takes vs the
## labour force. Usage: godot --headless --path . --script res://tools/io_feasibility.gd -- [pop] [eff] [disc_consumer_pc] [kit_tier]

const GOOD_PLANT := {"FOOD": "FARM", "MINERAL": "MINE", "MATERIAL": "PROCESSING", "COMPONENT": "COMPONENTS", "CONSUMER": "CONSUMERF",
	"MEDICAL": "MEDWORKS", "ENERGY": "POWER", "WATER": "WATERWORKS", "SERVICES": "SERVICEHUB", "HEALTH": "CLINIC",
	"EDUCATION": "SCHOOL", "FREIGHT": "DEPOT", "HOUSING": "HOUSING"}


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var pop := float(a[0]) if a.size() > 0 else 2000.0
	var eff := float(a[1]) if a.size() > 1 else 0.95       # condition × management efficiency
	var disc := float(a[2]) if a.size() > 2 else 0.3       # discretionary CONSUMER units per person per month
	var kit_tier := int(a[3]) if a.size() > 3 else 2
	var hh := pop / EconData.HOUSEHOLD_SIZE
	# final (household) demand per month
	var final := {"FOOD": pop * EconData.NEED["FOOD"], "WATER": pop * EconData.NEED["WATER"], "ENERGY": pop * EconData.NEED["ENERGY"],
		"CONSUMER": pop * (EconData.NEED["CONSUMER_MIN"] + disc), "HOUSING": hh, "SERVICES": pop * 0.6,
		"HEALTH": pop * 1.0, "EDUCATION": pop * 0.25, "FREIGHT": pop * 2.0}
	var fac := {}
	for it in 60:
		var dem := final.duplicate()
		for t in fac:
			var r: Dictionary = EconData.RECIPES[t]
			var mult_in := float(EconData.TIER_IN[kit_tier]) if t in EconData.KIT_TYPES else 1.0
			for g in r["in"]:
				dem[g] = float(dem.get(g, 0.0)) + float(r["in"][g]) * fac[t] * mult_in
			dem["MATERIAL"] = float(dem.get("MATERIAL", 0.0)) + float(r["upkeep"]) * fac[t]
			dem["COMPONENT"] = float(dem.get("COMPONENT", 0.0)) + float(EconData.UPKEEP_COMPONENT.get(t, 0)) * fac[t]
		var nf := {}
		for g in dem:
			if not GOOD_PLANT.has(g):
				continue
			var t: String = GOOD_PLANT[g]
			var r: Dictionary = EconData.RECIPES[t]
			var out := float(r["out"][1]) * eff * (float(EconData.TIER_OUT[kit_tier]) if t in EconData.KIT_TYPES else 1.0)
			nf[t] = float(dem[g]) / maxf(out, 0.001)
		fac = nf
	var labour := 0.0
	var rows: Array = []
	for t in EconUtil.sorted_keys(fac):
		var l := 0.0
		for tier in EconData.RECIPES[t]["labor"]:
			l += float(EconData.RECIPES[t]["labor"][tier])
		labour += l * fac[t]
		rows.append("%s %.1f plants (%d workers)" % [t, fac[t], int(l * fac[t])])
	var lf := pop * 1062.0 / 1999.0
	print("pop %d LF %d | plants needed:\n  %s" % [int(pop), int(lf), "\n  ".join(rows)])
	print("workers needed %d = %.0f%% of labour force (+ construction crews, admin, self-employed)" % [int(labour), 100.0 * labour / lf])
	quit()

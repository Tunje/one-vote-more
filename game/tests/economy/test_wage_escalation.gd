extends TestCase
## A building contract carries the change in wages since its award, as it carries the change in material prices (E76),
## under R8_BUILDERS: a job under way pays its crew at today's wages.


func _job(w: WorldState) -> Dictionary:
	var p := {"wu_total": 450 * EconUtil.S, "mat_total": 0, "comp_total": 0}
	var st := EconUtil.st(w)
	p["esc_mat_price"] = st["prices"]["MATERIAL"]
	p["esc_comp_price"] = st["prices"]["COMPONENT"]
	p["esc_mat_cost"] = 0
	p["esc_comp_cost"] = 0
	return p


func test_wages_since_the_award_are_paid_on_the_work_done() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["R8", "R8_BUILDERS"]
	sim.run(2)
	var p := _job(w)
	p["esc_wage"] = EconConstruction.crew_wage(w)
	p["esc_wage_cost"] = int(450.0 * float(p["esc_wage"]))
	check_eq(EconConstruction._escalation(w, p, 0.1), 0, "wages as at the award: nothing extra")
	var st := EconUtil.st(w)
	for t in st["wage"]:
		st["wage"][t] = int(st["wage"][t]) * 3 / 2
	var up := EconConstruction._escalation(w, p, 0.1)
	var expect := int(float(p["esc_wage_cost"]) * 0.1 * 0.5)
	check(absi(up - expect) <= expect / 50 + 1, "wages up by half: a tenth of the job pays half as much again for its labour (%d against %d)" % [up, expect])
	for t in st["wage"]:
		st["wage"][t] = int(st["wage"][t]) / 3
	check(EconConstruction._escalation(w, p, 0.1) < 0, "wages down: the client pays less")


func test_without_the_switch_nothing_changes() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	sim.run(2)
	var p := _job(w)
	var st := EconUtil.st(w)
	for t in st["wage"]:
		st["wage"][t] = int(st["wage"][t]) * 2
	check_eq(EconConstruction._escalation(w, p, 0.1), 0, "a contract awarded without the switch carries no wage clause")

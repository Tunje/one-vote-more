extends TestCase
## Support economy A (EconOffice): organisations staff offices in proportion to their crews (opt-in "SUPPORT_A"),
## office wages are real payroll (jobs = people, ledger closed), a firm in liquidation gives its office up.


func _offices(w: WorldState) -> Array:
	var out: Array = []
	for fid in EconUtil.sorted_keys(w.table("facility")):
		if w.table("facility")[fid]["type"] == "OFFICE":
			out.append(fid)
	return out


func test_off_by_default() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.run(4)
	check(_offices(sim.world).is_empty(), "no offices unless SUPPORT_A is switched on")
	check_eq(EconOffice.cost_factor(sim.world, "FARM"), 1.0, "no overhead in unit costs when off")


func test_offices_are_staffed_and_paid() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.world.meta["on"] = ["SUPPORT_A"]
	sim.run(6)
	var w := sim.world
	check(not _offices(w).is_empty(), "organisations opened offices")
	var sm := EconOffice.summary(w)
	check(int(sm["posts_wanted"]) > 0, "office posts are wanted (%s)" % [sm])
	check(int(sm["posts_held"]) > 0, "office posts are filled (%s)" % [sm])
	var cpw := EconFinance.org_by_key(w, "CPW")
	var t := EconOffice.target_posts(w, cpw)
	check(t > 0, "the utility needs office staff (%d)" % t)
	check_eq(EconOffice.cost_factor(w, "POWER"), 1.0, "the split adds no cost")
	var plant := ""
	for fid in EconUtil.sorted_keys(w.table("facility")):
		var f: Dictionary = w.table("facility")[fid]
		if f["type"] == "POWER" and not f["mothball"]:
			plant = fid
			break
	if plant != "":
		var pf: Dictionary = w.table("facility")[plant]
		var full := 0
		var floor_crew := 0
		for tier in EconLabor.required_full(pf):
			full += int(EconLabor.required_full(pf)[tier])
			floor_crew += int(EconLabor.required(pf)[tier])
		check(floor_crew < full, "part of the power plant's crew works at the office (%d of %d on the floor)" % [floor_crew / 1000, full / 1000])
	check(EconPop.check(w).is_empty(), "jobs still equal people: %s" % [EconPop.check(w)])
	check_eq(w.ledger.total(), 0, "ledger closed")
	check(EconReport.goods_errors(w).is_empty(), "goods conserved: %s" % [EconReport.goods_errors(w)])


func test_liquidation_gives_up_the_office() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.world.meta["on"] = ["SUPPORT_A"]
	sim.run(4)
	var w := sim.world
	var victim := ""
	for fid in _offices(w):
		var oid: String = w.table("facility")[fid]["org"]
		if w.table("org")[oid]["type"] == "PRIVATE":
			victim = oid
			break
	check(victim != "", "a private firm has an office")
	if victim == "":
		return
	var office := EconOffice.office_of(w, victim)
	w.table("org")[victim]["status"] = "LIQUIDATION"
	sim.run(1)
	var f: Dictionary = w.table("facility")[office]
	var left := 0
	for tier in EconLabor.required(f):
		left += int(EconLabor.required(f)[tier])
	check(bool(f.get("abandoned", false)) and left == 0, "the office is given up (posts left %d)" % [left / 1000])
	check_eq(EconOffice.office_of(w, victim), "", "no live office left")
	check(EconPop.check(w).is_empty(), "jobs still equal people: %s" % [EconPop.check(w)])
	check_eq(w.ledger.total(), 0, "ledger closed")

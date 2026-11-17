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


## E143 (opt-in): an office needing less than half a person per tier has no whole post to hire — it no longer
## counts as empty (fill 0 stopped the plant); a bigger office is measured against its whole posts.
func test_e143_whole_posts() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["SUPPORT_A"]
	sim.run(4)
	var oid := ""
	for fid in _offices(w):
		var o2: String = w.table("facility")[fid]["org"]
		if w.table("org")[o2]["type"] == "PRIVATE":
			oid = o2
			break
	check(oid != "", "a private firm has an office")
	if oid == "":
		return
	var f: Dictionary = w.table("facility")[EconOffice.office_of(w, oid)]
	f["office_req"] = {"G": 452, "S": 90, "Sp": 0}
	f["staff"] = {"G": {}, "S": {}, "Sp": {}}
	check_eq(EconOffice.office_fill(w, oid), 0.0, "old rule: an unhireable 0.54-person office is empty")
	w.meta["on"] = ["SUPPORT_A", "E143"]
	check_eq(EconOffice.office_fill(w, oid), 1.0, "E143: no whole post to hire, the plant is not stopped")
	f["office_req"] = {"G": 1400, "S": 400, "Sp": 0}  # 1 whole G post (0.4 S rounds to none)
	check_eq(EconOffice.office_fill(w, oid), 0.0, "E143: one hireable post, unfilled")


## OFFICE_SOFT (the user, 2026-11-17): a plant whose office is empty loses about 15% of its output, not all of it.
func test_office_soft_an_empty_office_costs_15_pct() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.world.meta["on"] = ["SUPPORT_A"]
	sim.run(6)
	var w := sim.world
	var plant := {}
	for fid in EconUtil.sorted_keys(w.table("facility")):
		var f: Dictionary = w.table("facility")[fid]
		if int(f.get("off_share_pm", 0)) > 0 and not f["mothball"] and EconOffice.office_of(w, f["org"]) != "" and float(EconProduction._plan(w, f)["u"]) > 0.0:
			plant = f
			break
	check(not plant.is_empty(), "a running plant with its crew split to an office")
	if plant.is_empty():
		return
	var off: Dictionary = w.table("facility")[EconOffice.office_of(w, plant["org"])]
	off["staff"] = {"G": {}, "S": {}, "Sp": {}}  # the office stands empty
	check(EconOffice.office_fill(w, plant["org"]) == 0.0, "the office is empty")
	check(float(EconProduction._plan(w, plant)["u"]) == 0.0, "without the switch an empty office stops the plant")
	var u_floor := 0.0
	(w.meta["on"] as Array).append("OFFICE_SOFT")
	check(absf(EconOffice.production_factor(w, plant["org"]) - 0.85) < 0.0001, "an empty office: 15%% less (%.3f)" % EconOffice.production_factor(w, plant["org"]))
	var u_soft := float(EconProduction._plan(w, plant)["u"])
	check(u_soft > 0.0, "with OFFICE_SOFT the plant still runs (u %.3f)" % u_soft)
	off["staff"] = {"G": {"hb:d:1|G": 100000}, "S": {"hb:d:1|S": 100000}, "Sp": {"hb:d:1|Sp": 100000}}  # more than enough
	check(EconOffice.office_fill(w, plant["org"]) == 1.0, "a full office")
	check(absf(EconOffice.production_factor(w, plant["org"]) - 1.0) < 0.0001, "a full office costs nothing")
	u_floor = float(EconProduction._plan(w, plant)["u"])
	check(u_soft >= u_floor * 0.85 - 0.001 and u_soft <= u_floor + 0.001, "the empty office takes at most 15%% off (%.3f of %.3f)" % [u_soft, u_floor])

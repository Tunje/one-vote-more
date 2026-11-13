extends TestCase
const LawOps := preload("res://sim/law/law_ops.gd")
## E132 conduct pass: risky private firms cut corners for real money, report it to the law every month it lasts, stop
## when the CEO changes course; accidents carry the keys inquiries need. Opt-in ("CONDUCT").


func _greedy(w: WorldState) -> String:
	# the private firm with the most facilities, made reckless and kept "profitable" for the misconduct rule
	var best := ""
	var best_n := 0
	for oid in EconUtil.sorted_keys(w.table("org")):
		var o: Dictionary = w.table("org")[oid]
		if o["type"] != "PRIVATE" or o["is_contractor"] or o["status"] != "ACTIVE":
			continue
		var n := 0
		for fid in w.table("facility"):
			if w.table("facility")[fid]["org"] == oid:
				n += 1
		if n > best_n:
			best_n = n
			best = oid
	return best


func _active_kinds(w: WorldState, org: String) -> Dictionary:
	var out := {}
	for fid in w.table("violation_track"):
		var v: Dictionary = w.table("violation_track")[fid]
		if v["company"] == org and v["active"]:
			out[v["kind"]] = true
	return out


func test_off_by_default() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.run(6)
	check(EconUtil.st(sim.world).get("conduct", {}).is_empty(), "no conduct tracking unless CONDUCT is on")


func test_reckless_firm_cuts_corners_and_reports() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.world.meta["on"] = ["CONDUCT"]
	sim.run(3)
	var w := sim.world
	var org := _greedy(w)
	check(org != "", "a private firm exists")
	if org == "":
		return
	var o: Dictionary = w.table("org")[org]
	o["ceo"]["risk"] = 95
	o["pl_last"] = {"rev": 1000000, "wages": 1}  # profitable enough for the misconduct rule
	sim.run(1)
	o["pl_last"] = {"rev": 1000000, "wages": 1}
	sim.run(1)
	var kinds := _active_kinds(w, org)
	check(not kinds.is_empty(), "the firm's conduct is on record: %s" % [kinds.keys()])
	var flagged := false
	for fid in w.table("facility"):
		var f: Dictionary = w.table("facility")[fid]
		if f["org"] == org and (bool(f.get("c_defer", false)) or bool(f.get("c_safety", false)) or bool(f.get("c_dump", false))):
			flagged = true
	check(flagged, "at least one plant really cuts corners")
	# a new CEO stops it: the records end
	o["ceo"]["risk"] = 5
	o["status"] = "ACTIVE"
	sim.run(EconConduct.CALM_MONTHS + 1)  # hysteresis: calm for CALM_MONTHS before it stops
	check(_active_kinds(w, org).is_empty(), "a careful CEO ends the conduct: %s" % [_active_kinds(w, org).keys()])
	check(EconPop.check(w).is_empty(), "jobs still equal people: %s" % [EconPop.check(w)])
	check_eq(w.ledger.total(), 0, "ledger closed")


func test_major_accident_carries_the_cause() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.world.meta["on"] = ["CONDUCT"]
	sim.run(2)
	var w := sim.world
	var plant := ""
	for fid in EconUtil.sorted_keys(w.table("facility")):
		var f: Dictionary = w.table("facility")[fid]
		var r: Dictionary = EconData.RECIPES[f["type"]]
		if (r["hazard"] == "HIGH" or f["type"] == "MINE") and not f["mothball"]:
			plant = fid
			break
	check(plant != "", "a hazardous plant exists")
	if plant == "":
		return
	var f: Dictionary = w.table("facility")[plant]
	f["c_safety"] = true
	f["condition"] = 20 * EconUtil.S
	var tid := LawOps.record_greed(w, String(f["org"]), {"kind": "SAFETY_CORNERS", "facility": plant, "hazard_ids": [EconConduct.hazard_key(plant)], "saving": 1000})
	EconUtil.st(w)["conduct"] = {String(f["org"]) + "|SAFETY_CORNERS": tid}
	for _i in 400:
		EconConduct.major_accident(w, f)
	var found := false
	for fx in w.facts.query("COMP_WORKPLACE_ACCIDENT"):
		var d: Dictionary = fx["data"]
		if bool(d.get("crisis", false)) and d.get("facility", "") == plant:
			found = true
			check_eq(String(d.get("operator", "")), String(f["org"]), "the operator is named")
			check(d.get("cause_records", []).has(tid), "the conduct record is linked as a cause")
			check_eq(String(d.get("hazard", "")), EconConduct.hazard_key(plant), "the hazard key is on the fact")
			break
	check(found, "a run-down hazardous plant cutting corners has a major accident")

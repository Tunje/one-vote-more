extends TestCase
## 27-W follow-up (Wilma, Anni's triggers): overworked sectors give unions a STAFFING grievance; with WORKLOAD off it is
## zero (default game unchanged); a settled staffing demand binds the firm to full crews for PLEDGE_M months.


func test_no_staffing_grievance_without_workload() -> void:
	var sim := EconSim.make_econ_only(5)
	sim.run(24)
	var w := sim.world
	for u in Unions.active(w):
		for occ in u["sectors"]:
			check_eq(Unions.staffing_grievance(w, str(occ)), 0.0, "no workload data, no staffing grievance (%s)" % occ)


func test_overload_raises_staffing_grievance_and_kind() -> void:
	var sim := EconSim.make_econ_only(5)
	sim.world.meta["on"] = ["WORKLOAD"]
	sim.run(24)
	var w := sim.world
	var col: Dictionary = EconQuery.workload(w).get("colony", {})
	check(not col.is_empty(), "workload view publishes sectors")
	# force overload in one facility of a unionised sector and check the grievance follows
	var u: Dictionary = {}
	for x in Unions.active(w):
		if not x["federation"]:
			u = x
			break
	check(not u.is_empty(), "a union")
	var occ := str(u["sectors"][0])
	var hit := false
	for fid in EconUtil.sorted_keys(w.table("facility")):
		var f: Dictionary = w.table("facility")[fid]
		if f.has("stress_pm") and w.table("org").has(f["org"]) and EconLabor.occupation_of(w, f["org"], f["type"]) == occ:
			f["stress_pm"] = 1000
			hit = true
	check(hit, "a facility in the union's sector")
	var g := Unions.staffing_grievance(w, occ)
	check(g >= 1.0, "full stress in the sector is a strong grievance (%.2f)" % g)
	check_eq(UnionDisputes._kind(w, u), "STAFFING", "the demand is for more staff")


func test_settled_staffing_demand_stops_lean_crews() -> void:
	var sim := EconSim.make_econ_only(5)
	sim.world.meta["on"] = ["WORKLOAD"]
	sim.run(36)
	var w := sim.world
	var oid := ""
	for o_id in EconUtil.sorted_keys(w.table("org")):
		var o: Dictionary = w.table("org")[o_id]
		if o["type"] == "PRIVATE" and not o["is_contractor"] and o["status"] == "ACTIVE":
			oid = o_id
			break
	check(oid != "", "a private firm")
	w.table("org")[oid]["ceo"]["risk"] = 95   # reckless: would run lean
	var u: Dictionary = {}
	for x in Unions.active(w):
		if not x["federation"]:
			u = x
			break
	check(not u.is_empty(), "a union by year 3")
	if u.is_empty():
		return
	var id := w.new_id("udemand")
	var d := {"id": id, "union": u["id"], "employer": oid, "employer_name": "test", "occ": u["sectors"][0], "kind": "STAFFING",
		"size_pm": 0, "made": w.month - 1, "deadline": w.month + 2, "status": "OPEN", "answer": "", "counter_pm": 0,
		"player_answer": "", "outcome": "", "award_pm": 0, "strike_start": -1, "strike_months": 0, "persons": 0, "losses": 0,
		"unlawful": false, "reasons": [], "lockout": false, "ended": -1}
	w.table("union_demand")[id] = d
	UnionDisputes._settle(w, d, u, "ACCEPTED", 0)
	check_eq(int(w.table("org")[oid].get("staffing_pledge_m", -1)), w.month, "the firm pledged full crews")
	EconWorkload.monthly(w)
	for fid in w.table("facility"):
		var f: Dictionary = w.table("facility")[fid]
		if f["org"] == oid:
			check_eq(int(f.get("lean_pm", 0)), 0, "no lean crews under the pledge (%s)" % fid)
	check_eq(w.ledger.total(), 0, "ledger closed")

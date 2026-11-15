extends TestCase
## EconPop.casualties (Terra's wildlife attacks): people die in the right order and jobs stay equal to people.


func _farm(w: WorldState) -> String:
	for fid in EconUtil.sorted_keys(w.table("facility")):
		var f: Dictionary = w.table("facility")[fid]
		if f["type"] == "FARM" and EconLabor.staff_total(f["staff"]) >= EconUtil.S:
			return fid
	return ""


func test_attack_on_a_farm() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	sim.run(3)
	var fid := _farm(w)
	check(fid != "", "a staffed farm exists")
	var f: Dictionary = w.table("facility")[fid]
	var staff0 := EconLabor.staff_total(f["staff"])
	var pop0 := PopStore.total(w)
	var killed := EconPop.casualties(w, f["district"], 1, "OUTDOOR", fid)
	check_eq(killed, 1, "one killed")
	check_eq(EconLabor.staff_total(f["staff"]), staff0 - EconUtil.S, "a worker of that farm")
	check_eq(PopStore.total(w), pop0 - 1, "one person fewer")
	check(EconPop.check(w).is_empty(), "jobs equal people after the attack")
	sim.run(2)
	check(EconPop.check(w).is_empty(), "and the colony goes on consistent")
	check_eq(w.ledger.total(), 0, "ledger closed")


func test_settlement_edge_order() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	sim.run(3)
	var d := "d:1"
	var hb := EconPop.hb_of(d)
	var free0 := 0
	for st in ["UNEMPLOYED", "NOT_IN_LF", "RETIRED"]:
		free0 += PopStore.count(w, {"hb": hb, "status": st})
	var kids0 := PopStore.count(w, {"hb": hb, "status": "CHILD"})
	var pop0 := PopStore.total(w)
	var killed := EconPop.casualties(w, d, 3, "", "")
	check_eq(killed, 3, "three killed")
	check_eq(PopStore.total(w), pop0 - 3, "three people fewer")
	check(EconPop.check(w).is_empty(), "jobs equal people")
	if free0 >= 3:
		check_eq(PopStore.count(w, {"hb": hb, "status": "CHILD"}), kids0, "adults without a job die before children")
	check_eq(EconPop.casualties(w, d, 0, "OUTDOOR", ""), 0, "zero is zero")

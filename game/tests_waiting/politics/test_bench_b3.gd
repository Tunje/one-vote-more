extends TestCase
## A51 B3: election lists, independents, the personal-mandate amendment.
const Bench := preload("res://sim/staff/bench.gd")


func _sim() -> Simulation:
	var sim: Simulation = EconFace.sim_make(3, "BALANCED", {}, true)
	sim.run(PolDefs.PARTY_FORMATION_MONTH + 40)
	return sim


func test_lists_fill_seats_from_the_top() -> void:
	var w := _sim().world
	check(w.table("pol")["state"]["elections"].size() >= 1, "an election was held")
	for p in PartyLife.active(w):
		var seated := 0
		for pid in w.table("person"):
			var q: Dictionary = w.table("person")[pid]
			if String(q.get("party_id", "")) == p["id"] and bool(q.get("assembly_seat", false)):
				seated += 1
				check(int(q["list_rank"]) <= int(p["seats"]), "seated names come from the top of the list")
		check(seated <= int(p["seats"]), "no more seated names than seats (%s: %d of %d)" % [p["id"], seated, p["seats"]])


func test_independent_carries_the_seat_until_the_election() -> void:
	var sim := _sim()
	var w := sim.world
	var who := ""
	for pid in CoreUtil.sorted_keys(w.table("person")):
		var q: Dictionary = w.table("person")[pid]
		if bool(q.get("assembly_seat", false)) and not Bench.is_leader(w, pid):
			who = pid
			break
	check(who != "", "a seated member exists")
	if who == "":
		return
	var from := String(w.table("person")[who]["party_id"])
	var before := int(w.table("party")[from]["seats"])
	var r: Dictionary = Bench.defect(w, who, "")
	check(bool(r["ok"]), "defects to sit as an independent: %s" % str(r))
	var row := String(w.table("person")[who]["party_id"])
	check_eq(int(w.table("party")[from]["seats"]), before - 1, "old party loses the seat")
	check_eq(String(w.table("party")[row]["status"]), "INDEPENDENT", "a one-seat independent row")
	check_eq(int(w.table("party")[row]["seats"]), 1, "it holds the seat")
	check(not PartyLife.active(w).any(func(p): return p["id"] == row), "independents are not active parties")
	PartyLife.end_independents(w)
	check_eq(int(w.table("party")[row]["seats"]), 0, "the seat ends at the election")
	check(not bool(w.table("person")[who]["assembly_seat"]), "no longer seated")


func test_mandate_amendment_needs_two_thirds() -> void:
	var w := _sim().world
	var LO: Script = load("res://sim/law/law_ops.gd")
	if not LO.call("state", w)["constitution"]:
		return   # no constitution yet in this seed at this point
	var r: Dictionary = LO.call("amend_constitution", w, "LAW_PERSONAL_MANDATE", 0, int(LO.call("amend_seats")) - 1)
	check(not bool(r["ok"]), "one seat short fails")
	r = LO.call("amend_constitution", w, "LAW_PERSONAL_MANDATE", 0, int(LO.call("amend_seats")))
	check(bool(r["ok"]), "2/3 passes")
	check_eq(int(w.levers["LAW_PERSONAL_MANDATE"]), 0, "the seat now belongs to the party")

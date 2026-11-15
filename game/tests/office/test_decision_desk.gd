extends TestCase
## Who decides, step 1 (planning/design-delegation.md): the decision-type registry and the case counter (flag DELEGATION).

const EconSim := preload("res://sim/economy/econ_sim.gd")
const Desk := preload("res://sim/office/decision_desk.gd")
const OS_ := preload("res://sim/staff/office_staff.gd")


func _sim(on: bool) -> Simulation:
	var sim: Simulation = EconSim.make(1, "BALANCED", {}, true)
	if on:
		(sim.world.meta["on"] as Array).append(Desk.FLAG)
	return sim


func test_registry_is_well_formed() -> void:
	for ty in Desk.TYPES:
		var d: Dictionary = Desk.TYPES[ty]
		check(String(d.get("name", "")) != "", "%s has a name" % ty)
		check(String(d["ceiling"]) in Desk.CEILINGS, "%s has a legal ceiling" % ty)
		var p := String(d["portfolio"])
		check(p == "FM" or OS_.ROLES.has(p), "%s belongs to a known office role (%s)" % [ty, p])
		if d.has("fallback"):
			check(OS_.PORTFOLIOS.has(String(d["fallback"])), "%s falls back to a standing portfolio" % ty)
	for f in Desk.BUILD_TYPE:
		check(Desk.TYPES.has(Desk.BUILD_TYPE[f]), "build type for %s is registered" % f)
	check_eq(Desk.build_type("ROAD", "ECON_BUDGET_PUBLIC_WORKS"), "PUBLIC_WORKS", "public-works orders count as public works")
	check_eq(Desk.build_type("ROAD", "ECON_BUDGET_INFRASTRUCTURE"), "BUILD_ROAD", "road needs count as road works")


func test_agriculture_falls_back_to_the_economy_without_its_minister() -> void:
	var w := _sim(false).world
	check_eq(Desk.portfolio(w, "GRANT_COVERAGE"), "ECON_ADVISER", "no Minister of Agriculture: the Economy holds it")
	(w.meta["on"] as Array).append("AGRI_MIN")
	check_eq(Desk.portfolio(w, "GRANT_COVERAGE"), "AGRICULTURE", "with one: Agriculture holds it")
	check_eq(Desk.portfolio(w, "BILL"), "FM", "bills are the First Minister's")


func test_off_reproduces_exactly_and_on_only_counts() -> void:
	var off := _sim(false)
	var on := _sim(true)
	off.run(72)
	on.run(72)
	check(off.world.peek("decision_case").is_empty(), "without the flag nothing is recorded")
	var c := Desk.counts(on.world, 0, 71)
	check(Desk.total(c) > 0, "decisions are counted (%s)" % str(c))
	check(c.has("BILL") or c.has("ORDINANCE"), "laws are among them")
	var tagged := false
	for ty in c:
		if Desk.TYPES[ty]["src"] == "gov_builder":
			tagged = true
	check(tagged, "the capital programme is counted")
	# the flag changes nothing but its own table
	on.world.entities.erase("decision_case")
	(on.world.meta["on"] as Array).erase(Desk.FLAG)
	check_eq(on.world.state_hash(), off.world.state_hash(), "with the counter removed the two games are identical")


func test_office_items_counted_once_and_party_mail_not() -> void:
	var w := _sim(true).world
	var m := w.month
	Desk.note_office(w, {"kind": "EMAIL", "category": "UNION_DEMAND", "from": {}})
	Desk.note_office(w, {"kind": "EMAIL", "category": "", "from": {"kind": "PARTY_STAFF"}})
	Desk.note_office(w, {"kind": "PAPER", "category": ""})
	Desk.note_office(w, {"kind": "CALL", "category": "COMPETITION", "from": {}})
	var c := Desk.month_counts(w, m)
	check_eq(int(c.get("UNION_DEMAND", 0)), 1, "a union demand answered is one case")
	check_eq(int(c.get("COMPETITION_REVIEW", 0)), 1, "a merger review is one case")
	check_eq(Desk.total(c), 2, "party mail and papers are not government decisions")


func test_save_load_keeps_the_counter() -> void:
	var a := _sim(true)
	a.run(30)
	var path := "user://test_decision_desk.sav"
	check_eq(SaveIO.save(a, path), OK, "saved")
	var b := EconSim.for_load()
	check_eq(SaveIO.load_into(b, path), OK, "loaded")
	check_eq(var_to_str(Desk.counts(b.world, 0, 29)), var_to_str(Desk.counts(a.world, 0, 29)), "the counter survives save/load")
	a.step()
	b.step()
	check_eq(b.world.state_hash(), a.world.state_hash(), "save/load/continue stays identical")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

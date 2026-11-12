extends TestCase
## U1 (A41): unions as organisations — founding after the first year, a federation, members from real employment,
## dues into the fund (closed ledger), a leader, mood; deterministic.


func test_unions_founded_with_members_and_funds() -> void:
	var sim := EconSim.make_econ_only(5)
	sim.run(11)
	check(Unions.active(sim.world).is_empty(), "no unions in the first year")
	sim.run(4)
	var w := sim.world
	var act := Unions.active(w)
	var sectors := act.filter(func(u): return not u["federation"])
	check(sectors.size() >= 4, "sector unions founded after year 1: %d" % sectors.size())
	var fed := Unions.federation(w)
	check(not fed.is_empty(), "a federation once 3+ unions exist")
	var affil := 0
	for u in sectors:
		check(int(u["members"]) > 0, "%s has members" % u["name"])
		check(Unions.fund(w, u["id"]) > 0, "%s collects dues" % u["name"])
		check(str(u["leader"].get("name", "")) != "", "%s has a leader" % u["name"])
		check(int(u["mood"]) >= 0 and int(u["mood"]) <= 100, "mood in range")
		check_eq(String(u["acct"]), "union:" + String(u["id"]), "fund account naming")
		if u["affiliated_to"] == fed["id"]:
			affil += 1
	check(affil >= 3, "unions affiliate to the federation (%d)" % affil)
	check(Unions.fund(w, fed["id"]) > 0, "the federation receives affiliation fees")
	check(not Unions.of_occ(w, "MINING").is_empty() or not Unions.of_occ(w, "MANUFACTURING").is_empty(), "of_occ finds a sector union")
	check(not w.facts.query("UNION_FOUNDED").is_empty(), "founding makes news")
	check_eq(w.ledger.total(), 0, "ledger closed")
	check(EconPop.check(w).is_empty(), "no PopStore change")


func test_deterministic_and_switch() -> void:
	var a := EconSim.make_econ_only(9)
	var b := EconSim.make_econ_only(9)
	a.run(20)
	b.run(20)
	var ua := Unions.active(a.world)
	var ub := Unions.active(b.world)
	check_eq(ua.size(), ub.size(), "same unions")
	for i in mini(ua.size(), ub.size()):
		check_eq(ua[i]["members"], ub[i]["members"], "same members")
		check_eq(ua[i]["leader"]["name"], ub[i]["leader"]["name"], "same leader")
	var off := EconSim.make_econ_only(9)
	off.world.meta["off"] = ["UNIONS_U1"]
	off.run(20)
	check(Unions.active(off.world).is_empty(), "switch off: no union organisations")


func test_elections_happen() -> void:
	var sim := EconSim.make_econ_only(5)
	sim.run(14)
	var w := sim.world
	for u in Unions.active(w):
		u["election_due"] = w.month + 1
	sim.run(2)
	check(w.facts.query("UNION_LEADER_ELECTED").size() >= Unions.active(w).size(), "every union held its election")


func test_employer_density() -> void:
	var sim := EconSim.make_econ_only(5)
	sim.run(15)
	var w := sim.world
	var cpw := EconFinance.org_by_key(w, "CPW")
	var d := Unions.at_employer(w, cpw)
	check_eq(String(d["occ"]), "PUBLIC_SECTOR", "the utility's staff are public servants")
	check(int(d["density_pm"]) > 0 and String(d["union"]) != "", "a density and a union at the employer: %s" % [d])


func test_empty_union_dissolves_and_merges_do_not_chain() -> void:
	var sim := EconSim.make_econ_only(5)
	sim.run(15)
	var w := sim.world
	var fed := Unions.federation(w)
	var u: Dictionary = Unions.active(w).filter(func(x): return not x["federation"])[0]
	u["sectors"] = ["NO_SUCH_OCC"]
	u["share"] = {"NO_SUCH_OCC": 1.0}
	u["lapsed"] = 0
	u["members"] = 0
	u["empty_m"] = Unions.EMPTY_DISSOLVE_M - 1
	var fund0 := Unions.fund(w, u["id"])
	var fed0 := Unions.fund(w, fed["id"])
	sim.run(2)
	check_eq(String(u["status"]), "DISSOLVED", "a union with no members for two years winds up")
	check(Unions.fund(w, fed["id"]) >= fed0 + fund0 * 9 / 10, "its fund goes to the federation")
	check(not w.facts.query("UNION_DISSOLVED").is_empty(), "dissolution makes news")
	check_eq(w.ledger.total(), 0, "ledger closed")
	for x in Unions.active(w):
		check(x["sectors"].size() <= Unions.MERGE_MAX_SECTORS, "%s covers at most two sectors" % x["name"])

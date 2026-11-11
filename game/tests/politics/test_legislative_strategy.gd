extends TestCase
## Fixes from the 2nd/3rd/4th 100-year analyses: governments back their own bills, don't resubmit defeated bills
## to an unchanged parliament, don't flip-flop, promise only feasible deals, and lose credibility on failed issues.

const EconSim := preload("res://sim/economy/econ_sim.gd")


func _world() -> WorldState:
	var sim: Simulation = EconSim.make(5, "BALANCED", {}, true)
	sim.run(66)
	return sim.world


func _st(w: WorldState) -> Dictionary:
	return w.table("pol")["state"]


func _propose(w: WorldState) -> Array:
	var st := _st(w)
	var g: Dictionary = st["government"]
	var cs := PoliticsProvider.new().colony_concerns(w)
	return Legislature.propose(w, g["center"], cs[0], cs[1], g.get("agreement", []), "PARLIAMENT")


func test_every_governing_party_backs_the_proposals() -> void:
	var w := _world()
	var st := _st(w)
	var g: Dictionary = st["government"]
	check(not g.is_empty(), "government")
	var cs := PoliticsProvider.new().colony_concerns(w)
	for c in _propose(w):
		for pid in g["members"]:
			check_eq(Legislature.party_vote(w.table("party")[pid], [c], w, g, cs[0], cs[1]), "YES", "%s backs %s" % [pid, c["lever"]])


func test_defeated_change_not_resubmitted_to_same_parliament() -> void:
	var w := _world()
	var props := _propose(w)
	if props.is_empty():
		return
	var c: Dictionary = props[0]
	w.table("bill")["bill:test"] = {"id": "bill:test", "month": w.month, "sponsor": "", "clauses": [c], "votes": {}, "yes": 10, "no": 141, "status": "DEFEATED"}
	for c2 in _propose(w):
		check(not (c2["lever"] == c["lever"] and signf(float(c2["to"]) - float(c2["from"])) == signf(float(c["to"]) - float(c["from"]))),
			"the defeated %s change is not tabled again" % c["lever"])


func test_no_flip_flopping_within_a_government() -> void:
	var w := _world()
	var props := _propose(w)
	if props.is_empty():
		return
	var c: Dictionary = props[0]
	var back := {"lever": c["lever"], "from": c["to"], "to": c["from"]}
	w.table("bill")["bill:test"] = {"id": "bill:test", "month": w.month, "sponsor": "", "clauses": [back], "votes": {}, "yes": 100, "no": 51, "status": "PASSED"}
	for c2 in _propose(w):
		check(c2["lever"] != c["lever"] or signf(float(c2["to"]) - float(c2["from"])) != signf(float(c["to"]) - float(c["from"])),
			"no reversal of this government's own recent %s change" % c["lever"])


func test_deals_only_for_feasible_demands() -> void:
	var w := _world()
	var lid := "ECON_BENEFIT_DURATION"
	if not w.lever_defs.has(lid):
		return
	var r: Array = Legislature._range(w.lever_defs[lid])
	w.levers[lid] = r[1]
	check(not Coalition.feasible(w, lid, 1), "can't promise to raise a lever already at its maximum")
	check(Coalition.feasible(w, lid, -1), "lowering it is still possible")


func test_failing_government_loses_issue_credibility() -> void:
	var w := _world()
	var st := _st(w)
	var g: Dictionary = st["government"]
	var p: Dictionary = w.table("party")[g["pm_party"]]
	p["ownership"]["PUBLIC_SERVICES"] = 80
	PartyLife.lifecycle(st)["issue_months"]["PUBLIC_SERVICES"] = 24
	for c in w.table("cell").values():
		c["sat"]["PUBLIC_SERVICES"] = 5000  # services in ruins
	while w.month_of_year() != 12:
		w.month += 1
	PartyLife.track_grievances(w, st)
	check(int(p["ownership"]["PUBLIC_SERVICES"]) < 80, "credibility lost after a year of failure in office (%d)" % p["ownership"]["PUBLIC_SERVICES"])

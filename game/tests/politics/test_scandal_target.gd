extends TestCase
## A press scandal draws fire (Ella; Wilma/Anni review: 1 of 4 press-hit parties drew an attack ad): attack and
## oppo-research targets weight recent POL_SCANDAL_REVEALED (DONATION or FAVOUR), fading over 24 months.
## Symmetric: any party hit, any attacker; a governing party only spares its own partners.


func _sim() -> Simulation:
	var sim := PoliticalSim.make(3, "BALANCED", {})
	sim.run(PolDefs.PARTY_FORMATION_MONTH + 6)
	return sim


func _scandal(w: WorldState, pid: String, sev: int, kind: String = "DONATION") -> void:
	w.add_fact({"type": "POL_SCANDAL_REVEALED", "owner": "law", "subjects": [{"kind": "PARTY", "id": pid}],
		"responsible": [], "impact": {}, "magnitude": 50, "visibility": "PUBLIC",
		"data": {"party": pid, "leader": "x", "severity": sev, "kind": kind, "donor": "", "channel": "PRESS"}})


func _gov(w: WorldState, members: Array) -> Dictionary:
	var st: Dictionary = w.table("pol")["state"]
	st["government"] = {"members": members, "pm_party": members[0], "support": []}
	return st


func test_heat_fades_over_two_years() -> void:
	var w := _sim().world
	var pid := String(PartyLife.active(w)[0]["id"])
	var h0 := float(Campaign.scandal_heat(w).get(pid, 0.0))
	_scandal(w, pid, 50, "FAVOUR")
	check(absf(float(Campaign.scandal_heat(w)[pid]) - h0 - 1.0) < 1e-6, "a fresh severity-50 scandal is heat 1")
	w.month += 12
	check(float(Campaign.scandal_heat(w).get(pid, 0.0)) < 0.6, "half gone after a year")
	w.month += 12
	check(float(Campaign.scandal_heat(w).get(pid, 0.0)) == 0.0, "gone after two years")
	check(Campaign.vulnerability({"credibility": 50, "leader": {"popularity": 60}}, 1.0) > Campaign.vulnerability({"credibility": 50, "leader": {"popularity": 60}}), "attacks stick better")


func test_any_attacker_turns_on_a_fresh_scandal() -> void:
	var w := _sim().world
	var ps := PartyLife.active(w)
	check(ps.size() >= 4, "enough parties")
	var a := String(ps[0]["id"])
	var b := String(ps[1]["id"])
	var x := String(ps[2]["id"])
	var y := String(ps[3]["id"])
	var st := _gov(w, [a, b])
	var before_x := Campaign.pick_target(w, st, ps[2])
	check_eq(before_x, a, "opposition goes after the First Minister's party")
	_scandal(w, y, 80)
	w.month += 1
	check_eq(Campaign.pick_target(w, st, ps[2]), y, "an opposition party turns on a scandal-hit rival in opposition")
	check_eq(Campaign.pick_target(w, st, ps[0]), y, "the Cabinet turns on it too")
	# the other way round: a governing party in scandal
	w.month += 30
	_scandal(w, b, 80)
	w.month += 1
	check_eq(Campaign.pick_target(w, st, ps[2]), b, "the opposition turns on the scandal-hit coalition partner")
	check(Campaign.pick_target(w, st, ps[0]) != b, "the First Minister's party spares its own partner")
	w.month += 30
	check_eq(Campaign.pick_target(w, st, ps[2]), a, "back to normal when the story is old")

extends TestCase
## A58: a party that took money from an org leans toward granting its asks; transparency weakens the lean.
const EconSim := preload("res://sim/economy/econ_sim.gd")
const CL := preload("res://sim/law/competition_law.gd")


func test_donor_ask_tilts_the_party_and_disclosure_weakens_it() -> void:
	var sim: Simulation = EconSim.make(5, "BALANCED", {}, true)
	sim.run(60)
	var w := sim.world
	var p: Dictionary = PartyLife.active(w)[0]
	var org := ""
	for oid in CoreUtil.sorted_keys(w.table("org")):
		if String(w.table("org")[oid].get("type", "")) == "PRIVATE":
			org = oid
			break
	check(org != "", "a private firm exists")
	var lever := "ECON_PROFIT_TAX_RATE"
	check_eq(Legislature.lobby_tilt(w, p, lever, -1.0), 0.0, "no asks, no tilt")
	w.add_fact({"type": "POL_DONATION", "owner": "pol", "subjects": [{"kind": "PARTY", "id": p["id"]}, {"kind": "COMPANY", "id": org}],
		"responsible": [], "impact": {}, "magnitude": 20, "visibility": "PUBLIC",
		"data": {"donor": org, "party": p["id"], "amount": 3 * int(w.values.get("ECON_W_REF", 1200000)), "lawful": true, "cap": -1}})
	CL.lobby(w, org, String(p["id"]), {"lever": lever, "dir": -1})
	var t0 := Legislature.lobby_tilt(w, p, lever, -1.0)
	check(t0 > 0.0, "the donor's ask pulls toward the cut (got %.3f)" % t0)
	check(Legislature.lobby_tilt(w, p, lever, 1.0) < 0.0, "and against a rise")
	w.levers["LAW_LOBBY_REGISTER"] = 2
	check(Legislature.lobby_tilt(w, p, lever, -1.0) < t0, "disclosure weakens the pull")

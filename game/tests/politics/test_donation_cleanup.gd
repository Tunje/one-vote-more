extends TestCase
## After a donation scandal a party cleans up (Ella; v7 seed-3 loop of 91 scandals in one party): it refuses the
## donor for 5 years and takes nothing secret or illegal under a clean pledge; the clean-up is announced.

const EconSim := preload("res://sim/economy/econ_sim.gd")


func _sim() -> Simulation:
	var sim: Simulation = EconSim.make(3, "BALANCED", {}, true)
	sim.run(60)
	return sim


func _scandal(w: WorldState, pid: String, donor: String) -> void:
	w.add_fact({"type": "POL_SCANDAL_REVEALED", "owner": "law", "subjects": [{"kind": "PARTY", "id": pid}],
		"responsible": [], "impact": {}, "magnitude": 50, "visibility": "PUBLIC",
		"data": {"party": pid, "leader": "x", "severity": 40, "donor": donor, "amount": 1000, "excess": 0,
			"undisclosed": true, "channel": "PRESS"}})


func _seated(w: WorldState) -> Dictionary:
	for p in PartyLife.active(w):
		if int(p["seats"]) > 0:
			return p
	return {}


func test_a_scandal_sets_a_pledge_and_a_refusal_that_expire() -> void:
	var w := _sim().world
	var p := _seated(w)
	_scandal(w, p["id"], "org:1")
	w.month += 1
	var cs := PartyLife.cleanup_state(w)
	check(cs.has(p["id"]), "the party is cleaning up")
	var e: Dictionary = cs[p["id"]]
	check_eq(int(e["refuse"]["org:1"]), w.month - 1 + PartyLife.CLEANUP_REFUSE_MONTHS, "refuses the donor 5 years")
	check(int(e["pledge"]) >= w.month - 1 + PartyLife.CLEANUP_PLEDGE_MONTHS, "pledge for at least 4 years")
	_scandal(w, p["id"], "org:2")
	w.month += 1
	check_eq(int(PartyLife.cleanup_state(w)[p["id"]]["n"]), 2, "repeat offences count")
	check(int(PartyLife.cleanup_state(w)[p["id"]]["pledge"]) >= w.month - 1 + 2 * PartyLife.CLEANUP_PLEDGE_MONTHS, "longer pledge for a repeat")


func test_the_cleanup_is_announced_and_the_donor_refused() -> void:
	var w := _sim().world
	var p := _seated(w)
	var donor := ""
	for oid in Det_ordered(w.peek("org")):
		if w.ledger.has_account(CoreUtil.acct(String(oid))):
			donor = String(oid)
			break
	check(donor != "", "a company that can give")
	w.ledger.transfer(Ledger.EXTERNAL, CoreUtil.acct(donor), 10_000, "TEST", w.month)
	_scandal(w, p["id"], donor)
	w.month += 1
	var n0 := w.facts.query("POL_PARTY_CLEANUP").size()
	# an offer from the same donor that fits only this party
	var prefers := {}
	for ax in PolDefs.AXES:
		prefers[ax] = 1000 if int(p["positions"][ax]) >= 0 else -1000
	w.table("donation_offer")["o_t"] = {"month": w.month, "from": donor, "amount_milli": 1000, "prefers": prefers}
	PartyLife._book_donations(w)
	check_eq(w.facts.query("POL_PARTY_CLEANUP").size(), n0 + 1, "announced")
	var c: Dictionary = w.facts.query("POL_PARTY_CLEANUP").back()
	check_eq(String(c["data"]["party"]), String(p["id"]), "the right party")
	check_eq(c["visibility"], "PUBLIC", "public")
	var gifts: Array = w.facts.query("POL_DONATION", w.month).filter(func(f): return String(f["data"]["donor"]) == donor and String(f["data"]["party"]) == String(p["id"]))
	check(gifts.is_empty(), "no money from that donor")


func test_no_hidden_illegal_gifts_under_a_pledge() -> void:
	var sim := _sim()
	var w := sim.world
	var pledged: Array = []
	for q in PartyLife.active(w):
		q["leader"]["integrity"] = 0   # the worst case: every leader would hide gifts
		_scandal(w, q["id"], "org:none")
		pledged.append(String(q["id"]))
	var m0 := w.month
	sim.run(24)
	var bad: Array = w.facts.query("POL_DONATION", m0 + 1).filter(func(f): return not bool(f["data"].get("lawful", true)) and String(f["data"]["party"]) in pledged)
	check_eq(bad.size(), 0, "nothing unlawful from a party on a pledge (parties founded since are not)")


func Det_ordered(d: Dictionary) -> Array:
	var k := d.keys()
	k.sort()
	return k

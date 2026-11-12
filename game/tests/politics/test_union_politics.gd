extends TestCase
## Unions in politics (A41 U3, Ella): per-union endorsements, betrayal, union money and volunteers
## (planning/spec-election-year-v1.md §10, spec-unions-v1.md §3).

const EconSim := preload("res://sim/economy/econ_sim.gd")
const MONTHS := 60   # unions found at m12, the federation once three exist


func _sim() -> Simulation:
	var sim: Simulation = EconSim.make(3, "BALANCED", {}, true)
	sim.run(MONTHS)
	return sim


func _st(w: WorldState) -> Dictionary:
	return w.table("pol")["state"]


## A sector union (not the federation) with an endorsement, and its party.
func _endorsing(w: WorldState) -> Array:
	var pk := UnionPolitics.picks(w)
	for u in Unions.active(w):
		if not u["federation"] and pk.has(u["id"]):
			return [u, w.table("party")[pk[u["id"]]]]
	return []


func _labour_bill(w: WorldState, sponsor: String, votes: Dictionary, from_v: int, to_v: int, passed: bool, lever: String = "ECON_MIN_WAGE") -> void:
	var id := w.new_id("bill")
	w.table("bill")[id] = {"id": id, "month": w.month, "sponsor": sponsor,
		"clauses": [{"lever": lever, "from": from_v, "to": to_v}], "votes": votes, "status": "PASSED" if passed else "DEFEATED"}
	w.add_fact({"type": "POL_BILL_PASSED" if passed else "POL_BILL_DEFEATED", "owner": "pol", "subjects": [],
		"responsible": [], "impact": {}, "magnitude": 40, "visibility": "PUBLIC", "data": {"bill": id}})


func test_every_union_reviews_and_the_federation_keeps_the_legacy_key() -> void:
	var w := _sim().world
	check(UnionPolitics.on(w), "unions exist by month %d" % MONTHS)
	var e := PartyLife.endorsements(w)
	check(e.has("unions") and e.has("occ_pick"), "per-union shape")
	check_eq(e["union"], e["federation"], "legacy 'union' = the federation's pick")
	check(not e["unions"].is_empty(), "some union endorses")
	check(w.facts.query("UNION_ENDORSED").size() >= e["unions"].size(), "a fact per endorsement")
	for f in w.facts.query("UNION_ENDORSED"):
		check_eq(f["visibility"], "PUBLIC", "public")
		check_eq(String(f["data"]["channel"]), "UNION", "channel")


func test_cabinet_cut_betrays_the_union_and_angers_the_labour_wing() -> void:
	var w := _sim().world
	var st := _st(w)
	var pair := _endorsing(w)
	check(not pair.is_empty(), "an endorsing union")
	if pair.is_empty():
		return
	var u: Dictionary = pair[0]
	var p: Dictionary = pair[1]
	st["government"]["members"] = [p["id"]]
	var before := UnionPolitics.score(w, u, p)
	var disc := 0
	for f in p["factions"]:
		disc += int(f["discontent"])
	var r: Array = w.lever_defs["ECON_UNION_RIGHTS"].get("range", [0, 100])
	_labour_bill(w, p["id"], {p["id"]: "YES"}, int(r[1]), int(r[0]), true, "ECON_UNION_RIGHTS")
	w.month += 1
	UnionPolitics.monthly(w, st)
	check(String(UnionPolitics.picks(w).get(u["id"], "")) != p["id"], "endorsement withdrawn")
	var wd: Array = w.facts.query("UNION_ENDORSEMENT_WITHDRAWN").filter(func(f): return f["data"]["party"] == p["id"] and f["data"]["reason"] == "BETRAYAL")
	check(not wd.is_empty(), "betrayal fact")
	check(UnionPolitics.score(w, u, p) < before - 20.0, "the union remembers (%.1f -> %.1f)" % [before, UnionPolitics.score(w, u, p)])
	var disc2 := 0
	for f in p["factions"]:
		disc2 += int(f["discontent"])
	check(disc2 > disc, "a wing of the party is angry")


func test_opposition_no_vote_on_a_pro_labour_bill_counts_half() -> void:
	var w := _sim().world
	var st := _st(w)
	var ps := PartyLife.active(w)
	var gov: Dictionary = ps[0]
	var opp: Dictionary = ps[1]
	st["government"]["members"] = [gov["id"]]
	var u: Dictionary = Unions.federation(w)
	var g0 := UnionPolitics.score(w, u, gov)
	var o0 := UnionPolitics.score(w, u, opp)
	_labour_bill(w, gov["id"], {gov["id"]: "YES", opp["id"]: "NO"}, 400, 1000, true)
	w.month += 1
	UnionPolitics.monthly(w, st)
	var dg := UnionPolitics.score(w, u, gov) - g0
	var do := UnionPolitics.score(w, u, opp) - o0
	check(dg > 0.0, "the government gets credit (%.1f)" % dg)
	check(do < 0.0, "the opposition's NO costs it (%.1f)" % do)
	check(absf(absf(do) - 0.5 * dg) < 0.6, "at half weight (%.1f vs %.1f)" % [do, dg])
	check_eq(w.facts.query("UNION_ENDORSEMENT_WITHDRAWN").filter(func(f): return f["data"]["reason"] == "BETRAYAL").size(), 0, "a NO vote is not a betrayal")


func test_grudge_fades_linearly_over_eight_years() -> void:
	var w := _sim().world
	var st := _st(w)
	var pair := _endorsing(w)
	if pair.is_empty():
		check(false, "an endorsing union")
		return
	var u: Dictionary = pair[0]
	var p: Dictionary = pair[1]
	var base := UnionPolitics.score(w, u, p)
	UnionPolitics.betray(w, st, p["id"], {"ECON_UNION_RIGHTS": -2.0})
	var m0 := w.month
	var at := func(dm: int) -> float:
		w.month = m0 + dm
		return base - UnionPolitics.score(w, u, p)
	var p0: float = at.call(0)
	var p48: float = at.call(48)
	var p96: float = at.call(96)
	check(absf(p0 - 2.0 * UnionPolitics.GRUDGE_PTS) < 0.5, "full penalty at first (%.1f)" % p0)
	check(absf(p48 - UnionPolitics.GRUDGE_PTS) < 0.5, "half after four years (%.1f)" % p48)
	check(absf(p96) < 0.5, "gone after eight (%.1f)" % p96)
	w.month = m0


func test_members_split_their_union_bonus_with_the_federation() -> void:
	var e := {"density": {"MINING": 50000}, "occ_pick": {"MINING": "a"}, "federation": "b"}
	var cell := {"occ": "MINING"}
	var b := UnionPolitics.union_bonus(cell, e, 0.9)
	check(absf(float(b["a"]) - 0.9 * 0.5 * 2.0 / 3.0) < 1e-6, "own union 2/3")
	check(absf(float(b["b"]) - 0.9 * 0.5 / 3.0) < 1e-6, "federation 1/3")
	e["federation"] = "a"
	b = UnionPolitics.union_bonus(cell, e, 0.9)
	check(absf(float(b["a"]) - 0.45) < 1e-6, "same party gets the whole bonus")
	e["occ_pick"] = {}
	b = UnionPolitics.union_bonus(cell, e, 0.9)
	check(absf(float(b["a"]) - 0.45) < 1e-6, "no own pick: the federation's")


func test_union_money_goes_to_the_endorsed_party_within_the_ledger() -> void:
	var w := _sim().world
	var pair := _endorsing(w)
	if pair.is_empty():
		check(false, "an endorsing union")
		return
	var u: Dictionary = pair[0]
	var p: Dictionary = pair[1]
	# top the fund up past its strike reserve (8 weeks of strike pay, which grows with wages and membership)
	var reserve := int(8.0 / 4.33 * float(u["members"]) / EconUtil.S * float(Unions.strike_pay(w)))
	var top := maxi(0, reserve - w.ledger.balance(String(u["acct"]))) + 50_000_000
	w.ledger.transfer(Ledger.EXTERNAL, String(u["acct"]), top, "TEST", w.month)
	check(Unions.spare_fund(w, String(u["id"])) >= 40_000_000, "spare money above the reserve")
	var fund0 := w.ledger.balance(String(u["acct"]))
	var party0 := w.ledger.balance("party:" + String(p["id"]))
	UnionPolitics._donate(w, UnionPolitics._s(w))
	var gave := fund0 - w.ledger.balance(String(u["acct"]))
	check(gave > 0, "the union gave")
	check_eq(w.ledger.balance("party:" + String(p["id"])) - party0 >= gave, true, "the party received it")
	var d: Array = w.facts.query("POL_DONATION").filter(func(f): return String(f["data"].get("donor", "")) == String(u["id"]))
	check(not d.is_empty() and d.back()["visibility"] == "PUBLIC", "public donation fact")
	check(UnionPolitics.mob_units(w, p["id"]) > 0.0, "and volunteers")


func test_union_politics_deterministic_and_save_load() -> void:
	var ref: Simulation = EconSim.make(5, "BALANCED", {}, true)
	ref.run(50)
	check_eq(SaveIO.save(ref, save_path("union_pol.sav")), OK, "save")
	ref.run(20)
	var loaded: Simulation = EconSim.for_load()
	check_eq(SaveIO.load_into(loaded, save_path("union_pol.sav")), OK, "load")
	loaded.run(20)
	check_eq(loaded.world.state_hash(), ref.world.state_hash(), "save/load/continue identical")
	check_eq(UnionPolitics.picks(loaded.world), UnionPolitics.picks(ref.world), "same endorsements")


func test_a_union_weighs_the_laws_its_members_live_by() -> void:
	var miners := {"id": "m", "sectors": ["MINING"], "federation": false}
	var clerks := {"id": "c", "sectors": ["PUBLIC_SECTOR"], "federation": false}
	var safety_cut := {"LAW_SAFETY_STANDARD": -1.0}
	var pay_cut := {"ECON_PUBLIC_PAY_INDEX": -1.0}
	check(UnionPolitics.union_value(miners, safety_cut) < UnionPolitics.union_value(clerks, safety_cut), "miners mind safety more")
	check_eq(UnionPolitics.union_value(miners, pay_cut), 0.0, "public pay is not the miners' fight")
	check(UnionPolitics.union_value(clerks, pay_cut) <= -UnionPolitics.BETRAY_MIN, "it is the public servants'")


func test_a_small_cut_is_not_a_betrayal() -> void:
	var w := _sim().world
	var st := _st(w)
	var pair := _endorsing(w)
	if pair.is_empty():
		check(false, "an endorsing union")
		return
	var u: Dictionary = pair[0]
	var p: Dictionary = pair[1]
	UnionPolitics.betray(w, st, p["id"], {"ECON_UNEMPLOYMENT_BENEFIT_RATE": -0.5})
	check_eq(String(UnionPolitics.picks(w).get(u["id"], "")), String(p["id"]), "a token cut is grumbled at, not a walk-out")


func test_a_union_does_not_hop_to_the_coalition_partner_that_voted_the_same_cut() -> void:
	var w := _sim().world
	var st := _st(w)
	var pair := _endorsing(w)
	if pair.is_empty():
		check(false, "an endorsing union")
		return
	var u: Dictionary = pair[0]
	var p: Dictionary = pair[1]
	var partner := ""
	for q in PartyLife.active(w):
		if q["id"] != p["id"] and UnionPolitics.pro_labour(u, q):
			partner = q["id"]
			break
	if partner == "":
		check(false, "a pro-labour partner")
		return
	st["government"]["members"] = [p["id"], partner]
	var r: Array = w.lever_defs["ECON_UNION_RIGHTS"].get("range", [0, 100])
	_labour_bill(w, p["id"], {p["id"]: "YES", partner: "YES"}, int(r[1]), int(r[0]), true, "ECON_UNION_RIGHTS")
	w.month += 1
	UnionPolitics.monthly(w, st)
	var now := String(UnionPolitics.picks(w).get(u["id"], ""))
	check(now != p["id"] and now != partner, "backs neither cabinet party (now '%s')" % now)
	var wd: Array = w.facts.query("UNION_ENDORSEMENT_WITHDRAWN").filter(func(f): return f["data"]["union"] == u["id"] and f["month"] == w.month)
	check_eq(wd.size(), 1, "one walk-out, not a chain")

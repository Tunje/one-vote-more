extends TestCase
## Political arrests in the campaign (Ella; Wilma's request on Anni's P1c POLICE): a revealed order to arrest an
## opponent makes the victim a martyr (sympathy momentum fading over a term, a jolt in the reveal month, the rule
## of law as its theme, a "they jailed our leader" attack line on the ordering PM's party); the visible detention
## is an allegation of persecution; a leader in a cell can't take the stage, only send statements.


func _campaign() -> Array:
	var sim := PoliticalSim.make(3, "BALANCED", {})
	var w := sim.world
	while Campaign.current(w).is_empty() and w.month < 200:
		sim.run(1)
	return [sim, Campaign.current(w)]


func _gov(w: WorldState, members: Array) -> Dictionary:
	var st: Dictionary = w.table("pol")["state"]
	st["government"] = {"members": members, "pm_party": members[0], "support": [], "formed_month": w.month - 1}
	return st


func _order(w: WorldState, victim: String, name: String = "Ada Berg", reveal: bool = true) -> String:
	var oid := w.add_fact({"type": "LAW_UNLAWFUL_GOV_ACTION", "owner": "law", "subjects": [],
		"responsible": [{"actor": {"kind": "AI_GOV", "id": "government"}, "share": 1.0}], "impact": {},
		"magnitude": 60, "visibility": "SECRET", "data": {"action": "POLITICAL_ARREST",
			"params": {"party": victim, "person": "", "name": name, "pretext": "fraud", "months": 3}}})
	if reveal:
		w.facts.reveal(w.month, oid)
	return oid


func test_a_revealed_order_makes_a_martyr_that_fades() -> void:
	var r := _campaign()
	var w: WorldState = r[0].world
	var c: Dictionary = r[1]
	check(not c.is_empty(), "a campaign is running")
	var ps := PartyLife.active(w)
	var pm := String(ps[0]["id"])
	var victim := String(ps[1]["id"])
	var st := _gov(w, [pm])
	check(Campaign.martyrs(w).is_empty(), "no martyr without a revealed order")
	_order(w, victim, "Ada Berg", false)
	check(Campaign.martyrs(w).is_empty(), "a secret order is not a story yet")
	_order(w, victim)
	var m: Dictionary = Campaign.martyrs(w).get(victim, {})
	check(not m.is_empty(), "the revealed order is found")
	check_eq(String(m.get("pm", "")), pm, "the PM party whose government gave the order")
	check(absf(float(m.get("heat", 0.0)) - 1.0) < 1e-6, "fresh: heat 1")
	check_eq(Campaign.pick_target(w, st, ps[1]), pm, "the victim turns on the jailers")
	var e: Dictionary = c["parties"][victim]
	e["manual"] = false
	e["momentum"] = 0
	var n0 := w.facts.query("POL_MARTYR_CAMPAIGN").size()
	Campaign._persecution(w, st, c)
	check_eq(int(e["momentum"]), Campaign.MARTYR_REVEAL + Campaign.MARTYR_MONTHLY, "a jolt plus the monthly sympathy")
	check_eq(String(e["themes"][0]), "GOVERNANCE", "the victim campaigns on the rule of law")
	check_eq(w.facts.query("POL_MARTYR_CAMPAIGN").size() - n0, 1, "the story is told")
	var told := w.facts.query("POL_MARTYR_CAMPAIGN").back() as Dictionary
	check(NewsText.sentence(w, told).contains("arrest its leader Ada Berg"), "the news names the leader: " + NewsText.sentence(w, told))
	w.month += 1
	e["momentum"] = 0
	Campaign._persecution(w, st, c)
	check_eq(w.facts.query("POL_MARTYR_CAMPAIGN").size() - n0, 1, "told once per campaign")
	check(int(e["momentum"]) > 0 and int(e["momentum"]) < Campaign.MARTYR_REVEAL, "sympathy, no second jolt")
	w.month += 23
	check(absf(float(Campaign.martyrs(w)[victim]["heat"]) - 0.5) < 1e-6, "half after two years")
	w.meta["off"] = ["MARTYR"]
	check(Campaign.martyrs(w).is_empty(), "A/B switch turns it off")
	w.meta.erase("off")
	w.month += 24
	check(Campaign.martyrs(w).is_empty(), "gone after a term")


func test_they_jailed_our_leader() -> void:
	var r := _campaign()
	var w: WorldState = r[0].world
	var c: Dictionary = r[1]
	var ps := PartyLife.active(w)
	var pm := String(ps[0]["id"])
	var victim := String(ps[1]["id"])
	_gov(w, [pm])
	_order(w, victim)
	var e: Dictionary = c["parties"][victim]
	e["target"] = pm
	e["tone"] = "NEGATIVE"
	e["manual"] = true
	e["attacks"] = 0
	e.erase("ad_target")
	var mom0 := int(c["parties"][pm]["momentum"])
	var n0 := w.facts.query("POL_ATTACK_AD").size()
	var sp := {}
	for q in c["parties"]:
		sp[q] = {"ad": 1000, "ground": 0, "oppo": 0}
	Campaign._ads(w, c, Campaign.segments(w), sp)
	var ads := w.facts.query("POL_ATTACK_AD").slice(n0).filter(func(f): return String(f["data"]["party"]) == victim)
	check_eq(ads.size(), 1, "one attack ad fact")
	if ads.size() == 1:
		check(not ads[0]["data"].get("jailed", {}).is_empty(), "the ad carries the line")
		check(NewsText.sentence(w, ads[0]).contains("they jailed our leader"), "the news quotes it: " + NewsText.sentence(w, ads[0]))
	check(int(c["parties"][pm]["momentum"]) <= mom0 + Campaign.JAILED_LINE, "the line hurts the jailers")
	# a new government did not give the order: sympathy stays, the line has no one to hit
	var other := String(ps[2]["id"])
	var st := _gov(w, [other])
	st["government"]["formed_month"] = w.month + 1
	check_eq(String(Campaign.martyrs(w)[victim]["pm"]), "", "the jailers are gone")


func test_a_detention_is_an_allegation_and_the_leader_is_off_stage() -> void:
	var r := _campaign()
	var w: WorldState = r[0].world
	var c: Dictionary = r[1]
	var ps := PartyLife.active(w)
	var pm := String(ps[0]["id"])
	var victim := String(ps[1]["id"])
	var st := _gov(w, [pm])
	var aid := w.add_fact({"type": "LAW_POLITICAL_ARREST", "owner": "law", "subjects": [{"kind": "PARTY", "id": victim}],
		"responsible": [], "impact": {}, "magnitude": 55, "visibility": "PUBLIC",
		"data": {"party": victim, "person": "", "name": "Ada Berg", "pretext": "tax fraud", "months": 3, "until": w.month + 3}})
	var lt := w.table("law_state")
	if not lt.has("s"):
		lt["s"] = {}
	if not (lt["s"] as Dictionary).has("police"):
		lt["s"]["police"] = {}
	lt["s"]["police"]["detained"] = {aid: {"party": victim, "person": "", "name": "Ada Berg", "until": w.month + 3, "order": ""}}
	check_eq(String(Campaign.held_leaders(w).get(victim, "")), "Ada Berg", "the leader is held")
	var e: Dictionary = c["parties"][victim]
	e["momentum"] = 0
	var n0 := w.facts.query("POL_PERSECUTION_ALLEGED").size()
	Campaign._persecution(w, st, c)
	check_eq(int(e["momentum"]), Campaign.PERSECUTION_CLAIM + Campaign.PERSECUTION_MONTHLY, "allegation plus a statement")
	var al := w.facts.query("POL_PERSECUTION_ALLEGED").slice(n0)
	check_eq(al.size(), 1, "the party alleges persecution")
	if al.size() == 1:
		check_eq(String(al[0]["data"]["by"]), pm, "against the government")
		check(NewsText.sentence(w, al[0]).contains("political persecution"), "the news says so: " + NewsText.sentence(w, al[0]))
	check(not Campaign._stage_parties(w, c).any(func(p): return String(p["id"]) == victim), "a held leader can't take the stage")
	w.month += 1
	e["momentum"] = 0
	Campaign._persecution(w, st, c)
	check_eq(int(e["momentum"]), Campaign.PERSECUTION_MONTHLY, "only statements the month after")
	check_eq(w.facts.query("POL_PERSECUTION_ALLEGED").size() - n0, 1, "alleged once")

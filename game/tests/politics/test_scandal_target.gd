extends TestCase
## A press scandal draws fire (Ella; Wilma/Anni review: 1 of 4 press-hit parties drew an attack ad): attack and
## oppo-research targets weight recent POL_SCANDAL_REVEALED (DONATION or FAVOUR), fading over 24 months.
## Symmetric: any party hit, any attacker; a governing party only spares its own partners. A 2-4 year old scandal
## keeps 30% (SCANDAL_FLOOR), pushes the attacker's tone, and the first attack ad names it ("recalls").


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
	check(float(Campaign.scandal_heat(w).get(pid, 0.0)) < 0.6 + h0, "half gone after a year")
	w.month += 12
	check(absf(float(Campaign.scandal_heat(w).get(pid, 0.0)) - Campaign.SCANDAL_FLOOR) < 0.05 + h0, "a floor of 30% remembered after two years")
	w.month += 24
	check(float(Campaign.scandal_heat(w).get(pid, 0.0)) == 0.0, "forgotten after four")
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


func test_a_scandal_pushes_tone_and_the_ad_names_it() -> void:
	var sim := PoliticalSim.make(3, "BALANCED", {})
	var w := sim.world
	# run into a campaign
	while Campaign.current(w).is_empty() and w.month < 200:
		sim.run(1)
	var c := Campaign.current(w)
	check(not c.is_empty(), "a campaign is running")
	var st: Dictionary = w.table("pol")["state"]
	var p: Dictionary = PartyLife.active(w)[0]
	var e: Dictionary = c["parties"][p["id"]]
	e["manual"] = false
	if String(e["target"]) == "":
		e["target"] = PartyLife.active(w)[1]["id"]
	var tgt := String(e["target"])
	p["leader"]["integrity"] = 60          # n = 0.2 - 0.3 + ... : MIXED or POSITIVE before the scandal
	Campaign._set_tone(w, st, c, p, e)
	var t0 := Campaign.TONES.find(String(e["tone"]))
	_scandal(w, tgt, 100)
	Campaign._set_tone(w, st, c, p, e)
	check(Campaign.TONES.find(String(e["tone"])) >= t0, "no softer after the target's scandal")
	w.meta["off"] = ["SCANDAL_FIRE"]
	check(Campaign.scandal_heat(w).is_empty(), "A/B switch turns it off")
	w.meta.erase("off")
	# the first attack ad of the campaign names the scandal
	e["tone"] = "NEGATIVE"
	e["manual"] = true
	e["attacks"] = 0
	var n0 := w.facts.query("POL_ATTACK_AD").size()
	var sp := {}
	for q in c["parties"]:
		sp[q] = {"ad": 1000, "ground": 0, "oppo": 0}
	Campaign._ads(w, c, Campaign.segments(w), sp)
	var named := w.facts.query("POL_ATTACK_AD").slice(n0).filter(func(f): return String(f["data"]["party"]) == String(p["id"]))
	check_eq(named.size(), 1, "one attack ad fact")
	if named.size() == 1:
		check_eq(String(named[0]["data"].get("recalls", {}).get("kind", "")), "DONATION", "it recalls the donation scandal")
		check(NewsText.sentence(w, named[0]).contains("reminding voters"), "the news says so")


# ---- revived scandals (Anni's press emits MEDIA_SCANDAL_REVIVED / _BURIED; opt-in "SCANDAL_REVIVAL") ----

func _revive(w: WorldState, pid: String, scandal: String, n: int, strength: int, escalated: bool = false) -> String:
	return w.add_fact({"type": "MEDIA_SCANDAL_REVIVED", "owner": "media", "subjects": [{"kind": "PARTY", "id": pid}],
		"responsible": [], "impact": {}, "magnitude": 30, "visibility": "PUBLIC",
		"data": {"party": pid, "scandal": scandal, "kind": "DONATION", "outlet": "out:x", "n": n, "strength_pm": strength,
			"escalated": escalated, "trigger": "NONE", "person": "", "dragged": ""}})


func _bury(w: WorldState, pid: String, scandal: String, rev: String, strength: int) -> void:
	w.add_fact({"type": "MEDIA_SCANDAL_BURIED", "owner": "media", "subjects": [{"kind": "PARTY", "id": pid}],
		"responsible": [], "impact": {}, "magnitude": 20, "visibility": "PUBLIC",
		"data": {"party": pid, "scandal": scandal, "revival": rev, "outlet": "out:y", "strength_pm": strength}})


## A sim with one old (forgotten) severity-50 scandal on a party; returns [world, pid, scandal fid].
func _old_scandal() -> Array:
	var w := _sim().world
	var pid := String(PartyLife.active(w)[0]["id"])
	_scandal(w, pid, 50)
	var fid := String(w.facts.query("POL_SCANDAL_REVEALED").back()["id"])
	w.month += Campaign.SCANDAL_MEMORY + 12
	return [w, pid, fid]


func _h(w: WorldState, pid: String) -> float:
	return float(Campaign.scandal_heat(w).get(pid, 0.0))


func test_a_paper_revives_a_forgotten_scandal_and_it_fades_again() -> void:
	var r := _old_scandal()
	var w: WorldState = r[0]
	var pid: String = r[1]
	var h0 := _h(w, pid)
	_revive(w, pid, r[2], 1, 500)
	check_eq(_h(w, pid), h0, "opt-in: nothing without the switch")
	w.meta["on"] = ["SCANDAL_REVIVAL"]
	check(absf(_h(w, pid) - h0 - 0.5) < 1e-6, "back to 50% of the peak at strength 500 (%f)" % (_h(w, pid) - h0))
	var m: Dictionary = Campaign.scandal_memory(w)[pid]
	check_eq(String(m["outlet"]), "out:x", "remembered as the paper's story")
	check_eq(String(m["fid"]), String(r[2]), "the original scandal")
	check(Campaign.pick_target(w, _gov(w, [String(PartyLife.active(w)[1]["id"])]), PartyLife.active(w)[2]) != "", "still a target")
	w.month += Campaign.SCANDAL_WINDOW
	check_eq(_h(w, pid), 0.0, "fades again at the normal rate")


func test_repeat_revivals_diminish_burying_slows_escalation_bites() -> void:
	var r := _old_scandal()
	var w: WorldState = r[0]
	var pid: String = r[1]
	w.meta["on"] = ["SCANDAL_REVIVAL"]
	var h0 := _h(w, pid)
	var rid := _revive(w, pid, r[2], 1, 0)
	var first := _h(w, pid) - h0
	check(absf(first - 0.4) < 1e-6, "40% at strength 0")
	w.month += Campaign.SCANDAL_WINDOW
	h0 = _h(w, pid)
	_revive(w, pid, r[2], 3, 0)
	check(absf(_h(w, pid) - h0 - 0.4 * 0.5) < 1e-6, "the third revival is half as hot")
	w.month += Campaign.SCANDAL_WINDOW
	h0 = _h(w, pid)
	rid = _revive(w, pid, r[2], 1, 0)
	_bury(w, pid, r[2], rid, 1000)
	var buried := _h(w, pid) - h0
	check(absf(buried - 0.2) < 1e-6, "a full bury halves it")
	check(buried > 0.0, "no immunity")
	w.month += Campaign.SCANDAL_WINDOW
	h0 = _h(w, pid)
	_revive(w, pid, r[2], 1, 0, true)
	check(_h(w, pid) - h0 > 1.0, "escalated: hotter than the original")


func test_the_attack_ad_cites_the_paper() -> void:
	var sim := PoliticalSim.make(3, "BALANCED", {})
	var w := sim.world
	w.meta["on"] = ["SCANDAL_REVIVAL"]
	while Campaign.current(w).is_empty() and w.month < 200:
		sim.run(1)
	var c := Campaign.current(w)
	check(Campaign.months_to_election(w) >= 0 and Campaign.months_to_election(w) <= Campaign.WINDOW_ORDINARY, "in the election window")
	var p: Dictionary = PartyLife.active(w)[0]
	var e: Dictionary = c["parties"][p["id"]]
	if String(e["target"]) == "":
		e["target"] = PartyLife.active(w)[1]["id"]
	var tgt := String(e["target"])
	_scandal(w, tgt, 50)
	var fid := String(w.facts.query("POL_SCANDAL_REVEALED").back()["id"])
	w.month += 1
	_revive(w, tgt, fid, 1, 500)
	e["tone"] = "NEGATIVE"
	e["manual"] = true
	e["attacks"] = 0
	var n0 := w.facts.query("POL_ATTACK_AD").size()
	var sp := {}
	for q in c["parties"]:
		sp[q] = {"ad": 1000, "ground": 0, "oppo": 0}
	Campaign._ads(w, c, Campaign.segments(w), sp)
	var ads := w.facts.query("POL_ATTACK_AD").slice(n0).filter(func(f): return String(f["data"]["party"]) == String(p["id"]))
	check_eq(ads.size(), 1, "an attack ad")
	if ads.size() == 1:
		check_eq(String(ads[0]["data"]["recalls"].get("outlet", "")), "out:x", "cites the paper")
		check(NewsText.sentence(w, ads[0]).contains("dug up again"), NewsText.sentence(w, ads[0]))

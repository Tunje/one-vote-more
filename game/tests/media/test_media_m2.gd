extends TestCase
## MEDIA v1 M2 (planning/spec-media-v1.md §3.3–3.4, §5, §6, §8): lies, exposure, corrections, defamation,
## censorship and press investigations. PD tests 13 (misinformation) and 14 (correction).

const LawOps := preload("res://sim/law/law_ops.gd")
const JO := preload("res://sim/law/justice_ops.gd")
const RE := preload("res://sim/law/rules_engine.gd")

const LEFT := {"ECON_ROLE": 60000, "REDISTRIBUTION": 60000, "LABOR": 60000}


func _line(d: Dictionary) -> Dictionary:
	var l := {}
	for ax in PolDefs.AXES:
		l[ax] = int(d.get(ax, 0))
	return l


func _world() -> WorldState:
	var w := WorldState.new(5)
	LawOps.init_world(w)
	w.month = 5
	w.table("party")["party:1"] = {"id": "party:1", "name": "Labour", "positions": _line(LEFT), "status": "ACTIVE"}
	w.table("party")["party:2"] = {"id": "party:2", "name": "Business", "positions": Media._vec(PolDefs.OCC_IDEOLOGY["BUSINESS_OWNER"]), "status": "ACTIVE"}
	Media.ensure_founding(w)
	for id in Media.outlets(w):
		w.table("outlet")[id]["reach"] = []          # keep the Gazette out of these tests
	return w


func _cell(w: WorldState, key: String, district: String, ideology: Dictionary, pop: int = 1000) -> Dictionary:
	var sal := {}
	for c in PolDefs.CONCERNS:
		sal[c] = 100
	var c := {"key": key, "district": district, "band": "MID", "pop": pop, "occ": "SERVICES", "ideology": _line(ideology), "salience": sal}
	w.table("cell")[key] = c
	return c


func _party_paper(w: WorldState) -> String:
	return Media.found_outlet(w, {"kind": "PARTY", "id": "party:1"}, {"line": _line(LEFT), "ethics": 0.0, "quality": 100,
		"reach": ["district:1"]})["out_id"]


func _false_reports(w: WorldState) -> Array:
	return w.peek("report").values().filter(func(r): return r["truth"] == "FALSE")


func test_misinformation_changes_beliefs_not_facts() -> void:
	var w := _world()
	var pp := _party_paper(w)
	var reader := _cell(w, "r", "district:1", LEFT)
	var other := _cell(w, "o", "district:2", LEFT)
	w.meta["media_p_fabricate"] = 10.0
	Media.run(w)
	var fr := _false_reports(w)
	check_eq(fr.size(), 1, "one fabricated story")
	check(fr[0]["claim"]["victim"] == {"kind": "PARTY", "id": "party:2"}, "aimed at the paper's chief opponent")
	var lies := w.facts.query("MEDIA_FALSE_REPORT")
	check(lies.size() == 1 and lies[0]["visibility"] == "SECRET", "the lie is recorded as a SECRET fact")
	check(int(reader["news_bias"].get("GOVERNANCE", 0)) < 0, "readers believe it (%s)" % [reader["news_bias"]])
	check(other.get("news_bias", {}).is_empty(), "people who never read it do not")
	check(w.facts.query("", -1, 1 << 30, "PUBLIC").filter(func(f): return String(f["type"]).begins_with("MEDIA_FALSE")).is_empty(),
		"no public fact says it happened")
	var ed := MediaQuery.edition(w, pp, w.month)
	check(ed["stories"].any(func(s): return s["fact"] == "" and not s["exposed"]), "printed like any story (truth hidden)")


func test_correction_revises_part_of_the_belief() -> void:
	var w := _world()
	var pp := _party_paper(w)
	var reader := _cell(w, "r", "district:1", LEFT)
	w.meta["media_p_fabricate"] = 10.0
	Media.run(w)
	w.meta["media_p_fabricate"] = 0.0
	var b0 := int(reader["news_bias"]["GOVERNANCE"])
	var fid: String = w.facts.query("MEDIA_FALSE_REPORT")[0]["id"]
	check(Media.expose_lie(w, fid, "COMPLAINT"), "exposed")
	check(not w.facts.query("MEDIA_REPORT_EXPOSED").is_empty(), "public exposure")
	check(int(w.peek("outlet")[pp]["cred"]) <= 55000 - 15000, "deliberate lie: -15 credibility")
	w.month += 1
	Media.run(w)
	var ed := MediaQuery.edition(w, pp, w.month)
	check(ed["stories"][0]["kind"] == "CORRECTION", "correction on the front page (duty)")
	var b1 := int(reader["news_bias"].get("GOVERNANCE", 0))
	var decay_only := int(round(b0 * 0.75))
	check(b1 > decay_only, "the correction revises beliefs (%d vs %d decay only)" % [b1, decay_only])
	check(b1 < 0, "but not everyone accepts it (%d)" % b1)
	check(MediaQuery.edition(w, pp, w.month - 1)["stories"].any(func(s): return s["exposed"] and s["corrected"]),
		"the old edition is stamped exposed and corrected")


func test_deliberate_lie_costs_more_than_a_corrected_error() -> void:
	var w := _world()
	var a := _party_paper(w)
	var b: String = Media.found_outlet(w, {"kind": "UNION", "id": "union:fed"}, {"ethics": 0.8})["out_id"]
	var lies := w.table("media_lie")
	lies["X1"] = {"fid": "X1", "outlet": a, "report": "", "victim": {}, "truth": "FALSE", "deliberate": true, "month": 5,
		"magnitude": 30, "claim_bias": {}, "revealed": false}
	lies["X2"] = {"fid": "X2", "outlet": b, "report": "", "victim": {}, "truth": "ERROR", "deliberate": false, "month": 5,
		"magnitude": 30, "claim_bias": {}, "revealed": false}
	w.table("revealed_fact")["X1"] = true
	w.table("revealed_fact")["X2"] = true
	var ca := int(w.peek("outlet")[a]["cred"])
	var cb := int(w.peek("outlet")[b]["cred"])
	Media.expose_lie(w, "X1", "RIVAL", b)
	Media.expose_lie(w, "X2", "COMPLAINT")
	var ha := ca - int(w.peek("outlet")[a]["cred"])
	var hb := cb - int(w.peek("outlet")[b]["cred"])
	check(ha >= 3 * hb and hb > 0, "fabrication %d vs prompt correction %d" % [ha, hb])
	check(w.peek("outlet")[b]["scoops"].size() == 1, "the debunk is the rival's scoop")


func test_defamation_depends_on_the_standard() -> void:
	var w := _world()
	var pp := _party_paper(w)
	var lies := w.table("media_lie")
	for x in [["F", "FALSE"], ["M", "MISLEADING"]]:
		lies[x[0]] = {"fid": x[0], "outlet": pp, "report": "", "victim": {"kind": "PARTY", "id": "party:2"}, "truth": x[1],
			"deliberate": true, "month": 5, "magnitude": 50, "claim_bias": {}, "revealed": false}
		w.table("revealed_fact")[x[0]] = true
	Media.expose_lie(w, "F", "COMPLAINT")
	Media.expose_lie(w, "M", "COMPLAINT")
	check(lies["F"].has("case") and not lies["M"].has("case"), "actual malice: sued over the lie, not the spin")
	var c: Dictionary = w.peek("case")[lies["F"]["case"]]
	check(c["type"] == "DEFAMATION" and c["respondent"] == {"kind": "OUTLET", "id": pp} and c["truth"], "case against the paper")
	w.levers["LAW_DEFAMATION_STANDARD"] = "STRICT"
	lies["M2"] = {"fid": "M2", "outlet": pp, "report": "", "victim": {"kind": "PARTY", "id": "party:2"}, "truth": "MISLEADING",
		"deliberate": true, "month": 5, "magnitude": 50, "claim_bias": {}, "revealed": false}
	w.table("revealed_fact")["M2"] = true
	Media.expose_lie(w, "M2", "COMPLAINT")
	check(lies["M2"].has("case") and w.peek("case")[lies["M2"]["case"]]["truth"], "strict: liable for misleading too")
	# damages come from the paper's account
	w.ledger.open_account("party:party:2")     # party accounts are "party:" + party id
	w.ledger.transfer(Ledger.EXTERNAL, "media:" + pp, 5000, "seed", w.month)
	JO._pay(w, {"kind": "OUTLET", "id": pp}, {"kind": "PARTY", "id": "party:2"}, 3000, "DAMAGES")
	check_eq(w.ledger.balance("party:party:2"), 3000, "damages paid by the outlet")
	w.table("outlet")[pp]["cred"] = 40000
	var cr := 40000
	Media.on_defamation_verdict(w, pp, true)
	check(int(w.peek("outlet")[pp]["cred"]) < cr, "a conviction costs credibility")


func test_censorship_only_in_a_declared_emergency() -> void:
	var w := _world()
	Media.ensure_rules(w)
	var gz: String = Media.outlets(w)[0]
	w.table("outlet")[gz]["reach"] = "ALL"
	_cell(w, "c", "district:1", {})
	w.levers["LAW_EMERGENCY_PRESS_CONTROL"] = true
	check(not Media.censorship_active(w), "no emergency: censorship is unlawful even with the lever")
	check_eq(RE.validate(w, {"kind": "COMMANDER", "id": "commander"}, "CENSOR_REPORT", {})["result"], "PROHIBITED",
		"public actors need an authorisation (default deny)")
	LawOps.state(w)["emergency"] = {"active": true}
	check(Media.censorship_active(w), "declared emergency + press control: lawful")
	var bad := w.add_fact({"type": "ECON_SHORTAGE", "owner": "t", "subjects": [], "responsible": [{"actor": {"kind": "GOVERNMENT", "id": "government"}, "share": 1.0}],
		"impact": {"COST_OF_LIVING": -4}, "magnitude": 60, "visibility": "PUBLIC"})
	Media.run(w)
	check(not (bad in MediaQuery.edition(w, gz, w.month)["stories"].map(func(s): return s["fact"])), "the censor strikes the story")
	var cf := w.facts.query("MEDIA_CENSORED")
	check(cf.size() == 1 and cf[0].has("exposure") and cf[0]["exposure"]["kind"] == "PRESS_RESTRICTION", "recorded, with exposure for S4")
	w.levers["LAW_EMERGENCY_PRESS_CONTROL"] = false
	check(not Media.censorship_active(w), "lever off: prohibited again")


func test_press_investigation_reveals_misconduct() -> void:
	var w := _world()
	JO.init_courts(w)       # in a game Justice.run (earlier in JUSTICE) has set them up
	var vid := LawOps.record_greed(w, "org:5", {"kind": "SAFETY_CORNERS", "facility": "f:1"})
	check(w.peek("violation_track")[vid]["unlawful"] and not w.peek("violation_track")[vid]["revealed"], "hidden unlawful practice")
	var pp: String = Media.found_outlet(w, {"kind": "UNION", "id": "union:fed"}, {"invest": 5.0, "line": _line(LEFT)})["out_id"]
	w.levers["LAW_FOI"] = true
	var found := false
	for i in 40:
		w.month += 1
		Media.run(w)
		if w.peek("violation_track")[vid]["revealed"]:
			found = true
			break
	check(found, "the paper digs it up")
	check_eq(w.peek("violation_track")[vid]["channel"], "PRESS", "through the press channel")
	var ed := MediaQuery.edition(w, pp, w.month)
	check(ed["stories"].any(func(s): return s["kind"] == "INVESTIGATION"), "run as the paper's own investigation")
	check(int(MediaQuery.investigations(w).get("VIOLATION", 0)) >= 1 and int(Media.outlet(w, pp).get("investigations", 0)) >= 1,
		"counted for good (the fact itself is compacted after 24 months)")


## v5: exposure windows — victims complain while a story is fresh, rivals check recent stories, insiders leak only
## lies. An honest error past both windows is never exposed; a fresh lie with a motivated victim usually is.
func test_old_errors_are_not_exposed_fresh_lies_are() -> void:
	var w := _world()
	w.levers["LAW_WHISTLEBLOWER_PROTECTION"] = true
	var a := _party_paper(w)
	Media.found_outlet(w, {"kind": "COMPANY", "id": "org:9"}, {"invest": 3.0})     # an eager rival
	var lies := w.table("media_lie")
	var victim := {"kind": "PARTY", "id": "party:2"}
	for i in 40:
		lies["E%d" % i] = {"fid": "E%d" % i, "outlet": a, "report": "", "victim": victim, "truth": "ERROR", "deliberate": false,
			"month": w.month - 8, "magnitude": 50, "claim_bias": {}, "revealed": false}
		lies["F%d" % i] = {"fid": "F%d" % i, "outlet": a, "report": "", "victim": victim, "truth": "FALSE", "deliberate": true,
			"month": w.month, "magnitude": 50, "claim_bias": {}, "revealed": false}
		w.table("revealed_fact")["E%d" % i] = true
		w.table("revealed_fact")["F%d" % i] = true
	for m in 3:
		Media._expose(w)
		w.month += 1
	var old := 0
	var fresh := 0
	for k in lies:
		if bool(lies[k]["revealed"]):
			if String(k).begins_with("E"):
				old += 1
			else:
				fresh += 1
	check_eq(old, 0, "an honest error eight months on: nobody looks any more")
	check(fresh >= 25, "fresh lies with a motivated victim and an eager rival are mostly exposed (%d/40)" % fresh)

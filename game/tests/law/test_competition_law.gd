extends TestCase
## Company rivalry law step 1: levers, readers and the conduct kinds (dominance-conditioned), neutral until reported.

const F := preload("res://tests/support/staff_fixture.gd")
const LawOps := preload("res://sim/law/law_ops.gd")
const CL := preload("res://sim/law/competition_law.gd")
const PF := preload("res://sim/law/party_finance.gd")


func _world() -> WorldState:
	var w := F.bare_world()
	LawOps.init_world(w)
	LawOps.ensure_m11_rules(w)
	LawOps.ensure_competition_rules(w)
	return w


func test_levers_and_open_frontier_defaults() -> void:
	var w := _world()
	for id in ["LAW_DOMINANCE_SHARE", "LAW_MERGER_THRESHOLD", "LAW_EXCLUSIVE_DEALING", "LAW_LOBBY_REGISTER"]:
		check(w.lever_defs.has(id) and String(w.lever_defs[id]["type"]) == "NUMBER" and bool(w.lever_defs[id]["legislative"]), id + " is draftable")
		check(int(w.lever_defs[id]["concerns"].get("JOBS", 0)) != 0, id + ": the jobs argument is on the table")
	check(not CL.needs_review(w, 900), "no merger review at the founding")
	check(CL.exclusive_allowed(w, 900) and CL.lobby_mode(w) == "NONE", "exclusive deals and lobbying are free")
	check(CL.dominant(w, 500) and not CL.dominant(w, 499), "dominant from 50%")
	w.levers["LAW_MERGER_THRESHOLD"] = 40
	check(CL.needs_review(w, 410) and not CL.needs_review(w, 400), "review above 40%")


func test_predation_is_unlawful_only_for_a_dominant_firm() -> void:
	var w := _world()
	var big := LawOps.record_greed(w, "org:1", {"kind": "PREDATORY_PRICING", "market": "FOOD", "rival": "org:2", "dominant": true, "saving": 0})
	var small := LawOps.record_greed(w, "org:3", {"kind": "PREDATORY_PRICING", "market": "FOOD", "rival": "org:2", "dominant": false, "saving": 0})
	check(bool(w.peek("violation_track")[big]["unlawful"]), "a dominant firm pricing below cost: unlawful")
	check(not bool(w.peek("violation_track")[small]["unlawful"]), "a small firm's price war: lawful")
	check_eq(String(w.peek("violation_track")[big]["channel"]), "MARKET", "the competition authority's case")
	w.levers["LAW_COMPETITION"] = "NONE"
	var none := LawOps.record_greed(w, "org:4", {"kind": "ABUSE_DOMINANCE", "market": "FOOD", "dominant": true, "saving": 0})
	check(not bool(w.peek("violation_track")[none]["unlawful"]), "no competition law: anything goes")


func test_exclusive_dealing_and_lobbying_follow_their_levers() -> void:
	var w := _world()
	var a := LawOps.record_greed(w, "org:1", {"kind": "EXCLUSIVE_DEALING", "dominant": true, "saving": 0})
	check(not bool(w.peek("violation_track")[a]["unlawful"]), "allowed by default")
	w.levers["LAW_EXCLUSIVE_DEALING"] = 1
	var b := LawOps.record_greed(w, "org:2", {"kind": "EXCLUSIVE_DEALING", "dominant": true, "saving": 0})
	var c := LawOps.record_greed(w, "org:3", {"kind": "EXCLUSIVE_DEALING", "dominant": false, "saving": 0})
	check(bool(w.peek("violation_track")[b]["unlawful"]) and not bool(w.peek("violation_track")[c]["unlawful"]), "banned for the dominant only")
	w.levers["LAW_LOBBY_REGISTER"] = 1
	var l := LawOps.record_greed(w, "org:4", {"kind": "UNREGISTERED_LOBBYING", "saving": 0})
	check(bool(w.peek("violation_track")[l]["unlawful"]), "a register: lobbying without it is unlawful")


func _gov(w: WorldState, econ_role: int, autoplay: bool) -> void:
	w.table("party")["P1"] = {"id": "P1", "name": "Gov", "status": "ACTIVE", "positions": {"ECON_ROLE": econ_role}}
	F.set_pol(w, {"era": "PARLIAMENTARY", "player_party": "P1", "autoplay_player": autoplay,
		"government": {"members": ["P1"], "pm_party": "P1"}})


func test_small_takeovers_clear_big_ones_are_reviewed() -> void:
	var w := _world()
	_gov(w, 0, true)
	check_eq(String(CL.request_takeover(w, {"buyer": "org:1", "target": "org:2", "market": "FOOD", "share_after_pm": 800})["status"]), "CLEARED", "no merger law: cleared")
	w.levers["LAW_MERGER_THRESHOLD"] = 40
	var r := CL.request_takeover(w, {"buyer": "org:1", "target": "org:3", "market": "FOOD", "share_after_pm": 750})
	check_eq(String(r["status"]), "REVIEW", "75% of the market: reviewed")
	check_eq(String(CL.takeover_status(w, r["id"])["recommendation"]), "BLOCK", "the authority would block it")
	w.month = int(r["due"])
	CL.monthly(w)
	check_eq(String(CL.takeover_status(w, r["id"])["status"]), "BLOCKED", "a centrist government follows its authority")
	check(w.facts.query("LAW_TAKEOVER_OVERRIDDEN").is_empty(), "no override")


func test_a_market_government_overrides_its_authority() -> void:
	var w := _world()
	_gov(w, -80000, true)
	w.levers["LAW_MERGER_THRESHOLD"] = 40
	var r := CL.request_takeover(w, {"buyer": "org:1", "target": "org:2", "market": "FOOD", "share_after_pm": 600})
	check_eq(String(CL.takeover_status(w, r["id"])["recommendation"]), "CONDITIONS", "the authority wants conditions")
	w.month = int(r["due"])
	CL.monthly(w)
	check_eq(String(CL.takeover_status(w, r["id"])["status"]), "CLEARED", "a market government waves it through")
	var o: Array = w.facts.query("LAW_TAKEOVER_OVERRIDDEN")
	check(o.size() == 1 and bool(o[0]["data"]["softer"]), "the override is public, softer than advised")


func test_the_player_decides_on_an_office_item() -> void:
	var w := _world()
	_gov(w, 0, false)
	w.levers["LAW_MERGER_THRESHOLD"] = 40
	var r := CL.request_takeover(w, {"buyer": "org:1", "target": "org:2", "market": "FOOD", "share_after_pm": 650, "jobs": 40})
	w.month = int(r["due"])
	CL.monthly(w)
	var row := CL.takeover_status(w, r["id"])
	var it := Office.get_item(w, String(row["item"]))
	check(not it.is_empty() and String(it["kind"]) == "CALL" and String(it["category"]) == "COMPETITION", "a CALL for a big deal")
	check_eq(String(it["default_option"]), "CONDITIONS", "left alone, the authority's advice stands")
	Office.answer(w, String(row["item"]), "BLOCK")
	CL.monthly(w)
	check_eq(String(CL.takeover_status(w, r["id"])["status"]), "BLOCKED", "the player's answer applies")
	check_eq(w.facts.query("LAW_TAKEOVER_OVERRIDDEN").size(), 1, "stricter than advised is public too")


func _donation(w: WorldState, org: String, party: String, amount: int, vis: String) -> String:
	var pref := {"kind": "PARTY", "id": party}
	return w.add_fact({"type": "POL_DONATION", "owner": "pol", "subjects": [pref], "responsible": [{"actor": pref, "share": 1.0}],
		"impact": {}, "magnitude": 20, "visibility": vis, "data": {"donor": org, "party": party, "amount": amount, "lawful": true, "cap": -1}})


func test_asks_carry_the_donors_money() -> void:
	var w := _world()
	_gov(w, 0, true)
	_donation(w, "org:5", "P1", 3 * 1200000, "PUBLIC")
	CL.lobby(w, "org:5", "P1", {"lever": "LAW_LUXURY_TAX", "dir": -1})
	CL.lobby(w, "org:6", "gov", {"contract": "bridge"})
	var asks := CL.open_asks(w, "P1")
	check_eq(asks.size(), 2, "a direct ask and an ask to the government P1 leads")
	check_eq(int(asks[0]["donated_24m"]), 3 * 1200000, "with what the org gave P1")
	check_eq(int(asks[1]["donated_24m"]), 0, "nothing from org:6")
	check(CL.open_asks(w, "P2").is_empty(), "nothing for a party outside government")


func test_a_hidden_donation_for_a_granted_ask_is_a_favour() -> void:
	var w := _world()
	_gov(w, 0, true)
	w.values["ECON_W_REF"] = 1200000
	w.levers["LAW_LOBBY_REGISTER"] = 2
	var ask := CL.lobby(w, "org:5", "P1", {"lever": "LAW_LUXURY_TAX", "dir": -1})
	w.levers["LAW_LUXURY_TAX"] = int(w.levers["LAW_LUXURY_TAX"]) - 5
	_donation(w, "org:5", "P1", 2 * 1200000, "SECRET")
	for i in CL.FAVOUR_WINDOW + 1:
		CL.monthly(w)
		w.month += 1
	var rows := w.peek("donation_track").values().filter(func(t): return String(t.get("kind", "")) == "FAVOUR")
	check_eq(rows.size(), 1, "a disclosure law and a secret gift: an undisclosed favour")
	check(String(rows[0]["ask"]) == ask and bool(rows[0]["undisclosed"]), "tied to the ask")
	check(PF.severity(w, rows[0]) >= 70, "money for a decision is a grave scandal (%d)" % PF.severity(w, rows[0]))


func test_a_big_gift_for_a_granted_contract_is_a_bribe_under_any_law() -> void:
	var w := _world()
	_gov(w, 0, true)
	w.values["ECON_W_REF"] = 1200000
	var ask := CL.lobby(w, "org:7", "gov", {"contract": "harbour"})
	CL.granted(w, ask)
	_donation(w, "org:7", "P1", 25 * 1200000, "PUBLIC")
	_donation(w, "org:8", "P1", 25 * 1200000, "PUBLIC")
	for i in CL.FAVOUR_WINDOW + 1:
		CL.monthly(w)
		w.month += 1
	var rows := w.peek("donation_track").values().filter(func(t): return String(t.get("kind", "")) == "FAVOUR")
	check(rows.size() == 1 and bool(rows[0]["bribe"]) and String(rows[0]["donor"]) == "org:7", "25 W_ref for the harbour contract: a bribe")


func test_unregistered_lobbying_under_a_register() -> void:
	var w := _world()
	w.levers["LAW_LOBBY_REGISTER"] = 1
	CL.lobby(w, "org:9", "P1", {"subsidy": "MINING"}, {"registered": false})
	var v := w.peek("violation_track").values().filter(func(x): return String(x["kind"]) == "UNREGISTERED_LOBBYING")
	check(v.size() == 1 and bool(v[0]["unlawful"]), "an unregistered lobbyist is a case for the authority")
	w.levers["LAW_LOBBY_REGISTER"] = 2
	CL.lobby(w, "org:9", "P1", {"subsidy": "MINING"})
	check_eq(w.facts.query("LAW_LOBBY_DISCLOSED").size(), 1, "full disclosure: the ask is public")

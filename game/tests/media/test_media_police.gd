extends TestCase
## P1c press: papers investigate police misconduct (violation_track, POLICE kinds) and the government's secret unlawful
## acts (unlawful_track, e.g. a POLITICAL_ARREST order); reveals run the usual law chains with channel PRESS.

const F := preload("res://tests/support/staff_fixture.gd")
const LawOps := preload("res://sim/law/law_ops.gd")
const JO := preload("res://sim/law/justice_ops.gd")
const P := preload("res://sim/law/police.gd")
const MS := preload("res://sim/media/media_ops.gd")

const RIGHT := {"ECON_ROLE": -60000, "REDISTRIBUTION": -60000, "LABOR": -60000}


func _line(d: Dictionary) -> Dictionary:
	var l := {}
	for ax in PolDefs.AXES:
		l[ax] = int(d.get(ax, 0))
	return l


func test_papers_expose_police_abuse_and_political_arrests() -> void:
	var w := F.bare_world()
	LawOps.init_world(w)
	LawOps.ensure_m11_rules(w)
	P.ensure_rules(w)
	JO.init_courts(w)
	w.month = 30
	w.meta["on"] = ["POLICE"]
	w.values["ECON_W_REF"] = 1200000
	w.table("party")["party:2"] = {"id": "party:2", "name": "Opposition", "status": "ACTIVE", "support": 30000,
		"positions": _line({}), "leader": {"name": "Ada Opp"}}
	Media.ensure_founding(w)
	var paper: String = Media.found_outlet(w, {"kind": "COMPANY", "id": "org:9"},
		{"name": "The Watch", "line": _line(RIGHT), "invest": 10.0})["out_id"]
	var rec := LawOps.record_greed(w, "org:police", {"kind": "EXCESSIVE_FORCE", "facility": "fac:st1", "district": "d:1"})
	var order := String(P.order_investigation(w, {"kind": "GOVERNMENT", "id": "government"}, {"kind": "PARTY", "id": "party:2"}, "", true)["order"])
	for i in 60:
		w.month += 1
		MS._investigate(w)
		if bool(w.peek("violation_track")[rec]["revealed"]) and bool(w.peek("unlawful_track")[order]["revealed"]):
			break
	check(bool(w.peek("violation_track")[rec]["revealed"]), "the abuse is exposed")
	var mis := w.facts.query("LAW_POLICE_MISCONDUCT_REVEALED", 0, w.month)
	check(mis.size() == 1 and String(mis[0]["data"]["channel"]) == "PRESS", "through the police chain, by the press")
	check(bool(w.peek("unlawful_track")[order]["revealed"]), "the arrest order is exposed")
	check_eq(w.facts.query("LAW_UNLAWFUL_GOV_ACTION_REVEALED", 0, w.month).size(), 1, "the usual reveal fact")
	var inv: Dictionary = Media.state(w).get("investigations", {})
	check(inv.has("POLICE") and inv.has("GOV_ACT"), "counted by target (%s)" % [inv])
	check(String(paper) != "", "paper")

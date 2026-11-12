extends TestCase
## Expedition X4–X5 law side (planning/spec-expedition-v1.md): the funding mix writes the charter; signing applies it.

const F := preload("res://tests/support/staff_fixture.gd")
const LawOps := preload("res://sim/law/law_ops.gd")
const CO := preload("res://sim/law/charter_ops.gd")
const CD := preload("res://sim/law/charter_deal.gd")


func _world() -> WorldState:
	var w := F.bare_world()
	LawOps.init_world(w)
	CO.ensure_m12(w)
	return w


func test_balanced_reproduces_todays_start() -> void:
	var w := _world()
	var t := CD.terms({"HOME_GOV": 400, "INVESTORS": 400, "COLONISTS": 200, "LOANS": 300})
	for lever in CO.CHARTER_LEVERS:
		check_eq(int(t[lever]), int(w.lever_defs[lever]["default"]), lever + " at today's default")
	check(not t["governor"] and t["status"] == "COLONY", "no governor, an ordinary colony")
	check_eq(CD.terms({})["LAW_CHARTER_QUOTA_SHARE"], 40, "no mix: the reference")


func test_home_world_money_buys_a_stricter_charter() -> void:
	var b := CD.terms({"HOME_GOV": 400, "INVESTORS": 400, "COLONISTS": 200})
	var h := CD.terms({"HOME_GOV": 800, "INVESTORS": 150, "COLONISTS": 50})
	check(int(h["LAW_CHARTER_QUOTA_SHARE"]) > int(b["LAW_CHARTER_QUOTA_SHARE"]), "higher quota (%d)" % int(h["LAW_CHARTER_QUOTA_SHARE"]))
	check(int(h["LAW_CHARTER_PRICE_PCT"]) < int(b["LAW_CHARTER_PRICE_PCT"]), "lower charter price (%d)" % int(h["LAW_CHARTER_PRICE_PCT"]))
	check(int(h["LAW_CHARTER_EXPORT_LEVY"]) > 0 and h["governor"], "an export levy and a governor")
	check(int(h["autonomy"]) < int(b["autonomy"]), "less autonomy")


func test_colonists_savings_buy_autonomy() -> void:
	var c := CD.terms({"HOME_GOV": 100, "INVESTORS": 200, "COLONISTS": 700})
	check_eq(String(c["status"]), "AUTONOMY", "the colony starts autonomous (autonomy %d)" % int(c["autonomy"]))
	check(int(c["LAW_CHARTER_QUOTA_SHARE"]) < 40 and int(c["LAW_CHARTER_PRICE_PCT"]) > 35 and not c["governor"], "softer terms (%s)" % [c])


func test_big_investors_get_privileges_and_seats() -> void:
	var t := CD.terms({"HOME_GOV": 300, "INVESTORS": 600, "COLONISTS": 100, "investors": [
		{"id": "house:mining", "sector": "MINING", "amount": 300}, {"id": "house:farm", "sector": "AGRICULTURE", "amount": 200},
		{"id": "house:trade", "sector": "TRADE", "amount": 100}]})
	check_eq(t["privileges"].map(func(p): return p["investor"]), ["house:mining", "house:farm"], "≥ 15%: a sector privilege")
	check_eq(t["council_seats"], ["house:mining"], "≥ 25%: a council seat")


func test_signing_sets_the_charter_once() -> void:
	var w := _world()
	var t := CD.terms({"HOME_GOV": 800, "INVESTORS": 200, "COLONISTS": 0, "investors": [{"id": "house:mining", "sector": "MINING", "amount": 200}]})
	check(CD.sign(w, t)["ok"], "signed")
	check_eq(int(w.levers["LAW_CHARTER_QUOTA_SHARE"]), int(t["LAW_CHARTER_QUOTA_SHARE"]), "quota set")
	check_eq(int(w.levers["LAW_CHARTER_EXPORT_LEVY"]), int(t["LAW_CHARTER_EXPORT_LEVY"]), "levy set")
	check(bool(CO.sov(w)["governor"]), "the governor arrives with the charter")
	check_eq(CD.privilege_holder(w, "MINING"), "house:mining", "the mining house holds its privilege")
	check_eq(w.facts.query("LAW_CHARTER_SIGNED").size(), 1, "public fact")
	check(not CD.sign(w, t)["ok"], "only once")
	check(not LawOps.check_change(w, "LAW_CHARTER_QUOTA_SHARE", 10, "LAW").is_empty(), "the colony still cannot change it")
	CO.recognise_independence(w)
	check_eq(CD.privilege_holder(w, "MINING"), "", "privileges lapse with independence")


func test_old_games_have_no_deal() -> void:
	var w := _world()
	check(CD.deal(w).is_empty() and CD.privilege_holder(w, "MINING") == "" and CD.autonomy(w) == CD.AUTONOMY_BASE, "nothing changes")

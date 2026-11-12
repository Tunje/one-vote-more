extends TestCase
## D5 trade law (planning/spec-demand-v1.md D5): levers, export terms under the charter, refusal and independence.

const F := preload("res://tests/support/staff_fixture.gd")
const LawOps := preload("res://sim/law/law_ops.gd")
const CO := preload("res://sim/law/charter_ops.gd")
const TL := preload("res://sim/law/trade_law.gd")


func _world() -> WorldState:
	var w := F.bare_world()
	LawOps.init_world(w)
	CO.ensure_m12(w)
	return w


func test_levers_registered() -> void:
	var w := _world()
	for id in ["LAW_EXPORT_TAX", "LAW_LUXURY_TAX", "LAW_TOURIST_TAX", "LAW_TOURIST_VISA", "LAW_LEISURE_LICENSING"]:
		check(w.lever_defs.has(id) and String(w.lever_defs[id]["type"]) == "NUMBER" and bool(w.lever_defs[id]["legislative"]),
			id + " is a draftable NUMBER")
	check_eq(String(w.lever_defs["LAW_CHARTER_EXPORT_LEVY"]["legalLevel"]), "CHARTER", "the levy is a charter term")
	check(not LawOps.check_change(w, "LAW_CHARTER_EXPORT_LEVY", 10, "LAW").is_empty(), "the colony cannot set the levy")
	check_eq(TL.visa_openness(w), 0.5, "visas half open by default")
	w.levers["LAW_LEISURE_LICENSING"] = 100
	check(TL.venue_approval_p(w) < 0.5 and TL.venue_sales_factor(w) < 1.0, "strict licensing: fewer, quieter venues")


func test_export_terms_follow_the_charter() -> void:
	var w := _world()
	w.levers["LAW_EXPORT_TAX"] = 10
	check(CO.home_world_amend(w, "LAW_CHARTER_EXPORT_LEVY", 15)["ok"], "the home world sets a levy")
	CO.home_world_reserve(w, "MINERAL", true)
	var t := CO.export_terms(w, "MINERAL")
	check(t["reserved"] and t["export_tax_pct"] == 0 and t["levy_pct"] == 15, "reserved: charter price, no colony tax (%s)" % [t])
	var c := CO.export_terms(w, "CONSUMER")
	check(not c["reserved"] and c["export_tax_pct"] == 10 and c["levy_pct"] == 15, "a free good: levy and colony tax")
	check_eq(w.facts.query("LAW_CHARTER_EXPORT_RESERVED").size(), 1, "the reservation is public")


func test_refusing_the_export_terms() -> void:
	var w := _world()
	CO.home_world_amend(w, "LAW_CHARTER_EXPORT_LEVY", 20)
	CO.home_world_reserve(w, "MINERAL", true)
	var r := CO.refuse_export_terms(w)
	check(r["ok"] and not r["lawful"], "refusal is unlawful under the charter")
	var t := CO.export_terms(w, "MINERAL")
	check(t["refusal"] and t["levy_pct"] == 0 and not t["reserved"], "no levy, free sale while refusing")
	check(CO.home_sanction(w, "APPOINT_GOVERNOR")["lawful"], "defiance justifies a governor")
	CO.end_export_refusal(w)
	check_eq(int(CO.export_terms(w, "MINERAL")["levy_pct"]), 20, "compliance restores the levy")


func test_independence_ends_the_terms() -> void:
	var w := _world()
	CO.home_world_amend(w, "LAW_CHARTER_EXPORT_LEVY", 20)
	CO.home_world_reserve(w, "MINERAL", true)
	CO.recognise_independence(w)
	var t := CO.export_terms(w, "MINERAL")
	check(not t["colonial"] and t["levy_pct"] == 0 and not t["reserved"], "an independent colony owes nothing")
	check(not CO.home_world_reserve(w, "MATERIAL", true)["ok"], "no new reservations")

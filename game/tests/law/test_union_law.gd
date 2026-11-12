extends TestCase
## Union law U4 (planning/spec-unions-v1.md §4): ballot, public-sector ban, recognition, closed shop, political
## levy, and the unlawful-strike suit against the union fund.

const F := preload("res://tests/support/staff_fixture.gd")
const LawOps := preload("res://sim/law/law_ops.gd")
const J := preload("res://sim/law/justice_ops.gd")
const UL := preload("res://sim/law/union_law.gd")

const CO := "org:1"
const GOV := "gov"


func _world() -> WorldState:
	var w := F.bare_world()
	LawOps.init_world(w)
	w.table("org")["org:1"] = {"id": "org:1", "type": "PRIVATE", "status": "ACTIVE"}
	w.table("union")["union:1"] = {"id": "union:1", "acct": "union:union:1", "status": "ACTIVE", "federation": false}
	return w


func _chk(w: WorldState, employer: String, yes_pm: int, occ: String = "MINING") -> Dictionary:
	return UL.strike_check(w, "union:1", employer, occ, yes_pm)


func test_levers_registered_as_draftable_numbers() -> void:
	var w := _world()
	for id in ["LAW_STRIKE_BALLOT", "LAW_CLOSED_SHOP", "LAW_PUBLIC_SECTOR_STRIKE", "LAW_UNION_RECOGNITION",
			"LAW_STRIKE_LIABILITY", "LAW_POLITICAL_LEVY"]:
		check(w.lever_defs.has(id), id + " registered")
		check_eq(String(w.lever_defs[id]["type"]), "NUMBER", id + " is a NUMBER (AI governments can draft it)")
		check(bool(w.lever_defs[id].get("legislative", false)), id + " is legislative")


func test_defaults_keep_todays_behaviour() -> void:
	var w := _world()
	check(_chk(w, CO, -1)["lawful"], "no ballot needed")
	check(_chk(w, GOV, -1)["lawful"], "public servants may strike")
	check(not UL.must_bargain(w, 900), "no recognition duty")
	check(not UL.closed_shop(w), "no closed shop")
	check_eq(UL.levy_share(w), 1.0, "dues fund politics freely")


func test_ballot_rule() -> void:
	var w := _world()
	w.levers["LAW_STRIKE_BALLOT"] = 50
	check_eq(_chk(w, CO, -1)["reasons"], ["NO_BALLOT"], "a strike without a ballot is unlawful")
	check_eq(_chk(w, CO, 420)["reasons"], ["BALLOT_FAILED"], "42% yes is not enough")
	check(_chk(w, CO, 550)["lawful"], "55% yes carries it")
	w.levers["LAW_STRIKE_BALLOT"] = 67
	check(not _chk(w, CO, 550)["lawful"], "a supermajority rule")


func test_public_sector_ban() -> void:
	var w := _world()
	w.levers["LAW_PUBLIC_SECTOR_STRIKE"] = 0
	check_eq(_chk(w, GOV, -1)["reasons"], ["PUBLIC_SECTOR_BAN"], "public servants may not strike")
	check(_chk(w, CO, -1)["lawful"], "private firms unaffected")
	check(not _chk(w, CO, -1, "PUBLIC_SECTOR")["lawful"], "public-sector staff at a public enterprise too")


func test_recognition_and_levy() -> void:
	var w := _world()
	w.levers["LAW_UNION_RECOGNITION"] = 40
	check(UL.must_bargain(w, 400), "at the threshold the employer must bargain")
	check(not UL.must_bargain(w, 399), "below it, it may refuse")
	w.levers["LAW_POLITICAL_LEVY"] = 2
	check(UL.levy_share(w) < 0.5, "opt-in shrinks the political fund")
	w.levers["LAW_CLOSED_SHOP"] = 1
	check(UL.closed_shop(w), "closed shop allowed")


func test_unlawful_strike_suit_pays_from_the_union_fund() -> void:
	var w := _world()
	w.ledger.open_account("co:org:1")
	w.ledger.open_account("union:union:1")
	w.ledger.transfer(Ledger.EXTERNAL, "union:union:1", 300000, "seed", w.month)
	w.levers["LAW_STRIKE_LIABILITY"] = 50
	check_eq(UL.sue_unlawful_strike(w, GOV, "union:1", 1000000, ["PUBLIC_SECTOR_BAN"], true), "", "the government does not sue")
	w.levers["LAW_STRIKE_LIABILITY"] = 0
	check_eq(UL.sue_unlawful_strike(w, CO, "union:1", 1000000, ["NO_BALLOT"], true), "", "immunity: no claim")
	w.levers["LAW_STRIKE_LIABILITY"] = 50
	var cid := UL.sue_unlawful_strike(w, CO, "union:1", 1000000, ["NO_BALLOT"], true)
	check(cid != "", "the employer sues")
	var c: Dictionary = w.table("case")[cid]
	check_eq(int(c["data"]["claim"]), 500000, "half the losses")
	J._final(w, c, true)
	check_eq(w.ledger.balance("co:org:1"), 300000, "paid what the fund held")
	check_eq(w.ledger.balance("union:union:1"), 0, "the fund is emptied, not negative")
	var r: Array = w.facts.query("LAW_RULING").filter(func(f): return f["data"]["case"] == cid)
	check(r.size() == 1 and int(r[0]["data"]["amount"]) == 500000 and int(r[0]["data"]["paid"]) == 300000, "ruling records award and payment")

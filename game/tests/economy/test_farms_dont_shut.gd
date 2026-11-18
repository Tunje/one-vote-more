extends TestCase
## Terra, 2026-11-18. "FARMS DON'T SHUT" (the user, verbatim; rebuild-company.md 15e): no path shuts a farm. 15e: "The
## family that owns a family farm works it themselves, without wages … A family farm with no money still grows food".
## A plant of another type shut for want of staff (19a, NO_STAFF) opens again when it has people (Wilma's reading).

const Company := preload("res://sim/economy/company.gd")
const Making := preload("res://sim/economy/making.gd")
const Rules := preload("res://sim/economy/rules.gd")
const Households := preload("res://sim/population/households.gd")
const Site := preload("res://sim/transport/site.gd")
const S := 1000
const HW := {"kind": "HOME_WORLD", "holders": {"home_world": 1000}}


var area := ""


## A world with its map (a plant must stand somewhere to hire) and the landing area; a landlord asking 100 for a home,
## so the starting salary is above a worker's needs and people apply at once.
func _w() -> WorldState:
	var w := GameSim.make(1, "BALANCED", {}, true).world
	area = String(AreaStore.found_landing(w))
	Company.set_price(w, Company.create(w, "LANDLORD", "SMALL", HW, "Homes", {"area": area}), "@home", 100 * S)
	return w


## A company of `type` with one SMALL plant placed on its best country tile. Returns [company, plant].
func _placed(w: WorldState, type: String, owner: Dictionary) -> Array:
	var cid := Company.create(w, type, "SMALL", owner, type.capitalize(), {"area": area})
	var pid := Company.add_plant(w, cid, "SMALL")
	check_eq(Site.place(w, pid, Site.choose_country(w, type, 2, 1)[0]), "", "%s placed" % type)
	return [cid, pid]


func _fund(w: WorldState, cid: String, credits: int) -> void:
	w.ledger.transfer(Ledger.EXTERNAL, CoreUtil.acct(cid), credits * S, "test money", w.month)


## A month whose wages could not be paid: what 19a reads (the books' wages due and wages paid).
func _unpaid(w: WorldState, cid: String, due: int) -> void:
	Company.book(w, cid, "wages_due", due)
	Company.book(w, cid, "wages", 0)


func test_a_farm_whose_hands_go_unpaid_stays_open_and_its_family_grows_food() -> void:
	var w := _w()
	var pool := Households.seed_test(w, area, "I2", "G", 40)
	Households.seed_test(w, area, "I3", "S", 10)
	var fam := Households.make_founder(w, pool, "", true)
	var f := _placed(w, "FARM", {"kind": "FAMILY", "holders": {fam: 1000}})
	var cid := String(f[0])
	var pid := String(f[1])
	Company.family_set(w, cid, pid, fam, {})
	_fund(w, cid, 10000)
	Rules.staff_to_posts(w, cid)
	var fam_n := Company.family_count(w, cid, "", pid)
	check(fam_n > 0, "the family works its own posts (%d)" % (fam_n / S))
	check(Company.staff_count(w, cid, "", pid) > 0, "and hands are hired for the rest (%d)" % (Company.staff_count(w, cid, "", pid) / S))
	Company.close_month(w, cid)
	w.month = 1
	_unpaid(w, cid, Company.wage_bill(w, cid))
	Rules.staff_to_posts(w, cid)
	check_eq(Company.staff_count(w, cid, "", pid), 0, "19a: the unpaid hands are laid off")
	check_eq(Company.family_count(w, cid, "", pid), fam_n, "the family stays on its posts")
	check(not bool(Company.plant(w, pid)["closed"]), "the farm is not shut")
	check(Logbook.rows(w, {"kind": "CLOSE", "who": cid}).is_empty() and Logbook.rows(w, {"kind": "CLOSE_REFUSED", "who": cid}).is_empty(),
		"nothing even asked to shut it: the family is on its posts")
	check(Making.make_plant(w, cid, pid) > 0, "and the family grows food that month")
	check(Households.check(w).is_empty(), "jobs = people still holds: %s" % str(Households.check(w)))


func test_no_path_shuts_a_farm() -> void:
	var w := _w()
	var f := _placed(w, "FARM", HW)
	var cid := String(f[0])
	var pid := String(f[1])
	_unpaid(w, cid, 300 * S)
	Rules.staff_to_posts(w, cid)
	check(not bool(Company.plant(w, pid)["closed"]), "19a with nobody on its posts: a farm is not shut")
	for reason in ["NO_STAFF", "LAW", "IDLE"]:
		check(not Company.close_plant(w, pid, reason), "close_plant refuses a farm (%s)" % reason)
	check(not bool(Company.plant(w, pid)["closed"]), "it stays open")
	check_eq(Logbook.rows(w, {"kind": "CLOSE_REFUSED", "ref": pid}).size(), 3,
		"each refusal is a row with the reason it was asked")
	check_eq(Company.posts_wanted(w, cid, pid), {"G": 6, "S": 2, "Sp": 0}, "and it still wants its posts filled")


func test_another_type_shut_for_no_staff_opens_again_when_it_has_people() -> void:
	var w := _w()
	Households.seed_test(w, area, "I2", "G", 60)
	Households.seed_test(w, area, "I3", "S", 20)
	Households.seed_test(w, area, "I4", "Sp", 10)
	var m := _placed(w, "MINE", HW)
	var cid := String(m[0])
	var pid := String(m[1])
	_unpaid(w, cid, 300 * S)
	Rules.staff_to_posts(w, cid)
	check(bool(Company.plant(w, pid)["closed"]), "another type, nobody on its posts after 19a: shut")
	check_eq(String(Company.plant(w, pid)["closed_why"]), "NO_STAFF", "for want of staff")
	check(Company.posts_wanted(w, cid, pid) != {"G": 0, "S": 0, "Sp": 0}, "its posts stay open to hiring while it is shut")
	Company.close_month(w, cid)   # the month's books close; the next month's are its own
	w.month = 1
	_fund(w, cid, 100000)
	Rules.staff_to_posts(w, cid)
	check(Company.staff_count(w, cid, "", pid) > 0, "it hires (%d)" % (Company.staff_count(w, cid, "", pid) / S))
	check(not bool(Company.plant(w, pid)["closed"]), "and with people on its posts it opens again")
	check_eq(Logbook.rows(w, {"kind": "REOPEN", "ref": pid}).size(), 1, "one REOPEN row")
	check(Households.check(w).is_empty(), "jobs = people still holds: %s" % str(Households.check(w)))


func test_a_plant_shut_by_the_law_is_not_reopened_by_hiring() -> void:
	var w := _w()
	var m := _placed(w, "MINE", HW)
	var cid := String(m[0])
	var pid := String(m[1])
	check(Company.close_plant(w, pid, "LAW"), "shut by the law")
	check_eq(Company.posts_wanted(w, cid, pid), {"G": 0, "S": 0, "Sp": 0}, "a plant the law shut wants nobody")
	Company.staff_change(w, cid, pid, "G", area + "|I2|G", 2 * S, 300 * S, 0)
	Rules.staff_to_posts(w, cid)
	check(bool(Company.plant(w, pid)["closed"]), "people on its posts do not reopen it: that is the law's (reopen_licensed)")

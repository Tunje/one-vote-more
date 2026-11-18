extends TestCase
## The farm grant in a real new game (Wilma, 2026-11-18: in a five-year game no grant was paid; every farm applied in
## month one before the government had decided its programme). Month one: the programmes open, the government sets
## each sum and chooses where it covers, and only then does anyone found, so the farm programme pays grants to the
## farms it wants, a tenth more to be sure (the user's 61b), and then stops. Exact to the last credit.

const Grants := preload("res://sim/economy/grants.gd")


func test_month_one_the_farm_programme_pays_the_farms_it_wants_then_stops() -> void:
	var sim := GameSim.make(1)
	sim.run(1)
	var w: WorldState = sim.world
	var set_rows := Logbook.rows(w, {"kind": "GRANT", "what": "sum set"}).filter(func(r): return String(r["why"]["kind"]) == "FARM")
	check_eq(set_rows.size(), 1, "the farm programme's sum is set once")
	if set_rows.size() != 1:
		return
	var b: Dictionary = set_rows[0]["why"]
	check_eq(int(set_rows[0]["m"]), 0, "in month one")
	check_eq(int(b["planned"]), 0, "before any plan is made: the farms the government wants are not counted against it")
	check(int(b["wanted"]) > 0, "it wants farms (%d)" % int(b["wanted"]))
	check_eq(int(b["sum"]), int(b["grant"]) * int(b["wanted"]) + int(b["extra"]), "the farms it wants and the extra")
	var paid := 0
	var n := 0
	for pid in CoreUtil.sorted_keys(w.peek("grant")):
		var g: Dictionary = w.peek("grant")[pid]
		if String(g["kind"]) == "FARM":
			paid += int(g["amount"])
			n += 1
	check(n >= int(b["wanted"]), "a grant for each farm it wants (%d paid, %d wanted)" % [n, int(b["wanted"])])
	check(paid <= int(b["sum"]), "never past the sum")
	check_eq(Grants.sum_left(w, "FARM"), int(b["sum"]) - paid, "what is left is the sum less what was paid")
	var refused := Logbook.rows(w, {"kind": "GRANT", "what": "grant refused"}).filter(func(r): return String(r["why"]["kind"]) == "FARM")
	for r in refused:
		check_eq(String(r["why"]["reason"]), "what is left of the programme's sum is less than a grant",
			"refused only because the sum is spent, never for want of a decided programme")
	if not refused.is_empty():
		check(Grants.sum_left(w, "FARM") < int(b["grant"]), "then it stops: less than a grant is left")
	# one grant per household (61): every founder paid a grant is marked, so it is kept when the household goes back (Maja)
	for pid in CoreUtil.sorted_keys(w.peek("grant")):
		var g: Dictionary = w.peek("grant")[pid]
		if String(g["kind"]) == "FARM":
			check(bool(w.peek("founder").get(String(g["founder"]), {}).get("had_grant", false)), "%s is marked as having had its grant" % g["founder"])

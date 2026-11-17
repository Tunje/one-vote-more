extends SceneTree
## How long an employee stays hired at a company. Reads every hire and every leaving from the log, month by month.
##
## The game counts staff in groups, not as named people, so it cannot say WHICH person left. The tool therefore gives
## two answers that bound the truth: "longest-serving leave first" and "newest leave first". The plain average (months
## worked in all, divided by jobs ended) is the same under both.
## It also checks the log against the companies' own staff counts every month: a change in staff with no row is a fault.
## usage: godot --headless --path game --script res://tools/tenure.gd -- [months=120] [seed=1]

const Company := preload("res://sim/economy/company.gd")
const S := CoreUtil.S


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var months := int(args[0]) if args.size() > 0 else 120
	var seed_v := int(args[1]) if args.size() > 1 else 1
	var sim := GameSim.make(seed_v)
	var w := sim.world
	var cohorts := {}      # company -> [[hire month, persons still there]]
	var spells := {"old": {}, "new": {}}   # rule -> type -> [months served, one entry per job ended]
	var ended := {}        # type -> {reason: persons}
	var hires := {}        # type -> persons
	var person_months := {}  # type -> months worked in all
	var headcount := {}    # type -> sum over months of staff
	var unexplained := 0
	for m in months:
		# run one month, then read that month's rows (a month's rows are written while it runs; the landing's own
		# rows carry month 0 too, so the first batch holds them as well)
		var ran := w.month
		sim.step()
		# only this month's rows of the four kinds: copying the whole log every month made a long game take hours
		var rows: Array = []
		for kind in ["HIRE", "JOB", "LAYOFF", "LEAVE"]:
			rows.append_array(Logbook.rows(w, {"kind": kind, "from": ran, "to": ran}))
		rows.sort_custom(func(a, b): return _order(a) < _order(b))
		for r in rows:
			var who := String(r["who"])
			match String(r["kind"]):
				"HIRE":
					if String(r["what"]).begins_with("hired"):
						_in(cohorts, hires, w, who, int(r["m"]), int(r["change"]["staff"][1]))
				"JOB":
					var k := int(r["change"]["staff"][1])
					_in(cohorts, hires, w, who, int(r["m"]), k)
					_out(cohorts, spells, ended, w, String(r["with"]), int(r["m"]), k, "left for better pay")
				"LAYOFF":
					_out(cohorts, spells, ended, w, who, int(r["m"]), int(r["change"]["staff"][0]), "laid off")
				"LEAVE":
					_out(cohorts, spells, ended, w, who, int(r["m"]), int(r["change"]["staff"][0]), "left: " + String(r["why"].get("reason", "?")).to_lower())
		for cid in Company.ids(w):
			var t := Company.type_of(w, cid)
			var real := Company.staff_count(w, cid) / S
			var mine := 0
			for c in cohorts.get(cid, []):
				mine += int(c[1])
			if mine != real:
				unexplained += absi(real - mine)
				if unexplained <= 5 * absi(real - mine):
					print("  month %d: %s (%s) has %d staff but the log accounts for %d" % [ran, cid, t, real, mine])
				cohorts[cid] = [[w.month, real]] if real > 0 else []   # start again from what is there
			headcount[t] = int(headcount.get(t, 0)) + real
			person_months[t] = int(person_months.get(t, 0)) + real

	print("HOW LONG A JOB LASTS  (seed %d, %d months; persons, and months)" % [seed_v, months])
	print("The game counts staff in groups, so two bounds are given: the longest-serving leave first / the newest leave first.\n")
	print("%-12s %7s %7s %9s | %-25s | %-25s | %s" % ["type", "hired", "ended", "avg staff", "longest-serving leave first", "newest leave first", "plain average"])
	print("%-12s %7s %7s %9s | %-25s | %-25s | %s" % ["", "", "", "", "median  <=3m  <=12m", "median  <=3m  <=12m", "months per job ended"])
	var types: Array = hires.keys()
	types.sort()
	for t in types:
		var e := 0
		for reason in ended.get(t, {}):
			e += int(ended[t][reason])
		print("%-12s %7d %7d %9.1f | %-25s | %-25s | %s" % [t, int(hires[t]), e, float(headcount.get(t, 0)) / float(months),
			_dist(spells["old"].get(t, [])), _dist(spells["new"].get(t, [])),
			("%.1f" % (float(person_months.get(t, 0)) / float(e))) if e > 0 else "nobody left"])
	print("\nWHY JOBS ENDED (persons)")
	for t in types:
		var parts: Array = []
		var rs: Array = ended.get(t, {}).keys()
		rs.sort()
		for reason in rs:
			parts.append("%s %d" % [reason, int(ended[t][reason])])
		print("  %-12s %s" % [t, ", ".join(parts) if not parts.is_empty() else "none"])
	print("\nSTILL EMPLOYED AT THE END: months in the job so far (longest-serving leave first / newest leave first give the same people-count, different ages)")
	var still := {}
	for cid in cohorts:
		var t := Company.type_of(w, cid)
		for c in cohorts[cid]:
			for i in int(c[1]):
				if not still.has(t):
					still[t] = []
				(still[t] as Array).append(w.month - int(c[0]))
	for t in types:
		print("  %-12s %4d persons, %s" % [t, (still.get(t, []) as Array).size(), _dist(still.get(t, []))])
	print("\nTHE LOG AGAINST THE COMPANIES' OWN COUNTS: %s" % ("every change in staff has its row" if unexplained == 0 else "%d person-changes with NO row (a fault: see the lines above)" % unexplained))
	quit()


## Hires before leavings within a month's batch read kind by kind: a person hired and gone in the same month must be
## hired first.
func _order(r: Dictionary) -> int:
	return 0 if String(r["kind"]) in ["HIRE"] else 1


func _in(cohorts: Dictionary, hires: Dictionary, w: WorldState, cid: String, month: int, n: int) -> void:
	if n <= 0:
		return
	if not cohorts.has(cid):
		cohorts[cid] = []
	(cohorts[cid] as Array).append([month, n])
	var t := Company.type_of(w, cid)
	hires[t] = int(hires.get(t, 0)) + n


## n persons leave company cid. Under "old" the longest-serving go first; under "new" the newest. The cohorts are kept
## by the "old" rule (one list cannot serve both), and the "new" spells are taken from a second pass over the same list
## from its other end, without removing: an approximation that is exact while a company's leavers in a month are fewer
## than its newest cohort, and otherwise understates the newest-first spells slightly.
func _out(cohorts: Dictionary, spells: Dictionary, ended: Dictionary, w: WorldState, cid: String, month: int, n: int, reason: String) -> void:
	if n <= 0:
		return
	var t := Company.type_of(w, cid)
	if not ended.has(t):
		ended[t] = {}
	ended[t][reason] = int(ended[t].get(reason, 0)) + n
	var list: Array = cohorts.get(cid, [])
	var left := n
	var i := list.size() - 1
	while left > 0 and i >= 0:   # newest first, read only
		var k := mini(left, int(list[i][1]))
		_add(spells["new"], t, month - int(list[i][0]), k)
		left -= k
		i -= 1
	left = n
	while left > 0 and not list.is_empty():   # longest-serving first, removed
		var k := mini(left, int(list[0][1]))
		_add(spells["old"], t, month - int(list[0][0]), k)
		list[0][1] = int(list[0][1]) - k
		left -= k
		if int(list[0][1]) == 0:
			list.pop_front()
	cohorts[cid] = list


func _add(by_type: Dictionary, t: String, months_served: int, k: int) -> void:
	if not by_type.has(t):
		by_type[t] = []
	for j in k:
		(by_type[t] as Array).append(months_served)


func _dist(a: Array) -> String:
	if a.is_empty():
		return "-"
	var s := a.duplicate()
	s.sort()
	var le3 := 0
	var le12 := 0
	for x in s:
		if int(x) <= 3:
			le3 += 1
		if int(x) <= 12:
			le12 += 1
	return "%4d m  %3d%%  %3d%%" % [int(s[s.size() / 2]), le3 * 100 / s.size(), le12 * 100 / s.size()]

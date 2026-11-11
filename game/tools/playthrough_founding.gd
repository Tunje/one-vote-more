extends SceneTree
## Proxy playtest (a9): autoplay OFF; a scripted "player" uses ONLY UI action entry points
## (PolActions, staff/law A.apply incl. STAFF_AUTO_ASSIGN, EconActions) from month 0 to the first government.
##   godot --headless --path game --script res://tools/playthrough_founding.gd [-- seed]
## Prints a monthly log and a list of findings: things the player could not do or got stuck on.

const A := preload("res://sim/staff/staff_law_actions.gd")
const SQ := preload("res://sim/staff/staff_query.gd")
const LQ := preload("res://sim/law/law_query.gd")
const Opp := preload("res://sim/staff/opposition.gd")
const GOV := {"kind": "GOVERNMENT", "id": "government"}
const GOV_OWNER := {"kind": "GOVERNMENT", "id": "government"}

var findings: Array = []
var log_lines: Array = []


func _find(what: String) -> void:
	if not findings.has(what):
		findings.append(what)


func _log(w: WorldState, s: String) -> void:
	log_lines.append("[m%02d] %s" % [w.month, s])


func _initialize() -> void:
	var seed_value := 7
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0].is_valid_int():
		seed_value = args[0].to_int()
	var session := GameSession.new()
	session.new_game(seed_value, false)
	var w := session.world()
	var districts: Array = []
	for key in w.peek("census"):
		var d := String(key).split("|")[0]
		if not districts.has(d):
			districts.append(d)
	districts.sort()
	var commissioned := 0
	var commission_tries := 0
	var ordinances := 0
	var drafts_started := 0
	var unstaffed_months := 0
	var stuck_enactments := {}
	var formed := false
	for m in 60:
		var st: Dictionary = w.peek("pol").get("state", {})
		var pp := String(st.get("player_party", ""))
		var viewer := {"party_id": pp} if pp != "" else {}
		# --- staff: the player relies on the chief of staff every month (government + own party)
		A.apply(w, {"id": "STAFF_AUTO_ASSIGN", "actor": GOV, "args": {}})
		if pp != "":
			A.apply(w, {"id": "STAFF_AUTO_ASSIGN", "actor": {"kind": "PARTY", "id": pp}, "args": {}})
		for d in SQ.decision_requests(w, GOV_OWNER, viewer):
			var rec: String = d["options"].filter(func(o): return o["recommended"])[0]["id"] if d["options"].any(func(o): return o["recommended"]) else d["options"][0]["id"]
			var r := A.apply(w, {"id": "STAFF_ANSWER_DECISION", "actor": GOV, "args": {"request_id": d["id"], "option": rec}})
			_log(w, "answered decision %s → %s (%s)" % [d["id"], rec, r.get("error", "ok")])
		var sm: Dictionary = SQ.summary(w, GOV_OWNER, viewer)
		if not sm.is_empty() and sm["mandatory_vacancies"] > 0:
			unstaffed_months += 1
		# --- economy: commission a housing project early, then one more mid-way
		if m in [1, 20]:
			commission_tries += 1
			var before := w.peek("project").size()
			EconActions.enqueue(w, "ECON_COMMISSION_PROJECT", {"type": "HOUSING", "district": districts[0] if not districts.is_empty() else "d:1"})
			session.end_month()
			if w.peek("project").size() > before:
				commissioned += 1
				_log(w, "commissioned HOUSING in %s" % (districts[0] if not districts.is_empty() else "d:1"))
			else:
				var line: String = EconActions.lines_for("HOUSING")[0]
				_log(w, "commission HOUSING FAILED silently (no project created): headroom on %s %d vs needed %d" % [line,
					EconActions.headroom(w, line) / 1000, EconConstruction.estimate("HOUSING") * 11 / 10 / 1000])
				_find("Commissioning a project can fail silently: EconActions.enqueue returns nothing and the reason (budget headroom, type) is not reported to the player.")
			continue
		# --- legislate: one ordinance at a time in the founding era
		var can: Dictionary = PolActions.player_can_legislate(w)
		var open_drafts: Array = PolActions.player_drafts(w).filter(func(d): return d["status"] == "DRAFTING")
		for d in open_drafts:
			if d["ready"]:
				var r: Dictionary = PolActions.player_submit(w, d["bill"])
				_log(w, "submitted %s: %s" % [d["bill"], str(r)])
				if r.get("result", "") == "ORDINANCE_ISSUED":
					ordinances += 1
				elif not r.get("ok", false):
					_find("Submit failed: %s" % r.get("error", "?"))
		if can["ok"] and open_drafts.is_empty() and m % 6 == 2:
			var levers: Array = LQ.lever_catalog(w).filter(func(l): return l["type"] == "NUMBER" and l["changeable"] and l["pending"].is_empty() and String(l["id"]).begins_with("ECON_"))
			if levers.is_empty():
				_find("No changeable economic lever available to the commander at month %d." % m)
			else:
				var l: Dictionary = levers[(m / 6) % levers.size()]
				var span := int(l["range"][1]) - int(l["range"][0])
				var to := clampi(int(l["legal"]) + maxi(1, span / 10), int(l["range"][0]), int(l["range"][1]))
				if to == int(l["legal"]):
					to = clampi(int(l["legal"]) - maxi(1, span / 10), int(l["range"][0]), int(l["range"][1]))
				var pv: Dictionary = LQ.preview_clauses(w, [{"lever": l["id"], "to": to}])
				if not pv["ok"]:
					_find("Preview rejected a clause the catalog marked changeable: %s" % str(pv["clauses"][0]["errors"]))
				var r: Dictionary = PolActions.player_draft(w, [{"lever": l["id"], "to": to}])
				_log(w, "draft %s %s→%d: %s" % [l["id"], str(l["legal"]), to, str(r)])
				if r.get("ok", false):
					drafts_started += 1
				else:
					_find("player_draft refused: %s" % r.get("error", "?"))
		if not can["ok"] and st.get("era", "") == "PARLIAMENTARY":
			_log(w, "cannot legislate: %s" % can["error"])
		# --- enactments stuck waiting for implementation
		for e in LQ.enactments(w, false, viewer):
			if e["status"] == "LEGAL" and w.month - int(e["legal_month"]) > 6:
				stuck_enactments[e["id"]] = e["lever"]
		# --- opposition view once parties exist (for the record)
		if pp != "" and m == 40:
			var o: Dictionary = Opp.options(w, pp)
			_log(w, "opposition options (role %s): %d inquiries, %d challenges" % [o["role"], o["oversight"].size(), o["challenges"].size()])
		session.end_month()
		st = w.peek("pol").get("state", {})
		if not formed and not st.get("government", {}).is_empty():
			formed = true
			var g: Dictionary = st["government"]
			_log(w, "FIRST GOVERNMENT: %s (pm %s), player party %s %s" % [str(g["members"]), g["pm_party"], st.get("player_party", ""),
				"IN GOVERNMENT" if g["members"].has(st.get("player_party", "")) else "IN OPPOSITION"])
			_log(w, "constitution adopted: %s" % str(LQ.constitution_view(w)["document"]))
			var ppid := String(st.get("player_party", ""))
			if ppid != "" and not g["members"].has(ppid):
				var o: Dictionary = Opp.options(w, ppid)
				_log(w, "player in opposition: party staff %d, top inquiry %s (yield %.1f), %d challenge options" % [o["pool"]["size"],
					o["oversight"][0]["domain"], o["oversight"][0]["expected_yield"], o["challenges"].size()])
				if o["pool"]["size"] == 0:
					_find("Player's party has no opposition staff after losing the founding election.")
		if formed and m >= 50:
			break
	# --- election and summary
	var st2: Dictionary = w.peek("pol").get("state", {})
	var elections: Array = st2.get("elections", [])
	if elections.is_empty():
		_find("No election by month %d (expected month 44)." % w.month)
	else:
		var e: Dictionary = w.peek("election")[elections[0]]
		var parts: Array = []
		for pid in e["seats"]:
			parts.append("%s %d" % [w.peek("party")[pid]["name"] + ("*" if w.peek("party")[pid]["is_player"] else ""), e["seats"][pid]])
		_log(w, "ELECTION: " + ", ".join(parts))
	if not formed:
		_find("No government formed by month %d." % w.month)
	if commissioned == 0:
		_find("The player never managed to commission a project.")
	if ordinances == 0:
		_find("The player never got an ordinance through (drafted %d)." % drafts_started)
	if not stuck_enactments.is_empty():
		_find("Enacted changes stuck at LEGAL >6 months (implementation unstaffed): %s" % str(stuck_enactments.values()))
	if unstaffed_months > 6:
		_find("Government had mandatory vacancies in %d months even with the chief of staff (more work than people)." % unstaffed_months)
	var pp2 := String(st2.get("player_party", ""))
	if pp2 != "":
		_find("Info: with autoplay off, politics skips updating the player party's platform ('human sets it in the UI') but there is no PolActions call to set a platform.")
	for l in log_lines:
		print(l)
	print("\nSUMMARY: projects %d/%d, ordinances %d (drafts %d), months with vacancies %d, stuck enactments %d, government formed %s" % [
		commissioned, commission_tries, ordinances, drafts_started, unstaffed_months, stuck_enactments.size(), str(formed)])
	print("FINDINGS:")
	for f in findings:
		print("  - " + f)
	print("PLAYTHROUGH DONE")
	quit(0)

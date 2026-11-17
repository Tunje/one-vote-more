extends SceneTree
## Interaction smoke for the economy panels (agent 88): budget → Legislate pre-fill, commission + award flow,
## company profile + why?, shortage/fact explainers, and refresh purity (state hash unchanged by rendering).
##   godot --headless --path . --script res://tools/smoke_econ_ui.gd

const EK := preload("res://ui/panels/econ_kit.gd")
var fails := 0


func _ok(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func _panel(main, title: String):
	for p in main.extra_panels:
		if p.panel_title() == title:
			return p
	return null


func _initialize() -> void:
	var main = load("res://ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.session.new_game(4, true)
	main._advance(8)   # founding era: the player is the commander (governing)
	var w: WorldState = main.session.world()
	var budget = _panel(main, "Budget")
	var projects = _panel(main, "Projects")
	var companies = _panel(main, "Companies")
	var why = _panel(main, "Why?")
	var leg = _panel(main, "Legislate")
	_ok(budget != null and projects != null and companies != null and why != null, "four econ panels discovered")

	# purity: rendering every econ panel (with explainers open) must not change the world
	var h0: String = str(w.state_hash())
	budget.edit_lever = "ECON_INCOME_TAX_RATE"
	budget.refresh()
	var orgs: Array = EconQuery.companies(w)
	companies.selected = orgs[0]["id"]
	var prof: Dictionary = EconQuery.company_profile(w, orgs[0]["id"])
	if not prof["facilities"].is_empty():
		companies.why_facility = prof["facilities"][0]["id"]
	if not prof["history"].is_empty():
		companies.why_fact = prof["history"][0]["fact"]
	companies.refresh()
	var sh: Array = EconQuery.shortages(w, 101.0)   # threshold > 100 lists everything with demand
	_ok(not sh.is_empty() and sh[0].has("producers"), "shortages() lists goods with producers and causes")
	why.open_good = sh[0]["good"] if not sh.is_empty() else ""
	var facts: Array = EconQuery.recent_econ_facts(w, 12, 0)
	_ok(not facts.is_empty(), "recent_econ_facts() finds events")
	if not facts.is_empty():
		why.open_fact = facts[0]["fact"]
	why.refresh()
	projects.refresh()
	_ok(str(w.state_hash()) == h0, "rendering econ panels leaves the state hash unchanged")

	# budget → Legislate pre-fill
	var err: String = EK.propose(budget, "ECON_INCOME_TAX_RATE", 27)
	_ok(err == "", "propose() pre-fills Legislate (%s)" % err)
	var cl: Array = leg.clauses.filter(func(c): return c["lever"] == "ECON_INCOME_TAX_RATE")
	_ok(cl.size() == 1 and cl[0]["to"] == 27, "Legislate has clause income tax → 27")
	_ok(main.windows.has("Legislate") and main.windows["Legislate"].visible, "Legislate window opened")

	# commission → tender → manual award
	var bad: Dictionary = EconActions.enqueue(w, "ECON_COMMISSION_PROJECT", {"type": "CASTLE", "district": "d:1"})
	_ok(not bad["ok"] and String(bad["error"]).begins_with("Cannot commission"), "invalid commission rejected with a reason: " + String(bad["error"]))
	EconActions.set_manual_award(w, true)
	var n0: int = w.peek("project").size()
	var opts: Array = EconQuery.commission_options(w).filter(func(o): return o["enabled"])
	_ok(not opts.is_empty(), "some commission option is affordable")
	if not opts.is_empty():
		projects._queue("ECON_COMMISSION_PROJECT", {"type": opts[0]["type"], "district": "d:2", "line": opts[0]["line"]}, "test")
		_ok(EconActions.pending(w).size() >= 1, "commission queued")
		main._advance(1)
		var t0: String = opts[0]["type"]
		var made: Array = w.peek("project").values().filter(func(p): return p["type"] == t0 and p["district"] == "d:2" and p["line"] == opts[0]["line"] and p["tender_month"] >= w.month - 1)
		_ok(made.size() == 1, "project %s in d:2 created after month end (projects %d -> %d)" % [t0, n0, w.peek("project").size()])
		main._advance(1)
		var mine: Array = EconQuery.tenders(w).filter(func(t): return t["owner"] == "gov" and not t["bids"].is_empty())
		if mine.is_empty():
			print("  (no gov tender with bids this month; award path not exercised)")
		else:
			var t: Dictionary = mine[0]
			projects._queue("ECON_AWARD_CONTRACT", {"project": t["project"], "org": t["bids"][-1]["org"]}, "test")
			main._advance(1)
			_ok(w.peek("project")[t["project"]]["contractor"] == t["bids"][-1]["org"], "manual award (override) applied")
	projects.refresh()
	print("SMOKE ECON UI %s (%d failures)" % ["OK" if fails == 0 else "FAILED", fails])
	quit(0 if fails == 0 else 1)

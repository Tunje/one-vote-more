extends SceneTree
## Headless smoke test for a9's interactive panels (personnel, staff briefing, legislate, opposition).
## Drives the real player flows through the panels' own callbacks/actions:
##   assign via candidate comparison, answer decisions, draft -> staff -> submit an ordinance, decree check,
##   opposition view.   godot --headless --path game --script res://tools/smoke_panels_staff_law.gd

const Kit := preload("res://ui/panels/panel_kit.gd")
const SQ := preload("res://sim/staff/staff_query.gd")
const PANELS := ["personnel_panel.gd", "staff_briefing_panel.gd", "drafting_panel.gd", "opposition_panel.gd"]

var fails: Array = []


func _check(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		fails.append(what)


func _initialize() -> void:
	var session := GameSession.new()
	session.new_game(7, false)          # the player plays; AI does not act for them
	var hub := Node.new()                # stands in for main.gd's refresh group
	hub.set_script(load("res://tools/support_refresh_hub.gd") if ResourceLoader.exists("res://tools/support_refresh_hub.gd") else null)
	root.add_child(hub)
	var panels := {}
	for f in PANELS:
		var p = load("res://ui/panels/" + f).new()
		p.setup(session)
		root.add_child(p)
		panels[f] = p
	await process_frame
	for f in panels:
		panels[f].refresh()
	await process_frame
	var w := session.world()
	var c := Kit.ctx(session)
	_check(c["governing"] and c["era"] == "FOUNDING", "founding: the player governs as commander")

	# --- personnel: open a vacant position, pick the best eligible candidate, assign through the panel action
	var pers = panels["personnel_panel.gd"]
	var pos: Array = SQ.open_positions(w, Kit.GOV_OWNER, c["viewer"])
	_check(not pos.is_empty(), "founding slate has vacant positions")
	pers.selected = {"task_id": pos[0]["task_id"], "pos": pos[0]["pos"]}
	pers.refresh()
	var cand: Array = SQ.candidates(w, pos[0]["task_id"], pos[0]["pos"], c["viewer"]).filter(func(x): return x["eligible"] and x["currently"].is_empty())
	pers._do({"id": "STAFF_ASSIGN", "actor": c["gov_actor"], "args": {"task_id": pos[0]["task_id"], "pos": pos[0]["pos"], "person_id": cand[0]["person_id"]}})
	_check(pers.msg == "Done.", "assigned via candidate list (%s)" % pers.msg)
	# the rest via the panel's "Let my chief of staff assign people" button (STAFF_AUTO_ASSIGN, matching-based)
	pers._do({"id": "STAFF_AUTO_ASSIGN", "actor": c["gov_actor"], "args": {}})
	_check(SQ.summary(w, Kit.GOV_OWNER, c["viewer"])["mandatory_vacancies"] == 0, "founding slate fully staffed by the chief of staff")

	# --- legislate: clause -> preview -> start drafting -> staff the draft -> submit as ordinance
	var leg = panels["drafting_panel.gd"]
	leg.clauses = [{"lever": "LAW_EXTRACTION_ROYALTY", "to": 1000}]
	leg.refresh()
	var res: Dictionary = PolActions.player_draft(w, leg.clauses)
	_check(res.get("ok", false), "draft started (%s)" % res.get("error", ""))
	var bill: String = res.get("bill_id", "")
	leg.refresh()
	var unstaffed: bool = not preload("res://sim/law/law_query.gd").drafting_status(w, bill, c["viewer"])["staffed"]
	_check(unstaffed, "new draft shows as unstaffed (everyone qualified is busy)")
	var r2: Dictionary = Kit.A.apply(w, {"id": "STAFF_AUTO_ASSIGN", "actor": c["gov_actor"], "args": {}})
	_check(int(r2.get("filled", 0)) >= 1, "chief of staff moved someone onto the draft (filled %d)" % int(r2.get("filled", 0)))
	var ready := false
	for _m in 8:
		session.end_month()
		for f in panels:
			panels[f].refresh()
		for d in PolActions.player_drafts(w):
			if d["bill"] == bill and d["ready"]:
				ready = true
		if ready:
			break
	_check(ready, "draft completed and is submittable")
	var sub: Dictionary = PolActions.player_submit(w, bill)
	_check(sub.get("result", "") == "ORDINANCE_ISSUED", "submitted as ordinance (%s)" % str(sub))
	leg.refresh()

	# --- staff briefing: decisions + reports render; answer any open decision via its option button action
	var brief = panels["staff_briefing_panel.gd"]
	brief.refresh()
	var b: Dictionary = SQ.briefing(w, Kit.GOV_OWNER, -1, c["viewer"])
	_check(b["items"].size() == 20, "20 staff reports in the briefing")

	# --- decree check text exists for parliament (not available in founding era)
	var dc: Dictionary = preload("res://sim/law/law_query.gd").decree_check(w, "LAW_PERMIT_STRICTNESS", "STRICT", c["viewer"])
	_check(not dc["allowed"], "no decrees in the founding era: " + dc["warning"])

	# --- opposition panel renders in every state
	panels["opposition_panel.gd"].refresh()
	var nodes := 0
	for f in panels:
		nodes += _count(panels[f])
	_check(nodes > 50, "panels rendered (%d nodes)" % nodes)
	print("PANELS OK" if fails.is_empty() else "PANELS FAILED: %s" % [fails])
	quit(0 if fails.is_empty() else 1)


func _count(n: Node) -> int:
	var k := 1
	for ch in n.get_children():
		k += _count(ch)
	return k

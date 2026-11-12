extends TestCase
## A44 office channel: one item per source, answers perform actions, expiry falls to the default and is logged,
## settled sources close their items, office hours.


func _world() -> WorldState:
	var sim: Simulation = EconSim.make(3, "BALANCED", {}, true)
	sim.run(2)
	return sim.world


func test_post_dedupes_by_source_and_refreshes() -> void:
	var w := _world()
	var a := Office.post(w, {"kind": "EMAIL", "subject": "first", "source": {"system": "T", "ref": "x"}})
	var b := Office.post(w, {"kind": "EMAIL", "subject": "second", "source": {"system": "T", "ref": "x"}})
	check_eq(a, b, "same source -> same item")
	check_eq(String(Office.get_item(w, a)["subject"]), "second", "refreshed")
	check_eq(Office.items(w, ["EMAIL"]).size(), 1, "one open email")


func test_answer_performs_action_and_closes() -> void:
	var w := _world()
	var id := Office.post(w, {"kind": "EMAIL", "subject": "ack", "options": [{"id": "OK", "label": "OK", "action": {}}], "source": {"system": "T", "ref": "y"}})
	check(Office.answer(w, id, "OK")["ok"], "answered")
	check_eq(String(Office.get_item(w, id)["status"]), "ANSWERED", "status")
	check(not Office.answer(w, id, "OK")["ok"], "cannot answer twice")
	var bad := Office.post(w, {"kind": "EMAIL", "subject": "bad", "options": [{"id": "X", "label": "X", "action": {"via": "ECON", "id": "ECON_ANSWER_UNION_DEMAND", "params": {"demand": "udemand:999", "answer": "ACCEPT"}}}]})
	check(not Office.answer(w, bad, "X")["ok"], "invalid action refused, item stays open")
	check_eq(String(Office.get_item(w, bad)["status"]), "NEW", "still open")


func test_expiry_takes_default_and_logs_fact() -> void:
	var w := _world()
	var id := Office.post(w, {"kind": "EMAIL", "subject": "deadline", "options": [{"id": "YES", "label": "Yes", "action": {}}, {"id": "NO", "label": "No", "action": {}}],
		"default_option": "NO", "deadline": w.month - 1})
	check(Office.blocking(w).size() >= 1, "past-deadline email blocks")
	Office.expire(w)
	var o := Office.get_item(w, id)
	check_eq(String(o["status"]), "EXPIRED", "expired")
	check_eq(String(o["answer"]), "NO", "default taken")
	check_eq(w.facts.query("OFFICE_ITEM_EXPIRED").size(), 1, "logged")


func test_resolve_and_hidden_kept() -> void:
	var w := _world()
	var id := Office.post(w, {"kind": "EMAIL", "subject": "s", "source": {"system": "UNION", "ref": "d1"}, "hidden": {"true_priority": 90}})
	check_eq(int(Office.get_item(w, id)["hidden"]["true_priority"]), 90, "hidden stored")
	Office.resolve(w, "UNION", "d1")
	check_eq(String(Office.get_item(w, id)["status"]), "RESOLVED", "resolved")


func test_office_hours() -> void:
	var w := _world()
	check_eq(OfficeFeed.hours(w), OfficeFeed.HOURS_PER_MONTH, "full hours")
	check(OfficeFeed.spend_hours(w, 10), "spend")
	check_eq(OfficeFeed.hours(w), OfficeFeed.HOURS_PER_MONTH - 10, "left")
	check(not OfficeFeed.spend_hours(w, 999), "cannot overspend")

extends TestCase
## The log of everything that happens in the economy (the user, 2026-11-17): rows can be written, searched and written
## to a file; nobody can change a row once written; writing to the log never changes the game; and no game code reads it.

const NoiseProvider := preload("res://tests/support/noise_provider.gd")


func _sim(seed_value: int) -> Simulation:
	var s := Simulation.new(seed_value, [NoiseProvider.new()])
	s.new_game()
	return s


func test_a_row_says_when_who_what_why_and_what_changed() -> void:
	var w := _sim(1).world
	w.month = 14
	Logbook.note(w, "RULE", "co:7", "R1 raise price", {"unfilled": 40, "sold": 100}, {"price": [1000, 1057]})
	var r: Array = Logbook.rows(w)
	check_eq(r.size(), 1, "one row")
	check_eq(int(r[0]["m"]), 14, "the month")
	check_eq(String(r[0]["who"]), "co:7", "who")
	check_eq(int(r[0]["why"]["unfilled"]), 40, "the numbers it read")
	check_eq(r[0]["change"]["price"], [1000, 1057], "what it changed")


func test_rows_are_found_by_kind_who_what_and_month() -> void:
	var w := _sim(1).world
	w.month = 3
	Logbook.note(w, "RULE", "co:1", "R1 raise price")
	Logbook.note(w, "SALE", "co:1", "sold FOOD", {"qty": 30})
	w.month = 9
	Logbook.note(w, "RULE", "co:2", "R2 lower price")
	Logbook.note(w, "END", "co:1", "sales death")
	check_eq(Logbook.rows(w, {"kind": "RULE"}).size(), 2, "by kind")
	check_eq(Logbook.rows(w, {"who": "co:1"}).size(), 3, "by who")
	check_eq(Logbook.rows(w, {"what": "sold FOOD"}).size(), 1, "by what, exactly")
	check_eq(Logbook.rows(w, {"what_has": "price"}).size(), 2, "by a word in what")
	check_eq(Logbook.rows(w, {"from": 4}).size(), 2, "from a month on")
	check_eq(Logbook.rows(w, {"to": 3}).size(), 2, "up to a month")
	check_eq(Logbook.rows(w, {"who": "co:1", "to": 3}).size(), 2, "two filters together")
	check_eq(int(Logbook.counts(w)["RULE R1 raise price"]), 1, "counts by kind and what")
	check_eq(Logbook.story(w, "co:1").size(), 3, "the story of one company")
	check(Logbook.story(w, "co:1")[2].begins_with("m9 END sales death"), "ends with its ending")
	Logbook.clear(w)
	check_eq(Logbook.rows(w).size(), 0, "cleared")


func test_a_job_can_be_followed_from_the_plan_to_the_company() -> void:
	# Otto's review: a contract has two parties, and a plan becomes a company with a new id.
	var w := _sim(1).world
	Logbook.note(w, "PLAN", "plan:4", "made", {"share": 900, "cost": 700})
	Logbook.note(w, "QUOTE", "co:builder2", "quoted", {"price": 5000, "wait": 3}, {}, "plan:4", "plan:4")
	Logbook.note(w, "CONTRACT", "plan:4", "signed", {}, {}, "co:builder2", "contract:9")
	Logbook.note(w, "WORK", "co:builder2", "built", {"work": 40}, {}, "plan:4", "contract:9")
	Logbook.note(w, "OPEN", "co:31", "opened", {}, {}, "", "plan:4")
	check_eq(Logbook.story(w, "plan:4").size(), 4, "the plan's story has both sides of its deals")
	check_eq(Logbook.story(w, "co:builder2").size(), 3, "and so has the builder's")
	check_eq(Logbook.rows(w, {"ref": "contract:9"}).size(), 2, "every row about one contract")
	var opened: Array = Logbook.rows(w, {"ref": "plan:4", "kind": "OPEN"})
	check_eq(String(opened[0]["who"]), "co:31", "the opening leads from the plan to the company")


func test_what_was_logged_cannot_be_changed_afterwards() -> void:
	var w := _sim(1).world
	var why := {"sold": 100}
	Logbook.note(w, "RULE", "co:1", "R1 raise price", why)
	why["sold"] = 5
	check_eq(int(Logbook.rows(w)[0]["why"]["sold"]), 100, "the writer changing its numbers later does not change the row")
	Logbook.rows(w)[0]["why"]["sold"] = 7
	Logbook.rows(w)[0]["what"] = "something else"
	check_eq(int(Logbook.rows(w)[0]["why"]["sold"]), 100, "a reader cannot change the row either")
	check_eq(String(Logbook.rows(w)[0]["what"]), "R1 raise price", "nor what it says happened")


func test_writing_to_the_log_never_changes_the_game() -> void:
	var a := _sim(42)
	var b := _sim(42)
	for i in 24:
		a.step()
		b.step()
		Logbook.note(b.world, "RULE", "co:%d" % i, "R1 raise price", {"i": i})
	check_eq(a.world.state_hash(), b.world.state_hash(), "the same game with and without a log")
	check_eq(Logbook.rows(b.world).size(), 24, "and the log is there")
	check_eq(Logbook.rows(a.world).size(), 0, "each world has its own log")
	check(not b.world.to_dict().has("log_rows"), "the log is not saved")


func test_no_game_code_reads_the_log() -> void:
	# Otto's review: the log must never become something a rule decides from. Game code may write, trim and clear only.
	var bad: Array = []
	var stack: Array = ["res://sim"]
	while not stack.is_empty():
		var d: String = stack.pop_back()
		for sub in DirAccess.get_directories_at(d):
			stack.append(d.path_join(sub))
		for f in DirAccess.get_files_at(d):
			if not f.ends_with(".gd") or f == "logbook.gd":
				continue
			var text := FileAccess.get_file_as_string(d.path_join(f))
			for reader in ["Logbook.rows", "Logbook.counts", "Logbook.story", "Logbook.write", ".log_rows"]:
				if text.contains(reader):
					bad.append("%s uses %s" % [d.path_join(f), reader])
	check(bad.is_empty(), "no file under sim/ reads the log (%s)" % ", ".join(bad))


func test_the_log_is_written_to_a_file_and_old_rows_can_be_dropped() -> void:
	var w := _sim(1).world
	for m in 30:
		w.month = 29 - m   # written out of month order on purpose
		Logbook.note(w, "SALE", "co:1", "sold FOOD", {"qty": m})
	w.month = 29
	var path := save_path("logbook.jsonl")
	check_eq(Logbook.write(w, path), 30, "thirty rows written")
	check_eq(Logbook.write(w, path, {"from": 20}), 10, "or only the ones that match")
	var f := FileAccess.open(path, FileAccess.READ)
	var first = JSON.parse_string(f.get_line())
	f.close()
	check_eq(String(first["what"]), "sold FOOD", "one JSON object per line")
	var keep := Logbook.keep_months
	Logbook.keep_months = 12
	Logbook.trim(w)
	Logbook.keep_months = keep
	check_eq(Logbook.rows(w).size(), 13, "the current month and the twelve before it are kept, whatever order they were written in")
	check_eq(Logbook.rows(w, {"to": 16}).size(), 0, "nothing older")

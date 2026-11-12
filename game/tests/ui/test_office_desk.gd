extends TestCase
## Terra (A44 §O3–O4): the drawn office desk and the office-view setting (user://, never the world).

const OfficePanel := preload("res://ui/panels/office_panel.gd")
const TEST_CFG := "user://test_settings.cfg"


func _use_test_settings() -> void:
	UserSettings.use_file(TEST_CFG)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_CFG))
	UserSettings.reload()


func _restore() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_CFG))
	UserSettings.use_file("")


func test_setting_is_saved_outside_the_world() -> void:
	_use_test_settings()
	check_eq(UserSettings.office_view(), "TABS", "tabs by default")
	var s := GameSession.new()
	s.new_game(3, true)
	var h := s.world().state_hash()
	check_eq(UserSettings.set_office_view("OFFICE"), OK, "saved")
	UserSettings.reload()
	check_eq(UserSettings.office_view(), "OFFICE", "read back from the file")
	check_eq(s.world().state_hash(), h, "the world never sees the setting")
	_restore()


func test_desk_shows_the_office_and_opens_tabs() -> void:
	_use_test_settings()
	var s := GameSession.new()
	s.new_game(3, true)
	var w := s.world()
	var m := w.month
	Office.post(w, {"kind": "REPORT", "subject": "r", "source": {"system": "T", "ref": "r"}})
	Office.post(w, {"kind": "EMAIL", "subject": "e", "deadline": m + 1, "options": [{"id": "Y", "label": "Y", "action": {}}],
		"default_option": "Y", "source": {"system": "T", "ref": "e"}})
	Office.post(w, {"kind": "CALL", "subject": "c", "deadline": m + 1, "options": [{"id": "Y", "label": "Y", "action": {}}],
		"default_option": "Y", "source": {"system": "T", "ref": "c"}})
	var p = OfficePanel.new()
	p.setup(s)
	p.size = Vector2(1280, 720)
	p.refresh()
	check(not p.desk.visible and p.bar.visible, "TABS: the plain tabs")
	UserSettings.set_office_view("OFFICE")
	p.refresh()
	check(p.desk.visible and not p.bar.visible, "OFFICE: the desk")
	var d: Dictionary = p.desk.gather()
	check_eq(int(d["reports_new"]), 1, "the in-tray counts unread reports")
	check_eq(int(d["inbox"]), 1, "the PC counts the inbox")
	check_eq(int(d["urgent"]), 1, "and what is due now")
	check_eq(int(d["calls"]), 1, "the phone rings")
	check(d["marks"].has(m + 1), "the calendar marks the deadline")
	var tabs := {"paper": "Paper", "tray": "Reports", "pc": "Inbox", "phone": "Calls", "calendar": "Calendar", "door": "Visitors"}
	for obj in tabs:
		p.at_desk = true
		p.refresh()
		p.desk.click(obj)
		check_eq(p.tab, tabs[obj], "%s opens %s" % [obj, tabs[obj]])
		check(not p.desk.visible and p.bar.visible, "the tab replaces the desk")
	var out := [false]
	p.outside_requested.connect(func(): out[0] = true)
	p.at_desk = true
	p.refresh()
	p.desk.click("window")
	check(out[0], "the window looks outside")
	check_eq(p.desk.spot_at(Vector2(560, 380)), "pc", "hotspots on the canvas")
	check_eq(p.desk.spot_at(Vector2(5, 5)), "", "the bare wall is not an object")
	p.free()
	_restore()

extends SceneTree
## Terra (A44): render the office's drawn desk to a PNG (needs a window, not --headless).
## godot --path game --script res://tools/shot_office.gd -- <seed> <out.png> [months] [click: paper|tray|pc|phone|calendar|door] [w] [h] [planet|map] [storm|-] [3d]
## Uses its own settings file (user://shot_settings.cfg), so the player's settings stay untouched.
const OfficePanel := preload("res://ui/panels/office_panel.gd")
var _panel
var _frames := 0
var _out := "user://office.png"
var _click := ""


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_v := int(args[0]) if args.size() > 0 else 1
	if args.size() > 1:
		_out = args[1]
	var months := int(args[2]) if args.size() > 2 else 30
	_click = args[3] if args.size() > 3 else ""
	var sz := Vector2i(int(args[4]) if args.size() > 4 else 1280, int(args[5]) if args.size() > 5 else 720)
	UserSettings.use_file("user://shot_settings.cfg")
	UserSettings.set_office_view("DESK3D" if args.size() > 8 and args[8] == "3d" else "DESK2D")
	var s := GameSession.new()
	s.new_game(seed_v, true)
	for _m in months:
		s.end_month()
	_demo(s.world())
	if args.size() > 7 and args[7] == "storm":   # a strong rain front over the colony this month
		var li := Planet.landing(s.world())
		s.world().table("planet")["storms"] = [{"id": "shot", "kind": "RAIN_FRONT", "strength": 4, "cells": [li], "global": false}]
	var bg := ColorRect.new()
	bg.color = Color("#23282e")
	bg.size = Vector2(sz)
	root.add_child(bg)
	_panel = OfficePanel.new()
	_panel.setup(s)
	root.size = sz
	_panel.size = Vector2(sz)
	root.add_child(_panel)


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 2:
		_panel.size = Vector2(root.size)
		(root.get_child(0) as ColorRect).size = Vector2(root.size)
		_panel.refresh()
		if OS.get_cmdline_user_args().size() > 6 and OS.get_cmdline_user_args()[6] == "planet":
			_panel.set_outside("PLANET")
			_panel.refresh()
		if _click != "":
			(_panel.desk3d if _panel.desk3d != null and _panel.desk3d.visible else _panel.desk).click(_click)
	if _frames < 14:
		return false
	root.get_texture().get_image().save_png(_out)
	print("saved ", _out)
	quit()
	return true



## A busy morning for the picture: reports, emails (one due now), a call, a calendar entry and a candidate at the door.
static func _demo(w: WorldState) -> void:
	var m := w.month
	for i in 4:
		Office.post(w, {"kind": "REPORT", "subject": "Monthly report %d" % i, "summary": "Figures for the month.", "source": {"system": "DEMO", "ref": "r%d" % i}})
	for i in 3:
		Office.post(w, {"kind": "EMAIL", "subject": "Question %d" % i, "summary": "Please decide.", "deadline": m + (1 if i == 0 else 3 + i),
			"options": [{"id": "YES", "label": "Yes", "action": {}}], "default_option": "YES", "source": {"system": "DEMO", "ref": "e%d" % i}})
	Office.post(w, {"kind": "CALL", "subject": "The union is on the line", "summary": "They want an answer today.", "deadline": m + 1,
		"options": [{"id": "OK", "label": "Take the call", "action": {}}], "default_option": "OK", "source": {"system": "DEMO", "ref": "c0"}})
	Office.post(w, {"kind": "CALENDAR", "subject": "Budget day", "deadline": m + 5, "source": {"system": "DEMO", "ref": "k0"}})
	load("res://sim/staff/staff_ops.gd").open_recruitment(w, "CHIEF_OF_STAFF")

class_name UserSettings
extends RefCounted
## The player's own settings (A44 §O4): saved in user://settings.cfg, never in the world state or saves.
##   ui.office_view = "TABS" | "DESK2D" | "DESK3D"   (plain tabs, the drawn desk, the 3D office; "OFFICE" = DESK2D)
## No static state (static vars were reset under us): the file path lives in an Engine meta, and the small file is
## read on each call.

const DEFAULTS := {"ui": {"office_view": "TABS"}}
const DEFAULT_PATH := "user://settings.cfg"
const META := "user_settings_path"


static func path() -> String:
	return String(Engine.get_meta(META, DEFAULT_PATH))


## Use another settings file (tests and screenshot tools, so the player's own file stays untouched); "" = the real one.
static func use_file(p: String) -> void:
	Engine.set_meta(META, p if p != "" else DEFAULT_PATH)


static func _file() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(path())   # a missing file just means defaults
	return cfg


static func get_value(section: String, key: String) -> Variant:
	return _file().get_value(section, key, DEFAULTS.get(section, {}).get(key, null))


static func set_value(section: String, key: String, value: Variant) -> Error:
	var cfg := _file()
	cfg.set_value(section, key, value)
	return cfg.save(path())


## Kept for callers that want a re-read; reading is always fresh.
static func reload() -> void:
	pass


const OFFICE_VIEWS := ["TABS", "DESK2D", "DESK3D"]


static func office_view() -> String:
	var v := String(get_value("ui", "office_view"))
	if v == "OFFICE":   # the first drawn desk's name
		return "DESK2D"
	return v if v in OFFICE_VIEWS else "TABS"


static func set_office_view(v: String) -> Error:
	if v == "OFFICE":
		v = "DESK2D"
	assert(v in OFFICE_VIEWS, "office_view is TABS, DESK2D or DESK3D")
	return set_value("ui", "office_view", v)

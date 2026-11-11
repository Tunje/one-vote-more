extends RefCounted
## Helpers for staff/law tests: bare worlds and hand-made people with exact stats.

const Ops := preload("res://sim/staff/staff_ops.gd")
const D := preload("res://sim/staff/staff_data.gd")
const LawProvider := preload("res://sim/law/law_provider.gd")
const StaffProvider := preload("res://sim/staff/staff_provider.gd")


## A WorldState with law + staff levers defined but no founding roster (use add() to make people).
static func bare_world(seed_value: int = 1) -> WorldState:
	var w := WorldState.new(seed_value)
	for p in [LawProvider.new(), StaffProvider.new()]:
		for d in p.lever_defs():
			w.define_lever(d)
	return w


## A full simulation (law + staff, founding roster and slate).
static func sim(seed_value: int = 1, autoplay: bool = false) -> Simulation:
	var s := Simulation.new(seed_value, [LawProvider.new(), StaffProvider.new()])
	s.world.meta["staff_autoplay"] = autoplay
	s.new_game()
	return s


## kind: "CIVIL" | "POLITICAL". skills: {SKILL: n}; other skills default to 20.
static func add(w: WorldState, kind: String, skills: Dictionary, speed: int = 50, reliability: int = 100,
		party: String = "", talents: Array = []) -> String:
	var sk := {}
	for s in D.SKILLS:
		sk[s] = int(skills.get(s, 20))
	var p := {"name": "T", "birth_month": w.month - 40 * 12, "party_id": party,
		"roles": ["CIVIL_SERVANT"] if kind == "CIVIL" else ["GOV_POLITICAL"], "skills": sk, "talents": talents,
		"work_speed": speed, "reliability": reliability, "integrity": 70, "xp": {}, "status": "ACTIVE",
		"unavailable_until": -1, "assignment_id": "", "specialization": "TEST", "career": []}
	return Ops.add_person(w, p, "GOV", "")


## Advance only the staff work step (no lifecycle), one month.
static func work_month(w: WorldState) -> void:
	Ops.state(w)["flags"] = {}
	Ops.process_tasks(w)
	w.month += 1


static func set_pol(w: WorldState, st: Dictionary) -> void:
	w.table("pol")["state"] = st


## Per-process save path: several sessions run the suite in parallel and user:// is shared between processes,
## so a fixed path lets one run overwrite another's save mid-test (cross-process flake).
static func save_path(file_name: String) -> String:
	return "user://test_saves/%d/%s" % [OS.get_process_id(), file_name]

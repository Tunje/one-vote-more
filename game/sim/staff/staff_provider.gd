extends PicProvider
## Staff subsystem provider (planning/spec-staff-v1.md §11, pic-staff-law.md). Stateless.

const Ops := preload("res://sim/staff/staff_ops.gd")


func owner_id() -> String:
	return "staff"


func indicator_defs() -> Array:
	return [{
		"id": "STAFF_DELIVERY_INDEX", "owner": "staff", "unit": "%", "range": [0, 100 * 1000], "granularity": "COLONY",
		"polarity": 1, "concerns": {"GOVERNANCE": 0.35}, "normalize": {"good": 90 * 1000, "bad": 40 * 1000},
		"phase": TickPhase.STAFF, "visibility": "PUBLIC", "perceptionLag": 2,
	}]


func lever_defs() -> Array:
	return [
		{"id": "STAFF_CIVIL_RETIREMENT_AGE", "owner": "staff", "type": "NUMBER", "range": [60, 72], "default": 67,
			"legalLevel": "LAW", "foundingEra": "COMMANDER", "ideology": {}, "fiscal": "", "domain": "ADMIN",
			"implementation": "STAFF_T_IMPL_ADMIN", "lag": 12, "scope": "COLONY"},
		{"id": "STAFF_DEFAULT_AUTHORITY_PRESET", "owner": "staff", "type": "ENUM", "values": ["TIGHT", "STANDARD", "BROAD"],
			"default": "STANDARD", "legalLevel": "ADMIN", "foundingEra": "COMMANDER", "ideology": {"INSTITUTIONS": -5},
			"fiscal": "", "domain": "ADMIN", "implementation": "STAFF_T_IMPL_ADMIN", "lag": 0, "scope": "COLONY"},
	]


func action_defs() -> Array:
	return preload("res://sim/staff/staff_law_actions.gd").ACTION_DEFS.filter(func(a): return a["owner"] == "staff")


func phases() -> Array:
	return [TickPhase.DECISIONS, TickPhase.STAFF, TickPhase.EVENTS, TickPhase.RECORD]


func init_world(world: WorldState) -> void:
	Ops.init_founding(world)


func run_phase(phase: int, world: WorldState) -> void:
	match phase:
		TickPhase.DECISIONS:
			Ops.ensure_benches(world)
			Ops.sync_politics(world)
			Ops.auto_appoint(world)
			Ops.auto_answer(world)
			preload("res://sim/staff/opposition.gd").run_ai(world)
			_auto_staff_all(world)
		TickPhase.STAFF:
			Ops.state(world)["flags"] = {}
			Ops.lifecycle(world)
			Ops.process_recruitment(world)
			Ops.process_tasks(world)
			Ops.check_deadlines(world)
			Ops.delivery(world)
		TickPhase.EVENTS:
			# Follow a government formed in POLITICS this month (seats, departing officials, opposition pools).
			Ops.ensure_benches(world)
			Ops.sync_politics(world)
		TickPhase.RECORD:
			Ops.make_reports(world)


func _auto_staff_all(world: WorldState) -> void:
	if Ops.autopilot(world, Ops.GOV):
		Ops.auto_staff(world, Ops.GOV)
	for pid in world.table("party"):
		var owner := {"kind": "PARTY", "id": pid}
		if Ops.autopilot(world, owner):
			Ops.auto_staff(world, owner)

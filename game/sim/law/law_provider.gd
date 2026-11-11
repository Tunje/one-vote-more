extends PicProvider
## Law subsystem provider, thin v1 + M6 prep (planning/spec-law-v1.md, pic-staff-law.md §1).
## Single writer of operative lever values (A8). Register BEFORE StaffProvider and PoliticsProvider.

const Ops := preload("res://sim/law/law_ops.gd")
const L := preload("res://sim/law/law_data.gd")
const Vis := preload("res://sim/law/visibility.gd")
const PF := preload("res://sim/law/party_finance.gd")
const CO := preload("res://sim/law/charter_ops.gd")


func owner_id() -> String:
	return "law"


func lever_defs() -> Array:
	return L.LEVERS


## Normalize values are milli-units (indicator values are stored x1000). Weights and ranges: see INDICATOR_TUNING.
func indicator_defs() -> Array:
	return [
		_ind("LAW_RULE_OF_LAW", "index 0-100", "COLONY", 1, L.INDICATOR_TUNING["LAW_RULE_OF_LAW"], 0),
		_ind("LAW_TRUST_IN_JUSTICE", "index 0-100", "VOTER_CELL", 1, L.INDICATOR_TUNING["LAW_TRUST_IN_JUSTICE"], 0),
		_ind("LAW_PERMIT_WAIT", "months", "DISTRICT", -1, L.INDICATOR_TUNING["LAW_PERMIT_WAIT"], 1),
		_ind("LAW_WORKPLACE_SAFETY", "accidents per 1,000 workers per year", "DISTRICT", -1,
			L.INDICATOR_TUNING["LAW_WORKPLACE_SAFETY"], 1),
		_ind("LAW_ENFORCEMENT_CONSISTENCY", "%", "COLONY", 1, L.INDICATOR_TUNING["LAW_ENFORCEMENT_CONSISTENCY"], 3),
		_ind("LAW_COURT_DURATION", "months", "COLONY", -1, L.INDICATOR_TUNING["LAW_COURT_DURATION"], 3),
	]


func _ind(id: String, unit: String, gran: String, polarity: int, tune: Dictionary, lag: int) -> Dictionary:
	return {"id": id, "owner": "law", "unit": unit, "range": tune["range"], "granularity": gran, "polarity": polarity,
		"concerns": tune["concerns"], "normalize": tune["normalize"], "phase": TickPhase.JUSTICE,
		"visibility": "PUBLIC", "perceptionLag": lag, "exceptionOnly": tune.get("exceptionOnly", false)}


func action_defs() -> Array:
	return preload("res://sim/staff/staff_law_actions.gd").ACTION_DEFS.filter(func(a): return a["owner"] == "law")


func phases() -> Array:
	return [TickPhase.DECISIONS, TickPhase.JUSTICE, TickPhase.EVENTS]


func init_world(world: WorldState) -> void:
	Ops.init_world(world)


func run_phase(phase: int, world: WorldState) -> void:
	match phase:
		TickPhase.DECISIONS:
			Ops.ensure_m11_rules(world)
			CO.ensure_m12(world)
			Ops.emergency_tick(world)
			Vis.note_government(world)
			Ops.maybe_adopt_constitution(world)
			Ops.run_pipeline(world)
		TickPhase.JUSTICE:
			Ops.process_permits(world)
			Ops.discover(world)
			Ops.decay_greed_evidence(world)
			Ops.Justice.run(world)
			PF.run(world)
			Ops.write_indicators(world)
		TickPhase.EVENTS:
			# Politics forms governments in POLITICS (after DECISIONS): adopt the constitution the same month,
			# so there is no month in which neither commander nor government powers apply.
			Vis.note_government(world)
			Ops.maybe_adopt_constitution(world)

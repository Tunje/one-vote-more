extends PicProvider
## Law subsystem provider, thin v1 + M6 prep (planning/spec-law-v1.md, pic-staff-law.md §1).
## Single writer of operative lever values (A8). Register BEFORE StaffProvider and PoliticsProvider.

const Ops := preload("res://sim/law/law_ops.gd")
const L := preload("res://sim/law/law_data.gd")
const Vis := preload("res://sim/law/visibility.gd")
const PF := preload("res://sim/law/party_finance.gd")
const CO := preload("res://sim/law/charter_ops.gd")
const CD := preload("res://sim/law/charter_deal.gd")
const DL := preload("res://sim/law/districting.gd")
const Land := preload("res://sim/law/land_law.gd")


func _init() -> void:
	# M13: law decides which district a newly founded area joins (single writer of membership).
	AreaStore.district_resolver = func(world, area_id): return DL.district_for_new_area(world, area_id)


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
		_ind("LAW_CRIME_INDEX", "reported theft + 3 x violence per 10k a year", "DISTRICT", -1,
			L.INDICATOR_TUNING["LAW_CRIME_INDEX"], 1),
		_ind("LAW_FRAUD_RATE", "reported frauds per 10k a year", "DISTRICT", -1, L.INDICATOR_TUNING["LAW_FRAUD_RATE"], 1),
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
	Land.ensure_rules(world)   # the land rules from the start, so a plan in the first month can buy its land (Terra)


func run_phase(phase: int, world: WorldState) -> void:
	match phase:
		TickPhase.DECISIONS:
			Ops.ensure_m11_rules(world)
			Ops.ensure_work_rules(world)
			Ops.ensure_competition_rules(world)
			CO.ensure_m12(world)
			Land.ensure_rules(world)
			Media.ensure_rules(world)
			DL.ensure_founding_district(world)
			DL.tick(world)
			Ops.emergency_tick(world)
			Vis.note_government(world)
			Ops.maybe_adopt_constitution(world)
			Ops.run_pipeline(world)
			CD.check_revocation(world)
			preload("res://sim/law/competition_law.gd").monthly(world)     # merger reviews that are due
			preload("res://sim/law/road_law.gd").monthly(world)     # private-road licences and appeals (opt-in PRIVATE_ROADS)
			preload("res://sim/law/road_safety_law.gd").monthly(world)     # default and ministerial speed limits (opt-in ROAD_SAFETY)
		TickPhase.JUSTICE:
			Ops.process_permits(world)
			preload("res://sim/law/law_company.gd").reopen_licensed(world)   # a plant closed for want of a licence (step 3)
			Ops.discover(world)
			Ops.decay_greed_evidence(world)
			Ops.Justice.run(world)
			PF.run(world)
			Land.tick(world)
			preload("res://sim/law/road_safety_law.gd").justice(world)     # liability for road deaths (opt-in ROAD_SAFETY)
			preload("res://sim/law/crime.gd").monthly(world)     # P1a offences (opt-in CRIME), before the press reports
			preload("res://sim/law/police.gd").monthly(world)    # P1c misconduct, trust, arrests (opt-in POLICE)
			preload("res://sim/law/criminal.gd").monthly(world)  # P2a charges, courts, sentences, cells (opt-in PRISONS)
			Media.run(world)
			Ops.write_indicators(world)
		TickPhase.EVENTS:
			# Politics forms governments in POLITICS (after DECISIONS): adopt the constitution the same month,
			# so there is no month in which neither commander nor government powers apply.
			Vis.note_government(world)
			Ops.maybe_adopt_constitution(world)

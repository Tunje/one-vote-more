extends RefCounted
## Staff v1 definitions (planning/spec-staff-v1.md). Data-as-code: constants only, no state.
## Thresholds, weights and work sizes are copied from the spec tables. Change balance here, not in logic.

const SKILLS := ["ADMIN", "ECON", "ENG", "LOGI", "LAW", "NEGO", "POLI", "COMM", "ENV", "PUBS"]

# ---------------------------------------------------------------- work model (spec §2)
const B_MANDATORY := 10.0
const B_OPTIONAL := 5.0
const T_CAP := 1.5
const MODE_W := {"RUSH": 1.25, "NORMAL": 1.0, "CAREFUL": 0.85}
const MODE_Q := {"RUSH": -15, "NORMAL": 0, "CAREFUL": 10}
const ALIGN_AGREEMENT := 1.10
const ALIGN_NEGOTIABLE := 0.80
const MAX_OPTIONAL := 2

# ---------------------------------------------------------------- talents (spec §4)
## t = work multiplier, q = quality bonus, tags = task tags it applies to ("ALL" = every task).
const TALENTS := {
	"FAST_LEARNER": {"xp": 1.5},
	"DETAIL_ORIENTED": {"q": 5, "q_tags": ["ALL"], "self_error": 0.5, "catch": 0.5},
	"SKILLED_MEDIATOR": {"t": 1.25, "q": 10, "tags": ["NEGOTIATION"]},
	"CRISIS_MANAGER": {"t": 1.25, "tags": ["CRISIS"]},
	"INDUSTRIAL_EXPERT": {"t": 1.20, "tags": ["INDUSTRY"]},
	"STRONG_ORGANIZER": {"team_c": 0.10, "team_q": 3},
	"CAUTIOUS_PLANNER": {"t": 0.90, "q": 10, "tags": ["ALL"]},
	"PERSUASIVE_SPEAKER": {"t": 1.20, "q": 10, "tags": ["CAMPAIGN", "COMMS"]},
	"PROCUREMENT_SPECIALIST": {"t": 1.20, "q": 10, "tags": ["PROCUREMENT"]},
	"FINANCIAL_ANALYST": {"t": 1.20, "q": 10, "tags": ["BUDGET", "FISCAL"]},
	"LEGAL_SPECIALIST": {"t": 1.20, "q": 10, "tags": ["DRAFTING", "LEGAL"]},
	"FIELD_SUPERVISOR": {"t": 1.20, "tags": ["SUPERVISION"], "detect": 0.10},
	"ADAPTABLE": {"k_floor": 0.85},
	"INSTITUTIONAL_MEMORY": {"t": 1.15, "q": 5, "tags": ["STANDING"], "civil_only": true},
	"PROBLEM_SOLVER": {"unblock": 1},   # hook for resource-blocked tasks (econ, M4)
	"RESOURCEFUL": {"cost": 0.9},
}
const TALENT_ORDER := [
	"FAST_LEARNER", "DETAIL_ORIENTED", "SKILLED_MEDIATOR", "CRISIS_MANAGER", "INDUSTRIAL_EXPERT",
	"STRONG_ORGANIZER", "CAUTIOUS_PLANNER", "PERSUASIVE_SPEAKER", "PROCUREMENT_SPECIALIST",
	"FINANCIAL_ANALYST", "LEGAL_SPECIALIST", "FIELD_SUPERVISOR", "ADAPTABLE", "INSTITUTIONAL_MEMORY",
	"PROBLEM_SOLVER", "RESOURCEFUL",
]
## Cumulative probability of 0 / 1 / 2 talents (30 / 50 / 20 %).
const TALENT_COUNT_CDF := [0.30, 0.80, 1.00]

# ---------------------------------------------------------------- generation (spec §5)
const GEN := {
	"CIVIL": {"age": [30, 58], "primary": [68, 85], "secondary": [45, 65], "other": [15, 45],
		"speed": [30, 55], "reliability": [60, 90], "integrity": [50, 95]},
	"POLITICAL": {"age": [28, 62], "primary": [58, 78], "secondary": [40, 60], "other": [10, 40],
		"speed": [55, 80], "reliability": [45, 80], "integrity": [30, 90]},
}

const CIVIL_TEMPLATES := [
	{"spec": "FINANCE", "primary": "ECON", "secondary": ["ADMIN", "LAW"]},
	{"spec": "ENGINEERING", "primary": "ENG", "secondary": ["LOGI", "ADMIN"]},
	{"spec": "LOGISTICS", "primary": "LOGI", "secondary": ["ADMIN", "ENG"]},
	{"spec": "PROCUREMENT", "primary": "ADMIN", "secondary": ["ECON", "LAW"], "talent": "PROCUREMENT_SPECIALIST"},
	{"spec": "LAW", "primary": "LAW", "secondary": ["ADMIN", "POLI"]},
	{"spec": "PUBLIC_ADMINISTRATION", "primary": "ADMIN", "secondary": ["PUBS", "COMM"]},
	{"spec": "INFRASTRUCTURE", "primary": "ENG", "secondary": ["ENV", "ADMIN"]},
	{"spec": "HEALTHCARE", "primary": "PUBS", "secondary": ["ADMIN", "ECON"]},
	{"spec": "ENVIRONMENT", "primary": "ENV", "secondary": ["ENG", "LAW"]},
	{"spec": "ECONOMIC_DEVELOPMENT", "primary": "ECON", "secondary": ["NEGO", "ENG"]},
]

## "sector" picks its primary from SECTOR_PRIMARIES; "manager" picks one secondary from MANAGER_SECONDARY.
const ARCHETYPES := {
	"STRATEGIST": {"primary": "POLI", "secondary": ["COMM", "NEGO"]},
	"NEGOTIATOR": {"primary": "NEGO", "secondary": ["POLI", "ECON"]},
	"COMMUNICATOR": {"primary": "COMM", "secondary": ["POLI"]},
	"JURIST": {"primary": "LAW", "secondary": ["POLI", "ADMIN"]},
	"ECONOMIST": {"primary": "ECON", "secondary": ["POLI"]},
	"MANAGER": {"primary": "ADMIN", "secondary": []},
	"SECTOR": {"primary": "", "secondary": ["POLI"]},
}
const SECTOR_PRIMARIES := ["ENG", "PUBS", "ENV"]
const MANAGER_SECONDARY := ["ENG", "PUBS"]
## Founding appointees: the 10 recommended picks follow the spec §5.2 quota.
const FOUNDING_ARCHETYPES := ["STRATEGIST", "STRATEGIST", "NEGOTIATOR", "NEGOTIATOR", "COMMUNICATOR",
	"COMMUNICATOR", "JURIST", "ECONOMIST", "MANAGER", "SECTOR"]
const FOUNDING_CANDIDATES := 16
## Bench order guarantees LAW, NEGO and COMM people in any bench of size >= 6.
const BENCH_ARCHETYPES := ["JURIST", "NEGOTIATOR", "COMMUNICATOR", "STRATEGIST", "ECONOMIST", "MANAGER",
	"SECTOR", "NEGOTIATOR", "COMMUNICATOR", "STRATEGIST"]
const BENCH_REQUIRED := {"LAW": 50, "NEGO": 50, "COMM": 50}
const VALIDATOR_MAX_RETRIES := 50

# ---------------------------------------------------------------- lifecycle (spec §6)
const P_ILLNESS := 0.003
const ILLNESS_MONTHS := [1, 3]
const P_CIVIL_DEPART := 0.001
const P_POLITICAL_RETIRE_60 := 0.002
const POLITICAL_MANDATORY_RETIRE := 72
const P_DEATH_UNDER_60 := 0.0005
const P_DEATH_60 := 0.002
const HIRE_LAG_MONTHS := 2
const SHORTLIST_SIZE := 3
const XP_BASE := 10.0
const TIER_D := {1: 1.0, 2: 1.5, 3: 2.0}
const TRAINING_GAIN := 5
const TRAINING_GAIN_FAST := 8
const TRAINING_CAP := 85
const TRAINING_COST_WREF := 10

# ---------------------------------------------------------------- politics (spec §7, §8)
const POLITICAL_SEATS := 10
const BENCH_BASE := 6
const BENCH_NEW_PER_ELECTION := 3
const BENCH_DEFUNCT := 3

# ---------------------------------------------------------------- delegation (spec §9)
const PRESETS := {
	"TIGHT": {"single_pct": 0.02, "overrun": 0.00, "slip": 0, "auto_admin": false, "retender": false, "variation": 0.0},
	"STANDARD": {"single_pct": 0.10, "overrun": 0.05, "slip": 2, "auto_admin": true, "retender": false, "variation": 0.0},
	"BROAD": {"single_pct": 0.25, "overrun": 0.10, "slip": 4, "auto_admin": true, "retender": true, "variation": 0.10},
}

# ---------------------------------------------------------------- reports (spec §11)
const REPORT_PRIORITY := {"DECISION_REQUIRED": 90, "COMPLETED": 60, "ATTENTION": 50, "ROUTINE": 10, "AVAILABLE": 5}
const REPORT_KEEP_MONTHS := 12

# ---------------------------------------------------------------- task catalogue (spec §10)
## Position paths: any one path qualifies. "DOMAIN" resolves to params.domain (default ADMIN).
## work: base + per_<param> * params[<param>]. Coverage tasks use monthly_required (or by_size).
## stages (SEQUENTIAL): {"share": f, "owners": [pos idx]} or {"months": n}.
const TASKS := {
	# ----- political
	"STAFF_T_DRAFT_BILL": {"category": "POLITICAL", "mode": "COORDINATED", "tags": ["DRAFTING"], "tier": 2,
		"owners": ["GOVERNMENT", "PARTY"], "work": {"base": 30, "per_clauses": 20},
		"positions": [
			{"role": "Legal drafter", "mandatory": true, "weights": {"LAW": 0.8, "ADMIN": 0.2},
				"paths": [{"min": {"LAW": 50}}, {"min": {"LAW": 35}, "talents": ["LEGAL_SPECIALIST"]}]},
			{"role": "Policy lead", "mandatory": true, "weights": {"DOMAIN": 0.7, "POLI": 0.3},
				"paths": [{"min": {"DOMAIN": 50}}]},
			{"role": "Second policy lead", "mandatory": true, "min_clauses": 4, "weights": {"DOMAIN": 0.7, "POLI": 0.3},
				"paths": [{"min": {"DOMAIN": 50}}]},
			{"role": "Political coordinator", "mandatory": false, "weights": {"POLI": 1.0},
				"paths": [{"min": {"POLI": 40}}]},
		]},
	"STAFF_T_REVISE_BILL": {"category": "POLITICAL", "mode": "COORDINATED", "tags": ["DRAFTING"], "tier": 1,
		"owners": ["GOVERNMENT", "PARTY"], "work": {"base": 10, "per_changed": 10},
		"positions": [
			{"role": "Legal drafter", "mandatory": true, "weights": {"LAW": 0.8, "ADMIN": 0.2}, "paths": [{"min": {"LAW": 45}}]},
			{"role": "Policy lead", "mandatory": false, "weights": {"DOMAIN": 0.7, "POLI": 0.3}, "paths": [{"min": {"DOMAIN": 45}}]},
		]},
	"STAFF_T_DRAFT_ORDINANCE": {"category": "POLITICAL", "mode": "COORDINATED", "tags": ["DRAFTING"], "tier": 1,
		"owners": ["GOVERNMENT"], "work": {"base": 15, "per_clauses": 10},
		"positions": [
			{"role": "Legal drafter", "mandatory": true, "weights": {"LAW": 0.8, "ADMIN": 0.2}, "paths": [{"min": {"LAW": 45}}]},
			{"role": "Policy lead", "mandatory": false, "weights": {"DOMAIN": 0.7, "POLI": 0.3}, "paths": [{"min": {"DOMAIN": 45}}]},
		]},
	"STAFF_T_BUDGET": {"category": "POLITICAL", "mode": "COORDINATED", "tags": ["BUDGET"], "tier": 2,
		"owners": ["GOVERNMENT"], "work": {"base": 80},
		"positions": [
			{"role": "Budget lead", "mandatory": true, "weights": {"ECON": 0.7, "ADMIN": 0.3}, "paths": [{"min": {"ECON": 55}}]},
			{"role": "Budget officer", "mandatory": true, "weights": {"ADMIN": 1.0}, "paths": [{"min": {"ADMIN": 45}}]},
			{"role": "Political adviser", "mandatory": false, "weights": {"POLI": 1.0}, "paths": [{"min": {"POLI": 40}}]},
		]},
	"STAFF_T_COALITION_NEGOTIATION": {"category": "POLITICAL", "mode": "COORDINATED", "tags": ["PARTY", "NEGOTIATION"], "tier": 2,
		"owners": ["PARTY"], "caretaker_ok": true, "work": {"base": 0, "per_partners": 30},
		"positions": [
			{"role": "Negotiator", "mandatory": true, "weights": {"NEGO": 0.7, "POLI": 0.3}, "paths": [{"min": {"NEGO": 50}}]},
			{"role": "Political lead", "mandatory": true, "weights": {"POLI": 1.0}, "paths": [{"min": {"POLI": 50}}]},
			{"role": "Policy adviser", "mandatory": false, "weights": {"ECON": 0.5, "LAW": 0.5},
				"paths": [{"min": {"ECON": 45}}, {"min": {"LAW": 45}}]},
		]},
	"STAFF_T_SUPPORT_NEGOTIATION": {"category": "POLITICAL", "mode": "COORDINATED", "tags": ["PARTY", "NEGOTIATION"], "tier": 1,
		"owners": ["PARTY"], "work": {"base": 15, "per_targets": 5},
		"positions": [
			{"role": "Negotiator", "mandatory": true, "weights": {"NEGO": 0.7, "POLI": 0.3}, "paths": [{"min": {"NEGO": 45}}]},
			{"role": "Political adviser", "mandatory": false, "weights": {"POLI": 1.0}, "paths": [{"min": {"POLI": 40}}]},
		]},
	"STAFF_T_AGENDA": {"category": "POLITICAL", "mode": "COORDINATED", "tags": ["PARTY"], "tier": 1,
		"owners": ["PARTY"], "work": {"base": 40},
		"positions": [
			{"role": "Strategist", "mandatory": true, "weights": {"POLI": 0.7, "COMM": 0.3}, "paths": [{"min": {"POLI": 50}}]},
			{"role": "Communicator", "mandatory": false, "weights": {"COMM": 1.0}, "paths": [{"min": {"COMM": 40}}]},
		]},
	"STAFF_T_CAMPAIGN": {"category": "POLITICAL", "mode": "PARALLEL", "coverage": true, "tags": ["PARTY", "CAMPAIGN"], "tier": 2,
		"owners": ["PARTY"], "monthly_required": 30,
		"positions": [
			{"role": "Campaign lead", "mandatory": true, "weights": {"COMM": 0.7, "POLI": 0.3}, "paths": [{"min": {"COMM": 50}}]},
			{"role": "Strategist", "mandatory": false, "weights": {"POLI": 1.0}, "paths": [{"min": {"POLI": 45}}]},
			{"role": "Organiser", "mandatory": false, "weights": {"ADMIN": 1.0}, "paths": [{"min": {"ADMIN": 40}}]},
		]},
	"STAFF_T_POLL": {"category": "POLITICAL", "mode": "COORDINATED", "tags": ["PARTY"], "tier": 1,
		"owners": ["PARTY"], "work": {"base": 10}, "cost_wref": 20,
		"positions": [
			{"role": "Analyst", "mandatory": true, "weights": {"COMM": 0.5, "ECON": 0.5},
				"paths": [{"min": {"COMM": 35}}, {"min": {"ECON": 45}}]},
		]},
	"STAFF_T_OVERSIGHT": {"category": "POLITICAL", "mode": "COORDINATED", "tags": ["PARTY", "LEGAL"], "tier": 2,
		"owners": ["PARTY"], "work": {"base": 30},
		"positions": [
			{"role": "Investigator", "mandatory": true, "weights": {"LAW": 0.6, "ADMIN": 0.4},
				"paths": [{"min": {"LAW": 45}}, {"min": {"ADMIN": 55}}]},
			{"role": "Communicator", "mandatory": false, "weights": {"COMM": 1.0}, "paths": [{"min": {"COMM": 40}}]},
		]},
	"STAFF_T_LEGAL_CHALLENGE": {"category": "POLITICAL", "mode": "COORDINATED", "tags": ["PARTY", "LEGAL"], "tier": 1,
		"owners": ["PARTY"], "work": {"base": 20},
		"positions": [
			{"role": "Counsel", "mandatory": true, "weights": {"LAW": 1.0}, "paths": [{"min": {"LAW": 45}}]},
		]},
	"STAFF_T_GOV_COMMS": {"category": "POLITICAL", "mode": "PARALLEL", "tags": ["COMMS"], "tier": 1,
		"owners": ["GOVERNMENT"], "work": {"base": 15},
		"positions": [
			{"role": "Communicator", "mandatory": true, "weights": {"COMM": 1.0}, "paths": [{"min": {"COMM": 45}}]},
		]},
	# ----- implementation (one class per lever; pic-core §5)
	"STAFF_T_IMPL_FISCAL": {"category": "IMPLEMENTATION", "mode": "COORDINATED", "tags": ["IMPLEMENTATION", "FISCAL"], "tier": 1,
		"owners": ["GOVERNMENT"], "work": {"base": 10, "per_levers": 5},
		"positions": [
			{"role": "Fiscal officer", "mandatory": true, "weights": {"ECON": 0.6, "ADMIN": 0.4},
				"paths": [{"min": {"ECON": 45}}, {"min": {"ADMIN": 50}}]},
		]},
	"STAFF_T_IMPL_REGULATORY": {"category": "IMPLEMENTATION", "mode": "COORDINATED", "tags": ["IMPLEMENTATION"], "tier": 2,
		"owners": ["GOVERNMENT"], "work": {"base": 30, "per_levers": 15},
		"positions": [
			{"role": "Implementation lead", "mandatory": true, "weights": {"ADMIN": 1.0}, "paths": [{"min": {"ADMIN": 50}}]},
			{"role": "Domain specialist", "mandatory": true, "weights": {"DOMAIN": 1.0}, "paths": [{"min": {"DOMAIN": 45}}]},
			{"role": "Legal adviser", "mandatory": false, "weights": {"LAW": 1.0}, "paths": [{"min": {"LAW": 45}}]},
		]},
	"STAFF_T_IMPL_PROGRAM": {"category": "IMPLEMENTATION", "mode": "SEQUENTIAL", "tags": ["IMPLEMENTATION"], "tier": 2,
		"owners": ["GOVERNMENT"], "work": {"base": 50, "per_levers": 20},
		"stages": [{"share": 0.4, "owners": [0, 1]}, {"share": 0.6, "owners": [0, 1]}],
		"positions": [
			{"role": "Program lead", "mandatory": true, "weights": {"ADMIN": 1.0}, "paths": [{"min": {"ADMIN": 50}}]},
			{"role": "Domain specialist", "mandatory": true, "weights": {"DOMAIN": 1.0}, "paths": [{"min": {"DOMAIN": 50}}]},
			{"role": "Economic adviser", "mandatory": false, "weights": {"ECON": 1.0}, "paths": [{"min": {"ECON": 45}}]},
		]},
	"STAFF_T_IMPL_INSTITUTION": {"category": "IMPLEMENTATION", "mode": "SEQUENTIAL", "tags": ["IMPLEMENTATION"], "tier": 3,
		"owners": ["GOVERNMENT"], "work": {"base": 80},
		"stages": [{"share": 0.5, "owners": [0, 1]}, {"share": 0.5, "owners": [0, 1]}],
		"positions": [
			{"role": "Institution lead", "mandatory": true, "weights": {"ADMIN": 1.0}, "paths": [{"min": {"ADMIN": 55}}]},
			{"role": "Legal lead", "mandatory": true, "weights": {"LAW": 1.0}, "paths": [{"min": {"LAW": 45}}]},
			{"role": "Economic adviser", "mandatory": false, "weights": {"ECON": 1.0}, "paths": [{"min": {"ECON": 45}}]},
		]},
	"STAFF_T_IMPL_ADMIN": {"category": "IMPLEMENTATION", "mode": "COORDINATED", "tags": ["IMPLEMENTATION"], "tier": 1,
		"owners": ["GOVERNMENT"], "work": {"base": 5},
		"positions": [
			{"role": "Administrator", "mandatory": true, "weights": {"ADMIN": 1.0}, "paths": [{"min": {"ADMIN": 40}}]},
		]},
	# ----- projects & procurement
	"STAFF_T_PROCURE": {"category": "PROJECT", "mode": "SEQUENTIAL", "tags": ["PROCUREMENT"], "tier": 2,
		"owners": ["GOVERNMENT"], "work": {"base": 40},
		"stages": [{"share": 0.5, "owners": [0, 1]}, {"months": 1}, {"share": 0.5, "owners": [0, 1]}],
		"positions": [
			{"role": "Procurement lead", "mandatory": true, "weights": {"ADMIN": 0.7, "ECON": 0.3},
				"paths": [{"min": {"ADMIN": 50}}, {"min": {"ADMIN": 40}, "talents": ["PROCUREMENT_SPECIALIST"]}, {"min": {"ECON": 60}}]},
			{"role": "Technical adviser", "mandatory": true, "only_if": "construction", "weights": {"ENG": 1.0},
				"paths": [{"min": {"ENG": 50}}]},
			{"role": "Legal adviser", "mandatory": false, "weights": {"LAW": 1.0}, "paths": [{"min": {"LAW": 40}}]},
		]},
	"STAFF_T_SUPERVISE": {"category": "PROJECT", "mode": "PARALLEL", "coverage": true, "tags": ["SUPERVISION", "INDUSTRY"], "tier": 2,
		"owners": ["GOVERNMENT"], "by_size": {"SMALL": 6, "MEDIUM": 12, "LARGE": 24},
		"positions": [
			{"role": "Site supervisor", "mandatory": true, "weights": {"ENG": 0.7, "ADMIN": 0.3},
				"paths": [{"min": {"ENG": 55}}, {"min": {"ENG": 45}, "talents": ["FIELD_SUPERVISOR"]}]},
			{"role": "Logistics coordinator", "mandatory": false, "weights": {"LOGI": 1.0}, "paths": [{"min": {"LOGI": 45}}]},
			{"role": "Administrator", "mandatory": false, "weights": {"ADMIN": 1.0}, "paths": [{"min": {"ADMIN": 40}}]},
		]},
	"STAFF_T_REPORT": {"category": "PROJECT", "mode": "COORDINATED", "tags": ["FISCAL"], "tier": 1,
		"owners": ["GOVERNMENT"], "work": {"base": 20},
		"positions": [
			{"role": "Analyst", "mandatory": true, "weights": {"ECON": 1.0}, "paths": [{"min": {"ECON": 50}}]},
		]},
	# T7 (spec-transport-v1): the infrastructure department's traffic study (yearly, and after a serious accident).
	# Report quality follows the team's engineering skill (sim/staff/traffic_reports.gd).
	"STAFF_T_TRAFFIC_STUDY": {"category": "PROJECT", "mode": "COORDINATED", "tags": ["INDUSTRY"], "tier": 2,
		"owners": ["GOVERNMENT"], "work": {"base": 24},
		"positions": [
			{"role": "Traffic engineer", "mandatory": true, "weights": {"ENG": 0.8, "LOGI": 0.2},
				"paths": [{"min": {"ENG": 50}}, {"min": {"ENG": 40, "LOGI": 55}}]},
			{"role": "Second engineer", "mandatory": false, "weights": {"ENG": 1.0}, "paths": [{"min": {"ENG": 45}}]},
			{"role": "Data analyst", "mandatory": false, "weights": {"LOGI": 0.5, "ECON": 0.5},
				"paths": [{"min": {"LOGI": 40}}, {"min": {"ECON": 45}}]},
		]},
	"STAFF_T_TRAINING": {"category": "TRAINING", "mode": "PARALLEL", "tags": [], "tier": 1,
		"owners": ["GOVERNMENT", "PARTY"], "fixed_months": 3, "cost_wref": 10,
		"positions": [{"role": "Trainee", "mandatory": true, "weights": {}, "paths": [{"min": {}}]}]},
	# ----- standing duties
	"STAFF_SD_FINANCE": {"category": "STANDING", "mode": "PARALLEL", "coverage": true, "tags": ["STANDING", "BUDGET"], "tier": 1,
		"owners": ["GOVERNMENT"], "monthly_required": 12,
		"positions": [{"role": "Finance overseer", "mandatory": true, "weights": {"ECON": 0.7, "ADMIN": 0.3},
			"paths": [{"min": {"ECON": 50}}, {"min": {"ADMIN": 55}}]}]},
	"STAFF_SD_INFRA": {"category": "STANDING", "mode": "PARALLEL", "coverage": true, "tags": ["STANDING"], "tier": 1,
		"owners": ["GOVERNMENT"], "monthly_required": 12,
		"positions": [
			{"role": "Infrastructure overseer", "mandatory": true, "weights": {"ENG": 1.0}, "paths": [{"min": {"ENG": 45}}]},
			{"role": "Logistics", "mandatory": false, "weights": {"LOGI": 1.0}, "paths": [{"min": {"LOGI": 40}}]},
		]},
	"STAFF_SD_PROCUREMENT": {"category": "STANDING", "mode": "PARALLEL", "coverage": true, "tags": ["STANDING", "PROCUREMENT"], "tier": 1,
		"owners": ["GOVERNMENT"], "monthly_required": 10,
		"positions": [{"role": "Procurement officer", "mandatory": true, "weights": {"ADMIN": 1.0}, "paths": [{"min": {"ADMIN": 45}}]}]},
	"STAFF_SD_SERVICES": {"category": "STANDING", "mode": "PARALLEL", "coverage": true, "tags": ["STANDING"], "tier": 1,
		"owners": ["GOVERNMENT"], "monthly_required": 12,
		"positions": [{"role": "Services administrator", "mandatory": true, "weights": {"PUBS": 1.0}, "paths": [{"min": {"PUBS": 50}}]}]},
	"STAFF_SD_PERMITS": {"category": "STANDING", "mode": "PARALLEL", "coverage": true, "tags": ["STANDING", "LEGAL"], "tier": 1,
		"owners": ["GOVERNMENT"], "monthly_required": 10,
		"positions": [{"role": "Permit administrator", "mandatory": true, "weights": {"ADMIN": 0.6, "LAW": 0.4},
			"paths": [{"min": {"ADMIN": 45}}, {"min": {"LAW": 45}}]}]},
	"STAFF_SD_LEGAL": {"category": "STANDING", "mode": "PARALLEL", "coverage": true, "tags": ["STANDING", "LEGAL"], "tier": 1,
		"owners": ["GOVERNMENT"], "monthly_required": 8,
		"positions": [{"role": "Legal compliance", "mandatory": true, "weights": {"LAW": 1.0}, "paths": [{"min": {"LAW": 50}}]}]},
	"STAFF_SD_PARLIAMENT": {"category": "STANDING", "mode": "PARALLEL", "coverage": true, "tags": ["STANDING", "PARTY"], "tier": 1,
		"owners": ["PARTY"], "monthly_required": 8,
		"positions": [{"role": "Whip", "mandatory": true, "weights": {"POLI": 1.0}, "paths": [{"min": {"POLI": 50}}]}]},
}

## Implementation class per lever (pic-core §5 `implementation`). null in a lever def falls back to ADMIN.
const IMPL_CLASSES := ["STAFF_T_IMPL_FISCAL", "STAFF_T_IMPL_REGULATORY", "STAFF_T_IMPL_PROGRAM",
	"STAFF_T_IMPL_INSTITUTION", "STAFF_T_IMPL_ADMIN"]

## Founding starting slate (spec §10.4): created at new game; the validator must be able to staff it.
const FOUNDING_SLATE := [
	{"def": "STAFF_SD_FINANCE", "params": {}},
	{"def": "STAFF_SD_INFRA", "params": {}},
	{"def": "STAFF_SD_PERMITS", "params": {}},
	{"def": "STAFF_T_PROCURE", "params": {"construction": true}},
	{"def": "STAFF_T_SUPERVISE", "params": {"size": "MEDIUM"}},
	{"def": "STAFF_T_SUPERVISE", "params": {"size": "MEDIUM"}},
	{"def": "STAFF_T_DRAFT_ORDINANCE", "params": {"clauses": 2, "domain": "ECON"}},
]

# ---------------------------------------------------------------- quality outputs (spec §3)
const DEFECT_Q_PIVOT := 70.0
const DEFECT_DIVISOR := 150.0
const DEFECT_DISCOVERY := 0.5
const DEFECT_WORK_EXTRA := 0.25
const POLL_MOE_BASE := 2.0
const POLL_MOE_RANGE := 3.0
const OVERSIGHT_BASE := 0.3
const OVERSIGHT_RANGE := 0.5
const AUTO_ERROR_DIVISOR := 300.0
const DELIVERY_WINDOW := 24
const DELIVERY_ON_TIME := 6
const DELIVERY_DEFAULT := 70

extends RefCounted
## Thin-law v1 definitions (planning/spec-law-v1.md §2–§4, §7, §10). Data-as-code constants.

const LEVEL_RANK := {"CHARTER": 5, "CONSTITUTIONAL": 5, "LAW": 3, "ORDINANCE": 3, "REGULATION": 2, "ADMIN": 1}
const PUBLIC_KINDS := ["COMMANDER", "GOVERNMENT", "AUTHORITY", "PARLIAMENT"]

## LegalActionType (spec §3) + INTERNAL (A7) + SELL_ASSET (88 ask).
const ACTIONS := ["ZONE_DISTRICT", "BUILD_FACILITY", "DEMOLISH_FACILITY", "OPERATE_FACILITY", "EXTRACT_RESOURCE",
	"SELL_GOOD", "IMPORT_GOOD", "HIRE", "SET_WAGE", "DISMISS_WORKERS", "LEVY_TAX", "SPEND", "BORROW", "GRANT_SUBSIDY",
	"AWARD_CONTRACT", "TERMINATE_CONTRACT", "ISSUE_PERMIT", "DENY_PERMIT", "ISSUE_LICENCE", "REVOKE_LICENCE",
	"EXPROPRIATE", "SELL_ASSET", "SET_LEVER", "APPOINT_OFFICIAL", "DISMISS_OFFICIAL", "HOLD_ELECTION",
	"POSTPONE_ELECTION", "RESTRICT_ASSOCIATION", "RESTRICT_ASSEMBLY", "RESTRICT_EXPRESSION",
	"INSTRUCT_AUTHORITY_DECISION", "REGISTER_PARTY", "CAMPAIGN", "INTERNAL"]

## Executive actions the commander (founding) and later the government may take without a specific law.
const EXECUTIVE_ACTIONS := ["ZONE_DISTRICT", "BUILD_FACILITY", "DEMOLISH_FACILITY", "AWARD_CONTRACT",
	"TERMINATE_CONTRACT", "ISSUE_PERMIT", "DENY_PERMIT", "ISSUE_LICENCE", "REVOKE_LICENCE", "APPOINT_OFFICIAL",
	"DISMISS_OFFICIAL", "HOLD_ELECTION", "IMPORT_GOOD", "HIRE", "SET_WAGE", "LEVY_TAX", "SELL_GOOD"]
## Founding-only fiscal powers (after the transition these need appropriation by parliament).
const COMMANDER_FISCAL := ["SPEND", "GRANT_SUBSIDY", "SELL_ASSET"]

const PUBLIC_SUBJECT := [{"field": "actor.kind", "op": "IN", "value": ["COMMANDER", "GOVERNMENT", "AUTHORITY"]}]


static func _r(kind: String, action: String, subject: Array, where: Array = [], extra: Dictionary = {}) -> Dictionary:
	var r := {"level": "CHARTER", "kind": kind, "action": action, "subject": subject, "where": where, "unless": [],
		"requirement": {}, "delegation": {}, "supersedes": [], "defect": false, "provisional": false, "source": "CHARTER"}
	for k in extra:
		r[k] = extra[k]
	return r


## Charter rules (spec §7.1). Created at new game in world.table("legal_rule").
static func charter_rules() -> Array:
	var out: Array = []
	# Rights as prohibitions on public actors.
	for a in ["POSTPONE_ELECTION", "RESTRICT_ASSOCIATION", "RESTRICT_ASSEMBLY", "RESTRICT_EXPRESSION",
			"INSTRUCT_AUTHORITY_DECISION"]:
		out.append(_r("PROHIBIT", a, PUBLIC_SUBJECT, [], {"right": a}))
	# Property: expropriation needs full compensation (and a specific authorization; default-deny covers that).
	out.append(_r("REQUIRE", "EXPROPRIATE", PUBLIC_SUBJECT, [], {"requirement": {"compensation_pct_min": 100}, "right": "PROPERTY"}))
	# Commander powers in the founding era.
	var cmd := [{"field": "actor.kind", "op": "EQ", "value": "COMMANDER"}]
	var founding := [{"field": "world.era", "op": "EQ", "value": "FOUNDING"}]
	out.append(_r("AUTHORIZE", "SET_LEVER", cmd, founding + [
		{"field": "p.founding_era", "op": "EQ", "value": "COMMANDER"},
		{"field": "p.instrument_level", "op": "IN", "value": ["ORDINANCE", "LAW", "REGULATION", "ADMIN"]}]))
	for a in EXECUTIVE_ACTIONS + COMMANDER_FISCAL:
		out.append(_r("AUTHORIZE", a, cmd, founding))
	out.append(_r("AUTHORIZE", "BORROW", cmd, founding + [{"field": "p.within_credit_line", "op": "EQ", "value": true}]))
	# The permit office (an AUTHORITY) issues and refuses permits and licences.
	var auth := [{"field": "actor.kind", "op": "EQ", "value": "AUTHORITY"}]
	for a in ["ISSUE_PERMIT", "DENY_PERMIT", "ISSUE_LICENCE", "REVOKE_LICENCE"]:
		out.append(_r("AUTHORIZE", a, auth))
	# The automatic liquidity draw in SETTLEMENT is charter-pre-authorized (88, E-spec).
	out.append(_r("AUTHORIZE", "BORROW", [{"field": "actor.kind", "op": "IN", "value": ["GOVERNMENT", "COMMANDER"]}],
		[{"field": "p.automatic_liquidity", "op": "EQ", "value": true}]))
	return out


## Constitutional procedures for government crises (M7; Swedish-inspired, RF ch. 6 and 3:11). Data, read via LQ.
const PROCEDURES := {
	"parliament_seats": 151,
	"no_confidence": {
		"movers_fraction": 0.10,        # a motion needs at least one tenth of all members (ceil: 16 of 151)
		"topple_votes": 76,             # an absolute majority of ALL members must vote against the PM
		"not_against_caretaker": true,  # a caretaker government cannot be the target of a motion
	},
	"extra_election": {
		"called_by": "GOVERNMENT",
		"blocked_months_after_election": 3,   # not within 3 months after an election
		"caretaker_may_call": false,          # a dismissed (caretaker) government may not call one
		"resets_ordinary_calendar": false,    # the next ordinary election stays on the 4-year calendar
	},
	"pm_votes": {"max_failed": 4, "then": "MANDATORY_EXTRA_ELECTION"},
	"caretaker": {
		"allowed": ["ongoing tasks and standing duties", "coalition negotiations", "implementing laws already enacted",
			"administrative (ADMIN-level) decisions", "answering staff decisions", "court and permit routine"],
		"forbidden": ["new political tasks except negotiation", "regulations (REGULATION-level decrees)",
			"new bills or ordinances", "calling an extra election", "new subsidies or asset sales"],
	},
}


## Rules added by the constitution at the first government (spec §7.2).
static func constitutional_rules() -> Array:
	var out: Array = []
	var parl := [{"field": "actor.kind", "op": "EQ", "value": "PARLIAMENT"}]
	var gov := [{"field": "actor.kind", "op": "EQ", "value": "GOVERNMENT"}]
	out.append(_r("AUTHORIZE", "SET_LEVER", parl, [{"field": "p.instrument_level", "op": "EQ", "value": "LAW"}],
		{"level": "CONSTITUTIONAL", "source": "CONSTITUTION"}))
	out.append(_r("AUTHORIZE", "SET_LEVER", gov, [{"field": "p.instrument_level", "op": "IN", "value": ["REGULATION", "ADMIN"]}],
		{"level": "CONSTITUTIONAL", "source": "CONSTITUTION"}))
	# Legislative monopoly: a government decision may not change a LAW/CHARTER-level lever unless a law delegates it.
	out.append(_r("PROHIBIT", "SET_LEVER", gov, [
		{"field": "p.instrument_level", "op": "IN", "value": ["REGULATION", "ADMIN"]},
		{"field": "p.lever_level", "op": "IN", "value": ["LAW", "CHARTER"]}],
		{"level": "CONSTITUTIONAL", "source": "CONSTITUTION", "right": "LEGISLATIVE_MONOPOLY",
		"unless": [{"field": "p.delegated", "op": "EQ", "value": true}]}))
	for a in EXECUTIVE_ACTIONS:
		out.append(_r("AUTHORIZE", a, gov, [], {"level": "CONSTITUTIONAL", "source": "CONSTITUTION"}))
	# Caretaker limits (PROCEDURES.caretaker): a dismissed government may not regulate, call an extra election,
	# or make new subsidy/asset commitments. Higher specificity than the AUTHORIZE rules, so it wins.
	var caretaker := [{"field": "world.caretaker", "op": "EQ", "value": true}]
	out.append(_r("PROHIBIT", "SET_LEVER", gov, caretaker + [{"field": "p.instrument_level", "op": "EQ", "value": "REGULATION"}],
		{"level": "CONSTITUTIONAL", "source": "CONSTITUTION", "right": "CARETAKER_LIMITS"}))
	out.append(_r("PROHIBIT", "HOLD_ELECTION", gov, caretaker + [{"field": "p.extra", "op": "EQ", "value": true}],
		{"level": "CONSTITUTIONAL", "source": "CONSTITUTION", "right": "CARETAKER_LIMITS"}))
	for a in ["GRANT_SUBSIDY", "SELL_ASSET"]:
		out.append(_r("PROHIBIT", a, gov, caretaker, {"level": "CONSTITUTIONAL", "source": "CONSTITUTION", "right": "CARETAKER_LIMITS"}))
	# Spending, subsidies, asset sales and borrowing need parliament's appropriation.
	for a in ["SPEND", "GRANT_SUBSIDY", "SELL_ASSET", "BORROW"]:
		out.append(_r("AUTHORIZE", a, gov, [], {"level": "CONSTITUTIONAL", "source": "CONSTITUTION"}))
		out.append(_r("REQUIRE", a, gov, [{"field": "p.appropriated", "op": "NEQ", "value": true}],
			{"level": "CONSTITUTIONAL", "source": "CONSTITUTION", "requirement": {"approval_by": "PARLIAMENT"}}))
	return out


## Charter bounds on levers (spec §7.1): hard limits for every level below CHARTER.
## Tax levers carry `is_tax: true` in their def (econ); their max is 5000 bp.
const TAX_MAX_BP := 5000
const LEVER_BOUNDS := {
	"ECON_MIN_WAGE": {"min": 400},                 # fraction of W_ref in milli (0.40)
	"STAFF_CIVIL_RETIREMENT_AGE": {"min": 60, "max": 72},
	"LAW_SAFETY_STANDARD": {"min_enum": "BASIC"},
}

## Indicator concern weights and normalization (milli). Tuned against tools/measure_law_indicators.gd so
## the near-constant baselines do not flatten concern satisfaction (see planning/pic-staff-law.md §1).
const INDICATOR_TUNING := {
	# exceptionOnly (pic-core v1.1): counts only while below 100 (clean), so full weight without baseline dilution.
	"LAW_RULE_OF_LAW": {"range": [0, 100000], "concerns": {"GOVERNANCE": 1.0, "FAIRNESS": 0.5},
		"normalize": {"good": 100000, "bad": 40000}, "exceptionOnly": true},
	# Near-constant until M6 courts add timeliness/consistency variation: raise to 0.4 at M6.
	"LAW_TRUST_IN_JUSTICE": {"range": [0, 100000], "concerns": {"FAIRNESS": 0.15},
		"normalize": {"good": 90000, "bad": 30000}},
	"LAW_PERMIT_WAIT": {"range": [0, 24000], "concerns": {"GOVERNANCE": 0.1},
		"normalize": {"good": 500, "bad": 6000}},
	"LAW_WORKPLACE_SAFETY": {"range": [0, 50000], "concerns": {"SAFETY": 0.6},
		"normalize": {"good": 1000, "bad": 10000}},
	# M6. Published only when there is data (revealed violations / decided cases).
	"LAW_ENFORCEMENT_CONSISTENCY": {"range": [0, 100000], "concerns": {"FAIRNESS": 0.2},
		"normalize": {"good": 85000, "bad": 30000}},
	"LAW_COURT_DURATION": {"range": [0, 36000], "concerns": {"GOVERNANCE": 0.3, "FAIRNESS": 0.3},
		"normalize": {"good": 3000, "bad": 18000}, "exceptionOnly": true},
}

## Law-owned levers (pic-staff-law §3; M6 court/inspectorate levers come later).
## NUMBER units: percentages in basis points, money in milli-W_ref.
const LEVERS := [
	{"id": "LAW_SAFETY_STANDARD", "owner": "law", "type": "ENUM", "values": ["BASIC", "STANDARD", "STRICT"],
		"default": "BASIC", "legalLevel": "LAW", "foundingEra": "COMMANDER", "ideology": {"LABOR": 15, "ECON_ROLE": 5},
		"fiscal": "", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 2, "scope": "COLONY", "domain": "LAW"},
	{"id": "LAW_LICENCE_REGIME_EXTRACTION", "owner": "law", "type": "ENUM", "values": ["NONE", "REQUIRED"],
		"default": "REQUIRED", "legalLevel": "LAW", "foundingEra": "COMMANDER", "ideology": {"ENVIRONMENT": 10, "ECON_ROLE": 5},
		"fiscal": "est_fee_revenue", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 1, "scope": "COLONY", "domain": "LAW"},
	{"id": "LAW_LICENCE_REGIME_HAZARD", "owner": "law", "type": "ENUM", "values": ["NONE", "REQUIRED"],
		"default": "REQUIRED", "legalLevel": "LAW", "foundingEra": "COMMANDER", "ideology": {"LABOR": 10, "ECON_ROLE": 5},
		"fiscal": "est_fee_revenue", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 1, "scope": "COLONY", "domain": "LAW"},
	{"id": "LAW_PERMIT_STRICTNESS", "owner": "law", "type": "ENUM", "values": ["LENIENT", "STANDARD", "STRICT"],
		"default": "STANDARD", "legalLevel": "REGULATION", "foundingEra": "COMMANDER", "ideology": {"ENVIRONMENT": 10, "ECON_ROLE": 5},
		"fiscal": "", "implementation": "STAFF_T_IMPL_ADMIN", "lag": 0, "scope": "COLONY", "domain": "ADMIN"},
	{"id": "LAW_EXTRACTION_ROYALTY", "owner": "law", "type": "NUMBER", "range": [0, 3000], "default": 800,
		"legalLevel": "LAW", "foundingEra": "COMMANDER", "ideology": {"REDISTRIBUTION": 0.01, "ECON_ROLE": 0.02},
		"fiscal": "est_royalty", "implementation": "STAFF_T_IMPL_FISCAL", "lag": 1, "scope": "COLONY", "domain": "ECON"},
	{"id": "LAW_FEE_BUILDING_PERMIT", "owner": "law", "type": "NUMBER", "range": [0, 500], "default": 50,
		"legalLevel": "REGULATION", "foundingEra": "COMMANDER", "ideology": {"ECON_ROLE": 0.02},
		"fiscal": "est_fee_revenue", "implementation": "STAFF_T_IMPL_FISCAL", "lag": 1, "scope": "COLONY", "domain": "ECON"},
	{"id": "LAW_FEE_EXTRACTION", "owner": "law", "type": "NUMBER", "range": [0, 50000], "default": 5000,
		"legalLevel": "REGULATION", "foundingEra": "COMMANDER", "ideology": {"ECON_ROLE": 0.0001},
		"fiscal": "est_fee_revenue", "implementation": "STAFF_T_IMPL_FISCAL", "lag": 1, "scope": "COLONY", "domain": "ECON"},
	{"id": "LAW_FEE_HAZARD", "owner": "law", "type": "NUMBER", "range": [0, 50000], "default": 3000,
		"legalLevel": "REGULATION", "foundingEra": "COMMANDER", "ideology": {"ECON_ROLE": 0.0001},
		"fiscal": "est_fee_revenue", "implementation": "STAFF_T_IMPL_FISCAL", "lag": 1, "scope": "COLONY", "domain": "ECON"},
	{"id": "LAW_DIRECT_AWARD_THRESHOLD", "owner": "law", "type": "NUMBER", "range": [0, 500000], "default": 50000,
		"legalLevel": "REGULATION", "foundingEra": "COMMANDER", "ideology": {"INSTITUTIONS": -0.0002},
		"fiscal": "", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 0, "scope": "COLONY", "domain": "LAW"},
	{"id": "LAW_PERMIT_OFFICE_BUDGET", "owner": "law", "type": "NUMBER", "range": [0, 50000], "default": 6000,
		"legalLevel": "LAW", "foundingEra": "COMMANDER", "ideology": {},
		"fiscal": "est_budget_line", "implementation": "STAFF_T_IMPL_FISCAL", "lag": 1, "scope": "COLONY", "domain": "ECON"},
	# ---- M6 justice levers (pic-staff-law §3). Money in milli-W_ref; LAW_FINE_SCALE in milli (1000 = x1.0).
	{"id": "LAW_COURT_BUDGET", "owner": "law", "type": "NUMBER", "range": [0, 200000], "default": 15000,
		"legalLevel": "LAW", "foundingEra": "LOCKED", "ideology": {"INSTITUTIONS": 0.0002},
		"fiscal": "est_budget_line", "implementation": "STAFF_T_IMPL_FISCAL", "lag": 1, "scope": "COLONY", "domain": "ECON"},
	{"id": "LAW_JUDGES", "owner": "law", "type": "NUMBER", "range": [1, 30], "default": 5,
		"legalLevel": "LAW", "foundingEra": "LOCKED", "ideology": {"INSTITUTIONS": 1},
		"fiscal": "est_judge_cost", "implementation": "STAFF_T_IMPL_INSTITUTION", "lag": 6, "scope": "COLONY", "domain": "LAW"},
	{"id": "LAW_INSPECTORATE_BUDGET", "owner": "law", "type": "NUMBER", "range": [0, 200000], "default": 8000,
		"legalLevel": "LAW", "foundingEra": "LOCKED", "ideology": {"ECON_ROLE": 0.0003, "LABOR": 0.0002},
		"fiscal": "est_budget_line", "implementation": "STAFF_T_IMPL_FISCAL", "lag": 1, "scope": "COLONY", "domain": "ECON"},
	{"id": "LAW_FINE_SCALE", "owner": "law", "type": "NUMBER", "range": [250, 4000], "default": 1000,
		"legalLevel": "LAW", "foundingEra": "LOCKED", "ideology": {"ECON_ROLE": 0.005, "LABOR": 0.003},
		"fiscal": "est_fine_revenue", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 1, "scope": "COLONY", "domain": "LAW"},
	{"id": "LAW_INSPECTORS", "owner": "law", "type": "NUMBER", "range": [0, 60], "default": 4,
		"legalLevel": "REGULATION", "foundingEra": "LOCKED", "ideology": {"ECON_ROLE": 0.4, "LABOR": 0.4},
		"fiscal": "est_inspector_cost", "implementation": "STAFF_T_IMPL_INSTITUTION", "lag": 3, "scope": "COLONY", "domain": "LAW"},
	# ---- M9 party finance (spec-politics-v2 §6). LAW_DONATION_CAP: milli-W_ref per donor per rolling 12 months; the
	# range maximum (and 0, never reachable by law) means no cap, so higher is always more permissive (monotone slope).
	{"id": "LAW_DONATION_CAP", "owner": "law", "type": "NUMBER", "range": [5000, 500000], "default": 50000,
		"legalLevel": "LAW", "foundingEra": "LOCKED", "ideology": {"REDISTRIBUTION": -0.0002, "ECON_ROLE": -0.0001, "INSTITUTIONS": -0.0001},
		"fiscal": "", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 1, "scope": "COLONY", "domain": "LAW"},
	{"id": "LAW_DONATION_DISCLOSURE", "owner": "law", "type": "ENUM", "values": ["NONE", "ABOVE_THRESHOLD", "ALL"],
		"default": "ABOVE_THRESHOLD", "legalLevel": "LAW", "foundingEra": "LOCKED", "ideology": {"INSTITUTIONS": 12, "REDISTRIBUTION": 4},
		"fiscal": "", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 1, "scope": "COLONY", "domain": "LAW"},
	{"id": "LAW_PUBLIC_PARTY_FUNDING", "owner": "law", "type": "NUMBER", "range": [0, 1000], "default": 0,
		"legalLevel": "LAW", "foundingEra": "LOCKED", "ideology": {"INSTITUTIONS": 0.06, "FISCAL": 0.05, "REDISTRIBUTION": 0.03},
		"fiscal": "est_budget_line", "implementation": "STAFF_T_IMPL_FISCAL", "lag": 1, "scope": "COLONY", "domain": "ECON"},
	{"id": "LAW_CONVICTED_CAN_HOLD_OFFICE", "owner": "law", "type": "BOOL", "default": true,
		"legalLevel": "LAW", "foundingEra": "LOCKED", "ideology": {"INSTITUTIONS": -12},
		"fiscal": "", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 0, "scope": "COLONY", "domain": "LAW"},
	# ---- M10 electoral eligibility (spec-population-v1 §4.2, PD §9.6). Read through LQ.eligibility(world).
	# Slopes use today's 7 axes; remap to STABILITY/LIBERTY when S3 adds them (planning/a9-population-note.md).
	{"id": "LAW_VOTING_AGE", "owner": "law", "type": "ENUM", "values": ["16", "18", "21"], "default": "18",
		"legalLevel": "LAW", "foundingEra": "LOCKED", "ideology": {"INSTITUTIONS": -8, "REDISTRIBUTION": -4},
		"fiscal": "", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 1, "scope": "COLONY", "domain": "LAW"},
	{"id": "LAW_RESIDENCY_FOR_VOTE", "owner": "law", "type": "NUMBER", "range": [0, 24], "default": 0,
		"legalLevel": "LAW", "foundingEra": "LOCKED", "ideology": {"INSTITUTIONS": -3, "REDISTRIBUTION": -2},
		"fiscal": "", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 1, "scope": "COLONY", "domain": "LAW"},
	{"id": "LAW_NONCITIZEN_VOTE", "owner": "law", "type": "BOOL", "default": true,
		"legalLevel": "LAW", "foundingEra": "LOCKED", "ideology": {"INSTITUTIONS": 8, "REDISTRIBUTION": 6},
		"fiscal": "", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 1, "scope": "COLONY", "domain": "LAW"},
]

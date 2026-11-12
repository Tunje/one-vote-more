extends RefCounted
## Thin-law v1 definitions (planning/spec-law-v1.md §2–§4, §7, §10). Data-as-code constants.

const LEVEL_RANK := {"CHARTER": 5, "CONSTITUTIONAL": 5, "LAW": 3, "ORDINANCE": 3, "REGULATION": 2, "ADMIN": 1}
const PUBLIC_KINDS := ["COMMANDER", "GOVERNMENT", "AUTHORITY", "PARLIAMENT", "HOME_WORLD"]

## LegalActionType (spec §3) + INTERNAL (A7) + SELL_ASSET (88 ask).
const ACTIONS := ["ZONE_DISTRICT", "BUILD_FACILITY", "DEMOLISH_FACILITY", "OPERATE_FACILITY", "EXTRACT_RESOURCE",
	"SELL_GOOD", "IMPORT_GOOD", "HIRE", "SET_WAGE", "DISMISS_WORKERS", "LEVY_TAX", "SPEND", "BORROW", "GRANT_SUBSIDY",
	"AWARD_CONTRACT", "TERMINATE_CONTRACT", "ISSUE_PERMIT", "DENY_PERMIT", "ISSUE_LICENCE", "REVOKE_LICENCE",
	"EXPROPRIATE", "SELL_ASSET", "SET_LEVER", "APPOINT_OFFICIAL", "DISMISS_OFFICIAL", "HOLD_ELECTION",
	"POSTPONE_ELECTION", "RESTRICT_ASSOCIATION", "RESTRICT_ASSEMBLY", "RESTRICT_EXPRESSION",
	"INSTRUCT_AUTHORITY_DECISION", "REGISTER_PARTY", "CAMPAIGN", "INTERNAL",
	# M11 (spec-events-v1): company greed conduct, emergency powers
	"DEFER_SAFETY_UPKEEP", "SAFETY_CORNERS", "DISCHARGE_WASTE", "HOARD", "PRICE_GOUGE", "EXPORT_GOODS", "CARTEL",
	"CUT_CONTRACT_CORNERS", "DECLARE_EMERGENCY", "REQUISITION",
	# M12 (spec-colony-v1): colonial charter, home-world sanctions, breaking away
	"SELL_COLONIAL_GOOD", "WITHHOLD_QUOTA", "OBSTRUCT_QUOTA", "REFUSE_QUOTA", "PETITION_HOME", "DECLARE_INDEPENDENCE",
	"REFUSE_EXPORT_TERMS",
	"HOME_FINE", "HOME_WITHHOLD", "HOME_REVOKE_PRIVILEGE", "HOME_APPOINT_GOVERNOR", "HOME_EXPEDITION",
	# M13 land law (spec-areas-v1 9.4, A37)
	"SELL_LAND", "LEASE_LAND", "ZONE_LAND", "CLEAR_HOUSING", "EVICT", "BUILD_WITHOUT_TITLE",
	# MEDIA v1 (spec-media-v1 8.3): suppressing a report (a restriction of expression)
	"CENSOR_REPORT"]

## M11 greed conduct (88 reports it with LawOps.record_greed). action = the rules-engine action that decides legality;
## channel = who can detect it (SAFETY inspectorate, ENV inspectorate, MARKET competition/consumer authority);
## class = penalty class (escalates to SEVERE after 6 active months for SAFETY/ENV kinds, or saving >= 20 W_ref).
const GREED_KINDS := {
	"DEFERRED_UPKEEP": {"action": "DEFER_SAFETY_UPKEEP", "channel": "SAFETY", "class": "SERIOUS"},
	"SAFETY_CORNERS": {"action": "SAFETY_CORNERS", "channel": "SAFETY", "class": "SERIOUS"},
	"CONTRACT_CORNERS": {"action": "CUT_CONTRACT_CORNERS", "channel": "SAFETY", "class": "SERIOUS"},
	"DUMPING": {"action": "DISCHARGE_WASTE", "channel": "ENV", "class": "SERIOUS"},
	"HOARDING": {"action": "HOARD", "channel": "MARKET", "class": "MINOR"},
	"GOUGING": {"action": "PRICE_GOUGE", "channel": "MARKET", "class": "MINOR"},
	"EXPORT_IN_SHORTAGE": {"action": "EXPORT_GOODS", "channel": "MARKET", "class": "SERIOUS"},
	"CARTEL": {"action": "CARTEL", "channel": "MARKET", "class": "SERIOUS"},
	# M12: charter evasion, detected by the home-world inspector at ship arrival (channel HOME)
	"QUOTA_EVASION": {"action": "WITHHOLD_QUOTA", "channel": "HOME", "class": "SERIOUS"},
	"SMUGGLING": {"action": "SELL_COLONIAL_GOOD", "channel": "HOME", "class": "SERIOUS"},
	# M13 land: building on land without a title; evicting or clearing without rehousing or a court order
	"SQUATTING_BUILD": {"action": "BUILD_WITHOUT_TITLE", "channel": "SAFETY", "class": "MINOR"},
	"ILLEGAL_EVICTION": {"action": "EVICT", "channel": "HOUSING", "class": "SERIOUS"},
}
## Emergency levers: settable only while a state of emergency is in force; revert to default when it ends.
const EMERGENCY_LEVERS := ["LAW_RATIONING", "LAW_PRICE_CONTROL", "LAW_FOOD_EXPORT_BAN", "LAW_REQUISITION",
	"LAW_EMERGENCY_PRESS_CONTROL"]

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


## M11 rules (spec-events-v1 3-4). Added once by LawOps.ensure_m11_rules (new games and older saves alike).
static func m11_rules() -> Array:
	var out: Array = []
	var co := [{"field": "actor.kind", "op": "EQ", "value": "COMPANY"}]
	var law := {"level": "LAW", "source": "M11_CRISIS"}
	# Duty of care, environment and contract law: always unlawful.
	for a in ["DEFER_SAFETY_UPKEEP", "SAFETY_CORNERS", "DISCHARGE_WASTE", "CUT_CONTRACT_CORNERS"]:
		out.append(_r("PROHIBIT", a, co, [], law))
	# Market conduct: unlawful only where the law says so.
	for a in ["PRICE_GOUGE", "HOARD"]:
		out.append(_r("PROHIBIT", a, co, [{"field": "lever.LAW_PRICE_GOUGING", "op": "EQ", "value": "ALWAYS"}], law))
		out.append(_r("PROHIBIT", a, co, [{"field": "lever.LAW_PRICE_GOUGING", "op": "EQ", "value": "IN_EMERGENCY"},
			{"field": "world.emergency", "op": "EQ", "value": true}], law))
	out.append(_r("PROHIBIT", "EXPORT_GOODS", co, [{"field": "lever.LAW_FOOD_EXPORT_BAN", "op": "EQ", "value": true},
		{"field": "p.food", "op": "EQ", "value": true}], law))
	out.append(_r("PROHIBIT", "CARTEL", co, [{"field": "lever.LAW_COMPETITION", "op": "NEQ", "value": "NONE"}], law))
	# Emergency powers (constitutional limits). Declaring needs an active crisis; parliament must approve it.
	var exec := [{"field": "actor.kind", "op": "IN", "value": ["GOVERNMENT", "COMMANDER"]}]
	out.append(_r("AUTHORIZE", "DECLARE_EMERGENCY", exec, [{"field": "p.crisis_active", "op": "EQ", "value": true}],
		{"source": "M11_CRISIS"}))
	out.append(_r("REQUIRE", "DECLARE_EMERGENCY", [{"field": "actor.kind", "op": "EQ", "value": "GOVERNMENT"}], [],
		{"source": "M11_CRISIS", "requirement": {"approval_by": "PARLIAMENT"}}))
	out.append(_r("AUTHORIZE", "REQUISITION", exec, [{"field": "world.emergency", "op": "EQ", "value": true}],
		{"source": "M11_CRISIS"}))
	out.append(_r("REQUIRE", "REQUISITION", exec, [], {"source": "M11_CRISIS", "requirement": {"compensation_pct_min": 100},
		"right": "PROPERTY"}))
	# Emergency levers: no one may set them outside an emergency (more specific than every SET_LEVER authorization).
	var pub := ["COMMANDER", "GOVERNMENT", "PARLIAMENT", "AUTHORITY"]
	out.append(_r("PROHIBIT", "SET_LEVER", [{"field": "actor.kind", "op": "IN", "value": pub}], [
		{"field": "p.lever_id", "op": "IN", "value": EMERGENCY_LEVERS},
		{"field": "world.emergency", "op": "EQ", "value": false},
		{"field": "p.instrument_level", "op": "IN", "value": ["ORDINANCE", "LAW", "REGULATION", "ADMIN"]},
		{"field": "actor.kind", "op": "IN", "value": pub}],
		{"source": "M11_CRISIS", "right": "EMERGENCY_ONLY"}))
	# During an emergency even a caretaker may use the emergency levers by regulation (beats the caretaker limit).
	out.append(_r("AUTHORIZE", "SET_LEVER", [{"field": "actor.kind", "op": "EQ", "value": "GOVERNMENT"}], [
		{"field": "p.lever_id", "op": "IN", "value": EMERGENCY_LEVERS},
		{"field": "world.emergency", "op": "EQ", "value": true},
		{"field": "p.instrument_level", "op": "IN", "value": ["REGULATION", "ADMIN"]},
		{"field": "world.caretaker", "op": "EQ", "value": true}], {"source": "M11_CRISIS"}))
	return out


## M12 colonial charter (spec-colony-v1 5-7). Entrenched: CHARTER level, source COLONIAL_CHARTER; suspended by a
## declaration of independence, repealed on recognition, reactivated by autonomy or a restored charter (CharterOps).
static func m12_rules() -> Array:
	var out: Array = []
	var cc := {"source": "COLONIAL_CHARTER", "colonial": true}
	var anyone := [{"field": "actor.kind", "op": "IN", "value": ["COMPANY", "HOUSEHOLD", "GOVERNMENT", "COMMANDER", "AUTHORITY"]}]
	var pub := [{"field": "actor.kind", "op": "IN", "value": ["GOVERNMENT", "COMMANDER", "PARLIAMENT", "AUTHORITY"]}]
	# Exclusive trade and the quota.
	out.append(_r("PROHIBIT", "SELL_COLONIAL_GOOD", anyone, [{"field": "p.buyer", "op": "NEQ", "value": "HOME_WORLD"}], cc))
	out.append(_r("PROHIBIT", "WITHHOLD_QUOTA", anyone, [], cc))
	out.append(_r("PROHIBIT", "OBSTRUCT_QUOTA", pub, [], cc))
	out.append(_r("PROHIBIT", "REFUSE_QUOTA", pub, [], cc))
	out.append(_r("PROHIBIT", "LEVY_TAX", pub, [{"field": "p.base", "op": "IN", "value": ["QUOTA", "COLONIAL_EXPORT"]}], cc))
	# The home world's lawful sanctions under the charter (anything else it does is unlawful: default-deny). From the
	# home world's side the charter still applies after a declaration, so these are not suspended with the obligations.
	var home := [{"field": "actor.kind", "op": "EQ", "value": "HOME_WORLD"}]
	cc = {"source": "COLONIAL_CHARTER"}
	out.append(_r("AUTHORIZE", "HOME_WITHHOLD", home, [], cc))
	out.append(_r("AUTHORIZE", "HOME_REVOKE_PRIVILEGE", home, [], cc))
	out.append(_r("AUTHORIZE", "HOME_FINE", home, [{"field": "p.evasion_proven", "op": "EQ", "value": true}], cc))
	out.append(_r("AUTHORIZE", "HOME_APPOINT_GOVERNOR", home, [{"field": "p.evasion_proven", "op": "EQ", "value": true}], cc))
	out.append(_r("AUTHORIZE", "HOME_APPOINT_GOVERNOR", home, [{"field": "p.refusal", "op": "EQ", "value": true}], cc))
	out.append(_r("AUTHORIZE", "HOME_EXPEDITION", home, [{"field": "p.colony_defiant", "op": "EQ", "value": true}], cc))
	# Rights of the colony: petition is always lawful.
	out.append(_r("AUTHORIZE", "PETITION_HOME", [{"field": "actor.kind", "op": "IN", "value": ["PARLIAMENT", "GOVERNMENT", "COMMANDER"]}],
		[], {"source": "COLONIAL_CHARTER"}))
	return out


## D5 (spec-demand-v1): the home world's export terms. Refusing the export levy and the reserved goods is defiance,
## like refusing the quota. (Reserved goods are colonial goods: SELL_COLONIAL_GOOD to anyone but the home world's
## charter buyer, and colony export tax on them (LEVY_TAX base COLONIAL_EXPORT), are already prohibited above.)
static func d5_rules() -> Array:
	var pub := [{"field": "actor.kind", "op": "IN", "value": ["GOVERNMENT", "COMMANDER", "PARLIAMENT", "AUTHORITY"]}]
	return [_r("PROHIBIT", "REFUSE_EXPORT_TERMS", pub, [], {"source": "COLONIAL_CHARTER", "colonial": true})]


## M13 land law (spec-areas-v1 9.4). Added once by LandLaw.ensure_rules.
static func land_rules() -> Array:
	var out: Array = []
	var src := {"source": "LAND_LAW"}
	var exec := [{"field": "actor.kind", "op": "IN", "value": ["GOVERNMENT", "COMMANDER"]}]
	var gov := [{"field": "actor.kind", "op": "EQ", "value": "GOVERNMENT"}]
	var priv := [{"field": "actor.kind", "op": "IN", "value": ["COMPANY", "HOUSEHOLD"]}]
	var caretaker := [{"field": "world.caretaker", "op": "EQ", "value": true}]
	out.append(_r("AUTHORIZE", "SELL_LAND", exec, [{"field": "lever.LAW_LAND_DISPOSAL", "op": "EQ", "value": "SELL"},
		{"field": "p.price_ok", "op": "EQ", "value": true}], src))
	out.append(_r("AUTHORIZE", "LEASE_LAND", exec, [{"field": "lever.LAW_LAND_DISPOSAL", "op": "IN", "value": ["LEASE", "SELL"]}], src))
	out.append(_r("AUTHORIZE", "ZONE_LAND", exec, [], src))
	out.append(_r("AUTHORIZE", "EXPROPRIATE", exec, [{"field": "p.public_purpose", "op": "EQ", "value": true}], src))
	for a in ["SELL_LAND", "ZONE_LAND", "EXPROPRIATE"]:
		out.append(_r("PROHIBIT", a, gov, caretaker + [{"field": "actor.kind", "op": "EQ", "value": "GOVERNMENT"}],
			{"source": "LAND_LAW", "right": "CARETAKER_LIMITS"}))
	# Clearance and eviction: never without lawful rehousing or a court order (people are never deleted).
	out.append(_r("AUTHORIZE", "CLEAR_HOUSING", exec, [{"field": "p.rehoused", "op": "EQ", "value": true}], src))
	out.append(_r("AUTHORIZE", "CLEAR_HOUSING", exec, [{"field": "p.eviction_order", "op": "EQ", "value": true}], src))
	for a in ["CLEAR_HOUSING", "EVICT"]:
		out.append(_r("PROHIBIT", a, priv, [], {"source": "LAND_LAW", "right": "HOUSING",
			"unless": [{"field": "p.rehoused", "op": "EQ", "value": true}, {"field": "p.eviction_order", "op": "EQ", "value": true}]}))
	out.append(_r("PROHIBIT", "BUILD_WITHOUT_TITLE", priv, [], src))
	for a in ["ZONE_LAND", "SELL_LAND", "LEASE_LAND", "EXPROPRIATE"]:   # state powers: private actors never hold them
		out.append(_r("PROHIBIT", a, priv, [], src))
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
## Tax levers carry `is_tax: true` in their def (econ). Bounds are in each lever's OWN unit: econ tax and
## minimum-wage levers are whole percent (tests/law/test_law_bounds.gd checks every bound against the lever range).
const TAX_MAX_PCT := 50
const LEVER_BOUNDS := {
	"ECON_MIN_WAGE": {"min": 40},                  # % of W_ref, same unit as the lever (was 400: unit bug, every change rejected)
	"STAFF_CIVIL_RETIREMENT_AGE": {"min": 60, "max": 72},
	"LAW_SAFETY_STANDARD": {"min_enum": "BASIC"},
	# Colonial charter: a small militia only. "colonial": lifted once the colony declares or wins independence.
	"LAW_MILITIA": {"max": 5, "colonial": true},
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
	# ---- M11 crises (spec-events-v1 3-4): market conduct law, enforcement budgets (milli-W_ref per month).
	{"id": "LAW_PRICE_GOUGING", "owner": "law", "type": "ENUM", "values": ["NONE", "IN_EMERGENCY", "ALWAYS"],
		"default": "IN_EMERGENCY", "legalLevel": "LAW", "foundingEra": "COMMANDER", "ideology": {"ECON_ROLE": 10, "REDISTRIBUTION": 6},
		"fiscal": "", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 1, "scope": "COLONY", "domain": "LAW"},
	{"id": "LAW_COMPETITION", "owner": "law", "type": "ENUM", "values": ["NONE", "CARTEL_BAN", "CARTEL_BAN_MERGER_REVIEW"],
		"default": "CARTEL_BAN", "legalLevel": "LAW", "foundingEra": "COMMANDER", "ideology": {"REDISTRIBUTION": 5, "ECON_ROLE": 3},
		"fiscal": "", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 1, "scope": "COLONY", "domain": "LAW"},
	{"id": "LAW_COMPETITION_BUDGET", "owner": "law", "type": "NUMBER", "range": [0, 50000], "default": 4000,
		"legalLevel": "LAW", "foundingEra": "COMMANDER", "ideology": {"ECON_ROLE": 0.0003, "INSTITUTIONS": 0.0002},
		"fiscal": "est_budget_line", "implementation": "STAFF_T_IMPL_FISCAL", "lag": 1, "scope": "COLONY", "domain": "ECON"},
	{"id": "LAW_ENV_INSPECTORATE_BUDGET", "owner": "law", "type": "NUMBER", "range": [0, 100000], "default": 4000,
		"legalLevel": "LAW", "foundingEra": "COMMANDER", "ideology": {"ENVIRONMENT": 0.0005, "ECON_ROLE": 0.0002},
		"fiscal": "est_budget_line", "implementation": "STAFF_T_IMPL_FISCAL", "lag": 1, "scope": "COLONY", "domain": "ECON"},
	{"id": "LAW_WHISTLEBLOWER_PROTECTION", "owner": "law", "type": "BOOL", "default": false,
		"legalLevel": "LAW", "foundingEra": "COMMANDER", "ideology": {"INSTITUTIONS": 8, "LABOR": 6},
		"fiscal": "", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 1, "scope": "COLONY", "domain": "LAW"},
	{"id": "LAW_LENIENCY", "owner": "law", "type": "BOOL", "default": false,
		"legalLevel": "LAW", "foundingEra": "COMMANDER", "ideology": {"INSTITUTIONS": 4, "ECON_ROLE": 2},
		"fiscal": "", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 1, "scope": "COLONY", "domain": "LAW"},
	# Emergency levers: REGULATION, immediate (ADMIN implementation, lag 0), only during a state of emergency
	# (EMERGENCY_LEVERS rule); no ideology slope, so they never become standing party commitments.
	{"id": "LAW_RATIONING", "owner": "law", "type": "ENUM", "values": ["NONE", "FOOD", "FOOD_FUEL"], "default": "NONE",
		"legalLevel": "REGULATION", "foundingEra": "COMMANDER", "ideology": {}, "emergency": true,
		"fiscal": "", "implementation": "STAFF_T_IMPL_ADMIN", "lag": 0, "scope": "COLONY", "domain": "ADMIN"},
	{"id": "LAW_PRICE_CONTROL", "owner": "law", "type": "ENUM", "values": ["NONE", "ESSENTIALS"], "default": "NONE",
		"legalLevel": "REGULATION", "foundingEra": "COMMANDER", "ideology": {}, "emergency": true,
		"fiscal": "", "implementation": "STAFF_T_IMPL_ADMIN", "lag": 0, "scope": "COLONY", "domain": "ADMIN"},
	{"id": "LAW_FOOD_EXPORT_BAN", "owner": "law", "type": "BOOL", "default": false,
		"legalLevel": "REGULATION", "foundingEra": "COMMANDER", "ideology": {}, "emergency": true,
		"fiscal": "", "implementation": "STAFF_T_IMPL_ADMIN", "lag": 0, "scope": "COLONY", "domain": "ADMIN"},
	{"id": "LAW_REQUISITION", "owner": "law", "type": "BOOL", "default": false,
		"legalLevel": "REGULATION", "foundingEra": "COMMANDER", "ideology": {}, "emergency": true,
		"fiscal": "", "implementation": "STAFF_T_IMPL_ADMIN", "lag": 0, "scope": "COLONY", "domain": "ADMIN"},
	# ---- M12 colonial charter (CHARTER level: only the home world changes them, via CharterOps.home_world_amend)
	{"id": "LAW_CHARTER_QUOTA_SHARE", "owner": "law", "type": "NUMBER", "range": [0, 100], "default": 40,
		"legalLevel": "CHARTER", "foundingEra": "LOCKED", "ideology": {},
		"fiscal": "", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 0, "scope": "COLONY", "domain": "ECON"},
	{"id": "LAW_CHARTER_PRICE_PCT", "owner": "law", "type": "NUMBER", "range": [0, 100], "default": 35,
		"legalLevel": "CHARTER", "foundingEra": "LOCKED", "ideology": {},
		"fiscal": "", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 0, "scope": "COLONY", "domain": "ECON"},
	# D5 (spec-demand-v1): the home world's levy on general exports (% of export revenue), set by the home world only.
	{"id": "LAW_CHARTER_EXPORT_LEVY", "owner": "law", "type": "NUMBER", "range": [0, 50], "default": 0,
		"legalLevel": "CHARTER", "foundingEra": "LOCKED", "ideology": {},
		"fiscal": "", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 0, "scope": "COLONY", "domain": "ECON"},
	# ---- D5 trade, luxury, tourism and leisure law (planning/spec-demand-v1.md D5). Read through sim/law/trade_law.gd.
	# NUMBER so AI governments draft them. Taxes carry is_tax (charter cap 50%) and a GOVERNANCE (+revenue) hint.
	{"id": "LAW_EXPORT_TAX", "owner": "law", "legislative": true, "is_tax": true, "type": "NUMBER", "range": [0, 50], "default": 0,
		"legalLevel": "LAW", "foundingEra": "COMMANDER", "ideology": {"ECON_ROLE": 0.6, "SOVEREIGNTY": 0.2},
		"concerns": {"JOBS": -30, "GOVERNANCE": 25},
		"fiscal": "", "implementation": "STAFF_T_IMPL_FISCAL", "lag": 1, "scope": "COLONY", "domain": "ECON"},
	{"id": "LAW_LUXURY_TAX", "owner": "law", "legislative": true, "is_tax": true, "type": "NUMBER", "range": [0, 50], "default": 0,
		"legalLevel": "LAW", "foundingEra": "COMMANDER", "ideology": {"REDISTRIBUTION": 1.2, "ECON_ROLE": 0.3},
		"concerns": {"FAIRNESS": 20, "JOBS": -10, "GOVERNANCE": 20},
		"fiscal": "", "implementation": "STAFF_T_IMPL_FISCAL", "lag": 1, "scope": "COLONY", "domain": "ECON"},
	{"id": "LAW_TOURIST_TAX", "owner": "law", "legislative": true, "is_tax": true, "type": "NUMBER", "range": [0, 30], "default": 0,
		"legalLevel": "LAW", "foundingEra": "COMMANDER", "ideology": {"ECON_ROLE": 0.4, "ENVIRONMENT": 0.3},
		"concerns": {"JOBS": -10, "GOVERNANCE": 15},
		"fiscal": "", "implementation": "STAFF_T_IMPL_FISCAL", "lag": 1, "scope": "COLONY", "domain": "ECON"},
	# Tourist visas: 0 = closed to visitors, 100 = open. Visitors bring jobs and money, and crowd housing and nature.
	{"id": "LAW_TOURIST_VISA", "owner": "law", "legislative": true, "type": "NUMBER", "range": [0, 100], "default": 50,
		"legalLevel": "LAW", "foundingEra": "COMMANDER", "ideology": {"ECON_ROLE": -0.05, "ENVIRONMENT": -0.06, "SOVEREIGNTY": -0.04},
		"concerns": {"JOBS": 20, "HOUSING": -8, "COST_OF_LIVING": -6, "ENVIRONMENT_QUALITY": -6},
		"fiscal": "", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 1, "scope": "COLONY", "domain": "ECON"},
	# Immigration (E120): 0 = closed to settlers, 100 = open. Bob multiplies would-be arrivals by it (with
	# attractiveness and ship space). Opening: more hands and growth; crowded jobs and housing.
	{"id": "LAW_IMMIGRATION", "owner": "law", "legislative": true, "type": "NUMBER", "range": [0, 100], "default": 70,
		"legalLevel": "LAW", "foundingEra": "COMMANDER",
		"ideology": {"SOVEREIGNTY": -0.08, "INSTITUTIONS": 0.04, "ECON_ROLE": -0.05, "ENVIRONMENT": -0.03},
		"concerns": {"JOBS": -12, "HOUSING": -10, "GOVERNANCE": 8},
		"fiscal": "", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 1, "scope": "COLONY", "domain": "ECON"},
	# Leisure licensing: venue licence and alcohol strictness, 0 = lax (anyone, all hours) .. 100 = strict (few venues,
	# early closing, no alcohol). Fewer venues and jobs, calmer streets.
	{"id": "LAW_LEISURE_LICENSING", "owner": "law", "legislative": true, "type": "NUMBER", "range": [0, 100], "default": 40,
		"legalLevel": "LAW", "foundingEra": "COMMANDER", "ideology": {"AUTONOMY": -0.1, "INSTITUTIONS": 0.05},
		"concerns": {"SAFETY": 15, "JOBS": -10, "FAIRNESS": -3},
		"fiscal": "", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 1, "scope": "COLONY", "domain": "ECON"},
	# ---- T5 transport law (planning/spec-transport-v1.md T5). Read through sim/law/transport_law.gd. NUMBER levers.
	# Fare cap: public (CTA) fares at most this % of the route's cost; below 100 the treasury pays the difference,
	# 0 = free public transport.
	{"id": "LAW_FARE_CAP", "owner": "law", "legislative": true, "type": "NUMBER", "range": [0, 150], "default": 100,
		"legalLevel": "LAW", "foundingEra": "COMMANDER", "ideology": {"REDISTRIBUTION": -0.05, "FISCAL": -0.04},
		"concerns": {"COST_OF_LIVING": -20, "JOBS": -5, "GOVERNANCE": 20},
		"fiscal": "", "implementation": "STAFF_T_IMPL_PROGRAM", "lag": 1, "scope": "COLONY", "domain": "ECON"},
	# Vehicle inspection strictness (all operators): 0 lax .. 100 strict. Fewer accidents, dearer transport.
	{"id": "LAW_TRANSPORT_SAFETY", "owner": "law", "legislative": true, "type": "NUMBER", "range": [0, 100], "default": 40,
		"legalLevel": "LAW", "foundingEra": "COMMANDER", "ideology": {"ECON_ROLE": 0.05, "INSTITUTIONS": 0.04},
		"concerns": {"SAFETY": 20, "COST_OF_LIVING": -8, "JOBS": -4},
		"fiscal": "", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 1, "scope": "COLONY", "domain": "ECON"},
	# Rover and airship tour operators: 0 lax (anyone with a vehicle) .. 100 strict (few, well-equipped operators).
	{"id": "LAW_TOUR_LICENSING", "owner": "law", "legislative": true, "type": "NUMBER", "range": [0, 100], "default": 40,
		"legalLevel": "LAW", "foundingEra": "COMMANDER", "ideology": {"ECON_ROLE": 0.04, "ENVIRONMENT": 0.04},
		"concerns": {"SAFETY": 10, "ENVIRONMENT_QUALITY": 4, "JOBS": -8},
		"fiscal": "", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 1, "scope": "COLONY", "domain": "ECON"},
	# Road toll per vehicle trip on PAVED roads, in milli-W_ref (0 = free roads). Revenue to the treasury.
	{"id": "LAW_ROAD_TOLL", "owner": "law", "legislative": true, "type": "NUMBER", "range": [0, 20], "default": 0,
		"legalLevel": "LAW", "foundingEra": "COMMANDER", "ideology": {"FISCAL": -0.3, "REDISTRIBUTION": -0.2},
		"concerns": {"COST_OF_LIVING": -10, "JOBS": -5, "GOVERNANCE": 15},
		"fiscal": "", "implementation": "STAFF_T_IMPL_FISCAL", "lag": 1, "scope": "COLONY", "domain": "ECON"},
	# Who runs passenger routes: 0 = the transport authority (CTA) runs them all, 1 = franchise (routes tendered to
	# private operators under the CTA's fares and timetable), 2 = open market (private operators run where they like;
	# the CTA runs only what nobody else will, and the fare cap binds only the CTA).
	{"id": "LAW_TRANSPORT_OPERATION", "owner": "law", "legislative": true, "type": "NUMBER", "range": [0, 2], "default": 0,
		"legalLevel": "LAW", "foundingEra": "COMMANDER", "ideology": {"ECON_ROLE": -6, "REDISTRIBUTION": -2},
		"concerns": {"GOVERNANCE": 10, "PUBLIC_SERVICES": -6, "FAIRNESS": -4},
		"fiscal": "", "implementation": "STAFF_T_IMPL_PROGRAM", "lag": 3, "scope": "COLONY", "domain": "ECON"},
	# Colony law: whether colony customs also chase charter evasion (false = passive defiance), and the militia.
	# SOVEREIGNTY slopes (+ = independence). The charter terms above have none: only the home world sets them.
	# Eligibility: newcomers lean loyal, so independence parties favour residency rules over the non-citizen vote.
	{"id": "LAW_ENFORCE_CHARTER", "owner": "law", "type": "BOOL", "default": true,
		"legalLevel": "LAW", "foundingEra": "LOCKED", "ideology": {"SOVEREIGNTY": -12},
		"fiscal": "", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 1, "scope": "COLONY", "domain": "LAW"},
	{"id": "LAW_MILITIA", "owner": "law", "type": "NUMBER", "range": [0, 100], "default": 0,
		"legalLevel": "LAW", "foundingEra": "LOCKED", "ideology": {"SOVEREIGNTY": 1.0},
		"fiscal": "est_militia_cost", "implementation": "STAFF_T_IMPL_INSTITUTION", "lag": 6, "scope": "COLONY", "domain": "LAW"},
	# ---- M13 land (spec-areas-v1 9.4, A37). The government owns all land at founding.
	{"id": "LAW_LAND_DISPOSAL", "owner": "law", "type": "ENUM", "values": ["KEEP", "LEASE", "SELL"], "default": "LEASE",
		"legalLevel": "LAW", "foundingEra": "COMMANDER", "ideology": {"ECON_ROLE": -12},
		"fiscal": "est_land_revenue", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 1, "scope": "COLONY", "domain": "ECON"},
	{"id": "LAW_LAND_PRICE_FLOOR_PCT", "owner": "law", "type": "NUMBER", "range": [0, 100], "default": 90,
		"legalLevel": "LAW", "foundingEra": "COMMANDER", "ideology": {"REDISTRIBUTION": -0.15, "ECON_ROLE": -0.05},
		"fiscal": "est_land_revenue", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 1, "scope": "COLONY", "domain": "ECON"},
	{"id": "LAW_RENT_CONTROL", "owner": "law", "type": "ENUM", "values": ["NONE", "CAP", "FREEZE"], "default": "NONE",
		"legalLevel": "LAW", "foundingEra": "COMMANDER", "ideology": {"REDISTRIBUTION": 10, "ECON_ROLE": 6},
		"fiscal": "", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 1, "scope": "COLONY", "domain": "ECON"},
	{"id": "LAW_EVICTION_NOTICE_MONTHS", "owner": "law", "type": "NUMBER", "range": [1, 12], "default": 3,
		"legalLevel": "LAW", "foundingEra": "COMMANDER", "ideology": {"LABOR": 1.0, "REDISTRIBUTION": 1.0},
		"fiscal": "", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 1, "scope": "COLONY", "domain": "LAW"},
	# ---- M10 electoral eligibility (spec-population-v1 §4.2, PD §9.6). Read through LQ.eligibility(world).
	# Slopes use today's 7 axes; remap to STABILITY/LIBERTY when S3 adds them (planning/a9-population-note.md).
	{"id": "LAW_VOTING_AGE", "owner": "law", "type": "ENUM", "values": ["16", "18", "21"], "default": "18",
		"legalLevel": "LAW", "foundingEra": "LOCKED", "ideology": {"INSTITUTIONS": -8, "REDISTRIBUTION": -4},
		"fiscal": "", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 1, "scope": "COLONY", "domain": "LAW"},
	{"id": "LAW_RESIDENCY_FOR_VOTE", "owner": "law", "type": "NUMBER", "range": [0, 24], "default": 0,
		"legalLevel": "LAW", "foundingEra": "LOCKED", "ideology": {"INSTITUTIONS": -3, "REDISTRIBUTION": -2, "SOVEREIGNTY": 1},
		"fiscal": "", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 1, "scope": "COLONY", "domain": "LAW"},
	{"id": "LAW_NONCITIZEN_VOTE", "owner": "law", "type": "BOOL", "default": true,
		"legalLevel": "LAW", "foundingEra": "LOCKED", "ideology": {"INSTITUTIONS": 8, "REDISTRIBUTION": 6, "SOVEREIGNTY": -5},
		"fiscal": "", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 1, "scope": "COLONY", "domain": "LAW"},
	# ---- Retirement age (Bob E111; read by EconHouseholds.retirement_age). Higher = fewer pensioners, more workers,
	# a smaller pension bill: a classic fight between labour and fiscal hawks.
	# Concern hints per unit raised (legislature.relief): budget relief (GOVERNANCE = budget-sign proxy) against
	# lost pension years (COST_OF_LIVING, FAIRNESS). Phased in over 6 months.
	{"id": "LAW_RETIREMENT_AGE", "owner": "law", "legislative": true, "type": "NUMBER", "range": [55, 72], "default": 62, "step": 1,
		"legalLevel": "LAW", "foundingEra": "COMMANDER", "ideology": {"LABOR": -2.0, "REDISTRIBUTION": -1.5, "FISCAL": -1.5},
		"concerns": {"GOVERNANCE": 30, "JOBS": 5, "COST_OF_LIVING": -20, "FAIRNESS": -10},
		"fiscal": "", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 6, "scope": "COLONY", "domain": "ECON"},
	# ---- Strikes in essential services (Wilma, from Bob's seed-3 trace: a power strike blacked out the colony).
	# Read by Bob's strike code for POWER / WATERWORKS / CLINIC: NONE = full strike; MIN_SERVICE = the struck
	# facility keeps a minimum share of its output (Bob's constant, ~60%); NO_STRIKE = no stoppage, the dispute goes to binding
	# arbitration (a smaller rise, no outage). Hints per step: steadier infrastructure against workers' leverage.
	{"id": "LAW_ESSENTIAL_SERVICES", "owner": "law", "legislative": true, "type": "ENUM",
		"values": ["NONE", "MIN_SERVICE", "NO_STRIKE"], "default": "NONE",
		"legalLevel": "LAW", "foundingEra": "COMMANDER", "ideology": {"LABOR": -6, "INSTITUTIONS": 3},
		"concerns": {"INFRASTRUCTURE": 15, "FAIRNESS": -8},
		"fiscal": "", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 1, "scope": "COLONY", "domain": "ECON"},
	# ---- Union law (planning/spec-unions-v1.md §4, U4). Read through sim/law/union_law.gd. All NUMBER so AI
	# governments can draft them (one clause = 10% of the range); defaults keep the M9 behaviour. Ideology is per unit
	# (+LABOR = pro-worker), concern hints are over the whole range.
	# Strike ballot: yes share of members (%) a strike needs; 0 = no ballot required.
	{"id": "LAW_STRIKE_BALLOT", "owner": "law", "legislative": true, "type": "NUMBER", "range": [0, 80], "default": 0,
		"legalLevel": "LAW", "foundingEra": "COMMANDER", "ideology": {"LABOR": -0.12, "INSTITUTIONS": 0.05},
		"concerns": {"INFRASTRUCTURE": 8, "JOBS": 4, "FAIRNESS": -10},
		"fiscal": "", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 1, "scope": "COLONY", "domain": "ECON"},
	# Closed shop: 1 = closed-shop agreements are enforceable (membership a condition of the job), 0 = banned.
	{"id": "LAW_CLOSED_SHOP", "owner": "law", "legislative": true, "type": "NUMBER", "range": [0, 1], "default": 0,
		"legalLevel": "LAW", "foundingEra": "COMMANDER", "ideology": {"LABOR": 8, "AUTONOMY": -6},
		"concerns": {"FAIRNESS": 8, "JOBS": -4},
		"fiscal": "", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 1, "scope": "COLONY", "domain": "ECON"},
	# Public-sector right to strike: 1 = public servants may strike, 0 = they may not (disputes go to arbitration).
	{"id": "LAW_PUBLIC_SECTOR_STRIKE", "owner": "law", "legislative": true, "type": "NUMBER", "range": [0, 1], "default": 1,
		"legalLevel": "LAW", "foundingEra": "COMMANDER", "ideology": {"LABOR": 8, "INSTITUTIONS": -4},
		"concerns": {"FAIRNESS": 10, "PUBLIC_SERVICES": -12},
		"fiscal": "", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 1, "scope": "COLONY", "domain": "ECON"},
	# Union recognition: an employer must bargain with a union holding at least this density (%) of its workers;
	# 100 = no statutory duty (the employer may refuse talks).
	{"id": "LAW_UNION_RECOGNITION", "owner": "law", "legislative": true, "type": "NUMBER", "range": [10, 100], "default": 100,
		"legalLevel": "LAW", "foundingEra": "COMMANDER", "ideology": {"LABOR": -0.1, "ECON_ROLE": -0.03},
		"concerns": {"FAIRNESS": -12, "JOBS": 4},
		"fiscal": "", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 1, "scope": "COLONY", "domain": "ECON"},
	# Liability for unlawful strikes: % of the employer's losses a court may award against the union fund; 0 = immunity.
	{"id": "LAW_STRIKE_LIABILITY", "owner": "law", "legislative": true, "type": "NUMBER", "range": [0, 100], "default": 50,
		"legalLevel": "LAW", "foundingEra": "COMMANDER", "ideology": {"LABOR": -0.08, "INSTITUTIONS": 0.04},
		"concerns": {"INFRASTRUCTURE": 6, "FAIRNESS": -8},
		"fiscal": "", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 1, "scope": "COLONY", "domain": "ECON"},
	# Political levy: 0 = dues fund politics freely, 1 = members may opt out, 2 = members must opt in.
	{"id": "LAW_POLITICAL_LEVY", "owner": "law", "legislative": true, "type": "NUMBER", "range": [0, 2], "default": 0,
		"legalLevel": "LAW", "foundingEra": "COMMANDER", "ideology": {"LABOR": -4, "AUTONOMY": 3},
		"concerns": {"FAIRNESS": 4},
		"fiscal": "", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 1, "scope": "COLONY", "domain": "ECON"},
	# ---- MEDIA v1 press law (planning/spec-media-v1.md section 8). Read by sim/media/media_ops.gd.
	{"id": "LAW_PRESS_LICENSING", "owner": "law", "type": "ENUM", "values": ["NONE", "REGISTER", "LICENCE"], "default": "NONE",
		"legalLevel": "LAW", "foundingEra": "COMMANDER", "ideology": {"AUTONOMY": -10, "INSTITUTIONS": 4},
		"fiscal": "", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 1, "scope": "COLONY", "domain": "LAW"},
	{"id": "LAW_DEFAMATION_STANDARD", "owner": "law", "type": "ENUM", "values": ["NONE", "ACTUAL_MALICE", "STRICT"],
		"default": "ACTUAL_MALICE", "legalLevel": "LAW", "foundingEra": "COMMANDER", "ideology": {"AUTONOMY": -6, "INSTITUTIONS": 4},
		"fiscal": "", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 1, "scope": "COLONY", "domain": "LAW"},
	{"id": "LAW_CORRECTION_DUTY", "owner": "law", "type": "BOOL", "default": true,
		"legalLevel": "LAW", "foundingEra": "COMMANDER", "ideology": {"INSTITUTIONS": 4},
		"fiscal": "", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 1, "scope": "COLONY", "domain": "LAW"},
	{"id": "LAW_MEDIA_OWNERSHIP_CAP", "owner": "law", "type": "NUMBER", "range": [20, 100], "default": 100,
		"legalLevel": "LAW", "foundingEra": "COMMANDER", "ideology": {"ECON_ROLE": -0.15, "REDISTRIBUTION": -0.1},
		"fiscal": "", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 1, "scope": "COLONY", "domain": "ECON"},
	{"id": "LAW_PARTY_PRESS", "owner": "law", "type": "BOOL", "default": true,
		"legalLevel": "LAW", "foundingEra": "COMMANDER", "ideology": {"INSTITUTIONS": -3},
		"fiscal": "", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 1, "scope": "COLONY", "domain": "LAW"},
	{"id": "LAW_PUBLIC_MEDIA", "owner": "law", "type": "ENUM", "values": ["INDEPENDENT", "GOVERNMENT_RUN"], "default": "INDEPENDENT",
		"legalLevel": "LAW", "foundingEra": "COMMANDER", "ideology": {"INSTITUTIONS": -10, "AUTONOMY": -8},
		"fiscal": "", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 1, "scope": "COLONY", "domain": "LAW"},
	{"id": "LAW_FOI", "owner": "law", "type": "BOOL", "default": false,
		"legalLevel": "LAW", "foundingEra": "COMMANDER", "ideology": {"INSTITUTIONS": 8, "AUTONOMY": 4},
		"fiscal": "", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 1, "scope": "COLONY", "domain": "LAW"},
	{"id": "LAW_PRESS_SUBSIDY", "owner": "law", "type": "NUMBER", "range": [0, 3], "default": 0,
		"legalLevel": "LAW", "foundingEra": "COMMANDER", "ideology": {"ECON_ROLE": 4},
		"fiscal": "", "implementation": "STAFF_T_IMPL_REGULATORY", "lag": 1, "scope": "COLONY", "domain": "ECON"},
	{"id": "LAW_EMERGENCY_PRESS_CONTROL", "owner": "law", "type": "BOOL", "default": false,
		"legalLevel": "REGULATION", "foundingEra": "COMMANDER", "ideology": {}, "emergency": true,
		"fiscal": "", "implementation": "STAFF_T_IMPL_ADMIN", "lag": 0, "scope": "COLONY", "domain": "ADMIN"},
]

class_name EconFace
extends RefCounted
## THE ONE DOORWAY TO THE ECONOMY (rebuild step 1, planning/rebuild-company.md section 13).
## Every call the rest of the game made into the old economy is one function here, under its old name
## (<old class>_<old function>), with the old arguments. Each gives a plain "nothing yet" answer until the rebuild
## connects it. A function still giving the plain answer is a connection still open. Nothing outside this file
## may call the economy any other way. Built by planning/step1_doorway.py; edit by hand from here on.

const NO := "There is no economy yet."

const ACTIONS_LINE_OF := {}  # old EconActions.LINE_OF
const ANNUAL_MIN_M := 3  # old EconAnnual.MIN_M
const QUERY_LINE_LABELS := {}  # old EconQuery.LINE_LABELS
const UNIONS_DONATION_MIN := 2000 * 1000  # old EconUnions.DONATION_MIN
const UNIONS_MODERATE := ["PROFESSIONAL"]  # old Unions.MODERATE

## old EconActions.check (economy/econ_actions.gd), 7 calls
static func actions_check(_world: WorldState, _id: String, _params: Dictionary) -> Dictionary:
	return {"ok": false, "error": "There is no economy yet."}


## old EconActions.enqueue (economy/econ_actions.gd), 16 calls
static func actions_enqueue(_world: WorldState, _action_id: String, _params: Dictionary = {}) -> Dictionary:
	return {"ok": false, "error": "There is no economy yet."}


## old EconActions.headroom (economy/econ_actions.gd), 11 calls
static func actions_headroom(_world: WorldState, _line: String) -> int:
	return 0


## old EconActions.last_results (economy/econ_actions.gd), 1 call
static func actions_last_results(_world: WorldState, _n: int = 10) -> Array:
	return []


## old EconActions.lines_for (economy/econ_actions.gd), 1 call
static func actions_lines_for(_ftype: String) -> Array:
	return ["ECON_BUDGET_PUBLIC_WORKS"]


## old EconActions.pending (economy/econ_actions.gd), 1 call
static func actions_pending(_world: WorldState) -> Array:
	return []


## old EconActions.set_manual_award (economy/econ_actions.gd), 1 call
static func actions_set_manual_award(_world: WorldState, _on: bool) -> void:
	pass


## old EconActions.validate (economy/econ_actions.gd), 5 calls
static func actions_validate(_world: WorldState, _id: String, _p: Dictionary) -> String:
	return "There is no economy yet."


## old EconAnnual.months (economy/econ_annual.gd), 1 call
static func annual_months(o: Dictionary) -> int:
	return (o.get("pl_ring", []) as Array).size()


## old EconAnnual.sum12 (economy/econ_annual.gd), 1 call
static func annual_sum12(o: Dictionary) -> Dictionary:
	var out := {}
	for pl in o.get("pl_ring", []):
		for k in pl:
			out[k] = int(out.get(k, 0)) + int(pl[k])
	return out


## old EconBuilders.refuse (economy/econ_builders.gd), 1 call
static func builders_refuse(_world: WorldState, _p: Dictionary, _ranked: Array, _why: String) -> void:
	pass


## old EconCohorts.slums (economy/econ_cohorts.gd), 1 call
static func cohorts_slums(_world: WorldState) -> Array:
	return []


## old EconConstruction.award (economy/econ_construction.gd), 1 call
static func construction_award(_world: WorldState, _pid: String, _org_id: String) -> bool:
	return false


## old EconConstruction.estimate (economy/econ_construction.gd), 6 calls
static func construction_estimate(_ftype: String) -> int:
	return 0


## old EconConstruction.ranked_bids (economy/econ_construction.gd), 1 call
static func construction_ranked_bids(_world: WorldState, _p: Dictionary) -> Array:
	return []


## old EconEssentials.human_governs (economy/econ_essentials.gd), 1 call
static func essentials_human_governs(_world: WorldState) -> bool:
	return false


## old EconEssentials.offers (economy/econ_essentials.gd), 1 call
static func essentials_offers(_world: WorldState) -> Dictionary:
	return {}


## old EconFacts.emit (economy/econ_facts.gd), 1 call
static func facts_emit(_world: WorldState, _type: String, _location, _subjects: Array, _responsible: Array, _impact: Dictionary, _magnitude: int, _visibility: String, _data: Dictionary = {}, _affected = "ALL", _causes: Array = []) -> String:
	return ""


## old EconFinance._spend_line (economy/econ_finance.gd), 2 calls
static func finance_spend_line(_world: WorldState, _lever_id: String, _amount: int) -> void:
	pass


## old EconFinance.gov_pay (economy/econ_finance.gd), 2 calls
static func finance_gov_pay(_world: WorldState, _to_acct: String, _amount: int, _memo: String) -> int:
	return 0


## old EconHouseholds.disposable (economy/econ_households.gd), 1 call
static func households_disposable(g: Dictionary) -> int:
	var i: Dictionary = g.get("income", {})
	return int(i.get("wages", 0)) + int(i.get("benefit", 0)) + int(i.get("pension", 0)) + int(i.get("dividend", 0)) + int(i.get("self", 0))


## old EconHouseholds.pay_media_wages (economy/econ_households.gd), 2 calls
static func households_pay_media_wages(_world: WorldState, _from_acct: String, _amount: int, _district: String) -> int:
	return 0


## old EconHouseholds.persons (economy/econ_households.gd), 5 calls
static func households_persons(g: Dictionary) -> int:
	return int(g.get("lf", 0)) + int(g.get("nonpart", 0)) + int(g.get("retired", 0)) + int(g.get("children", 0)) + int(g.get("owners", 0))


## old EconLabor.employed (economy/econ_labor.gd), 1 call
static func labor_employed(g: Dictionary) -> int:
	var n := 0
	for occ in g.get("emp", {}):
		n += int(g["emp"][occ])
	return n


## old EconLabor.occupation_of (economy/econ_labor.gd), 1 call
static func labor_occupation_of(_world: WorldState, _org_id: String, _ftype: String) -> String:
	return ""


## old EconLabor.staff_total (economy/econ_labor.gd), 2 calls
static func labor_staff_total(staff: Dictionary) -> int:
	var n := 0
	for t in staff:
		for g in staff[t]:
			n += int(staff[t][g])
	return n


## old EconPop.casualties (economy/econ_pop.gd), 2 calls
static func pop_casualties(_world: WorldState, _district: String, _n: int, _where: String = "", _fid: String = "") -> int:
	return 0


## old EconPop.district_of (economy/econ_pop.gd), 1 call
static func pop_district_of(hb: String) -> String:
	return hb.substr(3)


## old EconPop.lab_parts (economy/econ_pop.gd), 1 call
static func pop_lab_parts(k: String) -> Array:
	var i := k.rfind("|")
	return [k.substr(0, i), k.substr(i + 1)]


## old EconPop.people_by_lab (economy/econ_pop.gd), 2 calls
static func pop_people_by_lab(_world: WorldState, _status: String, _occ: String = "") -> Dictionary:
	return {}


## old EconPublicCo.pending (economy/econ_public_co.gd), 1 call
static func publicco_pending(_world: WorldState) -> Dictionary:
	return {}


## old EconQuery.budget_view (economy/econ_query.gd), 3 calls
static func query_budget_view(world: WorldState) -> Dictionary:
	return {"treasury": float(world.ledger.balance(CoreUtil.TREASURY)) / float(CoreUtil.S), "debt": 0.0, "credit_headroom": 0.0, "runway_months": 0, "balance_pct": 0, "grant_this_month": 0.0, "lines": [], "tax_levers": {"income": 0, "profit": 0, "tariff": 0}}


## old EconQuery.commission_options (economy/econ_query.gd), 1 call
static func query_commission_options(_world: WorldState) -> Array:
	return []


## old EconQuery.commuting (economy/econ_query.gd), 2 calls
static func query_commuting(_world: WorldState) -> Array:
	return []


## old EconQuery.companies (economy/econ_query.gd), 1 call
static func query_companies(_world: WorldState, _include_dissolved: bool = false) -> Array:
	return []


## old EconQuery.company_profile (economy/econ_query.gd), 1 call
static func query_company_profile(_world: WorldState, _oid: String) -> Dictionary:
	return {}


## old EconQuery.demography (economy/econ_query.gd), 2 calls
static func query_demography(_world: WorldState) -> Dictionary:
	return {}


## old EconQuery.district_economy (economy/econ_query.gd), 1 call
static func query_district_economy(world: WorldState, d: String) -> Dictionary:
	return {"district": d, "name": str(world.peek("district").get(d, {}).get("name", d))}


## old EconQuery.essentials (economy/econ_query.gd), 3 calls
static func query_essentials(_world: WorldState) -> Dictionary:
	return {}


## old EconQuery.explain_facility (economy/econ_query.gd), 3 calls
static func query_explain_facility(_world: WorldState, _fid: String) -> Dictionary:
	return {}


## old EconQuery.explain_fact (economy/econ_query.gd), 2 calls
static func query_explain_fact(_world: WorldState, _fact_id: String) -> Array:
	return []


## old EconQuery.explain_project (economy/econ_query.gd), 1 call
static func query_explain_project(_world: WorldState, _pid: String) -> Array:
	return []


## old EconQuery.labour (economy/econ_query.gd), 1 call
static func query_labour(_world: WorldState) -> Dictionary:
	return {}


## old EconQuery.market_overview (economy/econ_query.gd), 2 calls
static func query_market_overview(_world: WorldState) -> Array:
	return []


## old EconQuery.police (economy/econ_query.gd), 1 call
static func query_police(_world: WorldState) -> Dictionary:
	return {}


## old EconQuery.projects (economy/econ_query.gd), 1 call
static func query_projects(_world: WorldState, _owner: String = "gov") -> Array:
	return []


## old EconQuery.recent_econ_facts (economy/econ_query.gd), 1 call
static func query_recent_econ_facts(_world: WorldState, _months: int = 6, _min_mag: int = 30) -> Array:
	return []


## old EconQuery.shortages (economy/econ_query.gd), 1 call
static func query_shortages(_world: WorldState, _threshold_pct: float = 97.0) -> Array:
	return []


## old EconQuery.tenders (economy/econ_query.gd), 1 call
static func query_tenders(_world: WorldState) -> Array:
	return []


## old EconQuery.upgrade_options (economy/econ_query.gd), 1 call
static func query_upgrade_options(_world: WorldState) -> Array:
	return []


## old EconQuery.workload (economy/econ_query.gd), 1 call
static func query_workload(_world: WorldState) -> Dictionary:
	return {}


## old EconRulesUtil.capacity_on (economy/econ_rules_utilities.gd), 1 call
static func rulesutil_capacity_on(_world: WorldState, _ftype: String) -> bool:
	return false


## old EconStaple.active (economy/econ_staple.gd), 1 call
static func staple_active(_world: WorldState) -> bool:
	return false


## old EconStaple.raw_pct (economy/econ_staple.gd), 1 call
static func staple_raw_pct(_world: WorldState, _d: String) -> float:
	return 0.0


## old EconTrade.add_ship (economy/econ_trade.gd), 1 call
static func trade_add_ship(_world: WorldState, _next_month: int, _hold: int) -> void:
	pass


## old EconTrade.balance (economy/econ_trade.gd), 2 calls
static func trade_balance(_world: WorldState) -> Dictionary:
	return {}


## old EconTrade.export_pressure (economy/econ_trade.gd), 1 call
static func trade_export_pressure(_world: WorldState) -> Dictionary:
	return {}


## old EconTrade.fleet (economy/econ_trade.gd), 3 calls
static func trade_fleet(_world: WorldState) -> Array:
	return []


## old EconTrade.hold_of (economy/econ_trade.gd), 1 call
static func trade_hold_of(_world: WorldState, _idx: int) -> int:
	return 0


## old EconTrade.home_tariff (economy/econ_trade.gd), 1 call
static func trade_home_tariff(_world: WorldState) -> int:
	return 0


## old EconTrade.last_ship (economy/econ_trade.gd), 3 calls
static func trade_last_ship(_world: WorldState) -> Dictionary:
	return {}


## old EconTrade.next_ship (economy/econ_trade.gd), 2 calls
static func trade_next_ship(_world: WorldState) -> int:
	return -1


## old EconTrade.port_capacity (economy/econ_trade.gd), 1 call
static func trade_port_capacity(_world: WorldState) -> int:
	return 0


## old EconTrade.port_stock (economy/econ_trade.gd), 1 call
static func trade_port_stock(_world: WorldState) -> Dictionary:
	return {}


## old EconTrade.prices (economy/econ_trade.gd), 1 call
static func trade_prices(_world: WorldState) -> Dictionary:
	return {}


## old EconTrade.set_hold (economy/econ_trade.gd), 1 call
static func trade_set_hold(_world: WorldState, _idx: int, _hold: int) -> void:
	pass


## old EconTrade.ship_interval (economy/econ_trade.gd), 1 call
static func trade_ship_interval(_world: WorldState) -> Array:
	return [18, 30]


## old EconTraining.summary (economy/econ_training.gd), 2 calls
static func training_summary(_world: WorldState) -> Dictionary:
	return {}


## old EconWorkload.active (economy/econ_workload.gd), 1 call
static func workload_active(_world: WorldState) -> bool:
	return false


## old FirmAI.colony_unemployment (companies/firm_ai.gd), 2 calls
static func firm_colony_unemployment(_world: WorldState) -> float:
	return 0.0


## old UnionDisputes.dispute_of (economy/union_disputes.gd), 1 call
static func disputes_dispute_of(_world: WorldState, _union_id: String) -> Dictionary:
	return {}


## old UnionDisputes.pending_demands (economy/union_disputes.gd), 1 call
static func disputes_pending_demands(_world: WorldState, _employer: String = "") -> Array:
	return []


## old Unions.active (economy/unions.gd), 6 calls
static func unions_active(_world: WorldState) -> Array:
	return []


## old Unions.federation (economy/unions.gd), 7 calls
static func unions_federation(_world: WorldState) -> Dictionary:
	return {}


## old Unions.get_union (economy/unions.gd), 3 calls
static func unions_get_union(_world: WorldState, _id: String) -> Dictionary:
	return {}


## old Unions.of_occ (economy/unions.gd), 1 call
static func unions_of_occ(_world: WorldState, _occ: String) -> Dictionary:
	return {}


## old Unions.spare_fund (economy/unions.gd), 3 calls
static func unions_spare_fund(_world: WorldState, _id: String) -> int:
	return 0


## old Unions.strike_weeks (economy/unions.gd), 2 calls
static func unions_strike_weeks(_world: WorldState, _id: String) -> float:
	return 0.0


# ---------------------------------------------------------------- reached before by loading a script by its path

## old econ_institutions.gd on(): are public institutions run by the eight rules
static func inst_on(_world: WorldState) -> bool:
	return false


## old econ_institutions.gd build_needs(): plants an institution wants built
static func inst_build_needs(_world: WorldState) -> Array:
	return []


## old econ_institutions.gd close_candidates(): plants an institution wants closed
static func inst_close_candidates(_world: WorldState) -> Array:
	return []


## old econ_institutions.gd budget_requests(): what the institutions ask of the budget
static func inst_budget_requests(_world: WorldState) -> Array:
	return []


## old econ_institutions.gd answered(): the government has taken a request
static func inst_answered(_world: WorldState, _line: String, _answer: int) -> void:
	pass


## old econ_institutions.gd close(): close a public plant
static func inst_close(_world: WorldState, _fid: String) -> Dictionary:
	return {"ok": false, "error": NO}


## old econ_institutions.gd reopen(): reopen a public plant
static func inst_reopen(_world: WorldState, _fid: String) -> Dictionary:
	return {"ok": false, "error": NO}


## old econ_police.gd org(): the police organisation's id
static func police_org(_world: WorldState) -> String:
	return ""


## old EconQuery.prisons(): [{places, ...}]
static func query_prisons(_world: WorldState) -> Array:
	return []


## old companies/insolvency.gd court_liquidation(): the court winds a company up. True when it was done.
static func insolvency_court_liquidation(_world: WorldState, _org_id: String, _reason: String) -> bool:
	return false

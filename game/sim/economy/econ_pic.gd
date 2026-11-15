class_name EconPic
extends RefCounted
## PIC definitions for econ (planning/pic-economy.md §1, §3, §4). Indicator normalize values are ×1000 of display units.


## pic-core v1.1 exceptionOnly: these count toward a concern only while something is wrong. S7's shack and homeless
## shares sit at 0 almost everywhere; as ordinary indicators they added "perfect" weight to HOUSING, SAFETY and FAIRNESS
## in every district (concerns are weighted averages), diluting the real housing signal even with S7 switched off.
const EXCEPTION_ONLY := ["ECON_INFORMAL_HOUSING", "ECON_HOMELESSNESS", "ECON_ELDER_CARE_ACCESS", "ECON_CHILDCARE_ACCESS",
	"ECON_FOOD_UNAFFORDABLE", "ECON_RAW_FOOD_SHARE"]


static func indicators() -> Array:
	# id, unit, [min,max], granularity, polarity, concerns, good, bad, visibility, perceptionLag
	var rows := [
		["ECON_UNEMPLOYMENT_RATE", "%", [0, 100], "DISTRICT", -1, {"JOBS": 1.0}, 3, 15, "PUBLIC", 0],
		["ECON_JOB_RISK", "%", [0, 100], "VOTER_CELL", -1, {"JOBS": 0.8, "FAIRNESS": 0.1}, 3, 20, "PUBLIC", 0],
		["ECON_REAL_INCOME_INDEX", "index", [0, 300], "VOTER_CELL", 1, {"COST_OF_LIVING": 0.5, "JOBS": 0.2}, 115, 85, "PUBLIC", 3],
		["ECON_ESSENTIALS_SHARE", "%", [0, 200], "VOTER_CELL", -1, {"COST_OF_LIVING": 0.8, "HOUSING": 0.1}, 40, 85, "PUBLIC", 0],
		["ECON_ESSENTIAL_SHORTFALL", "%", [0, 100], "DISTRICT", -1, {"COST_OF_LIVING": 0.6, "PUBLIC_SERVICES": 0.2, "GOVERNANCE": 0.1}, 0, 10, "PUBLIC", 0],
		["ECON_CPI_INFLATION", "%", [-50, 300], "COLONY", -1, {"COST_OF_LIVING": 0.5, "GOVERNANCE": 0.1}, 2, 12, "PUBLIC", 2],
		["ECON_LOCAL_PRICE_INDEX", "index", [50, 200], "DISTRICT", -1, {"COST_OF_LIVING": 0.3, "FAIRNESS": 0.2}, 95, 120, "PUBLIC", 1],
		["ECON_RENT_BURDEN", "%", [0, 200], "VOTER_CELL", -1, {"HOUSING": 0.6, "COST_OF_LIVING": 0.3}, 20, 45, "PUBLIC", 0],
		["ECON_OVERCROWDING", "households/unit", [0, 3], "DISTRICT", -1, {"HOUSING": 1.0}, 0.95, 1.30, "PUBLIC", 0],
		# S3 (v6 review): the state of the homes (average block condition, 0–100) — renovations show up in housing concern
		["ECON_HOUSING_CONDITION", "index", [0, 100], "DISTRICT", 1, {"HOUSING": 0.4}, 80, 40, "PUBLIC", 2],
		# S7: households in self-built shacks / homeless, % of the district's households
		["ECON_INFORMAL_HOUSING", "%", [0, 100], "DISTRICT", -1, {"HOUSING": 0.5, "SAFETY": 0.2, "FAIRNESS": 0.2}, 0, 15, "PUBLIC", 1],
		["ECON_HOMELESSNESS", "%", [0, 100], "DISTRICT", -1, {"HOUSING": 0.6, "FAIRNESS": 0.3, "SAFETY": 0.2}, 0, 5, "PUBLIC", 0],
		# part E (EconCare, opt-in CARE): the share of the retired / of children aged 1–5 actually cared for
		["ECON_ELDER_CARE_ACCESS", "%", [0, 100], "DISTRICT", 1, {"PUBLIC_SERVICES": 0.4, "FAIRNESS": 0.1}, 80, 30, "PUBLIC", 1],
		["ECON_CHILDCARE_ACCESS", "%", [0, 100], "DISTRICT", 1, {"PUBLIC_SERVICES": 0.3, "JOBS": 0.1, "COST_OF_LIVING": 0.1}, 70, 25, "PUBLIC", 1],
		# S7a (EconFoodSec, opt-in S7F): share of household food need that went unbought for lack of money
		["ECON_FOOD_UNAFFORDABLE", "%", [0, 100], "DISTRICT", -1, {"COST_OF_LIVING": 0.5, "FAIRNESS": 0.3, "GOVERNANCE": 0.1}, 0, 10, "PUBLIC", 0],
		# E146 (EconStaple, opt-in): share of the preferred bakery portion of food that had to be raw farm food
		["ECON_RAW_FOOD_SHARE", "%", [0, 100], "DISTRICT", -1, {"COST_OF_LIVING": 0.5, "FAIRNESS": 0.2}, 0, 40, "PUBLIC", 0],
		["ECON_UTILITY_RELIABILITY", "%", [0, 100], "DISTRICT", 1, {"INFRASTRUCTURE": 0.6, "PUBLIC_SERVICES": 0.3}, 100, 85, "PUBLIC", 0],
		["ECON_INFRA_CONDITION", "index", [0, 100], "DISTRICT", 1, {"INFRASTRUCTURE": 0.6, "SAFETY": 0.1}, 90, 50, "PUBLIC", 3],
		["ECON_LOGISTICS_DELAY", "%", [0, 100], "DISTRICT", -1, {"INFRASTRUCTURE": 0.5, "COST_OF_LIVING": 0.1}, 0, 20, "PUBLIC", 1],
		["ECON_HEALTH_ACCESS", "%", [0, 100], "DISTRICT", 1, {"PUBLIC_SERVICES": 0.6, "SAFETY": 0.1}, 100, 60, "PUBLIC", 0],
		["ECON_EDUCATION_ACCESS", "%", [0, 100], "DISTRICT", 1, {"PUBLIC_SERVICES": 0.4, "FAIRNESS": 0.2}, 100, 60, "PUBLIC", 1],
		["ECON_POLLUTION_INDEX", "index", [0, 100], "DISTRICT", -1, {"ENVIRONMENT_QUALITY": 0.9, "SAFETY": 0.1}, 10, 70, "PUBLIC", 2],
		["ECON_INCOME_RATIO", "ratio", [1, 20], "DISTRICT", -1, {"FAIRNESS": 0.7}, 2.0, 5.0, "PUBLIC", 6],
		["ECON_TAX_BURDEN", "%", [0, 100], "VOTER_CELL", -1, {"COST_OF_LIVING": 0.3, "FAIRNESS": 0.1}, 10, 35, "PUBLIC", 1],
		["ECON_FINANCIAL_SECURITY", "months", [0, 60], "VOTER_CELL", 1, {"COST_OF_LIVING": 0.3, "JOBS": 0.2}, 6, 0.5, "PUBLIC", 1],
		["ECON_REAL_WAGE_GROWTH", "%", [-50, 50], "VOTER_CELL", 1, {"JOBS": 0.3, "COST_OF_LIVING": 0.3}, 3, -5, "PUBLIC", 3],
		["ECON_GROWTH", "%", [-50, 50], "COLONY", 1, {"JOBS": 0.3, "GOVERNANCE": 0.1}, 6, -4, "PUBLIC", 3],
		["ECON_PROJECT_DELIVERY", "%", [0, 100], "COLONY", 1, {"GOVERNANCE": 0.5, "INFRASTRUCTURE": 0.3}, 90, 40, "PUBLIC", 1],
		["ECON_COMPANY_FAILURES", "count", [0, 50], "COLONY", -1, {"JOBS": 0.2, "GOVERNANCE": 0.1}, 0, 4, "PUBLIC", 0],
		["ECON_IMPORT_DEPENDENCY", "%", [0, 100], "COLONY", -1, {"COST_OF_LIVING": 0.1, "GOVERNANCE": 0.1}, 5, 50, "PUBLIC", 3],
		["ECON_TRADE_BALANCE", "credits", [-10000000, 10000000], "COLONY", 1, {"JOBS": 0.1, "GOVERNANCE": 0.05}, 0, -50000, "PUBLIC", 0],  # D1: export earnings − imports bought, last 12 months
		["ECON_PUBLIC_DEBT_RATIO", "%", [0, 1000], "COLONY", -1, {"GOVERNANCE": 0.4}, 0, 150, "PUBLIC", 2],
		["ECON_BUDGET_BALANCE", "%", [-500, 100], "COLONY", 1, {"GOVERNANCE": 0.3}, 5, -40, "PUBLIC", 2],
		["ECON_TREASURY_RUNWAY", "months", [0, 240], "COLONY", 1, {"GOVERNANCE": 0.2}, 24, 3, "OFFICIAL", 0],
		["ECON_OPERATING_BALANCE", "%", [-500, 100], "COLONY", 1, {"GOVERNANCE": 0.05}, 5, -40, "OFFICIAL", 0],
		["ECON_MARKET_CONCENTRATION", "HHI", [0, 10000], "COLONY", -1, {"FAIRNESS": 0.1}, 1500, 6000, "OFFICIAL", 6],
		# M9 (spec-politics-v2 §5): keyed by occupation (INDUSTRY, MINING, ...); no direct concern, politics reads it as union strength
		["ECON_UNION_DENSITY", "%", [0, 100], "OCCUPATION", 1, {}, 50, 10, "PUBLIC", 0],
		# M10 S2 (spec-population-v1 §3.2, PD §4.4, §4.7): no concern weights yet; politics S3 decides how voters weigh them.
		# Gini is keyed by district and also "COLONY"; deprivation = % of residents who cannot afford essentials.
		["ECON_GINI", "index", [0, 100], "DISTRICT", -1, {}, 30, 50, "PUBLIC", 0],
		["ECON_DEPRIVATION", "%", [0, 100], "DISTRICT", -1, {}, 0, 20, "PUBLIC", 0],
	]
	# E74 non-linear harm (pic-core v1.4). Same sign convention as `concerns` (effect of RAISING the lever, per full range),
	# applied only to the part of a change above `from` (concernsHigh) or below `from` (concernsLow, proposed v1.4b).
	var high := {
		"ECON_INCOME_TAX_RATE": {"from": 35, "concerns": {"JOBS": -60, "COST_OF_LIVING": -40}},
		"ECON_SALES_TAX": {"from": 15, "concerns": {"COST_OF_LIVING": -50, "JOBS": -30}},
		"ECON_PROFIT_TAX_RATE": {"from": 30, "concerns": {"JOBS": -60}},
		"ECON_IMPORT_TARIFF": {"from": 15, "concerns": {"COST_OF_LIVING": -50, "JOBS": -20}},
		"ECON_MIN_WAGE": {"from": 90, "concerns": {"JOBS": -60}},
		"ECON_UTILITY_TARIFF_ENERGY": {"from": 70, "concerns": {"COST_OF_LIVING": -40, "JOBS": -20}},
		"ECON_UTILITY_TARIFF_WATER": {"from": 35, "concerns": {"COST_OF_LIVING": -40}},
		"ECON_PUBLIC_RENT": {"from": 400, "concerns": {"HOUSING": -40, "COST_OF_LIVING": -20}},
		"ECON_HEALTH_FEE": {"from": 40, "concerns": {"PUBLIC_SERVICES": -40}},
		"ECON_SCHOOL_FEE": {"from": 80, "concerns": {"PUBLIC_SERVICES": -30, "FAIRNESS": -20}},
	}
	var low := {
		"ECON_PUBLIC_PAY_INDEX": {"from": 95, "concerns": {"PUBLIC_SERVICES": 50, "JOBS": 10}},
		"ECON_PENSION_RATE": {"from": 20, "concerns": {"COST_OF_LIVING": 50, "FAIRNESS": 20}},
		"ECON_UNEMPLOYMENT_BENEFIT_RATE": {"from": 25, "concerns": {"COST_OF_LIVING": 40, "JOBS": 25}},
		"ECON_BENEFIT_FLOOR": {"from": 30, "concerns": {"COST_OF_LIVING": 40, "JOBS": 15}},
		"ECON_FOOD_ASSISTANCE": {"from": 50, "concerns": {"COST_OF_LIVING": 40, "FAIRNESS": 15}},
		"ECON_RENT_INCREASE_CAP": {"from": 5, "concerns": {"HOUSING": 40}},
		"ECON_UTILITY_TARIFF_ENERGY": {"from": 25, "concerns": {"INFRASTRUCTURE": 40}},
		"ECON_UTILITY_TARIFF_WATER": {"from": 12, "concerns": {"INFRASTRUCTURE": 30}},
		"ECON_BUDGET_INFRASTRUCTURE": {"from": 1500, "concerns": {"INFRASTRUCTURE": 60, "JOBS": 30}},
		"ECON_BUDGET_HEALTH": {"from": 500, "concerns": {"PUBLIC_SERVICES": 50}},
		"ECON_BUDGET_EDUCATION": {"from": 350, "concerns": {"PUBLIC_SERVICES": 40}},
	}
	var out: Array = []
	for r in rows:
		out.append({"id": r[0], "owner": "econ", "unit": r[1], "range": [int(r[2][0] * 1000), int(r[2][1] * 1000)],
			"granularity": r[3], "polarity": r[4], "concerns": r[5], "normalize": {"good": int(r[6] * 1000), "bad": int(r[7] * 1000)},
			"phase": TickPhase.SOCIAL, "visibility": r[8], "perceptionLag": r[9], "history": true,
			"exceptionOnly": EXCEPTION_ONLY.has(r[0])})
	# pic-core §3 v1.2: fiscal-stress signals for the government (current values, no perception lag) — E57
	# budget balance is NOT a stress input: founding-era capex from the charter treasury reads as a huge "deficit" (E57)
	# v7 follow-up (Wilma, A55): a treasury of 24 months of real reserves (no phantom credit in a default, E131) is comfortable, 6 is stressed (was 36 / 12:
	# governments maxed taxes in a slump while holding 2-3 years of spending in reserve, draining household demand)
	var stress := {"ECON_TREASURY_RUNWAY": {"good": 24000, "bad": 6000}, "ECON_PUBLIC_DEBT_RATIO": {"good": 60000, "bad": 150000}}
	# pic-core v1.3 soft brake: no budget-worsening proposals while below floor (E59). The operating balance excludes
	# capital spending, so charter-funded founding construction does not trip it.
	var guard := {"ECON_TREASURY_RUNWAY": {"floor": 9000}, "ECON_OPERATING_BALANCE": {"floor": -15000}}   # A55: was 24 months, briefly 6
	for d in out:
		if stress.has(d["id"]):
			d["fiscalStress"] = stress[d["id"]]
		if guard.has(d["id"]):
			d["fiscalGuard"] = guard[d["id"]]
	return out


static func levers() -> Array:
	# id, range, default, legalLevel, ideology, concerns, implementation, lag, is_tax
	var F := "STAFF_T_IMPL_FISCAL"
	var R := "STAFF_T_IMPL_REGULATORY"
	var P := "STAFF_T_IMPL_PROGRAM"
	var A := "STAFF_T_IMPL_ADMIN"
	var rows := [
		["ECON_INCOME_TAX_RATE", [0, 50], 24, "LAW", {"REDISTRIBUTION": 4.0, "ECON_ROLE": 1.0}, {"COST_OF_LIVING": -40, "FAIRNESS": 10, "GOVERNANCE": 40}, F, 1, true],
		["ECON_TAX_ALLOWANCE", [0, 2000], 300, "LAW", {"REDISTRIBUTION": 0.03}, {"COST_OF_LIVING": 30, "FAIRNESS": 25, "GOVERNANCE": -20}, F, 1, false],
		["ECON_PROFIT_TAX_RATE", [0, 50], 20, "LAW", {"REDISTRIBUTION": 2.0, "ECON_ROLE": 2.0}, {"JOBS": -30, "FAIRNESS": 20, "GOVERNANCE": 25}, F, 3, true],
		["ECON_SALES_TAX", [0, 25], 8, "LAW", {"REDISTRIBUTION": -1.0, "FISCAL": -0.5}, {"COST_OF_LIVING": -30, "FAIRNESS": -10, "GOVERNANCE": 35}, F, 1, true],
		["ECON_IMPORT_TARIFF", [0, 50], 0, "LAW", {"ECON_ROLE": 0.3, "AUTONOMY": 0.2}, {"COST_OF_LIVING": -15, "JOBS": 10, "GOVERNANCE": 10}, F, 1, true],
		["ECON_UNION_RIGHTS", [0, 100], 50, "LAW", {"LABOR": 0.8, "ECON_ROLE": 0.1}, {"FAIRNESS": 25, "SAFETY": 10, "JOBS": -10}, R, 2, false],
		["ECON_MIN_WAGE", [40, 150], 40, "LAW", {"LABOR": 0.6, "ECON_ROLE": 0.2}, {"COST_OF_LIVING": 30, "FAIRNESS": 25, "JOBS": -30}, R, 2, false],
		["ECON_UNEMPLOYMENT_BENEFIT_RATE", [0, 80], 40, "LAW", {"REDISTRIBUTION": 0.6, "LABOR": 0.3, "FISCAL": 0.2}, {"COST_OF_LIVING": 30, "FAIRNESS": 20, "GOVERNANCE": -15}, P, 1, false],
		["ECON_BENEFIT_FLOOR", [0, 100], 50, "LAW", {"REDISTRIBUTION": 0.3, "FISCAL": 0.1}, {"COST_OF_LIVING": 25, "FAIRNESS": 15, "GOVERNANCE": -15}, "STAFF_T_IMPL_PROGRAM", 1, false],
		["ECON_BENEFIT_DURATION", [3, 60], 12, "LAW", {"REDISTRIBUTION": 0.5}, {"COST_OF_LIVING": 15, "FAIRNESS": 10, "GOVERNANCE": -10}, P, 1, false],
		["ECON_FOOD_ASSISTANCE", [0, 100], 100, "LAW", {"REDISTRIBUTION": 0.15, "FISCAL": 0.05}, {"COST_OF_LIVING": 25, "FAIRNESS": 15, "GOVERNANCE": -10}, P, 1, false],
		["ECON_PENSION_RATE", [0, 100], 35, "LAW", {"REDISTRIBUTION": 0.4, "FISCAL": 0.2}, {"COST_OF_LIVING": 25, "GOVERNANCE": -20}, P, 1, false],
		["ECON_PUBLIC_PAY_INDEX", [80, 130], 100, "REGULATION", {"LABOR": 0.6, "FISCAL": 0.6, "ECON_ROLE": 0.2}, {"PUBLIC_SERVICES": 20, "JOBS": 5, "GOVERNANCE": -25}, F, 1, false],
		["ECON_UTILITY_TARIFF_ENERGY", [10, 120], 40, "ADMIN", {"REDISTRIBUTION": -0.6, "ECON_ROLE": -0.4, "FISCAL": -0.4}, {"COST_OF_LIVING": -35, "INFRASTRUCTURE": 10, "GOVERNANCE": 15}, F, 1, false],
		["ECON_UTILITY_TARIFF_WATER", [5, 60], 20, "ADMIN", {"REDISTRIBUTION": -0.6, "ECON_ROLE": -0.4, "FISCAL": -0.4}, {"COST_OF_LIVING": -25, "GOVERNANCE": 10}, F, 1, false],
		["ECON_FREIGHT_TARIFF", [1, 20], 5, "ADMIN", {"ECON_ROLE": -1.0, "AUTONOMY": -1.0}, {"COST_OF_LIVING": -10, "INFRASTRUCTURE": 10, "GOVERNANCE": 5}, A, 1, false],
		["ECON_PUBLIC_RENT", [100, 600], 250, "ADMIN", {"REDISTRIBUTION": -0.12, "FISCAL": -0.04}, {"HOUSING": -40, "COST_OF_LIVING": -20, "GOVERNANCE": 15}, A, 1, false],
		["ECON_RENT_INCREASE_CAP", [0, 20], 20, "LAW", {"ECON_ROLE": -1.5, "REDISTRIBUTION": -1.0}, {"HOUSING": -15, "COST_OF_LIVING": -10}, R, 2, false],
		["ECON_STRATEGIC_SUBSIDY_RATE", [0, 30], 0, "LAW", {"ECON_ROLE": 1.0, "FISCAL": 0.3}, {"JOBS": 20, "INFRASTRUCTURE": 10, "GOVERNANCE": -12}, "STAFF_T_IMPL_PROGRAM", 1, false],
		["ECON_PE_DIVIDEND_RATE", [0, 100], 50, "REGULATION", {"ECON_ROLE": -0.2, "FISCAL": -0.1}, {"GOVERNANCE": 10, "INFRASTRUCTURE": -10}, F, 3, false],
		["ECON_PROCUREMENT_PRICE_WEIGHT", [30, 100], 50, "REGULATION", {"FISCAL": -0.3, "INSTITUTIONS": -0.1}, {"GOVERNANCE": -10, "INFRASTRUCTURE": -10}, R, 1, false],
		["ECON_EMISSION_REDUCTION", [0, 40], 0, "REGULATION", {"ENVIRONMENT": 1.2, "ECON_ROLE": 0.3}, {"ENVIRONMENT_QUALITY": 60, "JOBS": -15, "COST_OF_LIVING": -5}, R, 3, false],
		["ECON_HEALTH_FEE", [0, 100], 0, "LAW", {"REDISTRIBUTION": -0.5, "ECON_ROLE": -0.3}, {"PUBLIC_SERVICES": -30, "COST_OF_LIVING": -15, "GOVERNANCE": 15}, F, 1, false],
		["ECON_SCHOOL_FEE", [0, 200], 0, "LAW", {"REDISTRIBUTION": -0.25, "ECON_ROLE": -0.15}, {"PUBLIC_SERVICES": -25, "FAIRNESS": -15, "GOVERNANCE": 10}, F, 1, false],
		["ECON_BUDGET_ADMIN", [0, 4000], 1000, "LAW", {"FISCAL": 0.0077, "INSTITUTIONS": -0.0077}, {"GOVERNANCE": 15}, F, 1, false],
		["ECON_BUDGET_HEALTH", [0, 4000], 860, "LAW", {"REDISTRIBUTION": 0.023, "ECON_ROLE": 0.012, "FISCAL": 0.012}, {"PUBLIC_SERVICES": 60, "SAFETY": 5, "GOVERNANCE": -11}, F, 1, false],
		["ECON_BUDGET_EDUCATION", [0, 3000], 550, "LAW", {"REDISTRIBUTION": 0.036, "ECON_ROLE": 0.018, "FISCAL": 0.018}, {"PUBLIC_SERVICES": 40, "FAIRNESS": 20, "GOVERNANCE": -8}, F, 1, false],
		["ECON_BUDGET_TRAINING", [0, 2000], 0, "LAW", {"LABOR": 0.02, "ECON_ROLE": 0.02}, {"JOBS": 25, "FAIRNESS": 10, "GOVERNANCE": -5}, P, 1, false],
		# E114: the state's share of firms' training cost (paid from ECON_BUDGET_TRAINING); 100% doubles the training rate
		["ECON_TRAINING_SUBSIDY", [0, 100], 0, "LAW", {"LABOR": 0.01, "ECON_ROLE": 0.01, "FISCAL": 0.005}, {"JOBS": 15, "FAIRNESS": 5, "GOVERNANCE": -3}, P, 1, false],
		["ECON_BUDGET_INFRASTRUCTURE", [0, 15000], 3000, "LAW", {"FISCAL": 0.0056, "ECON_ROLE": 0.0028}, {"INFRASTRUCTURE": 50, "JOBS": 20, "GOVERNANCE": -40}, F, 0, false],
		["ECON_BUDGET_HOUSING", [0, 10000], 2100, "LAW", {"REDISTRIBUTION": 0.0125, "ECON_ROLE": 0.0125, "FISCAL": 0.006}, {"HOUSING": 60, "JOBS": 10, "GOVERNANCE": -27}, F, 0, false],
		["ECON_BUDGET_PUBLIC_WORKS", [0, 5000], 1500, "LAW", {"ECON_ROLE": 0.008, "FISCAL": 0.008}, {"JOBS": 35, "INFRASTRUCTURE": 15, "HOUSING": 10, "GOVERNANCE": -20}, "STAFF_T_IMPL_PROGRAM", 1, false],
		# E124b (range [0, 20000]) reverted 2026-11-13: at the max the AI held 20M/yr from Y20 and households went hungry
		# with spare food capacity (seed 1); the range returns with the slump rule's cap on posts (Wilma)
		["ECON_BUDGET_PUBLIC_EMPLOYMENT", [0, 5000], 0, "LAW", {"ECON_ROLE": 0.008, "FISCAL": 0.008, "LABOR": 0.006}, {"JOBS": 40, "FAIRNESS": 5, "GOVERNANCE": -20}, "STAFF_T_IMPL_PROGRAM", 1, false],
		# E117b: the Public Employment Service hires the unemployed at 80% of the General wage for upkeep work (EconPublicJobs)
		["ECON_PE_EXPANSION", [0, 1], 1, "REGULATION", {"ECON_ROLE": 10.0}, {"JOBS": 10, "INFRASTRUCTURE": 10, "GOVERNANCE": -5}, "STAFF_T_IMPL_ADMIN", 1, false],
		# E137 (Wilma): who expands the economy — 0 MARKET (private investors; public assets sold at 40%), 1 MIXED (private
		# first, the public operator after 2 quarters), 2 STATE (the public operator expands; nothing re-privatised)
		["ECON_PUBLIC_OWNERSHIP_POLICY", [0, 2], 1, "LAW", {"ECON_ROLE": 8.0}, {"JOBS": 8, "GOVERNANCE": -10}, R, 3, false],
		# part E (EconCare): elder care and childcare buy posts (4 G + 1 S / 3 G + 2 S); spent only while CARE is on.
		# Defaults ≈ 10 / 45 posts (whole units of 5; a post ≈ 15–17k credits a year): ~60–80% / ~50% coverage around
		# years 10–20, falling as the colony ages and grows unless parliament raises them.
		["ECON_BUDGET_ELDER_CARE", [0, 1500], 200, "LAW", {"REDISTRIBUTION": 0.02, "ECON_ROLE": 0.01, "FISCAL": 0.01}, {"PUBLIC_SERVICES": 40, "FAIRNESS": 10, "JOBS": 5, "GOVERNANCE": -8}, F, 1, false],
		["ECON_BUDGET_CHILDCARE", [0, 3000], 850, "LAW", {"REDISTRIBUTION": 0.012, "ECON_ROLE": 0.008, "FISCAL": 0.008}, {"PUBLIC_SERVICES": 30, "JOBS": 15, "COST_OF_LIVING": 10, "FAIRNESS": 10, "GOVERNANCE": -12}, F, 1, false],
		# §8c (Wilma): the state's subsidy to the bus fleet (parts and new buses, on top of the fares' fifth); spent only
		# while FLEET is on. Default ≈ a normal fleet's maintenance and renewal (~16 buses × ~9k credits a year).
		["ECON_BUDGET_PUBLIC_TRANSPORT", [0, 2000], 150, "LAW", {"ECON_ROLE": 0.01, "FISCAL": 0.01}, {"INFRASTRUCTURE": 30, "JOBS": 8, "GOVERNANCE": -6}, P, 1, false],
		# E160 / E162 (opt-in): grants for family farms and bakeries, % of build cost + start-up (+ the baking course)
		["ECON_FAMILY_FARM_GRANT", [0, 100], 0, "LAW", {"REDISTRIBUTION": 0.01, "ECON_ROLE": 0.01}, {"COST_OF_LIVING": 25, "JOBS": 15, "FAIRNESS": 15, "GOVERNANCE": -10}, P, 1, false],
		["ECON_FAMILY_BAKERY_GRANT", [0, 100], 0, "LAW", {"REDISTRIBUTION": 0.01, "ECON_ROLE": 0.01}, {"COST_OF_LIVING": 25, "JOBS": 15, "FAIRNESS": 15, "GOVERNANCE": -10}, P, 1, false],
		# R8 step 4 (Otto, opt-in R8_BUILDERS): 1 = a public builder bids at cost on public work (else the market margin rule)
		# (Anni: LAW, since at-cost bids by a dominant public builder are PRICE_BELOW_COST unless a law exempts them, E173)
		["ECON_PUBLIC_BUILDER_AT_COST", [0, 1], 0, "LAW", {"ECON_ROLE": 10.0}, {"INFRASTRUCTURE": 8, "JOBS": -4}, R, 1, false],
		["ECON_BUDGET_SUBSIDIES", [0, 3000], 0, "LAW", {"ECON_ROLE": 0.03, "FISCAL": 0.01}, {"JOBS": 25, "FAIRNESS": -5, "GOVERNANCE": -8}, P, 1, false],
		["ECON_BUDGET_RESERVE_PURCHASES", [0, 2000], 200, "LAW", {"ECON_ROLE": 0.01, "AUTONOMY": 0.01}, {"COST_OF_LIVING": 10, "GOVERNANCE": -5}, F, 1, false],
	]
	# E74 non-linear harm (pic-core v1.4). Same sign convention as `concerns` (effect of RAISING the lever, per full range),
	# applied only to the part of a change above `from` (concernsHigh) or below `from` (concernsLow, proposed v1.4b).
	var high := {
		"ECON_INCOME_TAX_RATE": {"from": 35, "concerns": {"JOBS": -60, "COST_OF_LIVING": -40}},
		"ECON_SALES_TAX": {"from": 15, "concerns": {"COST_OF_LIVING": -50, "JOBS": -30}},
		"ECON_PROFIT_TAX_RATE": {"from": 30, "concerns": {"JOBS": -60}},
		"ECON_IMPORT_TARIFF": {"from": 15, "concerns": {"COST_OF_LIVING": -50, "JOBS": -20}},
		"ECON_MIN_WAGE": {"from": 90, "concerns": {"JOBS": -60}},
		"ECON_UTILITY_TARIFF_ENERGY": {"from": 70, "concerns": {"COST_OF_LIVING": -40, "JOBS": -20}},
		"ECON_UTILITY_TARIFF_WATER": {"from": 35, "concerns": {"COST_OF_LIVING": -40}},
		"ECON_PUBLIC_RENT": {"from": 400, "concerns": {"HOUSING": -40, "COST_OF_LIVING": -20}},
		"ECON_HEALTH_FEE": {"from": 40, "concerns": {"PUBLIC_SERVICES": -40}},
		"ECON_SCHOOL_FEE": {"from": 80, "concerns": {"PUBLIC_SERVICES": -30, "FAIRNESS": -20}},
	}
	var low := {
		"ECON_PUBLIC_PAY_INDEX": {"from": 95, "concerns": {"PUBLIC_SERVICES": 50, "JOBS": 10}},
		"ECON_PENSION_RATE": {"from": 20, "concerns": {"COST_OF_LIVING": 50, "FAIRNESS": 20}},
		"ECON_UNEMPLOYMENT_BENEFIT_RATE": {"from": 25, "concerns": {"COST_OF_LIVING": 40, "JOBS": 25}},
		"ECON_BENEFIT_FLOOR": {"from": 30, "concerns": {"COST_OF_LIVING": 40, "JOBS": 15}},
		"ECON_FOOD_ASSISTANCE": {"from": 50, "concerns": {"COST_OF_LIVING": 40, "FAIRNESS": 15}},
		"ECON_RENT_INCREASE_CAP": {"from": 5, "concerns": {"HOUSING": 40}},
		"ECON_UTILITY_TARIFF_ENERGY": {"from": 25, "concerns": {"INFRASTRUCTURE": 40}},
		"ECON_UTILITY_TARIFF_WATER": {"from": 12, "concerns": {"INFRASTRUCTURE": 30}},
		"ECON_BUDGET_INFRASTRUCTURE": {"from": 1500, "concerns": {"INFRASTRUCTURE": 60, "JOBS": 30}},
		"ECON_BUDGET_HEALTH": {"from": 500, "concerns": {"PUBLIC_SERVICES": 50}},
		"ECON_BUDGET_EDUCATION": {"from": 350, "concerns": {"PUBLIC_SERVICES": 40}},
		"ECON_BUDGET_PUBLIC_TRANSPORT": {"from": 75, "concerns": {"INFRASTRUCTURE": 40, "JOBS": 15}},
		"ECON_PUBLIC_OWNERSHIP_POLICY": {"from": 1, "concerns": {"GOVERNANCE": -10, "FAIRNESS": 15}},
		"ECON_BUDGET_ELDER_CARE": {"from": 100, "concerns": {"PUBLIC_SERVICES": 50, "SAFETY": 10}},
		"ECON_BUDGET_CHILDCARE": {"from": 425, "concerns": {"PUBLIC_SERVICES": 40, "JOBS": 20}},
	}
	var out: Array = []
	for r in rows:
		var d := {"id": r[0], "owner": "econ", "type": "NUMBER", "range": r[1], "default": r[2], "legalLevel": r[3],
			"foundingEra": "COMMANDER", "ideology": r[4], "concerns": r[5], "implementation": r[6], "lag": r[7], "scope": "COLONY",
			"fiscal": "econ.est_" + r[0].to_lower(), "domain": "ECON"}
		if r[8]:
			d["is_tax"] = true
		if high.has(r[0]):
			d["concernsHigh"] = high[r[0]]
		if low.has(r[0]):
			d["concernsLow"] = low[r[0]]
		if r[0] == "ECON_FAMILY_FARM_GRANT":
			d["requires"] = ["E160"]  # opt-in feature levers: the legislature leaves them alone unless a flag is on
		elif r[0] == "ECON_FAMILY_BAKERY_GRANT":
			d["requires"] = ["E162"]
		elif r[0] == "ECON_PUBLIC_BUILDER_AT_COST":
			d["requires"] = ["R8_BUILDERS"]
		if r[0] in ["ECON_EMISSION_REDUCTION"]:
			d["domain"] = "ENV"
		if r[0] in ["ECON_BUDGET_HEALTH", "ECON_BUDGET_EDUCATION", "ECON_HEALTH_FEE", "ECON_SCHOOL_FEE", "ECON_BUDGET_ELDER_CARE", "ECON_BUDGET_CHILDCARE"]:
			d["domain"] = "PUBS"
		out.append(d)
	out.append({"id": "ECON_ENERGY_PRIORITY", "owner": "econ", "type": "ENUM", "values": ["HOUSEHOLDS_FIRST", "INDUSTRY_FIRST"],
		"default": "HOUSEHOLDS_FIRST", "legalLevel": "ADMIN", "foundingEra": "COMMANDER",
		"ideology": {"REDISTRIBUTION": -10.0, "ECON_ROLE": -3.0}, "concerns": {}, "implementation": "STAFF_T_IMPL_ADMIN", "lag": 0,
		"scope": "COLONY", "fiscal": null, "domain": "ECON"})
	return out


static func actions() -> Array:
	var ids := ["ECON_COMMISSION_PROJECT", "ECON_AWARD_CONTRACT", "ECON_RETENDER_PROJECT", "ECON_CANCEL_PROJECT", "ECON_TERMINATE_FOR_BREACH",
		"ECON_SET_BUDGET", "ECON_SUBSIDIZE", "ECON_RESCUE_LOAN", "ECON_BUY_FACILITY", "ECON_SELL_FACILITY", "ECON_ORDER_IMPORTS",
		"ECON_RELEASE_RESERVE", "ECON_UPGRADE_FACILITY", "ECON_OFFER_INCENTIVE", "ECON_ANSWER_UNION_DEMAND", "ECON_APPROVE_TARIFF", "ECON_BORROW", "ECON_BANK_BAILOUT", "ECON_REPAY_DEBT", "ECON_PUBLISH_FISCAL_REPORT", "ECON_REQUEST_ECON_BRIEFING"]
	var out: Array = []
	for id in ids:
		out.append({"id": id, "owner": "econ", "actors": ["PLAYER_GOV", "AI_GOV", "COMMANDER"], "spec": "planning/pic-economy.md §4"})
	return out

class_name EconData
extends RefCounted
## Economy v1 scenario and tuning data (planning/spec-economy-v1.md §2–4, §3 starting scenario).
## Display units here (credits, units, percent). Code converts to fixed point (×1000) on use.
## Values marked Knob in the spec are tuning values; change them here, never in code.

const SCALE := 1000

# ---------- commodities (spec §2.1) ----------
const MARKET_GOODS: Array[String] = ["FOOD", "MEDICAL", "MINERAL", "MATERIAL", "COMPONENT", "CONSUMER"]
const NETWORK_GOODS: Array[String] = ["ENERGY", "WATER"]
const SPOILAGE_PERMILLE := {"FOOD": 20, "MEDICAL": 5}          # per month (Knob)
const CARGO_MASS := {"FOOD": 1, "MEDICAL": 1, "MINERAL": 2, "MATERIAL": 2, "COMPONENT": 1, "CONSUMER": 1}

# ---------- month-1 prices, credits/unit (spec §3.3, E5) ----------
const BASE_PRICE := {"FOOD": 115, "MEDICAL": 250, "MINERAL": 120, "MATERIAL": 400, "COMPONENT": 1800, "CONSUMER": 115}
const BASE_SERVICES_PRICE := 30
const WAGE := {"G": 800, "S": 1200, "Sp": 1800}
const TIERS: Array[String] = ["Sp", "S", "G"]                  # matching order high -> low
const PRIVATE_RENT := 260
const IMPORT_MULT := 2.5                                       # origin price = 2.5 x base (Knob)

# ---------- tuning (Knob) ----------
const ALPHA := 0.15
const PRICE_MIN_MULT := 0.25
const PRICE_MAX_MULT := 4.0
const WAGE_NEUTRAL_U := 0.10
const HIRE_RATE := 0.40
const HIRE_MIN := 5
const LAYOFF_RATE := 0.30
const INPUT_LIMIT_MULT := 1.30
const DISC_PROPENSITY := 0.65
const EXCESS_SAVINGS_SPEND := 0.08
const SAVINGS_TARGET_MONTHS := 4
const DISC_CONSUMER_SHARE := 0.35
const DISC_SMOOTH_SHARE := 0.6
## E78: nominal wages are sticky downward (max −0.15%/month ≈ −1.8%/yr); with −0.5% the wage index fell 25–30% in
## slumps while prices rose, and the real-income collapse fed the demand spiral (O-1)
const WAGE_MAX_CUT_PM := 0.0015  # E70: share of habitual discretionary budget kept from savings
const MAX_DISC_CONSUMER_PC := 0.4
const FREIGHT_FLEET_CAP := 8000      # unit-links / month per depot
## E111: age-structured demography (the colony aged far too fast: retirees almost never died).
## Careers run from 18 to RETIREMENT_AGE (Anni may wrap it as LAW_RETIREMENT_AGE; read via EconHouseholds.retirement_age),
## retirees live LIFE_EXPECTANCY − RETIREMENT_AGE years on average (shorter with poor health access).
const RETIREMENT_AGE := 62
const LIFE_EXPECTANCY := 78
const BIRTH_RATE_ADULT := 0.0021      # births per working-age adult per month (≈ replacement plus slow growth)
const MORTALITY_CHILD := 0.0001       # per month
const MORTALITY_ADULT := 0.0001       # per month (working age)
const FAMINE_MORTALITY := {"RETIRED": 0.006, "CHILD": 0.003, "NOT_IN_LF": 0.002}  # extra per month in famine
const FOOD_BRAKE_SHORTFALL := 300     # ‰ food shortfall at which births and ship migrants are at their floor
const FOOD_BRAKE_FLOOR := 0.5         # soft: births/migrants never fall below this share from food alone
const SHIP_CARGO := 2000
const SHIP_MIGRANTS := 120
## M12 §4: home-world ships every SHIP_INTERVAL months (seeded, irregular). Migrants per ship: the immigration quota
## (persons per quarter) × interval / 3 × SHIP_QUOTA_SHARE, capped by SHIP_CAPACITY and by housing (as before).
const SHIP_INTERVAL := [18, 30]
const SHIP_QUOTA_SHARE := 0.5
const SHIP_CAPACITY := 300
const MIGRANT_FUNDS := 2000          # credits per adult migrant
const DEPRECIATION_MONTHS := 240
const LIQUIDATION_RESERVE := 0.60
## Strategic facilities: if unsold in liquidation, the government's public enterprise takes them over at 40% of book (E47).
## E65: origin import backstop (price signal instead of a hard bottleneck): see ORIGIN_BACKSTOP below.
## E67 class mapping & self-employment (Knob)
const COOP_FARM_OWNER_SHARE := 0.20     # share of non-specialist agricultural co-op members who are member-farmers (owners)
const SELF_EMP_ENTRY := 0.05            # monthly share of unemployed G/S adults with a savings cushion who go self-employed
const SELF_EMP_EXIT := 0.15             # monthly exit share when earnings fall below benefit level
const SELF_EMP_MAX_SHARE := 0.12        # cap: share of a group's labour force
const SELF_EMP_OUTPUT := 40
const SELF_EMP_FOUNDING := 0.05       # founding small traders/craftspeople: share of G/S labour force at landing (scenario data)             # SERVICES units per self-employed person per month (same as a hub worker)
const STRATEGIC_INPUT_TYPES := ["MINE", "PROCESSING"]
## E75: the origin backstop also covers COMPONENT (utility/facility upkeep must not hinge on one local factory).
## good -> [trigger × base (2 consecutive months), ask × base, cap units/month]
## O-1 recovery (E80, E82, E83)
const SURPLUS_BUFFER_MONTHS := 6       # firms keep 6 months of costs as working capital
const SURPLUS_BUFFER_MIN := 20000      # credits
const SURPLUS_SHARE := 0.5             # share of the excess paid out per quarter
const SOVEREIGN_RESTRUCTURE_AFTER := 12          # months in sovereign default before creditors restructure
const SOVEREIGN_HAIRCUT := 0.5         # share of government debt written off
const REPAIR_PER_MONTH := 250         # E84: milli-condition points restored per month with full upkeep (running)
const OVERHAUL_PER_MONTH := 2000       # E84: per month while a plant closed as unsafe is overhauled
const REOPEN_CONDITION := 50
const REPAIR_CREW_SHARE := 0.3        # E104: a plant closed as unsafe keeps 30% of its crew as a repair crew
const LABOUR_REPAIR_PER_MONTH := 2000  # E104: milli-condition a full repair crew restores per month without parts
const BLACKOUT_MONTHS := 3             # E101: months of total blackout before cannibalising dead power plants
const COLD_START_STEP := 10            # E101: condition points moved per month from donor plants           # E84: an overhauled plant reopens at this condition
const BUILDER_ENTRY_BACKLOG := 3       # E87: projects waiting without bids before a new builder is founded
const BUILDER_EQUITY := 30000          # E87: founder capital (credits)
const BUILDER_CREW := {"G": 20, "S": 8, "Sp": 1}
const DISC_CAP_BAND := {"I1": 1.0, "I2": 1.0, "I3": 1.5, "I4": 2.5, "I5": 4.0}  # E88: × MAX_DISC_CONSUMER_PC by income band
const FORCED_SALE_MONTHS := 6         # E91: months a closed plant may stay unrepaired before it must be sold
const ESSENTIAL_SPARE := 0.15         # E105: CPW keeps capacity ≥ demand × 1.15 in power, water, materials, components
const ESSENTIAL_GAP := 12             # E105: months between essential plants of one type
const NEW_PLANT_QUARTERS := 2         # E102: quarters of scarcity before an owner builds a new plant
const NEW_PLANT_GAP := 24              # E102: months between new plants of one type
const RENT_ARREARS_CUT := 0.10         # landlords cut rent 3%/quarter while arrears exceed 10% of rent due
## [trigger×base, ask×base, min qty, max qty]. E94 (scaling cargo) is ON HOLD (user, 2026-11-11: no home-world supply model);
## max = min keeps the old fixed cargo until the self-sufficiency spec replaces the backstop altogether.
const ORIGIN_BACKSTOP := {"MATERIAL": [2.0, 3.0, 200, 200], "COMPONENT": [2.0, 3.0, 40, 40]}
const STRATEGIC := ["POWER", "WATERWORKS", "MINE", "PROCESSING", "FARM", "DEPOT", "COMPONENTS", "MEDWORKS", "CONSUMERF"]
const GOV_FIRST_PURCHASE := 0.40
const RESTRUCTURE_HAIRCUT := 0.30
const ORIGIN_GRANT := 200000
const ORIGIN_GRANT_MONTHS := 48
const ORIGIN_GRANT_TAPER_END := 120  # E58: linear taper months 48→120 (charter)
const BANK_GOV_RATE_PM := 0.005
const BANK_GOV_LIMIT := 1.5          # x trailing-12m revenue
const BANK_FIRM_BASE_PM := 0.006
const BANK_MIN_CASH := 1000000
const TRAINING_COST := 4000

# ---------- per-capita needs, units / person / month (spec §3.4) ----------
const NEED := {"FOOD": 1.0, "WATER": 1.0, "ENERGY": 0.5, "CONSUMER_MIN": 0.1}
const HOUSEHOLD_SIZE := 2.5

# ---------- recipes (spec §4.1) ----------
# labor {tier: n}, inputs {good: qty}, out [product, qty], upkeep MAT, pollution pts, accident base per-mille/yr,
# hazard class, licence, occupation of its workers, energy/water needs come via inputs.
const RECIPES := {
	"POWER":    {"labor": {"G": 10, "S": 10, "Sp": 2}, "in": {}, "out": ["ENERGY", 1200], "upkeep": 12, "poll": 2, "acc": 3, "hazard": "HIGH", "licence": "LICENCE_HAZARD", "occ": "MANUFACTURING"},
	"WATERWORKS": {"labor": {"G": 8, "S": 6}, "in": {"ENERGY": 80}, "out": ["WATER", 1500], "upkeep": 3, "poll": 0, "acc": 2, "hazard": "LOW", "licence": "", "occ": "MANUFACTURING"},
	"FARM":     {"labor": {"G": 28, "S": 2}, "in": {"WATER": 40, "ENERGY": 10}, "out": ["FOOD", 280], "upkeep": 1, "poll": 1, "acc": 3, "hazard": "LOW", "licence": "", "occ": "AGRICULTURE"},
	"MINE":     {"labor": {"G": 14, "S": 7}, "in": {"ENERGY": 50}, "out": ["MINERAL", 300], "upkeep": 3, "poll": 6, "acc": 8, "hazard": "MEDIUM", "licence": "LICENCE_EXTRACTION", "occ": "MINING"},
	"PROCESSING": {"labor": {"G": 12, "S": 12}, "in": {"MINERAL": 300, "ENERGY": 80}, "out": ["MATERIAL", 220], "upkeep": 4, "poll": 8, "acc": 5, "hazard": "HIGH", "licence": "LICENCE_HAZARD", "occ": "MANUFACTURING"},
	"COMPONENTS": {"labor": {"G": 6, "S": 12, "Sp": 3}, "in": {"MATERIAL": 50, "ENERGY": 50}, "out": ["COMPONENT", 45], "upkeep": 3, "poll": 4, "acc": 3, "hazard": "MEDIUM", "licence": "", "occ": "MANUFACTURING"},
	"CONSUMERF": {"labor": {"G": 35, "S": 12}, "in": {"MATERIAL": 75, "ENERGY": 60}, "out": ["CONSUMER", 850], "upkeep": 2, "poll": 3, "acc": 3, "hazard": "LOW", "licence": "", "occ": "MANUFACTURING"},
	"MEDWORKS": {"labor": {"S": 5, "Sp": 5}, "in": {"COMPONENT": 4, "ENERGY": 20, "WATER": 10}, "out": ["MEDICAL", 120], "upkeep": 2, "poll": 1, "acc": 2, "hazard": "MEDIUM", "licence": "", "occ": "MANUFACTURING"},
	"SERVICEHUB": {"labor": {"G": 25, "S": 5}, "in": {"ENERGY": 30, "CONSUMER": 10}, "out": ["SERVICES", 1200], "upkeep": 1, "poll": 0, "acc": 1, "hazard": "LOW", "licence": "", "occ": "SERVICES"},
	"CLINIC":   {"labor": {"G": 5, "S": 10, "Sp": 15}, "in": {"MEDICAL": 100, "ENERGY": 40, "WATER": 30}, "out": ["HEALTH", 2500], "upkeep": 2, "poll": 0, "acc": 1, "hazard": "LOW", "licence": "", "occ": "PUBLIC_SECTOR"},
	"SCHOOL":   {"labor": {"G": 4, "S": 16, "Sp": 10}, "in": {"ENERGY": 30, "WATER": 20, "CONSUMER": 15}, "out": ["EDUCATION", 450], "upkeep": 2, "poll": 0, "acc": 1, "hazard": "LOW", "licence": "", "occ": "PUBLIC_SECTOR"},
	"DEPOT":    {"labor": {"G": 20, "S": 5}, "in": {"ENERGY": 120}, "out": ["FREIGHT", 8000], "upkeep": 5, "poll": 2, "acc": 4, "hazard": "MEDIUM", "licence": "", "occ": "LOGISTICS"},
	"ADMIN":    {"labor": {"G": 20, "S": 30, "Sp": 30}, "in": {"ENERGY": 40, "CONSUMER": 10}, "out": ["ADMIN", 1], "upkeep": 0, "poll": 0, "acc": 1, "hazard": "LOW", "licence": "", "occ": "PUBLIC_SECTOR"},
	"PUBJOBS":  {"labor": {"G": 4, "S": 1}, "in": {}, "out": ["PUBWORK", 0], "upkeep": 0, "poll": 0, "acc": 1, "hazard": "LOW", "licence": "", "occ": "PUBLIC_SECTOR"},  # E117b public employment scheme: upkeep work, no output
	"HOUSING":  {"labor": {"G": 1}, "in": {}, "out": ["HOUSING", 50], "upkeep": 2, "poll": 0, "acc": 1, "hazard": "LOW", "licence": "", "occ": "SERVICES"},
}
const CONTRACTOR_ACC := 6
## Soft inputs: a shortage costs up to 10% efficiency instead of stopping output (E46).
const SOFT_INPUTS := {"SERVICEHUB": ["CONSUMER"], "SCHOOL": ["CONSUMER"], "ADMIN": ["CONSUMER"]}
## Equipment wear: COMPONENT upkeep per month at full operation (spec §4.3 upkeep, E46).
const UPKEEP_COMPONENT := {"POWER": 2, "WATERWORKS": 1, "MINE": 1, "PROCESSING": 2, "CONSUMERF": 1, "DEPOT": 1, "COMPONENTS": 1, "FARM": 0}

# ---------- build bills: [WU, MATERIAL, COMPONENT, min months] (spec §4.4) ----------
const BUILD := {
	"HOUSING": [1200, 700, 20, 6], "FARM": [250, 250, 10, 3], "WATERWORKS": [500, 500, 60, 6],
	"POWER": [800, 800, 150, 8], "MINE": [600, 400, 80, 6], "PROCESSING": [700, 700, 100, 8],
	"COMPONENTS": [700, 600, 120, 8], "CONSUMERF": [500, 500, 60, 6], "MEDWORKS": [400, 300, 80, 6],
	"SERVICEHUB": [200, 200, 10, 3], "CLINIC": [450, 400, 30, 6], "SCHOOL": [450, 450, 15, 6],
	"DEPOT": [300, 250, 40, 4], "ROAD": [300, 300, 10, 4],
}
const WU_COST_EST := 1050           # credits per WU, used for book values / estimates

# ---------- map (D5 v1, A11) ----------
const DISTRICTS := {
	"d:1": {"name": "Landing", "pop": 900, "hh": 360},
	"d:2": {"name": "Riverside", "pop": 400, "hh": 160},
	"d:3": {"name": "Redrock", "pop": 250, "hh": 100},
	"d:4": {"name": "Foundry", "pop": 300, "hh": 120},
	"d:5": {"name": "Greenhill", "pop": 150, "hh": 60},
	"d:6": {"name": "Northfield", "pop": 0, "hh": 0},
}
const LINKS := [["d:1", "d:2", 3000, 90], ["d:1", "d:4", 3000, 90], ["d:4", "d:3", 2000, 80], ["d:2", "d:5", 1500, 85], ["d:1", "d:5", 1500, 85]]

# ---------- population (spec §3.2) ----------
const LABOR_FORCE := {"G": 680, "S": 290, "Sp": 92}
const WORKING_AGE := 1400
const CHILDREN := 480
const RETIRED := 120
const SAVINGS_PC := {"G": 500, "S": 900, "Sp": 2000}
const OWNER_SAVINGS := 20000

# ---------- organizations (spec §3.6) ----------
# key: [name, type, cash, loan, mgmt, risk, age, reliability, crew {G,S,Sp} | {}, inventory {good: qty}, hq]
const ORGS := {
	"CPW": ["Colony Power & Water", "PUBLIC_ENTERPRISE", 300000, 0, 64, 25, 51, 0, {}, {}, "d:4"],
	"CTA": ["Colony Transit Authority", "PUBLIC_ENTERPRISE", 100000, 0, 55, 30, 47, 0, {}, {}, "d:1"],
	"CHO": ["Colony Housing Office", "PUBLIC_ENTERPRISE", 200000, 0, 50, 20, 56, 0, {}, {}, "d:1"],
	"MERIDIAN": ["Meridian Agricultural Co-op", "COOPERATIVE", 400000, 0, 62, 30, 44, 0, {}, {}, "d:2"],
	"GREENFOLD": ["Greenfold Farms Ltd", "PRIVATE", 240000, 300000, 55, 50, 39, 0, {}, {}, "d:5"],
	"REDROCK": ["Redrock Mining Co.", "PRIVATE", 190000, 300000, 58, 60, 45, 0, {}, {}, "d:3"],
	"BASALT": ["Basalt Processing Ltd", "PRIVATE", 450000, 500000, 66, 45, 52, 0, {}, {}, "d:4"],
	"VECTOR": ["Vector Components Ltd", "PRIVATE", 500000, 500000, 72, 50, 41, 0, {}, {}, "d:4"],
	"HEARTH": ["Hearth Goods Co.", "PRIVATE", 220000, 0, 50, 55, 36, 0, {}, {}, "d:4"],
	"COMMONS": ["Commons Services Ltd", "PRIVATE", 260000, 0, 57, 45, 43, 0, {}, {}, "d:1"],
	"LMC": ["Landing Market Co-op", "COOPERATIVE", 90000, 0, 53, 25, 49, 0, {}, {}, "d:2"],
	"FRONTIER": ["Frontier Homes Ltd", "PRIVATE", 150000, 2000000, 60, 55, 50, 0, {}, {}, "d:1"],
	"ATLAS": ["Atlas Construction", "PRIVATE", 600000, 0, 78, 35, 58, 85, {"G": 60, "S": 30, "Sp": 10}, {"MATERIAL": 120, "COMPONENT": 4}, "d:1"],
	"PIONEER": ["Pioneer Builders", "PRIVATE", 150000, 400000, 52, 80, 40, 60, {"G": 55, "S": 20, "Sp": 5}, {"MATERIAL": 160, "COMPONENT": 20}, "d:4"],
	# E76: public contractor of last resort — bids only on public re-tenders (or when no private builder is alive), at cost
	"CWD": ["Colony Works Department", "PUBLIC_ENTERPRISE", 150000, 0, 55, 20, 50, 60, {"G": 30, "S": 10, "Sp": 2}, {"MATERIAL": 40, "COMPONENT": 2}, "d:1"],
	"WBC": ["Workers' Building Co-op", "COOPERATIVE", 200000, 0, 60, 30, 46, 70, {"G": 45, "S": 15}, {"MATERIAL": 60, "COMPONENT": 2}, "d:2"],
	"HEALTH": ["Colony Health Service", "PUBLIC_INSTITUTION", 0, 0, 61, 20, 53, 0, {}, {}, "d:1"],
	"SCHOOLS": ["Colony School", "PUBLIC_INSTITUTION", 0, 0, 58, 20, 48, 0, {}, {}, "d:1"],
	"ADMINISTRATION": ["Colony Administration", "PUBLIC_INSTITUTION", 0, 0, 60, 20, 50, 0, {}, {}, "d:1"],
}

# [facility type, org key, district, count]
const FACILITIES := [
	["POWER", "CPW", "d:4", 2], ["WATERWORKS", "CPW", "d:2", 2], ["DEPOT", "CTA", "d:1", 1],
	["HOUSING", "CHO", "d:1", 5], ["HOUSING", "CHO", "d:2", 2], ["HOUSING", "CHO", "d:3", 2], ["HOUSING", "CHO", "d:4", 1],
	["HOUSING", "FRONTIER", "d:1", 3], ["HOUSING", "FRONTIER", "d:2", 2], ["HOUSING", "FRONTIER", "d:4", 1], ["HOUSING", "FRONTIER", "d:5", 1],
	["FARM", "MERIDIAN", "d:2", 5], ["FARM", "GREENFOLD", "d:5", 3], ["MINE", "REDROCK", "d:3", 2],
	["PROCESSING", "BASALT", "d:4", 2], ["COMPONENTS", "VECTOR", "d:4", 1], ["MEDWORKS", "VECTOR", "d:4", 1],
	["CONSUMERF", "HEARTH", "d:4", 1], ["SERVICEHUB", "COMMONS", "d:1", 2], ["SERVICEHUB", "COMMONS", "d:4", 1],
	["SERVICEHUB", "LMC", "d:2", 1], ["CLINIC", "HEALTH", "d:1", 1], ["SCHOOL", "SCHOOLS", "d:1", 1], ["ADMIN", "ADMINISTRATION", "d:1", 1],
]

## Founding construction programme, awarded at landing (charter-funded): [type, district, contractor key]
const FOUNDING_PROJECTS := [["HOUSING", "d:4", "ATLAS"], ["HOUSING", "d:5", "WBC"], ["CLINIC", "d:4", "PIONEER"]]

const GOV_RESERVE := {"FOOD": 4000, "MEDICAL": 300, "MATERIAL": 1000, "COMPONENT": 100}
const TREASURY := 15000000
const BANK_CASH := 12000000

## M12 §1–§2 (user decision A34): the home world does not support the colony. No grant, no food aid, no import
## backstop, imports and migrants only by ship. Instead a one-off FOUNDING ENDOWMENT. world.meta["support"] = true
## restores the old support model (A/B and old tests only).
const HOME_SUPPORT := false
const ENDOW_TREASURY := 6000000        # extra treasury at landing (~30 months of the old grant; the old support was ~16.8M)
const ENDOW_RESERVE := {"FOOD": 13000, "MEDICAL": 600, "MATERIAL": 3000, "COMPONENT": 400}  # ~6 months of food
const RESERVE_AUTO_RELEASE := ["MATERIAL", "COMPONENT"]  # E98: strategic reserve sells into a scarce market
const ENDOW_SPARES_MONTHS := 36        # each operator lands with 3 years of upkeep parts (MATERIAL, COMPONENT)
## extra founding capacity so materials, components, power and water balance locally without imports
const ENDOW_FACILITIES := [["POWER", "CPW", "d:4", 1], ["WATERWORKS", "CPW", "d:2", 1]]
## E106 (user decision A38): the colony lands with FABRICATION KITS — a crude smelter (MATERIAL from MINERAL) and a
## crude component workshop, run by the public utility. Kits have tiers Mk I..III; an upgrade is a local project that
## consumes the previous tier's materials and components. Each tier raises output per worker and cuts input waste.
const ENDOW_KITS := [["PROCESSING", "CPW", "d:4", 1], ["COMPONENTS", "CPW", "d:4", 1]]  # founded at tier 1
const KIT_TYPES := ["PROCESSING", "COMPONENTS"]
const TIER_OUT := [0.0, 0.6, 1.0, 1.4]   # output multiplier by tier (index = tier); founding firms' plants are tier 2
const TIER_IN := [0.0, 1.4, 1.0, 0.8]    # input use per unit of activity by tier (waste)
const UPGRADE_BUILD := {2: [1500, 120, 15, 8], 3: [2500, 200, 40, 10]}  # to tier: [work units, material, components, min months]

# Institution -> budget lever that funds it
const INSTITUTION_BUDGET := {"HEALTH": "ECON_BUDGET_HEALTH", "SCHOOLS": "ECON_BUDGET_EDUCATION", "ADMINISTRATION": "ECON_BUDGET_ADMIN"}

# Occupation of employer types (spec §7.2)
const PUBLIC_TYPES := ["PUBLIC_ENTERPRISE", "PUBLIC_INSTITUTION"]

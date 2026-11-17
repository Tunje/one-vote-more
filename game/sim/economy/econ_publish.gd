extends PicProvider
## What the economy publishes for politics, rebuild step 2 (planning/rebuild-politics-face.md; Ella).
##
## Step 2 brings the government's purse paying its own staff, the benefit and pensions (rebuild-company.md 13, step 2).
## From this step politics can read, under the old names (9.11: "the same names where the thing still exists"):
##   levers      ECON_UNEMPLOYMENT_BENEFIT_RATE, ECON_PENSION_RATE: per cent of the area's starting salary (12.5, 41).
##               The purse reads them when it pays. They are in the lever table, so the legislature can vote them.
##   indicators  ECON_TREASURY_RUNWAY (months the treasury lasts at the last twelve months' spending),
##               ECON_BUDGET_BALANCE and ECON_OPERATING_BALANCE (the last twelve months' income less spending, in per
##               cent of spending). Until step 8 the state builds nothing (no capital spending), so the two balances
##               are the same figure.
##
## The voters read the stand-in's indicators until step 11 (rebuild-politics-face.md 1.2). So these indicators carry
## no concern weights, and no fiscal stress or fiscal guard for the legislature, until step 11 removes the stand-in and
## gives them their weights. Code that reads them by name (gov_builder, legislature) reads the real figures now.
##
## Every number comes from the ledger: what was paid into and out of the government's purse this month. The purse is
## every account whose id begins with "gov:" (the treasury CoreUtil.TREASURY, the law's fines account
## "gov:fines_revenue", and any other the government keeps apart so it can be seen apart). A payment between two of them
## counts neither way; the treasury figure is what they hold together. This provider keeps the last twelve months'
## totals in its own table "econ_pub", so a loaded game publishes the same figures.
## Capital is not income: money the purse is given to start with (the landing treasury, memo LANDING_TREASURY) is in the
## treasury, so the runway counts it, but not in the balance's income, or the balance would read +100% for a year
## whatever the purse does. The home world's development grant (12.11, 90) is income and is not in CAPITAL_MEMOS.

const OWNER := "econ_pub"
const Company := preload("res://sim/economy/company.gd")
const PURSE := "gov:"   # the prefix of every government account
## Payments into the purse that are capital, not income: the landing treasury, the colony's land sold (LandLaw.sell),
## the landing stock sold by Colony Stores (the sale of an asset; Wilma, step 3).
const CAPITAL_MEMOS := ["LANDING_TREASURY", "LAND_SALE", "LANDING_STOCK_SALE"]
const KEEP_M := 12
const RUNWAY_MAX_M := 240   # the indicator's range: a treasury that spends nothing lasts "240 months or more"
const STEP2_LEVERS := ["ECON_UNEMPLOYMENT_BENEFIT_RATE", "ECON_PENSION_RATE"]
const STEP3_LEVERS := ["ECON_YEARLY_RAISE_MIN_PCT", "ECON_FAMILY_FARM_GRANT", "ECON_FAMILY_BAKERY_GRANT",
	"ECON_TRUCK_DRIVER_GRANT", "ECON_TRUCK_WORKSHOP_GRANT"]
const GRANT_START_PCT := 50   # START: a grant's share of what a founder must bring, open from month one (9.12)
const STEP2_INDICATORS := ["ECON_TREASURY_RUNWAY", "ECON_BUDGET_BALANCE", "ECON_OPERATING_BALANCE"]


func owner_id() -> String:
	return OWNER


func phases() -> Array:
	return [TickPhase.SOCIAL]


## The levers. Their ideology and concern hints are politics' own figures (how parties read the lever), carried from the
## old table; their range and starting value are ours to set with the other numbers (rebuild-company.md 1).
func lever_defs() -> Array:
	return [
		_lever("ECON_UNEMPLOYMENT_BENEFIT_RATE", [0, 80], 40, {"REDISTRIBUTION": 0.6, "LABOR": 0.3, "FISCAL": 0.2},
			{"COST_OF_LIVING": 30, "FAIRNESS": 20, "GOVERNANCE": -15}),
		_lever("ECON_PENSION_RATE", [0, 100], 35, {"REDISTRIBUTION": 0.4, "FISCAL": 0.2},
			{"COST_OF_LIVING": 25, "GOVERNANCE": -20}),
		# step 3. The yearly raise every employed person gets at least (9.2: "they have a sallery set on hire then it
		# climbs based on yearly upps set by goverment"; "2% is a good start"). Households.yearly_raise_month reads it.
		_lever("ECON_YEARLY_RAISE_MIN_PCT", [0, 20], 2, {"LABOR": 0.4, "REDISTRIBUTION": 0.2, "ECON_ROLE": 0.1},
			{"COST_OF_LIVING": 20, "FAIRNESS": 15, "JOBS": -10}),
		# step 3. The four grants (9.5, 9.12: all open from month one), each a time-limited programme (12.9, 61a;
		# sim/economy/grants.gd). Per cent of what a founder must bring.
		_lever("ECON_FAMILY_FARM_GRANT", [0, 100], GRANT_START_PCT, {"REDISTRIBUTION": 0.01, "ECON_ROLE": 0.01},
			{"COST_OF_LIVING": 25, "JOBS": 15, "FAIRNESS": 15, "GOVERNANCE": -10}),
		_lever("ECON_FAMILY_BAKERY_GRANT", [0, 100], GRANT_START_PCT, {"REDISTRIBUTION": 0.01, "ECON_ROLE": 0.01},
			{"COST_OF_LIVING": 25, "JOBS": 15, "FAIRNESS": 15, "GOVERNANCE": -10}),
		_lever("ECON_TRUCK_DRIVER_GRANT", [0, 100], GRANT_START_PCT, {"REDISTRIBUTION": 0.01, "ECON_ROLE": 0.01},
			{"JOBS": 15, "INFRASTRUCTURE": 15, "FAIRNESS": 10, "GOVERNANCE": -10}),
		_lever("ECON_TRUCK_WORKSHOP_GRANT", [0, 100], GRANT_START_PCT, {"REDISTRIBUTION": 0.01, "ECON_ROLE": 0.01},
			{"JOBS": 15, "INFRASTRUCTURE": 15, "FAIRNESS": 10, "GOVERNANCE": -10}),
	]


## What a grant lever means, for the legislature's and the voters' screens: it lapses (12.9, 61a; Anni's review).
const GRANT_NOTE := "A grant programme: per cent of what a founder must bring. Each programme is open for 24 months, then the lever returns to 0 by law and a new programme needs a new decision."


func _lever(id: String, rng: Array, def: int, ideo: Dictionary, concerns: Dictionary) -> Dictionary:
	# owner "econ", not this provider's id: the law names a lever's facts after its owner (ECON_LEVER_EFFECTIVE), and the
	# press and gazette know that name; an indicator's owner is the provider that writes it
	return {"id": id, "owner": "econ", "type": "NUMBER", "range": rng, "default": def, "legalLevel": "LAW",
		"foundingEra": "COMMANDER", "ideology": ideo, "concerns": concerns, "implementation": "STAFF_T_IMPL_PROGRAM",
		"lag": 1, "scope": "COLONY", "fiscal": null, "domain": "ECON",
		"description": GRANT_NOTE if id in STEP3_LEVERS and id != "ECON_YEARLY_RAISE_MIN_PCT" else ""}


func indicator_defs() -> Array:
	return [
		_ind("ECON_TREASURY_RUNWAY", "months", [0, RUNWAY_MAX_M], 24, 3, "OFFICIAL"),
		_ind("ECON_BUDGET_BALANCE", "%", [-500, 100], 5, -40, "PUBLIC"),
		_ind("ECON_OPERATING_BALANCE", "%", [-500, 100], 5, -40, "OFFICIAL"),
	]


## Values are milli of the unit. concerns {} until step 11 (see the head of this file).
func _ind(id: String, unit: String, rng: Array, good: float, bad: float, vis: String) -> Dictionary:
	return {"id": id, "owner": OWNER, "unit": unit, "range": [int(rng[0]) * 1000, int(rng[1]) * 1000],
		"granularity": "COLONY", "polarity": 1, "concerns": {}, "normalize": {"good": int(good * 1000), "bad": int(bad * 1000)},
		"phase": TickPhase.SOCIAL, "visibility": vis, "perceptionLag": 0, "history": true}


func init_world(world: WorldState) -> void:
	world.table(OWNER)["months"] = []


## The reference wage (12.11, 108): the average pay over every company's staff, colony-wide (Company.reference_wage),
## a month in milli-credits, as world value ECON_W_REF. The law's fines, the press's costs and the legislature read it.
## Not written while nobody is paid (the readers keep their own fallback), so it never reads 0.
static func publish_w_ref(world: WorldState) -> void:
	var w := Company.reference_wage(world)
	if w > 0:
		world.values["ECON_W_REF"] = w


func run_phase(_phase: int, world: WorldState) -> void:
	publish_w_ref(world)
	var flows := month_flows(world, PURSE, world.month)
	var t := world.table(OWNER)
	var ring: Array = t.get("months", [])
	ring.append({"m": world.month, "in": int(flows["in"]), "out": int(flows["out"])})
	while ring.size() > KEEP_M:
		ring.pop_front()
	t["months"] = ring
	var f := figures(world)
	world.set_indicator(OWNER, "ECON_TREASURY_RUNWAY", "COLONY", int(f["runway_milli"]))
	world.set_indicator(OWNER, "ECON_BUDGET_BALANCE", "COLONY", int(f["balance_milli"]))
	world.set_indicator(OWNER, "ECON_OPERATING_BALANCE", "COLONY", int(f["balance_milli"]))


## What went into and out of a group of accounts (every id beginning with `prefix`) in a month, from the ledger's
## journal. Every transfer in the game is booked with world.month, so the journal is in month order and the newest
## entries are at the end: it reads backwards and stops at the first entry of an earlier month. A transfer inside the
## group counts neither way. A payment in under one of CAPITAL_MEMOS is capital, counted apart and not as income.
static func month_flows(world: WorldState, prefix: String, month: int) -> Dictionary:
	var j: Array = world.ledger.journal
	var inn := 0
	var out := 0
	var capital := 0
	var i := j.size() - 1
	while i >= 0:
		var e: Dictionary = j[i]
		if int(e["m"]) < month:
			break
		if int(e["m"]) == month:
			var to_in := String(e["to"]).begins_with(prefix)
			var from_in := String(e["from"]).begins_with(prefix)
			if to_in and not from_in:
				if String(e.get("memo", "")) in CAPITAL_MEMOS:
					capital += int(e["amt"])
				else:
					inn += int(e["amt"])
			elif from_in and not to_in:
				out += int(e["amt"])
		i -= 1
	return {"in": inn, "out": out, "capital": capital}


## The purse's figures over the months kept (up to twelve): treasury (mcr), income and spending per month (mcr),
## runway (months, milli), balance (per cent of spending, milli). With no spending the runway is RUNWAY_MAX_M and the
## balance is the top of its range if anything came in, else 0.
static func figures(world: WorldState) -> Dictionary:
	var ring: Array = world.peek(OWNER).get("months", [])
	var inn := 0
	var out := 0
	for r in ring:
		inn += int(r["in"])
		out += int(r["out"])
	var n := maxi(1, ring.size())
	var treasury := purse_balance(world)
	var runway := RUNWAY_MAX_M * 1000
	if out > 0:
		runway = clampi(int(round(float(treasury) * 1000.0 * float(n) / float(out))), 0, RUNWAY_MAX_M * 1000)
	var bal := 0
	if out > 0:
		bal = clampi(int(round(float(inn - out) * 100000.0 / float(out))), -500000, 100000)
	elif inn > 0:
		bal = 100000
	return {"treasury": treasury, "in_pm": inn / n, "out_pm": out / n, "months": ring.size(), "runway_milli": runway,
		"balance_milli": bal}


## What the government's accounts hold together (mcr). 0 until the purse opens them (step 2, Wilma).
static func purse_balance(world: WorldState) -> int:
	var n := 0
	for k in CoreUtil.sorted_keys(world.ledger.balances):
		if String(k).begins_with(PURSE):
			n += world.ledger.balance(String(k))
	return n

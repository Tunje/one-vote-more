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

const OWNER := "econ_pub"
const PURSE := "gov:"   # the prefix of every government account
const KEEP_M := 12
const RUNWAY_MAX_M := 240   # the indicator's range: a treasury that spends nothing lasts "240 months or more"
const STEP2_LEVERS := ["ECON_UNEMPLOYMENT_BENEFIT_RATE", "ECON_PENSION_RATE"]
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
	]


func _lever(id: String, rng: Array, def: int, ideo: Dictionary, concerns: Dictionary) -> Dictionary:
	return {"id": id, "owner": OWNER, "type": "NUMBER", "range": rng, "default": def, "legalLevel": "LAW",
		"foundingEra": "COMMANDER", "ideology": ideo, "concerns": concerns, "implementation": "STAFF_T_IMPL_PROGRAM",
		"lag": 1, "scope": "COLONY", "fiscal": null, "domain": "ECON"}


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


func run_phase(_phase: int, world: WorldState) -> void:
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
## group counts neither way.
static func month_flows(world: WorldState, prefix: String, month: int) -> Dictionary:
	var j: Array = world.ledger.journal
	var inn := 0
	var out := 0
	var i := j.size() - 1
	while i >= 0:
		var e: Dictionary = j[i]
		if int(e["m"]) < month:
			break
		if int(e["m"]) == month:
			var to_in := String(e["to"]).begins_with(prefix)
			var from_in := String(e["from"]).begins_with(prefix)
			if to_in and not from_in:
				inn += int(e["amt"])
			elif from_in and not to_in:
				out += int(e["amt"])
		i -= 1
	return {"in": inn, "out": out}


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

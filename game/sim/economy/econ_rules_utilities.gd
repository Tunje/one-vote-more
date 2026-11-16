class_name EconRulesUtil
extends RefCounted
## R8 utilities (planning/eight-rules.md; the user's order of 2026-11-16 "every producer all eight rules"; Anni): the
## public utility CPW (POWER, WATERWORKS) on its own market. OPT-IN: R8 + R8_UTILITIES (EconRules.sector_on). Off →
## nothing here runs and the base is unchanged.
##
## The utility's market, measured monthly at the start of TRADE from the month before (EconProduction's grid):
##   per grid ("E" power, "W" water): dem (metered demand, mu), sup (what the plants delivered), cap (effective capacity:
##   Σ out × scale × condition/management of the open plants), unserved = dem − sup, billed units (served less the
##   water works' own power, which nobody pays for), the bill (billed × tariff), and the cost of running the grid's
##   plants (crews at the going wage, upkeep material and components at market prices, depreciation; water also pays
##   for its own power at power's unit cost). Kept 12 months in st["r8u"]["hist"][grid].
##
## Rules (quarterly unless said):
##   1/2 TARIFF (replaces E150's P&L step for CPW under the switch). Rise when the bill does not cover the grid's cost
##     (12-month result < 0, or the tariff is below the cost per billed unit in the last quarter): to that cost per unit,
##     at least +1. Rise by step_up when the bill covers it but demand went unserved at full use in the last quarter.
##     Cut by step_down when it covers the cost and use stayed below idle_pm all quarter, never below the cost per unit.
##     Within the levers' legal ranges (EconPublicCo.TARIFFS). A rise is a proposal the government decides
##     (st["pe_proposals"], the E150P shape, EconPublicCo.approve) when E150P is on; without E150P it applies at once
##     (the stand-in for "a government that always approves", as E150 does). A cut applies at once.
##   3/4 OUTPUT (monthly, FirmAI._set_target): the plants run to the metered demand: T = demand × out_margin ÷ effective
##     capacity of the grid's open plants, 0..1 (no 30% floor).
##   5 ADD CAPACITY: full (demand ≥ full_pm of effective capacity) in full_m of the last 12 months, or demand unserved
##     at full use in the last quarter, or the forecast (demand a year on, at the last 12 months' trend) above the
##     effective capacity with what is being built → reopen a mothballed plant, else a +25% extension of the smallest
##     plant (EXPAND), else a new plant where the grid's first plant stands. One project at a time per grid. Cash, else
##     a loan; with neither, nothing is built (noted as "unfunded"). Replaces the essentials planner (E105), FirmAI's
##     new plants (E102) and the caretaker autopilot for these two types.
##   6 REDUCE: wind down, then mothball, the smallest open plant when, for idle_m months, the other open plants could carry the demand
##     (demand × out_margin ≤ their capacity), nothing went unserved, and the forecast would not fill them (else rule 5
##     reopens it within the year); never the last open plant of a grid. Winding down: the others plan for the whole
##     demand and hire for it, the plant makes only what they did not; at the next review it is mothballed if the others
##     delivered the whole demand, kept if anything went unserved or rule 5 wants capacity.
##   7/8 A NEW UTILITY COMPANY, private or a second public one (the user, 2026-11-16): founded when the forecast leaves
##     demand unserved that the incumbents do not clear and a plant would make a profit at today's tariff; none while the
##     incumbents have spare capacity or serve all demand, or lose money. Who founds it follows the ownership policy
##     (founder_order). The condition is checked every quarter for as long as the game runs. See _entry.
## PRIVATE PLANTS (Wilma's yes, 2026-11-16): CPW is the single grid buyer and the tariff stays the customers' price. A
##   private plant sells everything the grid takes to CPW at its own price; the grid takes the cheapest units first (CPW's
##   own plants at their running cost per unit), and a unit needed to avoid unserved demand is always bought (_buy,
##   _dispatch). What CPW pays is part of its grid cost, so its tariff rule sees it. The private plant's own rules 1-6:
##   _private. CPW's rules 5/6 act on CPW's own plants only.
## Step sizes and thresholds below are Anni's (labelled "yours" in the order); none is a cap or floor beyond the levers'
## legal ranges.

const S := EconUtil.S
const GRIDS := {"E": "POWER", "W": "WATERWORKS"}
const TARIFF_LEVER := {"E": ["ECON_UTILITY_TARIFF_ENERGY", 40], "W": ["ECON_UTILITY_TARIFF_WATER", 20]}
const WW_POWER := 80  # the water works' power per unit of recipe (EconData.RECIPES["WATERWORKS"]["in"]["ENERGY"])
# --- Anni's numbers: EconRules.SECTORS["UTILITIES"]["params"] (read with _p) ---
##   out_margin 1.08: rule 3/4, run to 8% above the metered demand (the existing E66 figure: crews short, power late)
##   step_up 0.05 / step_down 0.03: rule 1 scarcity step, rule 2 idle step (the E150 steps)
##   full_pm 950: ‰ of effective capacity that makes a full month; full_m 6: full months in 12 that call for capacity
##   idle_pm 700: ‰ below which all quarter a tariff cut may be due; idle_m 12: months the rest could carry the demand
##   before a plant is mothballed
const EXPAND_SCALE := 250  # ‰ of a plant per extension (EconConstruction.create_expansion)
const MAX_SCALE := 3000  # an extension stops at 3× (the freight and E54 figure)
const MIN_HIST := 3
const RAMP_M := 3  # months a reopened or new plant hires as if alone (Anni's)


static func _p(k: String) -> float:
	return float(EconRules.SECTORS["UTILITIES"]["params"][k])


static func on(world: WorldState) -> bool:
	return EconRules.sector_on(world, "UTILITIES")


## True when the utilities' rule 5 decides for this plant type (the planners skip it).
static func capacity_on(world: WorldState, ftype: String) -> bool:
	return ftype in GRIDS.values() and on(world)


static func _grid_of(ftype: String) -> String:
	return "E" if ftype == "POWER" else ("W" if ftype == "WATERWORKS" else "")


## Effective capacity of a grid's open plants (mu a month); without_winding leaves out a plant being wound down.
static func eff_cap(world: WorldState, ftype: String, skip: String = "", without_winding: bool = false) -> float:
	var cap := 0.0
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] == ftype and not f["mothball"] and fid != skip and not (without_winding and (f.has("r8u_wind") or f.has("r8u_ramp"))):
			cap += _plant_cap(world, f)
	return cap


## What the grid's other open plants delivered last month (mu), the plant being wound down left out.
## (A plant ramping up after a reopening or a build is counted: what it delivers, the wound plant need not.)
static func _others_out(world: WorldState, ftype: String) -> int:
	var t := 0
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] == ftype and not f["mothball"] and not f.has("r8u_wind"):
			t += int(f.get("out_last", 0))
	return t


static func _plant_cap(world: WorldState, f: Dictionary) -> float:
	return float(EconData.RECIPES[f["type"]]["out"][1]) * S * EconUtil.fscale(f) * EconProduction._eff(world, f)


## Rules 3/4: the plant's planned use (0..1) — the grid's metered demand over its effective capacity. While a plant is
## wound down (rule 6) the others plan for the whole demand, and it makes only what they did not deliver last month. A
## plant reopened or newly built ramps up for RAMP_M months: it hires for the whole demand as if alone, and the others
## keep planning without it, so no customer goes unserved while its crew is found.
static func target(world: WorldState, f: Dictionary) -> float:
	var ftype := String(f["type"])
	var g := _grid_of(ftype)
	var cap := eff_cap(world, ftype, "", true)
	var s := EconUtil.peek_st(world)
	var need := _p("out_margin") * float(s.get("util_demand", {}).get(g, eff_cap(world, ftype)))
	if f.has("r8u_wind"):
		return clampf((need - float(_others_out(world, ftype))) / maxf(1.0, _plant_cap(world, f)), 0.0, 1.0)
	if f.has("r8u_ramp"):
		return clampf(need / maxf(1.0, _plant_cap(world, f)), 0.0, 1.0)  # hires as if alone for its first quarter
	if cap <= 0.0:
		return 0.0
	return float(_dispatch(world, ftype, need).get(String(f["id"]), 0.0))


## The price a plant's units are bought at (credits per unit): CPW's own plants at the grid's running cost per unit,
## a private plant at its own price.
static func price_of(world: WorldState, f: Dictionary) -> float:
	var g := _grid_of(String(f["type"]))
	if String(f["org"]) == EconFinance.org_by_key(world, "CPW"):
		return float(EconUtil.peek_st(world).get("r8u", {}).get("cpw_unit", {}).get(g, 0.0))
	var o: Dictionary = world.table("org").get(f["org"], {})
	return float(f.get("r8u_price", o.get("r8u_price", EconUtil.lever(world, TARIFF_LEVER[g][0], TARIFF_LEVER[g][1]))))


## Merit order: the open plants (not wound down, not ramping) by price, CPW first on a tie; each price group runs to
## the need left, shared in proportion to capacity. {fid: planned use 0..1}.
static func _dispatch(world: WorldState, ftype: String, need: float) -> Dictionary:
	var cpw := EconFinance.org_by_key(world, "CPW")
	var groups := {}
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] != ftype or f["mothball"] or f.has("r8u_wind") or f.has("r8u_ramp"):
			continue
		var k := "%012.3f|%d" % [price_of(world, f), 0 if String(f["org"]) == cpw else 1]
		if not groups.has(k):
			groups[k] = []
		groups[k].append(fid)
	var out := {}
	var left := need
	for k in EconUtil.sorted_keys(groups):
		var gcap := 0.0
		for fid in groups[k]:
			gcap += _plant_cap(world, world.table("facility")[fid])
		var t := clampf(left / maxf(1.0, gcap), 0.0, 1.0)
		for fid in groups[k]:
			out[fid] = t
		left = maxf(0.0, left - gcap)
	return out


# ------------------------------------------------------------------ monthly (EconRules.monthly, TRADE)

static func monthly(world: WorldState) -> void:
	if not on(world):
		return
	var s := EconUtil.st(world)
	if not s.has("util_demand"):
		return
	var u: Dictionary = s.get("r8u", {"hist": {}, "acts": [], "entry": {}})
	var e_unit := 0
	var cpw0 := EconFinance.org_by_key(world, "CPW")
	if not u.has("cpw_unit"):
		u["cpw_unit"] = {}
	for g in ["E", "W"]:
		var bought := _buy(world, cpw0, g)
		var row := _measure(world, g, e_unit, cpw0)
		row["bought"] = bought
		row["cost"] = int(row["cost"]) + bought
		if int(row["own_out"]) > 0:
			u["cpw_unit"][g] = float(int(row["cost"]) - bought) / float(int(row["own_out"]))  # credits per unit of its own plants
		if g == "E":
			e_unit = (int(row["cost"]) - bought) * S / maxi(S, int(row["own_out"]))
		var h: Array = u["hist"].get(g, [])
		h.append(row)
		while h.size() > 12:
			h.pop_front()
		u["hist"][g] = h
	_ramps(world, u)
	s["r8u"] = u
	if world.month % 3 != 0:
		return
	var cpw := EconFinance.org_by_key(world, "CPW")
	if cpw == "" or not world.table("org").has(cpw) or world.table("org")[cpw]["status"] in ["LIQUIDATION", "DISSOLVED"]:
		return
	_tariffs(world, cpw, u)
	for g in ["E", "W"]:
		var acted := _capacity(world, cpw, g, u)
		if not acted:
			_reduce(world, cpw, g, u)
		_private(world, cpw, g, u)
		_entry(world, cpw, g, u)


## Plants new to the grid (built since the rules started) ramp up; a ramp ends after RAMP_M months.
static func _ramps(world: WorldState, u: Dictionary) -> void:
	var first: bool = not u.has("seen")
	var seen: Dictionary = u.get("seen", {})
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if not (f["type"] in GRIDS.values()):
			continue
		if not seen.has(fid):
			seen[fid] = world.month
			if not first and not f["mothball"]:
				f["r8u_ramp"] = world.month
		if f.has("r8u_ramp") and (f["mothball"] or world.month - int(f["r8u_ramp"]) >= RAMP_M):
			f.erase("r8u_ramp")
	u["seen"] = seen


## A plant's running cost this month (mcr): its crew at the going wage, upkeep (a quarter while closed), depreciation,
## and for a private water works its power bill.
static func _plant_cost(world: WorldState, f: Dictionary) -> float:
	var s := EconUtil.st(world)
	var ftype := String(f["type"])
	var r: Dictionary = EconData.RECIPES[ftype]
	var cost := 0.0
	for t in f.get("staff", {}):
		cost += float(EconLabor.tier_total(f["staff"], t)) / float(S) * float(s["wage"].get(t, 0))
	var share := 0.25 if f["mothball"] else 1.0  # EconProduction._upkeep: a closed plant keeps a quarter
	cost += share * EconUtil.fscale(f) * (float(r["upkeep"]) * float(s["prices"]["MATERIAL"]) \
		+ float(EconData.UPKEEP_COMPONENT.get(ftype, 0)) * float(s["prices"].get("COMPONENT", 0)))
	cost += _plant_depr(f)
	if ftype == "WATERWORKS" and String(f["org"]) != EconFinance.org_by_key(world, "CPW"):
		cost += float(_ww_power(f)) * float(EconUtil.lever(world, "ECON_UTILITY_TARIFF_ENERGY", 40))
	return cost


## Depreciation part of _plant_cost (mcr a month).
static func _plant_depr(f: Dictionary) -> float:
	var ftype := String(f["type"])
	return float(EconConstruction.estimate(ftype)) * EconUtil.fscale(f) / float(EconData.DEPRECIATION_MONTHS) if EconData.BUILD.has(ftype) else 0.0


## The power a water works drew last month (mu).
static func _ww_power(f: Dictionary) -> int:
	if f["mothball"]:
		return 0
	return int(float(WW_POWER) * S * float(f.get("util", 0)) / 1000.0 * EconUtil.fscale(f) * float(f.get("e_served", 1000)) / 1000.0)


## A plant's cost per unit at full use (credits): a full crew, upkeep, depreciation, power for water at the tariff.
static func full_unit(world: WorldState, f: Dictionary) -> float:
	var s := EconUtil.st(world)
	var ftype := String(f["type"])
	var r: Dictionary = EconData.RECIPES[ftype]
	var cost := 0.0
	for t in r["labor"]:
		cost += float(r["labor"][t]) * EconUtil.fscale(f) * float(s["wage"].get(t, 0))
	cost += EconUtil.fscale(f) * (float(r["upkeep"]) * float(s["prices"]["MATERIAL"]) + float(EconData.UPKEEP_COMPONENT.get(ftype, 0)) * float(s["prices"].get("COMPONENT", 0)))
	cost += _plant_depr(f)
	if ftype == "WATERWORKS":
		cost += float(WW_POWER) * float(S) * EconUtil.fscale(f) * float(EconUtil.lever(world, "ECON_UTILITY_TARIFF_ENERGY", 40))
	return cost / maxf(1.0, _plant_cap(world, f))


## The grid buys from private plants (Wilma's yes, 2026-11-16: CPW the single buyer, cheapest units first, a unit needed
## to avoid unserved demand always bought): last month's served demand is taken from the plants in price order (CPW
## first on a tie); each private plant is paid its price per unit taken, plus what CPW still owed it. Returns what the
## grid owes for the month (mcr), CPW's cost.
static func _buy(world: WorldState, cpw: String, g: String) -> int:
	var s := EconUtil.st(world)
	var ftype: String = GRIDS[g]
	var left := mini(int(s.get("util_demand", {}).get(g, 0)), int(s.get("util_supply", {}).get(g, 0)))
	var rows: Array = []
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] == ftype and (not f["mothball"] or int(f.get("out_last", 0)) > 0):
			rows.append([price_of(world, f), 0 if String(f["org"]) == cpw else 1, fid])
	rows.sort_custom(func(a, b): return float(a[0]) < float(b[0]) or (float(a[0]) == float(b[0]) and (int(a[1]) < int(b[1]) or (int(a[1]) == int(b[1]) and str(a[2]) < str(b[2])))))
	var due_all := 0
	for row in rows:
		var f: Dictionary = world.table("facility")[row[2]]
		var out := int(f.get("out_last", 0))
		var take := mini(out, left)
		left -= take
		if String(f["org"]) == cpw:
			continue
		var due := EconUtil.val(take, int(round(float(row[0]) * S)))
		due_all += due
		var owed := int(f.get("r8u_owed", 0)) + due
		var paid := 0
		if owed > 0 and cpw != "":
			paid = EconUtil.pay_upto(world, EconUtil.acct(cpw), EconUtil.acct(String(f["org"])), owed, "UTILITY_PURCHASE")
			EconFinance.pl_add(world, cpw, "cogs", paid)
			EconFinance.pl_add(world, String(f["org"]), "rev", paid)
		f["r8u_owed"] = owed - paid
		var pp: Array = f.get("r8u_pp", [])
		pp.append([world.month, out, take, due, int(_plant_cost(world, f)), int(_plant_depr(f))])
		while pp.size() > 12:
			pp.pop_front()
		f["r8u_pp"] = pp
	return due_all


## One month of one grid: {m, dem, sup, cap, unserved, served, billed, bill, cost, own_out} (mu, mcr). Cost and own_out
## are CPW's own plants; the caller adds what the grid bought.
static func _measure(world: WorldState, g: String, e_unit: int, cpw: String = "") -> Dictionary:
	var s := EconUtil.st(world)
	var ftype: String = GRIDS[g]
	var dem := int(s.get("util_demand", {}).get(g, 0))
	var sup := int(s.get("util_supply", {}).get(g, 0))
	var served := mini(dem, sup)
	var self_use := 0  # CPW's own water works draw power nobody bills
	var cost := 0.0
	var own_out := 0
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if cpw != "" and String(f["org"]) != cpw:
			continue
		if g == "E" and f["type"] == "WATERWORKS":
			self_use += _ww_power(f)
		if f["type"] != ftype:
			continue
		cost += _plant_cost(world, f)
		own_out += int(f.get("out_last", 0))
		if g == "W":
			cost += float(_ww_power(f)) * float(e_unit) / float(S)
	var billed := maxi(0, served - self_use)
	var tariff := int(EconUtil.lever(world, TARIFF_LEVER[g][0], TARIFF_LEVER[g][1]))
	return {"m": world.month, "dem": dem, "sup": sup, "cap": int(eff_cap(world, ftype)), "unserved": maxi(0, dem - sup),
		"served": served, "billed": billed, "bill": EconUtil.val(billed, tariff * S), "cost": int(cost), "own_out": own_out}


static func _full(row: Dictionary) -> bool:
	return int(row["dem"]) * 1000 >= _p("full_pm") * maxi(1, int(row["cap"]))


static func _last(h: Array, n: int) -> Array:
	return h.slice(maxi(0, h.size() - n))


# ------------------------------------------------------------------ rules 1/2: the tariff

static func _tariffs(world: WorldState, cpw: String, u: Dictionary) -> void:
	var o: Dictionary = world.table("org")[cpw]
	var changed_up: Array = []
	var changed_down: Array = []
	var why := {}
	for g in ["E", "W"]:
		var h: Array = u["hist"].get(g, [])
		if h.size() < MIN_HIST:
			continue
		var bill12 := 0
		var cost12 := 0
		for row in h:
			bill12 += int(row["bill"])
			cost12 += int(row["cost"])
		var q := _last(h, 3)
		var qcost := 0
		var qbilled := 0
		var short_full := false
		var idle := true
		for row in q:
			qcost += int(row["cost"])
			qbilled += int(row["billed"])
			if int(row["unserved"]) > 0 and _full(row):
				short_full = true
			if int(row["dem"]) * 1000 >= _p("idle_pm") * maxi(1, int(row["cap"])) or int(row["unserved"]) > 0:
				idle = false
		var lv: String = TARIFF_LEVER[g][0]
		var rng := _range(lv)
		var old := int(EconUtil.lever(world, lv, TARIFF_LEVER[g][1]))
		var unit := int(ceil(float(qcost) / float(maxi(S, qbilled))))  # credits per unit at current use (mcr × S / mu ÷ S)
		var covered := bill12 >= cost12 and old >= unit
		var nv := old
		if not covered:
			nv = maxi(old + 1, unit)
			why[g] = "cost"
		elif short_full:
			nv = maxi(old + 1, int(round(float(old) * (1.0 + _p("step_up")))))
			why[g] = "unserved"
		elif idle:
			nv = maxi(unit, mini(old - 1, int(round(float(old) * (1.0 - _p("step_down"))))))
			why[g] = "idle"
		nv = clampi(nv, rng[0], rng[1])
		if nv > old:
			changed_up.append([lv, old, nv])
		elif nv < old:
			changed_down.append([lv, old, nv])
	u["tariff"] = {"month": world.month, "why": why}
	var pend: Dictionary = EconUtil.st(world).get("pe_proposals", {})
	if not changed_down.is_empty():
		for c in changed_down:
			world.levers[c[0]] = int(c[2])
		EconFacts.emit(world, "ECON_TARIFF_CHANGE", o["hq"], [["COMPANY", cpw]], [["COMPANY", cpw, 0.6], ["GOVERNMENT", "government", 0.4]],
			{"COST_OF_LIVING": 4}, 20, "PUBLIC", {"org": cpw, "up": false, "levers": changed_down, "rule": "R8U", "why": why})
		u["acts"].append([world.month, "tariff_cut"])
	if changed_up.is_empty():
		if pend.has(cpw) and changed_down.size() > 0:
			pend.erase(cpw)  # a cut supersedes an open rise
		return
	var gap := 0
	for g in ["E", "W"]:
		var h: Array = u["hist"].get(g, [])
		for row in h:
			gap += int(row["cost"]) - int(row["bill"])
	gap = maxi(0, gap)
	if EconPublicCo.proposals(world):
		var sub_room := maxi(0, EconActions.headroom(world, "ECON_BUDGET_SUBSIDIES"))
		pend[cpw] = {"month": world.month, "levers": changed_up, "gap12": gap / S, "subsidy_needed": maxi(0, gap - sub_room) / S}
		EconUtil.st(world)["pe_proposals"] = pend
		EconFacts.emit(world, "ECON_PE_FUNDING_REQUEST", o["hq"], [["COMPANY", cpw]], [["GOVERNMENT", "government", 1.0]], {}, 30, "OFFICIAL",
			{"org": cpw, "amount": 0, "asked": gap / S, "proposed": changed_up, "subsidy_needed": maxi(0, gap - sub_room) / S, "rule": "R8U", "why": why})
		u["acts"].append([world.month, "tariff_proposed"])
		return
	for c in changed_up:
		world.levers[c[0]] = int(c[2])
	EconFacts.emit(world, "ECON_TARIFF_CHANGE", o["hq"], [["COMPANY", cpw]], [["COMPANY", cpw, 0.6], ["GOVERNMENT", "government", 0.4]],
		{"COST_OF_LIVING": -6}, 20, "PUBLIC", {"org": cpw, "up": true, "levers": changed_up, "rule": "R8U", "why": why})
	u["acts"].append([world.month, "tariff_rise"])


static func _range(lv: String) -> Array:
	for row in EconPublicCo.TARIFFS["CPW"]:
		if row[0] == lv:
			return [int(row[1]), int(row[2])]
	return [0, 1000000]


# ------------------------------------------------------------------ rule 5: add capacity

## Demand a year on at the trend of the history (first to last month), mu.
static func forecast(h: Array) -> int:
	if h.size() < MIN_HIST:
		return 0
	var first := int(h[0]["dem"])
	var last := int(h[h.size() - 1]["dem"])
	return maxi(0, last + (last - first) * 12 / maxi(1, h.size() - 1))


static func _pending(world: WorldState, ftype: String) -> bool:
	for pid in world.table("project"):
		var p: Dictionary = world.table("project")[pid]
		if not (p["status"] in ["TENDER", "TENDERABLE", "ACTIVE"]):
			continue
		if p["type"] == ftype:
			return true
		if p["type"] in ["EXPAND", "UPGRADE"] and world.table("facility").has(p.get("target", "")) and world.table("facility")[p["target"]]["type"] == ftype:
			return true
	return false


## Why rule 5 wants capacity for grid g ("" when it does not): "full", "unserved" or "forecast".
static func capacity_signal(world: WorldState, g: String, u: Dictionary) -> String:
	var h: Array = u.get("hist", {}).get(g, [])
	if h.size() < MIN_HIST:
		return ""
	var full := 0
	for row in h:
		if _full(row):
			full += 1
	if full >= _p("full_m"):
		return "full"
	for row in _last(h, 3):
		if int(row["unserved"]) > 0 and _full(row):
			return "unserved"
	if forecast(h) * 1000 >= _p("full_pm") * maxi(1, int(h[h.size() - 1]["cap"])):
		return "forecast"
	return ""


static func _capacity(world: WorldState, cpw: String, g: String, u: Dictionary) -> bool:
	var ftype: String = GRIDS[g]
	var why := capacity_signal(world, g, u)
	if why == "" or _pending(world, ftype):
		return false
	var plants: Array = []
	var shut: Array = []
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] != ftype or String(f["org"]) != cpw:
			continue
		if not f["mothball"]:
			plants.append(fid)
		elif not f.get("closed_unsafe", false) and not f.get("law_closed", false) and not f.get("abandoned", false):
			shut.append(fid)
	for fid in plants:
		if world.table("facility")[fid].has("r8u_wind"):
			world.table("facility")[fid].erase("r8u_wind")  # rule 6 undone: the plant being wound down is kept
			u["acts"].append([world.month, g + "_keep", why])
			return true
	if not shut.is_empty():  # the cheapest capacity: a plant standing idle
		var re: Dictionary = world.table("facility")[shut[0]]
		re["mothball"] = false
		re["low_util_m"] = 0
		re["r8u_ramp"] = world.month
		EconFacts.emit(world, "ECON_FACILITY_REOPENED", re["district"], [["COMPANY", re["org"]]], [["COMPANY", re["org"], 1.0]],
			{"JOBS": 10}, 30, "PUBLIC", {"facility": re["id"], "reason": "r8u_" + why})
		u["acts"].append([world.month, g + "_reopen", why])
		return true
	var smallest := ""
	for fid in plants:
		var sc := int(world.table("facility")[fid].get("scale", 1000))
		if sc < MAX_SCALE and (smallest == "" or sc < int(world.table("facility")[smallest].get("scale", 1000))):
			smallest = fid
	var est := EconConstruction.estimate(ftype) * EXPAND_SCALE / 1000 if smallest != "" else EconConstruction.estimate(ftype)
	var home := ""
	for fid in EconUtil.sorted_keys(world.table("facility")):
		if world.table("facility")[fid]["type"] == ftype and String(world.table("facility")[fid]["org"]) == cpw:
			home = String(world.table("facility")[fid]["district"])
			break
	if home == "":
		home = "d:4" if ftype == "POWER" else "d:2"
	if smallest == "" and not LawBridge.allowed(world, cpw, "BUILD_FACILITY", {"facility_type": ftype, "district": home, "owner_kind": "COMPANY",
			"value_wref": est / maxi(1, int(world.values.get("ECON_W_REF", 1200 * S)))}):
		u["acts"].append([world.month, g + "_not_allowed"])
		return false
	var cash := world.ledger.balance(EconUtil.acct(cpw))
	if cash < est and not EconFinance.new_loan(world, cpw, est - cash, 0, true):
		u["acts"].append([world.month, g + "_unfunded"])
		u["unfunded_" + g] = world.month
		return false
	var pid := ""
	if smallest != "":
		pid = EconConstruction.create_expansion(world, smallest, cpw)
		u["acts"].append([world.month, g + "_expand", why])
	else:
		pid = EconConstruction.create(world, ftype, home, cpw, cpw, "")
		u["acts"].append([world.month, g + "_new", why])
	EconFacts.emit(world, "COMP_INVESTMENT", home, [["COMPANY", cpw]], [["COMPANY", cpw, 0.5], ["GOVERNMENT", "government", 0.5]],
		{"JOBS": 3, "INFRASTRUCTURE": 5}, 25, "PUBLIC", {"type": ftype, "project": pid, "reason": "r8u_" + why})
	return true


# ------------------------------------------------------------------ rule 6: reduce

static func _reduce(world: WorldState, cpw: String, g: String, u: Dictionary) -> void:
	var ftype: String = GRIDS[g]
	var h: Array = u["hist"].get(g, [])
	var open: Array = []
	var winding := ""
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] == ftype and not f["mothball"] and String(f["org"]) == cpw:
			open.append(fid)
			if f.has("r8u_wind"):
				winding = fid
	if winding != "":
		# step 2: closed once the others delivered the whole demand last month
		var wf: Dictionary = world.table("facility")[winding]
		if h.is_empty() or int(h[h.size() - 1]["unserved"]) > 0:
			wf.erase("r8u_wind")
			u["acts"].append([world.month, g + "_wind_cancelled"])
		elif _others_out(world, ftype) >= int(h[h.size() - 1]["dem"]):
			_mothball(world, wf)
			u["acts"].append([world.month, g + "_mothball"])
		return
	if h.size() < int(_p("idle_m")) or open.size() < 2:
		return
	var smallest := ""
	for fid in open:
		if smallest == "" or _plant_cap(world, world.table("facility")[fid]) < _plant_cap(world, world.table("facility")[smallest]):
			smallest = fid
	var rest := eff_cap(world, ftype, smallest)
	for row in _last(h, int(_p("idle_m"))):
		if int(row["unserved"]) > 0 or float(row["dem"]) * _p("out_margin") > rest:
			return
	if float(forecast(h)) * 1000.0 >= _p("full_pm") * rest:
		return  # rule 5 would want it back within the year
	# step 1: wind it down: the others take its load (and hire for it) before it closes
	world.table("facility")[smallest]["r8u_wind"] = world.month
	u["acts"].append([world.month, g + "_wind_down"])


static func _mothball(world: WorldState, f: Dictionary) -> void:
	var jobs := 0
	var req := EconLabor.required(f)
	for t in req:
		jobs += int(req[t])
	f.erase("r8u_wind")
	f["mothball"] = true
	EconFacts.emit(world, "ECON_FACILITY_MOTHBALLED", f["district"], [["COMPANY", f["org"]]],
		EconFacts.company_blame(world, f["org"], 0.7), {"JOBS": -10}, 35, "PUBLIC", {"facility": f["id"],
		"type": f["type"], "jobs": jobs / S, "reason": "r8u_idle"}, {"districts": [f["district"]]})


# ------------------------------------------------------------------ private plants: their own rules 1-6

## Each private power or water works, quarterly, on its own sales to the grid (r8u_pp: [month, out, taken, due, cost,
## depreciation] for 12 months):
##   1 raise: to its cost per unit at full use when its price is below it (at least +1); +step_up when all it made was
##     taken and demand went unserved at full use last quarter.
##   2 lower: −step_down (at least −1) when it was taken for less than idle_pm of its capacity last quarter, never below
##     its cost per unit at full use.
##   3/4: output by the merit order (target): what the grid needs from it at its price.
##   5 add: a +25% extension when it was taken at full_pm of capacity in full_m of 12 months and its price covers its
##     cost; its own cash, else a loan; one project at a time.
##   6 reduce: mothballed when 12 months of sales did not cover its running cost (crew and upkeep, depreciation aside);
##     reopened (and ramped) when demand went unserved at full use last quarter.
static func _private(world: WorldState, cpw: String, g: String, u: Dictionary) -> void:
	var ftype: String = GRIDS[g]
	var gh: Array = u["hist"].get(g, [])
	var short_full := false
	for row in _last(gh, 3):
		if int(row["unserved"]) > 0 and _full(row):
			short_full = true
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] != ftype or String(f["org"]) == cpw:
			continue
		var o: Dictionary = world.table("org").get(f["org"], {})
		if o.is_empty() or not (o["status"] in ["ACTIVE", "DISTRESSED"]):
			continue
		if f["mothball"]:
			if short_full and not f.get("closed_unsafe", false) and not f.get("law_closed", false) and not f.get("abandoned", false):
				f["mothball"] = false
				f["r8u_ramp"] = world.month
				EconFacts.emit(world, "ECON_FACILITY_REOPENED", f["district"], [["COMPANY", f["org"]]], [["COMPANY", f["org"], 1.0]],
					{"JOBS": 10}, 30, "PUBLIC", {"facility": fid, "reason": "r8u_private_unserved"})
				u["acts"].append([world.month, g + "_private_reopen", fid])
			continue
		var pp: Array = f.get("r8u_pp", [])
		if pp.size() < MIN_HIST:
			continue
		var cap := _plant_cap(world, f)
		var unit := full_unit(world, f)
		var price := price_of(world, f)
		var q := _last(pp, 3)
		var all_taken := true
		var taken_q := 0
		for row in q:
			taken_q += int(row[2])
			if int(row[1]) <= 0 or int(row[2]) * 1000 < 950 * int(row[1]):
				all_taken = false
		var np := price
		if price < unit:
			np = maxf(price + 1.0, ceilf(unit))
		elif all_taken and short_full:
			np = maxf(price + 1.0, roundf(price * (1.0 + _p("step_up"))))
		elif float(taken_q) * 1000.0 < _p("idle_pm") * cap * float(q.size()):
			np = maxf(ceilf(unit), minf(price - 1.0, roundf(price * (1.0 - _p("step_down")))))
		if np != price:
			f["r8u_price"] = np
			u["acts"].append([world.month, g + "_private_price", fid, price, np])
		# rule 5
		var full_m := 0
		for row in pp:
			if float(int(row[2])) * 1000.0 >= _p("full_pm") * cap:
				full_m += 1
		if full_m >= int(_p("full_m")) and np >= unit and int(f.get("scale", 1000)) < MAX_SCALE and not EconConstruction.upgrade_pending(world, fid) \
				and not _expand_pending(world, fid):
			var est := EconConstruction.estimate(ftype) * EXPAND_SCALE / 1000
			var cash := world.ledger.balance(EconUtil.acct(String(f["org"])))
			if cash >= est or EconFinance.new_loan(world, String(f["org"]), est - cash, 0, true):
				var pid := EconConstruction.create_expansion(world, fid, String(f["org"]))
				EconFacts.emit(world, "COMP_INVESTMENT", f["district"], [["COMPANY", f["org"]]], [["COMPANY", f["org"], 1.0]],
					{"JOBS": 3, "INFRASTRUCTURE": 5}, 25, "PUBLIC", {"type": ftype, "project": pid, "reason": "r8u_private_full"})
				u["acts"].append([world.month, g + "_private_expand", fid])
			continue
		# rule 6
		if pp.size() >= int(_p("idle_m")):
			var rev := 0
			var run := 0
			for row in pp:
				rev += int(row[3])
				run += int(row[4]) - int(row[5])
			if rev < run:
				_mothball(world, f)
				u["acts"].append([world.month, g + "_private_mothball", fid])


static func _expand_pending(world: WorldState, fid: String) -> bool:
	for pid in world.table("project"):
		var p: Dictionary = world.table("project")[pid]
		if p["type"] == "EXPAND" and p.get("target", "") == fid and p["status"] in ["TENDER", "TENDERABLE", "ACTIVE"]:
			return true
	return false


# ------------------------------------------------------------------ rules 7/8: a private utility company

## Capacity being built for a grid (mu a month): a new plant at its recipe size, an extension at a quarter of its plant.
static func _pending_cap(world: WorldState, ftype: String) -> float:
	var t := 0.0
	for pid in EconUtil.sorted_keys(world.table("project")):
		var p: Dictionary = world.table("project")[pid]
		if not (p["status"] in ["TENDER", "TENDERABLE", "ACTIVE"]):
			continue
		if p["type"] == ftype:
			t += float(EconData.RECIPES[ftype]["out"][1]) * S
		elif p["type"] == "EXPAND" and world.table("facility").has(p.get("target", "")) and world.table("facility")[p["target"]]["type"] == ftype:
			t += float(EconData.RECIPES[ftype]["out"][1]) * S * float(EXPAND_SCALE) / 1000.0
	return t


## A new private plant's first year (mcr): volume (mu a month, up to one plant), revenue at today's tariff (the price it
## can expect: what customers pay), a full crew, upkeep, power for water at the tariff, and loan service on the build
## (EconForecast's loan share, term and rate).
static func forecast_profit(world: WorldState, ftype: String, volume: float) -> Dictionary:
	var s := EconUtil.st(world)
	var g := _grid_of(ftype)
	var r: Dictionary = EconData.RECIPES[ftype]
	var vol := clampf(volume, 0.0, float(r["out"][1]) * S)
	var tariff := float(EconUtil.lever(world, TARIFF_LEVER[g][0], TARIFF_LEVER[g][1]))
	var revenue := vol * tariff * 12.0  # mu × credits a unit = mcr
	var crew := 0.0
	for t in r["labor"]:
		crew += float(r["labor"][t]) * float(s["wage"].get(t, 0))
	var upkeep := float(r["upkeep"]) * float(s["prices"]["MATERIAL"]) + float(EconData.UPKEEP_COMPONENT.get(ftype, 0)) * float(s["prices"].get("COMPONENT", 0))
	var power := 0.0
	if ftype == "WATERWORKS":
		power = vol / float(r["out"][1]) * float(WW_POWER) * float(EconUtil.lever(world, "ECON_UTILITY_TARIFF_ENERGY", 40))
	var loan := float(EconConstruction.estimate(ftype)) * EconForecast.LOAN_SHARE
	var service := loan / float(EconForecast.LOAN_TERM_M) + loan * EconData.BANK_FIRM_BASE_PM
	var costs := (crew + upkeep + power + service) * 12.0
	return {"volume": int(vol), "revenue": int(revenue), "costs": int(costs), "profit": int(revenue - costs)}


## Rules 7/8, a private or a second public company (the user's rulings of 2026-11-16 via Wilma: every company type can be founded private; "maybe there is
## only ever enough work for one power plant, then the conditions for new ones don't get switched on"). Quarterly, per
## grid:
##   7: a private power or water company is founded when the forecast (demand a year on) leaves demand unserved that the
##      incumbents do not clear (their capacity plus what is being built) and a plant serving it would make a profit at
##      today's tariff.
##   8: none while the incumbents have spare capacity (last month not full) or serve all demand (nothing unserved last
##      quarter and nothing short in the forecast), nor while an incumbent loses money (CPW on the grid, or a private
##      plant over its 12 months), nor while one is being founded.
## The founder: the richest household pool of high income with an adult outside the labour force that can put in the
## founder's share (as FirmAI._entry); the rest is a bank loan. Licence through LawBridge (BUILD_FACILITY). The company
## starts with its price at today's tariff.
static func _entry(world: WorldState, cpw: String, g: String, u: Dictionary) -> void:
	var ftype: String = GRIDS[g]
	var h: Array = u["hist"].get(g, [])
	if h.size() < MIN_HIST:
		return
	var last: Dictionary = h[h.size() - 1]
	var verdict := {"month": world.month, "want": false, "why": ""}
	u["entry"][g] = verdict
	var unserved_q := false
	for row in _last(h, 3):
		if int(row["unserved"]) > 0:
			unserved_q = true
	var short := float(forecast(h)) - float(int(last["cap"])) - _pending_cap(world, ftype)
	if not _full(last):
		verdict["why"] = "incumbent_spare"
		return
	if not unserved_q and short <= 0.0:
		verdict["why"] = "incumbent_serves_all"
		return
	if short <= 0.0:
		verdict["why"] = "incumbent_clears"
		return
	var bill12 := 0
	var cost12 := 0
	for row in h:
		bill12 += int(row["bill"])
		cost12 += int(row["cost"])
	if bill12 < cost12:
		verdict["why"] = "incumbent_loses"
		return
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] != ftype or String(f["org"]) == cpw:
			continue
		var pp: Array = f.get("r8u_pp", [])
		var rev := 0
		var cost := 0
		for row in pp:
			rev += int(row[3])
			cost += int(row[4])
		if pp.size() >= 6 and rev < cost:
			verdict["why"] = "incumbent_loses"
			return
	for oid in world.table("org"):
		var o: Dictionary = world.table("org")[oid]
		if o["status"] == "FORMING" and String(o.get("entry_type", "")) == ftype:
			verdict["why"] = "forming"
			return
	var fc := forecast_profit(world, ftype, short)
	verdict["forecast"] = fc
	if int(fc["profit"]) <= 0:
		verdict["why"] = "no_profit"
		return
	verdict["want"] = true
	var oid := ""
	for kind in founder_order(world, ftype):
		oid = _found(world, ftype) if kind == "PRIVATE" else _found_public(world, ftype)
		if oid != "":
			verdict["kind"] = kind
			break
	verdict["why"] = "founded" if oid != "" else "no_founder"
	verdict["org"] = oid
	if oid != "":
		u["acts"].append([world.month, g + "_founded_" + String(verdict["kind"]).to_lower(), oid])


## Who may found the new company, in order, by the ownership policy as it stands (E137): a market policy leaves it to
## private founders; a mixed one asks private founders first and the state if none can; a state policy founds a public
## company first and leaves it to private founders when the state cannot (a human government is never committed to a
## company it did not choose: E110's rule). Without E137 the policy has no say: private first, then public.
static func founder_order(world: WorldState, ftype: String) -> Array:
	if not EconOwnership.active(world):
		return ["PRIVATE", "PUBLIC"]
	match EconOwnership.policy_for(world, ftype):
		"MARKET":
			return ["PRIVATE"]
		"STATE":
			return ["PUBLIC", "PRIVATE"]
	return ["PRIVATE", "PUBLIC"]


## A second public utility company (the user, 2026-11-16: "What if for example we run 500 years at that point there
## might be a need for another powerplant"). The government founds it with the founder's share from the treasury
## (INFRASTRUCTURE line, as a public builder is founded); the rest is a bank loan. It sells to the grid like any other
## company that is not CPW, with its own price rules. Not behind a human government's back ("" then).
static func _found_public(world: WorldState, ftype: String) -> String:
	if EconEssentials.human_governs(world):
		return ""
	var est := EconConstruction.estimate(ftype)
	var district := ""
	for fid in EconUtil.sorted_keys(world.table("facility")):
		if world.table("facility")[fid]["type"] == ftype:
			district = String(world.table("facility")[fid]["district"])
			break
	if district == "":
		district = "d:4" if ftype == "POWER" else "d:2"
	if not LawBridge.allowed(world, "new", "BUILD_FACILITY", {"facility_type": ftype, "district": district, "owner_kind": "COMPANY", "value_wref": 0}):
		return ""
	var id := world.new_id("org")
	world.table("org")[id] = {"id": id, "key": "PUBUTIL_" + id, "name": EconUtil.firm_name(world, district, ftype, "Authority"),
		"type": "PUBLIC_ENTERPRISE", "hq": district, "status": "FORMING", "ceo": {"mgmt": 55, "risk": 20, "age_m": 45 * 12},
		"reliability": 50, "is_contractor": false, "crew": {}, "crew_target": {}, "premium_m": {"G": 0, "S": 0, "Sp": 0}, "tax_loss_cf": 0,
		"profit_q": 0, "pl": EconFinance.empty_pl(), "pl_last": {}, "missed_streak": 0, "ok_streak": 0, "low_cash_streak": 0,
		"distress_months": 0, "admin_months": 0, "liq_months": 0, "missed_this_month": false, "owner_group": "", "sales_ema": {},
		"contracts": [], "dividends_ytd": 0, "sold": {}}
	var o: Dictionary = world.table("org")[id]
	o["entry_type"] = ftype
	o["r8u_price"] = float(EconUtil.lever(world, TARIFF_LEVER[_grid_of(ftype)][0], TARIFF_LEVER[_grid_of(ftype)][1]))
	world.ledger.open_account(EconUtil.acct(id))
	var eq_pm := EconBankRisk.founder_equity_pm(world)
	var paid := EconFinance.gov_pay(world, EconUtil.acct(id), est * eq_pm / 1000, "PUBLIC_EQUITY")
	EconFinance._spend_line(world, "ECON_BUDGET_INFRASTRUCTURE", paid)
	if not EconFinance.new_loan(world, id, est - paid, 0, true):
		pass  # builds with the treasury's share only; may stall on payments
	EconConstruction.create(world, ftype, district, id, id, "")
	EconFacts.emit(world, "COMP_COMPANY_FOUNDED", district, [["COMPANY", id], ["GOVERNMENT", "government"]],
		[["GOVERNMENT", "government", 1.0]], {"JOBS": 3, "INFRASTRUCTURE": 2}, 25, "PUBLIC",
		{"type": ftype, "public": true, "capital": paid / S, "rule": "R8U"}, {"districts": [district]})
	return id


static func _found(world: WorldState, ftype: String) -> String:
	var s := EconUtil.st(world)
	var est := EconConstruction.estimate(ftype)
	var eq_pm := EconBankRisk.founder_equity_pm(world)
	var best := ""
	var best_cash := est * eq_pm / 1000 - 1
	for gid in EconUtil.sorted_keys(world.table("hh")):
		var g0: Dictionary = world.table("hh")[gid]
		if g0["band"] in ["I4", "I5"] and g0["nonpart"] >= S:
			var c := world.ledger.balance(EconUtil.hh_acct(gid))
			if c > best_cash:
				best_cash = c
				best = gid
	if best == "":
		return ""
	var g: Dictionary = world.table("hh")[best]
	var district := String(g["district"])
	if not LawBridge.allowed(world, "new", "BUILD_FACILITY", {"facility_type": ftype, "district": district, "owner_kind": "COMPANY", "value_wref": 0}):
		return ""
	var id := world.new_id("org")
	var mgmt := int(clampf(50.0 + EconUtil.normal(world, "comp.entry", 15.0), 10.0, 95.0))
	var risk := world.rng.stream("comp.entry").randi_range(20, 80)
	world.table("org")[id] = {"id": id, "key": "NEW_" + id, "name": EconUtil.firm_name(world, district, ftype, "Ltd"), "type": "PRIVATE",
		"hq": district, "status": "FORMING", "ceo": {"mgmt": mgmt, "risk": risk, "age_m": 40 * 12}, "reliability": 0, "is_contractor": false,
		"crew": {}, "crew_target": {}, "premium_m": {"G": 0, "S": 0, "Sp": 0}, "tax_loss_cf": 0, "profit_q": 0, "pl": EconFinance.empty_pl(),
		"pl_last": {}, "missed_streak": 0, "ok_streak": 0, "low_cash_streak": 0, "distress_months": 0, "admin_months": 0, "liq_months": 0,
		"missed_this_month": false, "owner_group": best, "sales_ema": {}, "contracts": [], "dividends_ytd": 0, "sold": {}}
	var o: Dictionary = world.table("org")[id]
	o["entry_type"] = ftype
	o["r8u_price"] = float(EconUtil.lever(world, TARIFF_LEVER[_grid_of(ftype)][0], TARIFF_LEVER[_grid_of(ftype)][1]))
	world.ledger.open_account(EconUtil.acct(id))
	world.ledger.transfer(EconUtil.hh_acct(best), EconUtil.acct(id), est * eq_pm / 1000, "EQUITY", world.month)
	EconPop.make_owner(world, g["hb"], g["band"])
	EconPop.sync(world)
	if EconInsolvency.plan_b(world):
		o["plan_credit"] = est * (1000 - eq_pm) / 1000
	elif not EconFinance.new_loan(world, id, est * (1000 - eq_pm) / 1000, 0, true):
		pass  # builds with equity only; may stall on payments (as FirmAI._entry)
	EconConstruction.create(world, ftype, district, id, id, "")
	if EconInsolvency.planning_stage(world):
		o["planned_month"] = world.month
		var ps: Dictionary = s.get("plan_stats", {})
		ps["plans"] = int(ps.get("plans", 0)) + 1
		s["plan_stats"] = ps
		EconFacts.emit(world, "COMP_COMPANY_PLANNED", district, [["COMPANY", id]], [["COMPANY", id, 1.0]],
			{}, 10, "PUBLIC", {"type": ftype}, {"districts": [district]})
	else:
		EconFacts.emit(world, "COMP_COMPANY_FOUNDED", district, [["COMPANY", id]], [["COMPANY", id, 0.8], ["GOVERNMENT", "government", 0.2]],
			{"JOBS": 3}, 15, "PUBLIC", {"type": ftype, "rule": "R8U"}, {"districts": [district]})
	return id

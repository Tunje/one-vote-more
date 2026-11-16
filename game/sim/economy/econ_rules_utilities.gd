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
##   7/8 A NEW UTILITY COMPANY: wanted when the forecast leaves unserved demand the incumbent does not clear (every
##     plant at its largest or the incumbent unable to fund its project) — none while the incumbent has spare capacity
##     or loses money on the grid. The law today (EconOwnership.PUBLIC_ONLY) allows no other owner of power or water
##     works, so the verdict is only recorded (st["r8u"]["entry"]) and nothing is founded.
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
	return clampf(need / maxf(1.0, cap), 0.0, 1.0)


# ------------------------------------------------------------------ monthly (EconRules.monthly, TRADE)

static func monthly(world: WorldState) -> void:
	if not on(world):
		return
	var s := EconUtil.st(world)
	if not s.has("util_demand"):
		return
	var u: Dictionary = s.get("r8u", {"hist": {}, "acts": [], "entry": {}})
	var e_unit := 0
	for g in ["E", "W"]:
		var row := _measure(world, g, e_unit)
		if g == "E":
			e_unit = int(row["cost"]) * S / maxi(S, int(row["served"]))
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


## One month of one grid: {m, dem, sup, cap, unserved, served, billed, bill, cost} (mu, mcr).
static func _measure(world: WorldState, g: String, e_unit: int) -> Dictionary:
	var s := EconUtil.st(world)
	var ftype: String = GRIDS[g]
	var dem := int(s.get("util_demand", {}).get(g, 0))
	var sup := int(s.get("util_supply", {}).get(g, 0))
	var served := mini(dem, sup)
	var self_use := 0
	var cost := 0.0
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if g == "E" and f["type"] == "WATERWORKS" and not f["mothball"]:
			self_use += int(float(WW_POWER) * S * float(f.get("util", 0)) / 1000.0 * EconUtil.fscale(f) * float(f.get("e_served", 1000)) / 1000.0)
		if f["type"] != ftype:
			continue
		var r: Dictionary = EconData.RECIPES[ftype]
		for t in f.get("staff", {}):
			cost += float(EconLabor.tier_total(f["staff"], t)) / float(S) * float(s["wage"].get(t, 0))
		var share := 0.25 if f["mothball"] else 1.0  # EconProduction._upkeep: a closed plant keeps a quarter
		cost += share * EconUtil.fscale(f) * (float(r["upkeep"]) * float(s["prices"]["MATERIAL"]) \
			+ float(EconData.UPKEEP_COMPONENT.get(ftype, 0)) * float(s["prices"].get("COMPONENT", 0)))
		if EconData.BUILD.has(ftype):
			cost += float(EconConstruction.estimate(ftype)) * EconUtil.fscale(f) / float(EconData.DEPRECIATION_MONTHS)
	if g == "W":
		var ww_power := 0
		for fid in EconUtil.sorted_keys(world.table("facility")):
			var f: Dictionary = world.table("facility")[fid]
			if f["type"] == "WATERWORKS" and not f["mothball"]:
				ww_power += int(float(WW_POWER) * S * float(f.get("util", 0)) / 1000.0 * EconUtil.fscale(f) * float(f.get("e_served", 1000)) / 1000.0)
		cost += float(ww_power) * float(e_unit) / float(S)
	var billed := maxi(0, served - self_use)
	var tariff := int(EconUtil.lever(world, TARIFF_LEVER[g][0], TARIFF_LEVER[g][1]))
	return {"m": world.month, "dem": dem, "sup": sup, "cap": int(eff_cap(world, ftype)), "unserved": maxi(0, dem - sup),
		"served": served, "billed": billed, "bill": EconUtil.val(billed, tariff * S), "cost": int(cost)}


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
		if f["type"] != ftype:
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
		if world.table("facility")[fid]["type"] == ftype:
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
		if f["type"] == ftype and not f["mothball"]:
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


# ------------------------------------------------------------------ rules 7/8: a new utility company

static func _entry(world: WorldState, cpw: String, g: String, u: Dictionary) -> void:
	var ftype: String = GRIDS[g]
	var h: Array = u["hist"].get(g, [])
	if h.size() < MIN_HIST:
		return
	var last: Dictionary = h[h.size() - 1]
	var verdict := {"month": world.month, "want": false, "allowed": not (ftype in EconOwnership.PUBLIC_ONLY), "why": ""}
	var bill12 := 0
	var cost12 := 0
	for row in h:
		bill12 += int(row["bill"])
		cost12 += int(row["cost"])
	var short := forecast(h) - int(last["cap"])
	if short <= 0 or not _full(last):
		verdict["why"] = "incumbent_spare"  # rule 8
	elif bill12 < cost12:
		verdict["why"] = "incumbent_loses"  # rule 8: no entrant into a grid that loses money at today's tariff
	else:
		var all_max := true
		for fid in EconUtil.sorted_keys(world.table("facility")):
			var f: Dictionary = world.table("facility")[fid]
			if f["type"] == ftype and int(f.get("scale", 1000)) < MAX_SCALE:
				all_max = false
		var unfunded := world.month - int(u.get("unfunded_" + g, -999)) <= 3
		if (all_max and not _pending(world, ftype)) or unfunded:
			verdict["want"] = true
			verdict["why"] = "incumbent_cannot_clear" if verdict["allowed"] else "wanted_but_public_only"
		else:
			verdict["why"] = "incumbent_clears"
	u["entry"][g] = verdict

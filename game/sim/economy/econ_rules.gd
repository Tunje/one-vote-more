class_name EconRules
extends RefCounted
## R8 step 1 (planning/eight-rules.md; user decision 2026-11-15 "build the eight rules once"): the shared signals every
## producer's eight rules will read. OPT-IN "R8". Step 1 only measures and publishes, nothing acts on it yet, so with R8
## off nothing here runs and base is bit-identical; with R8 on the simulation is still unchanged (only st["r8"] is
## written).
## Signals (monthly, integers):
##   goods  {good: {district: {w wanted, f filled, u unfilled, hf held for want of freight, hr held by roads}}} this month,
##          plus an orders EMA per good and district (oe).
##   deliver {"from|to": ‰}: the share of last month's demand on the route that could be carried = min(the depot part
##          (moved ÷ (moved + held) on that route when trucks were full, else 1000), the road part
##          (Transport.deliverable_pm under FREIGHT_ROADS, else 1000)).
##   plants {fid: {g good, d district, util ‰ (output ÷ effective capacity), cover ‰ of a month (stock ÷ sales EMA),
##          sales, reach (unfilled orders the plant could deliver to, mu), cost_now, cost_var, cost_full (mcr per unit),
##          profit12 (mcr)}}.
## Queries: plant(world, fid), reachable_unfilled(world, good, d), deliverable_pm(world, from_d, to_d),
## institution_needs(world).
##
## STABLE INTERFACE (for every owner of a sector: Bob, Ella's service hubs, Wilma's utilities and institutions):
##   Computed: monthly, at the end of EconMarket.trade (TRADE phase), from that month's clearing. Read them in later
##   phases of the same month or in the next month's decisions; they describe the month just cleared.
##   Units: quantities in milli-units (mu, 1000 = one unit); money in mcr (1000 = one credit); shares in ‰.
##   st["r8"]["goods"][good][district] = {w, f, u, hf, hr}: wanted, filled, unfilled, held for want of freight, held by
##     roads. Services are recorded as good "SERVICES" in the customer's home district (EconHouseholds._buy_services).
##   st["r8"]["oe"][good][district] = orders EMA (mu).
##   st["r8"]["deliver"]["from|to"] = ‰ of demand on that route that could be carried last month (goods).
##   st["r8"]["plants"][fid] = {kind "goods" | "services", g, d, util ‰, cover ‰ of a month, sales mu, reach mu,
##     cost_now, cost_var, cost_full (mcr/unit), profit12 (mcr)}.
##   REACH BY KIND: goods are carried to the buyer: reach = unfilled orders in each district × deliverability of the
##     route (freight, then roads). Services aren't shipped, the customer travels: reach = unfilled service demand in
##     the hub's own district + its neighbours (today's rule: neighbours buy at +10%). travel_pm() is the slot for
##     Terra's road times and commute data.
##   SECTORS: each sector registers one row in SECTORS {switch: its flag (on only together with R8), types: plant types,
##     params: its numbers for the eight rules}. sector_on(world, name) is the only test a sector's code uses. Add a
##     row (one line) for a new sector; never change another sector's row.

const S := EconUtil.S
const OE_KEEP := 0.8
## Sector registry (rows filled in as each sector moves onto the eight rules; params empty until then).
const SECTORS := {
	"FREIGHT": {"switch": "R8_FREIGHT", "types": ["DEPOT"], "params": {}},
	"MATERIAL": {"switch": "R8_MATERIAL", "types": ["MINE", "PROCESSING", "COMPONENTS"], "params": {}},
	"FOOD": {"switch": "R8_FOOD", "types": ["FARM", "BAKERY", "FAMFARM", "FAMBAKERY"], "params": {}},
	"BUILDERS": {"switch": "R8_BUILDERS", "types": [], "params": {}},
	"WORKSHOPS": {"switch": "R8_WORKSHOPS", "types": ["CONSUMERF", "TEXTILE", "FURNITURE", "MEDWORKS"], "params": {}},
	"SERVICES": {"switch": "R8_SERVICES", "types": ["SERVICEHUB"], "params": {}},
	"UTILITIES": {"switch": "R8_UTILITIES", "types": ["POWER", "WATERWORKS"], "params": {}},
	"INSTITUTIONS": {"switch": "R8_INSTITUTIONS", "types": ["CLINIC", "SCHOOL", "ADMIN"], "params": {}},
	"HOUSING": {"switch": "R8_HOUSING", "types": ["HOUSING"], "params": {}},
}


static func sector_on(world: WorldState, name: String) -> bool:
	return active(world) and SECTORS.has(name) and (world.meta.get("on", []) as Array).has(String(SECTORS[name]["switch"]))


## The travel half for services (customer to hub): own district 1000, neighbours 1000 (at +10% price), farther 0.
## Slot for Terra's road times / commute data later.
static func travel_pm(world: WorldState, home_d: String, hub_d: String) -> int:
	if home_d == hub_d:
		return 1000
	return 1000 if hub_d in EconUtil.neighbours(home_d) else 0


static func active(world: WorldState) -> bool:
	return world.meta.has("on") and (world.meta["on"] as Array).has("R8") and not EconUtil.off(world, "R8")


# ------------------------------------------------------------------ hooks in EconMarket (no-ops when off)

static func _m(world: WorldState) -> Dictionary:
	var s := EconUtil.st(world)
	if int(s.get("r8_m_month", -1)) != world.month:
		s["r8_m"] = {"goods": {}, "moved": {}, "held": {}}
		s["r8_m_month"] = world.month
	return s["r8_m"]


static func note_fill(world: WorldState, good: String, d: String, want: int, got: int) -> void:
	if not active(world):
		return
	var g: Dictionary = (_m(world)["goods"] as Dictionary).get(good, {})
	var row: Dictionary = g.get(d, {"w": 0, "f": 0, "hf": 0, "hr": 0})
	row["w"] = int(row["w"]) + want
	row["f"] = int(row["f"]) + got
	g[d] = row
	_m(world)["goods"][good] = g


static func note_held(world: WorldState, good: String, from_d: String, to_d: String, held: int, by_roads: bool) -> void:
	if not active(world) or held <= 0:
		return
	var g: Dictionary = (_m(world)["goods"] as Dictionary).get(good, {})
	var row: Dictionary = g.get(to_d, {"w": 0, "f": 0, "hf": 0, "hr": 0})
	row["hr" if by_roads else "hf"] = int(row["hr" if by_roads else "hf"]) + held
	g[to_d] = row
	_m(world)["goods"][good] = g
	var k := from_d + "|" + to_d
	_m(world)["held"][k] = int(_m(world)["held"].get(k, 0)) + held


static func note_move(world: WorldState, from_d: String, to_d: String, qty: int) -> void:
	if not active(world) or qty <= 0 or from_d == to_d:
		return
	var k := from_d + "|" + to_d
	_m(world)["moved"][k] = int(_m(world)["moved"].get(k, 0)) + qty


# ------------------------------------------------------------------ monthly (end of TRADE)

static func monthly(world: WorldState) -> void:
	if not active(world):
		return
	var s := EconUtil.st(world)
	var m := _m(world)
	var r8: Dictionary = s.get("r8", {})
	# goods by district, with the orders EMA
	var goods := {}
	var oe: Dictionary = r8.get("oe", {})
	for good in EconUtil.sorted_keys(m["goods"]):
		var gd := {}
		var oeg: Dictionary = oe.get(good, {})
		for d in EconUtil.sorted_keys(m["goods"][good]):
			var row: Dictionary = m["goods"][good][d]
			var w := int(row["w"])
			gd[d] = {"w": w, "f": int(row["f"]), "u": maxi(0, w - int(row["f"])), "hf": int(row["hf"]), "hr": int(row["hr"])}
			oeg[d] = int(OE_KEEP * float(oeg.get(d, w)) + (1.0 - OE_KEEP) * float(w))
		goods[good] = gd
		oe[good] = oeg
	# deliverability per route
	var deliver := {}
	var trucks_full := int(s.get("freight_cap", 0)) > 0 and int(s.get("freight_used", 0)) * 100 >= int(s.get("freight_cap", 0)) * 95
	for d1 in EconUtil.sorted_keys(EconData.DISTRICTS):
		for d2 in EconUtil.sorted_keys(EconData.DISTRICTS):
			if d1 == d2:
				continue
			var k: String = String(d1) + "|" + String(d2)
			var mv := int(m["moved"].get(k, 0))
			var hd := int(m["held"].get(k, 0))
			var depot := 1000
			if trucks_full and mv + hd > 0:
				depot = 1000 * mv / (mv + hd)
			deliver[k] = mini(depot, _road_pm(world, d1, d2))
	r8["goods"] = goods
	r8["oe"] = oe
	r8["deliver"] = deliver
	r8["month"] = world.month
	s["r8"] = r8
	r8["plants"] = _plants(world, goods, deliver)
	s["r8"] = r8


## The road half (Terra, FREIGHT_ROADS): 1000 when the flag or the function is absent.
static func _road_pm(world: WorldState, d1: String, d2: String) -> int:
	if not (world.meta.get("on", []) as Array).has("FREIGHT_ROADS"):
		return 1000
	var tr = load("res://sim/transport/transport.gd") if ResourceLoader.exists("res://sim/transport/transport.gd") else null
	if tr == null or not tr.has_method("deliverable_pm"):
		return 1000
	return clampi(int(tr.deliverable_pm(world, d1, d2)), 0, 1000)


static func _plants(world: WorldState, goods: Dictionary, deliver: Dictionary) -> Dictionary:
	var s := EconUtil.st(world)
	var out := {}
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		var r: Dictionary = EconData.RECIPES.get(f["type"], {})
		if r.is_empty() or f["mothball"]:
			continue
		var good := String(r["out"][0])
		var kind := "services" if good == "SERVICES" else "goods"
		if not (good in EconData.MARKET_GOODS) and kind != "services":
			continue
		var o: Dictionary = world.table("org").get(f["org"], {})
		var cap := float(r["out"][1]) * float(S) * EconUtil.fscale(f) * EconProduction._eff(world, f) * EconUtil.tier_out(f)
		cap *= EconFoodSec.labour_fill(f)
		var outq := int(f.get("out_last", 0))
		var sales := int(o.get("sales_ema", {}).get(good, 0)) if kind == "goods" else int(f.get("svc_sold", 0))
		var stock := EconUtil.inv_get(world, f["org"], good, f["district"])
		# costs (mcr per unit): variable = inputs + utilities per unit; now = variable + fixed (crew, upkeep, depreciation)
		# spread over this month's output; full = the planners' unit cost at full load
		var var_c := 0.0
		for g in r["in"]:
			if g in EconData.MARKET_GOODS:
				var_c += float(r["in"][g]) * float(s["prices"][g])
			elif g == "ENERGY":
				var_c += float(r["in"][g]) * float(EconUtil.lever(world, "ECON_UTILITY_TARIFF_ENERGY", 40)) * S
			elif g == "WATER":
				var_c += float(r["in"][g]) * float(EconUtil.lever(world, "ECON_UTILITY_TARIFF_WATER", 20)) * S
		var_c /= float(r["out"][1])
		var crew_c := 0.0
		for t in f.get("staff", {}):
			crew_c += float(EconLabor.tier_total(f["staff"], t)) / float(S) * float(s["wage"].get(t, 0))
		var fixed := crew_c + float(r["upkeep"]) * float(s["prices"]["MATERIAL"])
		if EconData.BUILD.has(f["type"]):
			fixed += float(EconConstruction.estimate(f["type"])) / float(EconData.DEPRECIATION_MONTHS)
		var now_c := var_c + fixed * float(S) / float(maxi(S, outq))
		var reach := 0
		for d in goods.get(good, {}):
			var pm := 1000
			if kind == "services":
				pm = travel_pm(world, String(d), String(f["district"]))
			elif d != f["district"]:
				pm = int(deliver.get(String(f["district"]) + "|" + String(d), 1000))
			reach += int(goods[good][d]["u"]) * pm / 1000
		out[fid] = {"kind": kind, "g": good, "d": f["district"], "util": int(1000.0 * float(outq) / maxf(1.0, cap)),
			"cover": int(1000.0 * float(stock) / float(maxi(1, sales))), "sales": sales, "reach": reach,
			"cost_now": int(now_c), "cost_var": int(var_c), "cost_full": int(FirmAI.unit_cost(world, f["type"])),
			"profit12": EconPublicCo.result12(o) if not o.is_empty() else 0}
	return out


# ------------------------------------------------------------------ queries (pure)

static func plant(world: WorldState, fid: String) -> Dictionary:
	return EconUtil.peek_st(world).get("r8", {}).get("plants", {}).get(fid, {})


## Unfilled orders for `good` a producer in district d could deliver to (mu), from last month's signals.
static func reachable_unfilled(world: WorldState, good: String, d: String) -> int:
	var r8: Dictionary = EconUtil.peek_st(world).get("r8", {})
	var t := 0
	for d2 in r8.get("goods", {}).get(good, {}):
		var pm := 1000 if d2 == d else int(r8.get("deliver", {}).get(d + "|" + String(d2), 1000))
		t += int(r8["goods"][good][d2]["u"]) * pm / 1000
	return t


static func deliverable_pm(world: WorldState, from_d: String, to_d: String) -> int:
	if from_d == to_d:
		return 1000
	return int(EconUtil.peek_st(world).get("r8", {}).get("deliver", {}).get(from_d + "|" + to_d, 1000))


## Institutions' budget request (planning/eight-rules.md 3a.4). First approximation: what is served grows with budget
## and crew in proportion (access ‰ = served share), so budget_to_serve = budget_now × 1000 ÷ access.
const INSTITUTIONS := {"CLINIC": ["health_access", "ECON_BUDGET_HEALTH"], "SCHOOL": ["edu_access", "ECON_BUDGET_EDUCATION"]}


static func institution_needs(world: WorldState) -> Array:
	var s := EconUtil.peek_st(world)
	var out: Array = []
	for typ in EconUtil.sorted_keys(INSTITUTIONS):
		var acc_key: String = INSTITUTIONS[typ][0]
		var line: String = INSTITUTIONS[typ][1]
		var by_d := {}
		for fid in EconUtil.sorted_keys(world.peek("facility")):
			var f: Dictionary = world.peek("facility")[fid]
			if f["type"] != typ:
				continue
			var row: Dictionary = by_d.get(f["district"], {"plants": 0, "open": 0, "crew": 0, "crew_full": 0})
			row["plants"] = int(row["plants"]) + 1
			if not f["mothball"]:
				row["open"] = int(row["open"]) + 1
			row["crew"] = int(row["crew"]) + EconLabor.staff_total(f["staff"]) / S
			var req := EconLabor.required(f)
			for t in req:
				row["crew_full"] = int(row["crew_full"]) + int(req[t]) / S
			by_d[f["district"]] = row
		var budget_year := int(EconUtil.lever(world, line, 0)) * S
		var plants_all := 0
		for d in by_d:
			plants_all += int(by_d[d]["plants"])
		for d in EconUtil.sorted_keys(EconData.DISTRICTS):
			var row: Dictionary = by_d.get(d, {"plants": 0, "open": 0, "crew": 0, "crew_full": 0})
			var access := int(s.get(acc_key, {}).get(d, 0))
			var budget_now := budget_year / 12 * int(row["plants"]) / maxi(1, plants_all)
			var to_serve := budget_now * 1000 / maxi(1, access) if access > 0 else 0
			var crew_to := int(row["crew"]) * 1000 / maxi(1, access) if access > 0 else int(row["crew_full"])
			var per_plant := int(row["crew_full"]) / maxi(1, int(row["plants"])) if int(row["plants"]) > 0 else 0
			var plants_needed := 0
			if per_plant > 0 and crew_to > int(row["crew_full"]):
				plants_needed = int(ceil(float(crew_to - int(row["crew_full"])) / float(per_plant)))
			out.append({"type": typ, "district": d, "need": 1000, "served": access, "unmet": maxi(0, 1000 - access), "budget_line": line,
				"budget_now": budget_now / S, "budget_to_serve": to_serve / S, "plants": int(row["plants"]), "plants_open": int(row["open"]),
				"crew_now": int(row["crew"]), "crew_to_serve": crew_to, "plants_needed": plants_needed})
	return out

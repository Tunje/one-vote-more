class_name GovBuilder
extends RefCounted
## The AI government's capital programme (user decision 2026-11-11: AI governments decide what the state builds,
## by their politics; companies decide their own plants; when the human player governs, nothing is ordered
## behind their back). Replaces EconAutopilot's commissioning in the integrated game; the autopilot now runs
## only in econ-only test sims.
##
## Every quarter the government reviews needs (overcrowded districts, poor health/school access, utility headroom,
## unemployment, essentials margins from EconQuery.essentials) and orders public projects through the same EconActions entry point the player uses. Its politics
## shape the programme:
##   FISCAL > 0 (spend for growth)  builds with less cash in hand and does counter-cyclical public works
##   ECON_ROLE > 0 (state-directed) builds public housing earlier
##   REDISTRIBUTION > 0, or owning PUBLIC_SERVICES / HOUSING, raises the bar for schools, clinics and homes
##   Essentials (food, power, water, materials, components): ECON_ROLE > 0.15 builds; < -0.15 offers a grant to
##   private builders (ECON_OFFER_INCENTIVE); in between offers first and builds if still short.
## Stateless.

const QUARTER_MONTH := 1


static func monthly(world: WorldState, st: Dictionary) -> void:
	if world.month % 3 != QUARTER_MONTH or not world.table("econ").has("s"):
		return
	var who := _actor(world, st)
	if who.is_empty():
		return
	var pos: Dictionary = who["pos"]
	var spend := float(pos.get("FISCAL", 0)) / 100000.0          # -1..1
	var state := float(pos.get("ECON_ROLE", 0)) / 100000.0
	var equality := float(pos.get("REDISTRIBUTION", 0)) / 100000.0
	var s := EconUtil.st(world)
	var busy := {}
	for pid in EconUtil.sorted_keys(world.table("project")):
		var p: Dictionary = world.table("project")[pid]
		if p["owner"] == "gov" and p["status"] in ["TENDER", "ACTIVE", "TENDERABLE"]:
			busy[p["type"] + "|" + p["district"]] = true
			if p["status"] == "TENDERABLE":
				EconActions.enqueue(world, "ECON_RETENDER_PROJECT", {"project": pid})
	# food emergency: any government opens the reserve
	if int(s.get("food_shortfall", 0)) > 50:
		EconActions.enqueue(world, "ECON_RELEASE_RESERVE", {"good": "FOOD", "qty": 1500})
	# 1a. essentials (A39 / Bob's E110): food, power, water, materials, components. State-minded governments
	#     build (the Colony Agricultural Board runs state farms, CPW the rest); market-minded ones offer a grant to
	#     private builders; centrists offer first and build if the deficit persists. Incentives cost nothing until
	#     a plant is finished, so they are not held back by the cash check below.
	var runway := float(world.indicators.read("ECON_TREASURY_RUNWAY", "COLONY", 240000)) / 1000.0
	var can_build := runway >= 12.0 - 6.0 * spend
	_essentials(world, st, busy, who, state, spend, can_build)
	if not can_build:
		return  # not enough cash and credit for new capital projects (a spending government accepts less)
	var services_owner := float(who.get("own_services", 0)) / 100.0
	var housing_owner := float(who.get("own_housing", 0)) / 100.0
	var orders := 0
	# 1. housing: the most overcrowded district; state-minded governments build before it is full
	var occ_bar := 1000.0 - 60.0 * state - 40.0 * housing_owner
	var worst := ""
	var worst_v := occ_bar
	for d in EconUtil.sorted_keys(world.table("district")):
		var occ := float(world.table("district")[d].get("occupancy", 0))
		if occ > worst_v and not busy.has("HOUSING|" + d):
			worst_v = occ
			worst = d
	if worst != "":
		orders += _order(world, st, busy, who, "HOUSING", worst, "")
	# 3. schools and clinics where access is poor; egalitarian and service-owning governments set a higher bar
	var bar := clampf(650.0 + 150.0 * maxf(equality, services_owner), 500.0, 850.0)
	var needs: Array = []
	for key in [["health_access", "CLINIC"], ["edu_access", "SCHOOL"]]:
		var acc: Dictionary = s.get(key[0], {})
		for d in EconUtil.sorted_keys(acc):
			if float(acc[d]) < bar and not _has_facility(world, key[1], d):
				needs.append([float(acc[d]), key[1], d])
	needs.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[2] < b[2]))
	for n in needs.slice(0, 2):
		orders += _order(world, st, busy, who, n[1], n[2], "")
	# 4. fabrication kits (A38): development- and spending-minded governments upgrade the colony's own
	#    workshop and smelter sooner; austere governments wait until the gain is large
	var dev := -float(pos.get("ENVIRONMENT", 0)) / 100000.0   # development-first = negative environment axis
	var eagerness := 0.5 + 0.4 * spend + 0.3 * dev + 0.2 * state
	var running := false
	for pid2 in world.table("project"):
		var pr: Dictionary = world.table("project")[pid2]
		if pr.get("type", "") == "UPGRADE" and pr["status"] in ["TENDER", "ACTIVE", "TENDERABLE"]:
			running = true
	if not running:
		var opts: Array = EconQuery.upgrade_options(world).filter(func(o): return o.get("enabled", false))
		opts.sort_custom(func(a, b): return float(a["output_gain_pct"]) > float(b["output_gain_pct"]) or (a["output_gain_pct"] == b["output_gain_pct"] and String(a["facility"]) < String(b["facility"])))
		if not opts.is_empty() and float(opts[0]["output_gain_pct"]) / 100.0 * eagerness >= 0.2:
			var r: Dictionary = EconActions.enqueue(world, "ECON_UPGRADE_FACILITY", {"facility": opts[0]["facility"], "line": "ECON_BUDGET_INFRASTRUCTURE"})
			if r.get("ok", false):
				world.add_fact({"type": "POL_PROJECT_ORDERED", "owner": "pol", "subjects": [], "responsible": [{"actor": {"kind": "GOVERNMENT" if who["by"] != "commander" else "COMMANDER", "id": "government"}, "share": 1.0}],
					"impact": {}, "magnitude": 35, "visibility": "PUBLIC", "data": {"type": "UPGRADE", "facility": opts[0]["facility"], "to_tier": opts[0]["next_tier"], "by": who["by"]}})
	# 5. counter-cyclical public works: interventionist and spending governments fight unemployment by building
	if state + spend > -0.2 and FirmAI.colony_unemployment(world) > 0.12 - 0.04 * maxf(0.0, state):
		var pw := "ECON_BUDGET_PUBLIC_WORKS"
		for d in EconUtil.sorted_keys(world.table("district")):
			if float(world.table("district")[d].get("occupancy", 0)) >= 850.0 and not busy.has("HOUSING|" + d):
				if EconActions.headroom(world, pw) >= EconConstruction.estimate("HOUSING") * 11 / 10:
					orders += _order(world, st, busy, who, "HOUSING", d, pw)
					break


## Who decides: the AI government in parliament, or the commander in the founding era when the player's
## persona is on autoplay. Nobody when the human player governs.
static func _actor(world: WorldState, st: Dictionary) -> Dictionary:
	if st.get("era", "") == "FOUNDING":
		if not st.get("autoplay_player", true):
			return {}
		return {"pos": st.get("persona", {}), "by": "commander", "own_services": 0, "own_housing": 0}
	var g: Dictionary = st.get("government", {})
	if g.is_empty():
		return {}
	if st.get("player_party", "") in g.get("members", []) and not st.get("autoplay_player", true):
		return {}
	var pm: Dictionary = world.table("party").get(g.get("pm_party", ""), {})
	return {"pos": g.get("center", {}), "by": g.get("pm_party", ""),
		"own_services": int(pm.get("ownership", {}).get("PUBLIC_SERVICES", 0)),
		"own_housing": int(pm.get("ownership", {}).get("HOUSING", 0))}


static func _order(world: WorldState, st: Dictionary, busy: Dictionary, who: Dictionary, ftype: String, d: String, line: String) -> int:
	if busy.has(ftype + "|" + d):
		return 0
	busy[ftype + "|" + d] = true
	var params := {"type": ftype, "district": d}
	if line != "":
		params["line"] = line
	var r: Dictionary = EconActions.enqueue(world, "ECON_COMMISSION_PROJECT", params)
	if not r.get("ok", false):
		return 0
	world.add_fact({"type": "POL_PROJECT_ORDERED", "owner": "pol", "subjects": [{"kind": "PARTY", "id": who["by"]}] if who["by"] != "commander" else [],
		"responsible": [{"actor": {"kind": "GOVERNMENT" if who["by"] != "commander" else "COMMANDER", "id": "government"}, "share": 1.0}],
		"impact": {}, "magnitude": 35, "visibility": "PUBLIC", "data": {"type": ftype, "district": d, "by": who["by"], "line": line}})
	return 1


static func _has_facility(world: WorldState, ftype: String, d: String) -> bool:
	for fid in world.table("facility"):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] == ftype and f["district"] == d:
			return true
	return false


static func _capacity(world: WorldState, ftype: String) -> int:
	var c := 0
	for fid in world.table("facility"):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] == ftype and not f["mothball"]:
			c += int(float(EconData.RECIPES[ftype]["out"][1]) * EconUtil.S * EconUtil.fscale(f))
	return c


const ESS_PLANT := {"FOOD": "FARM", "ENERGY": "POWER", "WATER": "WATERWORKS", "MATERIAL": "PROCESSING", "COMPONENT": "COMPONENTS"}
const ESS_HOME := {"FARM": "d:2", "POWER": "d:4", "WATERWORKS": "d:2", "PROCESSING": "d:4", "COMPONENTS": "d:4"}


## How worried a government is about one essential good: survival goods (food, power, water) worry it once the
## spare margin falls under 10% or is shrinking fast; supply-chain goods only when actually short. A government
## that owns the issue (ECONOMY) or leans state-ward worries a little sooner.
static func _worried(good: String, e: Dictionary, state: float) -> bool:
	var margin := int(e.get("margin_pct", 0))
	var trend := int(e.get("trend", 0))
	if good in ["FOOD", "ENERGY", "WATER"]:
		return margin < 10 + int(5.0 * maxf(0.0, state)) or (trend < -10 and margin < 25)
	return margin < 0


static func _essentials(world: WorldState, st: Dictionary, busy: Dictionary, who: Dictionary, state: float, spend: float, can_build: bool) -> void:
	var ess: Dictionary = EconQuery.essentials(world)
	var pending := {}
	for pid in world.table("project"):
		var p: Dictionary = world.table("project")[pid]
		if p["status"] in ["TENDER", "ACTIVE", "TENDERABLE"]:
			pending[p["type"]] = int(pending.get(p["type"], 0)) + 1
	for good in ["FOOD", "ENERGY", "WATER", "MATERIAL", "COMPONENT"]:
		var e: Dictionary = (ess.get(good, {}) as Dictionary).duplicate()
		var ftype: String = ESS_PLANT[good]
		if e.is_empty() or float(e.get("demand", 0)) <= 0.0:
			continue
		# count plants already being built as if they were running: act only if they will not close the gap
		var n_pending := int(pending.get(ftype, 0))
		if n_pending > 0:
			var per_plant := float(e["capacity"]) / float(maxi(1, _count(world, ftype)))
			e["margin_pct"] = int(100.0 * ((float(e["capacity"]) + per_plant * n_pending) / float(e["demand"]) - 1.0))
			e["trend"] = 0
		if not _worried(good, e, state):
			continue
		var survival: bool = good in ["FOOD", "ENERGY", "WATER"] and int(e["margin_pct"]) < 0
		if float(e.get("labour_fill", 1.0)) < 0.5 and not survival:
			continue  # nobody to staff it
		var offer_open: bool = not (e.get("incentive", {}) as Dictionary).is_empty()
		# state > 0.15 builds; state < -0.15 only offers; in between offer first, build if still short with an offer out
		var build: bool = state > 0.15 or (state >= -0.15 and offer_open and int(e["margin_pct"]) < 0)
		if build and can_build:
			_order(world, st, busy, who, ftype, _home(world, ftype), "")
		elif not build and not offer_open:
			var pct := clampi(25 + int(round(15.0 * spend)), 10, 50)
			var cap := int(float(EconConstruction.estimate(ftype)) / float(EconUtil.S) * float(pct) / 100.0 * 1.5)
			EconActions.enqueue(world, "ECON_OFFER_INCENTIVE", {"type": ftype, "grant_pct": pct, "months": 24, "cap": maxi(1, cap)})


static func _home(world: WorldState, ftype: String) -> String:
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] == ftype:
			return String(f["district"])
	return ESS_HOME.get(ftype, "d:2")


static func _count(world: WorldState, ftype: String) -> int:
	var n := 0
	for fid in world.table("facility"):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] == ftype and not f.get("mothball", false):
			n += 1
	return n

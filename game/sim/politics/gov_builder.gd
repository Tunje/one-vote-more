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
## State: pol.state["pw_roads"] (district -> month of the last public-works road, so roads are spread out).

const QUARTER_MONTH := 1
## Who decides, step 1 (flag DELEGATION): each decision taken here is counted by type. No-op without the flag.
const Desk := preload("res://sim/office/decision_desk.gd")
const SafetyLaw := preload("res://sim/law/road_safety_law.gd")   # ROAD_SAFETY: Parliament's limit near homes (Anni)
const Grants := preload("res://sim/economy/grants.gd")


static func monthly(world: WorldState, st: Dictionary) -> void:
	if world.table("econ").has("s"):
		_road_budget_need(world, st)
		_toll_feelings(world)
	if world.month % 3 != QUARTER_MONTH or not world.table("econ").has("s"):
		return
	var who := _who(world, st)
	if who.is_empty():
		return
	_road_feelings(world, st, who)
	var pos: Dictionary = who["pos"]
	var spend := float(pos.get("FISCAL", 0)) / 100000.0          # -1..1
	var state := float(pos.get("ECON_ROLE", 0)) / 100000.0
	var equality := float(pos.get("REDISTRIBUTION", 0)) / 100000.0
	var s := CoreUtil.st(world)
	var busy := {}
	for pid in CoreUtil.sorted_keys(world.table("project")):
		var p: Dictionary = world.table("project")[pid]
		if p["owner"] == "gov" and p["status"] in ["TENDER", "ACTIVE", "TENDERABLE"]:
			busy[p["type"] + "|" + p["district"]] = true
			if p["status"] == "TENDERABLE" and _retender_due(world, st, String(pid), p):
				if Desk.on(world):
					_retender_case(world, String(pid), p)
				elif EconFace.actions_enqueue(world, "ECON_RETENDER_PROJECT", {"project": pid}).get("ok", false):
					Desk.note(world, "RETENDER_PROJECT")
	_retender_prune(world, st)
	# food emergency: any government opens the reserve
	if int(s.get("food_shortfall", 0)) > 50:
		if Desk.on(world):
			_simple_case(world, "FOOD_RESERVE_RELEASE", "RESERVE|FOOD", "Open the food reserve",
				["Food is short: %d per mille of what people need goes unmet." % int(s.get("food_shortfall", 0))], "Release 1500 from the reserve",
				{"via": "ECON", "id": "ECON_RELEASE_RESERVE", "params": {"good": "FOOD", "qty": 1500}}, 0)
		elif EconFace.actions_enqueue(world, "ECON_RELEASE_RESERVE", {"good": "FOOD", "qty": 1500}).get("ok", false):
			Desk.note(world, "FOOD_RESERVE_RELEASE")
	# 1a. essentials (A39 / Bob's E110): food, power, water, materials, components. State-minded governments
	#     build (the Colony Agricultural Board runs state farms, CPW the rest); market-minded ones offer a grant to
	#     private builders; centrists offer first and build if the deficit persists. Incentives cost nothing until
	#     a plant is finished, so they are not held back by the cash check below.
	var runway := float(world.indicators.read("ECON_TREASURY_RUNWAY", "COLONY", 240000)) / 1000.0
	var can_build := runway >= 12.0 - 6.0 * spend
	if Legislature.e151(world):
		can_build = runway >= 3.0 - 1.5 * spend or not Legislature.fiscal_guard(world)   # E151: reserves target 6 months, not 24; capital projects may borrow
	_essentials(world, st, busy, who, state, spend, can_build)
	_tariff_proposals(world, state, equality)
	if Desk.on(world) and RoadSafety.on(world):
		_safety_cases(world, st, who)   # who decides (Maja): road safety only as cases
	if EconFace.inst_on(world):
		_inst_sites(world)   # R8_INSTITUTIONS (Maja): reopen, close, budget requests
	if can_build:
		_port_depot(world, st, busy, who, state, spend)
	if not can_build:
		return  # not enough cash and credit for new capital projects (a spending government accepts less)
	var services_owner := float(who.get("own_services", 0)) / 100.0
	var housing_owner := float(who.get("own_housing", 0)) / 100.0
	var orders := 0
	# 1. housing: the most overcrowded district; state-minded governments build before it is full
	var occ_bar := 1000.0 - 60.0 * state - 40.0 * housing_owner
	var worst := ""
	var worst_v := occ_bar
	for d in CoreUtil.sorted_keys(world.table("district")):
		var occ := float(world.table("district")[d].get("occupancy", 0))
		if occ > worst_v and not busy.has("HOUSING|" + d):
			worst_v = occ
			worst = d
	if worst != "":
		orders += _order(world, st, busy, who, "HOUSING", worst, "")
	# 1b. housing ahead of the wave (A46 S6): households forming over the planning horizon against free homes.
	#     State-minded governments plan further ahead and build; market-minded ones offer developers a grant.
	orders += _housing_ahead(world, st, busy, who, state)
	# 2b. bakeries (E146, user: "people prefer bakery things over direct from farms"; "living on raw should produce
	#     unhappiness"): where many people live on raw farm food and no bakery serves them, a state-minded or centrist
	#     government has the Agricultural Board build one. Market-minded governments leave it to private founders.
	orders += _bakery_needs(world, st, busy, who, state, equality)
	# 3. schools and clinics where access is poor; egalitarian and service-owning governments set a higher bar
	var bar := clampf(650.0 + 150.0 * maxf(equality, services_owner), 500.0, 850.0)
	var needs: Array = []
	if EconFace.inst_on(world):
		orders += _inst_builds(world, st, busy, who)   # R8_INSTITUTIONS (Maja): where the open plants cannot hold the clients
	else:
		for key in [["health_access", "CLINIC"], ["edu_access", "SCHOOL"]]:
			var acc: Dictionary = s.get(key[0], {})
			for d in CoreUtil.sorted_keys(acc):
				if float(acc[d]) < bar and not _has_facility(world, key[1], d):
					needs.append([float(acc[d]), key[1], d])
		needs.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[2] < b[2]))
		for n in needs.slice(0, 2):
			orders += _order(world, st, busy, who, n[1], n[2], "")
	# 3b. roads by need (Terra's Transport.road_needs, v8 follow-up): congested or worn links and junctions get their
	#     cheapest fix on the infrastructure line, whatever unemployment is. Spending- and state-minded governments act
	#     sooner (lower bar) and fix more per quarter; austere ones wait until the jam is bad. Each link or junction is
	#     ordered at most once per ROAD_NEED_GAP months.
	_road_needs(world, st, busy, who, state, spend)
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
		var opts: Array = EconFace.query_upgrade_options(world).filter(func(o): return o.get("enabled", false))
		opts.sort_custom(func(a, b): return float(a["output_gain_pct"]) > float(b["output_gain_pct"]) or (a["output_gain_pct"] == b["output_gain_pct"] and String(a["facility"]) < String(b["facility"])))
		if not opts.is_empty() and float(opts[0]["output_gain_pct"]) / 100.0 * eagerness >= 0.2 and Desk.on(world):
			var fid := String(opts[0]["facility"])
			_simple_case(world, "UPGRADE_FACILITY", "UPGRADE|" + fid, "Upgrade the %s" % String(world.peek("facility").get(fid, {}).get("type", fid)).to_lower(),
				["An upgrade to tier %s would raise its output by %d%%." % [str(opts[0]["next_tier"]), int(opts[0]["output_gain_pct"])]], "Order the upgrade",
				{"via": "DESK", "id": "GOV_UPGRADE", "params": {"facility": fid, "to_tier": opts[0]["next_tier"], "by": String(who["by"])}}, CASE_LEAN)
		elif not opts.is_empty() and float(opts[0]["output_gain_pct"]) / 100.0 * eagerness >= 0.2:
			var r: Dictionary = EconFace.actions_enqueue(world, "ECON_UPGRADE_FACILITY", {"facility": opts[0]["facility"], "line": "ECON_BUDGET_INFRASTRUCTURE"})
			if r.get("ok", false):
				Desk.note(world, "UPGRADE_FACILITY")
				world.add_fact({"type": "POL_PROJECT_ORDERED", "owner": "pol", "subjects": [], "responsible": [{"actor": {"kind": "GOVERNMENT" if who["by"] != "commander" else "COMMANDER", "id": "government"}, "share": 1.0}],
					"impact": {}, "magnitude": 35, "visibility": "PUBLIC", "data": {"type": "UPGRADE", "facility": opts[0]["facility"], "to_tier": opts[0]["next_tier"], "by": who["by"]}})
	# 5. counter-cyclical public works: interventionist and spending governments fight unemployment by building.
	#    Jobs follow output (Bob's E115 trace): idle plants hire nobody, so the jobs have to be created. The more
	#    a government believes in it, and the worse unemployment is, the more it orders per quarter: crowded
	#    housing first, then schools and clinics (a higher bar than the normal programme), then roads (pure works).
	var believer := state + spend
	var unemp := EconFace.firm_colony_unemployment(world)
	if believer > -0.2 and unemp > 0.12 - 0.04 * maxf(0.0, state):
		# conviction scales the programme: a lukewarm government (+0.0) orders 1 project a quarter, a convinced
		# one (+0.5 and up) 4-5; deep unemployment adds one more
		var n_max := 1 + int(round(6.0 * clampf(believer, 0.0, 0.6))) + (1 if unemp > 0.20 else 0)
		var pw := "ECON_BUDGET_PUBLIC_WORKS"
		var cands: Array = []
		for d in CoreUtil.sorted_keys(world.table("district")):
			if float(world.table("district")[d].get("occupancy", 0)) >= 850.0:
				cands.append(["HOUSING", d])
		for key in [["health_access", "CLINIC"], ["edu_access", "SCHOOL"]]:
			var acc: Dictionary = s.get(key[0], {})
			for d in CoreUtil.sorted_keys(acc):
				if float(acc[d]) < 900.0 and not _has_facility(world, key[1], d):
					cands.append([key[1], d])
		var roads: Dictionary = st.get("pw_roads", {})
		var by_pop: Array = CoreUtil.sorted_keys(world.table("district"))
		by_pop.sort_custom(func(a, b): return int(world.table("district")[a].get("households", 0)) > int(world.table("district")[b].get("households", 0)) or (world.table("district")[a].get("households", 0) == world.table("district")[b].get("households", 0) and a < b))
		for d in by_pop:
			if world.month - int(roads.get(d, -999)) >= 24 - int(12.0 * clampf(believer, 0.0, 0.5)):
				cands.append(["ROAD", d])
		var done := 0
		for c in cands:
			if done >= n_max:
				break
			if busy.has(c[0] + "|" + c[1]) or EconFace.actions_headroom(world, pw) < EconFace.construction_estimate(c[0]) * 11 / 10:
				continue
			if _order(world, st, busy, who, c[0], c[1], pw) > 0:
				done += 1
				if c[0] == "ROAD":
					roads[c[1]] = world.month
		st["pw_roads"] = roads


const ROAD_NEED_BAR := 300.0
const ROAD_NEED_GAP := 36


static func _road_needs(world: WorldState, st: Dictionary, busy: Dictionary, who: Dictionary, state: float, spend: float) -> int:
	var needs: Array = Transport.road_needs(world)
	if needs.is_empty():
		return 0
	var bar := clampf(ROAD_NEED_BAR - 200.0 * spend - 100.0 * state, 100.0, 800.0)
	var n_max := 1 + (1 if spend + state > 0.3 else 0)
	var choose := road_works_on(world)
	if choose:
		# freight held back by the roads presses every government, the willing ones harder (a pressure, not a duty)
		var jam := float(FreightRoads.jam_share_pm(world))
		var will := clampf(0.6 + spend + 0.5 * state, 0.2, 1.5)
		bar = clampf(bar - ROAD_JAM_BAR * jam * will, 60.0, 800.0)
		n_max += int(jam * will / ROAD_JAM_PER_ORDER)
		n_max = mini(n_max, ROAD_MAX_ORDERS)
	var done_keys: Dictionary = st.get("road_need_keys", {})
	var line := "ECON_BUDGET_INFRASTRUCTURE"
	var done := 0
	if choose:
		needs = road_ranking(world, needs.filter(func(r): return float(r.get("severity", 0)) >= bar), (st.get("government", {}) as Dictionary).get("members", []))
	for r in needs:
		if done >= n_max or float(r.get("severity", 0)) < bar:
			break
		var key := str(r["key"])
		if world.month - int(done_keys.get(key, -9999)) < ROAD_NEED_GAP:
			continue
		var cost := int(r.get("cost", 0))
		var spec: Dictionary = r["spec"]
		var o := {}
		if choose:
			o = road_option(r.get("options", []), spend, state, EconFace.actions_headroom(world, line))
			if int(r.get("cond", 1000)) < ROAD_REPAIR_FIRST:
				# a badly worn road: repair first (back to full capacity in months), widen later (A/B 2026-11-15,
				# planning/ab-road-works.md: bigger works relieve nothing until they are finished)
				for x in r.get("options", []):
					if String(x["fix"]) == "REPAIR" and int(x["cost"]) * 11 / 10 <= EconFace.actions_headroom(world, line):
						o = x
			if o.is_empty():
				continue
			cost = int(o["cost"])
			spec = o["spec"]
			if int(o["load_after_pm"]) > 1000 and not Desk.on(world):
				_road_patch_fact(world, who, r, o)
		if EconFace.actions_headroom(world, line) < cost * 11 / 10:
			continue
		var placed := _road_case(world, busy, who, r, o, line) if choose and Desk.on(world) 			else _order(world, st, busy, who, "ROAD", str(r["district"]), line, {"link": spec.duplicate(true)})
		if placed > 0:
			done_keys[key] = world.month
			done += 1
			if choose:
				var q: Array = st.get("road_q_orders", [])
				q.append(str(r["district"]))
				st["road_q_orders"] = q
	st["road_need_keys"] = done_keys
	return done


## How people on a bad road take it (user 2026-11-15: "how do the people living on a bad road feel when the government
## prioritises them down?"). Each quarter, looking back at the last one: a district with a badly overloaded or worn
## road and no road work under way has waited another quarter (pol.state["road_wait"]). If the government ordered a
## road elsewhere meanwhile, the district was passed over: POL_ROAD_PASSED_OVER, felt in that district only, worse the
## longer it has waited, and worse again when the road that went first lies where the government's voters live.
## If nothing was ordered anywhere, the district is merely neglected (a milder fact once a year).
const ROAD_FELT_SEV := 300           # a road need at or over this severity is felt by the district
const ROAD_FAVOUR_GAP := 0.05        # the chosen district votes this much more for the government: seen as favouring its own


static func _road_feelings(world: WorldState, st: Dictionary, who: Dictionary) -> void:
	if not road_works_on(world):
		return
	var ordered: Array = st.get("road_q_orders", [])
	st.erase("road_q_orders")
	var wait: Dictionary = st.get("road_wait", {})
	var worst := {}
	for r in Transport.road_needs(world):
		var d := str(r["district"])
		if int(r.get("severity", 0)) >= ROAD_FELT_SEV:
			worst[d] = maxi(int(worst.get(d, 0)), int(r["severity"]))
	var working := {}
	for pid in world.peek("project"):
		var p: Dictionary = world.peek("project")[pid]
		if p["type"] == "ROAD" and p["status"] in ["TENDER", "ACTIVE", "TENDERABLE"]:
			working[String(p["district"])] = true
	for d in CoreUtil.sorted_keys(wait):
		if not worst.has(d) or working.has(d) or ordered.has(d):
			wait.erase(d)
	var members: Array = (st.get("government", {}) as Dictionary).get("members", [])
	var resp := [{"actor": {"kind": "GOVERNMENT" if who["by"] != "commander" else "COMMANDER", "id": "government"}, "share": 1.0}]
	for d in CoreUtil.sorted_keys(worst):
		if working.has(d) or ordered.has(d):
			continue
		var q := int(wait.get(d, 0)) + 1
		wait[d] = q
		var instead := ""
		for o in ordered:
			if String(o) != String(d):
				instead = String(o)
				break
		if instead != "":
			var favoured := not members.is_empty() and _district_share(world, instead, members) > _district_share(world, String(d), members) + ROAD_FAVOUR_GAP
			var impact := {"INFRASTRUCTURE": -(2 + mini(q, 8) / 2)}
			if favoured:
				impact["FAIRNESS"] = -3
			world.add_fact({"type": "POL_ROAD_PASSED_OVER", "owner": "pol", "subjects": [], "responsible": resp, "impact": impact,
				"affected": {"districts": [String(d)]}, "magnitude": 20 + 3 * mini(q, 8) + (10 if favoured else 0), "visibility": "PUBLIC",
				"data": {"district": String(d), "quarters": q, "instead": instead, "favoured": favoured, "severity": int(worst[d]), "by": who["by"]}})
		elif q % 4 == 0:
			world.add_fact({"type": "POL_ROAD_NEGLECTED", "owner": "pol", "subjects": [], "responsible": resp, "impact": {"INFRASTRUCTURE": -2},
				"affected": {"districts": [String(d)]}, "magnitude": 20, "visibility": "PUBLIC",
				"data": {"district": String(d), "quarters": q, "severity": int(worst[d]), "by": who["by"]}})
	if wait.is_empty():
		st.erase("road_wait")
	else:
		st["road_wait"] = wait


## Road works by choice (user 2026-11-15: "roads won't take the new freight ... another job for builders and for the
## government to argue about"). Opt-in flag ROAD_WORKS, on top of FREIGHT_ROADS: the government picks among every way
## to relieve a link or junction (Transport.road_needs "options") by its own character, and freight held back by the
## roads makes it order sooner and more. It may still choose badly: a thrifty government patches.
const ROAD_WORKS_FLAG := "ROAD_WORKS"
const ROAD_REPAIR_FIRST := 400       # condition under which a worn road is repaired before anything bigger
const ROAD_JAM_BAR := 0.5            # the bar falls by this per 1 permille of freight held (times the government's will)
const ROAD_JAM_PER_ORDER := 100.0    # one more road order a quarter per this much held freight (permille, times will)
const ROAD_MAX_ORDERS := 4
const ROAD_GOOD_LOAD := 800          # a fix that leaves the road at or under this load is a cure
const ROAD_AHEAD_LOAD := 600         # a builder government wants room to spare
const ROAD_THRIFTY := -0.2           # fiscal position at or under this: the cheapest thing that stops the jam
const ROAD_BUILDER := 0.5            # spend + state at or over this: build ahead


## The roads' case for the infrastructure budget (probe 2026-11-15: every overloaded road had a cure on offer, but the
## infrastructure line had no headroom for it in most years, so nothing was ordered while 40-60% of freight was held).
## While the roads hold freight back and the line cannot pay for the cheapest cure, the road department reports a need
## for ECON_BUDGET_INFRASTRUCTURE (pol.state["lever_need"], permille, read by Legislature.propose like the regulator's).
## A pressure on the budget vote, which parliament may still refuse.
const ROAD_NEED_JAM := 50            # freight held (permille) from which the roads have a case
const ROAD_NEED_BASE := 500
const ROAD_NEED_PER_JAM := 3


static func _road_budget_need(world: WorldState, st: Dictionary) -> void:
	if not road_works_on(world):
		return
	var ln: Dictionary = st.get("lever_need", {})
	var v := 0
	var jam := FreightRoads.jam_share_pm(world)
	if jam >= ROAD_NEED_JAM:
		var cheapest := -1
		for r in Transport.road_needs(world):
			for o in r.get("options", []):
				if int(o["load_after_pm"]) <= 1000 and (cheapest < 0 or int(o["cost"]) < cheapest):
					cheapest = int(o["cost"])
		if cheapest >= 0 and EconFace.actions_headroom(world, "ECON_BUDGET_INFRASTRUCTURE") < cheapest * 11 / 10:
			v = clampi(ROAD_NEED_BASE + ROAD_NEED_PER_JAM * jam, 0, 2000)
	if v == 0:
		ln.erase("ECON_BUDGET_INFRASTRUCTURE")
	else:
		ln["ECON_BUDGET_INFRASTRUCTURE"] = v
	if ln.is_empty():
		st.erase("lever_need")
	else:
		st["lever_need"] = ln


## Which road first (user 2026-11-15: "road priority, what road is going to help the colony more"). Each need is scored
## by what it would free: the freight the roads held back on it last month (Terra's held_mu, food counted
## ROAD_FOOD_WEIGHT times) per unit of the cheapest cure's cost, relative to the best on the list; plus a share for
## how overloaded it is; plus the government's lean toward districts that vote for it (as with the grant programmes:
## every government leans, and a district passed over for the government's own voters resents it).
## → the needs, best first. Pure.
const ROAD_FOOD_WEIGHT := 3
const ROAD_W_BENEFIT := 1.0
const ROAD_W_SEVERITY := 0.3
const ROAD_W_OWN_VOTERS := 0.4


static func road_benefit(r: Dictionary) -> float:
	var held := 0.0
	var by_good: Dictionary = r.get("held_by_good", {})
	if by_good.is_empty():
		held = float(r.get("held_mu", 0))
	for g in by_good:
		held += float(by_good[g]) * (float(ROAD_FOOD_WEIGHT) if String(g) in ["FOOD", "BREAD"] else 1.0)
	if r.has("bottleneck_mu"):
		# only what this item itself holds back: held freight is credited to every item on a jammed route, but only
		# the route's most loaded item frees it (Terra's bottleneck_mu; A/B 2026-11-15: ranking by held_mu did harm)
		held *= float(r["bottleneck_mu"]) / maxf(1.0, float(r.get("held_mu", 0)))
	var cost := 0
	for o in r.get("options", []):
		if int(o["load_after_pm"]) <= 1000 and (cost == 0 or int(o["cost"]) < cost):
			cost = int(o["cost"])
	if cost <= 0:
		cost = maxi(1, int(r.get("cost", 1)))
	return held / float(cost)


static func road_ranking(world: WorldState, needs: Array, members: Array) -> Array:
	if needs.is_empty():
		return needs
	var top_b := 0.0
	var top_s := 1.0
	for r in needs:
		top_b = maxf(top_b, road_benefit(r))
		top_s = maxf(top_s, float(r.get("severity", 0)))
	var rows: Array = []
	var shares := {}
	for i in needs.size():
		var r: Dictionary = needs[i]
		var d := str(r["district"])
		if not shares.has(d):
			shares[d] = _district_share(world, d, members) if not members.is_empty() else 0.0
		var sc := ROAD_W_SEVERITY * float(r.get("severity", 0)) / top_s + ROAD_W_OWN_VOTERS * float(shares[d])
		if top_b > 0.0:
			sc += ROAD_W_BENEFIT * road_benefit(r) / top_b
		rows.append([sc, i])
	rows.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
	return rows.map(func(x): return needs[x[1]])


## Road tolls paid by commuters are felt as cost of living where they live (PRIVATE_ROADS; Terra's
## Transport.commuter_tolls: last month's tolls by home district, private and public roads together). Once a quarter,
## a district whose commuters paid more than TOLL_FELT_PM of a reference wage per head gets POL_ROAD_TOLLS_FELT,
## felt there only. The government carries half: it allowed the tolls, set the cap, or charges them itself.
const TOLL_FELT_PM := 2              # permille of a reference monthly wage per head from which tolls are noticed
const TOLL_FULL_PM := 20             # ... and at which the feeling is strongest
const TOLL_MAX_IMPACT := 6


static func toll_impact(toll_mcr: int, heads: int, wage_mcr: int) -> int:
	if heads <= 0 or wage_mcr <= 0:
		return 0
	var pm := float(toll_mcr) / float(heads) * 1000.0 / float(wage_mcr)
	if pm < float(TOLL_FELT_PM):
		return 0
	return -maxi(1, int(round(float(TOLL_MAX_IMPACT) * clampf(pm / float(TOLL_FULL_PM), 0.0, 1.0))))


static func _toll_feelings(world: WorldState) -> void:
	if world.month % 3 != QUARTER_MONTH or not PrivateRoads.on(world):
		return
	var tolls: Dictionary = Transport.commuter_tolls(world)
	if tolls.is_empty():
		return
	var heads := {}
	for c in PolVoters.all(world):
		var d := String(c.get("district", ""))
		heads[d] = int(heads.get(d, 0)) + int(c.get("pop", 0))
	var wage: int = load("res://sim/staff/staff_ops.gd").w_ref_milli(world)
	for d in CoreUtil.sorted_keys(tolls):
		var imp := toll_impact(int(tolls[d]), int(heads.get(d, 0)), wage)
		if imp == 0:
			continue
		world.add_fact({"type": "POL_ROAD_TOLLS_FELT", "owner": "pol", "subjects": [],
			"responsible": [{"actor": {"kind": "GOVERNMENT", "id": "government"}, "share": 0.5}], "impact": {"COST_OF_LIVING": imp},
			"affected": {"districts": [String(d)]}, "magnitude": 15 + 3 * absi(imp), "visibility": "PUBLIC",
			"data": {"district": String(d), "tolls_mcr": int(tolls[d]), "heads": int(heads.get(d, 0))}})


## Road works are part of the rebuild and always on (rebuild-company.md 12.4, 33).
static func road_works_on(_world: WorldState = null) -> bool:
	return true


## The option this government takes among `opts` (cheapest first; each {fix, cost, load_after_pm, relief_pm, spec}),
## with `headroom` on the budget line. {} when it can afford none. Pure.
## - thrifty: the cheapest that brings the load to 1000 or under; failing that the cheapest of all (a patch).
## - builder: the cheapest that leaves the load at ROAD_AHEAD_LOAD or under; failing that as the others.
## - others: the cheapest cure (ROAD_GOOD_LOAD or under); failing that the biggest relief.
static func road_option(opts: Array, spend: float, state: float, headroom: int) -> Dictionary:
	var can: Array = opts.filter(func(o): return int(o["cost"]) * 11 / 10 <= headroom)
	if can.is_empty():
		return {}
	var want := ROAD_GOOD_LOAD
	if spend <= ROAD_THRIFTY:
		want = 1000
	elif spend + state >= ROAD_BUILDER:
		want = ROAD_AHEAD_LOAD
	for target in [want, ROAD_GOOD_LOAD] if want < ROAD_GOOD_LOAD else [want]:
		for o in can:
			if int(o["load_after_pm"]) <= int(target):
				return o
	if spend <= ROAD_THRIFTY:
		return can[0]
	var best: Dictionary = can[0]
	for o in can:
		if int(o["relief_pm"]) > int(best["relief_pm"]):
			best = o
	return best


## The government ordered a fix that leaves the road over its capacity: public, and its own doing.
static func _road_patch_fact(world: WorldState, who: Dictionary, r: Dictionary, o: Dictionary) -> void:
	var better := 0
	for x in r.get("options", []):
		if int(x["load_after_pm"]) <= 1000:
			better += 1
	world.add_fact({"type": "POL_ROAD_PATCHED", "owner": "pol", "subjects": [{"kind": "PARTY", "id": who["by"]}] if who["by"] != "commander" else [],
		"responsible": [{"actor": {"kind": "GOVERNMENT" if who["by"] != "commander" else "COMMANDER", "id": "government"}, "share": 1.0}],
		"impact": {}, "magnitude": 25, "visibility": "PUBLIC", "data": {"key": str(r["key"]), "district": str(r["district"]), "fix": String(o["fix"]),
			"cost": int(o["cost"]), "load_after_pm": int(o["load_after_pm"]), "cures_on_offer": better, "by": who["by"]}})


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


static func _order(world: WorldState, st: Dictionary, busy: Dictionary, who: Dictionary, ftype: String, d: String, line: String, extra: Dictionary = {}) -> int:
	if busy.has(ftype + "|" + d):
		return 0
	busy[ftype + "|" + d] = true
	var params := {"type": ftype, "district": d}
	params.merge(extra)
	if line != "":
		params["line"] = line
	if EconFace.actions_validate(world, "ECON_COMMISSION_PROJECT", params) != "":
		return 0   # can't be paid for now: don't announce an order that would fail at execution (Terra's road trace)
	if Desk.on(world):
		return _order_case(world, who, ftype, d, line, params)
	var r: Dictionary = EconFace.actions_enqueue(world, "ECON_COMMISSION_PROJECT", params)
	if not r.get("ok", false):
		return 0
	Desk.note(world, Desk.build_type(ftype, line))
	world.add_fact({"type": "POL_PROJECT_ORDERED", "owner": "pol", "subjects": [{"kind": "PARTY", "id": who["by"]}] if who["by"] != "commander" else [],
		"responsible": [{"actor": {"kind": "GOVERNMENT" if who["by"] != "commander" else "COMMANDER", "id": "government"}, "share": 1.0}],
		"impact": {}, "magnitude": 35, "visibility": "PUBLIC", "data": {"type": ftype, "district": d, "by": who["by"], "line": line}})
	return 1


## Family grant programmes (user 2026-11-15: a grant is a time-limited programme; when it ends the government starts
## over on its level "and where it covers too"). When a programme opens (grant lever above 0 and no coverage set yet),
## the government names the districts it covers: those with the greatest need (EconFace.grant_need: {kind: {d: need}}),
## two by default, more for egalitarian and spending-minded governments. The economy reads the choice through
## GovBuilder.grant_cover() (absent kind = not decided yet, no grants that month), and the entry is dropped when the lever
## is back at 0, so the next programme chooses again. The open programmes and their cover are politics' own memory,
## kept in the politics state (st["grant_prog"], st["grant_cover"]), not in the economy's (rebuild step 2, Ella).
## The truck drivers' and truck workshops' grants (the user, 2026-11-16: "Don't forget the political side") are decided
## the same way: the government names the districts a programme covers, by need and by its politics.
const GRANT_KINDS := {"FARM": "ECON_FAMILY_FARM_GRANT", "BAKERY": "ECON_FAMILY_BAKERY_GRANT",
	"TRUCKER": "ECON_TRUCK_DRIVER_GRANT", "TRUCKSHOP": "ECON_TRUCK_WORKSHOP_GRANT"}
const GRANT_FAVOUR := 0.5   # weight of the governing parties' vote share in a district against its (normalised) need


## The economy's month calls this in COMPANY_AI, after the programmes open and close and before anyone founds, so a
## founder applies to a programme whose sum and districts are already decided (Wilma, 2026-11-18). Nothing without a
## politics state (an economy-only game).
static func grant_programmes(world: WorldState) -> void:
	if not world.peek("pol").has("state"):
		return
	_grant_cover(world, world.table("pol")["state"])


static func _grant_cover(world: WorldState, st: Dictionary) -> void:
	var need_all: Dictionary = EconFace.grant_need(world)
	if need_all.is_empty():
		return   # the economy publishes no grant need yet
	var cover: Dictionary = st.get("grant_cover", {})
	var progs: Dictionary = st.get("grant_prog", {})
	st["grant_prog"] = progs
	for kind in CoreUtil.sorted_keys(GRANT_KINDS):
		var need_d: Dictionary = need_all.get(kind, {})
		if int(world.levers.get(GRANT_KINDS[kind], 0)) <= 0:
			if progs.has(kind):
				_programme_ended(world, st, String(kind), progs[kind])
				progs.erase(kind)
			cover.erase(kind)
			(st.get("grant_sum", {}) as Dictionary).erase(kind)   # a limit, not money set aside: nothing to return
			continue
		# the open programme: who opened it, how long it has run and in how many of those months there was a need
		if not progs.has(kind):
			progs[kind] = {"by": String(_who(world, st).get("by", "")), "start": world.month, "months": 0, "need_m": 0}
			_grant_sum(world, st, String(kind), String(progs[kind]["by"]))
		progs[kind]["months"] = int(progs[kind]["months"]) + 1
		for d0 in need_d:
			if int(need_d[d0]) > 0:
				progs[kind]["need_m"] = int(progs[kind]["need_m"]) + 1
				break
		if cover.has(kind) or (Desk.on(world) and Desk.pending(world, "COVER|" + String(kind))):
			continue
		var ds: Array = []
		for d in CoreUtil.sorted_keys(need_d):
			if int(need_d[d]) > 0:
				ds.append(d)
		if ds.is_empty():
			continue   # nowhere needs it yet: decide when a need appears
		var who := _who(world, st)
		if who.is_empty():
			continue
		var pos: Dictionary = who["pos"]
		var wide := float(pos.get("REDISTRIBUTION", 0)) / 100000.0 + float(pos.get("FISCAL", 0)) / 100000.0
		var n := clampi(2 + int(round(2.0 * wide)), 1, ds.size())
		ds.sort_custom(func(a, b): return int(need_d[a]) > int(need_d[b]) or (int(need_d[a]) == int(need_d[b]) and String(a) < String(b)))
		var fair: Array = ds.slice(0, n)
		# User (2026-11-15): "this is a politics game first, yes voter territory, but that should not be appreciated".
		# An elected government leans toward the districts that voted for it: more so with little regard for
		# institutional norms and in an election year (pork). Need still counts; a district without need is never chosen.
		var chosen: Array = fair
		var members: Array = st.get("government", {}).get("members", [])
		if who["by"] != "commander" and not members.is_empty() and ds.size() > n:
			var inst := float(pos.get("INSTITUTIONS", 0)) / 100000.0
			var favour := clampf(GRANT_FAVOUR * (1.0 - inst), 0.0, 2.0 * GRANT_FAVOUR) * (1.0 + Campaign.pork_pressure(world, st))
			var top := 1.0
			for d in ds:
				top = maxf(top, float(need_d[d]))
			var sc := {}
			for d in ds:
				sc[d] = float(need_d[d]) / top + favour * _district_share(world, String(d), members)
			var ranked: Array = ds.duplicate()
			ranked.sort_custom(func(a, b): return float(sc[a]) > float(sc[b]) or (float(sc[a]) == float(sc[b]) and String(a) < String(b)))
			chosen = ranked.slice(0, n)
		if Desk.on(world):
			_cover_case(world, who, String(kind), fair, chosen, need_d)
			continue
		cover[kind] = chosen
		Logbook.note(world, "GRANT", "government", "cover chosen", {"kind": kind, "need": need_d.duplicate(), "fair": fair},
			{"cover": [[], chosen]}, String(who["by"]), String(GRANT_KINDS[kind]))
		Desk.note(world, "GRANT_COVERAGE")
		var resp := [{"actor": {"kind": "GOVERNMENT" if who["by"] != "commander" else "COMMANDER", "id": "government"}, "share": 1.0}]
		world.add_fact({"type": "POL_GRANT_COVERAGE", "owner": "pol", "subjects": [], "responsible": resp,
			"impact": {}, "magnitude": 25, "visibility": "PUBLIC", "data": {"kind": kind, "districts": chosen, "by": who["by"]}})
		var passed_over: Array = fair.filter(func(d): return not (d in chosen))
		if not passed_over.is_empty():
			# favouring its own voters over needier districts is seen and resented
			world.add_fact({"type": "POL_GRANT_FAVOURITISM", "owner": "pol", "subjects": [], "responsible": resp,
				"impact": {"FAIRNESS": -4, "GOVERNANCE": -3}, "magnitude": 45, "visibility": "PUBLIC",
				"data": {"kind": kind, "favoured": chosen.filter(func(d): return not (d in fair)), "passed_over": passed_over, "by": who["by"]}})
	st["grant_cover"] = cover


## The user (2026-11-17, plan 12.9, 61b): "The government should put a max sum into the grant based on how many farms
## they want maybe a little extra to be sure". When a programme opens the government decides how many plants of the
## kind it wants (Grants.wanted, the starting count) and the programme gets that many grants and a tenth more
## (Grants.budget_for). Each grant paid comes out of it (Grants.sum_left). Politics' memory, st["grant_sum"], dropped
## when the programme ends; a limit on the treasury's spending, so nothing is returned. One Logbook row with the numbers.
static func _grant_sum(world: WorldState, st: Dictionary, kind: String, by: String) -> void:
	var b: Dictionary = Grants.budget_for(world, kind)
	b["start"] = world.month
	var sums: Dictionary = st.get("grant_sum", {})
	sums[kind] = b
	st["grant_sum"] = sums
	Logbook.note(world, "GRANT", "government", "sum set", b.duplicate(), {"sum": [0, int(b["sum"]) / CoreUtil.S]}, by,
		String(GRANT_KINDS[kind]))


## Each open programme's sum, {kind: {wanted, rule, grant, extra, sum, start, ...}}, credits x S. A copy.
static func grant_sum(world: WorldState) -> Dictionary:
	return ((world.peek("pol").get("state", {}) as Dictionary).get("grant_sum", {}) as Dictionary).duplicate(true)


## The districts each open grant programme covers, {kind: [district ids]}, for the economy's grants. A kind that is
## absent is not decided yet: no grant of that kind is given that month. A copy: the economy cannot change the choice.
static func grant_cover(world: WorldState) -> Dictionary:
	return ((world.peek("pol").get("state", {}) as Dictionary).get("grant_cover", {}) as Dictionary).duplicate(true)


## User (2026-11-15): a government loses face when it opens a grant nobody takes up, "it feeds the politics", and
## "they need to not know if it will succeed": nothing here or in the legislature tells a government beforehand whether
## families will apply; it finds out when the programme ends (and its belief in the lever learns from the result like
## any other law, Intel). A programme that paid no grant is a public failure of whoever opened it: a real one when the
## colony needed the food or bread for much of its run, a small embarrassment when it did not.
const GRANT_FAIL_NEED_M := 6
static func _programme_ended(world: WorldState, st: Dictionary, kind: String, rec: Dictionary) -> void:
	var paid := -1
	var level := 0
	for f in world.facts.query("ECON_GRANT_PROGRAMME_ENDED", world.month - 1, world.month):
		if String(f["data"].get("lever", "")) == String(GRANT_KINDS[kind]):
			paid = int(f["data"].get("paid", 0))
			level = int(f["data"].get("level", 0))
	if paid != 0:
		return   # grants were paid (or the end is not on record): no failure
	var needed: bool = int(rec.get("need_m", 0)) >= GRANT_FAIL_NEED_M
	var by := String(rec.get("by", ""))
	var pm := String(st.get("government", {}).get("pm_party", ""))
	var actor := {"kind": "GOVERNMENT", "id": "government"}
	if by == "commander":
		actor = {"kind": "COMMANDER", "id": "government"}
	elif by != "" and by != pm:
		actor = {"kind": "PARTY", "id": by}   # the government that opened it has left office: its party carries it
	world.add_fact({"type": "POL_GRANT_PROGRAMME_FAILED", "owner": "pol", "subjects": [{"kind": "PARTY", "id": by}] if by != "" and by != "commander" else [],
		"responsible": [{"actor": actor, "share": 1.0}], "impact": {"GOVERNANCE": -6, "FAIRNESS": -2} if needed else {"GOVERNANCE": -2},
		"magnitude": 50 if needed else 25, "visibility": "PUBLIC",
		"data": {"kind": kind, "by": by, "level": level, "months": int(rec.get("months", 0)), "need_months": int(rec.get("need_m", 0)), "needed": needed}})


## Share of an economic district's voters that backed the given parties at the last election (0..1).
static func _district_share(world: WorldState, d: String, parties: Array) -> float:
	var v := 0.0
	var n := 0.0
	for c in PolVoters.all(world):
		if String(c.get("district", "")) != d or int(c.get("pop", 0)) <= 0:
			continue
		var sh := 0.0
		for pid in parties:
			sh += float((c.get("prev_share", {}) as Dictionary).get(pid, 0)) / 100000.0
		v += sh * float(c["pop"])
		n += float(c["pop"])
	return v / n if n > 0.0 else 0.0


## E146 bakery commissioning. Need per district = the raw-food share of the wanted bakery portion (EconStaple.raw_pct,
## 0..100). The bar falls for state-minded and egalitarian governments. A colony with no bakery at all has no taste yet
## (raw share 0), so the first one is judged on unfilled staple orders instead. Only with food to spare (no grain, no
## bread), at most one bakery a quarter, none while one is being built.
const BAKERY_BAR := 40.0
static func _bakery_needs(world: WorldState, st: Dictionary, busy: Dictionary, who: Dictionary, state: float, equality: float) -> int:
	if not EconFace.staple_active(world) or state < -0.15:
		return 0
	for pid in world.table("project"):
		var p: Dictionary = world.table("project")[pid]
		if p["type"] == "BAKERY" and p["status"] in ["TENDER", "ACTIVE", "TENDERABLE"]:
			return 0
	var food: Dictionary = EconFace.query_essentials(world).get("FOOD", {})
	if int(food.get("margin_pct", -1)) < 0:
		return 0
	var bar := clampf(BAKERY_BAR - 20.0 * maxf(0.0, state) - 10.0 * maxf(0.0, equality), 20.0, 40.0)
	var s := CoreUtil.st(world)
	var worst := ""
	var worst_v := bar
	for d in CoreUtil.sorted_keys(world.table("district")):
		var v := EconFace.staple_raw_pct(world, d)
		if v > worst_v and not _has_facility(world, "BAKERY", d):
			worst_v = v
			worst = d
	if worst == "" and _count(world, "BAKERY") == 0:
		var sm: Dictionary = s.get("staple_m", {})
		if int(sm.get("want", 0)) > 0 and int(sm.get("got", 0)) * 2 < int(sm.get("want", 0)):
			var best_h := -1
			for d in CoreUtil.sorted_keys(world.table("district")):
				var h := int(world.table("district")[d].get("households", 0))
				if h > best_h:
					best_h = h
					worst = d
	if worst == "":
		return 0
	return _order(world, st, busy, who, "BAKERY", worst, "")


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
			c += int(float(EconData.RECIPES[ftype]["out"][1]) * CoreUtil.S * CoreUtil.fscale(f))
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
	var ess: Dictionary = EconFace.query_essentials(world)
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
		if EconFace.rulesutil_capacity_on(world, ftype):
			continue  # R8_UTILITIES: the utility adds its own capacity on its own market (its rule 5), not the government on nameplate margin
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
			var cap := int(float(EconFace.construction_estimate(ftype)) / float(CoreUtil.S) * float(pct) / 100.0 * 1.5)
			if Desk.on(world):
				_simple_case(world, "BUILDER_GRANT", "GRANT|" + ftype, "Grant for a private %s" % ftype.to_lower(),
					[_case_why(world, ftype, _home(world, ftype), ""), "A %d%% grant for 24 months, up to %d cr, to the builder who adds one." % [pct, maxi(1, cap)]],
					"Offer the grant", {"via": "ECON", "id": "ECON_OFFER_INCENTIVE", "params": {"type": ftype, "grant_pct": pct, "months": 24, "cap": maxi(1, cap)}}, -CASE_LEAN)
			elif EconFace.actions_enqueue(world, "ECON_OFFER_INCENTIVE", {"type": ftype, "grant_pct": pct, "months": 24, "cap": maxi(1, cap)}).get("ok", false):
				Desk.note(world, "BUILDER_GRANT")


## The government's answer to a public company's tariff proposal (price rules 1/2 of the utilities and the transport
## authority: the company proposes on its own market, the government decides; the user's order 2026-11-16 that every
## producer has all eight rules. Before this no computer government ever answered, so a proposal froze the tariff).
## A government approves a rise once the proposal has waited as long as its reluctance: egalitarian and state-minded
## governments wait longer (a dearer tariff is a cost of living), every government waits longer close to an election.
## Until then the company runs short and asks for support; that is the government's to live with. Under DELEGATION it
## is a case on the desk. The numbers are Wilma's.
const TARIFF_WAIT_EQUALITY_M := 4.0   # months of waiting per unit of REDISTRIBUTION (-1..1)
const TARIFF_WAIT_STATE_M := 3.0      # months per unit of ECON_ROLE (-1..1)
const TARIFF_WAIT_ELECTION_M := 6.0   # extra months inside the last TARIFF_ELECTION_WINDOW_M before an election
const TARIFF_ELECTION_WINDOW_M := 6


static func _tariff_proposals(world: WorldState, state: float, equality: float) -> void:
	var pend: Dictionary = EconFace.publicco_pending(world)
	if pend.is_empty():
		return
	var to_go := Campaign.months_to_election(world)
	var wait_m := TARIFF_WAIT_EQUALITY_M * equality + TARIFF_WAIT_STATE_M * state
	if to_go >= 0 and to_go <= TARIFF_ELECTION_WINDOW_M:
		wait_m += TARIFF_WAIT_ELECTION_M
	for oid in CoreUtil.sorted_keys(pend):
		var pr: Dictionary = pend[oid]
		var o: Dictionary = world.peek("org").get(oid, {})
		if o.is_empty():
			continue
		if Desk.on(world):
			var lines: Array = ["%s asks to raise its charges: its last 12 months fell %d cr short of its costs." % [String(o.get("name", oid)), int(pr.get("gap12", 0))]]
			for c in pr.get("levers", []):
				lines.append("%s: %d to %d." % [String(c[0]), int(c[1]), int(c[2])])
			_simple_case(world, "TARIFF_PROPOSAL", "TARIFF|" + String(oid), "A dearer tariff for %s" % String(o.get("name", oid)), lines,
				"Approve the rise", {"via": "ECON", "id": "ECON_APPROVE_TARIFF", "params": {"org": oid}}, -CASE_LEAN)
			continue
		var waited := float(world.month - int(pr.get("since", pr.get("month", world.month))))
		if waited < wait_m:
			continue
		if EconFace.actions_enqueue(world, "ECON_APPROVE_TARIFF", {"org": oid}).get("ok", false):
			Desk.note(world, "TARIFF_PROPOSAL")


static func _home(world: WorldState, ftype: String) -> String:
	for fid in CoreUtil.sorted_keys(world.table("facility")):
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


## The port keeps filling before the ships come (v5 review: exports capped at 40% of the warehouse per good): a
## government that wants the trade builds another depot at the landing. Market-minded ones leave it to the trade.
static func _port_depot(world: WorldState, st: Dictionary, busy: Dictionary, who: Dictionary, state: float, spend: float) -> void:
	if state + spend < -0.3:
		return
	var full := world.facts.query("ECON_PORT_FULL", world.month - 30, world.month).size()
	if full < 2:
		return
	for pid in world.table("project"):
		var p: Dictionary = world.table("project")[pid]
		if p["type"] == "DEPOT" and p["status"] in ["TENDER", "ACTIVE", "TENDERABLE"]:
			return
	_order(world, st, busy, who, "DEPOT", "d:1", "")


static func _housing_ahead(world: WorldState, st: Dictionary, busy: Dictionary, who: Dictionary, state: float) -> int:
	var f: Dictionary = EconFace.query_demography(world)
	if f.is_empty():
		return 0
	var units := float(f.get("housing_units", 0))
	var occ := float(f.get("occupancy_pct", 0)) / 100.0
	var forming := float(f.get("households_forming_12m", 0))
	var horizon := 1.0 + 2.0 * clampf(state + 0.3, 0.0, 1.0)            # 1 to 3 years ahead
	var free := units * (1.0 - occ)
	var needed := forming * horizon - free
	if needed <= 0.0 or units <= 0.0:
		return 0
	var blocks := 0.0  # E120 lots: a lot is a part-block (facility scale), so count blocks, not facilities
	for fid in world.table("facility"):
		var hf: Dictionary = world.table("facility")[fid]
		if hf["type"] == "HOUSING" and not hf.get("mothball", false):
			blocks += CoreUtil.fscale(hf)
	var per_block := units / maxf(1.0, blocks)
	if state > -0.15:
		var best := ""
		var best_v := -1.0
		for d in CoreUtil.sorted_keys(world.table("district")):
			var o := float(world.table("district")[d].get("occupancy", 0))
			if o > best_v and not busy.has("HOUSING|" + d):
				best_v = o
				best = d
		if best == "":
			return 0
		var n := mini(2, int(ceil(needed / maxf(1.0, per_block))))
		var done := 0
		for _i in n:
			done += _order(world, st, busy, who, "HOUSING", best, "")
			if done == 0:
				break
		return done
	if EconFace.essentials_offers(world).has("HOUSING"):
		return 0
	var cap := int(float(EconFace.construction_estimate("HOUSING")) / float(CoreUtil.S) * 0.3 * 1.5)
	if Desk.on(world):
		_simple_case(world, "BUILDER_GRANT", "GRANT|HOUSING", "Grant for private housing",
			["Households are forming faster than homes are free.", "A 30%% grant for 24 months, up to %d cr, to developers who build." % maxi(1, cap)],
			"Offer the grant", {"via": "ECON", "id": "ECON_OFFER_INCENTIVE", "params": {"type": "HOUSING", "grant_pct": 30, "months": 24, "cap": maxi(1, cap)}}, -CASE_LEAN)
	elif EconFace.actions_enqueue(world, "ECON_OFFER_INCENTIVE", {"type": "HOUSING", "grant_pct": 30, "months": 24, "cap": maxi(1, cap)}).get("ok", false):
		Desk.note(world, "BUILDER_GRANT")
	return 0


# ======================================================================= who decides (flag DELEGATION, step 3)
## planning/design-delegation.md (Maja). With DELEGATION every order, road fix and grant coverage is a case of its
## decision type: the minister holding the type makes the call, or the case waits on the First Minister's desk
## (Desk.decide). The options carry what the government knows this month: the need, the estimate, the fixes on offer.
## merit = the government's own pick (CASE_MERIT; alternatives less), lean = which politics each option serves.
## A human government's ministers propose too; every decision of the programme is a case (re-tenders, the food
## reserve, workshop upgrades and builder grants as yes / not-now cases).
const CASE_MERIT := 30
const CASE_ALT_MERIT := 15
const CASE_LEAN := 2000      # ECON_ROLE (OfficeFeed.ai_answer's scale): building leans state, waiting market


## The government that decides: _actor, and with DELEGATION also a human government (its ministers propose).
static func _who(world: WorldState, st: Dictionary) -> Dictionary:
	var who := _actor(world, st)
	if who.is_empty() and Desk.on(world):
		who = _actor_human(world, st)
	return who


static func _actor_human(world: WorldState, st: Dictionary) -> Dictionary:
	if st.get("era", "") == "FOUNDING":
		return {"pos": st.get("revealed", {}), "by": "commander", "own_services": 0, "own_housing": 0, "human": true}
	var g: Dictionary = st.get("government", {})
	if g.is_empty():
		return {}
	var pm: Dictionary = world.table("party").get(g.get("pm_party", ""), {})
	return {"pos": g.get("center", {}), "by": g.get("pm_party", ""), "human": true,
		"own_services": int(pm.get("ownership", {}).get("PUBLIC_SERVICES", 0)),
		"own_housing": int(pm.get("ownership", {}).get("HOUSING", 0))}


static func _dname(world: WorldState, d: String) -> String:
	return String(world.peek("district").get(d, {}).get("name", d))


static func _cr(money: int) -> String:
	return "%d cr" % (money / CoreUtil.S)


## Why the government wants this order, from what it knows this month.
static func _case_why(world: WorldState, ftype: String, d: String, line: String) -> String:
	var s := CoreUtil.st(world)
	if line == "ECON_BUDGET_PUBLIC_WORKS":
		return "Unemployment is %d%%: public works would put people to work." % int(round(EconFace.firm_colony_unemployment(world) * 100.0))
	match ftype:
		"HOUSING":
			return "Homes in %s are %d%% full." % [_dname(world, d), int(float(world.peek("district").get(d, {}).get("occupancy", 0)) / 10.0)]
		"SCHOOL":
			return "School access in %s is %d%%." % [_dname(world, d), int(float(s.get("edu_access", {}).get(d, 0)) / 10.0)]
		"CLINIC":
			return "Clinic access in %s is %d%%." % [_dname(world, d), int(float(s.get("health_access", {}).get(d, 0)) / 10.0)]
	var good := ""
	for g in ESS_PLANT:
		if String(ESS_PLANT[g]) == ftype:
			good = String(g)
	if good != "":
		var e: Dictionary = EconFace.query_essentials(world).get(good, {})
		return "%s: the colony's spare capacity is %d%%." % [good.capitalize(), int(e.get("margin_pct", 0))]
	return "The %s is short of a %s." % [_dname(world, d), ftype.to_lower().replace("_", " ")]


## An order as a case: order it now, or not now. Returns 1 when ordered or waiting on the desk (the caller books it
## as placed), 0 when the decision was not now or the order failed.
static func _order_case(world: WorldState, who: Dictionary, ftype: String, d: String, line: String, params: Dictionary) -> int:
	var ref := "ORDER|%s|%s|%s" % [ftype, d, line]
	if Desk.pending(world, ref):
		return 1
	var ty := Desk.build_type(ftype, line)
	var act := {"via": "DESK", "id": "GOV_ORDER", "params": {"params": params.duplicate(true), "by": String(who["by"])}}
	var spec := {"type": ty, "ref": ref, "subject": "%s in %s" % [String(Desk.TYPES[ty]["name"]), _dname(world, d)],
		"lines": [_case_why(world, ftype, d, line), "Estimate: %s." % _cr(EconFace.construction_estimate(ftype))],
		"options": [{"id": "ORDER", "label": "Order it", "action": act}, {"id": "WAIT", "label": "Not now", "action": {}}],
		"hidden": {"ORDER": {"merit": CASE_MERIT, "lean": {"ECON_ROLE": CASE_LEAN}}, "WAIT": {"merit": 0, "lean": {"ECON_ROLE": -CASE_LEAN}}},
		"default": "WAIT"}
	var r := Desk.decide(world, spec)
	return 1 if r == "PENDING" or r == "ORDER" else 0


## A road need as a case (ROAD_WORKS): each fix the budget line can pay for, or not now. The government's own pick
## (road_option) is `o`.
static func _road_case(world: WorldState, busy: Dictionary, who: Dictionary, r: Dictionary, o: Dictionary, line: String) -> int:
	var d := str(r["district"])
	if busy.has("ROAD|" + d):
		return 0
	busy["ROAD|" + d] = true
	var ref := "ROAD|" + str(r["key"])
	if Desk.pending(world, ref):
		return 1
	var head := EconFace.actions_headroom(world, line)
	var opts: Array = []
	var hid := {}
	var i := 0
	for x in r.get("options", []):
		i += 1
		if int(x["cost"]) * 11 / 10 > head:
			continue
		var params := {"type": "ROAD", "district": d, "line": line, "link": (x["spec"] as Dictionary).duplicate(true)}
		if EconFace.actions_validate(world, "ECON_COMMISSION_PROJECT", params) != "":
			continue
		var oid := "FIX_%d" % i
		opts.append({"id": oid, "label": "%s (%s, %d months; load after %d%%)" % [String(x["fix"]).to_lower().replace("_", " "), _cr(int(x["cost"])),
			int(x.get("months", 0)), int(x["load_after_pm"]) / 10],
			"action": {"via": "DESK", "id": "GOV_ORDER", "params": {"params": params, "by": String(who["by"]), "need": r.duplicate(true), "opt": (x as Dictionary).duplicate(true)}}})
		hid[oid] = {"merit": CASE_MERIT if x == o else CASE_ALT_MERIT, "lean": {"ECON_ROLE": CASE_LEAN} if x == o else {}}
	if opts.is_empty():
		return 0
	opts.append({"id": "WAIT", "label": "Not now", "action": {}})
	hid["WAIT"] = {"merit": 0, "lean": {"ECON_ROLE": -CASE_LEAN}}
	var spec := {"type": "BUILD_ROAD", "ref": ref, "subject": "Road works in %s" % _dname(world, d),
		"lines": ["A road in %s is at %d%% of its capacity%s." % [_dname(world, d), int(r.get("load_pm", 0)) / 10,
			(" and worn (%d%%)" % (int(r.get("cond", 1000)) / 10)) if int(r.get("cond", 1000)) < 600 else ""],
			"The fixes the infrastructure budget can pay for now are listed."],
		"options": opts, "hidden": hid, "default": "WAIT"}
	var res := Desk.decide(world, spec)
	return 1 if res == "PENDING" or res.begins_with("FIX_") else 0


## Where an open family grant programme lands, as a case: the neediest districts, or (when the government's pick
## differs) the ones its politics favours.
static func _cover_case(world: WorldState, who: Dictionary, kind: String, fair: Array, chosen: Array, need_d: Dictionary) -> void:
	var names := func(ds: Array) -> String: return ", ".join(PackedStringArray(ds.map(func(x): return _dname(world, String(x)))))
	var base := {"kind": kind, "fair": fair.duplicate(), "by": String(who["by"])}
	var opts: Array = []
	var hid := {}
	var p_need := base.duplicate(true)
	p_need["districts"] = fair.duplicate()
	opts.append({"id": "NEED", "label": "The neediest: %s" % names.call(fair), "action": {"via": "DESK", "id": "GOV_COVER", "params": p_need}})
	hid["NEED"] = {"merit": CASE_MERIT if chosen == fair else CASE_ALT_MERIT, "lean": {}}
	if chosen != fair:
		var p_fav := base.duplicate(true)
		p_fav["districts"] = chosen.duplicate()
		opts.append({"id": "FAVOUR", "label": "%s (our voters' districts)" % names.call(chosen), "action": {"via": "DESK", "id": "GOV_COVER", "params": p_fav}})
		hid["FAVOUR"] = {"merit": CASE_MERIT, "lean": {}}
	var lines: Array = ["A family %s grant programme is open; it pays nothing until we say where it applies." % kind.to_lower()]
	var needs: Array = []
	for d in CoreUtil.sorted_keys(need_d):
		if int(need_d[d]) > 0:
			needs.append("%s %d" % [_dname(world, String(d)), int(need_d[d])])
	lines.append("Need by district: %s." % ", ".join(PackedStringArray(needs)))
	Desk.decide(world, {"type": "GRANT_COVERAGE", "ref": "COVER|" + kind, "subject": "Where the family %s grants go" % kind.to_lower(),
		"lines": lines, "options": opts, "hidden": hid, "default": "NEED"})


## Desk route GOV_ORDER: the order, as _order placed it (validated again: money may have moved since).
static func commit_order(world: WorldState, p: Dictionary) -> Dictionary:
	var params: Dictionary = p.get("params", {})
	var err := EconFace.actions_validate(world, "ECON_COMMISSION_PROJECT", params)
	if err != "":
		return {"ok": false, "error": err}
	var r: Dictionary = EconFace.actions_enqueue(world, "ECON_COMMISSION_PROJECT", params)
	if not r.get("ok", false):
		return r
	var by := String(p.get("by", ""))
	var who := {"by": by}
	world.add_fact({"type": "POL_PROJECT_ORDERED", "owner": "pol", "subjects": [{"kind": "PARTY", "id": by}] if by != "commander" else [],
		"responsible": [{"actor": {"kind": "GOVERNMENT" if by != "commander" else "COMMANDER", "id": "government"}, "share": 1.0}],
		"impact": {}, "magnitude": 35, "visibility": "PUBLIC", "data": {"type": String(params.get("type", "")), "district": String(params.get("district", "")),
			"by": by, "line": String(params.get("line", ""))}})
	if p.has("opt") and int((p["opt"] as Dictionary).get("load_after_pm", 0)) > 1000:
		_road_patch_fact(world, who, p["need"], p["opt"])
	return {"ok": true, "error": ""}


## Desk route GOV_COVER: the programme's districts (nothing when the programme closed meanwhile).
static func commit_cover(world: WorldState, p: Dictionary) -> Dictionary:
	var kind := String(p.get("kind", ""))
	if not GRANT_KINDS.has(kind) or int(world.levers.get(GRANT_KINDS[kind], 0)) <= 0:
		return {"ok": true, "error": ""}
	var s: Dictionary = world.table("pol")["state"]
	var cover: Dictionary = s.get("grant_cover", {})
	var chosen: Array = (p.get("districts", []) as Array).duplicate()
	var fair: Array = p.get("fair", [])
	var by := String(p.get("by", ""))
	cover[kind] = chosen
	s["grant_cover"] = cover
	Logbook.note(world, "GRANT", "government", "cover chosen", {"kind": kind, "fair": fair, "on": "the decision desk"},
		{"cover": [[], chosen]}, by, String(GRANT_KINDS[kind]))
	var resp := [{"actor": {"kind": "GOVERNMENT" if by != "commander" else "COMMANDER", "id": "government"}, "share": 1.0}]
	world.add_fact({"type": "POL_GRANT_COVERAGE", "owner": "pol", "subjects": [], "responsible": resp,
		"impact": {}, "magnitude": 25, "visibility": "PUBLIC", "data": {"kind": kind, "districts": chosen, "by": by}})
	var passed_over: Array = fair.filter(func(d): return not (d in chosen))
	if not passed_over.is_empty():
		world.add_fact({"type": "POL_GRANT_FAVOURITISM", "owner": "pol", "subjects": [], "responsible": resp,
			"impact": {"FAIRNESS": -4, "GOVERNANCE": -3}, "magnitude": 45, "visibility": "PUBLIC",
			"data": {"kind": kind, "favoured": chosen.filter(func(d): return not (d in fair)), "passed_over": passed_over, "by": by}})
	return {"ok": true, "error": ""}


## Who decides, step 3 (the rest of the programme): a yes / not-now case for the decisions above that act through one
## economy action. `lean` = the ECON_ROLE lean of saying yes (not now leans the other way).
static func _simple_case(world: WorldState, ty: String, ref: String, subject: String, lines: Array, yes_label: String, action: Dictionary, lean: int, extra: Array = []) -> void:
	if Desk.pending(world, ref):
		return
	var opts: Array = [{"id": "YES", "label": yes_label, "action": action}, {"id": "WAIT", "label": "Not now", "action": {}}]
	var hid := {"YES": {"merit": CASE_MERIT, "lean": {"ECON_ROLE": lean}}, "WAIT": {"merit": 0, "lean": {"ECON_ROLE": -lean}}}
	for x in extra:
		opts.append({"id": x["id"], "label": x["label"], "action": x["action"]})
		hid[x["id"]] = {"merit": int(x.get("merit", 0)), "lean": x.get("lean", {})}
	Desk.decide(world, {"type": ty, "ref": ref, "subject": subject, "lines": lines, "options": opts, "hidden": hid, "default": "WAIT"})


## A public project nobody bid for: tender it again, leave it, or cancel it.
static func _retender_case(world: WorldState, pid: String, p: Dictionary) -> void:
	var ftype := String(p.get("type", ""))
	var d := String(p.get("district", ""))
	var lines: Array = ["No builder bid for the %s in %s (tendered %d time(s); estimate %s)." % [ftype.to_lower().replace("_", " "), _dname(world, d),
		int(p.get("tenders", 1)), _cr(int(p.get("est_cost", 0)))],
		"%d builder(s) are working in the colony." % _builders(world)]
	_simple_case(world, "RETENDER_PROJECT", "RETENDER|" + pid, "Tender again: %s in %s" % [ftype.to_lower().replace("_", " "), _dname(world, d)], lines,
		"Tender it again", {"via": "ECON", "id": "ECON_RETENDER_PROJECT", "params": {"project": pid}}, 0,
		[{"id": "CANCEL", "label": "Cancel the project", "action": {"via": "ECON", "id": "ECON_CANCEL_PROJECT", "params": {"project": pid}},
			"merit": 0, "lean": {"ECON_ROLE": -CASE_LEAN}}])


static func _builders(world: WorldState) -> int:
	var n := 0
	for oid in world.peek("org"):
		var o: Dictionary = world.peek("org")[oid]
		if bool(o.get("is_contractor", false)) and String(o.get("status", "")) in ["ACTIVE", "DISTRESSED"]:
			n += 1
	return n


## Desk route GOV_UPGRADE: the workshop upgrade, as the programme ordered it.
static func commit_upgrade(world: WorldState, p: Dictionary) -> Dictionary:
	var r: Dictionary = EconFace.actions_enqueue(world, "ECON_UPGRADE_FACILITY", {"facility": String(p.get("facility", "")), "line": "ECON_BUDGET_INFRASTRUCTURE"})
	if not r.get("ok", false):
		return r
	var by := String(p.get("by", ""))
	world.add_fact({"type": "POL_PROJECT_ORDERED", "owner": "pol", "subjects": [], "responsible": [{"actor": {"kind": "GOVERNMENT" if by != "commander" else "COMMANDER", "id": "government"}, "share": 1.0}],
		"impact": {}, "magnitude": 35, "visibility": "PUBLIC", "data": {"type": "UPGRADE", "facility": String(p.get("facility", "")), "to_tier": p.get("to_tier", 0), "by": by}})
	return {"ok": true, "error": ""}


## Re-tendering (Wilma, 2026-11-15: the same stuck project was re-tendered every quarter, 400-1000 times a century):
## a public project nobody bid for is tendered again at most once every RETENDER_GAP_M months, sooner only when
## something changed that could bring a bid: more headroom on its budget line, more builders working, a lower
## estimate. pol.state["retender_m"] = {project id: {m, head, b, est}} (dropped once the project leaves the tender).
## Off for A/B with world.meta["off"] has "RETENDER_YEARLY".
const RETENDER_GAP_M := 12


static func _retender_due(world: WorldState, st: Dictionary, pid: String, p: Dictionary) -> bool:
	if CoreUtil.off(world, "RETENDER_YEARLY"):
		return true
	var memo: Dictionary = st.get("retender_m", {})
	var line := String(p.get("line", ""))
	var now := {"m": world.month, "head": EconFace.actions_headroom(world, line) if line != "" else 0, "b": _builders(world), "est": int(p.get("est_cost", 0))}
	var was: Dictionary = memo.get(pid, {})
	var due: bool = was.is_empty() or world.month - int(was["m"]) >= RETENDER_GAP_M or int(now["head"]) > int(was["head"]) \
		or int(now["b"]) > int(was["b"]) or int(now["est"]) < int(was["est"])
	if due:
		memo[pid] = now
		st["retender_m"] = memo
	return due


static func _retender_prune(world: WorldState, st: Dictionary) -> void:
	if not st.has("retender_m"):
		return
	var memo: Dictionary = st["retender_m"]
	for pid in CoreUtil.sorted_keys(memo):
		if not (String(world.peek("project").get(pid, {}).get("status", "")) in ["TENDER", "TENDERABLE"]):
			memo.erase(pid)


## Road safety (Terra's ROAD_SAFETY), as cases from the start (with DELEGATION; nothing decides them without it). Each
## quarter the SAFETY_CASES worst links where fast traffic meets people on foot (Transport.safety_needs) get up to two
## cases: SPEED_LIMIT (a limit, at once and free, or no change) and ROAD_PASS (an over- or underpass at the worst spot,
## or a bypass, that the infrastructure line can pay for now, or not now). A link is brought again at most once every
## SAFETY_GAP_M months (pol.state["safety_case_m"] {key: month}). Merit = the share of the danger an option removes,
## less the slowdown a limit costs or the share of the line's headroom a work takes.
const SAFETY_CASES := 2
const SAFETY_GAP_M := 12


static func _safety_cases(world: WorldState, st: Dictionary, who: Dictionary) -> void:
	var seen: Dictionary = st.get("safety_case_m", {})
	var line := "ECON_BUDGET_INFRASTRUCTURE"
	var n := 0
	for r in Transport.safety_needs(world):
		if n >= SAFETY_CASES:
			break
		var lid := String(r["link"])
		var rpm := maxi(1, int(r["risk_pm"]))
		var place := _dname(world, String(r.get("district", "")))
		var lines: Array = ["A %d km/h road near %s passes %d people's places on foot: about %.1f accidents a year (%.1f deaths)." % [int(r["kmh"]), place,
			int(r["people"]), float(rpm) / 1000.0, float(int(r.get("deaths_pm", 0))) / 1000.0]]
		var lim: Array = []
		var hid_l := {}
		var works: Array = []
		var hid_w := {}
		var head := EconFace.actions_headroom(world, line)
		for o in r.get("options", []):
			var cut := float(rpm - int(o["risk_after_pm"])) / float(rpm)
			if String(o["type"]) == "LIMIT":
				var k := int(o["spec"]["kmh"])
				var label := "No limit" if k == 0 else "Limit it to %d km/h" % k
				if SafetyLaw.exempts(world, lid, k):
					label += " (exempts it from the law's limit near homes)"   # Anni: the law marks the road exempt; a death there is ours
				lim.append({"id": String(o["fix"]), "label": "%s (accidents %+d%%, %d trip-hours a month)" % [label, -roundi(100.0 * cut), int(o.get("hours_lost", 0))],
					"action": {"via": "DESK", "id": "SAFE_LIMIT", "params": {"link": lid, "kmh": k}}})
				var slow := float(int(r["kmh"]) - k) / float(maxi(1, int(r["kmh"]))) if k > 0 else 0.0
				hid_l[String(o["fix"])] = {"merit": roundi(CASE_MERIT * cut - CASE_ALT_MERIT * slow), "lean": {"ECON_ROLE": CASE_LEAN}}
			elif int(o["cost"]) * 11 / 10 <= head:
				var params := {"type": "ROAD", "district": String(r.get("district", "")), "line": line, "link": (o["spec"] as Dictionary).duplicate(true)}
				if EconFace.actions_validate(world, "ECON_COMMISSION_PROJECT", params) != "":
					continue
				works.append({"id": String(o["fix"]), "label": "%s (%s, %d months; accidents %+d%%)" % [String(o["fix"]).capitalize(), _cr(int(o["cost"])), int(o["months"]), -roundi(100.0 * cut)],
					"action": {"via": "DESK", "id": "GOV_ORDER", "params": {"params": params, "by": String(who["by"])}}})
				hid_w[String(o["fix"])] = {"merit": roundi(CASE_MERIT * cut - CASE_ALT_MERIT * float(o["cost"]) / float(maxi(1, head))), "lean": {"ECON_ROLE": CASE_LEAN}}
		var raised := false
		if not lim.is_empty() and world.month - int(seen.get("L|" + lid, -9999)) >= SAFETY_GAP_M and not Desk.pending(world, "SAFE_LIMIT|" + lid):
			lim.append({"id": "WAIT", "label": "No change", "action": {}})
			hid_l["WAIT"] = {"merit": 0, "lean": {"ECON_ROLE": -CASE_LEAN}}
			Desk.decide(world, {"type": "SPEED_LIMIT", "ref": "SAFE_LIMIT|" + lid, "subject": "Speed on the road near %s" % place,
				"lines": lines, "options": lim, "hidden": hid_l, "default": "WAIT"})
			seen["L|" + lid] = world.month
			raised = true
		if not works.is_empty() and world.month - int(seen.get("P|" + lid, -9999)) >= SAFETY_GAP_M and not Desk.pending(world, "SAFE_PASS|" + lid):
			works.append({"id": "WAIT", "label": "Not now", "action": {}})
			hid_w["WAIT"] = {"merit": 0, "lean": {"ECON_ROLE": -CASE_LEAN}}
			Desk.decide(world, {"type": "ROAD_PASS", "ref": "SAFE_PASS|" + lid, "subject": "A safe crossing near %s" % place,
				"lines": lines, "options": works, "hidden": hid_w, "default": "WAIT"})
			seen["P|" + lid] = world.month
			raised = true
		if raised:
			n += 1
	if not seen.is_empty():
		st["safety_case_m"] = seen


## R8_INSTITUTIONS (Maja; planning/eight-rules.md, public institutions): rules 5 and 6 are the government's. Each
## quarter: up to two clinics or schools where EconInstitutions.build_needs says the open plants cannot hold the
## clients (a district that already has one can get another); a mothballed plant in such a district is reopened
## instead; one plant that has stood empty for a year is closed (never the last of its district, never while anyone
## in reach is unserved). Under DELEGATION the reopenings and closings are INSTITUTION_SITE cases and a due budget
## request is an INSTITUTION_BUDGET case (its "yes" tables the bill); without it the budget goes through the
## legislature's need signal (st["lever_need"]) alone.
static func _inst_builds(world: WorldState, st: Dictionary, busy: Dictionary, who: Dictionary) -> int:
	# no count of ours: as many as the line's headroom pays for (orders queued this quarter are not committed yet, so
	# they are counted here), the most unserved first; the builders' quotes then decide what gets built
	var orders := 0
	var room := {}
	for b in EconFace.inst_build_needs(world):
		var typ := String(b["type"])
		if int(b["mothballed"]) > 0 or busy.has(typ + "|" + String(b["district"])):
			continue
		var line := String(EconFace.ACTIONS_LINE_OF.get(typ, "ECON_BUDGET_INFRASTRUCTURE"))
		if not room.has(line):
			room[line] = EconFace.actions_headroom(world, line)
		var cost := EconFace.construction_estimate(typ) * 11 / 10
		if cost > int(room[line]):
			continue
		var n := _order(world, st, busy, who, typ, String(b["district"]), "")
		if n > 0:
			room[line] = int(room[line]) - cost
		orders += n
	return orders


static func _inst_sites(world: WorldState) -> void:
	for b in EconFace.inst_build_needs(world):
		if int(b["mothballed"]) <= 0:
			continue
		var fid := _inst_closed(world, String(b["type"]), String(b["district"]))
		if fid == "":
			continue
		var what := "%s in %s" % [String(b["type"]).to_lower(), _dname(world, String(b["district"]))]
		if Desk.on(world):
			_simple_case(world, "INSTITUTION_SITE", "INST_SITE|" + fid, "Reopen the " + what,
				["Its district has %d people to serve and room for %d at a full crew." % [int(b["clients"]), int(b["capacity"])]], "Reopen it",
				{"via": "DESK", "id": "INST_REOPEN", "params": {"facility": fid}}, CASE_LEAN)
		elif EconFace.inst_reopen(world, fid).get("ok", false):
			Desk.note(world, "INSTITUTION_SITE")
		break
	for c in EconFace.inst_close_candidates(world):
		var fid2 := String(c["fid"])
		var what2 := "%s in %s" % [String(c["type"]).to_lower(), _dname(world, String(c["district"]))]
		if Desk.on(world):
			_simple_case(world, "INSTITUTION_SITE", "INST_SITE|" + fid2, "Close the " + what2,
				["It has stood at a core crew for a year; the other plants in the district can serve all its people."], "Close it",
				{"via": "DESK", "id": "INST_CLOSE", "params": {"facility": fid2}}, -CASE_LEAN)
		elif EconFace.inst_close(world, fid2).get("ok", false):
			Desk.note(world, "INSTITUTION_SITE")
		break
	if not Desk.on(world):
		return
	for q in EconFace.inst_budget_requests(world):
		if not bool(q["due"]) or Desk.pending(world, "INST_BUDGET|" + String(q["line"])):
			continue
		var up := int(q["ask"]) > int(q["now"])
		var fee := String(q.get("kind", "budget")) != "budget"
		_simple_case(world, "INSTITUTION_FEE" if fee else "INSTITUTION_BUDGET", "INST_BUDGET|" + String(q["line"]),
			("Tax bracket proposal: %s" if fee else "Budget request: %s") % EconFace.QUERY_LINE_LABELS.get(String(q["line"]), String(q["line"])),
			["The service asks for %d a year (now %d)%s." % [int(q["ask"]), int(q["now"]), (": %d people go unserved" % int(q["unmet"])) if up else ": its clients need less"]],
			"Table a bill: %d -> %d" % [int(q["now"]), int(q["ask"])],
			{"via": "DESK", "id": "INST_BUDGET", "params": {"line": String(q["line"]), "from": int(q["now"]), "to": int(q["ask"])}}, CASE_LEAN if up else -CASE_LEAN)
		EconFace.inst_answered(world, String(q["line"]), -1)   # the request is with the government now


static func _inst_closed(world: WorldState, typ: String, d: String) -> String:
	for fid in CoreUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] == typ and String(f["district"]) == d and f["mothball"] and not bool(f.get("closed_unsafe", false)):
			return String(fid)
	return ""


## Desk route INST_BUDGET: table the requested budget (nothing if the line moved or a bill on it is pending).
static func commit_inst_budget(world: WorldState, p: Dictionary) -> Dictionary:
	var st: Dictionary = world.table("pol")["state"]
	var g: Dictionary = st.get("government", {})
	var line := String(p.get("line", ""))
	if g.is_empty() or int(CoreUtil.lever(world, line, 0)) != int(p.get("from", -1)) or Legislature._pending_for(world, line):
		return {"ok": true, "error": ""}
	var cs := Intel.picture(world, "gov")
	Legislature.submit_bill(world, [{"lever": line, "from": int(p["from"]), "to": int(p["to"])}], g, cs[0], cs[1], world.new_id("bill"), 50)
	return {"ok": true, "error": ""}

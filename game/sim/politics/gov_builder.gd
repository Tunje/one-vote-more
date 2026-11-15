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


static func monthly(world: WorldState, st: Dictionary) -> void:
	if world.table("econ").has("s"):
		_grant_cover(world, st)
		_road_budget_need(world, st)
		_toll_feelings(world)
	if world.month % 3 != QUARTER_MONTH or not world.table("econ").has("s"):
		return
	var who := _actor(world, st)
	if who.is_empty():
		return
	_road_feelings(world, st, who)
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
				if EconActions.enqueue(world, "ECON_RETENDER_PROJECT", {"project": pid}).get("ok", false):
					Desk.note(world, "RETENDER_PROJECT")
	# food emergency: any government opens the reserve
	if int(s.get("food_shortfall", 0)) > 50:
		if EconActions.enqueue(world, "ECON_RELEASE_RESERVE", {"good": "FOOD", "qty": 1500}).get("ok", false):
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
	for d in EconUtil.sorted_keys(world.table("district")):
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
	for key in [["health_access", "CLINIC"], ["edu_access", "SCHOOL"]]:
		var acc: Dictionary = s.get(key[0], {})
		for d in EconUtil.sorted_keys(acc):
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
		var opts: Array = EconQuery.upgrade_options(world).filter(func(o): return o.get("enabled", false))
		opts.sort_custom(func(a, b): return float(a["output_gain_pct"]) > float(b["output_gain_pct"]) or (a["output_gain_pct"] == b["output_gain_pct"] and String(a["facility"]) < String(b["facility"])))
		if not opts.is_empty() and float(opts[0]["output_gain_pct"]) / 100.0 * eagerness >= 0.2:
			var r: Dictionary = EconActions.enqueue(world, "ECON_UPGRADE_FACILITY", {"facility": opts[0]["facility"], "line": "ECON_BUDGET_INFRASTRUCTURE"})
			if r.get("ok", false):
				Desk.note(world, "UPGRADE_FACILITY")
				world.add_fact({"type": "POL_PROJECT_ORDERED", "owner": "pol", "subjects": [], "responsible": [{"actor": {"kind": "GOVERNMENT" if who["by"] != "commander" else "COMMANDER", "id": "government"}, "share": 1.0}],
					"impact": {}, "magnitude": 35, "visibility": "PUBLIC", "data": {"type": "UPGRADE", "facility": opts[0]["facility"], "to_tier": opts[0]["next_tier"], "by": who["by"]}})
	# 5. counter-cyclical public works: interventionist and spending governments fight unemployment by building.
	#    Jobs follow output (Bob's E115 trace): idle plants hire nobody, so the jobs have to be created. The more
	#    a government believes in it, and the worse unemployment is, the more it orders per quarter: crowded
	#    housing first, then schools and clinics (a higher bar than the normal programme), then roads (pure works).
	var believer := state + spend
	var unemp := FirmAI.colony_unemployment(world)
	if believer > -0.2 and unemp > 0.12 - 0.04 * maxf(0.0, state):
		# conviction scales the programme: a lukewarm government (+0.0) orders 1 project a quarter, a convinced
		# one (+0.5 and up) 4-5; deep unemployment adds one more
		var n_max := 1 + int(round(6.0 * clampf(believer, 0.0, 0.6))) + (1 if unemp > 0.20 else 0)
		var pw := "ECON_BUDGET_PUBLIC_WORKS"
		var cands: Array = []
		for d in EconUtil.sorted_keys(world.table("district")):
			if float(world.table("district")[d].get("occupancy", 0)) >= 850.0:
				cands.append(["HOUSING", d])
		for key in [["health_access", "CLINIC"], ["edu_access", "SCHOOL"]]:
			var acc: Dictionary = s.get(key[0], {})
			for d in EconUtil.sorted_keys(acc):
				if float(acc[d]) < 900.0 and not _has_facility(world, key[1], d):
					cands.append([key[1], d])
		var roads: Dictionary = st.get("pw_roads", {})
		var by_pop: Array = EconUtil.sorted_keys(world.table("district"))
		by_pop.sort_custom(func(a, b): return int(world.table("district")[a].get("households", 0)) > int(world.table("district")[b].get("households", 0)) or (world.table("district")[a].get("households", 0) == world.table("district")[b].get("households", 0) and a < b))
		for d in by_pop:
			if world.month - int(roads.get(d, -999)) >= 24 - int(12.0 * clampf(believer, 0.0, 0.5)):
				cands.append(["ROAD", d])
		var done := 0
		for c in cands:
			if done >= n_max:
				break
			if busy.has(c[0] + "|" + c[1]) or EconActions.headroom(world, pw) < EconConstruction.estimate(c[0]) * 11 / 10:
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
		if choose:
			var o := road_option(r.get("options", []), spend, state, EconActions.headroom(world, line))
			if o.is_empty():
				continue
			cost = int(o["cost"])
			spec = o["spec"]
			if int(o["load_after_pm"]) > 1000:
				_road_patch_fact(world, who, r, o)
		if EconActions.headroom(world, line) < cost * 11 / 10:
			continue
		if _order(world, st, busy, who, "ROAD", str(r["district"]), line, {"link": spec.duplicate(true)}) > 0:
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
	for d in EconUtil.sorted_keys(wait):
		if not worst.has(d) or working.has(d) or ordered.has(d):
			wait.erase(d)
	var members: Array = (st.get("government", {}) as Dictionary).get("members", [])
	var resp := [{"actor": {"kind": "GOVERNMENT" if who["by"] != "commander" else "COMMANDER", "id": "government"}, "share": 1.0}]
	for d in EconUtil.sorted_keys(worst):
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
		if cheapest >= 0 and EconActions.headroom(world, "ECON_BUDGET_INFRASTRUCTURE") < cheapest * 11 / 10:
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
	for d in EconUtil.sorted_keys(tolls):
		var imp := toll_impact(int(tolls[d]), int(heads.get(d, 0)), wage)
		if imp == 0:
			continue
		world.add_fact({"type": "POL_ROAD_TOLLS_FELT", "owner": "pol", "subjects": [],
			"responsible": [{"actor": {"kind": "GOVERNMENT", "id": "government"}, "share": 0.5}], "impact": {"COST_OF_LIVING": imp},
			"affected": {"districts": [String(d)]}, "magnitude": 15 + 3 * absi(imp), "visibility": "PUBLIC",
			"data": {"district": String(d), "tolls_mcr": int(tolls[d]), "heads": int(heads.get(d, 0))}})


static func road_works_on(world: WorldState) -> bool:
	return (world.meta.get("on", []) as Array).has(ROAD_WORKS_FLAG) and FreightRoads.on(world)


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
	if EconActions.validate(world, "ECON_COMMISSION_PROJECT", params) != "":
		return 0   # can't be paid for now: don't announce an order that would fail at execution (Terra's road trace)
	var r: Dictionary = EconActions.enqueue(world, "ECON_COMMISSION_PROJECT", params)
	if not r.get("ok", false):
		return 0
	Desk.note(world, Desk.build_type(ftype, line))
	world.add_fact({"type": "POL_PROJECT_ORDERED", "owner": "pol", "subjects": [{"kind": "PARTY", "id": who["by"]}] if who["by"] != "commander" else [],
		"responsible": [{"actor": {"kind": "GOVERNMENT" if who["by"] != "commander" else "COMMANDER", "id": "government"}, "share": 1.0}],
		"impact": {}, "magnitude": 35, "visibility": "PUBLIC", "data": {"type": ftype, "district": d, "by": who["by"], "line": line}})
	return 1


## Family grant programmes (user 2026-11-15: a grant is a time-limited programme; when it ends the government starts
## over on its level "and where it covers too"). When a programme opens (grant lever above 0 and no coverage set yet),
## the government names the districts it covers: those with the greatest need (Bob's st["family_need_d"][kind] = {d:
## need}), two by default, more for egalitarian and spending-minded governments. EconFamily reads st["grant_cover"][kind]
## (absent = not decided yet, no grants that month) and the entry is dropped when the lever is back at 0, so the next programme chooses again.
const GRANT_KINDS := {"FARM": "ECON_FAMILY_FARM_GRANT", "BAKERY": "ECON_FAMILY_BAKERY_GRANT"}
const GRANT_FAVOUR := 0.5   # weight of the governing parties' vote share in a district against its (normalised) need
static func _grant_cover(world: WorldState, st: Dictionary) -> void:
	var s := EconUtil.st(world)
	if not s.has("family_need_d"):
		return
	var cover: Dictionary = s.get("grant_cover", {})
	var progs: Dictionary = s.get("grant_prog", {})
	s["grant_prog"] = progs
	for kind in EconUtil.sorted_keys(GRANT_KINDS):
		var need_d: Dictionary = (s["family_need_d"] as Dictionary).get(kind, {})
		if int(world.levers.get(GRANT_KINDS[kind], 0)) <= 0:
			if progs.has(kind):
				_programme_ended(world, st, String(kind), progs[kind])
				progs.erase(kind)
			cover.erase(kind)
			continue
		# the open programme: who opened it, how long it has run and in how many of those months there was a need
		if not progs.has(kind):
			progs[kind] = {"by": String(_actor(world, st).get("by", "")), "start": world.month, "months": 0, "need_m": 0}
		progs[kind]["months"] = int(progs[kind]["months"]) + 1
		for d0 in need_d:
			if int(need_d[d0]) > 0:
				progs[kind]["need_m"] = int(progs[kind]["need_m"]) + 1
				break
		if cover.has(kind):
			continue
		var ds: Array = []
		for d in EconUtil.sorted_keys(need_d):
			if int(need_d[d]) > 0:
				ds.append(d)
		if ds.is_empty():
			continue   # nowhere needs it yet: decide when a need appears
		var who := _actor(world, st)
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
		cover[kind] = chosen
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
	s["grant_cover"] = cover


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
	if not EconStaple.active(world) or state < -0.15:
		return 0
	for pid in world.table("project"):
		var p: Dictionary = world.table("project")[pid]
		if p["type"] == "BAKERY" and p["status"] in ["TENDER", "ACTIVE", "TENDERABLE"]:
			return 0
	var food: Dictionary = EconQuery.essentials(world).get("FOOD", {})
	if int(food.get("margin_pct", -1)) < 0:
		return 0
	var bar := clampf(BAKERY_BAR - 20.0 * maxf(0.0, state) - 10.0 * maxf(0.0, equality), 20.0, 40.0)
	var s := EconUtil.st(world)
	var worst := ""
	var worst_v := bar
	for d in EconUtil.sorted_keys(world.table("district")):
		var v := EconStaple.raw_pct(world, d)
		if v > worst_v and not _has_facility(world, "BAKERY", d):
			worst_v = v
			worst = d
	if worst == "" and _count(world, "BAKERY") == 0:
		var sm: Dictionary = s.get("staple_m", {})
		if int(sm.get("want", 0)) > 0 and int(sm.get("got", 0)) * 2 < int(sm.get("want", 0)):
			var best_h := -1
			for d in EconUtil.sorted_keys(world.table("district")):
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
			if EconActions.enqueue(world, "ECON_OFFER_INCENTIVE", {"type": ftype, "grant_pct": pct, "months": 24, "cap": maxi(1, cap)}).get("ok", false):
				Desk.note(world, "BUILDER_GRANT")


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
	var f: Dictionary = EconQuery.demography(world)
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
			blocks += EconUtil.fscale(hf)
	var per_block := units / maxf(1.0, blocks)
	if state > -0.15:
		var best := ""
		var best_v := -1.0
		for d in EconUtil.sorted_keys(world.table("district")):
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
	if EconEssentials.offers(world).has("HOUSING"):
		return 0
	var cap := int(float(EconConstruction.estimate("HOUSING")) / float(EconUtil.S) * 0.3 * 1.5)
	if EconActions.enqueue(world, "ECON_OFFER_INCENTIVE", {"type": "HOUSING", "grant_pct": 30, "months": 24, "cap": maxi(1, cap)}).get("ok", false):
		Desk.note(world, "BUILDER_GRANT")
	return 0

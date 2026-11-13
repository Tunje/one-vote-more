class_name EconFleet
extends RefCounted
## §8c the bus fleet (user: "Vehicle maintenance? Do public buses break down? Cause accidents? What if there aren't
## enough? ... What if the power station shuts down because the workers can't get to work when a bus broke down.
## Scandal! And what if this happened because the leaders cut funding to public transport again?").
##   FLEET: CTA's buses (table "bus": age_m, cond ‰, repair_m). New buses are assembled from CTA's COMPONENT stock
##     (BUS_PARTS each) when seats fall short of riders; parts come through TRANSIT's ordinary input orders.
##   MAINTENANCE: condition decays DECAY_PM a month; the TRANSIT crew (mechanics) and its parts restore up to
##     REPAIR_PM × the transit site's utilisation — a starved depot (no staff or parts) lets the fleet rot.
##   BREAKDOWNS: per bus a month BREAK_BASE_PM + BREAK_WORN_PM × (1 − cond) × age factor → 1–3 months off the road.
##   ACCIDENTS: CRASH_PM × (2 − cond) × Terra's route factor (where a map exists): injuries, Terra's add_accident.
##   ABSENCE: riders above LOAD_CAP_PM of the seats in service cannot get to work; the share absent per work district
##     cuts every workplace's effective crew there (EconProduction) — an essential plant short of crew trips an outage.
##   BLAME: ECON_COMMUTE_DISRUPTION names the employers hit, and carries the causes (breakdowns, fleet condition,
##     months the depot was starved, the public-transport budget against its 3-year peak) so the press and the parties
##     can trace "the blackout started with a bus — and the bus with the budget cut".
##   FUNDING: a fifth of the fares plus ECON_BUDGET_PUBLIC_TRANSPORT (the state reimburses parts bought beyond the
##     fares' share, up to the line's month). Buses retire at RETIRE_M months, so a cut line shows years later.
## OPT-IN until its A/B (world.meta["on"] has "FLEET"; needs SUPPORT_T for the riders).

const S := EconUtil.S
const SEATS := 50
const BUS_PARTS := 40  # COMPONENT units to assemble one bus
const DECAY_PM := 6
const REPAIR_PM := 12
const BREAK_BASE_PM := 2
const BREAK_WORN_PM := 30
const CRASH_PM := 0.3  # ‰ per bus-month at full condition on a normal road
const LOAD_CAP_PM := 1300
const PART_PM := 200  # milli-COMPONENT per bus-month of maintenance
const FLEET_SHARE := 0.2  # of the fare revenue, spent on parts and new buses (the rest pays the TRANSIT crew)
const LINE := "ECON_BUDGET_PUBLIC_TRANSPORT"
const RETIRE_M := 180
const HIST_M := 36


static func active(world: WorldState) -> bool:
	return world.meta.has("on") and (world.meta["on"] as Array).has("FLEET") and not EconUtil.off(world, "FLEET")


## CTA's monthly parts order from the fleet share of the fares (COMPONENT on the local market).
static func post_parts_order(world: WorldState, cta: String, fare_ema: int) -> void:
	var s := EconUtil.st(world)
	var price := int(s["prices"].get("COMPONENT", 0))
	if price <= 0:
		return
	var fare_part := int(float(fare_ema) * FLEET_SHARE)
	s["fleet_fare_part"] = fare_part
	var budget := fare_part + line_month(world)
	var qty := int(float(budget) * S / float(price))
	# no hoarding: stock for a year of maintenance and two new buses is enough
	var stock_cap := world.table("bus").size() * PART_PM * 12 + 2 * BUS_PARTS * S
	qty = mini(qty, maxi(0, stock_cap - EconUtil.inv_get(world, cta, "COMPONENT", "d:1")))
	if qty <= 0:
		return
	s["orders"].append({"buyer": cta, "acct": EconUtil.acct(cta), "district": "d:1", "good": "COMPONENT", "qty": qty,
		"limit": price * 3 / 2, "class": EconMarket.C_FIRM, "kind": "org"})


## The public-transport line's monthly amount (milli).
static func line_month(world: WorldState) -> int:
	return int(EconUtil.lever(world, LINE, 0)) * 1000 * S / 12


## The state pays CTA for the parts it bought last month beyond the fares' share, up to the line's month.
static func _reimburse(world: WorldState, cta: String) -> void:
	var s := EconUtil.st(world)
	var stock := EconUtil.inv_get(world, cta, "COMPONENT", "d:1")
	var bought := maxi(0, stock - int(s.get("fleet_stock_after", stock)))
	var spent := int(float(bought) / float(S) * float(int(s["prices"].get("COMPONENT", 0))))
	var due := mini(line_month(world), maxi(0, spent - int(s.get("fleet_fare_part", 0))))
	due = mini(due, maxi(0, EconActions.headroom(world, LINE)))
	if due > 0:
		var paid := EconFinance.gov_pay(world, EconUtil.acct(cta), due, "TRANSPORT_SUBSIDY")
		EconFinance._spend_line(world, LINE, paid)
		EconFinance.pl_add(world, cta, "subsidy", paid)
	var h: Array = s.get("pt_budget_hist", [])
	h.append(int(EconUtil.lever(world, LINE, 0)))
	while h.size() > HIST_M:
		h.pop_front()
	s["pt_budget_hist"] = h


## The budget line now against its peak over the last HIST_M months (for the blame chain).
static func budget_cause(world: WorldState) -> Dictionary:
	var h: Array = EconUtil.peek_st(world).get("pt_budget_hist", [])
	var now := int(EconUtil.lever(world, LINE, 0))
	var peak := now
	var since := 0
	for i in h.size():
		if int(h[i]) > peak:
			peak = int(h[i])
	for i in range(h.size() - 1, -1, -1):  # months since the line last stood at its peak
		if int(h[i]) >= peak:
			break
		since += 1
	return {"transport_budget": now, "transport_budget_peak": peak, "budget_cut_pm": (peak - now) * 1000 / maxi(1, peak),
		"budget_cut_months_ago": since if now < peak else 0, "fares_only": now == 0}


## Share (‰) of a work district's commuters who could not get to work this month (0 when off).
static func absent_pm(world: WorldState, d: String) -> int:
	if not active(world):
		return 0
	return int(EconUtil.peek_st(world).get("commute_absent_pm", {}).get(d, 0))


static func _buses(world: WorldState) -> Dictionary:
	return world.table("bus")


## Monthly, from EconCommute with this month's pairs and CTA: age, maintain, break down, buy, assign, absence, crashes.
## Returns the per-pair seats in service and breakdowns for the rows.
static func step(world: WorldState, cta: String, pairs: Array, transit: Dictionary) -> Dictionary:
	var s := EconUtil.st(world)
	var buses := _buses(world)
	var rng := world.rng.stream("econ.buses")
	_reimburse(world, cta)
	# maintenance level: mechanics (the TRANSIT crew's fill) and parts in stock (PART_PM components per bus-month)
	var req := 0
	for t in EconLabor.required(transit):
		req += int(EconLabor.required(transit)[t])
	var fill := 1.0 if req <= 0 else clampf(float(EconLabor.staff_total(transit["staff"])) / float(req), 0.0, 1.0)
	var need := buses.size() * PART_PM
	var took := EconUtil.inv_take(world, cta, "COMPONENT", "d:1", mini(need, EconUtil.inv_get(world, cta, "COMPONENT", "d:1")))
	if took > 0:
		EconUtil.qflow(world, "COMPONENT", "burned", took)
	var parts := 1.0 if need <= 0 else float(took) / float(need)
	var util := minf(fill, parts)
	var starved := util < 0.5
	s["depot_starved_m"] = int(s.get("depot_starved_m", 0)) + 1 if starved else 0
	var broke := 0
	var broken: Array = []
	for bid in EconUtil.sorted_keys(buses):
		var b: Dictionary = buses[bid]
		b["age_m"] = int(b["age_m"]) + 1
		if int(b["age_m"]) >= RETIRE_M:
			buses.erase(bid)  # scrapped; the assembly below replaces it if the parts are there
			continue
		var c := int(b["cond"]) - DECAY_PM * (3 if starved else 1) + int(float(REPAIR_PM) * util)
		b["cond"] = clampi(c, 0, 1000)
		if int(b["repair_m"]) > 0:
			b["repair_m"] = int(b["repair_m"]) - 1
			continue
		var agef := 1.0 + float(int(b["age_m"])) / 120.0
		var p := (float(BREAK_BASE_PM) + float(BREAK_WORN_PM) * (1.0 - float(b["cond"]) / 1000.0) * agef) / 1000.0
		if rng.randf() < p:
			b["repair_m"] = rng.randi_range(1, 3)
			broke += 1
			broken.append(bid)
	# riders and seats
	var riders := 0
	for p in pairs:
		riders += int(p["bus_commuters"])
	if buses.is_empty() and not bool(s.get("fleet_founded", false)):
		# the founding fleet: the colony arrives with enough buses for its commuters (without it, every rider was
		# stranded from month one and the colony collapsed — the first A/B); parts maintain and grow it from here
		s["fleet_founded"] = true
		for _i in (riders * 1000 / LOAD_CAP_PM + SEATS - 1) / SEATS + 1:
			var fid0 := world.new_id("bus")
			buses[fid0] = {"id": fid0, "age_m": rng.randi_range(0, RETIRE_M * 2 / 3), "cond": 900, "repair_m": 0}  # mixed ages
	var in_service := 0
	for bid in buses:
		if int(buses[bid]["repair_m"]) <= 0:
			in_service += 1
	# assemble new buses from CTA's components while seats fall short
	var hq := "d:1"
	# plan for a seat per rider (LOAD_CAP_PM is the crush limit, not the plan): pairs share seats unevenly
	while in_service * SEATS < riders and EconUtil.inv_get(world, cta, "COMPONENT", hq) >= BUS_PARTS * S:
		EconUtil.inv_take(world, cta, "COMPONENT", hq, BUS_PARTS * S)
		EconUtil.qflow(world, "COMPONENT", "burned", BUS_PARTS * S)
		var nid := world.new_id("bus")
		buses[nid] = {"id": nid, "age_m": 0, "cond": 1000, "repair_m": 0}
		in_service += 1
	s["fleet_stock_after"] = EconUtil.inv_get(world, cta, "COMPONENT", hq)
	# share seats over pairs by riders; absence where a pair's load passes the cap
	var out := {}
	var absent_d := {}
	var hit := {}
	for p in pairs:
		var r := int(p["bus_commuters"])
		var seats := in_service * SEATS * r / maxi(1, riders)
		var excess := maxi(0, r - seats * LOAD_CAP_PM / 1000)
		out["%s>%s" % [p["from_d"], p["to_d"]]] = {"seats": seats, "buses": seats / SEATS, "absent": excess}
		absent_d[p["to_d"]] = int(absent_d.get(p["to_d"], 0)) + excess
		if excess > 0:
			hit[p["to_d"]] = true
	var abs_pm := {}
	var commuters_d := {}
	for p in pairs:
		commuters_d[p["to_d"]] = int(commuters_d.get(p["to_d"], 0)) + int(p["commuters"])
	for d in absent_d:
		abs_pm[d] = int(absent_d[d]) * 1000 / maxi(1, int(commuters_d.get(d, 0)))
	s["commute_absent_pm"] = abs_pm
	# crashes (Terra places them where a map exists)
	var crashes := 0
	var has_map := not (world.peek("map").get("grid", {}) as Dictionary).is_empty()
	# breakdowns as facts with a place on the map (Terra draws the marks from data.tile)
	for bid in broken:
		if not buses.has(bid):
			continue
		var site0 := {}
		if has_map and not pairs.is_empty():
			var p0: Dictionary = pairs[rng.randi_range(0, pairs.size() - 1)]
			site0 = Transport.incident_site(world, p0["from_d"], p0["to_d"], rng.randi(), "BREAKDOWN")
		EconFacts.emit(world, "BUS_BREAKDOWN", "d:1", [["COMPANY", cta]], [["COMPANY", cta, 0.6], ["GOVERNMENT", "government", 0.4]],
			{"INFRASTRUCTURE": -3}, 10, "PUBLIC",
			{"bus": bid, "condition": int(buses[bid]["cond"]) / 10, "age_m": int(buses[bid]["age_m"]), "repair_m": int(buses[bid]["repair_m"]),
			"tile": site0.get("tile", -1), "link": site0.get("link", ""), "depot_starved_m": int(s["depot_starved_m"])})
	for bid in EconUtil.sorted_keys(buses):
		var b2: Dictionary = buses[bid]
		if int(b2["repair_m"]) > 0:
			continue
		var pc := CRASH_PM / 1000.0 * (2.0 - float(b2["cond"]) / 1000.0)
		if rng.randf() < pc:
			crashes += 1
			var hurt := rng.randi_range(1, 6)
			var site := {}
			if has_map and not pairs.is_empty():
				var pp: Dictionary = pairs[rng.randi_range(0, pairs.size() - 1)]
				site = Transport.incident_site(world, pp["from_d"], pp["to_d"], rng.randi(), "CRASH")
				var lid := String(site.get("link", "")) if String(site.get("link", "")) != "" else String(site.get("junction", ""))
				if lid != "":
					Transport.add_accident(world, lid)
			EconFacts.emit(world, "BUS_CRASH", "d:1", [["COMPANY", cta]], [["COMPANY", cta, 0.6], ["GOVERNMENT", "government", 0.4]],
				{"SAFETY": -20, "INFRASTRUCTURE": -10}, 30 + 5 * hurt, "PUBLIC",
				{"bus": bid, "injured": hurt, "condition": int(b2["cond"]) / 10, "tile": site.get("tile", -1), "link": site.get("link", ""),
				"depot_starved_m": int(s["depot_starved_m"]), "budget": budget_cause(world)})
	# disruption news: employers in the districts commuters could not reach
	for d in EconUtil.sorted_keys(hit):
		if int(abs_pm.get(d, 0)) < 50:
			continue
		var employers := {}
		for fid in world.table("facility"):
			var f: Dictionary = world.table("facility")[fid]
			if f["district"] == d and not f["mothball"]:
				employers[f["org"]] = true
		var avg := 0
		for bid in buses:
			avg += int(buses[bid]["cond"])
		var cause := {"breakdowns_m": broke, "fleet_condition": avg / maxi(1, buses.size()) / 10, "buses": buses.size(),
			"in_service": in_service, "depot_starved_m": int(s["depot_starved_m"])}
		cause.merge(budget_cause(world))
		EconFacts.emit(world, "ECON_COMMUTE_DISRUPTION", d, [["COMPANY", cta]], [["COMPANY", cta, 0.4], ["GOVERNMENT", "government", 0.6]],
			{"INFRASTRUCTURE": -15, "JOBS": -5}, 30 + int(abs_pm[d]) / 20, "PUBLIC",
			{"district": d, "absent_pm": int(abs_pm[d]), "employers": EconUtil.sorted_keys(employers),
			"cause": cause}, {"districts": [d]})
	return {"pairs": out, "breakdowns": broke, "crashes": crashes}

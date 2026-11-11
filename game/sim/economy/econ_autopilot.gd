class_name EconAutopilot
extends PicProvider
## Minimal caretaker government for headless econ soaks (M4 gate) and for runs without an AI government.
## Uses only public econ actions (same entry point as player/AI, pic-core §6). Not part of the political model.


func owner_id() -> String:
	return "econ_auto"


func phases() -> Array:
	return [TickPhase.DECISIONS]


func _commission(world: WorldState, busy: Dictionary, ftype: String, d: String) -> void:
	if busy.has(ftype + "|" + d):
		return
	busy[ftype + "|" + d] = true
	EconActions.enqueue(world, "ECON_COMMISSION_PROJECT", {"type": ftype, "district": d})


static func _has_facility(world: WorldState, ftype: String, d: String) -> bool:
	for fid in world.table("facility"):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] == ftype and f["district"] == d:
			return true
	return false


func run_phase(_phase: int, world: WorldState) -> void:
	if not world.table("econ").has("s"):
		return
	var s := EconUtil.st(world)
	if world.month % 3 != 1:
		return
	_fiscal_rule(world)
	if _runway(world) < 12.0:
		return  # caretaker pauses new capital projects when cash + credit cover < 12 months
	var busy := {}
	for pid in world.table("project"):
		var p: Dictionary = world.table("project")[pid]
		if p["owner"] == "gov" and p["status"] in ["TENDER", "ACTIVE", "TENDERABLE"]:
			busy[p["type"] + "|" + p["district"]] = true
			if p["status"] == "TENDERABLE":
				EconActions.enqueue(world, "ECON_RETENDER_PROJECT", {"project": pid})
	# housing: most overcrowded district
	var worst := ""
	var worst_v := 1000
	for d in EconUtil.sorted_keys(world.table("district")):
		var occ: int = world.table("district")[d].get("occupancy", 0)
		if occ > worst_v and not busy.has("HOUSING|" + d):
			worst_v = occ
			worst = d
	if worst != "":
		_commission(world, busy, "HOUSING", worst)
	elif EconActions.headroom(world, "ECON_BUDGET_HOUSING") > EconConstruction.estimate("HOUSING") * 2:
		# no district is over-full, but the housing budget is unspent: build where occupancy is highest
		var best := ""
		var best_v := 0
		for d in EconUtil.sorted_keys(world.table("district")):
			var occ: int = world.table("district")[d].get("occupancy", 0)
			if occ > best_v and occ >= 900 and not busy.has("HOUSING|" + d):
				best_v = occ
				best = d
		if best != "":
			_commission(world, busy, "HOUSING", best)
	# utilities
	var dem: Dictionary = s.get("util_demand", {})
	var sup: Dictionary = s.get("util_supply", {})
	if float(dem.get("E", 0)) > 0.80 * float(_capacity(world, "POWER")):
		_commission(world, busy, "POWER", "d:4")
	if float(dem.get("W", 0)) > 0.80 * float(_capacity(world, "WATERWORKS")):
		_commission(world, busy, "WATERWORKS", "d:2")
	# services access
	for key in [["health_access", "CLINIC"], ["edu_access", "SCHOOL"]]:
		var acc: Dictionary = s.get(key[0], {})
		for d in EconUtil.sorted_keys(acc):
			if acc[d] < 650 and not _has_facility(world, key[1], d) and not busy.has(key[1] + "|" + d):
				_commission(world, busy, key[1], d)
				break
	# keep contractors loaded (≈ 6 months of work) while the infrastructure budget allows
	var cap_total := 0
	var committed := 0
	for oid in EconUtil.sorted_keys(world.table("org")):
		var o: Dictionary = world.table("org")[oid]
		if o["is_contractor"] and o["status"] in ["ACTIVE", "DISTRESSED"]:
			cap_total += EconConstruction.capacity(world, oid)
			committed += EconConstruction.committed(world, oid)
	for pid in world.table("project"):
		var p: Dictionary = world.table("project")[pid]
		if p["status"] in ["TENDER", "TENDERABLE"]:
			committed += p["wu_total"]
	var mat_tight: bool = float(s["prices"]["MATERIAL"]) > 1.3 * float(s["base"]["MATERIAL"])
	if committed < 6 * cap_total and not mat_tight:
		var options: Array = []
		var hacc: Dictionary = s.get("health_access", {})
		var eacc: Dictionary = s.get("edu_access", {})
		for d in EconUtil.sorted_keys(hacc):
			if not busy.has("CLINIC|" + d) and hacc[d] < 800 and not _has_facility(world, "CLINIC", d):
				options.append([hacc[d], "CLINIC", d])
		for d in EconUtil.sorted_keys(eacc):
			if not busy.has("SCHOOL|" + d) and eacc[d] < 800 and not _has_facility(world, "SCHOOL", d):
				options.append([eacc[d], "SCHOOL", d])
		if float(dem.get("E", 0)) > 0.75 * float(_capacity(world, "POWER")) and not busy.has("POWER|d:4"):
			options.append([0, "POWER", "d:4"])
		for d in EconUtil.sorted_keys(world.table("district")):
			if world.table("district")[d].get("occupancy", 0) >= 900 and not busy.has("HOUSING|" + d):
				options.append([1000 - world.table("district")[d]["occupancy"], "HOUSING", d])
		options.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[2] < b[2]))
		if not options.is_empty():
			_commission(world, busy, options[0][1], options[0][2])
	# E68 counter-cyclical public works: own appropriation, used only while colony unemployment > 12%,
	# not paused by material prices (keeps the construction sector alive through slumps)
	if FirmAI.colony_unemployment(world) > 0.12:
		var pw := "ECON_BUDGET_PUBLIC_WORKS"
		var picks: Array = []
		for d in EconUtil.sorted_keys(world.table("district")):
			if world.table("district")[d].get("occupancy", 0) >= 850 and not busy.has("HOUSING|" + d):
				picks.append(["HOUSING", d])
		for key in [["health_access", "CLINIC"], ["edu_access", "SCHOOL"]]:
			var acc: Dictionary = s.get(key[0], {})
			for d in EconUtil.sorted_keys(acc):
				if acc[d] < 900 and not busy.has(key[1] + "|" + d) and not _has_facility(world, key[1], d):
					picks.append([key[1], d])
		for pk in picks:
			if EconActions.headroom(world, pw) >= EconConstruction.estimate(pk[0]) * 11 / 10:
				busy[pk[0] + "|" + pk[1]] = true
				EconActions.enqueue(world, "ECON_COMMISSION_PROJECT", {"type": pk[0], "district": pk[1], "line": pw})
				break
	# food emergency
	if s.get("food_shortfall", 0) > 50:
		EconActions.enqueue(world, "ECON_RELEASE_RESERVE", {"good": "FOOD", "qty": 1500})
		EconActions.enqueue(world, "ECON_ORDER_IMPORTS", {"good": "FOOD", "qty": 600})


## Caretaker fiscal rule: after the grant, persistent deficits raise income tax (+2 pp, ≤ 35%); big surpluses lower it.
static func _fiscal_rule(world: WorldState) -> void:
	if not world.meta.get("econ_caretaker_fiscal", false):
		return  # integrated game: politics owns taxes (Wilma M4 steer)
	if world.month < EconData.ORIGIN_GRANT_MONTHS or world.month % 6 != 1:  # grant tapers after this
		return
	var bal := world.indicators.read("ECON_BUDGET_BALANCE", "COLONY") / 1000
	var rate: int = world.levers.get("ECON_INCOME_TAX_RATE", 24)
	var target := rate
	if bal < -10 and rate < 35:
		target = rate + 2
	elif bal > 15 and rate > 15:
		target = rate - 1
	if target == rate:
		return
	var id := world.new_id("enactment")
	world.table("enactment")[id] = {"id": id, "lever": "ECON_INCOME_TAX_RATE", "value": target, "legal_level": "ORDINANCE",
		"source_bill": "caretaker", "decided_month": world.month, "earliest_effective_month": world.month + 1, "status": "PENDING"}


static func _runway(world: WorldState) -> float:
	return float(world.indicators.read("ECON_TREASURY_RUNWAY", "COLONY", 240000)) / 1000.0


static func _capacity(world: WorldState, ftype: String) -> int:
	var c := 0
	for fid in world.table("facility"):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] == ftype and not f["mothball"]:
			c += int(float(EconData.RECIPES[ftype]["out"][1]) * EconUtil.S * EconUtil.fscale(f))
	return c

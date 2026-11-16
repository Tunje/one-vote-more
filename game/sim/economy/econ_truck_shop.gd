extends RefCounted
## Truck workshops (TRUCKSHOP, opt-in; Ella; planning/design-truck-drivers.md). Preloaded as EconTruckShop (no
## class_name). The user, 2026-11-16: "if you're truck breaks down you can fix it yourself in about 4 months or drive to
## a workship and have it fixed now"; "trucks have quality that's what governs breakdown and a component factory is not
## the best at making them but the workshop can!"; "No improvements for trucks set quality stays".
##
## THE TRUCK (Bob's table "truck", one footing with the buses): id, owner (the driver's org), district, age_m, cond ‰,
## quality ‰ (set once when built, never changed), maker, maker_org, repair_m (months off the road), carry, earn_m (what a
## month on the road earned its owner, mcr; Bob keeps it). Bob's breakdowns set repair_m to SELF_M: the owner's own repair.
## A workshop is never needed for a truck to run: it sells speed.
##
## THE WORKSHOP: a TRUCKSHOP plant (a family of four, started like a family bakery: the plan first, the grant after the
## plan, on need: EconFamily kind TRUCKSHOP, lever ECON_TRUCK_WORKSHOP_GRANT). Its crew makes TRUCKWORK, units of bay
## work a month (f["tw_cap"], EconProduction). A repair takes REPAIR_WORK, a truck BUILD_WORK and TRUCK_PARTS COMPONENT
## bought on the market like any buyer's. Each month (FirmAI.run, before the targets):
##   REPAIRS  every broken truck whose owner reaches a workshop (its district and the neighbours) with a free bay: the
##            owner pays the cheapest fee when it is below what the months of self-repair left would cost him
##            (earn_m × repair_m); the truck runs again next month. A workshop repair uses REPAIR_PARTS components and
##            resets the wear, each time to REPAIR_LOSS_PM under the last (the user: "Uses components and resets wear,
##            about 5% are lost reach time"; t["cond_max"]); quality never changes. A self-repair (Ella's, not
##            contradicted) needs no parts and leaves the wear where it was. A workshop out of parts takes no repair (no
##            price signal) and orders them.
##   BUILDS   orders (order()) are built in turn with what bay work is left, once the parts are in stock; the finished
##            truck enters the table with quality() set once, maker WORKSHOP. The price is paid when the order is placed.
##   RULES    1/2 fee and truck price: drivers turned away (no free bay) raise the fee, orders waiting raise the truck
##            price, unused bay work lowers both. Rule nine (the user, 2026-11-16): below what it costs to make the raise
##            has priority, above it the cut; when both signals come in one month only the one with priority acts; the
##            same limit up and down (MOVE_PM). A sale stopped by anything but price (no workshop in reach, the owner's
##            money) is no signal. 3/4 output: the work asked of it (done, turned away, orders waiting) ÷ its capacity,
##            none while neither price covers its variable cost. 5/6 capacity: a quarter more when turned-away work
##            exists and an extension's share of the work in reach pays; mothballed when it lost money over 12 months and
##            its own share of the work no longer pays; a mothballed shop reopens when its share pays again. 7/8 founding:
##            where a workshop's share of all the work in reach (EconForecast.share_of_work, the average of all the
##            breakdowns and truck orders, not the leftovers) pays over a year at today's fee and price.
## Off (no "TRUCKSHOP" in meta on): nothing here runs and no table is touched.

const S := EconUtil.S
const FLAG := "TRUCKSHOP"
const TYPE := "TRUCKSHOP"
const LEVER := "ECON_TRUCK_WORKSHOP_GRANT"
const Forecast := preload("res://sim/economy/econ_forecast.gd")
const SELF_M := 4          # the user: "fix it yourself in about 4 months"
const REPAIR_WORK := 1     # TRUCKWORK units a repair takes (recipe fact)
const BUILD_WORK := 6      # TRUCKWORK units a truck takes: a full workshop-month (recipe fact)
const REPAIR_PARTS := 2    # COMPONENT a workshop repair uses (recipe fact; Ella's number)
const REPAIR_LOSS_PM := 50 # the user: "about 5% are lost" each workshop repair
const TRUCK_PARTS := 20    # COMPONENT per truck (recipe fact; to agree with Bob's works order)
const Q_MIN := 500         # ‰: a truck from the components works, always the lowest (the user); Ella's number
const CARRY := 400         # mu a month on the road (Bob's figure replaces it)
const MOVE_PM := 50        # rule nine: the most a price moves in a month, up and down alike
const HIST_M := 12         # the work in reach is averaged over a year


static func on(world: WorldState) -> bool:
	return world.meta.has("on") and (world.meta["on"] as Array).has(FLAG) and not EconUtil.off(world, FLAG)


static func _trucks(world: WorldState) -> Dictionary:
	return world.peek("truck")


static func _near(d: String) -> Array:
	return [d] + EconUtil.neighbours(d)


static func _cap(f: Dictionary) -> float:
	return float(EconData.RECIPES[TYPE]["out"][1]) * float(S) * EconUtil.fscale(f)


static func _open(world: WorldState, f: Dictionary) -> bool:
	var o: Dictionary = world.peek("org").get(f["org"], {})
	return f["type"] == TYPE and not f["mothball"] and not o.is_empty() and o["status"] in ["ACTIVE", "DISTRESSED"]


## mcr per TRUCKWORK unit: full (crew, inputs, upkeep, capital) and variable (inputs only).
static func unit_full(world: WorldState) -> float:
	return FirmAI.unit_cost(world, TYPE)


static func unit_var(world: WorldState) -> float:
	var r: Dictionary = EconData.RECIPES[TYPE]
	var c := 0.0
	for g in r["in"]:
		if g == "ENERGY":
			c += float(r["in"][g]) * float(EconUtil.lever(world, "ECON_UTILITY_TARIFF_ENERGY", 40)) * S
		elif g == "WATER":
			c += float(r["in"][g]) * float(EconUtil.lever(world, "ECON_UTILITY_TARIFF_WATER", 20)) * S
	return c / float(r["out"][1])


static func _parts_cost(world: WorldState) -> float:
	return float(TRUCK_PARTS) * float(int(EconUtil.peek_st(world).get("prices", {}).get("COMPONENT", 0)))


## What a repair and a truck cost the workshop to make (mcr), full or variable.
static func fee_cost(world: WorldState, full: bool = true) -> float:
	return (unit_full(world) if full else unit_var(world)) * float(REPAIR_WORK)


static func truck_cost(world: WorldState, full: bool = true) -> float:
	return (unit_full(world) if full else unit_var(world)) * float(BUILD_WORK) + _parts_cost(world)


static func fee_of(world: WorldState, f: Dictionary) -> int:
	if not f.has("tw_fee"):
		return int(fee_cost(world))  # a new workshop starts at its full cost
	return int(f["tw_fee"])


static func price_of(world: WorldState, f: Dictionary) -> int:
	if not f.has("tw_price"):
		return int(truck_cost(world))
	return int(f["tw_price"])


# ------------------------------------------------------------------ quality (set once, when the truck is built)

## A workshop truck's quality ‰, set once when its build starts (the user, 2026-11-16: "Then leave it at workers are
## they stressed out not"): from the best (1000) when its workers are not stressed down to the works' trucks (Q_MIN)
## at full stress (EconWorkload's stress_pm; 0 while WORKLOAD is off). Components carry no quality.
## OPTION, not built (the user's "maybe they can add more parts to make better trucks"; waits for a yes): a truck built
## with more components than TRUCK_PARTS comes out better.
static func quality(_world: WorldState, f: Dictionary) -> int:
	var calm := 1.0 - clampf(float(int(f.get("stress_pm", 0))) / 1000.0, 0.0, 1.0)
	return Q_MIN + int(float(1000 - Q_MIN) * calm)


# ------------------------------------------------------------------ drivers' side (Bob calls these)

## The trucks a driver in district d can order from workshops in reach: [{seller (facility id), quality, price, wait_m}].
static func quotes(world: WorldState, d: String) -> Array:
	var out: Array = []
	if not on(world):
		return out
	for fid in EconUtil.sorted_keys(world.peek("facility")):
		var f: Dictionary = world.peek("facility")[fid]
		if not _open(world, f) or not (String(f["district"]) in _near(d)):
			continue
		var queued := 0
		for od in f.get("tw_orders", []):
			queued += int(od["left"])
		var per_m := maxf(1.0, _cap(f))
		out.append({"seller": fid, "quality": quality(world, f), "price": price_of(world, f),
			"wait_m": int(ceil((float(queued) + float(BUILD_WORK * S)) / per_m))})
	return out


## A driver orders a truck from workshop `seller` and pays its price now. false: no such open workshop, or the owner
## cannot pay (no order, no signal).
static func order(world: WorldState, seller: String, owner: String, district: String) -> bool:
	if not on(world) or not world.peek("facility").has(seller):
		return false
	var f: Dictionary = world.table("facility")[seller]
	if not _open(world, f):
		return false
	var price := price_of(world, f)
	if world.ledger.balance(EconUtil.acct(owner)) < price:
		return false
	world.ledger.transfer(EconUtil.acct(owner), EconUtil.acct(f["org"]), price, "SALE", world.month)
	EconFinance.pl_add(world, f["org"], "rev", price)
	var ods: Array = f.get("tw_orders", [])
	ods.append({"owner": owner, "district": district, "left": BUILD_WORK * S, "parts": false, "month": world.month, "quality": 0})
	f["tw_orders"] = ods
	_add_work(world, district, BUILD_WORK * S)
	return true


# ------------------------------------------------------------------ monthly (FirmAI.run, before the targets)

static func monthly(world: WorldState) -> void:
	if not on(world):
		return
	var s := EconUtil.st(world)
	var shops: Array = []
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] != TYPE:
			continue
		f["tw_used"] = 0
		f["tw_turned"] = 0
		f["tw_repairs"] = 0
		f["tw_parts_short"] = 0
		f["tw_left"] = int(f.get("tw_cap", 0)) if _open(world, f) else 0
		if _open(world, f):
			shops.append(fid)
	_repairs(world, shops)
	_builds(world, shops)
	var need_d := {}
	for fid2 in shops:
		var f2: Dictionary = world.table("facility")[fid2]
		_prices(world, f2)
		_post_parts(world, f2)
	for d in EconUtil.sorted_keys(s.get("tw_wait_d", {})):
		need_d[d] = int(s["tw_wait_d"][d])
	s["tw_need_d"] = need_d
	_roll_work(world)
	_capacity(world)
	_publish_need(world)


## Broken trucks: the owner weighs the cheapest free workshop in reach against the months of self-repair left.
static func _repairs(world: WorldState, shops: Array) -> void:
	var s := EconUtil.st(world)
	var trucks := _trucks(world)
	var wait_d := {}
	for tid in EconUtil.sorted_keys(trucks):
		var t: Dictionary = trucks[tid]
		var rm := int(t.get("repair_m", 0))
		if rm <= 0:
			continue
		var d := String(t["district"])
		if rm == SELF_M:
			_add_work(world, d, REPAIR_WORK * S)  # a new breakdown: work in reach, fixed here or not
		var best := ""
		var best_fee := 0
		var any := false
		var bay_free := false
		for fid in shops:
			var f: Dictionary = world.table("facility")[fid]
			if not (String(f["district"]) in _near(d)):
				continue
			any = true
			if int(f["tw_left"]) < REPAIR_WORK * S:
				continue
			bay_free = true
			if EconUtil.inv_get(world, f["org"], "COMPONENT", f["district"]) < REPAIR_PARTS * S:
				f["tw_parts_short"] = int(f.get("tw_parts_short", 0)) + 1  # its own parts ran out: no price signal
				continue
			var fee := fee_of(world, f)
			if best == "" or fee < best_fee:
				best = fid
				best_fee = fee
		if not any:
			wait_d[d] = int(wait_d.get(d, 0)) + 1  # no workshop in reach: no price signal, but the grant's need
			continue
		if best == "" and bay_free:
			continue  # bays free but no parts: he fixes it himself; the workshop orders parts (_post_parts)
		if best == "":
			# every workshop in reach was full: turned away (the fee's raise signal, at the cheapest of them)
			var cheap := ""
			var cf := 0
			for fid3 in shops:
				var f3: Dictionary = world.table("facility")[fid3]
				if String(f3["district"]) in _near(d) and (cheap == "" or fee_of(world, f3) < cf):
					cheap = fid3
					cf = fee_of(world, f3)
			world.table("facility")[cheap]["tw_turned"] = int(world.table("facility")[cheap]["tw_turned"]) + REPAIR_WORK * S
			wait_d[d] = int(wait_d.get(d, 0)) + 1
			continue
		var worth := int(t.get("earn_m", 0)) * rm
		if best_fee > worth:
			continue  # four months off the road cost him less: he fixes it himself
		var acct := EconUtil.acct(String(t["owner"]))
		if world.ledger.balance(acct) < best_fee:
			continue  # his money stops it: no signal
		var fb: Dictionary = world.table("facility")[best]
		world.ledger.transfer(acct, EconUtil.acct(fb["org"]), best_fee, "SALE", world.month)
		EconFinance.pl_add(world, fb["org"], "rev", best_fee)
		if world.peek("org").has(String(t["owner"])):
			EconFinance.pl_add(world, String(t["owner"]), "inputs", best_fee)
		fb["tw_left"] = int(fb["tw_left"]) - REPAIR_WORK * S
		fb["tw_used"] = int(fb["tw_used"]) + REPAIR_WORK * S
		fb["tw_repairs"] = int(fb["tw_repairs"]) + 1
		EconUtil.inv_take(world, fb["org"], "COMPONENT", fb["district"], REPAIR_PARTS * S)
		EconUtil.qflow(world, "COMPONENT", "burned", REPAIR_PARTS * S)
		# the user: "Uses components and resets wear, about 5% are lost reach time": back to 5% under the last repair
		var top := int(t.get("cond_max", 1000)) * (1000 - REPAIR_LOSS_PM) / 1000
		t["cond_max"] = top
		t["cond"] = top
		t["repair_m"] = 0
		t["shop_m"] = world.month
	s["tw_wait_d"] = wait_d
	for fid4 in shops:
		var f4: Dictionary = world.table("facility")[fid4]
		if int(f4["tw_repairs"]) > 0:
			EconFacts.emit(world, "ECON_TRUCK_REPAIRS", String(f4["district"]), [["COMPANY", f4["org"]]], [["COMPANY", f4["org"], 1.0]],
				{"JOBS": 1}, 5, "PUBLIC", {"org": f4["org"], "facility": fid4, "repairs": int(f4["tw_repairs"]), "fee": fee_of(world, f4)})


## Orders in turn: parts first (taken when the build starts), then the bay work left this month.
static func _builds(world: WorldState, shops: Array) -> void:
	for fid in shops:
		var f: Dictionary = world.table("facility")[fid]
		var ods: Array = f.get("tw_orders", [])
		var keep: Array = []
		for od in ods:
			if not bool(od["parts"]):
				if EconUtil.inv_get(world, f["org"], "COMPONENT", f["district"]) >= TRUCK_PARTS * S:
					EconUtil.inv_take(world, f["org"], "COMPONENT", f["district"], TRUCK_PARTS * S)
					EconUtil.qflow(world, "COMPONENT", "burned", TRUCK_PARTS * S)
					od["parts"] = true
					od["quality"] = quality(world, f)  # set once, from its workers' stress
			if bool(od["parts"]) and int(f["tw_left"]) > 0:
				var w := mini(int(f["tw_left"]), int(od["left"]))
				od["left"] = int(od["left"]) - w
				f["tw_left"] = int(f["tw_left"]) - w
				f["tw_used"] = int(f["tw_used"]) + w
			if bool(od["parts"]) and int(od["left"]) <= 0:
				_deliver(world, f, od)
			else:
				keep.append(od)
		f["tw_orders"] = keep


static func _deliver(world: WorldState, f: Dictionary, od: Dictionary) -> void:
	var tid := world.new_id("truck")
	world.table("truck")[tid] = {"id": tid, "owner": String(od["owner"]), "district": String(od["district"]), "age_m": 0,
		"cond": 1000, "quality": int(od["quality"]), "maker": "WORKSHOP", "maker_org": String(f["org"]), "repair_m": 0, "carry": CARRY * S,
		"earn_m": 0}
	EconFacts.emit(world, "ECON_TRUCK_BUILT", String(f["district"]), [["COMPANY", f["org"]], ["COMPANY", String(od["owner"])]],
		[["COMPANY", f["org"], 1.0]], {"JOBS": 1}, 5, "PUBLIC",
		{"truck": tid, "maker": "WORKSHOP", "maker_org": f["org"], "owner": String(od["owner"]), "quality": int(od["quality"]),
			"months": world.month - int(od["month"])})


## Rules 1/2 under rule nine: the fee and the truck price, each on its own signal.
static func _prices(world: WorldState, f: Dictionary) -> void:
	var cap := maxf(float(S), _cap(f))
	var spare := int(f["tw_left"])
	var queued := 0
	for od in f.get("tw_orders", []):
		queued += int(od["left"])
	f["tw_fee"] = int(step(float(fee_of(world, f)), fee_cost(world), int(f["tw_turned"]), spare, cap))
	f["tw_price"] = int(step(float(price_of(world, f)), truck_cost(world), queued, spare if queued == 0 else 0, cap))
	f["tw_spare"] = spare
	f["tw_queued"] = queued


## One price under rule nine: `up` (work asked and not served) raises it, `down` (bay work unused) lowers it; below
## `cost` the raise has priority, at or above it the cut; in proportion to the signal over the capacity, at most
## MOVE_PM a month either way.
static func step(p: float, cost: float, up: int, down: int, cap: float) -> float:
	var u := up > 0
	var dn := down > 0
	if u and dn:
		if p < cost:
			dn = false
		else:
			u = false
	var lim := float(MOVE_PM) / 1000.0
	if u:
		return p * (1.0 + minf(lim, EconData.ALPHA * float(up) / cap))
	if dn:
		return p * (1.0 - minf(lim, EconData.ALPHA * float(down) / cap))
	return p


## The parts for the orders waiting, on the market like any buyer (cleared at the next TRADE).
static func _post_parts(world: WorldState, f: Dictionary) -> void:
	var s := EconUtil.st(world)
	var need := 0
	for od in f.get("tw_orders", []):
		if not bool(od["parts"]):
			need += TRUCK_PARTS * S
	# next month's repairs, as many as this month's asked of it (done, turned away, or missed for want of parts)
	var asked := int(f.get("tw_repairs", 0)) + int(f.get("tw_turned", 0)) / maxi(1, REPAIR_WORK * S) + int(f.get("tw_parts_short", 0))
	need += maxi(1, asked) * REPAIR_PARTS * S
	var qty := need - EconUtil.inv_get(world, f["org"], "COMPONENT", f["district"])
	var price := int(s["prices"].get("COMPONENT", 0))
	if qty <= 0 or price <= 0:
		return
	s["orders"].append({"buyer": f["org"], "acct": EconUtil.acct(f["org"]), "district": f["district"], "good": "COMPONENT",
		"qty": qty, "limit": price * 3 / 2, "class": EconMarket.C_FIRM, "kind": "org"})


## Rules 3/4 (FirmAI._set_target): the work asked of it over its capacity; none while neither price covers its variable cost.
static func target(world: WorldState, f: Dictionary) -> float:
	if not on(world):
		return 1.0
	if float(fee_of(world, f)) < fee_cost(world, false) and float(price_of(world, f)) < truck_cost(world, false):
		return 0.0
	var asked := float(int(f.get("tw_used", 0)) + int(f.get("tw_turned", 0)) + int(f.get("tw_queued", 0)))
	return clampf(asked / maxf(1.0, _cap(f)), 0.0, 1.0)


# ------------------------------------------------------------------ the work in reach (the average, not the leftovers)

static func _add_work(world: WorldState, d: String, mu: int) -> void:
	var s := EconUtil.st(world)
	var now: Dictionary = s.get("tw_work_now", {})
	now[d] = int(now.get(d, 0)) + mu
	s["tw_work_now"] = now


## Month end: the month's work (breakdowns and truck orders, by the truck's district) joins the year's history.
static func _roll_work(world: WorldState) -> void:
	var s := EconUtil.st(world)
	var h: Array = s.get("tw_work_hist", [])
	h.append((s.get("tw_work_now", {}) as Dictionary).duplicate())
	while h.size() > HIST_M:
		h.pop_front()
	s["tw_work_hist"] = h
	s["tw_work_now"] = {}


## The average work a month (mu) whose trucks could reach a workshop in d, over the months recorded.
static func work_in_reach(world: WorldState, d: String) -> float:
	var h: Array = EconUtil.peek_st(world).get("tw_work_hist", [])
	if h.is_empty():
		return 0.0
	var t := 0
	for row in h:
		for d2 in _near(d):
			t += int((row as Dictionary).get(d2, 0))
	return float(t) / float(h.size())


## Workshop capacity serving d's reach: open shops and those being built or extended there.
static func cap_in_reach(world: WorldState, d: String, skip: String = "") -> float:
	var near := _near(d)
	var full := float(EconData.RECIPES[TYPE]["out"][1]) * float(S)
	var t := 0.0
	for fid in EconUtil.sorted_keys(world.peek("facility")):
		var f: Dictionary = world.peek("facility")[fid]
		if f["type"] == TYPE and not f["mothball"] and String(f["district"]) in near and fid != skip:
			t += _cap(f)
	for pid in EconUtil.sorted_keys(world.peek("project")):
		var p: Dictionary = world.peek("project")[pid]
		if not (String(p.get("status", "")) in ["TENDER", "TENDERABLE", "ACTIVE", "PLANNING"]) or not (String(p["district"]) in near):
			continue
		if p["type"] == TYPE:
			t += full
		elif p["type"] == "EXPAND" and world.peek("facility").has(String(p.get("target", ""))) \
				and world.peek("facility")[p["target"]]["type"] == TYPE:
			t += full / 4.0
	return t


## A workshop of `scale_pm` in d over a year (mcr): {volume (mu a month), revenue, costs, profit, reasons}. Volume = its
## share of all the work in reach (EconForecast.share_of_work); revenue at today's fee and truck price in the mix the
## work came in; costs its crew, inputs and capital. `skip`: a plant not to count among the others (itself).
static func forecast(world: WorldState, d: String, scale_pm: int, skip: String = "") -> Dictionary:
	var s := EconUtil.peek_st(world)
	var r: Dictionary = EconData.RECIPES[TYPE]
	var cap := float(r["out"][1]) * float(S) * float(scale_pm) / 1000.0
	var reasons: Array = []
	var share: float = Forecast.share_of_work(world, TYPE, d, cap, skip, work_in_reach(world, d), cap_in_reach(world, d, skip))
	if share <= 0.0:
		reasons.append("no_work")
	var volume := minf(share, cap)
	# revenue per work unit: the fees and truck prices of the shops in reach (or the full cost when there are none)
	var per_unit := _going_rate(world, d)
	var revenue := volume / float(S) * per_unit * 12.0
	var crew := 0.0
	for t in r["labor"]:
		crew += float(r["labor"][t]) * float(int(s["wage"].get(t, 0))) * float(scale_pm) / 1000.0
	var capital := float(EconConstruction.estimate(TYPE)) * float(scale_pm) / 1000.0 / float(EconData.DEPRECIATION_MONTHS)
	var costs := crew * 12.0 + unit_var(world) * volume / float(S) * 12.0 + capital * 12.0
	var profit := int(revenue - costs)
	if profit <= 0 and reasons.is_empty():
		reasons.append("no_profit")
	return {"volume": int(volume), "revenue": int(revenue), "costs": int(costs), "profit": profit, "reasons": reasons}


## mcr a work unit gets in d's reach: the cheapest open shop's fee per repair unit (a newcomer prices at the going rate),
## or the full cost of a unit where none is open.
static func _going_rate(world: WorldState, d: String) -> float:
	var best := -1.0
	for fid in EconUtil.sorted_keys(world.peek("facility")):
		var f: Dictionary = world.peek("facility")[fid]
		if _open(world, f) and String(f["district"]) in _near(d):
			var v := float(fee_of(world, f)) / float(REPAIR_WORK)
			if best < 0.0 or v < best:
				best = v
	return best if best >= 0.0 else unit_full(world)


# ------------------------------------------------------------------ rules 5/6 (monthly) and 7/8 (founding)

static func _capacity(world: WorldState) -> void:
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] != TYPE or f.has("converting"):
			continue
		var o: Dictionary = world.table("org").get(f["org"], {})
		if o.is_empty() or not (o["status"] in ["ACTIVE", "DISTRESSED"]):
			continue
		var d := String(f["district"])
		var sc := int(f.get("scale", 1000))
		if f["mothball"]:
			# a mothballed workshop reopens when its share of the work pays again
			if int(forecast(world, d, sc, fid)["profit"]) > 0:
				f["mothball"] = false
			continue
		# rule 6: it lost money over 12 months and its own share of the work no longer pays
		if EconPublicCo.result12(o) < 0 and int(forecast(world, d, sc, fid)["profit"]) <= 0:
			f["mothball"] = true
			continue
		# rule 5: drivers were turned away and a quarter more's share of the work pays
		if int(f.get("tw_turned", 0)) + int(f.get("tw_queued", 0)) <= 0 or EconPublicCo.result12(o) <= 0:
			continue
		if EconConstruction.has_open_project(world, f["org"], TYPE) or EconRulesMat._expand_pending(world, fid):
			continue
		if int(forecast(world, d, 250)["profit"]) <= 0:
			continue
		var cost := EconConstruction.estimate(TYPE) / 4
		if not EconRulesMat._finance(world, String(f["org"]), cost, false):
			continue
		EconConstruction.create_expansion(world, fid, f["org"])
		o["last_expand"] = world.month


## Rules 7/8 (FirmAI.run, monthly): a family founds a workshop where its share of all the work in reach pays; each
## founding's plan counts in the next one's capacity in reach. "" when no district pays.
static func found(world: WorldState) -> void:
	if not on(world):
		return
	var s := EconUtil.st(world)
	var tried := {}
	while true:
		var best := ""
		var best_p := 0
		for d in EconUtil.sorted_keys(EconData.DISTRICTS):
			if not EconUtil.connected(String(d)) or tried.has(d):
				continue
			var fc := forecast(world, String(d), 1000)
			if (fc["reasons"] as Array).is_empty() and int(fc["profit"]) > best_p:
				best_p = int(fc["profit"])
				best = String(d)
		if best == "":
			return
		tried[best] = true
		var gid := EconFamily._household(world, best)
		if gid == "":
			_note(s, "no_household")
			continue
		var pct := EconFamily._grant_pct(world, TYPE, best)
		if not EconFamily._start(world, TYPE, best, gid, pct, best):
			_note(s, "money")


static func _note(s: Dictionary, why: String) -> void:
	var f: Dictionary = s.get("tw_fail_found", {})
	f[why] = int(f.get(why, 0)) + 1
	s["tw_fail_found"] = f


# ------------------------------------------------------------------ the grant's need (EconFamily, the legislature)

## Broken trucks in d this month that no workshop could take (none in reach, or all full).
static func need_at(world: WorldState, d: String) -> int:
	return int(EconUtil.peek_st(world).get("tw_need_d", {}).get(d, 0))


static func need_any(world: WorldState) -> bool:
	for d in EconUtil.peek_st(world).get("tw_need_d", {}):
		if int(EconUtil.peek_st(world)["tw_need_d"][d]) > 0:
			return true
	return false


## st["lever_need"][LEVER]: 1000 while broken trucks wait with no workshop to take them, -1000 while the grant is
## offered without that need, else 0.
static func _publish_need(world: WorldState) -> void:
	var s := EconUtil.st(world)
	var ln: Dictionary = s.get("lever_need", {})
	if need_any(world):
		ln[LEVER] = 1000
	elif int(EconUtil.lever(world, LEVER, 0)) > 0:
		ln[LEVER] = -1000
	else:
		ln[LEVER] = 0
	s["lever_need"] = ln


## For the government's choice of the districts a programme covers (EconFamily._publish_need_d): broken trucks waiting
## in each district.
static func need_by_district(world: WorldState) -> Dictionary:
	var out := {}
	for d in EconUtil.sorted_keys(EconData.DISTRICTS):
		out[d] = need_at(world, String(d))
	return out

extends RefCounted
## Truck drivers and their trucks (TRUCKERS, opt-in; Bob; planning/design-truck-drivers.md). Preloaded as EconTrucks (no
## class_name). Needs R8FR_PRIVATE (each carrier paid for what its own trucks carry); without it nothing here runs.
## The user, 2026-11-16: "Two new businesses we are adding started by grants alla bakeries, truck drivers and truck
## workshops! Same rules as before"; "if you're truck breaks down you can fix it yourself in about 4 months or drive to a
## workship and have it fixed now"; "trucks for this should be able to be built at the component workshop as special
## orders"; "trucks have quality that's what governs breakdown and a component factory is not the best at making them
## but the workshop can!"; trucks on the bus fleet's footing ("Agreed"); "No improvements for trucks set quality stays";
## "Yes they ware, yes and no the components ones are always lowest quality".
##
## THE TRUCK (table "truck", agreed with Ella's EconTruckShop): id, owner (the driver's org), fac (the driver's business,
## Bob's), district, age_m, cond ‰ (wear), cond_max ‰ (what a workshop repair brings it back to; Ella's, missing = 1000),
## quality ‰ (set once when built, never changed), maker (WORKS, WORKSHOP, HOME), maker_org, repair_m (months off the
## road), carry (unit-links a month on the road), earn_m (what a month on the road earned its owner last month, mcr).
## Each month (FirmAI.run, before EconTruckShop.monthly):
##   WEAR       cond falls DECAY_PM a month (the buses' rate). A self-repair leaves it; a workshop repair resets it
##              (Ella). At cond 0 the truck is scrapped (Bob's).
##   BREAKDOWN  a running truck breaks down with chance (BREAK_BASE_PM + BREAK_WORN_PM × wear) × 1000 ÷ quality a
##              month (the buses' figures; quality divides them: a 500 truck breaks down twice as often as a 1000 one).
##              A broken truck is off the road SELF_M months (the owner's own repair, no parts) unless a workshop fixes
##              it at once (EconTruckShop._repairs, the owner's choice). The countdown runs before new breakdowns.
## THE DRIVER: a family business (EconFamily kind TRUCKER), one driver per truck, the truck parked at home: no building,
## so nothing waits for a builder. A TRUCKER facility is the business (scale = its trucks, owned and on order); its
## FREIGHT room this month is the carry of its trucks on the road (EconProduction), and it is one more carrier in
## EconHaulier's list, cheapest with room first, paid for what it carries.
## WHERE TRUCKS COME FROM (the driver takes the best value: price ÷ the share of its life a truck of that quality is on
## the road):
##   a truck workshop in reach (Ella's EconTruckShop.quotes / order; quality from its workers' stress);
##   a components works, as a special order: TRUCK_PARTS of its components at its own price, quality Q_MIN, delivered
##     when it has the parts in store (taken from its stock);
##   the home world, only while the colony has neither (no workshop in reach and no works making components; the
##     ORDER_IN rule): paid on order, the order goes out on a ship in port, the truck comes on the ship after it.
## A DRIVER'S EIGHT RULES:
##   1/2 its rate: EconHaulier's carrier rules (up when its trucks were full and freight was left behind, down when
##       they stood idle).
##   3/4 its trucks drive whenever they run; the idle ones are the rate's cut signal.
##   5   one more truck (quarterly) when its trucks were full in FULL_M of 12 months, freight was left behind, it earned
##       over 12 months, and one more truck's share of the work pays.
##   6   parked (mothballed) when it lost money over 12 months and its own share of the work no longer pays; a parked
##       business drives again when its share pays.
##   7   founded (monthly) by a family where a truck's share of all the freight asked (carried by every carrier and
##       left behind; EconForecast.share_of_work, the average, not the leftovers) pays over a year at today's rate,
##       after the truck, its fuel and the family's living; each founding counts in the next one's competitors.
##   8   none while a driver of 12 months or more loses money, or no truck can be bought.
## THE GRANT (lever ECON_TRUCK_DRIVER_GRANT, like the family bakeries'): the plan first, the grant after the plan (sized
## on the accepted truck price), approved on need only: freight left behind in each of the last NEED_M months.
## Off (no "TRUCKERS" in meta on): nothing here runs and no table is touched.

const S := EconUtil.S
const FLAG := "TRUCKERS"
const TYPE := "TRUCKER"
const LEVER := "ECON_TRUCK_DRIVER_GRANT"
const EconTruckShop := preload("res://sim/economy/econ_truck_shop.gd")
const EconHaulier := preload("res://sim/economy/econ_haulier.gd")
const EconImports := preload("res://sim/economy/econ_imports.gd")
const Forecast := preload("res://sim/economy/econ_forecast.gd")
const CARRY := 320          # unit-links a month on the road: a depot's 8,000 over its crew of 25 (Bob's)
const DECAY_PM := 6         # ‰ wear a month (the buses')
const BREAK_BASE_PM := 2    # ‰ a month (the buses')
const BREAK_WORN_PM := 30   # ‰ a month at full wear (the buses')
const LIFE_COND := 500      # ‰: the mean condition over a truck's life, for the driver's choice of maker
const Q_HOME := 1000        # ‰: a home-world truck (Bob's; not settled)
const FULL_PCT := 95
const FULL_M := 6
const NEED_M := 3
const HIST_M := 12


static func on(world: WorldState) -> bool:
	return world.meta.has("on") and (world.meta["on"] as Array).has(FLAG) and not EconUtil.off(world, FLAG) and EconHaulier.on(world)


static func _parts() -> int:
	return EconTruckShop.TRUCK_PARTS


# ------------------------------------------------------------------ the truck

## ‰ chance a month that a running truck of this quality and condition breaks down.
static func break_pm(quality: int, cond: int) -> float:
	var wear := float(1000 - clampi(cond, 0, 1000)) / 1000.0
	return (float(BREAK_BASE_PM) + float(BREAK_WORN_PM) * wear) * 1000.0 / float(maxi(1, quality))


## The share of its life a truck of this quality is on the road (at the mean condition LIFE_COND).
static func uptime(quality: int) -> float:
	return maxf(0.05, 1.0 - break_pm(quality, LIFE_COND) / 1000.0 * float(EconTruckShop.SELF_M))


static func _running(t: Dictionary) -> bool:
	return int(t.get("repair_m", 0)) <= 0


## The FREIGHT room of a driver's business this month (EconProduction): its trucks on the road × act.
static func room(world: WorldState, f: Dictionary, act: float) -> int:
	var n := 0
	for tid in EconUtil.sorted_keys(world.peek("truck")):
		var t: Dictionary = world.peek("truck")[tid]
		if String(t.get("fac", "")) == String(f["id"]) and _running(t):
			n += int(t.get("carry", CARRY * S))
	return int(float(n) * act)


static func _new_truck(world: WorldState, owner: String, fac: String, d: String, quality: int, maker: String, maker_org: String) -> String:
	var tid := world.new_id("truck")
	world.table("truck")[tid] = {"id": tid, "owner": owner, "fac": fac, "district": d, "age_m": 0, "cond": 1000, "cond_max": 1000,
		"quality": quality, "maker": maker, "maker_org": maker_org, "repair_m": 0, "carry": CARRY * S, "earn_m": 0}
	EconFacts.emit(world, "ECON_TRUCK_BUILT", d, [["COMPANY", owner]], [["COMPANY", owner, 1.0]], {"JOBS": 1}, 5, "PUBLIC",
		{"truck": tid, "maker": maker, "maker_org": maker_org, "owner": owner, "quality": quality})
	return tid


## The driver's business of an org (its TRUCKER facility), "" if none.
static func _fac_of(world: WorldState, oid: String) -> String:
	for fid in EconUtil.sorted_keys(world.peek("facility")):
		var f: Dictionary = world.peek("facility")[fid]
		if f["type"] == TYPE and String(f["org"]) == oid:
			return fid
	return ""


# ------------------------------------------------------------------ monthly (FirmAI.run, before EconTruckShop.monthly)

static func monthly(world: WorldState) -> void:
	if not on(world):
		return
	var s := EconUtil.st(world)
	_adopt(world)
	_earnings(world)
	_wear(world)
	_works_orders(world)
	_scale(world)
	_work_hist(world)
	if world.month % 3 == 0:
		for fid in EconUtil.sorted_keys(world.table("facility")):
			var f: Dictionary = world.table("facility")[fid]
			if f["type"] == TYPE:
				_driver_rules(world, f)
	_publish_need(world)
	s["trk_n"] = world.peek("truck").size()


## Trucks a workshop delivered (Ella's _deliver: no fac) join their owner's business; a business sold to another owner
## takes its trucks with it.
static func _adopt(world: WorldState) -> void:
	for tid in EconUtil.sorted_keys(world.peek("truck")):
		var t: Dictionary = world.table("truck")[tid]
		var fac := String(t.get("fac", ""))
		if fac == "" or not world.peek("facility").has(fac):
			fac = _fac_of(world, String(t["owner"]))
			t["fac"] = fac
			t["carry"] = CARRY * S
			if not t.has("cond_max"):
				t["cond_max"] = 1000
		if fac != "":
			t["owner"] = String(world.peek("facility")[fac]["org"])


## What a month on the road earned each truck's owner last month: its freight revenue ÷ the trucks that ran.
static func _earnings(world: WorldState) -> void:
	var s := EconUtil.peek_st(world)
	var carried: Dictionary = s.get("fr_last", {}).get("carried", {})
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] != TYPE:
			continue
		var oid := String(f["org"])
		var rev := EconUtil.val(int(carried.get(oid, 0)), EconHaulier.rate_of(world, oid)) if world.peek("org").has(oid) else 0
		var per := rev / maxi(1, int(f.get("trk_ran", 0)))
		for tid in EconUtil.sorted_keys(world.peek("truck")):
			var t: Dictionary = world.table("truck")[tid]
			if String(t.get("fac", "")) == fid:
				t["earn_m"] = per


## Age, wear, the self-repair countdown, then new breakdowns; scrapped at cond 0.
static func _wear(world: WorldState) -> void:
	var rng := world.rng.stream("econ.trucks")
	var s := EconUtil.st(world)
	var gone: Array = []
	var broke := 0
	var off := 0
	for tid in EconUtil.sorted_keys(world.peek("truck")):
		var t: Dictionary = world.table("truck")[tid]
		t["age_m"] = int(t.get("age_m", 0)) + 1
		t["cond"] = maxi(0, int(t["cond"]) - DECAY_PM)
		if int(t["cond"]) <= 0:
			gone.append(tid)
			continue
		if int(t.get("repair_m", 0)) > 0:
			t["repair_m"] = int(t["repair_m"]) - 1  # the owner's own repair: no parts, the wear stays
		if _running(t):
			var fac: Dictionary = world.peek("facility").get(String(t.get("fac", "")), {})
			if not fac.is_empty() and not bool(fac["mothball"]) and rng.randf() * 1000.0 < break_pm(int(t["quality"]), int(t["cond"])):
				t["repair_m"] = EconTruckShop.SELF_M
				t["broke_n"] = int(t.get("broke_n", 0)) + 1
				broke += 1
		if not _running(t):
			off += 1
	for tid in gone:
		var t2: Dictionary = world.table("truck")[tid]
		EconFacts.emit(world, "ECON_TRUCK_SCRAPPED", String(t2["district"]), [["COMPANY", String(t2["owner"])]], [["NATURE", "market", 1.0]],
			{}, 3, "PUBLIC", {"truck": tid, "owner": String(t2["owner"]), "age_m": int(t2["age_m"]), "quality": int(t2["quality"]), "maker": String(t2["maker"])})
		world.table("truck").erase(tid)
	s["trk_broke_m"] = broke
	s["trk_off_m"] = off
	var n := world.peek("truck").size()
	if n > 0 and off * 5 >= n and off >= 2:
		# trucks off the road: a fifth of the colony's trucks or more (news; the workshops' grant reads its own need)
		EconFacts.emit(world, "ECON_TRUCKS_OFF_ROAD", "COLONY", [], [["NATURE", "market", 1.0]], {"INFRASTRUCTURE": -2}, 10, "PUBLIC",
			{"off": off, "trucks": n, "broke": broke})


## Each driver's business: scale = its trucks owned and on order (one driver each), and the trucks that run this month.
static func _scale(world: WorldState) -> void:
	var own := {}
	var run := {}
	for tid in world.peek("truck"):
		var t: Dictionary = world.peek("truck")[tid]
		var fac := String(t.get("fac", ""))
		own[fac] = int(own.get(fac, 0)) + 1
		if _running(t):
			run[fac] = int(run.get(fac, 0)) + 1
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] != TYPE:
			continue
		var n := int(own.get(fid, 0)) + on_order(world, String(f["org"]))
		f["scale"] = maxi(1, n) * 1000
		f["trk_ran"] = int(run.get(fid, 0))
		f["trk_own"] = int(own.get(fid, 0))


## Trucks an org has ordered and not yet received (workshops, works, home world).
static func on_order(world: WorldState, oid: String) -> int:
	var n := 0
	var s := EconUtil.peek_st(world)
	for od in s.get("trk_works_orders", []):
		if String(od["owner"]) == oid:
			n += 1
	for od in s.get("trk_home", []):
		if String(od["owner"]) == oid:
			n += 1
	for fid in world.peek("facility"):
		var f: Dictionary = world.peek("facility")[fid]
		if f["type"] == EconTruckShop.TYPE:
			for od in f.get("tw_orders", []):
				if String(od["owner"]) == oid:
					n += 1
	return n


# ------------------------------------------------------------------ the makers

## Every truck a driver in d can buy now: [{kind, seller, quality, price, wait_m}].
static func quotes(world: WorldState, d: String) -> Array:
	var out: Array = []
	for q in EconTruckShop.quotes(world, d):
		out.append({"kind": "WORKSHOP", "seller": String(q["seller"]), "quality": int(q["quality"]), "price": int(q["price"]), "wait_m": int(q["wait_m"])})
	var works := {}
	for fid in EconUtil.sorted_keys(world.peek("facility")):
		var f: Dictionary = world.peek("facility")[fid]
		if f["type"] != "COMPONENTS" or f["mothball"] or works.has(String(f["org"])):
			continue
		var o: Dictionary = world.peek("org").get(f["org"], {})
		if o.is_empty() or not (o["status"] in ["ACTIVE", "DISTRESSED"]):
			continue  # an open works quotes even while starved of material: it builds when it has the parts
		works[String(f["org"])] = true
		var stock := EconUtil.inv_get(world, f["org"], "COMPONENT", f["district"])
		out.append({"kind": "WORKS", "seller": fid, "quality": EconTruckShop.Q_MIN, "price": works_price(world, f),
			"wait_m": 0 if stock >= _parts() * S else 1})
	if out.is_empty() and not EconImports.producing(world, "COMPONENT"):
		out.append({"kind": "HOME", "seller": "home", "quality": Q_HOME, "price": home_price(world), "wait_m": 2})
	return out


## A components works' truck: TRUCK_PARTS of its components at its own price (its crew's time is in that price).
static func works_price(world: WorldState, f: Dictionary) -> int:
	var px := int(f.get("r8_px", int(EconUtil.peek_st(world).get("prices", {}).get("COMPONENT", 0))))
	return _parts() * px


static func home_price(world: WorldState) -> int:
	return _parts() * EconImports.landed(world, "COMPONENT")


## The best value: price ÷ the share of its life the truck is on the road. {} when nothing can be bought.
static func best_quote(world: WorldState, d: String) -> Dictionary:
	var best := {}
	var bv := 0.0
	for q in quotes(world, d):
		var v := float(int(q["price"])) / uptime(int(q["quality"]))
		if best.is_empty() or v < bv:
			best = q
			bv = v
	return best


## The driver `oid` buys the quoted truck for its business `fac`, paying now. false: it cannot pay or the seller is gone.
static func buy(world: WorldState, q: Dictionary, oid: String, fac: String, d: String) -> bool:
	var price := int(q["price"])
	var acct := EconUtil.acct(oid)
	match String(q["kind"]):
		"WORKSHOP":
			return EconTruckShop.order(world, String(q["seller"]), oid, d)
		"WORKS":
			if not world.peek("facility").has(String(q["seller"])) or world.ledger.balance(acct) < price:
				return false
			var wf: Dictionary = world.table("facility")[q["seller"]]
			world.ledger.transfer(acct, EconUtil.acct(wf["org"]), price, "SALE", world.month)
			EconFinance.pl_add(world, wf["org"], "rev", price)
			var s := EconUtil.st(world)
			var ods: Array = s.get("trk_works_orders", [])
			ods.append({"works": String(q["seller"]), "owner": oid, "fac": fac, "district": d, "month": world.month})
			s["trk_works_orders"] = ods
			return true
		"HOME":
			if world.ledger.balance(acct) < price:
				return false
			world.ledger.transfer(acct, Ledger.EXTERNAL, price, "IMPORT", world.month)
			var s2 := EconUtil.st(world)
			var hs: Array = s2.get("trk_home", [])
			hs.append({"owner": oid, "fac": fac, "district": d, "month": world.month, "sailing": false})
			s2["trk_home"] = hs
			return true
	return false


## Special orders at the components works, first ordered first: built when the works has the parts in store.
static func _works_orders(world: WorldState) -> void:
	var s := EconUtil.st(world)
	var keep: Array = []
	for od in s.get("trk_works_orders", []):
		var wf: Dictionary = world.peek("facility").get(String(od["works"]), {})
		if wf.is_empty() or not world.peek("org").has(String(od["owner"])):
			continue  # the works or the buyer is gone: the order lapses (paid, lost)
		if EconUtil.inv_get(world, wf["org"], "COMPONENT", wf["district"]) < _parts() * S:
			keep.append(od)
			continue
		EconUtil.inv_take(world, wf["org"], "COMPONENT", wf["district"], _parts() * S)
		EconUtil.qflow(world, "COMPONENT", "burned", _parts() * S)
		var fac := String(od["fac"]) if world.peek("facility").has(String(od["fac"])) else _fac_of(world, String(od["owner"]))
		_new_truck(world, String(od["owner"]), fac, String(od["district"]), EconTruckShop.Q_MIN, "WORKS", String(wf["org"]))
	s["trk_works_orders"] = keep


## EconTrade.on_ship: the trucks ordered on the last ship come in this one; orders waiting go out on it.
static func on_ship(world: WorldState) -> void:
	if not on(world):
		return
	var s := EconUtil.st(world)
	var keep: Array = []
	for od in s.get("trk_home", []):
		if not world.peek("org").has(String(od["owner"])):
			continue
		if bool(od["sailing"]):
			var fac := String(od["fac"]) if world.peek("facility").has(String(od["fac"])) else _fac_of(world, String(od["owner"]))
			_new_truck(world, String(od["owner"]), fac, String(od["district"]), Q_HOME, "HOME", "home")
		else:
			od["sailing"] = true
			keep.append(od)
	s["trk_home"] = keep


# ------------------------------------------------------------------ the work (all the freight asked, the average)

## Month end: the freight asked of all the carriers (carried by each, and left behind) joins the year's history.
static func _work_hist(world: WorldState) -> void:
	var s := EconUtil.st(world)
	var last: Dictionary = s.get("fr_last", {})
	var asked := int(last.get("deferred", 0))
	var c: Dictionary = last.get("carried", {})
	for oid in c:
		asked += int(c[oid])
	var h: Array = s.get("trk_work_hist", [])
	h.append([asked, int(last.get("deferred", 0))])
	while h.size() > HIST_M:
		h.pop_front()
	s["trk_work_hist"] = h


static func work_avg(world: WorldState) -> float:
	var h: Array = EconUtil.peek_st(world).get("trk_work_hist", [])
	if h.is_empty():
		return 0.0
	var t := 0
	for r in h:
		t += int(r[0])
	return float(t) / float(h.size())


## Every carrier's capacity: the depots' and every truck's (on the road or not) and the trucks on order. `skip`: an org
## not counted (a driver reading its own share).
static func fleet_cap(world: WorldState, skip: String = "") -> float:
	var t := 0.0
	var seen := {}
	for fid in EconUtil.sorted_keys(world.peek("facility")):
		var f: Dictionary = world.peek("facility")[fid]
		if f["type"] == "DEPOT" and not seen.has(String(f["org"])):
			seen[String(f["org"])] = true
			t += float(EconHaulier.full_of(world, String(f["org"])))
	for tid in world.peek("truck"):
		var tr: Dictionary = world.peek("truck")[tid]
		if String(tr["owner"]) != skip:
			t += float(int(tr.get("carry", CARRY * S)))
	var ordered := 0
	var s := EconUtil.peek_st(world)
	for od in (s.get("trk_works_orders", []) as Array) + (s.get("trk_home", []) as Array):
		if String(od["owner"]) != skip:
			ordered += 1
	for fid2 in world.peek("facility"):
		var f2: Dictionary = world.peek("facility")[fid2]
		if f2["type"] == EconTruckShop.TYPE:
			for od2 in f2.get("tw_orders", []):
				if String(od2["owner"]) != skip:
					ordered += 1
	return t + float(ordered * CARRY * S)


## The going rate (mcr per unit and hop): the cheapest carrier's this month, else the transit authority's.
static func going_rate(world: WorldState) -> int:
	var best := -1
	for row in EconUtil.peek_st(world).get("fr_carriers", []):
		if best < 0 or int(row["rate"]) < best:
			best = int(row["rate"])
	return best if best > 0 else int(EconUtil.lever(world, "ECON_FREIGHT_TARIFF", 5)) * S


## One truck more in d over a year (mcr): {volume, revenue, costs, profit, reasons}. Its share of all the freight
## asked; revenue at the going rate for the share of the year it is on the road; costs its fuel, the truck spread over
## the depreciation months (less a grant's share) and the family's living (EconFamily's own-labour cost).
static func forecast(world: WorldState, q: Dictionary, extra_cap: float = 0.0, skip: String = "", pct: int = 0) -> Dictionary:
	var s := EconUtil.peek_st(world)
	var reasons: Array = []
	if q.is_empty():
		return {"volume": 0, "revenue": 0, "costs": 0, "profit": 0, "reasons": ["no_maker"]}
	var cap := float(CARRY * S)
	var share: float = Forecast.share_of_work(world, TYPE, "", cap, "", work_avg(world), fleet_cap(world, skip) + extra_cap)
	var volume := minf(share, cap) * uptime(int(q["quality"]))
	if volume <= 0.0:
		reasons.append("no_work")
	var revenue := float(EconUtil.val(int(volume), going_rate(world))) * 12.0
	var r: Dictionary = EconData.RECIPES[TYPE]
	var fuel := float(r["in"]["ENERGY"]) * float(EconUtil.lever(world, "ECON_UTILITY_TARIFF_ENERGY", 40)) * float(S)
	var keep := float(s["wage"]["G"]) * float(EconUtil.lever(world, "ECON_UNEMPLOYMENT_BENEFIT_RATE", 40)) / 100.0 * EconFamily.FAMILY_WORK_PREMIUM
	var living := minf(float(s["wage"]["G"]), keep) * float(r["labor"]["G"])
	var capital := float(int(q["price"])) * float(100 - clampi(pct, 0, 100)) / 100.0 / float(EconData.DEPRECIATION_MONTHS)
	var costs := (fuel + living + capital) * 12.0
	var profit := int(revenue - costs)
	if profit <= 0 and reasons.is_empty():
		reasons.append("no_profit")
	return {"volume": int(volume), "revenue": int(revenue), "costs": int(costs), "profit": profit, "reasons": reasons}


# ------------------------------------------------------------------ rules 5/6 (quarterly)

static func _driver_rules(world: WorldState, f: Dictionary) -> void:
	var s := EconUtil.st(world)
	var oid := String(f["org"])
	var o: Dictionary = world.table("org").get(oid, {})
	if o.is_empty() or not (o["status"] in ["ACTIVE", "DISTRESSED"]):
		return
	var last: Dictionary = s.get("fr_last", {})
	var room_m := int(f.get("trk_ran", 0)) * CARRY * S
	var ring: Array = f.get("trk_ring", [])
	ring.append([room_m, int(last.get("carried", {}).get(oid, 0)), int(last.get("deferred", 0))])
	while ring.size() > 12:
		ring.pop_front()
	f["trk_ring"] = ring
	var d := String(f["district"])
	var q := best_quote(world, d)
	var acts: Array = s.get("trk_actions", [])
	if f["mothball"]:
		# a parked business drives again when its own share of the work pays
		if int(forecast(world, q, 0.0, oid)["profit"]) > 0:
			f["mothball"] = false
			acts.append([world.month, "reopen", oid])
		s["trk_actions"] = acts
		return
	# rule 6: it lost money over 12 months and its own share of the work no longer pays
	if EconAnnual.months(o) >= 12 and EconPublicCo.result12(o) < 0 and int(forecast(world, q, 0.0, oid)["profit"]) <= 0:
		f["mothball"] = true
		acts.append([world.month, "park", oid])
		s["trk_actions"] = acts
		return
	# rule 5: full in FULL_M of 12 months, freight left behind, earning, and one more truck's share pays
	var full_m := 0
	var left := false
	for h in ring:
		if int(h[0]) > 0 and int(h[1]) * 100 >= int(h[0]) * FULL_PCT:
			full_m += 1
		if int(h[2]) > 0:
			left = true
	if full_m < FULL_M or not left or EconPublicCo.result12(o) <= 0 or on_order(world, oid) > 0 or q.is_empty():
		return
	if int(forecast(world, q)["profit"]) <= 0:
		return
	if not EconRulesMat._finance(world, oid, int(q["price"]), false):
		return
	if buy(world, q, oid, String(f["id"]), d):
		acts.append([world.month, "truck", oid, String(q["kind"])])
		s["trk_actions"] = acts


# ------------------------------------------------------------------ rules 7/8 (founding, monthly)

static func found(world: WorldState) -> void:
	if not on(world):
		return
	var s := EconUtil.st(world)
	# rule 8: a driver of 12 months or more losing money
	for fid in EconUtil.sorted_keys(world.peek("facility")):
		var f: Dictionary = world.peek("facility")[fid]
		if f["type"] != TYPE:
			continue
		var o: Dictionary = world.peek("org").get(f["org"], {})
		if not o.is_empty() and o["status"] in ["ACTIVE", "DISTRESSED"] and EconAnnual.months(o) >= 12 and EconPublicCo.result12(o) < 0:
			_note(s, "driver_losing")
			return
	var extra := 0.0
	var tried := {}
	while true:
		var d := _district(world, tried)
		if d == "":
			return
		var q := best_quote(world, d)
		if q.is_empty():
			_note(s, "no_maker")
			return
		var pct := EconFamily._grant_pct(world, TYPE, d, true)
		var fc := forecast(world, q, extra, "", pct)
		if not (fc["reasons"] as Array).is_empty():
			_note(s, String((fc["reasons"] as Array)[0]))
			return
		var gid := EconFamily._household(world, d)
		if gid == "":
			_note(s, "no_household")
			tried[d] = true
			continue
		if not _start(world, d, gid, q):
			_note(s, "money")
			tried[d] = true
			continue
		extra += float(CARRY * S)


## Where a driver starts: the district where the most freight was left behind last month (its buyers wait there), else
## the one with the most unemployed; `tried`: districts with no family or no money this month.
static func _district(world: WorldState, tried: Dictionary) -> String:
	var s := EconUtil.peek_st(world)
	var best := ""
	var bv := -1
	for d in EconUtil.sorted_keys(EconData.DISTRICTS):
		if not EconUtil.connected(String(d)) or tried.has(d):
			continue
		var v := int(s.get("freight_deferred", {}).get(d, 0)) * 1000 + PopStore.count(world, {"hb": EconPop.hb_of(String(d)), "status": "UNEMPLOYED"})
		if v > bv:
			bv = v
			best = String(d)
	return best


## The plan, then the grant on the accepted truck price (the user: the plan first, the grant after the plan), then the
## business and the truck order. Nothing is left behind when the money is not there.
static func _start(world: WorldState, d: String, gid: String, q: Dictionary) -> bool:
	var s := EconUtil.st(world)
	var pct := EconFamily._grant_pct(world, TYPE, d)
	var m := EconFamily._money(world, TYPE, gid, pct, int(q["price"]))
	if not bool(m["ok"]):
		return false
	var g: Dictionary = world.table("hh")[gid]
	var id := EconFamily._make_org(world, TYPE, d, gid, d)
	world.table("org")[id]["planned_month"] = world.month
	EconFamily._fund_apply(world, id, TYPE, d, gid, pct, m)
	EconPop.make_owner(world, g["hb"], g["band"])
	EconPop.sync(world)
	var fid := EconSetup.add_facility(world, TYPE, id, d, false)
	if not buy(world, q, id, fid, d):
		_note(s, "order_failed")  # paid for by the grant and the loan; the business waits for its next chance (rule 5)
	EconFamily._count_founded(world, id, TYPE, d, pct)
	var first := not bool(s.get("trk_first_told", false))
	if first:
		s["trk_first_told"] = true
		EconFacts.emit(world, "ECON_TRUCK_DRIVER_FIRST", d, [["COMPANY", id]], [["COMPANY", id, 0.6], ["GOVERNMENT", "government", 0.4]],
			{"JOBS": 2, "INFRASTRUCTURE": 3}, 20, "PUBLIC", {"org": id, "district": d, "grant_pct": pct, "maker": String(q["kind"])})
	var fd: Dictionary = s.get("trk_founded", {})
	fd[String(q["kind"])] = int(fd.get(String(q["kind"]), 0)) + 1
	s["trk_founded"] = fd
	return true


static func _note(s: Dictionary, why: String) -> void:
	var f: Dictionary = s.get("trk_fail_found", {})
	f[why] = int(f.get(why, 0)) + 1
	s["trk_fail_found"] = f


# ------------------------------------------------------------------ the grant's need (EconFamily, the legislature)

## Freight was left behind in each of the last NEED_M months.
static func need_any(world: WorldState) -> bool:
	var h: Array = EconUtil.peek_st(world).get("trk_work_hist", [])
	if h.size() < NEED_M:
		return false
	for i in range(h.size() - NEED_M, h.size()):
		if int(h[i][1]) <= 0:
			return false
	return true


## st["lever_need"][LEVER]: 1000 while freight is left behind, -1000 while the grant is offered without that need, else 0.
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


## For the government's choice of the districts a programme covers: freight left behind for buyers in each district
## (units), while the need holds.
static func need_by_district(world: WorldState) -> Dictionary:
	var out := {}
	var s := EconUtil.peek_st(world)
	var need := need_any(world)
	for d in EconUtil.sorted_keys(EconData.DISTRICTS):
		out[d] = int(s.get("freight_deferred", {}).get(d, 0)) / S if need else 0
	return out


## {trucks, running, broken_m, by_maker {kind: n}, drivers, founded {kind}, fail_found, actions} for reports.
static func view(world: WorldState) -> Dictionary:
	var s := EconUtil.peek_st(world)
	var by := {}
	var run := 0
	for tid in world.peek("truck"):
		var t: Dictionary = world.peek("truck")[tid]
		by[String(t["maker"])] = int(by.get(String(t["maker"]), 0)) + 1
		if _running(t):
			run += 1
	var drivers := 0
	for fid in world.peek("facility"):
		var f: Dictionary = world.peek("facility")[fid]
		if f["type"] == TYPE and not f["mothball"]:
			drivers += 1
	return {"trucks": world.peek("truck").size(), "running": run, "broke_m": int(s.get("trk_broke_m", 0)), "by_maker": by,
		"drivers": drivers, "founded": s.get("trk_founded", {}), "fail_found": s.get("trk_fail_found", {}), "actions": s.get("trk_actions", [])}

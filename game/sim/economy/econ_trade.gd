class_name EconTrade
extends RefCounted
const EconImports := preload("res://sim/economy/econ_imports.gd")
## D1 (user decision A42, planning/spec-demand-v1.md §D1): exports and a small import trade on the home-world ships.
## "If the colony can't use something there is no point in making it": outside buyers give plants a reason to run.
##
## State in econ.s["trade"] (integer state):
##   home {good: milli per unit}, home0 (starting price), trend_ppm {good}, last_year {good} (for swing facts),
##   ships [{month, exports {good: units}, export_value, tax, imports {good: units}, import_value, by_org {org: value}}],
##   exported_12m, imports_bought (milli, running), balance_hist
## Each month (COMPANY_AI, after the firms):
##   - home-world prices take a slow random walk with their own trend (bounded HOME_BAND around the start);
##   - export houses: each firm (and the public utility) consigns stock of an exportable good to the port store when
##     the home price net of freight and export tax beats the local price by EXPORT_MARGIN, keeping a month of local
##     sales; the port store is limited (PORT_BASE + PORT_PER_DEPOT per DEPOT). Consignments count as sales for
##     production planning, so plants run fuller between ships.
## On a ship (EconHouseholds._ships → on_ship): the charter quota of colonial goods first (none exist yet — hook for
## M12(2)), then general exports up to the cargo space, pro rata by consigned stock; the exporter is paid from
## EXTERNAL (the home world) at the net home price, the export tax (LAW_EXPORT_TAX) goes to the treasury. Merchants
## then bring IMPORT_SHARE of the export earnings back as CONSUMER / MEDICAL goods, sold in the local market at their
## landed price (paid to EXTERNAL when bought). Goods that don't keep (FOOD, ENERGY, WATER) are not exported.

const S := EconUtil.S
const CO := preload("res://sim/law/charter_ops.gd")
const EXPORT_GOODS := ["MINERAL", "MATERIAL", "COMPONENT", "CONSUMER", "MEDICAL", "CLOTHING", "FURNISHINGS", "FINE_FOOD"]  # D2 goods too
const HOME_MULT := {"MINERAL": 1.4, "MATERIAL": 1.3, "COMPONENT": 1.3, "CONSUMER": 1.2, "MEDICAL": 1.5, "CLOTHING": 1.3, "FURNISHINGS": 1.3, "FINE_FOOD": 1.2}
const FREIGHT_SHARE := {"MINERAL": 0.45, "MATERIAL": 0.35, "COMPONENT": 0.15, "CONSUMER": 0.2, "MEDICAL": 0.1, "CLOTHING": 0.12, "FURNISHINGS": 0.25, "FINE_FOOD": 0.15}
const HOME_BAND := [600, 1500]  # ‰ of the starting home price
const HOME_NOISE := 0.015  # monthly σ of the home price
const TREND_STEP := 300  # ppm/month: the trend's own random walk step
const TREND_MAX := 3000  # ppm/month
const EXPORT_MARGIN := 1.1
const PORT_BASE := 1000  # units
const PORT_PER_DEPOT := 1000
const PORT_GOOD_SHARE := 0.4  # at most this share of the port per good
const IMPORT_SHARE := 0.3
const IMPORT_MIX := {"CONSUMER": 700, "MEDICAL": 300}  # ‰ of the import value
const IMPORT_SHELF_M := 18  # unsold imports are written off after this many months
const IMPORT_MARKUP := 1.3  # imported goods sell at a premium: they fill shortages rather than undercut local plants
const PORT := "port"  # inventory location of consigned export stock
const IMPORTER := "import"  # inventory owner of imported stock (sold for EXTERNAL)
const SWING_PCT := 20


static func _t(world: WorldState) -> Dictionary:
	var s := EconUtil.st(world)
	if not s.has("trade"):
		var home := {}
		var trend := {}
		for g in EXPORT_GOODS:
			home[g] = int(float(EconData.BASE_PRICE[g]) * S * float(HOME_MULT[g]))
			trend[g] = 0
		s["trade"] = {"home": home, "home0": home.duplicate(), "trend_ppm": trend, "last_year": home.duplicate(), "ships": [],
			"imports_bought": 0, "exported_total": 0, "balance_hist": []}
	var tr: Dictionary = s["trade"]
	for g in EXPORT_GOODS:  # goods added later (D2) in older worlds
		if not tr["home"].has(g):
			var h0 := int(float(EconData.BASE_PRICE[g]) * S * float(HOME_MULT[g]))
			tr["home"][g] = h0
			tr["home0"][g] = h0
			tr["trend_ppm"][g] = 0
			tr["last_year"][g] = h0
	return tr


# ------------------------------------------------------------------ queries (Trade window)

## {good: {home, freight, levy, tax, net, local, reserved}} in milli per unit. Anni's charter terms
## (CharterOps.export_terms): a good the home world has reserved sells only to its charter buyer at charter_price_pct %
## of the home price (freight on the buyer); otherwise the home world takes levy_pct of the revenue (it never leaves
## EXTERNAL) and the colony's export tax goes to the treasury.
## A61 (Wilma's treaty / sanction side): months between home-world ships [min, max]; default EconData.SHIP_INTERVAL,
## overridden by world.values["SHIP_INTERVAL"] (an Array of two ints) when a treaty or a sanction sets it.
static func ship_interval(world: WorldState) -> Array:
	var v = world.values.get("SHIP_INTERVAL", null)
	if typeof(v) == TYPE_ARRAY and (v as Array).size() == 2:
		return [int(v[0]), maxi(int(v[0]), int(v[1]))]
	return [int(EconData.SHIP_INTERVAL[0]), int(EconData.SHIP_INTERVAL[1])]


## A61: export cargo a ship can carry (units); default EconData.SHIP_CARGO, overridden by world.values["SHIP_HOLD"].
static func ship_hold(world: WorldState) -> int:
	return maxi(0, int(world.values.get("SHIP_HOLD", EconData.SHIP_CARGO)))


## A61: a home-world tariff on the colony's exports (‰ cut on export income; 0 = none), world.values["HOME_TARIFF"].
static func home_tariff(world: WorldState) -> int:
	return clampi(int(world.values.get("HOME_TARIFF", 0)), 0, 1000)


## Extra home-world ships (HomeWorld, flag SHIPPING; user 2026-11-15: "two ships could take turns"): each is
## {next: month it calls, hold: units} and keeps its own interval. The first ship stays on the ship clock
## (s.ship_next) with ship_hold(). Empty unless the home world built one.
static func fleet(world: WorldState) -> Array:
	return EconUtil.peek_st(world).get("trade", {}).get("fleet", [])


static func add_ship(world: WorldState, next_month: int, hold: int) -> void:
	var t := _t(world)
	if not t.has("fleet"):
		t["fleet"] = []
	(t["fleet"] as Array).append({"next": next_month, "hold": hold})


## Hold of ship `idx` (0 = the first ship, 1.. = the fleet's extra ships).
static func hold_of(world: WorldState, idx: int) -> int:
	var fl := fleet(world)
	return int(fl[idx - 1]["hold"]) if idx >= 1 and idx <= fl.size() else ship_hold(world)


static func set_hold(world: WorldState, idx: int, hold: int) -> void:
	var fl := fleet(world)
	if idx >= 1 and idx <= fl.size():
		_t(world)["fleet"][idx - 1]["hold"] = hold
	else:
		world.values["SHIP_HOLD"] = hold


static func prices(world: WorldState) -> Dictionary:
	var t: Dictionary = EconUtil.peek_st(world).get("trade", {})
	var out := {}
	for g in EXPORT_GOODS:
		var home := int(t.get("home", {}).get(g, int(float(EconData.BASE_PRICE[g]) * S * float(HOME_MULT[g]))))
		var fr := freight(g)
		var terms: Dictionary = CO.export_terms(world, g)
		var gross := maxi(0, home - fr)
		if bool(terms.get("reserved", false)):
			gross = int(float(home) * float(terms.get("charter_price_pct", 35)) / 100.0)
		gross = gross * (1000 - home_tariff(world)) / 1000  # A61: a home-world tariff cuts what the colony is paid
		var levy := int(float(gross) * float(terms.get("levy_pct", 0)) / 100.0)
		var tx := int(float(gross - levy) * float(terms.get("export_tax_pct", 0)) / 100.0)
		out[g] = {"home": home, "freight": fr, "levy": levy, "tax": tx, "net": maxi(0, gross - levy - tx),
			"local": int(EconUtil.peek_st(world).get("prices", {}).get(g, 0)), "reserved": bool(terms.get("reserved", false))}
	return out


static func freight(good: String) -> int:
	return int(float(EconData.BASE_PRICE[good]) * S * float(FREIGHT_SHARE.get(good, 0.3)))


## Units consigned for the next ship: {good: units}.
static func port_stock(world: WorldState) -> Dictionary:
	var out := {}
	for g in EXPORT_GOODS:
		var q := 0
		for oid in world.peek("org"):
			q += EconUtil.inv_get(world, oid, g, PORT)
		if q > 0:
			out[g] = q / S
	return out


static func port_capacity(world: WorldState) -> int:
	var depots := 0
	for fid in world.peek("facility"):
		var f: Dictionary = world.peek("facility")[fid]
		if f["type"] == "DEPOT" and not f["mothball"]:
			depots += 1
	return PORT_BASE + PORT_PER_DEPOT * depots


static func next_ship(world: WorldState) -> int:
	return int(EconUtil.peek_st(world).get("ship_next", -1))


static func last_ship(world: WorldState) -> Dictionary:
	var sh: Array = EconUtil.peek_st(world).get("trade", {}).get("ships", [])
	return {} if sh.is_empty() else sh[sh.size() - 1]


## Trade balance over the last 24 months (milli; ships come every 18–30 months): export earnings − imports bought.
static func balance(world: WorldState) -> Dictionary:
	var t: Dictionary = EconUtil.peek_st(world).get("trade", {})
	var ex := 0
	var im := 0
	for sh in t.get("ships", []):
		if world.month - int(sh["month"]) < 24:
			ex += int(sh["export_value"])
	for h in t.get("balance_hist", []):
		im += int(h)
	return {"exports_24m": ex, "imports_24m": im, "balance_24m": ex - im}


# ------------------------------------------------------------------ monthly (COMPANY_AI)

static func monthly(world: WorldState) -> void:
	if EconUtil.off(world, "D1"):
		return
	var t := _t(world)
	_walk_prices(world, t)
	_consign(world, t)
	_clear_old_imports(world, t)
	_port_full(world, t)
	if exp_on(world):
		var rh: Array = t.get("refused_hist", [])
		rh.append((t.get("refused_m", {}) as Dictionary).duplicate())
		while rh.size() > 12:
			rh.pop_front()
		t["refused_hist"] = rh
	var hist: Array = t["balance_hist"]
	hist.append(int(t.get("imports_m", 0)))
	t["imports_m"] = 0
	while hist.size() > 24:
		hist.pop_front()



static func _walk_prices(world: WorldState, t: Dictionary) -> void:
	var r := world.rng.stream("econ.trade")
	for g in EXPORT_GOODS:
		var tr := clampi(int(t["trend_ppm"].get(g, 0)) + r.randi_range(-TREND_STEP, TREND_STEP), -TREND_MAX, TREND_MAX)
		t["trend_ppm"][g] = tr
		var p := float(t["home"][g]) * (1.0 + float(tr) / 1000000.0 + r.randfn(0.0, HOME_NOISE))
		var p0 := float(t["home0"][g])
		t["home"][g] = clampi(int(p), int(p0 * HOME_BAND[0] / 1000.0), int(p0 * HOME_BAND[1] / 1000.0))
	if world.month_of_year() == 1:
		for g in EXPORT_GOODS:
			var last := float(t["last_year"].get(g, t["home"][g]))
			var pct := int(round(100.0 * (float(t["home"][g]) / maxf(1.0, last) - 1.0)))
			if absi(pct) >= SWING_PCT:
				EconFacts.emit(world, "ECON_HOME_PRICE_SWING", null, [["EXTERNAL", "home_world"]], [["EXTERNAL", "home_world", 1.0]],
					{"JOBS": 5 if pct > 0 else -5}, 30, "PUBLIC", {"good": g, "pct": pct, "price": int(t["home"][g]) / S})
			t["last_year"][g] = t["home"][g]


## Export houses: move stock worth exporting into the port store (a month of local sales stays home).
static func _consign(world: WorldState, t: Dictionary) -> void:
	var px := prices(world)
	var exp := exp_on(world)
	if exp:
		t["refused_m"] = {}
	# stock waiting for a ship goes back to the local market when the colony pays more than the home world
	for g in EXPORT_GOODS:
		if float(px[g]["local"]) <= EXPORT_MARGIN * float(px[g]["net"]):
			continue
		for oid in EconUtil.sorted_keys(world.table("org")):
			var q := EconUtil.inv_get(world, oid, g, PORT)
			if q <= 0:
				continue
			var wac := EconUtil.inv_wac(world, oid, g, PORT)
			var o: Dictionary = world.table("org")[oid]
			var home_d: String = o["hq"] if EconData.DISTRICTS.has(o["hq"]) else "d:1"
			EconUtil.inv_add(world, oid, g, home_d, EconUtil.inv_take(world, oid, g, PORT, q), wac)
	var free := port_capacity(world) * S
	for g in px:
		for oid in world.peek("org"):
			free -= EconUtil.inv_get(world, oid, g, PORT)
	if free <= 0 and not exp:
		return
	# the most valuable cargo first: limited port space goes to the goods that earn most per unit
	var by_value: Array = EXPORT_GOODS.duplicate()
	by_value.sort_custom(func(a, b): return int(px[a]["net"]) > int(px[b]["net"]) or (int(px[a]["net"]) == int(px[b]["net"]) and a < b))
	# only producers export their own output: a builder's or a plant's INPUT stock (materials, components bought for
	# their work) is not for sale abroad (v5 review: builders shipped their construction materials)
	var producers := {}
	for fid in world.table("facility"):
		var ff: Dictionary = world.table("facility")[fid]
		producers[ff["org"] + "|" + str(EconData.RECIPES[ff["type"]]["out"][0])] = true
	for g in by_value:
		for oid in EconUtil.sorted_keys(world.table("org")):
			var o: Dictionary = world.table("org")[oid]
			if o["status"] in ["LIQUIDATION", "DISSOLVED"] or o["type"] == "PUBLIC_INSTITUTION" or not producers.has(oid + "|" + g):
				continue
			if free <= 0 and not exp:
				return
			var p: Dictionary = px[g]
			if float(p["net"]) < EXPORT_MARGIN * float(p["local"]):
				continue
			var stock := 0
			for d in EconUtil.sorted_keys(EconData.DISTRICTS):
				stock += EconUtil.inv_get(world, oid, g, d)
			var keep := _keep(world, o, g)
			var held_g := 0
			for oid2 in world.peek("org"):
				held_g += EconUtil.inv_get(world, oid2, g, PORT)
			var room_g := int(float(port_capacity(world) * S) * PORT_GOOD_SHARE) - held_g  # no single good fills the port
			var q := mini(mini(stock - keep, free / 2 + S), room_g)
			if exp:
				var lim_port := maxi(0, mini(free, room_g))
				if free <= 0:
					q = 0
				if stock - keep > lim_port and stock - keep >= S:
					t["refused_m"][g] = int(t["refused_m"].get(g, 0)) + stock - keep - lim_port  # EXP_PORT: wanted to ship, no port space
			if q < S:
				continue
			var moved := 0
			for d in EconUtil.sorted_keys(EconData.DISTRICTS):
				if moved >= q:
					break
				var wac := EconUtil.inv_wac(world, oid, g, d)
				var took := EconUtil.inv_take(world, oid, g, d, mini(q - moved, EconUtil.inv_get(world, oid, g, d)))
				if took > 0:
					EconUtil.inv_add(world, oid, g, PORT, took, wac)
					moved += took
			free -= moved
			var sold: Dictionary = o.get("sold", {})
			sold[g] = int(sold.get(g, 0)) + moved  # production planning sees export demand
			o["sold"] = sold


# ------------------------------------------------------------------ the ship

## Called when a home-world ship arrives (EconHouseholds._ships). Returns {cargo {good: units}, export_value, imports
## {good: units}, import_value, quota_delivered} for ECON_SHIP_ARRIVED.
static func on_ship(world: WorldState, hold: int = -1) -> Dictionary:
	EconImports.unload(world, hold if hold >= 0 else ship_hold(world))  # ORDER_IN: goods ordered in come in this ship's hold
	if EconUtil.off(world, "D1"):
		return {"cargo": {}, "export_value": 0, "imports": {}, "import_value": 0, "quota_delivered": {}}
	var t := _t(world)
	var px := prices(world)
	var quota := {}  # M12(2): colonial goods first (none exist yet)
	# general exports, pro rata by consigned stock, up to the cargo space
	var total := 0
	var held := {}
	for oid in EconUtil.sorted_keys(world.table("org")):
		for g in EXPORT_GOODS:
			var q := EconUtil.inv_get(world, oid, g, PORT)
			if q > 0:
				held[oid + "|" + g] = q
				total += q
	var cap := (hold if hold >= 0 else ship_hold(world)) * S
	var f := 1.0 if total <= cap else float(cap) / float(total)
	var cargo := {}
	var value := 0
	var tax_total := 0
	var levy_total := 0
	var left := {}
	var by_org := {}
	for k in EconUtil.sorted_keys(held):
		var parts: PackedStringArray = str(k).split("|")
		var oid := parts[0]
		var g := parts[1]
		var q := int(float(held[k]) * f)
		left[g] = int(left.get(g, 0)) + int(held[k]) - maxi(0, q)  # left on the dock (Wilma's shipping pressure)
		if q <= 0:
			continue
		var wac := EconUtil.inv_wac(world, oid, g, PORT)
		q = EconUtil.inv_take(world, oid, g, PORT, q)
		EconUtil.qflow(world, g, "burned", q)  # left the colony
		var pay := EconUtil.val(q, px[g]["net"])
		if g in EconConsumer.GOODS:
			pay = int(float(pay) * (0.6 + 0.008 * float(EconConsumer.rep_of(world, oid, g))))  # D2: the home world pays for quality
		var tax := EconUtil.val(q, px[g]["tax"])
		if pay > 0:
			world.ledger.transfer(Ledger.EXTERNAL, EconUtil.acct(oid), pay, "EXPORT_SALE", world.month)
			EconFinance.pl_add(world, oid, "rev", pay)
			EconFinance.pl_add(world, oid, "cogs", EconUtil.val(q, wac))
		if tax > 0:
			world.ledger.transfer(Ledger.EXTERNAL, EconUtil.TREASURY, tax, "EXPORT_TAX", world.month)
			EconFinance._gov_rev(world, tax)
		cargo[g] = int(cargo.get(g, 0)) + q / S
		value += pay + tax
		tax_total += tax
		levy_total += EconUtil.val(q, px[g]["levy"])  # the home world's share never leaves EXTERNAL
		by_org[oid] = int(by_org.get(oid, 0)) + pay
	t["exported_total"] = int(t["exported_total"]) + value
	# merchants bring goods back for a share of the earnings
	var imports := {}
	var import_value := 0
	var budget := int(float(value) * IMPORT_SHARE)
	for g in EconUtil.sorted_keys(IMPORT_MIX):
		var landed := int(t["home"].get(g, EconData.BASE_PRICE[g] * S)) + freight(g)
		# merchants bring less while their last cargo is still unsold
		var unsold := EconUtil.val(EconUtil.inv_get(world, IMPORTER, g, "d:1"), landed)
		var q := int(float(maxi(0, int(float(budget) * float(IMPORT_MIX[g]) / 1000.0) - unsold)) * S / float(maxi(1, landed)))
		# only what would sell: the local price must reach the landed price with the merchants' markup
		if float(EconUtil.st(world)["prices"].get(g, 0)) < float(landed) * IMPORT_MARKUP:
			q = 0
		if q <= 0:
			continue
		EconUtil.inv_add(world, IMPORTER, g, "d:1", q, landed)
		t["import_landed"] = world.month
		EconUtil.qflow(world, g, "imported", q)
		imports[g] = q / S
		import_value += EconUtil.val(q, landed)
	var rec := {"month": world.month, "exports": cargo, "export_value": value, "tax": tax_total, "levy": levy_total, "imports": imports,
		"import_value": import_value, "by_org": by_org}
	var left_u := {}
	for g in EconUtil.sorted_keys(left):
		if int(left[g]) >= S:
			left_u[g] = int(left[g]) / S
	rec["left"] = left_u
	var sh: Array = t["ships"]
	sh.append(rec)
	while sh.size() > 8:
		sh.pop_front()
	if value > 0:
		var top := ""
		for oid in EconUtil.sorted_keys(by_org):
			if top == "" or int(by_org[oid]) > int(by_org[top]):
				top = oid
		EconFacts.emit(world, "ECON_EXPORTS_SOLD", "d:1", [["EXTERNAL", "home_world"], ["COMPANY", top]], [["COMPANY", top, 0.5],
			["GOVERNMENT", "government", 0.5]], {"JOBS": clampi(value / S / 2000, 2, 30)}, clampi(25 + value / S / 5000, 25, 60), "PUBLIC",
			{"goods": cargo, "value": value / S, "tax": tax_total / S, "levy": levy_total / S, "top_exporter": top, "imports": imports, "import_value": import_value / S})
	return {"cargo": cargo, "export_value": value / S, "imports": imports, "import_value": import_value / S, "quota_delivered": quota}


## Market hook (EconMarket._clear): the importer's stock is offered at its landed price × IMPORT_MARKUP.
static func import_offer(world: WorldState, good: String) -> Dictionary:
	var q := EconUtil.inv_get(world, IMPORTER, good, "d:1")
	if q <= 0:
		return {}
	# unsold imports are marked down 5% a month after landing (to 70% of the landed price)
	var age := world.month - int(EconUtil.peek_st(world).get("trade", {}).get("import_landed", world.month))
	var mark := maxf(0.7, IMPORT_MARKUP - 0.05 * float(age))
	return {"seller": IMPORTER, "acct": Ledger.EXTERNAL, "district": "d:1", "good": good, "qty": q,
		"ask": int(float(EconUtil.inv_wac(world, IMPORTER, good, "d:1")) * mark)}


## Market hook: an import was bought (paid to EXTERNAL); counts toward the trade balance.
static func note_import(world: WorldState, amount: int) -> void:
	var t := _t(world)
	t["imports_m"] = int(t.get("imports_m", 0)) + amount
	t["imports_bought"] = int(t["imports_bought"]) + amount


## SOCIAL: the trade-balance indicator (credits × 1000: export earnings − imports bought, last 12 months).
static func publish(world: WorldState) -> void:
	if EconUtil.off(world, "D1"):
		return
	if not world.indicators.defs.has("ECON_TRADE_BALANCE"):
		return  # worlds built without the economy's indicator rows (some test setups)
	world.set_indicator("econ", "ECON_TRADE_BALANCE", "COLONY", balance(world)["balance_24m"])


## Imports still unsold IMPORT_SHELF_M months after landing are written off (the merchants dump them).
static func _clear_old_imports(world: WorldState, t: Dictionary) -> void:
	if world.month - int(t.get("import_landed", world.month)) < IMPORT_SHELF_M:
		return
	for g in IMPORT_MIX:
		var q := EconUtil.inv_take(world, IMPORTER, g, "d:1", EconUtil.inv_get(world, IMPORTER, g, "d:1"))
		if q > 0:
			EconUtil.qflow(world, g, "burned", q)


## News when the port store is (nearly) full: goods pile up waiting for the ship (once per ship cycle).
static func _port_full(world: WorldState, t: Dictionary) -> void:
	var held := 0
	for g in EXPORT_GOODS:
		for oid in world.peek("org"):
			held += EconUtil.inv_get(world, oid, g, PORT)
	var cap := port_capacity(world) * S
	if held < cap * 95 / 100 or int(t.get("port_full_month", -999)) > int(EconUtil.peek_st(world).get("ship_last", 0)):
		return
	t["port_full_month"] = world.month
	EconFacts.emit(world, "ECON_PORT_FULL", "d:1", [["GOVERNMENT", "government"]], [["GOVERNMENT", "government", 0.5], ["NATURE", "market", 0.5]],
		{"INFRASTRUCTURE": -5, "JOBS": -3}, 25, "PUBLIC", {"units": held / S, "capacity": cap / S, "depots": (port_capacity(world) - PORT_BASE) / PORT_PER_DEPOT,
		"next_ship": next_ship(world)})


# ------------------------------------------------------------------ exports in the eight rules (planning/design-exports.md)
## User 2026-11-16: producers count the home world as a customer: the net home price and the next ship's free hold are
## orders they can reach, in the eight rules and in expected sales; depots grow on cargo the port could not take.
## OPT-IN: EXP (orders), EXP_PORT (depots on refused cargo), EXP_KEEP (keep back current local orders, not past sales).

static func _flag(world: WorldState, f: String) -> bool:
	return EconRules.active(world) and (world.meta.get("on", []) as Array).has(f) and not EconUtil.off(world, f)


static func exp_on(world: WorldState) -> bool:
	return _flag(world, "EXP")


static func port_rule_on(world: WorldState) -> bool:
	return exp_on(world) and _flag(world, "EXP_PORT")


## What a producer keeps back for the colony before consigning: a month of its past local sales (as before), or with
## EXP_KEEP the local orders it can reach now (no limit built on past sales).
static func _keep(world: WorldState, o: Dictionary, g: String) -> int:
	if _flag(world, "EXP_KEEP"):
		var home_d: String = o["hq"] if EconData.DISTRICTS.has(o["hq"]) else "d:1"
		return EconRules.reachable_unfilled(world, g, home_d)
	return int(o["sales_ema"].get(g, 0))


## The ship that calls next: [month, idx] (idx 0 = the first ship on s.ship_next, 1.. = the fleet's extra ships).
static func next_call(world: WorldState) -> Array:
	var best := next_ship(world)
	var idx := 0
	var fl := fleet(world)
	for i in fl.size():
		var m := int(fl[i]["next"])
		if best < 0 or m < best:
			best = m
			idx = i + 1
	return [best, idx]


## The export order book {good: {net, hold_open, per_m}}: net home price (mcr/unit, after freight, levy, tariff, tax),
## the next ship's hold still free (mu, shared by all goods: the cargo that fills it shrinks it for every good) and that
## hold spread over the months to the ship (mu a month). Pure: reads the port store and the trade state.
static func export_book(world: WorldState) -> Dictionary:
	var px := prices(world)
	var consigned := 0
	for g in EXPORT_GOODS:
		for oid in world.peek("org"):
			consigned += EconUtil.inv_get(world, oid, g, PORT)
	var call := next_call(world)
	var free := maxi(0, hold_of(world, int(call[1])) * S - consigned)
	var months := maxi(1, int(call[0]) - world.month) if int(call[0]) >= 0 else 1
	var out := {}
	for g in EXPORT_GOODS:
		var net := int(px[g]["net"])
		var open := free if net > 0 else 0
		out[g] = {"net": net, "hold_open": open, "per_m": open / months}
	return out


## The selling price a producer of `good` plans with: the local price, or the net home price when the ship has room
## and pays more (EXP on). Used by the rules' price tests.
static func plan_price(world: WorldState, good: String) -> int:
	var local := int(EconUtil.peek_st(world).get("prices", {}).get(good, 0))
	if not exp_on(world) or not (good in EXPORT_GOODS):
		return local
	var b: Dictionary = EconUtil.peek_st(world).get("r8", {}).get("export", {}).get(good, {})
	if int(b.get("hold_open", 0)) <= 0:
		return local
	return maxi(local, int(b.get("net", 0)))


## A firm's consigned port stock valued at the net home price, spread over the months to the next ship (mcr a month):
## sales the ship will pay for (EconAnnual.expected_rev).
static func export_month(world: WorldState, oid: String) -> int:
	if not exp_on(world):
		return 0
	var px := prices(world)
	var v := 0
	for g in EXPORT_GOODS:
		var q := EconUtil.inv_get(world, oid, g, PORT)
		if q > 0:
			v += EconUtil.val(q, int(px[g]["net"]))
	if v <= 0:
		return 0
	var nxt := int(next_call(world)[0])
	return v / (maxi(1, nxt - world.month) if nxt >= 0 else 1)


## Months of the last 12 in which producers wanted to consign cargo the port could not take.
static func refused_months(world: WorldState) -> int:
	var n := 0
	for m in EconUtil.peek_st(world).get("trade", {}).get("refused_hist", []):
		var tot := 0
		for g in m:
			tot += int(m[g])
		if tot > 0:
			n += 1
	return n


## Wilma's shipping pressure (home_world.gd): {left_last_ship {good: units}, left_total, refused_12m {good: units},
## hold_open {good: units}}. Integers; a measurement only.
static func export_pressure(world: WorldState) -> Dictionary:
	var t: Dictionary = EconUtil.peek_st(world).get("trade", {})
	var last := last_ship(world)
	var left: Dictionary = last.get("left", {})
	var lt := 0
	for g in left:
		lt += int(left[g])
	var ref := {}
	for m in t.get("refused_hist", []):
		for g in m:
			ref[g] = int(ref.get(g, 0)) + int(m[g])
	for g in ref.keys():
		ref[g] = int(ref[g]) / S
	var ho := {}
	var book := export_book(world)
	for g in book:
		ho[g] = int(book[g]["hold_open"]) / S
	return {"left_last_ship": left.duplicate(), "left_total": lt, "refused_12m": ref, "hold_open": ho}

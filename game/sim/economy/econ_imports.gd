extends RefCounted
## Ordering MATERIAL and COMPONENT in from the home world (ORDER_IN, opt-in until its A/B; the user, 2026-11-16: "Yes
## they may order in"; Wilma's yes to Bob's proposal the same day). Preloaded as EconImports (no class name).
##   WHEN (the user, 2026-11-16: "a thing that was there if they needed it, not the primary means of getting
##     resources"): only while the colony has no working producer of the good, no open plant that made any of it last
##     month (a mothballed, closed-as-unsafe or input-starved plant making nothing is not working). The moment a plant
##     produces it again, no new orders go out; what is already ordered and paid still arrives. No price test.
##   WHO: any buyer whose MATERIAL or COMPONENT order went unfilled this month (plant owners for inputs and upkeep,
##     builders for their jobs, public bodies). It orders what it was short, less what it already has on order, as much
##     as its cash pays.
##   PRICE: the landed price ECON_ORDER_IMPORTS uses (base × IMPORT_MULT × 1.01 a year), paid on order to the home world.
##   DELIVERY: with the next ship, in its hold (a ship arrives as full as it can leave: EconTrade.hold_of), first ordered,
##     first unloaded, to the buyer's district; what does not fit waits for the following ship, already paid.

const S := EconUtil.S
const GOODS := ["MATERIAL", "COMPONENT"]


static func on(world: WorldState) -> bool:
	return (world.meta.get("on", []) as Array).has("ORDER_IN") and not EconUtil.off(world, "ORDER_IN")


static func landed(world: WorldState, good: String) -> int:
	return int(EconData.BASE_PRICE[good] * EconData.IMPORT_MULT * pow(1.01, world.year() - 1)) * S


## EconMarket._fill: a buyer's unfilled MATERIAL / COMPONENT this month, with its limit.
static func note_short(world: WorldState, bid: Dictionary, short: int) -> void:
	if short <= 0 or not (String(bid["good"]) in GOODS) or bid.get("kind", "") != "org" or not on(world):
		return
	var s := EconUtil.st(world)
	var k := String(bid["buyer"]) + "|" + String(bid["good"])
	var m: Dictionary = s.get("imp_short", {})
	var row: Dictionary = m.get(k, {"qty": 0, "limit": 0, "district": String(bid["district"]), "acct": String(bid["acct"])})
	row["qty"] = int(row["qty"]) + short
	row["limit"] = maxi(int(row["limit"]), int(bid["limit"]))
	m[k] = row
	s["imp_short"] = m


## Whether any open plant in the colony made `good` last month.
static func producing(world: WorldState, good: String) -> bool:
	for fid in world.table("facility"):
		var f: Dictionary = world.table("facility")[fid]
		if f["mothball"] or int(f.get("out_last", 0)) <= 0:
			continue
		var r: Dictionary = EconData.RECIPES.get(f["type"], {})
		if not r.is_empty() and String(r["out"][0]) == good:
			return true
	return false


static func _on_order(s: Dictionary, buyer: String, good: String) -> int:
	var n := 0
	for o in s.get("imp_pending", []):
		if String(o["holder"]) == buyer and String(o["good"]) == good:
			n += int(o["qty"])
	return n


## After clearing (EconMarket.trade): order in what was short and is not on order yet.
static func order_round(world: WorldState) -> void:
	var s := EconUtil.st(world)
	var m: Dictionary = s.get("imp_short", {})
	s["imp_short"] = {}
	if not on(world):
		return
	var pend: Array = s.get("imp_pending", [])
	var working := {}
	for g in GOODS:
		working[g] = producing(world, g)
	for k in EconUtil.sorted_keys(m):
		var parts: PackedStringArray = String(k).split("|")
		var buyer := parts[0]
		var good := parts[1]
		var row: Dictionary = m[k]
		var unit := landed(world, good)
		if bool(working[good]):
			continue  # a plant in the colony makes it: the colony's own sellers are the source
		var want := int(row["qty"]) - _on_order(s, buyer, good)
		if want <= 0:
			continue
		var cash := world.ledger.balance(String(row["acct"]))
		want = mini(want, int(float(maxi(0, cash)) * float(S) / float(unit)))
		if want <= 0:
			continue
		var cost := EconUtil.val(want, unit)
		world.ledger.transfer(String(row["acct"]), Ledger.EXTERNAL, cost, "IMPORT", world.month)
		pend.append({"holder": buyer, "good": good, "qty": want, "unit_cost": unit, "district": String(row["district"]), "month": world.month})
		var st_m: Dictionary = s.get("imp_ordered_m", {})
		st_m[good] = int(st_m.get(good, 0)) + want
		s["imp_ordered_m"] = st_m
	s["imp_pending"] = pend


## EconTrade.on_ship: unload ordered goods, first ordered first, up to the ship's hold (units).
static func unload(world: WorldState, hold: int) -> int:
	var s := EconUtil.st(world)
	var pend: Array = s.get("imp_pending", [])
	if pend.is_empty():
		return 0
	var room := hold * S
	var keep: Array = []
	var landed_q := 0
	for o in pend:
		var q := mini(int(o["qty"]), room)
		if q > 0 and world.table("org").has(String(o["holder"])):
			EconUtil.inv_add(world, String(o["holder"]), String(o["good"]), String(o["district"]), q, int(o["unit_cost"]))
			EconUtil.qflow(world, String(o["good"]), "imported", q)
			room -= q
			landed_q += q
			o["qty"] = int(o["qty"]) - q
		elif not world.table("org").has(String(o["holder"])):
			o["qty"] = 0  # the buyer is gone: the goods are not shipped (paid, lost)
		if int(o["qty"]) > 0:
			keep.append(o)
	s["imp_pending"] = keep
	return landed_q

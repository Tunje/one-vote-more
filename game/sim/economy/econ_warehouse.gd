class_name EconWarehouse
extends RefCounted
## §9 Warehouses: stock needs space (user: "Where are reserves kept, considering we have had issues with reserves being
## stockpiled? Do they buy warehouses? Do they then have workers?"; planning/plan-support-economy.md §9).
##   FREE BUFFER: each organisation keeps BUF_M months of its own sales of a good it makes (FOOD: FOOD_BUF_M — Wilma's
##     condition: a harvest glut must not feed the food trap) on the shop floor or plant yard, free. Inputs it does not
##     make stay free (v1). The government's reserve ("gov") has no free buffer.
##   SPACE: stock above the buffer must sit in a warehouse. CTA (the transport operator, LOGISTICS) runs the colony's
##     storage halls: CAPACITY units each. Space is shared pro rata when demand exceeds capacity.
##   RENT: RENT_PM ‰ of the good's market price per unit-month, holder → CTA (the reserve's rent from the treasury,
##     booked to ECON_BUDGET_RESERVE_PURCHASES). A holder that cannot pay loses the space it could not pay for.
##   STAFF: the WAREHOUSE site's posts are paid from the rent (WAGE_SHARE of its smoothed revenue).
##   GROWTH: BUILD_SHARE of the rent buys MATERIAL; a new hall opens for HALL_MATERIAL units once halls run over 90%.
##   SHRINKAGE: stored stock loses IN_PM ‰ a month (damage, theft); stock with no space OUT_PM ‰ (FOOD: OUT_FOOD_PM —
##     food is not destroyed fast while households may be hungry); the buffer is unchanged from today.
## OPT-IN until its A/B (world.meta["on"] has "WAREHOUSE").

const S := EconUtil.S
const BUF_M := 1
const FOOD_BUF_M := 3
const CAPACITY := 2000 * 1000  # milli-units per hall
const RENT_PM := 6
const WAGE_SHARE := 0.8
const BUILD_SHARE := 0.2
const HALL_MATERIAL := 300 * 1000
const IN_PM := 2
const OUT_PM := 30
const OUT_FOOD_PM := 10
const POSTS_PER_UNIT := 5
const EMA_KEEP := 0.8
const RESERVE_LINE := "ECON_BUDGET_RESERVE_PURCHASES"


static func active(world: WorldState) -> bool:
	return world.meta.has("on") and (world.meta["on"] as Array).has("WAREHOUSE") and not EconUtil.off(world, "WAREHOUSE")


static func _site(world: WorldState, oid: String) -> Dictionary:
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["org"] == oid and f["type"] == "WAREHOUSE":
			return f
	return {}


## Stock that needs space: [{key, holder, good, need}] in sorted order (milli-units).
static func _needs(world: WorldState) -> Array:
	var out: Array = []
	var inv: Dictionary = world.table("inv")
	var orgs: Dictionary = world.table("org")
	for k in EconUtil.sorted_keys(inv):
		var parts: PackedStringArray = String(k).split("|")
		var holder := parts[0]
		var good := parts[1]
		var q := int(inv[k]["q"])
		if q <= 0 or not EconData.BASE_PRICE.has(good):
			continue
		var free := 0
		if holder == "gov":
			free = 0
		elif orgs.has(holder):
			var ema: Dictionary = orgs[holder].get("sales_ema", {})
			if not ema.has(good):
				continue  # an input it does not make: free (v1)
			free = int(ema[good]) * (FOOD_BUF_M if good == "FOOD" else BUF_M)
		else:
			continue
		if q > free:
			out.append({"key": k, "holder": holder, "good": good, "need": q - free})
	return out


static func _rent(world: WorldState, good: String, qty: int) -> int:
	return int(float(qty) / float(S) * float(int(EconUtil.st(world)["prices"].get(good, 0))) * float(RENT_PM) / 1000.0)


## COMPANY_AI, before FirmAI.run: allocate space, charge rent, shrink, staff the halls, grow.
static func monthly(world: WorldState) -> void:
	if not active(world):
		return
	var cta := EconFinance.org_by_key(world, "CTA")
	if cta == "":
		return
	var s := EconUtil.st(world)
	var needs := _needs(world)
	var demand := 0
	for n in needs:
		demand += int(n["need"])
	var f := _site(world, cta)
	if f.is_empty():
		var fid := EconSetup.add_facility(world, "WAREHOUSE", cta, "d:1", false)
		world.table("facility")[fid]["book"] = 0
		f = world.table("facility")[fid]
		f["halls"] = demand / CAPACITY + 1  # the founding halls: room for what the colony holds today
	var cap := int(f["halls"]) * CAPACITY
	var share := 1.0 if demand <= cap else float(cap) / float(demand)
	var inv: Dictionary = world.table("inv")
	var rev := 0
	var stored_all := 0
	var short_all := 0  # no space: the halls could not take it (demand over capacity)
	var unpaid_all := 0  # space was there but the holder could not pay the rent for it
	var reserve_rent := 0
	var shrunk := 0
	for n in needs:
		var want := int(float(int(n["need"])) * share)
		var rent := _rent(world, n["good"], want)
		var paid := 0
		if rent > 0:
			if n["holder"] == "gov":
				paid = EconFinance.gov_pay(world, EconUtil.acct(cta), rent, "STORAGE_RENT")
				reserve_rent += paid
			else:
				paid = EconUtil.pay_upto(world, EconUtil.acct(n["holder"]), EconUtil.acct(cta), rent, "STORAGE_RENT")
		rev += paid
		var stored := want if rent <= 0 else int(float(want) * float(paid) / float(rent))
		var unstored := int(n["need"]) - stored
		var r: Dictionary = inv[n["key"]]
		var lost := stored * IN_PM / 1000 + unstored * (OUT_FOOD_PM if n["good"] == "FOOD" else OUT_PM) / 1000
		lost = mini(lost, int(r["q"]))
		if lost > 0:
			r["q"] = int(r["q"]) - lost
			EconUtil.qflow(world, n["good"], "burned", lost)
			shrunk += lost
		stored_all += stored
		short_all += int(n["need"]) - want
		unpaid_all += maxi(0, want - stored)
	if reserve_rent > 0:
		EconFinance._spend_line(world, RESERVE_LINE, reserve_rent)
	EconFinance.pl_add(world, cta, "rev", rev)
	var ema := int(EMA_KEEP * float(s.get("storage_rev_ema", rev)) + (1.0 - EMA_KEEP) * float(rev))
	s["storage_rev_ema"] = ema
	var posts := int(float(ema) * WAGE_SHARE / float(maxi(1, int(s["wage"]["G"]))))
	f["scale"] = posts * 1000 / POSTS_PER_UNIT
	f["T"] = 1000
	f["stored"] = stored_all
	f["no_space"] = short_all
	f["unpaid"] = unpaid_all
	f["demand"] = demand
	f["shrunk"] = shrunk
	# growth: a new hall from MATERIAL when the halls run over 90%
	var mat := EconUtil.inv_get(world, cta, "MATERIAL", "d:1")
	if demand * 10 > cap * 9 and mat >= HALL_MATERIAL:
		EconUtil.inv_take(world, cta, "MATERIAL", "d:1", HALL_MATERIAL)
		EconUtil.qflow(world, "MATERIAL", "burned", HALL_MATERIAL)
		f["halls"] = int(f["halls"]) + 1
		mat -= HALL_MATERIAL
	var price := int(s["prices"].get("MATERIAL", 0))
	if price > 0 and demand * 10 > cap * 8 and mat < HALL_MATERIAL:
		var qty := mini(int(float(ema) * BUILD_SHARE * float(S) / float(price)), HALL_MATERIAL - mat)
		if qty > 0:
			s["orders"].append({"buyer": cta, "acct": EconUtil.acct(cta), "district": "d:1", "good": "MATERIAL", "qty": qty,
				"limit": price * 3 / 2, "class": EconMarket.C_FIRM, "kind": "org"})
	if short_all > 0 and world.month - int(s.get("storage_news_m", -99)) >= 12:
		s["storage_news_m"] = world.month
		EconFacts.emit(world, "ECON_STORAGE_SHORTAGE", "d:1", [["COMPANY", cta]], [["COMPANY", cta, 0.5], ["GOVERNMENT", "government", 0.5]],
			{"INFRASTRUCTURE": -5, "COST_OF_LIVING": -3}, 20, "PUBLIC",
			{"no_space": short_all / S, "unpaid": unpaid_all / S, "stored": stored_all / S, "halls": int(f["halls"]), "capacity": cap / S})


## {halls, capacity, stored, no_space, demand (units), posts} for probes and the coming panel.
static func summary(world: WorldState) -> Dictionary:
	var cta := EconFinance.org_by_key(world, "CTA")
	var f := {} if cta == "" else _site(world, cta)
	if f.is_empty():
		return {}
	return {"halls": int(f.get("halls", 0)), "capacity": int(f.get("halls", 0)) * CAPACITY / S, "stored": int(f.get("stored", 0)) / S,
		"no_space": int(f.get("no_space", 0)) / S, "unpaid": int(f.get("unpaid", 0)) / S, "demand": int(f.get("demand", 0)) / S, "shrunk": int(f.get("shrunk", 0)) / S, "posts": EconLabor.staff_total(f["staff"]) / S}

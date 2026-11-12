class_name EconHouseholds
extends RefCounted
## SOCIAL phase, household side (spec §7): consumption, services, next month's orders, housing, demography,
## migration, pollution. Indicators and the census are published by EconIndicators afterwards.

const S := EconUtil.S


static func persons(g: Dictionary) -> int:
	return g["lf"] + g["nonpart"] + g["retired"] + g["children"] + g["owners"]


static func adults(g: Dictionary) -> int:
	return g["lf"] + g["nonpart"] + g["retired"] + g["owners"]


static func households(g: Dictionary) -> int:
	return int(float(persons(g)) / EconData.HOUSEHOLD_SIZE)


static func population_by_district(world: WorldState) -> Dictionary:
	var out := {}
	for gid in EconUtil.sorted_keys(world.table("hh")):
		var g: Dictionary = world.table("hh")[gid]
		out[g["district"]] = out.get(g["district"], 0) + persons(g)
	return out


static func units_by_district(world: WorldState) -> Dictionary:
	var out := {}
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] == "HOUSING" and not f["mothball"]:
			out[f["district"]] = out.get(f["district"], 0) + 50 * S
	return out


## Monthly disposable income of a group (mcr), from this month's settlement.
static func disposable(g: Dictionary) -> int:
	var i: Dictionary = g["income"]
	return i.get("wages", 0) + i.get("benefit", 0) + i.get("pension", 0) + i.get("dividend", 0) + i.get("self", 0)


## Essentials cost per month for the group at current prices (mcr).
static func essentials_cost(world: WorldState, g: Dictionary) -> int:
	var s := EconUtil.st(world)
	var p := float(persons(g)) / S
	var e := p * EconData.NEED["FOOD"] * float(s["prices"]["FOOD"]) + p * EconData.NEED["CONSUMER_MIN"] * float(s["prices"]["CONSUMER"]) \
		+ p * EconData.NEED["ENERGY"] * float(EconUtil.lever(world, "ECON_UTILITY_TARIFF_ENERGY", 40)) * S \
		+ p * EconData.NEED["WATER"] * float(EconUtil.lever(world, "ECON_UTILITY_TARIFF_WATER", 20)) * S \
		+ float(households(g)) / S * float(EconFinance.district_rent(world, g["district"]))
	return int(e)


static func social(world: WorldState) -> void:
	var s := EconUtil.st(world)
	_consume(world)
	_buy_media(world)
	_buy_services(world)
	if not EconUtil.off(world, "BANDS"):
		# M10 / E92: income EMAs update monthly; people change band (and pool) once a year, in January
		EconPop.reclassify(world, world.month_of_year() == 1 or EconUtil.off(world, "BANDS_YEARLY"))
	_self_employment_flow(world)
	EconLabor.recount(world)
	_post_orders(world)
	_housing(world)
	_demography(world)
	if EconUtil.support(world):
		if (world.month + 1) % 3 == 0:
			_ship_migrants(world, EconData.SHIP_MIGRANTS, true)  # old model: a migrant shuttle every quarter
	else:
		_ships(world)  # M12 §4: rare home-world ships
	_pollution(world)
	_famine_check(world)
	for gid in EconUtil.sorted_keys(world.table("hh")):
		var g: Dictionary = world.table("hh")[gid]
		g["income_last"] = g["income"].duplicate()
		# habit: slow EMA of the income-based discretionary budget (E70)
		var raw := int(EconData.DISC_PROPENSITY * maxi(0, disposable(g) - essentials_cost(world, g)))
		g["disc_habit"] = int(0.9 * float(g.get("disc_habit", raw)) + 0.1 * float(raw))


## E61: origin humanitarian backstop. After 2 months of colony food shortfall > 10%, the origin ships emergency
## rations covering up to 30% of each group's food need (free). Famine stays possible in deep collapse.
static func _food_aid(world: WorldState) -> void:
	if not EconUtil.support(world):
		return  # M12: no food transports from the home world
	var s := EconUtil.st(world)
	s["aid_streak"] = s.get("aid_streak", 0) + 1 if s.get("food_shortfall", 0) > 100 else 0
	if s["aid_streak"] < 2:
		return
	var total := 0
	for gid in EconUtil.sorted_keys(world.table("hh")):
		var g: Dictionary = world.table("hh")[gid]
		var need := int(persons(g) * EconData.NEED["FOOD"])
		var have: int = g["bought"].get("FOOD", 0)
		var aid := mini(maxi(0, need - have), need * 3 / 10)
		if aid > 0:
			g["bought"]["FOOD"] = have + aid
			total += aid
	if total > 0:
		EconUtil.qflow(world, "FOOD", "imported", total)
		EconFacts.emit(world, "ECON_FOOD_AID", null, [["EXTERNAL", "origin"]], [["EXTERNAL", "origin", 0.4], ["GOVERNMENT", "government", 0.6]],
			{"GOVERNANCE": -10, "COST_OF_LIVING": 5}, 50, "PUBLIC", {"qty": total / S})


static func _consume(world: WorldState) -> void:
	var s := EconUtil.st(world)
	_food_aid(world)
	var short_food := 0
	var need_food := 0
	var short_d := {}
	var need_d := {}
	for gid in EconUtil.sorted_keys(world.table("hh")):
		var g: Dictionary = world.table("hh")[gid]
		var p := persons(g)
		var food_need := int(p * EconData.NEED["FOOD"])
		var cons_need := int(p * EconData.NEED["CONSUMER_MIN"])
		var food: int = g["bought"].get("FOOD", 0)
		var cons: int = g["bought"].get("CONSUMER", 0)
		var sv: Array = s.get("util_served_hh", {}).get(g["district"], [1.0, 1.0])
		var unmet_food := maxi(0, food_need - food)
		var unmet_cons := maxi(0, cons_need - cons)
		var unmet_e := int(p * EconData.NEED["ENERGY"] * (1.0 - float(sv[0])))
		var unmet_w := int(p * EconData.NEED["WATER"] * (1.0 - float(sv[1])))
		var paid_util: int = g.get("util_paid", -1)
		g["unmet"] = {"FOOD": unmet_food, "CONSUMER": unmet_cons, "ENERGY": unmet_e, "WATER": unmet_w}
		short_food += unmet_food
		need_food += food_need
		var d: String = g["district"]
		var need_tot := food_need + cons_need + int(p * (EconData.NEED["ENERGY"] + EconData.NEED["WATER"]))
		short_d[d] = short_d.get(d, 0) + unmet_food + unmet_cons + unmet_e + unmet_w
		need_d[d] = need_d.get(d, 0) + need_tot
		EconUtil.qflow(world, "FOOD", "burned", food)
		EconUtil.qflow(world, "CONSUMER", "burned", cons)
		if g["bought"].has("MEDICAL"):
			EconUtil.qflow(world, "MEDICAL", "burned", g["bought"]["MEDICAL"])
		EconConsumer.absorb(world, g)  # D2: durables into the home stock (which wears), fine food eaten
	s["food_shortfall"] = int(1000.0 * float(short_food) / maxf(1.0, float(need_food)))
	s["shortfall_d"] = {}
	for d in need_d:
		s["shortfall_d"][d] = int(1000.0 * float(short_d[d]) / maxf(1.0, float(need_d[d])))
		if s["shortfall_d"][d] >= 50:
			var big := food_buyers(world)
			var resp: Array = [["GOVERNMENT", "government", 0.6], ["NATURE", "market", 0.4]]
			if not big.is_empty():
				resp = [["GOVERNMENT", "government", 0.5], ["NATURE", "market", 0.25], ["COMPANY", big[0]["org"], 0.25]]
			EconFacts.emit(world, "ECON_SHORTAGE", d, [], resp,
				{"COST_OF_LIVING": -mini(60, int(0.3 * s["shortfall_d"][d]))}, int(0.2 * s["shortfall_d"][d]), "PUBLIC",
				{"shortfall_permille": s["shortfall_d"][d], "big_buyers": big}, {"districts": [d]})


## Discretionary budget (mcr) for this month (spec §7.3).
static func discretionary_budget(world: WorldState, g: Dictionary) -> int:
	var disp := disposable(g)
	var ess := essentials_cost(world, g)
	var surplus := maxi(0, disp - ess)
	var savings := world.ledger.balance(EconUtil.hh_acct(g["id"]))
	var excess := maxi(0, savings - EconData.SAVINGS_TARGET_MONTHS * ess)
	var b := int(EconData.DISC_PROPENSITY * surplus + EconData.EXCESS_SAVINGS_SPEND * excess)
	# E70 consumption smoothing: keep ≥ 60% of the habitual discretionary budget, drawn from savings above 1 month of essentials
	var habit: int = g.get("disc_habit", b)
	var share := float(world.meta.get("disc_smooth_share", EconData.DISC_SMOOTH_SHARE))  # meta override only for A/B tests
	var floor_b := mini(int(share * habit), maxi(0, savings - ess))
	return maxi(b, floor_b)


## Media M4 (Anni/Bob split): households buy newspaper copies from Media.demand() = {hh group id: {outlet id: copies
## (milli)}} at the outlet's price_mw × W_ref / 1000 per copy-month, paid hh → the outlet's account, out of the
## services share of the discretionary budget (papers compete with services, not with essentials). A group that cannot
## pay for everything it wants buys pro rata less. What was bought goes back to Media.record_sales.
static func _buy_media(world: WorldState) -> void:
	for gid0 in world.table("hh"):
		world.table("hh")[gid0]["media_spent"] = 0
	if EconUtil.off(world, "MEDIA_M4") or world.peek("outlet").is_empty():
		return
	var dem: Dictionary = Media.demand(world)
	var wref := int(world.values.get("ECON_W_REF", 1200 * S))
	var outlets: Dictionary = world.peek("outlet")
	var sold := {}
	for gid in EconUtil.sorted_keys(dem):
		if not world.table("hh").has(gid) or typeof(dem[gid]) != TYPE_DICTIONARY:
			continue  # not an hh group key (older demand format): nothing to buy
		var g: Dictionary = world.table("hh")[gid]
		var want: Dictionary = dem[gid]
		var cost := 0
		var price := {}
		for oid in EconUtil.sorted_keys(want):
			if not outlets.has(oid) or String(outlets[oid].get("status", "")) != "ACTIVE":
				continue
			price[oid] = int(outlets[oid].get("price_mw", 0)) * wref / 1000
			cost += int(want[oid]) * int(price[oid]) / S
		if cost <= 0:
			continue
		var budget := int((1.0 - EconData.DISC_CONSUMER_SHARE) * discretionary_budget(world, g))
		budget = maxi(0, mini(budget, world.ledger.balance(EconUtil.hh_acct(gid))))
		var f := minf(1.0, float(budget) / float(cost))
		var spent := 0
		for oid in EconUtil.sorted_keys(price):
			var q := int(float(want[oid]) * f)
			var amt := q * int(price[oid]) / S
			if q <= 0 or amt <= 0:
				continue
			var paid := EconUtil.pay_upto(world, EconUtil.hh_acct(gid), String(outlets[oid].get("account", "media:" + oid)), amt, "MEDIA_COPIES")
			if paid <= 0:
				continue
			if paid < amt:
				q = int(float(q) * float(paid) / float(amt))
			spent += paid
			sold[oid] = int(sold.get(oid, 0)) + q
		g["media_spent"] = spent
	Media.record_sales(world, sold)


## Media M4: an outlet's running costs paid as wages to the district's household groups (journalists, printers,
## distribution: service-sector income stays in the closed colony), split by employed count. Pays only what the
## outlet's account holds; returns the amount paid.
static func pay_media_wages(world: WorldState, from_acct: String, amount: int, district: String) -> int:
	if amount <= 0:
		return 0
	var amt := mini(amount, maxi(0, world.ledger.balance(from_acct)))
	var gids: Array = []
	var w: Array = []
	for gid in EconUtil.sorted_keys(world.table("hh")):
		var g: Dictionary = world.table("hh")[gid]
		if g["district"] == district or district == "":
			gids.append(gid)
			w.append(maxi(1, EconLabor.employed(g)))
	if amt <= 0 or gids.is_empty():
		return 0
	var parts := EconUtil.split_lr(amt, w)
	var paid := 0
	for i in gids.size():
		var a: int = parts[i]
		if a <= 0:
			continue
		var p := EconUtil.pay_upto(world, from_acct, EconUtil.hh_acct(gids[i]), a, "MEDIA_WAGES")
		if p > 0:
			world.table("hh")[gids[i]]["income"]["wages"] += p
			EconPop.credit_status(world, gids[i], "EMPLOYED", p, "wages")
			paid += p
	return paid


static func _buy_services(world: WorldState) -> void:
	var s := EconUtil.st(world)
	var hubs_by_d := {}
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] == "SERVICEHUB" and f["svc_cap"] > 0:
			hubs_by_d[f["district"]] = hubs_by_d.get(f["district"], []) + [fid]
	for fid in hubs_by_d.values().reduce(func(acc, l): return acc + l, []):
		world.table("facility")[fid]["svc_sold"] = 0
	var demand_d := {}
	var sold_d := {}
	for gid0 in world.table("hh"):
		world.table("hh")[gid0]["svc_spent"] = 0
	for gid in EconUtil.sorted_keys(world.table("hh")):
		var g: Dictionary = world.table("hh")[gid]
		var d: String = g["district"]
		var budget := int((1.0 - EconData.DISC_CONSUMER_SHARE) * discretionary_budget(world, g)) - int(g.get("media_spent", 0))
		budget = maxi(0, mini(budget, world.ledger.balance(EconUtil.hh_acct(gid))))
		var price: int = s["svc_price"][d]
		var want := int(float(budget) * S / float(maxi(1, price)))
		demand_d[d] = demand_d.get(d, 0) + want
		var sources: Array = []
		for fid in hubs_by_d.get(d, []):
			sources.append([fid, price])
		for n in EconUtil.neighbours(d):
			for fid in hubs_by_d.get(n, []):
				sources.append([fid, price * 11 / 10])
		var left := want
		for src in sources:
			if left <= 0:
				break
			var f: Dictionary = world.table("facility")[src[0]]
			var take := mini(left, f["svc_cap"])
			var cost := EconUtil.val(take, src[1])
			cost = mini(cost, world.ledger.balance(EconUtil.hh_acct(gid)))
			take = int(float(cost) * S / float(maxi(1, src[1])))
			if take <= 0:
				continue
			world.ledger.transfer(EconUtil.hh_acct(gid), EconUtil.acct(f["org"]), cost, "SALE", world.month)
			var vpaid := EconUtil.pay_upto(world, EconUtil.hh_acct(gid), EconUtil.TREASURY, int(float(cost) * float(EconUtil.lever(world, "ECON_SALES_TAX", 0)) / 100.0), "SALES_TAX")
			EconFinance._gov_rev(world, vpaid)
			EconFinance.pl_add(world, f["org"], "rev", cost)
			f["svc_cap"] -= take
			f["svc_sold"] = f.get("svc_sold", 0) + take
			g["svc_spent"] = g.get("svc_spent", 0) + cost
			left -= take
			sold_d[f["district"]] = sold_d.get(f["district"], 0) + take
			g["spent_goods"] = g.get("spent_goods", 0) + cost
	_self_employed_sales(world, demand_d)
	# district service prices (alpha rule on local supply/demand)
	var supply_d := {}
	for fid in world.table("facility"):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] == "SERVICEHUB":
			supply_d[f["district"]] = supply_d.get(f["district"], 0) + f["out_last"]
	for gid in world.table("hh"):
		var g2: Dictionary = world.table("hh")[gid]
		supply_d[g2["district"]] = supply_d.get(g2["district"], 0) + g2.get("self_emp", 0) * EconData.SELF_EMP_OUTPUT
	for d in EconUtil.sorted_keys(s["svc_price"]):
		var dd := float(demand_d.get(d, 0))
		var ss := float(supply_d.get(d, 0))
		if dd <= 0.0 and ss <= 0.0:
			continue
		var p := float(s["svc_price"][d])
		var base := float(EconData.BASE_SERVICES_PRICE * S)
		p *= 1.0 + EconData.ALPHA * (dd - ss) / maxf(maxf(dd, ss), float(S))
		s["svc_price"][d] = int(clampf(p, base * EconData.PRICE_MIN_MULT, base * EconData.PRICE_MAX_MULT * EconMarket.wage_level(world)))


## E67 sole proprietors: unmet local service demand (after hubs) is served by self-employed residents of the district,
## who are paid by the buying households (money stays in the household sector; income tax withheld on profit).
static func _self_employed_sales(world: WorldState, demand_d: Dictionary) -> void:
	var s := EconUtil.st(world)
	var sellers := {}  # district -> [gid]
	for gid in EconUtil.sorted_keys(world.table("hh")):
		var g: Dictionary = world.table("hh")[gid]
		g["self_rev"] = 0
		if g.get("self_emp", 0) > 0:
			if not sellers.has(g["district"]):
				sellers[g["district"]] = []
			sellers[g["district"]].append(gid)
	var sold_by_d := {}
	for d in EconUtil.sorted_keys(sellers):
		var cap := 0
		for gid in sellers[d]:
			cap += world.table("hh")[gid]["self_emp"] * EconData.SELF_EMP_OUTPUT
		var price: int = s["svc_price"].get(d, EconData.BASE_SERVICES_PRICE * S)
		var left_cap := cap
		# buyers: residual service budgets of the district's households
		for bid in EconUtil.sorted_keys(world.table("hh")):
			var b: Dictionary = world.table("hh")[bid]
			if b["district"] != d or left_cap <= 0:
				continue
			var budget: int = int((1.0 - EconData.DISC_CONSUMER_SHARE) * discretionary_budget(world, b)) - b.get("svc_spent", 0)
			budget = mini(budget, world.ledger.balance(EconUtil.hh_acct(bid)))
			var q := mini(left_cap, int(float(maxi(budget, 0)) * S / float(maxi(1, price))))
			if q <= 0:
				continue
			var cost := EconUtil.val(q, price)
			var parts := EconUtil.split_lr(cost, sellers[d].map(func(x): return float(world.table("hh")[x]["self_emp"])))
			for i in sellers[d].size():
				var sg: String = sellers[d][i]
				if parts[i] > 0 and sg != bid:
					world.ledger.transfer(EconUtil.hh_acct(bid), EconUtil.hh_acct(sg), parts[i], "SALE", world.month)
					world.table("hh")[sg]["self_rev"] += parts[i]
			left_cap -= q
			b["spent_goods"] = b.get("spent_goods", 0) + cost
		sold_by_d[d] = cap - left_cap
	# income tax on proprietors' earnings above the allowance
	var rate := float(EconUtil.lever(world, "ECON_INCOME_TAX_RATE", 24)) / 100.0
	var allowance := float(EconUtil.lever(world, "ECON_TAX_ALLOWANCE", 300)) * S
	for gid in EconUtil.sorted_keys(world.table("hh")):
		var g: Dictionary = world.table("hh")[gid]
		var n := float(g.get("self_emp", 0)) / S
		if n <= 0.0:
			continue
		var per := float(g["self_rev"]) / n
		var tax := int(rate * maxf(0.0, per - allowance) * n)
		var paid := EconUtil.pay_upto(world, EconUtil.hh_acct(gid), EconUtil.TREASURY, tax, "INCOME_TAX")
		EconFinance._gov_rev(world, paid)
		g["income"]["self"] = g["self_rev"] - paid
		g["income"]["tax"] = g["income"].get("tax", 0) + paid
		EconPop.credit_status(world, gid, "EMPLOYED", g["self_rev"] - paid, "self", "BUSINESS_OWNER")


## E67 entry/exit of sole proprietors (emerges from unemployment, savings and local service prices).
## M10: proprietors are BUSINESS_OWNER|EMPLOYED people; entry and exit are PopStore transfers within the pool.
## Flows are computed in milli-persons and paid out in whole persons, the remainder carried per pool.
static func _self_employment_flow(world: WorldState) -> void:
	var s := EconUtil.st(world)
	var benefit := float(s["wage"]["G"]) * float(EconUtil.lever(world, "ECON_UNEMPLOYMENT_BENEFIT_RATE", 40)) / 100.0
	for gid in EconUtil.sorted_keys(world.table("hh")):
		var g: Dictionary = world.table("hh")[gid]
		var se: int = g.get("self_emp", 0)
		var delta := 0  # milli-persons
		# exit: earnings per proprietor below benefit level
		if se > 0:
			var per := float(g["income"].get("self", 0)) / (float(se) / S)
			if per < benefit:
				delta -= maxi(int(float(se) * EconData.SELF_EMP_EXIT), mini(se, S / 2))
		# entry: unemployed adults with a savings cushion, while local services fetch at least 90% of base price
		var unemp: int = g.get("unemployed", 0)
		var cushion := world.ledger.balance(EconUtil.hh_acct(gid)) >= 3 * EconHouseholds.essentials_cost(world, g)
		var price_ok: bool = s["svc_price"].get(g["district"], 0) >= EconData.BASE_SERVICES_PRICE * S * 9 / 10
		if unemp > 0 and cushion and price_ok:
			delta += int(float(unemp) * EconData.SELF_EMP_ENTRY)
		var target := clampi(se + delta, 0, mini(int(float(g["lf"]) * EconData.SELF_EMP_MAX_SHARE), se + unemp))
		var rem: int = g.get("se_rem", 0) + target - se
		var persons := rem / S
		g["se_rem"] = rem - persons * S
		if persons > 0:
			PopStore.move_group(world, {"hb": g["hb"], "inc": g["band"], "status": "UNEMPLOYED"}, persons,
				{"occ": "BUSINESS_OWNER", "status": "EMPLOYED"}, "SELF_EMP_ENTRY")
		elif persons < 0:
			PopStore.move_group(world, {"hb": g["hb"], "inc": g["band"], "status": "EMPLOYED", "occ": "BUSINESS_OWNER"}, -persons,
				{"status": "UNEMPLOYED"}, "SELF_EMP_EXIT")
	EconPop.sync(world)


## Orders for next month's TRADE: essentials first (rent + utilities reserved), then discretionary goods.
static func _post_orders(world: WorldState) -> void:
	var s := EconUtil.st(world)
	var pf: int = s["prices"]["FOOD"]
	var pc: int = s["prices"]["CONSUMER"]
	var tax_m := 1.0 + float(EconUtil.lever(world, "ECON_SALES_TAX", 0)) / 100.0
	for gid in EconUtil.sorted_keys(world.table("hh")):
		var g: Dictionary = world.table("hh")[gid]
		var p := persons(g)
		if p <= 0:
			continue
		# E60: food first, then water/energy, then rent (unpaid rent becomes landlord arrears; hunger is worse)
		var budget := maxi(0, world.ledger.balance(EconUtil.hh_acct(gid)))
		var rent_res := int(float(households(g)) / S * float(EconFinance.district_rent(world, g["district"])))
		var util_res := int(float(p) / S * (EconData.NEED["ENERGY"] * float(EconUtil.lever(world, "ECON_UTILITY_TARIFF_ENERGY", 40)) * S
			+ EconData.NEED["WATER"] * float(EconUtil.lever(world, "ECON_UTILITY_TARIFF_WATER", 20)) * S))
		var pf_eff := int(float(pf) * 1.1 * tax_m)
		var food_q := int(p * EconData.NEED["FOOD"])
		var food_cost := EconUtil.val(food_q, pf_eff)
		if food_cost > budget:
			food_q = int(float(budget) * S / float(pf_eff))
			food_cost = budget
		budget = maxi(0, budget - food_cost - util_res)
		var pc_eff := int(float(pc) * 1.1 * tax_m)
		var cmin := int(p * EconData.NEED["CONSUMER_MIN"])
		var cmin_cost := mini(EconUtil.val(cmin, pc_eff), budget)
		cmin = int(float(cmin_cost) * S / float(maxi(1, pc_eff)))
		budget -= cmin_cost
		if food_q > 0:
			s["orders"].append({"buyer": gid, "acct": EconUtil.hh_acct(gid), "district": g["district"], "good": "FOOD", "qty": food_q,
				"limit": pf * 3, "class": EconMarket.C_HH_ESS, "kind": "hh"})
		if cmin > 0:
			s["orders"].append({"buyer": gid, "acct": EconUtil.hh_acct(gid), "district": g["district"], "good": "CONSUMER", "qty": cmin,
				"limit": pc * 3, "class": EconMarket.C_HH_ESS, "kind": "hh"})
		var disc := int(EconData.DISC_CONSUMER_SHARE * discretionary_budget(world, g))
		disc = mini(disc, maxi(0, budget - rent_res))
		var cap_mult: float = 1.0 if EconUtil.off(world, "E88") else float(EconData.DISC_CAP_BAND.get(g.get("band", "I2"), 1.0))
		var extra := mini(int(float(disc) * S / float(maxi(1, pc_eff))), int(p * EconData.MAX_DISC_CONSUMER_PC * cap_mult))
		if extra > 0:
			s["orders"].append({"buyer": gid + "~d", "acct": EconUtil.hh_acct(gid), "district": g["district"], "good": "CONSUMER",
				"qty": extra, "limit": pc * 11 / 10 + 3 * int(EconUtil.lever(world, "ECON_FREIGHT_TARIFF", 5)) * S, "class": EconMarket.C_HH_DISC, "kind": "hh", "group": gid})
		# D2: the rest of the goods budget (it used to sit idle above the CONSUMER cap) buys clothing, furnishings, fine food
		EconConsumer.post_orders(world, gid, g, disc - EconUtil.val(extra, pc_eff))


static func _housing(world: WorldState) -> void:
	var units := units_by_district(world)
	var hhs := {}
	for gid in EconUtil.sorted_keys(world.table("hh")):
		var g: Dictionary = world.table("hh")[gid]
		hhs[g["district"]] = hhs.get(g["district"], 0) + households(g)
	var cap := int(EconUtil.lever(world, "ECON_RENT_INCREASE_CAP", 20))
	for d in EconUtil.sorted_keys(world.table("district")):
		var dr: Dictionary = world.table("district")[d]
		dr["households"] = hhs.get(d, 0)
		dr["units"] = units.get(d, 0)
		var occ := float(hhs.get(d, 0)) / maxf(1.0, float(units.get(d, 0)))
		dr["occupancy"] = int(occ * 1000)
		if world.month % 3 == 2 and units.get(d, 0) > 0:
			var h: Array = dr["rent_hist"]
			var old: int = dr["rent_private"]
			var r := old
			var due_d := 0
			for gid2 in world.table("hh"):
				if world.table("hh")[gid2]["district"] == d:
					due_d += int(world.table("hh")[gid2].get("rent_due", 0))
			var arrears := float(EconUtil.st(world).get("rent_arrears", {}).get(d, 0)) / maxf(1.0, float(due_d))
			if arrears > EconData.RENT_ARREARS_CUT and not EconUtil.off(world, "E83"):
				r = int(old * 0.97)  # E83: tenants cannot pay — rents fall whatever the occupancy
			elif occ >= 0.97:
				r = int(old * 1.03)
			elif occ < 0.85:
				r = int(old * 0.98)
			if h.size() >= 4:
				r = mini(r, int(h[h.size() - 4] * (1.0 + float(cap) / 100.0)))
			dr["rent_private"] = maxi(r, EconData.PRIVATE_RENT * S / 4)
			h.append(dr["rent_private"])
			while h.size() > 4:
				h.pop_front()
			if r > old * 103 / 100 - 1 and r > old:
				EconFacts.emit(world, "ECON_RENT_INCREASE", d, [], [["COMPANY", "landlords", 0.6], ["GOVERNMENT", "government", 0.4]],
					{"HOUSING": -6, "COST_OF_LIVING": -3}, 12, "PUBLIC", {"pct": int(100.0 * (float(r) / float(old) - 1.0))}, {"districts": [d]})


## Demography (spec §7, re-expressed on the population leaves; the full age model is M10 S5).
## Rates as before; flows are computed per pool in milli-persons and applied in whole persons with the
## remainder carried in the pool ("demo_rem"), so small pools still have births and deaths over time.
static func _demography(world: WorldState) -> void:
	if not EconUtil.off(world, "E120"):
		EconCohorts.monthly(world)  # E120: age-structured births, deaths, growing up and retirement by cohort
		EconPop.sync(world)
		return
	var s := EconUtil.st(world)
	var edu: Dictionary = s.get("edu_access", {})
	var health: Dictionary = s.get("health_access", {})
	var famine := float(s.get("food_shortfall", 0)) / 1000.0 > 0.30
	for gid in EconUtil.sorted_keys(world.table("hh")):
		var g: Dictionary = world.table("hh")[gid]
		var p := persons(g)
		if p <= 0:
			continue
		var rem: Dictionary = g.get("demo_rem", {})
		g["demo_rem"] = rem
		var h := float(health.get(g["district"], 1000)) / 1000.0
		var f := {"hb": g["hb"], "inc": g["band"]}
		if not EconUtil.off(world, "E111"):
			_demography_e111(world, g, rem, h, f, edu, famine)
			continue
		# births: into the pool's children (parents' housing block and income band, PD §9.3)
		var births := _whole(rem, "birth", int(p * 0.0015))
		if births > 0:
			var ck := PopStore.key_of({"hb": g["hb"], "inc": g["band"], "occ": "NONE", "status": "CHILD", "arch": EconPop.ARCH, "eff": "e0"})
			PopStore.birth(world, ck, births)
		# deaths: 70% among the retired, 10% children, the rest non-participating adults
		var death_rate := 0.0005 + 0.0002 * (1.0 - h) + (0.005 if famine else 0.0)
		var deaths := _whole(rem, "death", int(p * death_rate))
		if deaths > 0:
			var d_ret := mini(g["retired"] / S, deaths * 7 / 10)
			var d_ch := mini(g["children"] / S, deaths / 10)
			var d_np := mini(g["nonpart"] / S, deaths - d_ret - d_ch)
			_die(world, f, "RETIRED", d_ret)
			_die(world, f, "CHILD", d_ch)
			_die(world, f, "NOT_IN_LF", d_np)
		# growing up: 1/216 of children per month become adults; skill by education access; 82% join the labour force
		var grown := _whole(rem, "grow", g["children"] / 216)
		if grown > 0:
			var a := float(edu.get(g["district"], 1000)) / 1000.0
			var split := EconUtil.split_lr(grown, [a * 0.45 + (1.0 - a) * 0.85, a * 0.40 + (1.0 - a) * 0.15, a * 0.15])
			var tiers := ["G", "S", "Sp"]
			for i in 3:
				var n_t: int = split[i]
				var to_lf := n_t * 82 / 100
				_grow_up(world, g, tiers[i], "UNEMPLOYED", to_lf)
				_grow_up(world, g, tiers[i], "NOT_IN_LF", n_t - to_lf)
		# retirement: 0.2% of working-age, from non-participants first, then the unemployed
		var ret := _whole(rem, "retire", int((g["lf"] + g["nonpart"]) * 0.002))
		if ret > 0:
			var from_np := mini(ret, g["nonpart"] / S)
			var m1 := PopStore.move_group(world, {"hb": g["hb"], "inc": g["band"], "status": ["NOT_IN_LF", "STUDENT"]}, from_np, {"status": "RETIRED"}, "RETIRE")
			var m2 := PopStore.move_group(world, {"hb": g["hb"], "inc": g["band"], "status": "UNEMPLOYED"}, ret - m1, {"status": "RETIRED"}, "RETIRE")
			_reage(world, g, "RETIRED", m1 + m2, "O")
	EconPop.sync(world)


## Retirement age in years (LAW_RETIREMENT_AGE lever if the law module defines it).
static func retirement_age(world: WorldState) -> int:
	return clampi(int(world.levers.get("LAW_RETIREMENT_AGE", EconData.RETIREMENT_AGE)), 50, 75)


## Soft food brake on births and ship migrants (Wilma): 1.0 with no shortfall, down to FOOD_BRAKE_FLOOR.
static func food_brake(world: WorldState) -> float:
	var sf := float(EconUtil.st(world).get("food_shortfall", 0))
	return 1.0 - (1.0 - EconData.FOOD_BRAKE_FLOOR) * clampf(sf / float(EconData.FOOD_BRAKE_SHORTFALL), 0.0, 1.0)


## E111: one pool's month — births from working-age adults, deaths by age group, growing up, retirement by career length.
static func _demography_e111(world: WorldState, g: Dictionary, rem: Dictionary, h: float, f: Dictionary, edu: Dictionary, famine: bool) -> void:
	var adults: int = g["lf"] + g["nonpart"] + g["owners"]
	var births := _whole(rem, "birth", int(float(adults) * EconData.BIRTH_RATE_ADULT * food_brake(world)))
	if births > 0:
		var ck := PopStore.key_of({"hb": g["hb"], "inc": g["band"], "occ": "NONE", "status": "CHILD", "arch": EconPop.ARCH, "eff": "e0"})
		PopStore.birth(world, ck, births)
	var ra := retirement_age(world)
	var years_retired := maxf(4.0, float(EconData.LIFE_EXPECTANCY - ra) - 6.0 * (1.0 - h))
	var fam: Dictionary = EconData.FAMINE_MORTALITY if famine else {}
	var d_ret := _whole(rem, "death_r", int(float(g["retired"]) * (1.0 / (12.0 * years_retired) + float(fam.get("RETIRED", 0.0)))))
	var d_ch := _whole(rem, "death_c", int(float(g["children"]) * (EconData.MORTALITY_CHILD * (2.0 - h) + float(fam.get("CHILD", 0.0)))))
	var d_ad := _whole(rem, "death_a", int(float(g["nonpart"]) * (EconData.MORTALITY_ADULT * (2.0 - h) + float(fam.get("NOT_IN_LF", 0.0)))))
	_die(world, f, "RETIRED", mini(d_ret, g["retired"] / S))
	_die(world, f, "CHILD", mini(d_ch, g["children"] / S))
	_die(world, f, "NOT_IN_LF", mini(d_ad, g["nonpart"] / S))
	var grown := _whole(rem, "grow", g["children"] / 216)
	if grown > 0:
		var a := float(edu.get(g["district"], 1000)) / 1000.0
		var split := EconUtil.split_lr(grown, [a * 0.45 + (1.0 - a) * 0.85, a * 0.40 + (1.0 - a) * 0.15, a * 0.15])
		var tiers := ["G", "S", "Sp"]
		for i in 3:
			var n_t: int = split[i]
			var to_lf := n_t * 82 / 100
			_grow_up(world, g, tiers[i], "UNEMPLOYED", to_lf)
			_grow_up(world, g, tiers[i], "NOT_IN_LF", n_t - to_lf)
	var ret := _whole(rem, "retire", int(float(g["lf"] + g["nonpart"]) / (12.0 * float(maxi(10, ra - 18)))))
	if ret > 0:
		var from_np := mini(ret, g["nonpart"] / S)
		var m1 := PopStore.move_group(world, {"hb": g["hb"], "inc": g["band"], "status": ["NOT_IN_LF", "STUDENT"]}, from_np, {"status": "RETIRED"}, "RETIRE")
		var m2 := PopStore.move_group(world, {"hb": g["hb"], "inc": g["band"], "status": "UNEMPLOYED"}, ret - m1, {"status": "RETIRED"}, "RETIRE")
		_reage(world, g, "RETIRED", m1 + m2, "O")


## Whole persons from a milli-person flow, carrying the remainder under `key`.
static func _whole(rem: Dictionary, key: String, flow_mu: int) -> int:
	var v: int = int(rem.get(key, 0)) + flow_mu
	var n := v / S
	rem[key] = v - n * S
	return n


static func _die(world: WorldState, f: Dictionary, status: String, n: int) -> void:
	if n <= 0:
		return
	var filt := f.duplicate()
	filt["status"] = status
	var keys := PopStore.select(world, filt)
	var parts := PopStore.split_over(n, keys, keys.map(func(k): return float(world.peek("pop")[k]["n"])))
	for k in EconUtil.sorted_keys(parts):
		PopStore.death(world, k, parts[k])


## Children of a pool become adults: CHILD → status (occupation NONE), age C → Y, skill set to the tier.
static func _grow_up(world: WorldState, g: Dictionary, tier: String, status: String, n: int) -> void:
	if n <= 0:
		return
	var keys := PopStore.select(world, {"hb": g["hb"], "inc": g["band"], "status": "CHILD"})
	var parts := PopStore.split_over(n, keys, keys.map(func(k): return float(world.peek("pop")[k]["n"])))
	for k in EconUtil.sorted_keys(parts):
		var dst := PopStore.relabel(k, {"status": status, "occ": "NONE"})
		PopStore.transfer(world, k, dst, parts[k], "GROW_UP", {"age": "C"})
		EconPop.recompose(world, dst, "age", "C", "Y", parts[k])
		EconPop.recompose(world, dst, "skill", "G", tier, parts[k])


## After a status move, set the age of the moved people (e.g. retirees → O), taking from the youngest-first other bands.
static func _reage(world: WorldState, g: Dictionary, status: String, n: int, band: String) -> void:
	if n <= 0:
		return
	var left := n
	for k in PopStore.select(world, {"hb": g["hb"], "inc": g["band"], "status": status}):
		for b in ["M", "A", "Y"]:
			if left <= 0:
				return
			left -= EconPop.recompose(world, k, "age", b, band, left)


## Ship migrants every 3 months (spec §7.6): arrivals are UNEMPLOYED / NOT_IN_LF adults and children, banded by
## skill like the founders, into the district with the most vacant housing. They bring savings from the origin.
## M12 §4: a home-world ship arrives every 18–30 months (seeded draw on "econ.ship"; M11 hazards may delay or
## lose it later). It brings a migrant batch; cargo and the quota return trip follow in M12 (2).
## Emits ECON_SHIP_ARRIVED {interval, migrants, cargo, quota_delivered}; the home-world actor reacts the same month.
static func _ships(world: WorldState) -> void:
	var s := EconUtil.st(world)
	var rng := world.rng.stream("econ.ship")
	if not s.has("ship_next"):
		s["ship_next"] = world.month + rng.randi_range(EconData.SHIP_INTERVAL[0], EconData.SHIP_INTERVAL[1])
		s["ship_last"] = 0
	if world.month < int(s["ship_next"]):
		return
	var interval: int = world.month - int(s.get("ship_last", 0))
	var migrants := 0
	var departed := 0
	if not EconUtil.off(world, "E120"):
		# E120: settlers = ship space × attractiveness × LAW_IMMIGRATION; the unemployed young may leave on it
		if world.levers.has("ECON_IMMIGRATION_QUOTA") and not world.levers.has("LAW_IMMIGRATION"):
			# old saves: the retired colony quota (persons/quarter, default 60) becomes the openness (default 70)
			world.levers["LAW_IMMIGRATION"] = clampi(int(world.levers["ECON_IMMIGRATION_QUOTA"]) * 70 / 60, 0, 100)
		var mig := EconCohorts.ship_migration(world)
		migrants = int(mig["arrived"])
		departed = int(mig["departed"])
	else:
		var quota := int(EconUtil.lever(world, "ECON_IMMIGRATION_QUOTA", 60))
		var cap := mini(EconData.SHIP_CAPACITY, int(float(quota) * float(interval) / 3.0 * EconData.SHIP_QUOTA_SHARE))
		migrants = _ship_migrants(world, cap, false)
	var trade := EconTrade.on_ship(world)  # D1: exports loaded, merchants' imports unloaded
	EconFacts.emit(world, "ECON_SHIP_ARRIVED", "d:1", [["EXTERNAL", "home_world"]], [["EXTERNAL", "home_world", 1.0]], {}, 40, "PUBLIC",
		{"interval": interval, "migrants": migrants, "emigrants": departed, "cargo": trade["cargo"], "quota_delivered": trade["quota_delivered"],
		"export_value": trade["export_value"], "imports": trade["imports"], "import_value": trade["import_value"]})
	s["ship_last"] = world.month
	s["ship_next"] = world.month + rng.randi_range(EconData.SHIP_INTERVAL[0], EconData.SHIP_INTERVAL[1])


## Migrants into the district with the most vacant housing; returns persons landed.
static func _ship_migrants(world: WorldState, cap: int, emit_fact: bool) -> int:
	var units := units_by_district(world)
	var hhs := {}
	for gid in world.table("hh"):
		var g: Dictionary = world.table("hh")[gid]
		hhs[g["district"]] = hhs.get(g["district"], 0) + households(g)
	var vacant := 0
	var best := ""
	var best_v := 0
	var tot_units := 0
	var tot_hh := 0
	for d in EconUtil.sorted_keys(units):
		tot_units += units[d]
		tot_hh += hhs.get(d, 0)
		var v: int = units[d] - hhs.get(d, 0)
		if v > best_v:
			best_v = v
			best = d
	vacant = maxi(0, tot_units - tot_hh)  # net colony vacancy (overcrowding elsewhere counts against it)
	var quota := int(EconUtil.lever(world, "ECON_IMMIGRATION_QUOTA", 60))
	# E50: migrants only come while the colony has jobs (unemployment < 10%)
	var lf_t := 0
	var emp_t := 0
	for gid in world.table("hh"):
		lf_t += world.table("hh")[gid]["lf"]
		emp_t += EconLabor.employed(world.table("hh")[gid])
	if lf_t > 0 and float(lf_t - emp_t) / float(lf_t) >= 0.10:
		return 0
	var n := mini(int(vacant * 2.5) / S, cap)  # persons
	if not EconUtil.off(world, "E111"):
		n = int(float(n) * food_brake(world))  # E111: a colony that cannot feed people draws fewer settlers
	if emit_fact:
		n = mini(n, quota)  # old model: per-quarter quota
	if n <= 0 or best == "":
		return 0
	land_migrants(world, best, n)
	if emit_fact:
		EconFacts.emit(world, "ECON_MIGRANTS_ARRIVED", best, [], [["GOVERNMENT", "government", 0.5], ["EXTERNAL", "origin", 0.5]], {}, 10,
			"PUBLIC", {"persons": n}, {"districts": [best]})
	return n


static func _adult_ages(n: int) -> Dictionary:
	var p := EconUtil.split_lr(n, [30, 45, 25])
	return {"Y": p[0], "A": p[1], "M": p[2]}


static func _pollution(world: WorldState) -> void:
	var s := EconUtil.st(world)
	var em: Dictionary = s.get("emissions", {})
	for d in EconUtil.sorted_keys(s["pollution"]):
		var e := float(em.get(d, 0)) / 1000.0
		var nb := 0.0
		for n in EconUtil.neighbours(d):
			nb += float(em.get(n, 0)) / 1000.0
		var p := float(s["pollution"][d]) / S
		var old := p
		p = clampf(0.8 * p + 0.4 * (e + 0.25 * nb), 0.0, 100.0)
		s["pollution"][d] = int(p * S)
		for th in [50.0, 75.0]:
			if old < th and p >= th:
				EconFacts.emit(world, "ECON_POLLUTION_THRESHOLD", d, [], [["COMPANY", "emitters", 0.5], ["GOVERNMENT", "government", 0.5]],
					{"ENVIRONMENT_QUALITY": -10 if th == 50.0 else -20}, 40 if th == 50.0 else 60, "PUBLIC", {"threshold": int(th)},
					{"districts": [d] + EconUtil.neighbours(d)})


static func _famine_check(world: WorldState) -> void:
	var s := EconUtil.st(world)
	if s.get("food_shortfall", 0) >= 250:
		s["food_short_streak"] += 1
	else:
		s["food_short_streak"] = 0
	if s["food_short_streak"] >= 3 and not s["famine"]:
		s["famine"] = true
		var big := food_buyers(world)
		var resp: Array = [["GOVERNMENT", "government", 0.8], ["NATURE", "nature", 0.2]]
		if not big.is_empty():
			resp = [["GOVERNMENT", "government", 0.65], ["NATURE", "nature", 0.15], ["COMPANY", big[0]["org"], 0.2]]
		EconFacts.emit(world, "ECON_FAMINE", null, [], resp,
			{"COST_OF_LIVING": -80, "GOVERNANCE": -40}, 100, "PUBLIC", {"big_buyers": big})


## D2: the companies that bought the most FOOD last month (bakeries, delicatessens): [{org, name, units}], top 3 with
## at least 5% of household food need; named in shortage and famine facts so the papers and parties can blame them.
static func food_buyers(world: WorldState) -> Array:
	var fb: Dictionary = EconUtil.peek_st(world).get("food_buyers_m", {})
	var need := float(PopStore.total(world)) * float(EconData.NEED["FOOD"])
	var rows: Array = []
	for oid in EconUtil.sorted_keys(fb):
		var u := int(fb[oid]) / S
		if float(u) >= 0.05 * need and world.peek("org").has(oid):
			rows.append({"org": oid, "name": str(world.peek("org")[oid].get("name", oid)), "units": u})
	rows.sort_custom(func(a, b): return int(a["units"]) > int(b["units"]) or (int(a["units"]) == int(b["units"]) and str(a["org"]) < str(b["org"])))
	return rows.slice(0, 3)


## Lands n migrants in district d: 70% adults by skill (half general, a third skilled), 30% children; they bring
## savings from the origin. Shared by the old ship model and E120 (EconCohorts.ship_migration).
static func land_migrants(world: WorldState, best: String, n: int) -> void:
	if n <= 0:
		return
	var hb := EconPop.hb_of(best)
	var adults_n := n * 7 / 10
	var tiers := EconUtil.split_lr(adults_n, [0.5, 0.35, 0.15])
	var names := ["G", "S", "Sp"]
	var band_of := {"G": "I2", "S": "I3", "Sp": "I4"}
	for i in 3:
		var t: String = names[i]
		var band: String = band_of[t]
		var lf: int = tiers[i] * 85 / 100
		var parts := {"hb": hb, "inc": band, "occ": "NONE", "arch": EconPop.ARCH, "eff": "e0"}
		parts["status"] = "UNEMPLOYED"
		PopStore.arrive(world, PopStore.key_of(parts), lf, {"age": _adult_ages(lf), "skill": {t: lf}})
		parts["status"] = "NOT_IN_LF"
		PopStore.arrive(world, PopStore.key_of(parts), tiers[i] - lf, {"age": _adult_ages(tiers[i] - lf), "skill": {t: tiers[i] - lf}})
		if i == 0:
			parts["status"] = "CHILD"
			PopStore.arrive(world, PopStore.key_of(parts), n - adults_n, {"age": {"C": n - adults_n}, "skill": {"G": n - adults_n}})
		world.ledger.transfer(Ledger.EXTERNAL, EconUtil.hh_acct(EconPop.pool_id(hb, band)), int(tiers[i] * EconData.MIGRANT_FUNDS) * S, "MIGRANT_FUNDS", world.month)
	EconPop.sync(world)

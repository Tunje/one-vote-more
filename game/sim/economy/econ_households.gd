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
	_buy_services(world)
	_self_employment_flow(world)
	EconLabor.recount(world)
	_post_orders(world)
	_housing(world)
	_demography(world)
	if (world.month + 1) % 3 == 0:
		_ship_migrants(world)
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
	s["food_shortfall"] = int(1000.0 * float(short_food) / maxf(1.0, float(need_food)))
	s["shortfall_d"] = {}
	for d in need_d:
		s["shortfall_d"][d] = int(1000.0 * float(short_d[d]) / maxf(1.0, float(need_d[d])))
		if s["shortfall_d"][d] >= 50:
			EconFacts.emit(world, "ECON_SHORTAGE", d, [], [["GOVERNMENT", "government", 0.6], ["NATURE", "market", 0.4]],
				{"COST_OF_LIVING": -mini(60, int(0.3 * s["shortfall_d"][d]))}, int(0.2 * s["shortfall_d"][d]), "PUBLIC",
				{"shortfall_permille": s["shortfall_d"][d]}, {"districts": [d]})


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
		var budget := int((1.0 - EconData.DISC_CONSUMER_SHARE) * discretionary_budget(world, g))
		budget = mini(budget, world.ledger.balance(EconUtil.hh_acct(gid)))
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
		s["svc_price"][d] = int(clampf(p, base * EconData.PRICE_MIN_MULT, base * EconData.PRICE_MAX_MULT))


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


## E67 entry/exit of sole proprietors (emerges from unemployment, savings and local service prices).
static func _self_employment_flow(world: WorldState) -> void:
	var s := EconUtil.st(world)
	var benefit := float(s["wage"]["G"]) * float(EconUtil.lever(world, "ECON_UNEMPLOYMENT_BENEFIT_RATE", 40)) / 100.0
	for gid in EconUtil.sorted_keys(world.table("hh")):
		var g: Dictionary = world.table("hh")[gid]
		var se: int = g.get("self_emp", 0)  # all tiers: Specialists set up private practice (consulting, clinics)
		# exit: earnings per proprietor below benefit level
		if se > 0:
			var per := float(g["income"].get("self", 0)) / (float(se) / S)
			if per < benefit:
				se -= maxi(int(float(se) * EconData.SELF_EMP_EXIT), mini(se, S / 2))
		# entry: unemployed adults with a savings cushion, while local services fetch at least 90% of base price
		var unemp := maxi(0, g["lf"] - EconLabor.employed(g))
		var cushion := world.ledger.balance(EconUtil.hh_acct(gid)) >= 3 * EconHouseholds.essentials_cost(world, g)
		var price_ok: bool = s["svc_price"].get(g["district"], 0) >= EconData.BASE_SERVICES_PRICE * S * 9 / 10
		if unemp > 0 and cushion and price_ok:
			se += int(float(unemp) * EconData.SELF_EMP_ENTRY)
		g["self_emp"] = clampi(se, 0, mini(int(float(g["lf"]) * EconData.SELF_EMP_MAX_SHARE), se + unemp))


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
		var extra := mini(int(float(disc) * S / float(maxi(1, pc_eff))), int(p * EconData.MAX_DISC_CONSUMER_PC))
		if extra > 0:
			s["orders"].append({"buyer": gid + "~d", "acct": EconUtil.hh_acct(gid), "district": g["district"], "good": "CONSUMER",
				"qty": extra, "limit": pc * 11 / 10 + 3 * int(EconUtil.lever(world, "ECON_FREIGHT_TARIFF", 5)) * S, "class": EconMarket.C_HH_DISC, "kind": "hh", "group": gid})


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
			if occ >= 0.97:
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


static func _group(world: WorldState, d: String, t: String) -> Dictionary:
	for gid in EconUtil.sorted_keys(world.table("hh")):
		var g: Dictionary = world.table("hh")[gid]
		if g["district"] == d and g["tier"] == t:
			return g
	var gid := world.new_id("hh")
	var g := {"id": gid, "district": d, "tier": t, "lf": 0, "nonpart": 0, "retired": 0, "children": 0, "owners": 0, "unemp_long": 0,
		"unemp_months": 0, "bought": {}, "unmet": {}, "income": {}, "income_last": {}, "disposable": 0, "ess_cost": 0, "rent_due": 0,
		"util_due": 0, "emp": {}, "base_income_pa": 0, "short": {}, "spent_goods": 0}
	world.table("hh")[gid] = g
	world.ledger.open_account(EconUtil.hh_acct(gid))
	return g


static func _demography(world: WorldState) -> void:
	var s := EconUtil.st(world)
	var edu: Dictionary = s.get("edu_access", {})
	var health: Dictionary = s.get("health_access", {})
	var famine := float(s.get("food_shortfall", 0)) / 1000.0 > 0.30
	var newcomers := []  # [district, tier, adults_mu]
	for gid in EconUtil.sorted_keys(world.table("hh")):
		var g: Dictionary = world.table("hh")[gid]
		var p := persons(g)
		var h := float(health.get(g["district"], 1000)) / 1000.0
		var births := int(p * 0.0015)
		var death_rate := 0.0005 + 0.0002 * (1.0 - h) + (0.005 if famine else 0.0)
		var deaths := int(p * death_rate)
		g["children"] += births
		var d_ret := mini(g["retired"], deaths * 7 / 10)
		var d_ch := mini(g["children"], deaths / 10)
		var d_np := mini(g["nonpart"], deaths - d_ret - d_ch)
		g["retired"] -= d_ret
		g["children"] -= d_ch
		g["nonpart"] -= d_np
		# aging: children -> adults (1/216 per month), split by education access
		var grown := int(g["children"] / 216)
		g["children"] -= grown
		if grown > 0:
			var a := float(edu.get(g["district"], 1000)) / 1000.0
			var split := [a * 0.45 + (1.0 - a) * 0.85, a * 0.40 + (1.0 - a) * 0.15, a * 0.15]
			var parts := EconUtil.split_lr(grown, split)
			for i in 3:
				newcomers.append([g["district"], ["G", "S", "Sp"][i], parts[i]])
		# retirement: 0.2% of working-age, from non-employed adults first
		var ret := int((g["lf"] + g["nonpart"]) * 0.002)
		var from_np := mini(ret, g["nonpart"])
		g["nonpart"] -= from_np
		var unemployed := maxi(0, g["lf"] - EconLabor.employed(g))
		var from_lf := mini(ret - from_np, unemployed)
		g["lf"] -= from_lf
		g["retired"] += from_np + from_lf
	for nc in newcomers:
		var g := _group(world, nc[0], nc[1])
		var lf := int(nc[2] * 0.82)
		g["lf"] += lf
		g["nonpart"] += nc[2] - lf


static func _ship_migrants(world: WorldState) -> void:
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
		return
	var n := mini(quota * S, mini(int(vacant * 2.5), EconData.SHIP_MIGRANTS * S))
	if n <= 0 or best == "":
		return
	var adults_n := n * 7 / 10
	var tiers := EconUtil.split_lr(adults_n, [0.5, 0.35, 0.15])
	var names := ["G", "S", "Sp"]
	for i in 3:
		var g := _group(world, best, names[i])
		var lf: int = tiers[i] * 85 / 100
		g["lf"] += lf
		g["nonpart"] += tiers[i] - lf
		if i == 0:
			g["children"] += n - adults_n
		world.ledger.transfer(Ledger.EXTERNAL, EconUtil.hh_acct(g["id"]), int(float(tiers[i]) / S * EconData.MIGRANT_FUNDS) * S, "MIGRANT_FUNDS", world.month)
	EconFacts.emit(world, "ECON_MIGRANTS_ARRIVED", best, [], [["GOVERNMENT", "government", 0.5], ["EXTERNAL", "origin", 0.5]], {}, 10,
		"PUBLIC", {"persons": n / S}, {"districts": [best]})


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
		EconFacts.emit(world, "ECON_FAMINE", null, [], [["GOVERNMENT", "government", 0.8], ["NATURE", "nature", 0.2]],
			{"COST_OF_LIVING": -80, "GOVERNANCE": -40}, 100, "PUBLIC")

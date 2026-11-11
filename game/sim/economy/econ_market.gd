class_name EconMarket
extends RefCounted
## TRADE phase (spec §5 step 3, §6.1–6.2, §8): import arrivals, commodity market clearing, spoilage, prices, CPI.

const S := EconUtil.S
enum { C_CONTRACT, C_HH_ESS, C_INSTITUTION, C_GOV, C_FIRM, C_CONSTRUCTION, C_HH_DISC }
const CLEAR_ORDER := ["FOOD", "MEDICAL", "MINERAL", "MATERIAL", "COMPONENT", "CONSUMER"]


static func trade(world: WorldState) -> void:
	var s := EconUtil.st(world)
	for oid in world.table("org"):
		var o: Dictionary = world.table("org")[oid]
		o["pl_last"] = o["pl"]
		o["pl"] = EconFinance.empty_pl()
		o["sold"] = {}
	for gid in world.table("hh"):
		var g: Dictionary = world.table("hh")[gid]
		g["bought"] = {}
		g["spent_goods"] = 0
		g["short"] = {}
	s["input_short"] = {}
	s["layoffs_m"] = {}
	EconActions.apply_queue(world)
	_import_arrivals(world)
	s["freight_used"] = 0
	s["freight_deferred"] = {}
	# fill ratio of last month per good (permille), read by the origin backstop (E75)
	var fr := {}
	var ul := {}
	for g2 in s.get("market_stats", {}):
		var m2: Dictionary = s["market_stats"][g2]
		if m2.get("wanted", 0) > 0:
			fr[g2] = int(1000.0 * float(m2.get("filled", 0)) / float(m2["wanted"]))
			ul[g2] = maxi(0, int(m2["wanted"]) - int(m2.get("filled", 0)))
	s["fill_last"] = fr
	s["unmet_last"] = ul
	s["market_stats"] = {}
	var tariff := int(EconUtil.lever(world, "ECON_FREIGHT_TARIFF", 5)) * S
	for good in CLEAR_ORDER:
		_clear(world, good, tariff)
	s["orders"] = []
	s["offers"] = []
	_spoilage(world)
	_update_prices(world)
	_cpi(world)


static func _import_arrivals(world: WorldState) -> void:
	var s := EconUtil.st(world)
	var keep: Array = []
	for o in s["import_orders"]:
		if o["arrival"] <= world.month:
			EconUtil.inv_add(world, o["holder"], o["good"], "d:1", o["qty"], o["unit_cost"])
			EconUtil.qflow(world, o["good"], "imported", o["qty"])
			EconFacts.emit(world, "ECON_IMPORT_ARRIVED", "d:1", [["GOVERNMENT", "government"]],
				[["GOVERNMENT", "government", 0.5], ["EXTERNAL", "origin", 0.5]], {"COST_OF_LIVING": 2}, 15, "PUBLIC",
				{"good": o["good"], "qty": o["qty"]})
			var st_m: Dictionary = s.get("imports_m", {})
			st_m[o["good"]] = st_m.get(o["good"], 0) + o["qty"]
			s["imports_m"] = st_m
		else:
			keep.append(o)
	s["import_orders"] = keep


static func _clear(world: WorldState, good: String, tariff: int) -> void:
	var s := EconUtil.st(world)
	var offers: Array = s["offers"].filter(func(o): return o["good"] == good and o["qty"] > 0)
	if EconData.ORIGIN_BACKSTOP.has(good) and EconUtil.support(world):  # M12: no import backstop
		var bk: Array = EconData.ORIGIN_BACKSTOP[good]
		var hot: bool = float(s["prices"][good]) >= float(bk[0]) * float(s["base"][good]) 			or int(s.get("fill_last", {}).get(good, 1000)) < 800   # E75: or buyers got < 80% of what they wanted
		var key := "mat_hot_m" if good == "MATERIAL" else good.to_lower() + "_hot_m"   # keep the E65 key (saves)
		s[key] = s.get(key, 0) + 1 if hot else 0
		# hysteresis: on after 2 consecutive hot months, off only after 6 consecutive calm months (no flicker)
		var on_key := key + "_on"
		var calm_key := key + "_calm"
		s[calm_key] = 0 if hot else s.get(calm_key, 0) + 1
		if s[key] >= 2:
			s[on_key] = true
		elif s.get(on_key, false) and s[calm_key] >= 6:
			s[on_key] = false
		if s.get(on_key, false):
			# E94: the cargo scales with last month's unmet demand (half the gap, base..cap); still at bk[1] × base price,
			# so scarcity is felt (price signal) but a shortage cannot become a permanent deadlock
			var qty := int(bk[2]) * S
			if not EconUtil.off(world, "E94"):
				qty = clampi(int(s.get("unmet_last", {}).get(good, 0)) / 2, int(bk[2]) * S, int(bk[3]) * S)
			offers.append({"seller": "origin", "acct": Ledger.EXTERNAL, "district": "d:1", "good": good,
				"qty": qty, "ask": int(float(bk[1]) * float(s["base"][good]))})
	# E98: the strategic reserve (endowment) sells MATERIAL / COMPONENT into a scarce market at the market price,
	# up to half of last month's unmet demand. Before, the reserve sat untouched while power plants decayed.
	if good in EconData.RESERVE_AUTO_RELEASE and not EconUtil.off(world, "E98"):
		var stock := EconUtil.inv_get(world, "gov", good, "d:1")
		var scarce: bool = float(s["prices"][good]) >= 2.0 * float(s["base"][good]) or int(s.get("fill_last", {}).get(good, 1000)) < 800
		if stock > 0 and scarce:
			var q := mini(stock, maxi(int(s.get("unmet_last", {}).get(good, 0)) / 2, 10 * S))
			offers.append({"seller": "gov", "acct": EconUtil.TREASURY, "district": "d:1", "good": good, "qty": q, "ask": int(s["prices"][good])})
	var bids: Array = s["orders"].filter(func(b): return b["good"] == good and b["qty"] > 0)
	var price: int = s["prices"][good]
	var supply := 0
	for o in offers:
		supply += o["qty"]
	var imp: int = s.get("imports_m", {}).get(good, 0)
	var demand := 0
	for b in bids:
		if b["limit"] >= price * 8 / 10:
			demand += b["qty"]
	s["market_stats"][good] = {"S": supply + imp, "D": demand, "filled": 0, "wanted": 0}
	for cls in [C_CONTRACT, C_HH_ESS, C_INSTITUTION, C_GOV, C_FIRM, C_CONSTRUCTION, C_HH_DISC]:
		var cb: Array = bids.filter(func(b): return b["class"] == cls)
		if cb.is_empty():
			continue
		if cls == C_HH_ESS:
			var avail := 0
			for o in offers:
				avail += o["qty"]
			var want := 0
			for b in cb:
				want += b["qty"]
			cb.sort_custom(func(a, b): return a["buyer"] < b["buyer"])
			var alloc := EconUtil.split_lr(mini(avail, want), cb.map(func(b): return float(b["qty"])))
			for i in cb.size():
				_fill(world, cb[i], alloc[i], offers, tariff)
			# E75: producers must see household demand that supply could not cover (the pro-rata allocation is
			# capped by supply, so without this the demand signal ratchets down with output)
			s["market_stats"][good]["wanted"] += maxi(0, want - mini(avail, want))
		else:
			cb.sort_custom(func(a, b): return a["limit"] > b["limit"] or (a["limit"] == b["limit"] and a["buyer"] < b["buyer"]))
			for b in cb:
				_fill(world, b, b["qty"], offers, tariff)


## Fill one bid up to `want` from the cheapest delivered offers.
static func _fill(world: WorldState, bid: Dictionary, want: int, offers: Array, tariff: int) -> void:
	var s := EconUtil.st(world)
	var good: String = bid["good"]
	var cta := EconFinance.org_by_key(world, "CTA")
	var ranked := offers.duplicate()
	ranked.sort_custom(func(a, b):
		var pa: int = a["ask"] + EconUtil.hops(a["district"], bid["district"]) * tariff
		var pb: int = b["ask"] + EconUtil.hops(b["district"], bid["district"]) * tariff
		return pa < pb or (pa == pb and a["seller"] < b["seller"]))
	var got := 0
	var left := want
	for o in ranked:
		if left <= 0:
			break
		if o["qty"] <= 0:
			continue
		var h := EconUtil.hops(o["district"], bid["district"])
		if h < 0:
			continue
		if o["seller"] == bid["buyer"]:
			# E97: a firm's own order is filled from its own offer as an internal transfer (no payment, at book cost).
			# Vertically integrated owners — in every long run the public operator ends up holding mines, processing,
			# component works and power — otherwise starved their own plants while their stock sat unsold.
			if EconUtil.off(world, "E97") or bid["kind"] != "org":
				continue
			var own := mini(left, o["qty"])
			var wac0 := EconUtil.inv_wac(world, o["seller"], good, o["district"])
			own = EconUtil.inv_take(world, o["seller"], good, o["district"], own)
			if own <= 0:
				continue
			EconUtil.inv_add(world, bid["buyer"], good, bid["district"], own, wac0)
			o["qty"] -= own
			got += own
			left -= own
			continue
		if o["seller"] == "origin" and not EconUtil.off(world, "E85"):
			h = 0  # E85: origin backstop cargo comes on the origin's own shuttle, to the buyer's district (no colony freight)
		var unit: int = o["ask"] + h * tariff
		if unit > bid["limit"]:
			break
		var take := mini(left, o["qty"])
		if h > 0:
			var fcap: int = s["freight_cap"] - s["freight_used"]
			take = mini(take, maxi(0, fcap / h))
			if take <= 0:
				var dd: Dictionary = s["freight_deferred"]
				dd[bid["district"]] = dd.get(bid["district"], 0) + left
				break
		var cash := world.ledger.balance(bid["acct"])
		if unit > 0:
			take = mini(take, int(float(cash) * S / float(unit)))
		if take <= 0:
			break
		var goods_cost := EconUtil.val(take, o["ask"])
		var freight := EconUtil.val(take, h * tariff)
		world.ledger.transfer(bid["acct"], o["acct"], goods_cost, "SALE", world.month)
		if freight > 0 and cta != "":
			world.ledger.transfer(bid["acct"], EconUtil.acct(cta), freight, "FREIGHT", world.month)
			EconFinance.pl_add(world, cta, "rev", freight)
			s["freight_used"] += take * h
		var wac := EconUtil.inv_wac(world, o["seller"], good, o["district"])
		if o["seller"] == "origin":
			EconUtil.qflow(world, good, "imported", take)  # backstop cargo, paid to the origin (EXTERNAL)
			var bi: Dictionary = s.get("imports_m", {})
			bi[good] = bi.get(good, 0) + take
			s["imports_m"] = bi
		else:
			EconUtil.inv_take(world, o["seller"], good, o["district"], take)
		o["qty"] -= take
		if o["seller"] == "origin":
			pass
		elif o["seller"] == "gov":
			EconFinance._gov_rev(world, goods_cost)  # reserve sales are public revenue
		else:
			EconFinance.pl_add(world, o["seller"], "rev", goods_cost)
			EconFinance.pl_add(world, o["seller"], "cogs", EconUtil.val(take, wac))
			var sold: Dictionary = world.table("org")[o["seller"]]["sold"]
			sold[good] = sold.get(good, 0) + take
			if good in ["MINERAL", "MATERIAL"] and world.table("org")[o["seller"]]["type"] in ["PRIVATE", "COOPERATIVE"]:
				var sv: Dictionary = s.get("strategic_sales_by", {})
				sv[o["seller"]] = sv.get(o["seller"], 0) + goods_cost
				s["strategic_sales_by"] = sv
			if good == "MINERAL":
				var ms: Dictionary = s.get("mineral_sales_by", {})
				ms[o["seller"]] = ms.get(o["seller"], 0) + goods_cost
				s["mineral_sales_by"] = ms
		if bid["kind"] == "hh":
			var g: Dictionary = world.table("hh")[bid.get("group", bid["buyer"])]
			g["bought"][good] = g["bought"].get(good, 0) + take
			g["spent_goods"] += goods_cost + freight
			var vpaid := EconUtil.pay_upto(world, bid["acct"], EconUtil.TREASURY, int(float(goods_cost) * float(EconUtil.lever(world, "ECON_SALES_TAX", 0)) / 100.0), "SALES_TAX")
			EconFinance._gov_rev(world, vpaid)
		else:
			EconUtil.inv_add(world, bid["buyer"], good, bid["district"], take, unit)
			if bid["kind"] == "org":
				EconFinance.pl_add(world, bid["buyer"], "freight", freight)
		got += take
		left -= take
	var ms2: Dictionary = s["market_stats"][good]
	ms2["filled"] += got
	ms2["wanted"] += want
	var short: int = bid["qty"] - got
	if short > 0:
		if bid["kind"] == "hh":
			var sh: Dictionary = world.table("hh")[bid.get("group", bid["buyer"])]["short"]
			sh[good] = sh.get(good, 0) + short
		else:
			s["input_short"][bid["buyer"] + "|" + good] = short


static func _spoilage(world: WorldState) -> void:
	var inv := world.table("inv")
	for k in EconUtil.sorted_keys(inv):
		var good: String = k.split("|")[1]
		var pm: int = EconData.SPOILAGE_PERMILLE.get(good, 0)
		if pm <= 0:
			continue
		var r: Dictionary = inv[k]
		var lost: int = r["q"] * pm / 1000
		if lost > 0:
			r["q"] -= lost
			EconUtil.qflow(world, good, "burned", lost)


static func _update_prices(world: WorldState) -> void:
	var s := EconUtil.st(world)
	for good in CLEAR_ORDER:
		var m: Dictionary = s["market_stats"].get(good, {})
		var d := float(m.get("D", 0))
		var sup := float(m.get("S", 0))
		if d <= 0.0 and sup <= 0.0:
			continue
		# E45: shortage (unfilled share) pushes up; offered cover beyond 2 months of demand pushes down.
		var wanted := float(m.get("wanted", 0))
		var shortage := (wanted - float(m.get("filled", 0))) / maxf(wanted, float(S)) if wanted > 0.0 else 0.0
		var cover := sup / maxf(d, float(S))
		var excess := clampf((cover - 2.0) / 4.0, 0.0, 1.0)
		var p := float(s["prices"][good])
		# unfilled demand wins over stock cover (otherwise asks above buyers' limits deadlock the market)
		var x := shortage if shortage > 0.05 else -excess
		var p2 := p * (1.0 + EconData.ALPHA * clampf(x, -1.0, 1.0))
		var base := float(s["base"][good])
		s["prices"][good] = int(clampf(p2, base * EconData.PRICE_MIN_MULT, base * EconData.PRICE_MAX_MULT * wage_level(world)))


## E100: price caps move with the wage level (skilled wage index vs founding), never below 1. Fixed caps let decades
## of wage growth push producers' costs above the most they may charge, freezing output at the cap.
static func wage_level(world: WorldState) -> float:
	if EconUtil.off(world, "E100"):
		return 1.0
	return maxf(1.0, float(EconUtil.st(world)["wage"]["S"]) / float(EconData.WAGE["S"] * S))


static func _cpi(world: WorldState) -> void:
	var s := EconUtil.st(world)
	var svc := 0.0
	var rent := 0.0
	var nd := 0
	for d in EconUtil.sorted_keys(world.table("district")):
		if EconData.DISTRICTS[d]["pop"] == 0 and world.table("district")[d]["households"] == 0:
			continue
		svc += float(s["svc_price"][d])
		rent += float(EconFinance.district_rent(world, d))
		nd += 1
	svc /= maxf(1.0, float(nd))
	rent /= maxf(1.0, float(nd))
	var basket: float = 1.0 * s["prices"]["FOOD"] + 0.35 * s["prices"]["CONSUMER"] \
		+ 0.5 * float(EconUtil.lever(world, "ECON_UTILITY_TARIFF_ENERGY", 40)) * S \
		+ 1.0 * float(EconUtil.lever(world, "ECON_UTILITY_TARIFF_WATER", 20)) * S + 2.0 * svc + 0.4 * rent
	if not s.has("cpi_basket0"):
		s["cpi_basket0"] = int(basket)
	s["cpi"] = int(100.0 * S * basket / float(s["cpi_basket0"]))
	var h: Array = s["cpi_hist"]
	h.append(s["cpi"])
	while h.size() > 13:
		h.pop_front()

class_name EconIndicators
extends RefCounted
## SOCIAL: income classes → colony tercile bands → VoterCell census + all econ PIC indicators
## (planning/pic-economy.md §0–1). Values ×1000 of the display unit.

const S := EconUtil.S


## M10: census occupations are still the politics set (PolDefs.OCCUPATIONS) until politics S3 moves to the
## 10 PopStore occupations: MANUFACTURING / CONSTRUCTION / LOGISTICS are reported as INDUSTRY.
const CENSUS_OCC := {"MANUFACTURING": "INDUSTRY", "CONSTRUCTION": "INDUSTRY", "LOGISTICS": "INDUSTRY"}


## Income classes of every household pool: [{gid, district, occ, adults (float persons), own_pa, inc_pa}]
static func classes(world: WorldState) -> Array:
	var out: Array = []
	for gid in EconUtil.sorted_keys(world.table("hh")):
		var g: Dictionary = world.table("hh")[gid]
		var inc: Dictionary = g["income"]
		var adults := float(EconHouseholds.adults(g)) / S
		if adults <= 0.0:
			continue
		var avg_pa := float(EconHouseholds.disposable(g)) / S / adults
		var emp := float(EconLabor.employed(g)) / S
		var self_n := float(g.get("self_emp", 0)) / S
		var unemp := maxf(0.0, float(g["lf"]) / S - emp)
		var wage_pa := float(inc.get("wages", 0)) / S / maxf(emp - self_n, 0.001)
		var self_pa := float(inc.get("self", 0)) / S / maxf(self_n, 0.001)
		var ben_pa := float(inc.get("benefit", 0)) / S / maxf(unemp, 0.001)
		var pen_pa := float(inc.get("pension", 0)) / S / maxf(float(g["retired"]) / S, 0.001)
		var owners := float(g["owners"]) / S
		g["div_ema"] = int(0.9 * float(g.get("div_ema", 0)) + 0.1 * float(inc.get("dividend", 0)) * 3.0)  # quarterly → monthly
		var div_pa := float(g["div_ema"]) / S / maxf(owners, 0.001)
		var rows: Array = []
		for occ in EconUtil.sorted_keys(g["emp"]):
			if occ == "BUSINESS_OWNER":  # self-employed proprietors
				rows.append(["BUSINESS_OWNER", float(g["emp"][occ]) / S, self_pa])
			else:
				rows.append([CENSUS_OCC.get(occ, occ), float(g["emp"][occ]) / S, wage_pa])
		rows.append(["UNEMPLOYED", unemp, ben_pa])
		rows.append(["RETIRED", float(g["retired"]) / S, pen_pa])
		if owners > 0.0:
			rows.append(["BUSINESS_OWNER", owners, div_pa + wage_pa * 0.5])
		# non-participants follow the group's employed mix (UNEMPLOYED if none)
		var np := float(g["nonpart"]) / S
		if np > 0.0:
			if emp > 0.0:
				for occ in EconUtil.sorted_keys(g["emp"]):
					rows.append([CENSUS_OCC.get(occ, occ), np * float(g["emp"][occ]) / S / emp, 0.0])
			else:
				rows.append(["UNEMPLOYED", np, 0.0])
		for r in rows:
			if r[1] <= 0.0:
				continue
			out.append({"gid": gid, "district": g["district"], "occ": r[0], "adults": r[1],
				"own_pa": r[2], "inc_pa": 0.6 * r[2] + 0.4 * avg_pa})
	return out


## Assigns band fractions [LOW, MID, HIGH] to each class: exact colony population terciles by inc_pa.
static func band(classes_in: Array) -> void:
	var idx: Array = range(classes_in.size())
	idx.sort_custom(func(a, b):
		var x: Dictionary = classes_in[a]
		var y: Dictionary = classes_in[b]
		return x["inc_pa"] < y["inc_pa"] or (x["inc_pa"] == y["inc_pa"] and (x["gid"] + x["occ"]) < (y["gid"] + y["occ"])))
	var total := 0.0
	for c in classes_in:
		total += c["adults"]
	var cut1 := total / 3.0
	var cut2 := 2.0 * total / 3.0
	var cum := 0.0
	for i in idx:
		var c: Dictionary = classes_in[i]
		var a: float = c["adults"]
		var lo := cum
		var hi := cum + a
		var fl := maxf(0.0, minf(hi, cut1) - lo)
		var fm := maxf(0.0, minf(hi, cut2) - maxf(lo, cut1))
		var fh := maxf(0.0, hi - maxf(lo, cut2))
		c["bands"] = [fl / a, fm / a, fh / a]
		cum = hi


static func publish(world: WorldState) -> void:
	var s := EconUtil.st(world)
	var cls := classes(world)
	band(cls)
	var bands := ["LOW", "MID", "HIGH"]
	# ---- census (largest remainder over all cells) ----
	var cell_pop := {}
	var cell_rows := {}  # key -> [[class, weight]]
	for c in cls:
		for bi in 3:
			var w: float = c["adults"] * c["bands"][bi]
			if w <= 0.0:
				continue
			var key := PolDefs.cell_key(c["district"], c["occ"], bands[bi])
			cell_pop[key] = cell_pop.get(key, 0.0) + w
			if not cell_rows.has(key):
				cell_rows[key] = []
			cell_rows[key].append([c, w])
	var keys := EconUtil.sorted_keys(cell_pop)
	var tot := 0.0
	for k in keys:
		tot += cell_pop[k]
	var ints := EconUtil.split_lr(int(round(tot)), keys.map(func(k): return cell_pop[k]))
	var census := world.table("census")
	census.clear()
	for i in keys.size():
		if ints[i] > 0:
			census[keys[i]] = ints[i]
	# ---- per-group values used by cells ----
	var gv := {}
	for gid in EconUtil.sorted_keys(world.table("hh")):
		var g: Dictionary = world.table("hh")[gid]
		var adults := maxf(0.001, float(EconHouseholds.adults(g)) / S)
		var ess := float(EconHouseholds.essentials_cost(world, g)) / S
		var rent := float(g.get("rent_due", 0)) / S
		var inc: Dictionary = g["income"]
		var gross := float(inc.get("gross", 0)) / S
		var savings := float(world.ledger.balance(EconUtil.hh_acct(gid))) / S
		var lf := float(g["lf"]) / S
		var emp := float(EconLabor.employed(g)) / S
		gv[gid] = {"ess_pa": ess / adults, "rent_pa": rent / adults, "tax_rate": (float(inc.get("tax", 0)) / S / gross) if gross > 0.0 else 0.0,
			"security": savings / maxf(1.0, ess), "unemp": (lf - emp) / maxf(lf, 0.001) if lf > 0.0 else 0.0}
	# unemployment by district × income band (for job risk; M10: pools replace district × tier groups)
	var dt_lf := {}
	var dt_emp := {}
	for gid in world.table("hh"):
		var g: Dictionary = world.table("hh")[gid]
		dt_lf[gid] = g["lf"]
		dt_emp[gid] = EconLabor.employed(g)
	if not s.has("cell_base_inc"):
		s["cell_base_inc"] = {}
	var cpi := float(s["cpi"]) / (100.0 * S)
	var wage_g := _real_wage_growth(world)
	for key in EconUtil.sorted_keys(cell_rows):
		var rows: Array = cell_rows[key]
		var wsum := 0.0
		var acc := {"risk": 0.0, "inc": 0.0, "ess": 0.0, "rent": 0.0, "tax": 0.0, "sec": 0.0, "wg": 0.0}
		for r in rows:
			var c: Dictionary = r[0]
			var w: float = r[1]
			var v: Dictionary = gv[c["gid"]]
			var dk: String = c["gid"]
			var u := 1.0 - float(dt_emp.get(dk, 0)) / maxf(1.0, float(dt_lf.get(dk, 0)))
			acc["risk"] += w * u
			acc["inc"] += w * c["inc_pa"]
			acc["ess"] += w * v["ess_pa"]
			acc["rent"] += w * v["rent_pa"]
			acc["tax"] += w * (v["tax_rate"] if c["occ"] != "UNEMPLOYED" and c["occ"] != "RETIRED" else 0.0)
			acc["sec"] += w * v["security"]
			acc["wg"] += w * _pool_wage_growth(world.table("hh")[c["gid"]], wage_g)
			wsum += w
		for k in acc:
			acc[k] /= maxf(wsum, 0.0001)
		var base: float = float(s["cell_base_inc"].get(key, 0)) / 1000.0
		if base <= 0.0:
			# a cell's base is its income when first seen; floored at 1/4 of the colony mean so cells first seen in a
			# slump (or with ~0 income) do not produce absurd index values decades later (Wilma's chronicle: 240M)
			s["cell_base_inc"][key] = int(maxf(acc["inc"], 0.25 * _colony_mean_inc(cls)) * 1000.0)
			base = float(s["cell_base_inc"][key]) / 1000.0
		_w(world, "ECON_JOB_RISK", key, 100.0 * acc["risk"])
		# sanity: clamp to the declared range [0, 300] and log 10x jumps (Wilma: v3 chronicle values in the millions)
		var rii: float = 100.0 * acc["inc"] / maxf(1.0, base) / maxf(0.25, cpi)
		var prev_rii := float(world.indicators.read("ECON_REAL_INCOME_INDEX", key, -1)) / 1000.0
		if prev_rii > 0.0 and (rii > 10.0 * prev_rii or rii * 10.0 < prev_rii):
			var lg: Array = s.get("rii_jumps", [])
			if lg.size() < 50:
				lg.append("m%d %s %.1f -> %.1f (inc %.0f base %.0f cpi %.3f)" % [world.month, key, prev_rii, rii, acc["inc"], base, cpi])
			s["rii_jumps"] = lg
		_w(world, "ECON_REAL_INCOME_INDEX", key, clampf(rii, 0.0, 300.0))
		_w(world, "ECON_ESSENTIALS_SHARE", key, 100.0 * acc["ess"] / maxf(1.0, acc["inc"]))
		_w(world, "ECON_RENT_BURDEN", key, 100.0 * acc["rent"] / maxf(1.0, acc["inc"]))
		_w(world, "ECON_TAX_BURDEN", key, 100.0 * acc["tax"])
		_w(world, "ECON_FINANCIAL_SECURITY", key, clampf(acc["sec"], 0.0, 60.0))
		_w(world, "ECON_REAL_WAGE_GROWTH", key, acc["wg"])
	_district_indicators(world, cls)
	_colony_indicators(world)


static func _colony_mean_inc(cls: Array) -> float:
	var a := 0.0
	var t := 0.0
	for c in cls:
		a += c["adults"] * c["inc_pa"]
		t += c["adults"]
	return a / maxf(t, 0.001)


static func _w(world: WorldState, id: String, key: String, v: float) -> void:
	world.set_indicator("econ", id, key, int(round(v * 1000.0)))


## Real wage growth of a pool: tier growth weighted by its labour force's skill mix.
static func _pool_wage_growth(g: Dictionary, wage_g: Dictionary) -> float:
	var tot := 0.0
	var acc := 0.0
	for t in ["G", "S", "Sp"]:
		var n := float(g.get("skill", {}).get(t, 0))
		tot += n
		acc += n * float(wage_g.get(t, 0.0))
	return acc / tot if tot > 0.0 else float(wage_g.get("G", 0.0))


static func _real_wage_growth(world: WorldState) -> Dictionary:
	var s := EconUtil.st(world)
	var wh: Array = s["wage_hist"]
	wh.append(s["wage"].duplicate())
	while wh.size() > 13:
		wh.pop_front()
	var ch: Array = s["cpi_hist"]
	var out := {}
	for t in ["G", "S", "Sp"]:
		if wh.size() < 13 or ch.size() < 13:
			out[t] = 0.0
			continue
		var wr := float(wh[-1][t]) / float(wh[0][t])
		var pr := float(ch[-1]) / float(ch[0])
		out[t] = 100.0 * (wr / pr - 1.0)
	return out


static func _district_indicators(world: WorldState, cls: Array) -> void:
	var s := EconUtil.st(world)
	var pop := EconHouseholds.population_by_district(world)
	var units := EconHouseholds.units_by_district(world)
	var lf := {}
	var emp := {}
	var hi := {}
	var lo := {}
	for gid in world.table("hh"):
		var g: Dictionary = world.table("hh")[gid]
		lf[g["district"]] = lf.get(g["district"], 0) + g["lf"]
		emp[g["district"]] = emp.get(g["district"], 0) + EconLabor.employed(g)
	for c in cls:
		var d: String = c["district"]
		if not hi.has(d):
			hi[d] = [0.0, 0.0]
			lo[d] = [0.0, 0.0]
		hi[d][0] += c["adults"] * c["bands"][2] * c["inc_pa"]
		hi[d][1] += c["adults"] * c["bands"][2]
		lo[d][0] += c["adults"] * c["bands"][0] * c["inc_pa"]
		lo[d][1] += c["adults"] * c["bands"][0]
	var col_hi := [0.0, 0.0]
	var col_lo := [0.0, 0.0]
	for d in EconUtil.sorted_keys(hi):
		col_hi[0] += hi[d][0]; col_hi[1] += hi[d][1]
		col_lo[0] += lo[d][0]; col_lo[1] += lo[d][1]
	var col_ratio: float = (col_hi[0] / maxf(col_hi[1], 0.001)) / maxf(1.0, col_lo[0] / maxf(col_lo[1], 0.001))
	var price_col := _local_price(world, "")
	var dep := EconPop.deprivation(world)
	var bs0: Dictionary = s.get("bands", {}) if s.get("bands", {}) is Dictionary else {}
	_w(world, "ECON_GINI", "COLONY", float(bs0.get("gini", 0)) / 10.0)
	for d in EconUtil.sorted_keys(pop):
		if pop[d] <= 0:
			continue
		_w(world, "ECON_UNEMPLOYMENT_RATE", d, 100.0 * (1.0 - float(emp.get(d, 0)) / maxf(1.0, float(lf.get(d, 0)))))
		_w(world, "ECON_ESSENTIAL_SHORTFALL", d, float(s.get("shortfall_d", {}).get(d, 0)) / 10.0)
		_w(world, "ECON_LOCAL_PRICE_INDEX", d, 100.0 * _local_price(world, d) / maxf(1.0, price_col))
		_w(world, "ECON_OVERCROWDING", d, float(pop[d]) / EconData.HOUSEHOLD_SIZE / maxf(1.0, float(units.get(d, 0))))
		var sv: Array = s.get("util_served_hh", {}).get(d, [1.0, 1.0])
		_w(world, "ECON_UTILITY_RELIABILITY", d, 100.0 * (float(sv[0]) + float(sv[1])) / 2.0)
		_w(world, "ECON_INFRA_CONDITION", d, _infra(world, d))
		var deferred: int = s.get("freight_deferred", {}).get(d, 0)
		_w(world, "ECON_LOGISTICS_DELAY", d, minf(100.0, 100.0 * float(deferred) / maxf(1.0, float(pop[d]))))
		_w(world, "ECON_HEALTH_ACCESS", d, float(s.get("health_access", {}).get(d, 1000)) / 10.0)
		_w(world, "ECON_EDUCATION_ACCESS", d, float(s.get("edu_access", {}).get(d, 1000)) / 10.0)
		_w(world, "ECON_POLLUTION_INDEX", d, float(s["pollution"].get(d, 0)) / S)
		var r := col_ratio
		if hi.has(d) and hi[d][1] > 0.5 and lo[d][1] > 0.5:
			r = (hi[d][0] / hi[d][1]) / maxf(1.0, lo[d][0] / lo[d][1])
		_w(world, "ECON_INCOME_RATIO", d, clampf(r, 1.0, 20.0))
		# M10 S2: inequality and absolute deprivation (from EconPop.reclassify / deprivation)
		var bs: Dictionary = s.get("bands", {}) if s.get("bands", {}) is Dictionary else {}
		_w(world, "ECON_GINI", d, float(bs.get("gini_d", {}).get(d, bs.get("gini", 0))) / 10.0)
		_w(world, "ECON_DEPRIVATION", d, float(dep.get(d, 0)) / 10.0)


## Delivered essentials price in a district ("" = colony average): food + consumer at reference + freight from producers.
static func _local_price(world: WorldState, d: String) -> float:
	var s := EconUtil.st(world)
	var tariff := float(EconUtil.lever(world, "ECON_FREIGHT_TARIFF", 5)) * S
	if d == "":
		var tot := 0.0
		var n := 0
		for dd in EconUtil.sorted_keys(EconData.DISTRICTS):
			if EconData.DISTRICTS[dd]["pop"] > 0:
				tot += _local_price(world, dd)
				n += 1
		return tot / maxf(1.0, float(n))
	var food_h := 99
	var cons_h := 99
	for fid in world.table("facility"):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] == "FARM":
			food_h = mini(food_h, EconUtil.hops(f["district"], d))
		elif f["type"] == "CONSUMERF":
			cons_h = mini(cons_h, EconUtil.hops(f["district"], d))
	return float(s["prices"]["FOOD"]) + food_h * tariff + 0.35 * (float(s["prices"]["CONSUMER"]) + cons_h * tariff)


static func _infra(world: WorldState, d: String) -> float:
	var tot := 0.0
	var n := 0.0
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] in ["POWER", "WATERWORKS", "DEPOT"]:
			tot += float(f["condition"]) / S
			n += 1.0
	for l in EconData.LINKS:
		if l[0] == d or l[1] == d:
			tot += float(l[3])
			n += 1.0
	return tot / maxf(1.0, n)


static func _colony_indicators(world: WorldState) -> void:
	var s := EconUtil.st(world)
	var ch: Array = s["cpi_hist"]
	var infl := 0.0
	if ch.size() >= 13:
		infl = 100.0 * (float(ch[-1]) / float(ch[0]) - 1.0)
	elif ch.size() >= 2:
		infl = 100.0 * (pow(float(ch[-1]) / float(ch[0]), 12.0 / float(ch.size() - 1)) - 1.0)
	_w(world, "ECON_CPI_INFLATION", "COLONY", infl)
	# real output at base prices
	var out := 0.0
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		var g: String = EconData.RECIPES[f["type"]]["out"][0]
		if s["base"].has(g):
			out += float(f["out_last"]) / S * float(s["base"][g]) / S
	var oh: Array = s["output_hist"]
	oh.append(int(out))
	while oh.size() > 13:
		oh.pop_front()
	var growth := 0.0
	if oh.size() >= 13 and oh[0] > 0:
		growth = 100.0 * (float(oh[-1]) / float(oh[0]) - 1.0)
	_w(world, "ECON_GROWTH", "COLONY", growth)
	# project delivery (government projects, last 12 months)
	var ok := 0
	var all := 0
	for pid in world.table("project"):
		var p: Dictionary = world.table("project")[pid]
		if p["owner"] != "gov" or p["start_month"] < 0:
			continue
		if p["status"] == "ACTIVE":
			all += 1
			if world.month <= p["start_month"] + p["bid_duration"]:
				ok += 1
		elif p["status"] == "DONE" and world.month - p.get("done_month", 0) <= 12:
			all += 1
			if p["done_month"] <= p["start_month"] + p["bid_duration"]:
				ok += 1
	_w(world, "ECON_PROJECT_DELIVERY", "COLONY", 100.0 if all == 0 else 100.0 * ok / all)
	_w(world, "ECON_COMPANY_FAILURES", "COLONY", float(world.facts.query("COMP_INSOLVENCY", world.month - 11).size()))
	# import dependency (food + medical), 12 months
	var ih: Array = s.get("import_hist", [])
	var imp_m: Dictionary = s.get("imports_m", {})
	var made := 0
	for fid in world.table("facility"):
		var f: Dictionary = world.table("facility")[fid]
		if EconData.RECIPES[f["type"]]["out"][0] in ["FOOD", "MEDICAL"]:
			made += f["out_last"]
	ih.append([imp_m.get("FOOD", 0) + imp_m.get("MEDICAL", 0), made])
	while ih.size() > 12:
		ih.pop_front()
	s["import_hist"] = ih
	s["imports_m"] = {}
	var it := 0.0
	var mt := 0.0
	for x in ih:
		it += float(x[0])
		mt += float(x[1])
	_w(world, "ECON_IMPORT_DEPENDENCY", "COLONY", 100.0 * it / maxf(1.0, it + mt))
	# public finance
	var rev12 := float(EconFinance.gov_revenue_12m(world))
	var debt := float(EconFinance.debt_of(world, "gov"))
	_w(world, "ECON_PUBLIC_DEBT_RATIO", "COLONY", 100.0 * debt / maxf(1.0, rev12))
	var sh: Array = s.get("gov_spend_hist", [])
	sh.append(s.get("gov_spend_m", 0))
	while sh.size() > 12:
		sh.pop_front()
	s["gov_spend_hist"] = sh
	var spend12 := 0.0
	for v in sh:
		spend12 += float(v)
	var rev_actual := 0.0
	for v in s["gov_rev_hist"]:
		rev_actual += float(v)
	_w(world, "ECON_BUDGET_BALANCE", "COLONY", clampf(100.0 * (rev_actual - spend12) / maxf(1.0, rev_actual), -500.0, 100.0))
	var cxh: Array = s.get("gov_capex_hist", [])
	cxh.append(s.get("gov_capex_m", 0))
	while cxh.size() > 12:
		cxh.pop_front()
	s["gov_capex_hist"] = cxh
	var capex12 := 0.0
	for v in cxh:
		capex12 += float(v)
	_w(world, "ECON_OPERATING_BALANCE", "COLONY", clampf(100.0 * (rev_actual - (spend12 - capex12)) / maxf(1.0, rev_actual), -500.0, 100.0))
	var monthly := maxf(1.0, spend12 / maxf(1.0, float(sh.size())))
	var runway := (float(world.ledger.balance(EconUtil.TREASURY)) + float(EconFinance.gov_credit_headroom(world))) / monthly
	_w(world, "ECON_TREASURY_RUNWAY", "COLONY", clampf(runway, 0.0, 240.0))
	_w(world, "ECON_MARKET_CONCENTRATION", "COLONY", _hhi(world))


static func _hhi(world: WorldState) -> float:
	var worst := 0.0
	for good in ["FOOD", "CONSUMER", "MATERIAL"]:
		var tot := 0.0
		var shares := {}
		for oid in EconUtil.sorted_keys(world.table("org")):
			var q := float(world.table("org")[oid].get("sold", {}).get(good, 0))
			if q > 0.0:
				shares[oid] = q
				tot += q
		if tot <= 0.0:
			continue
		var h := 0.0
		for oid in EconUtil.sorted_keys(shares):
			h += pow(100.0 * shares[oid] / tot, 2.0)
		worst = maxf(worst, h)
	return worst

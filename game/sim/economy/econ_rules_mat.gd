class_name EconRulesMat
extends RefCounted
## R8 step 2b (Bob; planning/eight-rules.md): the eight rules for the materials chain, MINE (MINERAL), PROCESSING
## (MATERIAL) and COMPONENTS (COMPONENT). Switch R8 + R8_MATERIAL. Kill switches for the A/B take-apart (opt-in names in
## meta "on"): R8M_NOVALUE (value bids), R8M_NOOUT (rules 3/4), R8M_NOCAP (rules 5/6), R8M_NOENTRY (rules 7/8).
## Price rules 1/2: the first draft's rules (one market price on the type's cost, creep up to full cost, never below
## variable cost) are opt-in only (R8M_PX); Wilma dropped them after the A/B (planning/ab-r8-materials.md). The user's
## sentence of 2026-11-15 ("That's also of hard rules that's just going to lock up price, why is no one paying the price,
## that's the issue") criticised the draft's hard floors and led to value bids; it did not remove rules 1/2 (the user,
## 2026-11-16: "i did not say that in relation to the eight rules i said that before we applied them"). Every producer
## has all eight rules: rules 1/2 on the seller's own signals are R8M_OWNPX (below), off until their A/B.
##
## Why (probe, seeds 1 and 4 × 30 years with E172): the materials markets were in a price deadlock, not short of plants.
## MINERAL sat at its floor (0.25 × base) for twenty years at a fifth of the mines' cost; MATERIAL sold at 0.6–0.7 × the
## smelters' cost while 8–26% of orders went unfilled and 4–6k units piled up. Sellers' ask floor (0.9 × full cost) was
## above buyers' limits (1.3 × price + freight), so stock could not sell, the market read the unsold stock as cover and
## the price kept falling. No plant could earn the margin that _investment and _new_plants wait for.
##
##   1 raise price: unfilled orders > 5% → up by ALPHA × shortage (≤ STEP_UP a month); any unfilled order while the
##     price is below the plants' full cost → creep up STEP a month, up to that cost
##   2 lower price: only with every order filled (≤ 2% unfilled), over 2 months of cover and plants under U_LOW use →
##     down by ALPHA × excess (≤ STEP); never below the plants' variable cost. Otherwise drift toward MARKUP × full cost
##     (E149's target), never down while orders go unfilled
##   3 produce more: a plant adds its capacity share of the unfilled orders it can reach (R8 reach), while its cover is
##     under 2 months
##   4 produce less: below variable cost, the core crew only (the 20% floor)
##   5 add capacity: use ≥ 85% in 6 of the last 12 months and reachable unfilled orders ≥ 5% of its capacity in 6 of the last 12, price ≥
##     1.1 × full cost, the owner not losing money over 12 months (public enterprises exempt), no open project of that
##     owner and type, a crew to be had → +25% (an EXPAND) or, at 3×, a new plant beside it. One step per good a
##     quarter. Replaces _investment, _expansion, _new_plants and the essentials planner for these three types.
##   6 reduce capacity: the old mothball rule, but never while the plant has reachable unfilled orders
##   7/8 a new company / no new company: E170's forecast (EconForecast.first_year) in the best district, profit > 0, no
##     "no_customers" or "competitors"; none while incumbents holding most of the capacity lose money. COMPONENTS gets an
##     entry path (it had none).

const S := EconUtil.S
const TYPE_FOR := {"MINERAL": "MINE", "MATERIAL": "PROCESSING", "COMPONENT": "COMPONENTS"}
const GOOD_FOR := {"MINE": "MINERAL", "PROCESSING": "MATERIAL", "COMPONENTS": "COMPONENT"}
## R8 step 3 (opt-in R8_FOOD): rules 3–6 also for the food companies' plants (families follow their sales instead:
## EconRulesFood). Kill switches R8F_NOOUT, R8F_NOCAP.
const FOOD_GOOD_FOR := {"FARM": "FOOD", "BAKERY": "FINE_FOOD"}
## R8_WORKSHOPS (the user's order of 2026-11-16, every producer under all eight rules): the consumer workshops and the
## medical works get the same eight rules as the materials chain, all under the one sector switch: rules 1/2 their own
## prices (own_prices), 3/4 output (target), 5/6 capacity (capacity, keeps), 7/8 entry on the forecast (entry_hot; the
## medical works get an entry path, they had none). Kill switches for the take-apart: R8W_NOPX, R8W_NOOUT, R8W_NOCAP,
## R8W_NOENTRY.
const WORKSHOP_GOOD_FOR := {"CONSUMERF": "CONSUMER", "TEXTILE": "CLOTHING", "FURNITURE": "FURNISHINGS", "MEDWORKS": "MEDICAL"}


static func shops_on(world: WorldState) -> bool:
	return EconRules.sector_on(world, "WORKSHOPS")
const STEP := 0.03
const STEP_UP := 0.05
const MARKUP := 1.2
const U_LOW := 700  # ‰ use below which a glut may lower the price
const HI_USE := 850
const HI_M := 6
const UNF_PM := 50  # ‰ of a plant's capacity in reachable unfilled orders
const UNF_M := 6
const ADD_MARGIN := 1.1
const MAX_SCALE := 3000
const COVER_MAX := 2000  # ‰ months of sales: no extra output beyond this stock


static func on(world: WorldState) -> bool:
	return EconRules.sector_on(world, "MATERIAL")


static func _part(world: WorldState, kill: String) -> bool:
	return on(world) and not (world.meta.get("on", []) as Array).has(kill)


## Rules 1/2 on the seller's own signals (R8M_OWNPX, opt-in until its A/B; Wilma 2026-11-16): each MINE, PROCESSING and
## COMPONENTS plant has its own price, set after each month's clearing from its own R8 readings. Both rules act every
## month: rule 1 up by OWN_ALPHA × the orders it could reach but not supply ÷ its capacity (at most OWN_UP); rule 2 down
## by stock_cut of the stock it offered and did not sell (not stock it holds back), the more the bigger the cut.
## No floor, no creep to cost, no "never below" (the hard rules the user objected to); only the bounds every price in
## the game has (PRICE_MIN_MULT .. PRICE_MAX_MULT × the wage level). The seller asks its own price (FirmAI: no cover
## markup, no 0.9 × full-cost ask floor for these goods); the good's market price, which buyers' limits and rules 5/7
## read, is the capacity-weighted mean of its open plants' prices instead of the E149 step.
## OWN_ALPHA, OWN_UP and OWN_DOWN are Bob's numbers, not the user's.
const OWN_ALPHA := 0.15
const OWN_UP := 0.05
const OWN_DOWN := 0.03
## Rule 2's curve (Bob's): the monthly cut = STOCK_CUT_MAX × c ÷ (1 + c), c = the seller's own stock in months of its
## sales (its cover; stock nobody buys counts as a great many months). No threshold: a little stock is a little cut
## (1 month 5%, 3 months 7.5%, 9 months 9%), never more than STOCK_CUT_MAX a month.
const STOCK_CUT_MAX := 0.10


## RULE NINE (the user, 2026-11-16: "if below making price climbing allways had priority if above lowering has
## priority if both signals come in the same month only the one with priority happens, and if your going to cap it at
## 5% THEN DO THE SAME FOR BOTH"; "Only fix this item for now": the material chain first, under R8M_OWNPX). A company's
## price for MINERAL, MATERIAL or COMPONENT, every month:
##   below its full cost: if the raise signal is there, the price rises and the cut does nothing; else the cut acts;
##   at or above it: if the cut signal is there, the price falls and the raise does nothing; else the raise acts.
## Signals, price-only (EconMarket._fill's tags): the raise reads orders from able, reachable buyers that found no goods
## (r8 plants reach_px), the cut the stock it offered and left unsold at the price (st unsold_px_by), both against what
## it sold. One curve and one most-per-month both ways: PRICE_STEP_MAX × c ÷ (1 + c); 5% is the user's, the shape Bob's.
const PRICE_STEP_MAX := 0.05


static func curve(c: float) -> float:
	var x := maxf(0.0, c)
	return PRICE_STEP_MAX * x / (1.0 + x)


static func rule_nine(p: float, cost: float, up_c: float, down_c: float) -> float:
	var up := curve(up_c)
	var down := curve(down_c)
	if p < cost:
		return p * (1.0 + up) if up > 0.0 else p * (1.0 - down)
	return p * (1.0 - down) if down > 0.0 else p * (1.0 + up)


## The material chain's cut signal: what the company offered and left unsold at the price (not what buyers wanted but
## could not take for freight, road or money), against what it sold.
static func _unsold_px_ratio(world: WorldState, oid: String, good: String) -> float:
	var o: Dictionary = world.table("org").get(oid, {})
	var sold := int((o.get("sold", {}) as Dictionary).get(good, 0))
	var unsold := int((EconUtil.peek_st(world).get("unsold_px_by", {}) as Dictionary).get(oid + "|" + good, 0))
	return float(unsold) / maxf(float(sold), float(S))


static func stock_cut(cover_months: float) -> float:
	var c := maxf(0.0, cover_months)
	return STOCK_CUT_MAX * c / (1.0 + c)


## Which switch puts a good's sellers on rules 1/2: materials R8M_OWNPX; food (big farms, bakeries and the family
## farms and bakeries alike: every plant that makes FOOD or FINE_FOOD) R8F_OWNPX, with R8_FOOD.
const OWN_SWITCH := {"MINERAL": "R8M_OWNPX", "MATERIAL": "R8M_OWNPX", "COMPONENT": "R8M_OWNPX", "FOOD": "R8F_OWNPX",
	"FINE_FOOD": "R8F_OWNPX", "CONSUMER": "R8_WORKSHOPS", "CLOTHING": "R8_WORKSHOPS", "FURNISHINGS": "R8_WORKSHOPS",
	"MEDICAL": "R8_WORKSHOPS"}


static func own_on(world: WorldState, good: String) -> bool:
	if not OWN_SWITCH.has(good):
		return false
	var sw := String(OWN_SWITCH[good])
	if sw == "R8_WORKSHOPS":
		return shops_on(world) and not (world.meta.get("on", []) as Array).has("R8W_NOPX")
	var sector := on(world) if TYPE_FOR.has(good) else EconRulesFood.on(world)
	return sector and (world.meta.get("on", []) as Array).has(sw) and not EconUtil.off(world, sw)


static func _makes(f: Dictionary, good: String) -> bool:
	var r: Dictionary = EconData.RECIPES.get(f["type"], {})
	return not r.is_empty() and String(r["out"][0]) == good


static func _px_bounds(world: WorldState, good: String, p: float) -> int:
	var base := float(EconUtil.st(world)["base"][good])
	return maxi(1, int(clampf(p, base * EconData.PRICE_MIN_MULT, base * EconData.PRICE_MAX_MULT * EconMarket.wage_level(world))))


## Rules 1/2, monthly after clearing (from EconRulesMat.monthly, after the R8 plant readings).
static func own_prices(world: WorldState) -> void:
	# One price per company and good (Wilma, 2026-11-16, from the seed-1 trace: one company asking five prices for the
	# same good, most above any buyer's limit, left its offers unsold, so the stock cut cancelled rule 1 and the price
	# never climbed back to cost). Rules 1 and 2 act on the company's price: rule 1 on the orders its plants could reach
	# (the most any of them reads) against its capacity, rule 2 on what it offered and did not sell across all its plants.
	# Every plant of the company carries that one price, so every offer it makes is at it (own_ask).
	var s := EconUtil.st(world)
	var pl: Dictionary = s["r8"].get("plants", {})
	for good in EconUtil.sorted_keys(OWN_SWITCH):
		if not own_on(world, good):
			continue
		var by_org := {}  # org -> {fids, cap, px_w, reach, read, first}
		for fid in EconUtil.sorted_keys(world.table("facility")):
			var f: Dictionary = world.table("facility")[fid]
			if not _makes(f, good):
				continue
			var oid := String(f["org"])
			var row: Dictionary = by_org.get(oid, {"fids": [], "cap": 0.0, "px_w": 0.0, "px_c": 0.0, "reach": 0, "read": false, "first": fid})
			var cap := float(EconData.RECIPES[f["type"]]["out"][1]) * float(S) * EconUtil.fscale(f)
			(row["fids"] as Array).append(fid)
			var p0 := float(int(f.get("r8_px", 0)))
			if p0 <= 0.0:
				p0 = float(s["prices"][good])
			row["px_w"] = float(row["px_w"]) + p0 * cap
			row["px_c"] = float(row["px_c"]) + cap
			if not f["mothball"]:
				row["cap"] = float(row["cap"]) + cap
				var r: Dictionary = pl.get(fid, {})
				if not r.is_empty():
					row["read"] = true
					row["reach"] = maxi(int(row["reach"]), int(r["reach"]))
					row["reach_px"] = maxi(int(row.get("reach_px", 0)), int(r.get("reach_px", 0)))
					row["first"] = fid if not bool(row.get("has_r", false)) else row["first"]
					row["has_r"] = true
			by_org[oid] = row
		var wsum := 0.0
		var csum := 0.0
		for oid in EconUtil.sorted_keys(by_org):
			var row: Dictionary = by_org[oid]
			var p := float(row["px_w"]) / maxf(1.0, float(row["px_c"]))  # the company's price (one per good)
			if bool(row["read"]) and TYPE_FOR.has(good):
				# the material chain under rule nine (price-only signals, one 5% curve both ways, priority by cost)
				var sold_c := int((world.table("org")[oid].get("sold", {}) as Dictionary).get(good, 0))
				var up_c := float(int(row.get("reach_px", 0))) / maxf(float(sold_c), float(S))
				var down_c := _unsold_px_ratio(world, String(oid), good)
				var fr: Dictionary = world.table("facility")[row["first"]]
				p = rule_nine(p, FirmAI.unit_cost(world, String(fr["type"])), up_c, down_c)
				var n9: Dictionary = EconUtil.st(world).get("r9_acts", {})
				var k9 := "%s|%s" % [good, "up" if p > float(row["px_w"]) / maxf(1.0, float(row["px_c"])) + 0.5 else ("down" if p < float(row["px_w"]) / maxf(1.0, float(row["px_c"])) - 0.5 else "none")]
				n9[k9] = int(n9.get(k9, 0)) + 1
				EconUtil.st(world)["r9_acts"] = n9
			elif bool(row["read"]):
				# rule 1: orders its plants could reach but not supply raise it, against the company's capacity
				if int(row["reach"]) > 0:
					p *= 1.0 + minf(OWN_UP, OWN_ALPHA * float(int(row["reach"])) / maxf(1.0, float(row["cap"])))
				# rule 2 (the user, 2026-11-16: "the more inventory you have, the more you reduce your price ... a soft
				# lock, not a hard lock"): a cut that grows smoothly with the stock it put on the market and did not
				# sell, across all its plants. Stock it holds back below its own cost waits for a better price.
				var f0: Dictionary = world.table("facility")[row["first"]]
				p *= 1.0 - stock_cut(_unsold_ratio(world, f0, good, pl.get(row["first"], {})))
			var px := _px_bounds(world, good, p)
			for fid in row["fids"]:
				world.table("facility")[fid]["r8_px"] = px
			wsum += float(px) * float(row["cap"])
			csum += float(row["cap"])
		if csum > 0.0:
			s["prices"][good] = _px_bounds(world, good, wsum / csum)


## Rule 2's signal (mu): what the plant's owner put on offer this month and did not sell, this plant's share by
## capacity. Stock it held back (FirmAI's hold-back below its own cost) is not in it: a seller does not cut its price
## for stock it chose to keep. Before any offer is recorded, the plant's stock (cover × sales).
## The stock cut's c: what the plant's owner offered this month and did not sell, ÷ what it sold (as the market table
## reads S − filled ÷ filled for every other good). Before any offer is recorded, the plant's cover.
static func _unsold_ratio(world: WorldState, f: Dictionary, good: String, r: Dictionary) -> float:
	var o: Dictionary = world.table("org").get(f["org"], {})
	if o.has("offered"):
		var offered := int((o["offered"] as Dictionary).get(good, 0))
		var sold := int((o.get("sold", {}) as Dictionary).get(good, 0))
		return float(maxi(0, offered - sold)) / maxf(float(sold), float(S))
	return float(int(r["cover"])) / 1000.0


static func _unsold_mu(world: WorldState, f: Dictionary, good: String, r: Dictionary, cap: float) -> float:
	var o: Dictionary = world.table("org").get(f["org"], {})
	if o.has("offered"):
		var offered := int((o["offered"] as Dictionary).get(good, 0))
		var sold := int((o.get("sold", {}) as Dictionary).get(good, 0))
		var own_cap := 0.0
		for fid in world.table("facility"):
			var f2: Dictionary = world.table("facility")[fid]
			if f2["org"] == f["org"] and not f2["mothball"] and _makes(f2, good):
				own_cap += float(EconData.RECIPES[f2["type"]]["out"][1]) * float(S) * EconUtil.fscale(f2)
		return float(maxi(0, offered - sold)) * cap / maxf(cap, own_cap)
	return float(int(r["cover"])) / 1000.0 * float(int(r.get("sales", 0)))


## What a seller asks for `good` in district `d` under R8M_OWNPX: the mean own price of its plants of that good there
## (open ones first), else of all its plants of that good, else the market price.
static func own_ask(world: WorldState, oid: String, good: String, d: String) -> int:
	var here := [0, 0]
	var open_here := [0, 0]
	var anyw := [0, 0]
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["org"] != oid or not _makes(f, good) or int(f.get("r8_px", 0)) <= 0:
			continue
		var p := int(f["r8_px"])
		anyw[0] += p
		anyw[1] += 1
		if f["district"] == d:
			here[0] += p
			here[1] += 1
			if not f["mothball"]:
				open_here[0] += p
				open_here[1] += 1
	if open_here[1] > 0:
		return open_here[0] / open_here[1]
	if here[1] > 0:
		return here[0] / here[1]
	if anyw[1] > 0:
		return anyw[0] / anyw[1]
	return int(EconUtil.st(world)["prices"][good])


static func prices_on(world: WorldState, good: String) -> bool:
	return TYPE_FOR.has(good) and on(world) and (world.meta.get("on", []) as Array).has("R8M_PX") and not EconUtil.off(world, "R8M_PX")


static func output_on(world: WorldState, ftype: String) -> bool:
	return _rule_on(world, ftype, "NOOUT")


static func capacity_on(world: WorldState, ftype: String) -> bool:
	return _rule_on(world, ftype, "NOCAP")


## The good a plant type makes under the eight rules' output and capacity rules ("" when its sector is off).
static func good_of(world: WorldState, ftype: String) -> String:
	if GOOD_FOR.has(ftype) and on(world):
		return String(GOOD_FOR[ftype])
	if FOOD_GOOD_FOR.has(ftype) and EconRulesFood.on(world):
		return String(FOOD_GOOD_FOR[ftype])
	if WORKSHOP_GOOD_FOR.has(ftype) and shops_on(world):
		return String(WORKSHOP_GOOD_FOR[ftype])
	return ""


## Family farms and bakeries under rules 5/6 (R8F_FAM56, with R8_FOOD; the user's order of 2026-11-16 that every
## producer has all eight rules): rule 5 grows the family's own plant by a quarter (it hires hands; never a second
## plant), on the same signals as any producer, with the family's own unit cost in the price test; rule 6 is the
## mothball rule, never while the plant has reachable unfilled orders. Rules 3/4 stay the family's own (EconRulesFood).
static func fam56_on(world: WorldState, ftype: String) -> bool:
	return EconRulesFood.FAMILY_TYPES.has(ftype) and EconRulesFood.on(world) \
		and (world.meta.get("on", []) as Array).has("R8F_FAM56") and not EconUtil.off(world, "R8F_FAM56")


## The good a plant type makes for rules 5/6 and their counters: good_of, or a family type's good under R8F_FAM56.
static func _rule_good(world: WorldState, ftype: String) -> String:
	var g := good_of(world, ftype)
	if g == "" and fam56_on(world, ftype):
		g = String(EconRulesFood.FAMILY_TYPES[ftype])
	return g


static func _rule_on(world: WorldState, ftype: String, part: String) -> bool:
	if good_of(world, ftype) == "":
		return false
	var kill := ("R8M_" if GOOD_FOR.has(ftype) else ("R8W_" if WORKSHOP_GOOD_FOR.has(ftype) else "R8F_")) + part
	return not (world.meta.get("on", []) as Array).has(kill)


static func entry_on(world: WorldState, ftype: String) -> bool:
	if WORKSHOP_GOOD_FOR.has(ftype):
		return shops_on(world) and not (world.meta.get("on", []) as Array).has("R8W_NOENTRY")
	if FOOD_GOOD_FOR.has(ftype):
		# R8F_ENTRY (with R8_FOOD; the user's order that every producer has all eight rules): big farms and bakeries
		# are founded on the forecast like the materials chain, instead of the colony price test and the D2 gates
		return EconRulesFood.on(world) and (world.meta.get("on", []) as Array).has("R8F_ENTRY") 			and not EconUtil.off(world, "R8F_ENTRY")
	return GOOD_FOR.has(ftype) and _part(world, "R8M_NOENTRY")


# ------------------------------------------------------------------ rules 1/2 (EconMarket._update_prices)

## The new price for `good` from last month's shortage (unfilled share) and excess (cover beyond 2 months, 0..1).
static func price(world: WorldState, good: String, p: float, shortage: float, excess: float) -> float:
	var uc := FirmAI.unit_cost(world, String(TYPE_FOR[good]))
	var use := _mean_use(world, good)
	var var_c := _var_floor(world, good)
	if shortage > 0.05:
		return p * (1.0 + minf(STEP_UP, EconData.ALPHA * shortage))
	if shortage > 0.0 and p < uc:
		return minf(uc, p * (1.0 + STEP))
	if shortage <= 0.02 and excess > 0.0 and use < U_LOW:
		return maxf(minf(p, var_c), p * (1.0 - minf(STEP, EconData.ALPHA * excess)))
	var target := MARKUP * uc
	if p > target:
		if shortage > 0.0:
			return p  # never down while orders go unfilled
		return maxf(target, p * (1.0 - STEP))
	return minf(target, p * (1.0 + STEP))


## Mean use (‰) of the open plants making `good`, last month's R8 readings (1000 when none are measured).
static func _mean_use(world: WorldState, good: String) -> int:
	var t := 0
	var n := 0
	var pl: Dictionary = EconUtil.peek_st(world).get("r8", {}).get("plants", {})
	for fid in EconUtil.sorted_keys(pl):
		if String(pl[fid]["g"]) == good:
			t += int(pl[fid]["util"])
			n += 1
	return 1000 if n == 0 else t / n


## The lowest variable cost (mcr/unit) among the open plants making `good` (0 when none are measured).
static func _var_floor(world: WorldState, good: String) -> float:
	var best := -1
	var pl: Dictionary = EconUtil.peek_st(world).get("r8", {}).get("plants", {})
	for fid in EconUtil.sorted_keys(pl):
		if String(pl[fid]["g"]) == good and (best < 0 or int(pl[fid]["cost_var"]) < best):
			best = int(pl[fid]["cost_var"])
	return float(maxi(0, best))


# ------------------------------------------------------------------ rules 3/4 (FirmAI._set_target)

## The plant's target (0..1) given the old rule's t: its share of reachable unfilled orders on top of last month's
## output while its stock is under COVER_MAX; the core crew only below variable cost.
static func target(world: WorldState, f: Dictionary, good: String, t: float) -> float:
	var pl := EconRules.plant(world, String(f["id"]))
	if pl.is_empty():
		return t
	var s := EconUtil.st(world)
	if float(EconTrade.plan_price(world, good)) < float(int(pl["cost_var"])):  # EXP: the home price counts when the ship has room
		return 0.2
	var cover := int(pl["cover"])
	if TYPE_FOR.has(good) and own_on(world, good):
		# (A), the user, 2026-11-16: "Ignore the stock in that other place too". The material chain's output reads only
		# the stock the company put on offer and left unsold, never the store it holds back below its cost, so a held
		# store does not drop the plants to the core crew while buyers go unfilled.
		var unsold := int((s.get("unsold_px_by", {}) as Dictionary).get(String(f["org"]) + "|" + good, 0))
		cover = int(1000.0 * float(unsold) / float(maxi(1, int(pl["sales"]))))
	if cover >= COVER_MAX:
		return t
	var r: Dictionary = EconData.RECIPES[f["type"]]
	var cap := float(r["out"][1]) * float(S) * EconUtil.fscale(f)
	var all_cap := 0.0
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f2: Dictionary = world.table("facility")[fid]
		if f2["type"] == f["type"] and not f2["mothball"]:
			all_cap += float(r["out"][1]) * float(S) * EconUtil.fscale(f2)
	var extra := float(int(pl["reach"])) * cap / maxf(1.0, all_cap)
	var want := (float(int(f.get("out_last", 0))) + extra) / maxf(1.0, cap)
	return maxf(t, clampf(want, 0.2, 1.0))


# ------------------------------------------------------------------ monthly counters (EconRules.monthly)

static func monthly(world: WorldState) -> void:
	if not on(world) and not EconRulesFood.on(world) and not shops_on(world):
		return
	var pl: Dictionary = EconUtil.st(world)["r8"].get("plants", {})
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if _rule_good(world, String(f["type"])) == "":
			continue
		var p: Dictionary = pl.get(fid, {})
		if p.is_empty():
			f["r8_hi_m"] = 0
			f["r8_unf_m"] = 0
			f["r8_hi_bits"] = 0
			f["r8_unf_bits"] = 0
			continue
		var r: Dictionary = EconData.RECIPES[f["type"]]
		var cap := int(float(r["out"][1]) * float(S) * EconUtil.fscale(f))
		# months in the last 12 (a 12-bit window; trace: unfilled orders come in bursts, so a run of 6 never formed)
		f["r8_hi_bits"] = ((int(f.get("r8_hi_bits", 0)) << 1) | (1 if int(p["util"]) >= HI_USE else 0)) & 0xFFF
		f["r8_unf_bits"] = ((int(f.get("r8_unf_bits", 0)) << 1) | (1 if int(p["reach"]) * 1000 >= cap * UNF_PM else 0)) & 0xFFF
		f["r8_hi_m"] = _bits(int(f["r8_hi_bits"]))
		f["r8_unf_m"] = _bits(int(f["r8_unf_bits"]))
	own_prices(world)  # rules 1/2 on the seller's own signals (R8M_OWNPX)


static func _bits(x: int) -> int:
	var n := 0
	while x > 0:
		n += x & 1
		x >>= 1
	return n


## Rule 6: a plant with reachable unfilled orders in the last 12 months is not mothballed.
static func keeps(world: WorldState, f: Dictionary) -> bool:
	return (capacity_on(world, String(f["type"])) or fam56_on(world, String(f["type"]))) and int(f.get("r8_unf_m", 0)) > 0


# ------------------------------------------------------------------ rule 5 (quarterly, FirmAI.run)

static func capacity(world: WorldState) -> void:
	if not on(world) and not EconRulesFood.on(world) and not shops_on(world):
		return
	var s := EconUtil.st(world)
	var acts: Array = s.get("r8_mat_actions", [])
	var done := {}
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		var ftype := String(f["type"])
		var fam56 := fam56_on(world, ftype)
		if not (capacity_on(world, ftype) or fam56) or f["mothball"] or done.has(ftype):
			continue
		if int(f.get("r8_hi_m", 0)) < HI_M or int(f.get("r8_unf_m", 0)) < UNF_M:
			continue
		var o: Dictionary = world.table("org").get(f["org"], {})
		if o.is_empty() or o["status"] != "ACTIVE" or o["is_contractor"] or (bool(o.get("family", false)) and not fam56):
			continue
		var pe: bool = o["type"] == "PUBLIC_ENTERPRISE"
		if not (o["type"] in ["PRIVATE", "COOPERATIVE"] or pe):
			continue
		var good := _rule_good(world, ftype)
		var family := bool(o.get("family", false))
		var uc := EconRulesFood.family_full_cost(world, String(f["org"]), ftype) if family else FirmAI.unit_cost(world, ftype)
		if float(EconTrade.plan_price(world, good)) < ADD_MARGIN * uc:
			continue
		if not pe and EconPublicCo.result12(o) < 0:
			continue
		if EconConstruction.has_open_project(world, f["org"], ftype) or _expand_pending(world, fid):
			continue
		var grow := int(f.get("scale", 1000)) < MAX_SCALE and EconData.BUILD.has(ftype)
		if family and not grow:
			continue  # a family grows its own plant; it never builds a second one
		if not grow and EconEssentials.labour_fill(world, ftype) < EconEssentials.MIN_LABOUR_FILL:
			continue
		var cost := EconConstruction.estimate(ftype) / 4 if grow else EconConstruction.estimate(ftype)
		if not grow and not LawBridge.allowed(world, f["org"], "BUILD_FACILITY", {"facility_type": ftype, "district": f["district"],
				"owner_kind": "COMPANY", "value_wref": cost / maxi(1, int(world.values.get("ECON_W_REF", 1200 * S)))}):
			continue
		if not _finance(world, String(f["org"]), cost, pe):
			continue
		if grow:
			EconConstruction.create_expansion(world, fid, f["org"])
			o["last_expand"] = world.month
		else:
			EconConstruction.create(world, ftype, f["district"], f["org"], f["org"], "")
			o["last_invest"] = world.month
		acts.append([world.month, ftype, "expand" if grow else "new"])
		done[ftype] = true
		for fid2 in world.table("facility"):
			var f2: Dictionary = world.table("facility")[fid2]
			if f2["type"] == ftype:
				f2["r8_hi_m"] = 0
				f2["r8_unf_m"] = 0
				f2["r8_hi_bits"] = 0
				f2["r8_unf_bits"] = 0
		EconFacts.emit(world, "COMP_INVESTMENT", f["district"], [["COMPANY", f["org"]]], [["COMPANY", f["org"], 1.0]], {"JOBS": 2}, 15,
			"PUBLIC", {"type": ftype, "reason": "orders", "good": good})
	s["r8_mat_actions"] = acts


static func _expand_pending(world: WorldState, fid: String) -> bool:
	for pid in world.table("project"):
		var p: Dictionary = world.table("project")[pid]
		if p["type"] == "EXPAND" and p.get("target", "") == fid and p["status"] in ["TENDER", "ACTIVE", "TENDERABLE"]:
			return true
	return false


## Cash first, then a bank loan (the owner puts in 30%); a public enterprise without bank room asks the treasury, as
## the essentials planner did (not behind a human government's back).
static func _finance(world: WorldState, oid: String, cost: int, pe: bool) -> bool:
	var cash := world.ledger.balance(EconUtil.acct(oid))
	if cash >= cost:
		return true
	if cash >= cost * 3 / 10 and EconFinance.new_loan(world, oid, mini(cost - cash, cost * 7 / 10), 0, true):
		return true
	if not pe or EconEssentials.human_governs(world):
		return false
	var paid := EconFinance.gov_pay(world, EconUtil.acct(oid), cost - cash, "PE_INVESTMENT")
	FirmAI.DecisionDesk.note(world, "PE_INVESTMENT")
	EconFinance._spend_line(world, "ECON_BUDGET_INFRASTRUCTURE", paid)
	return paid >= (cost - cash) / 2


# ------------------------------------------------------------------ rules 7/8 (FirmAI._entry)

## Whether founders see this sector as worth entering: the forecast in its best district, and incumbents not losing.
static func entry_hot(world: WorldState, ftype: String, founder_d: String) -> bool:
	if _incumbents_losing(world, ftype):
		return false
	var d := entry_district(world, ftype, founder_d)
	var fc := EconForecast.first_year(world, ftype, d)
	var why: Array = fc["reasons"]
	return int(fc["profit"]) > 0 and not why.has("no_customers") and not why.has("competitors")


## The district a founder would build in: mines where the ore is (d:3), other plants where the forecast is best.
static func entry_district(world: WorldState, ftype: String, founder_d: String) -> String:
	if ftype == "MINE":
		return "d:3"
	var best := founder_d
	var best_p := int(EconForecast.first_year(world, ftype, founder_d)["profit"])
	for d in EconUtil.sorted_keys(EconData.DISTRICTS):
		var pr := int(EconForecast.first_year(world, ftype, String(d))["profit"])
		if pr > best_p:
			best_p = pr
			best = String(d)
	return best


## Rule 8: incumbents holding more than half of the open capacity lost money over 12 months.
static func _incumbents_losing(world: WorldState, ftype: String) -> bool:
	var all_c := 0
	var losing := 0
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] != ftype or f["mothball"]:
			continue
		var o: Dictionary = world.table("org").get(f["org"], {})
		var c := int(f.get("scale", 1000))
		all_c += c
		if not o.is_empty() and EconPublicCo.result12(o) < 0:
			losing += c
	return all_c > 0 and losing * 2 > all_c


# ------------------------------------------------------------------ value bids (on with R8_MATERIAL, off with R8M_NOVALUE; user ruling via Wilma)
## "Why is no one paying the price?" Buyers' limits were a multiple of the market price (inputs 1.3×, builders 1.3×), so
## they fell with the price and nobody offered what an input is worth to them. A buyer of MINERAL,
## MATERIAL or COMPONENT bids up to its value (the old multiple stays as a floor; the price ceiling caps it):
## - a producer (private, co-op, public enterprise): its output at full load at today's price, less wages, the other
##   inputs, utilities and the rest of its upkeep, per unit of this good it uses (recipe input plus upkeep parts); the
##   best of its plant types that use it;
## - a builder: the material allowance its contracts pay for, base price × (contract price ÷ cost estimate).

static func value_on(world: WorldState) -> bool:
	return on(world) and not (world.meta.get("on", []) as Array).has("R8M_NOVALUE")


## {"org|good": mcr per unit} for the org's plant types that use the good; empty when off.
static func value_bids(world: WorldState) -> Dictionary:
	var out := {}
	if not value_on(world):
		return out
	var tv := {}
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		var o: Dictionary = world.table("org").get(f["org"], {})
		if o.is_empty() or not (o["type"] in ["PRIVATE", "COOPERATIVE", "PUBLIC_ENTERPRISE"]):
			continue
		for good in TYPE_FOR:
			var k := String(f["type"]) + "|" + String(good)
			if not tv.has(k):
				tv[k] = _type_value(world, String(f["type"]), String(good))
			if float(tv[k]) > 0.0:
				var ko := String(f["org"]) + "|" + String(good)
				out[ko] = maxi(int(out.get(ko, 0)), int(tv[k]))
	return out


## What one unit of `good` is worth to a plant of `ftype` running at full load (mcr; 0 when it doesn't use it).
static func _type_value(world: WorldState, ftype: String, good: String) -> float:
	var s := EconUtil.st(world)
	var r: Dictionary = EconData.RECIPES.get(ftype, {})
	if r.is_empty():
		return 0.0
	var units := float(r["in"].get(good, 0))
	if good == "MATERIAL":
		units += float(r["upkeep"])
	elif good == "COMPONENT":
		units += float(EconData.UPKEEP_COMPONENT.get(ftype, 0))
	if units <= 0.0:
		return 0.0
	var og := String(r["out"][0])
	var pout := 0.0
	if og in EconData.MARKET_GOODS:
		pout = float(int(s["prices"][og]))
	elif og == "SERVICES":
		var n := 0
		for d in s.get("svc_price", {}):
			pout += float(int(s["svc_price"][d]))
			n += 1
		pout /= maxf(1.0, float(n))
	else:
		return 0.0  # utilities and institutions: tariffs and budgets, not a market value
	var margin := float(r["out"][1]) * pout
	for t in r["labor"]:
		margin -= float(r["labor"][t]) * float(int(s["wage"].get(t, 0)))
	for g in r["in"]:
		if g == good:
			continue
		if g in EconData.MARKET_GOODS:
			margin -= float(r["in"][g]) * float(int(s["prices"][g]))
		elif g == "ENERGY":
			margin -= float(r["in"][g]) * float(EconUtil.lever(world, "ECON_UTILITY_TARIFF_ENERGY", 40)) * S
		elif g == "WATER":
			margin -= float(r["in"][g]) * float(EconUtil.lever(world, "ECON_UTILITY_TARIFF_WATER", 20)) * S
	if good != "MATERIAL":
		margin -= float(r["upkeep"]) * float(int(s["prices"]["MATERIAL"]))
	if good != "COMPONENT":
		margin -= float(EconData.UPKEEP_COMPONENT.get(ftype, 0)) * float(int(s["prices"]["COMPONENT"]))
	return maxf(0.0, margin / units)


## A buyer's limit for `good`: the old limit, raised to the value (+ the freight allowance), capped at the price ceiling.
static func value_limit(world: WorldState, good: String, old_lim: int, value: int, freight_allow: int) -> int:
	if value <= 0 or not TYPE_FOR.has(good):
		return old_lim
	var cap := int(float(EconUtil.st(world)["base"][good]) * EconData.PRICE_MAX_MULT * EconMarket.wage_level(world)) + freight_allow
	return maxi(old_lim, mini(value + freight_allow, cap))


## A builder's value per unit of MATERIAL / COMPONENT: the base price its contracts were priced on × contract price ÷
## cost estimate (its active contracts; 0 without one). Under R8M_JOBVALUE: job_value (no base price in it).
static func builder_value(world: WorldState, oid: String, good: String) -> int:
	if not value_on(world) or not TYPE_FOR.has(good):
		return 0
	if job_value_on(world):
		return job_value(world, oid, good)
	var price := 0
	var est := 0
	for pid in world.table("org")[oid].get("contracts", []):
		var p: Dictionary = world.table("project").get(pid, {})
		if p.is_empty() or p["status"] != "ACTIVE":
			continue
		price += int(p["price"])
		est += int(p.get("est_cost", 0))
	if price <= 0 or est <= 0:
		return 0
	return int(float(EconData.BASE_PRICE[good]) * float(S) * float(price) / float(est))


## R8M_JOBVALUE (opt-in until its A/B; Wilma 2026-11-16; formula agreed with Otto, who owns the builders): a builder's
## value of material is what its jobs leave for it at today's figures. Over the jobs it buys material for (ACTIVE, started,
## no payment behind: unpaid_m == 0), per unit of this good still needed (total × the share of work left):
##   the award price of this good (the E76 escalation clause pays back any rise above it, up to its cap)
## + (what the work left earns: (price − the late penalty owed today (supervised jobs: price × min(10%, 1% a month
##    late))) × the share of work left; not price − paid, since the 10% advance and the retention only move cash in
##    time (Otto) − the wages still to pay (work left × its crew wage × 1.08, the overhead its bid uses) − the other input still
##    needed at its award price) ÷ the units still needed.
## Office, upkeep and interest are not taken off (paid whether or not it buys this unit). This month's wages are counted
## as still to pay, so it is the lower bound (Otto). 0 when nothing is left (the old 1.3 × price limit then stands).
static func job_value_on(world: WorldState) -> bool:
	return (world.meta.get("on", []) as Array).has("R8M_JOBVALUE") and not EconUtil.off(world, "R8M_JOBVALUE")


static func job_value(world: WorldState, oid: String, good: String) -> int:
	if not (good in ["MATERIAL", "COMPONENT"]):
		return 0
	var mat := good == "MATERIAL"
	var key := "mat_total" if mat else "comp_total"
	var okey := "comp_total" if mat else "mat_total"
	var pkey := "esc_mat_price" if mat else "esc_comp_price"
	var opkey := "esc_comp_price" if mat else "esc_mat_price"
	var prices: Dictionary = EconUtil.st(world)["prices"]
	var wage := EconConstruction._crew_wage(world, oid) * 1.08
	var money := 0.0
	var need := 0.0
	for pid in world.table("org")[oid].get("contracts", []):
		var p: Dictionary = world.table("project").get(pid, {})
		if p.is_empty() or p["status"] != "ACTIVE" or int(p["wu_total"]) <= 0:
			continue
		if int(p.get("start_month", -1)) < 0 or int(p["start_month"]) > world.month or int(p.get("unpaid_m", 0)) > 0:
			continue
		var wu_left := float(maxi(0, int(p["wu_total"]) - int(p["wu_done"])))
		var frac := wu_left / float(int(p["wu_total"]))
		var n := float(int(p[key])) * frac
		var late := maxi(0, world.month - (int(p["start_month"]) + int(p["bid_duration"])))
		var penalty := float(int(p["price"])) * minf(0.10, 0.01 * float(late)) if int(p["supervision"]) >= 500 else 0.0
		var award := float(int(p.get(pkey, prices[good])))
		var o_award := float(int(p.get(opkey, prices["COMPONENT" if mat else "MATERIAL"])))
		money += award * n / float(S) + (float(int(p["price"])) - penalty) * frac \
			- wu_left / float(S) * wage - float(int(p[okey])) * frac / float(S) * o_award
		money += EconBuilders.wage_change(world, p, frac)  # the wage clause (a19ee06): the work left earns the wage rise since award
		need += n
	if need <= 0.0 or money <= 0.0:
		return 0
	return int(money * float(S) / need)

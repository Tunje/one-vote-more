extends RefCounted
## R8 step 6 (Ella; planning/eight-rules.md): the service hubs (SERVICEHUB) under the eight rules. Switch R8 +
## R8_SERVICES. The user's order (2026-11-16, MASTER-PLAN.md): every producer gets all eight rules, each on its own
## market, no floors, caps or locks of our own. Kill switches for the A/B take-apart (names in meta "on"):
## R8S_NOFILL (the service signal), R8S_NOPX (rules 1/2), R8S_NOOUT (rules 3/4), R8S_NOCAP (rules 5/6),
## R8S_NOENTRY (rules 7/8).
##
## A hub's market: households buy services where they live, from hubs in their own district, or from a neighbour's
## at +10% (EconHouseholds._buy_services); what is left goes to self-employed sellers. Services can't be stored, so
## a hub's unsold capacity is its glut, and demand nobody served is its shortage. The signals, monthly:
##   unfilled: st["r8"]["goods"]["SERVICES"][d].u (service wanted by district d's households and served by nobody)
##   reach:    st["r8"]["plants"][fid].reach (the unfilled demand in the hub's district and its neighbours)
##   spare:    f["svc_spare"] (capacity it offered and did not sell this month)
##   cost:     st["r8"]["plants"][fid].cost_var / cost_full (mcr per unit), profit12 (the owner's last 12 months)
## The signal (R8S_NOFILL): households buy services after TRADE, when R8 had already totalled the month, and the next
## month's reset wiped them, so the SERVICES row never arrived and every hub's reach was 0. keep_fill/carry hold the
## month's purchases (hubs + self-employed) for the next TRADE: the SERVICES row describes the month before (goods:
## the month just cleared). Every hub's svc_sold is reset monthly, also at zero output (it kept a frozen figure).
##
##   1 raise price / 2 lower price (per district, after the month's sales): p × (1 + ALPHA × (unfilled − spare) ÷
##     the larger of wanted and offered). Unserved customers raise it, unsold hours lower it, both in proportion; the
##     colony's price speed EconData.ALPHA. Replaces the old rule on district demand against hubs' output.
##   3 serve more / 4 serve less: target = (what it sold + its capacity share of the unfilled demand it can reach) ÷
##     its capacity: a hub that sold out with customers waiting steps up, one with unsold hours falls back to what it
##     sold. While the district price pays its full cost (crew, inputs, the building) it also offers OFFER_STEP more
##     hours a month: the unsold ones lower the price (rule 2) until it no longer pays, so an idle hub competes
##     instead of waiting while its neighbours sell dear. Below its variable cost (the price can't pay the energy
##     and goods a service uses) it serves none.
##     Replaces the old 1.1 × sales + 5% with a 30% floor, and E134's step-up gated on colony unemployment.
##   5 add capacity: sold out with customers waiting and its crew complete in ADD_M of the last WIN_M months, the district price at or above
##     its full cost, the owner earning over 12 months, no project of its own under way → +25% (EXPAND), or at the
##     largest scale a new hub beside it. One per district a quarter. Replaces FirmAI._expansion for hubs.
##   6 reduce capacity: unsold hours (or no output) in CUT_M of the last WIN_M months while the customers waiting near
##     it fit in the other open hubs' unused capacity, and the owner losing money over 12 months → mothballed. Never
##     while customers wait that the others can't serve. A mothballed hub reopens when the unfilled demand it would
##     reach is more than the open hubs near it leave unused, REOPEN_M
##     months running (it is the cheapest new capacity, so it comes before a founding).
##   7 a new company / 8 no new company: in the district where it pays best, a founder sees the unfilled service
##     demand it could reach, less the hours the hubs near it leave unused, less the hubs being built, expanded or
##     lying mothballed near it, times the share of a crew the unemployed can fill; it founds when a hub's first year
##     at today's price, wages and inputs (crew, energy, goods,
##     the building's cost spread over its life) makes a profit. No founding where no customer waits net of
##     incumbents, or where the incumbents holding most of the capacity near it lose money. The same test for a
##     rich founder's full hub (FirmAI._entry) and a household's micro co-op (FirmAI._small_business), which loses
##     its colony-unemployment trigger, its 18-month gap, its two-per-district cap and its price gate.
## The step sizes and windows are Ella's (SECTORS["SERVICES"].params); nothing else is a number of ours. The district
## price stays inside the economy's general price band (EconData.PRICE_MIN_MULT / PRICE_MAX_MULT, as every price).

const S := EconUtil.S
const HUB := "SERVICEHUB"


static func on(world: WorldState) -> bool:
	return EconRules.sector_on(world, "SERVICES")


static func part(world: WorldState, kill: String) -> bool:
	return on(world) and not (world.meta.get("on", []) as Array).has(kill)


static func fill_on(world: WorldState) -> bool:
	return part(world, "R8S_NOFILL")


static func px_on(world: WorldState) -> bool:
	return part(world, "R8S_NOPX")


static func out_on(world: WorldState) -> bool:
	return part(world, "R8S_NOOUT")


static func cap_on(world: WorldState) -> bool:
	return part(world, "R8S_NOCAP")


static func entry_on(world: WorldState) -> bool:
	return part(world, "R8S_NOENTRY")


static func _p(key: String) -> int:
	return int(EconRules.SECTORS["SERVICES"]["params"][key])


# ------------------------------------------------------------------ the signal (EconRules.note_fill / monthly)

## Households' service purchases this month (mu), kept for the next TRADE.
static func keep_fill(world: WorldState, d: String, want: int, got: int) -> void:
	var s := EconUtil.st(world)
	var sv: Dictionary = s.get("r8_svc", {})
	var row: Dictionary = sv.get(d, {"w": 0, "f": 0, "hf": 0, "hr": 0})
	row["w"] = int(row["w"]) + want
	row["f"] = int(row["f"]) + got
	sv[d] = row
	s["r8_svc"] = sv


## At TRADE (EconRules.monthly): last month's purchases become the SERVICES row of the month's signals.
static func carry(world: WorldState, m: Dictionary) -> void:
	var s := EconUtil.st(world)
	if not fill_on(world) or not s.has("r8_svc"):
		return
	m["goods"]["SERVICES"] = s["r8_svc"]
	s.erase("r8_svc")


# ------------------------------------------------------------------ rules 1/2 (EconHouseholds._buy_services)

## The district's new service price from this month's sales: want (mu wanted by its households), unfilled (served by
## nobody), spare (its hubs' unsold capacity), offered (its hubs' capacity on offer).
static func price(p: float, want: int, unfilled: int, spare: int, offered: int) -> float:
	var base := float(maxi(maxi(want, offered), S))
	return p * (1.0 + EconData.ALPHA * float(unfilled - spare) / base)


# ------------------------------------------------------------------ rules 3/4 (FirmAI._set_target)

## The hub's target (0..1).
static func target(world: WorldState, f: Dictionary, cap: float) -> float:
	var pl := EconRules.plant(world, String(f["id"]))
	if pl.is_empty():
		return float(f["T"]) / 1000.0  # opened this month: no reading yet
	var s := EconUtil.st(world)
	var price := float(s["svc_price"].get(f["district"], 0))
	if price < float(int(pl["cost_var"])):
		return 0.0
	var extra := float(int(pl["reach"])) * cap / maxf(1.0, _cap_near(world, String(f["district"])))
	var t := clampf((float(int(f.get("svc_sold", 0))) + extra) / maxf(1.0, cap), 0.0, 1.0)
	if price >= float(int(pl["cost_full"])):
		# the price pays its full cost: it offers more hours (unsold ones lower the price, rule 2), until it doesn't
		t = maxf(t, minf(1.0, float(f["T"]) / 1000.0 + float(_p("offer_step_pm")) / 1000.0))
	return t


## Capacity (mu) of the open hubs a customer of district d's neighbourhood can buy from: d and its neighbours.
static func _cap_near(world: WorldState, d: String) -> float:
	var c := 0.0
	var near := [d] + EconUtil.neighbours(d)
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] == HUB and not f["mothball"] and String(f["district"]) in near:
			c += _cap(f)
	return c


static func _cap(f: Dictionary) -> float:
	return float(EconData.RECIPES[HUB]["out"][1]) * float(S) * EconUtil.fscale(f)


## Monthly, every hub (FirmAI._set_target): the window (WIN_M bits) rules 5 and 6 read. "add" = sold out with
## customers waiting within reach and its crew complete (the hall is short, not the hands: a hub short of staff is
## helped by hiring, not by building); "cut" = unsold hours or no output, and the customers waiting near it fit in
## the other open hubs' unused capacity (nobody waits for this one).
static func note(world: WorldState, f: Dictionary) -> void:
	var pl := EconRules.plant(world, String(f["id"]))
	var out := int(f.get("out_last", 0))
	var spare := int(f.get("svc_spare", 0))
	var reach := int(pl.get("reach", 0))
	var sold_out := out > 0 and spare * 1000 <= out * _p("sold_out_pm")
	var add := 1 if (not pl.is_empty() and sold_out and reach > 0 and _crew_full(f)) else 0
	var idle := spare > 0 or out == 0
	var cut := 1 if (not pl.is_empty() and idle and reach <= _unused_near(world, String(f["district"]), String(f["id"]))) else 0
	var mask := (1 << _p("win_m")) - 1
	f["r8s_add_bits"] = ((int(f.get("r8s_add_bits", 0)) << 1) | add) & mask
	f["r8s_cut_bits"] = ((int(f.get("r8s_cut_bits", 0)) << 1) | cut) & mask


static func _bits(x: int) -> int:
	var n := 0
	while x > 0:
		n += x & 1
		x >>= 1
	return n


# ------------------------------------------------------------------ rule 6 (FirmAI._set_target, after the target)

## Mothball an idle hub nobody waits for, or reopen a mothballed one customers wait for. Returns true when it acted.
static func capacity_down_or_reopen(world: WorldState, f: Dictionary) -> bool:
	var o: Dictionary = world.table("org").get(f["org"], {})
	if o.is_empty():
		return false
	if not f["mothball"]:
		if _bits(int(f.get("r8s_cut_bits", 0))) < _p("cut_m") or EconPublicCo.result12(o) >= 0:
			return false
		var jobs := 0
		var req := EconLabor.required(f)
		for t in req:
			jobs += int(req[t])
		f["mothball"] = true
		f["r8s_cut_bits"] = 0
		f["r8s_add_bits"] = 0
		f["r8s_open_m"] = 0
		EconFacts.emit(world, "ECON_FACILITY_MOTHBALLED", f["district"], [["COMPANY", f["org"]]],
			EconFacts.company_blame(world, f["org"], 0.7), {"JOBS": -10}, 35, "PUBLIC", {"facility": f["id"],
			"type": f["type"], "jobs": jobs / S, "reason": "no_customers"}, {"districts": [f["district"]]})
		return true
	if not (o["status"] in ["ACTIVE", "DISTRESSED", "ADMINISTRATION"]) or bool(f.get("closed_unsafe", false)) \
			or bool(f.get("law_closed", false)) or bool(f.get("abandoned", false)) or f.has("converting"):
		f["r8s_open_m"] = 0
		return false
	var d := String(f["district"])
	f["r8s_open_m"] = int(f.get("r8s_open_m", 0)) + 1 if reach_d(world, d) > _unused_near(world, d, "") else 0
	if int(f["r8s_open_m"]) < _p("reopen_m"):
		return false
	f["mothball"] = false
	f["low_util_m"] = 0
	f["r8s_open_m"] = 0
	f["r8s_cut_bits"] = 0
	f["T"] = 1000
	EconFacts.emit(world, "ECON_FACILITY_REOPENED", f["district"], [["COMPANY", f["org"]]],
		EconFacts.company_blame(world, f["org"], 0.7), {"JOBS": 10}, 30, "PUBLIC", {"facility": f["id"], "reason": "customers"})
	return true


## Unfilled service demand (mu, last month's signal) a hub in district d can reach: d and its neighbours.
static func reach_d(world: WorldState, d: String) -> int:
	var row: Dictionary = EconUtil.peek_st(world).get("r8", {}).get("goods", {}).get("SERVICES", {})
	var t := 0
	for d2 in EconUtil.sorted_keys(row):
		t += int(row[d2]["u"]) * EconRules.travel_pm(world, String(d2), d) / 1000
	return t


## Capacity (mu) the open hubs in d and its neighbours did not sell this month (nameplate less sales: a hub at
## zero output has all of it unused), except hub `skip`.
static func _unused_near(world: WorldState, d: String, skip: String) -> int:
	var near := [d] + EconUtil.neighbours(d)
	var t := 0
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] == HUB and not f["mothball"] and String(f["district"]) in near and fid != skip:
			t += maxi(0, int(_cap(f)) - int(f.get("svc_sold", 0)))
	return t


## Every tier of the hub's crew at what its target asks for.
static func _crew_full(f: Dictionary) -> bool:
	var req := EconLabor.required(f)
	for t in req:
		if EconLabor.tier_total(f["staff"], t) < int(req[t]):
			return false
	return true


# ------------------------------------------------------------------ rule 5 (quarterly, FirmAI.run)

static func capacity_up(world: WorldState) -> void:
	if not cap_on(world):
		return
	var s := EconUtil.st(world)
	var acts: Array = s.get("r8s_actions", [])
	var done := {}
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		var d := String(f["district"])
		if f["type"] != HUB or f["mothball"] or f.has("converting") or done.has(d):
			continue
		if _bits(int(f.get("r8s_add_bits", 0))) < _p("add_m"):
			continue
		var o: Dictionary = world.table("org").get(f["org"], {})
		if o.is_empty() or o["status"] != "ACTIVE" or o["is_contractor"] or not (o["type"] in ["PRIVATE", "COOPERATIVE", "PUBLIC_ENTERPRISE"]):
			continue
		var pl := EconRules.plant(world, fid)
		if pl.is_empty() or float(s["svc_price"].get(d, 0)) < float(int(pl["cost_full"])) or EconPublicCo.result12(o) <= 0:
			continue
		if EconConstruction.has_open_project(world, f["org"], HUB) or EconRulesMat._expand_pending(world, fid):
			continue
		var grow := int(f.get("scale", 1000)) < EconRulesMat.MAX_SCALE
		var cost := EconConstruction.estimate(HUB) / 4 if grow else EconConstruction.estimate(HUB)
		if not grow and not LawBridge.allowed(world, f["org"], "BUILD_FACILITY", {"facility_type": HUB, "district": d,
				"owner_kind": "COMPANY", "value_wref": cost / maxi(1, int(world.values.get("ECON_W_REF", 1200 * S)))}):
			continue
		if not EconRulesMat._finance(world, String(f["org"]), cost, o["type"] == "PUBLIC_ENTERPRISE"):
			continue
		if grow:
			EconConstruction.create_expansion(world, fid, f["org"])
			o["last_expand"] = world.month
		else:
			EconConstruction.create(world, HUB, d, f["org"], f["org"], "")
			o["last_invest"] = world.month
		acts.append([world.month, fid, "expand" if grow else "new"])
		done[d] = true
		f["r8s_add_bits"] = 0
		EconFacts.emit(world, "COMP_INVESTMENT", d, [["COMPANY", f["org"]]], [["COMPANY", f["org"], 1.0]], {"JOBS": 2}, 15,
			"PUBLIC", {"type": HUB, "reason": "customers", "good": "SERVICES"})
	s["r8s_actions"] = acts


# ------------------------------------------------------------------ rules 7/8 (FirmAI._entry, FirmAI._small_business)

const MICRO_STAKE := 20000  # credits a household puts into a micro co-op (FirmAI._small_business's sum)
const MICRO_SCALE := 250


## A micro co-op's founder: in the district where a quarter hub pays best, the household pool (not the rich bands,
## who found full hubs) holding the stake, with the most idle hands to staff it. "" when no district pays (rule 8).
static func micro_founder(world: WorldState) -> String:
	var d := entry_district(world, MICRO_SCALE)
	if d == "":
		return ""
	var best := ""
	var best_u := -1
	for gid in EconUtil.sorted_keys(world.table("hh")):
		var g: Dictionary = world.table("hh")[gid]
		if String(g["district"]) != d or g["band"] in ["I4", "I5"] or world.ledger.balance(EconUtil.hh_acct(gid)) < MICRO_STAKE * S:
			continue
		var u := maxi(0, int(g["lf"]) - EconLabor.employed(g))
		if u > best_u:
			best_u = u
			best = gid
	return best


## The district where a new hub of `scale_pm` (1000 = a full hub) pays best, or "" when none does (rule 8).
static func entry_district(world: WorldState, scale_pm: int) -> String:
	var best := ""
	var best_p := 0
	for d in EconUtil.sorted_keys(EconData.DISTRICTS):
		var fc := forecast(world, String(d), scale_pm)
		if int(fc["profit"]) > best_p and (fc["reasons"] as Array).is_empty():
			best_p = int(fc["profit"])
			best = String(d)
	return best


## A new hub's first year in district d (mcr): {volume (mu a month), revenue, costs, profit, reasons}.
## volume = the unfilled demand it could reach, net of what the hubs near it could still serve (spare hours, hubs
## being built or expanded, mothballed hubs that would reopen), at most its capacity.
static func forecast(world: WorldState, d: String, scale_pm: int) -> Dictionary:
	var s := EconUtil.peek_st(world)
	var r: Dictionary = EconData.RECIPES[HUB]
	var cap := float(r["out"][1]) * float(S) * float(scale_pm) / 1000.0
	var reasons: Array = []
	var gap := reach_d(world, d) - _unused_near(world, d, "") - _coming_near(world, d)
	if gap <= 0:
		reasons.append("no_customers")
	if _incumbents_losing(world, d):
		reasons.append("incumbents_losing")
	var volume := clampf(float(gap), 0.0, cap) * _crew_fill(world, scale_pm)  # it serves what a crew it can hire can serve
	var price := float(s.get("svc_price", {}).get(d, 0))
	var revenue := volume / float(S) * price * 12.0
	var crew := 0.0
	for t in r["labor"]:
		crew += float(r["labor"][t]) * float(int(s["wage"].get(t, 0))) * float(scale_pm) / 1000.0
	var per_unit := 0.0
	for g in r["in"]:
		if g in EconData.MARKET_GOODS:
			per_unit += float(r["in"][g]) * float(int(s["prices"][g]))
		elif g == "ENERGY":
			per_unit += float(r["in"][g]) * float(EconUtil.lever(world, "ECON_UTILITY_TARIFF_ENERGY", 40)) * S
		elif g == "WATER":
			per_unit += float(r["in"][g]) * float(EconUtil.lever(world, "ECON_UTILITY_TARIFF_WATER", 20)) * S
	per_unit /= float(r["out"][1])
	var capital := float(EconConstruction.estimate(HUB)) * float(scale_pm) / 1000.0 / float(EconData.DEPRECIATION_MONTHS)
	var costs := crew * 12.0 + per_unit * volume / float(S) * 12.0 + capital * 12.0
	var profit := int(revenue - costs)
	if profit <= 0 and reasons.is_empty():
		reasons.append("no_profit")
	return {"volume": int(volume), "revenue": int(revenue), "costs": int(costs), "profit": profit, "reasons": reasons}


## The share (0..1) of a new hub's crew the unemployed can fill, worst tier (a smaller hub needs a smaller crew).
static func _crew_fill(world: WorldState, scale_pm: int) -> float:
	var fill := 1.0
	var lab: Dictionary = EconData.RECIPES[HUB]["labor"]
	for t in lab:
		var need := float(lab[t]) * float(scale_pm) / 1000.0
		if need > 0.0:
			fill = minf(fill, float(PopStore.count(world, {"status": "UNEMPLOYED"}, "skill:" + t)) / need)
	return clampf(fill, 0.0, 1.0)


## Capacity (mu) near d that will serve before a newcomer: hubs being built or expanded, mothballed hubs whose
## owner could reopen them.
static func _coming_near(world: WorldState, d: String) -> int:
	var near := [d] + EconUtil.neighbours(d)
	var full := float(EconData.RECIPES[HUB]["out"][1]) * float(S)
	var t := 0.0
	for pid in EconUtil.sorted_keys(world.table("project")):
		var p: Dictionary = world.table("project")[pid]
		if not (p["status"] in ["TENDER", "TENDERABLE", "ACTIVE"]) or not (String(p["district"]) in near):
			continue
		if p["type"] == HUB:
			t += full
		elif p["type"] == "EXPAND" and world.table("facility").has(String(p.get("target", ""))) \
				and world.table("facility")[p["target"]]["type"] == HUB:
			t += full / 4.0
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] != HUB or not f["mothball"] or not (String(f["district"]) in near) or f.has("converting"):
			continue
		var o: Dictionary = world.table("org").get(f["org"], {})
		if not o.is_empty() and o["status"] in ["ACTIVE", "DISTRESSED", "ADMINISTRATION"] and not bool(f.get("closed_unsafe", false)) \
				and not bool(f.get("law_closed", false)) and not bool(f.get("abandoned", false)):
			t += _cap(f)
	return int(t)


## Rule 8: the incumbents holding more than half of the open hub capacity near d lost money over 12 months.
static func _incumbents_losing(world: WorldState, d: String) -> bool:
	var near := [d] + EconUtil.neighbours(d)
	var all_c := 0
	var losing := 0
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] != HUB or f["mothball"] or not (String(f["district"]) in near):
			continue
		var o: Dictionary = world.table("org").get(f["org"], {})
		var c := int(f.get("scale", 1000))
		all_c += c
		if not o.is_empty() and EconPublicCo.result12(o) < 0:
			losing += c
	return all_c > 0 and losing * 2 > all_c

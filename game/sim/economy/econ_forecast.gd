class_name EconForecast
extends RefCounted
## E170 founders' market research (planning/eight-rules.md rules 7/8; Bob). STUB with the final signature: the
## deterministic part of the first-year forecast only. The error from the founder's management, risk and research,
## the failure memory and the buildability leg (Otto's EconConstruction.quoted_wait) come with E170 proper. Nothing
## calls this yet, so base is unchanged.
##
## first_year(world, ftype, district, founder := {}, purchase := {}) -> {volume (mu a month), revenue, costs, profit
## (mcr a year), reasons [why it would decline], error_applied (‰, 0 in the stub)}
##   founder: {mgmt, risk} (unused in the stub)
##   purchase: {fid, price (mcr)} to forecast buying an existing plant instead of a build (its real output and crew)

const S := EconUtil.S
const WIN_SHARE := 0.5  # of a filled market a new plant can take at the going price (incumbents keep customers)
const LOAN_SHARE := 0.6
const LOAN_TERM_M := 60


static func first_year(world: WorldState, ftype: String, district: String, founder: Dictionary = {}, purchase: Dictionary = {}) -> Dictionary:
	var s := EconUtil.peek_st(world)
	var r: Dictionary = EconData.RECIPES.get(ftype, {})
	if r.is_empty():
		return {"volume": 0, "revenue": 0, "costs": 0, "profit": 0, "reasons": ["unknown_type"], "error_applied": 0}
	var good := String(r["out"][0])
	var reasons: Array = []
	var cap := float(r["out"][1]) * float(S)
	var buying: bool = purchase.has("fid") and world.peek("facility").has(purchase["fid"])
	if buying:
		var pf: Dictionary = world.peek("facility")[purchase["fid"]]
		cap *= EconUtil.fscale(pf)
	# demand it could reach: unfilled orders (R8 signals when on, else the colony's unfilled last month), net of what
	# incumbents could still make, plus a share of the filled market
	var unfilled := 0
	if s.has("r8"):
		unfilled = EconRules.reachable_unfilled(world, good, district)
		var xb: Dictionary = s.get("r8", {}).get("export", {}).get(good, {})
		if int(xb.get("per_m", 0)) > 0 and int(xb.get("net", 0)) > 0:
			unfilled += int(xb["per_m"])  # EXP: the next ship's free hold is a customer too (design-exports.md)
	else:
		unfilled = int(s.get("unmet_last", {}).get(good, 0))
	var spare := 0
	for fid in world.peek("facility"):
		var f: Dictionary = world.peek("facility")[fid]
		if f["type"] == ftype and not f["mothball"] and not (buying and fid == purchase["fid"]):
			spare += maxi(0, int(float(r["out"][1]) * float(S) * EconUtil.fscale(f)) - int(f.get("out_last", 0)))
	var ms: Dictionary = s.get("market_stats", {}).get(good, {})
	var filled := float(int(ms.get("filled", 0)))
	var supply := float(int(ms.get("S", 0)))
	var win := WIN_SHARE * filled * cap / maxf(1.0, supply + cap)
	var volume := float(maxi(0, unfilled - spare)) + win
	if buying:
		volume = maxf(volume, float(int(world.peek("facility")[purchase["fid"]].get("out_last", 0))))
	if volume <= 0.0:
		reasons.append("no_customers")
	elif unfilled > 0 and unfilled <= spare:
		reasons.append("competitors")
	# can it produce that: inputs' fill and workers
	var fill := 1.0
	for g in r["in"]:
		if g in EconData.MARKET_GOODS:
			fill = minf(fill, float(int(s.get("fill_last", {}).get(g, 1000))) / 1000.0)
	if fill < 0.9:
		reasons.append("inputs")
	var lab := 1.0
	for t in EconEssentials.labour_fill_by_tier(world, ftype).values():
		lab = minf(lab, float(t))
	if lab < 0.9:
		reasons.append("workers")
	volume = minf(volume, cap) * minf(fill, lab)
	var price := float(EconTrade.plan_price(world, good))  # the local price, or the net home price when the ship pays more (EXP)
	var revenue := volume / float(S) * price * 12.0
	# costs: a full crew at today's wages, inputs and utilities for that volume, and loan service on the capital
	var crew := 0.0
	for t in r["labor"]:
		crew += float(r["labor"][t]) * float(int(s.get("wage", {}).get(t, 0)))
	var per_unit := 0.0
	for g in r["in"]:
		if g in EconData.MARKET_GOODS:
			per_unit += float(r["in"][g]) * float(int(s["prices"][g]))
		elif g == "ENERGY":
			per_unit += float(r["in"][g]) * float(EconUtil.lever(world, "ECON_UTILITY_TARIFF_ENERGY", 40)) * S
		elif g == "WATER":
			per_unit += float(r["in"][g]) * float(EconUtil.lever(world, "ECON_UTILITY_TARIFF_WATER", 20)) * S
	per_unit /= float(r["out"][1])
	var capital := float(int(purchase.get("price", 0))) if buying else float(EconConstruction.estimate(ftype))
	var loan := capital * LOAN_SHARE
	var rate := EconData.BANK_FIRM_BASE_PM  # already a monthly rate
	var service := loan / float(LOAN_TERM_M) + loan * rate
	var costs := crew * 12.0 + per_unit * volume / float(S) * 12.0 + float(r["upkeep"]) * float(int(s["prices"].get("MATERIAL", 0))) * 12.0 + service * 12.0
	var profit := revenue - costs
	if volume > 0.0 and profit < 0.0:
		reasons.append("costs")
	return {"volume": int(volume), "revenue": int(revenue), "costs": int(costs), "profit": int(profit), "reasons": reasons, "error_applied": 0}

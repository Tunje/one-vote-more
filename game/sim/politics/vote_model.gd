class_name VoteModel
extends RefCounted
## Pure functions: ideological distance, cell vote probabilities (multinomial logit), turnout,
## and Sainte-Laguë seat allocation. No state; everything is passed in.


## Weighted mean absolute distance on 7 axes, in POINTS (0..200). Inputs are milli-point vectors.
static func distance(a: Dictionary, b: Dictionary, weights: Dictionary = {}) -> float:
	var num := 0.0
	var den := 0.0
	for ax in PolDefs.AXES:
		var w: float = weights.get(ax, 1.0)
		num += w * absf(float(a[ax]) - float(b[ax]))
		den += w
	return num / den / 1000.0 if den > 0.0 else 0.0


## Axis weights for a cell: 1 + sum of salience of concerns linked to the axis.
static func axis_weights(salience: Dictionary) -> Dictionary:
	var w := {}
	for ax in PolDefs.AXES:
		w[ax] = 1.0
	for c in salience:
		for ax in PolDefs.CONCERN_AXES[c]:
			w[ax] += float(salience[c]) / 1000.0 * 4.0
	return w


## Utility of `party` for `cell`.
##  ctx: {approval (0..100 float), gov_share {party_id: 0..1}, prev_share {party_id: 0..1}, shock {party_id: float}, campaign {party_id: 0..1}}
static func utility(cell: Dictionary, party: Dictionary, ctx: Dictionary) -> float:
	var sal: Dictionary = cell["salience"]
	var u := -PolDefs.BETA_DISTANCE * distance(cell["ideology"], party["positions"], axis_weights(sal))
	var pid: String = party["id"]
	# retrospective performance: credit or blame shared by government parties
	var gs: float = ctx.get("gov_share", {}).get(pid, 0.0)
	if gs > 0.0:
		# Judged against expectations (mostly) and against an absolute bar (a little).
		var appr := float(cell["approval"]) / 1000.0
		var expect := float(cell.get("expect", 50000)) / 1000.0
		u += PolDefs.BETA_PERFORMANCE * gs * ((appr - expect) / 20.0 + (appr - 50.0) / 100.0)
	# Cost of ruling: every year in office wears a governing party down (capped).
	var tenure_m: int = int(ctx.get("tenure", {}).get(pid, 0))
	if tenure_m > 0:
		u -= minf(PolDefs.COST_OF_RULING_CAP, PolDefs.COST_OF_RULING_PER_YEAR * float(tenure_m) / 12.0)
	# issue ownership: parties "own" concerns; matters more when the concern is unmet
	var own: Dictionary = party.get("ownership", {})
	var o := 0.0
	for c in own:
		var unmet := 1.0 - float(cell["sat"].get(c, 50000)) / 100000.0
		o += float(sal.get(c, 0)) / 1000.0 * float(own[c]) / 100.0 * unmet
	u += PolDefs.BETA_OWNERSHIP * o * 3.0
	# party loyalty / habit
	var prev: float = float(ctx.get("prev_share", {}).get(pid, 0)) / 100000.0  # stored as int per-100000
	if prev > 0.0:
		u += PolDefs.BETA_LOYALTY * log(0.15 + prev)
	# promise-keeping record (0..100, 50 neutral)
	u += 0.5 * (float(party.get("credibility", 50)) - 50.0) / 50.0
	u += 0.6 * float(ctx.get("campaign", {}).get(pid, 0.0))
	u += float(ctx.get("endorse", {}).get(pid, 0.0))  # interest-group endorsement (M9)
	# leader appeal (M9)
	u += PolDefs.BETA_LEADER * (float(PartyLife.leader_popularity(party)) - 50.0) / 50.0
	u += float(ctx.get("shock", {}).get(pid, 0.0))
	return u


## Softmax over parties. Returns {party_id: probability}.
static func probabilities(cell: Dictionary, parties: Array, ctx: Dictionary) -> Dictionary:
	var us := {}
	var mx := -INF
	for p in parties:
		var u := utility(cell, p, ctx)
		us[p["id"]] = u
		mx = maxf(mx, u)
	var total := 0.0
	for k in us:
		us[k] = exp(us[k] - mx)
		total += us[k]
	for k in us:
		us[k] /= total
	return us


## Turnout falls when nobody is close to you, or when you are fed up with the government.
static func turnout(cell: Dictionary, parties: Array) -> float:
	var best := INF
	for p in parties:
		best = minf(best, distance(cell["ideology"], p["positions"]))
	var t := PolDefs.BASE_TURNOUT - 0.004 * maxf(0.0, best - 25.0)
	var appr := float(cell["approval"]) / 1000.0
	if appr < 30.0:
		t -= (30.0 - appr) * 0.003
	return clampf(t, 0.4, 0.95)


## Modified Sainte-Laguë (first divisor 1.2) with a vote threshold. votes: {party_id: int}.
## Deterministic tie-break: more votes, then party id.
static func allocate_seats(votes: Dictionary, seats: int = PolDefs.SEATS, threshold_permille: int = PolDefs.THRESHOLD_PERMILLE) -> Dictionary:
	var total := 0
	for p in votes:
		total += votes[p]
	var eligible: Array = []
	for p in votes:
		if total > 0 and votes[p] * 1000 >= threshold_permille * total:
			eligible.append(p)
	if eligible.is_empty():  # degenerate: everyone below threshold
		eligible = votes.keys()
	eligible.sort()
	var result := {}
	for p in votes:
		result[p] = 0
	for _i in seats:
		var best := ""
		var best_q := -1.0
		for p in eligible:
			var s: int = result[p]
			var div := PolDefs.FIRST_DIVISOR if s == 0 else float(2 * s + 1)
			var q := float(votes[p]) / div
			if q > best_q or (q == best_q and votes[p] > votes.get(best, -1)):
				best_q = q
				best = p
		result[best] += 1
	return result

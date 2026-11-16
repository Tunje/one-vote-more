class_name EconBuilders
extends RefCounted
## R8 step 4 (Otto, planning/eight-rules.md §2 "Builders" and §3c a; approved by Wilma 2026-11-15): builders under the
## eight rules. OPT-IN: R8 + R8_BUILDERS (EconRules.sector_on(world, "BUILDERS")). Off → nothing here runs and the base
## is bit-identical (the hooks in EconConstruction / FirmAI test on() first).
##
## Rules (second version, the user's order 2026-11-16: all eight, each on the builder's own market, no floors, caps or
## locks of our own; planning/eight-rules.md). The builder's own market: its book (signed jobs and their schedule), the
## quotes it won and the ones its clients refused (and why), what its jobs in hand earn at today's costs (job_margin),
## and the material it actually got for its orders (fill_pm).
##   1 raise the margin (quarterly, STEP_PM): it wins more than WIN_HI_PM of its bids, or its clients refused its quotes
##       for the wait (more work than crews: demand above capacity), or its jobs in hand lose at today's costs. Never while
##       a client refused one of its quotes on price in the last REFUSED_BLOCK_M months.
##   2 lower the margin: a client refused its quote on price, or it wins under WIN_LO_PM of its bids while no client
##       turned it down for the wait. A bid is never below the builder's own cost estimate (margin ≥ 0); no ceiling.
##   The quote a client may refuse: a bid is a price and a start date. The client takes the best-ranked bid it accepts:
##       - a private owner refuses a price above its own estimate of the job at this month's wages and input prices ×
##         (1 + tolerance from its CEO's risk), or a start later than its horizon;
##       - the government refuses a price above its own estimate × (1 + GOV_TOL), an overrun on its reservation beyond
##         the line's headroom plus GOV_LINE_SLACK of the line's annual budget, or a start later than GOV_WAIT_M months (fact ECON_PUBLIC_QUOTE_REFUSED: project, price, estimate, line, headroom).
##       After a refusal the tender opens again after QUOTE_REOPEN_M months and the plan waits; a refusal never cancels a
##       plan (only the owner's own patience rule, E165, may end it). Clients read only that month's estimates and budget.
##       The start date: its book ÷ (the crew it can field × the material it got over 12 months), field_capacity and
##       fill12_pm: its crew now plus the workers the labour market has, not today's headcount (crews grow to the book).
##   3 produce more / 4 produce less: the work done each month is its crews' output on started, paid-up jobs, as far as
##       the material it got allows (EconConstruction._progress_fill; E76 stops work the owner does not pay for).
##   5 add crew: crews to the work due now (started jobs at the pace their dates need, and queued jobs starting within
##       CREW_HORIZON_M months, the time to hire); when clients refused its quotes for the wait and its jobs in hand pay at
##       today's costs, crews to clear the whole book within the wait they refused (book ÷ that wait).
##   6 shed crew: to the work its material supports: with fill_pm under 1000 the crew is the work due × fill_pm; and to the
##       work due when the book is short. No founding-crew multiple, no monthly growth cap, no kept share, no core crew:
##       hiring is limited by the labour market, shedding by the work.
##   7/8 a new builder or none (FirmAI._builder_entry, quarterly; the user 2026-11-16: "instead of reading the leftovers,
##       they read an average of all available jobs"): average_share(). All the building work on offer and in the books
##       (open and reopening tenders, which include the plans' buildings, and the work left on jobs under way) is shared
##       among the live builders and the newcomer by the crew each can field (field_capacity); the newcomer's share is
##       the work a builder of its size gets on average. It starts when that share pays for its crew at today's costs:
##       what the work pays (the price left on jobs under way, the owner's estimate on open tenders) less its material at
##       today's prices, on the part its material lets it do (the builders' fill over 12 months), against the crew's
##       wages for all of it. No "work beyond the incumbents' crews", no material gate, no count of waiting tenders.
##   Public builders (§3c a): they bid on public tenders from the first round, at the same margin rule unless the lever
##       ECON_PUBLIC_BUILDER_AT_COST = 1 (then at cost for public work). builder_needs() is gov_builder's query;
##       found_public_builder() and enlarge_public_builder() are the government's two actions (Wilma wires the choice).
##
## State: org["r8b"] = {margin ‰, log {"month": [bids, won]} over 12 months, refused_m (price), wait_m and wait_w (the
## month and the shortest wait of a quote refused for its wait), fill {good: [wanted, got]} of this month's orders,
## fill_pm (last month's material fill, ‰), floor (crew ordered by the government)}; project["reopen_m"], ["refusals"];
## st["r8b_stats"] counters for the reports.

const S := EconUtil.S
const Desk := preload("res://sim/office/decision_desk.gd")   # who decides (flag DELEGATION): counts decisions
const STEP_PM := 20
const WIN_HI_PM := 600
const WIN_LO_PM := 200
const MIN_BIDS := 3
const REFUSED_BLOCK_M := 3
const WAIT_MEMORY_M := 12  # a quote refused for the wait is the builder's signal for this long
const CREW_HORIZON_M := 3  # the time to hire a crew: queued jobs starting within it are crewed now
const QUOTE_REOPEN_M := 3
const GOV_WAIT_M := 36
const PRIV_WAIT_BASE_M := 12
const PRIV_WAIT_RISK_M := 24
const TOL_BASE := 0.25
const TOL_RISK := 0.5
const GOV_TOL := 0.3  # the government refuses a price above its own estimate × 1.3
const GOV_LINE_SLACK := 0.25  # ... or an overrun beyond the line's headroom plus a quarter of its annual budget
const LEVER_AT_COST := "ECON_PUBLIC_BUILDER_AT_COST"
## The user 2026-11-16: "They should not need 90% of supplies up front they should need 3 months up front and add 1
## month of additional supplies every month". A job begins work once STOCK_M months of its material and components (at
## its pace) are in hand; the builder orders them the month before the start and then keeps STOCK_M months ahead, so
## each month it buys about one more month. EconConstruction.contractor_plans and _progress_fill.
const STOCK_M := 3


static func on(world: WorldState) -> bool:
	return EconRules.sector_on(world, "BUILDERS")


static func _r(o: Dictionary) -> Dictionary:
	if not o.has("r8b"):
		o["r8b"] = {"margin": int(1000.0 * (0.12 - 0.08 * float(o["ceo"]["risk"]) / 100.0)), "log": {}, "refused_m": -999, "floor": 0}
	return o["r8b"]


static func _stat(world: WorldState, key: String, n: int = 1) -> void:
	var s := EconUtil.st(world)
	var r: Dictionary = s.get("r8b_stats", {})
	r[key] = int(r.get(key, 0)) + n
	s["r8b_stats"] = r


# ------------------------------------------------------------------ bids and wins (rules 1/2 inputs)

static func note_bid(world: WorldState, o: Dictionary) -> void:
	_log(world, o, 0)


static func note_win(world: WorldState, o: Dictionary) -> void:
	_log(world, o, 1)


static func _log(world: WorldState, o: Dictionary, i: int) -> void:
	var lg: Dictionary = _r(o)["log"]
	var k := str(world.month)
	var row: Array = lg.get(k, [0, 0])
	row[i] = int(row[i]) + 1
	lg[k] = row
	for m in lg.keys():
		if int(m) <= world.month - 12:
			lg.erase(m)


## [bids, won] over the last 12 months (pure).
static func bid_counts(world: WorldState, o: Dictionary) -> Array:
	var b := 0
	var w := 0
	for m in o.get("r8b", {}).get("log", {}):
		if int(m) > world.month - 12:
			b += int(o["r8b"]["log"][m][0])
			w += int(o["r8b"]["log"][m][1])
	return [b, w]


## The margin a builder bids with (fraction).
static func margin(world: WorldState, o: Dictionary, p: Dictionary) -> float:
	if o["type"] == "PUBLIC_ENTERPRISE" and p["owner"] == "gov" and int(EconUtil.lever(world, LEVER_AT_COST, 0)) == 1:
		return 0.0
	return float(_r(o)["margin"]) / 1000.0


## Under R8 a public builder bids on public tenders from the first round (it competes; §3c a). Private work stays as
## before (last resort, E86).
static func public_may_bid(world: WorldState, p: Dictionary) -> bool:
	return p["owner"] == "gov"


## The work a builder can field in a month (wu, S-scaled; pure): its crew now plus the workers it can hire this month,
## the unemployed in its crew's mix (the scarcest skill sets the number). Rule 5: crews grow to the book, limited by the
## labour market, not by today's crew; a quote's start and a job's duration count this (Wilma's 2026-11-16 recorder:
## quotes counted today's crew, sized to the work due now, so a builder with a book quoted years in month 2).
static func field_capacity(world: WorldState, oid: String) -> int:
	var o: Dictionary = world.peek("org")[oid]
	var n := 0
	for t in EconData.BUILDER_CREW:
		n += int(EconData.BUILDER_CREW[t])
	var free := INF
	for t in EconData.BUILDER_CREW:
		var share := float(EconData.BUILDER_CREW[t]) / float(maxi(1, n))
		if share > 0.0:
			free = minf(free, float(PopStore.count(world, {"status": "UNEMPLOYED"}, "skill:" + t)) / share)
	if free == INF:
		free = 0.0
	var per := 0.9 + 0.002 * float(o["ceo"]["mgmt"])
	return EconConstruction.capacity(world, oid) + int(free * per * float(S))


# ------------------------------------------------------------------ the material it actually gets (rules 3/4, 6, 8, quotes)

## EconMarket._fill hook: a builder's order of MATERIAL / COMPONENT was filled `got` of `want` this month.
static func note_fill(world: WorldState, oid: String, good: String, want: int, got: int) -> void:
	var o: Dictionary = world.table("org").get(oid, {})
	if o.is_empty() or not bool(o.get("is_contractor", false)):
		return
	var r := _r(o)
	var f: Dictionary = r.get("fill", {})
	if int(f.get("m", -1)) != world.month:
		if f.has("m"):
			# the months before: the record a quote reads (fill12_pm)
			var h: Dictionary = r.get("fill_h", {})
			h[str(int(f["m"]))] = f
			for k in h.keys():
				if int(k) <= world.month - 12:
					h.erase(k)
			r["fill_h"] = h
		f = {"m": world.month}
	var row: Array = f.get(good, [0, 0])
	f[good] = [int(row[0]) + want, int(row[1]) + got]
	r["fill"] = f


## Per mille of the MATERIAL it ordered that it got in the last month it ordered any (COMPONENT counted as in
## _progress_fill: missing components cut work to half). 1000 when it ordered none. Pure.
static func fill_pm(o: Dictionary) -> int:
	var f: Dictionary = o.get("r8b", {}).get("fill", {})
	var m: Array = f.get("MATERIAL", [0, 0])
	var c: Array = f.get("COMPONENT", [0, 0])
	var fm := 1000 if int(m[0]) <= 0 else int(m[1]) * 1000 / int(m[0])
	var fc := 1000 if int(c[0]) <= 0 else int(c[1]) * 1000 / int(c[0])
	return clampi(mini(fm, 500 + fc / 2), 0, 1000)


## Per mille of the material it ordered over its last 12 months that it got (components as in fill_pm). What a quote's
## start date counts: a quote is about the months ahead, and one month's outage is not a forecast of them (Wilma's
## recorder 2026-11-16: in a two-month material outage the month's fill of 0 made every builder quote 100 years). Pure.
static func fill12_pm(o: Dictionary) -> int:
	var r: Dictionary = o.get("r8b", {})
	var rows: Array = (r.get("fill_h", {}) as Dictionary).values()
	if not (r.get("fill", {}) as Dictionary).is_empty():
		rows.append(r["fill"])
	var mw := 0
	var mg := 0
	var cw := 0
	var cg := 0
	for f in rows:
		var m: Array = f.get("MATERIAL", [0, 0])
		var c: Array = f.get("COMPONENT", [0, 0])
		mw += int(m[0])
		mg += int(m[1])
		cw += int(c[0])
		cg += int(c[1])
	var fm := 1000 if mw <= 0 else int(float(mg) * 1000.0 / float(mw))
	var fc := 1000 if cw <= 0 else int(float(cg) * 1000.0 / float(cw))
	return clampi(mini(fm, 500 + fc / 2), 0, 1000)


## What the work left on the builder's jobs earns at today's costs (mcr): the price (less the late penalty owed today) ×
## the share of work left - the crew's wages and overhead on that work (the bid's own rate) - the material and components
## still needed at their award prices (E76 escalation pays the change since award, up to its cap). The 10% advance and
## the retention only move cash in time, so they are not counted against the work. Pure.
static func job_margin(world: WorldState, oid: String) -> int:
	var o: Dictionary = world.peek("org").get(oid, {})
	if o.is_empty():
		return 0
	var wage_wu := EconConstruction._crew_wage(world, oid) * 1.08
	var s := EconUtil.peek_st(world)
	var sum := 0.0
	for pid in o.get("contracts", []):
		var p: Dictionary = world.peek("project").get(pid, {})
		if p.is_empty() or p["status"] != "ACTIVE" or int(p["wu_total"]) <= 0:
			continue
		var frac := float(int(p["wu_total"]) - int(p["wu_done"])) / float(p["wu_total"])
		var late := maxi(0, world.month - (int(p["start_month"]) + int(p["bid_duration"])))
		var penalty := int(float(p["price"]) * minf(0.10, 0.01 * late)) if int(p.get("supervision", 0)) >= 500 else 0
		var left := float(int(p["price"]) - penalty) * frac  # what the work left earns (the advance and retention are timing)
		left += wage_change(world, p, frac)  # and the wage clause on it
		var wages := float(int(p["wu_total"]) - int(p["wu_done"])) / float(S) * wage_wu
		var mp := int(p.get("esc_mat_price", s["prices"]["MATERIAL"]))
		var cp := int(p.get("esc_comp_price", s["prices"]["COMPONENT"]))
		var inputs := float(EconUtil.val(int(float(p["mat_total"]) * frac), mp) + EconUtil.val(int(float(p["comp_total"]) * frac), cp))
		sum += left - wages - inputs
	return int(sum)


## The shortest wait (months) of its quotes a client refused for the wait within WAIT_MEMORY_M months, or -1. Pure.
static func wait_refused(world: WorldState, o: Dictionary) -> int:
	var r: Dictionary = o.get("r8b", {})
	if world.month - int(r.get("wait_m", -999)) > WAIT_MEMORY_M:
		return -1
	return int(r.get("wait_w", -1))


# ------------------------------------------------------------------ signals (pure reads)

## Remaining work of a builder: [started, booked (accepted, not started)] in mu.
static func book(world: WorldState, o: Dictionary) -> Array:
	var started := 0
	var booked := 0
	for pid in o.get("contracts", []):
		var p: Dictionary = world.peek("project").get(pid, {})
		if p.is_empty() or p["status"] != "ACTIVE":
			continue
		var rem := int(p["wu_total"]) - int(p["wu_done"])
		if int(p["start_month"]) > world.month:
			booked += rem
		else:
			started += rem
	return [started, booked]


static func _cap(world: WorldState, o: Dictionary) -> int:
	var cap := int(float(EconLabor.staff_total(o["crew"])) * (0.9 + 0.002 * float(o["ceo"]["mgmt"])))
	if int(o.get("stop_until", -1)) >= world.month:
		cap = int(float(cap) * (EconUnions.LOCKOUT_WORK if o.get("stop_kind", "") == "LOCKOUT" else EconUnions.STRIKE_WORK))
	return cap


## Work waiting for a builder: unstarted jobs in all books + public/private tenders with no bid (mu). Pure.
static func waiting_wu(world: WorldState) -> Array:
	var all := 0
	var pub := 0
	var unbuilt := 0  # work with no builder: tenders without a bid, and tenders whose quotes were refused
	for pid in world.peek("project"):
		var p: Dictionary = world.peek("project")[pid]
		var w := 0
		if p["status"] == "ACTIVE" and int(p["start_month"]) > world.month:
			w = int(p["wu_total"]) - int(p["wu_done"])
		elif p["status"] == "TENDERABLE" or (p["status"] == "TENDER" and (p["bids"] as Array).is_empty()):
			w = int(p["wu_total"])
			unbuilt += w
		all += w
		if p["owner"] == "gov":
			pub += w
	return [all, pub, unbuilt]


## The builders' signals: one row per live builder and a colony row. Pure (gov_builder and UI may call it).
static func signals(world: WorldState) -> Dictionary:
	var rows := {}
	var cap_priv := 0
	var margin_sum := 0
	var spare := 0
	var want_m := 0
	var got_m := 0
	var horizon := GOV_WAIT_M  # the wait clients accept: the shortest wait refused lately, else the government's
	for oid in EconUtil.sorted_keys(world.peek("org")):
		var o: Dictionary = world.peek("org")[oid]
		if bool(o.get("is_contractor", false)) and o["status"] in ["ACTIVE", "DISTRESSED"]:
			var wr := wait_refused(world, o)
			if wr > 0:
				horizon = mini(horizon, wr)
	for oid in EconUtil.sorted_keys(world.peek("org")):
		var o: Dictionary = world.peek("org")[oid]
		if not bool(o.get("is_contractor", false)) or not (o["status"] in ["ACTIVE", "DISTRESSED"]):
			continue
		var k := _cap(world, o)
		var bk := book(world, o)
		var bw := bid_counts(world, o)
		var jm := job_margin(world, oid)
		var cost_m := EconFinance._monthly_costs(o)
		var cash := world.ledger.balance(EconUtil.acct(oid))
		var fp := fill_pm(o)
		var f: Dictionary = o.get("r8b", {}).get("fill", {})
		var mrow: Array = f.get("MATERIAL", [0, 0])
		rows[oid] = {"public": o["type"] == "PUBLIC_ENTERPRISE", "cap": k, "crew": EconLabor.staff_total(o["crew"]) / S,
			"started": int(bk[0]), "booked": int(bk[1]), "book_m": (int(bk[0]) + int(bk[1])) / maxi(S, k),
			"bids12": int(bw[0]), "won12": int(bw[1]), "margin": int(o.get("r8b", {}).get("margin", -1)), "job_margin": jm,
			"fill_pm": fp, "wait_refused": wait_refused(world, o),
			"cash_m": cash / maxi(1, cost_m) if cost_m > 0 else 99, "blocked": bool(o.get("blocked_last", false)),
			"refused_m": int(o.get("r8b", {}).get("refused_m", -999))}
		want_m += int(mrow[0])
		got_m += int(mrow[1])
		if o["type"] != "PUBLIC_ENTERPRISE":
			cap_priv += k
			margin_sum += jm
			spare += maxi(0, horizon * k * fp / 1000 - int(bk[0]) - int(bk[1]))
	var ww := waiting_wu(world)
	var waits: Array = EconUtil.peek_st(world).get("q_waits", [])
	var wsum := 0
	for x in waits:
		wsum += int(x[1])
	var ey := EconConstruction.entrant_year(world)
	return {"builders": rows, "colony": {"waiting_wu": int(ww[0]), "public_waiting_wu": int(ww[1]), "unbuilt_wu": int(ww[2]),
		"entrant_years_pm": int(ww[0]) * 1000 / maxi(1, ey), "mean_wait_m": wsum / maxi(1, waits.size()),
		"job_margin": margin_sum, "fill_pm": 1000 if want_m <= 0 else got_m * 1000 / want_m, "horizon_m": horizon,
		"spare_wu": spare, "private_cap": cap_priv, "month": world.month, "average": average_share(world)}}


## gov_builder's query (§3c a): the same signals, plus whether founding a builder would pass rule 8.
static func builder_needs(world: WorldState) -> Dictionary:
	var sg := signals(world)
	var c: Dictionary = sg["colony"]
	c["entry_ok"] = entry_reason(world, sg) == ""
	c["entry_block"] = entry_reason(world, sg)
	return sg


# ------------------------------------------------------------------ rules 1/2: the margin (COMPANY_AI, quarterly)

static func step_margins(world: WorldState) -> void:
	if world.month % 3 != 0:
		return
	for oid in EconUtil.sorted_keys(world.table("org")):
		var o: Dictionary = world.table("org")[oid]
		if not bool(o.get("is_contractor", false)) or not (o["status"] in ["ACTIVE", "DISTRESSED"]):
			continue
		var r := _r(o)
		var bw := bid_counts(world, o)
		var b := int(bw[0])
		var won := int(bw[1])
		var price_refused := world.month - int(r["refused_m"]) < REFUSED_BLOCK_M
		var wait_ref := wait_refused(world, o) >= 0
		var up := (b >= MIN_BIDS and won * 1000 > WIN_HI_PM * b) or wait_ref or job_margin(world, oid) < 0
		var down := price_refused or (b >= MIN_BIDS and won * 1000 < WIN_LO_PM * b and not wait_ref)
		if down:
			r["margin"] = maxi(0, int(r["margin"]) - STEP_PM)  # rule 2: never below its own cost
		elif up:
			r["margin"] = int(r["margin"]) + STEP_PM  # rule 1: no ceiling of ours; the clients' refusals are the ceiling


# ------------------------------------------------------------------ the quote the client may refuse (award)

## The wage clause on `frac` of job p's work (S-scaled mcr): what the contract adds for the change in wages since its
## award (EconConstruction._escalation; Wilma's clause, a19ee06), both directions; 0 without a wage basis. Pure.
## Counted wherever work under way is valued (job_margin, average_share), so they read today's wages on both sides.
static func wage_change(world: WorldState, p: Dictionary, frac: float) -> float:
	if not p.has("esc_wage") or int(p["esc_wage"]) <= 0:
		return 0.0
	var s := EconUtil.peek_st(world)
	var n := 0
	var wsum := 0.0
	for t in EconData.BUILDER_CREW:
		n += int(EconData.BUILDER_CREW[t])
		wsum += float(EconData.BUILDER_CREW[t]) * float(s["wage"].get(t, s["wage"].get("G", 0)))
	var now := int(wsum / float(maxi(1, n)))  # EconConstruction.crew_wage, read without touching the state
	return float(p["esc_wage_cost"]) * frac * (float(now) / float(int(p["esc_wage"])) - 1.0)


## The owner's own estimate of the job at this month's wages and input prices (no foreknowledge).
static func owner_estimate(world: WorldState, p: Dictionary) -> int:
	EconUtil.st(world)
	return owner_estimate_pure(world, p)


static func owner_estimate_pure(world: WorldState, p: Dictionary) -> int:
	var s := EconUtil.peek_st(world)
	var n := 0
	var wsum := 0.0
	for t in EconData.BUILDER_CREW:  # a builder crew's wage mix at this month's wages
		n += int(EconData.BUILDER_CREW[t])
		wsum += float(EconData.BUILDER_CREW[t]) * float(s["wage"].get(t, s["wage"].get("G", 0)))
	var c := float(p["wu_total"]) / float(S) * wsum / float(maxi(1, n)) + float(EconUtil.val(p["mat_total"], s["prices"]["MATERIAL"])) \
		+ float(EconUtil.val(p["comp_total"], s["prices"]["COMPONENT"]))
	return int(c * 1.15)


## "" when the owner accepts bid b, else the reason ("price" | "budget" | "wait").
static func refusal(world: WorldState, p: Dictionary, b: Dictionary) -> String:
	var wait := int(b.get("wait", 0))
	if p["owner"] == "gov":
		if wait > GOV_WAIT_M:
			return "wait"
		if String(p.get("line", "")) != "":
			var overrun := int(b["price"]) - int(p["est_cost"])
			var slack := int(float(int(EconUtil.lever(world, p["line"], 0)) * 1000 * S) * GOV_LINE_SLACK)
			if overrun > 0 and overrun > maxi(0, EconActions.headroom(world, p["line"])) + slack:
				return "budget"
		if float(b["price"]) > float(owner_estimate(world, p)) * (1.0 + GOV_TOL):
			return "price"
		return ""
	var o: Dictionary = world.table("org").get(p["owner"], {})
	var risk := float(o.get("ceo", {}).get("risk", 50))
	if wait > PRIV_WAIT_BASE_M + int(float(PRIV_WAIT_RISK_M) * risk / 100.0):
		return "wait"
	if float(b["price"]) > float(owner_estimate(world, p)) * (1.0 + TOL_BASE + TOL_RISK * risk / 100.0):
		return "price"
	return ""


## Replaces FirmAI._auto_award under R8_BUILDERS: the best-ranked bid the client accepts wins; with none, the quotes are
## refused and the tender opens again after QUOTE_REOPEN_M months (the plan waits).
static func award_round(world: WorldState) -> void:
	for pid in EconUtil.sorted_keys(world.table("project")):
		var p: Dictionary = world.table("project")[pid]
		if p["status"] != "TENDER" or p["bids"].is_empty():
			continue
		if p["owner"] == "gov" and world.meta.get("manual_award", false) and world.month - p["tender_month"] < 3:
			continue
		if p["owner"] == "gov" and Desk.on(world) and Desk.pending(world, "QUOTE|" + String(pid)):
			continue  # DELEGATION (Maja): the quote waits on the First Minister's desk
		var ranked := EconConstruction.ranked_bids(world, p)
		var why := ""
		var chosen := ""
		for b in ranked:
			var r := refusal(world, p, b)
			if r == "wait":
				_note_wait_refused(world, String(b["org"]), int(b.get("wait", 0)))
			elif r == "price":
				var ob: Dictionary = world.table("org").get(b["org"], {})
				if not ob.is_empty():
					_r(ob)["refused_m"] = world.month  # rule 2: this client found its price too high
			if r == "":
				chosen = String(b["org"])
				break
			if why == "":
				why = r
		if p["owner"] == "gov" and Desk.on(world):
			if Desk.quote_case(world, p, ranked, chosen, why):
				continue   # DELEGATION: decided by the minister now, or waiting on the desk (counted there)
		if p["owner"] == "gov":
			Desk.note(world, "PUBLIC_QUOTE")
		if chosen != "":
			EconConstruction.award(world, pid, chosen)
		else:
			_refuse(world, p, ranked, why)


## A client turned down the builder's quote for its wait (the signal for rules 1, 5 and 7).
static func _note_wait_refused(world: WorldState, oid: String, wait: int) -> void:
	var o: Dictionary = world.table("org").get(oid, {})
	if o.is_empty():
		return
	var r := _r(o)
	if world.month - int(r.get("wait_m", -999)) > WAIT_MEMORY_M or wait < int(r.get("wait_w", 9999)):
		r["wait_w"] = maxi(1, wait)
	r["wait_m"] = world.month


## The client refuses every quote on `p`: the tender reopens after QUOTE_REOPEN_M months (the plan is never cancelled).
## Public entry for the decision desk (Maja, DELEGATION), which commits a minister's REFUSE through it.
static func refuse(world: WorldState, p: Dictionary, ranked: Array, why: String) -> void:
	if ranked.is_empty():
		return
	_refuse(world, p, ranked, why)


static func _refuse(world: WorldState, p: Dictionary, ranked: Array, why: String) -> void:
	if why == "price":
		for b in ranked:
			var o: Dictionary = world.table("org").get(b["org"], {})
			if not o.is_empty():
				_r(o)["refused_m"] = world.month  # rule 2 reads refusals on price only
	var best: Dictionary = ranked[0]
	p["bids"] = []
	p["refusals"] = int(p.get("refusals", 0)) + 1
	p["reopen_m"] = world.month + QUOTE_REOPEN_M
	p["tender_month"] = world.month + QUOTE_REOPEN_M  # the tender's clock restarts when it reopens
	var gov: bool = p["owner"] == "gov"
	_stat(world, ("refused_gov_" if gov else "refused_priv_") + why)
	if gov:
		EconFacts.emit(world, "ECON_PUBLIC_QUOTE_REFUSED", p["district"], [["GOVERNMENT", "government"], ["COMPANY", best["org"]]],
			[["GOVERNMENT", "government", 1.0]], {}, 15, "PUBLIC", {"project": p["id"], "type": p["type"], "price": int(best["price"]),
			"estimate": int(p["est_cost"]), "line": String(p.get("line", "")),
			"headroom": EconActions.headroom(world, p["line"]) if String(p.get("line", "")) != "" else 0,
			"wait": int(best.get("wait", 0)), "reason": why, "refusals": int(p["refusals"])})


static func reopened(world: WorldState, p: Dictionary) -> bool:
	return world.month >= int(p.get("reopen_m", -1))


# ------------------------------------------------------------------ rules 3/4/5/6: crews to the book

## Crew target (workers) for a builder (rules 5/6). need_n: workers for the work due now (started jobs at the pace their
## dates need, queued jobs starting within CREW_HORIZON_M months). The other arguments are kept for the caller.
static func crew_target(world: WorldState, oid: String, o: Dictionary, need_n: float, _cur: float, _base_n: float, _blocked: bool) -> float:
	var r := _r(o)
	var target := need_n
	var wr := wait_refused(world, o)
	if wr > 0 and job_margin(world, oid) >= 0:
		# rule 5: its clients turned it down for the wait and its jobs pay: crews to clear the book within that wait
		var bk := book(world, o)
		var per_worker := 0.9 + 0.002 * float(o["ceo"]["mgmt"])
		target = maxf(target, float(int(bk[0]) + int(bk[1])) / float(S) / per_worker / float(wr))
	var fp := fill_pm(o)
	if fp < 1000:
		target = minf(target, maxf(need_n, target) * float(fp) / 1000.0)  # rule 6: no crew for work its material does not support
	return maxf(target, float(r["floor"]))


# ------------------------------------------------------------------ rules 7/8: entry

## The average a newcomer reads (rules 7/8, pure): {work_wu, share_wu, field_new, fill_pm, value_pw, mat_pw, wage_pw,
## profit (S-scaled mcr on its share)}.
static func average_share(world: WorldState) -> Dictionary:
	var s := EconUtil.peek_st(world)
	var px_m := float(int(s["prices"]["MATERIAL"]))
	var px_c := float(int(s["prices"]["COMPONENT"]))
	var work := 0.0
	var value := 0.0
	var mat := 0.0
	for pid in EconUtil.sorted_keys(world.peek("project")):
		var p: Dictionary = world.peek("project")[pid]
		var total := float(int(p["wu_total"]))
		if total <= 0.0:
			continue
		var left := 0.0
		var pays := 0.0
		var pm := px_m
		var pc := px_c
		if p["status"] == "ACTIVE":
			left = total - float(int(p["wu_done"]))
			pays = float(int(p["price"])) * left / total + wage_change(world, p, left / total)
			pm = float(int(p.get("esc_mat_price", int(px_m))))  # E76 escalation pays the change since the award
			pc = float(int(p.get("esc_comp_price", int(px_c))))
		elif p["status"] in ["TENDER", "TENDERABLE"]:
			left = total
			pays = float(owner_estimate_pure(world, p))  # what its client reckons it at today's wages and prices
		else:
			continue
		work += left
		value += pays
		mat += (float(int(p["mat_total"])) * pm + float(int(p["comp_total"])) * pc) / float(S) * left / total
	var field_sum := 0.0
	var fills := 0
	var nb := 0
	for oid in EconUtil.sorted_keys(world.peek("org")):
		var o: Dictionary = world.peek("org")[oid]
		if bool(o.get("is_contractor", false)) and o["status"] in ["ACTIVE", "DISTRESSED"]:
			field_sum += float(field_capacity(world, oid))
			fills += fill12_pm(o)
			nb += 1
	# a newcomer has no crew yet: it fields what it can hire (the same labour market every builder hires from)
	var n := 0
	for t in EconData.BUILDER_CREW:
		n += int(EconData.BUILDER_CREW[t])
	var free := INF
	for t in EconData.BUILDER_CREW:
		free = minf(free, float(PopStore.count(world, {"status": "UNEMPLOYED"}, "skill:" + t)) * float(n) / float(EconData.BUILDER_CREW[t]))
	var field_new := maxf(0.0, free) * float(S)
	var share := work * field_new / maxf(1.0, field_sum + field_new)
	var fill := float(fills) / float(nb) / 1000.0 if nb > 0 else 1.0
	var wsum := 0.0
	for t in EconData.BUILDER_CREW:
		wsum += float(EconData.BUILDER_CREW[t]) * float(int(s["wage"].get(t, s["wage"].get("G", 0))))
	var wage_pw := wsum / float(maxi(1, n)) * 1.08  # a worker-month does one wu (mgmt 50); the bid's own overhead mark-up
	var value_pw := value / maxf(1.0, work) * float(S)
	var mat_pw := mat / maxf(1.0, work) * float(S)
	# rule 6: its crew is what its material supports, so it is paid for the work it does (fill × share), not for all of it
	var profit := share / float(S) * fill * (value_pw - mat_pw - wage_pw)
	return {"work_wu": int(work), "share_wu": int(share), "field_new": int(field_new), "fill_pm": int(fill * 1000.0),
		"value_pw": int(value_pw), "mat_pw": int(mat_pw), "wage_pw": int(wage_pw), "profit": int(profit)}


## "" when a new builder may enter, else why not (pure).
static func entry_reason(world: WorldState, sg: Dictionary = {}) -> String:
	if sg.is_empty():
		sg = signals(world)
	var a: Dictionary = sg["colony"].get("average", {}) if sg["colony"].has("average") else average_share(world)
	if int(a["share_wu"]) <= 0:
		return "no_work"  # rule 8: no building work on offer or in the books, or no worker to hire
	if int(a["profit"]) <= 0:
		return "work_loses"  # rule 8: the average builder's share does not pay for its crew at today's costs
	return ""


static func entry_ok(world: WorldState) -> bool:
	var why := entry_reason(world)
	if why != "":
		_stat(world, "entry_blocked_" + why)
		return false
	_stat(world, "entry_passed")
	return true


# ------------------------------------------------------------------ public builders (§3c a)

## The government founds a public builder in `district`, capitalised from the treasury (INFRASTRUCTURE line).
## Returns the new org id ("" if the sector is off).
static func found_public_builder(world: WorldState, district: String) -> String:
	if not on(world):
		return ""
	var id := world.new_id("org")
	world.table("org")[id] = {"id": id, "key": "PUBBUILD_" + id, "name": EconUtil.firm_name(world, district, "CONTRACTOR", "Works"),
		"type": "PUBLIC_ENTERPRISE", "hq": district, "status": "ACTIVE", "ceo": {"mgmt": 55, "risk": 20, "age_m": 45 * 12},
		"reliability": 50, "is_contractor": true, "crew": {"G": {}, "S": {}, "Sp": {}}, "crew_target": EconData.BUILDER_CREW.duplicate(),
		"premium_m": {"G": 0, "S": 0, "Sp": 0}, "tax_loss_cf": 0, "profit_q": 0, "pl": EconFinance.empty_pl(), "pl_last": {},
		"missed_streak": 0, "ok_streak": 0, "low_cash_streak": 0, "distress_months": 0, "admin_months": 0, "liq_months": 0,
		"missed_this_month": false, "owner_group": "", "sales_ema": {}, "contracts": [], "dividends_ytd": 0, "sold": {}}
	world.ledger.open_account(EconUtil.acct(id))
	var paid := EconFinance.gov_pay(world, EconUtil.acct(id), EconData.BUILDER_EQUITY * S, "PUBLIC_EQUITY")
	EconFinance._spend_line(world, "ECON_BUDGET_INFRASTRUCTURE", paid)
	_r(world.table("org")[id])
	_stat(world, "public_founded")
	Desk.note(world, "PUBLIC_BUILDER")
	EconFacts.emit(world, "COMP_COMPANY_FOUNDED", district, [["COMPANY", id], ["GOVERNMENT", "government"]],
		[["GOVERNMENT", "government", 1.0]], {"JOBS": 3, "INFRASTRUCTURE": 2}, 25, "PUBLIC",
		{"type": "CONTRACTOR", "public": true, "capital": paid / S}, {"districts": [district]})
	return id


## The government orders a public builder to keep at least `crew` workers (0 lifts the order).
static func enlarge_public_builder(world: WorldState, oid: String, crew: int) -> bool:
	if not on(world):
		return false
	var o: Dictionary = world.table("org").get(oid, {})
	if o.is_empty() or o["type"] != "PUBLIC_ENTERPRISE" or not bool(o.get("is_contractor", false)):
		return false
	_r(o)["floor"] = maxi(0, crew)
	_stat(world, "public_enlarged")
	Desk.note(world, "PUBLIC_BUILDER")
	return true


## For EconRules / the E170 forecast's buildability leg (Bob): the shortest start a founder could be quoted now for a
## plant of `plant_type` in `district`, in months, from the builders' books (pure). -1 when no builder is alive.
static func quoted_wait(world: WorldState, _plant_type: String, _district: String) -> int:
	var best := -1
	for oid in EconUtil.sorted_keys(world.peek("org")):
		var o: Dictionary = world.peek("org")[oid]
		if not bool(o.get("is_contractor", false)) or not (o["status"] in ["ACTIVE", "DISTRESSED"]):
			continue
		if o["type"] == "PUBLIC_ENTERPRISE" and EconConstruction._private_builder_alive(world):
			continue
		var bk := book(world, o)
		var k := maxi(S, _cap(world, o))
		var w := 0
		if EconInsolvency.plan_q(world):
			w = (int(bk[0]) + int(bk[1])) / k
		if best < 0 or w < best:
			best = w
	return best

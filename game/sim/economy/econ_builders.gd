class_name EconBuilders
extends RefCounted
## R8 step 4 (Otto, planning/eight-rules.md §2 "Builders" and §3c a; approved by Wilma 2026-11-15): builders under the
## eight rules. OPT-IN: R8 + R8_BUILDERS (EconRules.sector_on(world, "BUILDERS")). Off → nothing here runs and the base
## is bit-identical (the hooks in EconConstruction / FirmAI test on() first).
##
## Rules:
##   1/2 the bid margin: each builder keeps its own margin (‰), starting from the old fixed rule (12% − 8% × risk), stepped
##       quarterly. Up STEP_PM when its book holds more than BOOK_HI_M months of its crew's work, or it wins more than
##       WIN_HI_PM of its bids, or it lost money over 12 months while holding at least BOOK_MID_M months of book. No step
##       up at all while a client refused one of its quotes in the last REFUSED_BLOCK_M months (a builder losing money
##       because its bids are refused must not climb; Wilma). Down STEP_PM when it wins under WIN_LO_PM of its bids with
##       under BOOK_LO_M months of book. Clamped to 0..MARGIN_MAX_PM; a bid is never below the builder's own cost estimate.
##   The quote a client may refuse: a bid is a price and a start date. The client takes the best-ranked bid it accepts:
##       - a private owner refuses a price above its own estimate of the job at this month's wages and input prices ×
##         (1 + tolerance from its CEO's risk), or a start later than its horizon;
##       - the government refuses a price above its own estimate × (1 + GOV_TOL), an overrun on its reservation beyond
##         the line's headroom plus GOV_LINE_SLACK of the line's annual budget, or a start later than GOV_WAIT_M months (fact ECON_PUBLIC_QUOTE_REFUSED: project, price, estimate, line, headroom).
##       After a refusal the tender opens again after QUOTE_REOPEN_M months and the plan waits; a refusal never cancels a
##       plan (only the owner's own patience rule, E165, may end it). Clients read only that month's estimates and budget.
##   3/4 crews to the work: work due now (started jobs, and queued jobs starting within CREW_HORIZON_M months) ÷
##       productivity; growth ≤ +25% a month up to 2× the founding crew; blocked on material → −15%; while it holds work
##       the crew keeps KEEP_SHARE of itself. (The A/B ablation, 2026-11-15: a cash cap on growth and a 6-month horizon
##       halved builders' crews and cost 400 adults; the old crew rule with the other R8 rules beat base.)
##   5   the cap rises to GROW_MULT × the founding crew only with a book longer than GROW_BOOK_M months of the crew's
##       work and a profitable year (no growth on losses).
##   6   shed to the core crew (selling a crew comes with the sale mechanism, §3b).
##   7/8 entry (FirmAI._builder_entry): the old book/backlog trigger, plus no entrant while builders holding more than
##       LOSS_SHARE_PM of private capacity lost money over 12 months, and none while incumbents' spare capacity would
##       clear the waiting work within ENTRY_SPARE_M months.
##   Public builders (§3c a): they bid on public tenders from the first round, at the same margin rule unless the lever
##       ECON_PUBLIC_BUILDER_AT_COST = 1 (then at cost for public work). builder_needs() is gov_builder's query;
##       found_public_builder() and enlarge_public_builder() are the government's two actions (Wilma wires the choice).
##
## State: org["r8b"] = {margin ‰, log {"month": [bids, won]} over 12 months, refused_m, floor (crew ordered by the
## government)}; project["reopen_m"], ["refusals"]; st["r8b_stats"] counters for the reports.

const S := EconUtil.S
const STEP_PM := 20
const MARGIN_MAX_PM := 300
const BOOK_HI_M := 6
const BOOK_MID_M := 3
const BOOK_LO_M := 2
const WIN_HI_PM := 600
const WIN_LO_PM := 200
const MIN_BIDS := 3
const REFUSED_BLOCK_M := 3
const CREW_HORIZON_M := 3
const GROW_BOOK_M := 12
const GROW_MULT := 5.0
const BASE_MULT := 2.0
const KEEP_SHARE := 0.6
const SHRINK := 0.85
const ENTRY_SPARE_M := 12
const LOSS_SHARE_PM := 500
const QUOTE_REOPEN_M := 3
const GOV_WAIT_M := 36
const PRIV_WAIT_BASE_M := 12
const PRIV_WAIT_RISK_M := 24
const TOL_BASE := 0.25
const TOL_RISK := 0.5
const GOV_TOL := 0.3  # the government refuses a price above its own estimate × 1.3
const GOV_LINE_SLACK := 0.25  # ... or an overrun beyond the line's headroom plus a quarter of its annual budget
const LEVER_AT_COST := "ECON_PUBLIC_BUILDER_AT_COST"


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
	for pid in world.peek("project"):
		var p: Dictionary = world.peek("project")[pid]
		var w := 0
		if p["status"] == "ACTIVE" and int(p["start_month"]) > world.month:
			w = int(p["wu_total"]) - int(p["wu_done"])
		elif p["status"] == "TENDERABLE" or (p["status"] == "TENDER" and (p["bids"] as Array).is_empty()):
			w = int(p["wu_total"])
		all += w
		if p["owner"] == "gov":
			pub += w
	return [all, pub]


## The builders' signals: one row per live builder and a colony row. Pure (gov_builder and UI may call it).
static func signals(world: WorldState) -> Dictionary:
	var rows := {}
	var cap_priv := 0
	var loss_cap := 0
	var spare := 0
	for oid in EconUtil.sorted_keys(world.peek("org")):
		var o: Dictionary = world.peek("org")[oid]
		if not bool(o.get("is_contractor", false)) or not (o["status"] in ["ACTIVE", "DISTRESSED"]):
			continue
		var k := _cap(world, o)
		var bk := book(world, o)
		var bw := bid_counts(world, o)
		var p12 := EconPublicCo.result12(o)
		var cost_m := EconFinance._monthly_costs(o)
		var cash := world.ledger.balance(EconUtil.acct(oid))
		rows[oid] = {"public": o["type"] == "PUBLIC_ENTERPRISE", "cap": k, "crew": EconLabor.staff_total(o["crew"]) / S,
			"started": int(bk[0]), "booked": int(bk[1]), "book_m": (int(bk[0]) + int(bk[1])) / maxi(S, k),
			"bids12": int(bw[0]), "won12": int(bw[1]), "margin": int(o.get("r8b", {}).get("margin", -1)), "profit12": p12,
			"cash_m": cash / maxi(1, cost_m) if cost_m > 0 else 99, "blocked": bool(o.get("blocked_last", false)),
			"refused_m": int(o.get("r8b", {}).get("refused_m", -999))}
		if o["type"] != "PUBLIC_ENTERPRISE":
			cap_priv += k
			if p12 < 0:
				loss_cap += k
			spare += maxi(0, ENTRY_SPARE_M * k - int(bk[0]) - int(bk[1]))
	var ww := waiting_wu(world)
	var waits: Array = EconUtil.peek_st(world).get("q_waits", [])
	var wsum := 0
	for x in waits:
		wsum += int(x[1])
	var ey := EconConstruction.entrant_year(world)
	return {"builders": rows, "colony": {"waiting_wu": int(ww[0]), "public_waiting_wu": int(ww[1]),
		"entrant_years_pm": int(ww[0]) * 1000 / maxi(1, ey), "mean_wait_m": wsum / maxi(1, waits.size()),
		"loss_share_pm": loss_cap * 1000 / maxi(1, cap_priv), "spare12_wu": spare, "private_cap": cap_priv,
		"month": world.month}}


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
		var k := maxi(S, _cap(world, o))
		var bk := book(world, o)
		var bm := float(int(bk[0]) + int(bk[1])) / float(k)
		var bw := bid_counts(world, o)
		var b := int(bw[0])
		var won := int(bw[1])
		var refused := world.month - int(r["refused_m"]) < REFUSED_BLOCK_M
		var up := bm > float(BOOK_HI_M) or (b >= MIN_BIDS and won * 1000 > WIN_HI_PM * b) \
			or (EconPublicCo.result12(o) < 0 and bm >= float(BOOK_MID_M))
		var down := b >= MIN_BIDS and won * 1000 < WIN_LO_PM * b and bm < float(BOOK_LO_M)
		if up and not refused and not down:
			r["margin"] = mini(MARGIN_MAX_PM, int(r["margin"]) + STEP_PM)
		elif down:
			r["margin"] = maxi(0, int(r["margin"]) - STEP_PM)


# ------------------------------------------------------------------ the quote the client may refuse (award)

## The owner's own estimate of the job at this month's wages and input prices (no foreknowledge).
static func owner_estimate(world: WorldState, p: Dictionary) -> int:
	var s := EconUtil.st(world)
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
		var ranked := EconConstruction.ranked_bids(world, p)
		var why := ""
		var chosen := ""
		for b in ranked:
			var r := refusal(world, p, b)
			if r == "":
				chosen = String(b["org"])
				break
			if why == "":
				why = r
		if chosen != "":
			EconConstruction.award(world, pid, chosen)
		else:
			_refuse(world, p, ranked, why)


static func _refuse(world: WorldState, p: Dictionary, ranked: Array, why: String) -> void:
	for b in ranked:
		var o: Dictionary = world.table("org").get(b["org"], {})
		if not o.is_empty():
			_r(o)["refused_m"] = world.month
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

## Crew target (workers) for a builder. need_n: workers for the work due now; cur: crew now; base_n: founding crew;
## blocked: material-blocked last month (not while building strategic input capacity).
static func crew_target(world: WorldState, _oid: String, o: Dictionary, need_n: float, cur: float, base_n: float, blocked: bool) -> float:
	var r := _r(o)
	var mult := 3.0 if o["type"] == "PUBLIC_ENTERPRISE" and not EconConstruction._private_builder_alive(world) else BASE_MULT  # E86
	var bk := book(world, o)
	var k := maxi(S, _cap(world, o))
	if int(bk[0]) + int(bk[1]) > GROW_BOOK_M * k and EconPublicCo.result12(o) > 0:
		mult = maxf(mult, GROW_MULT)  # rule 5: a long book and a profitable year
	var cap_n := minf(maxf(cur * 1.25, cur + 5.0), mult * base_n)
	if blocked:
		cap_n = cur * SHRINK
	var target := minf(need_n, cap_n)
	if not (o["contracts"] as Array).is_empty():
		target = maxf(target, KEEP_SHARE * cur)  # rule 4: a slow shed while it holds work
	target = maxf(target, 0.3 * base_n)  # rule 6: the core crew
	return maxf(target, float(r["floor"]))


# ------------------------------------------------------------------ rules 7/8: entry

## "" when a new builder may enter, else why not (pure).
static func entry_reason(world: WorldState, sg: Dictionary = {}) -> String:
	if sg.is_empty():
		sg = signals(world)
	var c: Dictionary = sg["colony"]
	if int(c["private_cap"]) > 0 and int(c["loss_share_pm"]) > LOSS_SHARE_PM:
		return "incumbents_lose"
	if int(c["private_cap"]) > 0 and int(c["waiting_wu"]) <= int(c["spare12_wu"]):
		return "incumbents_spare"
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

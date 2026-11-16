class_name EconPublicCo
extends RefCounted
## E150 self-funding public companies (user decision via Wilma 2026-11-14: "real firms don't wait for monthly
## government money; they run on sales, supplier credit and cost-based prices"). OPT-IN: world.meta["on"] has "E150".
##   SUPPORT: the automatic E44 support transfer to a public enterprise in distress is paid only out of the voted
##     subsidy line (ECON_BUDGET_SUBSIDIES headroom) — no payroll "lifeline" above it. Public institutions (schools,
##     clinics, administration) stay budget-funded.
##   CHARGES: the public utility (CPW) and the transport authority (CTA) set what they charge to cover their running
##     costs plus MARGIN_PCT (working cash). Each quarter, a company whose last 12 months fell short of that by more than
##     the voted subsidy line can cover raises its tariffs by STEP_UP; one with a surplus above SURPLUS_PCT of costs
##     lowers them by STEP_DOWN; within the
##     levers' ranges. Each change is a fact (the company is blamed; governments can answer with a subsidy vote).
##   With E148 they buy on supplier credit like everyone else.

const S := EconUtil.S
const STEP_UP := 0.05
const STEP_DOWN := 0.03
const MARGIN_PCT := 5  # target: a small surplus over running costs, so the company builds working cash for its invoices
const SURPLUS_PCT := 15
## company key → its tariff levers ([lever, min, max] — the PIC ranges)
const TARIFFS := {
	"CPW": [["ECON_UTILITY_TARIFF_ENERGY", 10, 120], ["ECON_UTILITY_TARIFF_WATER", 5, 60]],
	"CTA": [["ECON_FREIGHT_TARIFF", 1, 20]],
}


## E150B (seed-3 collapse trace, Wilma 2026-11-15; opt-in with E150): the PE dividend took half of each quarter's
## profit down to ONE month of costs, so CPW lived below half a month of cash, asked for support every month (0 under
## E150) and still cut its tariffs to the floor because its P&L showed a surplus. Under E150B:
##   (a) no tariff cut while the company is cash-short (cash < CASH_SHORT_M months of costs) or asked for funding in
##       the last REQ_MEMORY_M months;
##   (b) the surplus that justifies a cut is result12 minus what it paid to the treasury in 12 months (dividend+sweep);
##   (d) a public enterprise keeps PE_KEEP_M months of costs before any dividend goes to the treasury (the E80 sweep
##       already keeps SURPLUS_BUFFER_MONTHS).
## E150C (separate arm on top): the E44 support of a utility is never capped below its payroll (the E62 lifeline).
const CASH_SHORT_M := 2
const REQ_MEMORY_M := 6
const PE_KEEP_M := 6


static func b_on(world: WorldState) -> bool:
	return active(world) and (world.meta["on"] as Array).has("E150B") and not EconUtil.off(world, "E150B")


static func c_on(world: WorldState) -> bool:
	return active(world) and (world.meta["on"] as Array).has("E150C") and not EconUtil.off(world, "E150C")


## Cash a public enterprise keeps before paying a dividend (mcr).
static func pe_keep(world: WorldState, monthly_costs: int) -> int:
	return monthly_costs * (PE_KEEP_M if b_on(world) else 1)


## Money a public enterprise paid to the treasury (dividend, sweep): kept for 12 months (E150B (b)).
static func note_out(world: WorldState, oid: String, amt: int) -> void:
	if amt <= 0 or not b_on(world) or not world.table("org").has(oid):
		return
	var o: Dictionary = world.table("org")[oid]
	var h: Array = o.get("pe_out", [])
	h.append([world.month, amt])
	while not h.is_empty() and int(h[0][0]) <= world.month - 12:
		h.pop_front()
	o["pe_out"] = h


static func out12(world: WorldState, o: Dictionary) -> int:
	var t := 0
	for e in o.get("pe_out", []):
		if int(e[0]) > world.month - 12:
			t += int(e[1])
	return t


static func active(world: WorldState) -> bool:
	return world.meta.has("on") and (world.meta["on"] as Array).has("E150") and not EconUtil.off(world, "E150")


## Running result of the last 12 months (mcr): revenue − (wages, inputs, utilities, freight, interest, rent). Subsidies
## are not revenue here — the point is what the company earns by its charges.
static func result12(o: Dictionary) -> int:
	var p := EconAnnual.sum12(o)
	return int(p.get("rev", 0)) - int(p.get("wages", 0)) - int(p.get("cogs", 0)) - int(p.get("util", 0)) - int(p.get("freight", 0)) \
		- int(p.get("interest", 0)) - int(p.get("rent", 0))


static func costs12(o: Dictionary) -> int:
	var p := EconAnnual.sum12(o)
	return int(p.get("wages", 0)) + int(p.get("cogs", 0)) + int(p.get("util", 0)) + int(p.get("freight", 0)) + int(p.get("interest", 0)) + int(p.get("rent", 0))


## SETTLEMENT, quarterly: tariff reviews.
static func quarterly(world: WorldState) -> void:
	if not active(world):
		return
	var sub_room := maxi(0, EconActions.headroom(world, "ECON_BUDGET_SUBSIDIES"))
	for key in EconUtil.sorted_keys(TARIFFS):
		if key == "CPW" and EconRulesUtil.on(world):
			continue  # R8 utilities: rules 1/2 set CPW's tariffs
		if key == "CTA" and EconRules.freight_market_on(world, "R8FR_NOPX"):
			continue  # R8FR_MARKET: the freight tariff follows the freight market (EconRules._freight_tariff)
		var oid := EconFinance.org_by_key(world, key)
		if oid == "":
			continue
		var o: Dictionary = world.table("org")[oid]
		if EconAnnual.months(o) < 6:
			continue
		var res := result12(o)
		var mult := 1.0
		var short := costs12(o) * MARGIN_PCT / 100 - res  # how far below the target margin
		if short > 0 and short > sub_room:
			mult = 1.0 + STEP_UP
		elif res > costs12(o) * SURPLUS_PCT / 100:
			mult = 1.0 - STEP_DOWN
			if b_on(world):
				var cash := world.ledger.balance(EconUtil.acct(oid))
				var short_cash := cash < CASH_SHORT_M * costs12(o) / 12
				var asked := world.month - int(o.get("pe_req_m", -999)) < REQ_MEMORY_M
				if short_cash or asked or res - out12(world, o) <= costs12(o) * SURPLUS_PCT / 100:
					mult = 1.0  # (a)/(b): a cash-short company, or one whose surplus went to the treasury, keeps its prices
		if mult == 1.0:
			continue
		var changed := []
		for row in TARIFFS[key]:
			var lv: String = row[0]
			var old := float(EconUtil.lever(world, lv, row[1]))
			var nv := clampf(old * mult, float(row[1]), float(row[2]))
			if mult > 1.0:
				nv = maxf(nv, minf(float(row[2]), old + 1.0))  # integer levers: a step is at least 1
			else:
				nv = minf(nv, maxf(float(row[1]), old - 1.0))
			var iv := int(round(nv))
			if iv != int(old):
				world.levers[lv] = iv
				changed.append([lv, int(old), iv])
		if changed.is_empty():
			continue
		var up := mult > 1.0
		if up and proposals(world):
			# E150P: a rise is only proposed — the company files its request; the government approves the rise
			# (ECON_APPROVE_TARIFF), votes the subsidy, or lets the company run down
			for c in changed:
				world.levers[c[0]] = c[1]  # undo: nothing changes until approved
			var short_c := maxi(0, costs12(o) * MARGIN_PCT / 100 - res)
			var pend: Dictionary = EconUtil.st(world).get("pe_proposals", {})
			pend[oid] = {"month": world.month, "since": int((pend.get(oid, {}) as Dictionary).get("since", world.month)), "levers": changed, "gap12": short_c / S, "subsidy_needed": maxi(0, short_c - sub_room) / S}
			EconUtil.st(world)["pe_proposals"] = pend
			EconFacts.emit(world, "ECON_PE_FUNDING_REQUEST", o["hq"], [["COMPANY", oid]], [["GOVERNMENT", "government", 1.0]], {}, 30, "OFFICIAL",
				{"org": oid, "amount": 0, "asked": short_c / S, "proposed": changed, "subsidy_needed": maxi(0, short_c - sub_room) / S})
			continue
		EconFacts.emit(world, "ECON_TARIFF_CHANGE", o["hq"], [["COMPANY", oid]], [["COMPANY", oid, 0.6], ["GOVERNMENT", "government", 0.4]],
			{"COST_OF_LIVING": -6 if up else 4}, 20, "PUBLIC", {"org": oid, "up": up, "levers": changed, "result12": res / S})


## E150P (opt-in with E150): tariff rises are proposals the government decides on (the automatic step stands in for "a
## government that always approves" when E150P is off).
static func proposals(world: WorldState) -> bool:
	return active(world) and (world.meta["on"] as Array).has("E150P") and not EconUtil.off(world, "E150P")


## Open proposals {org id: {month, levers [[lever, old, new]], gap12, subsidy_needed}} (credits) — for the legislature.
static func pending(world: WorldState) -> Dictionary:
	return EconUtil.peek_st(world).get("pe_proposals", {})


## ECON_APPROVE_TARIFF {org}: applies the company's proposed tariffs (validate first). Returns false when nothing pends.
static func approve(world: WorldState, oid: String) -> bool:
	var pend: Dictionary = EconUtil.st(world).get("pe_proposals", {})
	if not pend.has(oid):
		return false
	var o: Dictionary = world.table("org").get(oid, {})
	for c in pend[oid]["levers"]:
		world.levers[c[0]] = int(c[2])
	pend.erase(oid)
	EconFacts.emit(world, "ECON_TARIFF_CHANGE", o.get("hq", "d:1"), [["COMPANY", oid], ["GOVERNMENT", "government"]],
		[["GOVERNMENT", "government", 0.6], ["COMPANY", oid, 0.4]], {"COST_OF_LIVING": -6}, 20, "PUBLIC", {"org": oid, "up": true, "approved": true})
	return true


## E44 support cap under E150: the voted subsidy line only (else -1: the old cap).
static func support_cap(world: WorldState) -> int:
	if not active(world):
		return -1
	return maxi(0, EconActions.headroom(world, "ECON_BUDGET_SUBSIDIES"))

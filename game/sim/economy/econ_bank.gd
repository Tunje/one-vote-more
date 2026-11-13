class_name EconBank
extends RefCounted
## M2 bank credit creation (A61, user-approved; planning/plan-money.md): the colony bank lends by creating deposits, so
## the money stock grows with borrowing and shrinks with repayment.
##   LEDGER: the bank's account may go negative — its cash minus the money it created; with the loan book (an asset
##     outside the ledger) its net worth is CAPITAL = bank balance + loans outstanding (the founding grant plus retained
##     profit, minus losses). The ledger total stays 0.
##   LIMIT: loans ≤ CAPITAL × 1000 / CAPITAL_PM (a capital ratio). Lending room = limit − loans (0 while failed).
##   RATE: a new loan's rate = the base rate × (RATE_FLOOR + RATE_SLOPE × utilisation²) — cheap credit in a boom with
##     room, dear credit near the limit.
##   BUSTS: written-off loans (liquidations, sovereign haircuts) destroy capital, so the room shrinks — a credit crunch
##     (ECON_CREDIT_CRUNCH at ≥ CRUNCH_PM utilisation, once a year). Capital ≤ 0: the bank fails (ECON_BANK_FAILURE) and
##     lends nothing until recapitalised (ECON_BANK_BAILOUT: treasury → bank capital).
## OPT-IN until its A/B (world.meta["on"] has "M2"). Off: the bank lends only its cash, as before.

const S := EconUtil.S
const CAPITAL_PM := 100  # capital ‰ of loans (a 10% capital ratio)
const RATE_FLOOR := 0.7
const RATE_SLOPE := 0.8
const CRUNCH_PM := 950


static func active(world: WorldState) -> bool:
	return world.meta.has("on") and (world.meta["on"] as Array).has("M2") and not EconUtil.off(world, "M2")


static func loans(world: WorldState) -> int:
	var t := 0
	for lid in world.peek("loan"):
		t += maxi(0, int(world.peek("loan")[lid]["principal"]))
	return t


static func capital(world: WorldState) -> int:
	return world.ledger.balance(EconUtil.BANK) + loans(world)


static func limit(world: WorldState) -> int:
	return maxi(0, capital(world)) * 1000 / CAPITAL_PM


## Lending room now (milli). 0 while the bank has failed.
static func room(world: WorldState) -> int:
	if bool(EconUtil.peek_st(world).get("bank_failed", false)):
		return 0
	return maxi(0, limit(world) - loans(world))


static func utilisation_pm(world: WorldState) -> int:
	var lim := limit(world)
	return 1000 if lim <= 0 else clampi(loans(world) * 1000 / lim, 0, 1000)


## Rate for a new loan (ppm a month) from the base rate and the bank's utilisation.
static func rate_ppm(world: WorldState, base_ppm: int) -> int:
	var u := float(utilisation_pm(world)) / 1000.0
	return int(float(base_ppm) * (RATE_FLOOR + RATE_SLOPE * u * u))


## Turns the bank's account into a credit account (once) — the activation hook, also safe to call every month.
static func ensure(world: WorldState) -> void:
	if active(world) and world.ledger.has_account(EconUtil.BANK) and not bool(world.ledger.allow_negative.get(EconUtil.BANK, false)):
		world.ledger.allow_negative[EconUtil.BANK] = true


## SETTLEMENT (after loan service): failure and crunch news; the money stock for the indicators.
static func monthly(world: WorldState) -> void:
	if not active(world):
		return
	ensure(world)
	var s := EconUtil.st(world)
	var cap := capital(world)
	if cap <= 0 and not bool(s.get("bank_failed", false)):
		s["bank_failed"] = true
		EconFacts.emit(world, "ECON_BANK_FAILURE", "d:1", [["EXTERNAL", "bank"]], [["EXTERNAL", "bank", 0.6], ["GOVERNMENT", "government", 0.4]],
			{"JOBS": -25, "COST_OF_LIVING": -10, "GOVERNANCE": -15}, 80, "PUBLIC",
			{"capital": cap / S, "loans": loans(world) / S, "deposits": deposits(world) / S})
	elif cap > 0 and bool(s.get("bank_failed", false)):
		s["bank_failed"] = false
	var u := utilisation_pm(world)
	if u >= CRUNCH_PM and not bool(s.get("bank_failed", false)) and world.month - int(s.get("crunch_m", -99)) >= 12:
		s["crunch_m"] = world.month
		EconFacts.emit(world, "ECON_CREDIT_CRUNCH", "d:1", [["EXTERNAL", "bank"]], [["EXTERNAL", "bank", 0.7], ["GOVERNMENT", "government", 0.3]],
			{"JOBS": -10}, 40, "PUBLIC", {"utilisation_pm": u, "capital": cap / S, "loans": loans(world) / S})
	var h: Array = s.get("money_hist", [])
	h.append(deposits(world))
	while h.size() > 24:
		h.pop_front()
	s["money_hist"] = h


## Private money (households, firms, unions, parties, papers): the deposits the bank's lending creates.
static func deposits(world: WorldState) -> int:
	var t := 0
	for a in world.ledger.balances:
		var k := String(a)
		if k.begins_with("hh:") or k.begins_with("co:") or k.begins_with("union:") or k.begins_with("party:") or k.begins_with("media:"):
			t += maxi(0, int(world.ledger.balances[a]))
	return t


## ECON_BANK_BAILOUT: the treasury recapitalises the bank (borrowing if it must). Returns the amount paid.
static func bailout(world: WorldState, amount: int) -> int:
	if amount <= 0:
		return 0
	var paid := EconFinance.gov_pay(world, EconUtil.BANK, amount, "BANK_BAILOUT")
	EconFinance._spend_line(world, "BAILOUT", paid)
	var s := EconUtil.st(world)
	if capital(world) > 0:
		s["bank_failed"] = false
	EconFacts.emit(world, "ECON_BANK_BAILOUT", "d:1", [["GOVERNMENT", "government"], ["EXTERNAL", "bank"]],
		[["GOVERNMENT", "government", 1.0]], {"GOVERNANCE": -10, "FAIRNESS": -10, "JOBS": 10}, 60, "PUBLIC",
		{"amount": paid / S, "capital_after": capital(world) / S})
	return paid


## {capital, loans, limit, room, utilisation_pm, deposits, failed, rate_firm_ppm} — credits, for probes and the panel.
static func view(world: WorldState) -> Dictionary:
	return {"capital": capital(world) / S, "loans": loans(world) / S, "limit": limit(world) / S, "room": room(world) / S,
		"utilisation_pm": utilisation_pm(world), "deposits": deposits(world) / S, "failed": bool(EconUtil.peek_st(world).get("bank_failed", false)),
		"rate_firm_ppm": rate_ppm(world, int(EconData.BANK_FIRM_BASE_PM * 1000000))}

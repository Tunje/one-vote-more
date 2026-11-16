class_name EconFamily
extends RefCounted
## Family enterprises with a government grant (user decisions via Wilma 2026-11-14). OPT-IN:
##   E160 family farms — FAMFARM: a sixth of a FARM's plot, one household of 4 working adults (3 G + 1 S, about parity
##        per worker with a big farm), 40 FOOD a month (six ≈ 86% of a FARM), water/energy and build cost a sixth.
##        Founded where food sells at ≥ FOUND_MARK × a family farm's cost and the district's water and energy are not
##        rationed. Grant lever ECON_FAMILY_FARM_GRANT (0–100% of build cost + start-up working capital, LAW).
##   E162 family bakeries — FAMBAKERY: a sixth of a BAKERY, 4 adults (1 trained baker + 3 G), 43 bread from 42 FOOD;
##        a neighbourhood shop founded in the district with the most unfilled staple bread (needs E146), at least one
##        bakery's output. The grant (ECON_FAMILY_BAKERY_GRANT) also pays a baking course for one adult (G → S,
##        counted as trained) and three months of flour and utilities (a new firm has no sales history for credit).
## Both: a family firm is a PRIVATE org marked "family", owned by its household pool; its four people are hired
## from that district's unemployed when it opens, with no hiring contest (and E158 never moves them). The family eats
## its own produce first (taken from the firm's stock before the market clears); only the rest is sold. Grants are their
## own spending category, paid through gov_pay; there is no clawback. A failed family firm goes through the normal
## insolvency: its plant is sold to another buyer, never taken back by the state.
## The government as regulator (user correction via Wilma 2026-11-14 — "grants would not be offered when there is no
## need for more food"): a grant is an application approved only on need; the lever is how generous an approved grant
## is. A family farm grant needs food to be short or dear (FOOD margin under NEED_MARGIN %, or a 12-month food
## shortfall above NEED_SF ‰, or the food price above NEED_PRICE × the cheapest farm's unit cost); a family bakery grant
## needs the district's bread gap (as for founding) and enough flour (FOOD margin ≥ NEED_MARGIN %, 12-month shortfall
## ≤ BAK_SF ‰, and no farm grant needed — farms come first). At most GRANT_YEAR_MAX grants a year in all. A refused
## family may still found with its own money and a bank loan, as without a grant.

const S := EconUtil.S
const LawOps := preload("res://sim/law/law_ops.gd")
const FOUND_MARK := 1.3
const FOUND_MAX := 4
const ADULTS := 4
const WC_MONTHS := 3
const COURSE_M := 3
const SERVED_MIN := 0.9  # households' share of their water and energy served in the district
const NEED_MARGIN := 10  # % effective FOOD capacity over demand (E157 measure, recorded monthly)
const NEED_SF := 10  # ‰ food shortfall, 12-month average
const NEED_PRICE := 1.5  # × the cheapest farm's unit cost
const BAK_SF := 2  # ‰: "no food shortfall" for bakery grants (12-month average)
const GRANT_YEAR_MAX := 6
const SF_HIST := 12
## A grant is a time-limited programme (user ruling via Wilma 2026-11-14: "when a grant ends, they reset to zero so they
## have to start over on where to put it; grants should be limited time for when you can apply"). Raising a grant lever
## from 0 opens an application window of PROG_M months; changing the level inside it does not extend it. When it ends the
## lever goes back to 0 by an enactment ("programme ended") and a public fact reports what it paid and refused. A new
## programme needs a new decision. Founding with the family's own money is possible at any time.
const PROG_M := 24
## A family with an approved grant does not need savings for the rest (user decision via Wilma 2026-11-15): the bank
## lends the whole remaining share of the package (the grant and the plant are its security; the bank's room still
## applies). Nothing is repaid before the plant opens; then each month a third of the surplus (cash above
## LOAN_KEEP_M months of running costs), up to the instalment of a LOAN_TERM_M-month annuity; a bad month pays less and
## unpaid interest is added. Only LOAN_DEFAULT_M months in a row with nothing paid is a default, and the family firm
## then has to sell (administration, the existing failure rule). Self-funded foundings keep the old rules.
const LOAN_TERM_M := 144
const LOAN_SHARE := 3  # one part in three of the surplus
const LOAN_KEEP_M := 2
const LOAN_DEFAULT_M := 12
const KINDS := {"FAMFARM": {"flag": "E160", "lever": "ECON_FAMILY_FARM_GRANT", "good": "FOOD"},
	"FAMBAKERY": {"flag": "E162", "lever": "ECON_FAMILY_BAKERY_GRANT", "good": "FINE_FOOD"}}


static func _on(world: WorldState, flag: String) -> bool:
	return world.meta.has("on") and (world.meta["on"] as Array).has(flag) and not EconUtil.off(world, flag)


static func any_on(world: WorldState) -> bool:
	return _on(world, "E160") or _on(world, "E162")


static func is_family(world: WorldState, oid: String) -> bool:
	return bool(world.table("org").get(oid, {}).get("family", false))


# ------------------------------------------------------------------ founding (COMPANY_AI, quarterly)

static func found(world: WorldState) -> void:
	if not any_on(world):
		return
	var s := EconUtil.st(world)
	var lf := int(EconQuery.labour(world)["labour_force"])
	var cap := mini(FOUND_MAX, 2 + lf / 2000)
	var n := 0
	for ftype in ["FAMFARM", "FAMBAKERY"]:
		var k: Dictionary = KINDS[ftype]
		if not _on(world, k["flag"]):
			continue
		if ftype == "FAMBAKERY" and not EconStaple.active(world):
			continue
		if ftype == "FAMFARM" and food_glut(world):
			_note(s, ftype, "glut")   # the eighth rule: nobody starts a farm while food is piling up unsold
			continue
		var good: String = k["good"]
		while n < cap:
			var d := _district(world, ftype)
			if d == "":
				break
			var r8why := EconRulesFood.family_entry_block(world, ftype, d)  # R8 step 3 (opt-in R8_FOOD): rules 7/8
			if r8why != "":
				_note(s, ftype, r8why)
				break
			var uc := family_unit_cost(world, ftype, _grant_pct(world, ftype, d, true))
			if float(s["prices"][good]) < found_mark(world, d) * uc:
				_note(s, ftype, "price")
				break
			var gid := _household(world, d)
			if gid == "":
				_note(s, ftype, "no_household")
				break
			var pct := _grant_pct(world, ftype, d)
			var site := farm_site(world, d) if ftype == "FAMFARM" else d
			if not _start(world, ftype, site, gid, pct, d):
				_note(s, ftype, "money")
				break
			n += 1


## What a family asks of the price before it founds, as a multiple of its unit cost, in district d (user 2026-11-15:
## "two factors are missing from the calc: hopes for betterment, a weight that weights how bad the living is there;
## their own farm should look like an improvement in a starving district; and unemployment as counter weight to
## non-profit"). From FOUND_MARK it falls with
## - hardship: how short of food people are (the colony's 12-month shortfall, and the district's own unbought and
##   undelivered food where that is measured): a family that eats its own produce first sees a farm as a way out;
## - idleness: the district's unemployment: a family with no work accepts a firm that pays little.
## Never under FOUND_FLOOR: below that the firm could not buy its inputs. A firm founded under 1.0 may well fail; that
## is the family's and the grant-giving government's risk, and nobody knows beforehand.
const FOUND_FLOOR := 0.6
const HOPE_W := 0.4
const HOPE_FULL_SF := 50.0           # permille of food shortfall at which hardship counts in full
const HOPE_FULL_GAP := 200.0         # permille of the district's food need unbought or undelivered, likewise
const IDLE_W := 0.4
const IDLE_FULL := 0.25              # district unemployment rate at which idleness counts in full


static func hardship(world: WorldState, d: String) -> float:
	var s := EconUtil.peek_st(world)
	var h := float(_sf12(world)) / HOPE_FULL_SF
	var gap := float(int(s.get("food_unaff_d", {}).get(d, 0)) + int(s.get("food_scarce_d", {}).get(d, 0)))
	return clampf(maxf(h, gap / HOPE_FULL_GAP), 0.0, 1.0)


static func idleness(world: WorldState, d: String) -> float:
	var hb := EconPop.hb_of(d)
	var un := float(PopStore.count(world, {"hb": hb, "status": "UNEMPLOYED"}))
	var em := float(PopStore.count(world, {"hb": hb, "status": "EMPLOYED"}))
	if un + em <= 0.0:
		return 0.0
	return clampf(un / (un + em) / IDLE_FULL, 0.0, 1.0)


static func found_mark(world: WorldState, d: String) -> float:
	return maxf(FOUND_FLOOR, FOUND_MARK - HOPE_W * hardship(world, d) - IDLE_W * idleness(world, d))


## What a unit costs a family to make (user 2026-11-15, after the audit of the founding sum): FirmAI.unit_cost judges
## a family as a wage-paying company that bought its own building. It is neither:
## - the family is owner-operated and pays itself no wages (EconFinance skips its payroll); its labour costs it what
##   it gives up: the unemployment benefit, plus FAMILY_WORK_PREMIUM for the work, never more than the market wage;
## - a grant pays grant_pct % of the building, so only the rest is the family's to recover.
## Inputs, power, water and upkeep are as for any plant. Pure.
const FAMILY_WORK_PREMIUM := 1.25


static func family_unit_cost(world: WorldState, ftype: String, grant_pct: int) -> float:
	var s := EconUtil.peek_st(world)
	var r: Dictionary = EconData.RECIPES[ftype]
	var keep := float(s["wage"]["G"]) * float(EconUtil.lever(world, "ECON_UNEMPLOYMENT_BENEFIT_RATE", 40)) / 100.0 * FAMILY_WORK_PREMIUM
	var c := 0.0
	for t in r["labor"]:
		c += float(r["labor"][t]) * minf(float(s["wage"][t]), keep)
	for g in r["in"]:
		if g in EconData.MARKET_GOODS:
			c += float(r["in"][g]) * float(s["prices"][g])
		elif g == "ENERGY":
			c += float(r["in"][g]) * float(EconUtil.lever(world, "ECON_UTILITY_TARIFF_ENERGY", 40)) * S
		elif g == "WATER":
			c += float(r["in"][g]) * float(EconUtil.lever(world, "ECON_UTILITY_TARIFF_WATER", 20)) * S
	c += float(r["upkeep"]) * float(s["prices"]["MATERIAL"])
	if EconData.BUILD.has(ftype):
		c += float(EconConstruction.estimate(ftype)) / EconData.DEPRECIATION_MONTHS * float(100 - clampi(grant_pct, 0, 100)) / 100.0
	return c / float(r["out"][1])


## A family firm the government paid a grant to has failed (user 2026-11-15: "grant farms failing is food for
## politics"). Reported once, when it goes into liquidation: public, the government's doing in part (more the fresher
## the grant), felt as bad government, with what was paid.
const GRANT_FAIL_FRESH_M := 60


static func _failed_grantees(world: WorldState) -> void:
	var orgs: Dictionary = world.table("org")
	for oid in EconUtil.sorted_keys(orgs):
		var o: Dictionary = orgs[oid]
		if not bool(o.get("family", false)) or int(o.get("grant_paid", 0)) <= 0 or bool(o.get("grant_fail_told", false)):
			continue
		if not (String(o.get("status", "")) in ["LIQUIDATION", "DISSOLVED"]):
			continue
		o["grant_fail_told"] = true
		var age := world.month - int(o.get("grant_month", world.month))
		var share := clampf(0.7 - 0.5 * float(age) / float(GRANT_FAIL_FRESH_M), 0.2, 0.7)
		EconFacts.emit(world, "ECON_GRANT_FIRM_FAILED", String(o.get("hq", "")), [["COMPANY", oid]],
			[["GOVERNMENT", "government", share], ["NATURE", "market", 1.0 - share]], {"GOVERNANCE": -3, "FAIRNESS": -1}, 35, "PUBLIC",
			{"org": oid, "type": String(o.get("family_type", "")), "district": String(o.get("hq", "")), "grant_paid": int(o["grant_paid"]),
				"months_since_grant": age})


## The government's decision on a grant application: the lever's % if approved, else 0 (refusal noted by reason).
## `dry`: only ask what the grant would be (the family's own sum before it applies); nothing is noted or counted.
static func _grant_pct(world: WorldState, ftype: String, d: String, dry: bool = false) -> int:
	var s := EconUtil.st(world)
	var pct := clampi(int(EconUtil.lever(world, KINDS[ftype]["lever"], 0)), 0, 100)
	if pct <= 0 or not prog_open(world, ftype):
		return 0
	# the government names the districts a programme covers (gov_builder._grant_cover); not chosen yet → no grants
	var cover: Dictionary = s.get("grant_cover", {})
	var ck := cover_kind(ftype)
	if not cover.has(ck):
		if not dry:
			_note(s, ftype, "grant_no_cover_yet")
		return 0
	if not (d in (cover[ck] as Array)):
		if not dry:
			_note(s, ftype, "grant_outside_districts")
		if not dry:
			_prog_count(world, ftype, "refused")
		return 0
	var ok := food_needed(world) if ftype == "FAMFARM" else flour_ok(world)
	if not ok:
		if not dry:
			_note(s, ftype, "grant_no_need")
		if not dry:
			_prog_count(world, ftype, "refused")
		return 0
	var yr: Array = s.get("fam_grant_year", [])
	var used := 0
	for m in yr:
		if int(m) > world.month - 12:
			used += 1
	if used >= GRANT_YEAR_MAX:
		if not dry:
			_note(s, ftype, "grant_ceiling")
		if not dry:
			_prog_count(world, ftype, "refused")
		return 0
	return pct


static func _food_margin(world: WorldState) -> int:
	var a: Array = EconUtil.peek_st(world).get("ess_hist", {}).get("FOOD", [])
	return 100 if a.is_empty() else int(a[a.size() - 1])


static func _sf12(world: WorldState) -> int:
	var a: Array = EconUtil.peek_st(world).get("fam_sf_hist", [])
	if a.is_empty():
		return int(EconUtil.peek_st(world).get("food_shortfall", 0))
	var t := 0
	for v in a:
		t += int(v)
	return t / a.size()


## Food is piling up unsold: last month's market had more than GLUT_COVER times the food buyers wanted on offer.
## (User 2026-11-15: "I hope government grants aren't given for farms when we are over producing?" They were: with a
## year of food in stock and a fifth of orders unfilled, the shortfall alone read as a need for more farms; probe in
## planning/ab-family.md.) In a glut hunger is not for want of farms: no grant is approved, and no family founds.
const GLUT_COVER := 3.0


static func food_glut(world: WorldState) -> bool:
	var ms: Dictionary = (EconUtil.peek_st(world).get("market_stats", {}) as Dictionary).get("FOOD", {})
	var wanted := float(maxi(int(ms.get("D", 0)), int(ms.get("wanted", 0))))
	return wanted > 0.0 and float(ms.get("S", 0)) > GLUT_COVER * wanted


## The colony needs more food: short capacity, real hunger, or a price well above what farming costs; never while
## food is piling up unsold.
static func food_needed(world: WorldState) -> bool:
	if food_glut(world):
		return false
	if _food_margin(world) < NEED_MARGIN or _sf12(world) > NEED_SF:
		return true
	var uc := minf(FirmAI.unit_cost(world, "FARM"), FirmAI.unit_cost(world, "FAMFARM"))
	return float(EconUtil.st(world)["prices"]["FOOD"]) > NEED_PRICE * uc


## Enough flour for another oven: food is not short and no farm grant is needed.
static func flour_ok(world: WorldState) -> bool:
	return _food_margin(world) >= NEED_MARGIN and _sf12(world) <= BAK_SF and not food_needed(world)


## Monthly: family grant loans are repaid out of the family firm's surplus (see LOAN_*).
static func service_loans(world: WorldState) -> void:
	var s := EconUtil.st(world)
	var fl: Dictionary = s.get("fam_loan_stats", {})
	var behind := 0
	for lid in EconUtil.sorted_keys(world.table("loan")):
		var l: Dictionary = world.table("loan")[lid]
		if not bool(l.get("family", false)) or int(l["principal"]) <= 0:
			continue
		var o: Dictionary = world.table("org").get(l["borrower"], {})
		if o.is_empty() or o["status"] in ["FORMING", "LIQUIDATION", "DISSOLVED"]:
			continue  # nothing before the plant opens
		var acc := EconUtil.acct(l["borrower"])
		var r := float(l["rate_ppm"]) / 1000000.0
		var interest := int(float(l["principal"]) * r)
		var n := maxi(1, int(l["term_left"]))
		var annuity := int(float(l["principal"]) * r / (1.0 - pow(1.0 + r, -n))) if r > 0.0 else int(l["principal"]) / n
		var keep := LOAN_KEEP_M * maxi(1, EconFinance._monthly_costs(o))
		var surplus := maxi(0, world.ledger.balance(acc) - keep)
		var pay := mini(surplus / LOAN_SHARE, annuity)
		if pay > 0:
			world.ledger.transfer(acc, EconUtil.BANK, pay, "LOAN_SERVICE", world.month)
			s["bank_profit_ytd"] = int(s.get("bank_profit_ytd", 0)) + mini(pay, interest)
			EconFinance.pl_add(world, l["borrower"], "interest", mini(pay, interest))
			l["principal"] = int(l["principal"]) + interest - pay  # a bad month pays less; unpaid interest is added
			l["term_left"] = maxi(1, int(l["term_left"]) - 1)
			l["zero_m"] = 0
			fl["paid"] = int(fl.get("paid", 0)) + pay
		else:
			l["principal"] = int(l["principal"]) + interest
			l["zero_m"] = int(l.get("zero_m", 0)) + 1
			behind += 1
			if int(l["zero_m"]) >= LOAN_DEFAULT_M and o["status"] in ["ACTIVE", "DISTRESSED"]:
				if not bool(l.get("defaulted", false)):
					fl["defaulted"] = int(fl.get("defaulted", 0)) + 1  # loans in default, each counted once
					l["defaulted"] = true
				fl["default_events"] = int(fl.get("default_events", 0)) + 1
				l["zero_m"] = 0
				EconInsolvency._enter_administration(world, l["borrower"])  # has to sell: the existing failure rule
	fl["behind"] = behind
	s["fam_loan_stats"] = fl


static func cover_kind(ftype: String) -> String:
	return "FARM" if ftype == "FAMFARM" else "BAKERY"


## Monthly: where a family firm is needed, by district, for the government's choice of coverage (integers, 0 = none).
## FARM: while the colony needs food, the unemployed adults (persons) of districts where a family could farm (water and
## energy served); BAKERY: while flour is sufficient, the district's unmet staple bread (units) beyond what is open or
## being built.
static func _publish_need_d(world: WorldState) -> void:
	var s := EconUtil.st(world)
	var food := _on(world, "E160") and food_needed(world)
	var flour := _on(world, "E162") and flour_ok(world)
	var farm := {}
	var bak := {}
	for d in EconUtil.sorted_keys(EconData.DISTRICTS):
		if not EconUtil.connected(d):
			continue
		var sv: Array = s.get("util_served_hh", {}).get(d, [1.0, 1.0])
		var served := float(sv[0]) >= SERVED_MIN and float(sv[1]) >= SERVED_MIN
		farm[d] = PopStore.count(world, {"hb": EconPop.hb_of(d), "status": "UNEMPLOYED"}) if food and served else 0
		bak[d] = maxi(0, int(s.get("staple_gap_d", {}).get(d, 0)) - _pending_out(world, "FAMBAKERY", d)) / S if flour else 0
	s["family_need_d"] = {"FARM": farm, "BAKERY": bak}


static func prog_open(world: WorldState, ftype: String) -> bool:
	var pr: Dictionary = EconUtil.peek_st(world).get("fam_prog", {}).get(ftype, {})
	return not pr.is_empty() and world.month < int(pr["until"])


static func _prog_count(world: WorldState, ftype: String, what: String) -> void:
	var pr: Dictionary = EconUtil.st(world).get("fam_prog", {}).get(ftype, {})
	if not pr.is_empty():
		pr[what] = int(pr[what]) + 1


## Monthly: open a programme when its lever rises from 0; end it when its window is over (lever back to 0).
static func _programmes(world: WorldState) -> void:
	var s := EconUtil.st(world)
	var progs: Dictionary = s.get("fam_prog", {})
	s["fam_prog"] = progs
	var prev: Dictionary = s.get("fam_lever_prev", {})
	s["fam_lever_prev"] = prev
	for ftype in ["FAMFARM", "FAMBAKERY"]:
		if not _on(world, KINDS[ftype]["flag"]):
			continue
		var lid: String = KINDS[ftype]["lever"]
		var lv := int(EconUtil.lever(world, lid, 0))
		var pr: Dictionary = progs.get(ftype, {})
		if not pr.is_empty():
			pr["level"] = maxi(int(pr["level"]), lv)
			var cv: Array = s.get("grant_cover", {}).get(cover_kind(ftype), [])
			if not cv.is_empty() and (pr["cover"] as Array).is_empty():
				pr["cover"] = cv.duplicate()
			if world.month >= int(pr["until"]):
				_end_programme(world, ftype, pr)
				progs.erase(ftype)
		elif lv > 0 and int(prev.get(ftype, 0)) == 0:
			progs[ftype] = {"start": world.month, "until": world.month + PROG_M, "level": lv, "paid": 0, "refused": 0, "cover": []}
		prev[ftype] = lv


static func _end_programme(world: WorldState, ftype: String, pr: Dictionary) -> void:
	var s := EconUtil.st(world)
	var lid: String = KINDS[ftype]["lever"]
	var id := world.new_id("enact")
	var e := {"id": id, "lever": lid, "value": 0, "legal_level": "LAW", "source_bill": "programme ended",
		"decided_month": world.month, "earliest_effective_month": world.month, "status": "LEGAL", "legal_month": world.month,
		"from": world.levers.get(lid)}
	world.table("enactment")[id] = e
	# the end is part of the programme itself: in force at once (no new bill, no implementation task); a change of the
	# grant still on its way through implementation is overtaken by it
	LawOps._supersede(world, e)
	LawOps.state(world)["legal_values"][lid] = 0
	LawOps._make_effective(world, id, e)
	var h: Array = s.get("fam_prog_hist", [])
	h.append([ftype, int(pr["start"]), world.month - int(pr["start"]), int(pr["level"]), int(pr["paid"]), int(pr["refused"]), (pr["cover"] as Array).duplicate(), (pr.get("bands", {}) as Dictionary).duplicate()])
	s["fam_prog_hist"] = h
	var opened := 0
	for gid2 in pr.get("grantees", []):
		var og: Dictionary = world.table("org").get(gid2, {})
		if not og.is_empty() and og["status"] in ["ACTIVE", "DISTRESSED"]:
			opened += 1
	EconFacts.emit(world, "ECON_GRANT_PROGRAMME_ENDED", "COLONY", [["GOVERNMENT", "government"]], [["GOVERNMENT", "government", 1.0]],
		{}, 20, "PUBLIC", {"lever": lid, "type": ftype, "start": int(pr["start"]), "level": int(pr["level"]),
		"paid": int(pr["paid"]), "opened": opened, "refused": int(pr["refused"]), "districts": (pr["cover"] as Array).duplicate()})


## Some district lacks at least one family bakery's bread beyond what is open or being built (pure read).
static func bread_gap_any(world: WorldState) -> bool:
	var s := EconUtil.peek_st(world)
	var one := int(EconData.RECIPES["FAMBAKERY"]["out"][1]) * S
	for d in EconUtil.sorted_keys(EconData.DISTRICTS):
		if EconUtil.connected(d) and int(s.get("staple_gap_d", {}).get(d, 0)) - _pending_out(world, "FAMBAKERY", d) >= one:
			return true
	return false


## Monthly: the regulator's need signal for the legislature (st["lever_need"], ‰): positive = the colony needs what the
## grant pays for (farms: up to 2000 with the food shortfall), negative = no need while the grant is still offered.
static func _publish_need(world: WorldState) -> void:
	var s := EconUtil.st(world)
	var ln: Dictionary = s.get("lever_need", {})
	if _on(world, "E160"):
		var v := 0
		if food_needed(world):
			v = 1000 + clampi(_sf12(world) * 20, 0, 1000)
		elif int(EconUtil.lever(world, "ECON_FAMILY_FARM_GRANT", 0)) > 0:
			v = -1000
		ln["ECON_FAMILY_FARM_GRANT"] = v
	if _on(world, "E162"):
		var v2 := 0
		if bread_gap_any(world) and flour_ok(world):
			v2 = 1000
		elif int(EconUtil.lever(world, "ECON_FAMILY_BAKERY_GRANT", 0)) > 0:
			v2 = -1000
		ln["ECON_FAMILY_BAKERY_GRANT"] = v2
	s["lever_need"] = ln


static func _note(s: Dictionary, ftype: String, why: String) -> void:
	var f: Dictionary = s.get("fam_fail_found", {})
	var key := ftype + "|" + why
	f[key] = int(f.get(key, 0)) + 1
	s["fam_fail_found"] = f


## Farms: a district whose households get their water and energy (not rationed); the one with the most unemployed.
## Bakeries: the district with the most unfilled staple bread, at least one family bakery's output.
static func _district(world: WorldState, ftype: String) -> String:
	var s := EconUtil.st(world)
	var best := ""
	var bv := -1
	for d in EconUtil.sorted_keys(EconData.DISTRICTS):
		if not EconUtil.connected(d):
			continue
		var sv: Array = s.get("util_served_hh", {}).get(d, [1.0, 1.0])
		if float(sv[0]) < SERVED_MIN or float(sv[1]) < SERVED_MIN:
			continue  # no family starts a farm or an oven without (most of its) power and water
		var v := 0
		if ftype == "FAMFARM":
			v = PopStore.count(world, {"hb": EconPop.hb_of(d), "status": "UNEMPLOYED"})
		else:
			v = int(s.get("staple_gap_d", {}).get(d, 0))
			if v < int(EconData.RECIPES["FAMBAKERY"]["out"][1]) * S:
				continue
			v -= _pending_out(world, ftype, d)
			if v < int(EconData.RECIPES["FAMBAKERY"]["out"][1]) * S:
				continue
		if v > bv:
			bv = v
			best = d
	if best == "" and ftype == "FAMBAKERY":
		_note(s, ftype, "no_district")
	return best


## Where a family puts its farm (user 2026-11-15: "farms could be placed in other places than where they came from, so
## don't place all farms next to the same district; place them where they can produce good"). Every connected
## district with power and water is scored by the farmland around its settlement that no farm has taken yet (a big
## farm takes PLOTS_PER_FARM family plots), by how well its power and water are served, and a little by how far it is
## from home. The best one; the family's own district when no map is there or no land is free anywhere.
const PLOTS_PER_FARM := 6
const SITE_REACH := 6                # tiles around a settlement a family will farm
const SITE_HOP_COST := 0.15          # each hop from home takes this share off a site's worth


static func farm_site(world: WorldState, home: String) -> String:
	if not Terrain.ready(world):
		return home   # no map (economy-only worlds): the family's own district
	var s := EconUtil.peek_st(world)
	var anchors: Dictionary = ColonyLayout.econ_anchors(world)
	var taken := {}
	for fid in world.peek("facility"):
		var f: Dictionary = world.peek("facility")[fid]
		if f["type"] == "FARM":
			taken[f["district"]] = int(taken.get(f["district"], 0)) + PLOTS_PER_FARM
		elif f["type"] == "FAMFARM":
			taken[f["district"]] = int(taken.get(f["district"], 0)) + 1
	for pid in world.peek("project"):
		var p: Dictionary = world.peek("project")[pid]
		if String(p.get("type", "")) == "FAMFARM" and p.get("status", "") in ["TENDER", "ACTIVE", "TENDERABLE", "PLANNING"]:
			taken[p["district"]] = int(taken.get(p["district"], 0)) + 1
	var best := home
	var bv := 0.0
	for d in EconUtil.sorted_keys(EconData.DISTRICTS):
		if not EconUtil.connected(d) or not anchors.has(d):
			continue
		var sv: Array = s.get("util_served_hh", {}).get(d, [1.0, 1.0])
		var served := minf(float(sv[0]), float(sv[1]))
		if served < SERVED_MIN:
			continue
		var land := ColonyLayout.count_near(world, ColonyLayout.as_tile(anchors[d]), ColonyLayout.FAC_TERRAIN["FARM"], SITE_REACH) - int(taken.get(d, 0))
		if land <= 0:
			continue
		var hops := maxi(0, EconUtil.hops(home, d)) if d != home else 0
		var v := float(land) * served * maxf(0.2, 1.0 - SITE_HOP_COST * float(hops))
		if v > bv:
			bv = v
			best = d
	return best


## Output of family firms of this type already open or being built in district d (milli-units a month).
static func _pending_out(world: WorldState, ftype: String, d: String) -> int:
	var n := 0
	for fid in world.table("facility"):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] == ftype and f["district"] == d and not f["mothball"]:
			n += 1
	for pid in world.table("project"):
		var p: Dictionary = world.table("project")[pid]
		if p["type"] == ftype and p["district"] == d and p["status"] in ["TENDER", "TENDERABLE", "ACTIVE"]:
			n += 1
	return n * int(EconData.RECIPES[ftype]["out"][1]) * S


## A common household pool (band I1–I3) of district d whose block has at least 4 unemployed adults.
static func _household(world: WorldState, d: String) -> String:
	var hb := EconPop.hb_of(d)
	if PopStore.count(world, {"hb": hb, "status": "UNEMPLOYED"}) < ADULTS:  # (persons)
		return ""
	var best := ""
	var bc := -1
	for gid in EconUtil.sorted_keys(world.table("hh")):
		var g: Dictionary = world.table("hh")[gid]
		if g["district"] != d or not (g.get("band", "I3") in ["I1", "I2", "I3"]):
			continue
		var c := world.ledger.balance(EconUtil.hh_acct(gid))
		if c > bc:
			bc = c
			best = gid
	return best


## Start-up cost (mcr): build estimate + WC_MONTHS of running inputs (+ a course for bakeries).
static func startup_cost(world: WorldState, ftype: String) -> Dictionary:
	var s := EconUtil.st(world)
	var r: Dictionary = EconData.RECIPES[ftype]
	var run := 0
	for g in r["in"]:
		if g in EconData.MARKET_GOODS:
			run += EconUtil.val(int(r["in"][g]) * S, int(s["prices"][g]))
		elif g == "ENERGY":
			run += int(r["in"][g]) * int(EconUtil.lever(world, "ECON_UTILITY_TARIFF_ENERGY", 40)) * S
		elif g == "WATER":
			run += int(r["in"][g]) * int(EconUtil.lever(world, "ECON_UTILITY_TARIFF_WATER", 20)) * S
	var course := int(s["wage"]["G"]) * COURSE_M if ftype == "FAMBAKERY" else 0
	return {"build": EconConstruction.estimate(ftype), "wc": run * WC_MONTHS, "course": course}


## `d`: where the plant stands; `home`: the district the family lives in and is hired from (a farm may stand elsewhere).
static func _start(world: WorldState, ftype: String, d: String, gid: String, pct: int, home: String = "") -> bool:
	var s := EconUtil.st(world)
	if EconInsolvency.planning_stage(world):
		# E165 with E160/E162 (the user, 2026-11-16: "PLANS ARE MADE BEFORE THEY BECOME COMPANIES ... THAT'S BEFORE
		# ACCEPTING A GRANT"): only the plan, an org row in FORMING and its project. No grant, loan or savings move, no
		# programme place, no founded count; the money comes in fund_plan when a builder's quote is accepted (Otto's
		# EconConstruction.award), and the founded count and fact at the opening (on_open).
		var pid := _make_org(world, ftype, d, gid, home)
		var po: Dictionary = world.table("org")[pid]
		po["fund_on_award"] = true
		po["fund_pct"] = pct
		po["fund_gid"] = gid
		po["fam_plan"] = true
		EconConstruction.create(world, ftype, d, pid, pid, "")
		EconFacts.emit(world, "COMP_COMPANY_PLANNED", d, [["COMPANY", pid]], [["COMPANY", pid, 1.0]], {}, 10, "PUBLIC",
			{"type": ftype, "family": true, "grant_pct": pct}, {"districts": [d]})
		return true
	var m := _money(world, ftype, gid, pct)
	if not bool(m["ok"]):
		return false
	var g: Dictionary = world.table("hh")[gid]
	var id := _make_org(world, ftype, d, gid, home)
	_fund_apply(world, id, ftype, d, gid, pct, m)
	EconPop.make_owner(world, g["hb"], g["band"])
	EconPop.sync(world)
	EconConstruction.create(world, ftype, d, id, id, "")
	_count_founded(world, id, ftype, d, pct)
	return true


## Otto's award hook (E165): a family's plan has a builder's accepted quote; now it applies for its grant and the
## bank's share and puts in its savings, as _start did at founding before. false: the money is not there (the grant
## refused or no bank room under the family rules), and the award is reverted and the plan withdrawn (Otto's side).
static func fund_plan(world: WorldState, oid: String, pid: String) -> bool:
	var o: Dictionary = world.table("org").get(oid, {})
	if o.is_empty() or not bool(o.get("fund_on_award", false)):
		return true
	var ftype := String(o["family_type"])
	var gid := String(o.get("fund_gid", o.get("owner_group", "")))
	if not world.table("hh").has(gid):
		return false
	var pct := int(o.get("fund_pct", 0))
	var m := _money(world, ftype, gid, pct)
	if not bool(m["ok"]):
		return false
	_fund_apply(world, oid, ftype, String(o["hq"]), gid, pct, m)
	var g: Dictionary = world.table("hh")[gid]
	EconPop.make_owner(world, g["hb"], g["band"])
	EconPop.sync(world)
	o.erase("fund_on_award")
	return true


## The funding test (unchanged): a grant of pct of the start-up cost; with a grant the bank lends the whole rest when
## it has room, else savings and a build loan for part of the build.
static func _money(world: WorldState, ftype: String, gid: String, pct: int) -> Dictionary:
	var s := EconUtil.st(world)
	var c := startup_cost(world, ftype)
	var total := int(c["build"]) + int(c["wc"]) + int(c["course"])
	var grant := total * pct / 100
	var own := total - grant
	var savings := world.ledger.balance(EconUtil.hh_acct(gid))
	var loan := 0
	var fam_loan := false
	var room := EconBank.room(world) if EconBank.active(world) else world.ledger.balance(EconUtil.BANK) - EconData.BANK_MIN_CASH * S
	if grant > 0 and own <= room:
		# an approved grant: the bank lends the whole rest; the family's savings stay where they are
		loan = own
		savings = 0
		fam_loan = true
	else:
		if grant > 0:
			_note(s, ftype, "bank_no_room")  # no room at the bank: the old rules (savings and a build loan)
	if not fam_loan and savings < own:
		loan = mini(own - savings, int(c["build"]) * 7 / 10)  # a small bank loan for part of the build
		if savings + loan < own:
			return {"ok": false}
	return {"ok": true, "grant": grant, "own": own, "savings": savings, "loan": loan, "fam_loan": fam_loan, "c": c}


static func _make_org(world: WorldState, ftype: String, d: String, gid: String, home: String) -> String:
	var id := world.new_id("org")
	world.table("org")[id] = {"id": id, "key": "FAM_" + id, "name": EconUtil.firm_name(world, d, "FAMILY", "& Family"), "type": "PRIVATE",
		"hq": d, "status": "FORMING", "ceo": {"mgmt": 45, "risk": 25, "age_m": 38 * 12}, "reliability": 0, "is_contractor": false,
		"crew": {}, "crew_target": {}, "premium_m": {"G": 0, "S": 0, "Sp": 0}, "tax_loss_cf": 0, "profit_q": 0, "pl": EconFinance.empty_pl(),
		"pl_last": {}, "missed_streak": 0, "ok_streak": 0, "low_cash_streak": 0, "distress_months": 0, "admin_months": 0, "liq_months": 0,
		"missed_this_month": false, "owner_group": gid, "sales_ema": {}, "contracts": [], "dividends_ytd": 0, "sold": {},
		"family": true, "family_type": ftype}
	world.ledger.open_account(EconUtil.acct(id))
	world.table("org")[id]["home"] = home if home != "" else d
	world.table("org")[id]["grant_paid"] = 0  # what the government gave (mcr; 0 = self-funded), for news and blame later
	world.table("org")[id]["grant_month"] = -1
	return id


static func _fund_apply(world: WorldState, id: String, ftype: String, d: String, gid: String, pct: int, m: Dictionary) -> void:
	var s := EconUtil.st(world)
	var k: Dictionary = KINDS[ftype]
	var c: Dictionary = m["c"]
	var grant := int(m["grant"])
	var own := int(m["own"])
	var savings := int(m["savings"])
	var loan := int(m["loan"])
	var fam_loan := bool(m["fam_loan"])
	if grant > 0:
		var paid := EconFinance.gov_pay(world, EconUtil.acct(id), grant, "FAMILY_GRANT")
		world.table("org")[id]["grant_paid"] = paid
		world.table("org")[id]["grant_month"] = world.month
		EconFinance._spend_line(world, k["lever"], paid)
		s["fam_grant_total"] = int(s.get("fam_grant_total", 0)) + paid
		var yr: Array = s.get("fam_grant_year", [])
		yr.append(world.month)
		while yr.size() > GRANT_YEAR_MAX * 2:
			yr.pop_front()
		s["fam_grant_year"] = yr
		_prog_count(world, ftype, "paid")
		var prg: Dictionary = s.get("fam_prog", {}).get(ftype, {})
		if not prg.is_empty():
			var gl: Array = prg.get("grantees", [])
			gl.append(id)
			prg["grantees"] = gl
		var prb: Dictionary = s.get("fam_prog", {}).get(ftype, {})
		if not prb.is_empty():
			var bd: Dictionary = prb.get("bands", {})
			var band: String = String(world.table("hh")[gid].get("band", "?"))
			bd[band] = int(bd.get(band, 0)) + 1
			prb["bands"] = bd
		var gn: Dictionary = s.get("fam_grant_n", {})
		gn[ftype] = int(gn.get(ftype, 0)) + 1
		s["fam_grant_n"] = gn
		if ftype == "FAMBAKERY" and int(c["course"]) > 0:
			s["fam_course_total"] = int(s.get("fam_course_total", 0)) + int(c["course"]) * pct / 100
	var from_hh := mini(own, savings)
	if from_hh > 0:
		world.ledger.transfer(EconUtil.hh_acct(gid), EconUtil.acct(id), from_hh, "EQUITY", world.month)
	if loan > 0:
		var lent := EconFinance.new_loan(world, id, loan, 0, true)
		if fam_loan:
			if lent:
				for lid in world.table("loan"):
					var l: Dictionary = world.table("loan")[lid]
					if l["borrower"] == id:
						l["family"] = true
						l["zero_m"] = 0
						l["term_left"] = LOAN_TERM_M
				var fl: Dictionary = s.get("fam_loan_stats", {})
				fl["n"] = int(fl.get("n", 0)) + 1
				fl["amount"] = int(fl.get("amount", 0)) + loan
				s["fam_loan_stats"] = fl
			else:
				_note(s, ftype, "bank_no_room_late")
	if ftype == "FAMBAKERY":
		# the course: one adult of the district learns to bake (General → Skilled), counted with the colony's training
		var hb := EconPop.hb_of(d)
		var keys := PopStore.select(world, {"hb": hb, "status": "UNEMPLOYED"})
		for key in keys:
			if int(world.peek("pop")[key]["skill"].get("G", 0)) >= 1 and EconPop.recompose(world, key, "skill", "G", "S", 1) > 0:  # (persons)
				var h: Array = s.get("train_hist", [])
				if h.is_empty():
					h.append([0, 0])
				h[h.size() - 1][0] = int(h[h.size() - 1][0]) + 1
				s["train_hist"] = h
				s["fam_courses"] = int(s.get("fam_courses", 0)) + 1
				break


static func _count_founded(world: WorldState, id: String, ftype: String, d: String, pct: int) -> void:
	var s := EconUtil.st(world)
	var fd: Dictionary = s.get("fam_founded", {})
	fd[ftype] = int(fd.get(ftype, 0)) + 1
	s["fam_founded"] = fd
	EconFacts.emit(world, "COMP_COMPANY_FOUNDED", d, [["COMPANY", id]], [["COMPANY", id, 0.6], ["GOVERNMENT", "government", 0.4]],
		{"JOBS": 2, "FAIRNESS": 2}, 10, "PUBLIC", {"type": ftype, "family": true, "grant_pct": pct}, {"districts": [d]})


# ------------------------------------------------------------------ opening: the family goes to work

## Called when the family firm's plant opens (EconInsolvency, FORMING → ACTIVE): its four adults are hired from the
## district's unemployed directly (no hiring contest).
static func on_open(world: WorldState, oid: String, fid: String) -> void:
	if not is_family(world, oid):
		return
	var oo: Dictionary = world.table("org")[oid]
	if bool(oo.get("fam_plan", false)):
		oo.erase("fam_plan")  # E165: a family's plan is counted as founded only when its plant opens
		_count_founded(world, oid, String(oo["family_type"]), String(world.table("facility")[fid]["district"]), int(oo.get("fund_pct", 0)))
	var f: Dictionary = world.table("facility")[fid]
	var hb := EconPop.hb_of(String(world.table("org")[oid].get("home", f["district"])))   # the family, wherever its farm stands
	var occ := EconPop.person_occ(world, oid, f["type"], "G")
	var req := EconLabor.required(f)
	for t in ["S", "G"]:
		var need := int(req.get(t, 0)) / S
		if need <= 0:
			continue
		if not f["staff"].has(t):
			f["staff"][t] = {}
		for sk in EconLabor.LOWER_TIERS[t]:
			if need <= 0:
				break
			var got := EconPop.hire(world, hb, sk, occ, need)
			if got > 0:
				var key := EconPop.lab_key(hb, sk)
				f["staff"][t][key] = int(f["staff"][t].get(key, 0)) + got * S
				need -= got
	EconPop.sync(world)


# ------------------------------------------------------------------ the family eats first (TRADE, before clearing)

static func self_supply(world: WorldState) -> void:
	if not any_on(world):
		return
	var s := EconUtil.st(world)
	# the regulator's view: last month's food shortfall (12-month history) and, each January, the two grant levers
	var sh: Array = s.get("fam_sf_hist", [])
	sh.append(int(s.get("food_shortfall", 0)))
	while sh.size() > SF_HIST:
		sh.pop_front()
	s["fam_sf_hist"] = sh
	if world.month % 12 == 0:
		var lh: Array = s.get("fam_lever_hist", [])
		lh.append([int(EconUtil.lever(world, "ECON_FAMILY_FARM_GRANT", 0)), int(EconUtil.lever(world, "ECON_FAMILY_BAKERY_GRANT", 0)),
			1 if food_needed(world) else 0, 1 if flour_ok(world) else 0])
		s["fam_lever_hist"] = lh
	_programmes(world)
	service_loans(world)
	_failed_grantees(world)
	_publish_need(world)
	_publish_need_d(world)
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if not KINDS.has(f["type"]) or f["mothball"]:
			continue
		var o: Dictionary = world.table("org").get(f["org"], {})
		if not bool(o.get("family", false)) or not world.table("hh").has(o.get("owner_group", "")):
			continue
		var g: Dictionary = world.table("hh")[o["owner_group"]]
		var good: String = KINDS[f["type"]]["good"]
		# the family: four adults and their share of the pool's children
		var adults := maxi(1, (int(g["lf"]) + int(g["nonpart"]) + int(g["owners"])) / S)
		var persons := float(ADULTS) * (1.0 + float(int(g["children"]) / S) / float(adults))
		var need := int(persons * EconData.NEED["FOOD"] * float(S))
		if good == "FINE_FOOD":
			need = need * int(EconStaple.SHARE_PM.get(g.get("band", "I3"), 600)) / 1000
		var q := EconUtil.inv_take(world, f["org"], good, f["district"], mini(need, EconUtil.inv_get(world, f["org"], good, f["district"])))
		if q <= 0:
			continue
		# the stock was offered for sale last month: what the family keeps comes off that offer too (else the market
		# would sell food that is no longer there)
		var left := q
		for off in s.get("offers", []):
			if left <= 0:
				break
			if off["seller"] == f["org"] and off["good"] == good and off["district"] == f["district"] and int(off["qty"]) > 0:
				var cut := mini(left, int(off["qty"]))
				off["qty"] = int(off["qty"]) - cut
				left -= cut
		g["bought"][good] = int(g["bought"].get(good, 0)) + q
		var sf: Dictionary = s.get("fam_self", {})
		sf[good] = int(sf.get(good, 0)) + q
		s["fam_self"] = sf


# ------------------------------------------------------------------ report

## {founded {type}, alive {type}, sold {type} (plants now held by a non-family owner), out {type} (last month's output),
##  grant_total, course_total, courses, fail_found {type|why}, failed_utility {type}} (counts / credits).
static func view(world: WorldState) -> Dictionary:
	var s := EconUtil.peek_st(world)
	var alive := {}
	var sold := {}
	var out := {}
	var dark := {}
	for fid in world.peek("facility"):
		var f: Dictionary = world.peek("facility")[fid]
		if not KINDS.has(f["type"]):
			continue
		var o: Dictionary = world.peek("org").get(f["org"], {})
		var fam := bool(o.get("family", false))
		var dead: bool = o.get("status", "") in ["LIQUIDATION", "DISSOLVED"]
		if fam and not dead and not f["mothball"]:
			alive[f["type"]] = int(alive.get(f["type"], 0)) + 1
			out[f["type"]] = int(out.get(f["type"], 0)) + int(f.get("out_last", 0)) / S
		elif not fam:
			sold[f["type"]] = int(sold.get(f["type"], 0)) + 1
		if int(f.get("dark_m", 0)) >= 3:
			dark[f["type"]] = int(dark.get(f["type"], 0)) + 1
	return {"founded": s.get("fam_founded", {}), "alive": alive, "sold": sold, "out": out, "dark": dark,
		"grant_total": int(s.get("fam_grant_total", 0)) / S, "course_total": int(s.get("fam_course_total", 0)) / S,
		"courses": int(s.get("fam_courses", 0)), "fail_found": s.get("fam_fail_found", {}),
		"grant_n": s.get("fam_grant_n", {}), "lever_hist": s.get("fam_lever_hist", []),
		"prog_hist": s.get("fam_prog_hist", []), "prog_open": s.get("fam_prog", {}),
		"loans": s.get("fam_loan_stats", {})}

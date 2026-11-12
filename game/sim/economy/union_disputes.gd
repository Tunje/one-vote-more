class_name UnionDisputes
extends RefCounted
## U2 (user decision A41, planning/spec-unions-v1.md §2): bargaining and strikes. Replaces M9's random strike roll
## (EconUnions keeps mass layoffs, union_pm decay, stoppage effects and the essential-services law).
##
## Table "union_demand" (ids "udemand:N"):
##   {id, union, employer (org id | "gov" for the public sector), employer_name, occ, kind WAGE|SAFETY|JOBS|RECOGNITION,
##    size_pm, made, deadline, status OPEN|STRIKE|SETTLED|FAILED, answer, counter_pm, player_answer, outcome
##    (ACCEPTED|COUNTER|WON|COMPROMISE|LOST|ARBITRATED|STOOD_DOWN), award_pm, strike_start, strike_months, persons,
##    losses (milli), unlawful, reasons, lockout, ended}
## Monthly (COMPANY_AI, from EconUnions.industrial_action):
##   1. strikes in progress: strike pay from the fund to the strikers' households; an empty fund collapses the strike
##      (LOST); each month the employer may settle (AI company by cash and profit, AI government by ideology; while
##      the PLAYER governs only the player's answer settles a public-sector strike); a union gives up after STRIKE_MAX_M.
##   2. answers to open demands: AI employers answer the month after the demand; the player answers public-sector
##      demands through ECON_ANSWER_UNION_DEMAND (no answer by the deadline = talks failed). ACCEPT settles; a COUNTER
##      is taken or rejected by the union (militancy × mood); REFUSE fails the talks.
##   3. failed talks: the union decides to strike from militancy × mood × fund strength (weeks of strike pay) and the
##      law (UnionLaw.strike_check: ballot, public-sector ban → arbitration). Unlawful strikes are rarer and may be sued.
##   4. new demands when a union's mood passes its threshold (lower for militant leaders).
##   5. a rare general strike by the federation against a labour-law cut while 2+ big unions are in dispute.
## Outcomes: WON / ACCEPTED award the demand (union_pm wage premium as M9), COMPROMISE / COUNTER half; LOST raises mood,
## dips density and calls an early leader election. Arbitration (NO_STRIKE essential services, or the public-sector
## strike ban) awards ARBITRATION_PM.

const S := EconUtil.S
const UL := preload("res://sim/law/union_law.gd")
const DEMAND_MOOD := 55.0  # mood a moderate-average leader (militancy 50) needs to table a demand
const DEMAND_COOLDOWN_M := 12
const MAX_NEW_DEMANDS := 2
const DEADLINE_M := 2
const STRIKE_MAX_M := 6
const FARM_STRIKE_MAX_M := 2  # months a strike can hold the farms (at minimum service)
const GENERAL_WORK := 0.7
const GENERAL_GAP_M := 120
const GENERAL_P := 0.1
const BIG_UNION := 50  # persons
const PUBLIC_EMPLOYER := "gov"


static func _ud(world: WorldState) -> Dictionary:
	return world.table("union_demand")


# ------------------------------------------------------------------ queries / player action

## Demands an employer can answer now (OPEN, or STRIKE: an answer can end a strike), oldest first.
## employer "" = all; "gov" = the public sector (the player answers these while governing).
static func pending_demands(world: WorldState, employer: String = "") -> Array:
	var out: Array = []
	var t := world.peek("union_demand")
	for id in EconUtil.sorted_keys(t):
		var d: Dictionary = t[id]
		if d["status"] in ["OPEN", "STRIKE"] and (employer == "" or d["employer"] == employer):
			out.append(d)
	return out


## The union's current dispute (OPEN or STRIKE), or {}.
static func dispute_of(world: WorldState, union_id: String) -> Dictionary:
	for d in pending_demands(world):
		if d["union"] == union_id:
			return d
	return {}


static func strike_losses(world: WorldState, demand_id: String) -> int:
	return int(world.peek("union_demand").get(demand_id, {}).get("losses", 0))


static func validate_answer(world: WorldState, p: Dictionary) -> String:
	var did := str(p.get("demand", ""))
	var d: Dictionary = world.peek("union_demand").get(did, {})
	if d.is_empty():
		return "Unknown demand %s" % did
	if d["employer"] != PUBLIC_EMPLOYER:
		return "Only public-sector demands are answered by the Cabinet"
	if not d["status"] in ["OPEN", "STRIKE"]:
		return "This dispute is already over"
	var a := str(p.get("answer", ""))
	if not a in ["ACCEPT", "COUNTER", "REFUSE"]:
		return "Answer ACCEPT, COUNTER or REFUSE"
	if a == "COUNTER" and d["kind"] == "WAGE" and (int(p.get("counter_pm", 0)) <= 0 or int(p.get("counter_pm", 0)) >= int(d["size_pm"])):
		return "A counter-offer must be between 0 and %d‰" % int(d["size_pm"])
	if a == "REFUSE" and UL.must_bargain(world, Unions.at_employer(world, _a_public_org(world)).get("density_pm", 0)):
		return "The recognition law obliges the Cabinet to bargain: accept or make a counter-offer"
	return ""


static func apply_answer(world: WorldState, p: Dictionary) -> bool:
	if validate_answer(world, p) != "":
		return false
	var d: Dictionary = _ud(world)[str(p["demand"])]
	d["player_answer"] = str(p["answer"])
	d["counter_pm"] = int(p.get("counter_pm", int(d["size_pm"]) / 2))
	return true


# ------------------------------------------------------------------ monthly

static func monthly(world: WorldState) -> void:
	if EconUtil.off(world, "UNIONS_U2") or EconUtil.off(world, "UNIONS_U1"):
		return
	var rng := world.rng.stream("econ.unions.disputes")
	for d in pending_demands(world):
		if d["status"] == "STRIKE":
			_strike_month(world, d, rng)
	for d in pending_demands(world):
		if d["status"] == "OPEN":
			_talks(world, d, rng)
	_new_demands(world, rng)
	_general_strike(world, rng)


# ------------------------------------------------------------------ demands

static func _employer_for(world: WorldState, u: Dictionary) -> Dictionary:
	if "PUBLIC_SECTOR" in u["sectors"]:
		return {"id": PUBLIC_EMPLOYER, "name": "the Cabinet", "occ": "PUBLIC_SECTOR"}
	var best := ""
	var best_n := 0
	var best_occ := ""
	for oid in EconUtil.sorted_keys(world.table("org")):
		var o: Dictionary = world.table("org")[oid]
		if o["type"] in EconData.PUBLIC_TYPES or not (o["status"] in ["ACTIVE", "DISTRESSED"]):
			continue
		var occ_n: Dictionary = EconUnions._org_workforce(world, oid)["occ"]
		for occ in u["sectors"]:
			if int(occ_n.get(occ, 0)) > best_n:
				best_n = int(occ_n.get(occ, 0))
				best = oid
				best_occ = occ
	if best == "" or best_n < 5 * S:
		return {}
	return {"id": best, "name": str(world.table("org")[best].get("name", best)), "occ": best_occ}


static func _kind(world: WorldState, u: Dictionary) -> String:
	var occ: String = u["sectors"][0]
	var wage_g := EconUnions.wage_grievance(world, occ)
	var law_g := EconUnions.law_grievance(world, occ)
	if law_g > wage_g:
		var hits: Array = EconUtil.peek_st(world).get("union", {}).get("law_hits", [])
		if not hits.is_empty():
			match str(hits[hits.size() - 1].get("lever", "")):
				"ECON_UNION_RIGHTS": return "RECOGNITION"
				"LAW_SAFETY_STANDARD": return "SAFETY"
	if wage_g <= 0.0 and law_g <= 0.0 and int(u["mood"]) >= 50:
		return "JOBS"  # mood from layoffs alone
	return "WAGE"


static func _new_demands(world: WorldState, rng: RandomNumberGenerator) -> void:
	var made := 0
	for u in Unions.active(world):
		if made >= MAX_NEW_DEMANDS:
			break
		if u["federation"] or int(u["members"]) < 5 * S or not dispute_of(world, u["id"]).is_empty():
			continue
		if world.month - int(u.get("last_dispute_end", -999)) < DEMAND_COOLDOWN_M:
			continue
		var mil := float(u["leader"].get("militancy", 50))
		if float(u["mood"]) < DEMAND_MOOD - 0.3 * (mil - 50.0):
			continue
		var emp := _employer_for(world, u)
		if emp.is_empty():
			continue
		var kind := _kind(world, u)
		var size := 0
		if kind == "WAGE":
			size = clampi(int(round(20.0 + 0.5 * float(u["mood"]) * (0.6 + 0.8 * mil / 100.0))), 20, 100)
		var id := world.new_id("udemand")
		var d := {"id": id, "union": u["id"], "employer": emp["id"], "employer_name": emp["name"], "occ": emp["occ"], "kind": kind,
			"size_pm": size, "made": world.month, "deadline": world.month + DEADLINE_M, "status": "OPEN", "answer": "", "counter_pm": 0,
			"player_answer": "", "outcome": "", "award_pm": 0, "strike_start": -1, "strike_months": 0, "persons": 0, "losses": 0,
			"unlawful": false, "reasons": [], "lockout": false, "ended": -1}
		_ud(world)[id] = d
		made += 1
		_emit(world, "UNION_DEMAND", d, u, {"FAIRNESS": 2}, 25, {"size_pm": size, "deadline": d["deadline"]})


# ------------------------------------------------------------------ talks

static func _talks(world: WorldState, d: Dictionary, rng: RandomNumberGenerator) -> void:
	var u := Unions.get_union(world, d["union"])
	if u.is_empty() or u["status"] != "ACTIVE":
		_close(world, d, "FAILED", "STOOD_DOWN", 0)
		return
	var answer := ""
	# Cabinet (Wilma, user): a public-sector demand is answered by the Cabinet whoever governs — the player, or an AI
	# First Minister on the Labour Liaison's advice (OfficeFeed → ECON_ANSWER_UNION_DEMAND sets player_answer).
	# Only an AI government that gave no answer by the deadline falls back to the ideology rule.
	var human := EconEssentials.human_governs(world)
	if d["employer"] == PUBLIC_EMPLOYER and (human or str(d["player_answer"]) != ""):
		answer = str(d["player_answer"])
		if answer == "":
			if world.month < int(d["deadline"]):
				return  # waiting for the government (the player)
			answer = "REFUSE"  # no answer by the deadline: talks failed
	elif d["employer"] == PUBLIC_EMPLOYER and world.month < int(d["deadline"]):
		return  # waiting for the Cabinet's answer
	elif world.month <= int(d["made"]):
		return  # talks take a month
	else:
		answer = _ai_answer(world, d)
	d["answer"] = answer
	match answer:
		"ACCEPT":
			_settle(world, d, u, "ACCEPTED", int(d["size_pm"]))
		"COUNTER":
			if int(d["counter_pm"]) <= 0:
				d["counter_pm"] = int(d["size_pm"]) / 2
			var p_take := clampf(1.0 - 1.6 * float(u["leader"].get("militancy", 50)) / 100.0 * float(u["mood"]) / 100.0, 0.1, 0.95)
			if rng.randf() < p_take:
				_settle(world, d, u, "COUNTER", int(d["counter_pm"]))
			else:
				_talks_failed(world, d, u, rng)
		_:
			_talks_failed(world, d, u, rng)


## AI employer's answer: a company by profit, cash and its CEO's risk appetite; the AI government by ideology.
static func _ai_answer(world: WorldState, d: Dictionary) -> String:
	var dens := int(Unions.at_employer(world, d["employer"] if d["employer"] != PUBLIC_EMPLOYER else _a_public_org(world)).get("density_pm", 0))
	var must := UL.must_bargain(world, dens)
	var a := "REFUSE"
	if d["employer"] == PUBLIC_EMPLOYER:
		var lab := _gov_labour(world)
		a = "ACCEPT" if lab > 0.4 else ("COUNTER" if lab > -0.15 else "REFUSE")
	else:
		var o: Dictionary = world.table("org").get(d["employer"], {})
		if o.is_empty():
			return "REFUSE"
		var pl: Dictionary = o["pl_last"] if not o.get("pl_last", {}).is_empty() else o["pl"]
		var profit := EconFinance.profit(pl)
		var cost := float(d["size_pm"]) / 1000.0 * float(pl.get("wages", 0))
		var hard := int(o["ceo"].get("risk", 50)) >= 70
		if o["status"] != "ACTIVE" or profit <= 0:
			a = "REFUSE"
		elif d["kind"] != "WAGE":
			a = "COUNTER" if hard else "ACCEPT"
		elif cost <= 0.10 * float(profit):
			a = "COUNTER" if hard else "ACCEPT"
		elif cost <= 0.5 * float(profit):
			a = "REFUSE" if hard else "COUNTER"
	if a == "REFUSE" and must:
		a = "COUNTER"
	return a


## -1..1: the governing party's pro-labour position (LABOR + half REDISTRIBUTION); 0 without a government.
static func _gov_labour(world: WorldState) -> float:
	var pol: Dictionary = world.peek("pol")
	if pol.is_empty() or not pol.has("state"):
		return 0.0
	var who: Dictionary = GovBuilder._actor(world, pol["state"])
	if who.is_empty():
		return 0.0
	var pos: Dictionary = who["pos"]
	return clampf((float(pos.get("LABOR", 0)) + 0.5 * float(pos.get("REDISTRIBUTION", 0))) / 100000.0, -1.0, 1.0)


static func _a_public_org(world: WorldState) -> String:
	var cpw := EconFinance.org_by_key(world, "CPW")
	return cpw


static func _talks_failed(world: WorldState, d: Dictionary, u: Dictionary, rng: RandomNumberGenerator) -> void:
	_emit(world, "UNION_TALKS_FAILED", d, u, {"FAIRNESS": -3}, 30, {"answer": d["answer"]})
	# the strike decision: leader militancy × mood × fund strength, then the law
	var mil := float(u["leader"].get("militancy", 50)) / 100.0
	var fund_f := clampf(Unions.strike_weeks(world, u["id"]) / 4.0, 0.0, 1.0)
	var p := clampf(2.5 * mil * float(u["mood"]) / 100.0 * (0.5 + 0.5 * fund_f), 0.0, 0.95)
	var need := UL.ballot_needed_pm(world)
	var yes := -1
	if need > 0:
		yes = clampi(int(float(u["mood"]) * 10.0 * (0.7 + 0.6 * mil)), 0, 1000)
	var chk: Dictionary = UL.strike_check(world, u["id"], d["employer"], d["occ"], yes)
	d["reasons"] = chk["reasons"].duplicate()
	if not chk["lawful"]:
		if "PUBLIC_SECTOR_BAN" in chk["reasons"]:
			_arbitrate(world, d, u)  # the ban sends public-sector disputes to arbitration
			return
		p *= 0.3 * mil  # only a militant leadership risks an unlawful strike (and a suit)
		d["unlawful"] = true
	if rng.randf() >= p:
		u["mood"] = mini(100, int(u["mood"]) + 10)
		_close(world, d, "FAILED", "STOOD_DOWN", 0)
		return
	_start_strike(world, d, u, rng)


# ------------------------------------------------------------------ strikes

static func _struck_orgs(world: WorldState, d: Dictionary) -> Array:
	if d["employer"] != PUBLIC_EMPLOYER:
		return [d["employer"]] if world.table("org").has(d["employer"]) else []
	var out: Array = []
	for oid in EconUtil.sorted_keys(world.table("org")):
		var o: Dictionary = world.table("org")[oid]
		if o["type"] in EconData.PUBLIC_TYPES and o["status"] in ["ACTIVE", "DISTRESSED", "ADMINISTRATION"]:
			out.append(oid)
	return out


## Stops this month's struck workplaces (essential-services law as in EconUnions._strike); returns how many stopped.
static func _stop(world: WorldState, d: Dictionary) -> int:
	var ess_law := str(world.levers.get("LAW_ESSENTIAL_SERVICES", "NONE"))
	var n := 0
	for oid in _struck_orgs(world, d):
		for fid in EconUnions._org_workforce(world, oid)["facs"]:
			var f: Dictionary = world.table("facility")[fid]
			if f["mothball"]:
				continue
			var essential: bool = f["type"] in EconUnions.ESSENTIAL_TYPES
			if essential and ess_law == "NO_STRIKE" and not d["lockout"]:
				continue
			# food: strikers keep tending crops and animals (a minimum service), and the harvest cannot wait — farms leave
			# a strike after FARM_STRIKE_MAX_M months (a long public strike still means shortages, not a famine by itself)
			var farm: bool = f["type"] == "FARM" and not d["lockout"]
			if farm and int(d["strike_months"]) >= FARM_STRIKE_MAX_M:
				if str(f.get("stop_demand", "")) == d["id"]:
					f["stop_until"] = world.month - 1
					f.erase("stop_demand")
				continue
			f["stop_until"] = world.month + 1
			f["stop_kind"] = "LOCKOUT" if d["lockout"] else "STRIKE"
			f["stop_min"] = farm or (essential and ess_law == "MIN_SERVICE" and not d["lockout"])
			f["stop_demand"] = d["id"]
			n += 1
		var o: Dictionary = world.table("org")[oid]
		if o["is_contractor"] and EconLabor.staff_total(o["crew"]) > 0:
			o["stop_until"] = world.month + 1  # builders' crews (EconConstruction.capacity)
			o["stop_kind"] = "LOCKOUT" if d["lockout"] else "STRIKE"
			o["stop_demand"] = d["id"]
			n += 1
	return n


static func _unstop(world: WorldState, d: Dictionary) -> void:
	for fid in world.table("facility"):
		var f: Dictionary = world.table("facility")[fid]
		if str(f.get("stop_demand", "")) == d["id"]:
			f["stop_until"] = world.month - 1
			f.erase("stop_demand")
	for oid in world.table("org"):
		var o: Dictionary = world.table("org")[oid]
		if str(o.get("stop_demand", "")) == d["id"]:
			o["stop_until"] = world.month - 1
			o.erase("stop_demand")


static func _start_strike(world: WorldState, d: Dictionary, u: Dictionary, rng: RandomNumberGenerator) -> void:
	# a hard-line private employer answers with a lockout (M9 rule)
	if d["employer"] != PUBLIC_EMPLOYER:
		var o: Dictionary = world.table("org")[d["employer"]]
		if o["type"] == "PRIVATE":
			var rights := float(EconUtil.lever(world, "ECON_UNION_RIGHTS", 50))
			d["lockout"] = rng.randf() < float(o["ceo"]["risk"]) / 100.0 * (0.25 + 0.5 * (1.0 - rights / 100.0))
	if _stop(world, d) == 0:
		_arbitrate(world, d, u)  # every workplace is an essential service under NO_STRIKE
		return
	var persons := 0
	for oid in _struck_orgs(world, d):
		var occ_n: Dictionary = EconUnions._org_workforce(world, oid)["occ"]
		for occ in u["sectors"]:
			persons += int(float(occ_n.get(occ, 0)) * float(EconUnions.density(world, occ)) / 100000.0)
	d["persons"] = persons / S
	d["status"] = "STRIKE"
	d["strike_start"] = world.month
	var resp: Array = [["GOVERNMENT", "government", 0.7]]
	if d["employer"] != PUBLIC_EMPLOYER:
		resp = []
		for x in EconFacts.company_blame(world, d["employer"], 0.6):
			resp.append([x[0], x[1], float(x[2]) * 0.7])  # the employer side carries 70% of the blame, the union 30%
	resp.append(["UNION", u["id"], 0.3])
	var services: bool = d["employer"] == PUBLIC_EMPLOYER
	var impact := {"JOBS": -30, "FAIRNESS": -10, "COST_OF_LIVING": -15}
	if services:
		impact["PUBLIC_SERVICES"] = -60
	_emit(world, "UNION_STRIKE_CALLED", d, u, impact, clampi(35 + int(d["persons"]) / 3 + (10 if services else 0), 35, 85),
		{"persons": d["persons"], "unlawful": d["unlawful"], "general": false, "lockout": d["lockout"]}, resp)


static func _strike_month(world: WorldState, d: Dictionary, rng: RandomNumberGenerator) -> void:
	var u := Unions.get_union(world, d["union"])
	if u.is_empty() or u["status"] != "ACTIVE":
		_end_strike(world, d, {}, "LOST", 0)
		return
	d["strike_months"] = int(d["strike_months"]) + 1
	# losses: struck plants' lost output this month, valued at market price (other plants at their wage bill)
	var s := EconUtil.st(world)
	for fid in world.table("facility"):
		var f: Dictionary = world.table("facility")[fid]
		if str(f.get("stop_demand", "")) != d["id"]:
			continue
		var wf := EconUnions.work_factor(world, f)
		var good: String = EconData.RECIPES[f["type"]]["out"][0]
		var unit := float(s["prices"].get(good, 0))
		var lost_q := float(f.get("out_last", 0)) * (1.0 - wf) / maxf(wf, 0.1)
		d["losses"] = int(d["losses"]) + int(lost_q * unit / S) if unit > 0.0 else int(d["losses"]) + int((1.0 - wf) * float(EconLabor.staff_total(f["staff"])) / S * float(s["wage"]["G"]))
	# strike pay from the fund to the strikers' households
	var pay := int(d["persons"]) * Unions.strike_pay(world)
	var paid := _strike_pay(world, u, pay)
	d["underpaid_m"] = int(d.get("underpaid_m", 0)) + 1 if paid < pay else 0
	if int(d["underpaid_m"]) >= 2:  # the fund ran dry: members drift back within two months
		_end_strike(world, d, u, "LOST", 0, true)
		return
	# settlement
	var outcome := ""
	var m := float(d["strike_months"])
	if d["employer"] == PUBLIC_EMPLOYER and (EconEssentials.human_governs(world) or str(d["player_answer"]) != ""):
		match str(d["player_answer"]):  # the Cabinet's answer (player or AI First Minister); AI with none: ideology below
			"ACCEPT": outcome = "WON"
			"COUNTER":
				var p_take := clampf(0.3 + 0.15 * m - float(u["mood"]) / 300.0, 0.1, 0.95)
				if rng.randf() < p_take:
					outcome = "COMPROMISE"
				d["player_answer"] = ""
			_: d["player_answer"] = ""
	elif d["employer"] == PUBLIC_EMPLOYER:
		var lab := _gov_labour(world)
		if lab < -0.15 and rng.randf() < clampf(0.12 * m, 0.0, 0.8):
			outcome = "LOST"  # a market-minded government breaks the strike
		elif rng.randf() < clampf(0.15 * m * (1.0 + lab), 0.0, 0.9):
			outcome = "WON" if lab > 0.2 else "COMPROMISE"
	else:
		var o: Dictionary = world.table("org").get(d["employer"], {})
		if o.is_empty() or o["status"] in ["LIQUIDATION", "DISSOLVED"]:
			outcome = "LOST"
		else:
			var weak := world.ledger.balance(EconUtil.acct(d["employer"])) < 2 * EconFinance._monthly_costs(o)
			if weak:
				outcome = "WON"
			else:
				# a rich, profitable employer can outlast a union whose fund is thin; otherwise the sides settle
				var strong: bool = world.ledger.balance(EconUtil.acct(d["employer"])) >= 6 * EconFinance._monthly_costs(o) and EconFinance.profit(o["pl_last"] if not o.get("pl_last", {}).is_empty() else o["pl"]) > 0
				var fund_f := clampf(Unions.strike_weeks(world, u["id"]) / 8.0, 0.0, 1.0)
				var r := rng.randf()
				if strong and r < clampf(0.12 * m * (1.2 - fund_f), 0.0, 0.8):
					outcome = "LOST"
				elif rng.randf() < clampf(0.15 * m, 0.0, 0.8):
					outcome = "COMPROMISE" if rng.randf() < 0.65 else "WON"
	if outcome == "" and int(d["strike_months"]) >= STRIKE_MAX_M:
		outcome = "LOST"  # the members drift back
	if outcome != "":
		var award := 0
		if d["kind"] == "WAGE":
			award = int(d["size_pm"]) if outcome == "WON" else (int(d["size_pm"]) / 2 if outcome == "COMPROMISE" else 0)
		_end_strike(world, d, u, outcome, award)
	else:
		_stop(world, d)  # the strike goes on


## Pays strike pay to the households of the union's members (by their employment); returns what was paid.
static func _strike_pay(world: WorldState, u: Dictionary, amount: int) -> int:
	var have := world.ledger.balance(u["acct"])
	var amt := mini(amount, maxi(0, have))
	if amt <= 0:
		return 0
	var gids: Array = []
	var w: Array = []
	for gid in EconUtil.sorted_keys(world.table("hh")):
		var e: Dictionary = world.table("hh")[gid].get("emp", {})
		var n := 0
		for occ in u["sectors"]:
			n += int(e.get(occ, 0))
		if n > 0:
			gids.append(gid)
			w.append(n)
	if gids.is_empty():
		return 0
	var parts := EconUtil.split_lr(amt, w)
	var paid := 0
	for i in gids.size():
		if int(parts[i]) > 0:
			paid += EconUtil.pay_upto(world, u["acct"], EconUtil.hh_acct(gids[i]), int(parts[i]), "STRIKE_PAY")
	return paid


static func _end_strike(world: WorldState, d: Dictionary, u: Dictionary, outcome: String, award: int, collapsed: bool = false) -> void:
	_unstop(world, d)
	if collapsed and not u.is_empty():
		_emit(world, "UNION_STRIKE_COLLAPSED", d, u, {"FAIRNESS": -5}, 40, {"strike_months": d["strike_months"],
			"fund_left": world.ledger.balance(u["acct"]) / S})
	if not u.is_empty():
		_settle(world, d, u, outcome, award)
	else:
		_close(world, d, "FAILED", outcome, 0)
	if d["unlawful"] and int(d["losses"]) > 0:
		UL.sue_unlawful_strike(world, d["employer"], d["union"], int(d["losses"]), d["reasons"])


# ------------------------------------------------------------------ settlement

static func _settle(world: WorldState, d: Dictionary, u: Dictionary, outcome: String, award: int) -> void:
	d["award_pm"] = award
	if outcome in ["ACCEPTED", "COUNTER", "WON", "COMPROMISE", "ARBITRATED"]:
		# a settlement relieves the grievance it answered (fading over Unions.RELIEF_M months): wages are now judged
		# against the last settlement, not against the slump
		u["relief"] = clampi(10 + award / 2, 10, 50) if d["kind"] == "WAGE" else 15  # mood points (int: saved state holds no floats)
		u["relief_m"] = world.month
	if award > 0:
		for oid in _struck_orgs(world, d):
			var o: Dictionary = world.table("org")[oid]
			o["union_pm"] = mini(EconUnions.UNION_PM_MAX, int(o.get("union_pm", 0)) + award)
	var mood_shift := {"ACCEPTED": -20, "COUNTER": -10, "WON": -25, "COMPROMISE": -12, "ARBITRATED": -10, "LOST": 15}
	u["mood"] = clampi(int(u["mood"]) + int(mood_shift.get(outcome, 0)), 0, 100)
	if d["status"] == "STRIKE" or outcome in ["WON", "COMPROMISE", "LOST"]:
		u["last_strike_result"] = outcome if outcome in ["WON", "COMPROMISE", "LOST"] else u["last_strike_result"]
	if outcome == "LOST":
		u["lost_strikes"] = int(u["lost_strikes"]) + 1
		u["election_due"] = mini(int(u["election_due"]), world.month + 1)
		var un: Dictionary = EconUtil.st(world).get("union", {})
		for occ in u["sectors"]:
			if un.get("density", {}).has(occ):
				un["density"][occ] = int(float(un["density"][occ]) * 0.92)
	elif outcome == "WON":
		u["leader"]["militancy"] = mini(95, int(u["leader"].get("militancy", 50)) + 5)
	_close(world, d, "SETTLED" if outcome != "LOST" else "FAILED", outcome, award)
	_emit(world, "UNION_SETTLED", d, u, {"FAIRNESS": 5 if award > 0 else -3}, 30 if int(d["strike_months"]) == 0 else 45,
		{"outcome": outcome, "award_pm": award, "strike_months": d["strike_months"]})


static func _arbitrate(world: WorldState, d: Dictionary, u: Dictionary) -> void:
	var award := EconUnions.ARBITRATION_PM if d["kind"] == "WAGE" else 0
	EconFacts.emit(world, "ECON_ARBITRATION", null, [["UNION", u["id"]]], [["GOVERNMENT", "government", 1.0]],
		{"FAIRNESS": -5, "INFRASTRUCTURE": 5}, 30, "PUBLIC", {"org": d["employer"], "union": u["id"], "name": u["name"],
		"persons": d["persons"], "award_pm": award, "demand": d["id"]})
	_settle(world, d, u, "ARBITRATED", award)


static func _close(world: WorldState, d: Dictionary, status: String, outcome: String, award: int) -> void:
	d["status"] = status
	d["outcome"] = outcome
	d["award_pm"] = award
	d["ended"] = world.month
	var u := Unions.get_union(world, d["union"])
	if not u.is_empty():
		u["last_dispute_end"] = world.month


# ------------------------------------------------------------------ general strike

static func _general_strike(world: WorldState, rng: RandomNumberGenerator) -> void:
	var fed := Unions.federation(world)
	if fed.is_empty() or world.month - int(fed.get("last_general", -9999)) < GENERAL_GAP_M:
		return
	var rights_cut := false
	for h in EconUtil.peek_st(world).get("union", {}).get("law_hits", []):
		if str(h.get("lever", "")) in ["ECON_UNION_RIGHTS", "ECON_MIN_WAGE"] and world.month - int(h["m"]) < 12:
			rights_cut = true
	if not rights_cut:
		return
	var big := 0
	for d in pending_demands(world):
		var u := Unions.get_union(world, d["union"])
		if not u.is_empty() and int(u["members"]) >= BIG_UNION * S:
			big += 1
	if big < 2 or rng.randf() >= GENERAL_P:
		return
	fed["last_general"] = world.month
	var ess_law := str(world.levers.get("LAW_ESSENTIAL_SERVICES", "NONE"))
	var n := 0
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["mothball"] or int(f.get("stop_until", -1)) >= world.month:
			continue
		if f["type"] in EconUnions.ESSENTIAL_TYPES and ess_law == "NO_STRIKE":
			continue
		f["stop_until"] = world.month
		f["stop_kind"] = "GENERAL"
		n += 1
	EconFacts.emit(world, "UNION_STRIKE_CALLED", null, [["UNION", fed["id"]]], [["GOVERNMENT", "government", 0.7], ["UNION", fed["id"], 0.3]],
		{"JOBS": -40, "PUBLIC_SERVICES": -40, "FAIRNESS": -10, "GOVERNANCE": -20}, 90, "PUBLIC",
		{"name": fed["name"], "union": fed["id"], "employer": "ALL", "employer_name": "every employer", "kind": "LAW", "demand": "",
		"persons": int(fed["members"]) / S, "unlawful": false, "general": true, "workplaces": n})


# ------------------------------------------------------------------ facts

static func _emit(world: WorldState, type: String, d: Dictionary, u: Dictionary, impact: Dictionary, mag: int, extra: Dictionary,
		resp: Array = []) -> void:
	var data := {"name": u["name"], "union": u["id"], "employer": d["employer"], "employer_name": d["employer_name"], "kind": d["kind"],
		"demand": d["id"]}
	for k in extra:
		data[k] = extra[k]
	var subj: Array = [["UNION", u["id"]]]
	if d["employer"] != PUBLIC_EMPLOYER and world.peek("org").has(d["employer"]):
		subj.append(["COMPANY", d["employer"]])
	if resp.is_empty():
		resp = [["UNION", u["id"], 0.5], ["GOVERNMENT" if d["employer"] == PUBLIC_EMPLOYER else "COMPANY", "government" if d["employer"] == PUBLIC_EMPLOYER else d["employer"], 0.5]]
	EconFacts.emit(world, type, null, subj, resp, impact, mag, "PUBLIC", data)

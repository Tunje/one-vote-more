class_name UnionPolitics
extends RefCounted
## Unions in politics (A41, planning/spec-unions-v1.md §3; Ella's half, spec-election-year-v1.md §10).
## Owner: Ella. Each union (Bob's U1 table "union") and the federation endorses a party of its own; a governing
## party that cuts labour law betrays the unions that backed it. Unions give money in election years and volunteers
## in campaigns. Before unions exist (or with "UNIONS_U1" off) PartyLife keeps the M9 single "union" endorsement.
##
## State: table "union_pol", row "s":
##   {scanned_to: month, rec: {pid: [[month, w]]}, picks: {union_id: pid}, grudge: {union_id: {pid: [[month, w]]}}}
## rec = the party's labour record (+ pro-labour, - cuts); cabinet enactments count fully, opposition NO votes on
## labour bills at OPPOSITION_WEIGHT. Record and grudges fade linearly over MEMORY_MONTHS.
## Facts: UNION_ENDORSED {union, party, prev, score}, UNION_ENDORSEMENT_WITHDRAWN {union, party, reason, size},
## POL_DONATION from a union (data.donor = union id, donor_kind "UNION").

const Det := preload("res://sim/staff/det.gd")
const LQ := preload("res://sim/law/law_query.gd")
const UnionLaw := preload("res://sim/law/union_law.gd")

const MEMORY_MONTHS := 96          # record and betrayal grudges fade linearly over 8 years
const OPPOSITION_WEIGHT := 0.5     # an opposition NO vote on a labour bill counts half an enactment
const RECORD_PTS := 12.0           # score points per unit of labour record (one typical law change ~ 0.5..2 units)
const GRUDGE_PTS := 35.0           # score points per unit of betrayal, fading
const TIE_PTS := 15.0              # the party is the union's own (kind UNION) or its leader came from the union
const VIABLE_PTS := 0.3            # per percentage point of support: unions back parties that can win
const MIN_SCORE := 10.0            # below this a union endorses nobody
const MODERATE_MIN := 25.0         # the moderate unions (Unions.MODERATE sectors) are pickier
const STICKY := 8.0                # a rival must beat the current pick by this much to take the endorsement
const LABOR_LEVERS := ["ECON_UNION_RIGHTS", "ECON_MIN_WAGE", "LAW_SAFETY_STANDARD", "ECON_UNEMPLOYMENT_BENEFIT_RATE",
	"ECON_PUBLIC_PAY_INDEX"]       # higher = better for workers (EconUnions.LABOR_LEVERS)
## How much each labour lever matters to a union's members: lever -> {sector: weight, "*": default}. The federation
## uses FED_RELEVANCE. A miner cares about safety, a shop worker about the minimum wage, a public servant about public pay.
const RELEVANCE := {
	"ECON_UNION_RIGHTS": {"*": 1.0},
	"ECON_MIN_WAGE": {"*": 1.0, "SERVICES": 1.5, "AGRICULTURE": 1.5, "PUBLIC_SECTOR": 0.5, "PROFESSIONAL": 0.3},
	"LAW_SAFETY_STANDARD": {"*": 0.6, "MINING": 1.5, "CONSTRUCTION": 1.5, "MANUFACTURING": 1.3, "AGRICULTURE": 1.0},
	"ECON_UNEMPLOYMENT_BENEFIT_RATE": {"*": 0.8},
	"ECON_PUBLIC_PAY_INDEX": {"*": 0.0, "PUBLIC_SECTOR": 1.5},
}
const FED_RELEVANCE := {"ECON_UNION_RIGHTS": 1.0, "ECON_MIN_WAGE": 1.0, "LAW_SAFETY_STANDARD": 0.8,
	"ECON_UNEMPLOYMENT_BENEFIT_RATE": 0.8, "ECON_PUBLIC_PAY_INDEX": 0.4}
const BETRAY_MIN := 1.5            # a union walks out only over a cut that matters to it (weighted labour value <= -1.5)
const DONATE_SHARE := 0.08         # of a union's spare fund, per quarter of an election year
const BETRAY_DISCONTENT := 25      # the labour-side faction of a betraying party
const MOB_FED := 0.5               # campaign volunteers: the federation's pick gets MOB_UNION x this ...
const MOB_SECTOR := 1.5            # ... plus MOB_UNION x this x the endorsing unions' share of all members


static func on(world: WorldState) -> bool:
	return not EconUtil.off(world, "UNIONS_U1") and not EconUtil.off(world, "UNION_POLITICS") and not Unions.active(world).is_empty()


static func _s(world: WorldState) -> Dictionary:
	var t := world.table("union_pol")
	if not t.has("s"):
		t["s"] = {"scanned_to": world.month - 1, "rec": {}, "picks": {}, "grudge": {}}
	return t["s"]


static func _peek_s(world: WorldState) -> Dictionary:
	return world.peek("union_pol").get("s", {})


static func picks(world: WorldState) -> Dictionary:
	return _peek_s(world).get("picks", {})


# ======================================================================= monthly (POLITICS, party life)

static func monthly(world: WorldState, st: Dictionary) -> void:
	if not on(world):
		return
	var s := _s(world)
	_scan_record(world, st, s)
	var c := Campaign.current(world)
	if world.month_of_year() == 1 or (not c.is_empty() and int(c.get("opened", -1)) == world.month):
		for u in Unions.active(world):
			review(world, st, u)
	if not c.is_empty() and world.month % 3 == 0:
		_donate(world, s)


## Labour bills and ordinances since the last scan (one-month lag: bills pass later in POLITICS than this runs).
static func _scan_record(world: WorldState, st: Dictionary, s: Dictionary) -> void:
	var from := int(s["scanned_to"]) + 1
	var to := world.month - 1
	if to < from:
		return
	s["scanned_to"] = to
	var cabinet: Array = st.get("government", {}).get("members", [])
	for kind in ["POL_BILL_PASSED", "POL_BILL_DEFEATED"]:
		for f in world.facts.query(kind, from, to):
			var b: Dictionary = world.peek("bill").get(String(f["data"].get("bill", "")), {})
			if b.is_empty():
				continue
			var lab := labour_values(world, b.get("clauses", []))
			if lab.is_empty():
				continue
			var cab: Array = cabinet if String(b.get("sponsor", "")) in cabinet else [String(b.get("sponsor", ""))]
			var votes: Dictionary = b.get("votes", {})
			var enactors: Array = []
			for pid in Det.ordered(votes):
				if pid in cab:
					if kind == "POL_BILL_PASSED":
						_record(world, st, s, pid, lab, 1.0, false)
						enactors.append(pid)
				elif String(votes[pid]) == "NO":
					_record(world, st, s, pid, lab, -OPPOSITION_WEIGHT, false)
			_betray_all(world, st, enactors, lab)
	for f in world.facts.query("POL_ORDINANCE_ISSUED", from, to):
		var cl: Array = f["data"].get("clauses", [])
		var lab := labour_values(world, cl)
		if not lab.is_empty():
			for pid in cabinet:
				_record(world, st, s, pid, lab, 1.0, false)
			_betray_all(world, st, cabinet, lab)


## Record per lever: rows [month, milli-value, lever]. weight: 1 for an enactment, -OPPOSITION_WEIGHT for a NO vote.
static func _record(world: WorldState, st: Dictionary, s: Dictionary, pid: String, vals: Dictionary, weight: float, enacted: bool = true) -> void:
	var rec: Array = s["rec"].get(pid, [])
	for lid in Det.ordered(vals):
		rec.append([world.month, int(round(float(vals[lid]) * weight * 1000.0)), lid])
	s["rec"][pid] = rec
	if enacted:
		betray(world, st, pid, vals)


## Every party that enacted it answers for the cut: a union backing any of them walks out and holds it against all
## of them, so it does not hop to a coalition partner that just voted the same cut through.
static func _betray_all(world: WorldState, st: Dictionary, enactors: Array, vals: Dictionary) -> void:
	for pid in enactors:
		betray(world, st, String(pid), vals, enactors)


## How much lever lid matters to union u (0..1.5).
static func relevance(u: Dictionary, lid: String) -> float:
	if u.get("federation", false):
		return float(FED_RELEVANCE.get(lid, 1.0))
	var t: Dictionary = RELEVANCE.get(lid, {"*": 1.0})
	var best := -1.0
	for occ in u.get("sectors", []):
		best = maxf(best, float(t.get(occ, t["*"])))
	return float(t["*"]) if best < 0.0 else best


## Union u's weighted view of a set of lever moves {lever: signed value}.
static func union_value(u: Dictionary, vals: Dictionary) -> float:
	var v := 0.0
	for lid in vals:
		v += relevance(u, lid) * float(vals[lid])
	return v


## Signed labour value of a set of clauses: + raises workers' protections, - cuts them. ~0.5..2 per lever moved.
static func labour_value(world: WorldState, clauses: Array) -> float:
	var v := 0.0
	var vals := labour_values(world, clauses)
	for lid in vals:
		v += float(vals[lid])
	return v


## Per lever: {lever: signed value}; levers that did not move are left out.
static func labour_values(world: WorldState, clauses: Array) -> Dictionary:
	var out := {}
	for c in clauses:
		var lid := String(c.get("lever", ""))
		if not lid in LABOR_LEVERS or not world.lever_defs.has(lid):
			continue
		var def: Dictionary = world.lever_defs[lid]
		var d := Legislature.clause_delta(def, c)
		if d == 0.0:
			continue
		var span := 1.0
		if def.get("type", "NUMBER") == "ENUM":
			span = maxf(1.0, float(def.get("values", []).size() - 1))
		else:
			var r: Array = def.get("range", [0, 100])
			span = maxf(1.0, float(r[1]) - float(r[0]))
		out[lid] = float(out.get(lid, 0.0)) + signf(d) * clampf(0.5 + 6.0 * absf(d) / span, 0.5, 2.0)
	return out


## Sum of rows [month, milli-value(, lever)] fading linearly over MEMORY_MONTHS; with u, each row weighted by the
## lever's relevance to that union.
static func _faded(rows: Array, month: int, u: Dictionary = {}) -> float:
	var t := 0.0
	for r in rows:
		var age := month - int(r[0])
		if age < MEMORY_MONTHS:
			var rel := 1.0 if u.is_empty() or r.size() < 3 else relevance(u, String(r[2]))
			t += rel * float(r[1]) / 1000.0 * (1.0 - float(age) / float(MEMORY_MONTHS))
	return t


static func _prune(rows: Array, month: int) -> Array:
	return rows.filter(func(r): return month - int(r[0]) < MEMORY_MONTHS)


## A cabinet party enacted labour-law moves {lever: signed value}: each union that endorsed it and counts them as a
## cut that matters (its weighted value <= -BETRAY_MIN) withdraws, remembers, and looks again.
static func betray(world: WorldState, st: Dictionary, pid: String, vals: Dictionary, partners: Array = []) -> void:
	var s := _s(world)
	var p: Dictionary = world.table("party").get(pid, {})
	var hit := false
	for u in Unions.active(world):
		var uid := String(u["id"])
		if String(s["picks"].get(uid, "")) != pid:
			continue
		var size := -union_value(u, vals)
		if size < BETRAY_MIN:
			continue
		hit = true
		s["picks"].erase(uid)
		var g: Dictionary = s["grudge"].get(uid, {})
		for gp in ([pid] + partners.filter(func(x): return String(x) != pid)):
			var rows: Array = g.get(String(gp), [])
			rows.append([world.month, int(round(size * 1000.0))])
			g[String(gp)] = rows
		s["grudge"][uid] = g
		var levers: Array = Det.ordered(vals).filter(func(l): return float(vals[l]) < 0.0)
		_fact(world, "UNION_ENDORSEMENT_WITHDRAWN", u, pid, 65,
			{"union": uid, "party": pid, "reason": "BETRAYAL", "size": int(round(size * 1000.0)), "levers": levers})
		review(world, st, u)
	if hit and not p.is_empty():
		PartyLife.ensure_factions(p)
		var fs: Array = p["factions"]
		var fi := 1 - int(p["leader"]["faction"])
		if String(p["faction_axis"]) == "LABOR":
			fi = 0 if int(fs[0]["pole"]) > int(fs[1]["pole"]) else 1   # the pro-labour wing
			fs[fi]["discontent"] = mini(100, int(fs[fi]["discontent"]) + BETRAY_DISCONTENT)
		else:
			fs[fi]["discontent"] = mini(100, int(fs[fi]["discontent"]) + BETRAY_DISCONTENT / 2)


## Does party p lean toward labour on union u's terms (LABOR + the union's REDISTRIBUTION weight > 0)?
static func pro_labour(u: Dictionary, p: Dictionary) -> bool:
	var red_w := 0.5 if "PUBLIC_SECTOR" in u.get("sectors", []) else 0.25
	return float(p["positions"]["LABOR"]) + red_w * float(p["positions"]["REDISTRIBUTION"]) > 0.0


## How much union u likes party p (score points). Read-only.
static func score(world: WorldState, u: Dictionary, p: Dictionary, s: Dictionary = {}) -> float:
	if s.is_empty():
		s = _peek_s(world)
	var pos: Dictionary = p["positions"]
	var red_w := 0.5 if "PUBLIC_SECTOR" in u.get("sectors", []) else 0.25
	var ideo := float(pos["LABOR"]) / 1000.0 + red_w * float(pos["REDISTRIBUTION"]) / 1000.0
	var mil := float(u.get("leader", {}).get("militancy", 50))
	var sc := ideo * (0.75 + mil / 200.0)
	var pid := String(p["id"])
	sc += RECORD_PTS * _faded(s.get("rec", {}).get(pid, []), world.month, u)
	sc -= GRUDGE_PTS * _faded(s.get("grudge", {}).get(String(u["id"]), {}).get(pid, []), world.month)
	if _tied(world, u, p):
		sc += TIE_PTS
	sc += VIABLE_PTS * float(p.get("support", 0)) / 1000.0
	return sc


static func _tied(world: WorldState, u: Dictionary, p: Dictionary) -> bool:
	var uid := String(u["id"])
	var fed: Dictionary = Unions.federation(world)
	var fid := "" if fed.is_empty() else String(fed["id"])
	for key in [String(p.get("union", "")), String(p.get("leader", {}).get("union", ""))]:
		if key != "" and (key == uid or (u.get("federation", false) and key == fid) or (key == fid and String(u.get("affiliated_to", "")) == fid)):
			return true
	return false


static func _moderate(u: Dictionary) -> bool:
	for occ in u.get("sectors", []):
		if occ in Unions.MODERATE:
			return true
	return false


## Re-decide union u's endorsement (January, campaign opening, after a betrayal).
static func review(world: WorldState, _st: Dictionary, u: Dictionary) -> void:
	var s := _s(world)
	var uid := String(u["id"])
	for pid in Det.ordered(s["rec"]):
		s["rec"][pid] = _prune(s["rec"][pid], world.month)
	var g: Dictionary = s["grudge"].get(uid, {})
	for pid in Det.ordered(g):
		g[pid] = _prune(g[pid], world.month)
	var cur := String(s["picks"].get(uid, ""))
	var best := ""
	var best_sc := -INF
	var cur_sc := -INF
	for p in PartyLife.active(world):
		if int(p["support"]) < PartyLife.THRESHOLD and int(p["seats"]) <= 0:
			continue
		if not pro_labour(u, p):
			continue   # a union never backs a party that leans against labour, however big or tied
		var sc := score(world, u, p, s)
		if p["id"] == cur:
			cur_sc = sc
		if sc > best_sc:
			best_sc = sc
			best = p["id"]
	var floor_sc := MODERATE_MIN if _moderate(u) else MIN_SCORE
	if cur != "" and cur_sc >= floor_sc and best_sc < cur_sc + STICKY:
		return
	if best != "" and best_sc < floor_sc:
		best = ""
	if best == cur:
		return
	if best == "":
		s["picks"].erase(uid)
		_fact(world, "UNION_ENDORSEMENT_WITHDRAWN", u, cur, 45, {"union": uid, "party": cur, "reason": "NO_MATCH", "size": 0})
		return
	s["picks"][uid] = best
	_fact(world, "UNION_ENDORSED", u, best, 50, {"union": uid, "party": best, "prev": cur, "score": int(round(best_sc))})


static func _fact(world: WorldState, type: String, u: Dictionary, pid: String, mag: int, data: Dictionary) -> void:
	var d := data.duplicate()
	d["channel"] = "UNION"
	d["federation"] = bool(u.get("federation", false))
	var subj: Array = [{"kind": "UNION", "id": String(u["id"])}]
	if pid != "":
		subj.append({"kind": "PARTY", "id": pid})
	world.add_fact({"type": type, "owner": "pol", "subjects": subj,
		"responsible": [{"actor": {"kind": "UNION", "id": String(u["id"])}, "share": 1.0}], "impact": {},
		"magnitude": mag, "visibility": "PUBLIC", "data": d})


# ======================================================================= money and volunteers

## Election year, quarterly: unions give to the party they endorse, openly and within the law
## (cap, the political levy's opt-out share; never from a striking union's fund or its strike reserve).
static func _donate(world: WorldState, s: Dictionary) -> void:
	var levy := UnionLaw.levy_share(world)
	for u in Unions.active(world):
		var uid := String(u["id"])
		var pid := String(s["picks"].get(uid, ""))
		if pid == "" or _striking(world, uid) or not world.ledger.has_account("party:" + pid):
			continue
		var amount := int(float(Unions.spare_fund(world, uid)) * DONATE_SHARE * levy)
		if amount < EconUnions.DONATION_MIN:
			continue
		var chk: Dictionary = LQ.donation_allowed(world, amount, uid)
		if not chk.get("ok", true):
			var cap := int(chk.get("cap", -1))
			amount = int(chk.get("remaining", 0)) - maxi(0, cap) / 10   # unions stay 10% under the cap
			if amount < EconUnions.DONATION_MIN:
				continue
			chk = LQ.donation_allowed(world, amount, uid)
			if not chk.get("ok", true):
				continue
		if not world.ledger.transfer(String(u["acct"]), "party:" + pid, amount, "DONATION", world.month):
			continue
		world.add_fact({"type": "POL_DONATION", "owner": "pol",
			"subjects": [{"kind": "PARTY", "id": pid}, {"kind": "UNION", "id": uid}],
			"responsible": [{"actor": {"kind": "PARTY", "id": pid}, "share": 1.0}], "impact": {},
			"magnitude": 20, "visibility": "PUBLIC",
			"data": {"donor": uid, "donor_kind": "UNION", "party": pid, "amount": amount, "lawful": true, "cap": int(chk.get("cap", -1))}})


static func _striking(world: WorldState, uid: String) -> bool:
	return String(UnionDisputes.dispute_of(world, uid).get("status", "")) == "STRIKE"   # Bob's U2


## Campaign volunteers for party pid, in MOB_UNION units (Campaign._ground adds MOB_UNION x this).
static func mob_units(world: WorldState, pid: String) -> float:
	var pk := picks(world)
	var total := 0.0
	var mine := 0.0
	var fed := 0.0
	for u in Unions.active(world):
		if u["federation"]:
			if String(pk.get(String(u["id"]), "")) == pid:
				fed = MOB_FED
			continue
		total += float(u["members"])
		if String(pk.get(String(u["id"]), "")) == pid:
			mine += float(u["members"])
	return fed + (MOB_SECTOR * mine / total if total > 0.0 else 0.0)


# ======================================================================= the vote model

## Endorsements for PartyLife.endorsements: per union, the federation (legacy key "union"), and per occupation the
## sector union's pick. Read-only.
static func endorsements(world: WorldState) -> Dictionary:
	var pk := picks(world)
	var fed: Dictionary = Unions.federation(world)
	var out := {"unions": pk.duplicate(), "federation": "" if fed.is_empty() else String(pk.get(String(fed["id"]), "")), "occ_pick": {}}
	out["union"] = out["federation"]
	for u in Unions.active(world):
		if u["federation"]:
			continue
		var pid := String(pk.get(String(u["id"]), ""))
		for occ in u["sectors"]:
			var own: Dictionary = Unions.of_occ(world, occ)
			if not own.is_empty() and String(own["id"]) == String(u["id"]):
				out["occ_pick"][occ] = pid
	return out


## {party_id: utility} for one cell's union members: 2/3 from their own union's pick, 1/3 from the federation's
## (the whole of it to whichever exists when only one does; the same party gets both shares).
static func union_bonus(cell: Dictionary, e: Dictionary, beta: float) -> Dictionary:
	var out := {}
	var d := float(e["density"].get(cell["occ"], 0)) / 100000.0
	if d <= 0.0:
		return out
	var own := String(e.get("occ_pick", {}).get(cell["occ"], ""))
	var fed := String(e.get("federation", ""))
	if own != "" and fed != "":
		out[own] = beta * d * 2.0 / 3.0
		out[fed] = float(out.get(fed, 0.0)) + beta * d / 3.0
	elif own != "":
		out[own] = beta * d
	elif fed != "":
		out[fed] = beta * d
	return out

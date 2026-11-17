extends RefCounted
## P1c police: misconduct, oversight, trust in the police, political arrests, station news
## (planning/design-p1-crime-police.md §3–§5). Owner: Anni (law). Preload it (no class_name).
##
## Runs monthly from the law JUSTICE step after the crime model, while Bob's stations run (meta["on"] "POLICE").
##   MISCONDUCT  per station and kind: an M11 record (LawOps.record_greed, org = the police) starts at a small chance
##               scaled by station stress, LAW_POLICE_POWERS and size; it lasts until it stops (P_STOP) or is found.
##               Found through channel OVERSIGHT (JusticeOps.detect_p): the complaints authority, victims, whistleblowers.
##               A reveal (misconduct_revealed, called from JusticeOps._reveal_violation) makes
##               LAW_POLICE_MISCONDUCT_REVEALED, a TORT for the victims paid by the treasury, a trust shock in the
##               district and, for a repeat within REPEAT_MONTHS, LAW_POLICE_INQUIRY_OPENED.
##   TRUST       per voter cell c["trust_police"] 0..100000, drifting toward a target from clearance, misconduct and
##               the powers law against the cell's INSTITUTIONS view. trust_pm(world, d) feeds crime.gd cooperation.
##   ARRESTS     order_investigation(world, actor, target, reason, force): the lawful referral (an investigation only
##               if the target party has hidden party-finance violations) or, with force, the always-unlawful
##               POLITICAL_ARREST (charter right). ai_monthly lets a cornered order-minded AI government try it.
##   STATIONS    LAW_POLICE_STATION_OPENED / _CLOSED from Bob's EconQuery.police, diffed month to month.

const L := preload("res://sim/law/law_data.gd")
const LawOps := preload("res://sim/law/law_ops.gd")
const Det := preload("res://sim/staff/det.gd")

const GOVERNMENT := {"kind": "GOVERNMENT", "id": "government"}

# --- misconduct
const P_START := {"IMPROPER_SEARCH": 0.010, "UNLAWFUL_DETENTION": 0.005, "EXCESSIVE_FORCE": 0.005, "POLICE_CORRUPTION": 0.004}
const P_STOP := 0.2                      # a month an active misconduct pattern ends by itself
const STRESS_MULT := 2.0                 # × (1 + STRESS_MULT × stress‰/1000)
const STRESS_FORCE_MULT := 2.0           # EXCESSIVE_FORCE: ×2 more while the station's workload is a stress level (WK)
const POWERS_REF := 40
const POWERS_MISCONDUCT_MAX := 3.0       # at 100 powers
const POWERS_MISCONDUCT_MIN := 0.6       # at 0 powers
const OFFICERS_REF := 10                 # rates are per 10 officers
const TORT_WREF := {"UNLAWFUL_DETENTION": 4.0, "EXCESSIVE_FORCE": 6.0, "IMPROPER_SEARCH": 1.0, "POLICE_CORRUPTION": 0.0}
const REPEAT_MONTHS := 60
const REVEAL_MAGNITUDE := 40
# --- oversight (JusticeOps.detect_ctx / detect_p, channel OVERSIGHT)
const OVERSIGHT_CASE_COST := 1000        # milli-W_ref per investigation a month
const P_FIND_PER_CASE := 0.08            # per investigation a month, capped
const P_FIND_MAX := 0.6
const P_VICTIM_COMPLAINT := 0.03         # victims complain and are heard even without an authority
# --- trust
const TRUST_START := 60000
const TRUST_DRIFT := 0.05
const TRUST_CLEAR_W := 20000             # ± at clearance 0 / 2× the base
const TRUST_SHOCK := 15000               # per revealed misconduct in the district
const TRUST_SHOCK_DECAY := 0.9
const TRUST_POWERS_W := 15000            # at powers 100 for a fully liberty- (−) or order-minded (+) voter
# --- political arrests
const DETAIN_MONTHS := [2, 6]
const AI_P := 0.01                       # a month, once every condition holds
const AI_INSTITUTIONS_MAX := -40000      # the governing party's INSTITUTIONS position (milli)
const PRETEXTS := ["fraud", "incitement", "tax evasion", "illegal assembly"]


static func on(world: WorldState) -> bool:
	var on_list: Array = world.meta.get("on", [])
	var off_list: Array = world.meta.get("off", [])
	return on_list.has("POLICE") and not off_list.has("POLICE")


static func state(world: WorldState) -> Dictionary:
	var s := LawOps.state(world)
	if not s.has("police"):
		s["police"] = {}
	var p: Dictionary = s["police"]
	for k in ["records", "shock", "stations", "detained", "arrests", "repeats"]:
		if not p.has(k):
			p[k] = {} if k != "arrests" else []
	return p


static func _peek(world: WorldState) -> Dictionary:
	return world.peek("law_state").get("s", {}).get("police", {})


static func ensure_rules(world: WorldState) -> void:
	var s := LawOps.state(world)
	if s.get("police_rules", false):
		return
	s["police_rules"] = true
	for r in L.police_rules():
		r["effective_month"] = world.month
		LawOps.add_rule(world, r)
	LawOps.bump_rules_version(world)


static func _stations(world: WorldState) -> Array:
	return EconFace.query_police(world).get("stations", [])


static func _org(world: WorldState) -> String:
	return EconFace.police_org(world)


static func powers(world: WorldState) -> int:
	return clampi(int(world.levers.get("LAW_POLICE_POWERS", POWERS_REF)), 0, 100)


## Misconduct multiplier from the powers law: 1 at 40, POWERS_MISCONDUCT_MAX at 100, POWERS_MISCONDUCT_MIN at 0.
static func powers_misconduct(world: WorldState) -> float:
	var p := powers(world)
	if p >= POWERS_REF:
		return 1.0 + (POWERS_MISCONDUCT_MAX - 1.0) * float(p - POWERS_REF) / float(100 - POWERS_REF)
	return 1.0 - (1.0 - POWERS_MISCONDUCT_MIN) * float(POWERS_REF - p) / float(POWERS_REF)


## Clearance multiplier from the powers law (crime.gd): +40% at 100, −10% at 0 (a probe: −25% doubled theft through deterrence).
static func powers_clearance(world: WorldState) -> float:
	var p := powers(world)
	if p >= POWERS_REF:
		return 1.0 + 0.4 * float(p - POWERS_REF) / float(100 - POWERS_REF)
	return 1.0 - 0.1 * float(POWERS_REF - p) / float(POWERS_REF)


# =====================================================================================  monthly

static func monthly(world: WorldState) -> void:
	if not on(world):
		return
	ensure_rules(world)
	var st := state(world)
	_station_news(world, st)
	_misconduct(world, st)
	_trust(world, st)
	_releases(world, st)
	ai_monthly(world)


static func _station_news(world: WorldState, st: Dictionary) -> void:
	var now := {}
	for s in _stations(world):
		now[String(s["id"])] = String(s["district"])
	var prev: Dictionary = st["stations"]
	if not st.has("stations_seen"):
		st["stations_seen"] = true      # the founding stations are not news
	else:
		for fid in Det.ordered(now):
			if not prev.has(fid):
				LawOps.law_fact(world, "LAW_POLICE_STATION_OPENED", "PUBLIC", [{"kind": "DISTRICT", "id": now[fid]}],
					[{"actor": GOVERNMENT, "share": 1.0}], {"SAFETY": 2}, 25, {"district": now[fid], "station": fid})
		for fid in Det.ordered(prev):
			if not now.has(fid):
				LawOps.law_fact(world, "LAW_POLICE_STATION_CLOSED", "PUBLIC", [{"kind": "DISTRICT", "id": prev[fid]}],
					[{"actor": GOVERNMENT, "share": 1.0}], {"SAFETY": -3}, 35, {"district": prev[fid], "station": fid})
	st["stations"] = now


static func _misconduct(world: WorldState, st: Dictionary) -> void:
	var org := _org(world)
	if org == "":
		return
	var rng := world.rng.stream("law.police")
	var recs: Dictionary = st["records"]          # "station|kind" -> violation fact id
	var track := world.table("violation_track")
	var pm := powers_misconduct(world)
	var WK = load("res://sim/law/work_law.gd")
	for s in _stations(world):
		var sid := String(s["id"])
		var staff := int(s.get("staff", 0))
		var stress := float(int(s.get("stress_pm", 0))) / 1000.0
		var size := float(staff) / float(OFFICERS_REF)
		for kind in L.POLICE_KINDS:
			var key := sid + "|" + String(kind)
			var fid := String(recs.get(key, ""))
			var v: Dictionary = track.get(fid, {})
			if not v.is_empty() and bool(v.get("active", false)) and not bool(v.get("revealed", false)):
				if rng.randf() < P_STOP or staff <= 0:
					LawOps.greed_stop(world, fid)
					recs.erase(key)
				else:
					LawOps.record_greed(world, org, {"kind": kind, "facility": sid, "district": String(s["district"])})
				continue
			recs.erase(key)
			var p := float(P_START[kind]) * size * (1.0 + STRESS_MULT * stress) * pm
			if kind == "EXCESSIVE_FORCE" and bool(WK.stress_accident(int(s.get("workload_pm", 1000)))):
				p *= STRESS_FORCE_MULT
			if staff > 0 and rng.randf() < p:
				recs[key] = LawOps.record_greed(world, org, {"kind": kind, "facility": sid, "district": String(s["district"]),
					"evidence": 600})


## Called by JusticeOps._reveal_violation for a police kind (instead of fines and enforcement against the police).
static func misconduct_revealed(world: WorldState, fid: String, v: Dictionary, rid: String, channel: String) -> void:
	var st := state(world)
	v["active"] = false
	var district := ""
	for s in _stations(world):
		if String(s["id"]) == String(v.get("facility", "")):
			district = String(s["district"])
	if district == "":
		district = String(world.facts.get_fact(fid).get("data", {}).get("params", {}).get("district", "d:1"))
	var kind := String(v["kind"])
	var reps: Dictionary = st["repeats"]
	var last: Array = reps.get(kind, [])
	var repeat := false
	for m in last:
		if world.month - int(m) <= REPEAT_MONTHS:
			repeat = true
	last.append(world.month)
	reps[kind] = last.filter(func(m): return world.month - int(m) <= REPEAT_MONTHS)
	var pol := {"kind": "POLICE", "id": String(v["company"])}
	var mid := LawOps.law_fact(world, "LAW_POLICE_MISCONDUCT_REVEALED", "PUBLIC", [pol, {"kind": "DISTRICT", "id": district}],
		[{"actor": GOVERNMENT, "share": 0.6}, {"actor": pol, "share": 0.4}], {"FAIRNESS": -4, "SAFETY": -2},
		REVEAL_MAGNITUDE + (10 if repeat else 0),
		{"kind": kind, "district": district, "station": String(v.get("facility", "")), "channel": channel,
		"months": maxi(1, world.month - int(v.get("since_month", world.month))), "repeat": repeat, "record": fid,
		"powers": powers(world)})
	st["shock"][district] = int(st["shock"].get(district, 0)) + TRUST_SHOCK
	var J = load("res://sim/law/justice_ops.gd")
	var claim := int(round(float(TORT_WREF.get(kind, 0.0)) * float(J.w_ref(world))))
	if claim > 0:
		J.init_courts(world)
		J.file_case(world, "TORT", {"kind": "VICTIMS", "id": mid, "scope": {"districts": [district]}}, GOVERNMENT, true,
			{"fact": mid, "claim": claim, "gov_share": 0.0, "police": true, "kind": kind}, [900])
	if repeat:
		LawOps.law_fact(world, "LAW_POLICE_INQUIRY_OPENED", "PUBLIC", [pol], [{"actor": GOVERNMENT, "share": 1.0}],
			{"GOVERNANCE": -2}, 45, {"kind": kind, "district": district, "count": (reps[kind] as Array).size()})


## detect_ctx hook: investigations the complaints authority can run a month.
static func oversight_cases(world: WorldState) -> float:
	return float(clampi(int(world.levers.get("LAW_POLICE_OVERSIGHT", 2000)), 0, 20000)) / float(OVERSIGHT_CASE_COST)


## detect_p hook: monthly chance an active police record is found (authority + victims), before evidence scaling.
static func p_find(cases: float) -> float:
	return minf(P_FIND_MAX, P_FIND_PER_CASE * cases) + P_VICTIM_COMPLAINT


# =====================================================================================  trust

static func _trust(world: WorldState, st: Dictionary) -> void:
	var shock: Dictionary = st["shock"]
	for d in shock.keys():
		shock[d] = int(round(float(shock[d]) * TRUST_SHOCK_DECAY))
		if int(shock[d]) < 100:
			shock.erase(d)
	var Crime = load("res://sim/law/crime.gd")
	var crime_d: Dictionary = world.peek("law_state").get("s", {}).get("crime", {}).get("d", {})
	var clear_term := {}
	for d in crime_d:
		var ema: Dictionary = crime_d[d].get("clear_ema", {})
		var rel := 0.0
		var n := 0
		for k in ["THEFT", "VIOLENCE"]:
			if ema.has(k):
				rel += float(ema[k]) / float(Crime.BASE_CLEAR_PM[k]) - 1.0
				n += 1
		clear_term[d] = clampf(rel / maxf(1.0, float(n)), -1.0, 1.0) * TRUST_CLEAR_W
	var pw := float(powers(world) - POWERS_REF) / float(100 - POWERS_REF)
	var cells := world.table("cell")
	for ck in Det.ordered(cells):
		var c: Dictionary = cells[ck]
		var d := String(c.get("district", ""))
		var inst := float(int(c.get("ideology", {}).get("INSTITUTIONS", 0))) / 100000.0     # −1 order … +1 liberty
		var target := float(TRUST_START) + float(clear_term.get(d, 0.0)) - float(shock.get(d, 0)) \
			- pw * inst * TRUST_POWERS_W           # strong powers: liberty-minded voters lose trust, order-minded gain
		target = clampf(target, 0.0, 100000.0)
		var t := float(int(c.get("trust_police", TRUST_START)))
		c["trust_police"] = int(round(t + (target - t) * TRUST_DRIFT))


## Population-weighted trust in the police in a district ("" = colony), 0..100000. TRUST_START without cells.
static func trust_pm(world: WorldState, district: String = "") -> int:
	var w := 0.0
	var tot := 0.0
	for c in world.peek("cell").values():
		if district != "" and String(c.get("district", "")) != district:
			continue
		var pop := float(int(c.get("pop", 0)))
		w += pop * float(int(c.get("trust_police", TRUST_START)))
		tot += pop
	return TRUST_START if tot <= 0.0 else int(round(w / tot))


# =====================================================================================  political control

## The government refers an opponent to the police. Lawful (force false): the prosecutor opens an investigation only
## if the target party has hidden party-finance violations; else LAW_REFERRAL_DECLINED (OFFICIAL). Unlawful (force
## true): POLITICAL_ARREST, always PROHIBITED (charter right) — a SECRET LAW_UNLAWFUL_GOV_ACTION (burdened: the
## target party, so it can complain) and the PUBLIC detention LAW_POLITICAL_ARREST on a pretext. target = {kind PARTY,
## id} (its leader is detained) or {kind PERSON, id} (a staff person: unavailable while detained).
## -> {ok, path: "REFERRAL"|"DECLINED"|"ARREST", fact?, investigation?, reason?}
static func order_investigation(world: WorldState, actor: Dictionary, target: Dictionary, reason: String = "",
		force: bool = false) -> Dictionary:
	var party := ""
	var person := ""
	var name := ""
	if String(target.get("kind", "")) == "PERSON":
		var p: Dictionary = world.peek("person").get(String(target.get("id", "")), {})
		if p.is_empty() or not (String(p.get("status", "")) in ["ACTIVE", "UNAVAILABLE"]):
			return {"ok": false, "reason": "no such person"}
		person = String(target["id"])
		name = String(p.get("name", ""))
		party = String(p.get("party_id", ""))
	else:
		party = String(target.get("id", ""))
		if not world.peek("party").has(party):
			return {"ok": false, "reason": "no such party"}
		name = String(load("res://sim/law/party_finance.gd").call("leader_name", world, party))
	if not force:
		var PF = load("res://sim/law/party_finance.gd")
		var evidence := false
		for t in world.peek("donation_track").values():
			if String(t.get("party", "")) == party and not bool(t.get("revealed", false)):
				evidence = true
		if party != "" and evidence:
			var inv := String(PF.call("open_investigation", world, {"kind": "PARTY", "id": party},
				{"kind": "INSTITUTION", "id": "prosecutor"}, "police referral: " + reason))
			return {"ok": true, "path": "REFERRAL", "investigation": inv}
		var fid := LawOps.law_fact(world, "LAW_REFERRAL_DECLINED", "OFFICIAL", [target], [{"actor": actor, "share": 1.0}], {}, 15,
			{"target": target.duplicate(), "party": party, "reason": reason})
		return {"ok": true, "path": "DECLINED", "fact": fid}
	var rng := world.rng.stream("law.police")
	var months := rng.randi_range(int(DETAIN_MONTHS[0]), int(DETAIN_MONTHS[1]))
	var pretext := reason if reason != "" else String(PRETEXTS[rng.randi_range(0, PRETEXTS.size() - 1)])
	var burdened := {"kind": "PARTY", "id": party} if party != "" else target.duplicate()
	var res := LawOps.proceed_unlawfully(world, actor, "POLITICAL_ARREST",
		{"target": target.duplicate(), "party": party, "person": person, "name": name, "pretext": pretext, "months": months},
		"", burdened, "SEVERE")
	if not bool(res.get("ok", false)):
		return {"ok": false, "reason": String(res.get("reason", "not prohibited"))}
	var st := state(world)
	var org := _org(world)
	var pol := {"kind": "POLICE", "id": org if org != "" else "police"}
	var aid := LawOps.law_fact(world, "LAW_POLITICAL_ARREST", "PUBLIC", [target, pol], [{"actor": pol, "share": 1.0}],
		{"FAIRNESS": -3}, 55, {"party": party, "person": person, "name": name, "pretext": pretext, "months": months,
		"until": world.month + months})
	if person != "":
		var p: Dictionary = world.table("person")[person]
		p["status"] = "UNAVAILABLE"
		p["unavailable_until"] = maxi(int(p.get("unavailable_until", -1)), world.month + months)
	st["detained"][aid] = {"party": party, "person": person, "name": name, "until": world.month + months,
		"order": String(res["fact"])}
	(st["arrests"] as Array).append({"month": world.month, "order": String(res["fact"]), "arrest": aid, "party": party,
		"name": name, "by": actor.duplicate()})
	return {"ok": true, "path": "ARREST", "fact": aid, "order": String(res["fact"])}


static func _releases(world: WorldState, st: Dictionary) -> void:
	var det: Dictionary = st["detained"]
	for aid in Det.ordered(det):
		var r: Dictionary = det[aid]
		if world.month < int(r["until"]):
			continue
		LawOps.law_fact(world, "LAW_DETAINEE_RELEASED", "PUBLIC", [{"kind": "PARTY", "id": String(r["party"])}], [], {}, 30,
			{"party": r["party"], "person": r["person"], "name": r["name"], "arrest": aid})
		det.erase(aid)


## Detained opposition figures now: {arrest fact id: {party, person, name, until, order}} (Wilma, Ella, the UI).
static func detained(world: WorldState) -> Dictionary:
	return _peek(world).get("detained", {})


## Political arrests ever ordered (the lasting count for Wilma's drift): [{month, order, arrest, party, name, by}].
static func arrests(world: WorldState) -> Array:
	return _peek(world).get("arrests", [])


## An AI government tries a political arrest only when cornered: the governing party is order-minded
## (INSTITUTIONS ≤ −40), there is a crisis, an emergency or authoritarian drift, and it trails in the polls.
## Never while the player governs. A small monthly chance; the target is the leading opposition party.
static func ai_monthly(world: WorldState) -> void:
	var pst: Dictionary = world.peek("pol").get("state", {})
	var g: Dictionary = pst.get("government", {})
	var pm := String(g.get("pm_party", ""))
	var parties := world.peek("party")
	if pm == "" or not parties.has(pm):
		return
	if pm == String(pst.get("player_party", "")) and not bool(world.meta.get("autoplay_player", false)):
		return
	if int(parties[pm].get("positions", {}).get("INSTITUTIONS", 0)) > AI_INSTITUTIONS_MAX:
		return
	var cornered: bool = LawOps.crisis_active(world) or bool(LawOps.emergency(world).get("active", false)) \
		or int(pst.get("authoritarian_drift", 0)) > 0
	if not cornered:
		return
	var members: Array = g.get("members", [pm])
	var top := ""
	var top_sup := int(parties[pm].get("support", 0))
	for pid in Det.ordered(parties):
		var p: Dictionary = parties[pid]
		if members.has(pid) or String(p.get("status", "")) != "ACTIVE":
			continue
		if int(p.get("support", 0)) > top_sup:
			top_sup = int(p.get("support", 0))
			top = String(pid)
	if top == "":
		return     # not trailing
	if world.rng.stream("law.police.ai").randf() >= AI_P:
		return
	order_investigation(world, GOVERNMENT, {"kind": "PARTY", "id": top}, "", true)

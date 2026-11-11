extends RefCounted
## M6 core (planning/spec-law-v1.md §11): courts, administrative appeals, contract disputes, the inspectorate,
## a seeded verdict model, remedies and fines through the ledger. Stateless; tables owned here:
##   court, judge, case, violation_track (+ licence suspension fields), law_state.s["justice"]
## Reads: unlawful_track / revealed_fact / permit_application (law), org / liability (econ, 88), facts.

const Det := preload("res://sim/staff/det.gd")
const Staff := preload("res://sim/staff/staff_ops.gd")
const RG := preload("res://sim/staff/roster_gen.gd")
const Vis := preload("res://sim/law/visibility.gd")

const GOVERNMENT := {"kind": "GOVERNMENT", "id": "government"}
const STATE := {"kind": "INSTITUTION", "id": "inspectorate"}

# ---- tuning (spec §11) ----
const CP_PER_JUDGE_BASE := 4.0
const CP_PER_JUDGE_LAW := 4.0
const JUDGE_COST_WREF := 3000       # milli-W_ref per judge per month (budget adequacy)
const INSPECTOR_COST_WREF := 2000
const INSPECTIONS_PER_INSPECTOR := 3
const CASE_CP := {"ADMIN_APPEAL": 3, "UNLAWFUL_GOV": 6, "CONTRACT": 5, "ENFORCEMENT": 4, "APPEAL": 4, "PARTY_FINANCE": 4,
	"TORT": 5}
# M11 detection channels (spec-events 3): environment inspectorate and competition/consumer authority.
const ENV_INSPECTION_COST_WREF := 1500     # milli-W_ref per environmental inspection
const MARKET_CASE_COST_WREF := 2500        # milli-W_ref per market investigation
const P_WHISTLE_PROTECTED := 0.03          # with LAW_WHISTLEBLOWER_PROTECTION
const P_LENIENCY := 0.05                   # per month a cartel member confesses under LAW_LENIENCY
const INQUIRY_MIN_MAGNITUDE := 50
const VICTIM_FUND := "law:victim_fund"
const PARTY_FINE_MULT := 2.0      # party-finance fine = 2 x the amount over the cap (min 1 W_ref) x LAW_FINE_SCALE
const THETA := 0.5
const SETTLE_GAP := 0.15
const APPEAL_IF_ABOVE := 0.4
const FINE := {"MINOR": [0.01, 2.0], "SERIOUS": [0.04, 10.0], "SEVERE": [0.10, 30.0]}   # [share of annual revenue, min W_ref]
const SUSPEND_MONTHS := 3
const P_WHISTLE := 0.01
const AGENCY_Q_DEFAULT := 60.0
const P_FILE_UNLAWFUL := 0.5
const P_FILE_CONTRACT := 0.3
const P_FILE_DENIAL_WRONG := 0.75
const P_FILE_DENIAL_RIGHT := 0.10


static func js(world: WorldState) -> Dictionary:
	var t := world.table("law_state")
	if not t.has("s"):
		t["s"] = {}
	if not t["s"].has("justice"):
		t["s"]["justice"] = {"warnings": {}, "filed": {}, "sanctioned": {}, "contract_filed": {}}
	return t["s"]["justice"]


static func w_ref(world: WorldState) -> int:
	return int(Staff.w_ref_milli(world))


static func company_acct(org_id: String) -> String:
	return "co:" + org_id


static func fact(world: WorldState, type: String, vis: String, subjects: Array, resp: Array, impact: Dictionary,
		mag: int, data: Dictionary, causes: Array = []) -> String:
	return world.add_fact({"type": type, "owner": "law", "subjects": subjects, "responsible": resp, "impact": impact,
		"magnitude": mag, "visibility": vis, "data": data, "causes": causes})


# =====================================================================================  courts & judges

static func init_courts(world: WorldState) -> void:
	var courts := world.table("court")
	if not courts.is_empty():
		return
	for kind in ["GENERAL", "ADMIN"]:
		var id := world.new_id("court")
		courts[id] = {"id": id, "kind": kind, "judges": []}
	sync_judges(world)


static func court_of(world: WorldState, kind: String) -> Dictionary:
	var courts := world.table("court")
	for id in Det.ordered(courts):
		if courts[id]["kind"] == kind:
			return courts[id]
	return {}


## Keep the judge count equal to the operative LAW_JUDGES lever (60% general court, rest administrative).
## New judges come from a merit shortlist of 3 (best LAW is appointed); judges cannot be dismissed, they retire at 70.
static func sync_judges(world: WorldState) -> void:
	var target := int(world.levers.get("LAW_JUDGES", 5))
	var judges := world.table("judge")
	var active: Array = []
	for id in Det.ordered(judges):
		if judges[id]["status"] == "ACTIVE":
			active.append(id)
	var rng := world.rng.stream("law.judges")
	while active.size() < target:
		var best: Dictionary = {}
		for _i in 3:
			var p := RG.make_person(rng, "CIVIL", "LAW", ["ADMIN", "POLI"], "", world.month)
			p["skills"]["LAW"] = rng.randi_range(60, 85)
			if best.is_empty() or int(p["skills"]["LAW"]) > int(best["skills"]["LAW"]):
				best = p
		var id := world.new_id("judge")
		best["id"] = id
		best["roles"] = ["JUDGE"]
		best["status"] = "ACTIVE"
		best["appointed_month"] = world.month
		judges[id] = best
		active.append(id)
	var gen := court_of(world, "GENERAL")
	var adm := court_of(world, "ADMIN")
	if gen.is_empty():
		return
	var n_gen := int(ceil(float(active.size()) * 0.6))
	gen["judges"] = active.slice(0, n_gen)
	adm["judges"] = active.slice(n_gen)


static func retire_judges(world: WorldState) -> void:
	var judges := world.table("judge")
	var changed := false
	for id in Det.ordered(judges):
		var j: Dictionary = judges[id]
		if j["status"] == "ACTIVE" and Staff.age_years(world, j) >= 70:
			j["status"] = "RETIRED"
			changed = true
	if changed or _judge_count(world) != int(world.levers.get("LAW_JUDGES", 5)):
		sync_judges(world)


static func _judge_count(world: WorldState) -> int:
	var n := 0
	for j in world.table("judge").values():
		if j["status"] == "ACTIVE":
			n += 1
	return n


## Case-points per month: sum over judges of (4 + 4 LAW/100), scaled by budget adequacy.
static func capacity(world: WorldState, court: Dictionary) -> float:
	var cp := 0.0
	for jid in court["judges"]:
		cp += CP_PER_JUDGE_BASE + CP_PER_JUDGE_LAW * float(world.table("judge")[jid]["skills"]["LAW"]) / 100.0
	var need := float(_judge_count(world) * JUDGE_COST_WREF)
	var budget := float(world.levers.get("LAW_COURT_BUDGET", 15000))
	return cp * (minf(1.0, budget / need) if need > 0.0 else 1.0)


static func mean_law(world: WorldState, court: Dictionary) -> float:
	if court["judges"].is_empty():
		return 60.0
	var s := 0.0
	for jid in court["judges"]:
		s += float(world.table("judge")[jid]["skills"]["LAW"])
	return s / float(court["judges"].size())


# =====================================================================================  cases

## File a case. truth = ground truth that the claimant is right (never read by the court directly).
static func file_case(world: WorldState, type: String, claimant: Dictionary, respondent: Dictionary, truth: bool,
		data: Dictionary, evidence_extra: Array = []) -> String:
	var kind := "ADMIN" if type == "ADMIN_APPEAL" or type == "UNLAWFUL_GOV" else "GENERAL"
	var court := court_of(world, kind)
	var id := world.new_id("case")
	var cp := int(CASE_CP[type]) * 1000
	world.table("case")[id] = {"id": id, "type": type, "court": court["id"], "claimant": claimant, "respondent": respondent,
		"truth": truth, "evidence": _evidence(world, truth) + evidence_extra, "cp_total": cp, "cp_left": cp,
		"filed_month": world.month, "status": "OPEN", "settle_checked": false, "data": data, "appeal_of": "",
		"outcome": "", "decided_month": -1}
	for party_ref in [claimant, respondent]:
		if party_ref.get("kind", "") == "PARTY":
			var ids: Array = []
			for k in ["unlawful_fact", "violation", "fact"]:
				if String(data.get(k, "")) != "":
					ids.append(String(data[k]))
			Vis.add_grant(world, String(party_ref["id"]), "FACT_IDS", {"ids": ids}, id)
	fact(world, "LAW_CASE_FILED", "PUBLIC", [claimant, respondent], [{"actor": claimant, "share": 1.0}], {}, 10,
		{"case": id, "type": type})
	return id


## Evidence generated from ground truth (spec §11.3): true claims leave real evidence, false ones only weak traces.
static func _evidence(world: WorldState, truth: bool) -> Array:
	var rng := world.rng.stream("law.verdict")
	var ev: Array = []
	if truth:
		var n := 1 + _poisson(rng, 1.5)
		for _i in n:
			ev.append(int(round(rng.randf_range(0.4, 0.9) * 1000.0)))
	else:
		var n := _poisson(rng, 0.7)
		for _i in n:
			ev.append(int(round(rng.randf_range(0.0, 0.3) * 1000.0)))
	return ev


static func _poisson(rng: RandomNumberGenerator, lam: float) -> int:
	var l := exp(-lam)
	var k := 0
	var p := 1.0
	while true:
		p *= rng.randf()
		if p <= l:
			return k
		k += 1
	return k


static func strength(c: Dictionary) -> float:
	var miss := 1.0
	for r in c["evidence"]:
		miss *= 1.0 - float(r) / 1000.0
	return 1.0 - miss


## P(claimant wins) = logistic((S - theta) / w), w = 0.12 - 0.06 LAW/100 (better judges -> sharper outcomes).
static func p_win(world: WorldState, c: Dictionary) -> float:
	var court: Dictionary = world.table("court")[c["court"]]
	var w := 0.12 - 0.06 * mean_law(world, court) / 100.0
	return 1.0 / (1.0 + exp(-(strength(c) - THETA) / w))


# =====================================================================================  monthly justice step

static func run(world: WorldState) -> void:
	init_courts(world)
	retire_judges(world)
	_reactivate_licences(world)
	_inspect(world)
	_accident_reveals(world)
	_file_new_cases(world)
	_crisis_inquiries(world)
	_settlements(world)
	_process_courts(world)
	_pay_victims(world)


static func _reactivate_licences(world: WorldState) -> void:
	var lic := world.table("licence")
	for id in Det.ordered(lic):
		var l: Dictionary = lic[id]
		if l["status"] == "SUSPENDED" and world.month >= int(l.get("suspended_until", 0)):
			l["status"] = "ACTIVE"


## Shared detection context (monthly): inspections per channel, regulated population, find probability.
static func detect_ctx(world: WorldState) -> Dictionary:
	var track := world.table("violation_track")
	var inspectors := int(world.levers.get("LAW_INSPECTORS", 4))
	var budget := float(world.levers.get("LAW_INSPECTORATE_BUDGET", 8000))
	var need := float(inspectors * INSPECTOR_COST_WREF)
	var regulated := {}
	for l in world.table("licence").values():
		regulated[l["holder_id"]] = true
	for v in track.values():
		regulated[v["company"]] = true
	var q := float(Staff.duty_quality(world, "STAFF_SD_LEGAL", int(AGENCY_Q_DEFAULT * 1000.0))) / 1000.0
	return {"SAFETY": float(inspectors * INSPECTIONS_PER_INSPECTOR) * (minf(1.0, budget / need) if need > 0.0 else 0.0),
		"ENV": float(world.levers.get("LAW_ENV_INSPECTORATE_BUDGET", 4000)) / float(ENV_INSPECTION_COST_WREF),
		"MARKET": float(world.levers.get("LAW_COMPETITION_BUDGET", 4000)) / float(MARKET_CASE_COST_WREF),
		# M12: colony customs chase charter evasion only while the colony enforces the charter (home inspector: CharterOps)
		"HOME": float(world.levers.get("LAW_COMPETITION_BUDGET", 4000)) / float(MARKET_CASE_COST_WREF) \
			if bool(world.levers.get("LAW_ENFORCE_CHARTER", true)) and String(world.peek("law_state").get("s", {}) \
			.get("sovereignty", {}).get("status", "COLONY")) in ["COLONY", "AUTONOMY"] else 0.0,
		"n_reg": maxi(10, regulated.size()), "p_find": 0.6 + 0.3 * q / 100.0,
		"p_whistle": P_WHISTLE_PROTECTED if bool(world.levers.get("LAW_WHISTLEBLOWER_PROTECTION", false)) else P_WHISTLE,
		"leniency": bool(world.levers.get("LAW_LENIENCY", false)), "priors": js(world)["sanctioned"]}


## Monthly detection probabilities of one tracked violation: {inspect, whistle, leniency}. Evidence 0..1000 scales
## them (x0.5..x1.5; pre-M11 rows count as 500 = x1.0). Lawful or stale conduct is not detectable this way.
static func detect_p(ctx: Dictionary, v: Dictionary) -> Dictionary:
	if not v.get("unlawful", true) or (v.has("kind") and not v.get("active", true) and int(v.get("evidence", 0)) < 50):
		return {"inspect": 0.0, "whistle": 0.0, "leniency": 0.0}
	var ev := 0.5 + float(v.get("evidence", 500)) / 1000.0
	var risk := 2.0 if ctx["priors"].has(v["company"]) else 1.0
	var ch: String = v.get("channel", "SAFETY")
	var cap: float = ctx[ch]
	var p_insp := minf(1.0, cap / float(ctx["n_reg"]) * risk) * float(ctx["p_find"]) * ev
	var lp := P_LENIENCY if ctx["leniency"] and v.get("kind", "") == "CARTEL" else 0.0
	return {"inspect": minf(1.0, p_insp), "whistle": minf(1.0, float(ctx["p_whistle"]) * ev), "leniency": lp}


## Inspectorates: each open violation is inspected by its channel with p = inspections/regulated x risk x find x evidence.
static func _inspect(world: WorldState) -> void:
	var track := world.table("violation_track")
	var ctx := detect_ctx(world)
	var rng := world.rng.stream("law.inspect")
	for fid in Det.ordered(track):
		var v: Dictionary = track[fid]
		if v["revealed"]:
			continue
		var p := detect_p(ctx, v)
		if p["inspect"] <= 0.0 and p["whistle"] <= 0.0:
			continue
		if rng.randf() < p["inspect"]:
			_reveal_violation(world, fid, STATE, "INSPECTION")
		elif rng.randf() < p["whistle"]:
			_reveal_violation(world, fid, {"kind": "OFFICIAL", "id": "whistleblower"}, "WHISTLEBLOWER")
		elif p["leniency"] > 0.0 and rng.randf() < p["leniency"]:
			_reveal_violation(world, fid, {"kind": "COMPANY", "id": "cartel_member"}, "LENIENCY")


## Accidents at a facility operated in violation reveal that operator's open violations and wrongly granted licences.
static func _accident_reveals(world: WorldState) -> void:
	for f in world.facts.query("COMP_WORKPLACE_ACCIDENT", world.month, world.month):
		var op: String = String(f["data"].get("operator", ""))
		if op == "":
			continue
		for fid in Det.ordered(world.table("violation_track")):
			var v: Dictionary = world.table("violation_track")[fid]
			if not v["revealed"] and v["company"] == op:
				_reveal_violation(world, fid, {"kind": "NATURE", "id": "accident"}, "ACCIDENT")
		for fid in Det.ordered(world.table("unlawful_track")):
			var t: Dictionary = world.table("unlawful_track")[fid]
			if t["kind"] == "PERMIT" and not t["revealed"] and String(world.facts.get_fact(fid)["data"].get("holder", "")) == op:
				t["revealed"] = true
				world.table("revealed_fact")[fid] = true
				world.facts.reveal(world.month, fid, [{"kind": "NATURE", "id": "accident"}])


static func _reveal_violation(world: WorldState, fid: String, by: Dictionary, channel: String) -> void:
	var v: Dictionary = world.table("violation_track")[fid]
	v["revealed"] = true
	v["revealed_month"] = world.month
	v["channel"] = channel
	world.table("revealed_fact")[fid] = true
	var rid := world.facts.reveal(world.month, fid, [by])
	v["revealed_fact"] = rid
	if not v.get("unlawful", true):
		return   # harmful but lawful conduct: public, nothing to prosecute
	if channel != "INSPECTION":
		# Weak oversight shares the blame when it took an accident or a whistleblower (pic-staff-law §2).
		fact(world, "LAW_OVERSIGHT_FAILURE", "PUBLIC", [GOVERNMENT], [{"actor": GOVERNMENT, "share": 1.0}],
			{"SAFETY": -3, "GOVERNANCE": -3}, 20, {"violation": fid, "channel": channel}, [rid])
	if v["class"] == "MINOR":
		var warns: Dictionary = js(world)["warnings"]
		var last := int(warns.get(v["company"], -999))
		warns[v["company"]] = world.month
		if world.month - last > 24:
			fact(world, "LAW_WARNING_ISSUED", "OFFICIAL", [{"kind": "COMPANY", "id": v["company"]}],
				[{"actor": {"kind": "COMPANY", "id": v["company"]}, "share": 1.0}], {}, 5, {"violation": fid})
			v["sanctioned_month"] = world.month
			return
	file_case(world, "ENFORCEMENT", STATE, {"kind": "COMPANY", "id": v["company"]}, true,
		{"violation": fid, "class": v["class"]})


static func _file_new_cases(world: WorldState) -> void:
	var j := js(world)
	var rng := world.rng.stream("law.filing")
	# 1. Revealed unlawful government acts: the burdened party (or anyone with standing) challenges them.
	for fid in Det.ordered(world.table("unlawful_track")):
		var t: Dictionary = world.table("unlawful_track")[fid]
		if t["kind"] != "GOV" or not t["revealed"] or j["filed"].has(fid) or not t["burdened"]:
			continue
		if rng.randf() < P_FILE_UNLAWFUL:
			j["filed"][fid] = true
			file_case(world, "UNLAWFUL_GOV", t["burdened_ref"], GOVERNMENT, true, {"unlawful_fact": fid}, [900])
	# 2. Opposition legal challenges completed by staff (STAFF_T_LEGAL_CHALLENGE, params.target_fact).
	for tid in Det.ordered(world.table("task")):
		var task: Dictionary = world.table("task")[tid]
		if task["def_id"] != "STAFF_T_LEGAL_CHALLENGE" or task["status"] != "COMPLETED" or task["outputs"].get("filed", false):
			continue
		task["outputs"]["filed"] = true
		var claimant := {"kind": "PARTY", "id": task["owner"]["id"]}
		var eid: String = String(task["params"].get("target_enactment", ""))
		var target: String = String(task["params"].get("target_fact", ""))
		if eid != "":
			# Challenge of a decree: truth = whether it really was unlawful. Filing exposes a hidden unlawful decree.
			var e: Dictionary = world.table("enactment").get(eid, {})
			target = String(e.get("unlawful_fact", ""))
			var truth: bool = e.get("unlawful", false)
			if truth and target != "" and not world.table("revealed_fact").has(target):
				world.table("revealed_fact")[target] = true
				if world.table("unlawful_track").has(target):
					world.table("unlawful_track")[target]["revealed"] = true
				world.facts.reveal(world.month, target, [claimant])
			if truth and target != "":
				j["filed"][target] = true
			file_case(world, "UNLAWFUL_GOV", claimant, GOVERNMENT, truth, {"unlawful_fact": target, "enactment": eid},
				[900] if truth else [])
			continue
		var known: bool = world.table("revealed_fact").has(target) and world.table("unlawful_track").has(target)
		if known and not j["filed"].has(target):
			j["filed"][target] = true
			file_case(world, "UNLAWFUL_GOV", claimant, GOVERNMENT, true, {"unlawful_fact": target}, [900])
		elif not known:
			file_case(world, "UNLAWFUL_GOV", claimant, GOVERNMENT, false, {"unlawful_fact": target})
	# 3. Permit denials: wrongly denied firms usually appeal, rightly denied ones rarely do.
	for aid in Det.ordered(world.table("permit_application")):
		var a: Dictionary = world.table("permit_application")[aid]
		if a["status"] != "DENIED" or int(a["decided_month"]) != world.month:
			continue
		if rng.randf() < (P_FILE_DENIAL_WRONG if a["wrong"] else P_FILE_DENIAL_RIGHT):
			file_case(world, "ADMIN_APPEAL", {"kind": "COMPANY", "id": a["holder_id"]},
				{"kind": "AUTHORITY", "id": "permit_office"}, bool(a["wrong"]), {"application": aid})
	# 4. Contract disputes from econ facts (severe delay: owner sues contractor; missed payment: contractor sues owner).
	for f in world.facts.query("ECON_CONTRACT_", world.month, world.month):
		var typ: String = f["type"]
		if typ != "ECON_CONTRACT_SEVERELY_DELAYED" and typ != "ECON_CONTRACT_PAYMENT_MISSED":
			continue
		var proj: String = String(f["data"].get("project", ""))
		var key := "%s|%s" % [typ, proj]
		if j["contract_filed"].has(key) or rng.randf() >= P_FILE_CONTRACT:
			continue
		j["contract_filed"][key] = true
		var p: Dictionary = world.table("project").get(proj, {})
		var owner_ref := GOVERNMENT if p.get("owner", "gov") == "gov" else {"kind": "COMPANY", "id": p.get("owner", "")}
		var contractor := {"kind": "COMPANY", "id": String(p.get("contractor", ""))}
		if typ == "ECON_CONTRACT_SEVERELY_DELAYED":
			var claim := int(p.get("price", 0)) / 10
			file_case(world, "CONTRACT", owner_ref, contractor, true, {"project": proj, "claim": claim, "fact": f["id"]})
		else:
			file_case(world, "CONTRACT", contractor, owner_ref, true,
				{"project": proj, "claim": int(f["data"].get("amount_due", 0)), "fact": f["id"]})


## Contract cases may settle once, before the hearing: both sides estimate P with noise 0.1.
static func _settlements(world: WorldState) -> void:
	var rng := world.rng.stream("law.verdict")
	for cid in Det.ordered(world.table("case")):
		var c: Dictionary = world.table("case")[cid]
		if c["status"] != "OPEN" or c["settle_checked"] or c["type"] != "CONTRACT" or c["appeal_of"] != "":
			continue
		c["settle_checked"] = true
		var p := p_win(world, c)
		var a := clampf(p + rng.randfn(0.0, 0.1), 0.0, 1.0)
		var b := clampf(p + rng.randfn(0.0, 0.1), 0.0, 1.0)
		if absf(a - b) < SETTLE_GAP:
			var amount := int(round((a + b) / 2.0 * float(c["data"].get("claim", 0))))
			c["status"] = "SETTLED"
			c["outcome"] = "SETTLED"
			c["decided_month"] = world.month
			_pay(world, c["respondent"], c["claimant"], amount, "COMPENSATION")
			fact(world, "LAW_CASE_SETTLED", "PUBLIC", [c["claimant"], c["respondent"]],
				[{"actor": c["respondent"], "share": 1.0}], {}, 10, {"case": cid, "amount": amount})


## FIFO per court: capacity is spent on the oldest open cases; a case is decided when its case-points are done.
static func _process_courts(world: WorldState) -> void:
	var cases := world.table("case")
	for court_id in Det.ordered(world.table("court")):
		var court: Dictionary = world.table("court")[court_id]
		var cap := int(round(capacity(world, court) * 1000.0))
		for cid in Det.ordered(cases):
			if cap <= 0:
				break
			var c: Dictionary = cases[cid]
			if c["status"] != "OPEN" or c["court"] != court_id:
				continue
			var use := mini(cap, int(c["cp_left"]))
			c["cp_left"] = int(c["cp_left"]) - use
			cap -= use
			if int(c["cp_left"]) <= 0:
				_decide(world, c)


static func _decide(world: WorldState, c: Dictionary) -> void:
	var rng := world.rng.stream("law.verdict")
	var p := p_win(world, c)
	var claimant_wins := rng.randf() < p
	c["status"] = "DECIDED"
	c["decided_month"] = world.month
	c["outcome"] = "CLAIMANT" if claimant_wins else "RESPONDENT"
	# One appeal level: the loser appeals if its own estimate of winning is above 0.4.
	if c["appeal_of"] == "":
		var loser_p := (1.0 - p) if claimant_wins else p
		if clampf(loser_p + rng.randfn(0.0, 0.1), 0.0, 1.0) > APPEAL_IF_ABOVE:
			var aid := world.new_id("case")
			var gen := court_of(world, "GENERAL")
			world.table("case")[aid] = {"id": aid, "type": c["type"], "court": gen["id"], "claimant": c["claimant"],
				"respondent": c["respondent"], "truth": c["truth"], "evidence": c["evidence"].duplicate(),
				"cp_total": CASE_CP["APPEAL"] * 1000, "cp_left": CASE_CP["APPEAL"] * 1000, "filed_month": world.month,
				"status": "OPEN", "settle_checked": true, "data": c["data"].duplicate(true), "appeal_of": c["id"],
				"outcome": "", "decided_month": -1}
			c["status"] = "APPEALED"
			return
	_final(world, c, claimant_wins)


## Final judgment: remedies, fines, rulings (PUBLIC facts; against-government rulings carry GOVERNMENT blame).
static func _final(world: WorldState, c: Dictionary, claimant_wins: bool) -> void:
	var against_gov: bool = (claimant_wins and c["respondent"]["kind"] in ["GOVERNMENT", "AUTHORITY"]) \
		or (not claimant_wins and c["claimant"]["kind"] == "GOVERNMENT")
	var winner: Dictionary = c["claimant"] if claimant_wins else c["respondent"]
	var loser: Dictionary = c["respondent"] if claimant_wins else c["claimant"]
	var data := {"case": c["id"], "type": c["type"], "outcome": c["outcome"], "winner": winner, "against_government": against_gov,
		"duration": world.month - _root_filed(world, c)}
	var causes: Array = []
	if claimant_wins:
		match c["type"]:
			"ADMIN_APPEAL":
				var a: Dictionary = world.table("permit_application").get(c["data"]["application"], {})
				if not a.is_empty():
					a["status"] = "GRANTED"
					a["licence_id"] = _grant(world, a)
					data["remedy"] = "PERMIT_GRANTED"
			"UNLAWFUL_GOV":
				var fid: String = c["data"].get("unlawful_fact", "")
				if fid != "":
					causes.append(fid)
				data["remedy"] = "OVERTURNED"
				data["overturned"] = world.facts.get_fact(fid).get("data", {}) if fid != "" else {}
				_revert(world, data["overturned"])
				# A challenged decree with no recorded unlawful act (court error in the claimant's favour): undo it too.
				var eid: String = String(c["data"].get("enactment", ""))
				if fid == "" and eid != "":
					var e: Dictionary = world.table("enactment").get(eid, {})
					if e.get("status", "") == "EFFECTIVE" and e.get("from") != null:
						world.levers[e["lever"]] = e["from"]
					data["overturned"] = {"action": "SET_LEVER", "params": {"lever_id": e.get("lever", ""), "lawful_value": e.get("from")}}
				_pay(world, GOVERNMENT, c["claimant"], CASE_CP["UNLAWFUL_GOV"] * w_ref(world), "LITIGATION_COSTS")
			"CONTRACT":
				var amt := int(c["data"].get("claim", 0))
				_pay(world, c["respondent"], c["claimant"], amt, "COMPENSATION")
				data["remedy"] = "COMPENSATION"
				data["amount"] = amt
			"ENFORCEMENT":
				var v: Dictionary = world.table("violation_track").get(c["data"]["violation"], {})
				data["fine"] = _fine(world, c["respondent"]["id"], c["data"]["class"], c["data"]["violation"])
				data["remedy"] = "FINE"
				if not v.is_empty():
					v["sanctioned_month"] = world.month
					js(world)["sanctioned"][v["company"]] = world.month
				if String(c["data"].get("class", "")) == "SEVERE":
					var org: Dictionary = world.table("org").get(c["respondent"]["id"], {})
					var ceo = org.get("ceo", {})
					var cref := {"kind": "COMPANY", "id": c["respondent"]["id"]}
					fact(world, "LAW_MANAGER_CONVICTED", "PUBLIC", [cref], [{"actor": cref, "share": 1.0}], {"FAIRNESS": 3}, 40,
						{"org": c["respondent"]["id"], "ceo": ceo.get("name", "") if ceo is Dictionary else str(ceo),
						"violation": c["data"]["violation"], "case": c["id"]})
			"TORT":
				var claim := int(c["data"].get("claim", 0))
				var gov_share := float(c["data"].get("gov_share", 0.0))
				var by_gov := int(round(float(claim) * gov_share))
				_pay(world, c["respondent"], c["claimant"], claim - by_gov, "COMPENSATION")
				if by_gov > 0:
					_pay(world, GOVERNMENT, c["claimant"], by_gov, "COMPENSATION")
				data["remedy"] = "COMPENSATION"
				data["amount"] = claim
				data["gov_paid"] = by_gov
			"PARTY_FINANCE":
				data["remedy"] = "FINE"
				data["fine"] = _party_fine(world, c)
				data["party"] = c["data"].get("party", "")
				data["leader"] = c["data"].get("leader", "")
				data["leader_convicted"] = c["data"].get("leader_charged", false)
	var mag := 40 if c["type"] == "UNLAWFUL_GOV" else (25 if against_gov else 15)
	var impact := {"FAIRNESS": 3}
	var resp := [{"actor": loser, "share": 1.0}]
	if against_gov:
		impact = {"GOVERNANCE": -10, "FAIRNESS": -5 if c["type"] == "UNLAWFUL_GOV" else 2}
		resp = [{"actor": GOVERNMENT, "share": 1.0}]
	fact(world, "LAW_RULING", "PUBLIC", [winner, loser], resp, impact, mag, data, causes)


## Party-finance conviction: fine from party:<id> to gov:fines_revenue (no liability; the unpaid part is reported),
## and, when the leader was charged, LAW_LEADER_CONVICTED {party, leader, can_hold_office, must_step_down}.
static func _party_fine(world: WorldState, c: Dictionary) -> int:
	var pid := String(c["respondent"]["id"])
	var amount := int(round(maxf(PARTY_FINE_MULT * float(c["data"].get("excess", 0)), float(w_ref(world)))
		* float(world.levers.get("LAW_FINE_SCALE", 1000)) / 1000.0))
	var acct := "party:" + pid
	var paid := 0
	if world.ledger.has_account(acct) and world.ledger.has_account("gov:fines_revenue"):
		paid = mini(amount, maxi(0, world.ledger.balance(acct)))
		if paid > 0:
			world.ledger.transfer(acct, "gov:fines_revenue", paid, "FINE", world.month)
	var pref := {"kind": "PARTY", "id": pid}
	fact(world, "LAW_FINE_IMPOSED", "PUBLIC", [pref], [{"actor": pref, "share": 1.0}], {"FAIRNESS": 2},
		mini(40, 10 + amount / maxi(1, w_ref(world))), {"amount": amount, "paid": paid, "class": "PARTY_FINANCE", "party": pid})
	if c["data"].get("leader_charged", false):
		var can := bool(world.levers.get("LAW_CONVICTED_CAN_HOLD_OFFICE", true))
		var leader := String(c["data"].get("leader", ""))
		var t := world.table("law_state")
		if t.has("s") and t["s"].has("party_finance"):
			t["s"]["party_finance"]["convictions"].append({"leader": leader, "party": pid, "month": world.month, "case": c["id"]})
		fact(world, "LAW_LEADER_CONVICTED", "PUBLIC", [pref], [{"actor": pref, "share": 1.0}], {"GOVERNANCE": -3}, 60,
			{"party": pid, "leader": leader, "case": c["id"], "can_hold_office": can, "must_step_down": not can})
	return amount


# =====================================================================================  M11 crises: inquiry, liability

## A serious crisis (fact with data.crisis = true, magnitude >= 50) opens a public inquiry with p = 0.5 + 0.4 Q/100.
## It reports after 3-6 months: linked conduct (data.cause_records, or records whose hazard_ids include data.hazard,
## or at the same facility) is found with the inspection find odds x evidence. A found greed cause emits
## LAW_CRISIS_CAUSE_REVEALED (company + government blame) and, with damages, a TORT case for the victims.
static func _crisis_inquiries(world: WorldState) -> void:
	var inq := world.table("inquiry")
	var rng := world.rng.stream("law.inquiry")
	var q := float(Staff.duty_quality(world, "STAFF_SD_LEGAL", int(AGENCY_Q_DEFAULT * 1000.0))) / 1000.0
	for f in world.facts.query("", world.month, world.month):
		if not bool(f["data"].get("crisis", false)) or int(f["magnitude"]) < INQUIRY_MIN_MAGNITUDE:
			continue
		if rng.randf() >= 0.5 + 0.4 * q / 100.0:
			continue
		var id := world.new_id("inquiry")
		inq[id] = {"id": id, "crisis": f["id"], "opened_month": world.month, "due_month": world.month + 3 + rng.randi_range(0, 3),
			"status": "OPEN", "found": []}
		fact(world, "LAW_INQUIRY_OPENED", "PUBLIC", [GOVERNMENT], [], {}, 25, {"inquiry": id, "crisis": f["id"], "crisis_type": f["type"]})
	var ctx := detect_ctx(world)
	for id in Det.ordered(inq):
		var i: Dictionary = inq[id]
		if i["status"] != "OPEN" or world.month < int(i["due_month"]):
			continue
		var crisis := world.facts.get_fact(i["crisis"])
		for fid in _linked_conduct(world, crisis):
			var v: Dictionary = world.table("violation_track")[fid]
			if not v["revealed"]:
				var ev := 0.5 + float(v.get("evidence", 500)) / 1000.0
				if rng.randf() >= minf(1.0, float(ctx["p_find"]) * ev):
					continue
				_reveal_violation(world, fid, {"kind": "INSTITUTION", "id": "inquiry"}, "INQUIRY")
			i["found"].append(fid)
			cause_revealed(world, crisis, fid)
		i["status"] = "CLOSED"
		fact(world, "LAW_INQUIRY_CLOSED", "PUBLIC", [GOVERNMENT], [], {}, 25 if i["found"].is_empty() else 40,
			{"inquiry": id, "crisis": i["crisis"], "outcome": "CAUSE_FOUND" if not i["found"].is_empty() else "NO_FINDINGS",
			"found": i["found"].size()})


static func _linked_conduct(world: WorldState, crisis: Dictionary) -> Array:
	var d: Dictionary = crisis.get("data", {})
	var out: Array = []
	var track := world.table("violation_track")
	for fid in d.get("cause_records", []):
		if track.has(fid) and not out.has(fid):
			out.append(fid)
	var hz := String(d.get("hazard", ""))
	var fac := String(d.get("facility", ""))
	for fid in Det.ordered(track):
		var v: Dictionary = track[fid]
		if out.has(fid) or not v.has("kind") or int(v.get("since_month", 0)) > int(crisis.get("month", world.month)):
			continue
		if (hz != "" and v.get("hazard_ids", []).has(hz)) or (fac != "" and v.get("facility", "") == fac):
			out.append(fid)
	return out


## The actual cause of a crisis becomes public: a scandal for the company and for the government that let it happen
## (larger share when the conduct ran 12+ months undetected). Damages -> TORT case for the victims (once per crisis+org).
static func cause_revealed(world: WorldState, crisis: Dictionary, fid: String) -> void:
	var v: Dictionary = world.table("violation_track")[fid]
	var org := String(v["company"])
	var cref := {"kind": "COMPANY", "id": org}
	var hidden := int(crisis.get("month", world.month)) - int(v.get("since_month", v["month"]))
	var gov_share := 0.3 if hidden >= 12 else 0.1
	var mag := maxi(50, int(crisis.get("magnitude", 50)))
	fact(world, "LAW_CRISIS_CAUSE_REVEALED", "PUBLIC", [cref, GOVERNMENT],
		[{"actor": cref, "share": 1.0 - gov_share}, {"actor": GOVERNMENT, "share": gov_share}],
		{"SAFETY": -5, "FAIRNESS": -8, "GOVERNANCE": -int(round(gov_share * 20.0))}, mini(95, mag + 10),
		{"crisis": crisis.get("id", ""), "crisis_type": crisis.get("type", ""), "org": org, "kind": v.get("kind", ""),
		"cause": "%s by %s for %d months" % [String(v.get("kind", "violation")).to_lower().replace("_", " "), org, maxi(1, hidden)],
		"months_hidden": hidden, "unlawful": v.get("unlawful", true), "saving": int(v.get("saving", 0)), "record": fid,
		"gov_share": gov_share}, [crisis.get("id", ""), fid] if crisis.has("id") else [fid])
	var damages := int(crisis.get("data", {}).get("damages", 0))
	var key := "%s|%s" % [crisis.get("id", ""), org]
	if damages > 0 and not js(world)["filed"].has(key):
		js(world)["filed"][key] = true
		file_case(world, "TORT", {"kind": "VICTIMS", "id": crisis.get("id", ""), "scope": crisis.get("data", {}).get("scope", {})},
			cref, true, {"crisis": crisis.get("id", ""), "fact": fid, "claim": damages, "gov_share": gov_share,
			"scope": crisis.get("data", {}).get("scope", {})}, [900])


## Compensation paid into the victim fund is recorded as an award; 88's helper pays awards out to the victims'
## (housing block x income band) pools by the crisis exposure scope and marks them PAID.
static func _award(world: WorldState, victims: Dictionary, amount: int) -> void:
	var id := world.new_id("award")
	world.table("victim_award")[id] = {"id": id, "crisis": String(victims.get("id", "")), "scope": victims.get("scope", {}),
		"amount": amount, "paid_out": 0, "status": "OPEN", "month": world.month}


## Placeholder until 88's pool payout exists: nothing to do here (awards wait in law:victim_fund).
static func _pay_victims(_world: WorldState) -> void:
	pass


static func _root_filed(world: WorldState, c: Dictionary) -> int:
	if c["appeal_of"] != "":
		return int(world.table("case")[c["appeal_of"]]["filed_month"])
	return int(c["filed_month"])


static func _grant(world: WorldState, a: Dictionary) -> String:
	var id := world.new_id("licence")
	world.table("licence")[id] = {"id": id, "holder_id": a["holder_id"], "kind": a["kind"], "type": a["type"],
		"status": "ACTIVE", "issued_month": world.month, "expiry_month": (world.month + int(a["months"])) if int(a["months"]) > 0 else -1}
	return id


## Overturn: lever changes made unlawfully are restored to their lawful value (law is the single writer, A8).
## Other unlawful actions are reverted by their owning subsystem when it sees the LAW_RULING (data.overturned).
static func _revert(world: WorldState, overturned: Dictionary) -> void:
	var params: Dictionary = overturned.get("params", {})
	if overturned.get("action", "") == "SET_LEVER" and params.has("lever_id") and params.has("lawful_value"):
		world.levers[params["lever_id"]] = params["lawful_value"]


## Fines (spec §11.5): max(share x annual revenue, min W_ref) x LAW_FINE_SCALE, paid to gov:fines_revenue;
## any shortfall becomes a FINE liability (88's insolvency machine collects it). SEVERE also suspends licences.
static func _fine(world: WorldState, org_id: String, cls: String, violation: String) -> int:
	var spec: Array = FINE.get(cls, FINE["SERIOUS"])
	var org: Dictionary = world.table("org").get(org_id, {})
	var pl: Dictionary = org.get("pl_last", {})
	var annual := float(pl.get("rev", 0)) * 12.0
	var amount := int(round(maxf(float(spec[0]) * annual, float(spec[1]) * float(w_ref(world)))
		* float(world.levers.get("LAW_FINE_SCALE", 1000)) / 1000.0))
	var acct := company_acct(org_id)
	var paid := 0
	if world.ledger.has_account(acct) and world.ledger.has_account("gov:fines_revenue"):
		paid = mini(amount, maxi(0, world.ledger.balance(acct)))
		if paid > 0:
			world.ledger.transfer(acct, "gov:fines_revenue", paid, "FINE", world.month)
	if amount - paid > 0:
		var lid := world.new_id("liability")
		world.table("liability")[lid] = {"id": lid, "debtor": org_id, "creditor": "gov", "amount": amount - paid,
			"due_month": world.month + 1, "kind": "FINE", "status": "OPEN"}
	if cls == "SEVERE":
		for l in world.table("licence").values():
			if l["holder_id"] == org_id and l["status"] == "ACTIVE":
				l["status"] = "SUSPENDED"
				l["suspended_until"] = world.month + SUSPEND_MONTHS
		fact(world, "LAW_LICENCE_SUSPENDED", "PUBLIC", [{"kind": "COMPANY", "id": org_id}],
			[{"actor": {"kind": "COMPANY", "id": org_id}, "share": 1.0}], {"JOBS": -2}, 20, {"months": SUSPEND_MONTHS})
	fact(world, "LAW_FINE_IMPOSED", "PUBLIC", [{"kind": "COMPANY", "id": org_id}],
		[{"actor": {"kind": "COMPANY", "id": org_id}, "share": 1.0}], {"FAIRNESS": 3}, mini(40, 10 + amount / maxi(1, w_ref(world))),
		{"amount": amount, "paid": paid, "class": cls, "violation": violation})
	return amount


## Money between case parties through the ledger; an unpayable company debt becomes a COMPENSATION liability.
static func _pay(world: WorldState, from_ref: Dictionary, to_ref: Dictionary, amount: int, memo: String) -> void:
	if amount <= 0:
		return
	var from := "gov:treasury" if from_ref["kind"] in ["GOVERNMENT", "AUTHORITY", "INSTITUTION"] else company_acct(String(from_ref["id"]))
	var to := "gov:treasury" if to_ref["kind"] in ["GOVERNMENT", "AUTHORITY", "INSTITUTION"] else company_acct(String(to_ref["id"]))
	if to_ref["kind"] == "PARTY":
		to = "party:" + String(to_ref["id"])
	if to_ref["kind"] == "VICTIMS":
		to = VICTIM_FUND
		if world.ledger.has_account("gov:treasury") and not world.ledger.has_account(VICTIM_FUND):
			world.ledger.open_account(VICTIM_FUND)
	if not world.ledger.has_account(from) or not world.ledger.has_account(to):
		return   # no economy loaded (politics-only configurations)
	var paid := mini(amount, maxi(0, world.ledger.balance(from))) if not world.ledger.allow_negative.get(from, false) else amount
	if paid > 0:
		world.ledger.transfer(from, to, paid, memo, world.month)
		if to_ref["kind"] == "VICTIMS":
			_award(world, to_ref, paid)
	if amount - paid > 0 and from.begins_with("co:"):
		var lid := world.new_id("liability")
		world.table("liability")[lid] = {"id": lid, "debtor": String(from_ref["id"]),
			"creditor": "gov" if to == "gov:treasury" else String(to_ref["id"]), "amount": amount - paid,
			"due_month": world.month + 1, "kind": "COMPENSATION", "status": "OPEN"}


# =====================================================================================  indicators (M6)

## % of revealed violations (rolling 24 months) sanctioned within 12 months. -1 = no data (not published).
static func enforcement_consistency(world: WorldState) -> float:
	var n := 0
	var ok := 0
	for v in world.table("violation_track").values():
		if not v["revealed"] or world.month - int(v["revealed_month"]) > 24:
			continue
		if v.has("sanctioned_month"):
			n += 1
			if int(v["sanctioned_month"]) - int(v["revealed_month"]) <= 12:
				ok += 1
		elif world.month - int(v["revealed_month"]) > 12:
			n += 1
	return 100.0 * float(ok) / float(n) if n > 0 else -1.0


## Mean duration (months) of cases finally decided in the last 12 months; -1 = no data.
static func court_duration(world: WorldState) -> float:
	var s := 0.0
	var n := 0
	for c in world.table("case").values():
		if (c["status"] == "DECIDED" or c["status"] == "SETTLED") and world.month - int(c["decided_month"]) <= 12:
			s += float(int(c["decided_month"]) - _root_filed(world, c))
			n += 1
	return s / float(n) if n > 0 else -1.0

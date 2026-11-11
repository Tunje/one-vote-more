extends RefCounted
## Read-only accessors for the UI (planning/ui-staff-law.md §3–§4). Pure: never mutates the world.
## Case views never expose ground truth or evidence strength (evidence != truth).

const L := preload("res://sim/law/law_data.gd")
const RE := preload("res://sim/law/rules_engine.gd")
const LawOps := preload("res://sim/law/law_ops.gd")
const J := preload("res://sim/law/justice_ops.gd")
const Staff := preload("res://sim/staff/staff_ops.gd")
const SQ := preload("res://sim/staff/staff_query.gd")
const SD := preload("res://sim/staff/staff_data.gd")
const Det := preload("res://sim/staff/det.gd")
const Vis := preload("res://sim/law/visibility.gd")
const PF := preload("res://sim/law/party_finance.gd")

const DECREE_WARNING := "This decree is UNLAWFUL: %s. If you proceed it will be implemented like any decision, " \
	+ "but it is recorded as a secret unlawful act. It can leak from the civil service (about 3%% a month), be " \
	+ "exposed by an opposition inquiry, or be challenged in court by those it harms. If it comes out, voters " \
	+ "punish the government (governance), the rule-of-law index falls, and a court will very likely overturn it."


static func _lever_level_ok(world: WorldState, lever: String, level: String) -> Array:
	return LawOps.check_change(world, lever, LawOps.legal_value(world, lever), level)


## Instrument level the actor uses in the current era (ORDINANCE for the commander, LAW for parliament).
static func default_level(world: WorldState) -> String:
	return "ORDINANCE" if RE.era(world) == "FOUNDING" else "LAW"


static func pending_for(world: WorldState, lever: String) -> Dictionary:
	for eid in Det.ordered(world.table("enactment")):
		var e: Dictionary = world.table("enactment")[eid]
		if e["lever"] == lever and e["status"] in ["PENDING", "LEGAL", "SCHEDULED"]:
			return {"enactment": eid, "status": e["status"], "value": e["value"]}
	return {}


# ======================================================================  (c) drafting

## Every lever with current operative/legal value and whether `level` may change it now.
static func lever_catalog(world: WorldState, level: String = "") -> Array:
	var lvl := default_level(world) if level == "" else level
	var ids: Array = world.lever_defs.keys()
	ids.sort()
	var out: Array = []
	for id in ids:
		var d: Dictionary = world.lever_defs[id]
		var errs := _lever_level_ok(world, id, lvl)
		out.append({"id": id, "owner": d["owner"], "type": d["type"], "range": d.get("range", []), "values": d.get("values", []),
			"default": d["default"], "operative": world.levers.get(id), "legal": LawOps.legal_value(world, id),
			"legal_level": d["legalLevel"], "founding_era": d["foundingEra"], "ideology": d.get("ideology", {}).duplicate(),
			"implementation": LawOps.impl_class(d), "lag": d.get("lag", 0), "pending": pending_for(world, id),
			"changeable": errs.is_empty(), "why_not": "; ".join(errs)})
	return out


## Preview of a draft: per-clause legal check, ideology shift, implementation, drafting work.
## clauses = [{lever, to}]. Nothing is changed.
static func preview_clauses(world: WorldState, clauses: Array, level: String = "") -> Dictionary:
	var lvl := default_level(world) if level == "" else level
	var rows: Array = []
	var ideology := {}
	var domains := {}
	var ok := true
	for c in clauses:
		var lv: String = c["lever"]
		var d: Dictionary = world.lever_defs.get(lv, {})
		var errs := LawOps.check_change(world, lv, c["to"], lvl)
		ok = ok and errs.is_empty()
		var from = LawOps.legal_value(world, lv)
		var steps := 0.0
		if d.get("type", "") == "NUMBER":
			steps = float(c["to"]) - float(from)
		elif d.get("type", "") == "ENUM":
			steps = float(d["values"].find(c["to"]) - d["values"].find(from))
		var shift := {}
		for ax in d.get("ideology", {}):
			shift[ax] = float(d["ideology"][ax]) * steps
			ideology[ax] = float(ideology.get(ax, 0.0)) + shift[ax]
		var dom := Staff.lever_domain(world, lv)
		domains[dom] = int(domains.get(dom, 0)) + 1
		rows.append({"lever": lv, "from": from, "to": c["to"], "errors": errs, "ideology": shift,
			"implementation": LawOps.impl_class(d) if not d.is_empty() else "", "lag": d.get("lag", 0),
			"pending": pending_for(world, lv)})
	var def_id := "STAFF_T_DRAFT_ORDINANCE" if lvl == "ORDINANCE" else "STAFF_T_DRAFT_BILL"
	var w: Dictionary = SD.TASKS[def_id]["work"]
	var domain := "ADMIN"
	for k in domains:
		if domain == "ADMIN" or int(domains[k]) > int(domains.get(domain, 0)):
			domain = k
	return {"ok": ok, "level": lvl, "clauses": rows, "ideology": ideology,
		"drafting": {"task": def_id, "work_wu": int(w["base"]) + int(w["per_clauses"]) * clauses.size(), "domain": domain,
			"second_policy_lead_required": def_id == "STAFF_T_DRAFT_BILL" and clauses.size() >= 4}}


## Drafting progress for a bill (politics creates the bill id and calls StaffOps.request_drafting).
static func drafting_status(world: WorldState, bill_id: String, viewer: Dictionary = {}) -> Dictionary:
	var t := Staff.draft_for_bill(world, bill_id)
	if t.is_empty() or not Vis.can_see_owner(world, viewer, t["owner"]):
		return {"exists": false}
	var tv := SQ.task_view(world, t["id"])
	var staffed := true
	for p in tv["positions"]:
		if p["mandatory"] and p["assigned"] == "":
			staffed = false
	return {"exists": true, "task_id": t["id"], "status": t["status"], "progress_pct": tv["progress_pct"],
		"staffed": staffed, "positions": tv["positions"], "draft_quality": t["outputs"].get("draft_quality", -1),
		"defects_known": 0, "ready": t["status"] == "COMPLETED"}


## The government decides ADMIN-level levers by administrative decision and everything else by regulation
## (lawful only for REGULATION-level levers or LAW-level ones a law delegates).
static func decree_level(world: WorldState, lever: String) -> String:
	return "ADMIN" if world.lever_defs.get(lever, {}).get("legalLevel", "") == "ADMIN" else "REGULATION"


## Government decision on one lever: lawful, or unlawful with the warning text the UI must show.
static func decree_check(world: WorldState, lever: String, value, viewer: Dictionary = {}) -> Dictionary:
	if not Vis.can_decree(world, viewer):
		return {"allowed": false, "lawful": false, "result": "N/A", "warning": "Only the government can decree.", "errors": []}
	if RE.era(world) == "FOUNDING":
		return {"allowed": false, "lawful": false, "result": "N/A",
			"warning": "Before the first government, the commander changes levers by ordinance.", "errors": []}
	var d: Dictionary = world.lever_defs.get(lever, {})
	var level := decree_level(world, lever)
	var errs := LawOps.check_change(world, lever, value, level)
	var res := RE.validate(world, {"kind": "GOVERNMENT", "id": "government"}, "SET_LEVER", {"lever_id": lever,
		"instrument_level": level, "founding_era": d.get("foundingEra", ""), "lever_level": d.get("legalLevel", ""),
		"delegated": LawOps._delegated(world, lever, value, level)})
	if errs.is_empty():
		return {"allowed": true, "lawful": true, "level": level, "result": res["result"], "warning": "", "errors": []}
	var structural := errs.filter(func(e): return not String(e).begins_with("no authority") and not String(e).contains("cannot change"))
	if res["result"] != "PROHIBITED" or not structural.is_empty():
		return {"allowed": false, "lawful": false, "result": res["result"], "warning": "", "errors": errs}
	var why := "only parliament can change %s (a %s-level lever)" % [lever, d.get("legalLevel", "")]
	return {"allowed": true, "lawful": false, "result": "PROHIBITED", "warning": DECREE_WARNING % why,
		"errors": errs, "trace": res["trace"].map(func(r): return rule_view(world, r))}


# ======================================================================  (d) law register, constitution, cases

static func _pred_text(p: Dictionary) -> String:
	var f := String(p["field"]).replace("p.", "").replace("actor.", "").replace("lever.", "").replace("world.", "")
	var v = p["value"]
	var vs: String = ", ".join(v.map(func(x): return str(x))) if v is Array else str(v)
	var op: String = {"EQ": "is", "NEQ": "is not", "IN": "is one of", "NIN": "is not one of", "LT": "<", "LTE": "≤",
		"GT": ">", "GTE": "≥"}.get(p["op"], p["op"])
	return "%s %s %s" % [f.replace("_", " "), op, vs]


static func rule_text(r: Dictionary) -> String:
	var who := "everyone"
	for p in r["subject"]:
		if p["field"] == "actor.kind":
			who = ", ".join(p["value"]).to_lower() if p["value"] is Array else String(p["value"]).to_lower()
	var act := String(r["action"]).replace("_", " ").to_lower()
	var verb: String = {"PROHIBIT": "%s may not %s", "PERMIT": "%s may %s", "AUTHORIZE": "%s is authorized to %s",
		"REQUIRE": "%s must meet a requirement to %s", "DELEGATE": "%s may %s within delegated bounds"}.get(r["kind"], "%s %s") % [who, act]
	var conds: Array = []
	for p in r["where"]:
		if not String(p["field"]).begins_with("actor."):
			conds.append(_pred_text(p))
	var text := verb.capitalize().left(1) + verb.substr(1)
	if not conds.is_empty():
		text += " when " + " and ".join(conds)
	if not r["unless"].is_empty():
		text += ", unless " + " or ".join(r["unless"].map(func(p): return _pred_text(p)))
	var req: Dictionary = r.get("requirement", {})
	if req.has("licence_type"):
		text += " (needs a %s licence)" % String(req["licence_type"]).to_lower()
	if req.has("approval_by"):
		text += " (needs approval by %s)" % String(req["approval_by"]).to_lower()
	if req.has("compensation_pct_min"):
		text += " (compensation ≥ %d%%)" % int(req["compensation_pct_min"])
	return text + "."


static func rule_view(world: WorldState, rid: String) -> Dictionary:
	var r: Dictionary = world.table("legal_rule").get(rid, {})
	if r.is_empty():
		return {}
	return {"id": rid, "level": r["level"], "kind": r["kind"], "action": r["action"], "status": r["status"],
		"source": r.get("source", ""), "right": r.get("right", ""), "effective_month": r.get("effective_month", 0),
		"text": rule_text(r)}


## The law register, highest level first. filter: {level?, status?, action?}
static func law_register(world: WorldState, filter: Dictionary = {}) -> Array:
	var out: Array = []
	for rid in Det.ordered(world.table("legal_rule")):
		var r: Dictionary = world.table("legal_rule")[rid]
		if filter.has("level") and r["level"] != filter["level"]:
			continue
		if filter.has("status") and r["status"] != filter["status"]:
			continue
		if filter.has("action") and r["action"] != filter["action"]:
			continue
		out.append(rule_view(world, rid))
	out.sort_custom(func(a, b): return int(L.LEVEL_RANK.get(a["level"], 0)) > int(L.LEVEL_RANK.get(b["level"], 0)))
	return out


static func constitution_view(world: WorldState) -> Dictionary:
	var s := LawOps.state(world)
	var rights: Array = []
	var powers: Array = []
	for rv in law_register(world, {"status": "ACTIVE"}):
		if rv["level"] != "CHARTER" and rv["level"] != "CONSTITUTIONAL":
			continue
		if rv["right"] != "":
			rights.append(rv)
		else:
			powers.append(rv)
	var bounds: Array = []
	for lever in L.LEVER_BOUNDS:
		bounds.append({"lever": lever, "bounds": L.LEVER_BOUNDS[lever]})
	bounds.append({"lever": "any tax rate", "bounds": {"max": L.TAX_MAX_BP}})
	return {"era": RE.era(world), "document": "CONSTITUTION" if s["constitution"] else "EXPEDITION CHARTER",
		"adopted_month": s.get("constitution_month", -1), "rights": rights, "powers": powers, "charter_bounds": bounds,
		"amendment": "Two identical decisions by simple majority, with an ordinary election in between " \
			+ "(the first at least 9 months before it). Not available to players in v1.",
		"rules_version": s["rules_version"]}


## Lever changes in the pipeline ("enacted but not yet implemented" is a political state).
static func enactments(world: WorldState, include_final: bool = false, viewer: Dictionary = {}) -> Array:
	var insider := Vis.is_sim(viewer) or Vis.role(world, viewer["party_id"]) == "GOVERNING"
	var out: Array = []
	for eid in Det.ordered(world.table("enactment")):
		var e: Dictionary = world.table("enactment")[eid]
		if not include_final and e["status"] in ["EFFECTIVE", "REJECTED", "CANCELLED"]:
			continue
		var impl := {}
		if insider and e.get("impl_task", "") != "":
			var tv := SQ.task_view(world, e["impl_task"])
			impl = {"task_id": e["impl_task"], "progress_pct": tv.get("progress_pct", 0), "status": tv.get("status", ""),
				"staffed": tv.get("positions", []).all(func(p): return not p["mandatory"] or p["assigned"] != "")}
		out.append({"id": eid, "lever": e["lever"], "from": e.get("from"), "to": e["value"], "level": e["legal_level"],
			"status": e["status"], "source_bill": e.get("source_bill", ""), "legal_month": e.get("legal_month", -1),
			"due_month": e.get("due_month", -1), "effective_month": e.get("effective_month", -1),
			"errors": e.get("errors", []), "unlawful": _unlawful_visible(world, viewer, e), "deemed_statute": e.get("deemed_statute", false),
			"implementation": impl})
	return out


static func _actor_name(world: WorldState, ref: Dictionary) -> String:
	match String(ref.get("kind", "")):
		"GOVERNMENT": return "The Government"
		"AUTHORITY": return "Permit & Licence Office"
		"INSTITUTION": return "Inspectorate" if ref.get("id", "") == "inspectorate" else String(ref.get("id", ""))
		"PARTY": return String(world.peek("party").get(ref["id"], {}).get("name", ref["id"]))
		"COMPANY": return String(world.peek("org").get(ref["id"], {}).get("name", ref["id"]))
	return String(ref.get("id", "?"))


## Court cases (public view: no truth, no evidence strength). open_only = pending cases only.
static func cases(world: WorldState, open_only: bool = true) -> Array:
	var out: Array = []
	var backlog := {}
	for cid in Det.ordered(world.table("case")):
		var c: Dictionary = world.table("case")[cid]
		var court: Dictionary = world.table("court").get(c["court"], {})
		var ahead: int = int(backlog.get(c["court"], 0))
		if c["status"] == "OPEN":
			backlog[c["court"]] = ahead + int(c["cp_left"])
		if open_only and c["status"] != "OPEN":
			continue
		var cap := J.capacity(world, court) if not court.is_empty() else 0.0
		var expected := -1
		if c["status"] == "OPEN" and cap > 0.0:
			expected = int(ceil(float(ahead + int(c["cp_left"])) / 1000.0 / cap))
		out.append({"id": cid, "type": c["type"], "court": court.get("kind", ""), "claimant": _actor_name(world, c["claimant"]),
			"respondent": _actor_name(world, c["respondent"]), "status": c["status"], "filed_month": c["filed_month"],
			"progress_pct": 100 - 100 * int(c["cp_left"]) / maxi(1, int(c["cp_total"])), "expected_months": expected,
			"outcome": c["outcome"], "decided_month": c["decided_month"], "is_appeal": c["appeal_of"] != "",
			"against_government": c["respondent"].get("kind", "") in ["GOVERNMENT", "AUTHORITY"]})
	return out


static func courts(world: WorldState) -> Array:
	var out: Array = []
	for id in Det.ordered(world.table("court")):
		var c: Dictionary = world.table("court")[id]
		var backlog := 0
		var n_open := 0
		for cs in world.table("case").values():
			if cs["court"] == id and cs["status"] == "OPEN":
				backlog += int(cs["cp_left"])
				n_open += 1
		var cap := J.capacity(world, c)
		out.append({"id": id, "kind": c["kind"], "judges": c["judges"].size(), "capacity_cp": snappedf(cap, 0.1),
			"open_cases": n_open, "backlog_cp": snappedf(float(backlog) / 1000.0, 0.1),
			"expected_wait_months": snappedf(float(backlog) / 1000.0 / cap, 0.1) if cap > 0.0 else -1.0})
	return out


static func permits(world: WorldState, holder_id: String = "") -> Array:
	var out: Array = []
	for id in Det.ordered(world.table("permit_application")):
		var a: Dictionary = world.table("permit_application")[id]
		if holder_id == "" or a["holder_id"] == holder_id:
			out.append({"id": id, "holder": a["holder_id"], "type": a["type"], "district": a["district"],
				"status": a["status"], "submitted_month": a["submitted_month"], "decided_month": a["decided_month"]})
	return out


# ======================================================================  visibility-aware feeds (spec-visibility §4)

## An enactment's "unlawful" mark is shown only once revealed, or to those who may see the SECRET fact
## (the parties that governed when it was decreed; a later government does not inherit the secret).
static func _unlawful_visible(world: WorldState, viewer: Dictionary, e: Dictionary) -> bool:
	if not e.get("unlawful", false):
		return false
	var fid := String(e.get("unlawful_fact", ""))
	return world.peek("revealed_fact").has(fid) or Vis.can_see_fact(world, viewer, world.facts.get_fact(fid))


## Facts the viewer may see, newest first. type_prefix filters by type (e.g. "LAW_", "STAFF_").
static func fact_feed(world: WorldState, viewer: Dictionary, from_month: int = -1, type_prefix: String = "", limit: int = 100) -> Array:
	var out: Array = []
	var facts: Array = world.facts.query(type_prefix, from_month, world.month)
	for i in range(facts.size() - 1, -1, -1):
		var f: Dictionary = facts[i]
		if Vis.can_see_fact(world, viewer, f):
			out.append({"id": f["id"], "month": f["month"], "type": f["type"], "visibility": f["visibility"],
				"magnitude": f["magnitude"], "subjects": f["subjects"].duplicate(true), "data": f["data"].duplicate(true)})
			if out.size() >= limit:
				break
	return out


## Indicator value for a viewer, or null if hidden from them (OFFICIAL needs government/support/oversight).
static func indicator(world: WorldState, viewer: Dictionary, ind_id: String, key: String = "COLONY"):
	return Vis.read_indicator(world, viewer, ind_id, key)


## Role and active access grants of a party (for the UI's "what can I see" panel).
static func access(world: WorldState, party_id: String) -> Dictionary:
	var grants: Array = []
	for gid in Det.ordered(world.peek("access_grant")):
		var g: Dictionary = world.peek("access_grant")[gid]
		if g["party_id"] == party_id and (g["kind"] != "INDICATOR_PREFIX" or world.month <= int(g["expires_month"])):
			grants.append(g.duplicate(true))
	return {"role": Vis.role(world, party_id), "grants": grants}


# ======================================================================  constitutional procedures (M7)

## The procedure rules in force (charter era: parliament-related procedures do not apply yet).
static func procedures(world: WorldState) -> Dictionary:
	var p: Dictionary = L.PROCEDURES.duplicate(true)
	p["in_force"] = LawOps.state(world)["constitution"]
	return p


static func _pol(world: WorldState) -> Dictionary:
	return world.peek("pol").get("state", {})


static func movers_needed() -> int:
	return int(ceil(float(L.PROCEDURES["parliament_seats"]) * float(L.PROCEDURES["no_confidence"]["movers_fraction"]) - 0.0001))


## May these parties (one, or several jointly) move a no-confidence vote now?
## {ok, reason, seats, needed, topple_votes}
static func can_move_no_confidence(world: WorldState, party_id, joint: Array = []) -> Dictionary:
	var ids: Array = [party_id] + joint
	var st := _pol(world)
	var needed := movers_needed()
	var seats := 0
	for pid in ids:
		seats += int(world.peek("party").get(pid, {}).get("seats", 0))
	var out := {"ok": false, "reason": "", "seats": seats, "needed": needed, "topple_votes": int(L.PROCEDURES["no_confidence"]["topple_votes"])}
	if not LawOps.state(world)["constitution"] or String(st.get("era", "FOUNDING")) == "FOUNDING":
		out["reason"] = "There is no parliament yet."
	elif st.get("government", {}).is_empty() or bool(st.get("caretaker", false)):
		out["reason"] = "There is no regular government to vote out (caretaker)."
	elif seats < needed:
		out["reason"] = "A motion needs at least %d members (one tenth of parliament); you have %d." % [needed, seats]
	else:
		out["ok"] = true
	return out


## May the government call an extra election now? {ok, reason, months_since_election, next_ordinary_month}
static func extra_election_allowed(world: WorldState) -> Dictionary:
	return LawOps.check_extra_election(world, false)


## What a caretaker government may and may not do (and whether one is in office now).
static func caretaker_limits(world: WorldState) -> Dictionary:
	var c: Dictionary = L.PROCEDURES["caretaker"]
	return {"caretaker": bool(_pol(world).get("caretaker", false)), "allowed": c["allowed"].duplicate(),
		"forbidden": c["forbidden"].duplicate(),
		"text": "A caretaker government keeps the state running (ongoing work, implementation of enacted laws, " \
			+ "administrative decisions, coalition talks) but may not regulate, call an extra election or make new commitments."}


# =====================================================================================  party finance (M9)

## May `donor` (company id or {kind,id}) give `amount` (ledger milli) now?
## {ok, disclose, cap (-1 = none), given (12 months), remaining (-1 = none), reason}. disclose=true: must be PUBLIC.
static func donation_allowed(world: WorldState, amount: int, donor) -> Dictionary:
	return PF.donation_allowed(world, amount, donor)


## Party-finance law in plain terms plus open investigations and convictions (UI).
static func party_finance(world: WorldState) -> Dictionary:
	var inv: Array = []
	var t := world.peek("investigation")
	for id in Det.ordered(t):
		inv.append(t[id].duplicate(true))
	var st: Dictionary = world.peek("law_state").get("s", {}).get("party_finance", {})
	return {"cap": PF.cap_amount(world), "disclosure": String(world.levers.get("LAW_DONATION_DISCLOSURE", "ABOVE_THRESHOLD")),
		"public_funding_per_seat": int(world.levers.get("LAW_PUBLIC_PARTY_FUNDING", 0)),
		"convicted_can_hold_office": PF.convicted_can_hold_office(world), "investigations": inv,
		"convictions": st.get("convictions", []).duplicate(true)}


## May a convicted leader (by name) hold a party leadership / office under current law?
static func may_hold_office(world: WorldState, leader: String) -> bool:
	var st: Dictionary = world.peek("law_state").get("s", {}).get("party_finance", {})
	for c in st.get("convictions", []):
		if c["leader"] == leader:
			return PF.convicted_can_hold_office(world)
	return true

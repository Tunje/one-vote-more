extends RefCounted
## Thin-law operations (planning/spec-law-v1.md §6, §7): the lever pipeline, the charter -> constitution
## transition, licences, and violation recording. Stateless; all state is in world tables:
##   legal_rule, licence, law_state (owned by law); enactment rows after PENDING (hand-off from politics, A8).
##
## Enactment lifecycle (law is the single writer of operative lever values, A8):
##   PENDING (politics) -> LEGAL (legal value in force, implementation task created)
##   -> SCHEDULED (implementation done, waiting lag) -> EFFECTIVE (world.levers written)
##   | REJECTED (failed legal check) | CANCELLED (superseded or repealed before taking effect)

const Det := preload("res://sim/staff/det.gd")
const L := preload("res://sim/law/law_data.gd")
const RE := preload("res://sim/law/rules_engine.gd")
const Staff := preload("res://sim/staff/staff_ops.gd")
const SD := preload("res://sim/staff/staff_data.gd")
const Justice := preload("res://sim/law/justice_ops.gd")

const GOVERNMENT := {"kind": "GOVERNMENT", "id": "government"}
const COMMANDER := {"kind": "COMMANDER", "id": "commander"}


static func state(world: WorldState) -> Dictionary:
	var t := world.table("law_state")
	if not t.has("s"):
		t["s"] = {"constitution": false, "rules_version": 0, "legal_values": {}, "defects_checked": {}}
	return t["s"]


static func set_value(world: WorldState, key: String, v) -> void:
	var vals = world.get("values")
	if vals is Dictionary:
		vals[key] = v
	else:
		world.meta[key] = v


static func bump_rules_version(world: WorldState) -> void:
	var s := state(world)
	s["rules_version"] = int(s["rules_version"]) + 1
	set_value(world, "LAW_RULES_VERSION", s["rules_version"])


static func add_rule(world: WorldState, r: Dictionary) -> String:
	var id := world.new_id("rule")
	var rule := r.duplicate(true)
	rule["id"] = id
	rule["status"] = "ACTIVE"
	if not rule.has("effective_month"):
		rule["effective_month"] = world.month
	world.table("legal_rule")[id] = rule
	return id


static func validate(world: WorldState, actor: Dictionary, action: String, params: Dictionary = {}) -> Dictionary:
	return RE.validate(world, actor, action, params)


static func law_fact(world: WorldState, type: String, visibility: String, subjects: Array, responsible: Array,
		impact: Dictionary, magnitude: int, data: Dictionary) -> String:
	return world.add_fact({"type": type, "owner": "law", "subjects": subjects, "responsible": responsible,
		"impact": impact, "magnitude": magnitude, "visibility": visibility, "data": data})


# =====================================================================================  new game

static func init_world(world: WorldState) -> void:
	state(world)
	for k in ["legal_rule", "licence", "permit_application", "enactment", "unlawful_track", "violation_track", "revealed_fact",
			"case", "court", "judge", "liability", "gov_term", "access_grant", "donation_track", "investigation"]:
		world.table(k)   # owned/shared tables exist from the start, so read-only queries never create them
	for r in L.charter_rules():
		r["effective_month"] = 0
		add_rule(world, r)
	# Founding licensing rules (LAW level, from the expedition charter's licensing annex): active while the regime is REQUIRED.
	add_rule(world, {"level": "LAW", "kind": "REQUIRE", "action": "EXTRACT_RESOURCE",
		"subject": [{"field": "actor.kind", "op": "EQ", "value": "COMPANY"}],
		"where": [{"field": "lever.LAW_LICENCE_REGIME_EXTRACTION", "op": "EQ", "value": "REQUIRED"}], "unless": [],
		"requirement": {"licence_type": "EXTRACTION"}, "delegation": {}, "supersedes": [], "defect": false,
		"provisional": false, "source": "CHARTER_ANNEX", "effective_month": 0})
	add_rule(world, {"level": "LAW", "kind": "REQUIRE", "action": "OPERATE_FACILITY",
		"subject": [{"field": "actor.kind", "op": "EQ", "value": "COMPANY"}],
		"where": [{"field": "p.hazard_class", "op": "EQ", "value": "HIGH"},
			{"field": "lever.LAW_LICENCE_REGIME_HAZARD", "op": "EQ", "value": "REQUIRED"}], "unless": [],
		"requirement": {"licence_type": "HAZARD"}, "delegation": {}, "supersedes": [], "defect": false,
		"provisional": false, "source": "CHARTER_ANNEX", "effective_month": 0})
	bump_rules_version(world)


# =====================================================================================  licences (permit office queue is M6)

## Grants a licence immediately (v1 stub for the permit office). 88 calls it for starting facilities and applications.
static func grant_licence(world: WorldState, holder_id: String, kind: String, type: String, months: int = -1) -> String:
	var id := world.new_id("licence")
	world.table("licence")[id] = {"id": id, "holder_id": holder_id, "kind": kind, "type": type, "status": "ACTIVE",
		"issued_month": world.month, "expiry_month": (world.month + months) if months > 0 else -1}
	return id


## Comp's misconduct AI proceeded without authorization (X7): ground truth, SECRET until detected.
static func record_violation(world: WorldState, actor: Dictionary, action: String, params: Dictionary) -> String:
	var res := validate(world, actor, action, params)
	# Penalty class: unlicensed hazardous operation or extraction is SERIOUS; anything else MINOR (spec §11.5).
	var cls := "MINOR"
	if action == "EXTRACT_RESOURCE" or (action == "OPERATE_FACILITY" and params.get("hazard_class", "") == "HIGH"):
		cls = "SERIOUS"
	cls = String(params.get("penalty_class", cls))
	var fid := law_fact(world, "LAW_VIOLATION", "SECRET", [actor], [{"actor": actor, "share": 1.0}],
		{"SAFETY": -5, "FAIRNESS": -3}, 30, {"action": action, "params": params, "result": res["result"],
		"trace": res["trace"], "class": cls})
	world.table("violation_track")[fid] = {"fact": fid, "company": String(actor.get("id", "")), "month": world.month,
		"class": cls, "revealed": false, "revealed_month": -1}
	return fid


# =====================================================================================  lever pipeline (spec §6.2)

static func _instrument_actor(world: WorldState, level: String) -> Dictionary:
	match level:
		"ORDINANCE":
			return COMMANDER
		"LAW":
			return {"kind": "PARLIAMENT", "id": "parliament"}
		_:
			return COMMANDER if RE.era(world) == "FOUNDING" else GOVERNMENT


static func impl_class(def: Dictionary) -> String:
	var c = def.get("implementation", null)
	return String(c) if c != null and SD.IMPL_CLASSES.has(String(c)) else "STAFF_T_IMPL_ADMIN"


## Legal check of one lever change. Returns an array of error strings (empty = lawful).
static func check_change(world: WorldState, lever: String, value, level: String) -> Array:
	var errs: Array = []
	if not world.lever_defs.has(lever):
		return ["unknown lever " + lever]
	var def: Dictionary = world.lever_defs[lever]
	match String(def["type"]):
		"NUMBER":
			if not (value is int or value is float):
				errs.append("value must be a number")
			elif def.has("range") and (float(value) < float(def["range"][0]) or float(value) > float(def["range"][1])):
				errs.append("value outside lever range")
		"ENUM":
			if not def.get("values", []).has(value):
				errs.append("value not one of the lever's options")
		"BOOL":
			if not value is bool:
				errs.append("value must be true/false")
	if not errs.is_empty():
		return errs
	var lever_level: String = def["legalLevel"]
	if lever_level == "CHARTER":
		errs.append("charter-level lever cannot be changed in v1")
	elif int(L.LEVEL_RANK.get(level, 0)) < int(L.LEVEL_RANK[lever_level]) and not _delegated(world, lever, value, level):
		errs.append("%s cannot change a %s-level lever" % [level, lever_level])
	errs.append_array(_charter_bounds(world, def, value))
	var res := RE.validate(world, _instrument_actor(world, level), "SET_LEVER",
		{"lever_id": lever, "instrument_level": level, "founding_era": def["foundingEra"], "lever_level": lever_level,
		"delegated": _delegated(world, lever, value, level)})
	if res["result"] != "AUTHORIZED":
		errs.append("no authority: %s (%s)" % [res["result"], res["reason"]])
	return errs


static func _delegated(world: WorldState, lever: String, value, level: String) -> bool:
	if level != "REGULATION":
		return false
	var rules := world.table("legal_rule")
	for rid in Det.ordered(rules):
		var r: Dictionary = rules[rid]
		if r["status"] == "ACTIVE" and r["kind"] == "DELEGATE" and r["delegation"].get("lever_id", "") == lever:
			if float(value) >= float(r["delegation"]["min"]) and float(value) <= float(r["delegation"]["max"]):
				return true
	return false


static func _charter_bounds(_world: WorldState, def: Dictionary, value) -> Array:
	var errs: Array = []
	var b: Dictionary = L.LEVER_BOUNDS.get(def["id"], {})
	if def.get("is_tax", false) and float(value) > float(L.TAX_MAX_BP):
		errs.append("charter: tax rate above 50%")
	if b.has("min") and float(value) < float(b["min"]):
		errs.append("charter: below the charter minimum")
	if b.has("max") and float(value) > float(b["max"]):
		errs.append("charter: above the charter maximum")
	if b.has("min_enum"):
		var vals: Array = def.get("values", [])
		if vals.find(value) < vals.find(b["min_enum"]):
			errs.append("charter: below the charter minimum standard")
	return errs


static func legal_value(world: WorldState, lever: String):
	var lv: Dictionary = state(world)["legal_values"]
	return lv[lever] if lv.has(lever) else world.levers.get(lever, null)


## Monthly pipeline step (DECISIONS phase).
static func run_pipeline(world: WorldState) -> void:
	var rows := world.table("enactment")
	var groups := {}       # "bill|class" -> [enactment ids], in insertion order
	var group_order: Array = []
	for eid in Det.ordered(rows):
		var e: Dictionary = rows[eid]
		if e["status"] != "PENDING":
			continue
		# A confirmed unlawful decree skips the check: it is already recorded as a SECRET unlawful act (spec §8).
		var errs: Array = [] if e.get("unlawful", false) else check_change(world, e["lever"], e["value"], e["legal_level"])
		if not errs.is_empty():
			e["status"] = "REJECTED"
			e["errors"] = errs
			var actor := _instrument_actor(world, e["legal_level"])
			law_fact(world, "LAW_ENACTMENT_REJECTED", "PUBLIC", [actor], [{"actor": GOVERNMENT if actor["kind"] == "PARLIAMENT" else actor, "share": 1.0}],
				{}, 15, {"enactment": eid, "lever": e["lever"], "errors": errs, "source_bill": e.get("source_bill", "")})
			continue
		_supersede(world, e)
		e["status"] = "LEGAL"
		e["legal_month"] = world.month
		e["from"] = world.levers.get(e["lever"])
		state(world)["legal_values"][e["lever"]] = e["value"]
		var key := "%s|%s" % [e.get("source_bill", ""), impl_class(world.lever_defs[e["lever"]])]
		if not groups.has(key):
			groups[key] = []
			group_order.append(key)
		groups[key].append(eid)
	for key in group_order:
		_create_impl_task(world, groups[key])
	var tasks := world.table("task")
	for eid in Det.ordered(rows):
		var e: Dictionary = rows[eid]
		if e["status"] == "LEGAL" and e.get("impl_task", "") != "":
			var t: Dictionary = tasks.get(e["impl_task"], {})
			if t.get("status", "") == "COMPLETED":
				e["status"] = "SCHEDULED"
				e["due_month"] = int(t["completed_month"]) + maxi(1, int(world.lever_defs[e["lever"]].get("lag", 0)))
			elif t.get("status", "") == "CANCELLED":
				e["impl_task"] = ""   # stalled: enacted but not implemented until restarted
		if e["status"] == "SCHEDULED" and world.month >= int(e["due_month"]):
			_make_effective(world, eid, e)


static func _supersede(world: WorldState, newer: Dictionary) -> void:
	var rows := world.table("enactment")
	for eid in Det.ordered(rows):
		var e: Dictionary = rows[eid]
		if e["id"] != newer["id"] and e["lever"] == newer["lever"] and (e["status"] == "LEGAL" or e["status"] == "SCHEDULED"):
			e["status"] = "CANCELLED"
			e["cancelled_by"] = newer["id"]
			_maybe_cancel_task(world, e.get("impl_task", ""))


static func _maybe_cancel_task(world: WorldState, tid: String) -> void:
	if tid == "":
		return
	var t: Dictionary = world.table("task").get(tid, {})
	if t.is_empty() or t["status"] != "ACTIVE":
		return
	for e in Det.ordered(world.table("enactment")).map(func(k): return world.table("enactment")[k]):
		if e.get("impl_task", "") == tid and e["status"] == "LEGAL":
			return
	Staff.cancel_task(world, tid)


static func _create_impl_task(world: WorldState, eids: Array) -> void:
	var rows := world.table("enactment")
	var first: Dictionary = rows[eids[0]]
	var bill: String = String(first.get("source_bill", ""))
	var cls := impl_class(world.lever_defs[first["lever"]])
	var lever_ids: Array = []
	var deltas: Array = []
	for eid in eids:
		var e: Dictionary = rows[eid]
		lever_ids.append(e["lever"])
		var dir := 0
		if world.lever_defs[e["lever"]]["type"] == "NUMBER":
			dir = 1 if float(e["value"]) >= float(e["from"]) else -1
		elif world.lever_defs[e["lever"]]["type"] == "ENUM":
			var vals: Array = world.lever_defs[e["lever"]]["values"]
			dir = 1 if vals.find(e["value"]) >= vals.find(e["from"]) else -1
		deltas.append({"lever": e["lever"], "dir": dir})
	var params := {"levers": eids.size(), "lever_ids": lever_ids, "instrument_id": bill,
		"domain": Staff.lever_domain(world, first["lever"]), "lever_deltas": deltas,
		"work_multiplier": _defect_multiplier(world, bill)}
	var r := Staff.create_task(world, cls, params, Staff.GOV)
	if r["ok"]:
		for eid in eids:
			rows[eid]["impl_task"] = r["id"]


## Drafting defects (staff §3): each defective clause is discovered with p=0.5 when implementation starts
## and adds 25% to that clause's share of implementation work.
static func _defect_multiplier(world: WorldState, bill: String) -> float:
	if bill == "":
		return 1.0
	var draft := Staff.draft_for_bill(world, bill)
	if draft.is_empty() or draft["status"] != "COMPLETED":
		return 1.0
	var defects: Array = draft["outputs"].get("defects", [])
	if defects.is_empty():
		return 1.0
	var n_def := defects.count(true)
	var s := state(world)
	if not s["defects_checked"].has(bill):
		s["defects_checked"][bill] = true
		var rng := world.rng.stream("law.defects")
		for d in defects:
			if d and rng.randf() < SD.DEFECT_DISCOVERY:
				Staff.fact(world, "STAFF_DRAFTING_DEFECT_REVEALED", "PUBLIC", [Staff.GOV],
					[{"actor": Staff.GOV, "share": 0.7}, {"actor": Staff.official_ref(Staff._lead(draft)) if Staff._lead(draft) != "" else Staff.GOV, "share": 0.3}],
					{"GOVERNANCE": -10}, 15, {"bill": bill})
	return 1.0 + SD.DEFECT_WORK_EXTRA * float(n_def) / float(defects.size())


static func _make_effective(world: WorldState, eid: String, e: Dictionary) -> void:
	var old = world.levers.get(e["lever"])
	world.levers[e["lever"]] = e["value"]
	e["status"] = "EFFECTIVE"
	e["effective_month"] = world.month
	var owner: String = String(world.lever_defs[e["lever"]]["owner"]).to_upper()
	var actor := COMMANDER if e["legal_level"] == "ORDINANCE" else GOVERNMENT
	law_fact(world, "%s_LEVER_EFFECTIVE" % owner, "PUBLIC", [actor], [{"actor": actor, "share": 1.0}], {}, 20,
		{"lever": e["lever"], "from": old, "to": e["value"], "enactment": eid, "source_bill": e.get("source_bill", "")})


## Restart implementation of enacted-but-stalled changes (e.g. after the task was cancelled).
static func restart_implementation(world: WorldState, source_bill: String) -> void:
	var rows := world.table("enactment")
	var groups := {}
	var order: Array = []
	for eid in Det.ordered(rows):
		var e: Dictionary = rows[eid]
		if e["status"] == "LEGAL" and e.get("impl_task", "") == "" and String(e.get("source_bill", "")) == source_bill:
			var key := impl_class(world.lever_defs[e["lever"]])
			if not groups.has(key):
				groups[key] = []
				order.append(key)
			groups[key].append(eid)
	for k in order:
		_create_impl_task(world, groups[k])


# =====================================================================================  transition (spec §7.2)

static func maybe_adopt_constitution(world: WorldState) -> void:
	var s := state(world)
	if s["constitution"] or RE.era(world) != "PARLIAMENTARY":
		return
	var gov: Dictionary = world.table("pol").get("state", {}).get("government", {})
	if gov.is_empty():
		return   # caretaker commander until the first government takes office
	s["constitution"] = true
	s["constitution_month"] = world.month
	var rules := world.table("legal_rule")
	for rid in Det.ordered(rules):
		if rules[rid]["level"] == "CHARTER":
			rules[rid]["level"] = "CONSTITUTIONAL"
	for r in L.constitutional_rules():
		add_rule(world, r)
	var deemed := 0
	for e in Det.ordered(world.table("enactment")).map(func(k): return world.table("enactment")[k]):
		if e["legal_level"] == "ORDINANCE" and e["status"] != "REJECTED":
			e["deemed_statute"] = true
			deemed += 1
	bump_rules_version(world)
	law_fact(world, "LAW_CONSTITUTION_ADOPTED", "PUBLIC", [{"kind": "INSTITUTION", "id": "parliament"}],
		[{"actor": {"kind": "NATURE", "id": ""}, "share": 1.0}], {"FAIRNESS": 5}, 60, {"month": world.month})
	if deemed > 0:
		law_fact(world, "LAW_ORDINANCE_DEEMED", "PUBLIC", [COMMANDER], [{"actor": COMMANDER, "share": 1.0}], {}, 5,
			{"count": deemed})


# =====================================================================================  permit & licence office (spec §10)

const PERMIT_OFFICE := {"kind": "AUTHORITY", "id": "permit_office"}
const BASE_BUDGET := 6000          # milli-W_ref/month the office needs for full clerical capacity
const UNMANAGED_Q := 40000         # milli: decision quality when STAFF_SD_PERMITS is unmanaged


## A company applies for a licence/permit. criteria_ok = does the application meet the criteria
## (zone, safety plan; evaluated by econ/comp in v1). The decision comes from the queue in the JUSTICE phase.
static func apply_licence(world: WorldState, holder_id: String, kind: String, type: String, district: String,
		criteria_ok: bool, months: int = -1) -> String:
	var id := world.new_id("permit_app")
	world.table("permit_application")[id] = {"id": id, "holder_id": holder_id, "kind": kind, "type": type,
		"district": district, "criteria_ok": criteria_ok, "months": months, "submitted_month": world.month,
		"status": "QUEUED", "decided_month": -1, "wrong": false, "licence_id": ""}
	return id


## Decisions per month: floor((2 + 10e) x budget adequacy), e = STAFF_SD_PERMITS effectiveness.
static func permit_capacity(world: WorldState) -> int:
	var e := float(Staff.duty_effectiveness(world, "STAFF_SD_PERMITS")) / 1000.0
	var budget := float(world.levers.get("LAW_PERMIT_OFFICE_BUDGET", BASE_BUDGET))
	return int(floor((2.0 + 10.0 * e) * minf(1.0, budget / float(BASE_BUDGET))))


static func process_permits(world: WorldState) -> void:
	var apps := world.table("permit_application")
	var cap := permit_capacity(world)
	var q := float(Staff.duty_quality(world, "STAFF_SD_PERMITS", UNMANAGED_Q)) / 1000.0
	var p_wrong := (100.0 - q) / 400.0
	var rng := world.rng.stream("law.permits")
	for id in Det.ordered(apps):
		if cap <= 0:
			break
		var a: Dictionary = apps[id]
		if a["status"] != "QUEUED":
			continue
		cap -= 1
		var grant: bool = a["criteria_ok"]
		if rng.randf() < p_wrong:
			grant = not grant
			a["wrong"] = true
		a["decided_month"] = world.month
		var holder := {"kind": "COMPANY", "id": a["holder_id"]}
		var resp := [{"actor": PERMIT_OFFICE, "share": 0.5}, {"actor": GOVERNMENT, "share": 0.5}]
		if grant:
			a["status"] = "GRANTED"
			a["licence_id"] = grant_licence(world, a["holder_id"], a["kind"], a["type"], int(a["months"]))
			if a["wrong"]:
				var fid := law_fact(world, "LAW_PERMIT_WRONGLY_GRANTED", "SECRET", [holder, PERMIT_OFFICE], resp,
					{"SAFETY": -5}, 15, {"application": id, "type": a["type"], "holder": a["holder_id"]})
				world.table("unlawful_track")[fid] = {"fact": fid, "month": world.month, "kind": "PERMIT",
					"executor": "", "burdened": false, "burdened_ref": {}, "revealed": false}
		else:
			a["status"] = "DENIED"
			if a["wrong"]:
				law_fact(world, "LAW_PERMIT_WRONGLY_DENIED", "PUBLIC", [holder, PERMIT_OFFICE], resp,
					{"GOVERNANCE": -3}, 10, {"application": id, "type": a["type"], "district": a["district"]})
			else:
				law_fact(world, "LAW_PERMIT_DENIED", "OFFICIAL", [holder, PERMIT_OFFICE],
					[{"actor": PERMIT_OFFICE, "share": 1.0}], {}, 5, {"application": id, "type": a["type"]})


## Mean months waited per district: age of queued applications, else waits of decisions in the last 6 months.
static func permit_wait_by_district(world: WorldState) -> Dictionary:
	var apps := world.table("permit_application")
	var queued := {}
	var decided := {}
	for id in Det.ordered(apps):
		var a: Dictionary = apps[id]
		var d: String = a["district"]
		if a["status"] == "QUEUED":
			if not queued.has(d):
				queued[d] = []
			queued[d].append(world.month - int(a["submitted_month"]))
		elif world.month - int(a["decided_month"]) <= 6:
			if not decided.has(d):
				decided[d] = []
			decided[d].append(int(a["decided_month"]) - int(a["submitted_month"]))
	var out := {}
	for src in [decided, queued]:   # a growing queue overrides past waits: it is what applicants feel now
		for d in src:
			var s := 0.0
			for x in src[d]:
				s += float(x)
			out[d] = s / float(src[d].size())
	return out


# =====================================================================================  unlawful government action (spec §8)

const UNLAWFUL_MAGNITUDE := {"MINOR": 30, "SERIOUS": 50, "SEVERE": 70}
const P_LEAK := 0.03
const P_COMPLAINT := 0.10
const TRACK_MONTHS := 36


## The government (player or AI) knowingly proceeds with a PROHIBITED action. The caller executes the action;
## law records the SECRET ground truth. burdened = ActorRef harmed by it ({} if none).
static func proceed_unlawfully(world: WorldState, actor: Dictionary, action: String, params: Dictionary,
		executor_pid: String = "", burdened: Dictionary = {}, penalty_class: String = "SERIOUS") -> Dictionary:
	var res := validate(world, actor, action, params)
	if res["result"] != "PROHIBITED":
		return {"ok": false, "reason": "action is not prohibited (%s)" % res["result"]}
	var resp: Array = [{"actor": actor, "share": 1.0}]
	if executor_pid != "":
		resp = [{"actor": actor, "share": 0.8}, {"actor": {"kind": "OFFICIAL", "id": executor_pid}, "share": 0.2}]
	var subjects: Array = [actor]
	if not burdened.is_empty():
		subjects.append(burdened)
	var fid := law_fact(world, "LAW_UNLAWFUL_GOV_ACTION", "SECRET", subjects, resp, {"GOVERNANCE": -15, "FAIRNESS": -10},
		int(UNLAWFUL_MAGNITUDE.get(penalty_class, 50)),
		{"action": action, "params": params, "trace": res["trace"], "reason": res["reason"], "class": penalty_class})
	world.table("unlawful_track")[fid] = {"fact": fid, "month": world.month, "kind": "GOV", "executor": executor_pid,
		"burdened": not burdened.is_empty(), "burdened_ref": burdened, "revealed": false}
	return {"ok": true, "fact": fid}


## D7 hook: what an AI government should expect from acting unlawfully over `horizon` months.
## {p_reveal, rule_of_law_drop (points at reveal), governance_impact (fact impact), p_overturn_if_revealed}
static func unlawful_expected_cost(penalty_class: String = "SERIOUS", burdened: bool = true, horizon: int = 24) -> Dictionary:
	var stay := pow(1.0 - P_LEAK, horizon) * (pow(1.0 - P_COMPLAINT, horizon) if burdened else 1.0)
	var mag := float(UNLAWFUL_MAGNITUDE.get(penalty_class, 50))
	return {"p_reveal": 1.0 - stay, "rule_of_law_drop": RULE_OF_LAW_PER_ACT * mag / 50.0, "governance_impact": -15,
		"p_overturn_if_revealed": 0.9 if burdened else 0.0}


## Monthly discovery: civil-service leaks and complaints by the burdened party; oversight reveals
## (staff, via the shared revealed_fact table) are picked up so nothing is revealed twice.
static func discover(world: WorldState) -> void:
	var track := world.table("unlawful_track")
	var revealed := world.table("revealed_fact")
	var rng := world.rng.stream("law.discovery")
	for fid in Det.ordered(track):
		var t: Dictionary = track[fid]
		if t["revealed"]:
			continue
		if revealed.has(fid):
			t["revealed"] = true
			continue
		if t["kind"] != "GOV" or world.month - int(t["month"]) > TRACK_MONTHS:
			continue   # wrongly granted permits surface through accidents / inspections (M6)
		var p_leak := P_LEAK
		if t["executor"] != "" and int(Staff.person(world, t["executor"]).get("integrity", 70)) < 40:
			p_leak *= 0.5
		var by: Array = []
		if rng.randf() < p_leak:
			by = [{"kind": "OFFICIAL", "id": "civil_service"}]
		elif t["burdened"] and rng.randf() < P_COMPLAINT:
			by = [t["burdened_ref"]]
		if not by.is_empty():
			revealed[fid] = true
			t["revealed"] = true
			world.facts.reveal(world.month, fid, by)


# =====================================================================================  indicators (pic-staff-law §1)

const RULE_OF_LAW_PER_ACT := 20.0     # points lost per revealed magnitude-50 act
const RULE_OF_LAW_HALF_LIFE := 12.0   # months
const TRUST_START := 55.0
const TRUST_SPEED := 0.1
const TRUST_WEIGHTS := {"BUSINESS_OWNER": [35, 15, 20], "INDUSTRY": [15, 35, 20], "MINING": [15, 35, 20]}
const TRUST_DEFAULT := [25, 25, 20]
const CONSISTENCY_PRE_M6 := 0.5
const WORKING_OCCS := ["AGRICULTURE", "INDUSTRY", "MINING", "SERVICES", "PUBLIC_SECTOR", "BUSINESS_OWNER"]
## Accidents per 1,000 workers per year (milli) by safety standard, used until econ emits COMP_WORKPLACE_ACCIDENT
## (88's expected rates: ~3.75 BASIC, ~2.6 STANDARD, ~1.7 STRICT).
const STUB_ACCIDENT_RATE := {"BASIC": 3750, "STANDARD": 2600, "STRICT": 1700}


static func rule_of_law(world: WorldState) -> float:
	var v := 100.0
	for f in world.facts.query("LAW_UNLAWFUL_GOV_ACTION_REVEALED", world.month - 120, world.month, "PUBLIC"):
		var age := float(world.month - int(f["month"]))
		v -= RULE_OF_LAW_PER_ACT * (float(f["magnitude"]) / 50.0) * pow(0.5, age / RULE_OF_LAW_HALF_LIFE)
	# Court rulings against the government (M6) count half: the act itself was already counted when revealed.
	for f in world.facts.query("LAW_RULING", world.month - 120, world.month, "PUBLIC"):
		if f["data"].get("against_government", false):
			var age := float(world.month - int(f["month"]))
			v -= 0.5 * RULE_OF_LAW_PER_ACT * (float(f["magnitude"]) / 50.0) * pow(0.5, age / RULE_OF_LAW_HALF_LIFE)
	return clampf(v, 0.0, 100.0)


static func write_indicators(world: WorldState) -> void:
	var census := world.table("census")
	var districts := {}
	var workers := {}
	var occs := {}
	for key in Det.ordered(census):
		var parts: PackedStringArray = String(key).split("|")
		if parts.size() < 3:
			continue
		districts[parts[0]] = true
		occs[parts[1]] = true
		if WORKING_OCCS.has(parts[1]):
			workers[parts[0]] = int(workers.get(parts[0], 0)) + int(census[key])
	var s := state(world)
	# Rule of law (colony)
	var rol := rule_of_law(world)
	world.set_indicator("law", "LAW_RULE_OF_LAW", "COLONY", int(round(rol * 1000.0)))
	# Permit wait (district)
	# Only districts with applications in the window publish a wait (a constant 0 would dilute GOVERNANCE).
	var waits := permit_wait_by_district(world)
	var wsum := 0.0
	for d in waits:
		wsum += float(waits[d])
		world.set_indicator("law", "LAW_PERMIT_WAIT", d, int(round(float(waits[d]) * 1000.0)))
	var mean_wait := wsum / float(waits.size()) if not waits.is_empty() else 0.0
	# Trust in justice (voter cell): per occupation, moves 10%/month toward its target
	if not s.has("trust"):
		s["trust"] = {}
	# M6: courts and inspectorate (published only when there is data)
	var consistency := Justice.enforcement_consistency(world)
	if consistency >= 0.0:
		world.set_indicator("law", "LAW_ENFORCEMENT_CONSISTENCY", "COLONY", int(round(consistency * 1000.0)))
	var duration := Justice.court_duration(world)
	if duration >= 0.0:
		world.set_indicator("law", "LAW_COURT_DURATION", "COLONY", int(round(duration * 1000.0)))
	var timeliness := clampf(1.0 - mean_wait / 12.0, 0.0, 1.0)
	if duration >= 0.0:
		timeliness = 0.5 * timeliness + 0.5 * clampf(1.0 - duration / 24.0, 0.0, 1.0)
	var cons := consistency / 100.0 if consistency >= 0.0 else CONSISTENCY_PRE_M6
	var lawful := rol / 100.0
	for occ in occs:
		var wts: Array = TRUST_WEIGHTS.get(occ, TRUST_DEFAULT)
		var target := 30.0 + float(wts[0]) * timeliness + float(wts[1]) * cons + float(wts[2]) * lawful
		var prev := float(s["trust"].get(occ, int(TRUST_START * 1000.0))) / 1000.0
		s["trust"][occ] = int(round((prev + TRUST_SPEED * (target - prev)) * 1000.0))
	for key in Det.ordered(census):
		var parts: PackedStringArray = String(key).split("|")
		if parts.size() >= 3:
			world.set_indicator("law", "LAW_TRUST_IN_JUSTICE", key, int(s["trust"][parts[1]]))
	# Workplace safety (district): published only when the real economy runs (it publishes ECON_W_REF);
	# under the stub world STUB_ACCIDENTS already covers SAFETY and a second, lever-only series would dilute it.
	# Uses accident facts once any exist, else the lever-based expected rate.
	if Staff.world_value(world, "ECON_W_REF", null) == null:
		return
	var accidents := {}
	for f in world.facts.query("COMP_WORKPLACE_ACCIDENT", world.month - 11, world.month):
		s["accident_facts_seen"] = true
		var d: String = String(f["data"].get("district", f.get("location", "")))
		accidents[d] = int(accidents.get(d, 0)) + 1
	var stub := int(STUB_ACCIDENT_RATE.get(String(world.levers.get("LAW_SAFETY_STANDARD", "BASIC")), 3750))
	var months := float(mini(12, world.month + 1))
	for d in districts:
		var rate := stub
		if s.get("accident_facts_seen", false):
			var wk := maxi(1, int(workers.get(d, 0)))
			rate = int(round(float(accidents.get(d, 0)) / float(wk) * 1000.0 * 12.0 / months * 1000.0))
		world.set_indicator("law", "LAW_WORKPLACE_SAFETY", d, rate)


# =====================================================================================  extra elections (M7)

## The one gate for extra elections (politics calls it before scheduling one).
## mandatory = required by the constitution (e.g. 4 failed PM votes): always lawful, even for a caretaker.
## Discretionary: no constitution yet -> no; < 3 months after an election -> no; then the rules engine decides
## HOLD_ELECTION {extra: true} for the GOVERNMENT (the caretaker ban lives there as a constitutional rule).
## {ok, reason, months_since_election, next_ordinary_month, resets_ordinary_calendar, trace}
static func check_extra_election(world: WorldState, mandatory: bool = false) -> Dictionary:
	var st: Dictionary = world.peek("pol").get("state", {})
	var ee: Dictionary = L.PROCEDURES["extra_election"]
	var last := -999
	for eid in st.get("elections", []):
		last = maxi(last, int(world.peek("election").get(eid, {}).get("month", -999)))
	var out := {"ok": false, "reason": "", "months_since_election": world.month - last,
		"next_ordinary_month": int(st.get("next_election", -1)), "resets_ordinary_calendar": ee["resets_ordinary_calendar"], "trace": []}
	if mandatory:
		out["ok"] = true
		out["reason"] = "required by the constitution"
		return out
	if not state(world)["constitution"]:
		out["reason"] = "The first election is fixed by the charter."
		return out
	if world.month - last < int(ee["blocked_months_after_election"]):
		out["reason"] = "No extra election within %d months of an election (%d months so far)." % [ee["blocked_months_after_election"], world.month - last]
		return out
	var res := RE.validate(world, GOVERNMENT, "HOLD_ELECTION", {"extra": true})
	out["trace"] = res["trace"]
	if res["result"] != "AUTHORIZED":
		out["reason"] = "A caretaker government may not call an extra election." if bool(st.get("caretaker", false)) \
			else "Not authorized: %s" % res["reason"]
		return out
	out["ok"] = true
	return out

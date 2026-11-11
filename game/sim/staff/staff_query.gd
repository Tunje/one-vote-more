extends RefCounted
## Read-only accessors for the UI (planning/ui-staff-law.md §1–§2). Pure: never mutates the world.
## All mutations go through sim/staff/staff_law_actions.gd (pic-core §6).

const Ops := preload("res://sim/staff/staff_ops.gd")
const D := preload("res://sim/staff/staff_data.gd")
const W := preload("res://sim/staff/work_model.gd")
const Q := preload("res://sim/staff/qualification.gd")
const Det := preload("res://sim/staff/det.gd")
const Vis := preload("res://sim/law/visibility.gd")

const CATEGORY_TEXT := {
	"DECISION_REQUIRED": "Decision required", "COMPLETED": "Completed", "ATTENTION": "Attention",
	"ROUTINE": "Routine", "AVAILABLE": "Available",
}
const PROBLEM_TEXT := {
	"ERROR": "made an error this month (no progress)", "ILL": "was unavailable (illness)",
	"PAUSED": "work paused: a mandatory position is vacant", "BLOCKED": "work blocked: waiting for your decision",
	"FRICTION": "objects to this task (conflicts with their party's position)",
}


static func task_name(def_id: String) -> String:
	return def_id.trim_prefix("STAFF_T_").trim_prefix("STAFF_SD_").replace("_", " ").capitalize()


static func requirements_text(pos: Dictionary, domain: String) -> String:
	var paths: Array = []
	for p in pos["paths"]:
		var parts: Array = []
		var mins: Dictionary = p.get("min", {})
		for k in mins:
			parts.append("%s ≥ %d" % [domain if k == "DOMAIN" else k, int(mins[k])])
		for t in p.get("talents", []):
			parts.append(String(t).replace("_", " ").capitalize())
		paths.append(" + ".join(parts) if not parts.is_empty() else "anyone")
	return " or ".join(paths)


static func progress_pct(t: Dictionary) -> int:
	var def: Dictionary = D.TASKS[t["def_id"]]
	if def.get("coverage", false):
		return int(t["coverage"]) / 10
	if def.has("fixed_months"):
		return mini(100, 100 * int(t["months_active"]) / int(def["fixed_months"]))
	if int(t["work_required"]) <= 0:
		return 0
	return mini(100, 100 * int(t["progress"]) / int(t["work_required"]))


# ======================================================================  (a) personnel

## PersonView for one person.
static func person_view(world: WorldState, pid: String, viewer: Dictionary = {}) -> Dictionary:
	var p := Ops.person(world, pid)
	if p.is_empty():
		return {}
	if not Vis.is_sim(viewer) and not _sees_person(world, viewer, p):
		return {"id": pid, "name": p["name"], "age": Ops.age_years(world, p), "party_id": p["party_id"],
			"category": "CIVIL_SERVANT" if p["roles"].has("CIVIL_SERVANT") else "POLITICAL",
			"specialization": p["specialization"], "status": p["status"], "public_only": true}
	var asg := {}
	if p["assignment_id"] != "":
		var a: Dictionary = world.table("assignment")[p["assignment_id"]]
		var t := Ops.task(world, a["task_id"])
		asg = {"task_id": a["task_id"], "def_id": t["def_id"], "task_name": task_name(t["def_id"]), "pos": a["pos"],
			"role": Ops.pos_def(t, int(a["pos"]))["role"], "start_month": a["start_month"], "task_progress_pct": progress_pct(t)}
	var cat := "CIVIL_SERVANT" if p["roles"].has("CIVIL_SERVANT") else ("POLITICAL" if p["pool"] == "GOV" else "PARTY_STAFF")
	return {"id": pid, "name": p["name"], "age": Ops.age_years(world, p), "category": cat, "party_id": p["party_id"],
		"specialization": p["specialization"], "skills": p["skills"].duplicate(), "talents": p["talents"].duplicate(),
		"work_speed": p["work_speed"], "reliability": p["reliability"], "status": p["status"], "pool": p["pool"],
		"available": p["status"] == "ACTIVE" and p["assignment_id"] == "", "assignment": asg,
		"career": p["career"].duplicate(true)}


## Everyone who can work for the owner, available first, then by creation order.
static func roster(world: WorldState, owner: Dictionary, viewer: Dictionary = {}) -> Array:
	if not Vis.can_see_owner(world, viewer, owner):
		return []
	var out: Array = []
	for pid in Ops.pool_members(world, owner):
		out.append(person_view(world, pid))
	out.sort_custom(func(a, b): return a["available"] and not b["available"])
	return out


static func summary(world: WorldState, owner: Dictionary, viewer: Dictionary = {}) -> Dictionary:
	if not Vis.can_see_owner(world, viewer, owner):
		return {}
	var members := Ops.pool_members(world, owner)
	var avail := Ops.available(world, owner)
	var vacant_seats := 0
	if owner["kind"] == "GOVERNMENT":
		for sid in Det.ordered(world.table("gov_seat")):
			if world.table("gov_seat")[sid]["person_id"] == "":
				vacant_seats += 1
	var needing := open_positions(world, owner).filter(func(x): return x["mandatory"]).size()
	var open_dec := decision_requests(world, owner).size()
	return {"total": members.size(), "available": avail.size(), "assigned": members.size() - avail.size(),
		"vacant_seats": vacant_seats, "mandatory_vacancies": needing, "decisions": open_dec}


## TaskView: everything the task panel shows.
static func task_view(world: WorldState, tid: String, viewer: Dictionary = {}) -> Dictionary:
	var t := Ops.task(world, tid)
	if t.is_empty() or not Vis.can_see_owner(world, viewer, t.get("owner", {})):
		return {}
	var def: Dictionary = D.TASKS[t["def_id"]]
	var domain := Q.domain_of(t["params"])
	var positions: Array = []
	for i in t["positions"].size():
		var pd := Ops.pos_def(t, i)
		var holder: String = t["positions"][i]["assigned"]
		positions.append({"idx": i, "role": pd["role"], "mandatory": pd["mandatory"], "assigned": holder,
			"assigned_name": Ops.person(world, holder).get("name", "") if holder != "" else "",
			"requirements": requirements_text(pd, domain)})
	return {"id": tid, "def_id": t["def_id"], "name": task_name(t["def_id"]), "category": def["category"],
		"mode": t["mode"], "preset": t["preset"], "status": t["status"], "paused": t["paused"],
		"blocked": Ops.task_blocked(world, tid), "owner": t["owner"], "progress_pct": progress_pct(t),
		"quality": int(t["quality"]) / 1000, "coverage_pct": int(t["coverage"]) / 10,
		"effectiveness_pct": int(t["effectiveness"]) / 10, "stage": t["stage"], "stages": t.get("stages", []).size(),
		"positions": positions, "outputs": t["outputs"].duplicate(true), "start_month": t["start_month"],
		"source_bill": t["params"].get("source_bill", ""), "target": t["params"].get("target", "")}


static func tasks(world: WorldState, owner: Dictionary, include_closed: bool = false, viewer: Dictionary = {}) -> Array:
	if not Vis.can_see_owner(world, viewer, owner):
		return []
	var out: Array = []
	var key := Ops.owner_key(owner)
	for tid in Det.ordered(world.table("task")):
		var t: Dictionary = world.table("task")[tid]
		if Ops.owner_key(t["owner"]) == key and (include_closed or t["status"] == "ACTIVE"):
			out.append(task_view(world, tid))
	return out


## Vacant positions on the owner's active tasks (for "Official -> select task").
static func open_positions(world: WorldState, owner: Dictionary, viewer: Dictionary = {}) -> Array:
	if not Vis.can_see_owner(world, viewer, owner):
		return []
	var out: Array = []
	for tv in tasks(world, owner):
		for p in tv["positions"]:
			if p["assigned"] == "":
				out.append({"task_id": tv["id"], "task_name": tv["name"], "pos": p["idx"], "role": p["role"],
					"mandatory": p["mandatory"], "requirements": p["requirements"]})
	return out


## Candidate comparison for one position (S §10.7): every pool member, eligible first, best estimate first.
static func candidates(world: WorldState, tid: String, idx: int, viewer: Dictionary = {}) -> Array:
	var t := Ops.task(world, tid)
	if t.is_empty() or not Vis.can_see_owner(world, viewer, t.get("owner", {})):
		return []
	var def: Dictionary = D.TASKS[t["def_id"]]
	var pd := Ops.pos_def(t, idx)
	var domain := Q.domain_of(t["params"])
	var out: Array = []
	for pid in Ops.pool_members(world, t["owner"]):
		var p := Ops.person(world, pid)
		var e := Ops.eligibility(world, tid, idx, pid, true)
		var suit := W.suitability(p, pd["weights"], domain)
		var al := Ops.alignment(world, t, p)
		var matches: Array = []
		for tal in p["talents"]:
			var td: Dictionary = D.TALENTS.get(tal, {})
			if W._tag_match(td.get("tags", td.get("q_tags", [])), def["tags"]):
				matches.append(tal)
		out.append({"person_id": pid, "name": p["name"], "eligible": e["ok"], "reason": e["reason"],
			"path": Q.path_index(p, pd, domain), "suitability": int(round(suit)),
			"est_work": snappedf(W.individual_w(p, pd["mandatory"], suit, def["tags"], t["mode"], al["mult"]), 0.1),
			"est_quality": int(round(W.member_q(p, suit, def["tags"], t["mode"]))), "talent_matches": matches,
			"coalition": "REFUSES" if al["refuse"] else ("RELUCTANT" if al["friction"] else ("KEEN" if al["mult"] > 1.0 else "")),
			"currently": person_view(world, pid)["assignment"]})
	out.sort_custom(func(a, b):
		if a["eligible"] != b["eligible"]:
			return a["eligible"]
		return a["est_work"] > b["est_work"])
	return out


## Government seats (founding appointees / coalition allocation) with their holders.
static func seats(world: WorldState) -> Array:
	var out: Array = []
	for sid in Det.ordered(world.table("gov_seat")):
		var s: Dictionary = world.table("gov_seat")[sid]
		out.append({"seat_id": sid, "party_id": s["party_id"], "person_id": s["person_id"],
			"name": Ops.person(world, s["person_id"]).get("name", "") if s["person_id"] != "" else ""})
	return out


## Bench people a party could appoint to a seat.
static func bench(world: WorldState, party_id: String) -> Array:
	return Ops._bench(world, party_id).map(func(pid): return person_view(world, pid))


static func recruitments(world: WorldState) -> Array:
	var out: Array = []
	for rid in Det.ordered(world.table("recruitment")):
		var r: Dictionary = world.table("recruitment")[rid]
		if r["status"] == "OPEN":
			out.append({"id": rid, "spec": r["spec"], "opened_month": r["opened_month"], "picked": r["picked"],
				"hire_month": r["hire_month"], "shortlist": r["shortlist"].map(func(p): return {"name": p["name"],
				"skills": p["skills"].duplicate(), "talents": p["talents"].duplicate(), "work_speed": p["work_speed"],
				"reliability": p["reliability"]})})
	return out


# ======================================================================  (b) monthly briefing

static func report_text(world: WorldState, r: Dictionary) -> String:
	var name: String = Ops.person(world, r["staff_id"]).get("name", "?")
	var t := Ops.task(world, r["task_id"]) if r["task_id"] != "" else {}
	var tn := task_name(t["def_id"]) if not t.is_empty() else ""
	var probs: Array = r["problems"].map(func(p): return PROBLEM_TEXT.get(p, p))
	match r["category"]:
		"AVAILABLE":
			return "%s is available for a new assignment." % name + (" " + "; ".join(probs) if not probs.is_empty() else "")
		"COMPLETED":
			return "%s completed %s." % [name, tn]
		"DECISION_REQUIRED":
			return "%s needs your decision on %s." % [name, tn]
		"ATTENTION":
			return "%s on %s: %s." % [name, tn, "; ".join(probs)]
	return "%s: %s progressing (+%.1f work units, %d%% done)." % [name, tn, float(r["progress_change"]) / 1000.0,
		progress_pct(t) if not t.is_empty() else 0]


static func decision_view(world: WorldState, rid: String) -> Dictionary:
	var r: Dictionary = world.table("decision_request")[rid]
	var t := Ops.task(world, r["task_id"])
	var text := "Decision needed on %s." % task_name(t.get("def_id", ""))
	if r["kind"] == "COMMITMENT":
		text = "The %s team wants to commit %.1f credits, beyond its delegated authority (%s)." % [
			task_name(t.get("def_id", "")), float(r["data"]["amount"]) / 1000.0, t.get("preset", "")]
	return {"id": rid, "task_id": r["task_id"], "kind": r["kind"], "month": r["month"], "text": text,
		"options": r["options"].map(func(o): return {"id": o, "label": String(o).capitalize(), "recommended": o == r["recommended"]})}


static func decision_requests(world: WorldState, owner: Dictionary, viewer: Dictionary = {}) -> Array:
	if not Vis.can_see_owner(world, viewer, owner):
		return []
	var out: Array = []
	var key := Ops.owner_key(owner)
	for rid in Det.ordered(world.table("decision_request")):
		var r: Dictionary = world.table("decision_request")[rid]
		var t := Ops.task(world, r["task_id"])
		if r["status"] == "OPEN" and not t.is_empty() and Ops.owner_key(t["owner"]) == key:
			out.append(decision_view(world, rid))
	return out


## The briefing for the month just simulated: individual reports by priority, open decisions, consolidated tasks.
static func briefing(world: WorldState, owner: Dictionary, month: int = -1, viewer: Dictionary = {}) -> Dictionary:
	if not Vis.can_see_owner(world, viewer, owner):
		return {}
	var m := world.month - 1 if month < 0 else month
	var members := Ops.pool_members(world, owner)
	var items: Array = []
	for rid in Det.ordered(world.table("staff_report")):
		var r: Dictionary = world.table("staff_report")[rid]
		if int(r["month"]) != m or not members.has(r["staff_id"]):
			continue
		items.append({"priority": r["priority"], "category": r["category"], "label": CATEGORY_TEXT[r["category"]],
			"staff_id": r["staff_id"], "task_id": r["task_id"], "text": report_text(world, r),
			"progress_change": r["progress_change"], "problems": r["problems"].duplicate(),
			"collapsed": r["category"] == "ROUTINE" or r["category"] == "AVAILABLE",
			"n": int(Ops.person(world, r["staff_id"]).get("n", 0))})
	items.sort_custom(func(a, b):
		if a["priority"] != b["priority"]:
			return a["priority"] > b["priority"]
		return a["n"] < b["n"])
	return {"month": m, "items": items, "decisions": decision_requests(world, owner), "tasks": tasks(world, owner),
		"summary": summary(world, owner), "failed_actions": failed_actions(world, m, viewer) if owner["kind"] == "GOVERNMENT" else []}


## A person's full profile is visible to whoever may see the staff pool they work in.
static func _sees_person(world: WorldState, viewer: Dictionary, p: Dictionary) -> bool:
	if p["pool"] == "GOV":
		return Vis.can_see_owner(world, viewer, Ops.GOV)
	if String(p["pool"]).begins_with("PARTY:"):
		return Vis.can_see_owner(world, viewer, {"kind": "PARTY", "id": String(p["pool"]).substr(6)})
	return p["bench_party_id"] == viewer.get("party_id", "")


## Government orders that were refused when the month ran (88's ECON_ACTION_FAILED; OFFICIAL, so the government only).
## [{month, action, error, params, district}]
static func failed_actions(world: WorldState, month: int, viewer: Dictionary = {}) -> Array:
	var out: Array = []
	for f in world.facts.query("ECON_ACTION_FAILED", month, month):
		if Vis.can_see_fact(world, viewer, f):
			out.append({"month": f["month"], "action": String(f["data"].get("action", "")), "error": String(f["data"].get("error", "")),
				"params": f["data"].get("params", {}).duplicate(true), "district": f.get("location", null)})
	return out


## Named persons employed now, for population/labour reconciliation (spec-population-v1 §12, PD §11.5).
## public = government officials + civil servants + judges (subtract from PUBLIC_SECTOR employment);
## party = opposition party staff (private employers: subtract from PROFESSIONAL). Bench/departed people are not employed.
static func named_headcount(world: WorldState) -> Dictionary:
	var out := {"political": 0, "civil": 0, "judges": 0, "party": 0, "public": 0}
	var people := world.peek("person")
	for pid in Det.ordered(people):
		var p: Dictionary = people[pid]
		if not (p["status"] == "ACTIVE" or p["status"] == "UNAVAILABLE"):
			continue
		if p["pool"] == "GOV":
			if p["roles"].has("GOV_POLITICAL"):
				out["political"] += 1
			else:
				out["civil"] += 1
		elif String(p["pool"]).begins_with("PARTY:"):
			out["party"] += 1
	var judges := world.peek("judge")
	for jid in Det.ordered(judges):
		if judges[jid]["status"] == "ACTIVE":
			out["judges"] += 1
	out["public"] = out["political"] + out["civil"] + out["judges"]
	return out

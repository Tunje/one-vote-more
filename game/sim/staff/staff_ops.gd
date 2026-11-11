extends RefCounted
## Staff state operations (planning/spec-staff-v1.md). Stateless: every function takes the WorldState.
##
## Tables owned by staff:
##   person, task, assignment, staff_report, decision_request, gov_seat, recruitment, staff_state
## Tables read (owned by others): party (pol), government (pol), lever_change (law), law_state (law)
##
## Player/AI actions call the op functions between ticks (planning phase). The provider calls the
## *_phase functions inside the tick.

const Det := preload("res://sim/staff/det.gd")
const D := preload("res://sim/staff/staff_data.gd")
const W := preload("res://sim/staff/work_model.gd")
const Q := preload("res://sim/staff/qualification.gd")
const RG := preload("res://sim/staff/roster_gen.gd")
const Vis := preload("res://sim/law/visibility.gd")

const GOV := {"kind": "GOVERNMENT", "id": "government"}
const MILLI := 1000


# =====================================================================================  helpers

static func state(world: WorldState) -> Dictionary:
	var t := world.table("staff_state")
	if not t.has("s"):
		t["s"] = {"seq": 0, "flags": {}, "completed_now": {}, "overdue_reported": {}, "benches": {},
			"report_counts": {}, "friction_month": {}}
	return t["s"]


## Political state is owned by politics (Wilma): world.table("pol")["state"].
static func pol_state(world: WorldState) -> Dictionary:
	return world.peek("pol").get("state", {})


static func era(world: WorldState) -> String:
	return String(pol_state(world).get("era", "FOUNDING"))


static func gov_record(world: WorldState) -> Dictionary:
	return pol_state(world).get("government", {})


static func is_caretaker(world: WorldState) -> bool:
	return bool(pol_state(world).get("caretaker", false))


static func player_party(world: WorldState) -> String:
	var st := pol_state(world)
	if st.has("player_party"):
		return String(st["player_party"])
	var parties: Dictionary = world.peek("party")
	for pid in Det.ordered(parties):
		if parties[pid].get("is_player", false):
			return pid
	return ""


static func party_active(world: WorldState, pid: String) -> bool:
	return String(world.peek("party").get(pid, {}).get("status", "ACTIVE")) == "ACTIVE"


static func pm_party(world: WorldState) -> String:
	if era(world) == "FOUNDING":
		return player_party(world)
	return String(gov_record(world).get("pm_party", player_party(world)))


static func owner_key(owner: Dictionary) -> String:
	return "GOVERNMENT" if owner["kind"] == "GOVERNMENT" else "PARTY:" + String(owner["id"])


## Is this owner run by the AI (or by the headless autoplay flag)?
static func autopilot(world: WorldState, owner: Dictionary) -> bool:
	if world.meta.get("staff_autoplay", false) or bool(pol_state(world).get("autoplay_player", false)):
		return true
	var pp := player_party(world)
	if owner["kind"] == "GOVERNMENT":
		return era(world) == "PARLIAMENTARY" and pm_party(world) != pp
	return String(owner["id"]) != pp


static func owner_actor(world: WorldState, owner: Dictionary) -> Dictionary:
	if owner["kind"] == "GOVERNMENT":
		return {"kind": "COMMANDER", "id": "commander"} if era(world) == "FOUNDING" else GOV
	return {"kind": "PARTY", "id": owner["id"]}


static func fact(world: WorldState, type: String, visibility: String, subjects: Array, responsible: Array,
		impact: Dictionary, magnitude: int, data: Dictionary = {}, causes: Array = []) -> String:
	return world.add_fact({"type": type, "owner": "staff", "subjects": subjects, "responsible": responsible,
		"impact": impact, "magnitude": magnitude, "visibility": visibility, "data": data, "causes": causes})


static func official_ref(pid: String) -> Dictionary:
	return {"kind": "OFFICIAL", "id": pid}


static func flag(world: WorldState, pid: String, f: String) -> void:
	var flags: Dictionary = state(world)["flags"]
	if not flags.has(pid):
		flags[pid] = []
	if not flags[pid].has(f):
		flags[pid].append(f)


## World scalar values (88 publishes ECON_W_REF there). Falls back to meta if the kernel has no `values` yet.
static func world_value(world: WorldState, key: String, default_value):
	var vals = world.get("values")
	if vals is Dictionary and vals.has(key):
		return vals[key]
	return world.meta.get(key, default_value)


static func w_ref_milli(world: WorldState) -> int:
	# Average monthly Skilled wage published by econ (88, E36). Default 1,200 credits until econ runs.
	return int(world_value(world, "ECON_W_REF", 1200 * Ledger.SCALE))


## Charge a W_ref-denominated cost to the owner's account if it exists (econ/pol create the accounts).
## Closed economy (A34): training, hiring and task costs are paid to colony households (trainers, recruiters,
## suppliers), pro rata to population. Only a world without households (staff-only tests) pays EXTERNAL.
static func charge(world: WorldState, owner: Dictionary, cost_wref: float, memo: String) -> void:
	var acct: String = "gov:treasury" if owner["kind"] == "GOVERNMENT" else "party:" + String(owner["id"])
	if cost_wref <= 0.0 or not world.ledger.has_account(acct):
		return
	var amount := int(round(cost_wref * float(w_ref_milli(world))))
	if not world.ledger.allow_negative.get(acct, false):
		amount = mini(amount, maxi(0, world.ledger.balance(acct)))
	if amount <= 0:
		return
	var accts: Array = []
	var weights: Array = []
	var hh := world.peek("hh")
	for gid in Det.ordered(hh):
		var a := EconUtil.hh_acct(String(gid))
		if world.ledger.has_account(a):
			accts.append(a)
			weights.append(EconHouseholds.persons(hh[gid]))
	if accts.is_empty():
		world.ledger.transfer(acct, Ledger.EXTERNAL, amount, memo, world.month)
		return
	var parts := EconUtil.split_lr(amount, weights)
	for i in accts.size():
		if int(parts[i]) > 0:
			world.ledger.transfer(acct, accts[i], int(parts[i]), memo, world.month)


# =====================================================================================  people & pools

static func add_person(world: WorldState, p: Dictionary, pool: String, bench_party: String) -> String:
	var id := world.new_id("person")
	var s := state(world)
	s["seq"] = int(s["seq"]) + 1
	p["id"] = id
	p["n"] = s["seq"]
	p["pool"] = pool
	p["bench_party_id"] = bench_party
	world.table("person")[id] = p
	return id


static func person(world: WorldState, pid: String) -> Dictionary:
	return world.table("person").get(pid, {})


static func age_years(world: WorldState, p: Dictionary) -> int:
	return int(floor(float(world.month - int(p["birth_month"])) / 12.0))


static func is_alive_active(p: Dictionary) -> bool:
	return p["status"] == "ACTIVE" or p["status"] == "UNAVAILABLE"


## Persons who may work for this owner (spec §7.4, §8).
static func pool_members(world: WorldState, owner: Dictionary) -> Array:
	var out: Array = []
	var people := world.table("person")
	for pid in Det.ordered(people):
		var p: Dictionary = people[pid]
		if not is_alive_active(p):
			continue
		if owner["kind"] == "GOVERNMENT":
			if p["pool"] == "GOV":
				out.append(pid)
		else:
			if p["pool"] == "PARTY:" + String(owner["id"]):
				out.append(pid)
			elif p["pool"] == "GOV" and p["roles"].has("GOV_POLITICAL") and p["party_id"] == owner["id"]:
				out.append(pid)
	return out


static func available(world: WorldState, owner: Dictionary) -> Array:
	return pool_members(world, owner).filter(func(pid):
		var p: Dictionary = world.table("person")[pid]
		return p["status"] == "ACTIVE" and p["assignment_id"] == "")


# =====================================================================================  tasks

static func work_required_wu(def: Dictionary, params: Dictionary) -> float:
	var w: Dictionary = def.get("work", {})
	var total := float(w.get("base", 0))
	for k in w:
		if String(k).begins_with("per_"):
			total += float(w[k]) * float(params.get(String(k).substr(4), 0))
	return total * float(params.get("work_multiplier", 1.0))


static func create_task(world: WorldState, def_id: String, params: Dictionary, owner: Dictionary) -> Dictionary:
	if not D.TASKS.has(def_id):
		return {"ok": false, "error": "unknown task " + def_id}
	var def: Dictionary = D.TASKS[def_id]
	if not def["owners"].has(owner["kind"]):
		return {"ok": false, "error": "%s cannot be run by %s" % [def_id, owner["kind"]]}
	if owner["kind"] == "GOVERNMENT" and def["category"] == "POLITICAL" and is_caretaker(world) \
			and not def.get("caretaker_ok", false):
		return {"ok": false, "error": "caretaker government cannot start new political tasks"}
	var positions: Array = []
	for pi in Q.active_positions(def, params):
		positions.append({"pi": pi, "assigned": ""})
	var id := world.new_id("task")
	var t := {
		"id": id, "def_id": def_id, "params": params.duplicate(true), "owner": owner.duplicate(),
		"status": "ACTIVE", "mode": "NORMAL",
		"preset": String(world.levers.get("STAFF_DEFAULT_AUTHORITY_PRESET", "STANDARD")),
		"positions": positions, "progress": 0, "work_required": 0, "stage": 0, "stage_progress": 0,
		"stage_months": 0, "carry": 0, "months_active": 0, "month_delta": 0,
		"wu_acc": 0, "q_acc": 0, "quality": 0, "coverage": 0, "effectiveness": 0, "cov_window": [],
		"outputs": {}, "start_month": world.month, "completed_month": -1,
		"budget": int(params.get("budget", 0)), "spent": 0, "paused": false,
		"lever_deltas": params.get("lever_deltas", []).duplicate(true), "history": [],
	}
	if def.get("coverage", false):
		t["work_required"] = 0
	elif def.has("fixed_months"):
		t["work_required"] = 0
	elif def.has("stages"):
		var total := work_required_wu(def, params)
		var stages: Array = []
		for st in def["stages"]:
			if st.has("months"):
				stages.append({"months": int(st["months"])})
			else:
				stages.append({"wu": int(round(total * float(st["share"]) * MILLI)), "owners": st["owners"]})
		t["stages"] = stages
		t["work_required"] = int(round(total * MILLI))
	else:
		t["work_required"] = int(round(work_required_wu(def, params) * MILLI))
	world.table("task")[id] = t
	charge(world, owner, float(def.get("cost_wref", 0)), def_id)
	_hist(world, t, "CREATED", {})
	return {"ok": true, "id": id}


## Politics hook: start a drafting task for a bill (M3: legislation requires staffed drafting).
## clauses = [{lever, to}] as politics builds them; owner GOVERNMENT for government bills, PARTY for opposition bills.
static func request_drafting(world: WorldState, owner: Dictionary, source_bill: String, clauses: Array) -> Dictionary:
	var deltas: Array = []
	var domain_votes := {}
	for c in clauses:
		var lv: String = c["lever"]
		var cur := float(world.levers.get(lv, 0)) if world.lever_defs.get(lv, {}).get("type", "NUMBER") == "NUMBER" else 0.0
		var dir := 1 if float(c.get("to", cur)) >= cur else -1
		deltas.append({"lever": lv, "dir": dir})
		var dom := lever_domain(world, lv)
		domain_votes[dom] = int(domain_votes.get(dom, 0)) + 1
	var domain := "ADMIN"
	for d in domain_votes:
		if domain == "ADMIN" or int(domain_votes[d]) > int(domain_votes.get(domain, 0)):
			domain = d
	var def_id := "STAFF_T_DRAFT_ORDINANCE" if era(world) == "FOUNDING" and owner["kind"] == "GOVERNMENT" else "STAFF_T_DRAFT_BILL"
	return create_task(world, def_id, {"clauses": maxi(1, clauses.size()), "domain": domain, "source_bill": source_bill,
		"target": source_bill, "lever_deltas": deltas, "clauses_spec": clauses.duplicate(true)}, owner)


## The drafting task for a bill (empty if none). D1 reads outputs.draft_quality when status == COMPLETED.
static func draft_for_bill(world: WorldState, source_bill: String) -> Dictionary:
	var tasks := world.table("task")
	for tid in Det.ordered(tasks):
		var t: Dictionary = tasks[tid]
		if String(t["params"].get("source_bill", "")) == source_bill and String(t["def_id"]).begins_with("STAFF_T_DRAFT"):
			return t
	return {}


## Skill a lever's policy work needs (lever def `domain`, else by owner).
static func lever_domain(world: WorldState, lever: String) -> String:
	var def: Dictionary = world.lever_defs.get(lever, {})
	if def.has("domain"):
		return String(def["domain"])
	return String({"econ": "ECON", "comp": "ECON", "law": "LAW", "staff": "ADMIN", "map": "ENG", "pol": "POLI"}.get(def.get("owner", ""), "ECON"))


static func _hist(world: WorldState, t: Dictionary, ev: String, data: Dictionary) -> void:
	t["history"].append({"m": world.month, "ev": ev, "data": data})


static func task(world: WorldState, tid: String) -> Dictionary:
	return world.table("task").get(tid, {})


static func pos_def(t: Dictionary, idx: int) -> Dictionary:
	return D.TASKS[t["def_id"]]["positions"][t["positions"][idx]["pi"]]


static func monthly_required(t: Dictionary) -> float:
	var def: Dictionary = D.TASKS[t["def_id"]]
	if def.has("by_size"):
		return float(def["by_size"].get(String(t["params"].get("size", "MEDIUM")), 12))
	return float(def.get("monthly_required", 10))


# =====================================================================================  coalition alignment (spec §7.3)

## Returns {"mult": float, "refuse": bool, "friction": bool}.
static func alignment(world: WorldState, t: Dictionary, p: Dictionary) -> Dictionary:
	var out := {"mult": 1.0, "refuse": false, "friction": false}
	if t["owner"]["kind"] != "GOVERNMENT" or not p["roles"].has("GOV_POLITICAL"):
		return out
	var pm := pm_party(world)
	if p["party_id"] == "" or p["party_id"] == pm:
		return out
	var commitments: Array = world.peek("party").get(p["party_id"], {}).get("commitments", [])
	var agreement: Array = gov_record(world).get("agreement", [])
	var agreed := false
	for d in t["lever_deltas"]:
		for c in commitments:
			if c["lever"] == d["lever"] and int(c["dir"]) == -int(d["dir"]):
				if c["kind"] == "CORE":
					out["refuse"] = true
				else:
					out["friction"] = true
		for a in agreement:
			if a["lever"] == d["lever"] and int(a["dir"]) == int(d["dir"]):
				agreed = true
	if out["refuse"]:
		out["mult"] = 0.0
	elif out["friction"]:
		out["mult"] = D.ALIGN_NEGOTIABLE
	elif agreed:
		out["mult"] = D.ALIGN_AGREEMENT
	return out


# =====================================================================================  assignment ops (atomic)

## S §7.5 validation. ignore_vacancy is used by replace().
static func eligibility(world: WorldState, tid: String, idx: int, pid: String, ignore_vacancy: bool = false) -> Dictionary:
	var t := task(world, tid)
	if t.is_empty() or t["status"] != "ACTIVE":
		return {"ok": false, "reason": "task not active"}
	if idx < 0 or idx >= t["positions"].size():
		return {"ok": false, "reason": "no such position"}
	var p := person(world, pid)
	if p.is_empty() or p["status"] != "ACTIVE":
		return {"ok": false, "reason": "person not available"}
	if p["assignment_id"] != "":
		return {"ok": false, "reason": "person already assigned"}
	if not pool_members(world, t["owner"]).has(pid):
		return {"ok": false, "reason": "person not in this owner's staff"}
	if not ignore_vacancy and t["positions"][idx]["assigned"] != "":
		return {"ok": false, "reason": "position occupied"}
	var def: Dictionary = D.TASKS[t["def_id"]]
	if not Q.neutrality_ok(p, def):
		return {"ok": false, "reason": "civil servants cannot do party-political work"}
	var only: String = String(t["params"].get("only_person", ""))
	if only != "" and only != pid:
		return {"ok": false, "reason": "position reserved"}
	if Q.path_index(p, pos_def(t, idx), Q.domain_of(t["params"])) < 0:
		return {"ok": false, "reason": "does not meet qualifications"}
	if alignment(world, t, p)["refuse"]:
		return {"ok": false, "reason": "refused: conflicts with %s core commitment" % p["party_id"]}
	return {"ok": true, "reason": ""}


static func assign(world: WorldState, tid: String, idx: int, pid: String) -> Dictionary:
	var e := eligibility(world, tid, idx, pid)
	if not e["ok"]:
		return e
	_do_assign(world, tid, idx, pid)
	return {"ok": true, "reason": ""}


static func _do_assign(world: WorldState, tid: String, idx: int, pid: String) -> void:
	var t := task(world, tid)
	var aid := world.new_id("asg")
	world.table("assignment")[aid] = {"id": aid, "staff_id": pid, "task_id": tid, "pos": idx,
		"start_month": world.month, "end_month": -1, "status": "ACTIVE"}
	world.table("person")[pid]["assignment_id"] = aid
	t["positions"][idx]["assigned"] = pid
	_hist(world, t, "ASSIGNED", {"person": pid, "pos": idx})


static func unassign(world: WorldState, pid: String, reason: String = "UNASSIGNED") -> Dictionary:
	var p := person(world, pid)
	if p.is_empty() or p["assignment_id"] == "":
		return {"ok": false, "reason": "not assigned"}
	var a: Dictionary = world.table("assignment")[p["assignment_id"]]
	var t := task(world, a["task_id"])
	a["status"] = "CLOSED"
	a["end_month"] = world.month
	p["assignment_id"] = ""
	t["positions"][int(a["pos"])]["assigned"] = ""
	_hist(world, t, reason, {"person": pid, "pos": a["pos"]})
	p["career"].append({"task": t["def_id"], "from": a["start_month"], "to": world.month, "end": reason})
	return {"ok": true, "reason": ""}


## Release the current holder and assign a replacement as one validated operation (S §12.8).
static func replace(world: WorldState, tid: String, idx: int, new_pid: String) -> Dictionary:
	var e := eligibility(world, tid, idx, new_pid, true)
	if not e["ok"]:
		return e
	var t := task(world, tid)
	var old: String = t["positions"][idx]["assigned"]
	if old != "":
		unassign(world, old, "REPLACED")
	_do_assign(world, tid, idx, new_pid)
	return {"ok": true, "reason": ""}


static func cancel_task(world: WorldState, tid: String) -> Dictionary:
	var t := task(world, tid)
	if t.is_empty() or not (t["status"] == "ACTIVE"):
		return {"ok": false, "reason": "task not active"}
	for pos in t["positions"]:
		if pos["assigned"] != "":
			unassign(world, pos["assigned"], "TASK_CANCELLED")
	t["status"] = "CANCELLED"
	t["completed_month"] = world.month
	_hist(world, t, "CANCELLED", {})
	return {"ok": true, "reason": ""}


static func set_mode(world: WorldState, tid: String, mode: String) -> void:
	assert(D.MODE_W.has(mode))
	task(world, tid)["mode"] = mode


static func set_preset(world: WorldState, tid: String, preset: String) -> void:
	assert(D.PRESETS.has(preset))
	task(world, tid)["preset"] = preset


## Training: a special assignment of one person (spec §6).
static func train(world: WorldState, pid: String, skill: String, owner: Dictionary = GOV) -> Dictionary:
	var p := person(world, pid)
	if p.is_empty() or int(p["skills"].get(skill, 100)) >= D.TRAINING_CAP:
		return {"ok": false, "reason": "skill already at training cap"}
	var r := create_task(world, "STAFF_T_TRAINING", {"only_person": pid, "skill": skill}, owner)
	if not r["ok"]:
		return {"ok": false, "reason": r["error"]}
	var a := assign(world, r["id"], 0, pid)
	if not a["ok"]:
		world.table("task")[r["id"]]["status"] = "CANCELLED"
		return a
	return {"ok": true, "id": r["id"]}


# =====================================================================================  delegation (spec §9)

static func open_decision(world: WorldState, tid: String, kind: String, options: Array, recommended: String, data: Dictionary) -> String:
	var id := world.new_id("dreq")
	world.table("decision_request")[id] = {"id": id, "task_id": tid, "kind": kind, "options": options,
		"recommended": recommended, "data": data, "status": "OPEN", "month": world.month, "chosen": ""}
	return id


static func task_blocked(world: WorldState, tid: String) -> bool:
	var reqs := world.table("decision_request")
	for rid in Det.ordered(reqs):
		if reqs[rid]["task_id"] == tid and reqs[rid]["status"] == "OPEN":
			return true
	return false


static func answer_decision(world: WorldState, rid: String, option: String) -> Dictionary:
	var r: Dictionary = world.table("decision_request").get(rid, {})
	if r.is_empty() or r["status"] != "OPEN" or not r["options"].has(option):
		return {"ok": false, "reason": "invalid decision"}
	r["status"] = "ANSWERED"
	r["chosen"] = option
	var t := task(world, r["task_id"])
	if r["kind"] == "COMMITMENT" and option == "APPROVE" and not t.is_empty():
		t["spent"] = int(t["spent"]) + int(r["data"]["amount"])
	return {"ok": true, "reason": ""}


## Econ calls this when a delegated official wants to commit money on a task. "AUTO" or "ESCALATED".
static func request_commitment(world: WorldState, tid: String, amount: int) -> String:
	var t := task(world, tid)
	var pr: Dictionary = D.PRESETS[t["preset"]]
	var budget := float(t["budget"])
	if float(amount) > budget * float(pr["single_pct"]) or float(int(t["spent"]) + amount) > budget * (1.0 + float(pr["overrun"])):
		open_decision(world, tid, "COMMITMENT", ["APPROVE", "REJECT"], "APPROVE", {"amount": amount})
		return "ESCALATED"
	t["spent"] = int(t["spent"]) + amount
	var q := float(t["quality"]) / MILLI if int(t["wu_acc"]) > 0 else 50.0
	if world.rng.stream("staff.work").randf() < (100.0 - q) / D.AUTO_ERROR_DIVISOR:
		fact(world, "STAFF_AUTO_DECISION_ERROR", "PUBLIC", [GOV], [{"actor": GOV, "share": 0.7},
			{"actor": official_ref(_lead(t)), "share": 0.3}] if _lead(t) != "" else [{"actor": GOV, "share": 1.0}],
			{"GOVERNANCE": -5}, 15, {"task": tid, "amount": amount, "preset": t["preset"]})
	return "AUTO"


static func _lead(t: Dictionary) -> String:
	for pos in t["positions"]:
		if pos["assigned"] != "":
			return pos["assigned"]
	return ""


# =====================================================================================  seats & government (spec §7)

## Sainte-Laguë (1,3,5,...) over formal coalition members, every member >= 1 (spec §7.1).
static func allocate_seats(seats: Dictionary, formal: Array, n: int = D.POLITICAL_SEATS) -> Dictionary:
	var alloc := {}
	var q: Array = []
	for i in formal.size():
		var p: String = formal[i]
		alloc[p] = 0
		for k in n:
			q.append([float(seats.get(p, 0)) / float(2 * k + 1), i, k, p])
	q.sort_custom(func(a, b):
		if a[0] != b[0]:
			return a[0] > b[0]
		if a[1] != b[1]:
			return a[1] < b[1]
		return a[2] < b[2])
	for j in mini(n, q.size()):
		alloc[q[j][3]] += 1
	for p in formal:
		if alloc[p] == 0:
			var largest := ""
			for o in formal:
				if alloc[o] > 1 and (largest == "" or int(seats.get(o, 0)) > int(seats.get(largest, 0))):
					largest = o
			if largest != "":
				alloc[largest] -= 1
				alloc[p] = 1
	return alloc


static func seats_of(world: WorldState) -> Array:
	return world.table("gov_seat").keys()


## Called by politics when a government takes office. formal = coalition member party ids, seats = {pid: seats}.
static func form_government(world: WorldState, formal: Array, seats: Dictionary) -> Dictionary:
	var alloc := allocate_seats(seats, formal)
	var gs := world.table("gov_seat")
	# Remove seats of parties that are no longer (or less) represented. Occupants return to their bench.
	var by_party := {}
	for sid in Det.ordered(gs):
		var pty: String = gs[sid]["party_id"]
		if not by_party.has(pty):
			by_party[pty] = []
		by_party[pty].append(sid)
	for pty in by_party:
		var keep: int = alloc.get(pty, 0)
		var list: Array = by_party[pty]
		list.sort_custom(func(a, b): return (gs[a]["person_id"] != "") and (gs[b]["person_id"] == ""))
		for i in list.size():
			if i >= keep:
				var sid: String = list[i]
				if gs[sid]["person_id"] != "":
					_leave_government(world, gs[sid]["person_id"], "GOVERNMENT_CHANGE")
				gs.erase(sid)
	for pty in formal:
		var have := 0
		for sid in Det.ordered(gs):
			if gs[sid]["party_id"] == pty:
				have += 1
		for _i in int(alloc[pty]) - have:
			var sid := world.new_id("seat")
			gs[sid] = {"id": sid, "party_id": pty, "person_id": ""}
		clear_party_pool(world, pty)
	return alloc


static func _leave_government(world: WorldState, pid: String, reason: String) -> void:
	var p := person(world, pid)
	if p["assignment_id"] != "":
		unassign(world, pid, reason)
	p["pool"] = ""
	p["bench_party_id"] = p["party_id"]
	for sid in Det.ordered(world.table("gov_seat")):
		if world.table("gov_seat")[sid]["person_id"] == pid:
			world.table("gov_seat")[sid]["person_id"] = ""


## Appoint a bench member of the seat's party (player via action, AI automatically).
static func appoint_political(world: WorldState, sid: String, pid: String) -> Dictionary:
	var seat: Dictionary = world.table("gov_seat").get(sid, {})
	var p := person(world, pid)
	if seat.is_empty() or seat["person_id"] != "":
		return {"ok": false, "reason": "seat not vacant"}
	if p.is_empty() or p["status"] != "ACTIVE" or p["pool"] != "" or p["bench_party_id"] != seat["party_id"]:
		return {"ok": false, "reason": "not on this party's bench"}
	seat["person_id"] = pid
	p["pool"] = "GOV"
	p["party_id"] = seat["party_id"]
	if not p["roles"].has("GOV_POLITICAL"):
		p["roles"].append("GOV_POLITICAL")
	var pty_ref := {"kind": "PARTY", "id": seat["party_id"]} if seat["party_id"] != "" else {"kind": "COMMANDER", "id": "commander"}
	fact(world, "STAFF_OFFICIAL_APPOINTED", "PUBLIC", [official_ref(pid), pty_ref], [{"actor": pty_ref, "share": 1.0}], {}, 5,
		{"seat": sid})
	return {"ok": true, "reason": ""}


## A party may dismiss only its own officials. Civil servants cannot be dismissed (v1).
static func dismiss_political(world: WorldState, pid: String, by_party: String) -> Dictionary:
	var p := person(world, pid)
	if p.is_empty() or p["pool"] != "GOV" or not p["roles"].has("GOV_POLITICAL") or p["party_id"] != by_party:
		return {"ok": false, "reason": "can only dismiss own party's political officials"}
	_leave_government(world, pid, "DISMISSED")
	var pty_ref := {"kind": "PARTY", "id": by_party} if by_party != "" else {"kind": "COMMANDER", "id": "commander"}
	fact(world, "STAFF_OFFICIAL_DISMISSED", "PUBLIC", [official_ref(pid), pty_ref], [{"actor": pty_ref, "share": 1.0}],
		{"GOVERNANCE": -3}, 15, {})
	return {"ok": true, "reason": ""}


static func opposition_pool_size(seats: int) -> int:
	return mini(6, 2 + seats / 20)


## Opposition (or formation) party staff pool, auto-filled from the bench by suitability.
## Opposition staff should be able to litigate, campaign and negotiate (spec-staff section 8).
const POOL_FUNCTIONS := {"LAW": 50, "COMM": 50, "NEGO": 50}


static func set_party_pool(world: WorldState, pid: String, seats: int) -> void:
	var size := opposition_pool_size(seats)
	var key := "PARTY:" + pid
	var members: Array = []
	var people := world.table("person")
	for id in Det.ordered(people):
		if people[id]["pool"] == key and is_alive_active(people[id]):
			members.append(id)
	while members.size() > size:
		var id: String = members.pop_back()
		_leave_pool(world, id)
	var bench := _bench(world, pid)
	bench.sort_custom(func(a, b): return _person_value(people[a]) > _person_value(people[b]) \
		or (_person_value(people[a]) == _person_value(people[b]) and int(people[a]["n"]) < int(people[b]["n"])))
	# Cover the opposition's core functions first (counsel, campaigner, negotiator), then fill by strength.
	for skill in POOL_FUNCTIONS:
		if members.size() >= size or members.any(func(m): return int(people[m]["skills"][skill]) >= int(POOL_FUNCTIONS[skill])):
			continue
		var best := ""
		for id in bench:
			if not members.has(id) and int(people[id]["skills"][skill]) >= int(POOL_FUNCTIONS[skill]) \
					and (best == "" or int(people[id]["skills"][skill]) > int(people[best]["skills"][skill])):
				best = id
		if best != "":
			people[best]["pool"] = key
			members.append(best)
	for id in bench:
		if members.size() >= size:
			break
		if members.has(id):
			continue
		people[id]["pool"] = key
		members.append(id)


static func clear_party_pool(world: WorldState, pid: String) -> void:
	var people := world.table("person")
	for id in Det.ordered(people):
		if people[id]["pool"] == "PARTY:" + pid:
			_leave_pool(world, id)


static func _leave_pool(world: WorldState, id: String) -> void:
	var p := person(world, id)
	if p["assignment_id"] != "":
		unassign(world, id, "POOL_CHANGE")
	p["pool"] = ""


static func _bench(world: WorldState, pid: String) -> Array:
	var out: Array = []
	var people := world.table("person")
	for id in Det.ordered(people):
		var p: Dictionary = people[id]
		if p["status"] == "ACTIVE" and p["pool"] == "" and p["bench_party_id"] == pid:
			out.append(id)
	return out


static func _person_value(p: Dictionary) -> int:
	var top := 0
	for s in p["skills"]:
		top = maxi(top, int(p["skills"][s]))
	return top + int(p["work_speed"]) / 4


## Bench refresh at each election (spec §5.4). seats = {pid: seats}.
static func on_election(world: WorldState, seats: Dictionary) -> void:
	var parties := world.table("party")
	for pid in Det.ordered(parties):
		var n_seats: int = int(seats.get(pid, 0))
		var rng := world.rng.stream("staff.gen")
		var newcomers := RG.generate_bench(rng, D.BENCH_NEW_PER_ELECTION, world.month,
			String(parties[pid].get("flavour_skill", "")), world.month)
		for np in newcomers:
			np["party_id"] = pid
			add_person(world, np, "", pid)
		var cap := D.BENCH_DEFUNCT if n_seats == 0 else D.BENCH_BASE + int(ceil(float(n_seats) / 10.0))
		var bench := _bench(world, pid)
		var people := world.table("person")
		bench.sort_custom(func(a, b): return _person_value(people[a]) - age_years(world, people[a]) / 5 \
			> _person_value(people[b]) - age_years(world, people[b]) / 5)
		for i in range(cap, bench.size()):
			people[bench[i]]["status"] = "DEPARTED"
		RG.enforce_bench_minimums(_bench(world, pid).map(func(id): return people[id]))


## New parties get a bench; once the player's party exists, founding appointees join it (X4).
static func ensure_benches(world: WorldState) -> void:
	var s := state(world)
	var parties := world.table("party")
	var pp := player_party(world)
	var people := world.table("person")
	if pp != "":
		for id in Det.ordered(people):
			var p: Dictionary = people[id]
			if p["roles"].has("GOV_POLITICAL") and p["party_id"] == "" and is_alive_active(p):
				p["party_id"] = pp
				if p["pool"] == "":
					p["bench_party_id"] = pp
		for sid in Det.ordered(world.table("gov_seat")):
			if world.table("gov_seat")[sid]["party_id"] == "":
				world.table("gov_seat")[sid]["party_id"] = pp
	for pid in Det.ordered(parties):
		if s["benches"].has(pid) or not party_active(world, pid):
			continue
		s["benches"][pid] = true
		if pid == pp:
			continue   # the player's party bench is the founding appointees (+3 per election)
		var n := D.BENCH_BASE + int(ceil(float(parties[pid].get("seats", 0)) / 10.0))
		var bench := RG.generate_bench(world.rng.stream("staff.gen"), n, world.month, String(parties[pid].get("flavour_skill", "")))
		RG.enforce_bench_minimums(bench)
		for np in bench:
			np["party_id"] = pid
			add_person(world, np, "", pid)


## Follow politics: new government -> seat reallocation; new election -> bench refresh; opposition pools.
static func sync_politics(world: WorldState) -> void:
	var s := state(world)
	var st := pol_state(world)
	var parties := world.table("party")
	var elections: Array = st.get("elections", [])
	if elections.size() > int(s.get("elections_seen", 0)):
		s["elections_seen"] = elections.size()
		var e: Dictionary = world.table("election").get(elections[-1], {})
		on_election(world, e.get("seats", {}))
	var gov := gov_record(world)
	if not gov.is_empty() and int(gov.get("formed_month", -1)) != int(s.get("gov_formed", -2)):
		s["gov_formed"] = int(gov.get("formed_month", -1))
		var seats := {}
		for pid in gov["members"]:
			seats[pid] = int(parties.get(pid, {}).get("seats", 0))
		form_government(world, gov["members"], seats)
		s["pools_dirty"] = true
	if s.get("pools_dirty", false) or elections.size() != int(s.get("pools_for_elections", -1)):
		s["pools_dirty"] = false
		s["pools_for_elections"] = elections.size()
		var members: Array = gov.get("members", [])
		for pid in Det.ordered(parties):
			var n_seats := int(parties[pid].get("seats", 0))
			if not party_active(world, pid) or n_seats == 0:
				clear_party_pool(world, pid)
			elif not members.has(pid):
				set_party_pool(world, pid, n_seats)


# =====================================================================================  founding (spec §5, §10.4)

static func init_founding(world: WorldState) -> void:
	state(world)
	for k in ["person", "task", "assignment", "staff_report", "decision_request", "gov_seat", "recruitment", "revealed_fact"]:
		world.table(k)   # owned tables exist from the start, so read-only queries never create them
	var r := RG.generate_founding(world.rng.stream("staff.gen"), world.month)
	world.table("staff_state")["s"]["founding_fallback"] = r["fallback"]
	for p in r["civil"]:
		add_person(world, p, "GOV", "")
	var cands: Array = r["candidates"]
	for i in cands.size():
		var pid := add_person(world, cands[i], "", "")
		if i < D.POLITICAL_SEATS:
			var sid := world.new_id("seat")
			world.table("gov_seat")[sid] = {"id": sid, "party_id": "", "person_id": ""}
			appoint_political(world, sid, pid)
	for entry in D.FOUNDING_SLATE:
		create_task(world, entry["def"], entry["params"], GOV)


# =====================================================================================  recruitment (spec §5.4)

static func open_recruitment(world: WorldState, spec: String) -> String:
	var id := world.new_id("recruit")
	var rec := {"id": id, "opened_month": world.month, "spec": spec, "shortlist": [], "picked": -1, "hire_month": -1, "status": "OPEN"}
	world.table("recruitment")[id] = rec
	_fill_shortlist(world, rec)
	return id


static func _fill_shortlist(world: WorldState, rec: Dictionary) -> void:
	var tpl := RG.civil_template(rec["spec"])
	var list: Array = []
	for _i in D.SHORTLIST_SIZE:
		list.append(RG.make_civil(world.rng.stream("staff.gen"), tpl, world.month))
	rec["shortlist"] = list


## Government chooses the specialization of the vacancy (regenerates the merit shortlist).
static func set_recruitment_spec(world: WorldState, rid: String, spec: String) -> void:
	var rec: Dictionary = world.table("recruitment")[rid]
	if rec["picked"] < 0:
		rec["spec"] = spec
		_fill_shortlist(world, rec)


static func pick_candidate(world: WorldState, rid: String, idx: int) -> Dictionary:
	var rec: Dictionary = world.table("recruitment").get(rid, {})
	if rec.is_empty() or rec["picked"] >= 0 or idx < 0 or idx >= rec["shortlist"].size():
		return {"ok": false, "reason": "invalid pick"}
	rec["picked"] = idx
	rec["hire_month"] = int(rec["opened_month"]) + D.HIRE_LAG_MONTHS
	return {"ok": true, "reason": ""}


static func _best_candidate(rec: Dictionary) -> int:
	var best := 0
	for i in rec["shortlist"].size():
		if _person_value(rec["shortlist"][i]) > _person_value(rec["shortlist"][best]):
			best = i
	return best


# =====================================================================================  lifecycle (spec §6)

static func _depart(world: WorldState, pid: String, status: String, reason: String) -> void:
	var p := person(world, pid)
	var was_pooled: bool = p["pool"] != ""
	var was_civil: bool = p["pool"] == "GOV" and p["roles"].has("CIVIL_SERVANT")
	if p["assignment_id"] != "":
		unassign(world, pid, reason)
	for sid in Det.ordered(world.table("gov_seat")):
		if world.table("gov_seat")[sid]["person_id"] == pid:
			world.table("gov_seat")[sid]["person_id"] = ""
	p["status"] = status
	p["pool"] = ""
	if was_civil:
		open_recruitment(world, p["specialization"])
	if was_pooled:
		fact(world, "STAFF_OFFICIAL_DEPARTED", "PUBLIC", [official_ref(pid)], [{"actor": {"kind": "NATURE", "id": ""}, "share": 1.0}],
			{}, 5, {"reason": reason})


static func lifecycle(world: WorldState) -> void:
	var rng := world.rng.stream("staff.life")
	var retire_age: int = int(world.levers.get("STAFF_CIVIL_RETIREMENT_AGE", 67))
	var people := world.table("person")
	for pid in Det.ordered(people):
		var p: Dictionary = people[pid]
		if not is_alive_active(p):
			continue
		if p["status"] == "UNAVAILABLE" and world.month >= int(p["unavailable_until"]):
			p["status"] = "ACTIVE"
		var age := age_years(world, p)
		if rng.randf() < (D.P_DEATH_60 if age >= 60 else D.P_DEATH_UNDER_60):
			_depart(world, pid, "DECEASED", "DEATH")
			continue
		var civil: bool = p["roles"].has("CIVIL_SERVANT")
		if civil and p["pool"] == "GOV":
			if age >= retire_age:
				_depart(world, pid, "RETIRED", "RETIREMENT")
				continue
			if rng.randf() < D.P_CIVIL_DEPART:
				_depart(world, pid, "DEPARTED", "RESIGNATION")
				continue
		elif not civil:
			if age >= D.POLITICAL_MANDATORY_RETIRE or (age >= 60 and rng.randf() < D.P_POLITICAL_RETIRE_60):
				_depart(world, pid, "RETIRED", "RETIREMENT")
				continue
		if p["pool"] != "" and p["status"] == "ACTIVE" and rng.randf() < D.P_ILLNESS:
			p["status"] = "UNAVAILABLE"
			p["unavailable_until"] = world.month + rng.randi_range(D.ILLNESS_MONTHS[0], D.ILLNESS_MONTHS[1])
			flag(world, pid, "ILL")


static func process_recruitment(world: WorldState) -> void:
	var recs := world.table("recruitment")
	for rid in Det.ordered(recs):
		var rec: Dictionary = recs[rid]
		if rec["status"] != "OPEN":
			continue
		if rec["picked"] < 0 and autopilot(world, GOV):
			pick_candidate(world, rid, _best_candidate(rec))
		if rec["picked"] >= 0 and world.month >= int(rec["hire_month"]):
			var np: Dictionary = rec["shortlist"][rec["picked"]].duplicate(true)
			var pid := add_person(world, np, "GOV", "")
			rec["status"] = "FILLED"
			rec["person_id"] = pid
			fact(world, "STAFF_CIVIL_SERVANT_HIRED", "OFFICIAL", [official_ref(pid), GOV], [{"actor": GOV, "share": 1.0}], {}, 5,
				{"specialization": np["specialization"]})


# =====================================================================================  monthly work (spec §2, §3, §11)

static func _member_rows(world: WorldState, t: Dictionary, def: Dictionary, domain: String) -> Array:
	var rows: Array = []
	var team_detail := false
	for pos in t["positions"]:
		if pos["assigned"] != "" and person(world, pos["assigned"])["talents"].has("DETAIL_ORIENTED"):
			team_detail = true
	var rng := world.rng.stream("staff.work")
	for i in t["positions"].size():
		var pid: String = t["positions"][i]["assigned"]
		if pid == "":
			continue
		var p := person(world, pid)
		var pd := pos_def(t, i)
		var suit := W.suitability(p, pd["weights"], domain)
		var al := alignment(world, t, p)
		var w := 0.0
		if p["status"] == "ACTIVE" and not al["refuse"]:
			w = W.individual_w(p, pd["mandatory"], suit, def["tags"], t["mode"], al["mult"])
			var p_err := (100.0 - float(p["reliability"])) / 1000.0
			if p["talents"].has("DETAIL_ORIENTED"):
				p_err *= D.TALENTS["DETAIL_ORIENTED"]["self_error"]
			if rng.randf() < p_err:
				var caught: bool = team_detail and not p["talents"].has("DETAIL_ORIENTED") \
					and rng.randf() < D.TALENTS["DETAIL_ORIENTED"]["catch"]
				if not caught:
					w = 0.0
					flag(world, pid, "ERROR")
		elif p["status"] != "ACTIVE":
			flag(world, pid, "ILL")
		if al["friction"]:
			flag(world, pid, "FRICTION")
		rows.append({"idx": i, "pid": pid, "w": w, "q": W.member_q(p, suit, def["tags"], t["mode"]),
			"mandatory": pd["mandatory"], "weights": pd["weights"], "friction": al["friction"],
			"refuse": al["refuse"], "organizer": p["talents"].has("STRONG_ORGANIZER")})
	return rows


static func _team_w(def: Dictionary, t: Dictionary, rows: Array) -> float:
	var mand: Array = []
	var opt: Array = []
	var organizer := false
	var stage_owners: Array = []
	if def["mode"] == "SEQUENTIAL":
		var st: Dictionary = t["stages"][int(t["stage"])]
		stage_owners = st.get("owners", [])
	for r in rows:
		organizer = organizer or r["organizer"]
		var w: float = r["w"]
		if def["mode"] == "SEQUENTIAL":
			w *= 1.0 if stage_owners.has(t["positions"][r["idx"]]["pi"]) else 0.5
		if r["mandatory"]:
			mand.append(w)
		else:
			opt.append(w)
	if def["mode"] == "COORDINATED":
		return W.team_coordinated(mand, opt, organizer)
	return W.team_parallel(mand, opt)


static func process_tasks(world: WorldState) -> void:
	var tasks := world.table("task")
	for tid in Det.ordered(tasks):
		var t: Dictionary = tasks[tid]
		if t["status"] != "ACTIVE":
			continue
		_process_task(world, t)


static func _process_task(world: WorldState, t: Dictionary) -> void:
	var def: Dictionary = D.TASKS[t["def_id"]]
	var domain := Q.domain_of(t["params"])
	t["month_delta"] = 0
	if task_blocked(world, t["id"]):
		for pos in t["positions"]:
			if pos["assigned"] != "":
				flag(world, pos["assigned"], "BLOCKED")
		return
	var paused := false
	for i in t["positions"].size():
		if t["positions"][i]["assigned"] == "" and pos_def(t, i)["mandatory"]:
			paused = true
	t["paused"] = paused
	if paused:
		for pos in t["positions"]:
			if pos["assigned"] != "":
				flag(world, pos["assigned"], "PAUSED")
		if def.get("coverage", false):
			_coverage_update(world, t, 0.0, 0.0)
			if def["category"] == "STANDING" and not t.get("unmanaged_reported", false):
				t["unmanaged_reported"] = true
				fact(world, "STAFF_DUTY_UNMANAGED", "OFFICIAL", [owner_actor(world, t["owner"])],
					[{"actor": owner_actor(world, t["owner"]), "share": 1.0}], {}, 10, {"task": t["id"], "duty": t["def_id"]})
		return
	t["unmanaged_reported"] = false
	# Time-gated stage (e.g. tender period): no work, the clock runs.
	if def["mode"] == "SEQUENTIAL" and t["stages"][int(t["stage"])].has("months"):
		t["stage_months"] = int(t["stage_months"]) + 1
		if int(t["stage_months"]) >= int(t["stages"][int(t["stage"])]["months"]):
			t["stage"] = int(t["stage"]) + 1
			t["stage_months"] = 0
			t["stage_progress"] = int(t["carry"])
			t["carry"] = 0
			_advance_stages(t)
		if int(t["stage"]) >= t["stages"].size():
			complete_task(world, t)
		return
	var rows := _member_rows(world, t, def, domain)
	var w_team := _team_w(def, t, rows)
	var wsum := 0.0
	var qsum := 0.0
	var organizer := false
	for r in rows:
		wsum += float(r["w"])
		qsum += float(r["w"]) * float(r["q"])
		organizer = organizer or r["organizer"]
	var q_month := (qsum / wsum if wsum > 0.0 else 0.0) + (float(D.TALENTS["STRONG_ORGANIZER"]["team_q"]) if organizer else 0.0)
	q_month = clampf(q_month, 0.0, 100.0)
	var w_milli := int(round(w_team * MILLI))
	t["month_delta"] = w_milli
	t["months_active"] = int(t["months_active"]) + 1
	_award_xp(world, t, def, rows, domain)
	# Partner friction -> D1 coalition cohesion (spec §7.3), once per task per month.
	for r in rows:
		if r["friction"]:
			var pty: String = person(world, r["pid"])["party_id"]
			fact(world, "STAFF_PARTNER_FRICTION", "OFFICIAL", [{"kind": "PARTY", "id": pty}, official_ref(r["pid"])],
				[{"actor": {"kind": "PARTY", "id": pty}, "share": 1.0}], {}, 10, {"task": t["id"]})
			break
	if def.get("coverage", false):
		_coverage_update(world, t, w_team, q_month)
		return
	t["wu_acc"] = int(t["wu_acc"]) + w_milli
	t["q_acc"] = int(t["q_acc"]) + int(round(w_team * q_month * MILLI))
	if int(t["wu_acc"]) > 0:
		t["quality"] = int(round(float(t["q_acc"]) / float(t["wu_acc"]) * MILLI))
	if def.has("fixed_months"):
		if int(t["months_active"]) >= int(def["fixed_months"]):
			complete_task(world, t)
		return
	t["progress"] = int(t["progress"]) + w_milli
	if def["mode"] == "SEQUENTIAL":
		t["stage_progress"] = int(t["stage_progress"]) + w_milli
		_advance_stages(t)
		if int(t["stage"]) >= t["stages"].size():
			complete_task(world, t)
		return
	if int(t["progress"]) >= int(t["work_required"]):
		complete_task(world, t)


static func _advance_stages(t: Dictionary) -> void:
	while int(t["stage"]) < t["stages"].size():
		var st: Dictionary = t["stages"][int(t["stage"])]
		if st.has("months"):
			t["carry"] = int(t["carry"]) + int(t["stage_progress"])
			t["stage_progress"] = 0
			return
		if int(t["stage_progress"]) < int(st["wu"]):
			return
		var left: int = int(t["stage_progress"]) - int(st["wu"])
		t["stage"] = int(t["stage"]) + 1
		t["stage_progress"] = left


static func _coverage_update(world: WorldState, t: Dictionary, w_team: float, q_month: float) -> void:
	var req := monthly_required(t)
	var c := minf(1.0, w_team / req) if req > 0.0 else 0.0
	var win: Array = t["cov_window"]
	win.append([int(round(w_team * MILLI)), int(round(q_month * MILLI))])
	while win.size() > 6:
		win.pop_front()
	var ws := 0.0
	var qs := 0.0
	for e in win:
		ws += float(e[0])
		qs += float(e[0]) * float(e[1])
	var q := (qs / ws / MILLI) if ws > 0.0 else 0.0
	t["quality"] = int(round(q * MILLI))
	t["coverage"] = int(round(c * MILLI))
	t["effectiveness"] = int(round(W.effectiveness(c, q) * MILLI))
	if t["def_id"] == "STAFF_T_CAMPAIGN":
		var effort := int(round(w_team * (0.5 + q / 200.0) * MILLI))
		t["outputs"]["campaign_effort"] = effort
		fact(world, "STAFF_CAMPAIGN_EFFORT", "OFFICIAL", [owner_actor(world, t["owner"])],
			[{"actor": owner_actor(world, t["owner"]), "share": 1.0}], {}, 1, {"task": t["id"], "effort_milli": effort})


static func _award_xp(world: WorldState, t: Dictionary, def: Dictionary, rows: Array, domain: String) -> void:
	var d: float = D.TIER_D.get(int(def.get("tier", 1)), 1.0)
	for r in rows:
		if float(r["w"]) <= 0.0:
			continue
		var p := person(world, r["pid"])
		var l := float(D.TALENTS["FAST_LEARNER"]["xp"]) if p["talents"].has("FAST_LEARNER") else 1.0
		for k in r["weights"]:
			var skill: String = domain if k == "DOMAIN" else k
			var gain := int(round(D.XP_BASE * d * float(r["weights"][k]) * l * MILLI))
			var xp: int = int(p["xp"].get(skill, 0)) + gain
			var lvl: int = int(p["skills"][skill])
			while lvl < 100 and xp >= int(round(W.xp_cost(lvl) * MILLI)):
				xp -= int(round(W.xp_cost(lvl) * MILLI))
				lvl += 1
			p["skills"][skill] = lvl
			p["xp"][skill] = xp


## Finite task completion: compute outputs, emit facts, release staff (S §9.7).
static func complete_task(world: WorldState, t: Dictionary) -> void:
	var def_id: String = t["def_id"]
	var q := float(t["quality"]) / MILLI
	var actor := owner_actor(world, t["owner"])
	var resp := [{"actor": actor, "share": 1.0}]
	var rngq := world.rng.stream("staff.quality")
	var team: Array = []
	for pos in t["positions"]:
		if pos["assigned"] != "":
			team.append(official_ref(pos["assigned"]))
	match def_id:
		"STAFF_T_DRAFT_BILL", "STAFF_T_DRAFT_ORDINANCE", "STAFF_T_REVISE_BILL":
			var n := maxi(1, int(t["params"].get("clauses", t["params"].get("changed", 1))))
			var defects: Array = []
			for _i in n:
				defects.append(rngq.randf() < W.defect_probability(q))
			t["outputs"]["draft_quality"] = int(round(q))
			t["outputs"]["defects"] = defects
			fact(world, "STAFF_DRAFT_COMPLETED", "OFFICIAL", [actor] + team, resp, {}, 10,
				{"task": t["id"], "target": t["params"].get("target", ""), "draft_quality": int(round(q)), "defects": defects.count(true)})
		"STAFF_T_COALITION_NEGOTIATION", "STAFF_T_SUPPORT_NEGOTIATION":
			t["outputs"]["negotiation_quality"] = int(round(q))
			fact(world, "STAFF_NEGOTIATION_READY", "OFFICIAL", [actor] + team, resp, {}, 10,
				{"task": t["id"], "target": t["params"].get("target", ""), "negotiation_quality": int(round(q))})
		"STAFF_T_POLL":
			var moe := int(round(W.poll_moe_pp(q) * 100.0))   # basis points of percentage points
			t["outputs"]["poll_moe_bp"] = moe
			fact(world, "STAFF_POLL_RESULT", "OFFICIAL", [actor], resp, {}, 5, {"task": t["id"], "moe_bp": moe})
		"STAFF_T_AGENDA":
			t["outputs"]["agenda_quality"] = int(round(q))
			fact(world, "STAFF_AGENDA_READY", "OFFICIAL", [actor], resp, {}, 10, {"task": t["id"], "quality": int(round(q))})
		"STAFF_T_BUDGET":
			t["outputs"]["budget_quality"] = int(round(q))
			fact(world, "STAFF_BUDGET_READY", "OFFICIAL", [actor] + team, resp, {}, 10, {"task": t["id"]})
		"STAFF_T_OVERSIGHT":
			t["outputs"]["revealed"] = _oversight_reveal(world, t, q)
			if t["owner"]["kind"] == "PARTY":
				_oversight_report(world, t, String(t["owner"]["id"]))
		"STAFF_T_PROCURE":
			t["outputs"]["procurement_quality"] = int(round(q))
		"STAFF_T_REPORT":
			t["outputs"]["report_quality"] = int(round(q))
		"STAFF_T_TRAINING":
			var pid: String = t["params"]["only_person"]
			var p := person(world, pid)
			var skill: String = t["params"]["skill"]
			var gain := D.TRAINING_GAIN_FAST if p["talents"].has("FAST_LEARNER") else D.TRAINING_GAIN
			p["skills"][skill] = mini(D.TRAINING_CAP, int(p["skills"][skill]) + gain)
		_:
			if def_id.begins_with("STAFF_T_IMPL_"):
				var n_levers: int = int(t["params"].get("levers", 1))
				fact(world, "STAFF_IMPLEMENTATION_COMPLETE", "PUBLIC", [actor] + team, resp, {"GOVERNANCE": 5},
					mini(40, 10 + 5 * n_levers), {"task": t["id"], "instrument": t["params"].get("instrument_id", ""),
					"levers": t["params"].get("lever_ids", []), "months_taken": world.month - int(t["start_month"])})
	for pos in t["positions"]:
		if pos["assigned"] != "":
			state(world)["completed_now"][pos["assigned"]] = t["id"]
			unassign(world, pos["assigned"], "COMPLETED")
	t["status"] = "COMPLETED"
	t["completed_month"] = world.month
	_hist(world, t, "COMPLETED", {"quality": int(round(q))})


## Oversight: reveal SECRET facts whose type starts with one of params.domain_prefixes (spec §3).
static func _oversight_reveal(world: WorldState, t: Dictionary, q: float) -> Array:
	var prefixes: Array = t["params"].get("domain_prefixes", [])
	var rng := world.rng.stream("staff.quality")
	var revealed := world.table("revealed_fact")
	var out: Array = []
	for f in world.facts.query("", -1, world.month, "SECRET"):
		if revealed.has(f["id"]):
			continue
		var hit := false
		for pre in prefixes:
			if String(f["type"]).begins_with(pre):
				hit = true
		if hit and rng.randf() < W.oversight_find_probability(q):
			revealed[f["id"]] = true
			out.append(world.facts.reveal(world.month, f["id"], [owner_actor(world, t["owner"])]))
	return out


# =====================================================================================  deadlines, delivery, overdue

static func check_deadlines(world: WorldState) -> void:
	var tasks := world.table("task")
	for tid in Det.ordered(tasks):
		var t: Dictionary = tasks[tid]
		if t["status"] != "ACTIVE" or not t["params"].has("deadline_month") or t.get("late_reported", false):
			continue
		if world.month > int(t["params"]["deadline_month"]):
			t["late_reported"] = true
			if t["def_id"] == "STAFF_T_BUDGET":
				fact(world, "STAFF_BUDGET_LATE", "PUBLIC", [GOV], [{"actor": GOV, "share": 1.0}], {"GOVERNANCE": -20}, 40, {"task": tid})


## STAFF_DELIVERY_INDEX and STAFF_IMPLEMENTATION_OVERDUE from the enactment table (law's lever pipeline).
## Statuses: PENDING (politics) -> LEGAL -> SCHEDULED -> EFFECTIVE | REJECTED | CANCELLED.
static func delivery(world: WorldState) -> void:
	var changes := world.table("enactment")
	var s := state(world)
	var on_time := 0
	var counted := 0
	for cid in Det.ordered(changes):
		var c: Dictionary = changes[cid]
		if not c.has("legal_month") or c["status"] == "CANCELLED" or c["status"] == "REJECTED":
			continue
		var eff: int = int(c["legal_month"])
		if world.month - eff > D.DELIVERY_WINDOW:
			continue
		if c["status"] == "EFFECTIVE":
			counted += 1
			if int(c["effective_month"]) - eff <= D.DELIVERY_ON_TIME:
				on_time += 1
		elif world.month - eff > D.DELIVERY_ON_TIME:
			counted += 1
			if not s["overdue_reported"].has(cid):
				s["overdue_reported"][cid] = true
				fact(world, "STAFF_IMPLEMENTATION_OVERDUE", "PUBLIC", [GOV], [{"actor": GOV, "share": 1.0}],
					{"GOVERNANCE": -10}, 20, {"enactment": cid, "lever": c["lever"]})
	var v := D.DELIVERY_DEFAULT * MILLI if counted == 0 else int(round(100.0 * MILLI * float(on_time) / float(counted)))
	world.set_indicator("staff", "STAFF_DELIVERY_INDEX", "COLONY", v)


# =====================================================================================  AI staffing (spec §12)

static func _score(world: WorldState, t: Dictionary, idx: int, pid: String) -> float:
	var p := person(world, pid)
	var pd := pos_def(t, idx)
	var def: Dictionary = D.TASKS[t["def_id"]]
	var suit := W.suitability(p, pd["weights"], Q.domain_of(t["params"]))
	return W.individual_w(p, true, suit, def["tags"], "NORMAL", 1.0) * (0.5 + W.member_q(p, suit, def["tags"], "NORMAL") / 200.0)


## AI priority of a task (D7 hook): params.priority if set, else by category. Higher = staffed first.
const CATEGORY_PRIORITY := {"IMPLEMENTATION": 70, "STANDING": 60, "POLITICAL": 65, "PROJECT": 50, "TRAINING": 10}
const MAX_POACH_PER_MONTH := 2
const POACH_MARGIN := 20


static func task_priority(t: Dictionary) -> int:
	if t["params"].has("priority"):
		return int(t["params"]["priority"])
	var p: int = int(CATEGORY_PRIORITY.get(D.TASKS[t["def_id"]]["category"], 40))
	if t["params"].has("deadline_month"):
		p += 25
	if t["params"].has("source_bill"):
		p += 15
	return p


## Owner's active tasks, highest priority first (ties: creation order).
static func _tasks_by_priority(world: WorldState, owner: Dictionary) -> Array:
	var ok := owner_key(owner)
	var tasks := world.table("task")
	var ids: Array = Det.ordered(tasks).filter(func(tid): return tasks[tid]["status"] == "ACTIVE" and owner_key(tasks[tid]["owner"]) == ok)
	var order := {}
	for i in ids.size():
		order[ids[i]] = i
	ids.sort_custom(func(a, b):
		var pa := task_priority(tasks[a])
		var pb := task_priority(tasks[b])
		return pa > pb if pa != pb else order[a] < order[b])
	return ids


static func _best_free(world: WorldState, owner: Dictionary, tid: String, idx: int) -> String:
	var t := task(world, tid)
	var best := ""
	var best_s := -1.0
	for pid in available(world, owner):
		if not eligibility(world, tid, idx, pid)["ok"]:
			continue
		var s := _score(world, t, idx, pid)
		if s > best_s:
			best_s = s
			best = pid
	return best


## Greedy AI staffing (spec-staff §12, D7): mandatory positions by task priority, then optional ones only while
## >= 3 people stay free. If a mandatory position of a task can't be filled from free staff, the AI moves someone
## off a task at least POACH_MARGIN priority lower (optional holders first), at most MAX_POACH_PER_MONTH per month.
static func auto_staff(world: WorldState, owner: Dictionary) -> void:
	var order := _tasks_by_priority(world, owner)
	var poached := 0
	# 1. Mandatory vacancies, as a maximum bipartite matching with free people (slots in priority order,
	#    candidates best-first). Greedy best-first can strand a slot that a full assignment would fill.
	var slots: Array = []
	for tid in order:
		var t := task(world, tid)
		for idx in t["positions"].size():
			if t["positions"][idx]["assigned"] == "" and pos_def(t, idx)["mandatory"]:
				slots.append([tid, idx])
	var free := available(world, owner)
	var adj: Array = []
	for s in slots:
		var cands: Array = []
		for j in free.size():
			if eligibility(world, s[0], s[1], free[j])["ok"]:
				cands.append([_score(world, task(world, s[0]), s[1], free[j]), j])
		cands.sort_custom(func(a, b): return a[0] > b[0] if a[0] != b[0] else a[1] < b[1])
		adj.append(cands.map(func(x): return x[1]))
	var holder: Array = []
	holder.resize(free.size())
	holder.fill(-1)
	for i in slots.size():
		var seen: Array = []
		seen.resize(free.size())
		seen.fill(false)
		RG._augment(i, adj, holder, seen)
	for j in free.size():
		if holder[j] >= 0:
			_do_assign(world, slots[holder[j]][0], slots[holder[j]][1], free[j])
	# 2. Whatever is still vacant: reassign from lower-priority work (limited per month).
	for tid in order:
		var t := task(world, tid)
		for idx in t["positions"].size():
			if t["positions"][idx]["assigned"] != "" or not pos_def(t, idx)["mandatory"]:
				continue
			var best := _best_free(world, owner, tid, idx)
			if best == "" and poached < MAX_POACH_PER_MONTH:
				best = _poach(world, owner, tid, idx, task_priority(t) - POACH_MARGIN)
				if best != "":
					poached += 1
			if best != "":
				_do_assign(world, tid, idx, best)
	for tid in order:
		var t := task(world, tid)
		for idx in t["positions"].size():
			if t["positions"][idx]["assigned"] != "" or pos_def(t, idx)["mandatory"]:
				continue
			if available(world, owner).size() < 3:
				return
			var best := _best_free(world, owner, tid, idx)
			if best != "":
				_do_assign(world, tid, idx, best)


## Find a qualified person on a lower-priority task (optional positions first), release them, return their id.
static func _poach(world: WorldState, owner: Dictionary, tid: String, idx: int, max_priority: int) -> String:
	var t := task(world, tid)
	var best := ""
	var best_key := []
	for pid in pool_members(world, owner):
		var p := person(world, pid)
		if p["status"] != "ACTIVE" or p["assignment_id"] == "":
			continue
		var a: Dictionary = world.table("assignment")[p["assignment_id"]]
		var other := task(world, a["task_id"])
		if a["task_id"] == tid or task_priority(other) > max_priority:
			continue
		# eligibility ignoring that the person is currently busy
		p["assignment_id"] = ""
		var ok: bool = eligibility(world, tid, idx, pid)["ok"]
		p["assignment_id"] = a["id"]
		if not ok:
			continue
		var key := [0 if pos_def(other, int(a["pos"]))["mandatory"] else 1, -task_priority(other), _score(world, t, idx, pid)]
		if best == "" or _tuple_gt(key, best_key):
			best = pid
			best_key = key
	if best != "":
		unassign(world, best, "REASSIGNED")
	return best

static func auto_appoint(world: WorldState) -> void:
	var gs := world.table("gov_seat")
	for sid in Det.ordered(gs):
		var seat: Dictionary = gs[sid]
		if seat["person_id"] != "":
			continue
		var pty_owner := {"kind": "PARTY", "id": seat["party_id"]}
		if not autopilot(world, pty_owner):
			continue
		var bench := _bench(world, seat["party_id"])
		var best := ""
		for pid in bench:
			if best == "" or _person_value(person(world, pid)) > _person_value(person(world, best)):
				best = pid
		if best != "":
			appoint_political(world, sid, best)


static func auto_answer(world: WorldState) -> void:
	var reqs := world.table("decision_request")
	for rid in Det.ordered(reqs):
		var r: Dictionary = reqs[rid]
		if r["status"] == "OPEN":
			var t := task(world, r["task_id"])
			if not t.is_empty() and autopilot(world, t["owner"]):
				answer_decision(world, rid, r["recommended"])


# =====================================================================================  reports (spec §11, S §14)

static func make_reports(world: WorldState) -> void:
	var s := state(world)
	var people := world.table("person")
	var reports := world.table("staff_report")
	for pid in Det.ordered(people):
		var p: Dictionary = people[pid]
		if p["pool"] == "" or not is_alive_active(p):
			continue
		var flags: Array = s["flags"].get(pid, [])
		var cat := "AVAILABLE"
		var tid := ""
		var delta := 0
		var total := 0
		if s["completed_now"].has(pid):
			cat = "COMPLETED"
			tid = s["completed_now"][pid]
		elif p["assignment_id"] != "":
			tid = world.table("assignment")[p["assignment_id"]]["task_id"]
			var t := task(world, tid)
			delta = int(t["month_delta"])
			total = int(t["progress"])
			if task_blocked(world, tid):
				cat = "DECISION_REQUIRED"
			elif not flags.is_empty():
				cat = "ATTENTION"
			else:
				cat = "ROUTINE"
		elif flags.has("ILL"):
			cat = "ATTENTION"
		var rid := world.new_id("srep")
		reports[rid] = {"id": rid, "staff_id": pid, "month": world.month, "category": cat,
			"priority": D.REPORT_PRIORITY[cat], "task_id": tid, "progress_change": delta, "total_progress": total,
			"problems": flags.duplicate()}
	# Compress: drop routine/available reports older than 12 months, keep monthly counts (S §14.7).
	var cutoff := world.month - D.REPORT_KEEP_MONTHS
	for rid in Det.ordered(reports):
		var r: Dictionary = reports[rid]
		if int(r["month"]) < cutoff and (r["category"] == "ROUTINE" or r["category"] == "AVAILABLE"):
			var key := "%d|%s" % [r["month"], r["category"]]
			s["report_counts"][key] = int(s["report_counts"].get(key, 0)) + 1
			reports.erase(rid)
	s["flags"] = {}
	s["completed_now"] = {}


# =====================================================================================  invariants (S §23)

static func check_invariants(world: WorldState) -> Array:
	var errs: Array = []
	var people := world.table("person")
	var tasks := world.table("task")
	var asg := world.table("assignment")
	var active_by_person := {}
	for aid in Det.ordered(asg):
		var a: Dictionary = asg[aid]
		if a["status"] != "ACTIVE":
			continue
		if not people.has(a["staff_id"]):
			errs.append("assignment %s: unknown person" % aid)
			continue
		if not tasks.has(a["task_id"]):
			errs.append("assignment %s: unknown task" % aid)
			continue
		active_by_person[a["staff_id"]] = int(active_by_person.get(a["staff_id"], 0)) + 1
		var t: Dictionary = tasks[a["task_id"]]
		if t["status"] != "ACTIVE":
			errs.append("assignment %s on non-active task" % aid)
		if int(a["pos"]) >= t["positions"].size() or t["positions"][int(a["pos"])]["assigned"] != a["staff_id"]:
			errs.append("assignment %s: position mismatch" % aid)
		if people[a["staff_id"]]["assignment_id"] != aid:
			errs.append("assignment %s: person back-link" % aid)
	for pid in active_by_person:
		if int(active_by_person[pid]) > 1:
			errs.append("person %s has %d active assignments" % [pid, active_by_person[pid]])
	for pid in Det.ordered(people):
		var p: Dictionary = people[pid]
		if p["assignment_id"] != "" and not active_by_person.has(pid):
			errs.append("person %s points to closed assignment" % pid)
		if p["assignment_id"] != "" and not is_alive_active(p):
			errs.append("departed person %s still assigned" % pid)
	for tid in Det.ordered(tasks):
		var t: Dictionary = tasks[tid]
		for i in t["positions"].size():
			var holder: String = t["positions"][i]["assigned"]
			if holder != "" and (not people.has(holder) or people[holder]["assignment_id"] == "" \
					or asg[people[holder]["assignment_id"]]["task_id"] != tid):
				errs.append("task %s pos %d: orphaned holder" % [tid, i])
	var civil := 0
	for pid in Det.ordered(people):
		if people[pid]["pool"] == "GOV" and people[pid]["roles"].has("CIVIL_SERVANT") and is_alive_active(people[pid]):
			civil += 1
	var open := 0
	for rid in Det.ordered(world.table("recruitment")):
		if world.table("recruitment")[rid]["status"] == "OPEN":
			open += 1
	if civil + open != D.POLITICAL_SEATS:
		errs.append("civil service %d + open recruitments %d != 10" % [civil, open])
	return errs


# =====================================================================================  queries for other systems

## Quality (0..100000 milli) of the most effective active instance of a duty; `unmanaged` if none is effective.
static func duty_quality(world: WorldState, def_id: String, unmanaged: int) -> int:
	var best_e := 0
	var q := unmanaged
	var tasks := world.table("task")
	for tid in Det.ordered(tasks):
		var t: Dictionary = tasks[tid]
		if t["status"] == "ACTIVE" and t["def_id"] == def_id and int(t["effectiveness"]) > best_e:
			best_e = int(t["effectiveness"])
			q = int(t["quality"])
	return q


## Best effectiveness (0..1000 milli) among active government instances of a standing duty; 0 = unmanaged.
static func duty_effectiveness(world: WorldState, def_id: String) -> int:
	var best := 0
	var tasks := world.table("task")
	for tid in Det.ordered(tasks):
		var t: Dictionary = tasks[tid]
		if t["status"] == "ACTIVE" and t["def_id"] == def_id:
			best = maxi(best, int(t["effectiveness"]))
	return best


static func _tuple_gt(a: Array, b: Array) -> bool:
	for i in mini(a.size(), b.size()):
		if a[i] != b[i]:
			return a[i] > b[i]
	return false


## Facts an inquiry does not treat as findings: a refused econ order (e.g. not enough budget headroom) is the
## system working as designed, not a failure to expose. Decided by a9, 2026-11-11.
const NOT_FINDINGS := ["ECON_ACTION_FAILED"]


## An opposition inquiry publishes what it found (M7): OFFICIAL government failures in its domain from the last
## 24 months that the party could not see before become a PUBLIC report blaming the government. Then the party
## gets its access grants (spec-visibility §4).
static func _oversight_report(world: WorldState, t: Dictionary, pid: String) -> void:
	var prefixes: Array = t["params"].get("domain_prefixes", [])
	var viewer := {"party_id": pid}
	var findings: Array = []
	for f in world.facts.query("", world.month - Vis.OVERSIGHT_FACT_MONTHS, world.month, "OFFICIAL"):
		if not Vis._prefix_hit(prefixes, f["type"]) or Vis.can_see_fact(world, viewer, f) or NOT_FINDINGS.has(f["type"]):
			continue
		var gov := false
		for r in f["responsible"]:
			gov = gov or r["actor"].get("kind", "") in ["GOVERNMENT", "COMMANDER", "AUTHORITY"]
		if gov:
			findings.append(f["id"])
	Vis.grant_oversight(world, pid, prefixes, t["id"])
	var revealed: Array = t["outputs"].get("revealed", [])
	var n := findings.size() + 2 * revealed.size()
	var party := {"kind": "PARTY", "id": pid}
	if n == 0:
		fact(world, "STAFF_OVERSIGHT_REPORT", "PUBLIC", [party, GOV], [{"actor": party, "share": 1.0}], {}, 10,
			{"party": pid, "domain": t["params"].get("domain", ""), "findings": 0, "revealed": []})
		return
	fact(world, "STAFF_OVERSIGHT_REPORT", "PUBLIC", [party, GOV], [{"actor": GOV, "share": 1.0}],
		{"GOVERNANCE": -mini(15, 2 * n)}, mini(60, 15 + 5 * n),
		{"party": pid, "domain": t["params"].get("domain", ""), "findings": findings.size(), "revealed": revealed},
		findings + revealed)


## Number of vacant positions (mandatory + optional) on the owner's active tasks.
static func open_positions_count(world: WorldState, owner: Dictionary) -> int:
	var n := 0
	var key := owner_key(owner)
	for tid in Det.ordered(world.table("task")):
		var t: Dictionary = world.table("task")[tid]
		if t["status"] == "ACTIVE" and owner_key(t["owner"]) == key:
			for p in t["positions"]:
				if p["assigned"] == "":
					n += 1
	return n


## Government crisis hook (M7, called by politics): the coalition changed from old_members to new_members
## (a partner left, or joined). Departing parties' officials leave their posts at once: their positions go vacant
## and dependent work pauses next month. Political seats are reallocated (Sainte-Laguë, min 1) among the
## remaining parties; partner AI fills its new seats in the next DECISIONS. Departing parties get opposition pools.
## Returns {departed: [person ids], vacated_tasks: [task ids], seats: {party: n}}.
static func on_coalition_change(world: WorldState, old_members: Array, new_members: Array) -> Dictionary:
	var people := world.table("person")
	var departed: Array = []
	var vacated := {}
	for pid in Det.ordered(people):
		var p: Dictionary = people[pid]
		if p["pool"] != "GOV" or not p["roles"].has("GOV_POLITICAL") or new_members.has(p["party_id"]) or not old_members.has(p["party_id"]):
			continue
		if p["assignment_id"] != "":
			var a: Dictionary = world.table("assignment")[p["assignment_id"]]
			var t := task(world, a["task_id"])
			if pos_def(t, int(a["pos"]))["mandatory"]:
				vacated[a["task_id"]] = true
		departed.append(pid)
	var parties := world.table("party")
	var seats := {}
	for pty in new_members:
		seats[pty] = int(parties.get(pty, {}).get("seats", 0))
	var alloc := form_government(world, new_members, seats)   # removes departing parties' seats (their officials leave)
	for pty in old_members:
		if new_members.has(pty):
			continue
		var gone: Array = departed.filter(func(id): return people[id]["party_id"] == pty)
		var pref := {"kind": "PARTY", "id": pty}
		fact(world, "STAFF_OFFICIALS_WITHDRAWN", "PUBLIC", [pref, GOV], [{"actor": pref, "share": 1.0}], {"GOVERNANCE": -5},
			mini(60, 20 + 5 * gone.size()), {"party": pty, "officials": gone, "vacated_tasks": vacated.keys()})
		if int(parties.get(pty, {}).get("seats", 0)) > 0 and party_active(world, pty):
			set_party_pool(world, pty, int(parties[pty]["seats"]))
	state(world)["pools_dirty"] = true
	return {"departed": departed, "vacated_tasks": vacated.keys(), "seats": alloc}

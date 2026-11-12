extends RefCounted
## T7 traffic engineering (planning/spec-transport-v1.md T7), staff side. Owner: Anni.
##
## The infrastructure department runs STAFF_T_TRAFFIC_STUDY once a year (January) and after a serious accident. The
## finished study becomes a traffic report: the worst links and junctions with counts, accidents and a recommended fix
## with estimated cost and time. Quality follows the staff model (task quality 0..100 from the team's ENG skill):
## a weak team misses problems, misjudges costs and sometimes recommends the wrong fix (lights where a roundabout
## would do). An unstaffed study is late (fact after LATE_MONTHS) and produces nothing.
## A fatal accident where a report had flagged the spot and nothing was ordered is a scandal (STAFF_REPORT_IGNORED,
## caused by the report and the accident). Wilma's government AI / the player act on items: order_item, decline_item.
##
## Inputs (plain data, so the module works before T1–T4 land):
##   table "traffic_stat"  key "<LINK|NODE>:<id>"  (Bob): {kind, id, name, load_pm (12-month mean flow / capacity, ‰),
##       flow (per month), accidents_12m, serious_12m, fatal_12m}
##   Transport.traffic_fixes(world) (Terra), same keys: {options: [{fix, cost (mcr), months, cap_pm (capacity
##       after/before ‰), acc_pm (accident rate after/before ‰), spec (the ROAD project's "link" param)}]}.
##       A non-empty table "traffic_fix" of the same shape overrides it (tests, scenarios).
##   facts ACCIDENT_TYPES (Bob): data {target: key, serious: bool, fatal: int}

const Det := preload("res://sim/staff/det.gd")
const Ops := preload("res://sim/staff/staff_ops.gd")

const TASK := "STAFF_T_TRAFFIC_STUDY"
const ACCIDENT_TYPES := ["ECON_TRAFFIC_ACCIDENT"]
const MAX_ITEMS := 5
const MIN_SEVERITY := 5.0
const CONGESTION_FROM_PM := 800          # load above 80% of capacity is a problem (spec T7)
const LATE_MONTHS := 6
const IGNORE_GRACE := 3                  # months a government has to act before a fatal crash is "ignored"
const WRONG_FIX_MAX := 0.6               # p(wrong fix) at quality 0: WRONG_FIX_MAX × (1 − q/100)^1.5
const ESTIMATE_SD := 0.35                # cost/time estimate error at quality 0 (× (1 − q/100))


# ===================================================================================== monthly hooks

## DECISIONS (before auto-staffing): start the yearly study, or one after a serious accident last month.
static func start_studies(world: WorldState) -> void:
	if world.peek("traffic_stat").is_empty() or not _active(world).is_empty():
		return
	for f in world.facts.query("", world.month - 1, world.month - 1):
		if f["type"] in ACCIDENT_TYPES and (bool(f["data"].get("serious", false)) or int(f["data"].get("fatal", 0)) > 0):
			Ops.create_task(world, TASK, {"kind": "ACCIDENT", "cause_fact": String(f["id"]),
				"target": String(f["data"].get("target", ""))}, Ops.GOV)
			return
	if world.month % 12 == 0:
		Ops.create_task(world, TASK, {"kind": "YEARLY"}, Ops.GOV)


## STAFF (after process_tasks): late studies and ignored reports.
static func monthly(world: WorldState) -> void:
	for tid in _active(world):
		var t: Dictionary = world.table("task")[tid]
		if world.month - int(t["start_month"]) >= LATE_MONTHS and not t.get("late_reported", false):
			t["late_reported"] = true
			Ops.fact(world, "STAFF_TRAFFIC_REPORT_LATE", "OFFICIAL", [Ops.GOV], [{"actor": Ops.GOV, "share": 1.0}],
				{"GOVERNANCE": -2}, 20, {"task": tid, "kind": String(t["params"].get("kind", "YEARLY"))})
	_check_ignored(world)


static func _active(world: WorldState) -> Array:
	var out: Array = []
	var tasks := world.table("task")
	for tid in Det.ordered(tasks):
		if tasks[tid]["def_id"] == TASK and tasks[tid]["status"] == "ACTIVE":
			out.append(tid)
	return out


# ===================================================================================== the report

## Called from StaffOps.complete_task with the task quality (0..100).
static func on_complete(world: WorldState, t: Dictionary, q: float) -> void:
	var rng := world.rng.stream("staff.traffic")
	var fixes: Dictionary = world.peek("traffic_fix")
	if fixes.is_empty():
		fixes = Transport.traffic_fixes(world)
	var items := build_items(world.peek("traffic_stat"), fixes, q, rng,
		int(world.values.get("ECON_W_REF", 1200000)))
	var id := world.new_id("treport")
	var kind := String(t["params"].get("kind", "YEARLY"))
	var cause := String(t["params"].get("cause_fact", ""))
	var team: Array = []
	for pos in t["positions"]:
		if pos["assigned"] != "":
			team.append(Ops.official_ref(pos["assigned"]))
	var fid := Ops.fact(world, "STAFF_TRAFFIC_REPORT", "OFFICIAL", [Ops.GOV] + team, [{"actor": Ops.GOV, "share": 1.0}], {},
		15 + 5 * items.size(), {"report": id, "kind": kind, "items": items.size(),
		"top": String(items[0]["name"]) if not items.is_empty() else ""}, [cause] if cause != "" else [])
	world.table("traffic_report")[id] = {"id": id, "month": world.month, "kind": kind, "cause_fact": cause,
		"task": t["id"], "quality": int(round(q)), "fact": fid, "items": items}
	t["outputs"]["report"] = id


## Pure: rank the problems, detect them as well as the team can, and pick a fix for each. -> items (best first).
static func build_items(stats: Dictionary, fixes: Dictionary, q: float, rng: RandomNumberGenerator, wref: int) -> Array:
	var qf := clampf(q / 100.0, 0.0, 1.0)
	var seen: Array = []
	for key in Det.ordered(stats):
		var s: Dictionary = stats[key]
		var sev := severity(s)
		if sev < MIN_SEVERITY:
			continue
		var p_detect := clampf(0.2 + 0.7 * qf + sev / 100.0, 0.1, 1.0)
		if rng.randf() >= p_detect:
			continue
		var perceived := sev * (1.0 + rng.randfn(0.0, 0.3 * (1.0 - qf)))
		seen.append({"key": String(key), "s": s, "perceived": perceived})
	seen.sort_custom(func(a, b): return a["perceived"] > b["perceived"] or (a["perceived"] == b["perceived"] and a["key"] < b["key"]))
	var items: Array = []
	for x in seen.slice(0, MAX_ITEMS):
		var s: Dictionary = x["s"]
		var opts: Array = fixes.get(x["key"], {}).get("options", [])
		var item := {"key": x["key"], "kind": String(s.get("kind", "")), "id": String(s.get("id", "")),
			"name": String(s.get("name", x["key"])), "problem": problem(s), "load_pm": int(s.get("load_pm", 0)),
			"accidents_12m": int(s.get("accidents_12m", 0)), "serious_12m": int(s.get("serious_12m", 0)),
			"fatal_12m": int(s.get("fatal_12m", 0)), "fix": "", "est_cost": 0, "est_months": 0, "best_fix": "",
			"wrong": false, "status": "OPEN", "decided_month": -1, "scandal": false}
		if not opts.is_empty():
			var best := best_option(s, opts, wref)
			var pick := best
			if opts.size() > 1 and rng.randf() < WRONG_FIX_MAX * pow(1.0 - qf, 1.5):
				pick = (best + 1 + rng.randi_range(0, opts.size() - 2)) % opts.size()
			var o: Dictionary = opts[pick]
			var err := ESTIMATE_SD * (1.0 - qf)
			item["fix"] = String(o["fix"])
			item["spec"] = o.get("spec", {}).duplicate(true) if o.get("spec", {}) is Dictionary else o.get("spec", {})
			item["best_fix"] = String(opts[best]["fix"])
			item["wrong"] = pick != best
			item["est_cost"] = maxi(0, int(round(float(o["cost"]) * (1.0 + clampf(rng.randfn(0.0, err), -0.6, 0.6)))))
			item["est_months"] = maxi(1, int(round(float(o["months"]) * (1.0 + clampf(rng.randfn(0.0, err), -0.6, 0.6)))))
		items.append(item)
	return items


## Severity points: congestion above 80% of capacity, and accidents (serious ×3, fatal ×10).
static func severity(s: Dictionary) -> float:
	return maxf(0.0, float(int(s.get("load_pm", 0)) - CONGESTION_FROM_PM)) / 10.0 + float(s.get("accidents_12m", 0)) \
		+ 3.0 * float(s.get("serious_12m", 0)) + 10.0 * float(s.get("fatal_12m", 0))


static func problem(s: Dictionary) -> String:
	var cong := int(s.get("load_pm", 0)) >= CONGESTION_FROM_PM
	var acc := int(s.get("serious_12m", 0)) + int(s.get("fatal_12m", 0)) > 0 or int(s.get("accidents_12m", 0)) >= 3
	return "BOTH" if cong and acc else ("CONGESTION" if cong else "ACCIDENTS")


## The right fix: most relief (capacity where congested, safety where crashes happen) per cost. -> option index.
static func best_option(s: Dictionary, opts: Array, wref: int) -> int:
	var cong_w := maxf(0.0, float(int(s.get("load_pm", 0)) - 700)) / 300.0
	var acc_w := (float(s.get("accidents_12m", 0)) + 3.0 * float(s.get("serious_12m", 0)) + 10.0 * float(s.get("fatal_12m", 0))) / 10.0
	var best := 0
	var best_v := -INF
	for i in opts.size():
		var o: Dictionary = opts[i]
		var gain := cong_w * maxf(0.0, float(int(o.get("cap_pm", 1000)) - 1000)) / 1000.0 \
			+ acc_w * maxf(0.0, float(1000 - int(o.get("acc_pm", 1000)))) / 1000.0
		var v := gain / (float(o.get("cost", 0)) / float(maxi(1, wref)) / 100.0 + 1.0)
		if v > best_v:
			best_v = v
			best = i
	return best


# ===================================================================================== decisions (Wilma / player)

## Open recommendations of the latest reports, for the government AI and the UI (the hidden truth left out):
## [{report, idx, key, name, problem, fix, est_cost, est_months, load_pm, accidents_12m, serious_12m, fatal_12m, month}].
static func open_items(world: WorldState) -> Array:
	var out: Array = []
	var reps := world.peek("traffic_report")
	for rid in Det.ordered(reps):
		var r: Dictionary = reps[rid]
		for i in r["items"].size():
			var it: Dictionary = r["items"][i]
			if it["status"] == "OPEN" and it["fix"] != "":
				out.append({"report": rid, "idx": i, "key": it["key"], "name": it["name"], "problem": it["problem"],
					"fix": it["fix"], "spec": it.get("spec", {}), "est_cost": it["est_cost"], "est_months": it["est_months"], "load_pm": it["load_pm"],
					"accidents_12m": it["accidents_12m"], "serious_12m": it["serious_12m"], "fatal_12m": it["fatal_12m"],
					"month": r["month"]})
	return out


## The government orders a recommended fix (Wilma then commissions it: ECON_COMMISSION_PROJECT {type: "ROAD",
## district, link: item spec}, or Transport.fix_spec(world, key, fix)). Supersedes older open items on
## the same target. -> {ok, key, fix}
static func order_item(world: WorldState, rid: String, idx: int, project_id: String = "") -> Dictionary:
	var it := _item(world, rid, idx)
	if it.is_empty() or it["status"] != "OPEN":
		return {"ok": false, "reason": "no open item"}
	it["status"] = "ORDERED"
	it["decided_month"] = world.month
	it["project"] = project_id
	_close_same_target(world, it["key"], rid)
	return {"ok": true, "key": it["key"], "fix": it["fix"]}


static func decline_item(world: WorldState, rid: String, idx: int) -> Dictionary:
	var it := _item(world, rid, idx)
	if it.is_empty() or it["status"] != "OPEN":
		return {"ok": false, "reason": "no open item"}
	it["status"] = "DECLINED"
	it["decided_month"] = world.month
	return {"ok": true}


static func _item(world: WorldState, rid: String, idx: int) -> Dictionary:
	var r: Dictionary = world.table("traffic_report").get(rid, {})
	if r.is_empty() or idx < 0 or idx >= r["items"].size():
		return {}
	return r["items"][idx]


static func _close_same_target(world: WorldState, key: String, keep_rid: String) -> void:
	var reps := world.table("traffic_report")
	for rid in Det.ordered(reps):
		if rid == keep_rid:
			continue
		for it in reps[rid]["items"]:
			if it["key"] == key and it["status"] == "OPEN":
				it["status"] = "SUPERSEDED"


# ===================================================================================== the scandal

## A fatal accident last month on a spot a report flagged at least IGNORE_GRACE months earlier, with the item still
## open or declined: STAFF_REPORT_IGNORED (PUBLIC), caused by the report and the accident. Once per item.
static func _check_ignored(world: WorldState) -> void:
	var reps := world.table("traffic_report")
	if reps.is_empty():
		return
	for f in world.facts.query("", world.month - 1, world.month):
		if not (f["type"] in ACCIDENT_TYPES) or int(f["data"].get("fatal", 0)) <= 0:
			continue
		var key := String(f["data"].get("target", ""))
		for rid in Det.ordered(reps):
			var r: Dictionary = reps[rid]
			if int(r["month"]) > int(f["month"]) - IGNORE_GRACE:
				continue
			for it in r["items"]:
				if it["key"] != key or it["scandal"] or not (it["status"] in ["OPEN", "DECLINED"]):
					continue
				it["scandal"] = true
				Ops.fact(world, "STAFF_REPORT_IGNORED", "PUBLIC", [Ops.GOV], [{"actor": Ops.GOV, "share": 1.0}],
					{"SAFETY": -5, "GOVERNANCE": -8}, 65,
					{"report": rid, "target": key, "name": it["name"], "fix": it["fix"], "accident": f["id"],
					"fatal": int(f["data"].get("fatal", 0)), "months_ignored": int(f["month"]) - int(r["month"]),
					"declined": it["status"] == "DECLINED"}, [String(r["fact"]), String(f["id"])])

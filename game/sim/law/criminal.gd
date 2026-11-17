extends RefCounted
## P2a criminal procedure, sentences, holding cells and reoffending (planning/design-p2-courts-prisons.md §1–§4).
## Owner: Anni (law). Preload it (no class_name). Opt-in meta["on"] "PRISONS" (with "CRIME"); meta["off"] wins.
##
## Ordinary crime stays aggregate: solved offences (crime.gd) are charged into a per-kind docket, the courts hear it
## before civil cases (the share they use is taken off the civil capacity next month), verdicts and LAW_SENTENCING turn
## convictions into fines, community service or prison. Prisoners and pretrial detainees fill the places: 4 cells per
## police station until Bob's PRISON facility exists (P2b). Overcrowding brings disturbances and escapes; released
## prisoners join a district pool of recent offenders that adds THEFT and VIOLENCE (crime.gd).
## Named prisoners: convicted CEOs (SEVERE company cases) and party leaders (party finance) can be imprisoned
## (LAW_IMPRISONED); JusticeOps calls named_months / imprison_named.

const LawOps := preload("res://sim/law/law_ops.gd")
const Det := preload("res://sim/staff/det.gd")

const GOVERNMENT := {"kind": "GOVERNMENT", "id": "government"}
const KINDS := ["THEFT", "VIOLENCE", "FRAUD"]
# --- procedure
const CHARGE_PM := {"THEFT": 700, "VIOLENCE": 900, "FRAUD": 800}        # solved cases prosecuted
const CP_COST := {"THEFT": 0.2, "VIOLENCE": 1.0, "FRAUD": 1.5}          # court points per case
const CONVICT_PM := {"THEFT": 850, "VIOLENCE": 750, "FRAUD": 650}       # at good evidence
const PRETRIAL_MIN := 0.3                # share of charged VIOLENCE held pretrial at powers 0 …
const PRETRIAL_SPAN := 0.4               # … + this at powers 100
const PRETRIAL_LIMIT := 6                # months a detainee may wait for the court
const BACKLOG_MONTHS := 3.0              # docket above this many months of capacity …
const BACKLOG_PERSIST := 3               # … for this many months: LAW_COURT_BACKLOG
const FACT_GAP := 12                     # months between repeats of the same standing fact
# --- sentences: LAW_SENTENCING anchors 0 / 40 / 100: [prison share ‰, mean months]
const SENTENCE := {
	"THEFT": [[20, 1], [100, 3], [350, 9]],
	"VIOLENCE": [[250, 6], [500, 14], [850, 36]],
	"FRAUD": [[80, 3], [250, 8], [600, 24]],
}
const SENTENCING_DEFAULT := 40
const REPEAT_HALF := 20.0                # repeat share = pool / (pool + REPEAT_HALF) persons (cap REPEAT_MAX)
const REPEAT_MAX := 0.6
const REPEAT_MULT := 2
# --- places and overcrowding
const CELLS_PER_STATION := 4
const HELD_TOO_LONG := 3                 # months in police cells before it is a scandal
const P_DISTURB_PER := 0.1               # × (occupancy ratio − 1), a month
const ESCAPE_FROM := 1.3
const P_ESCAPE_PER := 0.33               # × (ratio − ESCAPE_FROM), a month, capped
const P_ESCAPE_MAX := 0.2
const ESCAPE_SHARE := 0.3                # of the prisoners over capacity
# --- reoffending
const POOL_DECAY := 1.0 / 24.0
const OFFENCES_PER_REOFFENDER := 0.3     # a month (THEFT 80%, VIOLENCE 20%)
const REOFFEND_SPLIT := {"THEFT": 0.8, "VIOLENCE": 0.2}
# --- named prisoners (white-collar: the FRAUD row)
const NAMED_KIND := "FRAUD"
const DISQUALIFY_MONTHS := 12            # a sentence this long costs a member their seat (Wilma)


static func on(world: WorldState) -> bool:
	var on_list: Array = world.meta.get("on", [])
	var off_list: Array = world.meta.get("off", [])
	return on_list.has("PRISONS") and not off_list.has("PRISONS")


static func state(world: WorldState) -> Dictionary:
	var s := LawOps.state(world)
	if not s.has("criminal"):
		s["criminal"] = {"docket": {}, "prisoners": [], "pool": {}, "cp_share_pm": 0, "backlog_run": 0, "last": {},
			"month": {}, "totals": {}}
		for k in KINDS:
			s["criminal"]["docket"][k] = []
	return s["criminal"]


static func _peek(world: WorldState) -> Dictionary:
	return world.peek("law_state").get("s", {}).get("criminal", {})


static func sentencing(world: WorldState) -> int:
	return clampi(int(world.levers.get("LAW_SENTENCING", SENTENCING_DEFAULT)), 0, 100)


## [prison share 0..1, mean months] for a kind at the current LAW_SENTENCING (linear between the anchors).
static func sentence_terms(world: WorldState, kind: String) -> Array:
	var a: Array = SENTENCE[kind]
	var x := sentencing(world)
	var lo: Array = a[0] if x <= 40 else a[1]
	var hi: Array = a[1] if x <= 40 else a[2]
	var t := float(x) / 40.0 if x <= 40 else float(x - 40) / 60.0
	return [lerpf(float(lo[0]), float(hi[0]), t) / 1000.0, lerpf(float(lo[1]), float(hi[1]), t)]


static func reoffend_rate(world: WorldState) -> float:
	var r := clampi(int(world.levers.get("LAW_PRISON_REGIME", 50)), 0, 100)
	return 0.5 - 0.3 * float(r) / 100.0


# =====================================================================================  monthly

static func monthly(world: WorldState) -> void:
	if not on(world):
		return
	var crime: Dictionary = world.peek("law_state").get("s", {}).get("crime", {})
	var st := state(world)
	var rng := world.rng.stream("law.criminal")
	st["month"] = {"charged": 0, "heard": 0, "convicted": 0, "prison": 0, "fines": 0, "released": 0, "time_limit": 0,
		"escaped": 0}
	if not crime.is_empty():          # ordinary crime needs the crime model; named prisoners do not
		_charge(world, st, crime, rng)
		_hear(world, st, crime, rng)
	_time_limits(world, st)
	_release(world, st)
	_overcrowding(world, st, rng)
	for d in st["pool"].keys():
		st["pool"][d] = int(round(float(st["pool"][d]) * (1.0 - POOL_DECAY)))
		if int(st["pool"][d]) < 50:
			st["pool"].erase(d)
	for k in st["month"]:
		st["totals"][k] = int(st["totals"].get(k, 0)) + int(st["month"][k])


static func _draw(rng: RandomNumberGenerator, expected: float) -> int:
	var n := int(floor(expected))
	if rng.randf() < expected - floor(expected):
		n += 1
	return n


static func _charge(world: WorldState, st: Dictionary, crime: Dictionary, rng: RandomNumberGenerator) -> void:
	var pre_share := PRETRIAL_MIN + PRETRIAL_SPAN * float(load("res://sim/law/police.gd").powers(world)) / 100.0
	var rows: Dictionary = crime.get("d", {})
	for d in Det.ordered(rows):
		var row: Dictionary = rows[d]
		if int(row.get("month", -1)) != world.month:
			continue
		for k in KINDS:
			var solved := int(row.get("m", {}).get(k, [0, 0, 0])[2])
			var n := _draw(rng, float(solved) * float(CHARGE_PM[k]) / 1000.0)
			if n <= 0:
				continue
			var pre := _draw(rng, float(n) * pre_share) if k == "VIOLENCE" else 0
			(st["docket"][k] as Array).append({"m": world.month, "d": String(d), "n": n, "pre": mini(pre, n)})
			st["month"]["charged"] += n


## Court points a month across all courts (JusticeOps.capacity) — the criminal docket goes first.
static func court_points(world: WorldState) -> float:
	var J = load("res://sim/law/justice_ops.gd")
	var tot := 0.0
	for cid in Det.ordered(world.peek("court")):
		tot += float(J.capacity(world, world.peek("court")[cid]))
	return tot


static func _hear(world: WorldState, st: Dictionary, crime: Dictionary, rng: RandomNumberGenerator) -> void:
	var total := court_points(world)
	var left := total
	# oldest batches first across kinds
	var queue: Array = []
	for k in KINDS:
		for b in st["docket"][k]:
			queue.append([int(b["m"]), k, b])
	queue.sort_custom(func(x, y): return x[0] < y[0] or (x[0] == y[0] and KINDS.find(x[1]) < KINDS.find(y[1])))
	for q in queue:
		var k: String = q[1]
		var b: Dictionary = q[2]
		var cost := float(CP_COST[k])
		var can := mini(int(b["n"]), int(floor(left / cost + 1e-6)))
		if can <= 0:
			break
		left -= float(can) * cost
		var pre_heard := mini(int(b["pre"]), can)
		b["pre"] = int(b["pre"]) - pre_heard
		b["n"] = int(b["n"]) - can
		_verdicts(world, st, crime, rng, k, String(b["d"]), can)
	for k in KINDS:
		st["docket"][k] = (st["docket"][k] as Array).filter(func(b): return int(b["n"]) > 0)
	st["cp_share_pm"] = 0 if total <= 0.0 else clampi(int(round(1000.0 * (total - left) / total)), 0, 1000)
	var need := 0.0
	for k in KINDS:
		for b in st["docket"][k]:
			need += float(int(b["n"])) * float(CP_COST[k])
	st["backlog_pm"] = 0 if total <= 0.0 else int(round(1000.0 * need / total))
	st["backlog_run"] = int(st["backlog_run"]) + 1 if need > BACKLOG_MONTHS * total else 0
	if int(st["backlog_run"]) >= BACKLOG_PERSIST and _gap_ok(world, st, "backlog"):
		LawOps.law_fact(world, "LAW_COURT_BACKLOG", "PUBLIC", [GOVERNMENT], [{"actor": GOVERNMENT, "share": 1.0}],
			{"GOVERNANCE": -3, "SAFETY": -2}, 40, {"months": snappedf(need / maxf(0.001, total), 0.1), "cases": _docket_cases(st),
			"court_budget": int(world.levers.get("LAW_COURT_BUDGET", 15000))})


static func _gap_ok(world: WorldState, st: Dictionary, key: String) -> bool:
	if world.month - int(st["last"].get(key, -999)) < FACT_GAP:
		return false
	st["last"][key] = world.month
	return true


static func _docket_cases(st: Dictionary) -> int:
	var n := 0
	for k in KINDS:
		for b in st["docket"][k]:
			n += int(b["n"])
	return n


static func _verdicts(world: WorldState, st: Dictionary, crime: Dictionary, rng: RandomNumberGenerator, k: String, d: String,
		n: int) -> void:
	st["month"]["heard"] += n
	var wl := int(crime.get("d", {}).get(d, {}).get("workload_pm", 1000))
	var evidence := clampf(1.15 - 0.3 * float(wl) / 1000.0, 0.7, 1.0)     # a swamped station builds weaker cases
	var conv := _draw(rng, float(n) * float(CONVICT_PM[k]) / 1000.0 * evidence)
	st["month"]["convicted"] += conv
	var terms := sentence_terms(world, k)
	var pool_d := float(int(st["pool"].get(d, 0))) / 1000.0
	var p_rep := minf(REPEAT_MAX, pool_d / (pool_d + REPEAT_HALF))
	for i in conv:
		if rng.randf() >= float(terms[0]):
			st["month"]["fines"] += 1
			continue
		var months := maxi(1, int(round(float(terms[1]) * rng.randf_range(0.5, 1.5))))
		if rng.randf() < p_rep:
			months *= REPEAT_MULT
		(st["prisoners"] as Array).append({"d": d, "kind": k, "n": 1, "since": world.month, "until": world.month + months})
		st["month"]["prison"] += 1


static func _time_limits(world: WorldState, st: Dictionary) -> void:
	var freed := 0
	for b in st["docket"]["VIOLENCE"]:
		if int(b["pre"]) > 0 and world.month - int(b["m"]) >= PRETRIAL_LIMIT:
			freed += int(b["pre"])
			st["pool"][String(b["d"])] = int(st["pool"].get(String(b["d"]), 0)) + 1000 * int(b["pre"])
			b["pre"] = 0
	if freed <= 0:
		return
	st["month"]["time_limit"] += freed
	LawOps.law_fact(world, "LAW_RELEASED_ON_TIME_LIMIT", "PUBLIC", [GOVERNMENT], [{"actor": GOVERNMENT, "share": 1.0}],
		{"SAFETY": -3, "GOVERNANCE": -2}, mini(60, 30 + 5 * freed), {"released": freed, "limit_months": PRETRIAL_LIMIT,
		"court_budget": int(world.levers.get("LAW_COURT_BUDGET", 15000))})


static func _release(world: WorldState, st: Dictionary) -> void:
	var keep: Array = []
	for p in st["prisoners"]:
		if world.month < int(p["until"]):
			keep.append(p)
			continue
		st["month"]["released"] += int(p["n"])
		if p.has("named"):
			_named_released(world, p)
		else:
			st["pool"][String(p["d"])] = int(st["pool"].get(String(p["d"]), 0)) + 1000 * int(p["n"])
	st["prisoners"] = keep


# =====================================================================================  places and overcrowding

static func _police_stations(world: WorldState) -> int:
	return maxi(1, (load("res://sim/law/police.gd")._stations(world) as Array).size())


static func _prison_places(world: WorldState) -> int:
	var n := 0
	for p in world.peek("prison").values():
		n += int(p.get("places", 0))
	return n


static func places(world: WorldState) -> Dictionary:
	var cells := CELLS_PER_STATION * _police_stations(world)
	var prison := _prison_places(world)
	return {"cells": cells, "prison": prison, "total": cells + prison}


static func occupancy(world: WorldState) -> Dictionary:
	var st := _peek(world)
	var sentenced := 0
	for p in st.get("prisoners", []):
		sentenced += int(p["n"])
	var pre := 0
	for b in st.get("docket", {}).get("VIOLENCE", []):
		pre += int(b["pre"])
	var political: int = (load("res://sim/law/police.gd").detained(world) as Dictionary).size()
	return {"sentenced": sentenced, "pretrial": pre, "political": political, "total": sentenced + pre + political}


static func _overcrowding(world: WorldState, st: Dictionary, rng: RandomNumberGenerator) -> void:
	var pl := places(world)
	var occ := occupancy(world)
	var total := int(occ["total"])
	if int(pl["prison"]) == 0 and total > 0:
		var oldest := world.month
		for p in st["prisoners"]:
			oldest = mini(oldest, int(p["since"]))
		if world.month - oldest >= HELD_TOO_LONG and _gap_ok(world, st, "cells"):
			LawOps.law_fact(world, "LAW_HELD_IN_CELLS", "PUBLIC", [GOVERNMENT], [{"actor": GOVERNMENT, "share": 1.0}],
				{"FAIRNESS": -3, "GOVERNANCE": -2}, 40, {"held": total, "cells": int(pl["cells"]), "months": world.month - oldest})
	var ratio := float(total) / float(maxi(1, int(pl["total"])))
	if ratio <= 1.0:
		return
	if rng.randf() < P_DISTURB_PER * (ratio - 1.0):
		LawOps.law_fact(world, "LAW_PRISON_DISTURBANCE", "PUBLIC", [GOVERNMENT], [{"actor": GOVERNMENT, "share": 1.0}],
			{"SAFETY": -3, "GOVERNANCE": -2}, 45, {"held": total, "places": int(pl["total"]), "in_cells": int(pl["prison"]) == 0,
			"regime": int(world.levers.get("LAW_PRISON_REGIME", 50))})
	if ratio > ESCAPE_FROM and rng.randf() < minf(P_ESCAPE_MAX, P_ESCAPE_PER * (ratio - ESCAPE_FROM)):
		var n := maxi(1, int(round(float(total - int(pl["total"])) * ESCAPE_SHARE)))
		var gone: Array = []
		var arr: Array = st["prisoners"]
		while n > 0 and not arr.is_empty():
			var p: Dictionary = arr.pop_at(rng.randi_range(0, arr.size() - 1))
			gone.append(p)
			n -= 1
		var names: Array = []
		var by_d := {}
		for p in gone:
			if p.has("named"):
				names.append(String(p["named"]["name"]))
				_named_released(world, p, true)
			else:
				st["pool"][String(p["d"])] = int(st["pool"].get(String(p["d"]), 0)) + 1000
			by_d[String(p["d"])] = int(by_d.get(String(p["d"]), 0)) + 1
		st["month"]["escaped"] += gone.size()
		if not gone.is_empty():
			LawOps.law_fact(world, "LAW_PRISON_ESCAPE", "PUBLIC", [GOVERNMENT], [{"actor": GOVERNMENT, "share": 1.0}],
				{"SAFETY": -5, "GOVERNANCE": -2}, mini(80, 45 + 5 * gone.size() + (20 if not names.is_empty() else 0)),
				{"escaped": gone.size(), "districts": by_d, "names": names, "in_cells": int(pl["prison"]) == 0,
				"regime": int(world.levers.get("LAW_PRISON_REGIME", 50))})


## crime.gd: extra expected offences (milli, a month) in a district from recent offenders who reoffend.
static func reoffending_milli(world: WorldState, district: String, kind: String) -> float:
	if not REOFFEND_SPLIT.has(kind):
		return 0.0
	var pool := float(int(_peek(world).get("pool", {}).get(district, 0)))      # milli-persons
	return pool * reoffend_rate(world) * OFFENCES_PER_REOFFENDER * float(REOFFEND_SPLIT[kind])


# =====================================================================================  named prisoners

## Months of prison for a convicted CEO or party leader (0 = a fine only), drawn at the white-collar row. 0 while off.
static func named_months(world: WorldState) -> int:
	if not on(world):
		return 0
	var rng := world.rng.stream("law.criminal.named")
	var terms := sentence_terms(world, NAMED_KIND)
	if rng.randf() >= float(terms[0]):
		return 0
	return maxi(1, int(round(float(terms[1]) * rng.randf_range(0.5, 1.5))))


## Imprison a named person for `months`. who: CEO | LEADER | PERSON. info: {name, org?, party?, person?, case?, district?}.
## LAW_IMPRISONED {who, name, org, party, person, months, until, case, disqualified} — Bob replaces a CEO, Wilma's
## party_life replaces a leader (must_step_down on LAW_LEADER_CONVICTED), a staff person is UNAVAILABLE.
static func imprison_named(world: WorldState, who: String, months: int, info: Dictionary) -> String:
	if months <= 0 or not on(world):
		return ""
	var st := state(world)
	var subj: Array = []
	if String(info.get("org", "")) != "":
		subj.append({"kind": "COMPANY", "id": String(info["org"])})
	if String(info.get("party", "")) != "":
		subj.append({"kind": "PARTY", "id": String(info["party"])})
	var person := String(info.get("person", ""))
	var data := {"who": who, "name": String(info.get("name", "")), "org": String(info.get("org", "")),
		"party": String(info.get("party", "")), "person": person, "months": months, "until": world.month + months,
		"case": String(info.get("case", "")), "disqualified": months >= DISQUALIFY_MONTHS}
	var fid := LawOps.law_fact(world, "LAW_IMPRISONED", "PUBLIC", subj, [], {"FAIRNESS": 2}, 60, data)
	if person != "" and world.table("person").has(person):
		var p: Dictionary = world.table("person")[person]
		p["status"] = "UNAVAILABLE"
		p["unavailable_until"] = maxi(int(p.get("unavailable_until", -1)), world.month + months)
	(st["prisoners"] as Array).append({"d": String(info.get("district", "d:1")), "kind": NAMED_KIND, "n": 1,
		"since": world.month, "until": world.month + months, "named": data.duplicate(), "fact": fid})
	return fid


static func _named_released(world: WorldState, p: Dictionary, escaped: bool = false) -> void:
	var nd: Dictionary = p["named"]
	var subj: Array = []
	if String(nd.get("org", "")) != "":
		subj.append({"kind": "COMPANY", "id": String(nd["org"])})
	if String(nd.get("party", "")) != "":
		subj.append({"kind": "PARTY", "id": String(nd["party"])})
	LawOps.law_fact(world, "LAW_RELEASED_FROM_PRISON", "PUBLIC", subj, [], {}, 40 if escaped else 30,
		{"who": nd["who"], "name": nd["name"], "org": nd.get("org", ""), "party": nd.get("party", ""), "person": nd.get("person", ""),
		"served": world.month - int(p["since"]), "escaped": escaped, "imprisoned": String(p.get("fact", ""))})


# =====================================================================================  readers

## UI, Terra, Wilma: {places {cells, prison, total}, occupancy {sentenced, pretrial, political, total}, docket (cases),
## backlog_pm (‰ of a month's court capacity), cp_share_pm (court capacity the docket used), pool (recent offenders,
## persons), named [{who, name, until}], month {charged, heard, convicted, prison, fines, released, time_limit, escaped}}.
static func stats(world: WorldState) -> Dictionary:
	var st := _peek(world)
	if st.is_empty():
		return {}
	var pool := 0
	for d in st.get("pool", {}):
		pool += int(st["pool"][d])
	var named: Array = []
	for p in st.get("prisoners", []):
		if p.has("named"):
			named.append({"who": p["named"]["who"], "name": p["named"]["name"], "until": int(p["until"])})
	return {"places": places(world), "occupancy": occupancy(world), "docket": _docket_cases(st),
		"backlog_pm": int(st.get("backlog_pm", 0)), "cp_share_pm": int(st.get("cp_share_pm", 0)), "pool": pool / 1000,
		"named": named, "month": st.get("month", {}).duplicate(), "totals": st.get("totals", {}).duplicate()}

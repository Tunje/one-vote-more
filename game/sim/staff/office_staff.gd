extends RefCounted
## O5 (planning/spec-office-v1.md): the player's staff as authors of office items, the chief of staff's sorting,
## the press secretary's digest, delegation by category, and hiring by interview. Owner: Anni.
## Wilma's Office (sim/office/office.gd) calls author_item(world, item) before storing each new item; the rest runs
## from the staff provider. Everything the UI must not see lives in item.hidden.
##
## Tables: office_role {role: {role, person, since, by AUTO|PLAYER}}, office_delegation {category: {category, role,
## since}}, interview {id: {...}}. Person traits added here (derived once, deterministically): lean {ECON_ROLE,
## REDISTRIBUTION, SOVEREIGNTY} milli, loyalty 0..100, temper 0..100; known {trait: [est, sd]} = what the player
## believes (from interviews), converging on the truth while the person works.

const Det := preload("res://sim/staff/det.gd")
const Ops := preload("res://sim/staff/staff_ops.gd")

const LEAN_AXES := ["ECON_ROLE", "REDISTRIBUTION", "SOVEREIGNTY"]

## Office roles: the skill mix that makes a good holder, and the lean axis their advice bends along.
const ROLES := {
	"CHIEF_OF_STAFF": {"w": {"ADMIN": 0.6, "POLI": 0.4}, "axis": "ECON_ROLE"},
	"FINANCE": {"w": {"ECON": 1.0}, "axis": "ECON_ROLE"},
	"LEGAL": {"w": {"LAW": 1.0}, "axis": "SOVEREIGNTY"},
	"PRESS": {"w": {"COMM": 1.0}, "axis": "REDISTRIBUTION"},
	"ENGINEER": {"w": {"ENG": 0.8, "LOGI": 0.2}, "axis": "ECON_ROLE"},
	"ECON_ADVISER": {"w": {"ECON": 0.7, "POLI": 0.3}, "axis": "ECON_ROLE"},
	"LABOUR_LIAISON": {"w": {"NEGO": 0.7, "PUBS": 0.3}, "axis": "REDISTRIBUTION"},
	"HOME_LIAISON": {"w": {"NEGO": 0.5, "POLI": 0.5}, "axis": "SOVEREIGNTY"},
	"HR": {"w": {"ADMIN": 1.0}, "axis": "ECON_ROLE"},
	"PARTY_WHIP": {"w": {"POLI": 1.0}, "axis": "REDISTRIBUTION"},
	"SERVICES": {"w": {"PUBS": 1.0}, "axis": "REDISTRIBUTION"},
	"ENVIRONMENT": {"w": {"ENV": 1.0}, "axis": "ECON_ROLE"},
}
const ROLE_ORDER := ["CHIEF_OF_STAFF", "FINANCE", "LEGAL", "PRESS", "ENGINEER", "ECON_ADVISER", "LABOUR_LIAISON",
	"HOME_LIAISON", "HR", "PARTY_WHIP", "SERVICES", "ENVIRONMENT"]

const BURY_P := 0.3                  # × (1 − chief skill)²
const BURY_FROM := 70                # only important items can be buried
const DIGEST_STORIES := 6
const KNOWN_CONVERGE := 0.15         # per month worked: est moves this share toward the truth …
const KNOWN_SD_DECAY := 0.9          # … and the uncertainty shrinks

## Interview questions: minutes (Wilma charges office hours), the traits they read with their noise sd, and whether
## a low-integrity candidate can bluff the answer.
const QUESTIONS := {
	"EXPERIENCE": {"minutes": 10, "traits": {"PRIMARY": 15, "SECONDARY": 20}, "bluff": 1.0},
	"TECHNICAL": {"minutes": 20, "traits": {"PRIMARY": 7, "SECONDARY": 12}, "bluff": 0.0},
	"POLITICAL": {"minutes": 10, "traits": {"LEAN": 15}, "bluff": 1.0},
	"WHY_LEFT": {"minutes": 10, "traits": {"INTEGRITY": 20, "LOYALTY": 20}, "bluff": 1.0},
	"STRESS": {"minutes": 15, "traits": {"TEMPER": 12, "RELIABILITY": 15}, "bluff": 0.5},
	"REFERENCES": {"minutes": 5, "traits": {"INTEGRITY": 8, "RELIABILITY": 10, "PRIMARY": 10}, "bluff": 0.0},
}
const QUESTION_ORDER := ["EXPERIENCE", "TECHNICAL", "POLITICAL", "WHY_LEFT", "STRESS", "REFERENCES"]


# ===================================================================================== person traits

## lean / loyalty / temper, derived once from the person's name and birth (no RNG stream is disturbed).
static func traits(p: Dictionary) -> Dictionary:
	if not p.has("loyalty"):
		var r := RandomNumberGenerator.new()
		r.seed = hash("%s|%d" % [String(p.get("name", "")), int(p.get("birth_month", 0))])
		var civil: bool = p.get("roles", []).has("CIVIL_SERVANT")
		var span := 40 if civil else 70
		var lean := {}
		for ax in LEAN_AXES:
			lean[ax] = r.randi_range(-span, span) * 1000
		p["lean"] = lean
		p["loyalty"] = r.randi_range(30, 95)
		p["temper"] = r.randi_range(20, 95)
	return {"lean": p["lean"], "loyalty": int(p["loyalty"]), "temper": int(p["temper"])}


static func role_skill(p: Dictionary, role: String) -> int:
	var w: Dictionary = ROLES[role]["w"]
	var s := 0.0
	for k in w:
		s += float(w[k]) * float(p["skills"].get(k, 0))
	return int(round(s))


# ===================================================================================== roles

## DECISIONS: fill empty or vacated roles from the government pool by best fit (one role per person).
static func fill_roles(world: WorldState) -> void:
	var t := world.table("office_role")
	var taken := {}
	for role in ROLE_ORDER:
		var r: Dictionary = t.get(role, {})
		var pid := String(r.get("person", ""))
		var p := Ops.person(world, pid)
		if pid != "" and (p.is_empty() or p["pool"] != "GOV" or not Ops.is_alive_active(p)):
			pid = ""
		if pid != "":
			taken[pid] = true
		t[role] = {"role": role, "person": pid, "since": int(r.get("since", world.month)), "by": String(r.get("by", "AUTO"))}
	for role in ROLE_ORDER:
		if String(t[role]["person"]) != "":
			continue
		var best := ""
		var best_s := -1
		for pid in Det.ordered(world.table("person")):
			var p: Dictionary = world.table("person")[pid]
			if p["pool"] != "GOV" or not Ops.is_alive_active(p) or taken.has(pid):
				continue
			var sc := role_skill(p, role)
			if sc > best_s:
				best_s = sc
				best = pid
		if best != "":
			taken[best] = true
			t[role] = {"role": role, "person": best, "since": world.month, "by": "AUTO"}


## The player puts someone in a role (the previous holder of that person's role is cleared).
static func assign_role(world: WorldState, role: String, pid: String) -> Dictionary:
	if not ROLES.has(role):
		return {"ok": false, "reason": "unknown role"}
	var p := Ops.person(world, pid)
	if p.is_empty() or p["pool"] != "GOV" or not Ops.is_alive_active(p):
		return {"ok": false, "reason": "not on the government staff"}
	var t := world.table("office_role")
	for r in t.values():
		if String(r["person"]) == pid:
			r["person"] = ""
	t[role] = {"role": role, "person": pid, "since": world.month, "by": "PLAYER"}
	return {"ok": true, "reason": ""}


static func holder(world: WorldState, role: String) -> Dictionary:
	return Ops.person(world, String(world.peek("office_role").get(role, {}).get("person", "")))


# ===================================================================================== authoring (called by Office.post)

## Mutates the item in place: author, recommendation, summary, chief-of-staff priority, delegation mark.
## item.hidden (from the system): {true_priority?, options: {option_id: {merit −100..100, lean {axis: milli}}},
## truth?}. Writes hidden.truth {best, omitted}, hidden.buried, hidden.delegate.
static func author_item(world: WorldState, item: Dictionary) -> void:
	var rng := world.rng.stream("staff.office")
	var hid: Dictionary = item["hidden"]
	var role := String(item.get("role", ""))
	var p: Dictionary = holder(world, role) if ROLES.has(role) else {}
	var lines: Array = item.get("summary_lines", [])
	if ROLES.has(role):
		if p.is_empty():
			item["from"] = {"kind": "STAFF_ROLE", "id": "", "role": role}
			item["recommendation"] = ""
			item["summary"] = String(lines[0]) if not lines.is_empty() else String(item["summary"])
			hid["unauthored"] = true
			hid["truth"] = {"best": _best(hid), "omitted": lines.slice(1)}
		else:
			var skill := role_skill(p, role)
			item["from"] = {"kind": "OFFICIAL", "id": String(p["id"]), "role": role, "name": String(p["name"])}
			var rec := _recommend(item, hid, traits(p)["lean"], skill, rng)
			if rec != "":
				item["recommendation"] = rec
			var omitted: Array = []
			if lines.size() > 1 and skill < 40 and rng.randf() < 0.5:
				omitted.append(lines[rng.randi_range(1, lines.size() - 1)])
			if not lines.is_empty():
				item["summary"] = " ".join(lines.filter(func(l): return not (l in omitted)))
			hid["summary_quality"] = skill
			hid["truth"] = {"best": _best(hid), "omitted": omitted}
			item["author_note"] = _note(hid, String(item["recommendation"]))
	# the chief of staff sorts the inbox; calls are never buried
	var truep := int(hid.get("true_priority", item["priority"]))
	hid["true_priority"] = truep
	if item["kind"] != "CALL":
		var chief := holder(world, "CHIEF_OF_STAFF")
		var cs := float(role_skill(chief, "CHIEF_OF_STAFF")) if not chief.is_empty() else 20.0
		var pr := float(truep) + rng.randfn(0.0, (100.0 - cs) / 4.0)
		if truep >= BURY_FROM and rng.randf() < BURY_P * pow(1.0 - cs / 100.0, 2.0):
			pr = float(rng.randi_range(10, 25))
			hid["buried"] = true
			hid["buried_by"] = String(chief.get("id", ""))
		item["priority"] = clampi(int(round(pr)), 0, 100)
	# delegation (never a CALL)
	var cat := String(item.get("category", ""))
	if cat != "" and item["kind"] == "EMAIL" and world.peek("office_delegation").has(cat) and not item["options"].is_empty():
		hid["delegate"] = String(world.peek("office_delegation")[cat]["role"])


static func _best(hid: Dictionary) -> String:
	var best := ""
	var bm := -1000000000
	for oid in Det.ordered(hid.get("options", {})):
		var m := int(hid["options"][oid].get("merit", 0))
		if m > bm:
			bm = m
			best = String(oid)
	return best


## The author's pick: merit weighed by skill, bent by their lean (less the more skilled), blurred by inexperience.
static func _recommend(item: Dictionary, hid: Dictionary, lean: Dictionary, skill: int, rng: RandomNumberGenerator) -> String:
	var opts: Dictionary = hid.get("options", {})
	if opts.is_empty():
		return ""
	var sk := float(skill) / 100.0
	var best := ""
	var bv := -INF
	for o in item["options"]:
		var oid := String(o.get("id", ""))
		if not opts.has(oid):
			continue
		var h: Dictionary = opts[oid]
		var al := 0.0
		for ax in LEAN_AXES:
			al += float(h.get("lean", {}).get(ax, 0)) * float(lean.get(ax, 0)) / 1.0e10
		var v := float(h.get("merit", 0)) * sk + clampf(al, -1.0, 1.0) * (1.0 - sk) * 40.0 + rng.randfn(0.0, 1.0) * (100.0 - float(skill)) / 3.0
		if v > bv:
			bv = v
			best = oid
	return best


static func _note(hid: Dictionary, rec: String) -> String:
	var opts: Dictionary = hid.get("options", {})
	if rec == "" or not opts.has(rec):
		return ""
	var m := int(opts[rec].get("merit", 0))
	var second := -1000000000
	for oid in opts:
		if String(oid) != rec:
			second = maxi(second, int(opts[oid].get("merit", 0)))
	if m - second >= 40:
		return "STRONGLY_RECOMMEND"
	return "ON_BALANCE" if m >= second else "CAREFUL"


# ===================================================================================== delegation

static func delegate(world: WorldState, category: String, role: String) -> Dictionary:
	if not ROLES.has(role) or category == "":
		return {"ok": false, "reason": "unknown role or category"}
	world.table("office_delegation")[category] = {"category": category, "role": role, "since": world.month}
	return {"ok": true, "reason": ""}


static func revoke(world: WorldState, category: String) -> void:
	world.table("office_delegation").erase(category)


## EVENTS: delegated emails are answered with their author's recommendation (or the default), as that person.
## Returns the items answered; a "done for you" REPORT lists them.
static func run_delegation(world: WorldState) -> Array:
	var done: Array = []
	var t := world.table("office_item")
	for id in Det.ordered(t):
		var o: Dictionary = t[id]
		if not (o["status"] in ["NEW", "READ"]) or String(o["hidden"].get("delegate", "")) == "":
			continue
		var cat := String(o.get("category", ""))
		if not world.peek("office_delegation").has(cat):
			o["hidden"].erase("delegate")      # revoked meanwhile: back to the player
			continue
		var p := holder(world, String(o["hidden"]["delegate"]))
		if p.is_empty():
			continue
		var opt := String(o["recommendation"]) if String(o["recommendation"]) != "" else String(o["default_option"])
		var r: Dictionary = Office.answer(world, id, opt, String(p["id"]))
		if r.get("ok", false):
			done.append({"item": id, "subject": o["subject"], "answer": opt, "by": String(p["id"])})
	if not done.is_empty():
		Office.post(world, {"kind": "REPORT", "subject": "Handled for you this month", "priority": 20,
			"summary": "%d delegated item(s) answered by your staff." % done.size(), "source": {"system": "office_staff", "ref": "delegated:%d" % world.month},
			"hidden": {"done": done}})
	return done


# ===================================================================================== press digest

## RECORD: the press secretary's digest of this month's editions (kind PAPER). A loyal secretary softens news that
## is bad for the government, a disloyal one leads with it; a weak one misses the top story.
static func press_digest(world: WorldState) -> String:
	var rng := world.rng.stream("staff.office")
	var p := holder(world, "PRESS")
	var skill := float(role_skill(p, "PRESS")) if not p.is_empty() else 0.0
	var loyalty := float(traits(p)["loyalty"]) if not p.is_empty() else 50.0
	var cands: Array = []
	for oid in Media.outlets(world):
		var ed := MediaQuery.edition(world, oid, world.month)
		for st in ed.get("stories", []):
			var f := world.facts.get_fact(String(st["fact"])) if String(st["fact"]) != "" else {}
			var mag := int(f.get("magnitude", 40))
			var bad: bool = float(st["gov_share"]) >= 0.3 and Media.valence(f) < 0 if not f.is_empty() else float(st["gov_share"]) >= 0.3
			var tilt := (50.0 - loyalty) / 50.0 if bad else 0.0
			cands.append({"outlet": oid, "outlet_name": String(ed["name"]), "report": String(st["report"]), "fact": String(st["fact"]),
				"type": String(f.get("type", "MEDIA_STORY")), "bad_for_government": bad,
				"w": float(mag) * (1.0 + tilt) + rng.randfn(0.0, 5.0), "slant_note": "SOFTENED" if tilt < -0.2 else ("PLAYED_UP" if tilt > 0.2 else "STRAIGHT")})
	if cands.is_empty():
		return ""
	cands.sort_custom(func(a, b): return a["w"] > b["w"] or (a["w"] == b["w"] and a["report"] < b["report"]))
	var missed := ""
	if skill < 40.0 and cands.size() > 1 and rng.randf() < 0.3:
		missed = cands[0]["report"]
		cands.remove_at(0)
	var digest: Array = []
	var seen_facts := {}
	for c in cands:
		if digest.size() >= DIGEST_STORIES:
			break
		if c["fact"] != "" and seen_facts.has(c["fact"]):
			continue
		seen_facts[c["fact"]] = true
		digest.append({"outlet": c["outlet"], "outlet_name": c["outlet_name"], "report": c["report"], "fact": c["fact"],
			"type": c["type"], "slant_note": c["slant_note"]})
	return Office.post(world, {"kind": "PAPER", "subject": "Press digest", "role": "PRESS", "priority": 60,
		"summary": "%d stories from the papers." % digest.size(), "source": {"system": "office_staff", "ref": "digest:%d" % world.month},
		"digest": digest, "hidden": {"missed": missed}})


# ===================================================================================== buried items, known traits

## EVENTS: a buried item that expired unanswered: OFFICE_ITEM_BURIED (OFFICIAL); the chief's record notes it.
static func check_buried(world: WorldState) -> void:
	for f in world.facts.query("OFFICE_ITEM_EXPIRED", world.month - 1, world.month):
		var o: Dictionary = world.peek("office_item").get(String(f["data"].get("item", "")), {})
		if o.is_empty() or not bool(o["hidden"].get("buried", false)) or bool(o["hidden"].get("buried_logged", false)):
			continue
		o["hidden"]["buried_logged"] = true
		var cid := String(o["hidden"].get("buried_by", ""))
		var chief := Ops.person(world, cid)
		if not chief.is_empty():
			chief["office_mistakes"] = int(chief.get("office_mistakes", 0)) + 1
		Ops.fact(world, "OFFICE_ITEM_BURIED", "OFFICIAL", [Ops.GOV], [{"actor": Ops.GOV, "share": 0.5},
			{"actor": Ops.official_ref(cid), "share": 0.5}] if cid != "" else [{"actor": Ops.GOV, "share": 1.0}], {}, 20,
			{"item": o["id"], "subject": o["subject"], "chief": cid})


## STAFF: what the player believes about each hired person converges on the truth while they work.
static func update_known(world: WorldState) -> void:
	for pid in Det.ordered(world.table("person")):
		var p: Dictionary = world.table("person")[pid]
		if not p.has("known") or p["pool"] != "GOV" or String(p.get("assignment_id", "")) == "":
			continue
		var tr := _true_traits(p)
		for k in p["known"]:
			if not tr.has(k):
				continue
			var e: Array = p["known"][k]
			var est := int(e[0])
			e[0] = est + int(round(float(int(tr[k]) - est) * KNOWN_CONVERGE))
			e[1] = maxi(1, int(float(e[1]) * KNOWN_SD_DECAY))


# ===================================================================================== interviews

## The true value of each interview trait for a candidate or person (lean on the role's axis, in milli).
static func _true_traits(p: Dictionary, axis: String = "ECON_ROLE") -> Dictionary:
	var tr := traits(p)
	var prim := String(p.get("specialization", ""))
	var top := ""
	var second := ""
	var sk: Dictionary = p["skills"]
	for s in Det.ordered(sk):
		if top == "" or int(sk[s]) > int(sk[top]):
			top = s
	for s in Det.ordered(sk):
		if s != top and (second == "" or int(sk[s]) > int(sk[second])):
			second = s
	return {"PRIMARY": int(sk[top]), "SECONDARY": int(sk[second]), "INTEGRITY": int(p["integrity"]),
		"RELIABILITY": int(p["reliability"]), "LOYALTY": int(tr["loyalty"]), "TEMPER": int(tr["temper"]),
		"LEAN": int(tr["lean"].get(axis, 0))}


## The door: open an interview with shortlist candidate idx of a recruitment (one at a time). -> interview id or "".
static func start_interview(world: WorldState, rid: String, idx: int) -> String:
	var rec: Dictionary = world.table("recruitment").get(rid, {})
	if rec.is_empty() or rec["status"] != "OPEN" or int(rec["picked"]) >= 0 or idx < 0 or idx >= rec["shortlist"].size():
		return ""
	var id := world.new_id("interview")
	world.table("interview")[id] = {"id": id, "recruitment": rid, "idx": idx, "month": world.month, "minutes_used": 0,
		"asked": [], "reference": {"status": "NONE", "due_month": -1, "signals": []}, "hr_note": {}}
	return id


## Ask one question. -> {ok, minutes, answer: {q, text_key, signals: [{trait, est, sd}]}}. Each question once.
static func ask(world: WorldState, iid: String, q: String) -> Dictionary:
	var iv: Dictionary = world.table("interview").get(iid, {})
	if iv.is_empty() or not QUESTIONS.has(q):
		return {"ok": false, "reason": "no such interview or question"}
	for a in iv["asked"]:
		if a["q"] == q:
			return {"ok": false, "reason": "already asked"}
	var cand: Dictionary = world.table("recruitment")[iv["recruitment"]]["shortlist"][int(iv["idx"])]
	var rng := world.rng.stream("staff.interview")
	var qd: Dictionary = QUESTIONS[q]
	iv["minutes_used"] = int(iv["minutes_used"]) + int(qd["minutes"])
	if q == "REFERENCES":
		iv["reference"] = {"status": "PENDING", "due_month": world.month + 1, "signals": []}
		var ans0 := {"q": q, "text_key": "REFERENCES_REQUESTED", "signals": []}
		iv["asked"].append(ans0)
		return {"ok": true, "minutes": qd["minutes"], "answer": ans0}
	var sig := _signals(cand, qd, rng)
	var ans := {"q": q, "text_key": _text_key(q, sig), "signals": sig}
	iv["asked"].append(ans)
	_hr_note(world, iv)
	return {"ok": true, "minutes": qd["minutes"], "answer": ans}


static func _signals(cand: Dictionary, qd: Dictionary, rng: RandomNumberGenerator) -> Array:
	var tr := _true_traits(cand)
	var integ := int(cand["integrity"])
	var out: Array = []
	for tk in Det.ordered(qd["traits"]):
		var sd := float(qd["traits"][tk])
		var scale := 1000.0 if tk == "LEAN" else 1.0
		var est := float(tr[tk]) + rng.randfn(0.0, sd) * scale
		var shown_sd := sd
		if integ < 40 and float(qd["bluff"]) > 0.0 and tk != "LEAN":
			est += float(40 - integ) / 2.0 * float(qd["bluff"])          # the flattering answer …
			shown_sd = sd * 0.6                                             # … delivered with confidence
		if tk == "LEAN" and integ < 40:
			est *= 0.5                                                      # dodges toward the middle
		out.append({"trait": tk, "est": int(round(est)) if tk == "LEAN" else clampi(int(round(est)), 0, 100), "sd": int(round(shown_sd))})
	return out


static func _text_key(q: String, sig: Array) -> String:
	if sig.is_empty():
		return q
	var s: Dictionary = sig[0]
	if s["trait"] == "LEAN":
		return "POLITICAL_DODGE" if absi(int(s["est"])) < 15000 else ("POLITICAL_MARKET" if int(s["est"]) < 0 else "POLITICAL_STATE")
	var v := int(s["est"])
	return q + ("_STRONG" if v >= 70 else ("_SOLID" if v >= 50 else ("_VAGUE" if v >= 35 else "_WEAK")))


## The HR adviser's combined estimate per trait (inverse-variance mean), blurred by HR's own weakness.
static func _hr_note(world: WorldState, iv: Dictionary) -> void:
	var hr := holder(world, "HR")
	var hs := float(role_skill(hr, "HR")) if not hr.is_empty() else 20.0
	var rng := world.rng.stream("staff.interview")
	var acc := {}
	var sigs: Array = []
	for a in iv["asked"]:
		sigs.append_array(a["signals"])
	sigs.append_array(iv["reference"]["signals"])
	for s in sigs:
		var w := 1.0 / maxf(1.0, float(s["sd"]) * float(s["sd"]))
		var a: Array = acc.get(s["trait"], [0.0, 0.0])
		acc[s["trait"]] = [a[0] + w * float(s["est"]), a[1] + w]
	var note := {}
	for k in Det.ordered(acc):
		var scale := 1000.0 if k == "LEAN" else 1.0
		var est: float = float(acc[k][0]) / float(acc[k][1]) + rng.randfn(0.0, (100.0 - hs) / 5.0) * scale
		note[k] = [int(round(est)), int(round(sqrt(1.0 / float(acc[k][1])) + (100.0 - hs) / 5.0))]
	iv["hr_note"] = note


## DECISIONS: reference checks come back after a month (reliable, no bluffing).
static func resolve_references(world: WorldState) -> void:
	var rng := world.rng.stream("staff.interview")
	for iid in Det.ordered(world.table("interview")):
		var iv: Dictionary = world.table("interview")[iid]
		if iv["reference"]["status"] != "PENDING" or world.month < int(iv["reference"]["due_month"]):
			continue
		var rec: Dictionary = world.table("recruitment").get(iv["recruitment"], {})
		if rec.is_empty():
			continue
		var cand: Dictionary = rec["shortlist"][int(iv["idx"])]
		iv["reference"] = {"status": "DONE", "due_month": iv["reference"]["due_month"],
			"signals": _signals(cand, QUESTIONS["REFERENCES"], rng)}
		_hr_note(world, iv)


## Hire on impressions: picks the candidate (normal hire lag) and stores the HR note as what the player knows.
static func hire_from_interview(world: WorldState, iid: String) -> Dictionary:
	var iv: Dictionary = world.table("interview").get(iid, {})
	if iv.is_empty():
		return {"ok": false, "reason": "no such interview"}
	var r := Ops.pick_candidate(world, String(iv["recruitment"]), int(iv["idx"]))
	if r.get("ok", false):
		var cand: Dictionary = world.table("recruitment")[iv["recruitment"]]["shortlist"][int(iv["idx"])]
		cand["known"] = iv["hr_note"].duplicate(true)
	return r

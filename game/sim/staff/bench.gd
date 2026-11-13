extends RefCounted
## The party bench (planning/spec-bench-v1.md A51 B1–B2). Owner: Anni. Preload it (no class_name).
##
## B1 RECRUITING. A party recruitment drive (party money + the party secretary's time) opens a "recruitment" row of
## kind PARTY with a shortlist of prospects. Each prospect has a SOURCE (UNION, COMPANY, CIVIL_SERVICE, NOTABLE,
## PRESS) that sets their skills, their ties {kind, id} and pulls their lean. The player's party interviews them with
## the O5 engine (OfficeStaff.start_interview / ask / hire_from_interview → Bench.pick); AI parties pick by merit
## and fit. Soft cap: BENCH_BASE + ceil(seats/10) (the election trim, StaffOps.on_election); every place over it
## makes a drive dearer.
##
## B2 AMBITIONS. Every party member (bench, Cabinet, party staff) has: ambition OFFICE|LEADERSHIP|CAUSE|QUIET
## (+ cause), loyalty 0..100 (to the leader; the O5 trait), line_fit 0..100 (lean vs the party's positions, monthly),
## grievance 0..100 (decays) and grievances [{month, kind, ref}] (the last 5, the causes in the record). Events are
## read from the record each month (EVENTS phase): PASSED_OVER, SACKED, PROMOTED, PARTY_DEFEAT, SCANDAL, LINE_SHIFT.
## Actions: CHALLENGE (Ella reads challengers() and reports contest_result()), DEFECT (LAW_PERSONAL_MANDATE decides
## whether an Assembly seat goes with the person), LEAK (a party or government secret, through the reveal path),
## RETIRE (a quiet life, burnout). The player's party secretary emails about restless members (Office, category
## PARTY): promise a post, give a portfolio (governing only), ignore.

const Det := preload("res://sim/staff/det.gd")
const Ops := preload("res://sim/staff/staff_ops.gd")
const D := preload("res://sim/staff/staff_data.gd")
const RG := preload("res://sim/staff/roster_gen.gd")
const OFS := preload("res://sim/staff/office_staff.gd")

const SOURCES := ["UNION", "COMPANY", "CIVIL_SERVICE", "NOTABLE", "PRESS"]
## Skill profile by source (staff_data ARCHETYPES) and the lean (points) the source pulls toward.
const SOURCE_ARCH := {"UNION": "NEGOTIATOR", "COMPANY": "ECONOMIST", "CIVIL_SERVICE": "JURIST", "NOTABLE": "STRATEGIST",
	"PRESS": "COMMUNICATOR"}
const SOURCE_LEAN := {"UNION": {"ECON_ROLE": 40, "REDISTRIBUTION": 50, "SOVEREIGNTY": 0},
	"COMPANY": {"ECON_ROLE": -50, "REDISTRIBUTION": -40, "SOVEREIGNTY": 0},
	"CIVIL_SERVICE": {"ECON_ROLE": 0, "REDISTRIBUTION": 0, "SOVEREIGNTY": -10},
	"NOTABLE": {}, "PRESS": {"ECON_ROLE": 0, "REDISTRIBUTION": 0, "SOVEREIGNTY": 10}}
const LEAN_PARTY_W := 0.4            # prospect lean: party line, source, own (the rest)
const LEAN_SOURCE_W := 0.4
const SHORTLIST := 4
const DRIVE_COST_WREF := 1.0
const DRIVE_OVER_CAP := 0.5          # +50% per place over the soft cap
const DRIVE_MINUTES := 120           # the party secretary's time (Wilma's office hours)
const DRIVE_MONTHS := 3              # a drive's shortlist stays open this long
const AI_DRIVE_P := 0.04             # an AI party under its cap with the money starts a drive this often a month

const AMBITIONS := ["OFFICE", "LEADERSHIP", "CAUSE", "QUIET"]
const GRIEVANCE_DECAY := 1
const LOYALTY_RECOVER_EVERY := 4      # months: loyalty drifts 1 back toward the person's own baseline
const KEEP_GRIEVANCES := 5
const EVENT := {"PASSED_OVER": [20, 0], "SACKED": [30, -10], "PROMOTED": [-30, 5], "PARTY_DEFEAT": [5, -8],
	"PARTY_DEFEAT_AMBITIOUS": [15, 0], "SCANDAL": [5, -8], "LINE_SHIFT": [15, 0], "IGNORED": [10, -3],
	"BROKEN_PROMISE": [25, -10], "CONTEST_LOST": [20, -15]}     # [grievance, loyalty]
const PASSED_OVER_MARGIN := 5        # skill points the passed-over member must beat the appointee by
const LINE_FIT_LOW := 40
const CHALLENGE := {"loyalty_below": 50, "grievance_from": 30, "poli_from": 55}
const SINKING := {"seat_loss": 0.34, "months": 24, "loyalty_below": 60, "fit_gain": 5, "grievance_from": 10, "p": 0.015}
const INDEPENDENT_LOYALTY_BELOW := 20    # a seated member with no better party sits as an independent (free mandate)
const DEFECT := {"loyalty_below": 40, "fit_below": 55, "fit_gain": 10, "p": 0.03}
const LEAK := {"grievance_from": 30, "integrity_below": 45, "p": 0.03, "named_p": 0.5}
const QUIET_RETIRE := {"age_from": 55, "p": 0.02}
const BURNOUT := {"grievance_from": 80, "months": 12}
const MAIL := {"grievance_from": 35, "cooldown": 12, "deadline": 2, "promise_months": 12}


# ===================================================================================== B1: recruiting

static func _wref(world: WorldState) -> int:
	return maxi(1, int(world.values.get("ECON_W_REF", 1200000)))


static func bench_of(world: WorldState, party: String) -> Array:
	var out: Array = []
	for pid in Det.ordered(world.table("person")):
		var p: Dictionary = world.table("person")[pid]
		if p["status"] == "ACTIVE" and p["pool"] == "" and String(p.get("bench_party_id", "")) == party:
			out.append(String(pid))
	return out


static func soft_cap(world: WorldState, party: String) -> int:
	return D.BENCH_BASE + int(ceil(float(world.peek("party").get(party, {}).get("seats", 0)) / 10.0))


static func drive_cost(world: WorldState, party: String) -> int:
	var over := maxi(0, bench_of(world, party).size() + 1 - soft_cap(world, party))
	return int(round(DRIVE_COST_WREF * float(_wref(world)) * (1.0 + DRIVE_OVER_CAP * float(over))))


## Source weights for this party: its line and what exists in the colony (no federation, no union people).
static func source_weights(world: WorldState, party: String) -> Dictionary:
	var pos: Dictionary = world.peek("party").get(party, {}).get("positions", {})
	var red := float(pos.get("REDISTRIBUTION", 0)) / 1000.0
	var eco := float(pos.get("ECON_ROLE", 0)) / 1000.0
	var w := {"CIVIL_SERVICE": 1.0, "NOTABLE": 1.2, "PRESS": 0.5 if world.peek("outlet").size() > 1 else 0.3}
	w["UNION"] = (1.0 + maxf(0.0, red) / 25.0) if not Unions.federation(world).is_empty() else 0.0
	w["COMPANY"] = (1.0 + maxf(0.0, -eco) / 25.0) if not _companies(world).is_empty() else 0.0
	return w


static func _companies(world: WorldState) -> Array:
	var out: Array = []
	for oid in Det.ordered(world.peek("org")):
		var o: Dictionary = world.peek("org")[oid]
		if String(o.get("status", "ACTIVE")) == "ACTIVE" and not String(o.get("type", "")).begins_with("PUBLIC"):
			out.append(String(oid))
	return out


static func _pick_w(rng: RandomNumberGenerator, w: Dictionary) -> String:
	var tot := 0.0
	for k in SOURCES:
		tot += float(w.get(k, 0.0))
	var x := rng.randf() * tot
	for k in SOURCES:
		x -= float(w.get(k, 0.0))
		if x <= 0.0 and float(w.get(k, 0.0)) > 0.0:
			return k
	return "CIVIL_SERVICE"


## One prospect: a bench archetype shaped by its source, its ties and a lean pulled toward the party and the source.
static func make_prospect(world: WorldState, party: String, source: String, rng: RandomNumberGenerator) -> Dictionary:
	var p := RG.make_archetype(rng, String(SOURCE_ARCH[source]), world.month, String(world.peek("party").get(party, {}).get("flavour_skill", "")))
	var ties := {}
	var src_lean: Dictionary = SOURCE_LEAN[source]
	match source:
		"UNION":
			ties = {"kind": "UNION", "id": String(Unions.federation(world).get("id", ""))}
		"COMPANY":
			var cs := _companies(world)
			ties = {"kind": "COMPANY", "id": String(cs[rng.randi_range(0, cs.size() - 1)])} if not cs.is_empty() else {}
		"PRESS":
			var os: Array = Det.ordered(world.peek("outlet"))
			ties = {"kind": "OUTLET", "id": String(os[rng.randi_range(0, os.size() - 1)])} if not os.is_empty() else {}
		"CIVIL_SERVICE":
			ties = {"kind": "GOVERNMENT", "id": "government"}
		"NOTABLE":
			var d := _district_mean(world, rng)
			ties = {"kind": "DISTRICT", "id": String(d["district"])}
			src_lean = d["lean"]
	OFS.traits(p)                       # loyalty, temper and a personal lean (deterministic) …
	var own: Dictionary = p["lean"]
	var line: Dictionary = world.peek("party").get(party, {}).get("positions", {})
	var lean := {}
	for ax in OFS.LEAN_AXES:            # … pulled toward the party and the source
		lean[ax] = clampi(int(round(LEAN_PARTY_W * float(line.get(ax, 0)) + LEAN_SOURCE_W * float(src_lean.get(ax, 0)) * 1000.0
			+ (1.0 - LEAN_PARTY_W - LEAN_SOURCE_W) * float(own.get(ax, 0)))), -100000, 100000)
	p["lean"] = lean
	p["lean_party"] = party
	p["source"] = source
	p["ties"] = ties
	p["party_id"] = party
	_init_ambition(world, p)
	return p


## A district and its voters' mean lean (points) for a local notable.
static func _district_mean(world: WorldState, rng: RandomNumberGenerator) -> Dictionary:
	var by := {}
	for c in PolVoters.all(world):
		var d := String(c.get("district", ""))
		if d == "" or int(c.get("pop", 0)) <= 0:
			continue
		if not by.has(d):
			by[d] = {"pop": 0.0, "sum": {}}
		var pop := float(c["pop"])
		by[d]["pop"] = float(by[d]["pop"]) + pop
		for ax in OFS.LEAN_AXES:
			by[d]["sum"][ax] = float(by[d]["sum"].get(ax, 0.0)) + pop * float(c.get("ideology", {}).get(ax, 0)) / 1000.0
	if by.is_empty():
		return {"district": "", "lean": {}}
	var ds: Array = Det.ordered(by)
	var d: String = ds[rng.randi_range(0, ds.size() - 1)]
	var lean := {}
	for ax in OFS.LEAN_AXES:
		lean[ax] = int(round(float(by[d]["sum"].get(ax, 0.0)) / maxf(1.0, float(by[d]["pop"]))))
	return {"district": d, "lean": lean}


## Start a drive: pays from party:<id> (to households, closed ledger) and opens a PARTY recruitment row.
## -> {ok, reason, rid, cost, minutes}
static func start_drive(world: WorldState, party: String, size: int = SHORTLIST) -> Dictionary:
	if not Ops.party_active(world, party) or not world.peek("party").has(party):
		return {"ok": false, "reason": "no such party", "rid": "", "cost": 0, "minutes": 0}
	var cost := drive_cost(world, party)
	var acc := "party:" + party
	if not world.ledger.has_account(acc) or world.ledger.balance(acc) < cost:
		return {"ok": false, "reason": "the party cannot afford a drive", "rid": "", "cost": cost, "minutes": 0}
	PartyLife._household_receive(world, acc, cost, "PARTY_RECRUITMENT")
	var rng := world.rng.stream("staff.bench")
	var w := source_weights(world, party)
	var list: Array = []
	for i in size:
		list.append(make_prospect(world, party, _pick_w(rng, w), rng))
	var id := world.new_id("recruit")
	world.table("recruitment")[id] = {"id": id, "kind": "PARTY", "party": party, "spec": "BENCH", "opened_month": world.month,
		"expires": world.month + DRIVE_MONTHS, "shortlist": list, "picked": -1, "hire_month": -1, "status": "OPEN", "cost": cost}
	return {"ok": true, "reason": "", "rid": id, "cost": cost, "minutes": DRIVE_MINUTES}


## Take prospect idx onto the party's bench now (the player after interviews, or the AI). One pick per drive.
static func pick(world: WorldState, rid: String, idx: int) -> Dictionary:
	var rec: Dictionary = world.table("recruitment").get(rid, {})
	if rec.is_empty() or String(rec.get("kind", "")) != "PARTY" or rec["status"] != "OPEN" or idx < 0 or idx >= rec["shortlist"].size():
		return {"ok": false, "reason": "invalid pick"}
	var party := String(rec["party"])
	var np: Dictionary = rec["shortlist"][idx].duplicate(true)
	np["party_id"] = party
	var pid := Ops.add_person(world, np, "", party)
	rec["picked"] = idx
	rec["status"] = "FILLED"
	rec["person_id"] = pid
	var pref := {"kind": "PARTY", "id": party}
	world.add_fact({"type": "STAFF_BENCH_RECRUITED", "owner": "staff", "subjects": [Ops.official_ref(pid), pref], "responsible": [],
		"impact": {}, "magnitude": 25, "visibility": "PUBLIC",
		"data": {"party": party, "person": pid, "name": String(np["name"]), "source": String(np.get("source", "")), "ties": np.get("ties", {}).duplicate()}})
	return {"ok": true, "reason": "", "person": pid}


static func ties(world: WorldState, pid: String) -> Dictionary:
	return Ops.person(world, pid).get("ties", {})


## Line fit 0..100 of a lean (milli) with a party's positions.
static func fit(lean: Dictionary, positions: Dictionary) -> int:
	var d := 0.0
	for ax in OFS.LEAN_AXES:
		d += absf(float(lean.get(ax, 0)) - float(positions.get(ax, 0))) / 1000.0
	return clampi(int(round(100.0 - 0.7 * d / float(OFS.LEAN_AXES.size()))), 0, 100)


static func _merit(world: WorldState, p: Dictionary, party: String) -> float:
	var top := 0
	for s in p["skills"]:
		top = maxi(top, int(p["skills"][s]))
	return float(top + int(p.get("work_speed", 50)) / 4) * (0.5 + float(fit(p.get("lean", {}), world.peek("party").get(party, {}).get("positions", {}))) / 200.0)


## DECISIONS: AI parties (and an autoplayed player party) recruit when under the soft cap and able to pay, and pick
## the best prospect by merit × fit at once. Open drives close at their expiry.
static func ai_recruit(world: WorldState) -> void:
	var recs := world.table("recruitment")
	for rid in Det.ordered(recs):
		var r: Dictionary = recs[rid]
		if String(r.get("kind", "")) == "PARTY" and r["status"] == "OPEN" and world.month >= int(r["expires"]):
			r["status"] = "EXPIRED"
	var rng := world.rng.stream("staff.bench.ai")
	for party in Det.ordered(world.peek("party")):
		if not Ops.party_active(world, party) or not Ops.autopilot(world, {"kind": "PARTY", "id": party}):
			continue
		if bench_of(world, party).size() >= soft_cap(world, party):
			continue
		var acc := "party:" + String(party)
		if not world.ledger.has_account(acc) or world.ledger.balance(acc) < 3 * drive_cost(world, party) or rng.randf() >= AI_DRIVE_P:
			continue
		var d := start_drive(world, party)
		if not d["ok"]:
			continue
		var list: Array = recs[d["rid"]]["shortlist"]
		var best := 0
		for i in list.size():
			if _merit(world, list[i], party) > _merit(world, list[best], party):
				best = i
		pick(world, d["rid"], best)


# ===================================================================================== bench strength (B3 links)

const LIST_TOP := 5          # list_strength weighs the top names of the list


## How strong a party's public faces are, 0..100 (for a small candidate-quality term in polling). The top LIST_TOP
## of its list (list_rank 1.., else by standing), weighted 5..1: charisma-like skill (COMM, POLI), integrity, minus
## scandals and defections. A thin bench (fewer than LIST_TOP names) scores the missing places at 20.
static func list_strength(world: WorldState, party: String) -> int:
	var ms := members(world, party)
	ms.sort_custom(func(x, y):
		var rx := int(Ops.person(world, x).get("list_rank", 9999))
		var ry := int(Ops.person(world, y).get("list_rank", 9999))
		if rx != ry:
			return rx < ry
		return _face(Ops.person(world, x)) > _face(Ops.person(world, y)))
	var num := 0.0
	var den := 0.0
	for i in LIST_TOP:
		var wt := float(LIST_TOP - i)
		num += wt * (float(_face(Ops.person(world, ms[i]))) if i < ms.size() else 20.0)
		den += wt
	return clampi(int(round(num / den)), 0, 100)


static func _face(p: Dictionary) -> int:
	var sk: Dictionary = p.get("skills", {})
	var v := 0.4 * float(sk.get("COMM", 0)) + 0.3 * float(sk.get("POLI", 0)) + 0.3 * float(p.get("integrity", 50))
	return clampi(int(round(v)) - 10 * int(p.get("scandals", 0)) - 5 * int(p.get("defected", 0)), 0, 100)


## A party's best analyst, 0..100: the highest 0.6 ECON + 0.4 POLI among its members (for Intel.quality: a party
## with a strong researcher reads the colony better). 0 for a party with nobody.
static func research_skill(world: WorldState, party: String) -> int:
	var best := 0
	for pid in members(world, party):
		var sk: Dictionary = Ops.person(world, pid).get("skills", {})
		best = maxi(best, int(round(0.6 * float(sk.get("ECON", 0)) + 0.4 * float(sk.get("POLI", 0)))))
	return best


# ===================================================================================== B2: ambitions

## Ambition and cause, derived once from the person (no RNG stream disturbed): the young want office, the old peace.
static func _init_ambition(world: WorldState, p: Dictionary) -> void:
	if p.has("ambition"):
		return
	var r := RandomNumberGenerator.new()
	r.seed = hash("amb|%s|%d" % [String(p.get("name", "")), int(p.get("birth_month", 0))])
	var age := Ops.age_years(world, p)
	var w: Array = [40, 25, 25, 10] if age < 40 else ([35, 20, 30, 15] if age < 55 else [25, 10, 30, 35])
	var x := r.randi_range(1, 100)
	var i := 0
	while i < 3 and x > int(w[i]):
		x -= int(w[i])
		i += 1
	p["ambition"] = AMBITIONS[i]
	p["cause"] = PolDefs.CONCERNS[r.randi_range(0, PolDefs.CONCERNS.size() - 1)] if p["ambition"] == "CAUSE" else ""
	OFS.traits(p)
	p["loyalty0"] = int(p["loyalty"])
	p["grievance"] = int(p.get("grievance", 0))
	p["grievances"] = p.get("grievances", [])


## Party members: active people with a party (bench, Cabinet, party staff).
static func members(world: WorldState, party: String = "") -> Array:
	var out: Array = []
	for pid in Det.ordered(world.table("person")):
		var p: Dictionary = world.table("person")[pid]
		var pty := String(p.get("party_id", ""))
		if pty == "" or not Ops.is_alive_active(p) or not Ops.party_active(world, pty) or (party != "" and pty != party):
			continue
		if p["roles"].has("CIVIL_SERVANT"):
			continue
		out.append(String(pid))
	return out


static func is_leader(world: WorldState, pid: String) -> bool:
	var p := Ops.person(world, pid)
	var l = world.peek("party").get(String(p.get("party_id", "")), {}).get("leader", {})
	return typeof(l) == TYPE_DICTIONARY and String(l.get("person", "")) == pid


static func grieve(world: WorldState, p: Dictionary, kind: String, ref: String = "") -> void:
	var e: Array = EVENT[kind]
	p["grievance"] = clampi(int(p.get("grievance", 0)) + int(e[0]), 0, 100)
	OFS.traits(p)
	p["loyalty"] = clampi(int(p["loyalty"]) + int(e[1]), 0, 100)
	if int(e[0]) > 0:
		var g: Array = p.get("grievances", [])
		g.append({"month": world.month, "kind": kind, "ref": ref})
		while g.size() > KEEP_GRIEVANCES:
			g.pop_front()
		p["grievances"] = g


static func _portfolios(world: WorldState) -> Dictionary:
	var out := {}
	var t := world.peek("office_role")
	for role in OFS.PORTFOLIOS:
		var pid := String(t.get(role, {}).get("person", ""))
		if pid != "" and OFS._is_minister(Ops.person(world, pid)):
			out[pid] = role
	return out


## EVENTS: read this month's record into grievances and loyalty, then let people act.
static func monthly(world: WorldState) -> void:
	var st := world.table("bench_state")
	_rehome_orphans(world)
	_count_scandals(world)
	var ms := members(world)
	for pid in ms:
		_init_ambition(world, Ops.person(world, pid))
	_events(world, st, ms)
	_mail_answers(world)
	var rng := world.rng.stream("staff.bench")
	for pid in ms:
		var p := Ops.person(world, pid)
		if not Ops.is_alive_active(p):
			continue
		p["grievance"] = maxi(0, int(p["grievance"]) - GRIEVANCE_DECAY)
		if world.month % LOYALTY_RECOVER_EVERY == 0 and int(p["grievance"]) < 10:
			var l0 := int(p.get("loyalty0", p["loyalty"]))
			p["loyalty"] = int(p["loyalty"]) + signi(l0 - int(p["loyalty"]))
		_act(world, pid, p, rng)


static func _events(world: WorldState, st: Dictionary, ms: Array) -> void:
	var now := _portfolios(world)
	var prev: Dictionary = st.get("portfolios", {})
	var parties := world.peek("party")
	# portfolios: promoted, sacked, passed over
	for pid in Det.ordered(now):
		if String(prev.get(pid, "")) == "":
			var p := Ops.person(world, pid)
			grieve(world, p, "PROMOTED", String(now[pid]))
			for mid in ms:
				var m := Ops.person(world, mid)
				if mid == pid or now.has(mid) or String(m["party_id"]) != String(p["party_id"]) or String(m.get("ambition", "")) != "OFFICE":
					continue
				if OFS.role_skill(m, String(now[pid])) > OFS.role_skill(p, String(now[pid])) + PASSED_OVER_MARGIN:
					grieve(world, m, "PASSED_OVER", String(now[pid]))
	for pid in Det.ordered(prev):
		var p := Ops.person(world, pid)
		if not now.has(pid) and not p.is_empty() and Ops.is_alive_active(p) and String(p.get("party_id", "")) != "":
			grieve(world, p, "SACKED", String(prev[pid]))
			if String(p.get("ambition", "")) == "OFFICE" and int(p["skills"].get("POLI", 0)) >= 50:
				p["ambition"] = "LEADERSHIP"
	st["portfolios"] = now
	# elections: a party that lost seats
	for f in Det.recent_facts(world, "POL_ELECTION_HELD", world.month):
		var els: Array = world.peek("pol").get("state", {}).get("elections", [])
		var i := els.find(String(f["data"].get("election", "")))
		if i <= 0:
			continue
		var now_s: Dictionary = world.peek("election").get(els[i], {}).get("seats", {})
		var was_s: Dictionary = world.peek("election").get(els[i - 1], {}).get("seats", {})
		for pty in Det.ordered(was_s):
			if int(was_s[pty]) > 0 and float(int(was_s[pty]) - int(now_s.get(pty, 0))) / float(was_s[pty]) >= SINKING["seat_loss"]:
				st.get_or_add("sinking", {})[pty] = world.month
		for mid in ms:
			var m := Ops.person(world, mid)
			var pty := String(m["party_id"])
			if int(now_s.get(pty, 0)) < int(was_s.get(pty, 0)):
				grieve(world, m, "PARTY_DEFEAT", pty)
				if String(m.get("ambition", "")) == "LEADERSHIP":
					grieve(world, m, "PARTY_DEFEAT_AMBITIOUS", pty)
	# scandals of their own party
	for f in Det.recent_facts(world, "POL_SCANDAL_REVEALED", world.month):
		for s in f.get("subjects", []):
			if typeof(s) == TYPE_DICTIONARY and String(s.get("kind", "")) == "PARTY":
				for mid in ms:
					if String(Ops.person(world, mid)["party_id"]) == String(s.get("id", "")):
						grieve(world, Ops.person(world, mid), "SCANDAL", String(f["id"]))
	# the line moving away from them
	for mid in ms:
		var m := Ops.person(world, mid)
		var lf := fit(m.get("lean", {}), parties.get(String(m["party_id"]), {}).get("positions", {}))
		if int(m.get("line_fit", 100)) >= LINE_FIT_LOW and lf < LINE_FIT_LOW and m.has("line_fit"):
			grieve(world, m, "LINE_SHIFT", String(m["party_id"]))
		m["line_fit"] = lf
		if String(m.get("ambition", "")) == "OFFICE" and Ops.age_years(world, m) >= 60 and not now.has(mid):
			m["ambition"] = "QUIET"
		if m.has("promised") and world.month - int(m["promised"]) >= MAIL["promise_months"]:
			m.erase("promised")
			if not now.has(mid):
				grieve(world, m, "BROKEN_PROMISE")


static func _act(world: WorldState, pid: String, p: Dictionary, rng: RandomNumberGenerator) -> void:
	var leader := is_leader(world, pid)
	var g := int(p["grievance"])
	# burnout clock
	if g >= BURNOUT["grievance_from"]:
		if not p.has("burnout_since"):
			p["burnout_since"] = world.month
	else:
		p.erase("burnout_since")
	# retire: a quiet life or burnout
	var age := Ops.age_years(world, p)
	if (String(p["ambition"]) == "QUIET" and age >= QUIET_RETIRE["age_from"] and rng.randf() < QUIET_RETIRE["p"]) \
			or (p.has("burnout_since") and world.month - int(p["burnout_since"]) >= BURNOUT["months"]):
		_retire(world, pid, p, "BURNOUT" if p.has("burnout_since") else "QUIET_LIFE")
		return
	if leader:
		return
	# restless: a would-be challenger (Ella reads challengers()); the player's party secretary writes
	var chall := String(p["ambition"]) == "LEADERSHIP" and int(p["loyalty"]) < CHALLENGE["loyalty_below"] \
		and g >= CHALLENGE["grievance_from"] and int(p["skills"].get("POLI", 0)) >= CHALLENGE["poli_from"]
	if chall and not bool(p.get("restless", false)):
		p["restless"] = true
		var pref := {"kind": "PARTY", "id": String(p["party_id"])}
		world.add_fact({"type": "STAFF_BENCH_RESTLESS", "owner": "staff", "subjects": [Ops.official_ref(pid), pref], "responsible": [],
			"impact": {}, "magnitude": 30, "visibility": "OFFICIAL",
			"data": {"party": String(p["party_id"]), "person": pid, "name": String(p["name"]), "reasons": _reasons(p)}})
	elif not chall:
		p["restless"] = false
	_maybe_mail(world, pid, p)
	# defect
	var sinking := sinking(world, String(p["party_id"]))
	var sour := int(p["loyalty"]) < DEFECT["loyalty_below"] and int(p.get("line_fit", 100)) < DEFECT["fit_below"]
	var jump := sinking and int(p["loyalty"]) < SINKING["loyalty_below"] and g >= SINKING["grievance_from"]
	if (sour and rng.randf() < DEFECT["p"]) or (jump and not sour and rng.randf() < SINKING["p"]):
		var to := defection_target(world, pid, SINKING["fit_gain"] if jump and not sour else DEFECT["fit_gain"])
		if to != "":
			defect(world, pid, to)
			return
		if int(p["loyalty"]) < INDEPENDENT_LOYALTY_BELOW and bool(p.get("assembly_seat", false)) 				and int(world.levers.get("LAW_PERSONAL_MANDATE", 1)) == 1 and defect(world, pid, "")["ok"]:
			return
	# leak
	if g >= LEAK["grievance_from"] and int(p.get("integrity", 50)) < LEAK["integrity_below"] and rng.randf() < LEAK["p"]:
		_leak(world, pid, p, rng)


## People whose party is gone (dissolved, merged, or an independent's seat ended at the election): join the active
## party that fits them best (fit ≥ ORPHAN_FIT_MIN) as a bench member, or retire. Civil servants are not affected.
const ORPHAN_FIT_MIN := 50


## p.scandals (Wilma's list standing reads it): +1 when a revealed wrong names them responsible (an official who
## carried out an unlawful act: *_REVEALED facts with an OFFICIAL share), when their party's donation scandal breaks
## while they lead it (POL_SCANDAL_REVEALED, leader linked by `person`), or when a leak unmasks them (_leak).
static func _count_scandals(world: WorldState) -> void:
	var st := world.table("bench_state")
	if int(st.get("scandals_month", -1)) == world.month:
		return      # once per month
	st["scandals_month"] = world.month
	var people := world.table("person")
	for f in Det.recent_facts(world, "", world.month):
		if int(f["month"]) != world.month:
			continue
		var t := String(f["type"])
		var hit := {}
		if t.ends_with("_REVEALED"):
			for r in f.get("responsible", []):
				var a: Dictionary = r.get("actor", {})
				if String(a.get("kind", "")) == "OFFICIAL" and people.has(String(a.get("id", ""))):
					hit[String(a["id"])] = true
		if t == "POL_SCANDAL_REVEALED":
			for sj in f.get("subjects", []):
				if typeof(sj) == TYPE_DICTIONARY and String(sj.get("kind", "")) == "PARTY":
					var l = world.peek("party").get(String(sj.get("id", "")), {}).get("leader", {})
					if typeof(l) == TYPE_DICTIONARY and people.has(String(l.get("person", ""))):
						hit[String(l["person"])] = true
		for pid in Det.ordered(hit):
			people[pid]["scandals"] = int(people[pid].get("scandals", 0)) + 1


static func _rehome_orphans(world: WorldState) -> void:
	var parties := world.peek("party")
	for pid in Det.ordered(world.table("person")):
		var p: Dictionary = world.table("person")[pid]
		var pty := String(p.get("party_id", ""))
		if pty == "" or p["status"] != "ACTIVE" or p["roles"].has("CIVIL_SERVANT"):
			continue
		var st := String(parties.get(pty, {}).get("status", "ACTIVE"))
		if st == "ACTIVE" or st == "INDEPENDENT":
			continue
		var best := ""
		var best_f := ORPHAN_FIT_MIN - 1
		for q in Det.ordered(parties):
			if not Ops.party_active(world, q):
				continue
			var f := fit(p.get("lean", {}), parties[q].get("positions", {}))
			if f > best_f:
				best_f = f
				best = String(q)
		if best == "":
			_retire(world, String(pid), p, "PARTY_GONE")
			continue
		if p["pool"] == "GOV":
			Ops._leave_government(world, String(pid), "PARTY_GONE")
		elif p["pool"] != "":
			if p["assignment_id"] != "":
				Ops.unassign(world, String(pid), "PARTY_GONE")
			p["pool"] = ""
		_init_ambition(world, p)        # traits and ambition first: a never-initialised person gets their lean
		p["party_id"] = best
		p["bench_party_id"] = best
		p["lean_party"] = best
		p["assembly_seat"] = false
		p["list_rank"] = -1
		p["loyalty"] = 55
		p["grievances"] = []
		p["grievance"] = 0
		world.add_fact({"type": "STAFF_BENCH_JOINED", "owner": "staff", "subjects": [Ops.official_ref(String(pid)), {"kind": "PARTY", "id": best}],
			"responsible": [], "impact": {}, "magnitude": 25, "visibility": "PUBLIC",
			"data": {"person": String(pid), "name": String(p.get("name", "")), "party": best, "from": pty}})


static func _reasons(p: Dictionary) -> Array:
	return p.get("grievances", []).map(func(e): return String(e["kind"]))


# ----------------------------------------------------------------------------------- challenge (Ella)

## Would-be challengers of a party's leader, strongest first: [{person, name, strength, reasons, faction}].
static func challengers(world: WorldState, party: String) -> Array:
	var out: Array = []
	var pt: Dictionary = world.peek("party").get(party, {})
	for pid in members(world, party):
		var p := Ops.person(world, pid)
		if is_leader(world, pid) or not bool(p.get("restless", false)):
			continue
		out.append({"person": pid, "name": String(p["name"]),
			"strength": (int(p["skills"].get("POLI", 0)) + int(p["skills"].get("COMM", 0))) / 2 + int(p["grievance"]) / 5,
			"reasons": _reasons(p), "faction": _faction(pt, p)})
	out.sort_custom(func(a, b): return int(a["strength"]) > int(b["strength"]) or (a["strength"] == b["strength"] and String(a["person"]) < String(b["person"])))
	return out


## The faction whose pole is nearer the person's lean on the party's faction axis (else: against the leader's).
static func _faction(pt: Dictionary, p: Dictionary) -> int:
	var ax := String(pt.get("faction_axis", ""))
	var fs: Array = pt.get("factions", [])
	var l = pt.get("leader", {})
	var lf := int(l.get("faction", 0)) if typeof(l) == TYPE_DICTIONARY else 0
	if fs.size() < 2 or ax == "" or not p.get("lean", {}).has(ax):
		return 1 - lf
	var v := float(p["lean"][ax])
	return 0 if absf(v - float(fs[0].get("pole", 0))) <= absf(v - float(fs[1].get("pole", 0))) else 1


## A bench person as a leader dict (PartyLife.make_leader's shape) linked by `person`.
static func as_leader(world: WorldState, pid: String) -> Dictionary:
	var p := Ops.person(world, pid)
	var sk: Dictionary = p.get("skills", {})
	var ch := clampi(int(round(0.6 * float(sk.get("COMM", 0)) + 0.4 * float(sk.get("POLI", 0)))), 5, 100)
	var vals: Array = sk.values().map(func(v): return int(v))
	vals.sort()
	var co := clampi((int(vals[-1]) + int(vals[-2])) / 2 if vals.size() >= 2 else 50, 5, 100)
	var it := clampi(int(p.get("integrity", 50)), 5, 100)
	return {"name": String(p.get("name", "")), "charisma": ch, "competence": co, "integrity": it,
		"faction": _faction(world.peek("party").get(String(p.get("party_id", "")), {}), p), "since": world.month,
		"popularity": int(round(0.6 * ch + 0.2 * co + 0.2 * it)), "person": pid}


## Ella: the outcome of a contest a bench member fought. The winner's ambition is met; a loser is bitter.
static func contest_result(world: WorldState, party: String, pid: String, won: bool) -> void:
	var p := Ops.person(world, pid)
	if p.is_empty():
		return
	_init_ambition(world, p)
	p["restless"] = false
	if won:
		p["grievance"] = 0
		p["loyalty"] = 90
		p["ambition"] = "OFFICE"
	else:
		grieve(world, p, "CONTEST_LOST", party)


# ----------------------------------------------------------------------------------- defection

## The active party that fits them clearly better than their own (DEFECT.fit_gain), best first; "" if none.
## A party in trouble: lost a third of its seats at an election in the last SINKING.months.
static func sinking(world: WorldState, party: String) -> bool:
	return world.month - int(world.peek("bench_state").get("sinking", {}).get(party, -999)) <= SINKING["months"]


static func defection_target(world: WorldState, pid: String, gain: int = DEFECT["fit_gain"]) -> String:
	var p := Ops.person(world, pid)
	var own := String(p.get("party_id", ""))
	var base := fit(p.get("lean", {}), world.peek("party").get(own, {}).get("positions", {}))
	var best := ""
	var best_f := base + gain - 1
	for pty in Det.ordered(world.peek("party")):
		if pty == own or not Ops.party_active(world, pty):
			continue
		var f := fit(p.get("lean", {}), world.peek("party")[pty].get("positions", {}))
		if f > best_f:
			best_f = f
			best = String(pty)
	return best


## Move a member to another party. A minister leaves the Cabinet; an Assembly seat (B3: p.assembly_seat) goes with
## them under LAW_PERSONAL_MANDATE = 1, or stays with the old party under 0. to = "": the member leaves to sit as an
## INDEPENDENT (free mandate and a seat only; PartyLife.make_independent makes the 1-seat row). PUBLIC STAFF_DEFECTED.
static func defect(world: WorldState, pid: String, to: String) -> Dictionary:
	var p := Ops.person(world, pid)
	var from := String(p.get("party_id", ""))
	if p.is_empty() or from == "" or to == from or (to != "" and not Ops.party_active(world, to)):
		return {"ok": false, "reason": "cannot defect"}
	if to == "":
		if not bool(p.get("assembly_seat", false)) or int(world.levers.get("LAW_PERSONAL_MANDATE", 1)) != 1:
			return {"ok": false, "reason": "only a member with a seat under the free mandate can sit as an independent"}
		if not _has_static(load("res://sim/politics/party_life.gd"), "make_independent"):
			return {"ok": false, "reason": "independents are not available yet"}
	var role := String(_portfolios(world).get(pid, ""))
	var minister_label := OFS.minister_label(world, role) if role != "" else ""
	if p["pool"] == "GOV":
		Ops._leave_government(world, pid, "DEFECTED")
	elif p["pool"] != "":
		if p["assignment_id"] != "":
			Ops.unassign(world, pid, "DEFECTED")
		p["pool"] = ""
	var seat := ""
	if to == "":
		# the independent row carries the seat (1); the old party loses it
		var parties0 := world.table("party")
		parties0[from]["seats"] = maxi(0, int(parties0[from].get("seats", 0)) - 1)
		to = String(load("res://sim/politics/party_life.gd").call("make_independent", world, p))   # Wilma (A51)
		seat = "CARRIED"
	elif bool(p.get("assembly_seat", false)):
		var parties := world.table("party")
		if int(world.levers.get("LAW_PERSONAL_MANDATE", 1)) == 1:
			parties[from]["seats"] = maxi(0, int(parties[from].get("seats", 0)) - 1)
			parties[to]["seats"] = int(parties[to].get("seats", 0)) + 1
			seat = "CARRIED"
		else:
			p["assembly_seat"] = false
			seat = "STAYS"
	var reasons := _reasons(p)
	p["party_id"] = to
	p["bench_party_id"] = to
	p["loyalty"] = 60
	p["grievance"] = 10
	p["grievances"] = []
	p["restless"] = false
	p["lean_party"] = to
	p["defected"] = p.get("defected", 0) + 1
	var f_ref := {"kind": "PARTY", "id": from}
	var t_ref := {"kind": "PARTY", "id": to}
	world.add_fact({"type": "STAFF_DEFECTED", "owner": "staff", "subjects": [Ops.official_ref(pid), f_ref, t_ref],
		"responsible": [{"actor": Ops.official_ref(pid), "share": 1.0}], "impact": {}, "magnitude": 60 if role != "" else 45,
		"visibility": "PUBLIC", "data": {"person": pid, "name": String(p["name"]), "from": from, "to": to, "reasons": reasons,
			"role": role, "minister": minister_label, "list_rank": int(p.get("list_rank", -1)), "seat": seat}})
	return {"ok": true, "reason": "", "seat": seat}


static func _has_static(script: Script, name: String) -> bool:
	for m in script.get_script_method_list():
		if String(m.get("name", "")) == name:
			return true
	return false


# ----------------------------------------------------------------------------------- leaks

## A party secret (an unrevealed illegal donation) or, from inside the government, a SECRET government fact of the
## last 24 months, revealed through the existing path with channel LEAK. The party learns who with LEAK.named_p.
static func _leak(world: WorldState, pid: String, p: Dictionary, rng: RandomNumberGenerator) -> void:
	var party := String(p["party_id"])
	var by := {"kind": "PRESS", "id": "LEAK"}
	var target := ""
	for fid in Det.ordered(world.peek("donation_track")):
		var t: Dictionary = world.peek("donation_track")[fid]
		if not bool(t.get("revealed", true)) and String(t.get("party", "")) == party:
			target = String(fid)
			break
	if target != "":
		load("res://sim/law/party_finance.gd")._scandal(world, target, by, "LEAK")
	else:
		var insider: bool = p["pool"] == "GOV" or Ops.pm_party(world) == party
		for f in Det.recent_facts(world, "", world.month - 24, "SECRET"):
			var fid := String(f["id"])
			if world.peek("revealed_fact").has(fid):
				continue
			var actors: Array = f.get("subjects", []).duplicate()
			for r in f.get("responsible", []):
				actors.append(r.get("actor", {}))
			if actors.any(func(a): return typeof(a) == TYPE_DICTIONARY and ((String(a.get("kind", "")) == "PARTY" and String(a.get("id", "")) == party) 					or (insider and String(a.get("kind", "")) == "GOVERNMENT"))):
				world.table("revealed_fact")[fid] = true
				world.facts.reveal(world.month, fid, [by])
				target = fid
				break
	if target == "":
		return
	var named := rng.randf() < LEAK["named_p"]
	if named:
		p["scandals"] = int(p.get("scandals", 0)) + 1      # unmasked as the leaker
	world.add_fact({"type": "STAFF_LEAKED", "owner": "staff", "subjects": [{"kind": "PARTY", "id": party}], "responsible": [],
		"impact": {}, "magnitude": 45, "visibility": "PUBLIC",
		"data": {"party": party, "fact": target, "person": pid if named else "", "name": String(p["name"]) if named else ""}})


static func _retire(world: WorldState, pid: String, p: Dictionary, why: String) -> void:
	var party := String(p["party_id"])
	Ops._depart(world, pid, "RETIRED", "RETIREMENT")
	world.add_fact({"type": "STAFF_BENCH_RETIRED", "owner": "staff", "subjects": [Ops.official_ref(pid), {"kind": "PARTY", "id": party}],
		"responsible": [], "impact": {}, "magnitude": 25, "visibility": "PUBLIC",
		"data": {"person": pid, "name": String(p["name"]), "party": party, "why": why}})


# ----------------------------------------------------------------------------------- the party secretary's mail

static func _secretary(world: WorldState, party: String, not_pid: String) -> String:
	var best := ""
	var best_s := -1
	for pid in bench_of(world, party):
		if pid == not_pid:
			continue
		var s := int(Ops.person(world, pid)["skills"].get("ADMIN", 0))
		if s > best_s:
			best_s = s
			best = pid
	return String(Ops.person(world, best).get("name", "the party secretary")) if best != "" else "the party secretary"


## The player's party: a restless member (OFFICE or LEADERSHIP, grievance ≥ MAIL.grievance_from) gets one email a
## year from the party secretary. Options: promise a post, give a portfolio (governing only), ignore (default).
static func _maybe_mail(world: WorldState, pid: String, p: Dictionary) -> void:
	var party := String(p["party_id"])
	if party != Ops.player_party(world) or Ops.autopilot(world, {"kind": "PARTY", "id": party}):
		return
	if not (String(p["ambition"]) in ["OFFICE", "LEADERSHIP"]) or int(p["grievance"]) < MAIL["grievance_from"]:
		return
	if world.month - int(p.get("bench_mail", -999)) < MAIL["cooldown"] or _portfolios(world).has(pid):
		return
	p["bench_mail"] = world.month
	var opts: Array = [{"id": "PROMISE", "label": "Promise a post at the next reshuffle", "action": {}}]
	if Ops.pm_party(world) == party:
		opts.append({"id": "PORTFOLIO", "label": "Give them a portfolio now", "action": {}})
	opts.append({"id": "IGNORE", "label": "Ignore it", "action": {}})
	var why: Array = _reasons(p)
	Office.post(world, {"kind": "EMAIL", "from": {"kind": "PARTY_STAFF", "role": "PARTY_SECRETARY", "name": _secretary(world, party, pid)},
		"subject": "%s feels passed over" % String(p["name"]), "category": "PARTY", "priority": 55,
		"summary_lines": ["%s wants %s." % [String(p["name"]), "a seat in the Cabinet" if p["ambition"] == "OFFICE" else "to lead the party"],
			"Their grievances: %s." % (", ".join(why).to_lower().replace("_", " ") if not why.is_empty() else "none on record"),
			"Loyalty to you is %s." % ("low" if int(p["loyalty"]) < 40 else "holding")],
		"options": opts, "default_option": "IGNORE", "deadline": world.month + MAIL["deadline"],
		"source": {"system": "bench", "ref": pid}})


## Apply answered (or expired) secretary emails once.
static func _mail_answers(world: WorldState) -> void:
	for id in Det.ordered(world.peek("office_item")):
		var o: Dictionary = world.peek("office_item")[id]
		if String(o.get("source", {}).get("system", "")) != "bench" or o["status"] in ["NEW", "READ"] or bool(o.get("bench_done", false)):
			continue
		world.table("office_item")[id]["bench_done"] = true
		var pid := String(o["source"].get("ref", ""))
		var p := Ops.person(world, pid)
		if p.is_empty() or not Ops.is_alive_active(p):
			continue
		match String(o.get("answer", "")):
			"PROMISE":
				p["grievance"] = maxi(0, int(p["grievance"]) - 25)
				p["promised"] = world.month
			"PORTFOLIO":
				if give_portfolio(world, pid)["ok"]:
					p["grievance"] = maxi(0, int(p["grievance"]) - 40)
			_:
				grieve(world, p, "IGNORED")


## Bring a bench member into the Cabinet in place of their party's weakest appointee (who is sacked); the next
## reshuffle (fill_roles) deals the freed portfolio.
static func give_portfolio(world: WorldState, pid: String) -> Dictionary:
	var p := Ops.person(world, pid)
	var party := String(p.get("party_id", ""))
	if p.is_empty() or p["pool"] != "" or String(p.get("bench_party_id", "")) != party:
		return {"ok": false, "reason": "not on the party's bench"}
	var weakest := ""
	var ws := 1 << 30
	for qid in Det.ordered(world.table("person")):
		var q: Dictionary = world.table("person")[qid]
		if q["pool"] == "GOV" and q["roles"].has("GOV_POLITICAL") and String(q["party_id"]) == party and Ops.is_alive_active(q):
			var v := Ops._person_value(q)
			if v < ws:
				ws = v
				weakest = String(qid)
	if weakest == "":
		return {"ok": false, "reason": "the party holds no Cabinet seat"}
	var sid := ""
	for s in Det.ordered(world.table("gov_seat")):
		if String(world.table("gov_seat")[s]["person_id"]) == weakest:
			sid = String(s)
	var d := Ops.dismiss_political(world, weakest, party)
	if not d["ok"]:
		return d
	return Ops.appoint_political(world, sid, pid)

class_name Intel
extends RefCounted
## Imperfect knowledge (A49, planning/spec-knowledge-v1.md).
## K1 PICTURES: each active party and the government ("gov") keep an estimate of the electorate's satisfaction and
## salience per concern, built monthly from polls (noise by research quality) and their own base (the bubble), and
## taken up slowly. AI drafting, crisis judgement and floor votes read pictures, never the voters directly.
## K2 BELIEFS: each party believes a share of every lever's effect hints (milli; 1000 = the hints), starting from its
## ideology and learning from the public record a year after each change, against ideological resistance.
## State in pol.state: intel {key: {sat, sal, q, month}}, beliefs {pid: {lever: milli}}, policy_record [..],
## lever_snap {lever: value}. Integer state; RNG stream "pol.intel".

const UPTAKE := 0.3            # share of the gap to the evidence closed each month (new anger is noticed late)
const SAT_NOISE := 9000.0      # sat noise sd (milli of 0..100000) at research quality 0
const SAL_NOISE := 40.0        # salience noise sd at quality 0 (salience ~111 per concern)
const BUBBLE := 0.6            # weight of the own base at quality 0
const RECORD_MONTHS := 12      # evidence is read a year after a law changes
const EXPECT_PTS := 3000.0     # sat change (milli) a one-step change is "supposed" to bring, per unit hint share
const LEARN := 0.25            # belief step toward the evidence
const RESIST := 0.4            # learning factor when the evidence goes against the party's ideology
const OWN_LAW := 1.5           # governing parties learn more from their own laws
const OStaff := preload("res://sim/staff/office_staff.gd")


static func _st(world: WorldState) -> Dictionary:
	return world.table("pol")["state"]


## Research quality 0..100: parties by size; the government by its economic adviser's skill (A44 O5 roles).
static func quality(world: WorldState, key: String) -> int:
	if key == "gov":
		var h: Dictionary = OStaff.holder(world, "ECON_ADVISER")
		return clampi(OStaff.role_skill(h, "ECON_ADVISER"), 20, 95) if not h.is_empty() else 50
	var p: Dictionary = world.peek("party").get(key, {})
	var st: Dictionary = world.peek("pol").get("state", {})
	var gov := 10 if key in st.get("government", {}).get("members", []) else 0
	return clampi(25 + int(p.get("seats", 0)) * 2 / 5 + gov, 15, 85)


## A party's (or the government's) picture: [sat {c: milli}, sal {c: int}]. Pure read; neutral if none yet.
static func picture(world: WorldState, key: String) -> Array:
	var st: Dictionary = world.peek("pol").get("state", {})
	var pic: Dictionary = st.get("intel", {}).get(key, {})
	if pic.is_empty():
		var sat := {}
		var sal := {}
		for c in PolDefs.CONCERNS:
			sat[c] = 50000
			sal[c] = 111
		return [sat, sal]
	return [pic["sat"].duplicate(), pic["sal"].duplicate()]


## POLITICS phase: update every picture from the truth (polls) and each party's base, then read the record.
static func monthly(world: WorldState, truth: Array) -> void:
	var st := _st(world)
	var intel: Dictionary = st.get("intel", {})
	st["intel"] = intel
	var parties: Array = []
	for pid in EconUtil.sorted_keys(world.table("party")):
		if world.table("party")[pid].get("status", "") == "ACTIVE":
			parties.append(pid)
	var bases := _bases(world, parties)
	var rng := world.rng.stream("pol.intel")
	for key in ["gov"] + parties:
		var q := float(quality(world, key)) / 100.0
		var base: Array = bases.get(key, truth)
		var w_base := BUBBLE * (1.0 - q) if key != "gov" else 0.0
		var pic: Dictionary = intel.get(key, {})
		var first := pic.is_empty()
		var sat := {}
		var sal := {}
		for c in PolDefs.CONCERNS:
			var t_sat := (1.0 - w_base) * float(truth[0][c]) + w_base * float(base[0].get(c, truth[0][c])) + rng.randfn(0.0, SAT_NOISE * (1.0 - q))
			var t_sal := (1.0 - w_base) * float(truth[1][c]) + w_base * float(base[1].get(c, truth[1][c])) + rng.randfn(0.0, SAL_NOISE * (1.0 - q))
			var old_sat := float(pic.get("sat", {}).get(c, t_sat)) if not first else t_sat
			var old_sal := float(pic.get("sal", {}).get(c, t_sal)) if not first else t_sal
			sat[c] = clampi(int(round(old_sat + UPTAKE * (t_sat - old_sat))), 0, 100000)
			sal[c] = maxi(0, int(round(old_sal + UPTAKE * (t_sal - old_sal))))
		intel[key] = {"sat": sat, "sal": sal, "q": int(q * 100.0), "month": world.month}
	for key in intel.keys():
		if key != "gov" and not (key in parties):
			intel.erase(key)
	_record(world, st, truth)


## Each party's base: voters weighted by the party's previous vote share in their group.
static func _bases(world: WorldState, parties: Array) -> Dictionary:
	var acc := {}
	for pid in parties:
		var s := {}
		var l := {}
		for c in PolDefs.CONCERNS:
			s[c] = 0.0
			l[c] = 0.0
		acc[pid] = [s, l, 0.0]
	for cell in PolVoters.all(world):
		var pop := float(cell.get("pop", 0))
		if pop <= 0.0:
			continue
		var ps: Dictionary = cell.get("prev_share", {})
		for pid in parties:
			var w := pop * float(ps.get(pid, 0)) / 100000.0
			if w <= 0.0:
				continue
			var a: Array = acc[pid]
			for c in PolDefs.CONCERNS:
				a[0][c] += float(cell["sat"][c]) * w
				a[1][c] += float(cell["salience"][c]) * w
			a[2] += w
	var out := {}
	for pid in parties:
		var a: Array = acc[pid]
		if float(a[2]) <= 0.0:
			continue
		var s2 := {}
		var l2 := {}
		for c in PolDefs.CONCERNS:
			s2[c] = a[0][c] / a[2]
			l2[c] = a[1][c] / a[2]
		out[pid] = [s2, l2]
	return out


# ------------------------------------------------------------------ K2 beliefs

## A party's belief in a lever's effect hints (1.0 = the hints). Pure: falls back to the ideological prior.
static func belief(world: WorldState, pid: String, lever: String) -> float:
	var st: Dictionary = world.peek("pol").get("state", {})
	var b: Dictionary = st.get("beliefs", {}).get(pid, {})
	if b.has(lever):
		return float(b[lever]) / 1000.0
	return float(_prior(world, pid, lever)) / 1000.0


## Ideological prior: a party that likes a lever believes it works better (up to 1.4), one that dislikes it worse.
static func _prior(world: WorldState, pid: String, lever: String) -> int:
	var def: Dictionary = world.lever_defs.get(lever, {})
	var p: Dictionary = world.peek("party").get(pid, {})
	var pos: Dictionary = p.get("positions", {})
	var num := 0.0
	var den := 0.0
	for ax in def.get("ideology", {}):
		var w := float(def["ideology"][ax])
		num += w * float(pos.get(ax, 0)) / 100000.0
		den += absf(w)
	var a := clampf(num / maxf(0.0001, den), -1.0, 1.0)
	return int(round(1000.0 + 400.0 * a))


## Note lever changes (legislative NUMBER levers with effect hints) and, a year later, read the evidence.
static func _record(world: WorldState, st: Dictionary, truth: Array) -> void:
	var snap: Dictionary = st.get("lever_snap", {})
	var rec: Array = st.get("policy_record", [])
	var first := snap.is_empty()
	for lid in EconUtil.sorted_keys(world.lever_defs):
		var def: Dictionary = world.lever_defs[lid]
		if def.get("type", "") != "NUMBER" or def.get("concerns", {}).is_empty():
			continue
		var v := int(world.levers.get(lid, def.get("default", 0)))
		if not first and snap.has(lid) and int(snap[lid]) != v:
			var base := {}
			for c in def["concerns"]:
				if truth[0].has(c):
					base[c] = int(truth[0][c])
			rec.append({"lever": lid, "dir": 1 if v > int(snap[lid]) else -1, "month": world.month, "base": base,
				"gov": st.get("government", {}).get("members", []).duplicate()})
		snap[lid] = v
	st["lever_snap"] = snap
	var keep: Array = []
	for r in rec:
		if world.month - int(r["month"]) < RECORD_MONTHS:
			keep.append(r)
			continue
		_learn(world, st, r, truth)
	st["policy_record"] = keep


static func _learn(world: WorldState, st: Dictionary, r: Dictionary, truth: Array) -> void:
	var def: Dictionary = world.lever_defs.get(String(r["lever"]), {})
	var hints: Dictionary = def.get("concerns", {})
	var num := 0.0
	var den := 0.0
	for c in r["base"]:
		if c == "GOVERNANCE" or not hints.has(c):
			continue   # the budget sign is accounting, not belief
		var h := float(hints[c]) * float(r["dir"])
		num += signf(h) * absf(h) * (float(truth[0].get(c, r["base"][c])) - float(r["base"][c]))
		den += absf(h)
	if den <= 0.0:
		return
	var evidence := clampf(num / den / EXPECT_PTS, 0.0, 2.0) * 1000.0   # 1000 = it did what the hints say
	var beliefs: Dictionary = st.get("beliefs", {})
	st["beliefs"] = beliefs
	var moved := {}   # pid -> [before, after] milli (for the chronicle: expectation vs reality)
	for pid in EconUtil.sorted_keys(world.table("party")):
		if world.table("party")[pid].get("status", "") != "ACTIVE":
			continue
		var b: Dictionary = beliefs.get(pid, {})
		beliefs[pid] = b
		var lid := String(r["lever"])
		var prior := _prior(world, pid, lid)
		var cur := float(b.get(lid, prior))
		var rate := LEARN
		if (prior > 1000 and evidence < cur) or (prior < 1000 and evidence > cur):
			rate *= RESIST   # evidence against what the party's ideology wants to believe
		if pid in r.get("gov", []):
			rate *= OWN_LAW
		b[lid] = clampi(int(round(cur + rate * (evidence - cur))), 100, 2000)
		moved[pid] = [int(round(cur)), int(b[lid])]
	world.add_fact({"type": "POL_POLICY_EVIDENCE", "owner": "pol", "subjects": [], "responsible": [], "impact": {}, "magnitude": 10,
		"visibility": "OFFICIAL", "data": {"lever": String(r["lever"]), "dir": int(r["dir"]), "evidence": int(round(evidence)),
		"changed": int(r["month"]), "passed_by": r.get("gov", []).duplicate(), "beliefs": moved}})

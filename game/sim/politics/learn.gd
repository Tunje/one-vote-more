class_name Learn
extends RefCounted
## A53: party strategy genomes and the learning party (planning/spec-learning-party-v1.md).
## A party's strategy is party["strategy"] = {gene: milli 0..1000}; a missing gene is 500 = today's behaviour, so worlds
## without genomes are unchanged. Decision points read Learn.gene(party, "G_X") and map it through small multipliers.
## L1: the learning party (meta.learning_party = party id or "auto") nudges its genes after each election and each
## January toward directions that paid off (a (1+1) evolution step with exploration; stream "pol.learn").

const GENES := ["G_DRIFT", "G_ISSUE", "G_NEGATIVE", "G_SPEND", "G_COALITION", "G_PORK", "G_PACE", "G_DISCIPLINE",
	"G_RESEARCH", "G_UNION"]
const STEP := 120          # exploration step (milli)
const LEARN_RATE := 0.5    # share of a successful trial kept


static func gene(party: Dictionary, g: String) -> int:
	return int(party.get("strategy", {}).get(g, 500))


## Multiplier around 1.0 for a gene: 500 -> 1.0, 0 -> 1 - span, 1000 -> 1 + span.
static func mult(party: Dictionary, g: String, span: float = 0.5) -> float:
	return 1.0 + span * (float(gene(party, g)) - 500.0) / 500.0


static func learning_party(world: WorldState) -> String:
	var lp := String(world.meta.get("learning_party", ""))
	if lp == "auto":
		var best := ""
		var seats := -1
		for pid in CoreUtil.sorted_keys(world.peek("party")):
			var p: Dictionary = world.peek("party")[pid]
			if p.get("status", "") == "ACTIVE" and p.get("kind", "") == "FOUNDING" and int(p.get("seats", 0)) > seats:
				seats = int(p.get("seats", 0))
				best = pid
		return best
	return lp


## The learning party's score now: vote share (milli), seats and whether it leads or sits in the Cabinet.
static func score(world: WorldState, pid: String) -> float:
	var p: Dictionary = world.peek("party").get(pid, {})
	var st: Dictionary = world.peek("pol").get("state", {})
	var g: Dictionary = st.get("government", {})
	var s := float(p.get("support", 0)) / 1000.0 + float(p.get("seats", 0)) * 0.3
	if String(g.get("pm_party", "")) == pid:
		s += 25.0
	elif pid in g.get("members", []):
		s += 10.0
	return s


## L1, each January and after each election: keep a trial genome that did better than the last baseline, else revert
## part-way; then propose the next trial (one random gene moved by ±STEP).
static func step(world: WorldState) -> void:
	var pid := learning_party(world)
	if pid == "" or not world.table("party").has(pid):
		return
	var p: Dictionary = world.table("party")[pid]
	if p.get("status", "") != "ACTIVE":
		return
	var st: Dictionary = world.table("pol")["state"]
	var ls: Dictionary = st.get("learn", {})
	st["learn"] = ls
	var now := int(round(score(world, pid) * 1000.0))   # milli: integer state only
	var genome: Dictionary = p.get("strategy", {}).duplicate()
	for g in GENES:
		if not genome.has(g):
			genome[g] = 500
	if ls.has("base"):
		var base: Dictionary = ls["base"]
		if now >= int(ls.get("base_score", 0)):
			ls["base"] = genome.duplicate()          # the trial paid off: keep it
			ls["base_score"] = now
			ls["kept"] = int(ls.get("kept", 0)) + 1
		else:
			for g in GENES:                          # it did not: move back toward the baseline
				genome[g] = int(round(float(genome[g]) + LEARN_RATE * (float(base[g]) - float(genome[g]))))
			ls["base_score"] = int(round(0.9 * float(ls.get("base_score", 0)) + 0.1 * float(now)))   # the world moves on
	else:
		ls["base"] = genome.duplicate()
		ls["base_score"] = now
	var rng := world.rng.stream("pol.learn")
	var g2: String = GENES[rng.randi_range(0, GENES.size() - 1)]
	genome[g2] = clampi(int(genome[g2]) + (STEP if rng.randf() < 0.5 else -STEP), 0, 1000)
	p["strategy"] = genome
	var hist: Array = ls.get("history", [])
	hist.append({"month": world.month, "score": now, "genome": genome.duplicate()})
	if hist.size() > 160:   # a century of Januaries and elections
		hist.pop_front()
	ls["history"] = hist
	ls["party"] = pid

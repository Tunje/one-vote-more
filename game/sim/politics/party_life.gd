class_name PartyLife
extends RefCounted
## M9 living party system (planning/spec-politics-v2.md §1–3): leaders, factions, leadership contests,
## party founding (unrepresented / populist / single-issue), splits, mergers and dissolution, party funds.
## Stateless; state lives on party rows and in pol.state (lifecycle sub-dict).

const S := 1000
const DEAD_SHARE := 100              # 0.1% (per-100000): below this for DEAD_MONTHS running, a party is wound up
const DEAD_MONTHS := 36
const THRESHOLD := 4000              # 4% (per-100000 support)
# founding
const UNREP_DISTANCE := 28.0         # points from the nearest party
const UNREP_SHARE := 0.04
const POPULIST_GOV_SAT := 40000
const POPULIST_APPROVAL := 45000
const ISSUE_SAT := 35000
const ISSUE_MONTHS := 24
const FOUNDING_COOLDOWN := 36        # months between foundings colony-wide
# factions & splits
const FACTION_MIN_SD := 8.0          # points
const SPLIT_DISCONTENT := 75
const SPLIT_MONTHS := 12
const SPLIT_MIN_STRENGTH := 0.25
const SPLIT_MIN_SEATS := 10
const SPLIT_COOLDOWN := 60            # colony-wide; splits are rare, memorable events
const SINGLE_ISSUE_OWNERSHIP := 75
const FORCED_CONTESTS := ["SCANDAL", "RETIREMENT", "CONVICTION"]
# interest groups (spec §4–5)
const UNION_ENDORSE_BETA := 0.8       # utility bonus x union density for the endorsed party
const BUSINESS_ENDORSE_BETA := 0.3    # business owners and the federation's party
const SPLINTER_SEAT_SHARE := 0.6     # share of the faction's MPs who actually leave
# mergers
const NEW_PARTY_GRACE := 48            # months before a new party can be merged away
const MERGE_DISTANCE := 15.0
# leaders
const CONTEST_SUPPORT_DROP := 3000   # 3 pp lost at an election triggers a contest
const CONTEST_POPULARITY := 25
const LEADER_PLATFORM_PULL := 0.15
# money (milli-credits)
const DUES_PER_SUPPORT_POINT := 40 * S   # per month per 1% support
const CAMPAIGN_MONTHS := 6


# ======================================================================= leaders

static func make_leader(world: WorldState, faction: int, boost_charisma: int = 0) -> Dictionary:
	var r := world.rng.stream("pol.leaders")
	var ch := clampi(int(round(r.randfn(50.0, 15.0))) + boost_charisma, 5, 100)
	var co := clampi(int(round(r.randfn(50.0, 15.0))), 5, 100)
	var it := clampi(int(round(r.randfn(55.0, 18.0))), 5, 100)
	var used := {}
	for q in world.table("party").values():
		used[leader_name(q)] = true
	var nm := PartyGen.leader_name(world.rng.stream("pol.names"))
	for _i in 20:
		if not used.has(nm):
			break
		nm = PartyGen.leader_name(world.rng.stream("pol.names"))
	return {"name": nm, "charisma": ch, "competence": co,
		"integrity": it, "faction": faction, "since": world.month, "popularity": int(round(0.6 * ch + 0.2 * co + 0.2 * it))}


static func leader_name(p: Dictionary) -> String:
	var l = p.get("leader", "")
	return String(l["name"]) if typeof(l) == TYPE_DICTIONARY else String(l)


static func leader_popularity(p: Dictionary) -> int:
	var l = p.get("leader", {})
	return int(l.get("popularity", 50)) if typeof(l) == TYPE_DICTIONARY else 50


## Monthly: popularity drifts toward what the leader's traits and record justify; scandals bite.
static func leaders_monthly(world: WorldState, st: Dictionary) -> void:
	var g: Dictionary = st.get("government", {})
	var approval := float(world.indicators.read("POL_GOV_APPROVAL")) / 1000.0 if world.indicators.values.has("POL_GOV_APPROVAL") else 50.0
	var scandals := {}
	for f in world.facts.query("POL_SCANDAL_REVEALED", world.month, world.month):
		var pid: String = f["data"].get("party", "")
		scandals[pid] = scandals.get(pid, 0) + int(f["data"].get("severity", 30))
	for p in active(world):
		var l: Dictionary = p["leader"]
		var target: float = 0.5 * l["charisma"] + 0.2 * l["competence"] + 0.3 * l["integrity"]
		if p["id"] == g.get("pm_party", ""):
			target += 0.4 * (approval - 50.0)   # a PM wears the government's record
		var pop: float = 0.92 * float(l["popularity"]) + 0.08 * target
		if scandals.has(p["id"]):
			pop -= float(scandals[p["id"]]) * (1.0 - float(l["integrity"]) / 200.0)
			p["credibility"] = clampi(p["credibility"] - scandals[p["id"]] / 3, 0, 100)
			if pop < CONTEST_POPULARITY:
				st["lifecycle"]["contest_due"][p["id"]] = "SCANDAL"
		l["popularity"] = clampi(int(round(pop)), 0, 100)
	# a convicted leader who may not hold office has to go (a9: LAW_LEADER_CONVICTED.must_step_down)
	for f in world.facts.query("LAW_LEADER_CONVICTED", world.month, world.month):
		var pid: String = f["data"].get("party", "")
		var p: Dictionary = world.table("party").get(pid, {})
		if p.is_empty() or p["status"] != "ACTIVE":
			continue
		var l: Dictionary = p["leader"]
		l["popularity"] = maxi(0, int(l["popularity"]) - 15)
		if f["data"].get("must_step_down", false) and String(f["data"].get("leader", "")) == String(l["name"]):
			st["lifecycle"]["contest_due"][pid] = "CONVICTION"


## Leadership contest: the challenging faction wins with odds set by its strength and discontent.
static func leadership_contest(world: WorldState, st: Dictionary, p: Dictionary, reason: String) -> void:
	if p["is_player"] and not st.get("autoplay_player", true):
		return  # a human leads their own party (an internal challenge to the player is post-v1)
	ensure_factions(p)
	var fs: Array = p["factions"]
	var inc: int = int(p["leader"]["faction"])
	var ch: int = 1 - inc
	var r := world.rng.stream("pol.leaders")
	var odds := 0.2 + 0.8 * (faction_strength(fs[ch]) - 0.5) + float(fs[ch]["discontent"]) / 300.0
	var forced := reason in FORCED_CONTESTS
	if forced:
		odds = maxf(odds, 0.5)  # an open contest: the leader is gone either way
	var winner := ch if r.randf() < clampf(odds, 0.05, 0.95) else inc
	var old_name := leader_name(p)
	var changed := forced or winner != inc
	if not changed:
		fs[ch]["discontent"] = mini(100, int(fs[ch]["discontent"]) + 10)  # lost again: bitterness
		world.add_fact({"type": "POL_LEADER_SURVIVED", "owner": "pol", "subjects": [{"kind": "PARTY", "id": p["id"]}],
			"responsible": [], "impact": {}, "magnitude": 35, "visibility": "PUBLIC", "data": {"party": p["id"], "leader": old_name, "reason": reason}})
		return
	p["leader"] = make_leader(world, winner)
	# the winning faction pulls the platform toward its pole
	var ax: String = p["faction_axis"]
	var pole: int = fs[winner]["pole"]
	p["positions"][ax] += int(round(float(pole - int(p["positions"][ax])) * LEADER_PLATFORM_PULL))
	fs[winner]["discontent"] = 20
	fs[1 - winner]["discontent"] = mini(100, int(fs[1 - winner]["discontent"]) + 15)
	p["commitments"] = PartyGen.commitments(p["positions"], world.lever_defs)
	world.add_fact({"type": "POL_LEADER_CHANGED", "owner": "pol", "subjects": [{"kind": "PARTY", "id": p["id"]}],
		"responsible": [], "impact": {}, "magnitude": 55, "visibility": "PUBLIC",
		"data": {"party": p["id"], "old": old_name, "new": p["leader"]["name"], "reason": reason, "faction": winner}})


# ======================================================================= factions

## Factions split the party on the axis where its own voters disagree most (prev_share-weighted SD).
## Colony-wide (pop-weighted) standard deviation of voter ideology per axis, in points.
static func _colony_sd(world: WorldState) -> Dictionary:
	var out := {}
	for ax in PolDefs.AXES:
		var w := 0.0
		var m := 0.0
		var m2 := 0.0
		for c in world.table("cell").values():
			var n := float(c["pop"])
			if n <= 0.0:
				continue
			var x := float(c["ideology"][ax]) / 1000.0
			w += n
			m += n * x
			m2 += n * x * x
		if w > 0.0:
			out[ax] = sqrt(maxf(0.0, m2 / w - (m / w) * (m / w)))
	return out


static func update_factions(world: WorldState, p: Dictionary) -> void:
	var pid: String = p["id"]
	# The faction line runs where the party's voters are UNUSUALLY divided (their spread relative to the
	# colony's spread on that axis) on issues they CARE about (salience-linked axis weight). Raw spread alone
	# always picked REDISTRIBUTION, because income bands spread everyone on it (100-year chronicle: 13/13 splits).
	var best_ax := ""
	var best_sd := -1.0
	var best_score := -1.0
	var scores := {}
	var sds := {}
	var col_sd := _colony_sd(world)
	var aw := {}
	var aw_w := 0.0
	for c in world.table("cell").values():
		var s := float(c["prev_share"].get(pid, 0)) / 100000.0 * float(c["pop"])
		if s <= 0.0:
			continue
		var wts := VoteModel.axis_weights(c["salience"])
		for ax in wts:
			aw[ax] = float(aw.get(ax, 0.0)) + wts[ax] * s
		aw_w += s
	for ax in PolDefs.AXES:
		var w := 0.0
		var m := 0.0
		var m2 := 0.0
		for c in world.table("cell").values():
			var s := float(c["prev_share"].get(pid, 0)) / 100000.0 * float(c["pop"])
			if s <= 0.0:
				continue
			var x := float(c["ideology"][ax]) / 1000.0
			w += s
			m += s * x
			m2 += s * x * x
		if w <= 0.0:
			continue
		var mean := m / w
		var sd := sqrt(maxf(0.0, m2 / w - mean * mean))
		sds[ax] = sd
		scores[ax] = sd / maxf(5.0, float(col_sd.get(ax, 20.0))) * float(aw.get(ax, aw_w)) / maxf(1.0, aw_w)
		if scores[ax] > best_score:
			best_score = scores[ax]
			best_ax = ax
	# sticky: keep the current conflict unless another is clearly (25%) more divisive
	var cur: String = p.get("faction_axis", "")
	if cur != "" and scores.has(cur) and best_ax != cur and scores[best_ax] < 1.25 * scores[cur]:
		best_ax = cur
	if best_ax != "":
		best_sd = sds[best_ax]
	if best_ax == "":
		ensure_factions(p)
		return
	var sd2 := maxf(FACTION_MIN_SD, best_sd)
	var pos := float(p["positions"][best_ax]) / 1000.0
	# strength: voter weight on each side of the platform
	var lo := 0.0
	var hi := 0.0
	for c in world.table("cell").values():
		var s := float(c["prev_share"].get(pid, 0)) / 100000.0 * float(c["pop"])
		if s > 0.0:
			if float(c["ideology"][best_ax]) / 1000.0 < pos:
				lo += s
			else:
				hi += s
	var tot := maxf(1.0, lo + hi)
	var old: Array = p.get("factions", [])
	var keep: bool = p.get("faction_axis", "") == best_ax and old.size() == 2
	p["faction_axis"] = best_ax
	p["factions"] = [
		{"pole": clampi(int(round((pos - sd2) * S)), -100 * S, 100 * S), "strength": snappedf(lo / tot, 0.001), "discontent": old[0]["discontent"] if keep else 30, "high_months": old[0].get("high_months", 0) if keep else 0},
		{"pole": clampi(int(round((pos + sd2) * S)), -100 * S, 100 * S), "strength": snappedf(hi / tot, 0.001), "discontent": old[1]["discontent"] if keep else 30, "high_months": old[1].get("high_months", 0) if keep else 0},
	]
	# strengths are stored as ints (README rule 3)
	for f in p["factions"]:
		f["strength"] = int(round(float(f["strength"]) * 1000.0))


static func ensure_factions(p: Dictionary) -> void:
	if p.has("factions") and p["factions"].size() == 2:
		return
	var ax: String = PartyGen.dominant_axis(p["positions"])[0]
	var pos: int = p["positions"][ax]
	p["faction_axis"] = ax
	p["factions"] = [
		{"pole": clampi(pos - 12 * S, -100 * S, 100 * S), "strength": 500, "discontent": 30, "high_months": 0},
		{"pole": clampi(pos + 12 * S, -100 * S, 100 * S), "strength": 500, "discontent": 30, "high_months": 0},
	]


static func faction_strength(f: Dictionary) -> float:
	return float(f["strength"]) / 1000.0


## Monthly discontent: platform far from the faction's pole, coalition compromises, poll losses, lost credibility.
static func factions_monthly(world: WorldState, st: Dictionary) -> void:
	var g: Dictionary = st.get("government", {})
	var poll: Dictionary = world.peek("poll").get(st.get("last_poll", ""), {}).get("estimates", {})
	for p in active(world):
		ensure_factions(p)
		var ax: String = p["faction_axis"]
		var drop := maxf(0.0, (float(p["support"]) - float(poll.get(p["id"], p["support"]))) / 1000.0)
		for i in 2:
			var f: Dictionary = p["factions"][i]
			var gap := absf(float(p["positions"][ax] - int(f["pole"]))) / 1000.0
			var gov_gap := 0.0
			if p["id"] in g.get("members", []) and g.has("center"):
				gov_gap = absf(float(int(g["center"][ax]) - int(f["pole"]))) / 1000.0
			var lead := -10.0 if int(p["leader"]["faction"]) == i else 8.0
			var target := clampf(gap + 0.5 * gov_gap + 3.0 * drop + lead + (50.0 - float(p["credibility"])) * 0.3, 0.0, 100.0)
			f["discontent"] = int(round(0.92 * float(f["discontent"]) + 0.08 * target))
			f["high_months"] = int(f.get("high_months", 0)) + 1 if int(f["discontent"]) >= SPLIT_DISCONTENT else 0


# ======================================================================= lifecycle helpers

static func active(world: WorldState) -> Array:
	var ids: Array = world.table("party").keys()
	ids.sort()
	var out: Array = []
	for pid in ids:
		if world.table("party")[pid]["status"] == "ACTIVE":
			out.append(world.table("party")[pid])
	return out


static func lifecycle(st: Dictionary) -> Dictionary:
	if not st.has("lifecycle"):
		st["lifecycle"] = {"last_founding": -99, "last_split": -99, "issue_months": {}, "contest_due": {}, "approval_hist": []}
	return st["lifecycle"]


static func _taken_names(world: WorldState) -> Dictionary:
	var taken := {}
	for p in world.table("party").values():
		taken[p["name"]] = true
	return taken


static func _new_party(world: WorldState, st: Dictionary, pos: Dictionary, kind: String, name_override: String = "", charisma_boost: int = 0) -> Dictionary:
	var taken := _taken_names(world)
	var nm := name_override if name_override != "" and not taken.has(name_override) else PartyGen.name_for(pos, taken)
	var np := PartyGen.make_party(world, pos, nm, false, world.table("party").size())
	np["kind"] = kind
	np["leader"] = make_leader(world, 0, charisma_boost)
	ensure_factions(np)
	open_account(world, np["id"])
	lifecycle(st)["last_founding"] = world.month
	return np


static func open_account(world: WorldState, pid: String) -> void:
	var acc := "party:" + pid
	if not world.ledger.has_account(acc):
		world.ledger.open_account(acc)


## Moves voters' habit (prev_share) from one party to another in every cell (fraction 0..1; side filter optional).
static func _move_loyalty(world: WorldState, from_pid: String, to_pid: String, frac: float, axis: String = "", side: int = 0, pivot: int = 0) -> void:
	for c in world.table("cell").values():
		var ps: Dictionary = c["prev_share"]
		var v: int = int(ps.get(from_pid, 0))
		if v <= 0:
			continue
		if axis != "":
			var on_side := (int(c["ideology"][axis]) >= pivot) == (side == 1)
			if not on_side:
				continue
		var mv := int(round(float(v) * frac))
		ps[from_pid] = v - mv
		ps[to_pid] = int(ps.get(to_pid, 0)) + mv


static func _nearest_party(world: WorldState, pos: Dictionary, exclude: String) -> String:
	var best := ""
	var bd := INF
	for q in active(world):
		if q["id"] == exclude:
			continue
		var d := VoteModel.distance(pos, q["positions"])
		if d < bd:
			bd = d
			best = q["id"]
	return best


static func _refresh_government(world: WorldState, st: Dictionary) -> void:
	var g: Dictionary = st.get("government", {})
	if g.is_empty():
		return
	var yes := 0
	for m in g["members"]:
		yes += int(world.table("party")[m]["seats"])
	g["yes"] = yes


# ======================================================================= founding

## Yearly + after elections. One founding at most per call; cooldown colony-wide.
static func check_foundings(world: WorldState, st: Dictionary) -> void:
	var lc := lifecycle(st)
	var parties := active(world)
	if world.month - int(lc["last_founding"]) < FOUNDING_COOLDOWN:
		return
	if _found_single_issue(world, st, parties):
		return
	if _found_populist(world, st, parties):
		return
	_found_unrepresented(world, st, parties)


static func _found_unrepresented(world: WorldState, st: Dictionary, parties: Array) -> bool:
	var far: Array = []
	var fp := 0.0
	var tp := 0.0
	for c in world.table("cell").values():
		tp += c["pop"]
		var best := INF
		for p in parties:
			best = minf(best, VoteModel.distance(c["ideology"], p["positions"]))
		if best > UNREP_DISTANCE:
			far.append(c)
			fp += c["pop"]
	if tp <= 0.0 or fp / tp < UNREP_SHARE:
		return false
	var pos := PolDefs.zero_axes()
	for c in far:
		for ax in PolDefs.AXES:
			pos[ax] += float(c["ideology"][ax]) * c["pop"]
	for ax in PolDefs.AXES:
		pos[ax] = int(round(pos[ax] / fp))
	var np := _new_party(world, st, pos, "UNREPRESENTED")
	_fact_founded(world, np, "UNREPRESENTED", {"share": int(fp / tp * 1000.0)})
	return true


## Anti-establishment party: governance dissatisfaction plus a run of unpopular governments.
static func _found_populist(world: WorldState, st: Dictionary, parties: Array) -> bool:
	for p in parties:
		if p.get("kind", "") == "POPULIST":
			return false
	var hist: Array = lifecycle(st)["approval_hist"]
	if hist.size() < 2:
		return false
	var avg := (float(hist[-1]) + float(hist[-2])) / 2.0
	var gov_sat := _colony_sat(world, "GOVERNANCE")
	if gov_sat >= POPULIST_GOV_SAT or avg >= POPULIST_APPROVAL:
		return false
	# the disaffected: cells with the lowest approval (bottom quarter by population)
	var cells: Array = world.table("cell").values().filter(func(c): return c["pop"] > 0)
	cells.sort_custom(func(a, b): return a["approval"] < b["approval"] or (a["approval"] == b["approval"] and a["key"] < b["key"]))
	var tp := 0.0
	for c in cells:
		tp += c["pop"]
	var pos := PolDefs.zero_axes()
	var acc := 0.0
	for c in cells:
		if acc >= tp * 0.25:
			break
		acc += c["pop"]
		for ax in PolDefs.AXES:
			pos[ax] += float(c["ideology"][ax]) * c["pop"]
	for ax in PolDefs.AXES:
		pos[ax] = int(round(pos[ax] / maxf(1.0, acc)))
	pos["INSTITUTIONS"] = clampi(pos["INSTITUTIONS"] - 35 * S, -100 * S, 100 * S)  # "strong leadership, drain the swamp"
	var np := _new_party(world, st, pos, "POPULIST", "People's Voice", 25)
	np["ownership"]["GOVERNANCE"] = 90
	np["ownership"]["FAIRNESS"] = maxi(int(np["ownership"].get("FAIRNESS", 0)), 70)
	_fact_founded(world, np, "POPULIST", {"approval": int(avg), "governance": gov_sat})
	return true


## Single-issue party: a concern badly unmet for ISSUE_MONTHS that no party owns credibly.
static func _found_single_issue(world: WorldState, st: Dictionary, parties: Array) -> bool:
	var im: Dictionary = lifecycle(st)["issue_months"]
	for c in PolDefs.CONCERNS:
		if int(im.get(c, 0)) < ISSUE_MONTHS:
			continue
		var owned := false
		for p in parties:
			if int(p["ownership"].get(c, 0)) >= SINGLE_ISSUE_OWNERSHIP:
				owned = true
		im[c] = 0
		if owned:
			continue
		# the people who care most: salience-weighted mean ideology
		var pos := PolDefs.zero_axes()
		var w := 0.0
		for cell in world.table("cell").values():
			var s := float(cell["pop"]) * pow(float(cell["salience"][c]) / 111.0, 2.0)
			w += s
			for ax in PolDefs.AXES:
				pos[ax] += float(cell["ideology"][ax]) * s
		for ax in PolDefs.AXES:
			pos[ax] = int(round(pos[ax] / maxf(1.0, w)))
		for ax in PolDefs.CONCERN_PULL[c]:
			pos[ax] = clampi(pos[ax] + 25 * S, -100 * S, 100 * S)
		var np := _new_party(world, st, pos, "SINGLE_ISSUE", ISSUE_NAMES.get(c, ""))
		np["ownership"][c] = SINGLE_ISSUE_OWNERSHIP
		_fact_founded(world, np, "SINGLE_ISSUE", {"concern": c})
		return true
	return false


const ISSUE_NAMES := {
	"JOBS": "Work for All", "COST_OF_LIVING": "Fair Prices League", "HOUSING": "Homes Now",
	"PUBLIC_SERVICES": "Care & Schools Alliance", "SAFETY": "Safe Shifts Party", "ENVIRONMENT_QUALITY": "Clean Air Coalition",
	"INFRASTRUCTURE": "Roads & Power Party", "FAIRNESS": "Justice for All", "GOVERNANCE": "Clean Government List",
}


static func _fact_founded(world: WorldState, np: Dictionary, kind: String, data: Dictionary) -> void:
	var d := data.duplicate()
	d["party"] = np["id"]
	d["kind"] = kind
	world.add_fact({"type": "POL_PARTY_FOUNDED", "owner": "pol", "subjects": [{"kind": "PARTY", "id": np["id"]}],
		"responsible": [], "impact": {}, "magnitude": 60, "visibility": "PUBLIC", "data": d})


static func _colony_sat(world: WorldState, concern: String) -> int:
	var s := 0.0
	var p := 0.0
	for c in world.table("cell").values():
		s += float(c["sat"][concern]) * c["pop"]
		p += c["pop"]
	return int(round(s / p)) if p > 0.0 else 50000


## Monthly bookkeeping for founding triggers.
static func track_grievances(world: WorldState, st: Dictionary) -> void:
	var im: Dictionary = lifecycle(st)["issue_months"]
	for c in PolDefs.CONCERNS:
		im[c] = int(im.get(c, 0)) + 1 if _colony_sat(world, c) < ISSUE_SAT else 0
	if world.month_of_year() == 12 and not st.get("government", {}).is_empty():
		var h: Array = lifecycle(st)["approval_hist"]
		h.append(world.indicators.read("POL_GOV_APPROVAL"))
		if h.size() > 4:
			h.pop_front()


# ======================================================================= splits, mergers, dissolution

static func check_splits(world: WorldState, st: Dictionary) -> void:
	var lc := lifecycle(st)
	if world.month - int(lc["last_split"]) < SPLIT_COOLDOWN:
		return
	for p in active(world):
		if int(p["seats"]) < SPLIT_MIN_SEATS:
			continue
		for i in 2:
			var f: Dictionary = p["factions"][i]
			if i == int(p["leader"]["faction"]) or int(f["high_months"]) < SPLIT_MONTHS or faction_strength(f) < SPLIT_MIN_STRENGTH:
				continue
			split_party(world, st, p, i)
			return


static func split_party(world: WorldState, st: Dictionary, p: Dictionary, fi: int) -> Dictionary:
	var f: Dictionary = p["factions"][fi]
	var ax: String = p["faction_axis"]
	var pos: Dictionary = p["positions"].duplicate()
	pos[ax] = clampi(int(f["pole"]) + (int(f["pole"]) - int(p["positions"][ax])) / 2, -100 * S, 100 * S)
	var sgn := 1 if int(f["pole"]) >= int(p["positions"][ax]) else -1
	var np := _new_party(world, st, pos, "SPLINTER", PartyGen.name_for(pos, _taken_names(world), ax, sgn))
	np["leader"]["faction"] = 0
	var mps := int(round(float(p["seats"]) * faction_strength(f) * SPLINTER_SEAT_SHARE))
	p["seats"] = int(p["seats"]) - mps
	np["seats"] = mps
	np["support"] = int(round(float(p["support"]) * faction_strength(f) * 0.5))
	p["support"] = int(p["support"]) - int(np["support"])
	_move_loyalty(world, p["id"], np["id"], 0.6, ax, fi, int(p["positions"][ax]))
	# the remaining party is now its other faction
	p["credibility"] = maxi(0, int(p["credibility"]) - 10)
	np["credibility"] = 45
	f["discontent"] = 30
	f["high_months"] = 0
	f["strength"] = 150
	p["factions"][1 - fi]["strength"] = 850
	lifecycle(st)["last_split"] = world.month
	_refresh_government(world, st)
	world.add_fact({"type": "POL_PARTY_SPLIT", "owner": "pol", "subjects": [{"kind": "PARTY", "id": p["id"]}, {"kind": "PARTY", "id": np["id"]}],
		"responsible": [{"actor": {"kind": "PARTY", "id": p["id"]}, "share": 1.0}], "impact": {"GOVERNANCE": -3}, "magnitude": 70,
		"visibility": "PUBLIC", "data": {"party": p["id"], "splinter": np["id"], "mps": mps, "axis": ax}})
	return np


## Quarterly, after the poll: small parties close to a bigger one merge into it.
static func check_mergers(world: WorldState, st: Dictionary) -> void:
	var polls: Array = []
	for pid in world.peek("poll"):
		polls.append(world.peek("poll")[pid])
	polls.sort_custom(func(a, b): return a["month"] > b["month"] or (a["month"] == b["month"] and a["id"] > b["id"]))
	if polls.size() < 2:
		return
	var parties := active(world)
	for small in parties:
		if small["is_player"] or world.month - int(small["founded_month"]) < NEW_PARTY_GRACE:
			continue  # a new or breakaway party gets time to prove itself before it can be absorbed
		var e0: int = int(polls[0]["estimates"].get(small["id"], 0))
		var e1: int = int(polls[1]["estimates"].get(small["id"], 0))
		if e0 >= THRESHOLD or e1 >= THRESHOLD:
			continue
		var best := ""
		var bd := INF
		for big in parties:
			if big["id"] == small["id"]:
				continue
			var d := VoteModel.distance(small["positions"], big["positions"])
			if d < bd and int(polls[0]["estimates"].get(big["id"], 0)) > e0:
				bd = d
				best = big["id"]
		if best != "" and bd <= MERGE_DISTANCE:
			merge(world, st, world.table("party")[best], small)
			return


static func merge(world: WorldState, st: Dictionary, big: Dictionary, small: Dictionary) -> void:
	var wb := maxf(1.0, float(big["support"]))
	var ws := maxf(1.0, float(small["support"]))
	if not big["is_player"]:
		for ax in PolDefs.AXES:
			big["positions"][ax] = int(round((float(big["positions"][ax]) * wb + float(small["positions"][ax]) * ws) / (wb + ws)))
		big["commitments"] = PartyGen.commitments(big["positions"], world.lever_defs)
	for c in small["ownership"]:
		big["ownership"][c] = maxi(int(big["ownership"].get(c, 0)), int(small["ownership"][c]) - 10)
	big["seats"] = int(big["seats"]) + int(small["seats"])
	big["support"] = int(big["support"]) + int(small["support"])
	_move_loyalty(world, small["id"], big["id"], 1.0)
	_transfer_funds(world, small["id"], big["id"])
	small["seats"] = 0
	small["status"] = "MERGED"
	small["merged_into"] = big["id"]
	var g: Dictionary = st.get("government", {})
	if not g.is_empty() and small["id"] in g["members"]:
		g["members"].erase(small["id"])
		if not (big["id"] in g["members"]):
			g["members"].append(big["id"])
	_refresh_government(world, st)
	world.add_fact({"type": "POL_PARTIES_MERGED", "owner": "pol", "subjects": [{"kind": "PARTY", "id": big["id"]}, {"kind": "PARTY", "id": small["id"]}],
		"responsible": [], "impact": {}, "magnitude": 55, "visibility": "PUBLIC", "data": {"into": big["id"], "absorbed": small["id"]}})


## Quarterly (poll) and at elections: a party below 0.1% of the vote for 3 years running is wound up;
## its voters' habits and its money go to the nearest party. No cap on the number of parties.
## shares: {party_id: per-100000 share} from the latest poll or election.
static func check_dissolutions(world: WorldState, st: Dictionary, shares: Dictionary) -> void:
	for p in active(world):
		if p["is_player"]:
			continue
		if int(shares.get(p["id"], 0)) >= DEAD_SHARE:
			p["low_since"] = -1
			continue
		if int(p.get("low_since", -1)) < 0:
			p["low_since"] = world.month
		if world.month - int(p["low_since"]) < DEAD_MONTHS:
			continue
		var heir := _nearest_party(world, p["positions"], p["id"])
		p["status"] = "DISSOLVED"
		p["seats"] = 0
		if heir != "":
			_move_loyalty(world, p["id"], heir, 1.0)
			_transfer_funds(world, p["id"], heir)
		var g: Dictionary = st.get("government", {})
		if not g.is_empty() and p["id"] in g["members"]:
			g["members"].erase(p["id"])
			_refresh_government(world, st)
		world.add_fact({"type": "POL_PARTY_DISSOLVED", "owner": "pol", "subjects": [{"kind": "PARTY", "id": p["id"]}],
			"responsible": [], "impact": {}, "magnitude": 45, "visibility": "PUBLIC", "data": {"party": p["id"], "heir": heir}})


## Latest poll's estimates {party_id: per-100000}.
static func latest_poll_shares(world: WorldState) -> Dictionary:
	var best: Dictionary = {}
	for pid in world.peek("poll"):
		var q: Dictionary = world.peek("poll")[pid]
		if best.is_empty() or q["month"] > best["month"] or (q["month"] == best["month"] and q["id"] > best["id"]):
			best = q
	return best.get("estimates", {})


## After an election: losers and scandal-hit parties hold contests; long-serving leaders may retire.
static func post_election_contests(world: WorldState, st: Dictionary, before: Dictionary) -> void:
	var lc := lifecycle(st)
	var r := world.rng.stream("pol.leaders")
	for p in active(world):
		var reason := ""
		if before.has(p["id"]) and int(before[p["id"]]) - int(p["support"]) >= CONTEST_SUPPORT_DROP:
			reason = "ELECTION_LOSS"
		elif world.month - int(p["leader"]["since"]) >= 96 and r.randf() < 0.4:
			reason = "RETIREMENT"
		if reason != "":
			leadership_contest(world, st, p, reason)
	for pid in lc["contest_due"].keys():
		lc["contest_due"].erase(pid)


## Monthly: scandal-triggered contests between elections.
static func pending_contests(world: WorldState, st: Dictionary) -> void:
	var lc := lifecycle(st)
	for pid in lc["contest_due"].keys():
		var p: Dictionary = world.table("party").get(pid, {})
		if not p.is_empty() and p["status"] == "ACTIVE":
			leadership_contest(world, st, p, String(lc["contest_due"][pid]))
		lc["contest_due"].erase(pid)


# ======================================================================= money & campaigns

static func _transfer_funds(world: WorldState, from_pid: String, to_pid: String) -> void:
	var a := "party:" + from_pid
	var b := "party:" + to_pid
	if world.ledger.has_account(a) and world.ledger.has_account(b) and world.ledger.balance(a) > 0:
		world.ledger.transfer(a, b, world.ledger.balance(a), "PARTY_MERGER", world.month)


## Monthly: membership dues (from members' private means, outside the modelled economy).
## Public party funding is paid by law (a9, JUSTICE phase); company donations below.
static func funds_monthly(world: WorldState, st: Dictionary) -> void:
	for p in active(world):
		open_account(world, p["id"])
		var acc: String = "party:" + p["id"]
		var dues := int(round(float(p["support"]) / 1000.0 * float(DUES_PER_SUPPORT_POINT)))
		if dues > 0:
			world.ledger.transfer(Ledger.EXTERNAL, acc, dues, "PARTY_DUES", world.month)
	_book_donations(world)


const LQ := preload("res://sim/law/law_query.gd")
const DONATION_MIN_FIT := 10.0   # points of alignment before a company backs a party

## Company donation offers (88: table donation_offer, written in SETTLEMENT) go to the seated party that best
## matches the donor's political exposure. Law (a9) decides what is legal and what must be disclosed:
##   legal + disclosed  -> PUBLIC POL_DONATION
##   legal, below threshold -> SECRET (lawful)
##   over the cap / disclosure required -> the party takes it secretly only if its leader's integrity allows
## Secret illegal gifts are what a9's leaks, tips and investigations turn into scandals.
static func _book_donations(world: WorldState) -> void:
	var offers: Dictionary = world.peek("donation_offer")
	if offers.is_empty():
		return
	var ids: Array = offers.keys()
	ids.sort()
	var r := world.rng.stream("pol.donations")
	var parties := active(world).filter(func(q): return int(q["seats"]) > 0)
	for oid in ids:
		var o: Dictionary = offers[oid]
		if int(o.get("month", world.month)) != world.month:
			continue
		var best: Dictionary = {}
		var best_fit := DONATION_MIN_FIT
		for q in parties:
			var fit := 0.0
			for ax in o.get("prefers", {}):
				fit += float(o["prefers"][ax]) * float(q["positions"][ax]) / 1000.0
			if fit > best_fit:
				best_fit = fit
				best = q
		if best.is_empty():
			continue
		var amount: int = int(o["amount_milli"])
		var chk: Dictionary = LQ.donation_allowed(world, amount, o["from"])
		# careful donors stay 10% under the cap: it is set in W_ref, which drifts between booking and audit
		var cap: int = int(chk.get("cap", -1))
		if chk.get("ok", true) and cap >= 0 and int(chk.get("given", 0)) + amount > cap * 9 / 10:
			amount = cap * 9 / 10 - int(chk.get("given", 0))
			if amount <= 0:
				continue
			chk = LQ.donation_allowed(world, amount, o["from"])
		var integrity := float(best["leader"]["integrity"])
		var vis := "SECRET"
		if not chk.get("ok", true):
			# most donors give what the law allows; a few parties take the rest under the table
			var room: int = int(chk.get("remaining", 0)) - maxi(0, cap) / 10
			if r.randf() < (100.0 - integrity) / 800.0:
				pass  # the full, illegal amount, secretly
			elif room > 0:
				amount = room
				chk = LQ.donation_allowed(world, amount, o["from"])
				vis = "PUBLIC" if chk.get("disclose", false) else "SECRET"
			else:
				continue
		elif chk.get("disclose", false):
			# required to disclose: honest parties do; a few hide it
			vis = "SECRET" if r.randf() < (100.0 - integrity) / 800.0 else "PUBLIC"
		if not world.ledger.transfer(EconUtil.acct(String(o["from"])), "party:" + best["id"], amount, "DONATION", world.month):
			continue  # the offer lapsed (cash gone)
		world.add_fact({"type": "POL_DONATION", "owner": "pol",
			"subjects": [{"kind": "PARTY", "id": best["id"]}, {"kind": "COMPANY", "id": o["from"]}],
			"responsible": [{"actor": {"kind": "PARTY", "id": best["id"]}, "share": 1.0}], "impact": {},
			"magnitude": 20, "visibility": vis,
			"data": {"donor": o["from"], "party": best["id"], "amount": amount, "lawful": chk.get("ok", true) and not (vis == "SECRET" and chk.get("disclose", false)), "cap": int(chk.get("cap", -1))}})


## Interest-group endorsements for the vote model:
##   unions (88: ECON_UNION_DENSITY per occupation) back the most pro-labour seated party;
##   the business federation backs the most pro-market seated party among business owners.
static func endorsements(world: WorldState) -> Dictionary:
	var labor := ""
	var market := ""
	for q in active(world):
		if int(q["support"]) < THRESHOLD:
			continue
		if labor == "" or int(q["positions"]["LABOR"]) > int(world.table("party")[labor]["positions"]["LABOR"]):
			labor = q["id"]
		if market == "" or int(q["positions"]["ECON_ROLE"]) < int(world.table("party")[market]["positions"]["ECON_ROLE"]):
			market = q["id"]
	var dens := {}
	if world.indicators.defs.has("ECON_UNION_DENSITY"):
		for occ in world.indicators.values["ECON_UNION_DENSITY"]:
			dens[occ] = world.indicators.read("ECON_UNION_DENSITY", occ)
	return {"union": labor, "business": market, "density": dens}


## {party_id: utility bonus} for one cell.
static func endorsement_bonus(cell: Dictionary, e: Dictionary) -> Dictionary:
	var out := {}
	if e.is_empty():
		return out
	var d := float(e["density"].get(cell["occ"], 0)) / 100000.0
	if e["union"] != "" and d > 0.0:
		out[e["union"]] = UNION_ENDORSE_BETA * d
	if e["business"] != "" and cell["occ"] == "BUSINESS_OWNER":
		out[e["business"]] = float(out.get(e["business"], 0.0)) + BUSINESS_ENDORSE_BETA
	return out


## Campaign strength per party for the vote model (ctx.campaign): relative spending in the campaign window.
## Spending happens monthly in the window: each party spends 30% of its funds.
static func campaign_monthly(world: WorldState, st: Dictionary) -> void:
	var to_go := int(st["next_election"]) - world.month
	var spent: Dictionary = st.get("campaign_spent", {})
	if to_go > CAMPAIGN_MONTHS or to_go < 0:
		if not spent.is_empty() and to_go > CAMPAIGN_MONTHS:
			st["campaign_spent"] = {}
		return
	for p in active(world):
		var acc: String = "party:" + p["id"]
		if not world.ledger.has_account(acc):
			continue
		var amt := world.ledger.balance(acc) * 3 / 10
		if amt > 0:
			world.ledger.transfer(acc, Ledger.EXTERNAL, amt, "CAMPAIGN", world.month)
			spent[p["id"]] = int(spent.get(p["id"], 0)) + amt
	st["campaign_spent"] = spent


## {party_id: 0..1} campaign effect: spending relative to the average party, capped.
static func campaign_ctx(world: WorldState, st: Dictionary) -> Dictionary:
	var spent: Dictionary = st.get("campaign_spent", {})
	if spent.is_empty():
		return {}
	var tot := 0.0
	var n := 0
	for p in active(world):
		tot += float(spent.get(p["id"], 0))
		n += 1
	var avg := tot / maxf(1.0, float(n))
	var out := {}
	if avg <= 0.0:
		return out
	for p in active(world):
		out[p["id"]] = clampf(float(spent.get(p["id"], 0)) / avg, 0.0, 2.0) * 0.5 - 0.5
	return out

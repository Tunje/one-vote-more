class_name Rivalry
extends RefCounted
## Rivalries and grudges between parties (user 2026-11-15: "Rivalries is the answer. Parties with opposite positions
## become rivals, they will target each other even if they are not governing. Parties should start developing grudges
## depending on who votes against them in the colonial parliament, and when not in Cabinet, opposing parties can go
## out and question decisions.").
## Opt-in: flag RIVALRY. Without it nothing is written and every query returns 0 / "".
##
## - opposition_pm(a, b): how far apart two parties stand, 0..1000, from their positions on every axis. Pure.
## - grudge(a, b): what a holds against b, 0..1000, kept in pol.state["grudge"]["a>b"]. It grows when b votes NO on a
##   bill of a's government (more when b sits in that government: a betrayal), a little when a is outvoted by b's
##   government, and when b questions a's decisions in public; it fades every month, faster after a YES.
## - score(a, b): rivalry of a toward b, 0..1000 = OPP_W × opposition + GRUDGE_W × grudge.
## - main_rival(a): the active party a's rivalry is strongest toward. The campaign aims there (Ella's Campaign.pick_target).
## - monthly: opposition parties question this month's government decisions; the fact POL_DECISION_QUESTIONED names
##   the party, the decision and its district. The harder the rivalry toward the First Minister's party, the likelier.

const FLAG := "RIVALRY"
const OPP_W := 0.6
const GRUDGE_W := 0.4
const OPP_FULL := 60000             # mean distance per axis (positions run -100000..100000) that counts as full opposition
const G_NO := 40                    # an opposition party votes NO on our government's bill
const G_BETRAYAL := 120             # a party in our own government votes NO
const G_OUTVOTED := 15              # our NO was overridden: held against the sponsor
const G_YES := -25                  # they voted with us
const G_QUESTIONED := 20            # they questioned our decision in public
const DECAY_PM := 30                # a grudge loses this permille of itself a month
const QUESTION_P := 0.5             # chance a month at full rivalry, when there is a decision to question
const QUESTIONS_MAX := 2            # parties questioning in one month
## government decisions the opposition can question (fact types), and how tempting each is
const QUESTIONABLE := {"POL_PROJECT_ORDERED": 1.0, "POL_ROAD_PATCHED": 2.5, "POL_ROAD_PASSED_OVER": 2.5, "POL_GRANT_COVERAGE": 1.5, "POL_GRANT_FAVOURITISM": 3.0,
	"POL_GRANT_PROGRAMME_FAILED": 3.0, "POL_WILDLIFE_OUTCRY": 2.0, "POL_BIRDS_MISSED": 1.0,
	"LAW_TAKEOVER_OVERRIDDEN": 2.5, "LAW_EMERGENCY_DECLARED": 1.5,
	"LAW_ROAD_OBJECTION_OVERRIDDEN": 2.0, "LAW_ROAD_REFUSAL_UNGROUNDED": 2.0, "LAW_ROAD_LICENCE_QUASHED": 2.5, "LAW_PRIVATE_ROAD_UNENFORCED": 2.0,
	"LAW_ROAD_TAKEN_OVER": 2.0, "LAW_ROAD_STEP_IN": 1.0, "ECON_PUBLIC_QUOTE_REFUSED": 1.0,
	"ECON_GRANT_FIRM_FAILED": 3.0}   # a family firm the government paid for has failed   # Anni: the minister overrode the competition authority; an emergency unlocks direct awards


static func on(world: WorldState) -> bool:
	return (world.meta.get("on", []) as Array).has(FLAG)


static func opposition_pm(a: Dictionary, b: Dictionary) -> int:
	var pa: Dictionary = a.get("positions", {})
	var pb: Dictionary = b.get("positions", {})
	var sum := 0
	for ax in PolDefs.AXES:
		sum += absi(int(pa.get(ax, 0)) - int(pb.get(ax, 0)))
	return clampi(sum / PolDefs.AXES.size() * 1000 / OPP_FULL, 0, 1000)


static func grudge(world: WorldState, a: String, b: String) -> int:
	if not on(world):
		return 0
	return int((world.peek("pol").get("state", {}) as Dictionary).get("grudge", {}).get(a + ">" + b, 0))


static func score(world: WorldState, a: String, b: String) -> int:
	if not on(world) or a == b:
		return 0
	var parties: Dictionary = world.peek("party")
	if not parties.has(a) or not parties.has(b):
		return 0
	return int(OPP_W * float(opposition_pm(parties[a], parties[b])) + GRUDGE_W * float(grudge(world, a, b)))


## Active parties with seats or support, by a's rivalry toward them, strongest first: [[party id, score], ...]. Pure.
static func rivals(world: WorldState, a: String) -> Array:
	var out: Array = []
	if not on(world):
		return out
	var parties: Dictionary = world.peek("party")
	for b in EconUtil.sorted_keys(parties):
		if String(b) == a or String(parties[b].get("status", "")) != "ACTIVE":
			continue
		out.append([String(b), score(world, a, String(b))])
	out.sort_custom(func(x, y): return x[1] > y[1] or (x[1] == y[1] and x[0] < y[0]))
	return out


static func main_rival(world: WorldState, a: String) -> String:
	var r := rivals(world, a)
	return "" if r.is_empty() or int(r[0][1]) <= 0 else String(r[0][0])


static func _add(st: Dictionary, a: String, b: String, by: int) -> void:
	if a == b or a == "" or b == "":
		return
	var g: Dictionary = st.get("grudge", {})
	var k := a + ">" + b
	var v := clampi(int(g.get(k, 0)) + by, 0, 1000)
	if v <= 0:
		g.erase(k)
	else:
		g[k] = v
	st["grudge"] = g


## A bill was voted on (Legislature.submit_bill): the government's parties remember who voted against them.
static func on_vote(world: WorldState, bill: Dictionary, gov: Dictionary) -> void:
	if not on(world):
		return
	var st: Dictionary = world.table("pol")["state"]
	var members: Array = gov.get("members", [])
	var votes: Dictionary = bill.get("votes", {})
	var passed := String(bill.get("status", "")) == "PASSED"
	for pid in EconUtil.sorted_keys(votes):
		var v := String(votes[pid])
		var inside := members.has(pid)
		for m in members:
			if String(m) == String(pid):
				continue
			if v == "NO":
				_add(st, String(m), String(pid), G_BETRAYAL if inside else G_NO)
				if passed and not inside:
					_add(st, String(pid), String(m), G_OUTVOTED)
			elif v == "YES" and not inside:
				_add(st, String(m), String(pid), G_YES)


static func monthly(world: WorldState, st: Dictionary) -> void:
	if not on(world):
		return
	var g: Dictionary = st.get("grudge", {})
	for k in EconUtil.sorted_keys(g):
		var v := int(g[k]) - maxi(1, int(g[k]) * DECAY_PM / 1000)
		if v <= 0:
			g.erase(k)
		else:
			g[k] = v
	st["grudge"] = g
	_question(world, st)


## Opposition parties go out and question what the government decided this month.
static func _question(world: WorldState, st: Dictionary) -> void:
	var gov: Dictionary = st.get("government", {})
	var pm := String(gov.get("pm_party", ""))
	if pm == "" or st.get("era", "") == "FOUNDING":
		return
	var members: Array = gov.get("members", [])
	var decisions: Array = []
	for f in world.facts.query("", world.month, world.month, "PUBLIC"):
		if QUESTIONABLE.has(String(f["type"])):
			decisions.append(f)
	if decisions.is_empty():
		return
	var rng: RandomNumberGenerator = world.rng.stream("pol.rivalry")
	var asked := 0
	var parties: Dictionary = world.table("party")
	var order: Array = []
	for pid in EconUtil.sorted_keys(parties):
		var p: Dictionary = parties[pid]
		if members.has(pid) or String(p.get("status", "")) != "ACTIVE" or int(p.get("seats", 0)) <= 0:
			continue
		order.append([String(pid), score(world, String(pid), pm)])
	order.sort_custom(func(x, y): return x[1] > y[1] or (x[1] == y[1] and x[0] < y[0]))
	for o in order:
		if asked >= QUESTIONS_MAX:
			break
		if rng.randf() >= QUESTION_P * float(o[1]) / 1000.0:
			continue
		# the most tempting decision of the month (ties: the first)
		var best: Dictionary = decisions[0]
		for f in decisions:
			if float(QUESTIONABLE[String(f["type"])]) > float(QUESTIONABLE[String(best["type"])]):
				best = f
		decisions.erase(best)
		asked += 1
		_add(st, pm, String(o[0]), G_QUESTIONED)
		world.add_fact({"type": "POL_DECISION_QUESTIONED", "owner": "pol", "subjects": [{"kind": "PARTY", "id": String(o[0])}, {"kind": "PARTY", "id": pm}],
			"responsible": [{"actor": {"kind": "GOVERNMENT", "id": "government"}, "share": 1.0}], "impact": {}, "magnitude": 20 + int(10.0 * float(QUESTIONABLE[String(best["type"])])),
			"visibility": "PUBLIC", "causes": [best["id"]] if best.has("id") else [],
			"data": {"by": String(o[0]), "against": pm, "about": String(best["type"]), "district": String((best.get("data", {}) as Dictionary).get("district", "")),
				"rivalry": int(o[1])}})
		if decisions.is_empty():
			break

class_name HomeWorld
extends RefCounted
## M12: the home world as an off-planet actor, and the colony's politics of the charter
## (planning/spec-colony-v1.md §6–§8; law side: a9, charter_ops.gd; ships and cargo: 88).
##
## The home world has:
##   need       0..100  how badly it wants colonial goods (random walk with occasional jumps: war, shortage, a new ruler)
##   patience   0..100  how much defiance it tolerates before it escalates
##   loyalty    0..100  how loyal it believes the colony is
##   legitimacy 0..100  how lawful and fair its rule looks (unlawful sanctions, broken petitions cost it)
## It acts only when a ship arrives (88's ECON_SHIP_ARRIVED; until 88's ships exist, its own 18–30-month clock):
## inspect, sanction evasion or defiance, answer petitions, raise its demands, respond to a declaration of independence,
## resolve a punitive expedition.
## The colony side (AI governments): petition for better terms, refuse the quota, declare independence
## (2/3 of parliament, then a referendum), all driven by the SOVEREIGNTY axis and the COLONIAL_BURDEN concern.
## Stateless; state in pol.state["home"].

const CO := preload("res://sim/law/charter_ops.gd")
const LQ := preload("res://sim/law/law_query.gd")
const S := 1000

const SHIP_MIN := 18
const SHIP_MAX := 30
const PETITION_GAP := 24          # months between petitions
const INDEPENDENCE_SEATS := 101
const REFERENDUM_DELAY := 2


# ======================================================================= state & reads

static func state(world: WorldState) -> Dictionary:
	var st: Dictionary = world.table("pol")["state"]
	if not st.has("home"):
		var r := world.rng.stream("pol.home")
		st["home"] = {"need": 40 + r.randi_range(0, 20), "patience": 70, "loyalty": 70, "legitimacy": 70,
			"next_ship": SHIP_MIN + r.randi_range(0, SHIP_MAX - SHIP_MIN), "own_clock": true, "ships": 0,
			"expedition_month": -1, "last_petition": -99, "refused_month": -1, "rejected_petitions": 0,
			"referendum_month": -1, "log": []}
	return st["home"]


static func colonial(world: WorldState) -> bool:
	return String(LQ.sovereignty(world).get("status", "COLONY")) != "INDEPENDENT"


## Burden index (milli, 0..100000): quota share × price gap, governor, refusal sanctions. 0 when independent.
static func burden(world: WorldState) -> int:
	var sv: Dictionary = LQ.sovereignty(world)
	if String(sv.get("status", "COLONY")) == "INDEPENDENT":
		return 0
	var b := float(sv.get("quota_share", 40)) * (100.0 - float(sv.get("price_pct", 35))) / 100.0
	if sv.get("governor", false):
		b += 15.0
	b += 5.0 * float(world.facts.query("HOME_SANCTION", world.month - 24, world.month).size())
	return clampi(int(round(b * 1000.0)), 0, 100000)


## Colony-wide mean of the SOVEREIGNTY axis (points; + = independence).
static func colony_mood(world: WorldState) -> float:
	var s := 0.0
	var n := 0.0
	for c in PolVoters.all(world):
		s += float(c["ideology"].get("SOVEREIGNTY", 0)) * c["pop"]
		n += c["pop"]
	return s / maxf(1.0, n) / 1000.0


static func _note(world: WorldState, h: Dictionary, line: String) -> void:
	h["log"].append("m%d %s" % [world.month, line])
	if h["log"].size() > 60:
		h["log"].pop_front()


static func _fact(world: WorldState, type: String, data: Dictionary, mag: int, impact: Dictionary = {}) -> void:
	world.add_fact({"type": type, "owner": "pol", "subjects": [{"kind": "HOME_WORLD", "id": "home"}],
		"responsible": [{"actor": {"kind": "HOME_WORLD", "id": "home"}, "share": 1.0}], "impact": impact,
		"magnitude": mag, "visibility": "PUBLIC", "data": data})


# ======================================================================= monthly

static func monthly(world: WorldState, st: Dictionary) -> void:
	var h := state(world)
	var r := world.rng.stream("pol.home")
	# home-world politics: need wanders, sometimes jumps (war, shortage at home, a new ruler)
	h["need"] = clampi(int(h["need"]) + r.randi_range(-2, 2) + (r.randi_range(15, 30) if r.randf() < 0.01 else 0), 5, 100)
	h["patience"] = mini(100, int(h["patience"]) + 1)
	var ship := false
	for f in world.facts.query("ECON_SHIP_ARRIVED", world.month, world.month):
		ship = true
		h["own_clock"] = false
	if h["own_clock"] and world.month >= int(h["next_ship"]):
		ship = true
		h["next_ship"] = world.month + SHIP_MIN + r.randi_range(0, SHIP_MAX - SHIP_MIN)
		_fact(world, "HOME_SHIP_CALLED", {"own_clock": true}, 35)
	if ship:
		h["ships"] = int(h["ships"]) + 1
		_on_ship(world, st, h, r)
	if st.get("era", "") == "PARLIAMENTARY" and not st.get("government", {}).is_empty():
		_colony_politics(world, st, h, r)


# ======================================================================= the home world, on each ship

static func _on_ship(world: WorldState, st: Dictionary, h: Dictionary, r: RandomNumberGenerator) -> void:
	var sv: Dictionary = LQ.sovereignty(world)
	var status := String(sv["status"])
	if status == "INDEPENDENT":
		return
	# a punitive expedition sent earlier arrives
	if int(h["expedition_month"]) >= 0 and world.month >= int(h["expedition_month"]):
		_resolve_expedition(world, st, h, r)
		return
	if status == "INDEPENDENCE_DECLARED":
		_respond_to_independence(world, st, h, r)
		return
	# inspection: an eager home world inspects harder
	var found: Array = CO.home_inspection(world, clampi(30 + int(h["need"]) / 2, 0, 100))
	if not found.is_empty():
		h["loyalty"] = maxi(0, int(h["loyalty"]) - 10)
		h["patience"] = maxi(0, int(h["patience"]) - 10)
		var kind := "FINE" if int(h["patience"]) > 40 else "APPOINT_GOVERNOR"
		_sanction(world, h, kind, {"records": found.size()})
	# open defiance
	if bool(sv.get("refusal", false)):
		h["patience"] = maxi(0, int(h["patience"]) - 30)
		h["loyalty"] = maxi(0, int(h["loyalty"]) - 20)
		_sanction(world, h, "WITHHOLD", {})
		if int(h["patience"]) < 25 and not bool(sv.get("governor", false)):
			_sanction(world, h, "APPOINT_GOVERNOR", {})
		elif int(h["patience"]) < 10:
			_send_expedition(world, h, r)
	# petitions waiting for an answer
	for pid in sv.get("petitions", {}):
		var pt: Dictionary = sv["petitions"][pid]
		if String(pt.get("status", "")) != "SENT":
			continue
		_answer_petition(world, st, h, r, pid, pt)
	# rising demands: a needy home world tightens the charter (the "Stamp Act" moment)
	if int(h["need"]) > 65 and r.randf() < float(int(h["need"]) - 55) / 100.0:
		var share := int(sv.get("quota_share", 40))
		if share < 70 and r.randf() < 0.6:
			CO.home_world_amend(world, "LAW_CHARTER_QUOTA_SHARE", mini(70, share + 10))
		else:
			CO.home_world_amend(world, "LAW_CHARTER_PRICE_PCT", maxi(10, int(sv.get("price_pct", 35)) - 10))
		h["legitimacy"] = maxi(0, int(h["legitimacy"]) - 5)
		_fact(world, "HOME_DEMAND_RAISED", {"need": h["need"]}, 70, {"COLONIAL_BURDEN": -40, "GOVERNANCE": -5})
		_note(world, h, "raised its demands (need %d)" % h["need"])


static func _sanction(world: WorldState, h: Dictionary, kind: String, params: Dictionary) -> void:
	var res: Dictionary = CO.home_sanction(world, kind, params)
	if not res.get("lawful", true):
		h["legitimacy"] = maxi(0, int(h["legitimacy"]) - 15)
	_fact(world, "HOME_SANCTION", {"kind": kind, "lawful": res.get("lawful", true)}, 60, {"COLONIAL_BURDEN": -30})
	_note(world, h, "sanction %s (%s)" % [kind, "lawful" if res.get("lawful", true) else "UNLAWFUL"])


## Leverage of the colony: how much the home world needs it vs how strong and united it is.
static func leverage(world: WorldState, h: Dictionary) -> float:
	var unity := clampf(0.5 + colony_mood(world) / 100.0, 0.0, 1.0)
	var unemp := 0.0
	if world.indicators.values.has("ECON_UNEMPLOYMENT_RATE"):
		var v: Dictionary = world.indicators.values["ECON_UNEMPLOYMENT_RATE"]
		for k in v:
			unemp = maxf(unemp, float(v[k]) / 1000.0)
	var self_suff := clampf(1.0 - unemp / 40.0, 0.0, 1.0)
	return 0.35 * unity + 0.35 * self_suff + 0.3 * float(h["need"]) / 100.0


static func _answer_petition(world: WorldState, st: Dictionary, h: Dictionary, r: RandomNumberGenerator, pid: String, pt: Dictionary) -> void:
	var p_accept := clampf(leverage(world, h) * 0.8 + float(h["loyalty"]) / 250.0 - float(h["need"]) / 300.0, 0.05, 0.9)
	var accepted := r.randf() < p_accept
	var terms: Dictionary = {}
	if accepted:
		terms = pt.get("demands", {}).duplicate()
		h["legitimacy"] = mini(100, int(h["legitimacy"]) + 10)
	else:
		h["rejected_petitions"] = int(h["rejected_petitions"]) + 1
		h["legitimacy"] = maxi(0, int(h["legitimacy"]) - 5)
	CO.answer_petition(world, pid, accepted, terms)
	_note(world, h, "petition %s %s" % [pid, "accepted" if accepted else "rejected"])


static func _send_expedition(world: WorldState, h: Dictionary, r: RandomNumberGenerator) -> void:
	if int(h["expedition_month"]) >= 0:
		return
	var res: Dictionary = CO.home_sanction(world, "EXPEDITION", {})
	if not res.get("lawful", false):
		h["legitimacy"] = maxi(0, int(h["legitimacy"]) - 25)
	h["expedition_month"] = world.month + SHIP_MIN + r.randi_range(0, SHIP_MAX - SHIP_MIN)
	_fact(world, "HOME_EXPEDITION_SENT", {"arrives_after": h["expedition_month"], "lawful": res.get("lawful", false)}, 90,
		{"COLONIAL_BURDEN": -60, "SAFETY": -20})
	_note(world, h, "punitive expedition sent")


static func _respond_to_independence(world: WorldState, st: Dictionary, h: Dictionary, r: RandomNumberGenerator) -> void:
	var lev := leverage(world, h)
	var p_recognise := clampf(0.15 + 0.5 * (1.0 - float(h["need"]) / 100.0) + 0.3 * (1.0 - float(h["legitimacy"]) / 100.0) + 0.2 * (lev - 0.5), 0.05, 0.9)
	var x := r.randf()
	if x < p_recognise:
		CO.recognise_independence(world)
		_note(world, h, "recognised independence")
	elif int(h["patience"]) > 40 or x < p_recognise + 0.25:
		CO.grant_autonomy(world, {"LAW_CHARTER_QUOTA_SHARE": 20, "LAW_CHARTER_PRICE_PCT": 70})
		_note(world, h, "offered autonomy")
	else:
		_send_expedition(world, h, r)


## Abstract confrontation (no combat simulation): colony strength = self-sufficiency, unity, militia, distance;
## home strength = need and legitimacy.
static func _resolve_expedition(world: WorldState, st: Dictionary, h: Dictionary, r: RandomNumberGenerator) -> void:
	h["expedition_month"] = -1
	var sv: Dictionary = LQ.sovereignty(world)
	var militia := clampf(float(sv.get("militia", 0)) / 20.0, 0.0, 1.0)
	var colony := leverage(world, h) + 0.4 * militia + 0.25  # distance favours the colony
	var home := 0.5 + 0.5 * float(h["need"]) / 100.0 + 0.3 * float(h["legitimacy"]) / 100.0
	var roll := colony - home + r.randfn(0.0, 0.25)
	var outcome := ""
	if roll > 0.15:
		CO.recognise_independence(world)
		outcome = "COLONY_PREVAILED"
	elif roll > -0.15:
		CO.grant_autonomy(world, {"LAW_CHARTER_QUOTA_SHARE": 25, "LAW_CHARTER_PRICE_PCT": 60})
		outcome = "NEGOTIATED_AUTONOMY"
	else:
		CO.restore_charter(world, {"LAW_CHARTER_QUOTA_SHARE": 60, "LAW_CHARTER_PRICE_PCT": 20}, true)
		outcome = "CHARTER_RESTORED"
	_fact(world, "HOME_EXPEDITION_RESOLVED", {"outcome": outcome, "colony": snappedf(colony, 0.01), "home": snappedf(home, 0.01)}, 95,
		{"GOVERNANCE": -20 if outcome == "CHARTER_RESTORED" else 10})
	_note(world, h, "expedition: " + outcome)


# ======================================================================= the colony side (AI governments)

static func _colony_politics(world: WorldState, st: Dictionary, h: Dictionary, r: RandomNumberGenerator) -> void:
	var g: Dictionary = st["government"]
	if st.get("player_party", "") in g.get("members", []) and not st.get("autoplay_player", true):
		return  # a human government acts through the UI
	var sv: Dictionary = LQ.sovereignty(world)
	var status := String(sv["status"])
	if status == "INDEPENDENT":
		return
	var gov_sov := float(g["center"].get("SOVEREIGNTY", 0)) / 1000.0
	var mood := colony_mood(world)
	var bsat := _burden_sat(world)
	# referendum after a successful independence vote in parliament
	if int(h["referendum_month"]) >= 0 and world.month >= int(h["referendum_month"]):
		h["referendum_month"] = -1
		_referendum(world, st, h)
		return
	if status == "INDEPENDENCE_DECLARED":
		return
	# 1. petition for better terms
	if bsat < 50.0 and gov_sov > -15.0 and world.month - int(h["last_petition"]) >= PETITION_GAP:
		var demands := {"LAW_CHARTER_QUOTA_SHARE": maxi(10, int(sv.get("quota_share", 40)) - 10),
			"LAW_CHARTER_PRICE_PCT": mini(100, int(sv.get("price_pct", 35)) + 15)}
		if _parliament_vote(world, st, "PETITION", -15.0)["passed"]:
			CO.petition_home(world, demands)
			h["last_petition"] = world.month
		return
	# 2. open refusal after rejected petitions, by an independence-minded government
	if not bool(sv.get("refusal", false)) and gov_sov > 25.0 and int(h["rejected_petitions"]) >= 1 and bsat < 35.0:
		if _parliament_vote(world, st, "REFUSAL", 15.0)["passed"]:
			CO.refuse_quota(world)
			h["refused_month"] = world.month
		return
	# 3. independence: a strongly independence-minded government and a colony leaning that way
	if gov_sov > 35.0 and mood > 10.0 and (bool(sv.get("refusal", false)) or int(h["rejected_petitions"]) >= 2):
		var v := _parliament_vote(world, st, "INDEPENDENCE", 20.0)
		var rec: Dictionary = CO.record_independence_vote(world, int(v["yes"]))
		if rec.get("ok", false):
			h["referendum_month"] = world.month + REFERENDUM_DELAY


## Burden satisfaction 0..100 (colony mean of the COLONIAL_BURDEN concern).
static func _burden_sat(world: WorldState) -> float:
	var s := 0.0
	var n := 0.0
	for c in PolVoters.all(world):
		s += float(c["sat"].get("COLONIAL_BURDEN", 50000)) * c["pop"]
		n += c["pop"]
	return s / maxf(1.0, n) / 1000.0


## Parties vote by their SOVEREIGNTY position against a threshold (points). Government members follow the
## government unless they are far on the loyal side.
static func _parliament_vote(world: WorldState, st: Dictionary, what: String, threshold: float) -> Dictionary:
	var g: Dictionary = st["government"]
	var yes := 0
	var no := 0
	var votes := {}
	var ids: Array = world.table("party").keys()
	ids.sort()
	for pid in ids:
		var p: Dictionary = world.table("party")[pid]
		if p["status"] != "ACTIVE" or int(p["seats"]) == 0:
			continue
		var sov := float(p["positions"].get("SOVEREIGNTY", 0)) / 1000.0
		var member: bool = pid in g["members"]
		var y := sov >= threshold or (member and sov >= threshold - 25.0)
		votes[pid] = "YES" if y else "NO"
		if y:
			yes += int(p["seats"])
		else:
			no += int(p["seats"])
	var passed := yes > no if what != "INDEPENDENCE" else yes >= INDEPENDENCE_SEATS
	world.add_fact({"type": "POL_CHARTER_VOTE", "owner": "pol", "subjects": [], "responsible": [{"actor": {"kind": "GOVERNMENT", "id": "government"}, "share": 1.0}],
		"impact": {}, "magnitude": 70 if what == "INDEPENDENCE" else 50, "visibility": "PUBLIC",
		"data": {"what": what, "passed": passed, "yes": yes, "no": no, "votes": votes}})
	return {"passed": passed, "yes": yes, "no": no}


## Referendum on independence: each voter group votes by its SOVEREIGNTY lean (with turnout).
static func _referendum(world: WorldState, st: Dictionary, h: Dictionary) -> void:
	var yes := 0.0
	var no := 0.0
	var parties: Array = PartyLife.active(world)
	for c in PolVoters.all(world):
		if c["pop"] <= 0:
			continue
		var t := VoteModel.turnout(c, parties)
		var lean := float(c["ideology"].get("SOVEREIGNTY", 0)) / 1000.0
		var p_yes := 1.0 / (1.0 + exp(-lean / 12.0))
		yes += c["pop"] * t * p_yes
		no += c["pop"] * t * (1.0 - p_yes)
	var eligible: int = LQ.eligible_total(world, {}, world.month)
	if eligible <= 0:
		for c in PolVoters.all(world):
			eligible += int(c["pop"])
	var res: Dictionary = CO.declare_independence(world, int(round(yes)), int(round(no)), eligible)
	world.add_fact({"type": "POL_INDEPENDENCE_REFERENDUM", "owner": "pol", "subjects": [], "responsible": [],
		"impact": {}, "magnitude": 95, "visibility": "PUBLIC",
		"data": {"yes": int(round(yes)), "no": int(round(no)), "eligible": eligible, "declared": res.get("ok", false), "reason": res.get("reason", "")}})
	_note(world, h, "referendum: %d yes / %d no -> %s" % [int(yes), int(no), "DECLARED" if res.get("ok", false) else "failed"])

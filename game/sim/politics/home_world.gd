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
const Desk := preload("res://sim/office/decision_desk.gd")   # who decides, step 1 (flag DELEGATION): counts decisions

const SHIP_MIN := 18
const SHIP_MAX := 30
const PETITION_GAP := 24          # months between petitions
const INDEPENDENCE_SEATS := 101
const REFERENDUM_DELAY := 2
const REFERENDUM_RETRY_MONTHS := 48   # a failed referendum is not re-run for four years


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
	_shipping_pressure(world, h)
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
	_shipping(world, h, sv, r)
	# petitions waiting for an answer
	for pid in sv.get("petitions", {}):
		var pt: Dictionary = sv["petitions"][pid]
		if String(pt.get("status", "")) != "SENT":
			continue
		_answer_petition(world, st, h, r, pid, pt)
	# a prosperous export trade invites a cut (A42 D6): the home world claims an export levy, and when it is very
	# needy it reserves the colony's top export for its own charter buyer
	_export_claims(world, h, sv, r)
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


## v8 review: a party votes to refuse the home world's autonomy offer from this SOVEREIGNTY lean (government members
## from 25 lower, like the other charter votes); one offer per ship, at most AUTONOMY_OFFERS refusals.
const AUTONOMY_REFUSE_SOV := 30.0
const AUTONOMY_OFFERS := 2


static func _respond_to_independence(world: WorldState, st: Dictionary, h: Dictionary, r: RandomNumberGenerator) -> void:
	var lev := leverage(world, h)
	var p_recognise := clampf(0.15 + 0.5 * (1.0 - float(h["need"]) / 100.0) + 0.3 * (1.0 - float(h["legitimacy"]) / 100.0) + 0.2 * (lev - 0.5), 0.05, 0.9)
	var x := r.randf()
	if x < p_recognise:
		CO.recognise_independence(world)
		_note(world, h, "recognised independence")
	elif (int(h["patience"]) > 40 or x < p_recognise + 0.25) and int(h.get("autonomy_refused", 0)) < AUTONOMY_OFFERS:
		# v8 review: autonomy after a declaration is an OFFER the colony's parliament can refuse (was imposed outright,
		# reversing a declared independence twice in v8 seed 2). Refused: the declaration stands and the home world
		# answers on a later ship (recognition or an expedition); after AUTONOMY_OFFERS refusals it stops offering.
		var v := _parliament_vote(world, st, "REFUSE_AUTONOMY", AUTONOMY_REFUSE_SOV)
		if v["passed"]:
			h["autonomy_refused"] = int(h.get("autonomy_refused", 0)) + 1
			h["legitimacy"] = maxi(0, int(h["legitimacy"]) - 5)
			_fact(world, "HOME_AUTONOMY_REFUSED", {"yes": v["yes"], "no": v["no"]}, 85, {})
			_note(world, h, "autonomy offer refused")
		else:
			CO.grant_autonomy(world, {"LAW_CHARTER_QUOTA_SHARE": 20, "LAW_CHARTER_PRICE_PCT": 70})
			_note(world, h, "autonomy offered and accepted")
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
		h["last_referendum"] = world.month
		_referendum(world, st, h)
		return
	if int(h["referendum_month"]) >= 0:
		return   # v7 review: parliament has voted; wait for the referendum (was: re-voted monthly, pushing it back)
	if status == "INDEPENDENCE_DECLARED":
		return
	# 1. petition for better terms
	if bsat < 50.0 and gov_sov > -15.0 and world.month - int(h["last_petition"]) >= PETITION_GAP:
		var demands := {"LAW_CHARTER_QUOTA_SHARE": maxi(10, int(sv.get("quota_share", 40)) - 10),
			"LAW_CHARTER_PRICE_PCT": mini(100, int(sv.get("price_pct", 35)) + 15)}
		Desk.note(world, "CHARTER_PETITION")
		if _parliament_vote(world, st, "PETITION", -15.0)["passed"]:
			CO.petition_home(world, demands)
			h["last_petition"] = world.month
		return
	# 2. open refusal after rejected petitions, by an independence-minded government
	if not bool(sv.get("refusal", false)) and gov_sov > 25.0 and int(h["rejected_petitions"]) >= 1 and bsat < 35.0:
		Desk.note(world, "CHARTER_REFUSAL")
		if _parliament_vote(world, st, "REFUSAL", 15.0)["passed"]:
			CO.refuse_quota(world)
			h["refused_month"] = world.month
		return
	# 3. independence: a strongly independence-minded government and a colony leaning that way
	if gov_sov > 35.0 and mood > 10.0 and (bool(sv.get("refusal", false)) or int(h["rejected_petitions"]) >= 2) 			and world.month - int(h.get("last_referendum", -1000)) >= REFERENDUM_RETRY_MONTHS 			and world.month - int(h.get("last_indep_vote", -1000)) >= 12:
		h["last_indep_vote"] = world.month   # a failed vote waits a year
		Desk.note(world, "INDEPENDENCE_VOTE")
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

const LEVY_STEP := 5
const LEVY_MAX := 30
const EXPORT_RICH := 2000000   # credits of exports over 24 months that catch the home world's eye


## Export claims: when the colony's trade is rich and the home world needy, it raises the export levy a step (up to
## LEVY_MAX); a very needy home world with the levy already high reserves the top export good for its own buyer.
## Facts come from CharterOps (LAW_CHARTER_AMENDED, LAW_CHARTER_EXPORT_RESERVED); the colony may refuse the terms.
static func _export_claims(world: WorldState, h: Dictionary, sv: Dictionary, r: RandomNumberGenerator) -> void:
	if not world.table("econ").has("s") or bool(CO.export_terms(world, "MATERIAL").get("refusal", false)):
		return
	var exports := int(EconFace.trade_balance(world).get("exports_24m", 0)) / 1000
	if exports < EXPORT_RICH or int(h["need"]) < 50:
		return
	var levy := int(world.levers.get("LAW_CHARTER_EXPORT_LEVY", 0))
	var p := clampf(float(int(h["need"]) - 40) / 100.0 + float(exports) / float(EXPORT_RICH * 10), 0.0, 0.8)
	if r.randf() >= p:
		return
	if levy < LEVY_MAX:
		CO.home_world_amend(world, "LAW_CHARTER_EXPORT_LEVY", mini(LEVY_MAX, levy + LEVY_STEP))
		_note(world, h, "claimed a %d%% levy on colony exports" % mini(LEVY_MAX, levy + LEVY_STEP))
	elif int(h["need"]) > 80:
		var last: Dictionary = EconFace.trade_last_ship(world)
		var ex: Dictionary = last.get("exports", {})
		var top := ""
		for g in CoreUtil.sorted_keys(ex):
			if top == "" or int(ex[g]) > int(ex[top]):
				top = g
		if top != "":
			CO.home_world_reserve(world, top, true)
			_note(world, h, "reserved the colony's %s for its own buyer" % String(top).to_lower())


# ======================================================================= shipping (flag SHIPPING)
## The user, 2026-11-15: "The ship should be a political thing, the homeworld can build a bigger ship if it wants or get
## more ships remember the round trip is 2 years so two ships could take turns increasing the number of arrivals to once
## a year". 2026-11-16: "if they build a bigger ship, they will demand a higher price to pay it off for a while and once
## done the ship stays ... it can't increase how often the ship comes ... can build one more ... comes on its own
## interval". Ships are the home world's, not the colony's.
##   NO WORD WITHOUT A SHIP (the user, 2026-11-16: "They can't order when there's not a ship there to take the order
##     ... they have to ask for one when the ship is there, which means they have the full period of waiting every
##     time ... that ship's already left Earth and they have no way of sending a message to it"). The colony can ask
##     only while a ship is in port; that ship carries the request home, and the answer comes back with the same ship
##     on its next call. Another ship calling in between left home before the request arrived and knows nothing.
##   REQUEST: when a ship calls and cargo is left on the dock, or the port store was full since the last call, the
##     colony's government hands it a request for more shipping (HOME_SHIPPING_REQUESTED). One request is under way at
##     a time.
##   ANSWER, when that ship calls again: the home world has weighed its own interest (need for colonial goods, how loyal
##     it thinks the colony is, defiance) and either BUILT: the ship comes back larger, or one more ship joins, calling
##     on its own interval (EconTrade.fleet); or said no: HOME_SHIPPING_REFUSED (felt as colonial burden and lost jobs).
##   PAYING IT OFF: the home world takes a higher price for carrying the colony's goods (world.values HOME_TARIFF, a cut
##     on export income) until the ship's cost is covered; then the charge ends and the ship stays (HOME_SHIP_PAID_OFF).
##     It builds nothing more while a ship is being paid off.
## OPT-IN: world.meta["on"] has "SHIPPING"; off: nothing is written. The sizes below are Wilma's, not the user's.
const SHIP_HOLD_STEP := 1.5       # a larger ship carries this much more than the one it replaces
const SHIP_COST_PER_UNIT := 1500  # credits of building cost per unit of hold added
const SHIP_PAYOFF_PM := 200       # the higher price while a ship is paid off: permille of export income


static func shipping_on(world: WorldState) -> bool:
	return world.meta.has("on") and (world.meta["on"] as Array).has("SHIPPING") and not CoreUtil.off(world, "SHIPPING")


## Units waiting at the port (after a ship: what it left behind).
static func _dock_units(world: WorldState) -> int:
	return int(EconFace.trade_export_pressure(world)["left_total"])  # cargo the last ship left behind (Bob's ship records)


## Monthly: the colony only remembers that its port store was full. Nothing can be said to the home world until a ship
## is in port.
static func _shipping_pressure(world: WorldState, h: Dictionary) -> void:
	if not shipping_on(world) or not colonial(world) or not world.table("econ").has("s"):
		return
	if world.facts.query("ECON_PORT_FULL", world.month, world.month).is_empty():
		return
	h["ship_short"] = world.month


## The colony hands the ship now in port (fleet index idx) its request; the answer comes back with that ship.
static func _ask_shipping(world: WorldState, h: Dictionary, left: int, full: bool, idx: int) -> void:
	h["ship_ask"] = {"idx": idx, "m": world.month, "left": left}
	world.add_fact({"type": "HOME_SHIPPING_REQUESTED", "owner": "pol", "subjects": [{"kind": "HOME_WORLD", "id": "home"}],
		"responsible": [{"actor": {"kind": "GOVERNMENT", "id": "government"}, "share": 1.0}], "impact": {}, "magnitude": 40,
		"visibility": "PUBLIC", "data": {"left_on_dock": left, "port_full": full, "ships": 1 + EconFace.trade_fleet(world).size()}})
	_note(world, h, "the colony gave the ship its request for more shipping (%d units left, port full %s)" % [left, str(full)])


## On each ship: the pay-off of a ship under way; or the answer to a request this ship carried home on its last call; or
## a new request handed to it.
static func _shipping(world: WorldState, h: Dictionary, sv: Dictionary, r: RandomNumberGenerator) -> void:
	if not shipping_on(world) or not world.table("econ").has("s"):
		return
	var prev := int(h.get("ship_seen", -1))
	h["ship_seen"] = world.month
	# paying it off: what the higher price took from this ship's cargo
	if int(h.get("ship_debt", 0)) > 0:
		var t := EconFace.trade_home_tariff(world)
		var last: Dictionary = EconFace.trade_last_ship(world)
		if t > 0 and t < 1000 and int(last.get("month", -1)) == world.month:
			h["ship_debt"] = int(h["ship_debt"]) - int(last.get("export_value", 0)) / 1000 * t / (1000 - t)
		if int(h["ship_debt"]) <= 0:
			h.erase("ship_debt")
			world.values.erase("HOME_TARIFF")
			_fact(world, "HOME_SHIP_PAID_OFF", {"ships": 1 + EconFace.trade_fleet(world).size()}, 45, {"COLONIAL_BURDEN": 10})
			_note(world, h, "the new ship is paid off; the higher price ends")
		return
	var idx := int(CoreUtil.peek_st(world).get("ship_idx", 0))
	var carried: Dictionary = h.get("ship_ask", {})
	if carried.is_empty():
		# no request under way: the colony can ask now, because a ship is here to carry it
		var left := _dock_units(world)
		if left > 0 or int(h.get("ship_short", -1)) >= prev:
			_ask_shipping(world, h, left, left <= 0, idx)
		return
	if int(carried.get("idx", 0)) != idx:
		return  # this ship left home before the request arrived there
	# the ship that carried the request is back with the home world's answer
	h.erase("ship_ask")
	var p := 0.25 + float(h["need"]) / 150.0 + float(h["loyalty"]) / 400.0
	if bool(sv.get("refusal", false)):
		p -= 0.4
	if r.randf() >= clampf(p, 0.05, 0.9):
		h["shipping_refused"] = int(h.get("shipping_refused", 0)) + 1
		_fact(world, "HOME_SHIPPING_REFUSED", {"refused": h["shipping_refused"]}, 55, {"COLONIAL_BURDEN": -15, "JOBS": -5})
		_note(world, h, "refused more shipping")
		return
	var old := EconFace.trade_hold_of(world, idx)
	var added := 0
	var what := "LARGER_SHIP"
	if r.randf() < 0.5:
		added = int(ceil(float(old) * SHIP_HOLD_STEP)) - old
		EconFace.trade_set_hold(world, idx, old + added)
	else:
		what = "ONE_MORE_SHIP"
		added = EconData.SHIP_CARGO
		var gap: Array = EconFace.trade_ship_interval(world)
		# it takes turns with the ships already sailing: its first call falls about half a round trip after this one
		EconFace.trade_add_ship(world, world.month + r.randi_range(int(gap[0]) / 2, int(gap[1]) / 2), added)
	h["ship_debt"] = added * SHIP_COST_PER_UNIT
	world.values["HOME_TARIFF"] = SHIP_PAYOFF_PM
	_fact(world, "HOME_SHIP_BUILT", {"what": what, "hold_added": added, "ships": 1 + EconFace.trade_fleet(world).size(),
		"cost": h["ship_debt"], "higher_price_pm": SHIP_PAYOFF_PM}, 60, {"JOBS": 10, "COLONIAL_BURDEN": -10})
	_note(world, h, "built %s (+%d units); a higher price until %d credits are paid off" % [what.to_lower(), added, int(h["ship_debt"])])

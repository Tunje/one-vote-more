extends RefCounted
## Company rivalry law (user ruling: rivalry "should cause clashes with politics"). Owner: Anni (law). Preload it
## (no class_name). Step 1: levers, readers and the conduct kinds (LawOps.record_greed: PREDATORY_PRICING,
## ABUSE_DOMINANCE, EXCLUSIVE_DEALING, UNREGISTERED_LOBBYING; channel MARKET). Step 2: merger review with office
## items. Step 3: lobby rows and FAVOUR detection (party_finance). Nothing happens until Bob's rivalry pass reports.
##
## Levers (NUMBER, legislative):
##   LAW_DOMINANCE_SHARE   30–70 % (50): a firm at or above it in a market is dominant
##   LAW_MERGER_THRESHOLD  20–100 % (100 = no review): a takeover leaving the buyer above it needs approval
##   LAW_EXCLUSIVE_DEALING 0 allowed / 1 banned for dominant firms / 2 banned
##   LAW_LOBBY_REGISTER    0 none / 1 register lobbyists / 2 register and disclose meetings and requests
## LAW_COMPETITION (ENUM, player) stays the cartel switch: NONE also lifts the predation and abuse rules.

const Det := preload("res://sim/staff/det.gd")
const Staff := preload("res://sim/staff/staff_ops.gd")
const GOV := {"kind": "GOVERNMENT", "id": "government"}
const PF := preload("res://sim/law/party_finance.gd")
const LawOps := preload("res://sim/law/law_ops.gd")
const EXCLUSIVE_MODES := ["ALLOWED", "DOMINANT_BANNED", "BANNED"]
const LOBBY_MODES := ["NONE", "REGISTER", "DISCLOSE"]


static func dominance_pm(world: WorldState) -> int:
	return clampi(int(world.levers.get("LAW_DOMINANCE_SHARE", 50)), 30, 70) * 10


## Is a firm with this market share (‰) dominant? Bob passes it to record_greed as rec.dominant.
static func dominant(world: WorldState, share_pm: int) -> bool:
	return share_pm >= dominance_pm(world)


## The share (‰) above which a takeover needs approval; -1 when there is no merger review (lever at 100).
static func merger_threshold_pm(world: WorldState) -> int:
	var v := clampi(int(world.levers.get("LAW_MERGER_THRESHOLD", 100)), 20, 100)
	return -1 if v >= 100 else v * 10


static func needs_review(world: WorldState, share_after_pm: int) -> bool:
	var t := merger_threshold_pm(world)
	return t >= 0 and share_after_pm > t


static func exclusive_mode(world: WorldState) -> String:
	return EXCLUSIVE_MODES[clampi(int(world.levers.get("LAW_EXCLUSIVE_DEALING", 0)), 0, 2)]


## May this firm sign exclusive contracts?
static func exclusive_allowed(world: WorldState, share_pm: int) -> bool:
	match exclusive_mode(world):
		"BANNED":
			return false
		"DOMINANT_BANNED":
			return not dominant(world, share_pm)
	return true


static func lobby_mode(world: WorldState) -> String:
	return LOBBY_MODES[clampi(int(world.levers.get("LAW_LOBBY_REGISTER", 0)), 0, 2)]


## Must a lobby request be disclosed (and a donation tied to it, by party_finance's FAVOUR scan)?
static func lobby_disclosure(world: WorldState) -> bool:
	return lobby_mode(world) == "DISCLOSE"


## Is the competition law in force at all (the cartel switch)?
static func competition_law(world: WorldState) -> bool:
	return String(world.levers.get("LAW_COMPETITION", "CARTEL_BAN")) != "NONE"


# ===================================================================================== step 2: merger review

const DECISIONS := ["APPROVE", "CONDITIONS", "BLOCK"]
const BLOCK_FROM_PM := 700          # the authority recommends blocking a buyer this big after the deal
const CONDITIONS_OVER_PM := 150     # … and conditions this far over the threshold
const CONDITIONS := {"divest": true, "price_cap_months": 24}
const CALL_FROM_PM := 600           # a deal this big is a CALL for the player, else an EMAIL
const IDEOLOGY_STEP := 50000        # milli-points of the government's ECON_ROLE per step away from the recommendation


## Bob: a takeover proposal. t = {buyer, target, market, share_before_pm, share_after_pm, jobs, invest}. Below the
## merger threshold it is cleared at once; above it the competition authority reviews it for 3–6 months (a bigger
## budget is faster). -> {id, status CLEARED|REVIEW, due}
static func request_takeover(world: WorldState, t: Dictionary) -> Dictionary:
	var id := world.new_id("takeover")
	var share := int(t.get("share_after_pm", 0))
	var row := {"id": id, "buyer": String(t.get("buyer", "")), "target": String(t.get("target", "")), "market": String(t.get("market", "")),
		"share_before_pm": int(t.get("share_before_pm", 0)), "share_after_pm": share, "jobs": int(t.get("jobs", 0)),
		"invest": int(t.get("invest", 0)), "opened": world.month, "status": "REVIEW", "due": -1, "recommendation": "",
		"decision": "", "conditions": {}, "item": ""}
	world.table("takeover")[id] = row
	if not needs_review(world, share):
		_decide(world, row, "APPROVE", "LAW")
		return {"id": id, "status": "CLEARED", "due": world.month}
	var budget := int(world.levers.get("LAW_COMPETITION_BUDGET", 4000))
	row["due"] = world.month + clampi(6 - budget / 4000, 3, 6)
	row["recommendation"] = recommend(world, share)
	world.add_fact({"type": "LAW_TAKEOVER_REVIEW", "owner": "law", "subjects": [{"kind": "COMPANY", "id": row["buyer"]}, {"kind": "COMPANY", "id": row["target"]}],
		"responsible": [], "impact": {}, "magnitude": 30, "visibility": "PUBLIC",
		"data": {"takeover": id, "buyer": row["buyer"], "target": row["target"], "market": row["market"], "share_after_pm": share, "due": row["due"]}})
	return {"id": id, "status": "REVIEW", "due": row["due"]}


## The authority's view from the buyer's share after the deal.
static func recommend(world: WorldState, share_after_pm: int) -> String:
	if share_after_pm >= BLOCK_FROM_PM:
		return "BLOCK"
	var t := merger_threshold_pm(world)
	if t >= 0 and share_after_pm >= t + CONDITIONS_OVER_PM:
		return "CONDITIONS"
	return "APPROVE"


## {status REVIEW|CLEARED|CONDITIONS|BLOCKED, conditions, decision, recommendation}: Bob completes or drops the deal.
static func takeover_status(world: WorldState, id: String) -> Dictionary:
	return world.peek("takeover").get(id, {})


## DECISIONS (law provider): reviews that are due go to the government. An AI government decides by its ECON_ROLE
## (market parties toward approval, state parties toward blocking); a player government gets an office item, whose
## answer (or its expiry to the authority's recommendation) is applied here.
static func monthly(world: WorldState) -> void:
	favour_scan(world)
	var t := world.table("takeover")
	for id in Det.ordered(t):
		var row: Dictionary = t[id]
		if row["status"] != "REVIEW":
			continue
		if row["item"] != "":
			var o: Dictionary = world.peek("office_item").get(String(row["item"]), {})
			if not o.is_empty() and not (o["status"] in ["NEW", "READ"]):
				_decide(world, row, String(o.get("answer", row["recommendation"])) if String(o.get("answer", "")) in DECISIONS else row["recommendation"], "PLAYER")
			continue
		if world.month < int(row["due"]):
			continue
		if Staff.autopilot(world, GOV):
			_decide(world, row, _ai_decision(world, String(row["recommendation"])), "AI")
		else:
			row["item"] = _post(world, row)


static func _ai_decision(world: WorldState, rec: String) -> String:
	var st: Dictionary = world.peek("pol").get("state", {})
	var pm := String(st.get("government", {}).get("pm_party", ""))
	var econ := int(world.peek("party").get(pm, {}).get("positions", {}).get("ECON_ROLE", 0))
	var i := DECISIONS.find(rec) + int(round(float(econ) / float(IDEOLOGY_STEP)))
	return DECISIONS[clampi(i, 0, 2)]


static func _post(world: WorldState, row: Dictionary) -> String:
	var rec := String(row["recommendation"])
	var opts: Array = [{"id": "APPROVE", "label": "Approve the takeover", "action": {}},
		{"id": "CONDITIONS", "label": "Approve on conditions (sell a plant, cap prices for two years)", "action": {}},
		{"id": "BLOCK", "label": "Block it", "action": {}}]
	var merit := {"APPROVE": 0, "CONDITIONS": 0, "BLOCK": 0}
	merit[rec] = 40
	var name := func(o): return String(world.peek("org").get(o, {}).get("name", o))
	return Office.post(world, {"kind": "CALL" if int(row["share_after_pm"]) >= CALL_FROM_PM else "EMAIL", "role": "ECON_ADVISER",
		"category": "COMPETITION", "priority": 70 if int(row["share_after_pm"]) >= CALL_FROM_PM else 55,
		"subject": "Takeover: %s buys %s" % [name.call(row["buyer"]), name.call(row["target"])],
		"summary_lines": ["%s would hold %d%% of the %s market." % [name.call(row["buyer"]), int(row["share_after_pm"]) / 10, String(row["market"]).to_lower()],
			"The buyer promises %d jobs and %d W_ref of investment." % [int(row["jobs"]), int(row["invest"]) / maxi(1, int(world.values.get("ECON_W_REF", 1200000)))],
			"The competition authority recommends: %s." % rec.to_lower()],
		"options": opts, "default_option": rec, "deadline": world.month + 2,
		"source": {"system": "competition", "ref": String(row["id"])},
		"hidden": {"options": {"APPROVE": {"merit": merit["APPROVE"], "lean": {"ECON_ROLE": -60000}},
			"CONDITIONS": {"merit": merit["CONDITIONS"], "lean": {}}, "BLOCK": {"merit": merit["BLOCK"], "lean": {"ECON_ROLE": 60000}}}}})


static func _decide(world: WorldState, row: Dictionary, decision: String, by: String) -> void:
	row["decision"] = decision
	row["status"] = {"APPROVE": "CLEARED", "CONDITIONS": "CONDITIONS", "BLOCK": "BLOCKED"}[decision]
	row["conditions"] = CONDITIONS.duplicate() if decision == "CONDITIONS" else {}
	row["decided"] = world.month
	var subj: Array = [{"kind": "COMPANY", "id": row["buyer"]}, {"kind": "COMPANY", "id": row["target"]}]
	var typ: String = {"APPROVE": "LAW_TAKEOVER_CLEARED", "CONDITIONS": "LAW_TAKEOVER_CONDITIONS", "BLOCK": "LAW_TAKEOVER_BLOCKED"}[decision]
	var data := {"takeover": row["id"], "buyer": row["buyer"], "target": row["target"], "market": row["market"],
		"share_after_pm": row["share_after_pm"], "recommendation": row["recommendation"], "by": by, "conditions": row["conditions"]}
	world.add_fact({"type": typ, "owner": "law", "subjects": subj, "responsible": [{"actor": GOV, "share": 1.0}] if by != "LAW" else [],
		"impact": {}, "magnitude": 25 if by == "LAW" else 45, "visibility": "PUBLIC", "data": data})
	if by != "LAW" and String(row["recommendation"]) != "" and decision != String(row["recommendation"]):
		var softer: bool = DECISIONS.find(decision) < DECISIONS.find(String(row["recommendation"]))
		world.add_fact({"type": "LAW_TAKEOVER_OVERRIDDEN", "owner": "law", "subjects": subj + [GOV], "responsible": [{"actor": GOV, "share": 1.0}],
			"impact": {"GOVERNANCE": -3, "FAIRNESS": -3 if softer else 0, "JOBS": -2 if not softer else 0}, "magnitude": 55, "visibility": "PUBLIC",
			"data": data.merged({"softer": softer})})


# ===================================================================================== step 3: lobbying and favours

const ASK_MONTHS := 12              # an ask stays open this long
const DONATION_WINDOW := 24         # open_asks reports the org's donations to the party over this many months
const FAVOUR_WINDOW := 6            # a donation within this many months of a granted ask is tied to it
const BRIBE_WREF := 20              # a tied donation this big (W_ref) is corruption under any disclosure law


## Bob's firm AI: an organisation asks a party (or "gov") for something. request = {lever, dir} | {contract} |
## {subsidy} | {block_rival}. opts.registered (default true): under LAW_LOBBY_REGISTER ≥ 1 an unregistered ask is
## UNREGISTERED_LOBBYING; under 2 a registered ask is disclosed (PUBLIC LAW_LOBBY_DISCLOSED). -> ask id
static func lobby(world: WorldState, org: String, target: String, request: Dictionary, opts: Dictionary = {}) -> String:
	var id := world.new_id("lobby")
	var mode := lobby_mode(world)
	var registered: bool = bool(opts.get("registered", true)) or mode == "NONE"
	var disclosed: bool = mode == "DISCLOSE" and registered
	var row := {"id": id, "org": org, "target": target, "request": request.duplicate(), "month": world.month,
		"registered": registered, "disclosed": disclosed, "granted": -1, "linked": false}
	if request.has("lever"):
		row["from"] = world.levers.get(String(request["lever"]), null)
	world.table("lobby")[id] = row
	if mode != "NONE" and not registered:
		LawOps.record_greed(world, org, {"kind": "UNREGISTERED_LOBBYING", "saving": 0})
	if disclosed:
		world.add_fact({"type": "LAW_LOBBY_DISCLOSED", "owner": "law", "subjects": [{"kind": "COMPANY", "id": org}], "responsible": [],
			"impact": {}, "magnitude": 20, "visibility": "PUBLIC", "data": {"ask": id, "org": org, "target": target, "request": request.duplicate()}})
	return id


## Wilma's Legislature: open asks aimed at this party (or at the government while the party is in it), from the last
## ASK_MONTHS, with each org's donations to the party over DONATION_WINDOW months. Pure read.
static func open_asks(world: WorldState, party_id: String) -> Array:
	var members: Array = world.peek("pol").get("state", {}).get("government", {}).get("members", [])
	var out: Array = []
	var gifts := {}
	for f in PF._donations(world, world.month - DONATION_WINDOW + 1, world.month):
		if String(f["data"].get("party", "")) == party_id:
			var d := PF._donor_of(f)
			gifts[d] = int(gifts.get(d, 0)) + PF._amount_of(f)
	for id in Det.ordered(world.peek("lobby")):
		var r: Dictionary = world.peek("lobby")[id]
		if world.month - int(r["month"]) >= ASK_MONTHS or int(r["granted"]) >= 0:
			continue
		var t := String(r["target"])
		if t != party_id and not (t == "gov" and party_id in members):
			continue
		out.append({"ask": String(id), "org": String(r["org"]), "request": r["request"].duplicate(), "month": int(r["month"]),
			"donated_24m": int(gifts.get(String(r["org"]), 0))})
	return out


## Bob: an ask that is not a lever (contract, subsidy, blocking a rival) was granted this month.
static func granted(world: WorldState, ask_id: String) -> void:
	var r: Dictionary = world.table("lobby").get(ask_id, {})
	if not r.is_empty() and int(r["granted"]) < 0:
		r["granted"] = world.month


## Monthly: lever asks are granted when the lever has moved the asked way; a granted ask with a donation from the
## asking org to the target party (or a governing party, for "gov") within FAVOUR_WINDOW months is a FAVOUR. It is
## unlawful when it had to be disclosed and was not (LAW_LOBBY_REGISTER = 2), or when the gift is big enough to be a
## bribe; then a SECRET LAW_FAVOUR fact joins donation_track, so leaks, tips, investigations, the press and rivals
## can reveal it like any illegal donation (POL_SCANDAL_REVEALED, data.kind FAVOUR).
static func favour_scan(world: WorldState) -> void:
	var lob := world.table("lobby")
	var members: Array = world.peek("pol").get("state", {}).get("government", {}).get("members", [])
	for id in Det.ordered(lob):
		var r: Dictionary = lob[id]
		if bool(r["linked"]):
			continue
		var req: Dictionary = r["request"]
		if int(r["granted"]) < 0 and req.has("lever") and r.get("from") != null:
			var cur = world.levers.get(String(req["lever"]), null)
			if cur != null and (float(cur) - float(r["from"])) * float(req.get("dir", 1)) > 0.0:
				r["granted"] = world.month
		if int(r["granted"]) < 0:
			if world.month - int(r["month"]) >= ASK_MONTHS + FAVOUR_WINDOW:
				r["linked"] = true      # never granted: done
			continue
		if world.month - int(r["granted"]) < FAVOUR_WINDOW:
			continue                # wait for donations after the grant
		r["linked"] = true
		var parties: Array = members.duplicate() if String(r["target"]) == "gov" else [String(r["target"])]
		var g := int(r["granted"])
		for f in PF._donations(world, g - FAVOUR_WINDOW, g + FAVOUR_WINDOW):
			if PF._donor_of(f) != String(r["org"]) or not (String(f["data"].get("party", "")) in parties):
				continue
			var amount := PF._amount_of(f)
			var hidden: bool = f["visibility"] == "SECRET" or not bool(r["disclosed"])
			var bribe := amount >= BRIBE_WREF * maxi(1, int(world.values.get("ECON_W_REF", 1200000)))
			if not ((lobby_disclosure(world) and hidden) or bribe):
				continue
			var party := String(f["data"]["party"])
			var pref := {"kind": "PARTY", "id": party}
			var fid := world.add_fact({"type": "LAW_FAVOUR", "owner": "law", "subjects": [pref, {"kind": "COMPANY", "id": String(r["org"])}],
				"responsible": [{"actor": pref, "share": 1.0}], "impact": {}, "magnitude": 50, "visibility": "SECRET",
				"data": {"party": party, "donor": String(r["org"]), "ask": String(id), "request": req.duplicate(), "donation": String(f["id"]),
					"amount": amount, "granted": g, "bribe": bribe}})
			world.table("donation_track")[fid] = {"id": fid, "party": party, "donor": String(r["org"]), "amount": amount, "excess": 0,
				"cap": -1, "undisclosed": hidden, "month": g, "revealed": false, "kind": "FAVOUR", "request": req.duplicate(),
				"bribe": bribe, "ask": String(id)}
			break

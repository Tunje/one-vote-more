extends RefCounted
## Party finance law and donation scandals (planning/spec-politics-v2.md §6). Law/justice side only:
## politics books donations (POL_DONATION facts, data {donor, party, amount}) and applies the political fallout of
## POL_SCANDAL_REVEALED / LAW_LEADER_CONVICTED. Money: ledger milli-credits; lever values in milli-W_ref.
##
## Monthly (JUSTICE phase): scan last month's donations for violations -> public party funding -> leaks and tips ->
## investigations. A revealed violation emits POL_SCANDAL_REVEALED and files a PARTY_FINANCE case (justice_ops).

const Det := preload("res://sim/staff/det.gd")
const Staff := preload("res://sim/staff/staff_ops.gd")
const Justice := preload("res://sim/law/justice_ops.gd")

const PROSECUTOR := {"kind": "INSTITUTION", "id": "prosecutor"}
const DISCLOSURE_THRESHOLD_WREF := 2000   # milli-W_ref per donation; ABOVE_THRESHOLD discloses gifts above this
const P_LEAK := 0.01                      # per month per hidden violation: the press finds it directly
const P_TIP := 0.04                       # per month per hidden violation: a tip opens a prosecutor's investigation
const INVESTIGATION_MONTHS := 4
const P_FIND_BASE := 0.6                  # + 0.3 x legal-service quality / 100 (as the inspectorate)
const P_FIND_Q := 0.3


static func pf_state(world: WorldState) -> Dictionary:
	var t := world.table("law_state")
	if not t.has("s"):
		t["s"] = {}
	if not t["s"].has("party_finance"):
		t["s"]["party_finance"] = {"scanned_id": 0, "scanned_month": 0, "convictions": []}
	return t["s"]["party_finance"]


# =====================================================================================  the law

## Cap per donor per rolling 12 months in ledger milli-credits, or -1 for no cap (lever 0 or at its range maximum).
static func cap_amount(world: WorldState) -> int:
	var v := int(world.levers.get("LAW_DONATION_CAP", 0))
	var def: Dictionary = world.lever_defs.get("LAW_DONATION_CAP", {})
	if v <= 0 or v >= int(def.get("range", [0, 1 << 40])[1]):
		return -1
	return int(round(float(v) * float(Staff.w_ref_milli(world)) / 1000.0))


static func disclosure_required(world: WorldState, amount: int) -> bool:
	match String(world.levers.get("LAW_DONATION_DISCLOSURE", "ABOVE_THRESHOLD")):
		"ALL":
			return true
		"NONE":
			return false
	return amount > int(round(float(DISCLOSURE_THRESHOLD_WREF) * float(Staff.w_ref_milli(world)) / 1000.0))


static func donor_id(donor) -> String:
	return String(donor.get("id", "")) if donor is Dictionary else String(donor)


static func _donor_of(f: Dictionary) -> String:
	var d: Dictionary = f["data"]
	return donor_id(d.get("donor", d.get("from", "")))


static func _amount_of(f: Dictionary) -> int:
	var d: Dictionary = f["data"]
	return int(d.get("amount", d.get("amount_milli", 0)))


static func _donations(world: WorldState, from_month: int, to_month: int) -> Array:
	return Det.recent_facts(world, "POL_DONATION", from_month).filter(func(f): return f["type"] == "POL_DONATION" and int(f["month"]) <= to_month)


## Sum of a donor's booked donations in the 12 months ending at `month` (all parties), optionally only facts before `before_id`.
static func donor_total(world: WorldState, donor, month: int, before_id: String = "") -> int:
	var did := donor_id(donor)
	var cut := int(before_id.substr(1)) if before_id != "" else 1 << 40
	var s := 0
	for f in _donations(world, month - 11, month):
		if _donor_of(f) == did and int(String(f["id"]).substr(1)) < cut:
			s += _amount_of(f)
	return s


## May `donor` give `amount` now? disclose = the donation must be PUBLIC by law (a SECRET one is a violation).
static func donation_allowed(world: WorldState, amount: int, donor) -> Dictionary:
	var cap := cap_amount(world)
	var given := donor_total(world, donor, world.month)
	var ok := cap < 0 or given + amount <= cap
	return {"ok": ok, "disclose": disclosure_required(world, amount), "cap": cap, "given": given,
		"remaining": -1 if cap < 0 else maxi(0, cap - given),
		"reason": "" if ok else "over the donation cap (%d of %d already given this year)" % [given, cap]}


# =====================================================================================  monthly step

static func run(world: WorldState) -> void:
	_scan(world)
	_public_funding(world)
	_leaks_and_tips(world)
	_process_investigations(world)


## Scan donations booked since the last scan (by fact id: politics books them in POLITICS, after JUSTICE).
static func _scan(world: WorldState) -> void:
	var st := pf_state(world)
	var track := world.table("donation_track")
	var last := int(st["scanned_id"])
	for f in _donations(world, int(st["scanned_month"]), world.month):
		var n := int(String(f["id"]).substr(1))
		if n <= last:
			continue
		st["scanned_id"] = maxi(int(st["scanned_id"]), n)
		var amount := _amount_of(f)
		# Judged by the law at booking time (no retroactivity): politics stamps data.cap (milli-credits, -1 = none) and
		# data.lawful from LQ.donation_allowed, so W_ref drift between booking and this scan cannot turn a gift unlawful.
		var d: Dictionary = f["data"]
		var cap := int(d["cap"]) if d.has("cap") else cap_amount(world)
		var before := donor_total(world, _donor_of(f), int(f["month"]), f["id"])
		var excess := 0 if cap < 0 else mini(amount, maxi(0, before + amount - cap))
		var hidden: bool = f["visibility"] == "SECRET"
		var undisclosed := hidden and disclosure_required(world, amount)
		if d.has("lawful"):
			if bool(d["lawful"]):
				continue
			if excess <= 0:
				undisclosed = hidden   # unlawful at booking but within the cap: the breach was secrecy
		if excess <= 0 and not undisclosed:
			continue
		track[f["id"]] = {"id": f["id"], "party": String(f["data"].get("party", "")), "donor": _donor_of(f), "amount": amount,
			"excess": excess, "cap": cap, "undisclosed": undisclosed, "month": int(f["month"]), "revealed": not hidden}
		if not hidden:
			_scandal(world, f["id"], {"kind": "PUBLIC", "id": "public_record"}, "PUBLIC_RECORD")   # openly illegal
	st["scanned_month"] = world.month


## LAW_PUBLIC_PARTY_FUNDING: milli-W_ref per seat per month from the treasury to each seated party.
static func _public_funding(world: WorldState) -> void:
	var per_seat := int(world.levers.get("LAW_PUBLIC_PARTY_FUNDING", 0))
	if per_seat <= 0 or not world.ledger.has_account("gov:treasury"):
		return
	var parties := world.peek("party")
	for pid in Det.ordered(parties):
		var p: Dictionary = parties[pid]
		var seats := int(p.get("seats", 0))
		var acct := "party:" + String(pid)
		if seats <= 0 or String(p.get("status", "ACTIVE")) == "DISSOLVED" or not world.ledger.has_account(acct):
			continue
		var amt := int(round(float(per_seat * seats) * float(Staff.w_ref_milli(world)) / 1000.0))
		if world.ledger.allow_negative.get("gov:treasury", false) or world.ledger.balance("gov:treasury") >= amt:
			world.ledger.transfer("gov:treasury", acct, amt, "PUBLIC_PARTY_FUNDING", world.month)


static func _leaks_and_tips(world: WorldState) -> void:
	var rng := world.rng.stream("law.party_finance")
	var track := world.table("donation_track")
	for fid in Det.ordered(track):
		var t: Dictionary = track[fid]
		if t["revealed"]:
			continue
		if rng.randf() < P_LEAK:
			_scandal(world, fid, {"kind": "PRESS", "id": "press"}, "LEAK")
		elif rng.randf() < P_TIP and open_investigation_of(world, t["party"]) == "":
			open_investigation(world, {"kind": "PARTY", "id": t["party"]}, PROSECUTOR, "TIP")


# =====================================================================================  investigations

static func party_of_target(world: WorldState, target: Dictionary) -> String:
	var id := String(target.get("id", ""))
	if target.get("kind", "") == "PARTY" or world.peek("party").has(id):
		return id
	for pid in Det.ordered(world.peek("party")):   # LEADER by leader id, if politics gives leaders ids
		var ld = world.peek("party")[pid].get("leader", {})
		if ld is Dictionary and String(ld.get("id", "")) == id:
			return String(pid)
	return ""


static func open_investigation_of(world: WorldState, party: String) -> String:
	var inv := world.table("investigation")
	for id in Det.ordered(inv):
		if inv[id]["status"] == "OPEN" and inv[id]["party"] == party:
			return id
	return ""


## Open an investigation of {kind:"PARTY"|"LEADER", id}. LEADER ids are party ids (the party's current leader).
## Returns the investigation id ("" for an unknown target; an existing open one is reused).
static func open_investigation(world: WorldState, target: Dictionary, by: Dictionary = PROSECUTOR, reason: String = "") -> String:
	var party := party_of_target(world, target)
	if party == "":
		return ""
	var existing := open_investigation_of(world, party)
	if existing != "":
		return existing
	var id := world.new_id("investigation")
	world.table("investigation")[id] = {"id": id, "target": target.duplicate(), "party": party, "by": by.duplicate(),
		"reason": reason, "opened_month": world.month, "due_month": world.month + INVESTIGATION_MONTHS,
		"status": "OPEN", "outcome": "", "found": []}
	Justice.fact(world, "LAW_INVESTIGATION_OPENED", "PUBLIC", [target], [], {}, 30,
		{"investigation": id, "target": target, "party": party, "leader": leader_name(world, party), "reason": reason})
	return id


static func _process_investigations(world: WorldState) -> void:
	var inv := world.table("investigation")
	var track := world.table("donation_track")
	var rng := world.rng.stream("law.party_finance")
	var q := float(Staff.duty_quality(world, "STAFF_SD_LEGAL", int(Justice.AGENCY_Q_DEFAULT * 1000.0))) / 1000.0
	var p_find := P_FIND_BASE + P_FIND_Q * q / 100.0
	for id in Det.ordered(inv):
		var i: Dictionary = inv[id]
		if i["status"] != "OPEN" or world.month < int(i["due_month"]):
			continue
		for fid in Det.ordered(track):
			var t: Dictionary = track[fid]
			if t["party"] == i["party"] and not t["revealed"] and rng.randf() < p_find:
				i["found"].append(fid)
				_scandal(world, fid, PROSECUTOR, "INVESTIGATION")
		i["status"] = "CLOSED"
		i["outcome"] = "FINDINGS" if not i["found"].is_empty() else "CLEARED"
		Justice.fact(world, "LAW_INVESTIGATION_CLOSED", "PUBLIC", [i["target"]], [], {}, 20 if i["found"].is_empty() else 30,
			{"investigation": id, "party": i["party"], "outcome": i["outcome"], "found": i["found"].size()})


# =====================================================================================  scandal

static func leader_name(world: WorldState, party: String) -> String:
	var ld = world.peek("party").get(party, {}).get("leader", "")
	return String(ld.get("name", "")) if ld is Dictionary else String(ld)


static func _leader_integrity(world: WorldState, party: String) -> int:
	var ld = world.peek("party").get(party, {}).get("leader", {})
	return int(ld.get("integrity", 50)) if ld is Dictionary else 50


## 0..100: how bad the violation is (hidden gift +20, cap breach up to +60 by excess relative to the cap).
static func severity(world: WorldState, t: Dictionary) -> int:
	var s := 20
	if t["undisclosed"]:
		s += 20
	if int(t["excess"]) > 0:
		var base := maxi(int(t["cap"]), Staff.w_ref_milli(world))
		s += 20 + int(round(40.0 * minf(1.0, float(t["excess"]) / float(base))))
	return clampi(s, 0, 100)


## Reveal a tracked violation: SECRET fact -> *_REVEALED, POL_SCANDAL_REVEALED {party, leader, severity}, and a
## PARTY_FINANCE prosecution. Whether the leader is charged too depends on the leader's integrity (did they know?).
static func _scandal(world: WorldState, fid: String, by: Dictionary, channel: String) -> void:
	var t: Dictionary = world.table("donation_track")[fid]
	var causes: Array = [fid]
	if world.facts.get_fact(fid).get("visibility", "") == "SECRET" and not world.table("revealed_fact").has(fid):
		causes.append(world.facts.reveal(world.month, fid, [by]))
	world.table("revealed_fact")[fid] = true
	t["revealed"] = true
	t["revealed_month"] = world.month
	t["channel"] = channel
	var party: String = t["party"]
	var sev := severity(world, t)
	var leader := leader_name(world, party)
	var rng := world.rng.stream("law.party_finance")
	var charged := rng.randf() < float(100 - _leader_integrity(world, party)) / 100.0
	var pref := {"kind": "PARTY", "id": party}
	Justice.fact(world, "POL_SCANDAL_REVEALED", "PUBLIC", [pref], [{"actor": pref, "share": 1.0}],
		{"GOVERNANCE": -int(round(sev / 10.0)), "FAIRNESS": -int(round(sev / 20.0))}, clampi(40 + sev / 2, 40, 90),
		{"party": party, "leader": leader, "severity": sev, "donation": fid, "donor": t["donor"], "amount": t["amount"],
			"excess": t["excess"], "undisclosed": t["undisclosed"], "channel": channel, "leader_charged": charged}, causes)
	Justice.file_case(world, "PARTY_FINANCE", PROSECUTOR, pref, true,
		{"fact": fid, "party": party, "excess": int(t["excess"]), "undisclosed": t["undisclosed"],
			"leader": leader, "leader_charged": charged}, [800])


## Opposition research (Ella, spec-election-year-v1): a rival party's dig exposes an unrevealed tracked violation of
## the target party. Same consequences as any reveal; POL_SCANDAL_REVEALED.data.channel = "OPPO_RESEARCH".
## Returns true when it fired (the entry exists and was still hidden).
static func reveal_by_rival(world: WorldState, fid: String, by_party: String) -> bool:
	var t: Dictionary = world.peek("donation_track").get(fid, {})
	if t.is_empty() or t.get("revealed", true):
		return false
	_scandal(world, fid, {"kind": "PARTY", "id": by_party}, "OPPO_RESEARCH")
	return true


## After a conviction: may the convicted leader stay? (LAW_CONVICTED_CAN_HOLD_OFFICE)
static func convicted_can_hold_office(world: WorldState) -> bool:
	return bool(world.levers.get("LAW_CONVICTED_CAN_HOLD_OFFICE", true))


static func is_convicted(world: WorldState, leader: String) -> bool:
	for c in pf_state(world)["convictions"]:
		if c["leader"] == leader:
			return true
	return false

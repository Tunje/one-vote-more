extends RefCounted
## Private roads, the law side (planning/design-law-private-roads.md; user via Wilma 2026-11-15: "private roads, bought
## and paid for by companies"). Owner: Anni (law). Preload it (no class_name). Terra owns the links
## (planning/design-private-roads-transport.md); Bob books the money. The law decides and records.
##
## Opt-in: flag PRIVATE_ROADS, on top of FREIGHT_ROADS. Without both, every reader answers "no private roads", the
## levers stay off the legislature's table ("requires"), and nothing is written.
##
## Levers (law_data, LAW level, parliament's):
##   LAW_PRIVATE_ROADS        0 FORBIDDEN / 1 LICENCE (default) / 2 FREE
##   LAW_PRIVATE_ROAD_ACCESS  0 the owner chooses / 1 common carriage (open to all, owner keeps ≤ 50% of capacity)
##   LAW_PRIVATE_TOLL_CAP     100–300 % of the road's cost-recovery toll (300 = no cap)
##
## Step 1: may_build (land, zoning, objections), the licence procedure (2-month objection window, the Minister of
## Infrastructure's decision, or the Cabinet's for a road across 3+ districts), refusal facts, the appeal against a
## refusal without grounds, and the pure access / toll readers on Terra's link fields.
## Step 2 (on Terra's Transport.private_link / transfer_link): the maintenance duty (cond ≥ 400 on licensed or open
## roads), the neglect ladder (notice, 6 months to repair, then the minister), step-in repairs billed to the owner
## (liability kind ROAD_STEP_IN), revocation, takeover at value (AGREED / COMPULSORY / REVOKED) and reversion of a
## failed owner's unsold road. Road rules (NEGLECT_ROAD, REFUSE_ROAD_ACCESS, TOLL_ABOVE_CAP) are added only with the flag.
## Not yet: the tort for an accident on a neglected road (needs a vehicle-accident hook), the state's first right in an
## estate sale (Bob's sale side, with SaleLaw).
##
## Who decides (one function per decision, with the options it chose among, for the decision registry):
##   licence_decision   GRANT | GRANT_COMMON_CARRIER | REFUSE    Minister of Infrastructure; the Cabinet for 3+ districts
##   neglect_decision   STEP_IN | LEAVE | REVOKE                  Minister of Infrastructure
##   take_over          AGREED | COMPULSORY | REVOKED             ministers up to LAW_STATE_AID_THRESHOLD; else the Cabinet
##
## Facts (owner law): LAW_ROAD_LICENCE_FILED, LAW_ROAD_LICENCE_GRANTED, LAW_ROAD_OBJECTION_OVERRIDDEN (one per district,
## "affected": {"districts": [d]}), LAW_ROAD_LICENCE_REFUSED (with grounds), LAW_ROAD_REFUSAL_UNGROUNDED,
## LAW_ROAD_LICENCE_QUASHED, LAW_ROAD_NEGLECT_NOTICE, LAW_ROAD_STEP_IN, LAW_PRIVATE_ROAD_UNENFORCED (owner 0.8 /
## government 0.2), LAW_ROAD_LICENCE_REVOKED, LAW_ROAD_TAKEN_OVER, LAW_ROAD_REVERTED.

const Det := preload("res://sim/staff/det.gd")
const Staff := preload("res://sim/staff/staff_ops.gd")
const Land := preload("res://sim/law/land_law.gd")
const JO := preload("res://sim/law/justice_ops.gd")
const LawOps := preload("res://sim/law/law_ops.gd")
const L := preload("res://sim/law/law_data.gd")

const FLAG := "PRIVATE_ROADS"
const BASE_FLAG := "FREIGHT_ROADS"
const GOV := {"kind": "GOVERNMENT", "id": "government"}
const SETTINGS := ["FORBIDDEN", "LICENCE", "FREE"]
const REGIMES := ["OWNER", "OPEN_TOLL", "OPEN_FREE"]
const DECISIONS := ["GRANT", "GRANT_COMMON_CARRIER", "REFUSE"]
## Lawful grounds for refusing a licence (design §1.1); a refusal citing none of them is appealable.
const GROUNDS := ["LAND", "SAFETY", "JUNCTIONS", "OBJECTIONS"]
const OBJECTION_MONTHS := 2
const CABINET_DISTRICTS := 3          # a road across this many districts is the Cabinet's
const COMMON_RESERVED_PM := 500       # under common carriage the owner keeps at most this ‰ of capacity
const COST_TOLL_MONTHS := 240         # the cost-recovery toll writes the build cost off over 20 years
const APPEAL_MIN := 3                 # months the court takes over an appeal (its recent mean, within these bounds)
const APPEAL_MAX := 12
## The AI minister: grant when this score ≥ GRANT_BAR. 1.0 − ECON_LEAN × (PM party's ECON_ROLE ÷ 100000)
## − OBJECTION_W × Σ district weight. A fully state-minded government refuses even an unopposed road (without grounds).
const GRANT_BAR := 0.5
const ECON_LEAN := 0.6
const OBJECTION_W := 0.4
const STATE_CC := 30000               # a government this state-minded (ECON_ROLE) attaches common carriage to OWNER roads


static func on(world: WorldState) -> bool:
	var on_l: Array = world.meta.get("on", [])
	var off_l: Array = world.meta.get("off", [])
	return on_l.has(FLAG) and on_l.has(BASE_FLAG) and not off_l.has(FLAG) and not off_l.has(BASE_FLAG)


static func _lv(world: WorldState, id: String, dflt: int, lo: int, hi: int) -> int:
	return clampi(int(world.levers.get(id, dflt)), lo, hi)


## FORBIDDEN | LICENCE | FREE ("FORBIDDEN" when the flag is off).
static func setting(world: WorldState) -> String:
	if not on(world):
		return "FORBIDDEN"
	return SETTINGS[_lv(world, "LAW_PRIVATE_ROADS", 1, 0, 2)]


static func common_carriage(world: WorldState) -> bool:
	return on(world) and _lv(world, "LAW_PRIVATE_ROAD_ACCESS", 0, 0, 1) == 1


## The toll cap as a share of the cost-recovery toll (1.0 .. 3.0); -1.0 = no cap.
static func toll_cap_share(world: WorldState) -> float:
	var v := _lv(world, "LAW_PRIVATE_TOLL_CAP", 200, 100, 300)
	return -1.0 if v >= 300 else float(v) / 100.0


# ===================================================================================== may a firm build this road?

## plan = {tiles: ["x,y" | Vector2i], kind TRACK|ROAD|PAVED, districts: [d] (crossed, in route order), regime,
##         junction_over: [d] (districts whose public junctions it would load past capacity; Terra), essential: bool
##         (it would be the only good route between two districts; Terra)}
## -> {status LAWFUL|NEEDS_LICENCE|REFUSED, reasons: [..], wayleave: [tile keys on state land to lease],
##     objections: [{district, grounds: [HOUSING|FARM_LAND|JUNCTIONS]}], needs_cabinet}
## A road over land the firm doesn't hold (other than state land, leased as a wayleave) is refused: no firm can force
## a sale. Housing on the route is an objection, and clearing it still needs LandLaw.may_clear (Terra / Bob).
static func may_build(world: WorldState, org: String, plan: Dictionary) -> Dictionary:
	var out := {"status": "REFUSED", "reasons": [], "wayleave": [], "objections": [], "needs_cabinet": false}
	var mode := setting(world)
	if mode == "FORBIDDEN":
		out["reasons"].append("FORBIDDEN" if on(world) else "NO_PRIVATE_ROADS")
		return out
	var held := true
	var by_d := {}
	var tiles: Array = plan.get("tiles", [])
	for tile in tiles:
		var k := Land._k(tile)
		var t := Land.title(world, k)
		if String(t.get("zoning", "UNZONED")) == "RESERVE":
			if not ("ZONE_RESERVE" in out["reasons"]):
				out["reasons"].append("ZONE_RESERVE")
			continue
		if Land.right_of(world, org, k) == "":
			held = false
			if String(t["owner"]) == "gov" and String(t["tenure"]) == "OWNED":
				out["wayleave"].append(k)
			elif not ("LAND_NOT_HELD" in out["reasons"]):
				out["reasons"].append("LAND_NOT_HELD")
		var dk := _district_of(world, k, plan)
		if String(t.get("zoning", "UNZONED")) == "FARM" and Land.right_of(world, org, k) == "" and dk != "":
			by_d[dk] = _add(by_d.get(dk, []), "FARM_LAND")
	if not (out["reasons"] as Array).is_empty():
		return out
	var districts: Array = plan.get("districts", [])
	# Housing on the route (only the firm's own clearance can remove it; the district objects either way).
	for d in districts:
		var dt: Array = tiles.filter(func(tl): return _district_of(world, Land._k(tl), plan) == String(d))
		if not dt.is_empty() and Land.residents_on(world, dt) > 0:
			by_d[String(d)] = _add(by_d.get(String(d), []), "HOUSING")
	for d in plan.get("junction_over", []):
		by_d[String(d)] = _add(by_d.get(String(d), []), "JUNCTIONS")
	# A farm or mine track wholly on the firm's own land in one district is part of its site.
	if String(plan.get("kind", "")) == "TRACK" and held and districts.size() <= 1:
		out["status"] = "LAWFUL"
		out["reasons"].append("SITE_TRACK")
		return out
	if mode == "FREE":
		out["status"] = "LAWFUL"
		return out
	for d in Det.ordered(by_d):
		out["objections"].append({"district": String(d), "grounds": by_d[d]})
	out["status"] = "NEEDS_LICENCE"
	out["needs_cabinet"] = districts.size() >= CABINET_DISTRICTS
	return out


static func _add(a: Array, g: String) -> Array:
	var b := a.duplicate()
	if not (g in b):
		b.append(g)
	return b


## A tile's district: plan.tile_district[key] when Terra passes it, else the plan's only district.
static func _district_of(_world: WorldState, k: String, plan: Dictionary) -> String:
	var td: Dictionary = plan.get("tile_district", {})
	if td.has(k):
		return String(td[k])
	var ds: Array = plan.get("districts", [])
	return String(ds[0]) if ds.size() == 1 else ""


# ===================================================================================== the road licence

## The firm files for a licence (only when may_build said NEEDS_LICENCE). -> licence id ("" when not needed or off).
## The filing is public; the districts have OBJECTION_MONTHS to object, then the minister (or the Cabinet) decides.
static func apply_licence(world: WorldState, org: String, plan: Dictionary) -> String:
	var chk := may_build(world, org, plan)
	if String(chk["status"]) != "NEEDS_LICENCE":
		return ""
	var id := world.new_id("roadlic")
	var row := {"id": id, "org": org, "plan": plan.duplicate(true), "filed": world.month,
		"due": world.month + OBJECTION_MONTHS, "status": "FILED", "objections": chk["objections"].duplicate(true),
		"wayleave": chk["wayleave"].duplicate(), "needs_cabinet": bool(chk["needs_cabinet"]), "decision": "",
		"grounds": [], "conditions": {}, "item": "", "decided": -1, "by": "", "appeal_due": -1, "link": ""}
	world.table("road_licence")[id] = row
	var ds: Array = plan.get("districts", [])
	world.add_fact({"type": "LAW_ROAD_LICENCE_FILED", "owner": "law", "subjects": [{"kind": "COMPANY", "id": org}],
		"responsible": [], "impact": {}, "affected": {"districts": ds.duplicate()}, "magnitude": 20, "visibility": "PUBLIC",
		"data": {"licence": id, "org": org, "districts": ds.duplicate(), "kind": String(plan.get("kind", "")),
			"regime": String(plan.get("regime", "OWNER")), "objections": row["objections"].duplicate(true), "due": row["due"]}})
	return id


## The licence row ({} for none): status FILED | GRANTED | REFUSED | APPEAL | REVOKED; conditions {regime_min,
## reserved_pm_max} when granted on common carriage. Terra may build only when status == GRANTED.
static func licence(world: WorldState, id: String) -> Dictionary:
	return world.peek("road_licence").get(id, {})


## Terra, when the licensed link is built: the licence names its link.
static func licence_built(world: WorldState, id: String, lid: String) -> void:
	var row: Dictionary = world.peek("road_licence").get(id, {})
	if not row.is_empty():
		row["link"] = lid


## DECISIONS (law provider): licences past their objection window are decided; appeals the court has finished grant.
static func monthly(world: WorldState) -> void:
	if not on(world):
		return
	if world.peek("road_licence").is_empty():
		links_monthly(world)
		return
	var t := world.table("road_licence")
	for id in Det.ordered(t):
		var row: Dictionary = t[id]
		match String(row["status"]):
			"FILED":
				if String(row["item"]) != "":
					var o: Dictionary = world.peek("office_item").get(String(row["item"]), {})
					if not o.is_empty() and not (o["status"] in ["NEW", "READ"]):
						var ans := String(o.get("answer", ""))
						var dflt := String(o.get("default_option", "GRANT"))
						_decide(world, row, ans if ans in DECISIONS else dflt, "PLAYER")
					continue
				if world.month < int(row["due"]):
					continue
				if Staff.autopilot(world, GOV):
					_decide(world, row, String(licence_decision(world, row)["choice"]), "AI")
				else:
					row["item"] = _post(world, row)
			"APPEAL":
				if world.month >= int(row["appeal_due"]):
					_quash(world, row)
	links_monthly(world)


## The objections' political weight per district: grounds × how much the district has (its INFRASTRUCTURE
## satisfaction: a road-starved district minds less) × how much the government cares (its vote share there).
## -> {district: weight}. Wilma: GovBuilder._district_share until a district-opinion query exists.
static func objection_weights(world: WorldState, row: Dictionary) -> Dictionary:
	var members: Array = (Staff.pol_state(world).get("government", {}) as Dictionary).get("members", [])
	var out := {}
	for ob in row.get("objections", []):
		var d := String(ob["district"])
		var share := GovBuilder._district_share(world, d, members) if not members.is_empty() else 0.0
		out[d] = float((ob["grounds"] as Array).size()) * (0.5 + _infra_sat(world, d)) * (0.5 + share)
	return out


## Population-weighted INFRASTRUCTURE satisfaction of a district's voters, 0..1 (0.5 when unknown).
static func _infra_sat(world: WorldState, d: String) -> float:
	var v := 0.0
	var n := 0.0
	for c in PolVoters.all(world):
		if String(c.get("district", "")) != d or int(c.get("pop", 0)) <= 0:
			continue
		v += float((c.get("sat", {}) as Dictionary).get("INFRASTRUCTURE", 50000)) / 100000.0 * float(c["pop"])
		n += float(c["pop"])
	return v / n if n > 0.0 else 0.5


## The Minister of Infrastructure's decision on a licence (the Cabinet's when row.needs_cabinet).
## -> {options: DECISIONS, choice, score, grounds}. Market-minded governments grant; state-minded ones refuse or
## attach common carriage; objections weigh by objection_weights.
static func licence_decision(world: WorldState, row: Dictionary) -> Dictionary:
	var pm := Staff.pm_party(world)
	var econ := float(int(world.peek("party").get(pm, {}).get("positions", {}).get("ECON_ROLE", 0)))
	var w := objection_weights(world, row)
	var sum := 0.0
	for d in Det.ordered(w):
		sum += float(w[d])
	var score := 1.0 - ECON_LEAN * econ / 100000.0 - OBJECTION_W * sum
	var choice := "REFUSE"
	if score >= GRANT_BAR:
		var plan: Dictionary = row.get("plan", {})
		var owner_only := String(plan.get("regime", "OWNER")) == "OWNER"
		choice = "GRANT_COMMON_CARRIER" if owner_only and not common_carriage(world) and (bool(plan.get("essential", false)) or econ >= STATE_CC) else "GRANT"
	return {"options": DECISIONS.duplicate(), "choice": choice, "score": score, "grounds": refusal_grounds(row) if choice == "REFUSE" else []}


## The lawful grounds a refusal of this licence could cite: OBJECTIONS when any district objected, JUNCTIONS when a
## junction ground was raised. [] = a refusal would be without grounds (appealable).
static func refusal_grounds(row: Dictionary) -> Array:
	var g: Array = []
	for ob in row.get("objections", []):
		if not ("OBJECTIONS" in g):
			g.append("OBJECTIONS")
		if "JUNCTIONS" in (ob["grounds"] as Array) and not ("JUNCTIONS" in g):
			g.append("JUNCTIONS")
	return g


static func _post(world: WorldState, row: Dictionary) -> String:
	var ai := licence_decision(world, row)
	var org_name := String(world.peek("org").get(String(row["org"]), {}).get("name", row["org"]))
	var ds: Array = row["plan"].get("districts", [])
	var lines: Array = ["%s asks to build its own %s road through %s." % [org_name, String(row["plan"].get("kind", "")).to_lower(),
		", ".join(ds.map(func(x): return String(x)))]]
	for ob in row["objections"]:
		lines.append("%s objects: %s." % [String(ob["district"]), ", ".join((ob["grounds"] as Array).map(func(x): return String(x).to_lower().replace("_", " ")))])
	if refusal_grounds(row).is_empty():
		lines.append("No district objects. A refusal would have no ground in law, and the court would overturn it on appeal.")
	var cab := bool(row["needs_cabinet"])
	return Office.post(world, {"kind": "CALL" if cab else "EMAIL", "role": "CHIEF_OF_STAFF" if cab else "ENGINEER",
		"category": "INFRASTRUCTURE", "priority": 60 if cab else 45,
		"subject": "Road licence: %s" % org_name, "summary_lines": lines,
		"options": [{"id": "GRANT", "label": "Grant the licence", "action": {}},
			{"id": "GRANT_COMMON_CARRIER", "label": "Grant it, open to all at a capped toll", "action": {}},
			{"id": "REFUSE", "label": "Refuse it", "action": {}}],
		"default_option": String(ai["choice"]), "deadline": world.month + 2,
		"source": {"system": "road_licence", "ref": String(row["id"])},
		"hidden": {"options": {"GRANT": {"merit": 20, "lean": {"ECON_ROLE": -40000}}, "GRANT_COMMON_CARRIER": {"merit": 20, "lean": {}},
			"REFUSE": {"merit": 0 if refusal_grounds(row).is_empty() else 10, "lean": {"ECON_ROLE": 40000}}}}})


static func _decide(world: WorldState, row: Dictionary, choice: String, by: String) -> void:
	row["decision"] = choice
	row["decided"] = world.month
	row["by"] = by
	var org := String(row["org"])
	var ds: Array = row["plan"].get("districts", [])
	var who := "CABINET" if bool(row["needs_cabinet"]) else "MINISTER"
	var resp := [{"actor": GOV, "share": 1.0}]
	var subj := [{"kind": "COMPANY", "id": org}, GOV]
	var data := {"licence": row["id"], "org": org, "districts": ds.duplicate(), "decision": choice, "decided_by": who, "by": by}
	if choice == "REFUSE":
		var g := refusal_grounds(row)
		row["grounds"] = g
		data["grounds"] = g.duplicate()
		if g.is_empty():
			# Lawful to decide, unlawful in substance: the firm appeals and the court will grant it.
			row["status"] = "APPEAL"
			var cd := JO.court_duration(world)
			row["appeal_due"] = world.month + clampi(int(round(cd)) if cd > 0.0 else APPEAL_MIN, APPEAL_MIN, APPEAL_MAX)
			data["appeal_due"] = row["appeal_due"]
			world.add_fact({"type": "LAW_ROAD_REFUSAL_UNGROUNDED", "owner": "law", "subjects": subj, "responsible": resp,
				"impact": {"GOVERNANCE": -2, "INFRASTRUCTURE": -1}, "affected": {"districts": ds.duplicate()}, "magnitude": 40,
				"visibility": "PUBLIC", "data": data})
		else:
			row["status"] = "REFUSED"
			world.add_fact({"type": "LAW_ROAD_LICENCE_REFUSED", "owner": "law", "subjects": subj, "responsible": resp,
				"impact": {}, "affected": {"districts": ds.duplicate()}, "magnitude": 25, "visibility": "PUBLIC", "data": data})
		return
	row["status"] = "GRANTED"
	if choice == "GRANT_COMMON_CARRIER":
		row["conditions"] = {"regime_min": "OPEN_TOLL", "reserved_pm_max": COMMON_RESERVED_PM}
	data["conditions"] = row["conditions"].duplicate()
	world.add_fact({"type": "LAW_ROAD_LICENCE_GRANTED", "owner": "law", "subjects": subj, "responsible": resp, "impact": {},
		"affected": {"districts": ds.duplicate()}, "magnitude": 25, "visibility": "PUBLIC", "data": data})
	var w := objection_weights(world, row)
	for ob in row["objections"]:
		var d := String(ob["district"])
		var n := (ob["grounds"] as Array).size()
		world.add_fact({"type": "LAW_ROAD_OBJECTION_OVERRIDDEN", "owner": "law", "subjects": subj, "responsible": resp,
			"impact": {"FAIRNESS": -2 - mini(n, 3), "GOVERNANCE": -1}, "affected": {"districts": [d]},
			"magnitude": 20 + 8 * mini(n, 3), "visibility": "PUBLIC",
			"data": {"licence": row["id"], "org": org, "district": d, "grounds": (ob["grounds"] as Array).duplicate(),
				"weight_pm": int(round(float(w.get(d, 0.0)) * 1000.0)), "decided_by": who, "by": by}})


## The court on a refusal without grounds: the refusal is quashed and the licence granted as filed.
static func _quash(world: WorldState, row: Dictionary) -> void:
	row["status"] = "GRANTED"
	row["decision"] = "GRANT"
	row["by"] = "COURT"
	row["decided"] = world.month
	var ds: Array = row["plan"].get("districts", [])
	world.add_fact({"type": "LAW_ROAD_LICENCE_QUASHED", "owner": "law", "subjects": [{"kind": "COMPANY", "id": String(row["org"])}, GOV],
		"responsible": [{"actor": GOV, "share": 1.0}], "impact": {"GOVERNANCE": -2}, "affected": {"districts": ds.duplicate()},
		"magnitude": 40, "visibility": "PUBLIC", "data": {"licence": row["id"], "org": String(row["org"]), "districts": ds.duplicate()}})


# ===================================================================================== access and tolls (pure)

## What the law allows on a private link (Terra's Transport.private_link shape: owner, regime, toll, reserved_pm,
## build_cost, upkeep (mcr a month, if known), ytr_last, licence). -> {regimes: [allowed], reserved_pm_max, toll_cap}
## toll_cap: mcr per truck trip, -1 = no cap. A licence granted on common carriage binds whatever the lever says.
static func access(world: WorldState, link: Dictionary) -> Dictionary:
	var cc := common_carriage(world)
	var lic := licence(world, String(link.get("licence", "")))
	if not lic.is_empty() and String((lic.get("conditions", {}) as Dictionary).get("regime_min", "")) == "OPEN_TOLL":
		cc = true
	return {"regimes": ["OPEN_TOLL", "OPEN_FREE"] if cc else REGIMES.duplicate(),
		"reserved_pm_max": COMMON_RESERVED_PM if cc else 1000, "toll_cap": toll_cap(world, link)}


## The cost-recovery toll per truck trip: (upkeep a month + build cost ÷ 240) ÷ last year's monthly truck trips.
static func cost_toll(link: Dictionary) -> int:
	var trips := maxi(1, int(link.get("ytr_last", 0)) / 12)
	return int((int(link.get("upkeep", 0)) + int(link.get("build_cost", 0)) / COST_TOLL_MONTHS) / trips)


## The highest lawful toll per truck trip, mcr (-1 = no cap).
static func toll_cap(world: WorldState, link: Dictionary) -> int:
	var sh := toll_cap_share(world)
	if sh < 0.0:
		return -1
	return int(round(float(cost_toll(link)) * sh))


## May the owner set these terms? -> {ok, reasons}. Terra's set_terms asks first.
static func check_terms(world: WorldState, link: Dictionary, regime: String, toll: int, reserved_pm: int) -> Dictionary:
	var a := access(world, link)
	var reasons: Array = []
	if not (regime in a["regimes"]):
		reasons.append("COMMON_CARRIAGE")
	if regime != "OWNER" and reserved_pm > int(a["reserved_pm_max"]):
		reasons.append("RESERVED_SHARE")
	if regime == "OPEN_TOLL" and int(a["toll_cap"]) >= 0 and toll > int(a["toll_cap"]):
		reasons.append("TOLL_OVER_CAP")
	return {"ok": reasons.is_empty(), "reasons": reasons}


# ===================================================================================== step 2: duty, neglect, takeover

const NEGLECT_COND := 400             # a duty-bearing road is kept at or above this condition (‰)
const NOTICE_AFTER := 3               # months below before the public notice
const CURE_MONTHS := 6                # the owner's time to repair after the notice; then the minister decides, and again
                                      # every CURE_MONTHS while it stays below
const REPEAT_MONTHS := 24             # two notices within this many months: the licence may be revoked
const DEBT_MONTHS := 12               # step-in costs unpaid this long: the licence may be revoked
const REVOKED_SALE_MONTHS := 12       # a revoked road must be sold within this; else the state takes it at value
const ESTATE_MONTHS := 6              # a failed owner's road unsold this long reverts to the state
const NEGLECT_DECISIONS := ["STEP_IN", "LEAVE", "REVOKE"]
const MARKET_LEAVES := -30000         # a government at or below this ECON_ROLE leaves a neglected road to its owner
const DEAD := ["LIQUIDATION", "DISSOLVED"]


## Road rules, added once when the flag is on: neglect of a duty-bearing road; refusing access under common carriage
## or to an essential road (params.dominant); a toll above the cap.
static func ensure_rules(world: WorldState) -> void:
	var s := LawOps.state(world)
	if s.get("road_rules", false):
		return
	s["road_rules"] = true
	var co := [{"field": "actor.kind", "op": "EQ", "value": "COMPANY"}]
	var law := {"level": "LAW", "source": "ROAD_LAW", "effective_month": world.month}
	for r in [L._r("PROHIBIT", "NEGLECT_ROAD", co, [], law),
			L._r("PROHIBIT", "REFUSE_ROAD_ACCESS", co, [{"field": "lever.LAW_PRIVATE_ROAD_ACCESS", "op": "EQ", "value": 1}], law),
			L._r("PROHIBIT", "REFUSE_ROAD_ACCESS", co, [{"field": "p.dominant", "op": "EQ", "value": true}], law),
			L._r("PROHIBIT", "TOLL_ABOVE_CAP", co, [], law)]:
		LawOps.add_rule(world, r)
	LawOps.bump_rules_version(world)


## Does this link carry the maintenance duty? A licensed road, or any road open to others.
static func has_duty(link: Dictionary) -> bool:
	return String(link.get("licence", "")) != "" or String(link.get("regime", "OWNER")) != "OWNER"


## The districts at a link's two ends (nearest settlements), sorted, no duplicates.
static func link_districts(world: WorldState, lid: String) -> Array:
	var l: Dictionary = world.peek("transport").get("links", {}).get(lid, {})
	var path: Array = l.get("path", [])
	if path.is_empty():
		return []
	var setl := ColonyLayout.settlements(world)
	var out: Array = []
	for i in [int(path[0]), int(path[path.size() - 1])]:
		var t := Transport.int_tile(i)
		var best := ""
		var bd := INF
		for s in setl:
			var dd := Vector2(s["tile"]).distance_to(Vector2(t))
			if dd < bd:
				bd = dd
				best = String(s["district"])
		if best != "" and not (best in out):
			out.append(best)
	out.sort()
	return out


## The road's value for a takeover (design §4.2): build cost × condition + the owner's own land under it − public
## money already in it − the owner's open step-in debts on it. Never below 0. mcr.
static func value(world: WorldState, lid: String) -> int:
	var link := Transport.private_link(world, lid)
	if link.is_empty():
		return 0
	var v := int(link["build_cost"]) * int(link["cond"]) / 1000
	var l: Dictionary = world.peek("transport").get("links", {}).get(lid, {})
	for i in l.get("path", []):
		var t := Transport.int_tile(int(i))
		if Land.right_of(world, String(link["owner"]), t) == "OWNER":
			v += Land.land_value(world, t)
	return maxi(0, v - int(link["public_money"]) - step_in_debt(world, lid))


## The owner's open step-in debt on a link, mcr.
static func step_in_debt(world: WorldState, lid: String) -> int:
	var n := 0
	for li in world.peek("liability").values():
		if String(li.get("kind", "")) == "ROAD_STEP_IN" and String(li.get("link", "")) == lid and String(li["status"]) == "OPEN":
			n += int(li["amount"])
	return n


static func _watch(world: WorldState, lid: String, link: Dictionary) -> Dictionary:
	var t := world.table("road_watch")
	if not t.has(lid) or String(t[lid]["owner"]) != String(link["owner"]):
		t[lid] = {"lid": lid, "owner": String(link["owner"]), "below": 0, "notice": -1, "notices": [], "decide_at": -1,
			"step_in": -1, "pm_seen": int(link["public_money"]), "revoked": -1, "estate": -1, "item": "", "pending": "", "greed": ""}
	return t[lid]


## Each private link, monthly: the step-in bill, a failed owner's estate, a pending player decision, a revoked road's
## sale deadline, and the neglect ladder for roads with the duty.
static func links_monthly(world: WorldState) -> void:
	var lids: Array = Transport.private_links(world)
	if lids.is_empty() and world.peek("road_watch").is_empty():
		return
	ensure_rules(world)
	var live := {}
	for lid in lids:
		live[lid] = true
		var link := Transport.private_link(world, lid)
		var row := _watch(world, lid, link)
		_bill_step_in(world, row, link)
		if _estate(world, row, link):
			continue
		if String(row["pending"]) != "":
			_poll(world, row)
			continue
		if int(row["revoked"]) >= 0:
			if world.month >= int(row["revoked"]) + REVOKED_SALE_MONTHS:
				take_over(world, lid, "REVOKED", -1, "AI")
			continue
		if has_duty(link):
			_neglect(world, row, link)
	var t := world.table("road_watch")
	for lid in Det.ordered(t):
		if not live.has(lid):
			t.erase(lid)


## A step-in repair (a government ROAD project on the link) adds to public_money when it completes: the owner owes it.
static func _bill_step_in(world: WorldState, row: Dictionary, link: Dictionary) -> void:
	var delta := int(link["public_money"]) - int(row["pm_seen"])
	row["pm_seen"] = int(link["public_money"])
	if delta <= 0 or int(row["step_in"]) < 0:
		return
	var id := world.new_id("liability")
	world.table("liability")[id] = {"id": id, "debtor": String(link["owner"]), "creditor": "gov", "amount": delta,
		"due_month": world.month + 1, "kind": "ROAD_STEP_IN", "status": "OPEN", "plan": false, "link": String(row["lid"])}
	row["step_in"] = -1


## The neglect ladder: notice after NOTICE_AFTER months below NEGLECT_COND, CURE_MONTHS to repair, then the minister.
static func _neglect(world: WorldState, row: Dictionary, link: Dictionary) -> void:
	var lid := String(row["lid"])
	if int(link["cond"]) >= NEGLECT_COND:
		row["below"] = 0
		if int(row["notice"]) >= 0:
			row["notice"] = -1
			row["decide_at"] = -1
			if String(row["greed"]) != "":
				LawOps.greed_stop(world, String(row["greed"]))
				row["greed"] = ""
		return
	row["below"] = int(row["below"]) + 1
	if int(row["notice"]) < 0:
		if int(row["below"]) >= NOTICE_AFTER:
			row["notice"] = world.month
			row["decide_at"] = world.month + CURE_MONTHS
			var keep: Array = (row["notices"] as Array).filter(func(m): return world.month - int(m) < REPEAT_MONTHS)
			keep.append(world.month)
			row["notices"] = keep
			var ds := link_districts(world, lid)
			var co := {"kind": "COMPANY", "id": String(link["owner"])}
			world.add_fact({"type": "LAW_ROAD_NEGLECT_NOTICE", "owner": "law", "subjects": [co],
				"responsible": [{"actor": co, "share": 1.0}], "impact": {"INFRASTRUCTURE": -1},
				"affected": {"districts": ds}, "magnitude": 20, "visibility": "PUBLIC",
				"data": {"link": lid, "owner": String(link["owner"]), "cond": int(link["cond"]), "cure_by": row["decide_at"], "districts": ds}})
		return
	if world.month >= int(row["decide_at"]):
		row["greed"] = LawOps.record_greed(world, String(link["owner"]), {"kind": "ROAD_NEGLECT", "facility": lid,
			"saving": int(link["upkeep"]) * CURE_MONTHS})
		row["decide_at"] = world.month + CURE_MONTHS
		if Staff.autopilot(world, GOV):
			_apply_neglect(world, row, String(neglect_decision(world, row, link)["choice"]), "AI")
		else:
			_ask(world, row, link)


## The Minister of Infrastructure on a neglected private road. -> {options, choice}. REVOKE is on offer only for a
## licensed road after two notices within REPEAT_MONTHS or step-in costs unpaid DEBT_MONTHS. Market-minded
## governments leave the road to its owner (the district feels it); others step in; repeat neglect under a centrist
## or state-minded government costs the licence.
static func neglect_decision(world: WorldState, row: Dictionary, link: Dictionary) -> Dictionary:
	var opts: Array = ["STEP_IN", "LEAVE"]
	if may_revoke(world, row, link):
		opts.append("REVOKE")
	var econ := _econ(world)
	var choice := "LEAVE" if econ <= MARKET_LEAVES else "STEP_IN"
	if "REVOKE" in opts and econ >= 0:
		choice = "REVOKE"
	return {"options": opts, "choice": choice}


static func may_revoke(world: WorldState, row: Dictionary, link: Dictionary) -> bool:
	if String(link.get("licence", "")) == "":
		return false
	if (row["notices"] as Array).size() >= 2:
		return true
	for li in world.peek("liability").values():
		if String(li.get("kind", "")) == "ROAD_STEP_IN" and String(li.get("link", "")) == String(row["lid"]) \
				and String(li["status"]) == "OPEN" and world.month - int(li["due_month"]) >= DEBT_MONTHS:
			return true
	return false


static func _econ(world: WorldState) -> int:
	return int(world.peek("party").get(Staff.pm_party(world), {}).get("positions", {}).get("ECON_ROLE", 0))


static func _apply_neglect(world: WorldState, row: Dictionary, choice: String, by: String) -> void:
	var lid := String(row["lid"])
	var link := Transport.private_link(world, lid)
	if link.is_empty():
		return
	var owner := String(link["owner"])
	var co := {"kind": "COMPANY", "id": owner}
	var ds := link_districts(world, lid)
	var data := {"link": lid, "owner": owner, "cond": int(link["cond"]), "districts": ds, "decision": choice, "by": by}
	if choice == "STEP_IN":
		var params := {"type": "ROAD", "district": String(ds[0]) if not ds.is_empty() else "", "link": {"repair": lid},
			"step_in": true, "line": "ECON_BUDGET_INFRASTRUCTURE"}
		if String(params["district"]) != "" and EconActions.validate(world, "ECON_COMMISSION_PROJECT", params) == "" \
				and bool(EconActions.enqueue(world, "ECON_COMMISSION_PROJECT", params).get("ok", false)):
			row["step_in"] = world.month
			world.add_fact({"type": "LAW_ROAD_STEP_IN", "owner": "law", "subjects": [co, GOV],
				"responsible": [{"actor": GOV, "share": 1.0}], "impact": {}, "affected": {"districts": ds}, "magnitude": 25,
				"visibility": "PUBLIC", "data": data})
			return
		data["decision"] = "LEAVE"   # can't be paid for this year: the road stays as it is
		data["why"] = "NO_BUDGET"
		choice = "LEAVE"
	if choice == "REVOKE" and may_revoke(world, row, link):
		var lic: Dictionary = world.peek("road_licence").get(String(link["licence"]), {})
		if not lic.is_empty():
			lic["status"] = "REVOKED"
		row["revoked"] = world.month
		data["sell_by"] = world.month + REVOKED_SALE_MONTHS
		world.add_fact({"type": "LAW_ROAD_LICENCE_REVOKED", "owner": "law", "subjects": [co, GOV],
			"responsible": [{"actor": co, "share": 1.0}], "impact": {}, "affected": {"districts": ds},
			"magnitude": 35, "visibility": "PUBLIC", "data": data})
		return
	world.add_fact({"type": "LAW_PRIVATE_ROAD_UNENFORCED", "owner": "law", "subjects": [co, GOV],
		"responsible": [{"actor": co, "share": 0.8}, {"actor": GOV, "share": 0.2}],
		"impact": {"INFRASTRUCTURE": -2}, "affected": {"districts": ds}, "magnitude": 25, "visibility": "PUBLIC", "data": data})


## A player government: an office item to the Minister of Infrastructure, answered (or expired to the AI's choice).
static func _ask(world: WorldState, row: Dictionary, link: Dictionary) -> void:
	var dec := neglect_decision(world, row, link)
	var labels := {"STEP_IN": "Repair it at the owner's cost", "LEAVE": "Leave it to the owner", "REVOKE": "Revoke the licence"}
	var opts: Array = (dec["options"] as Array).map(func(o): return {"id": o, "label": labels[o], "action": {}})
	var org_name := String(world.peek("org").get(String(link["owner"]), {}).get("name", link["owner"]))
	row["pending"] = "NEGLECT"
	row["item"] = Office.post(world, {"kind": "EMAIL", "role": "ENGINEER", "category": "INFRASTRUCTURE", "priority": 45,
		"subject": "Neglected private road: %s" % org_name,
		"summary_lines": ["The road of %s is at %d%% condition and was not repaired after the notice." % [org_name, int(link["cond"]) / 10],
			"Repairing it puts the cost on the owner. Leaving it is felt in %s." % ", ".join(link_districts(world, String(row["lid"])))],
		"options": opts, "default_option": String(dec["choice"]), "deadline": world.month + 2,
		"source": {"system": "road_neglect", "ref": String(row["lid"])}})


static func _poll(world: WorldState, row: Dictionary) -> void:
	var o: Dictionary = world.peek("office_item").get(String(row["item"]), {})
	if not o.is_empty() and o["status"] in ["NEW", "READ"]:
		return
	var ans := String(o.get("answer", "")) if not o.is_empty() else ""
	var choice := ans if ans in NEGLECT_DECISIONS else String(o.get("default_option", "LEAVE"))
	row["pending"] = ""
	row["item"] = ""
	_apply_neglect(world, row, choice, "PLAYER")


## A failed owner (LIQUIDATION or DISSOLVED, or gone): the road may be sold with the estate for ESTATE_MONTHS; unsold,
## it reverts to the state without payment, and the owner's step-in debts on it lapse. -> true while the estate runs.
static func _estate(world: WorldState, row: Dictionary, link: Dictionary) -> bool:
	var o: Dictionary = world.peek("org").get(String(link["owner"]), {})
	if not o.is_empty() and not (String(o.get("status", "")) in DEAD):
		return false
	if int(row["estate"]) < 0:
		row["estate"] = world.month
	if world.month < int(row["estate"]) + ESTATE_MONTHS:
		return true
	var lid := String(row["lid"])
	var ds := link_districts(world, lid)
	_close_debts(world, lid, "WRITTEN_OFF")
	if Transport.transfer_link(world, lid, "", "REVERTED") == "":
		world.add_fact({"type": "LAW_ROAD_REVERTED", "owner": "law", "subjects": [{"kind": "COMPANY", "id": String(link["owner"])}],
			"responsible": [], "impact": {}, "affected": {"districts": ds}, "magnitude": 25, "visibility": "PUBLIC",
			"data": {"link": lid, "owner": String(link["owner"]), "districts": ds, "cond": int(link["cond"])}})
	return true


static func _close_debts(world: WorldState, lid: String, status: String) -> void:
	var t := world.peek("liability")
	for id in Det.ordered(t):
		var li: Dictionary = t[id]
		if String(li.get("kind", "")) == "ROAD_STEP_IN" and String(li.get("link", "")) == lid and String(li["status"]) == "OPEN":
			li["status"] = status


## The state takes a private road (design §4). mode AGREED (bought at an agreed price: ministers up to
## LAW_STATE_AID_THRESHOLD, the Cabinet above), COMPULSORY (without consent, for a public purpose: always the
## Cabinet's; below value it is an unlawful expropriation, recorded SECRET and still executed), REVOKED (a revoked road
## unsold in time). price -1 = the value (which nets out public money and the owner's step-in debts; those debts are
## set off). The price goes from the treasury to the owner, as far as the treasury holds it.
## -> {ok, value, price, paid, needs_cabinet, unlawful}
static func take_over(world: WorldState, lid: String, mode: String, price: int = -1, by: String = "AI") -> Dictionary:
	var link := Transport.private_link(world, lid)
	if link.is_empty() or not on(world):
		return {"ok": false}
	var v := value(world, lid)
	var p := v if price < 0 else price
	var owner := String(link["owner"])
	var co := {"kind": "COMPANY", "id": owner}
	var ds := link_districts(world, lid)
	var aid := int(world.levers.get("LAW_STATE_AID_THRESHOLD", 20)) * Staff.w_ref_milli(world)
	var needs_cabinet := mode != "AGREED" or p > aid
	var unlawful := false
	if mode == "COMPULSORY":
		var act := {"public_purpose": true, "compensation_pct": 100 if v <= 0 else p * 100 / v}
		if LawOps.validate(world, GOV, "EXPROPRIATE", act)["result"] == "PROHIBITED":
			unlawful = bool(LawOps.proceed_unlawfully(world, GOV, "EXPROPRIATE", act.merged({"link": lid}), "", co).get("ok", false))
	if Transport.transfer_link(world, lid, "", "TAKEOVER") != "":
		return {"ok": false}
	_close_debts(world, lid, "SET_OFF")
	world.table("road_watch").erase(lid)
	var paid := EconUtil.pay_upto(world, EconUtil.TREASURY, EconUtil.acct(owner), p, "ROAD_TAKEOVER") if p > 0 else 0
	world.add_fact({"type": "LAW_ROAD_TAKEN_OVER", "owner": "law", "subjects": [co, GOV],
		"responsible": [{"actor": GOV, "share": 1.0}], "impact": {}, "affected": {"districts": ds}, "magnitude": 35,
		"visibility": "PUBLIC", "data": {"link": lid, "owner": owner, "mode": mode, "price": p, "value": -1 if unlawful else v,
			"districts": ds, "decided_by": "CABINET" if needs_cabinet else "MINISTER", "by": by}})
	return {"ok": true, "value": v, "price": p, "paid": paid, "needs_cabinet": needs_cabinet, "unlawful": unlawful}

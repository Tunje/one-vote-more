extends RefCounted
## Anni: the law side of road safety (Terra's sim/transport/road_safety.gd, planning/spec-transport-v1.md T9; the note is
## planning/design-law-road-safety.md). Flag ROAD_SAFETY (opt-in; base unchanged without it). Preload, no class_name.
##
## Who decides:
## - A speed limit on any colony road, public or private, is a traffic order of the Minister of Infrastructure, alone:
##   it costs no money, only travel time. The government's case is gov_builder's SPEED_LIMIT (Maja, flag DELEGATION);
##   this file holds the law around it. Later a municipality orders limits on roads inside it (the note, §1).
## - A private road's owner may set a lower limit on its own road, never lift one the law or the minister set
##   (may_set_limit, owner_limit).
## - Parliament may set a default limit near homes and schools (lever LAW_SPEED_NEAR_HOMES 0 none / 1 → 70 / 2 → 50 /
##   3 → 30 km/h). It pre-sets the limit on every road with homes, a school or childcare in reach and costs their travel
##   time. The minister may exempt one road (exempt; raising a limit the law set does it, exempts() tells a case):
##   no ban, but a death there is the government's.
## - Liability is the courts': a death or injury where an over- or underpass had been on offer and refused (Terra's
##   pass_refused) is negligence of whoever keeps the road. A public road: the state. A private road: the owner, with
##   the state as traffic authority sharing (LIABLE_OWNER_SHARE). A private road under a neglect notice (road law,
##   PRIVATE_ROADS): the owner. The victims sue (TORT, into the victim fund).
##
## Facts:
## - LAW_SPEED_LIMITS_BY_LAW: parliament's default limit applied to N roads.
## - LAW_SPEED_EXEMPTION: a road exempted from the default limit.
## - LAW_ROAD_LIABLE_PASS and LAW_ROAD_LIABLE_NEGLECT: the court cases' causes, with blame.
## - LAW_ROAD_DEATH_LIMIT_DECLINED and LAW_ROAD_DEATH_EXEMPT: deaths where the government had declined a limit in the
##   last year, or had exempted the road. Blame only, no tort: setting limits is policy.

const Det := preload("res://sim/staff/det.gd")
const J := preload("res://sim/law/justice_ops.gd")
const LawOps := preload("res://sim/law/law_ops.gd")

const FLAG := "ROAD_SAFETY"
const GOV := {"kind": "GOVERNMENT", "id": "government"}
const LEVER := "LAW_SPEED_NEAR_HOMES"
const STATUTORY := [0, 70, 50, 30]                 # km/h by lever value
const HOMES := ["HOMES", "HOUSING", "SCHOOL", "CHILDCARE"]   # what near a road brings the default limit
const DECLINED_MONTHS := 12        # a death this soon after a declined limit is the government's
const DEATH_WREF := 15.0           # claim per death, W_ref
const INJURY_WREF := 2.0           # claim per injury, W_ref
const LIABLE_OWNER_SHARE := 0.6    # a refused pass on a private road: owner 0.6, the traffic authority 0.4
const LEFT_GOV_SHARE := 0.2        # a neglected private road the government chose to leave: its share


static func on(world: WorldState) -> bool:
	return (world.meta.get("on", []) as Array).has(FLAG) and not (world.meta.get("off", []) as Array).has(FLAG)


static func _st(world: WorldState) -> Dictionary:
	var t := world.table("speed_law")
	if t.is_empty():
		t["by_law"] = {}       # lid -> km/h the default limit set
		t["before"] = {}       # lid -> the limit the road had before the law set its own (0 none)
		t["owner_set"] = {}    # lid -> km/h a private owner set on its own road
		t["exempt"] = {}       # lid -> month exempted
		t["filed"] = {}        # accident fact id -> true
	return t


## The default limit near homes and schools, km/h (0 = none).
static func statutory(world: WorldState) -> int:
	return int(STATUTORY[clampi(int(world.levers.get(LEVER, 0)), 0, STATUTORY.size() - 1)])


## Does the default limit reach this link (homes, a school or childcare in reach of it)?
static func near_homes(world: WorldState, lid: String) -> bool:
	for sp in RoadSafety.spots(world, lid):
		if String(sp[3]) in HOMES:
			return true
	return false


## Who may set this limit: "MINISTER" (always, the traffic authority) or an org id (the private road's owner: only a
## limit, never lower than none, never above the law's or the minister's). → "" or why not.
static func may_set_limit(world: WorldState, lid: String, kmh: int, who: String) -> String:
	if not on(world):
		return "Road safety is not in this game"
	if who == "MINISTER":
		return ""
	var l: Dictionary = Transport._links(world).get(lid, {})
	if l.is_empty() or String(l.get("owner", "")) != who:
		return "Only the road's owner or the minister sets its limit"
	if kmh <= 0:
		return "An owner cannot lift a limit"
	var st: Dictionary = world.peek("speed_law")
	var cur := int(l.get("limit", 0))
	var cap := int(st.get("by_law", {}).get(lid, 0))
	if cur > 0 and int(st.get("owner_set", {}).get(lid, 0)) != cur:
		cap = cur if cap == 0 else mini(cap, cur)       # the minister's or the law's limit stands
	if cap > 0 and kmh > cap:
		return "Above the limit the law or the minister set (%d km/h)" % cap
	return ""


## A private road's owner sets a limit on its own road (may_set_limit first). → "" or why not.
static func owner_limit(world: WorldState, lid: String, kmh: int, org: String) -> String:
	var why := may_set_limit(world, lid, kmh, org)
	if why != "":
		return why
	why = Transport.set_limit(world, lid, kmh)
	if why == "":
		_st(world)["owner_set"][lid] = kmh
	return why


## Would the minister's limit on this road go above the default limit? Then it is an exemption: lawful, but a death there
## is the government's (LAW_ROAD_DEATH_EXEMPT). For the case's label. kmh 0 = no limit.
static func exempts(world: WorldState, lid: String, kmh: int) -> bool:
	var law := int(world.peek("speed_law").get("by_law", {}).get(lid, 0))
	return on(world) and law > 0 and (kmh == 0 or kmh > law)


## DECISIONS (law provider): parliament's default limit. The minister's own limits are the government's cases
## (gov_builder SPEED_LIMIT, flag DELEGATION); raising a road above the default limit there exempts it.
static func monthly(world: WorldState) -> void:
	if not on(world):
		return
	apply_statutory(world)


## The default limit near homes: set on every road it reaches (unless exempt or already lower); loosened or lifted where
## the law had set it when parliament changes the lever (back to the limit the road had before). A road the law had
## limited whose limit someone raised (the minister) is exempt from then on; lowered, the lower limit governs. One fact
## a month when roads changed.
static func apply_statutory(world: WorldState) -> void:
	var st := _st(world)
	var target := statutory(world)
	if target == 0 and (st["by_law"] as Dictionary).is_empty():
		return
	var links := Transport._links(world)
	var changed := 0
	var ds: Array = []
	for lid in EconUtil.sorted_keys(links):
		var l: Dictionary = links[lid]
		if int(l.get("globe", 0)) == 1:
			continue
		var cur := int(l.get("limit", 0))
		var mine := int(st["by_law"].get(lid, 0))
		if mine > 0 and cur != mine:
			st["by_law"].erase(lid)
			st["before"].erase(lid)
			if cur == 0 or cur > mine:
				exempt(world, lid, "MINISTER")
			mine = 0
		var want := cur
		if target > 0 and near_homes(world, lid) and not st["exempt"].has(lid):
			if cur == 0 or cur > target or (mine > 0 and target > cur):
				want = target
		elif mine > 0:
			want = int(st["before"].get(lid, 0))       # lifted: back to the road's own limit
		if want == cur:
			continue
		if Transport.set_limit(world, lid, want) != "":
			continue
		changed += 1
		if want > 0 and want == target and not (mine == 0 and want == cur):
			if mine == 0:
				st["before"][lid] = cur
			st["by_law"][lid] = want
		else:
			st["by_law"].erase(lid)
			st["before"].erase(lid)
		var d := _district(world, l)
		if d != "" and not d in ds:
			ds.append(d)
	if changed > 0:
		LawOps.law_fact(world, "LAW_SPEED_LIMITS_BY_LAW", "PUBLIC", [GOV], [{"actor": GOV, "share": 1.0}],
			{"SAFETY": 2, "INFRASTRUCTURE": -1}, 20, {"kmh": target, "roads": changed, "districts": ds})


static func _district(world: WorldState, l: Dictionary) -> String:
	var p: Array = l.get("path", [])
	if p.is_empty():
		return ""
	return Transport._district_near(ColonyLayout.settlements(world), Transport.int_tile(int(p[p.size() / 2])))


## The minister exempts one road from the default limit (a fast road past a village). A death there is the government's.
static func exempt(world: WorldState, lid: String, by: String) -> void:
	var st := _st(world)
	if st["exempt"].has(lid):
		return
	st["exempt"][lid] = world.month
	var l: Dictionary = Transport._links(world).get(lid, {})
	LawOps.law_fact(world, "LAW_SPEED_EXEMPTION", "PUBLIC", [GOV], [{"actor": GOV, "share": 1.0}], {"SAFETY": -1}, 20,
		{"link": lid, "district": _district(world, l) if not l.is_empty() else "", "law_kmh": statutory(world), "by": by,
			"decided_by": "MINISTER"})


## The government declined a limit on this road in the last DECLINED_MONTHS: its SPEED_LIMIT case answered WAIT, on the
## desk (an office item) or by the minister at "make the call" (fact POL_CASE_CALLED).
static func declined(world: WorldState, lid: String) -> bool:
	for o in world.peek("office_item").values():
		if String(o.get("source", {}).get("ref", "")) == "SAFE_LIMIT|" + lid and String(o.get("answer", "")) == "WAIT" \
				and world.month - int(o.get("answered_month", -9999)) <= DECLINED_MONTHS:
			return true
	for f in Det.recent_facts(world, "POL_CASE_CALLED", world.month - DECLINED_MONTHS):   # decided at "make the call" (Maja)
		if String(f["data"].get("ref", "")) == "SAFE_LIMIT|" + lid and String(f["data"].get("answer", "")) == "WAIT":
			return true
	return false


# ================================================================== liability (JUSTICE)

## This month's road accidents with casualties: who kept the road, and whether they failed a duty.
static func justice(world: WorldState) -> void:
	if not on(world):
		return
	var st := _st(world)
	for f in Det.recent_facts(world, "TRANSPORT_ROAD_ACCIDENT", world.month):
		var fid := String(f["id"])
		var d: Dictionary = f["data"]
		var killed := int(d.get("killed", 0))
		var hurt := int(d.get("injured", 0))
		if st["filed"].has(fid) or killed + hurt <= 0:
			continue
		st["filed"][fid] = true
		var lid := String(d.get("link", ""))
		var owner := String(d.get("owner", ""))
		var district := String(d.get("district", ""))
		var aff := {"districts": [district]}
		var base := {"accident": fid, "link": lid, "district": district, "killed": killed, "injured": hurt, "kmh": int(d.get("kmh", 0)),
			"limit": int(d.get("limit", 0)), "owner": owner}
		var causes: Array = []
		var resp: Array = []
		if bool(d.get("pass_refused", false)):
			causes.append("PASS_REFUSED")
			resp = [{"actor": GOV, "share": 1.0}] if owner == "" else \
				[{"actor": {"kind": "COMPANY", "id": owner}, "share": LIABLE_OWNER_SHARE}, {"actor": GOV, "share": 1.0 - LIABLE_OWNER_SHARE}]
			var data := base.duplicate()
			data["offered_since"] = int(d.get("offered_since", -1))
			_fact(world, "LAW_ROAD_LIABLE_PASS", resp, killed, hurt, aff, data)
		if owner != "" and _neglected(world, lid):
			causes.append("NEGLECT")
			var gs := LEFT_GOV_SHARE if _left(world, lid) else 0.0
			var r2: Array = [{"actor": {"kind": "COMPANY", "id": owner}, "share": 1.0 - gs}]
			if gs > 0.0:
				r2.append({"actor": GOV, "share": gs})
			if resp.is_empty():
				resp = r2
			_fact(world, "LAW_ROAD_LIABLE_NEGLECT", r2, killed, hurt, aff, base.duplicate())
		if killed > 0 and st["exempt"].has(lid):
			_fact(world, "LAW_ROAD_DEATH_EXEMPT", [{"actor": GOV, "share": 1.0}], killed, hurt, aff, base.duplicate())
		elif killed > 0 and declined(world, lid):
			_fact(world, "LAW_ROAD_DEATH_LIMIT_DECLINED", [{"actor": GOV, "share": 1.0}], killed, hurt, aff, base.duplicate())
		if causes.is_empty():
			continue
		var claim := int(round((float(killed) * DEATH_WREF + float(hurt) * INJURY_WREF) * float(J.w_ref(world))))
		var public := owner == ""
		var gov_share := 0.0
		if not public:
			for x in resp:
				if x["actor"] == GOV:
					gov_share = float(x["share"])
		J.init_courts(world)
		J.file_case(world, "TORT", {"kind": "VICTIMS", "id": fid, "scope": aff}, GOV if public else {"kind": "COMPANY", "id": owner},
			true, {"fact": fid, "claim": claim, "gov_share": gov_share, "road": true, "causes": causes, "link": lid}, [800])


static func _fact(world: WorldState, type: String, resp: Array, killed: int, hurt: int, aff: Dictionary, data: Dictionary) -> void:
	world.add_fact({"type": type, "owner": "law", "subjects": [GOV], "responsible": resp, "impact": {"SAFETY": -2 - 2 * killed},
		"magnitude": clampi(25 + 20 * killed + 5 * hurt, 0, 80), "visibility": "PUBLIC", "affected": aff, "data": data})


## A private road under a neglect notice (road law, PRIVATE_ROADS).
static func _neglected(world: WorldState, lid: String) -> bool:
	return int(world.peek("road_watch").get(lid, {}).get("notice", -1)) >= 0


## The government chose to leave this neglected road in the last year.
static func _left(world: WorldState, lid: String) -> bool:
	for f in Det.recent_facts(world, "LAW_PRIVATE_ROAD_UNENFORCED", world.month - 12):
		if String(f["data"].get("link", "")) == lid:
			return true
	return false

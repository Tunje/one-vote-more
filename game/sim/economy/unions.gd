class_name Unions
extends RefCounted
## U1 (user decision A41, planning/spec-unions-v1.md §1): unions as organisations.
## Table "union", one row per union (ids "union:N"; ledger account row["acct"] = "union:" + id, closed ledger):
##   {id, name, sectors: [occ], share: {occ: 0..1 of that sector's organised workers}, members (mu), density (‰ of the
##    union's sector employment, 0..1000), acct, dues_pm (milli per member-month), leader: {name, militancy, competence,
##    ambition, since}, mood (0..100 grievance), status ACTIVE|MERGED|DISSOLVED, founded, federation: bool,
##    affiliated_to (union id or ""), lapsed (mu, unemployed members kept for a while), election_due (month),
##    lost_strikes, last_strike_result, moderate_high_mood_m}
## Monthly (SOCIAL, after EconUnions.publish_density):
##   - founding: one union per unionised occupation from month FOUND_MONTH once the sector employs MIN_SECTOR persons;
##     the federation once FED_MIN unions exist (all affiliate except the Professionals' Association, moderate by nature);
##   - members = sector density (EconUnions.density, the M9 targets) × employed in the sector × the union's share; members
##     who lose their job lapse slowly (LAPSE_KEEP kept, fading over LAPSE_MONTHS);
##   - dues from the household pools of the employed members' groups into the fund; FED_SHARE of affiliates' dues
##     to the federation;
##   - mood (U1 baseline: real-wage and labour-law grievances, sector layoffs; U2 adds disputes);
##   - leader elections every ELECTION_M months or when U2 sets election_due (after a lost strike);
##   - rare mergers of two small unions in related sectors, and militant breakaways from a moderate leadership that
##     ignores high mood.
## Power and water staff work for the public utility, so they are PUBLIC_SECTOR members (Public Servants' Union).

const S := EconUtil.S
const FOUND_MONTH := 12
const MIN_SECTOR := 15  # persons employed before a sector union is founded
const FED_MIN := 3
const FED_SHARE := 0.10
const DUES_SHARE := 0.01  # of the General wage, per member-month
const LAPSE_KEEP := 0.3
const LAPSE_MONTHS := 12
const ELECTION_M := 48
const STRIKE_PAY_SHARE := 0.5  # strike pay per striking member-month, share of the General wage (U2 pays it)
const MERGE_MAX := 40  # persons: both unions below this to merge
const MERGE_P := 1.0 / 120.0
const MERGE_MAX_SECTORS := 2
const EMPTY_DISSOLVE_M := 24
const RELIEF_M := 24  # months over which a settlement's relief fades
const MERGE_GAP_M := 120
const SPLIT_MOOD := 70
const SPLIT_AFTER_M := 24
const SPLIT_P := 1.0 / 60.0
const SPLIT_SHARE := 0.3
const NAMES := {"MINING": "Miners' Union", "CONSTRUCTION": "Builders' Union", "LOGISTICS": "Transport & Depot Workers",
	"MANUFACTURING": "Plant Workers' Union", "AGRICULTURE": "Farm Workers' Union", "PUBLIC_SECTOR": "Public Servants' Union",
	"SERVICES": "Shop & Service Workers", "PROFESSIONAL": "Professionals' Association"}
const FED_NAME := "Colony Federation of Labour"
const RELATED := [["MINING", "MANUFACTURING"], ["CONSTRUCTION", "MANUFACTURING"], ["LOGISTICS", "SERVICES"],
	["AGRICULTURE", "SERVICES"], ["MINING", "CONSTRUCTION"]]
const MODERATE := ["PROFESSIONAL"]


# ------------------------------------------------------------------ accessors (read-only; other modules use these)

## Active unions (federation included), in id order.
static func active(world: WorldState) -> Array:
	var out: Array = []
	var t := world.peek("union")
	for id in EconUtil.sorted_keys(t):
		if t[id]["status"] == "ACTIVE":
			out.append(t[id])
	return out


static func get_union(world: WorldState, id: String) -> Dictionary:
	return world.peek("union").get(id, {})


## The active sector union that organises the most of an occupation, or {}.
static func of_occ(world: WorldState, occ: String) -> Dictionary:
	var best := {}
	for u in active(world):
		if u["federation"] or not occ in u["sectors"]:
			continue
		if best.is_empty() or float(u["share"].get(occ, 0.0)) > float(best["share"].get(occ, 0.0)):
			best = u
	return best


## Every active sector union with members in an occupation (after a breakaway there are two).
static func all_of_occ(world: WorldState, occ: String) -> Array:
	return active(world).filter(func(u): return not u["federation"] and occ in u["sectors"])


## Union density at one employer (‰): its dominant occupation's sector density (v1 keeps no per-firm membership),
## and the union organising it. {occ, density_pm, union}.
static func at_employer(world: WorldState, org_id: String) -> Dictionary:
	if not world.peek("org").has(org_id):
		return {"occ": "", "density_pm": 0, "union": ""}
	var occ := EconUnions._dominant(EconUnions._org_workforce(world, org_id)["occ"])
	var u := of_occ(world, occ)
	return {"occ": occ, "density_pm": EconUnions.density(world, occ) / 100, "union": "" if u.is_empty() else String(u["id"])}


static func federation(world: WorldState) -> Dictionary:
	for u in active(world):
		if u["federation"]:
			return u
	return {}


static func fund(world: WorldState, id: String) -> int:
	var u := get_union(world, id)
	return 0 if u.is_empty() else world.ledger.balance(String(u["acct"]))


## Strike pay per striking member-month (milli).
static func strike_pay(world: WorldState) -> int:
	return int(float(EconUtil.peek_st(world)["wage"]["G"]) * STRIKE_PAY_SHARE)


## Weeks of strike pay the fund can carry for all members (U2's strike decision; 0 for the federation).
static func strike_weeks(world: WorldState, id: String) -> float:
	var u := get_union(world, id)
	if u.is_empty() or u["federation"] or int(u["members"]) <= 0:
		return 0.0
	var per_month := float(u["members"]) / S * float(strike_pay(world))
	return 4.33 * float(fund(world, id)) / maxf(1.0, per_month)


## What a union can give away (donations, a paper) without touching its strike reserve (8 weeks of strike pay).
static func spare_fund(world: WorldState, id: String) -> int:
	var u := get_union(world, id)
	if u.is_empty():
		return 0
	var reserve := 0
	if not u["federation"]:
		reserve = int(8.0 / 4.33 * float(u["members"]) / S * float(strike_pay(world)))
	return maxi(0, fund(world, id) - reserve)


# ------------------------------------------------------------------ monthly (SOCIAL)

static func monthly(world: WorldState) -> void:
	if EconUtil.off(world, "UNIONS_U1"):
		return
	var emp := EconUnions.employed_by_occ(world)
	_found_unions(world, emp)
	_members(world, emp)
	_dues(world)
	_mood(world)
	_elections(world)
	_merge_and_split(world)


static func _new_union(world: WorldState, name: String, sectors: Array, share: Dictionary, fed: bool, militancy_bias: float) -> Dictionary:
	var id := world.new_id("union")
	var u := {"id": id, "name": name, "sectors": sectors.duplicate(), "share": share.duplicate(), "members": 0, "density": 0,
		"acct": "union:" + id, "dues_pm": 0, "leader": {}, "mood": 30, "status": "ACTIVE", "founded": world.month,
		"federation": fed, "affiliated_to": "", "lapsed": 0, "election_due": world.month + ELECTION_M, "lost_strikes": 0,
		"last_strike_result": "", "moderate_high_mood_m": 0}
	world.table("union")[id] = u
	world.ledger.open_account(u["acct"])
	u["leader"] = _make_leader(world, u, militancy_bias)
	return u


static func _make_leader(world: WorldState, u: Dictionary, target_militancy: float) -> Dictionary:
	var r := world.rng.stream("econ.unions.orgs")
	var used := {}
	for x in world.peek("union").values():
		used[str(x.get("leader", {}).get("name", ""))] = true
	var nm := PartyGen.leader_name(world.rng.stream("econ.unions.names"))
	for _i in 20:
		if not used.has(nm):
			break
		nm = PartyGen.leader_name(world.rng.stream("econ.unions.names"))
	return {"name": nm, "militancy": clampi(int(round(target_militancy + r.randfn(0.0, 12.0))), 5, 95),
		"competence": clampi(int(round(r.randfn(55.0, 15.0))), 5, 95), "ambition": clampi(int(round(r.randfn(50.0, 18.0))), 5, 95),
		"since": world.month}


static func _emit(world: WorldState, type: String, u: Dictionary, impact: Dictionary, mag: int, data: Dictionary) -> void:
	var d := data.duplicate()
	d["union"] = u["id"]
	d["name"] = u["name"]
	EconFacts.emit(world, type, null, [["UNION", u["id"]]], [["UNION", u["id"], 1.0]], impact, mag, "PUBLIC", d)


static func _found_unions(world: WorldState, emp: Dictionary) -> void:
	if world.month < FOUND_MONTH:
		return
	for occ in EconUtil.sorted_keys(NAMES):
		if not all_of_occ(world, occ).is_empty() or int(emp.get(occ, 0)) < MIN_SECTOR * S:
			continue
		var bias := 35.0 if occ in MODERATE else 50.0
		var u := _new_union(world, NAMES[occ], [occ], {occ: 1.0}, false, bias)
		var fed := federation(world)
		if not fed.is_empty() and not occ in MODERATE:
			u["affiliated_to"] = fed["id"]
		_emit(world, "UNION_FOUNDED", u, {"FAIRNESS": 3}, 25, {"sectors": u["sectors"], "leader": u["leader"]["name"]})
	var sector_unions := active(world).filter(func(x): return not x["federation"])
	if federation(world).is_empty() and sector_unions.size() >= FED_MIN:
		var f := _new_union(world, FED_NAME, [], {}, true, 50.0)
		for x in sector_unions:
			if not (x["sectors"][0] in MODERATE):
				x["affiliated_to"] = f["id"]
		_emit(world, "UNION_FOUNDED", f, {"FAIRNESS": 5}, 35, {"federation": true, "affiliates": sector_unions.size(),
			"leader": f["leader"]["name"]})


static func _members(world: WorldState, emp: Dictionary) -> void:
	var fed := federation(world)
	var fed_members := 0
	for u in active(world):
		if u["federation"]:
			continue
		var m := 0
		var sector_emp := 0
		for occ in u["sectors"]:
			var dens := float(EconUnions.density(world, occ)) / 100000.0
			m += int(float(emp.get(occ, 0)) * dens * float(u["share"].get(occ, 1.0)))
			sector_emp += int(float(emp.get(occ, 0)) * float(u["share"].get(occ, 1.0)))
		# members who lose their job: LAPSE_KEEP of them stay on the books, fading over LAPSE_MONTHS
		var drop := int(u["members"]) - int(u["lapsed"]) - m
		var lapsed := int(float(u["lapsed"]) * (1.0 - 1.0 / float(LAPSE_MONTHS)))
		if drop > 0:
			lapsed += int(float(drop) * LAPSE_KEEP)
		u["lapsed"] = lapsed
		u["members"] = m + lapsed
		u["density"] = int(1000.0 * float(m) / maxf(1.0, float(sector_emp)))
		# a union whose sector has emptied (e.g. every mine went to the public utility, whose staff are public servants)
		# winds up after EMPTY_DISSOLVE_M months below one member; its fund goes to the federation
		u["empty_m"] = int(u.get("empty_m", 0)) + 1 if int(u["members"]) < S else 0
		if int(u["empty_m"]) >= EMPTY_DISSOLVE_M:
			_dissolve(world, u, fed)
		if not fed.is_empty() and u["affiliated_to"] == fed["id"]:
			fed_members += int(u["members"])
	if not fed.is_empty():
		fed["members"] = fed_members
		var all_emp := 0
		for occ in emp:
			all_emp += int(emp[occ])
		fed["density"] = int(1000.0 * float(fed_members) / maxf(1.0, float(all_emp)))


static func _dissolve(world: WorldState, u: Dictionary, fed: Dictionary) -> void:
	u["status"] = "DISSOLVED"
	u["dissolved"] = world.month
	var amt := world.ledger.balance(u["acct"])
	var to := ""
	if not fed.is_empty() and fed["id"] != u["id"]:
		to = String(fed["acct"])
	if amt > 0 and to != "":
		world.ledger.transfer(u["acct"], to, amt, "UNION_DISSOLVED", world.month)
	_emit(world, "UNION_DISSOLVED", u, {}, 20, {"sectors": u["sectors"], "fund_to": to, "amount": amt / S})


## Dues: per employed member, from the household pools whose people hold those jobs; affiliates pass FED_SHARE on.
static func _dues(world: WorldState) -> void:
	var due := int(float(EconUtil.st(world)["wage"]["G"]) * DUES_SHARE)
	var fed := federation(world)
	for u in active(world):
		if u["federation"]:
			continue
		u["dues_pm"] = due
		var got := 0
		for gid in EconUtil.sorted_keys(world.table("hh")):
			var e: Dictionary = world.table("hh")[gid].get("emp", {})
			var n := 0.0
			for occ in u["sectors"]:
				n += float(e.get(occ, 0)) * float(EconUnions.density(world, occ)) / 100000.0 * float(u["share"].get(occ, 1.0))
			var amt := int(n / S * float(due))
			if amt > 0:
				got += EconUtil.pay_upto(world, EconUtil.hh_acct(gid), u["acct"], amt, "UNION_DUES")
		if not fed.is_empty() and u["affiliated_to"] == fed["id"] and got > 0:
			EconUtil.pay_upto(world, u["acct"], fed["acct"], int(float(got) * FED_SHARE), "UNION_AFFILIATION")


## U1 baseline grievance 0..100 (smoothed): real wages, labour law, layoffs in the union's sectors. U2 adds disputes.
static func _mood(world: WorldState) -> void:
	var lay := {}
	var s := EconUtil.st(world)
	for k in s.get("layoffs_m", {}):
		var parts: PackedStringArray = str(k).split("|")
		var o: Dictionary = world.table("org").get(parts[0], {})
		if o.is_empty():
			continue
		var occ := "PUBLIC_SECTOR" if o["type"] in EconData.PUBLIC_TYPES else ("CONSTRUCTION" if o["is_contractor"] else "")
		if occ == "":
			for fid in world.table("facility"):
				var f: Dictionary = world.table("facility")[fid]
				if f["org"] == parts[0]:
					occ = EconData.RECIPES[f["type"]]["occ"]
					break
		lay[occ] = int(lay.get(occ, 0)) + int(s["layoffs_m"][k])
	var emp := EconUnions.employed_by_occ(world)
	var fed_sum := 0.0
	var fed_n := 0
	for u in active(world):
		if u["federation"]:
			continue
		var g := 0.0
		var laid := 0.0
		var base := 0.0
		for occ in u["sectors"]:
			g = maxf(g, EconUnions.wage_grievance(world, occ) + EconUnions.law_grievance(world, occ))
			laid += float(lay.get(occ, 0))
			base += float(emp.get(occ, 0))
		var target := 20.0 + 25.0 * g + 300.0 * laid / maxf(1.0, base)
		# relief from the last settlement, fading over RELIEF_M months (U2 sets it)
		target -= float(u.get("relief", 0.0)) * maxf(0.0, 1.0 - float(world.month - int(u.get("relief_m", -9999))) / float(RELIEF_M))
		if u["sectors"].size() > 0 and u["sectors"][0] in MODERATE:
			target *= 0.75  # the professions are slower to anger
		if u["last_strike_result"] == "LOST":
			target += 10.0
		u["mood"] = clampi(int(round(float(u["mood"]) + (clampf(target, 0.0, 100.0) - float(u["mood"])) / 6.0)), 0, 100)
		fed_sum += float(u["mood"]) * float(u["members"])
		fed_n += int(u["members"])
	var fed := federation(world)
	if not fed.is_empty():
		fed["mood"] = int(round(fed_sum / maxf(1.0, float(fed_n))))


## Leader elections: every ELECTION_M months or when due early (U2 sets election_due after a lost strike). Members
## pick a militant when mood is high, a moderate when the fund is thin or the last strike was lost.
static func _elections(world: WorldState) -> void:
	var r := world.rng.stream("econ.unions.orgs")
	for u in active(world):
		if world.month < int(u["election_due"]):
			continue
		var target := 25.0 + 0.6 * float(u["mood"])
		if not u["federation"] and strike_weeks(world, u["id"]) < 4.0:
			target -= 15.0
		if u["last_strike_result"] == "LOST":
			target -= 15.0
		if u["sectors"].size() > 0 and u["sectors"][0] in MODERATE:
			target -= 15.0
		var lead: Dictionary = u["leader"]
		var keep_p := 0.5 + (float(lead.get("competence", 50)) - 50.0) / 200.0 - absf(target - float(lead.get("militancy", 50))) / 100.0
		var old := str(lead.get("name", ""))
		var kept := r.randf() < keep_p
		if not kept:
			u["leader"] = _make_leader(world, u, target)
		u["election_due"] = world.month + ELECTION_M
		_emit(world, "UNION_LEADER_ELECTED", u, {}, 20 if kept else 30, {"leader": u["leader"]["name"], "re_elected": kept,
			"previous": old, "militancy": u["leader"]["militancy"], "mood": u["mood"]})


static func _merge_and_split(world: WorldState) -> void:
	var r := world.rng.stream("econ.unions.orgs")
	# merger: two small active unions in related sectors
	for pair in RELATED:
		var a := of_occ(world, pair[0])
		var b := of_occ(world, pair[1])
		if a.is_empty() or b.is_empty() or a["id"] == b["id"]:
			continue
		if int(a["members"]) >= MERGE_MAX * S or int(b["members"]) >= MERGE_MAX * S:
			continue
		# no snowballing (Wilma's U1 review): a merged union covers at most MERGE_MAX_SECTORS sectors, and a union
		# merges at most once per MERGE_GAP_M months
		var covered := {}
		for occ in a["sectors"] + b["sectors"]:
			covered[occ] = true
		if covered.size() > MERGE_MAX_SECTORS:
			continue
		if world.month - int(a.get("last_merge", -9999)) < MERGE_GAP_M or world.month - int(b.get("last_merge", -9999)) < MERGE_GAP_M:
			continue
		if r.randf() >= MERGE_P:
			continue
		var big := a if int(a["members"]) >= int(b["members"]) else b
		var small := b if big["id"] == a["id"] else a
		for occ in small["sectors"]:
			if not occ in big["sectors"]:
				big["sectors"].append(occ)
			big["share"][occ] = minf(1.0, float(big["share"].get(occ, 0.0)) + float(small["share"].get(occ, 1.0)))
		var amt := world.ledger.balance(small["acct"])
		if amt > 0:
			world.ledger.transfer(small["acct"], big["acct"], amt, "UNION_MERGER", world.month)
		small["status"] = "MERGED"
		small["merged_into"] = big["id"]
		big["last_merge"] = world.month
		big["lapsed"] = int(big["lapsed"]) + int(small["lapsed"])
		_emit(world, "UNION_MERGED", big, {}, 30, {"absorbed": small["id"], "absorbed_name": small["name"], "sectors": big["sectors"]})
		return  # at most one structural change a month
	# breakaway: a moderate leadership sitting on high mood for SPLIT_AFTER_M months
	for u in active(world):
		if u["federation"]:
			continue
		var moderate := int(u["leader"].get("militancy", 50)) < 40
		u["moderate_high_mood_m"] = int(u["moderate_high_mood_m"]) + 1 if moderate and int(u["mood"]) >= SPLIT_MOOD else 0
		if int(u["moderate_high_mood_m"]) < SPLIT_AFTER_M or r.randf() >= SPLIT_P:
			continue
		var share := {}
		for occ in u["sectors"]:
			var sh := float(u["share"].get(occ, 1.0))
			share[occ] = sh * SPLIT_SHARE
			u["share"][occ] = sh * (1.0 - SPLIT_SHARE)
		var nu := _new_union(world, "%s (Rank and File)" % u["name"], u["sectors"], share, false, 80.0)
		nu["mood"] = u["mood"]
		nu["affiliated_to"] = ""
		var amt := int(float(world.ledger.balance(u["acct"])) * SPLIT_SHARE)
		if amt > 0:
			world.ledger.transfer(u["acct"], nu["acct"], amt, "UNION_SPLIT", world.month)
		u["moderate_high_mood_m"] = 0
		_emit(world, "UNION_SPLIT", nu, {"FAIRNESS": -3}, 35, {"from": u["id"], "from_name": u["name"], "leader": nu["leader"]["name"],
			"sectors": nu["sectors"]})
		return

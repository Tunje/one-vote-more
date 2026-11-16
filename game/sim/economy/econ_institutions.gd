extends RefCounted
## The eight rules for public institutions (planning/eight-rules.md, "Who decides in whose place" and 3a.4; Maja,
## 2026-11-16). Switch R8_INSTITUTIONS, only together with R8 (EconRules.sector_on). Without it nothing here runs and
## clinics and schools keep today's crew: one budget ratio for every plant, whatever its district needs.
##
## Institutions are free, so there are no price rules (1/2). Nobody but the state may run one, so there are no
## founding rules (7/8). What remains:
##   3/4 CREWS TO THE CLIENTS. Each open clinic or school asks for the crew share (T) that serves the people who
##       actually come: its district's own need (residents for a clinic, school-age children for a school) plus its
##       share, by capacity, of the need of districts that have no plant of that type, plus a small margin. No floor
##       of our own: with no clients the ask falls to nothing. The budget line then pays for that: if it covers every plant's ask, each plant gets its
##       ask (a smaller ask leaves money on the line, so posts fall when clients fall); if not, every ask is cut
##       by the same share. So the money goes where the clients are, instead of the same share everywhere.
##   BUDGET REQUEST. When the asks cost more than the line for REQ_HOLD_M months (by more than REQ_GAP_PM ‰), or
##       less than CUT_PM ‰ of it for CUT_HOLD_M months, the institution asks the government for the line that
##       serves everyone (budget_requests). The government decides (Wilma: legislature and gov_builder; a case on
##       the decision desk under DELEGATION). At most one request per line every REQ_EVERY_M months; answered()
##       starts that clock. The care lines (EconCare, which already sizes its posts to need) ask the same way.
##   5   BUILD. Where a district's clients exceed what its open plants hold at a full crew, or a district without a
##       plant is left unserved by the others' spare room, build_needs lists the plants needed (a mothballed plant
##       there is reopened first). The government builds.
##   6   CLOSE. A plant whose ask stays at or below EMPTY_PM ‰ for CLOSE_HOLD_M months whose clients the other open plants in its district
##       can hold is a close candidate (close_candidates). Never the last plant of a district, never while anyone in
##       its reach is unserved. The government closes (close / reopen).
## ADMIN keeps the budget ratio: its output is read by nothing, so it has no clients to follow.
## Units as EconProduction: need and capacity in persons × S (a clinic at full serves 2500 residents, a school 450
## pupils); T and shares in ‰; money as EconFinance.wage_for × posts (mcr a month), the line in kcr a year.
## State: st["r8_inst"] = {t: {fid: T‰}, need: {type: {district: row}}, req: {line: {up_m, down_m, asked, answered,
## ask, now}}, low_m: {fid: months standing empty}}. Written once a month (EconRules.monthly, end of TRADE); read by FirmAI
## the next month. Pure in the world state, saved with it.

const S := EconUtil.S
const TYPES := {
	"CLINIC": {"line": "ECON_BUDGET_HEALTH", "lever_max": 4000},
	"SCHOOL": {"line": "ECON_BUDGET_EDUCATION", "lever_max": 3000},
}
const CARE_LINES := {"ELDER": "ECON_BUDGET_ELDER_CARE", "CHILD": "ECON_BUDGET_CHILDCARE"}
const CARE_MAX := {"ELDER": 1500, "CHILD": 3000}
## Defaults; EconRules.SECTORS["INSTITUTIONS"]["params"] overrides any of them.
const DEFAULTS := {"empty_pm": 200, "margin": 50, "req_gap_pm": 100, "req_hold_m": 3, "req_every_m": 12, "cut_pm": 850,
	"cut_hold_m": 12, "close_hold_m": 12, "build_min_pm": 300}


static func on(world: WorldState) -> bool:
	return EconRules.sector_on(world, "INSTITUTIONS")


static func p(key: String) -> int:
	var row: Dictionary = EconRules.SECTORS.get("INSTITUTIONS", {}).get("params", {})
	return int(row.get(key, DEFAULTS[key]))


static func _st(world: WorldState) -> Dictionary:
	var s := EconUtil.st(world)
	if not s.has("r8_inst"):
		s["r8_inst"] = {"t": {}, "need": {}, "req": {}, "low_m": {}, "care": {}}
	return s["r8_inst"]


## FirmAI's crew share for an institution plant: this month's T, or `dflt` (today's budget ratio) for a plant the
## rules have not seen yet or a type they don't run (ADMIN).
static func target(world: WorldState, f: Dictionary, dflt: float) -> float:
	if not on(world):
		return dflt
	var t: Dictionary = EconUtil.peek_st(world).get("r8_inst", {}).get("t", {})
	if not t.has(f["id"]):
		return dflt
	return float(int(t[f["id"]])) / 1000.0


# ------------------------------------------------------------------ monthly (EconRules.monthly, end of TRADE)

static func monthly(world: WorldState) -> void:
	if not on(world):
		return
	var r := _st(world)
	var t_all := {}
	var need_all := {}
	for typ in EconUtil.sorted_keys(TYPES):
		var res := _type_month(world, typ, r)
		t_all.merge(res["t"])
		need_all[typ] = res["rows"]
		_request_clock(world, r, String(TYPES[typ]["line"]), int(res["ask"]), int(res["now"]), int(res["unmet"]), int(res["clients"]), typ)
	r["t"] = t_all
	r["need"] = need_all
	if EconCare.active(world):
		for svc in EconUtil.sorted_keys(CARE_LINES):
			var c := _care_month(world, svc)
			_request_clock(world, r, String(CARE_LINES[svc]), int(c["ask"]), int(c["now"]), int(c["unmet"]), int(c["clients"]), svc)


## Clients by district for a type (persons × S): residents for clinics, the school-age share of children for schools
## (the same counts EconProduction._service_access divides by).
static func clients_by_district(world: WorldState, typ: String) -> Dictionary:
	var out := {}
	for gid in EconUtil.sorted_keys(world.table("hh")):
		var g: Dictionary = world.table("hh")[gid]
		var n := EconHouseholds.persons(g) if typ == "CLINIC" else int(g["children"] * 0.75)
		out[g["district"]] = int(out.get(g["district"], 0)) + n
	return out


## A plant's output at a full crew, in clients (persons × S): EconProduction's output formula at act = 1.
static func full_capacity(world: WorldState, f: Dictionary) -> int:
	var r: Dictionary = EconData.RECIPES[f["type"]]
	return int(float(r["out"][1]) * S * EconProduction._eff(world, f) * EconUtil.fscale(f) * EconUtil.tier_out(f))


## A plant's monthly cost at a full crew (wages and inputs at today's prices and tariffs), as FirmAI._budget_ratio.
static func full_cost(world: WorldState, f: Dictionary) -> float:
	var s := EconUtil.st(world)
	var r: Dictionary = EconData.RECIPES[f["type"]]
	var cost := 0.0
	for t in r["labor"]:
		cost += float(r["labor"][t]) * float(EconFinance.wage_for(world, f["org"], t))
	for g in r["in"]:
		if g in EconData.MARKET_GOODS:
			cost += float(r["in"][g]) * float(s["prices"][g])
		elif g == "ENERGY":
			cost += float(r["in"][g]) * float(EconUtil.lever(world, "ECON_UTILITY_TARIFF_ENERGY", 40)) * S
		elif g == "WATER":
			cost += float(r["in"][g]) * float(EconUtil.lever(world, "ECON_UTILITY_TARIFF_WATER", 20)) * S
	return cost * EconUtil.fscale(f)


static func _plants(world: WorldState, typ: String) -> Array:
	var out: Array = []
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] != typ:
			continue
		var o: Dictionary = world.table("org").get(f["org"], {})
		if String(o.get("type", "")) != "PUBLIC_INSTITUTION":
			continue  # only the state's institutions run on these rules
		out.append(f)
	return out


static func _type_month(world: WorldState, typ: String, r: Dictionary) -> Dictionary:
	var empty := p("empty_pm")
	var margin := p("margin")
	var need := clients_by_district(world, typ)
	var plants := _plants(world, typ)
	var cap_d := {}
	var open_d := {}
	var mothballed_d := {}
	for f in plants:
		var d := String(f["district"])
		if f["mothball"]:
			mothballed_d[d] = int(mothballed_d.get(d, 0)) + 1
			continue
		cap_d[d] = int(cap_d.get(d, 0)) + full_capacity(world, f)
		open_d[d] = int(open_d.get(d, 0)) + 1
	# districts without an open plant are served from the others' spare room (as EconProduction._access): their
	# clients come to the plants that have room, shared by capacity
	var cap_all := 0
	for d in cap_d:
		cap_all += int(cap_d[d])
	var spill := 0
	for d in need:
		if not cap_d.has(d):
			spill += int(need[d])
	var clients_d := {}
	for d in EconUtil.sorted_keys(cap_d):
		var share := int(float(spill) * float(cap_d[d]) / float(maxi(1, cap_all)))
		clients_d[d] = int(need.get(d, 0)) + share
	# each open plant's ask (‰): its district's clients over the district's capacity, plus the margin
	var ask_pm := {}
	var wanted := 0.0
	var low_was: Dictionary = r.get("low_m", {})
	var low_m := {}
	for fid in low_was:   # other types' counters stay; this type's are rebuilt from its open plants
		if String(world.peek("facility").get(fid, {}).get("type", "")) != typ:
			low_m[fid] = low_was[fid]
	for f in plants:
		if f["mothball"]:
			continue
		var d := String(f["district"])
		var a := clampi(int(1000.0 * float(clients_d[d]) * float(1000 + margin) / 1000.0 / float(maxi(1, int(cap_d[d])))), 0, 1000)
		ask_pm[f["id"]] = a
		wanted += full_cost(world, f) * float(a) / 1000.0
		if a <= empty:
			low_m[f["id"]] = int(low_was.get(f["id"], 0)) + 1
	r["low_m"] = low_m
	# the line pays: every ask in full when it covers them, else every ask cut by the same share
	var line := String(TYPES[typ]["line"])
	var lever_now := int(EconUtil.lever(world, line, 0))
	var budget := float(lever_now) * 1000.0 * S / 12.0
	var scale := 1.0 if wanted <= budget else budget / maxf(1.0, wanted)
	var t := {}
	for fid in ask_pm:
		t[fid] = int(float(int(ask_pm[fid])) * scale)
	# served and unmet by district (at the crews the line pays for)
	var rows := {}
	var unmet_all := 0
	var clients_all := 0
	var spare := 0
	for d in cap_d:
		var held := int(float(int(cap_d[d])) * scale)
		spare += maxi(0, held - int(need.get(d, 0)))
	for d in EconUtil.sorted_keys(need):
		var n := int(need[d])
		var served := 0
		if cap_d.has(d):
			served = mini(n, int(float(int(cap_d[d])) * scale))
		else:
			served = mini(n, int(float(spare) * float(n) / float(maxi(1, spill))))
		var cl := int(clients_d.get(d, n))
		rows[d] = {"clients": n / S, "served": served / S, "unmet": maxi(0, n - served) / S, "capacity": int(cap_d.get(d, 0)) / S,
			"crew_pm": _crew_pm(ask_pm, plants, d, scale), "plants_open": int(open_d.get(d, 0)), "mothballed": int(mothballed_d.get(d, 0)),
			"short": maxi(0, cl - int(cap_d.get(d, 0))) / S if cap_d.has(d) else maxi(0, n - served) / S}
		unmet_all += maxi(0, n - served) / S
		clients_all += n / S
	var ask_lever := mini(int(TYPES[typ]["lever_max"]), _round10(int(ceil(wanted * 12.0 / 1000.0 / float(S)))))
	return {"t": t, "rows": rows, "ask": ask_lever, "now": lever_now, "unmet": unmet_all, "clients": clients_all}


static func _crew_pm(ask_pm: Dictionary, plants: Array, d: String, scale: float) -> int:
	var n := 0
	var tot := 0
	for f in plants:
		if String(f["district"]) == d and ask_pm.has(f["id"]):
			tot += int(float(int(ask_pm[f["id"]])) * scale)
			n += 1
	return tot / maxi(1, n)


static func _round10(v: int) -> int:
	return (v + 9) / 10 * 10


## Care (EconCare sizes posts to need within its line): the line that would pay every post the clients need.
static func _care_month(world: WorldState, svc: String) -> Dictionary:
	var sd: Dictionary = EconCare.SERVICES[svc]
	var oid := EconCare.org(world, svc)
	var line := String(CARE_LINES[svc])
	var now := int(EconUtil.lever(world, line, 0))
	if oid == "":
		return {"ask": now, "now": now, "unmet": 0, "clients": 0}
	var cl := EconCare.clients(world, svc)
	var posts := 0
	var people := 0
	for d in cl:
		posts += int(ceil(float(int(cl[d])) / float(sd["normal"])))
		people += int(cl[d])
	var cost := maxi(1, EconCare._post_cost(world, oid, String(sd["type"])))
	var ask := mini(int(CARE_MAX[svc]), _round10(int(ceil(float(posts) * float(cost) * 12.0 / 1000.0 / float(S)))))
	var paid_posts := now * 1000 * S / 12 / cost
	var unmet := maxi(0, people - int(float(paid_posts) * float(sd["normal"])))
	return {"ask": ask, "now": now, "unmet": unmet, "clients": people}


## The request clock of one line: months the ask has stood above (or well below) the line; a request falls due after
## REQ_HOLD_M (CUT_HOLD_M) months, at most once every REQ_EVERY_M months.
static func _request_clock(world: WorldState, r: Dictionary, line: String, ask: int, now: int, unmet: int, clients: int, typ: String) -> void:
	var req: Dictionary = r["req"]
	var q: Dictionary = req.get(line, {"up_m": 0, "down_m": 0, "asked": -9999, "answered": -9999})
	var up := ask * 1000 > now * (1000 + p("req_gap_pm"))
	var down := ask * 1000 < now * p("cut_pm")
	q["up_m"] = int(q["up_m"]) + 1 if up else 0
	q["down_m"] = int(q["down_m"]) + 1 if down else 0
	q["ask"] = ask
	q["now"] = now
	q["unmet"] = unmet
	q["type"] = typ
	var answered_m := int(q.get("answered", -9999))
	var quiet := world.month - maxi(int(q["asked"]), answered_m) >= p("req_every_m")
	var fresh := quiet and (int(q["up_m"]) >= p("req_hold_m") or int(q["down_m"]) >= p("cut_hold_m"))
	if fresh:
		q["asked"] = world.month
	# a request stays open until the government takes it (answered) or for REQ_HOLD_M months
	q["due"] = int(q["asked"]) > answered_m and world.month - int(q["asked"]) < p("req_hold_m")
	# the legislature's need signal (Legislature.propose reads st["lever_need"], ‰): a lasting gap asks for more,
	# 1000 plus the unserved share (from 1500 a needed programme passes the fiscal guard); a lasting surplus asks less
	var ln: Dictionary = EconUtil.st(world).get("lever_need", {})
	if int(q["up_m"]) >= p("req_hold_m"):
		ln[line] = 1000 + clampi(unmet * 1000 / maxi(1, clients), 0, 1000)
	elif int(q["down_m"]) >= p("cut_hold_m"):
		ln[line] = -1000
	else:
		ln[line] = 0
	EconUtil.st(world)["lever_need"] = ln
	if fresh:
		EconFacts.emit(world, "ECON_BUDGET_REQUEST", null, [], [["GOVERNMENT", "government", 1.0]], {}, 10, "OFFICIAL",
			{"line": line, "type": typ, "now": now, "ask": ask, "unmet": unmet})
	req[line] = q


# ------------------------------------------------------------------ queries and the government's actions

## The budget requests, one row per line (clinics, schools, and the care lines when CARE is on). due: open, not yet taken.
## now / ask: the lever (kcr a year) as it stands / that would serve every client; unmet: people not served now.
static func budget_requests(world: WorldState) -> Array:
	var out: Array = []
	var req: Dictionary = EconUtil.peek_st(world).get("r8_inst", {}).get("req", {})
	for line in EconUtil.sorted_keys(req):
		var q: Dictionary = req[line]
		out.append({"line": line, "type": String(q.get("type", "")), "now": int(q.get("now", 0)), "ask": int(q.get("ask", 0)),
			"unmet": int(q.get("unmet", 0)), "due": bool(q.get("due", false)), "up_m": int(q.get("up_m", 0)), "down_m": int(q.get("down_m", 0))})
	return out


## The government has decided on a line's request (whatever it granted): no new request for REQ_EVERY_M months.
static func answered(world: WorldState, line: String, granted_kcr: int) -> void:
	var req: Dictionary = _st(world)["req"]
	var q: Dictionary = req.get(line, {"up_m": 0, "down_m": 0, "asked": -9999})
	q["answered"] = world.month
	q["granted"] = granted_kcr
	q["due"] = false
	req[line] = q


## By type and district: clients, served, unmet, capacity, crew ‰, open and mothballed plants, and short (clients
## the district's plants could not hold at a full crew).
static func needs(world: WorldState) -> Dictionary:
	return EconUtil.peek_st(world).get("r8_inst", {}).get("need", {})


## Rule 5: plants to build (or reopen) per type and district, most unmet first. A district with plants needs more
## when its clients exceed their full capacity; one without when the others' spare room leaves its people unserved.
## Only shortfalls of at least build_min_pm ‰ of one plant count.
static func build_needs(world: WorldState) -> Array:
	var out: Array = []
	var nd := needs(world)
	for typ in EconUtil.sorted_keys(nd):
		var per_plant := int(float(EconData.RECIPES[typ]["out"][1]) * 0.95)
		for d in EconUtil.sorted_keys(nd[typ]):
			var row: Dictionary = nd[typ][d]
			var short := int(row["short"])
			if short * 1000 < per_plant * p("build_min_pm"):
				continue
			out.append({"type": typ, "district": d, "clients": int(row["clients"]), "capacity": int(row["capacity"]), "short": short,
				"plants_needed": int(ceil(float(short) / float(per_plant))), "mothballed": int(row["mothballed"])})
	out.sort_custom(func(a, b): return int(a["short"]) > int(b["short"]) or (a["short"] == b["short"] and String(a["type"] + a["district"]) < String(b["type"] + b["district"])))
	return out


## Rule 6: plants whose ask stood at or below empty_pm for close_hold_m months whose district keeps another open plant that can hold all
## its clients at a full crew. Never the last plant of a district.
static func close_candidates(world: WorldState) -> Array:
	var out: Array = []
	var r: Dictionary = EconUtil.peek_st(world).get("r8_inst", {})
	var low: Dictionary = r.get("low_m", {})
	var nd: Dictionary = r.get("need", {})
	for fid in EconUtil.sorted_keys(low):
		if int(low[fid]) < p("close_hold_m"):
			continue
		var f: Dictionary = world.peek("facility").get(fid, {})
		if f.is_empty() or f["mothball"]:
			continue
		var d := String(f["district"])
		var row: Dictionary = nd.get(f["type"], {}).get(d, {})
		if row.is_empty() or int(row["plants_open"]) < 2 or int(row["unmet"]) > 0:
			continue
		var others := int(row["capacity"]) - full_capacity(world, f) / S
		if others * 1000 < int(row["clients"]) * (1000 + p("margin")):
			continue
		out.append({"fid": fid, "type": String(f["type"]), "district": d})
	return out


## The government closes an institution plant (it stays standing, mothballed; reopen brings it back).
static func close(world: WorldState, fid: String) -> Dictionary:
	var f: Dictionary = world.table("facility").get(fid, {})
	if f.is_empty() or f["mothball"]:
		return {"ok": false, "error": "No open plant " + fid}
	f["mothball"] = true
	_st(world)["low_m"].erase(fid)
	EconFacts.emit(world, "ECON_INSTITUTION_CLOSED", f["district"], [["COMPANY", f["org"]]], [["GOVERNMENT", "government", 1.0]],
		{"PUBLIC_SERVICES": -5}, 20, "PUBLIC", {"facility": fid, "type": f["type"]})
	return {"ok": true}


static func reopen(world: WorldState, fid: String) -> Dictionary:
	var f: Dictionary = world.table("facility").get(fid, {})
	if f.is_empty() or not f["mothball"] or bool(f.get("closed_unsafe", false)):
		return {"ok": false, "error": "No closed plant " + fid}
	f["mothball"] = false
	EconFacts.emit(world, "ECON_INSTITUTION_REOPENED", f["district"], [["COMPANY", f["org"]]], [["GOVERNMENT", "government", 1.0]],
		{"PUBLIC_SERVICES": 5}, 20, "PUBLIC", {"facility": fid, "type": f["type"]})
	return {"ok": true}

extends RefCounted
## The eight rules for public institutions (planning/eight-rules.md, "Who decides in whose place" and 3a.4; Maja,
## 2026-11-16). Switch R8_INSTITUTIONS, only together with R8 (EconRules.sector_on). Without it nothing here runs and
## clinics and schools keep today's crew: one budget ratio for every plant, whatever its district needs.
##
## The user (2026-11-16): no rule is skipped because it cannot take effect today. So:
##   1/2 PUBLIC PRICE: TAX BRACKETS. The user (2026-11-16): a public school charges nothing at the door, "it's a
##       bracket in taxes", "calibrated per pupil plus staff", and "they all get tax brackets". Each public service
##       has its own bracket (BRACKETS: health, schools, administration, elder care, childcare; care has two because
##       its two lines and institutions are separate), in per mille of income above the allowance, charged with the
##       income tax on wages (EconFinance._payroll) and proprietors' earnings (EconHouseholds) and earmarked: it goes
##       to the institution, not the treasury, and its line tops it up only by the rest. The institution's crews
##       count it beside the line. Rules 1/2 propose the bracket that raises what its clients plus staff cost (the
##       asks: posts at today's wages plus inputs per client) beyond what the line pays: the current bracket scaled
##       by (cost − line) ÷ what the bracket raised, up when it raises less, down when it raises more, held
##       REQ_HOLD_M months for a rise and CUT_HOLD_M for a cut (Maja's windows). Proposals are lever_need on the
##       bracket and an INSTITUTION_FEE case under DELEGATION; the government decides it like any tax. While a
##       bracket is 0 nothing is proposed. The line's own request (rule 3) stands beside it: the line is the
##       government's budget answer, the bracket the service's own price. The fee levers ECON_HEALTH_FEE and
##       ECON_SCHOOL_FEE stay unread.
##   ADMIN on all eight rules. Its output is read by nothing, so it needs a client measure: Maja's, residents, one
##       office at a full crew serving ADMIN_RESIDENTS of them (about 27 posts per 1000 residents). Built from
##       BUILD_EXTRA (an office building, a school's bill), since EconData.BUILD has no ADMIN row and adding one would
##       change the founding office's books in every game.
## The rules for every type:
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
## PRIVATE CLINICS, SCHOOLS AND OFFICES (the user, 2026-11-16: "All company types needs to be able to be created as private";
## Wilma approved the shape). A private or co-op plant of the same type lives on what its clients pay:
##   households fill the free public places first; only the clients the public plants leave unserved are buyers;
##   each pool pays from its discretionary budget, before the service hubs and comfort spending, at most WILL_PM per
##   mille of that budget for each type, at the plant's own fee per client a month: own district first, then
##   neighbours at +10%, the cheapest first (buy_places). A paid place counts in the district's access only for those
##   who pay (the plant's crew follows its sales, so its output does).
##   1 raise the fee when its places were full and clients were turned away for FEE_HOLD_M months; 2 lower it when
##   places stand empty and clients in its district were priced out (no floor of ours: below its cost per client,
##   FirmAI.unit_cost, it offers fewer places, fee ÷ cost of them, to stay afloat, the user's ruling); 3/4 crew to the paying clients plus the margin; 5 expand when full FULL_M months running and
##   profitable over 12 months; 6 mothball after EMPTY_M months mostly empty at a loss; 7 a founder enters
##   (FirmAI._entry) where the forecast, with the founder's error, finds unserved clients in reach whose means cover a
##   fee above cost, once the private places already there are counted, and a first year that pays (entry_profit:
##   fees less crew, inputs, upkeep and depreciation); 8 not while nobody in reach is unserved, nor while the private plants of the type lose money. Where the
##   state serves everyone the condition never comes true. Care homes the same way (CARE_TYPES): a private elder-care
##   or childcare home sells places to the retired or the small children the public care service leaves uncared for
##   (EconCare's coverage), its places are its posts × the normal clients per worker, and the people it cares for
##   count in the district's coverage (care_private, called by EconCare).
## Units as EconProduction: need and capacity in persons × S (a clinic at full serves 2500 residents, a school 450
## pupils); T and shares in ‰; money as EconFinance.wage_for × posts (mcr a month), the line in kcr a year.
## State: st["r8_inst"] = {t: {fid: T‰}, need: {type: {district: row}}, req: {line: {up_m, down_m, asked, answered,
## ask, now}}, low_m: {fid: months standing empty}}. Written once a month (EconRules.monthly, end of TRADE); read by FirmAI
## the next month. Pure in the world state, saved with it.

const S := EconUtil.S
## Maja's client measure for ADMIN (labelled hers; the user may give it another): residents served by one office at a
## full crew (80 posts), about 27 posts per 1000 residents.
const ADMIN_RESIDENTS := 3000
## ADMIN's build bill [WU, MATERIAL, COMPONENT, min months]: an office building, as a school's (EconData.BUILD has none).
const BUILD_EXTRA := {"ADMIN": [450, 450, 15, 6], "ELDERCARE": [120, 120, 5, 3], "CHILDCARE": [120, 120, 5, 3]}
## Care home types and their EconCare service.
const CARE_TYPES := {"CHILDCARE": "CHILD", "ELDERCARE": "ELDER"}
const TYPES := {
	"ADMIN": {"line": "ECON_BUDGET_ADMIN", "lever_max": 4000, "per_plant": ADMIN_RESIDENTS},
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
## rules have not seen yet.
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
		_bracket_clock(world, r, typ, int(res["wanted"]), int(res["budget"]), int(res["unmet"]), int(res["clients"]))
	for k in CARE_TYPES:   # the care rows EconCare handed over this month (care_private) stay
		if (r.get("need", {}) as Dictionary).has(k):
			need_all[k] = r["need"][k]
	r["need"] = need_all
	_private_month(world, r, t_all)   # private clinics and schools: their own rules on their paying clients
	r["t"] = t_all
	if EconCare.active(world):
		for svc in EconUtil.sorted_keys(CARE_LINES):
			var c := _care_month(world, svc)
			_request_clock(world, r, String(CARE_LINES[svc]), int(c["ask"]), int(c["now"]), int(c["unmet"]), int(c["clients"]), svc)
			_bracket_clock(world, r, svc, int(c["wanted"]), int(c["budget"]), int(c["unmet"]), int(c["clients"]))


## Clients by district for a type (persons × S): residents for clinics and offices, the school-age share of children
## for schools (the same counts EconProduction._service_access divides by).
static func clients_by_district(world: WorldState, typ: String) -> Dictionary:
	var out := {}
	for gid in EconUtil.sorted_keys(world.table("hh")):
		var g: Dictionary = world.table("hh")[gid]
		out[g["district"]] = int(out.get(g["district"], 0)) + pool_clients(g, typ)
	return out


## A pool's clients of a type (persons × S).
static func pool_clients(g: Dictionary, typ: String) -> int:
	return int(g["children"] * 0.75) if typ == "SCHOOL" else EconHouseholds.persons(g)


## Clients one plant serves at a full crew (persons): the recipe's output, or ADMIN's measure.
static func plant_out(typ: String) -> int:
	return int(TYPES.get(typ, {}).get("per_plant", EconData.RECIPES[typ]["out"][1]))


## ADMIN can be commissioned and founded only with the switch (its bill is BUILD_EXTRA's).
static func buildable(world: WorldState, ftype: String) -> bool:
	return BUILD_EXTRA.has(ftype) and on(world)


## A plant's output at a full crew, in clients (persons × S): EconProduction's output formula at act = 1.
static func full_capacity(world: WorldState, f: Dictionary) -> int:
	return int(float(plant_out(String(f["type"]))) * S * EconProduction._eff(world, f) * EconUtil.fscale(f) * EconUtil.tier_out(f))


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
	var pay := budget + float(earmarked(world, typ))   # the line and the service's own bracket
	var scale := 1.0 if wanted <= pay else pay / maxf(1.0, wanted)
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
	var ask_lever := mini(int(TYPES[typ]["lever_max"]), _round10(int(ceil(maxf(0.0, wanted - (pay - budget)) * 12.0 / 1000.0 / float(S)))))
	return {"t": t, "rows": rows, "ask": ask_lever, "now": lever_now, "unmet": unmet_all, "clients": clients_all, "wanted": int(wanted), "budget": int(budget)}


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
		return {"ask": now, "now": now, "unmet": 0, "clients": 0, "wanted": 0, "budget": 0}
	var cl := EconCare.clients(world, svc)
	var posts := 0
	var people := 0
	for d in cl:
		posts += int(ceil(float(int(cl[d])) / float(sd["normal"])))
		people += int(cl[d])
	var cost := maxi(1, EconCare._post_cost(world, oid, String(sd["type"])))
	var wanted := posts * cost
	var ask := mini(int(CARE_MAX[svc]), _round10(int(ceil(float(maxi(0, wanted - earmarked(world, svc))) * 12.0 / 1000.0 / float(S)))))
	var paid_posts := now * 1000 * S / 12 / cost
	var unmet := maxi(0, people - int(float(paid_posts) * float(sd["normal"])))
	return {"ask": ask, "now": now, "unmet": unmet, "clients": people, "wanted": wanted, "budget": now * 1000 * S / 12}


## The request clock of one line: months the ask has stood above (or well below) the line; a request falls due after
## REQ_HOLD_M (CUT_HOLD_M) months, at most once every REQ_EVERY_M months.
static func _request_clock(world: WorldState, r: Dictionary, line: String, ask: int, now: int, unmet: int, clients: int, typ: String, kind: String = "budget") -> void:
	var req: Dictionary = r["req"]
	var q: Dictionary = req.get(line, {"up_m": 0, "down_m": 0, "asked": -9999, "answered": -9999})
	q["kind"] = kind
	var up := ask * 1000 > now * (1000 + p("req_gap_pm")) if kind == "budget" else ask > now
	var down := ask * 1000 < now * p("cut_pm") if kind == "budget" else ask < now
	var down_hold := p("cut_hold_m")
	q["up_m"] = int(q["up_m"]) + 1 if up else 0
	q["down_m"] = int(q["down_m"]) + 1 if down else 0
	q["ask"] = ask
	q["now"] = now
	q["unmet"] = unmet
	q["type"] = typ
	var answered_m := int(q.get("answered", -9999))
	var quiet := world.month - maxi(int(q["asked"]), answered_m) >= p("req_every_m")
	var fresh := quiet and (int(q["up_m"]) >= p("req_hold_m") or int(q["down_m"]) >= down_hold)
	if fresh:
		q["asked"] = world.month
	# a request stays open until the government takes it (answered) or for REQ_HOLD_M months
	q["due"] = int(q["asked"]) > answered_m and world.month - int(q["asked"]) < p("req_hold_m")
	# the legislature's need signal (Legislature.propose reads st["lever_need"], ‰): a lasting gap asks for more,
	# 1000 plus the unserved share (from 1500 a needed programme passes the fiscal guard); a lasting surplus asks less
	var ln: Dictionary = EconUtil.st(world).get("lever_need", {})
	if int(q["up_m"]) >= p("req_hold_m"):
		ln[line] = 1000 + clampi(unmet * 1000 / maxi(1, clients), 0, 1000)
	elif int(q["down_m"]) >= down_hold:
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
		out.append({"line": line, "type": String(q.get("type", "")), "kind": String(q.get("kind", "budget")), "now": int(q.get("now", 0)), "ask": int(q.get("ask", 0)),
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
		if not TYPES.has(typ):
			continue   # care homes: the public service sizes its own sites (EconCare)
		var per_plant := int(float(plant_out(typ)) * 0.95)
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


# ------------------------------------------------------------------ private clinics and schools

const OWNER_TYPES := ["PRIVATE", "COOPERATIVE"]
const WILL_PM := {"ADMIN": 30, "CHILDCARE": 120, "CLINIC": 150, "ELDERCARE": 150, "SCHOOL": 120}   # ‰ of a pool's discretionary budget it will spend on each, at most
const FEE_START := 1.2      # × cost per client: a new plant's first fee
const FEE_STEP := 0.05
const FEE_HOLD_M := 2
const FULL_PM := 950        # sold ≥ this ‰ of places = full
const EMPTY_PM := 200       # sold < this ‰ of places = mostly empty
const FULL_M := 6
const EMPTY_M := 12
const ENTRY_ERR := 0.2      # sd of the founder's forecast error (E170 style)


static func private_on(world: WorldState) -> bool:
	return on(world)


## The types a private owner can run: clinics, schools, offices, and care homes while public care runs (CARE).
static func private_types(world: WorldState) -> Array:
	var out: Array = EconUtil.sorted_keys(TYPES)
	if EconCare.active(world):
		out.append_array(EconUtil.sorted_keys(CARE_TYPES))
	return out


static func _private_plants(world: WorldState, typ: String, open_only: bool = true) -> Array:
	var out: Array = []
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] != typ or (open_only and f["mothball"]):
			continue
		var o: Dictionary = world.table("org").get(f["org"], {})
		if String(o.get("type", "")) in OWNER_TYPES and String(o.get("status", "")) in ["ACTIVE", "DISTRESSED"]:
			out.append(f)
	return out


## A plant's places: the clients it can take a month at a full crew (persons).
static func places(world: WorldState, f: Dictionary) -> int:
	if CARE_TYPES.has(f["type"]):
		return int(float(EconCare.POSTS_PER_UNIT) * EconUtil.fscale(f) * EconCare.normal_for(String(f["type"])))
	return full_capacity(world, f) / S


## The places a private plant offers this month: all of them at or above its cost per client; below it, the share
## its fee covers (it sells less to stay afloat rather than refuse outright).
static func offered(world: WorldState, f: Dictionary) -> int:
	var pl := places(world, f)
	var cpc := cost_per_client(world, String(f["type"]))
	var fe := fee(world, f)
	return pl if fe >= cpc else pl * fe / maxi(1, cpc)


## Cost per client a month at full load (wages, inputs, upkeep, depreciation), as founders reckon it.
static func cost_per_client(world: WorldState, typ: String) -> int:
	if CARE_TYPES.has(typ):   # a care home's posts (its recipe has no output to divide by) and its building
		var r: Dictionary = EconData.RECIPES[typ]
		var wages := 0.0
		for t in r["labor"]:
			wages += float(r["labor"][t]) * float(EconUtil.st(world)["wage"][t])
		var clients := float(EconCare.POSTS_PER_UNIT) * EconCare.normal_for(typ)
		return int((wages + float(EconConstruction.estimate(typ)) / EconData.DEPRECIATION_MONTHS) / maxf(1.0, clients))
	return int(FirmAI.unit_cost(world, typ) * float(EconData.RECIPES[typ]["out"][1]) / float(maxi(1, plant_out(typ))))


static func fee(world: WorldState, f: Dictionary) -> int:
	if not f.has("fee"):
		f["fee"] = int(float(cost_per_client(world, String(f["type"]))) * FEE_START)
	return int(f["fee"])


## Pool g's clients of a type the public plants leave unserved (persons), from this month's public rows.
static func _unserved(g: Dictionary, typ: String, row: Dictionary) -> int:
	if row.is_empty() or int(row["clients"]) <= 0:
		return 0
	var n := pool_clients(g, typ)
	if typ == "ELDERCARE":
		n = int(g["retired"])
	elif typ == "CHILDCARE":   # the pool's share of the district's small children, by its children
		n = int(float(g["children"]) * float(int(row["clients"]) * S) / float(maxi(1, int(row.get("kids", 0)))))
	return n * maxi(0, int(row["clients"]) - int(row["served"])) / maxi(1, int(row["clients"])) / S


## Households (EconHouseholds._buy_services, before the service hubs): pool g buys private places for the clients the
## public plants leave unserved, out of `budget`. Returns what it spent.
static func buy_places(world: WorldState, g: Dictionary, budget: int) -> int:
	if not private_on(world):
		return 0
	budget = maxi(0, budget)
	var r := _st(world)
	if int(r.get("buy_m", -1)) != world.month:
		r["buy_m"] = world.month
		r["priced"] = {}
		for typ in private_types(world):
			for f in _private_plants(world, typ):
				f["inst_sold"] = 0
				f["inst_away"] = 0
	var d := String(g["district"])
	var spent := 0
	var nd: Dictionary = r.get("need", {})
	for typ in private_types(world):
		var unserved := _unserved(g, typ, nd.get(typ, {}).get(d, {}))
		if unserved <= 0:
			continue
		var will := mini(maxi(0, budget - spent), budget * int(WILL_PM[typ]) / 1000)
		var sources: Array = []
		for f in _private_plants(world, typ):
			var fd := String(f["district"])
			if fd == d:
				sources.append([fee(world, f), f])
			elif fd in EconUtil.neighbours(d):
				sources.append([fee(world, f) * 11 / 10, f])
		if sources.is_empty():
			continue
		sources.sort_custom(func(a, b): return int(a[0]) < int(b[0]) or (a[0] == b[0] and String(a[1]["id"]) < String(b[1]["id"])))
		var left := unserved
		var full := true
		for src in sources:
			if left <= 0:
				break
			var f: Dictionary = src[1]
			var price := maxi(1, int(src[0]))
			var room := maxi(0, offered(world, f) - int(f.get("inst_sold", 0)))
			if room > 0:
				full = false
			var k := mini(mini(left, room), will / price)
			k = mini(k, world.ledger.balance(EconUtil.hh_acct(g["id"])) / price)
			if k <= 0:
				continue
			world.ledger.transfer(EconUtil.hh_acct(g["id"]), EconUtil.acct(f["org"]), k * price, "SALE", world.month)
			EconFinance.pl_add(world, f["org"], "rev", k * price)
			f["inst_sold"] = int(f.get("inst_sold", 0)) + k
			will -= k * price
			spent += k * price
			left -= k
		if left > 0:
			if full:
				for src in sources:   # turned away: every plant in reach was full
					src[1]["inst_away"] = int(src[1].get("inst_away", 0)) + maxi(1, left / sources.size())
			else:
				var pr: Dictionary = r["priced"].get(typ, {})
				pr[d] = int(pr.get(d, 0)) + left   # priced out: places stood empty but the fee was beyond their means
				r["priced"][typ] = pr
	return spent


## Rules 1–6 of each open private plant, on this month's sales; its crew share goes into `t_all`.
static func _private_month(world: WorldState, r: Dictionary, t_all: Dictionary) -> void:
	var margin := p("margin")
	var priced: Dictionary = r.get("priced", {})
	for typ in private_types(world):
		var cpc := cost_per_client(world, typ)
		for f in _private_plants(world, typ):
			var pl := maxi(1, places(world, f))
			var sold := int(f.get("inst_sold", 0))
			t_all[f["id"]] = clampi(sold * (1000 + margin) / pl, 0, 1000)   # 3/4: crew to the paying clients
			if CARE_TYPES.has(typ):
				f["enrolled"] = sold   # the people it cares for (EconWorkload reads them)
			var fe := fee(world, f)
			var full := sold * 1000 >= maxi(1, offered(world, f)) * FULL_PM
			f["inst_away_m"] = int(f.get("inst_away_m", 0)) + 1 if full and int(f.get("inst_away", 0)) > 0 else 0
			if int(f["inst_away_m"]) >= FEE_HOLD_M:   # 1: full and turning clients away
				f["fee"] = int(float(fe) * (1.0 + FEE_STEP)) + 1
				f["inst_away_m"] = 0
			elif sold * 1000 < pl * 800 and int(priced.get(typ, {}).get(String(f["district"]), 0)) > 0:   # 2: empty places, priced-out clients
				f["fee"] = maxi(1, int(float(fe) * (1.0 - FEE_STEP)))
			f["inst_full_m"] = int(f.get("inst_full_m", 0)) + 1 if full else 0
			f["inst_empty_m"] = int(f.get("inst_empty_m", 0)) + 1 if sold * 1000 < pl * EMPTY_PM else 0
			var o: Dictionary = world.table("org")[f["org"]]
			if int(f["inst_full_m"]) >= FULL_M and EconPublicCo.result12(o) > 0:   # 5: full and paying
				_expand(world, f)
			elif int(f["inst_empty_m"]) >= EMPTY_M and EconPublicCo.result12(o) < 0:   # 6: empty and losing
				f["mothball"] = true
				f["inst_empty_m"] = 0
				t_all.erase(f["id"])
				EconFacts.emit(world, "COMP_FACILITY_MOTHBALLED", f["district"], [["COMPANY", f["org"]]], [["COMPANY", f["org"], 1.0]],
					{"JOBS": -5}, 15, "PUBLIC", {"facility": f["id"], "type": typ, "reason": "empty"})


static func _expand(world: WorldState, f: Dictionary) -> void:
	var fid := String(f["id"])
	if int(f.get("scale", 1000)) >= EconRulesMat.MAX_SCALE or EconRulesMat._expand_pending(world, fid):
		return
	var cost := EconConstruction.estimate(String(f["type"])) / 4
	if not EconRulesMat._finance(world, String(f["org"]), cost, false):
		return
	EconConstruction.create_expansion(world, fid, f["org"])
	f["inst_full_m"] = 0
	EconFacts.emit(world, "COMP_INVESTMENT", f["district"], [["COMPANY", f["org"]]], [["COMPANY", f["org"], 1.0]], {"JOBS": 2}, 15,
		"PUBLIC", {"type": f["type"], "reason": "full"})


## Rule 7 forecast for a founder, on the average (the user: "instead of reading the leftovers, they read an avrage"):
## every client in district d and its neighbours whose pool's means cover a fee of FEE_START × cost, shared among
## all the places in reach (the public plants', the private ones open or being built, and the founder's own), with
## the founder's error. Returns the founder's expected paying clients a month (persons).
static func forecast(world: WorldState, typ: String, d: String, err: float = 0.0) -> int:
	var nd: Dictionary = EconUtil.peek_st(world).get("r8_inst", {}).get("need", {}).get(typ, {})
	var reach: Array = [d] + EconUtil.neighbours(d)
	var fee_est := maxi(1, int(float(cost_per_client(world, typ)) * FEE_START))
	var buyers := 0
	for gid in EconUtil.sorted_keys(world.table("hh")):
		var g: Dictionary = world.table("hh")[gid]
		var gd := String(g["district"])
		if not (gd in reach):
			continue
		var n := _pool_all(g, typ, nd.get(gd, {}))
		if n <= 0:
			continue
		var will := EconHouseholds.discretionary_budget(world, g) * int(WILL_PM[typ]) / 1000
		var price := fee_est if gd == d else fee_est * 11 / 10
		buyers += mini(n, will / price)
	var own := new_places(typ)
	var all_places := own
	for f in _plants(world, typ):
		if not f["mothball"] and String(f["district"]) in reach:
			all_places += places(world, f)
	for f in _private_plants(world, typ, false):
		if String(f["district"]) in reach:
			all_places += places(world, f)
	all_places += _building_places(world, typ, reach)
	return maxi(0, int(float(_avg_share(world, typ, d, buyers, all_places, own)) * (1.0 + err)))


## The places being built in reach (persons): new plants of `typ` still projects (tendered, planned or under way, by
## anyone) at a new plant's places (× their lot size), and extensions of its plants at a quarter of a plant.
static func _building_places(world: WorldState, typ: String, reach: Array) -> int:
	var n := 0
	var fac: Dictionary = world.peek("facility")
	for pid in EconUtil.sorted_keys(world.peek("project")):
		var pr: Dictionary = world.peek("project")[pid]
		if not (String(pr.get("status", "")) in ["TENDER", "TENDERABLE", "ACTIVE", "PLANNING"]):
			continue
		if pr["type"] == typ and String(pr["district"]) in reach:
			n += new_places(typ) * int(pr.get("size_pm", 1000)) / 1000
		elif pr["type"] == "EXPAND" and fac.has(pr.get("target", "")) and fac[pr["target"]]["type"] == typ and String(pr["district"]) in reach:
			n += new_places(typ) / 4
	return n


## The places a new plant of `typ` offers at a full crew (persons).
static func new_places(typ: String) -> int:
	if CARE_TYPES.has(typ):
		return int(float(EconCare.POSTS_PER_UNIT) * EconCare.normal_for(typ))
	return plant_out(typ)


## A newcomer's share of the demand on the average: `demand` shared by capacity among `all_places` (its own
## included), its `own` places' part, at most its places. Bob's shared function (EconForecast.share_of_work), on the
## clients and places in reach (persons).
static func _avg_share(world: WorldState, typ: String, d: String, demand: int, all_places: int, own: int) -> int:
	if all_places <= 0:
		return 0
	var mu := EconForecast.share_of_work(world, typ, d, float(own * S), "", float(demand * S), float(maxi(0, all_places - own) * S))
	return mini(own, int(mu / float(S)))


## Pool g's clients of a type, all of them (persons): the residents, the school-age children, the retired, or the
## pool's share of the district's small children (from the care row).
static func _pool_all(g: Dictionary, typ: String, row: Dictionary) -> int:
	if typ == "ELDERCARE":
		return int(g["retired"]) / S
	if typ == "CHILDCARE":
		if row.is_empty() or int(row.get("kids", 0)) <= 0:
			return 0
		return int(float(g["children"]) * float(int(row["clients"])) / float(int(row["kids"])))
	return pool_clients(g, typ) / S


## Rule 8: private plants holding more than half of the type's private places lost money over 12 months.
static func _private_losing(world: WorldState, typ: String) -> bool:
	var all_p := 0
	var losing := 0
	for f in _private_plants(world, typ):
		var pl := places(world, f)
		all_p += pl
		if EconPublicCo.result12(world.table("org")[f["org"]]) < 0:
			losing += pl
	return all_p > 0 and losing * 2 > all_p


## A founder's first-year reckoning a month: `n` paying clients (at most a plant's places) at the starting fee, less
## what serving them costs (crew and inputs per client) and what the plant costs whatever it serves (upkeep and
## depreciation of the build estimate).
static func entry_profit(world: WorldState, typ: String, n: int) -> int:
	var r: Dictionary = EconData.RECIPES[typ]
	var out := float(plant_out(typ)) if TYPES.has(typ) else float(EconCare.POSTS_PER_UNIT) * EconCare.normal_for(typ)
	var full := float(cost_per_client(world, typ)) * out
	var fixed := float(r["upkeep"]) * float(EconUtil.st(world)["prices"]["MATERIAL"]) + float(EconConstruction.estimate(typ)) / EconData.DEPRECIATION_MONTHS
	var per_client := maxf(0.0, full - fixed) / out
	var k := mini(n, int(out))
	return int(float(k) * (float(cost_per_client(world, typ)) * FEE_START - per_client) - fixed)


## Rules 7/8 for FirmAI._entry: the district a founder of `typ` would build in, where the forecast (with the founder's
## error) gives the best first-year profit; "" when it is a loss everywhere.
static func entry_district(world: WorldState, typ: String) -> String:
	if not private_on(world) or not private_types(world).has(typ) or _private_losing(world, typ):
		return ""
	var rng := world.rng.stream("econ.inst_entry")
	var best := ""
	var best_p := 0
	for d in EconUtil.sorted_keys(EconData.DISTRICTS):
		if not EconUtil.connected(String(d)):
			continue
		var n := forecast(world, typ, String(d), clampf(rng.randfn(0.0, ENTRY_ERR), -0.6, 0.6))
		if n <= 0:
			continue
		var pr := entry_profit(world, typ, n)
		if pr > best_p:
			best_p = pr
			best = String(d)
	return best


# ------------------------------------------------------------------ tax brackets (rules 1/2 of the public services)

## Each public service's bracket: the lever (per mille of income above the allowance) and the key of the institution
## it is earmarked to.
const BRACKETS := {
	"ADMIN": ["ECON_ADMIN_TAX", "ADMINISTRATION"],
	"CHILD": ["ECON_CHILDCARE_TAX", "CHC"],
	"CLINIC": ["ECON_HEALTH_TAX", "HEALTH"],
	"ELDER": ["ECON_ELDER_CARE_TAX", "ELDC"],
	"SCHOOL": ["ECON_SCHOOL_TAX", "SCHOOLS"],
}
const BRACKET_MAX := 50


## A service's bracket in per mille (0 without the switch).
static func bracket_pm(world: WorldState, kind: String) -> int:
	if not on(world):
		return 0
	return clampi(int(EconUtil.lever(world, String(BRACKETS[kind][0]), 0)), 0, BRACKET_MAX)


## Charges every bracket on `base` (income above the allowance) out of `from_acct`, each to its institution, up to what
## the account holds. Returns what was paid (0 without the switch or with every bracket at 0).
static func earmark_all(world: WorldState, from_acct: String, base: int) -> int:
	if base <= 0 or not on(world):
		return 0
	var paid := 0
	for kind in EconUtil.sorted_keys(BRACKETS):
		var pm := bracket_pm(world, kind)
		if pm <= 0:
			continue
		var org := EconFinance.org_by_key(world, String(BRACKETS[kind][1]))
		if org == "":
			continue
		var amt := EconUtil.pay_upto(world, from_acct, EconUtil.acct(org), base * pm / 1000, "SERVICE_TAX")
		EconFinance.pl_add(world, org, "rev", amt)
		paid += amt
		var r := _st(world)
		var all: Dictionary = r.get("earmark", {})
		var e: Dictionary = all.get(kind, {})
		if int(e.get("month", -1)) != world.month:
			e = {"month": world.month, "now": 0, "last": int(e.get("now", 0)) if int(e.get("month", -1)) == world.month - 1 else 0}
		e["now"] = int(e["now"]) + amt
		all[kind] = e
		r["earmark"] = all
	return paid


## What a service's bracket raised in a month: this month's once collected, else last month's (money a month).
static func earmarked(world: WorldState, kind: String) -> int:
	var e: Dictionary = EconUtil.peek_st(world).get("r8_inst", {}).get("earmark", {}).get(kind, {})
	var m := int(e.get("month", -1))
	if m == world.month:
		return maxi(int(e.get("now", 0)), int(e.get("last", 0)))
	if m == world.month - 1:
		return int(e.get("now", 0))
	return 0


## Rules 1/2 on a service's bracket: the bracket that raises what its clients plus staff cost beyond the line, from
## the current bracket and what it raised; nothing while it is 0.
static func _bracket_clock(world: WorldState, r: Dictionary, kind: String, wanted: int, budget: int, unmet: int, clients: int) -> void:
	var lever := String(BRACKETS[kind][0])
	var now := int(EconUtil.lever(world, lever, 0))
	if now <= 0:
		var ln: Dictionary = EconUtil.st(world).get("lever_need", {})
		if ln.has(lever):
			ln[lever] = 0
		(r["req"] as Dictionary).erase(lever)
		return
	var e := earmarked(world, kind)
	var ask := now
	if e > 0:
		ask = clampi(int(ceil(float(now) * float(maxi(0, wanted - budget)) / float(e))), 0, BRACKET_MAX)
	_request_clock(world, r, lever, ask, now, unmet, maxi(1, clients), kind, "bracket")


# ------------------------------------------------------------------ private care homes (EconCare's side)

## EconCare.monthly, once each service's public coverage `cov` (‰ by district) is known: records the care rows the
## households and founders read (clients, cared for publicly, the district's children for the childcare share) and
## returns the coverage with the people private homes care for added. Unchanged without the switch.
static func care_private(world: WorldState, svc: String, clients: Dictionary, cov: Dictionary) -> Dictionary:
	if not on(world):
		return cov
	var typ := "ELDERCARE" if svc == "ELDER" else "CHILDCARE"
	var kids := {}
	if svc == "CHILD":
		for gid in EconUtil.sorted_keys(world.table("hh")):
			var g: Dictionary = world.table("hh")[gid]
			kids[g["district"]] = int(kids.get(g["district"], 0)) + int(g["children"])
	var rows := {}
	for d in EconUtil.sorted_keys(clients):
		var c := int(clients[d])
		rows[d] = {"clients": c, "served": c * int(cov.get(d, 0)) / 1000, "kids": int(kids.get(d, 0))}
	var r := _st(world)
	var need: Dictionary = r.get("need", {})
	need[typ] = rows
	r["need"] = need
	var out := cov.duplicate()
	for f in _private_plants(world, typ):
		var d := String(f["district"])
		var c := int(clients.get(d, 0))
		if c > 0:
			out[d] = mini(1000, int(out.get(d, 0)) + int(f.get("inst_sold", 0)) * 1000 / c)
	return out

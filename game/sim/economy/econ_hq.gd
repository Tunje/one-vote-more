class_name EconHQ
extends RefCounted
## Support economy part B (planning/plan-support-economy.md §2 B): non-production organisations employ real people.
##   PARTY HQs (paid from party:<id>): HQ_BASE + seats / SEAT_DIV posts, never fewer than the party's named staff
##     (Anni's StaffQuery.named_posts), and only what the party can afford for PARTY_RUNWAY_M months.
##   UNION HQs (paid from the union fund): members / MEMBERS_PER_POST officials, affordable for UNION_RUNWAY_M months.
##   NEWSROOMS: a paper's running cost (media_ops._finances → EconHouseholds.pay_media_wages) goes to its newsroom,
##     which employs journalists from it, instead of being spread over households already employed elsewhere.
##   Each is a stand-in organisation (PUBLIC_INSTITUTION, key "HQ|<funder account>") with one site (HQOFFICE 1 G + 1 S
##   or NEWSROOM, one S post a unit — these bodies are small: a paper's running cost buys ~2–3 journalists, a party a
##   handful of staff, so two-person units rounded most of them to nothing; a site keeps 70% of a unit, E49).
##   The funder tops up next month's wage bill; cash above KEEP_M months goes back to it. Named staff persons (Anni)
##   occupy some of these posts and are never paid twice (staff persons have no salary of their own).
##   Ministries: the ADMIN institution already employs ~80 (the government's 20 named people fit inside); scaling it
##   with population is a later step.
## OPT-IN until its A/B (world.meta["on"] has "SUPPORT_B").

const S := EconUtil.S
const SQ := preload("res://sim/staff/staff_query.gd")
const HQ_BASE := 2
const SEAT_DIV := 2
const PARTY_RUNWAY_M := 24
const MEMBERS_PER_POST := 250
const UNION_RUNWAY_M := 12
const KEEP_M := 2
const NEWS_SHARE := 0.95  # of a paper's running cost paid as newsroom wages (the rest: print, offices)
const EMA_KEEP := 0.8
const DEAD := ["LIQUIDATION", "DISSOLVED"]


static func active(world: WorldState) -> bool:
	return world.meta.has("on") and (world.meta["on"] as Array).has("SUPPORT_B") and not EconUtil.off(world, "SUPPORT_B")


static func _unit(ftype: String) -> int:
	var n := 0
	for t in EconData.RECIPES[ftype]["labor"]:
		n += int(EconData.RECIPES[ftype]["labor"][t])
	return n


static func org_for(world: WorldState, funder: String) -> String:
	return EconFinance.org_by_key(world, "HQ|" + funder)


static func _found(world: WorldState, funder: String, name: String, ftype: String, d: String) -> String:
	var oid := world.new_id("org")
	world.table("org")[oid] = {"id": oid, "key": "HQ|" + funder, "name": name, "type": "PUBLIC_INSTITUTION", "hq": d,
		"status": "ACTIVE", "ceo": {"mgmt": 50, "risk": 10, "age_m": 45 * 12}, "reliability": 0, "is_contractor": false,
		"crew": {}, "crew_target": {}, "premium_m": {"G": 0, "S": 0, "Sp": 0}, "tax_loss_cf": 0, "profit_q": 0,
		"pl": EconFinance.empty_pl(), "pl_last": {}, "missed_streak": 0, "ok_streak": 0, "low_cash_streak": 0, "distress_months": 0,
		"admin_months": 0, "liq_months": 0, "missed_this_month": false, "owner_group": "", "sales_ema": {}, "contracts": [],
		"dividends_ytd": 0, "sold": {}, "funder": funder, "hq_type": ftype}
	world.ledger.open_account(EconUtil.acct(oid))
	var fid := EconSetup.add_facility(world, ftype, oid, d, false)
	world.table("facility")[fid]["scale"] = 0
	world.table("facility")[fid]["book"] = 0
	world.table("facility")[fid]["mothball"] = true
	return oid


static func _site(world: WorldState, oid: String) -> Dictionary:
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["org"] == oid:
			return f
	return {}


static func _post_cost(world: WorldState, oid: String, ftype: String) -> int:
	var c := 0
	for t in EconData.RECIPES[ftype]["labor"]:
		c += int(EconData.RECIPES[ftype]["labor"][t]) * EconFinance.wage_for(world, oid, t)
	return c / maxi(1, _unit(ftype))


## Set a site's posts (whole units) and settle its cash with the funder: top up next month's bill, return the excess.
static func _staff(world: WorldState, oid: String, posts: int) -> void:
	var o: Dictionary = world.table("org")[oid]
	var f := _site(world, oid)
	if f.is_empty():
		return
	var ftype: String = o["hq_type"]
	var u := _unit(ftype)
	posts = posts / u * u
	f["scale"] = posts * 1000 / u
	f["T"] = 1000
	f["mothball"] = posts <= 0
	f["hq_posts"] = posts
	var bill := 0
	var req := EconLabor.required(f)
	for t in req:
		bill += int(req[t]) / S * EconFinance.wage_for(world, oid, t)
	var acct := EconUtil.acct(oid)
	var funder: String = o["funder"]
	if not world.ledger.has_account(funder):
		return
	var bal := world.ledger.balance(acct)
	if bal < bill:
		EconUtil.pay_upto(world, funder, acct, bill - bal, "HQ_WAGES")
	elif bal > bill * KEEP_M:
		world.ledger.transfer(acct, funder, bal - bill * KEEP_M, "HQ_RETURN", world.month)


## Newsroom hook (EconHouseholds.pay_media_wages while active): a paper's wage money goes to its newsroom.
static func pay_newsroom(world: WorldState, from_acct: String, amount: int) -> int:
	var oid := org_for(world, from_acct)
	if oid == "" or world.table("org")[oid]["status"] in DEAD:
		var name := "Newsroom"
		for id in world.peek("outlet"):
			if String(world.peek("outlet")[id].get("account", "")) == from_acct:
				name = "%s newsroom" % String(world.peek("outlet")[id].get("name", id))
		oid = _found(world, from_acct, name, "NEWSROOM", "d:1")
	var paid := EconUtil.pay_upto(world, from_acct, EconUtil.acct(oid), amount, "MEDIA_WAGES")
	var s := EconUtil.st(world)
	var m: Dictionary = s.get("news_paid_m", {})
	m[oid] = int(m.get(oid, 0)) + paid
	s["news_paid_m"] = m
	return paid


## COMPANY_AI, before FirmAI.run: size party HQs, union HQs and newsrooms; settle their cash with the funders.
static func monthly(world: WorldState) -> void:
	if not active(world):
		return
	var s := EconUtil.st(world)
	var named: Dictionary = SQ.named_posts(world)
	# parties
	for pid in EconUtil.sorted_keys(world.peek("party")):
		var p: Dictionary = world.peek("party")[pid]
		var acct := "party:" + String(pid)
		var oid := org_for(world, acct)
		var alive := String(p.get("status", "ACTIVE")) == "ACTIVE" and world.ledger.has_account(acct)
		if oid == "":
			if not alive:
				continue
			oid = _found(world, acct, "%s headquarters" % String(p.get("name", pid)), "HQOFFICE", "d:1")
		var cost := maxi(1, _post_cost(world, oid, "HQOFFICE"))
		var want := HQ_BASE + int(p.get("seats", 0)) / SEAT_DIV
		want = maxi(want, int(named.get("PARTY:" + String(pid), 0)))
		var afford := maxi(0, world.ledger.balance(acct) + world.ledger.balance(EconUtil.acct(oid))) / (cost * PARTY_RUNWAY_M)
		_staff(world, oid, mini(want, afford) if alive else 0)
	# unions
	for uid in EconUtil.sorted_keys(world.peek("union")):
		var un: Dictionary = world.peek("union")[uid]
		var acct2 := String(un.get("acct", ""))
		if acct2 == "":
			continue
		var oid2 := org_for(world, acct2)
		var alive2 := String(un.get("status", "")) == "ACTIVE" and world.ledger.has_account(acct2)
		if oid2 == "":
			if not alive2:
				continue
			oid2 = _found(world, acct2, "%s office" % String(un.get("name", uid)), "HQOFFICE", "d:1")
		var cost2 := maxi(1, _post_cost(world, oid2, "HQOFFICE"))
		var want2 := int(un.get("members", 0)) / MEMBERS_PER_POST
		var afford2 := maxi(0, world.ledger.balance(acct2) + world.ledger.balance(EconUtil.acct(oid2))) / (cost2 * UNION_RUNWAY_M)
		_staff(world, oid2, mini(want2, afford2) if alive2 else 0)
	# newsrooms: posts from the smoothed wage money their papers sent
	var paid_m: Dictionary = s.get("news_paid_m", {})
	var ema: Dictionary = s.get("news_paid_ema", {})
	for oid3 in EconUtil.sorted_keys(world.table("org")):
		var o3: Dictionary = world.table("org")[oid3]
		if String(o3.get("hq_type", "")) != "NEWSROOM" or o3["status"] in DEAD:
			continue
		ema[oid3] = int(EMA_KEEP * float(ema.get(oid3, paid_m.get(oid3, 0))) + (1.0 - EMA_KEEP) * float(paid_m.get(oid3, 0)))
		var cost3 := maxi(1, _post_cost(world, oid3, "NEWSROOM"))
		var posts3 := int(float(ema[oid3]) * NEWS_SHARE) / cost3
		if not world.ledger.has_account(String(o3["funder"])):
			posts3 = 0
		_staff(world, oid3, posts3)
	s["news_paid_ema"] = ema
	s["news_paid_m"] = {}


## {PARTY|UNION|NEWS: {orgs, posts, staff}} for probes and the panel.
static func summary(world: WorldState) -> Dictionary:
	var out := {"PARTY": {"orgs": 0, "posts": 0, "staff": 0}, "UNION": {"orgs": 0, "posts": 0, "staff": 0}, "NEWS": {"orgs": 0, "posts": 0, "staff": 0}}
	for oid in EconUtil.sorted_keys(world.peek("org")):
		var o: Dictionary = world.peek("org")[oid]
		if not String(o.get("key", "")).begins_with("HQ|"):
			continue
		var funder := String(o["funder"])
		var kind := "PARTY" if funder.begins_with("party:") else ("UNION" if funder.begins_with("union:") else "NEWS")
		var f := _site(world, oid)
		out[kind]["orgs"] += 1
		out[kind]["posts"] += int(f.get("hq_posts", 0))
		out[kind]["staff"] += EconLabor.staff_total(f["staff"]) / S if not f.is_empty() else 0
	return out

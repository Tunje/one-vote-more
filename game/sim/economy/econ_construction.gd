class_name EconConstruction
extends RefCounted
## Construction & procurement (spec §10): projects, tenders, bids, awards, progress, payments, completion.
## Project rows live in world.table("project"). Quantities in mu, money in mcr.

const S := EconUtil.S


static func size_class(wu: int) -> String:
	if wu < 300:
		return "SMALL"
	return "MEDIUM" if wu < 800 else "LARGE"


## Create a project + open tender. owner = "gov" or an org id. operator = org id that will run the facility.
static func create(world: WorldState, ftype: String, district: String, owner: String, operator: String, line: String) -> String:
	var b: Array = EconData.BUILD[ftype]
	var id := world.new_id("project")
	world.table("project")[id] = {"id": id, "type": ftype, "district": district, "owner": owner, "operator": operator, "line": line,
		"wu_total": b[0] * S, "wu_done": 0, "mat_total": b[1] * S, "comp_total": b[2] * S, "min_months": b[3],
		"status": "TENDER", "tender_month": world.month, "bids": [], "contractor": "", "price": 0, "paid": 0,
		"bid_duration": 0, "start_month": -1, "size_class": size_class(b[0]), "prog_m": 0, "unpaid_m": 0,
		"late_noted": false, "supervision": 1000, "staff_task": "", "est_cost": estimate(ftype)}
	EconFacts.emit(world, "ECON_TENDER_OPENED", district, [["GOVERNMENT" if owner == "gov" else "COMPANY", owner]],
		[["GOVERNMENT", "government", 1.0]] if owner == "gov" else [["COMPANY", owner, 1.0]], {}, 10, "PUBLIC", {"project": id, "type": ftype})
	return id


## Modular expansion (E54): +25% capacity on an existing facility for 25% of its build bill.
static func create_expansion(world: WorldState, fid: String, owner: String) -> String:
	var f: Dictionary = world.table("facility")[fid]
	var b: Array = EconData.BUILD[f["type"]]
	var id := world.new_id("project")
	world.table("project")[id] = {"id": id, "type": "EXPAND", "target": fid, "district": f["district"], "owner": owner, "operator": f["org"],
		"line": "", "wu_total": b[0] * S / 4, "wu_done": 0, "mat_total": b[1] * S / 4, "comp_total": b[2] * S / 4,
		"min_months": maxi(2, b[3] / 2), "status": "TENDER", "tender_month": world.month, "bids": [], "contractor": "", "price": 0,
		"paid": 0, "bid_duration": 0, "start_month": -1, "size_class": size_class(b[0] / 4), "prog_m": 0, "unpaid_m": 0,
		"late_noted": false, "supervision": 1000, "staff_task": "", "est_cost": estimate(f["type"]) / 4}
	return id


## E106: upgrade a fabrication kit (PROCESSING / COMPONENTS) to the next tier. Paid by `owner` ("gov" with a budget
## line, or the operating company); the work consumes materials and components like any project.
static func create_upgrade(world: WorldState, fid: String, owner: String, line: String) -> String:
	var f: Dictionary = world.table("facility")[fid]
	var to_tier := int(f.get("tier", 2)) + 1
	var b: Array = EconData.UPGRADE_BUILD[to_tier]
	var id := world.new_id("project")
	world.table("project")[id] = {"id": id, "type": "UPGRADE", "target": fid, "to_tier": to_tier, "district": f["district"], "owner": owner,
		"operator": f["org"], "line": line, "wu_total": b[0] * S, "wu_done": 0, "mat_total": b[1] * S, "comp_total": b[2] * S,
		"min_months": b[3], "status": "TENDER", "tender_month": world.month, "bids": [], "contractor": "", "price": 0,
		"paid": 0, "bid_duration": 0, "start_month": -1, "size_class": size_class(b[0]), "prog_m": 0, "unpaid_m": 0,
		"late_noted": false, "supervision": 1000, "staff_task": "", "est_cost": upgrade_estimate(to_tier)}
	return id


static func upgrade_estimate(to_tier: int) -> int:
	var b: Array = EconData.UPGRADE_BUILD[to_tier]
	return int((b[0] * EconData.WU_COST_EST + b[1] * EconData.BASE_PRICE["MATERIAL"] + b[2] * EconData.BASE_PRICE["COMPONENT"]) * 1.15) * S


## An upgrade project already open for this facility?
static func upgrade_pending(world: WorldState, fid: String) -> bool:
	for pid in world.peek("project"):
		var p: Dictionary = world.peek("project")[pid]
		if p["type"] == "UPGRADE" and p.get("target", "") == fid and p["status"] in ["TENDER", "TENDERABLE", "ACTIVE"]:
			return true
	return false


static func estimate(ftype: String) -> int:
	var b: Array = EconData.BUILD[ftype]
	return int((b[0] * EconData.WU_COST_EST + b[1] * EconData.BASE_PRICE["MATERIAL"] + b[2] * EconData.BASE_PRICE["COMPONENT"]) * 1.15) * S


## Contractor monthly capacity in WU (mu).
static func capacity(world: WorldState, oid: String) -> int:
	var o: Dictionary = world.table("org")[oid]
	return int(float(EconLabor.staff_total(o["crew"])) * (0.9 + 0.002 * float(o["ceo"]["mgmt"])))


static func committed(world: WorldState, oid: String) -> int:
	var c := 0
	for pid in world.table("org")[oid]["contracts"]:
		var p: Dictionary = world.table("project")[pid]
		c += p["wu_total"] - p["wu_done"]
	return c


## COMPANY_AI: contractors bid on open tenders (spec §9.2).
static func bid_round(world: WorldState) -> void:
	var s := EconUtil.st(world)
	var tentative := {}  # contractor -> WU bid this round (so one round can't over-commit a firm)
	var order: Array = EconUtil.sorted_keys(world.table("project"))
	# E65: expansions of strategic inputs (mines, processing) are tendered first; private failed tenders retry quarterly
	order.sort_custom(func(a, b):
		var sa := 0 if _strategic_expansion(world, world.table("project")[a]) else 1
		var sb := 0 if _strategic_expansion(world, world.table("project")[b]) else 1
		return sa < sb or (sa == sb and a < b))
	for pid in order:
		var p: Dictionary = world.table("project")[pid]
		if p["status"] == "TENDERABLE" and p["owner"] != "gov" and world.month % 3 == 0:
			retender(world, pid)
		if p["status"] != "TENDER" or not p["bids"].is_empty():
			continue
		if world.month - p["tender_month"] > 2:
			p["status"] = "TENDERABLE"
			EconFacts.emit(world, "ECON_TENDER_FAILED", p["district"], [["GOVERNMENT", "government"]],
				[["GOVERNMENT", "government", 0.7], ["NATURE", "market", 0.3]], {"GOVERNANCE": -5}, 20, "PUBLIC", {"project": pid})
			continue
		for oid in EconUtil.sorted_keys(world.table("org")):
			var o: Dictionary = world.table("org")[oid]
			if not o["is_contractor"] or not (o["status"] in ["ACTIVE", "DISTRESSED"]):
				continue
			var public_builder: bool = o["type"] == "PUBLIC_ENTERPRISE"
			var e86 := not EconUtil.off(world, "E86")
			if public_builder and (p["owner"] != "gov" and (not e86 or _private_builder_alive(world)) or (p["owner"] == "gov" and p.get("tenders", 0) < 1 and _private_builder_alive(world))):
				continue  # E76: last resort only; E86: with no private builder left it also builds for private owners
			# potential capacity: firms can re-hire to their founding crew, so idle crews still bid (E51)
			var base_crew := 0
			for t in EconData.ORGS.get(o["key"], ["", "", 0, 0, 0, 0, 0, 0, {"G": 30}])[8]:
				base_crew += EconData.ORGS.get(o["key"], ["", "", 0, 0, 0, 0, 0, 0, {"G": 30}])[8][t]
			var k := maxi(maxi(capacity(world, oid), base_crew * S * 9 / 10), S)
			var window := maxi(p["min_months"], 12)
			var load := float(committed(world, oid) + tentative.get(oid, 0) + p["wu_total"]) / float(k * window)
			var allowance := 1.0 + 0.5 * float(o["ceo"]["risk"]) / 100.0
			if _strategic_expansion(world, p):
				allowance += 0.5
			if load > allowance:
				continue
			var mgmt := float(o["ceo"]["mgmt"])
			var est_wu := float(p["wu_total"]) * maxf(0.5, 1.0 + EconUtil.normal(world, "comp.bid", 0.25 * (1.0 - mgmt / 100.0)))
			var wage_per_wu := _crew_wage(world, oid)
			var cost := est_wu / S * wage_per_wu * 1.08 + float(EconUtil.val(p["mat_total"], s["prices"]["MATERIAL"])) * 1.03 \
				+ float(EconUtil.val(p["comp_total"], s["prices"]["COMPONENT"])) * 1.03
			var margin := 0.12 - 0.08 * float(o["ceo"]["risk"]) / 100.0
			if public_builder:
				margin = 0.0 if p["owner"] == "gov" else 0.08
			var dur := maxi(p["min_months"], int(ceil(est_wu / (0.6 * float(k)))))
			p["bids"].append({"org": oid, "price": int(cost * (1.0 + margin)), "duration": dur, "reliability": o["reliability"]})
			tentative[oid] = tentative.get(oid, 0) + p["wu_total"]


static func _private_builder_alive(world: WorldState) -> bool:
	for oid in world.table("org"):
		var o: Dictionary = world.table("org")[oid]
		if o["is_contractor"] and o["type"] != "PUBLIC_ENTERPRISE" and o["status"] in ["ACTIVE", "DISTRESSED"]:
			return true
	return false


static func _strategic_expansion(world: WorldState, p: Dictionary) -> bool:
	var types: Array = EconData.STRATEGIC_INPUT_TYPES
	if not EconUtil.off(world, "E95b"):
		types = types + ["COMPONENTS", "FARM", "POWER", "WATERWORKS"]  # E95b: food and utilities capacity too (no imports to fall back on)
	if p["type"] in types:
		return true
	if p["type"] in ["EXPAND", "UPGRADE"] and world.table("facility").has(p.get("target", "")):
		return world.table("facility")[p["target"]]["type"] in types
	return false


static func _crew_wage(world: WorldState, oid: String) -> float:
	var o: Dictionary = world.table("org")[oid]
	var n := 0.0
	var w := 0.0
	for t in o["crew"]:
		var c := float(EconLabor.tier_total(o["crew"], t))
		n += c
		w += c * float(EconLabor.offer(world, oid, t))
	return w / n if n > 0.0 else float(EconUtil.st(world)["wage"]["G"])


## Bid scores (spec §10.2). Returns bids sorted best first, each with "score" (milli).
static func ranked_bids(world: WorldState, p: Dictionary) -> Array:
	var wp := float(EconUtil.lever(world, "ECON_PROCUREMENT_PRICE_WEIGHT", 50)) / 100.0
	var wr := 0.6 * (1.0 - wp)
	var wd := 0.4 * (1.0 - wp)
	var min_price := 1 << 62
	var min_dur := 1 << 30
	for b in p["bids"]:
		min_price = mini(min_price, b["price"])
		min_dur = mini(min_dur, b["duration"])
	var out: Array = []
	for b in p["bids"]:
		var sc := wp * float(min_price) / float(b["price"]) + wr * float(b["reliability"]) / 100.0 + wd * float(min_dur) / float(b["duration"])
		var c: Dictionary = b.duplicate()
		c["score"] = int(sc * 1000)
		out.append(c)
	out.sort_custom(func(a, b): return a["score"] > b["score"] or (a["score"] == b["score"] and a["org"] < b["org"]))
	return out


## Award a tendered project to a bidder (index into ranked bids). Pays the 10% advance.
static func award(world: WorldState, pid: String, org_id: String) -> bool:
	var p: Dictionary = world.table("project")[pid]
	if p["status"] != "TENDER":
		return false
	var ranked := ranked_bids(world, p)
	var chosen: Dictionary = {}
	var rank := 0
	for i in ranked.size():
		if ranked[i]["org"] == org_id:
			chosen = ranked[i]
			rank = i
	if chosen.is_empty():
		return false
	p["contractor"] = org_id
	p["price"] = chosen["price"]
	p["bid_duration"] = chosen["duration"]
	p["status"] = "ACTIVE"
	p["start_month"] = world.month
	# E76 escalation basis: material share of the price and the MATERIAL/COMPONENT prices at award
	var st := EconUtil.st(world)
	p["esc_mat_price"] = st["prices"]["MATERIAL"]
	p["esc_comp_price"] = st["prices"]["COMPONENT"]
	p["esc_mat_cost"] = EconUtil.val(p["mat_total"], st["prices"]["MATERIAL"])
	p["esc_comp_cost"] = EconUtil.val(p["comp_total"], st["prices"]["COMPONENT"])
	world.table("org")[org_id]["contracts"].append(pid)
	_pay(world, p, p["price"] / 10)
	EconFacts.emit(world, "ECON_CONTRACT_AWARDED", p["district"], [["GOVERNMENT", "government"], ["COMPANY", org_id]],
		[["GOVERNMENT", "government", 1.0]] if p["owner"] == "gov" else [["COMPANY", p["owner"], 1.0]], {},
		40 if rank > 0 else 15, "PUBLIC", {"project": pid, "price": p["price"], "override": rank > 0, "score_rank": rank + 1})
	return true


## Owner pays contractor; returns paid.
static func _pay(world: WorldState, p: Dictionary, amount: int) -> int:
	var to := EconUtil.acct(p["contractor"])
	var paid := 0
	if p["owner"] == "gov":
		paid = EconFinance.gov_pay(world, to, amount, "CONTRACT_PAYMENT")
		EconFinance._spend_line(world, p["line"], paid)
	else:
		paid = EconUtil.pay_upto(world, EconUtil.acct(p["owner"]), to, amount, "CONTRACT_PAYMENT")
	EconFinance.pl_add(world, p["contractor"], "rev", paid)
	p["paid"] += paid
	return paid


## PRODUCTION: progress on active contracts.
static func progress(world: WorldState) -> void:
	for oid in EconUtil.sorted_keys(world.table("org")):
		var o: Dictionary = world.table("org")[oid]
		if not o["is_contractor"]:
			continue
		var active: Array = o["contracts"].filter(func(pid): return world.table("project")[pid]["status"] == "ACTIVE")
		if active.is_empty():
			continue
		var k := capacity(world, oid)
		if not EconUtil.off(world, "E109"):
			_progress_fill(world, oid, o, active, k)
			continue
		var weights: Array = []
		for pid in active:
			var p: Dictionary = world.table("project")[pid]
			var months_left := maxi(1, p["start_month"] + p["bid_duration"] - world.month)
			var w := float(p["wu_total"] - p["wu_done"]) / float(months_left)
			if world.month > p["start_month"] + p["bid_duration"]:
				w *= 2.0  # overdue first
			weights.append(w)
		var alloc := EconUtil.split_lr(k, weights)
		var done_total := 0
		for i in active.size():
			var p: Dictionary = world.table("project")[active[i]]
			p["prog_m"] = 0
			if p["unpaid_m"] >= 2:
				continue  # work suspended for non-payment
			var sup := 0.9 + 0.2 * float(p["supervision"]) / 1000.0
			var wu := mini(int(float(alloc[i]) * sup), mini(p["wu_total"] / maxi(1, p["min_months"]), p["wu_total"] - p["wu_done"]))
			if wu <= 0:
				continue
			var mat_need := int(float(p["mat_total"]) * wu / p["wu_total"])
			var comp_need := int(float(p["comp_total"]) * wu / p["wu_total"])
			var hq: String = o["hq"]
			var um := 1.0
			if mat_need > 0:
				um = minf(um, float(EconUtil.inv_get(world, oid, "MATERIAL", hq)) / float(mat_need))
			var uc := 1.0
			if comp_need > 0:
				uc = clampf(float(EconUtil.inv_get(world, oid, "COMPONENT", hq)) / float(comp_need), 0.0, 1.0)
			um = clampf(minf(um, 0.5 + 0.5 * uc), 0.0, 1.0)  # components are soft: without them work runs at half speed (E46)
			var done := int(wu * um)
			if done <= 0:
				continue
			for pair in [["MATERIAL", int(mat_need * um)], ["COMPONENT", int(comp_need * minf(um, uc))]]:
				var wac := EconUtil.inv_wac(world, oid, pair[0], hq)
				var took := EconUtil.inv_take(world, oid, pair[0], hq, pair[1])
				EconUtil.qflow(world, pair[0], "burned", took)
				EconFinance.pl_add(world, oid, "cogs", EconUtil.val(took, wac))
			p["wu_done"] += done
			p["prog_m"] = done
			done_total += done
			_check_late(world, p)
			if p["wu_done"] >= p["wu_total"]:
				_complete(world, p)
		o["blocked_last"] = done_total < k * 7 / 10


## E109: crew capacity is filled project by project in priority order (strategic input capacity, then overdue,
## then the nearest to completion), instead of being spread pro rata. Suspended contracts (owner not paying) and
## projects without material take no capacity, so it rolls on to work that can proceed. A remnant under one work
## unit is finished off. The crew counts as material-blocked only when material, not a lack of workable
## contracts, left capacity idle.
static func _progress_fill(world: WorldState, oid: String, o: Dictionary, active: Array, k: int) -> void:
	var rows: Array = []
	for pid in active:
		var p: Dictionary = world.table("project")[pid]
		p["prog_m"] = 0
		if p["unpaid_m"] >= 2:
			continue  # work suspended for non-payment
		var overdue: bool = world.month > int(p["start_month"]) + int(p["bid_duration"])
		rows.append([0 if _strategic_expansion(world, p) else 1, 0 if overdue else 1, p["wu_total"] - p["wu_done"], pid])
	rows.sort()
	var hq: String = o["hq"]
	var left := k
	var workable := 0
	var done_total := 0
	for r in rows:
		var p: Dictionary = world.table("project")[r[3]]
		var remaining: int = int(p["wu_total"]) - int(p["wu_done"])
		if remaining < S:
			p["wu_done"] = p["wu_total"]  # remnant under one work unit
			_complete(world, p)
			continue
		var sup := 0.9 + 0.2 * float(p["supervision"]) / 1000.0
		var cap_p: int = mini(maxi(S, int(p["wu_total"]) / maxi(1, int(p["min_months"]))), remaining)
		workable += cap_p
		if left <= 0:
			continue
		var wu := mini(int(float(left) * sup), cap_p)
		var mat_need := int(float(p["mat_total"]) * wu / p["wu_total"])
		var comp_need := int(float(p["comp_total"]) * wu / p["wu_total"])
		var um := 1.0
		if mat_need > 0:
			um = minf(um, float(EconUtil.inv_get(world, oid, "MATERIAL", hq)) / float(mat_need))
		var uc := 1.0
		if comp_need > 0:
			uc = clampf(float(EconUtil.inv_get(world, oid, "COMPONENT", hq)) / float(comp_need), 0.0, 1.0)
		um = clampf(minf(um, 0.5 + 0.5 * uc), 0.0, 1.0)  # components are soft (E46)
		var done := int(wu * um)
		if done <= 0:
			continue
		for pair in [["MATERIAL", int(mat_need * um)], ["COMPONENT", int(comp_need * minf(um, uc))]]:
			var wac := EconUtil.inv_wac(world, oid, pair[0], hq)
			var took := EconUtil.inv_take(world, oid, pair[0], hq, pair[1])
			EconUtil.qflow(world, pair[0], "burned", took)
			EconFinance.pl_add(world, oid, "cogs", EconUtil.val(took, wac))
		p["wu_done"] += done
		p["prog_m"] = done
		done_total += done
		left -= int(float(done) / sup)
		_check_late(world, p)
		if p["wu_total"] - p["wu_done"] < S:
			p["wu_done"] = p["wu_total"]
			_complete(world, p)
	o["blocked_last"] = done_total < mini(k, workable) * 7 / 10


static func _check_late(world: WorldState, p: Dictionary) -> void:
	var late: int = world.month - (p["start_month"] + p["bid_duration"])
	if late <= 0:
		return
	EconFacts.emit(world, "ECON_CONTRACT_DELAYED", p["district"], [["COMPANY", p["contractor"]]],
		[["COMPANY", p["contractor"], 0.6], ["GOVERNMENT", "government", 0.4]], {"GOVERNANCE": -3, "INFRASTRUCTURE": -2},
		15 + 5 * late, "PUBLIC", {"project": p["id"], "months_late": late})
	if late >= 4 and not p["late_noted"]:
		p["late_noted"] = true
		EconFacts.emit(world, "ECON_CONTRACT_SEVERELY_DELAYED", p["district"], [["COMPANY", p["contractor"]]],
			[["COMPANY", p["contractor"], 0.6], ["GOVERNMENT", "government", 0.4]], {"GOVERNANCE": -8}, 40, "PUBLIC",
			{"project": p["id"], "months_late": late})


static func _complete(world: WorldState, p: Dictionary) -> void:
	p["status"] = "DONE"
	p["done_month"] = world.month
	if not EconUtil.off(world, "E110"):
		EconEssentials.on_complete(world, p)  # E110: incentive grant to a private owner
	var o: Dictionary = world.table("org")[p["contractor"]]
	o["contracts"].erase(p["id"])
	var actual: int = world.month - p["start_month"] + 1
	o["reliability"] = int(0.8 * o["reliability"] + 0.2 * 100.0 * minf(1.0, float(p["bid_duration"]) / float(maxi(1, actual))))
	var fid := ""
	if p["type"] == "ROAD":
		pass  # link upgrades are recorded only (map owns links; v1 keeps capacities fixed)
	elif p["type"] == "EXPAND":
		fid = p["target"]
		if world.table("facility").has(fid):
			var tf: Dictionary = world.table("facility")[fid]
			tf["scale"] = mini(3000, tf.get("scale", 1000) + 250)
			tf["book"] += p["price"]
	elif p["type"] == "UPGRADE":
		fid = p["target"]
		if world.table("facility").has(fid):
			var uf: Dictionary = world.table("facility")[fid]
			uf["tier"] = mini(3, int(p.get("to_tier", int(uf.get("tier", 2)) + 1)))
			uf["book"] += p["price"]
	else:
		fid = EconSetup.add_facility(world, p["type"], p["operator"], p["district"], false)
		world.table("facility")[fid]["book"] = p["price"]
	var impact := {"HOUSING": 15} if p["type"] == "HOUSING" else {"INFRASTRUCTURE": 5, "JOBS": 3}
	EconFacts.emit(world, "ECON_PROJECT_COMPLETED", p["district"], [["GOVERNMENT", "government"], ["COMPANY", p["contractor"]]],
		[["GOVERNMENT", "government", 0.7], ["COMPANY", p["contractor"], 0.3]] if p["owner"] == "gov" else [["COMPANY", p["owner"], 1.0]],
		impact, 40 if p["type"] == "HOUSING" else 30, "PUBLIC", {"project": p["id"], "facility": fid, "type": p["type"]},
		{"districts": [p["district"]]})


## SETTLEMENT: progress payments (80%), completion balance incl. 10% retention minus late penalty.
static func settle_payments(world: WorldState) -> void:
	for pid in EconUtil.sorted_keys(world.table("project")):
		var p: Dictionary = world.table("project")[pid]
		if p["contractor"] == "" or not (p["status"] in ["ACTIVE", "DONE"]) or p.get("settled", false):
			continue
		var due := 0
		if p["status"] == "DONE":
			var late: int = maxi(0, p["done_month"] - (p["start_month"] + p["bid_duration"]))
			var penalty := 0
			if p["supervision"] >= 500:
				penalty = int(p["price"] * minf(0.10, 0.01 * late))
			due = maxi(0, p["price"] - penalty - p["paid"])
			p["settled"] = true
		elif p["prog_m"] > 0:
			due = int(float(p["price"]) * 0.8 * float(p["prog_m"]) / float(p["wu_total"]))
			due += _escalation(world, p, float(p["prog_m"]) / float(p["wu_total"]))
		if due <= 0:
			continue
		var paid := _pay(world, p, due)
		if paid < due:
			p["unpaid_m"] += 1
			if p["owner"] != "gov" and p["unpaid_m"] >= 3 and p["status"] == "ACTIVE":
				# E76: a contractor terminates a private contract the owner cannot pay (instead of bleeding to death)
				p["status"] = "CANCELLED"
				world.table("org")[p["contractor"]]["contracts"].erase(pid)
				EconFacts.emit(world, "ECON_PROJECT_CANCELLED", p["district"], [["COMPANY", p["owner"]], ["COMPANY", p["contractor"]]],
					[["COMPANY", p["owner"], 1.0]], {}, 20, "PUBLIC", {"project": pid, "reason": "owner_unpaid"})
				continue
			EconFacts.emit(world, "ECON_CONTRACT_PAYMENT_MISSED", p["district"], [["GOVERNMENT" if p["owner"] == "gov" else "COMPANY", p["owner"]], ["COMPANY", p["contractor"]]],
				[["GOVERNMENT", "government", 1.0]] if p["owner"] == "gov" else [["COMPANY", p["owner"], 1.0]],
				{"GOVERNANCE": -5} if p["owner"] == "gov" else {}, 30, "PUBLIC", {"project": pid, "amount_due": due - paid, "months_overdue": p["unpaid_m"]})
		else:
			p["unpaid_m"] = 0


## E76 price escalation clause: the input-cost change since award on the work done this month (both directions,
## capped at ±100% of the input cost), so fixed-price contracts don't bankrupt builders when MATERIAL/COMPONENT spike.
static func _escalation(world: WorldState, p: Dictionary, frac: float) -> int:
	if not p.has("esc_mat_price"):
		return 0
	var st := EconUtil.st(world)
	var e := 0.0
	for pair in [["MATERIAL", "esc_mat_price", "esc_mat_cost"], ["COMPONENT", "esc_comp_price", "esc_comp_cost"]]:
		var base := float(maxi(1, p[pair[1]]))
		var ch := clampf(float(st["prices"][pair[0]]) / base - 1.0, -0.5, 1.0)
		e += float(p[pair[2]]) * frac * ch
	return int(e)


## Contractor liquidation: terminate its contracts; keep progress; project can be re-tendered.
static func fail_contracts(world: WorldState, oid: String) -> void:
	var o: Dictionary = world.table("org")[oid]
	for pid in o["contracts"].duplicate():
		var p: Dictionary = world.table("project")[pid]
		if p["status"] != "ACTIVE":
			continue
		p["status"] = "TENDERABLE"
		p["contractor"] = ""
		p["bids"] = []
		p["price"] = 0
		p["paid"] = 0
		var rem := float(p["wu_total"] - p["wu_done"]) / float(p["wu_total"])
		p["wu_total"] -= p["wu_done"]
		p["mat_total"] = int(p["mat_total"] * rem)
		p["comp_total"] = int(p["comp_total"] * rem)
		p["wu_done"] = 0
		p["min_months"] = maxi(1, int(ceil(float(p["min_months"]) * rem)))  # E107a: the pace cap follows the remaining work
		EconFacts.emit(world, "ECON_CONTRACT_FAILED", p["district"], [["COMPANY", oid]],
			[["COMPANY", oid, 0.6], ["GOVERNMENT", "government", 0.4]], {"GOVERNANCE": -10, "INFRASTRUCTURE": -5}, 50, "PUBLIC", {"project": pid})
	o["contracts"] = []
	o["reliability"] = int(o["reliability"] * 0.5)


## Re-open a TENDERABLE project for bids.
static func retender(world: WorldState, pid: String) -> void:
	var p: Dictionary = world.table("project")[pid]
	if p["status"] in ["TENDERABLE", "TENDER"]:
		p["status"] = "TENDER"
		p["tender_month"] = world.month
		p["bids"] = []
		p["tenders"] = p.get("tenders", 0) + 1


## Contractor AI: crew targets + material orders (COMPANY_AI).
static func contractor_plans(world: WorldState) -> void:
	var s := EconUtil.st(world)
	for oid in EconUtil.sorted_keys(world.table("org")):
		var o: Dictionary = world.table("org")[oid]
		if not o["is_contractor"] or o["status"] in ["LIQUIDATION", "DISSOLVED"]:
			continue
		var need_wu := 0.0
		var mat := 0
		var comp := 0
		var strategic := false
		for pid in o["contracts"]:
			var p: Dictionary = world.table("project")[pid]
			if p["status"] == "ACTIVE" and _strategic_expansion(world, p) and not EconUtil.off(world, "E95"):
				strategic = true
			if p["status"] != "ACTIVE" or p["unpaid_m"] >= 1:
				continue  # E76: no material purchases for work the owner is not paying for
			var months_left := maxi(1, p["start_month"] + p["bid_duration"] - world.month)
			var rate := minf(float(p["wu_total"] - p["wu_done"]) / float(months_left), float(p["wu_total"]) / float(p["min_months"]))
			need_wu += rate
			var frac := 2.0 * rate / float(p["wu_total"])
			mat += int(p["mat_total"] * frac)
			comp += int(p["comp_total"] * frac)
		var base: Dictionary = EconData.ORGS.get(o["key"], [])[8] if EconData.ORGS.has(o["key"]) else {"G": 30, "S": 10}
		var base_n := 0
		for t in base:
			base_n += base[t]
		var cur := float(EconLabor.staff_total(o["crew"])) / S
		var target_n := need_wu / S / (0.9 + 0.002 * float(o["ceo"]["mgmt"]))
		# growth limits: ≤ +25%/month, ≤ 2× founding crew, no growth while material-blocked last month
		var max_mult := 3.0 if o["type"] == "PUBLIC_ENTERPRISE" and not _private_builder_alive(world) else 2.0  # E86: sole builder
		var cap_n := minf(maxf(cur * 1.25, cur + 5.0), max_mult * float(base_n))
		if o.get("blocked_last", false) and not strategic:
			cap_n = cur * 0.85  # blocked crews shrink (E95: not while building strategic input capacity)
		target_n = minf(target_n, cap_n)
		if not o["contracts"].is_empty():
			target_n = maxf(target_n, 0.6 * cur)
		target_n = maxf(target_n, 0.3 * float(base_n))  # core crew kept between contracts
		for t in base:
			o["crew_target"][t] = int(round(target_n * float(base[t]) / float(base_n)))
		var hq: String = o["hq"]
		var budget := world.ledger.balance(EconUtil.acct(oid)) - int(EconFinance._monthly_costs(o) * 0.5)
		var mat_cost := EconUtil.val(maxi(0, mat - EconUtil.inv_get(world, oid, "MATERIAL", hq)), s["prices"]["MATERIAL"]) 			+ EconUtil.val(maxi(0, comp - EconUtil.inv_get(world, oid, "COMPONENT", hq)), s["prices"]["COMPONENT"])
		if mat_cost > budget:
			budget += FirmAI._working_capital(world, oid, mat_cost - budget)
		for pair in [["MATERIAL", mat], ["COMPONENT", comp]]:
			var want: int = pair[1] - EconUtil.inv_get(world, oid, pair[0], hq)
			if want <= 0 or budget <= 0:
				continue
			var lim := int(s["prices"][pair[0]] * EconData.INPUT_LIMIT_MULT) + 3 * int(EconUtil.lever(world, "ECON_FREIGHT_TARIFF", 5)) * S
			want = mini(want, int(float(budget) * S / float(lim)))
			if want > 0:
				s["orders"].append({"buyer": oid, "acct": EconUtil.acct(oid), "district": hq, "good": pair[0], "qty": want,
					"limit": lim, "class": EconMarket.C_FIRM if strategic else EconMarket.C_CONSTRUCTION, "kind": "org"})  # E56; E95: strategic input capacity buys with producers
				budget -= EconUtil.val(want, lim)

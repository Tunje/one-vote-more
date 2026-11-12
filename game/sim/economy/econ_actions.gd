class_name EconActions
extends RefCounted
## Econ actions (planning/pic-economy.md §4). Callers enqueue in DECISIONS (or any time); econ applies them at the
## start of TRADE. Player and AI use the same entry point. Params use display units (credits, units).

const S := EconUtil.S
## Government project operators by facility type.
## E110 (A39): FARM → the Colony Agricultural Board (founded on first use), fabrication plants → CPW.
const OPERATOR := {"HOUSING": "CHO", "POWER": "CPW", "WATERWORKS": "CPW", "DEPOT": "CTA", "ROAD": "CTA",
	"CLINIC": "HEALTH", "SCHOOL": "SCHOOLS", "FARM": "CAB", "PROCESSING": "CPW", "COMPONENTS": "CPW"}
const LINE_OF := {"HOUSING": "ECON_BUDGET_HOUSING"}
## Budget lines that may pay for a commissioned project (first = default). Public works is the counter-cyclical line (E68).
const PUBLIC_WORKS := "ECON_BUDGET_PUBLIC_WORKS"


static func lines_for(ftype: String) -> Array:
	return [LINE_OF.get(ftype, "ECON_BUDGET_INFRASTRUCTURE"), PUBLIC_WORKS]


## Queue an action for the next TRADE phase. Returns {ok, error}: obviously invalid actions (unknown type, line not
## allowed, not enough budget headroom, project not open, …) are rejected NOW with a readable reason and not queued.
## A queued action can still fail at apply time (e.g. two commissions competing for the same headroom); the reason
## is then recorded in action_log (see last_results).
static func enqueue(world: WorldState, action_id: String, params: Dictionary = {}) -> Dictionary:
	var err := validate(world, action_id, params)
	if err != "":
		return {"ok": false, "error": err}
	EconUtil.st(world)["queue"].append({"id": action_id, "params": params, "month": world.month})
	return {"ok": true, "error": ""}


## Pure pre-check for UI buttons: {ok, error}. error is player-readable and carries the numbers.
static func check(world: WorldState, id: String, params: Dictionary) -> Dictionary:
	var err := validate(world, id, params)
	return {"ok": err == "", "error": err}


## Why would this action fail right now? "" = looks valid. Pure read.
static func validate(world: WorldState, id: String, p: Dictionary) -> String:
	if id == "ECON_ORDER_IMPORTS" and not EconUtil.support(world):
		return "No ship is due: imports arrive only with the home-world ships, rarely and at great cost"
	match id:
		"ECON_OFFER_INCENTIVE":
			return EconEssentials.validate_offer(world, p)
		"ECON_ANSWER_UNION_DEMAND":
			return UnionDisputes.validate_answer(world, p)  # U2: the government (player) answers a public-sector demand
		"ECON_UPGRADE_FACILITY":
			var fid: String = p.get("facility", "")
			if not world.peek("facility").has(fid):
				return "Unknown facility %s" % fid
			var f: Dictionary = world.peek("facility")[fid]
			if not (f["type"] in EconData.KIT_TYPES):
				return "Only fabrication kits (smelters, component workshops) can be upgraded"
			if int(f.get("tier", 2)) >= 3:
				return "Already at the highest tier (Mk III)"
			var o: Dictionary = world.peek("org").get(f["org"], {})
			if not (o.get("type", "") in EconData.PUBLIC_TYPES):
				return "The state can only upgrade plants it owns (offer an incentive to private owners instead)"
			if EconConstruction.upgrade_pending(world, fid):
				return "An upgrade of this plant is already under way"
			var uline: String = p.get("line", "ECON_BUDGET_INFRASTRUCTURE")
			if not uline in ["ECON_BUDGET_INFRASTRUCTURE", PUBLIC_WORKS]:
				return "Upgrades are paid from Infrastructure or Public works"
			var ucost := EconConstruction.upgrade_estimate(int(f.get("tier", 2)) + 1) * 11 / 10
			if headroom(world, uline) < ucost:
				return "Not enough budget: %s has %dk uncommitted this year, the upgrade needs %dk" % [uline, headroom(world, uline) / 1000 / S, ucost / 1000 / S]
			return ""
		"ECON_COMMISSION_PROJECT":
			var ftype: String = p.get("type", "")
			if not OPERATOR.has(ftype) or not EconData.BUILD.has(ftype):
				return "Cannot commission '%s' (buildable: %s)" % [ftype, ", ".join(OPERATOR.keys().filter(func(t): return EconData.BUILD.has(t)))]
			if not EconData.DISTRICTS.has(p.get("district", "")):
				return "Unknown district '%s'" % str(p.get("district", ""))
			var line: String = p.get("line", LINE_OF.get(ftype, "ECON_BUDGET_INFRASTRUCTURE"))
			if not line in lines_for(ftype):
				return "%s cannot be paid from %s (allowed: %s)" % [ftype, line, ", ".join(lines_for(ftype))]
			var need := EconConstruction.estimate(ftype) * 11 / 10
			if ftype == "ROAD" and p.has("link") and not EconUtil.off(world, "T1"):
				# A43 / T1: a road along a real link — Terra's planner checks the route and prices it exactly
				var lerr: String = Transport.validate_link(world, p["link"])
				if lerr != "":
					return lerr
				need = int(Transport.plan_link(world, p["link"]).get("cost", 0)) * 11 / 10
			var room := headroom(world, line)
			if room < need:
				return "Not enough budget: %s has %dk uncommitted this year, %s needs %dk (estimate + 10%%)" % [line, room / 1000 / S, ftype, need / 1000 / S]
		"ECON_AWARD_CONTRACT", "ECON_RETENDER_PROJECT", "ECON_CANCEL_PROJECT":
			var pr: Dictionary = world.peek("project").get(p.get("project", ""), {})
			if pr.is_empty():
				return "Unknown project '%s'" % str(p.get("project", ""))
			if pr["owner"] != "gov":
				return "Not a public project"
			if id == "ECON_AWARD_CONTRACT":
				if pr["status"] != "TENDER":
					return "Project %s is not in an open tender (status %s)" % [pr["id"], pr["status"]]
				if not pr["bids"].any(func(b): return b["org"] == p.get("org", "")):
					return "%s did not bid on %s" % [str(p.get("org", "")), pr["id"]]
			elif pr["status"] in ["DONE", "CANCELLED"]:
				return "Project %s is already %s" % [pr["id"], String(pr["status"]).to_lower()]
		"ECON_SUBSIDIZE":
			if not world.peek("org").has(p.get("org", "")):
				return "Unknown company"
			if int(p.get("amount", 0)) <= 0:
				return "Amount must be positive"
			if headroom(world, "ECON_BUDGET_SUBSIDIES") < int(p.get("amount", 0)) * S:
				return "Not enough left on the Subsidies line (%dk)" % (headroom(world, "ECON_BUDGET_SUBSIDIES") / 1000 / S)
	return ""


## Results of recently applied actions, newest first: [{m, id, ok, error}].
static func last_results(world: WorldState, n: int = 10) -> Array:
	var log: Array = EconUtil.peek_st(world).get("action_log", []).duplicate(true)
	log.reverse()
	return log.slice(0, n)


## Player option (not a policy decision): choose contractors yourself (3-month window) instead of the
## delegated official awarding the top-scored bid.
static func set_manual_award(world: WorldState, on: bool) -> void:
	world.meta["manual_award"] = on


## Actions queued for the next TRADE phase (read-only view for the UI).
static func pending(world: WorldState) -> Array:
	return EconUtil.peek_st(world).get("queue", []).duplicate(true)


static func apply_queue(world: WorldState) -> void:
	var s := EconUtil.st(world)
	if world.month_of_year() == 1 and s.get("ytd_year", -1) != world.year():
		s["spent_ytd"] = {}
		s["ytd_year"] = world.year()
	var q: Array = s["queue"]
	s["queue"] = []
	for a in q:
		var why := validate(world, a["id"], a["params"])
		var res := apply(world, a["id"], a["params"])
		var log: Array = s.get("action_log", [])
		log.append({"m": world.month, "id": a["id"], "ok": res, "error": "" if res else (why if why != "" else "failed when applied")})
		if not res:
			# surfaced in the government briefing (a9); no voter impact
			EconFacts.emit(world, "ECON_ACTION_FAILED", a["params"].get("district", null), [["GOVERNMENT", "government"]], [["GOVERNMENT", "government", 1.0]],
				{}, 35, "OFFICIAL", {"action": a["id"], "params": a["params"].duplicate(), "error": log[-1]["error"]})
		while log.size() > 50:
			log.pop_front()
		s["action_log"] = log


## Uncommitted headroom (mcr) on a budget line this fiscal year.
static func headroom(world: WorldState, line: String) -> int:  # pure read (used by queries/UI too)
	var s := EconUtil.peek_st(world)
	var annual := int(EconUtil.lever(world, line, 0)) * 1000 * S
	var committed := 0
	for pid in world.peek("project"):
		var p: Dictionary = world.peek("project")[pid]
		if p["owner"] == "gov" and p["line"] == line and p["status"] in ["TENDER", "ACTIVE", "TENDERABLE"]:
			committed += (p["price"] - p["paid"]) if p["status"] == "ACTIVE" else p["est_cost"]
	return annual - s.get("spent_ytd", {}).get(line, 0) - committed


static func apply(world: WorldState, id: String, p: Dictionary) -> bool:
	match id:
		"ECON_OFFER_INCENTIVE":
			return EconEssentials.apply_offer(world, p)
		"ECON_ANSWER_UNION_DEMAND":
			return UnionDisputes.apply_answer(world, p)
		"ECON_UPGRADE_FACILITY":
			EconConstruction.create_upgrade(world, p["facility"], "gov", p.get("line", "ECON_BUDGET_INFRASTRUCTURE"))
			return true
		"ECON_COMMISSION_PROJECT":
			var ftype: String = p["type"]
			if not OPERATOR.has(ftype) or not EconData.BUILD.has(ftype):
				return false
			var line: String = p.get("line", LINE_OF.get(ftype, "ECON_BUDGET_INFRASTRUCTURE"))
			if not line in lines_for(ftype):
				return false
			if validate(world, id, p) != "":
				return false  # includes the T1 route check and its exact road price
			var op: String = EconEssentials.operator_for(world, ftype)
			var link: Dictionary = p.get("link", {}) if ftype == "ROAD" and typeof(p.get("link", {})) == TYPE_DICTIONARY else {}
			if ftype == "HOUSING":  # E120 lots: a public block is tendered as parallel lots too ("lots": 1..10)
				EconConstruction.create_lots(world, ftype, p["district"], "gov", op, line, int(p.get("lots", EconConstruction.HOUSING_LOTS)))
			else:
				EconConstruction.create(world, ftype, p["district"], "gov", op, line, link)
			return true
		"ECON_AWARD_CONTRACT":
			return EconConstruction.award(world, p["project"], p["org"])
		"ECON_RETENDER_PROJECT":
			EconConstruction.retender(world, p["project"])
			return true
		"ECON_CANCEL_PROJECT":
			var pr: Dictionary = world.table("project").get(p["project"], {})
			if pr.is_empty() or pr["status"] == "DONE":
				return false
			if pr["status"] == "ACTIVE":
				var remaining: int = pr["price"] - pr["paid"]
				EconConstruction._pay(world, pr, remaining * 5 / 100)
				world.table("org")[pr["contractor"]]["contracts"].erase(pr["id"])
			pr["status"] = "CANCELLED"
			EconFacts.emit(world, "ECON_PROJECT_CANCELLED", pr["district"], [["GOVERNMENT", "government"]], [["GOVERNMENT", "government", 1.0]],
				{"GOVERNANCE": -5}, 30, "PUBLIC", {"project": pr["id"]})
			return true
		"ECON_SUBSIDIZE":
			var oid: String = p["org"]
			var amt := int(p["amount"]) * S
			if headroom(world, "ECON_BUDGET_SUBSIDIES") < amt:
				return false
			var paid := EconFinance.gov_pay(world, EconUtil.acct(oid), amt, "SUBSIDY")
			EconFinance._spend_line(world, "ECON_BUDGET_SUBSIDIES", paid)
			EconFinance.pl_add(world, oid, "subsidy", paid)
			EconFacts.emit(world, "ECON_SUBSIDY_GRANTED", world.table("org")[oid]["hq"], [["GOVERNMENT", "government"], ["COMPANY", oid]],
				[["GOVERNMENT", "government", 1.0]], {"JOBS": 2}, 20, "PUBLIC", {"amount": paid})
			return true
		"ECON_BUY_FACILITY":
			var f: Dictionary = world.table("facility").get(p["facility"], {})
			if f.is_empty():
				return false
			var seller: Dictionary = world.table("org")[f["org"]]
			var price := int(f["book"] * (EconData.GOV_FIRST_PURCHASE if seller["status"] in ["LIQUIDATION", "DISSOLVED"] else 1.0))
			var paid := EconFinance.gov_pay(world, EconUtil.acct(f["org"]), price, "ASSET_PURCHASE")
			EconFinance._spend_line(world, "ECON_BUDGET_INFRASTRUCTURE", paid)
			var op: String = EconEssentials.operator_for(world, f["type"])
			f["org"] = op
			f["abandoned"] = false
			f["mothball"] = false
			EconFacts.emit(world, "ECON_FACILITY_SOLD", f["district"], [["GOVERNMENT", "government"]], [["GOVERNMENT", "government", 1.0]],
				{"JOBS": 5}, 30, "PUBLIC", {"facility": f["id"], "price": paid})
			return true
		"ECON_ORDER_IMPORTS":
			var good: String = p["good"]
			var qty := int(p["qty"]) * S
			var unit := int(EconData.BASE_PRICE[good] * EconData.IMPORT_MULT * pow(1.01, world.year() - 1)) * S
			var cost := EconUtil.val(qty, unit)
			if headroom(world, "ECON_BUDGET_RESERVE_PURCHASES") < cost:
				return false
			var paid := EconFinance.gov_pay(world, Ledger.EXTERNAL, cost, "IMPORT")
			EconFinance._spend_line(world, "ECON_BUDGET_RESERVE_PURCHASES", paid)
			var arrival := world.month + 3
			while (arrival + 1) % 3 != 0:
				arrival += 1
			EconUtil.st(world)["import_orders"].append({"holder": "gov", "good": good, "qty": int(float(paid) * S / float(unit)), "unit_cost": unit, "arrival": arrival})
			return true
		"ECON_RELEASE_RESERVE":
			var good: String = p["good"]
			var qty := mini(int(p["qty"]) * S, EconUtil.inv_get(world, "gov", good, "d:1"))
			var s := EconUtil.st(world)
			var price: int = maxi(int(p.get("price", 0)) * S, s["prices"][good] / 2) if p.get("price", 0) > 0 else s["prices"][good]
			if qty <= 0:
				return false
			s["offers"].append({"seller": "gov", "acct": EconUtil.TREASURY, "district": "d:1", "good": good, "qty": qty, "ask": price})
			EconFacts.emit(world, "ECON_RESERVE_RELEASED", "d:1", [["GOVERNMENT", "government"]], [["GOVERNMENT", "government", 1.0]],
				{"COST_OF_LIVING": 3}, 15, "PUBLIC", {"good": good, "qty": qty / S})
			return true
		"ECON_BORROW":
			return EconFinance.gov_borrow(world, int(p["amount"]) * S) > 0
		"ECON_REPAY_DEBT":
			var amt := mini(int(p["amount"]) * S, world.ledger.balance(EconUtil.TREASURY))
			for lid in EconUtil.sorted_keys(world.table("loan")):
				var l: Dictionary = world.table("loan")[lid]
				if l["borrower"] == "gov" and amt > 0:
					var pay := mini(amt, l["principal"])
					world.ledger.transfer(EconUtil.TREASURY, EconUtil.BANK, pay, "LOAN_SERVICE", world.month)
					l["principal"] -= pay
					amt -= pay
			return true
	return false

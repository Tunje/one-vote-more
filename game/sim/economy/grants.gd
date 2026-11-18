extends RefCounted
## The four grants (rebuild step 3; plan 9.5, 9.12, 8.1, 12.9 points 60 to 61a; joins: planning/rebuild-step3-joins.md).
## Owner: Ella. Preload it (no class_name): const Grants := preload("res://sim/economy/grants.gd").
##
## "I DID NOT SAY GIVE EVERYONE ... GRANTS": grants exist only for family farms, family bakeries, truck drivers and truck
## workshops ("No split trucks and workshops"), and all four are open from month one ("JUST ALL FUCKING GRANTS").
##
## A grant is a time-limited programme (the user, 2026-11-14: "when a grant ends, they reset to zero so they have to
## start over on where to put it; grants should be limited time for when you can apply"; plan 12.9, 61a). A grant lever
## above 0 opens an application window of PROGRAMME_M months; changing the level inside it does not extend it. When the
## window ends the lever goes to 0 by the law's "programme ended" enactment and a public fact says what the programme
## paid and refused. A new programme is a new decision of the government's. PROGRAMME_M is a START number of ours.
##
## Where a grant can be had: the districts the government chose for the programme (GovBuilder.grant_cover, politics'
## own memory). A kind not chosen yet pays nothing. The government chooses from the need this file publishes: the work a
## founder of that kind would see, by district (rule 7's signal, 15a).
##
## The money: a grant is the lever's per cent of what a founder must bring for the plant (Building.founder_needs). It
## is paid from the treasury into the plan's own account (60) right after the plan is made and before it signs with a
## builder (joins, COMPANY_AI 2), with memo "GRANT:<kind>". A treasury that cannot pay the whole grant pays none (a
## half grant would leave a plan short that was planned on the whole). One grant per household (61): the household is
## the founder's own, counted individually from the day the plan is made (60a), so the key is the founder's id
## ("founder:N") and the founder's "had_grant", not the pool, which holds a whole block's band of households (Anni's
## review). A founder who goes back into the pool (60c) takes its grant with it as one of the pool's granted households,
## and a household drawn from those comes back with "had_grant" (Maja's pick_founder), so it cannot take a second grant.
## A plan given up owes its grant back (60b): from the plan's account what it can, then from the founder's own money,
## and only what neither reaches is a debt of the founder's to the government that goes to court like any other.
##
## The programme's sum (the user, 2026-11-17, plan 12.9, 61b: "The government should put a max sum into the grant based
## on how many farms they want maybe a little extra to be sure"). When a programme opens the government decides how
## many plants of the kind it wants (wanted(): the starting count) and gives the programme a sum: that many grants and a
## tenth more (budget_for; GovBuilder keeps it in politics' memory, GovBuilder.grant_sum). Each grant paid comes out of
## it; when what is left is less than a grant, quote says 0 and apply refuses. The sum is a limit on what the treasury
## pays out for the programme, not money set aside: nothing moves when it is set or when the programme ends. It limits
## the grant only: a founder who can pay without a grant is not stopped by it.
##
## Every decision and deed writes a Logbook row of kind GRANT.

const Company := preload("res://sim/economy/company.gd")
const LawOps := preload("res://sim/law/law_ops.gd")
const Justice := preload("res://sim/law/justice_ops.gd")
const LawQuery := preload("res://sim/law/law_query.gd")
const Households := preload("res://sim/population/households.gd")
const TypeTable := preload("res://sim/economy/type_table.gd")

const TABLE := "grant"             # one row per grant paid: keyed by plan id
const STATE := "grant_prog"        # this file's own state: the programmes, the need (one table, one row "s")
const PROGRAMME_M := 24            # START: months a programme stays open for applications
const EXTRA_PM := 100              # START (Wilma's): "a little extra to be sure", a tenth on top of the grants wanted
const S := CoreUtil.S

## kind -> [lever, company type, size]. Every grant is for a family-size company: one household runs it (plan 5).
const KINDS := {
	"FARM": ["ECON_FAMILY_FARM_GRANT", "FARM", "FAMILY"],
	"BAKERY": ["ECON_FAMILY_BAKERY_GRANT", "BAKERY", "FAMILY"],
	"TRUCKER": ["ECON_TRUCK_DRIVER_GRANT", "HAULIER", "FAMILY"],
	"TRUCKSHOP": ["ECON_TRUCK_WORKSHOP_GRANT", "TRUCKSHOP", "FAMILY"],
}

## What a founder must bring for a plant: Otto's Building.founder_needs(world, type, size, area) -> credits x S. Set by
## the conductor when Otto's piece is in; tests set their own. Unset, a grant quotes 0.
static var needs_fn: Callable = Callable()


static func lever_of(kind: String) -> String:
	return String(KINDS.get(kind, ["", "", ""])[0])


## The grant kind for a company type and size, or "" when none exists.
static func kind_of(type: String, size: String) -> String:
	for k in KINDS:
		if String(KINDS[k][1]) == type and String(KINDS[k][2]) == size:
			return String(k)
	return ""


static func _st(world: WorldState) -> Dictionary:
	var t := world.table(STATE)
	if not t.has("s"):
		t["s"] = {"progs": {}, "need": {}, "seen": {}}
	return t["s"]


static func _peek_st(world: WorldState) -> Dictionary:
	return world.peek(STATE).get("s", {})


## The district an area lies in; a grant is covered by district. An area no district has been drawn over yet (month
## one has the Landing and no districts: 12.1, 2) stands for itself, so the government can still choose it.
static func _district(world: WorldState, area: String) -> String:
	var d := LawQuery.district_of(world, area)
	return d if d != "" else area


## Why a grant of this kind cannot be had in this area now ("" when it can). A founder who already had a grant is
## checked with `founder` ("" skips that check: a quote is asked before the founder is picked).
## A cover entry may name the area's district or, chosen while no district was drawn over it (month one), the area
## itself; both count, so drawing a district later does not silently empty a programme (Anni's review).
static func _refusal(world: WorldState, kind: String, area: String, founder: String) -> String:
	if not KINDS.has(kind):
		return "no such grant"
	if int(world.levers.get(lever_of(kind), 0)) <= 0:
		return "no programme open"
	var cover: Array = GovBuilder.grant_cover(world).get(kind, [])
	if not (_district(world, area) in cover) and not (area in cover):
		return "not in a district the programme covers"
	if founder != "" and had(world, founder):
		return "this household has had a grant"
	return ""


## Has this founder's household had a grant? (61: one per household.) Households are counts in pools, so the memory is
## kept there (Maja): a founder drawn from a pool's granted households carries "had_grant" on its record, and a paid
## grant is marked on the founder (Households.mark_granted, called from apply) and goes back to the pool with it.
## This file's own grants by founder id are checked too.
static func had(world: WorldState, founder: String) -> bool:
	if bool(world.peek("founder").get(founder, {}).get("had_grant", false)):
		return true
	for pid in world.peek(TABLE):
		if String(world.peek(TABLE)[pid]["founder"]) == founder:
			return true
	return false


## The grant's amount for a sum a founder must bring: the lever's per cent of it.
static func amount_for(world: WorldState, kind: String, needed: int) -> int:
	return int(round(float(maxi(0, needed)) * float(int(world.levers.get(lever_of(kind), 0))) / 100.0))


## What a grant of `kind` would pay a founder from `pool` in `area` this month, credits x S; 0 when none can be had.
## Read-only. Called by the founding sequence before the founder is picked (joins, COMPANY_AI 2), so it cannot know
## whether that founder had a grant before; apply checks that. `pool` is kept for the joins' signature.
static func quote(world: WorldState, kind: String, area: String, _pool: String) -> int:
	if _refusal(world, kind, area, "") != "" or not needs_fn.is_valid():
		return 0
	var k: Array = KINDS[kind]
	var amount := amount_for(world, kind, int(needs_fn.call(world, String(k[1]), String(k[2]), area)))
	# a grant the treasury cannot pay, or the programme's sum no longer holds, is refused by apply; quoting it would
	# let a household be picked that can only pay with it, and its plan would start short (Ella's review of the
	# founding sequence, ruled by Wilma)
	if world.ledger.balance(CoreUtil.TREASURY) < amount or sum_left(world, kind) < amount:
		return 0
	return amount


## A plan as this file reads it: {id, founder (person id), pool (the household the founder came from), type, size,
## area, account}. From Otto's plan record (table "plan") and Maja's founder record (table "founder", ids "founder:N",
## field "pool"; read through Households.person once her piece is in).
## The one place that knows their field names.
static func plan_of(world: WorldState, plan_id: String) -> Dictionary:
	var p: Dictionary = world.peek("plan").get(plan_id, {})
	if p.is_empty():
		return {}
	var founder := String(p.get("founder", ""))
	return {"id": plan_id, "founder": founder, "pool": String(world.peek("founder").get(founder, {}).get("pool", "")),
		"type": String(p.get("type", "")), "size": String(p.get("size", "")), "area": String(p.get("area", "")),
		"account": String(p.get("account", plan_id))}


## Pays the grant for a plan just made: from the treasury into the plan's account, all or nothing. -> {ok, amount, why}.
static func apply(world: WorldState, plan_id: String) -> Dictionary:
	var plan := plan_of(world, plan_id)
	if plan.is_empty():
		return {"ok": false, "amount": 0, "why": "no such plan"}
	var pid := plan_id
	var kind := kind_of(String(plan.get("type", "")), String(plan.get("size", "")))
	var why := {"kind": kind, "area": String(plan.get("area", "")), "pool": String(plan.get("pool", ""))}
	if kind == "":
		return {"ok": false, "amount": 0, "why": "no grant for this type and size"}   # no row: not a grant decision
	if world.peek(TABLE).has(pid):
		return {"ok": false, "amount": 0, "why": "this plan has its grant"}
	var no := _refusal(world, kind, String(plan.get("area", "")), String(plan.get("founder", "")))
	var needed := int(needs_fn.call(world, String(plan["type"]), String(plan["size"]), String(plan["area"]))) if needs_fn.is_valid() else 0
	var amount := amount_for(world, kind, needed)
	why["level_pct"] = int(world.levers.get(lever_of(kind), 0))
	why["needs"] = needed / S
	if no == "" and amount <= 0:
		no = "nothing to pay"
	if no == "":
		var left := sum_left(world, kind)
		if left < 0:
			no = "the programme has no sum"
		elif left < amount:
			no = "what is left of the programme's sum is less than a grant"
			why["sum_left"] = left / S
	if no == "" and world.ledger.balance(CoreUtil.TREASURY) < amount:
		no = "the treasury cannot pay it"
		why["treasury"] = world.ledger.balance(CoreUtil.TREASURY) / S
	if no != "":
		_count(world, kind, "refused")
		Logbook.note(world, "GRANT", String(plan.get("founder", "")), "grant refused", why.merged({"reason": no}), {}, "gov", pid)
		return {"ok": false, "amount": 0, "why": no}
	world.ledger.transfer(CoreUtil.TREASURY, String(plan["account"]), amount, "GRANT:" + kind, world.month)
	world.table(TABLE)[pid] = {"plan": pid, "kind": kind, "founder": String(plan.get("founder", "")),
		"pool": String(plan.get("pool", "")), "area": String(plan.get("area", "")), "amount": amount, "month": world.month,
		"status": "PAID", "repaid": 0}
	_count(world, kind, "paid")
	Logbook.note(world, "GRANT", String(plan.get("founder", "")), "grant paid", why, {"plan money": [0, amount / S]}, "gov", pid)
	if String(plan.get("founder", "")) != "":
		Households.mark_granted(world, String(plan["founder"]))   # one grant per household (61), kept when it goes back (Maja)
	return {"ok": true, "amount": amount, "why": ""}


static func _count(world: WorldState, kind: String, what: String) -> void:
	var progs: Dictionary = _st(world)["progs"]
	if progs.has(kind):
		progs[kind][what] = int(progs[kind][what]) + 1


## A plan given up owes its grant back (60b). From the plan's account what it holds, up to the grant, back to the
## treasury; then from the founder's own account (Wilma, 2026-11-17: the founder's own money comes before any debt);
## the founder owes the rest to the government, carried on the founder's id (60c). Returns what was paid back now.
## Call it while the plan's account still holds the plan's money.
static func reclaim(world: WorldState, plan_id: String) -> int:
	var g: Dictionary = world.peek(TABLE).get(plan_id, {})
	if g.is_empty() or String(g["status"]) != "PAID":
		return 0
	var plan := plan_of(world, plan_id)
	var plan_account := String(plan.get("account", plan_id))
	var founder := String(g["founder"])
	var due := int(g["amount"])
	var memo := "GRANT_BACK:" + String(g["kind"])
	var from_plan := CoreUtil.pay_upto(world, plan_account, CoreUtil.TREASURY, due, memo)
	# then the founder's own money (Wilma, 2026-11-17: the founder's own money comes before any debt; 60b)
	var from_founder := 0
	if due - from_plan > 0 and world.ledger.has_account(founder):
		from_founder = CoreUtil.pay_upto(world, founder, CoreUtil.TREASURY, due - from_plan, memo)
	var back := from_plan + from_founder
	var owed := due - back
	if owed > 0:   # what neither reaches stays on the founder, a debt the court collects (60b, 60c: carried)
		Justice.owe(world, founder, "gov", CoreUtil.TREASURY, owed, "GRANT")
	world.table(TABLE)[plan_id]["status"] = "REPAID" if owed == 0 else "OWED"
	world.table(TABLE)[plan_id]["repaid"] = back
	Logbook.note(world, "GRANT", founder, "grant owed back", {"kind": String(g["kind"]), "grant": due / S},
		{"from the plan": [0, from_plan / S], "from the founder": [0, from_founder / S], "owed": [0, owed / S]}, "gov", plan_id)
	return back


## How many MORE plants of `kind` the government wants a programme to found (Wilma, 2026-11-17: "how many farms they
## want" is how many more): its starting count (ours, Wilma's for the farm). -> {wanted, rule, and what the rule read}.
##   FARM: what feeds the colony at full output (the persons who buy food x one FOOD a month each), less what the farms
##         that stand and the plans made or signed would grow at full use (the government sees a plan: it sold it the
##         land), over a family farm's output a month at full use (TypeTable.output_milli), rounded up, never below 0.
##         A farm larger than a family farm counts for what it grows.
##   BAKERY: the same with bread (one BREAD is one person's food for a month, baked): enough bread for everyone. It
##         counts the whole food need, as if all ate bread, though a bakery bakes from the farms' FOOD.
##   TRUCKER, TRUCKSHOP: one in each area that has none standing or planned.
static func wanted(world: WorldState, kind: String) -> Dictionary:
	var k: Array = KINDS[kind]
	var type := String(k[1])
	if kind == "FARM" or kind == "BAKERY":
		var persons := 0
		for b in Households.buyers(world):
			persons += int(b["persons"])
		var out := TypeTable.output_milli(type, String(k[2]))
		var need := persons * int(Households.NEED_PER_PERSON["FOOD"])
		var good := TypeTable.out_of(type, 0)
		var have := _standing_and_planned(world, type, "", good)
		var short := maxi(0, need - int(have["output_milli"]))
		return {"wanted": (short + out - 1) / out if out > 0 else 0, "to_feed": (need + out - 1) / out if out > 0 else 0,
			"standing": int(have["standing"]), "planned": int(have["planned"]), "their_output_milli": int(have["output_milli"]),
			"persons": persons, "output_milli": out,
			"rule": "the persons who buy food, less what the %ss standing and planned make, over a family %s's output at full use" % [type.to_lower(), type.to_lower()]}
	var none := 0
	var standing := 0
	var planned := 0
	for ar in AreaStore.areas(world):
		var have := _standing_and_planned(world, type, String(ar["id"]), "")
		standing += int(have["standing"])
		planned += int(have["planned"])
		if int(have["standing"]) + int(have["planned"]) == 0:
			none += 1
	return {"wanted": none, "areas": AreaStore.areas(world).size(), "standing": standing, "planned": planned,
		"rule": "one in each area that has none standing or planned"}


## The plants of `type` that stand (not closed) and the plans of it made or signed, in `area` ("" = everywhere), and
## what they make of `good` a month at full use ("" = not counted): {standing, planned, output_milli}.
static func _standing_and_planned(world: WorldState, type: String, area: String, good: String) -> Dictionary:
	var out := {"standing": 0, "planned": 0, "output_milli": 0}
	for pid in Company.plant_ids(world):
		var p: Dictionary = Company.plant(world, String(pid))
		if String(p["type"]) != type or bool(p["closed"]):
			continue
		if area != "" and String(Company.record(world, String(p["company"])).get("area", "")) != area:
			continue
		out["standing"] += 1
		if good != "" and TypeTable.out_of(type, int(p["line"])) == good:
			out["output_milli"] += TypeTable.output_milli(type, String(p["size"]), int(p["line"]))
	for id in CoreUtil.sorted_keys(world.peek("plan")):
		var pl: Dictionary = world.peek("plan")[id]
		if String(pl.get("type", "")) != type or not (String(pl.get("status", "")) in ["MADE", "SIGNED"]):
			continue
		if area != "" and String(pl.get("area", "")) != area:
			continue
		out["planned"] += 1
		if good != "":
			out["output_milli"] += TypeTable.output_milli(type, String(pl["size"]))
	return out


## The grant the programme is planned on: the largest of the areas' grants this month (what a founder must bring
## differs by area), so the sum holds `wanted` grants wherever they are paid.
static func grant_planned(world: WorldState, kind: String) -> int:
	if not needs_fn.is_valid():
		return 0
	var k: Array = KINDS[kind]
	var most := 0
	for ar in AreaStore.areas(world):
		most = maxi(most, amount_for(world, kind, int(needs_fn.call(world, String(k[1]), String(k[2]), String(ar["id"])))))
	return most


## The sum for a programme of `kind` opened now: {kind, wanted, rule, ..., grant, extra, sum}, credits x S. Read-only;
## the government decides it (GovBuilder._grant_sum) and logs it.
static func budget_for(world: WorldState, kind: String) -> Dictionary:
	var b := wanted(world, kind)
	var g := grant_planned(world, kind)
	var grants := int(b["wanted"]) * g
	var extra := grants * EXTRA_PM / 1000
	b.merge({"kind": kind, "grant": g, "extra": extra, "sum": grants + extra})
	return b


## What is left of the open programme's sum: the sum less every grant of the kind paid since the government set it,
## plus what came back from plans given up (Wilma, 2026-11-17: the government wanted a farm and did not get it). A grant
## still owed by its founder refills nothing until it is paid; the law collects a person's debt from step 5 (12.8), and
## that step must add what it collects of a GRANT debt here.
## -1 when the government has set no sum (no programme open, or not decided yet).
static func sum_left(world: WorldState, kind: String) -> int:
	var b: Dictionary = GovBuilder.grant_sum(world).get(kind, {})
	if b.is_empty():
		return -1
	var spent := 0
	for pid in world.peek(TABLE):
		var g: Dictionary = world.peek(TABLE)[pid]
		if String(g["kind"]) == kind and int(g["month"]) >= int(b["start"]):
			spent += int(g["amount"]) - int(g.get("repaid", 0))
	return int(b["sum"]) - spent


## The plans that have accepted a grant and have neither opened nor been given up: {plan id: true}. Rule 7 reads them
## (the user, 2026-11-17, plan 12.3, 15a: "It does not see plans made, but they do see plans booked on builders notes
## and plans that have accepted grants"; Bob's Rules.founding). A grant row still PAID whose plan is MADE or SIGNED; a
## plan that has opened is a plant by then, and one given up has its row REPAID or OWED. Pure: writes nothing.
static func granted_plans(world: WorldState) -> Dictionary:
	var out := {}
	for pid in CoreUtil.sorted_keys(world.peek(TABLE)):
		if String(world.peek(TABLE)[pid]["status"]) != "PAID":
			continue
		if String(world.peek("plan").get(pid, {}).get("status", "")) in ["MADE", "SIGNED"]:
			out[pid] = true
	return out


## The month (COMPANY_AI, last): open and close programmes, then publish the need the government reads.
## need_fn: (world, type, size, area) -> the work a founder of that kind would see in that area, credits x S a month
## (rule 7's signal, Bob's Rules). Unset, the need is 0 everywhere.
static var need_fn: Callable = Callable()


static func monthly(world: WorldState) -> void:
	var st := _st(world)
	var progs: Dictionary = st["progs"]
	var seen: Dictionary = st["seen"]
	for kind in CoreUtil.sorted_keys(KINDS):
		var lid := lever_of(kind)
		var lv := int(world.levers.get(lid, 0))
		if progs.has(kind):
			var pr: Dictionary = progs[kind]
			pr["level"] = maxi(int(pr["level"]), lv)
			if lv <= 0:
				_closed(world, kind, pr, "the government closed it")
				progs.erase(kind)
			elif world.month >= int(pr["until"]):
				_end_programme(world, kind, pr)
				progs.erase(kind)
		elif lv > 0:
			progs[kind] = {"start": world.month, "until": world.month + PROGRAMME_M, "level": lv, "paid": 0, "refused": 0}
			Logbook.note(world, "GRANT", "gov", "programme opened", {"kind": kind, "level_pct": lv, "months": PROGRAMME_M,
				"until": world.month + PROGRAMME_M}, {}, "", lid)
		seen[kind] = lv
	_publish_need(world)


## The window has run out: the lever goes to 0 by the law ("programme ended"), in force at once, and the public fact.
static func _end_programme(world: WorldState, kind: String, pr: Dictionary) -> void:
	LawOps.end_programme(world, lever_of(kind), "its %d months ran out" % PROGRAMME_M)   # a sunset: no new vote (Anni)
	_closed(world, kind, pr, "its time ran out")


## The fact politics reads (GovBuilder._programme_ended: data.lever, level, paid) and the log row.
static func _closed(world: WorldState, kind: String, pr: Dictionary, how: String) -> void:
	var lid := lever_of(kind)
	var data := {"lever": lid, "kind": kind, "start": int(pr["start"]), "months": world.month - int(pr["start"]),
		"level": int(pr["level"]), "paid": int(pr["paid"]), "refused": int(pr["refused"]), "how": how}
	world.add_fact({"type": "ECON_GRANT_PROGRAMME_ENDED", "owner": "econ", "subjects": [],
		"responsible": [{"actor": {"kind": "GOVERNMENT", "id": "government"}, "share": 1.0}], "impact": {}, "magnitude": 20,
		"visibility": "PUBLIC", "data": data})
	Logbook.note(world, "GRANT", "gov", "programme ended", data, {lid: [int(pr["level"]), 0]}, "", lid)


## {kind: {district: need}}: the work a founder of each grant's kind would see, summed over the areas of a district.
static func _publish_need(world: WorldState) -> void:
	var out := {}
	for kind in CoreUtil.sorted_keys(KINDS):
		var by_d := {}
		if need_fn.is_valid():
			for ar in AreaStore.areas(world):
				var a := String(ar["id"])
				var d := _district(world, a)
				if d == "":
					continue
				var k: Array = KINDS[kind]
				by_d[d] = int(by_d.get(d, 0)) + maxi(0, int(need_fn.call(world, String(k[1]), String(k[2]), a)))
		out[kind] = by_d
	_st(world)["need"] = out


## What the economy publishes for politics (EconFace.grant_need): {kind: {district: need}}; {} before the first month.
static func need(world: WorldState) -> Dictionary:
	return (_peek_st(world).get("need", {}) as Dictionary).duplicate(true)


## {grant lever: 1000 where some district has need for it, else 0} (EconFace.lever_need, read by the legislature).
static func lever_need(world: WorldState) -> Dictionary:
	var out := {}
	var n := need(world)
	for kind in CoreUtil.sorted_keys(KINDS):
		var any := false
		for d in n.get(kind, {}):
			if int(n[kind][d]) > 0:
				any = true
		out[lever_of(kind)] = 1000 if any else 0
	return out

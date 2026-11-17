extends TestCase
## R8FR_QUEUE (Bob, opt-in, with R8FR_PRIVATE): freight that could not be moved waits in a queue and goes first next
## month; CTA's depots set their crew on the month's whole queue, not on what CTA carried before (the user, 2026-11-17).
## OFFICE_E99 (Bob, opt-in): the office of an essential plant hires first like the plant (the user: yes).

const EconHaulier := preload("res://sim/economy/econ_haulier.gd")
const S := EconUtil.S
const FR := ["R8FR_MARKET", "R8FR_PRIVATE"]


func _sim(extra: Array, months: int) -> Simulation:
	var sim := EconSim.make_econ_only(3)
	var on: Array = EconSim.DEFAULT_ON.duplicate()
	on.append_array(extra)
	sim.world.meta["on"] = on
	sim.run(months)
	return sim


func _private_orgs(w: WorldState, n: int) -> Array:
	var out := []
	for oid in EconUtil.sorted_keys(w.table("org")):
		var o: Dictionary = w.table("org")[oid]
		if o["status"] == "ACTIVE" and o.get("key", "") != "CTA":
			out.append(oid)
			if out.size() >= n:
				break
	return out


## One seller in d:1, two firm buyers in d:2 (A bids higher, so A goes first without a queue), freight room for
## exactly one of the two orders. `queued_b`: B's order waited since last month. Returns [A got, B got, queue now].
func _two_buyers(queued_b: bool) -> Array:
	var sim := _sim(FR + ["R8FR_QUEUE"], 3)
	var w := sim.world
	var s := EconUtil.st(w)
	var good := "FURNISHINGS"
	var o3 := _private_orgs(w, 3)
	check(o3.size() == 3, "three organisations")
	if o3.size() < 3:
		return [-1, -1, {}, -1, 0, "", ""]
	var seller: String = o3[0]
	var a: String = o3[1]
	var b: String = o3[2]
	var h := EconUtil.hops("d:1", "d:2")
	check(h > 0, "d:1 to d:2 needs freight")
	for oid in [a, b]:
		w.ledger.transfer(Ledger.EXTERNAL, EconUtil.acct(oid), 1000000 * S, "TEST", w.month)
	EconUtil.inv_add(w, seller, good, "d:1", 10 * S, S)
	var cta := EconFinance.org_by_key(w, "CTA")
	s["offers"] = [{"seller": seller, "acct": EconUtil.acct(seller), "district": "d:1", "good": good, "qty": 10 * S, "ask": 1}]
	var px := int(s["prices"][good])
	s["orders"] = [
		{"buyer": a, "acct": EconUtil.acct(a), "district": "d:2", "good": good, "qty": 5 * S, "limit": px * 10, "class": EconMarket.C_FIRM, "kind": "org"},
		{"buyer": b, "acct": EconUtil.acct(b), "district": "d:2", "good": good, "qty": 5 * S, "limit": px * 2, "class": EconMarket.C_FIRM, "kind": "org"}]
	s["fr_carriers"] = [{"org": cta, "rate": 0, "room": 5 * S * h, "cta": true}]
	s["fr_carried"] = {}
	s["fr_queue"] = {b + "|" + good + "|d:2": 5 * S} if queued_b else {}
	s["fr_queue_new"] = {}
	s["fr_wait_mu"] = 0
	s["input_short"] = {}
	s["market_stats"] = {}
	var a0 := EconUtil.inv_get(w, a, good, "d:2")
	var b0 := EconUtil.inv_get(w, b, good, "d:2")
	EconMarket._clear(w, good, 0)
	return [EconUtil.inv_get(w, a, good, "d:2") - a0, EconUtil.inv_get(w, b, good, "d:2") - b0, s["fr_queue_new"], int(s["fr_wait_mu"]), h, a, b]


func test_off_touches_nothing() -> void:
	var sim := _sim(FR, 6)
	var s := EconUtil.st(sim.world)
	check(not s.has("fr_queue") and not s.has("fr_queue_new") and not s.has("fr_wait_mu"), "no queue state without R8FR_QUEUE")


func test_needs_the_private_carriers() -> void:
	var sim := _sim(["R8FR_QUEUE"], 2)
	check(not EconUtil.st(sim.world).has("fr_queue"), "without R8FR_PRIVATE there is no carrier to queue for: off")


func test_without_a_queue_the_higher_bid_goes_first() -> void:
	var r := _two_buyers(false)
	check(r[0] == 5 * S, "A (higher limit) carried: %d" % r[0])
	check(r[1] == 0, "B left: %d" % r[1])
	check(int((r[2] as Dictionary).get(String(r[6]) + "|FURNISHINGS|d:2", 0)) == 5 * S, "B's order waits in the queue for next month")
	check(r[3] == 5 * S * int(r[4]), "the waiting freight in mu (goods × hops): %d" % r[3])


func test_the_waiting_order_goes_first() -> void:
	var r := _two_buyers(true)
	check(r[1] == 5 * S, "B waited since last month and is carried first: %d" % r[1])
	check(r[0] == 0, "A's new order waits: %d" % r[0])
	check(int((r[2] as Dictionary).get(String(r[5]) + "|FURNISHINGS|d:2", 0)) == 5 * S, "A now waits in the queue")


func test_the_depot_counts_the_whole_queue() -> void:
	var sim := _sim(FR + ["R8FR_QUEUE"], 3)
	var w := sim.world
	var s := EconUtil.st(w)
	var cta := EconFinance.org_by_key(w, "CTA")
	var dep := {}
	for fid in EconUtil.sorted_keys(w.table("facility")):
		var f: Dictionary = w.table("facility")[fid]
		if f["type"] == "DEPOT" and f["org"] == cta and not f["mothball"]:
			dep = f
			break
	check(not dep.is_empty(), "CTA has a depot")
	var full := EconHaulier.full_of(w, cta)
	s["fr_last"] = {"carried": {cta: full / 10, "org:other": full / 5}, "deferred": 0}
	s["fr_wait_mu"] = full / 4
	s["fr_room_by"] = {cta: full, "org:other": full / 10}
	var want := float(full / 10 + full / 5 + full / 4 - full / 10) / float(full)  # carried by all + waiting − the others' room
	check(absf(EconHaulier.depot_target(w, dep) - want) < 0.001, "queue rule: %.3f want %.3f" % [EconHaulier.depot_target(w, dep), want])
	(w.meta["on"] as Array).erase("R8FR_QUEUE")
	var old := float(full / 10) / float(full)  # what CTA carried + deferred (0)
	check(absf(EconHaulier.depot_target(w, dep) - maxf(0.2, old)) < 0.001, "old rule unchanged: %.3f" % EconHaulier.depot_target(w, dep))


func test_the_office_of_an_essential_plant_hires_first() -> void:
	var sim := _sim([], 3)
	var w := sim.world
	var cta := EconFinance.org_by_key(w, "CTA")
	var off := EconOffice.office_of(w, cta)
	check(off != "", "CTA has an office (support economy A)")
	var v := {"emp": off, "kind": "fac", "tier": "G", "org": cta}
	check(not EconLabor._strategic_vac(w, v, EconLabor._essential_offices(w)), "off: an office is not essential")
	(w.meta["on"] as Array).append("OFFICE_E99")
	check(EconLabor._strategic_vac(w, v, EconLabor._essential_offices(w)), "OFFICE_E99: the office of CTA's depots is essential")
	var plain := ""
	for oid in EconUtil.sorted_keys(w.table("org")):
		var o2 := EconOffice.office_of(w, oid)
		if o2 == "" or EconLabor._essential_offices(w).has(oid):
			continue
		plain = oid
		check(not EconLabor._strategic_vac(w, {"emp": o2, "kind": "fac", "tier": "G", "org": oid}, EconLabor._essential_offices(w)),
			"an office without an essential plant stays behind")
		break
	check(plain != "", "found an office without an essential plant")

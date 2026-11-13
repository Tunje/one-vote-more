extends TestCase
## §8b step 1 (EconComfort): households spend a share of their surplus above essentials on comfort services, out of
## their services budget; district comfort businesses staff up from that revenue (opt-in "SUPPORT_S").


func test_off_by_default() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.run(3)
	check(EconComfort.summary(sim.world).is_empty(), "no comfort businesses unless SUPPORT_S is on")


func test_comfort_spending_creates_jobs() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.world.meta["on"] = ["SUPPORT_S"]
	sim.run(8)
	var w := sim.world
	var sm := EconComfort.summary(w)
	check(not sm.is_empty(), "comfort businesses opened (%s)" % [sm])
	var posts := 0
	var rev := 0
	for d in sm:
		posts += int(sm[d]["posts"])
		rev += int(sm[d]["revenue_ema"])
	check(rev > 0, "households spend on comfort (%d)" % rev)
	check(posts > 0, "comfort businesses employ staff (%d)" % posts)
	var richer := 0
	var poorer := 0
	for gid in w.table("hh"):
		var g: Dictionary = w.table("hh")[gid]
		if g["band"] == "I5":
			richer += int(g.get("comfort_spent", 0))
		elif g["band"] == "I1":
			poorer += int(g.get("comfort_spent", 0))
	check(richer >= poorer, "richer bands spend more on comfort (I5 %d vs I1 %d)" % [richer / 1000, poorer / 1000])
	check(EconPop.check(w).is_empty(), "jobs still equal people: %s" % [EconPop.check(w)])
	check_eq(w.ledger.total(), 0, "ledger closed")
	check(EconReport.goods_errors(w).is_empty(), "goods conserved: %s" % [EconReport.goods_errors(w)])

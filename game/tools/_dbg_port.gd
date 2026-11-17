extends SceneTree
## Bob (export levers): is the port store the binding limit on exports? Monthly over N years: port capacity, held, per
## good share cap hits, consign attempts blocked by space, and on ship arrivals the cargo vs hold. args: seed years
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sim: Simulation = EconSim.make(int(a[0]), "BALANCED", {}, true)
	var w := sim.world
	var full_m := 0
	var good_cap_m := 0
	var ships := 0
	var cargo_tot := 0
	var hold_full := 0
	var last_next := -1
	for m in int(a[1]) * 12:
		sim.run(1)
		var cap := EconTrade.port_capacity(w) * 1000
		var held := 0
		var per := {}
		for oid in w.peek("org"):
			for g in EconTrade.EXPORT_GOODS:
				var q := EconUtil.inv_get(w, oid, g, EconTrade.PORT)
				held += q
				per[g] = int(per.get(g, 0)) + q
		if held * 100 >= cap * 95:
			full_m += 1
		for g in per:
			if int(per[g]) * 100 >= int(float(cap) * EconTrade.PORT_GOOD_SHARE) * 95:
				good_cap_m += 1
				break
		var s := EconUtil.st(w)
		if int(s.get("ship_next", -1)) != last_next and last_next != -1:
			ships += 1
			var ls: Dictionary = EconTrade.last_ship(w)
			var c := 0
			for g in ls.get("cargo", {}):
				c += int(ls["cargo"][g])
			cargo_tot += c
			if c * 100 >= EconTrade.ship_hold(w) * 95:
				hold_full += 1
		last_next = int(s.get("ship_next", -1))
		if (m + 1) % 120 == 0:
			print("Y%d port cap %d held %d | months port ≥95%% full %d, a good at its 40%% cap %d | ships %d, avg cargo %d (hold %d), holds full %d" % [(m + 1) / 12,
				cap / 1000, held / 1000, full_m, good_cap_m, ships, cargo_tot / maxi(1, ships), EconTrade.ship_hold(w), hold_full])
	quit()

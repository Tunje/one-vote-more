extends SceneTree
## temp (Bob, Wilma's demand question): where household income goes, by income band, per year. args: seed from to
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sim: Simulation = EconSim.make(int(a[0]), "BALANCED", {}, true)
	var w := sim.world
	sim.run(int(a[1]) * 12)
	for y in range(int(a[1]), int(a[2]) + 1):
		var acc := {}  # band -> [income, goods, services, rent, utilities, persons, bal_start, bal_end]
		for gid in w.table("hh"):
			var g: Dictionary = w.table("hh")[gid]
			var r: Array = acc.get(g["band"], [0, 0, 0, 0, 0, 0, 0, 0])
			r[6] += w.ledger.balance(EconUtil.hh_acct(gid))
			acc[g["band"]] = r
		for m in 12:
			sim.run(1)
			for gid in w.table("hh"):
				var g: Dictionary = w.table("hh")[gid]
				var r: Array = acc.get(g["band"], [0, 0, 0, 0, 0, 0, 0, 0])
				r[0] += EconHouseholds.disposable(g)
				r[1] += int(g.get("spent_goods", 0))
				r[2] += int(g.get("svc_spent", 0))
				r[3] += int(g.get("rent_paid", 0))
				r[4] += maxi(0, int(g.get("util_paid", 0)))
				acc[g["band"]] = r
		var tot := [0, 0, 0, 0, 0, 0, 0, 0]
		var line := []
		for gid in w.table("hh"):
			var g: Dictionary = w.table("hh")[gid]
			var r: Array = acc.get(g["band"], [0, 0, 0, 0, 0, 0, 0, 0])
			r[7] += w.ledger.balance(EconUtil.hh_acct(gid))
			r[5] += EconHouseholds.persons(g)
			acc[g["band"]] = r
		for b in EconUtil.sorted_keys(acc):
			var r: Array = acc[b]
			for i in 8:
				tot[i] += int(r[i])
			var inc := maxf(1.0, float(r[0]))
			line.append("%s inc %dk spend %d%% (goods %d svc %d rent %d util %d) save %d%% hoard %.1f mo" % [b, int(r[0]) / 1000000,
				int(100.0 * float(int(r[1]) + int(r[2]) + int(r[3]) + int(r[4])) / inc), int(100.0 * float(r[1]) / inc), int(100.0 * float(r[2]) / inc),
				int(100.0 * float(r[3]) / inc), int(100.0 * float(r[4]) / inc), int(100.0 * float(int(r[7]) - int(r[6])) / inc), 12.0 * float(r[7]) / inc])
		var inc_t := maxf(1.0, float(tot[0]))
		var t := EconTrade._t(w)
		print("Y%d ALL inc %dk spend %d%% save %d%% hoard %.1f months | imports per yr (24m avg) %dk | u %.1f%% | income tax %s sales %s" % [y, int(tot[0]) / 1000000,
			int(100.0 * float(int(tot[1]) + int(tot[2]) + int(tot[3]) + int(tot[4])) / inc_t), int(100.0 * float(int(tot[7]) - int(tot[6])) / inc_t), 12.0 * float(tot[7]) / inc_t,
			int(EconTrade.balance(w).get("imports_24m", 0)) / 2000000, 100.0 * FirmAI.colony_unemployment(w),
			str(w.levers.get("ECON_INCOME_TAX_RATE")), str(w.levers.get("ECON_SALES_TAX"))])
		print("   " + " | ".join(line))
	quit()

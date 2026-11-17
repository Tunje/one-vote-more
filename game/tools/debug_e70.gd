extends SceneTree
## E69/E70 engagement probe: does smoothing / benefit floor / runway guard ever bind?
##   godot --headless --path . --script res://tools/debug_e70.gd -- [seed] [months]
const S := 1000.0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_v := int(args[0]) if args.size() > 0 else 1
	var months := int(args[1]) if args.size() > 1 else 120
	var sim := EconSim.make(seed_v, "BALANCED", {}, true)
	var w := sim.world
	print("guard def runway: ", w.indicators.defs["ECON_TREASURY_RUNWAY"].get("fiscalGuard", {}))
	var rmin := 1e12
	var rmax := -1e12
	var guard_months := 0
	for m in months:
		sim.step()
		var smooth_bind := 0
		var smooth_gain := 0
		var groups := 0
		var ben_bind := 0
		var ben_unemp := 0
		var ben_base_total := 0
		var ben_floor_total := 0
		var wg := float(EconFinance.wage_for(w, "", "G")) if false else 0.0
		for gid in EconUtil.sorted_keys(w.table("hh")):
			var g: Dictionary = w.table("hh")[gid]
			groups += 1
			var disp := EconHouseholds.disposable(g)
			var ess := EconHouseholds.essentials_cost(w, g)
			var sav := w.ledger.balance(EconUtil.hh_acct(gid))
			var b := int(EconData.DISC_PROPENSITY * maxi(0, disp - ess) + EconData.EXCESS_SAVINGS_SPEND * maxi(0, sav - EconData.SAVINGS_TARGET_MONTHS * ess))
			var full := EconHouseholds.discretionary_budget(w, g)
			if full > b:
				smooth_bind += 1
				smooth_gain += full - b
			var unemp: int = maxi(0, g["lf"] - EconLabor.employed(g))
			if unemp > 0:
				ben_unemp += 1
				var ess_pa := float(ess) / maxf(1.0, float(EconHouseholds.adults(g)) / S)
				var fl := int(0.5 * ess_pa * float(unemp) / S)
				ben_floor_total += fl
				ben_base_total += int(g["income"].get("benefit", 0))
		var r := float(w.indicators.read("ECON_TREASURY_RUNWAY", "COLONY", 0))
		rmin = minf(rmin, r)
		rmax = maxf(rmax, r)
		if r < 24000.0:
			guard_months += 1
		if m % 6 == 5:
			print("m%3d smooth_bind %d/%d gain %.1fk  unemp_groups %d benefit_paid %.1fk floor_need %.1fk  runway %.1f" % [m, smooth_bind, groups, smooth_gain / 1e6, ben_unemp, ben_base_total / 1e6, ben_floor_total / 1e6, r / 1000.0])
	print("runway range %.1f..%.1f months, months below 24: %d" % [rmin / 1000.0, rmax / 1000.0, guard_months])
	quit(0)

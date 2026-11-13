extends SceneTree
## Bob (Wilma's method, 2026-11-13): pure-economy A/B without politics (EconSim.make_econ_only), levers held fixed.
## Usage: ... -- <seed> <years> <arm>; arm = base | E134 | money | E134money (money: income tax 10%, sales tax 0%,
## re-set every month so the caretaker cannot move them; the base arms hold the defaults 24% / 8%).
## Prints every 5 years: unemployment, employed, hub posts and use, household money, real income; mean unemployment
## over years 10..end at the end.
const S := 1000


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sd := int(a[0])
	var years := int(a[1])
	var arm: String = a[2]
	var sim := EconSim.make_econ_only(sd)
	var w := sim.world
	var on: Array = []
	if arm.contains("E134"):
		on.append("E134")
	if arm.contains("payout"):
		on.append("PAYOUT")
	if arm.contains("commute"):
		on.append("SUPPORT_T")
	if arm.contains("workload"):
		on.append("WORKLOAD")
	if arm.contains("fleet"):
		on.append("FLEET")
	w.meta["on"] = on
	var money := arm.contains("money")
	var u_sum := 0.0
	var u_n := 0
	for m in years * 12:
		w.levers["ECON_INCOME_TAX_RATE"] = 10 if money else 24
		w.levers["ECON_SALES_TAX"] = 0 if money else 8
		sim.run(1)
		var lab := EconQuery.labour(w)
		if m >= 120:
			u_sum += float(lab["rate_pct"])
			u_n += 1
		if (m + 1) % 60 != 0:
			continue
		var hub_staff := 0
		var hub_t := 0
		var hubs := 0
		for fid in w.table("facility"):
			var f: Dictionary = w.table("facility")[fid]
			if f["type"] == "SERVICEHUB" and not f["mothball"]:
				hubs += 1
				hub_staff += EconLabor.staff_total(f["staff"])
				hub_t += int(f["T"])
		var hh := 0
		var disp := 0
		var persons := 0
		for gid in w.table("hh"):
			var g: Dictionary = w.table("hh")[gid]
			hh += w.ledger.balance(EconUtil.hh_acct(gid))
			disp += EconHouseholds.disposable(g)
			persons += EconHouseholds.persons(g)
		var s := EconUtil.st(w)
		var basket := float(EconData.NEED["FOOD"]) * float(s["prices"]["FOOD"]) + float(EconData.NEED["CONSUMER_MIN"]) * float(s["prices"]["CONSUMER"])
		print("%s seed %d Y%d u %.1f%% employed %d | hubs %d T %d staff %d | hh money %dM | real income %.2f" % [arm, sd, (m + 1) / 12,
			float(lab["rate_pct"]), int(lab["employed"]), hubs, hub_t / maxi(1, hubs), hub_staff / S, hh / 1000000,
			float(disp) / maxf(1.0, float(persons) / float(S) * basket)])
	print("%s seed %d MEAN_U %.1f END ledger %d jobs %d" % [arm, sd, u_sum / maxf(1.0, float(u_n)), w.ledger.total(), EconPop.check(w).size()])
	quit()

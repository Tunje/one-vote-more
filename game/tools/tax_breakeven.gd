extends SceneTree
## Bob (Wilma): what income / sales tax does the econ-only economy need to fund the default budget? Taxes held fixed;
## yearly government revenue vs spending, treasury, default. Usage: ... -- <seed> <years> <income%> <sales%>
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sd := int(a[0])
	var years := int(a[1])
	var it := int(a[2])
	var st := int(a[3])
	var sim := EconSim.make_econ_only(sd)
	var w := sim.world
	var rev_y := 0
	var spend_y := 0
	for m in years * 12:
		w.levers["ECON_INCOME_TAX_RATE"] = it
		w.levers["ECON_SALES_TAX"] = st
		sim.run(1)
		var s := CoreUtil.st(w)
		rev_y += int(s.get("gov_rev_m", 0))
		spend_y += int(s.get("gov_spend_m", 0))
		if (m + 1) % 60 == 0:
			print("tax %d/%d seed %d Y%d revenue/yr %dk spend/yr %dk balance %+d%% | treasury %dk debt %dk default %s | u %.1f%%" % [it, st, sd, (m + 1) / 12,
				rev_y / 5 / 1000000, spend_y / 5 / 1000000, int(100.0 * float(rev_y - spend_y) / maxf(1.0, float(spend_y))),
				w.ledger.balance(CoreUtil.TREASURY) / 1000000, EconFinance.debt_of(w, "gov") / 1000000, str(s.get("sovereign_default", false)),
				float(EconFace.query_labour(w)["rate_pct"])])
			rev_y = 0
			spend_y = 0
	quit()

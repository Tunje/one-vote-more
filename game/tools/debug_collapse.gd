extends SceneTree
## O-1 collapse/recovery probe: yearly snapshot of what the economy still has (firms, plants, utilities, money)
## over an integrated run. Usage: godot --headless --path . --script res://tools/debug_collapse.gd -- [seed] [years]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_v := int(args[0]) if args.size() > 0 else 1
	var years := int(args[1]) if args.size() > 1 else 30
	var sim := EconSim.make(seed_v)
	var w := sim.world
	print("yr  u%   firmsA/D/L/X  plants run/mb/none  E_sup/dem  W_sup/dem  food_out  treas(M) gdebt(M) bank(M) freeze default  hhcash(M) wageG  pFood pCons pMat  grantM  spend/rev(M)")
	for y in years:
		sim.run(12)
		var s := EconUtil.st(w)
		var st := {"ACTIVE": 0, "DISTRESSED": 0, "ADMINISTRATION": 0, "LIQUIDATION": 0, "DISSOLVED": 0, "FORMING": 0}
		for oid in w.table("org"):
			var o: Dictionary = w.table("org")[oid]
			st[o["status"]] = int(st.get(o["status"], 0)) + 1
		var run := 0
		var mb := 0
		var idle := 0
		var by_type := {}
		for fid in w.table("facility"):
			var f: Dictionary = w.table("facility")[fid]
			if f["mothball"]:
				mb += 1
			elif f["util"] > 50:
				run += 1
				by_type[f["type"]] = int(by_type.get(f["type"], 0)) + 1
			else:
				idle += 1
		var food_out := 0
		for fid in w.table("facility"):
			var f: Dictionary = w.table("facility")[fid]
			if f["type"] == "FARM":
				food_out += f["out_last"]
		var hhc := 0
		for gid in w.table("hh"):
			hhc += w.ledger.balance(EconUtil.hh_acct(gid))
		var rev := 0
		for v in s["gov_rev_hist"]:
			rev += int(v)
		var spend := 0
		for v in s.get("gov_spend_hist", []):
			spend += int(v)
		print("%2d %5.1f  %2d/%d/%d/%d  %3d/%2d/%2d  %4d/%4d  %4d/%4d  %5d  %7.2f %7.2f %7.2f %s %s  %7.2f %5d  %5d %5d %5d  %5.2f  %6.2f/%6.2f" % [y + 1,
			100.0 * FirmAI.colony_unemployment(w), st["ACTIVE"] + st["DISTRESSED"], st["ADMINISTRATION"], st["LIQUIDATION"], st["DISSOLVED"],
			run, mb, idle, s["util_supply"]["E"] / 1000, s["util_demand"]["E"] / 1000, s["util_supply"]["W"] / 1000, s["util_demand"]["W"] / 1000,
			food_out / 1000, float(w.ledger.balance(EconUtil.TREASURY)) / 1e9, float(EconFinance.debt_of(w, "gov")) / 1e9,
			float(w.ledger.balance(EconUtil.BANK)) / 1e9, str(s.get("credit_freeze", false)).substr(0, 1), str(s.get("sovereign_default", false)).substr(0, 1),
			float(hhc) / 1e9, s["wage"]["G"] / 1000, s["prices"]["FOOD"] / 1000, s["prices"]["CONSUMER"] / 1000, s["prices"]["MATERIAL"] / 1000,
			float(EconFinance.origin_grant(w.month)) / 1e9, float(spend) / 1e9, float(rev) / 1e9])
		print("     running: ", by_type)
	quit()

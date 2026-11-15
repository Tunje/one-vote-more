extends SceneTree
## Bob: full-game A/B (v9 base = EconSim.make defaults). args: seed years flags(comma | base; -FLAG removes) arm_name
## One "AB" line: adults at the end; means over Y5..end of unemployment, food shortfall, unaffordable / scarce food
## (S7F arms), food-assistance dependence, real income; taxes at the end; private firms: alive, dead, distress entries
## (and those profitable over 12 months), credit lines; private share of sales by good (Y5..end); ledger.
const GOODS := ["FOOD", "MATERIAL", "COMPONENT", "CONSUMER", "CLOTHING", "FURNISHINGS", "FINE_FOOD", "MINERAL"]


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sim: Simulation = EconSim.make(int(a[0]), "BALANCED", {}, true)
	var w := sim.world
	if a[2] != "base":
		for fl in a[2].split(","):
			if fl.begins_with("-"):
				(w.meta["on"] as Array).erase(fl.substr(1))
			elif not (w.meta["on"] as Array).has(fl):
				(w.meta["on"] as Array).append(fl)
	var n := 0
	var su := 0.0
	var sf := 0.0
	var sua := 0.0
	var ssc := 0.0
	var sap := 0.0
	var sr := 0.0
	var sold_all := {}
	var sold_priv := {}
	var bak_m := 0
	var bak_u := 0
	var st_w := 0
	var st_g := 0
	var raw_sum := 0
	var idle_n := 0
	var plant_n := 0
	var swings := 0
	var prev_px := {}
	var runway_sum := 0.0
	var runway_y := {}
	var cpi_y := {}
	var px_sum := 0.0
	var cpi_sum := 0.0
	var px_n := 0
	var below_m := 0
	var bld_y := []  # builders every 5 years: alive/crew/waiting tenders/mean wait months
	var bld_last := {}  # builder oid → [rev12, wages12, contracts] at its last live month
	var bld_dead := {"no_work": 0, "loss": 0, "other": 0}
	var idle_bm := 0  # builder-months with no started job (since the last 5-year mark)
	var nobid_m := 0  # tender-months with no bid (same)
	var ent := {}  # E165 report: entrant oid → {c: plan month, o: opening month, a12/a36 alive, j12/j36 jobs}
	for m in int(a[1]) * 12:
		sim.run(1)
		for bo in w.table("org"):
			var bx: Dictionary = w.table("org")[bo]
			if not bool(bx.get("is_contractor", false)) or bx["type"] != "PRIVATE":
				continue
			if bx["status"] in ["LIQUIDATION", "DISSOLVED"]:
				if bld_last.has(bo):
					var bl: Array = bld_last[bo]
					var why := "no_work" if int(bl[0]) < int(bl[1]) * 3 / 10 else ("loss" if int(bl[0]) < int(bl[1]) else "other")
					bld_dead[why] += 1
					bld_last.erase(bo)
			else:
				var bp := EconAnnual.sum12(bx)
				bld_last[bo] = [int(bp.get("rev", 0)), int(bp.get("wages", 0)), (bx.get("contracts", []) as Array).size()]
		for bo2 in bld_last:
			var started := false
			for pj2 in w.table("org")[bo2].get("contracts", []):
				var pq: Dictionary = w.table("project")[pj2]
				if pq["status"] == "ACTIVE" and int(pq["start_month"]) <= w.month:
					started = true
			if not started:
				idle_bm += 1
		for pj3 in w.table("project"):
			var pz: Dictionary = w.table("project")[pj3]
			if pz["status"] == "TENDERABLE" or (pz["status"] == "TENDER" and (pz["bids"] as Array).is_empty()):
				nobid_m += 1
		if w.month % 60 == 0:
			var queued := 0
			var building := 0
			for pj4 in w.table("project"):
				var pv: Dictionary = w.table("project")[pj4]
				if pv["status"] == "ACTIVE":
					if int(pv["start_month"]) > w.month:
						queued += 1
					else:
						building += 1
			var qwv: Array = EconUtil.st(w).get("q_waits", [])
			var qsum := 0
			for qe in qwv:
				qsum += int(qe[1])
			var states := {"no_offer": 0, "queued": 0, "building": 0}
			for po in w.table("org"):
				if w.table("org")[po]["status"] == "FORMING":
					states[EconInsolvency.plan_state(w, po)] += 1
			var failed_t := 0
			for pj5 in w.table("project"):
				failed_t += int(w.table("project")[pj5].get("tenders_failed", 0))
			bld_y.append("Y%d:q%d/b%d/wait%.1f/idle%d/nobid%d/book%.1f/entries%d/plans%d-%d-%d/tfail%d" % [w.month / 12, queued, building,
				float(qsum) / maxf(1.0, float(qwv.size())), idle_bm, nobid_m, float(EconConstruction.backlog_wu(w)) / float(EconConstruction.entrant_year(w)),
				int(EconUtil.st(w).get("builder_entries", 0)), states["no_offer"], states["queued"], states["building"], failed_t])
			idle_bm = 0
			nobid_m = 0
			var crew := 0
			for bo in bld_last:
				for tier in w.table("org")[bo].get("crew", {}):
					for kk in w.table("org")[bo]["crew"][tier]:
						crew += int(w.table("org")[bo]["crew"][tier][kk]) / 1000
			var wt := 0
			var wsum := 0
			for pj in w.table("project"):
				var pp: Dictionary = w.table("project")[pj]
				if pp["status"] == "TENDERABLE" or (pp["status"] == "TENDER" and (pp["bids"] as Array).is_empty()):
					wt += 1
					wsum += w.month - int(pp.get("tender_month", w.month))
			bld_y.append("Y%d:%d/%d/%d/%d" % [w.month / 12, bld_last.size(), crew, wt, wsum / maxi(1, wt)])
		for eo in w.table("org"):
			var ox: Dictionary = w.table("org")[eo]
			if not ox.has("entry_type"):
				continue
			if not ent.has(eo):
				ent[eo] = {"c": w.month, "o": -1}
			var er: Dictionary = ent[eo]
			var gone: bool = ox["status"] in ["LIQUIDATION", "DISSOLVED"]
			if int(er["o"]) < 0 and ox["status"] != "FORMING" and not gone:
				er["o"] = w.month
			if int(er["o"]) >= 0:
				for k2 in [12, 36]:
					if w.month == int(er["o"]) + k2:
						er["a%d" % k2] = 0 if gone else 1
						var jobs := 0
						if not gone:
							for fj in w.table("facility"):
								var fx2: Dictionary = w.table("facility")[fj]
								if fx2["org"] == eo:
									for tier in fx2.get("staff", {}):
										for kk in fx2["staff"][tier]:
											jobs += int(fx2["staff"][tier][kk]) / 1000
						er["j%d" % k2] = jobs
		if m >= 60:  # Y5..end means of the food price and CPI (the end-of-run price is too noisy to compare arms)
			px_sum += 100.0 * float(int(EconUtil.st(w)["prices"]["FOOD"])) / float(EconData.BASE_PRICE["FOOD"] * EconUtil.S)
			cpi_sum += float(int(EconUtil.st(w).get("cpi", 0))) / float(EconUtil.S)
			px_n += 1
			if float(int(EconUtil.st(w)["prices"]["FOOD"])) < EconMarket._cheapest_cost(w, "FOOD"):
				below_m += 1
		if m == 11 or m == 59 or m == 119:
			var yk := m / 12 + 1
			cpi_y[yk] = int(EconUtil.st(w).get("cpi", 0)) / EconUtil.S
			var rw := []
			for key in EconData.ORGS:
				if not (EconData.ORGS[key][1] in ["PRIVATE", "COOPERATIVE"]):
					continue
				var oid := EconFinance.org_by_key(w, key)
				if oid == "" or w.table("org")[oid]["status"] in ["LIQUIDATION", "DISSOLVED"]:
					rw.append("%s:dead" % key.substr(0, 4))
					continue
				var cost := maxi(1, EconMoney.founding_cost(w, oid))
				rw.append("%s:%d" % [key.substr(0, 4), w.ledger.balance(EconUtil.acct(oid)) / cost])
			runway_y[yk] = ",".join(rw)
		if m < 60:
			continue
		var s := EconUtil.st(w)
		n += 1
		su += float(EconQuery.labour(w)["rate_pct"])
		sf += float(int(s.get("food_shortfall", 0)))
		sua += float(int(s.get("food_unaff", 0)))
		ssc += float(int(s.get("food_scarce", 0)))
		sap += float(int(s.get("food_assist_pm", 0)))
		var disp := 0
		var persons := 0
		for gid in w.table("hh"):
			disp += EconHouseholds.disposable(w.table("hh")[gid])
			persons += EconHouseholds.persons(w.table("hh")[gid])
		var basket := float(EconData.NEED["FOOD"]) * float(s["prices"]["FOOD"]) + float(EconData.NEED["CONSUMER_MIN"]) * float(s["prices"]["CONSUMER"])
		sr += float(disp) / maxf(1.0, float(persons) / 1000.0 * basket)
		raw_sum += int(s.get("raw_food", 0))
		for fid in w.table("facility"):
			var pf: Dictionary = w.table("facility")[fid]
			var rr: Dictionary = EconData.RECIPES.get(pf["type"], {})
			if pf["mothball"] or rr.is_empty() or not (String(rr["out"][0]) in EconData.MARKET_GOODS):
				continue
			plant_n += 1
			if int(pf["util"]) < 100:
				idle_n += 1
		for gd in s["prices"]:
			var pv := int(s["prices"][gd])
			if prev_px.has(gd) and int(prev_px[gd]) > 0 and absi(pv - int(prev_px[gd])) * 5 >= int(prev_px[gd]):
				swings += 1
			prev_px[gd] = pv
		var spend_m := float(maxi(1, int(s.get("gov_spend_m", 1))))
		runway_sum += minf(120.0, float(w.ledger.balance("gov:treasury")) / spend_m)
		st_w += int(s.get("staple_m", {}).get("want", 0))
		st_g += int(s.get("staple_m", {}).get("got", 0))
		for fid in w.table("facility"):
			var bf: Dictionary = w.table("facility")[fid]
			if bf["type"] == "BAKERY" and not bf["mothball"] and not (w.table("org")[bf["org"]]["status"] in ["LIQUIDATION", "DISSOLVED"]):
				bak_m += 1
				bak_u += int(bf["util"])
		for oid in w.table("org"):
			var o: Dictionary = w.table("org")[oid]
			for g in o.get("sold", {}):
				var q := int(o["sold"][g])
				sold_all[g] = int(sold_all.get(g, 0)) + q
				if o["type"] in ["PRIVATE", "COOPERATIVE"]:
					sold_priv[g] = int(sold_priv.get(g, 0)) + q
	var adults := 0
	for gid in w.table("hh"):
		var g: Dictionary = w.table("hh")[gid]
		adults += (int(g["lf"]) + int(g["nonpart"]) + int(g["owners"])) / 1000
	var alive := 0
	var dead := 0
	for oid in w.table("org"):
		var o: Dictionary = w.table("org")[oid]
		if o["type"] != "PRIVATE":
			continue
		if bool(o.get("plan_abandoned", false)):
			continue  # E165: a dropped plan is not a firm death
		if o["status"] in ["LIQUIDATION", "DISSOLVED"]:
			dead += 1
		else:
			alive += 1
	var lines := 0
	for lid in w.table("loan"):
		if bool(w.table("loan")[lid].get("revolving", false)) and int(w.table("loan")[lid]["principal"]) > 0:
			lines += 1
	var share := []
	for g in GOODS:
		if int(sold_all.get(g, 0)) > 0:
			share.append("%s:%d" % [g, 100 * int(sold_priv.get(g, 0)) / int(sold_all[g])])
	var bak_now := 0
	for fid in w.table("facility"):
		var bf2: Dictionary = w.table("facility")[fid]
		if bf2["type"] == "BAKERY" and not bf2["mothball"] and not (w.table("org")[bf2["org"]]["status"] in ["LIQUIDATION", "DISSOLVED"]):
			bak_now += 1
	var ffa := int(sold_all.get("FOOD", 0)) + int(sold_all.get("FINE_FOOD", 0))
	var ffp := int(sold_priv.get("FOOD", 0)) + int(sold_priv.get("FINE_FOOD", 0))
	var cv: Dictionary = EconCredit.view(w)
	var farms := 0
	for fid in w.table("facility"):
		if w.table("facility")[fid]["type"] == "FARM" and not w.table("facility")[fid]["mothball"]:
			farms += 1
	var mtot := 0
	var mhh := 0
	var mun := 0
	for acc in w.ledger.balances:
		var ka := String(acc)
		var b := int(w.ledger.balances[acc])
		if b <= 0 or ka == Ledger.EXTERNAL or ka == EconUtil.BANK:
			continue
		mtot += b
		if ka.begins_with("hh:"):
			mhh += b
		elif ka.begins_with("union:"):
			mun += b
	var trs := maxi(0, w.ledger.balance(EconUtil.TREASURY))
	var money := " money %d perad %d treas%% %d union%% %d bankcap %d loans %d util %d" % [mtot / 1000000000, mtot / maxi(1, adults) / 1000000, 100 * trs / maxi(1, mtot),
		100 * mun / maxi(1, mhh + mun), EconBank.capital(w) / 1000000000, EconBank.loans(w) / 1000000000, EconBank.utilisation_pm(w)]
	var b_alive := 0
	var b_dead := 0
	for oid in w.table("org"):
		var bo: Dictionary = w.table("org")[oid]
		if not bool(bo.get("is_contractor", false)) or not String(bo.get("key", "")).begins_with("BUILD_"):
			continue
		if bo["status"] in ["LIQUIDATION", "DISSOLVED"]:
			b_dead += 1
		else:
			b_alive += 1
	money += " cpi1 %d cpi5 %d cpi10 %d runway1 %s runway5 %s" % [int(cpi_y.get(1, 0)), int(cpi_y.get(5, 0)), int(cpi_y.get(10, 0)), str(runway_y.get(1, "")), str(runway_y.get(5, ""))]
	money += " builders %d/%d homecap %d" % [b_alive, b_dead, int(EconUtil.st(w).get("builder_home_capital", 0)) / 1000000000]
	var e148 := money + (" farms %d foodpx %d foodpx_avg %d cpi_avg %d food_below_cost_m %d farm_entrants %d farm_profit12 %d" % [farms, 100 * int(EconUtil.st(w)["prices"]["FOOD"]) / (EconData.BASE_PRICE["FOOD"] * EconUtil.S), int(px_sum / maxf(1.0, float(px_n))), int(cpi_sum / maxf(1.0, float(px_n))), below_m, farm_entrants(w), farm_profit(w)]) + " idle %d swings %d runway %.1f inv %d overdue %d invw %d" % [1000 * idle_n / maxi(1, plant_n), swings, runway_sum / maxf(1.0, float(n)), int(cv["open"]) / 1000, int(cv["overdue"]) / 1000, int(cv["written_ytd"]) / 1000]
	var extra := e148 + " bak %d bakmonths %d baku %d staple %d privff %d raw %d" % [bak_now, bak_m, bak_u / maxi(1, bak_m), 1000 * st_g / maxi(1, st_w), 100 * ffp / maxi(1, ffa), raw_sum / maxi(1, n)]
	var s2 := EconUtil.st(w)
	var k := float(maxi(1, n))
	var pr := {"plans": 0, "opened": 0, "never": 0, "forming": 0, "mo": 0, "n12": 0, "a12": 0, "n36": 0, "a36": 0, "j12": 0, "j36": 0}
	for eo in ent:
		var er: Dictionary = ent[eo]
		var ox: Dictionary = w.table("org")[eo]
		pr["plans"] += 1
		if int(er["o"]) >= 0:
			pr["opened"] += 1
			pr["mo"] += int(er["o"]) - int(er["c"])
			for k2 in [12, 36]:
				if er.has("a%d" % k2):
					pr["n%d" % k2] += 1
					pr["a%d" % k2] += int(er["a%d" % k2])
					pr["j%d" % k2] += int(er["j%d" % k2])
		elif ox["status"] == "FORMING":
			pr["forming"] += 1
		else:
			pr["never"] += 1
	var ps: Dictionary = EconUtil.st(w).get("plan_stats", {})
	extra += " plans %d opened %d never %d forming %d mo %.1f surv12 %d/%d surv36 %d/%d jobs12 %d jobs36 %d ab_nob %d ab_stall %d ab_lim %d wo %d wo_nob %d wo_stall %d wo_lim %d" % [
		pr["plans"], pr["opened"], pr["never"], pr["forming"], float(pr["mo"]) / maxf(1.0, float(pr["opened"])), pr["a12"], pr["n12"], pr["a36"], pr["n36"],
		pr["j12"], pr["j36"], int(ps.get("abandoned_no_builder", 0)), int(ps.get("abandoned_stalled", 0)), int(ps.get("abandoned_limit", 0)),
		int(ps.get("written_off", 0)) / 1000000, int(ps.get("written_off_no_builder", 0)) / 1000000, int(ps.get("written_off_stalled", 0)) / 1000000, int(ps.get("written_off_limit", 0)) / 1000000]
	extra += " ab_noreason %d" % int(ps.get("abandoned_no_reason", 0))
	extra += " skipped_nob %d bld %s blddead nowork %d loss %d other %d" % [int(ps.get("skipped_no_builder", 0)), ",".join(bld_y), bld_dead["no_work"], bld_dead["loss"], bld_dead["other"]]
	print("AB %s s%s adults %d u %.1f food %.0f unaff %.0f scarce %.0f assist %.0f real %.2f tax %d/%d priv alive %d dead %d distress %d pos12 %d lines %d share %s ledger %d" % [
		a[3], a[0], adults, su / k, sf / k, sua / k, ssc / k, sap / k, sr / k,
		int(w.levers["ECON_INCOME_TAX_RATE"]), int(w.levers["ECON_SALES_TAX"]), alive, dead,
		int(s2.get("distress_n", 0)), int(s2.get("distress_pos12_n", 0)), lines, ",".join(share), w.ledger.total()] + extra)
	quit()


static func farm_entrants(w: WorldState) -> int:
	var n := 0
	for oid in w.table("org"):
		if String(w.table("org")[oid].get("entry_type", "")) == "FARM":
			n += 1
	return n


## Profit of the last 12 months of every firm that runs a farm (thousand credits).
static func farm_profit(w: WorldState) -> int:
	var seen := {}
	var t2 := 0
	for fid in w.table("facility"):
		var f: Dictionary = w.table("facility")[fid]
		if f["type"] == "FARM" and not seen.has(f["org"]) and w.table("org").has(f["org"]):
			seen[f["org"]] = true
			t2 += EconPublicCo.result12(w.table("org")[f["org"]])
	return t2 / 1000000

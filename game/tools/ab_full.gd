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
	var locks := {}
	if a[2] != "base":
		for fl in a[2].split(","):
			if fl.contains("="):
				locks[fl.split("=")[0]] = int(fl.split("=")[1])  # a lever forced every month (arms independent of government)
				continue
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
	var fr := {"cap": 0, "used": 0, "def": 0, "full": 0, "n": 0}
	var below_m := 0
	var bld_y := []  # builders every 5 years: alive/crew/waiting tenders/mean wait months
	var bld_last := {}  # builder oid → [rev12, wages12, contracts] at its last live month
	var bld_dead := {"no_work": 0, "loss": 0, "other": 0}
	var idle_bm := 0  # builder-months with no started job (since the last 5-year mark)
	var nobid_m := 0  # tender-months with no bid (same)
	var ent := {}  # E165 report: entrant oid → {c: plan month, o: opening month, a12/a36 alive, j12/j36 jobs}
	var famfood := 0.0
	var allfood := 0.0
	var fambread := 0.0
	var allbread := 0.0
	var nn_m := {"F": 0, "B": 0}  # months a grant lever was above 0 with no need
	var nn_paid := {"F": 0, "B": 0}  # grants paid in such months
	var gn_prev := {}
	var lev_prev := {}
	var pm_moves := {}  # pm party → [raises, cuts] of the two grant levers
	var gov_path := []
	var gap_m := {"F": 0, "B": 0}  # months the colony needed it but no programme was open
	var guard_m := {}  # month → fiscal guard on
	var was_open := {"FAMFARM": false, "FAMBAKERY": false}
	var opened := {"elected": 0, "founders": 0}
	var favour := 0
	var failed_prog := 0
	var fact_i := 0  # highest fact id seen
	var fxs := {"comp": 0.0, "fam": 0.0, "flour": 0.0, "margin": 0.0, "n": 0.0, "compfarms": 0.0}
	for m in int(a[1]) * 12:
		for lk in locks:
			w.levers[lk] = locks[lk]
		sim.run(1)
		var est := EconUtil.st(w)
		var ln: Dictionary = est.get("lever_need", {})
		var gn: Dictionary = est.get("fam_grant_n", {})
		var gv: Dictionary = w.table("pol")["state"].get("government", {}) if w.table("pol").has("state") else {}
		var pmp := String(gv.get("pm_party", ""))
		var pmd: Dictionary = w.table("party").get(pmp, {})
		var pos: Dictionary = pmd.get("positions", {})
		var tag := "%s(r%d,e%d)" % [String(pmd.get("name", "-")).substr(0, 10).replace(" ", "_"), int(round(float(pos.get("REDISTRIBUTION", 0.0)) / 1000.0)), int(round(float(pos.get("ECON_ROLE", 0.0)) / 1000.0))]
		for e in [["F", "ECON_FAMILY_FARM_GRANT", "FAMFARM"], ["B", "ECON_FAMILY_BAKERY_GRANT", "FAMBAKERY"]]:
			var lv := int(w.levers.get(e[1], 0))
			var need := int(ln.get(e[1], 0))
			if need > 0 and not EconFamily.prog_open(w, e[2]):
				gap_m[e[0]] += 1
			if lv > 0 and need <= 0:
				nn_m[e[0]] += 1
				if int(gn.get(e[2], 0)) > int(gn_prev.get(e[2], 0)):
					nn_paid[e[0]] += int(gn.get(e[2], 0)) - int(gn_prev.get(e[2], 0))
			if lev_prev.has(e[1]) and lv != int(lev_prev[e[1]]):
				var mv: Array = pm_moves.get(tag, [0, 0])
				mv[0 if lv > int(lev_prev[e[1]]) else 1] += 1
				pm_moves[tag] = mv
			lev_prev[e[1]] = lv
		gn_prev = gn.duplicate()
		guard_m[w.month] = Legislature.fiscal_guard(w)
		for ft in was_open:
			var op := EconFamily.prog_open(w, ft)
			if op and not was_open[ft]:
				opened["elected" if pmp != "" else "founders"] += 1
			was_open[ft] = op
		# only the facts added since last month (ids F<n> only grow; compaction removes old ones, so no array index)
		var top_id := fact_i
		var fi2 := w.facts.facts.size() - 1
		while fi2 >= 0:
			var fct: Dictionary = w.facts.facts[fi2]
			var nid := int(String(fct["id"]).substr(1))
			if nid <= fact_i:
				break
			top_id = maxi(top_id, nid)
			if fct["type"] == "POL_GRANT_FAVOURITISM":
				favour += 1
			elif fct["type"] == "POL_GRANT_PROGRAMME_FAILED":
				failed_prog += 1
			fi2 -= 1
		fact_i = top_id
		if m >= 60:
			fxs["n"] += 1.0
			var ehx: Array = est.get("ess_hist", {}).get("FOOD", [])
			fxs["margin"] += float(int(ehx[ehx.size() - 1])) if not ehx.is_empty() else 0.0
			for fid2 in w.table("facility"):
				var f2: Dictionary = w.table("facility")[fid2]
				var o2 := float(int(f2.get("out_last", 0))) / 1000.0
				if f2["type"] == "FARM":
					fxs["comp"] += o2
					if not f2["mothball"]:
						fxs["compfarms"] += 1.0
				elif f2["type"] == "FAMFARM":
					fxs["fam"] += o2
				elif f2["type"] in ["BAKERY", "FAMBAKERY"]:
					var r2: Dictionary = EconData.RECIPES[f2["type"]]
					fxs["flour"] += o2 * float(r2["in"].get("FOOD", 0)) / float(r2["out"][1])
		if m % 12 == 11:
			gov_path.append("%d/%d@%s" % [int(w.levers.get("ECON_FAMILY_FARM_GRANT", 0)), int(w.levers.get("ECON_FAMILY_BAKERY_GRANT", 0)), tag])
		if m >= 60:
			for fid in w.table("facility"):
				var fx: Dictionary = w.table("facility")[fid]
				var ox := float(int(fx.get("out_last", 0)))
				if fx["type"] in ["FARM", "FAMFARM"]:
					allfood += ox
					if fx["type"] == "FAMFARM":
						famfood += ox
				elif fx["type"] in ["BAKERY", "FAMBAKERY"]:
					allbread += ox
					if fx["type"] == "FAMBAKERY":
						fambread += ox
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
			var fs := EconUtil.st(w)
			fr["cap"] += int(fs.get("freight_cap", 0))
			fr["used"] += int(fs.get("freight_used", 0))
			for fd in fs.get("freight_deferred", {}):
				fr["def"] += int(fs["freight_deferred"][fd])
			if int(fs.get("freight_cap", 0)) > 0 and int(fs.get("freight_used", 0)) * 100 >= int(fs.get("freight_cap", 0)) * 95:
				fr["full"] += 1
			fr["n"] += 1
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
	var fv: Dictionary = EconFamily.view(w)
	money += " famfarm %d/%d/%d famfood%% %d fambak %d/%d/%d fambread%% %d grant %d course %d courses %d famdark %s famfail %s" % [
		int(fv["founded"].get("FAMFARM", 0)), int(fv["alive"].get("FAMFARM", 0)), int(fv["sold"].get("FAMFARM", 0)), int(100.0 * famfood / maxf(1.0, allfood)),
		int(fv["founded"].get("FAMBAKERY", 0)), int(fv["alive"].get("FAMBAKERY", 0)), int(fv["sold"].get("FAMBAKERY", 0)), int(100.0 * fambread / maxf(1.0, allbread)),
		int(fv["grant_total"]) / 1000, int(fv["course_total"]) / 1000, int(fv["courses"]), JSON.stringify(fv["dark"]).replace(" ", ""), JSON.stringify(fv["fail_found"]).replace(" ", "")]
	var lh := []
	for e in fv["lever_hist"]:
		lh.append("%d/%d%s%s" % [int(e[0]), int(e[1]), "F" if int(e[2]) == 1 else "", "B" if int(e[3]) == 1 else ""])
	var pmv := []
	for k2 in pm_moves:
		pmv.append("%s:+%d/-%d" % [k2, pm_moves[k2][0], pm_moves[k2][1]])
	var ph := []
	var prog_zero := 0
	for e in fv["prog_hist"]:
		var bands := ""
		if (e as Array).size() > 7:
			for bk in EconUtil.sorted_keys(e[7]):
				bands += "%s%d" % [String(bk), int(e[7][bk])]
		ph.append("%s@%d:%dm/%d%%/p%d/r%d/%s/%s" % [String(e[0]).substr(3, 1), int(e[1]) / 12, int(e[2]), int(e[3]), int(e[4]), int(e[5]), "+".join((e[6] as Array).map(func(x): return String(x).replace("d:", ""))), bands])
		if int(e[4]) == 0:
			prog_zero += 1
	var gb := {"n": 0, "guard": 0, "third": 0}
	for bid in w.table("bill"):
		var bl: Dictionary = w.table("bill")[bid]
		var hit := false
		for c in bl.get("clauses", []):
			if String(c.get("lever", "")) in ["ECON_FAMILY_FARM_GRANT", "ECON_FAMILY_BAKERY_GRANT"] and int(c.get("to", 0)) > int(c.get("from", 0)):
				hit = true
		if hit:
			gb["n"] += 1
			if bool(guard_m.get(int(bl.get("month", -1)), false)):
				gb["guard"] += 1
			if (bl.get("clauses", []) as Array).size() >= 3:
				gb["third"] += 1
	var fn := maxf(1.0, fxs["n"])
	money += " g4 opened_elected %d opened_founders %d grantbills %d guardpass %d third %d favour %d progfailed %d foodx comp %d fam %d flour %d margin %d compfarms %.1f" % [
		opened["elected"], opened["founders"], gb["n"], gb["guard"], gb["third"], favour, failed_prog, int(fxs["comp"] / fn), int(fxs["fam"] / fn), int(fxs["flour"] / fn), int(fxs["margin"] / fn), fxs["compfarms"] / fn]
	var fls: Dictionary = fv.get("loans", {})
	var fam_out := 0
	for lid in w.table("loan"):
		if bool(w.table("loan")[lid].get("family", false)):
			fam_out += int(w.table("loan")[lid]["principal"])
	money += " famloans n %d amt %d paid %d behind %d defaulted %d outstanding %d fambankcap %d progzero %d" % [int(fls.get("n", 0)), int(fls.get("amount", 0)) / 1000000,
		int(fls.get("paid", 0)) / 1000000, int(fls.get("behind", 0)), int(fls.get("defaulted", 0)), fam_out / 1000000, EconBank.capital(w) / 1000000, prog_zero]
	money += " progs %s gap F%d B%d" % [",".join(ph), gap_m["F"], gap_m["B"]]
	money += " nneed F%d/%d B%d/%d govpath %s pmmoves %s" % [nn_m["F"], nn_paid["F"], nn_m["B"], nn_paid["B"], ",".join(gov_path), ",".join(pmv)]
	money += " famgov farmgr %d bakgr %d levers %s" % [int(fv["grant_n"].get("FAMFARM", 0)), int(fv["grant_n"].get("FAMBAKERY", 0)), ",".join(lh)]
	var dep_n := 0
	var dep_sc := 0
	for fdx in w.table("facility"):
		var ffx: Dictionary = w.table("facility")[fdx]
		if ffx["type"] == "DEPOT" and not ffx["mothball"]:
			dep_n += 1
			dep_sc += int(ffx.get("scale", 1000))
	var fra: Array = EconUtil.st(w).get("r8_fr_actions", [])
	money += " freight cap %d used %d deferred %d full_m %d depots %d scale %d fr_actions %d" % [fr["cap"] / 1000 / maxi(1, fr["n"]), fr["used"] / 1000 / maxi(1, fr["n"]),
		fr["def"] / 1000 / maxi(1, fr["n"]), fr["full"], dep_n, dep_sc, fra.size()]
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

extends SceneTree
## Bob: support-economy A/B (planning/plan-support-economy.md). One game per call.
## Usage: godot --headless --path . --script res://tools/ab_support.gd -- <seed> <years> <off|A|E|D|AED>
## Every 10 years: population, labour force, unemployment, support posts (offices, sanitation, shops), real income per
## person (disposable income ÷ a food + goods basket at the prices households pay, retail margin included), firms
## alive and failed, food shortfall. Ends with ledger / goods / jobs checks.
const S := 1000


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sd := int(a[0]) if a.size() > 0 else 1
	var years := int(a[1]) if a.size() > 1 else 50
	var v: String = a[2] if a.size() > 2 else "off"
	var sim: Simulation = EconSim.make(sd, "BALANCED", {}, true)
	var w := sim.world
	var on: Array = []
	if v.contains("A"):
		on.append("SUPPORT_A")
	if v.contains("E"):
		on.append("SUPPORT_E")
	if v.contains("D"):
		on.append("SUPPORT_D")
	if v.contains("C"):
		on.append("CONDUCT")
	w.meta["on"] = on
	var failed := 0
	var seen_dead := {}
	for y in years:
		sim.run(12)
		for oid in w.table("org"):
			var o: Dictionary = w.table("org")[oid]
			if o["status"] in ["LIQUIDATION", "DISSOLVED"] and not seen_dead.has(oid) and not o["is_contractor"]:
				seen_dead[oid] = true
				failed += 1
		if (y + 1) % 10 != 0:
			continue
		var s := EconUtil.st(w)
		var lab := EconQuery.labour(w)
		var disp := 0
		var persons := 0
		for gid in w.table("hh"):
			var g: Dictionary = w.table("hh")[gid]
			disp += EconHouseholds.disposable(g)
			persons += EconHouseholds.persons(g)
		var pf := float(s["prices"]["FOOD"]) * (1.0 + float(EconRetail.margin_pm(w, "FOOD")) / 1000.0)
		var pc := float(s["prices"]["CONSUMER"]) * (1.0 + float(EconRetail.margin_pm(w, "CONSUMER")) / 1000.0)
		var basket := float(EconData.NEED["FOOD"]) * pf + float(EconData.NEED["CONSUMER_MIN"]) * pc
		var real := float(disp) / maxf(1.0, float(persons) / float(S) * basket)  # baskets per person per month
		var alive := 0
		for oid in w.table("org"):
			var o2: Dictionary = w.table("org")[oid]
			if o2["status"] in ["ACTIVE", "DISTRESSED", "ADMINISTRATION"] and not o2["is_contractor"] and o2["type"] in ["PRIVATE", "COOPERATIVE"]:
				alive += 1
		var shops := 0
		for d in EconRetail.summary(w):
			shops += int(EconRetail.summary(w)[d]["posts"])
		var vt := w.peek("violation_track")
		var v_all := vt.size()
		var v_unl := 0
		var v_rev := 0
		for k in vt:
			if bool(vt[k].get("unlawful", false)):
				v_unl += 1
			if bool(vt[k].get("revealed", false)):
				v_rev += 1
		var majors := 0
		for fx in w.facts.query("COMP_WORKPLACE_ACCIDENT"):
			if bool(fx["data"].get("crisis", false)):
				majors += 1
		print("   conduct: records %d unlawful %d revealed %d | major accidents %d" % [v_all, v_unl, v_rev, majors])
		print("%s seed %d Y%d pop %d lf %d u %.1f%% | offices %d sanit %d shops %d | real income %.2f | firms alive %d failed %d | food short %d‰ | default %s" % [
			v, sd, y + 1, PopStore.total(w), int(lab["labour_force"]), float(lab["rate_pct"]),
			int(EconOffice.summary(w)["posts_held"]), int(EconSanitation.summary(w)["posts"]), shops, real,
			alive, failed, int(s.get("food_shortfall", 0)), str(s.get("sovereign_default", false))])
	print("%s seed %d END ledger %d goods %s jobs %s" % [v, sd, w.ledger.total(), str(EconReport.goods_errors(w)), str(EconPop.check(w).size())])
	quit()

extends SceneTree
## Bob: public-services hole probe (Ella's v9 seed-1 Y2-Y3 hole). args: seed from_m to_m [flags]
## Monthly: clinics / schools / power / waterworks (count, mothballed, util, staff fill, condition), access means,
## utility supply/demand, treasury, health/education budgets and the institutions' cash.
func _plants(w: WorldState, ftype: String) -> String:
	var n := 0
	var moth := 0
	var util := 0
	var fill := 0.0
	var cond := 0
	var causes := {}
	for fid in EconUtil.sorted_keys(w.peek("facility")):
		var f: Dictionary = w.peek("facility")[fid]
		if f["type"] != ftype:
			continue
		n += 1
		if f["mothball"]:
			moth += 1
			continue
		util += int(f["util"])
		fill += EconFoodSec.labour_fill(f)
		for c in EconQuery.explain_facility(w, fid)["causes"]:
			var cn: String = c["cause"]
			causes[cn] = int(causes.get(cn, 0)) + 1
		cond += int(f["condition"]) / EconUtil.S
	var k := maxi(1, n - moth)
	return "%s %d/%d u%d f%.2f c%d %s" % [ftype.substr(0, 5), n - moth, n, util / k, fill / float(k), cond / k, JSON.stringify(causes)]


func _mean(d: Dictionary) -> int:
	var t := 0
	for k in d:
		t += int(d[k])
	return t / maxi(1, d.size())


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sim: Simulation = EconSim.make(int(a[0]), "BALANCED", {}, true)
	var w := sim.world
	if a.size() > 3 and a[3] != "base":
		for fl in a[3].split(","):
			if fl.begins_with("-"):
				(w.meta["on"] as Array).erase(fl.substr(1))
			elif not (w.meta["on"] as Array).has(fl):
				(w.meta["on"] as Array).append(fl)
	for m in int(a[2]):
		sim.run(1)
		if m + 1 < int(a[1]):
			continue
		var s := EconUtil.st(w)
		var sv := 0.0
		var nd := 0
		for d in s.get("util_served_hh", {}):
			var x: Array = s["util_served_hh"][d]
			sv += (float(x[0]) + float(x[1])) / 2.0
			nd += 1
		var inst := []
		for oid in EconUtil.sorted_keys(w.table("org")):
			var o: Dictionary = w.table("org")[oid]
			if o["type"] == "PUBLIC_INSTITUTION":
				inst.append("%s:%d" % [str(o.get("key", "?")).substr(0, 4), w.ledger.balance(EconUtil.acct(oid)) / 1000000])
		print("m%d hlth %d edu %d short %d rel %d | E %d/%d W %d/%d | treas %dM short %s | bud H%s Ed%s | %s" % [m + 1,
			_mean(s.get("health_access", {})) / 10, _mean(s.get("edu_access", {})) / 10, _mean(s.get("shortfall_d", {})) / 10,
			int(100.0 * sv / maxf(1.0, float(nd))),
			int(s.get("util_supply", {}).get("E", 0)) / 1000, int(s.get("util_demand", {}).get("E", 0)) / 1000,
			int(s.get("util_supply", {}).get("W", 0)) / 1000, int(s.get("util_demand", {}).get("W", 0)) / 1000,
			w.ledger.balance("gov:treasury") / 1000000000, str(s.get("treasury_short", false)),
			str(w.levers.get("ECON_BUDGET_HEALTH", "?")), str(w.levers.get("ECON_BUDGET_EDUCATION", "?")), " ".join(inst)])
		print("    ", _plants(w, "CLINIC"), " | ", _plants(w, "SCHOOL"), " | ", _plants(w, "POWER"), " | ", _plants(w, "WATERWORKS"))
	quit()

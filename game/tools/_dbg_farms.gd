extends SceneTree
## temp (Bob): farms in a failing state. args: seed year savedir on|off
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var path: String = a[2].path_join("farms_s%s_y%s_%s.save" % [a[0], a[1], a[3]])
	var sim: Simulation = EconSim.make(int(a[0]), "BALANCED", {}, true)
	if a[3] == "on":
		sim.world.meta["on"] = ["S7"]
	if FileAccess.file_exists(path):
		SaveIO.load_into(sim, path)
	else:
		sim.run(int(a[1]) * 12)
		SaveIO.save(sim, path)
	var w := sim.world
	sim.run(1)
	var s := EconUtil.st(w)
	print("food price %d unit_cost FARM %d | shortfall %d‰" % [int(s["prices"]["FOOD"]) / 1000, int(FirmAI.unit_cost(w, "FARM")) / 1000, int(s.get("food_shortfall", 0))])
	var orgs := {}
	for fid in EconUtil.sorted_keys(w.table("facility")):
		var f: Dictionary = w.table("facility")[fid]
		if f["type"] != "FARM":
			continue
		var oid: String = f["org"]
		var o: Dictionary = w.table("org")[oid]
		print(fid, " ", f["district"], " ", oid, " ", o["status"], " T=", f["T"], " mb=", f["mothball"], " out=", int(f.get("out_last", 0)) / 1000, " staff=", EconLabor.staff_total(f["staff"]) / 1000, " cond=", int(f["condition"]) / 1000, " in_cost=", f.get("_in_cost", "-"))
		orgs[oid] = true
	for oid in EconUtil.sorted_keys(orgs):
		var o: Dictionary = w.table("org")[oid]
		print(oid, " ", o["key"], " stock FOOD ", FirmAI._org_stock(w, oid, "FOOD") / 1000, " port ", EconUtil.inv_get(w, oid, "FOOD", "port") / 1000, " sales_ema ", int(o["sales_ema"].get("FOOD", 0)) / 1000, " sold ", int(o.get("sold", {}).get("FOOD", 0)) / 1000, " cash ", w.ledger.balance(EconUtil.acct(oid)) / 1000)
	var hh_want := 0; var hh_got := 0; var firm_want := 0
	for o2 in s.get("orders", []):
		if o2["good"] == "FOOD":
			if o2.get("kind", "") == "hh":
				hh_want += int(o2["qty"])
			else:
				firm_want += int(o2["qty"])
	for gid in w.table("hh"):
		hh_got += int(w.table("hh")[gid]["bought"].get("FOOD", 0))
	var offered := 0
	for of in s.get("offers", []):
		if of["good"] == "FOOD":
			offered += int(of["qty"])
	print("orders: hh want %d got %d | firm want %d | offers posted %d | food buyers %s" % [hh_want / 1000, hh_got / 1000, firm_want / 1000, offered / 1000, str(s.get("food_buyers_m", {}))])
	quit()

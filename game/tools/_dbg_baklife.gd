extends SceneTree
## Bob: monthly life of the first new private service hub after month args[1]. args: seed from_m months flags
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sim: Simulation = EconSim.make(int(a[0]), "BALANCED", {}, true)
	var w := sim.world
	if a[3] != "base":
		for fl in a[3].split(","):
			(w.meta["on"] as Array).append(fl)
	sim.run(int(a[1]))
	var seen := {}
	for fid in w.table("facility"):
		seen[fid] = true
	var hub := ""
	for m in int(a[2]):
		sim.run(1)
		if hub == "":
			for fid in EconUtil.sorted_keys(w.table("facility")):
				var f: Dictionary = w.table("facility")[fid]
				if not seen.has(fid) and f["type"] == "BAKERY" and w.table("org")[f["org"]]["type"] in ["PRIVATE", "COOPERATIVE"]:
					hub = fid
					break
			if hub == "":
				continue
		var f: Dictionary = w.table("facility")[hub]
		var oid: String = f["org"]
		var o: Dictionary = w.table("org")[oid]
		var ofid := EconOffice.office_of(w, oid)
		var ost := 0
		var oreq := 0
		if ofid != "":
			ost = EconLabor.staff_total(w.table("facility")[ofid]["staff"])
			for t in w.table("facility")[ofid].get("office_req", {}):
				oreq += int(w.table("facility")[ofid]["office_req"][t])
		var s := EconUtil.st(w)
		print("m%d %s %s %s st %s T%d util %d staff %d/%d office %d/%d ofill %.2f out %d sold %d spare %d price %d food %d cash %dk rev %dk wages %dk" % [w.month, hub, f["district"], o["status"], o["type"],
			int(f["T"]), int(f["util"]), EconLabor.staff_total(f["staff"]), _sum(EconLabor.required(f)), ost, oreq, EconOffice.office_fill(w, oid),
			int(f.get("out_last", 0)) / 1000, int(f.get("svc_sold", 0)) / 1000, int(f.get("svc_spare", 0)) / 1000, int(s["prices"]["FINE_FOOD"]),
			EconUtil.inv_get(w, oid, "FOOD", f["district"]) / 1000, w.ledger.balance(EconUtil.acct(oid)) / 1000000, int(o["pl_last"].get("rev", 0)) / 1000000, int(o["pl_last"].get("wages", 0)) / 1000000])
	quit()

func _sum(d: Dictionary) -> int:
	var t := 0
	for k in d:
		t += int(d[k])
	return t

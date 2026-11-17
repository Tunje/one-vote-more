extends SceneTree
## temp (Bob, backlog 18): a builder's state. args: seed year org on|off months
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sim: Simulation = EconSim.make(int(a[0]), "BALANCED", {}, true)
	var w := sim.world
	if a[3] == "on":
		w.meta["on"] = ["S7"]
	sim.run(int(a[1]) * 12)
	var oid: String = a[2]
	for m in int(a[4]):
		var o: Dictionary = w.table("org")[oid]
		var hq: String = o["hq"]
		var cs := []
		for pid in o["contracts"]:
			var p: Dictionary = w.table("project")[pid]
			cs.append("%s %s %s %d/%d unpaid %d start %d dur %d" % [pid, p["type"], p["status"], int(p["wu_done"]) / 1000, int(p["wu_total"]) / 1000, int(p["unpaid_m"]), int(p["start_month"]), int(p["bid_duration"])])
		var s := EconUtil.st(w)
		print("m%d %s %s key=%s cash %d cap %d crew %d target %s mat %d comp %d blocked %s | MATERIAL price %d COMPONENT %d | contracts %s" % [w.month, oid, o["status"], o["key"],
			w.ledger.balance(EconUtil.acct(oid)) / 1000, EconConstruction.capacity(w, oid) / 1000, EconLabor.staff_total(o["crew"]) / 1000, str(o["crew_target"]),
			EconUtil.inv_get(w, oid, "MATERIAL", hq) / 1000, EconUtil.inv_get(w, oid, "COMPONENT", hq) / 1000, str(o.get("blocked_last", false)),
			int(s["prices"]["MATERIAL"]) / 1000, int(s["prices"]["COMPONENT"]) / 1000, str(cs)])
		sim.run(1)
	quit()

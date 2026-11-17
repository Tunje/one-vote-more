extends SceneTree
## temp (Bob, v6 review P0): trace the utility balance in sustained outages. args: seed months
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sd := int(a[0]) if a.size() > 0 else 1
	var months := int(a[1]) if a.size() > 1 else 360
	var sim: Simulation = EconSim.make(sd, "BALANCED", {}, true)
	var w := sim.world
	var printed := 0
	var streak := 0
	for m in months:
		sim.run(1)
		var s := EconUtil.st(w)
		var sup: Dictionary = s.get("util_supply", {})
		var dem: Dictionary = s.get("util_demand", {})
		var e_s := int(sup.get("E", 0)); var e_d := int(dem.get("E", 0)); var w_s := int(sup.get("W", 0)); var w_d := int(dem.get("W", 0))
		var out := e_s < e_d * 98 / 100 or w_s < w_d * 98 / 100
		streak = streak + 1 if out else 0
		if m == 0:
			for fid in w.table("facility"):
				if w.table("facility")[fid]["type"] == "POWER":
					print("POWER keys: ", w.table("facility")[fid].keys())
					break
		if not out or (streak > 3 and streak % 12 != 0) or printed > 40:
			continue
		printed += 1
		var cpw := EconFinance.org_by_key(w, "CPW")
		print("m%d streak=%d E %d/%d W %d/%d  CPW cash=%d status=%s" % [w.month, streak, e_s / 1000, e_d / 1000, w_s / 1000, w_d / 1000, w.ledger.balance(EconUtil.acct(cpw)) / 1000, w.table("org")[cpw]["status"]])
		for fid in EconUtil.sorted_keys(w.table("facility")):
			var f: Dictionary = w.table("facility")[fid]
			if f["type"] in ["POWER", "WATERWORKS"]:
				print("   ", fid, " ", f["type"], " ", f["district"], " org=", f["org"], " T=", f.get("T", 0), " mb=", f.get("mothball", false), " cond=", f.get("condition", -1), " scale=", f.get("scale", 1000), " staff=", f.get("staff", f.get("workers", "?")), " broken=", f.get("broken", f.get("down_m", "")))
		for pid in EconUtil.sorted_keys(w.table("project")):
			var p: Dictionary = w.table("project")[pid]
			if p["status"] != "DONE" and p["status"] != "CANCELLED" and (p["type"] in ["POWER", "WATERWORKS", "UPGRADE", "EXPAND", "REPAIR"] or str(p.get("target", "")) != ""):
				print("   proj ", pid, " ", p["type"], " ", p["district"], " owner=", p["owner"], " st=", p["status"], " wu=", p["wu_done"] / 1000, "/", p["wu_total"] / 1000, " t=", p["tender_month"], " fails=", p.get("tenders_failed", 0))
	quit()

extends SceneTree
## temp (Bob): why are service hubs mothballed? args: seed year dir
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sd := int(a[0]); var yr := int(a[1]); var dir: String = a[2]
	var path := dir.path_join("seed%d_y%d.save" % [sd, yr])
	var sim: Simulation = EconSim.make(sd, "BALANCED", {}, true)
	if FileAccess.file_exists(path):
		SaveIO.load_into(sim, path)
	else:
		sim.run(yr * 12)
		SaveIO.save(sim, path)
	var w := sim.world
	var s := EconUtil.st(w)
	print("svc_price ", s.get("svc_price", {}))
	print("u ", FirmAI.colony_unemployment(w), "  unit_cost SERVICEHUB ", FirmAI.unit_cost(w, "SERVICEHUB"))
	for fid in EconUtil.sorted_keys(w.table("facility")):
		var f: Dictionary = w.table("facility")[fid]
		if f["type"] in ["SERVICEHUB", "CONSUMERF"]:
			var o: Dictionary = w.table("org").get(f["org"], {})
			print(fid, " ", f["type"], " ", f["district"], " org=", f["org"], " ", o.get("status", "?"), " mb=", f["mothball"], " T=", f["T"], " sold=", f.get("svc_sold", "-"), " low_m=", f.get("low_util_m", 0), " closed_unsafe=", f.get("closed_unsafe", false), " law_closed=", f.get("law_closed", false), " abandoned=", f.get("abandoned", false), " staff=", EconLabor.staff_total(f["staff"]) / 1000)
	quit()

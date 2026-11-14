extends SceneTree
## Bob: export ships. args: seed years. Per ship: consigned port stock vs hold, cargo, value; at each ship the goods
## whose net home price beats the local price by the export margin (eligible) and the port capacity.
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sim: Simulation = EconSim.make(int(a[0]), "BALANCED", {}, true)
	var w := sim.world
	var nships := 0
	var port_before := 0
	for m in int(a[1]) * 12:
		var held := 0
		for oid in w.peek("org"):
			for g in EconTrade.EXPORT_GOODS:
				held += EconUtil.inv_get(w, oid, g, EconTrade.PORT)
		port_before = held
		var px := EconTrade.prices(w)
		sim.run(1)
		var t: Dictionary = EconUtil.st(w).get("trade", {})
		var ships: Array = t.get("ships", [])
		if ships.size() > nships:
			nships = ships.size()
			var r: Dictionary = ships[ships.size() - 1]
			var cargo := 0
			for g in r["exports"]:
				cargo += int(r["exports"][g])
			var elig := []
			for g in EconTrade.EXPORT_GOODS:
				var p: Dictionary = px[g]
				elig.append("%s %d/%d%s" % [g.substr(0, 4), int(p["net"]) / 1000, int(p["local"]) / 1000, "*" if float(p["net"]) >= EconTrade.EXPORT_MARGIN * float(p["local"]) else ""])
			print("Y%d ship: port held %d (cap %d, hold %d) cargo %d value %dk tax %dk imports %dk | net/local %s" % [m / 12 + 1, port_before / 1000, EconTrade.port_capacity(w), EconTrade.ship_hold(w), cargo,
				int(r["export_value"]) / 1000000, int(r["tax"]) / 1000000, int(r["import_value"]) / 1000000, " ".join(elig)])
	quit()

extends SceneTree
## Bob: public enterprises' yearly P&L (rev, wages, cogs, other, subsidy) and cash. args: seed years flags
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sim: Simulation = EconSim.make(int(a[0]), "BALANCED", {}, true)
	var w := sim.world
	if a[2] != "base":
		for fl in a[2].split(","):
			(w.meta["on"] as Array).append(fl)
	for m in int(a[1]) * 12:
		sim.run(1)
		if m % 12 != 11 or (m / 12 + 1) % 2 != 0:
			continue
		var line := "Y%d" % (m / 12 + 1)
		for oid in EconUtil.sorted_keys(w.table("org")):
			var o: Dictionary = w.table("org")[oid]
			if o["type"] != "PUBLIC_ENTERPRISE":
				continue
			var p := EconAnnual.sum12(o)
			var M := 1000000000
			var other := int(p.get("util", 0)) + int(p.get("freight", 0)) + int(p.get("rent", 0)) + int(p.get("interest", 0)) + int(p.get("royalty", 0)) + int(p.get("dep", 0))
			line += " | %s rev %d w %d c %d o %d sub %d cash %d" % [str(o.get("key", oid)).substr(0, 4), int(p.get("rev", 0)) / M, int(p.get("wages", 0)) / M, int(p.get("cogs", 0)) / M, other / M, int(p.get("subsidy", 0)) / M, w.ledger.balance(EconUtil.acct(oid)) / M]
		print(line)
	quit()

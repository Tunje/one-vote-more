extends SceneTree
## Government cash flow by memo over months [a, b) (debugging aid).
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var a := int(args[0]) if args.size() > 0 else 12
	var b := int(args[1]) if args.size() > 1 else 24
	var sim := EconSim.make(1, "BALANCED", {}, true)
	var out := {}
	var inn := {}
	for m in b:
		sim.step()
		if m < a:
			continue
		for e in sim.world.ledger.journal:
			if e["m"] != m:
				continue
			if e["from"] == EconUtil.TREASURY:
				var k: String = e["memo"] + " -> " + e["to"].split(":")[0]
				out[k] = out.get(k, 0) + e["amt"]
			elif e["to"] == EconUtil.TREASURY:
				inn[e["memo"]] = inn.get(e["memo"], 0) + e["amt"]
	print("OUT (k cr over %d months):" % (b - a))
	for k in out:
		print("  %-40s %8d" % [k, out[k] / 1000000])
	print("IN:")
	for k in inn:
		print("  %-40s %8d" % [k, inn[k] / 1000000])
	quit(0)

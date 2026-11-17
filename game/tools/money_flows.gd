extends SceneTree
## Bob (A61 M1): money crossing the colony's border, by channel, per year. Reads the ledger journal (kept 24 months):
## transfers from EXTERNAL (money in) and to EXTERNAL (money out), grouped by memo; every year and a 50-year total.
## Usage: ... -- <seed> <years> [econ]  (econ = make_econ_only, no politics)
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sd := int(a[0])
	var years := int(a[1])
	var sim: Simulation = EconSim.make_econ_only(sd) if a.size() > 2 and a[2] == "econ" else GameSim.make(sd, "BALANCED", {}, true)
	var w := sim.world
	var tot_in := {}
	var tot_out := {}
	for y in years:
		sim.run(12)
		var lo := w.month - 12
		var fin := {}
		var fout := {}
		for e in w.ledger.journal:
			if int(e["m"]) < lo:
				continue
			if e["from"] == "EXTERNAL" and e["to"] != "EXTERNAL":
				fin[e["memo"]] = int(fin.get(e["memo"], 0)) + int(e["amt"])
			elif e["to"] == "EXTERNAL" and e["from"] != "EXTERNAL":
				fout[e["memo"]] = int(fout.get(e["memo"], 0)) + int(e["amt"])
		var si := 0
		var so := 0
		for k in fin:
			si += int(fin[k])
			tot_in[k] = int(tot_in.get(k, 0)) + int(fin[k])
		for k in fout:
			so += int(fout[k])
			tot_out[k] = int(tot_out.get(k, 0)) + int(fout[k])
		if (y + 1) % 5 == 0:
			print("Y%d in %dk out %dk net %dk | money stock %dM | pop %d" % [y + 1, si / 1000000, so / 1000000, (si - so) / 1000000, -w.ledger.balance("EXTERNAL") / 1000000, PopStore.total(w)])
	print("TOTAL IN by channel (M):")
	for k in _by_size(tot_in):
		print("   %-28s %8d" % [k, int(tot_in[k]) / 1000000])
	print("TOTAL OUT by channel (M):")
	for k in _by_size(tot_out):
		print("   %-28s %8d" % [k, int(tot_out[k]) / 1000000])
	quit()


func _by_size(d: Dictionary) -> Array:
	var ks := d.keys()
	ks.sort_custom(func(x, y): return int(d[x]) > int(d[y]) or (int(d[x]) == int(d[y]) and str(x) < str(y)))
	return ks

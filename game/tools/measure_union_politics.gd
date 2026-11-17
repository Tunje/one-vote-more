extends SceneTree
## Acceptance for unions in politics (spec-unions-v1 §6, owner Ella): endorsements move between parties over a
## century (betrayal works), union money flows, the ledger stays closed.
##   godot --headless --path game --script res://tools/measure_union_politics.gd -- <months> <seed>
const EconSim := preload("res://sim/economy/econ_sim.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var months := int(args[0]) if args.size() > 0 else 1200
	var seed_v := int(args[1]) if args.size() > 1 else 1
	var sim: Simulation = EconSim.make(seed_v, "BALANCED", {}, true)
	sim.run(months)
	var w := sim.world
	var pname := func(pid: String) -> String: return String(w.peek("party").get(pid, {}).get("name", pid))
	var uname := func(uid: String) -> String: return String(w.peek("union").get(uid, {}).get("name", uid))
	var per := {}
	for f in w.facts.query("UNION_ENDORSED"):
		var u: String = uname.call(String(f["data"]["union"]))
		var r: Dictionary = per.get(u, {"parties": [], "changes": 0, "betrayed": 0, "dropped": 0, "money": 0, "path": []})
		var pn: String = pname.call(String(f["data"]["party"]))
		if not pn in r["parties"]:
			r["parties"].append(pn)
		r["changes"] += 1
		r["path"].append("Y%d %s" % [int(f["month"]) / 12, pn])
		per[u] = r
	for f in w.facts.query("UNION_ENDORSEMENT_WITHDRAWN"):
		var u: String = uname.call(String(f["data"]["union"]))
		var r: Dictionary = per.get(u, {"parties": [], "changes": 0, "betrayed": 0, "dropped": 0, "money": 0, "path": []})
		if f["data"]["reason"] == "BETRAYAL":
			r["betrayed"] += 1
			r["path"].append("Y%d BETRAYED by %s" % [int(f["month"]) / 12, pname.call(String(f["data"]["party"]))])
		else:
			r["dropped"] += 1
		per[u] = r
	for f in w.facts.query("POL_DONATION"):
		if String(f["data"].get("donor_kind", "")) == "UNION":
			var u: String = uname.call(String(f["data"]["donor"]))
			var r: Dictionary = per.get(u, {"parties": [], "changes": 0, "betrayed": 0, "dropped": 0, "money": 0, "path": []})
			r["money"] += int(f["data"]["amount"]) / 1000
			per[u] = r
	print("== seed %d, %d months" % [seed_v, months])
	var multi := 0
	for u in Det_sorted(per):
		var r: Dictionary = per[u]
		if r["parties"].size() >= 2:
			multi += 1
		print("  %-28s parties %d  endorsements %d  betrayals %d  no-match %d  money %d" % [u, r["parties"].size(), r["changes"], r["betrayed"], r["dropped"], r["money"]])
		print("      " + ", ".join(PackedStringArray(r["path"].slice(0, 14))))
	print("unions that backed 2+ parties: %d of %d" % [multi, per.size()])
	quit(0)


func Det_sorted(d: Dictionary) -> Array:
	var k := d.keys()
	k.sort()
	return k

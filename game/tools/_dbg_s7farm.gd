extends SceneTree
## temp (Bob, backlog 18): why S7 freezes farm building. args: seed from_year to_year on|off
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sim: Simulation = EconSim.make(int(a[0]), "BALANCED", {}, true)
	var w := sim.world
	if a.size() > 3 and a[3] == "on":
		w.meta["on"] = ["S7"]
	sim.run(int(a[1]) * 12)
	for y in range(int(a[1]), int(a[2]) + 1):
		var s := EconUtil.st(w)
		var n := 0; var mb := 0; var out := 0; var cap := 0; var staff := 0; var req := 0; var tsum := 0
		for fid in w.table("facility"):
			var f: Dictionary = w.table("facility")[fid]
			if f["type"] != "FARM":
				continue
			n += 1
			if f["mothball"]:
				mb += 1
				continue
			out += int(f.get("out_last", 0))
			cap += int(float(EconData.RECIPES["FARM"]["out"][1]) * 1000.0 * EconUtil.fscale(f))
			staff += EconLabor.staff_total(f["staff"])
			var r := EconLabor.required(f)
			for t in r:
				req += int(r[t])
			tsum += int(f["T"])
		var need := 0; var bought := 0
		for gid in w.table("hh"):
			var g: Dictionary = w.table("hh")[gid]
			need += int(EconHouseholds.persons(g) * EconData.NEED["FOOD"])
			bought += int(g["bought"].get("FOOD", 0))
		var projs := []
		for pid in EconUtil.sorted_keys(w.table("project")):
			var p: Dictionary = w.table("project")[pid]
			if p["type"] == "FARM" and p["status"] in ["TENDER", "TENDERABLE", "ACTIVE"]:
				var c: String = p["contractor"]
				var co: Dictionary = w.table("org").get(c, {})
				projs.append("%s %s:%s %d/%d c=%s %s listed=%s unpaid=%d arrears=%d line=%s headroom=%d" % [pid, p["owner"], p["status"], int(p["wu_done"]) / 1000, int(p["wu_total"]) / 1000,
					c, co.get("status", "GONE"), str(co.get("contracts", []).has(pid)), int(p["unpaid_m"]), int(p.get("arrears", 0)) / 1000, p["line"],
					EconActions.headroom(w, p["line"]) / 1000 if p["line"] != "" else -1])
		var e := EconEssentials.measure(w)
		print("Y%d farms %d (mb %d) T_avg %d staff %d/%d out %d cap %d | hh need %d bought %d | firms bought %s | food price %d | entry FARM %d | margin %d%% | farm projects %s | u %.1f%% | slums %s" % [y,
			n, mb, tsum / maxi(1, n - mb), staff / 1000, req / 1000, out / 1000, cap / 1000, need / 1000, bought / 1000,
			str(s.get("food_buyers_m", {})), int(s["prices"]["FOOD"]) / 1000, int(s.get("entry_signal", {}).get("FARM", 0)), int(e["FOOD"]["margin_pct"]), str(projs),
			100.0 * FirmAI.colony_unemployment(w), str(EconCohorts.slums(w))])
		sim.run(12)
	quit()

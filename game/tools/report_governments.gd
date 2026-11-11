extends SceneTree
## Per-term government report: who governed, approval over the term, laws passed, policy changes,
## concern satisfaction, and how voters judged the incumbents at the next election.
##   godot --headless --path game --script res://tools/report_governments.gd

const PERSONAS := {
	"LEFT": {"REDISTRIBUTION": 70, "LABOR": 60, "ENVIRONMENT": 40, "ECON_ROLE": 50, "FISCAL": 40},
	"RIGHT": {"REDISTRIBUTION": -70, "LABOR": -60, "ENVIRONMENT": -30, "ECON_ROLE": -60, "FISCAL": -50},
}
const SHORT := {"STUB_INCOME_TAX": "IncTax", "STUB_CORP_TAX": "CorpTax", "STUB_WELFARE": "Welfare",
	"STUB_PUBLIC_INVESTMENT": "Invest", "STUB_ENV_STANDARD": "EnvStd", "STUB_LABOR_PROTECTION": "LabProt",
	"STUB_DISTRICT_AUTONOMY": "Autonomy"}


func _initialize() -> void:
	for scenario in ["BALANCED", "RECESSION"]:
		for pname in PERSONAS:
			_run(scenario, pname)
	quit(0)


func _run(scenario: String, pname: String) -> void:
	var sim := PoliticalSim.make(1, scenario, PERSONAS[pname])
	var w := sim.world
	var terms: Array = []      # {start, gov_label, members, approval[], levers_start, sat_start}
	var cur := {}
	var last_formed := -1
	for m in 240:
		sim.step()
		var st: Dictionary = w.table("pol")["state"]
		var appr := w.indicators.read("POL_GOV_APPROVAL") / 1000.0
		var g: Dictionary = st["government"]
		var formed: int = g.get("formed_month", -1) if not g.is_empty() else -1
		if formed != last_formed or (m == 0):
			if not cur.is_empty():
				_close(w, cur)
				terms.append(cur)
			last_formed = formed
			cur = {"start": w.month - 1, "members": g.get("members", []) if not g.is_empty() else [],
				"pm": g.get("pm_party", ""), "seats": g.get("yes", 0), "approval": [],
				"levers_start": w.levers.duplicate(), "sat_start": _sat(w), "bills_before": _bills(w)}
		cur["approval"].append(appr)
	_close(w, cur)
	terms.append(cur)

	print("\n================ %s, commander %s ================" % [scenario, pname])
	for i in terms.size():
		var t: Dictionary = terms[i]
		var label := "Commander (founding era)" if t["members"].is_empty() else " + ".join(t["members"].map(func(pid): return _pn(w, pid)))
		var a: Array = t["approval"]
		print("Term %d  m%d-m%d  %s%s" % [i + 1, t["start"], t["end"], label,
			"" if t["members"].is_empty() else "  [%d seats%s]" % [t["seats"], ", minority" if t["seats"] < 76 else ""]])
		print("   approval: start %.0f%%, low %.0f%%, end %.0f%% | bills passed %d, defeated %d" % [a[0], a.min(), a[-1], t["passed"], t["defeated"]])
		print("   policy: %s" % t["policy"])
		print("   satisfaction change: %s" % t["sat_delta"])
		if i + 1 < terms.size() and not t["members"].is_empty():
			print("   verdict at next election: %s" % _verdict(w, t))


func _close(w: WorldState, t: Dictionary) -> void:
	t["end"] = w.month - 1
	var b := _bills(w)
	t["passed"] = b[0] - t["bills_before"][0]
	t["defeated"] = b[1] - t["bills_before"][1]
	var ch: Array = []
	for lid in SHORT:
		var d: int = int(w.levers[lid]) - int(t["levers_start"][lid])
		if d != 0:
			ch.append("%s %+d" % [SHORT[lid], d])
	t["policy"] = ", ".join(ch) if not ch.is_empty() else "no effective changes"
	var s1 := _sat(w)
	var parts: Array = []
	for c in s1:
		var d: float = s1[c] - t["sat_start"][c]
		if absf(d) >= 3.0:
			parts.append("%s %+.0f" % [c, d])
	t["sat_delta"] = ", ".join(parts) if not parts.is_empty() else "flat (all within ±3)"


func _verdict(w: WorldState, t: Dictionary) -> String:
	# find elections just before and just after the term end
	var els: Array = w.table("pol")["state"]["elections"]
	var before := {}
	var after := {}
	for eid in els:
		var e: Dictionary = w.table("election")[eid]
		if e["month"] <= t["start"] + 1:
			before = e
		elif e["month"] <= t["end"] + 1 and after.is_empty():
			after = e
	if after.is_empty() or before.is_empty():
		return "n/a"
	var out: Array = []
	for pid in t["members"]:
		var v0: float = 100.0 * before["votes"].get(pid, 0) / maxf(1.0, before["total"])
		var v1: float = 100.0 * after["votes"].get(pid, 0) / maxf(1.0, after["total"])
		out.append("%s %.1f%% -> %.1f%% (%+.1f)" % [_pn(w, pid), v0, v1, v1 - v0])
	return "; ".join(out)


func _sat(w: WorldState) -> Dictionary:
	var out := {}
	var tp := 0.0
	for c in PolDefs.CONCERNS:
		out[c] = 0.0
	for cell in w.table("cell").values():
		tp += cell["pop"]
		for c in PolDefs.CONCERNS:
			out[c] += float(cell["sat"][c]) / 1000.0 * cell["pop"]
	for c in out:
		out[c] = out[c] / maxf(1.0, tp)
	return out


func _bills(w: WorldState) -> Array:
	var p := 0
	var d := 0
	for b in w.table("bill").values():
		if b["status"] == "PASSED": p += 1
		elif b["status"] == "DEFEATED": d += 1
	return [p, d]


func _pn(w: WorldState, pid: String) -> String:
	var p: Dictionary = w.table("party")[pid]
	return p["name"] + ("*" if p["is_player"] else "")

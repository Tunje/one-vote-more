extends SceneTree
## A52 bias audit (planning/audit-bias-v1.md), one game: records every Cabinet (First Minister's party centre,
## months, the economy at start and end), every party-year (positions, support, seats, governing, donations, press
## tilt) and every POL_POLICY_EVIDENCE fact. With "mirror" the whole political space is mirrored from the start
## (world.meta.mirror: voters' base ideology negated on every axis), so the mirror test compares like with like.
##   godot --headless --path game --script res://tools/audit_outcomes.gd -- <seed> <years> <normal|mirror> <out.json>

const AXES := ["ECON_ROLE", "REDISTRIBUTION", "LABOR", "ENVIRONMENT", "AUTONOMY", "FISCAL", "INSTITUTIONS", "SOVEREIGNTY"]
const IND := ["ECON_UNEMPLOYMENT_RATE", "ECON_REAL_INCOME_INDEX", "ECON_PUBLIC_DEBT_RATIO", "ECON_POLLUTION_INDEX",
	"POL_GOV_APPROVAL", "ECON_CPI_INFLATION"]

var w: WorldState


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var seed_v := int(a[0]) if a.size() > 0 else 1
	var years := int(a[1]) if a.size() > 1 else 60
	var mode := String(a[2]) if a.size() > 2 else "normal"
	var out := String(a[3]) if a.size() > 3 else "user://audit.json"
	var sim: Simulation = EconSim.make(seed_v, "BALANCED", {}, true)
	w = sim.world
	if mode == "mirror":
		w.meta["mirror"] = true
	var cabinets: Array = []
	var cur := {}
	var party_years := {}
	var evidence: Array = []
	var donations := {}
	for m in years * 12:
		sim.step()
		var st: Dictionary = w.peek("pol").get("state", {})
		var g: Dictionary = st.get("government", {})
		var pm := String(g.get("pm_party", ""))
		var key := "%s|%s" % [pm, str(g.get("members", []))]
		if pm != "" and (cur.is_empty() or cur["key"] != key):
			if not cur.is_empty():
				_close(cur, m)
				cabinets.append(cur)
			var p: Dictionary = w.peek("party").get(pm, {})
			cur = {"key": key, "pm": pm, "pm_name": String(p.get("name", "")), "members": g.get("members", []).duplicate(),
				"start": m, "pos": _pos(p), "centre": _centre(g), "ind0": _inds(), "elections_won": 0}
		for f in w.facts.query("POL_POLICY_EVIDENCE", w.month - 1, w.month - 1):
			evidence.append(f.get("data", {}))
		for f in w.facts.query("POL_DONATION", w.month - 1, w.month - 1):
			var d: Dictionary = f.get("data", {})
			var pid := String(d.get("party", ""))
			donations[pid] = int(donations.get(pid, 0)) + int(d.get("amount", 0))
		if (m + 1) % 12 == 0:
			var tilt := _press_tilt()
			for p in PartyLife.active(w):
				var pid := String(p["id"])
				var y := (m + 1) / 12
				party_years["%s|%d" % [pid, y]] = {"party": pid, "name": String(p["name"]), "year": y, "pos": _pos(p),
					"support": int(p.get("support", 0)), "seats": int(p.get("seats", 0)), "kind": String(p.get("kind", "")),
					"pm": pid == pm, "cabinet": pid in g.get("members", []), "donations": int(donations.get(pid, 0)),
					"press": float(tilt.get(pid, 0.0))}
			donations.clear()
			if (m + 1) % 120 == 0:
				print("year %d" % ((m + 1) / 12))
	if not cur.is_empty():
		_close(cur, years * 12)
		cabinets.append(cur)
	var res := {"seed": seed_v, "years": years, "mode": mode, "cabinets": cabinets, "party_years": party_years.values(),
		"evidence": evidence}
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(res))
	f.close()
	print("AUDIT_DONE %s" % out)
	quit(0)


func _close(c: Dictionary, m: int) -> void:
	c["end"] = m
	c["months"] = m - int(c["start"])
	c["ind1"] = _inds()


func _pos(p: Dictionary) -> Dictionary:
	var out := {}
	for ax in AXES:
		out[ax] = int(p.get("positions", {}).get(ax, 0))
	return out


func _centre(g: Dictionary) -> Dictionary:
	var out := {}
	for ax in AXES:
		out[ax] = int(g.get("center", {}).get(ax, 0))
	return out


func _inds() -> Dictionary:
	var out := {}
	for id in IND:
		if w.indicators.values.has(id):
			out[id] = _colony_value(id)
	return out


func _colony_value(id: String) -> float:
	var vals: Dictionary = w.indicators.values[id]
	if vals.has("COLONY"):
		return float(vals["COLONY"]) / 1000.0
	var num := 0.0
	var den := 0.0
	for c in PolVoters.all(w):
		var k := String(c["district"])
		if vals.has(k):
			num += float(vals[k]) * float(c["pop"])
			den += float(c["pop"])
	return num / den / 1000.0 if den > 0.0 else 0.0


## Circulation-weighted press tilt per party: + = the press leans toward it (closer line), - = against.
func _press_tilt() -> Dictionary:
	var out := {}
	var outlets: Dictionary = w.peek("outlet")
	var total := 0.0
	for oid in outlets:
		total += float(outlets[oid].get("circulation", 0))
	if total <= 0.0:
		return out
	for p in PartyLife.active(w):
		var t := 0.0
		for oid in outlets:
			var o: Dictionary = outlets[oid]
			var d := 0.0
			for ax in AXES:
				d += absf(float(o.get("line", {}).get(ax, 0)) - float(p.get("positions", {}).get(ax, 0)))
			t += float(o.get("circulation", 0)) / total * -d / float(AXES.size()) / 1000.0
		out[p["id"]] = t
	return out

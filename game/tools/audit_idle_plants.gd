extends SceneTree
## Wilma (user 2026-11-15, after Bob's MATERIAL finding: "check every company type and its facilities for this type of
## error"): plants that make far less than they could while the thing they make is short.
## For every owner type × facility type, sampled every 6 months from year 5: how many plants, their output target (T),
## how hard they actually ran (util), crew against the recipe's full crew, and for what they make: how often it was
## short, and its price against the plant type's unit cost. A row is flagged when plants ran under 60% on average
## while their output was short in at least a third of the samples.
## Usage: godot --headless --path game --script res://tools/audit_idle_plants.gd -- <seed> <years>
const S := EconUtil.S


func _shortage(w: WorldState, s: Dictionary, ftype: String, good: String, district: String) -> float:
	# share of demand not met (0..1) for what this plant type makes; -1 when there is no measure
	if good in EconData.MARKET_GOODS:
		var m: Dictionary = (s.get("market_stats", {}) as Dictionary).get(good, {})
		var wanted := float(m.get("wanted", 0))
		return -1.0 if wanted <= 0.0 else clampf((wanted - float(m.get("filled", 0))) / wanted, 0.0, 1.0)
	match ftype:
		"POWER":
			return 1.0 - float((s.get("util_served_hh", {}) as Dictionary).get(district, [1.0, 1.0])[0])
		"WATERWORKS":
			return 1.0 - float((s.get("util_served_hh", {}) as Dictionary).get(district, [1.0, 1.0])[1])
		"CLINIC":
			return 1.0 - clampf(float((s.get("health_access", {}) as Dictionary).get(district, 1000)) / 1000.0, 0.0, 1.0)
		"SCHOOL":
			return 1.0 - clampf(float((s.get("edu_access", {}) as Dictionary).get(district, 1000)) / 1000.0, 0.0, 1.0)
	return -1.0


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sd := int(a[0])
	var years := int(a[1])
	var sim: Simulation = EconSim.make(sd, "BALANCED", {}, true)
	var w := sim.world
	var rows := {}   # "owner|ftype" -> accumulators
	for m in years * 12:
		sim.run(1)
		if m < 60 or m % 6 != 5:
			continue
		var s: Dictionary = EconUtil.peek_st(w)
		for fid in w.peek("facility"):
			var f: Dictionary = w.peek("facility")[fid]
			var o: Dictionary = w.peek("org").get(f["org"], {})
			if o.is_empty() or not EconData.RECIPES.has(f["type"]):
				continue
			var r: Dictionary = EconData.RECIPES[f["type"]]
			var good := String(r["out"][0])
			var k := "%s|%s" % [String(o.get("type", "?")) + ("/family" if bool(o.get("family", false)) else ""), f["type"]]
			var row: Dictionary = rows.get(k, {"n": 0, "moth": 0, "t": 0.0, "u": 0.0, "crew": 0.0, "low": 0, "sold_out": 0, "short_n": 0, "short": 0.0,
				"short5": 0, "pc": 0.0, "pc_n": 0, "good": good, "idle_short": 0})
			if bool(f.get("mothball", false)):
				row["moth"] += 1
				rows[k] = row
				continue
			var full := 0.0
			for t in r["labor"]:
				full += float(r["labor"][t])
			full *= float(S) * EconUtil.fscale(f)
			var util := float(f.get("util", 0)) / 1000.0
			row["n"] += 1
			row["t"] += float(f.get("T", 0)) / 1000.0
			row["u"] += util
			row["crew"] += 0.0 if full <= 0.0 else float(EconLabor.staff_total(f.get("staff", {}))) / full
			if int(f.get("T", 0)) <= 300:
				row["low"] += 1
			var sh := _shortage(w, s, String(f["type"]), good, String(f["district"]))
			if f["type"] == "SERVICEHUB":
				sh = 1.0 if int(f.get("svc_spare", 1)) <= 0 and int(f.get("out_last", 0)) > 0 else 0.0   # sold out: customers were turned away
				row["sold_out"] += int(sh)
			if sh >= 0.0:
				row["short_n"] += 1
				row["short"] += sh
				if sh > 0.05:
					row["short5"] += 1
					if util < 0.6:
						row["idle_short"] += 1
			if good in EconData.MARKET_GOODS:
				var uc := FirmAI.unit_cost(w, String(f["type"]))
				if uc > 0.0:
					row["pc"] += float(s["prices"].get(good, 0)) / uc
					row["pc_n"] += 1
			rows[k] = row
	print("AUDIT seed %d, %d years, on: %s" % [sd, years, str(w.meta.get("on", []))])
	print("owner|type|makes|plant-samples|mothballed|target%|ran%|crew%|at_or_under_30%_target|short_share%|samples_short>5%|idle(<60%)_while_short|price/cost|FLAG")
	for k in EconUtil.sorted_keys(rows):
		var r2: Dictionary = rows[k]
		var n := float(maxi(1, int(r2["n"])))
		var sn := float(maxi(1, int(r2["short_n"])))
		var flag := ""
		if int(r2["short_n"]) > 0 and float(r2["u"]) / n < 0.6 and float(r2["short5"]) / sn >= 0.33:
			flag = "IDLE WHILE SHORT"
		print("%s|%s|%d|%d|%.0f|%.0f|%.0f|%.0f|%s|%s|%s|%s|%s" % [k, r2["good"], r2["n"], r2["moth"], 100.0 * float(r2["t"]) / n, 100.0 * float(r2["u"]) / n,
			100.0 * float(r2["crew"]) / n, 100.0 * float(r2["low"]) / n,
			("%.1f" % (100.0 * float(r2["short"]) / sn)) if int(r2["short_n"]) > 0 else "-",
			("%.0f" % (100.0 * float(r2["short5"]) / sn)) if int(r2["short_n"]) > 0 else "-",
			("%.0f" % (100.0 * float(r2["idle_short"]) / sn)) if int(r2["short_n"]) > 0 else "-",
			("%.2f" % (float(r2["pc"]) / float(maxi(1, int(r2["pc_n"]))))) if int(r2["pc_n"]) > 0 else "-", flag])
	quit()

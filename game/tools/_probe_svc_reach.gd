extends SceneTree
## Wilma (user: "do other districts shop at other districts when no supplier exists in theirs?" -> "look into it"):
## how far service hubs reach. Households buy services only in their own district and direct neighbours (+10%).
## Per district, yearly means: population, hubs in reach, services price vs base, spare hub capacity in reach vs
## elsewhere, and how many of the district's commuters work in a district whose hubs had spare capacity.
## args: seed years
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sim: Simulation = EconSim.make(int(a[0]), "BALANCED", {}, true)
	var w := sim.world
	var years := int(a[1])
	var acc := {}
	for m in years * 12:
		sim.run(1)
		var s: Dictionary = EconUtil.peek_st(w)
		var hubs := {}
		var spare := {}
		for fid in w.peek("facility"):
			var f: Dictionary = w.peek("facility")[fid]
			if f["type"] == "SERVICEHUB":
				hubs[f["district"]] = int(hubs.get(f["district"], 0)) + 1
				spare[f["district"]] = int(spare.get(f["district"], 0)) + int(f.get("svc_spare", 0))
		var pop := {}
		for gid in w.peek("hh"):
			var g: Dictionary = w.peek("hh")[gid]
			pop[g["district"]] = int(pop.get(g["district"], 0)) + EconHouseholds.persons(g) / EconUtil.S
		var commute := {}   # home d -> [all commuters, commuters to a district with spare hub capacity outside reach]
		for r in s.get("commute_rows", []):
			var fd := String(r["from_d"])
			var td := String(r["to_d"])
			var c: Array = commute.get(fd, [0, 0])
			c[0] += int(r.get("commuters", 0))
			var reach := [fd] + EconUtil.neighbours(fd)
			if not (td in reach) and int(spare.get(td, 0)) > 0:
				c[1] += int(r.get("commuters", 0))
			commute[fd] = c
		var y := m / 12
		for d in EconUtil.sorted_keys(pop):
			var reach2 := [d] + EconUtil.neighbours(d)
			var h_in := 0
			var sp_in := 0
			for x in reach2:
				h_in += int(hubs.get(x, 0))
				sp_in += int(spare.get(x, 0))
			var sp_all := 0
			for x in spare:
				sp_all += int(spare[x])
			var base := float(EconData.BASE_SERVICES_PRICE * EconUtil.S)
			var k := "%d|%s" % [y, d]
			var r2: Array = acc.get(k, [0, 0, 0.0, 0, 0, 0, 0, 0])
			r2[0] += int(pop[d]); r2[1] += h_in; r2[2] += float(s["svc_price"].get(d, 0)) / base
			r2[3] += sp_in; r2[4] += sp_all - sp_in
			r2[5] += int(commute.get(d, [0, 0])[0]); r2[6] += int(commute.get(d, [0, 0])[1]); r2[7] += 1
			acc[k] = r2
	print("year district pop hubs_in_reach price_x spare_in_reach spare_elsewhere commuters to_spare_outside_reach")
	for k in EconUtil.sorted_keys(acc):
		var r3: Array = acc[k]
		var n := float(r3[7])
		var parts: PackedStringArray = k.split("|")
		if int(parts[0]) % 5 != 4:
			continue
		print("Y%d %s pop=%d hubs=%.1f price=%.2fx spare_in=%d spare_out=%d comm=%d to_spare_outside=%d" % [int(parts[0]) + 1, parts[1],
			int(r3[0] / n), r3[1] / n, r3[2] / n, int(r3[3] / n), int(r3[4] / n), int(r3[5] / n), int(r3[6] / n)])
	quit()

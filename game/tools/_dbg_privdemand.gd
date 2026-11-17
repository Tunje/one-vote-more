extends SceneTree
## Bob: private-firm demand probe. args: seed years [flags]
## Logs every private / cooperative firm death (type, district, age, last-12-month P&L, utilisation, peers of the same
## type in its district, the price of its good against base) and a yearly table by firm type.
const SKIP := ["OFFICE", "HQOFFICE"]


func _kind(w: WorldState, oid: String) -> Array:
	for fid in EconUtil.sorted_keys(w.table("facility")):
		var f: Dictionary = w.table("facility")[fid]
		if f["org"] == oid and not (f["type"] in SKIP):
			return [f["type"], fid]
	return ["NONE", ""]


func _price_pct(w: WorldState, ftype: String, d: String) -> int:
	var s := EconUtil.st(w)
	if ftype == "SERVICEHUB":
		return 100 * int(s["svc_price"].get(d, 0)) / (EconData.BASE_SERVICES_PRICE * EconUtil.S)
	var r: Dictionary = EconData.RECIPES.get(ftype, {})
	if r.is_empty():
		return -1
	var g: String = r["out"][0]
	if not s["prices"].has(g) or not EconData.BASE_PRICE.has(g):
		return -1
	return 100 * int(s["prices"][g]) / (int(EconData.BASE_PRICE[g]) * EconUtil.S)


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sim: Simulation = EconSim.make(int(a[0]), "BALANCED", {}, true)
	var w := sim.world
	if a.size() > 2 and a[2] != "base":
		for fl in a[2].split(","):
			if fl.begins_with("-"):
				(w.meta["on"] as Array).erase(fl.substr(1))
			elif not (w.meta["on"] as Array).has(fl):
				(w.meta["on"] as Array).append(fl)
	var born := {}
	var last := {}  # oid -> [kind, fid, district, sum12, util, price%]
	var deaths := {}  # kind -> [n, age sum, rev, wages, cogs, other]
	for m in int(a[1]) * 12:
		sim.run(1)
		var orgs := w.table("org")
		for oid in EconUtil.sorted_keys(orgs):
			var o: Dictionary = orgs[oid]
			if not (o["type"] in ["PRIVATE", "COOPERATIVE"]):
				continue
			if not born.has(oid):
				born[oid] = m
			var dead: bool = o["status"] in ["LIQUIDATION", "DISSOLVED"]
			if not dead:
				var k := _kind(w, oid)
				var f: Dictionary = w.table("facility")[k[1]] if k[1] != "" else {}
				var d: String = f.get("district", o.get("hq", "?"))
				last[oid] = [k[0], k[1], d, EconAnnual.sum12(o), int(f.get("util", 0)), _price_pct(w, k[0], d)]
			elif last.has(oid):
				var L: Array = last[oid]
				last.erase(oid)
				var p: Dictionary = L[3]
				var other := 0
				for key in ["util", "freight", "rent", "dep", "interest", "royalty"]:
					other += int(p.get(key, 0))
				var peers := 0
				for oid2 in orgs:
					if oid2 != oid and not (orgs[oid2]["status"] in ["LIQUIDATION", "DISSOLVED"]) and last.has(oid2) and last[oid2][0] == L[0] and last[oid2][2] == L[2]:
						peers += 1
				var age := m - int(born[oid])
				var M := 1000000
				print("DIE y%d m%d %s %s %s age %dm rev12 %dk wages12 %dk cogs12 %dk other12 %dk util %d‰ price %d%% peers %d" % [m / 12 + 1, m % 12 + 1, oid, L[0], L[2], age,
					int(p.get("rev", 0)) / M, int(p.get("wages", 0)) / M, int(p.get("cogs", 0)) / M, other / M, L[4], L[5], peers])
				var dk: Array = deaths.get(L[0], [0, 0, 0, 0, 0, 0])
				deaths[L[0]] = [dk[0] + 1, dk[1] + age, dk[2] + int(p.get("rev", 0)) / M, dk[3] + int(p.get("wages", 0)) / M, dk[4] + int(p.get("cogs", 0)) / M, dk[5] + other / M]
		if m % 12 == 11:
			var tab := {}  # kind -> [n, loss-making, rev, wages, cogs, other, util]
			for oid in last:
				var L: Array = last[oid]
				var p: Dictionary = L[3]
				var other := 0
				for key in ["util", "freight", "rent", "dep", "interest", "royalty"]:
					other += int(p.get(key, 0))
				var prof := int(p.get("rev", 0)) + int(p.get("subsidy", 0)) - int(p.get("wages", 0)) - int(p.get("cogs", 0)) - other
				var t: Array = tab.get(L[0], [0, 0, 0, 0, 0, 0, 0])
				tab[L[0]] = [t[0] + 1, t[1] + (1 if prof < 0 else 0), t[2] + int(p.get("rev", 0)) / 1000000, t[3] + int(p.get("wages", 0)) / 1000000, t[4] + int(p.get("cogs", 0)) / 1000000, t[5] + other / 1000000, t[6] + int(L[4])]
			var line := "Y%d u %.1f%%" % [m / 12 + 1, float(EconQuery.labour(w)["rate_pct"])]
			for kk in EconUtil.sorted_keys(tab):
				var t: Array = tab[kk]
				line += " | %s n%d loss%d rev%dk w%dk c%dk o%dk u%d" % [kk, t[0], t[1], t[2], t[3], t[4], t[5], t[6] / maxi(1, t[0])]
			print(line)
	for kk in EconUtil.sorted_keys(deaths):
		var dk: Array = deaths[kk]
		print("DEATHS %s n%d mean age %dm mean rev12 %dk wages12 %dk cogs12 %dk other12 %dk" % [kk, dk[0], dk[1] / dk[0], dk[2] / dk[0], dk[3] / dk[0], dk[4] / dk[0], dk[5] / dk[0]])
	quit()

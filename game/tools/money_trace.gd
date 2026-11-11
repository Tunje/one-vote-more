extends SceneTree
## Where did the money go? Runs one colony and reports, per year:
##   - money held by each sector (households, companies, government, banks, parties, other)
##   - net flows across the colony border (EXTERNAL) by memo: what money left and what came in
##   godot --headless --path game --script res://tools/money_trace.gd -- [years=20] [seed=1]
const EconSim := preload("res://sim/economy/econ_sim.gd")

var ext_year := {}   # memo -> net out (+ = left the colony)
var ext_total := {}
var flow_year := {}  # "sectorA>sectorB" -> amount (between sectors, by memo class)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var years := int(args[0]) if args.size() > 0 else 20
	var seed_v := int(args[1]) if args.size() > 1 else 1
	var sim: Simulation = EconSim.make(seed_v, "BALANCED", {}, true)
	var w := sim.world
	var seen := 0
	print("money in million cr (balances at year end; + inflow / - outflow at the border)")
	for m in years * 12:
		var before := w.ledger.journal.size()
		sim.step()
		# journal may have been compacted during the step: take entries of this month
		for e in w.ledger.journal:
			if int(e["m"]) != w.month - 1:
				continue
			var memo := String(e["memo"]).get_slice(":", 0).get_slice(" ", 0)
			if e["to"] == Ledger.EXTERNAL:
				ext_year[memo] = int(ext_year.get(memo, 0)) + int(e["amt"])
			elif e["from"] == Ledger.EXTERNAL:
				ext_year[memo] = int(ext_year.get(memo, 0)) - int(e["amt"])
		if w.month % 12 == 0:
			_report(w)
	print("\n=== border totals over %d years (million cr; + = money that LEFT the colony) ===" % years)
	var ks := ext_total.keys()
	ks.sort_custom(func(a, b): return absi(ext_total[a]) > absi(ext_total[b]))
	var net := 0
	for k in ks:
		net += int(ext_total[k])
		print("  %-36s %+10.1f" % [k, float(ext_total[k]) / 1e9])
	print("  %-36s %+10.1f" % ["NET", float(net) / 1e9])
	quit(0)


func _sector(acct: String) -> String:
	if acct == Ledger.EXTERNAL:
		return "EXTERNAL"
	if acct.begins_with("hh"):
		return "households"
	if acct.begins_with("co:") or acct.begins_with("org"):
		return "companies"
	if acct.begins_with("gov") or acct.begins_with("treasury"):
		return "government"
	if acct.contains("bank"):
		return "banks"
	if acct.begins_with("party"):
		return "parties"
	return "other:" + acct.get_slice(":", 0)


func _report(w: WorldState) -> void:
	var sec := {}
	var biggest := {}
	for a in w.ledger.balances:
		var s := _sector(a)
		var b: int = w.ledger.balances[a]
		sec[s] = int(sec.get(s, 0)) + b
		if s != "EXTERNAL" and (not biggest.has(s) or absi(b) > absi(biggest[s][1])):
			biggest[s] = [a, b]
	var line := "Y%3d " % (w.month / 12)
	var ks := sec.keys()
	ks.sort()
	for s in ks:
		line += " %s %.1f |" % [s, float(sec[s]) / 1e9]
	print(line)
	var top := ext_year.keys()
	top.sort_custom(func(a, b): return absi(ext_year[a]) > absi(ext_year[b]))
	var parts: Array = []
	for k in top.slice(0, 6):
		parts.append("%s %+.1f" % [k, float(ext_year[k]) / 1e9])
		ext_total[k] = int(ext_total.get(k, 0)) + int(ext_year[k])
	for k in top.slice(6):
		ext_total[k] = int(ext_total.get(k, 0)) + int(ext_year[k])
	print("       border: " + ", ".join(parts))
	ext_year = {}

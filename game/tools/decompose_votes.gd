extends SceneTree
## Wilma: why does one party run away? Pop-weighted mean of each vote-utility term per party, at given months.
##   godot --headless --path game --script res://tools/decompose_votes.gd -- seed m1 m2 ...
const EconSim := preload("res://sim/economy/econ_sim.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_v := int(args[0])
	var months: Array = []
	for i in range(1, args.size()):
		months.append(int(args[i]))
	var sim: Simulation = EconSim.make(seed_v, "BALANCED", {}, true)
	var prov: PoliticsProvider = null
	for p in sim.providers:
		if p is PoliticsProvider:
			prov = p
	for target in months:
		sim.run(target - sim.world.month)
		var w := sim.world
		var st: Dictionary = w.table("pol")["state"]
		var parties: Array = PartyLife.active(w)
		var gs: Dictionary = prov._gov_share(w, st)
		var camp := Campaign.vote_cache(w)
		var endorse := PartyLife.endorsements(w)
		var acc := {}
		var tot := 0.0
		var shares := {}
		for cell in PolVoters.all(w):
			var n := float(cell["pop"])
			if n <= 0:
				continue
			tot += n
			var ctx := {"gov_share": gs, "prev_share": cell["prev_share"], "shock": {}, "tenure": st.get("tenure", {}), "campaign_u": Campaign.voter_utility(camp, cell), "endorse": PartyLife.endorsement_bonus(cell, endorse)}
			var probs := VoteModel.probabilities(cell, parties, ctx)
			for p in parties:
				var pid: String = p["id"]
				shares[pid] = float(shares.get(pid, 0.0)) + probs[pid] * n
				var t := _terms(cell, p, ctx)
				if not acc.has(pid):
					acc[pid] = {}
				for k in t:
					acc[pid][k] = float(acc[pid].get(k, 0.0)) + t[k] * n
		print("=== seed %d month %d (Y%d) gov %s" % [seed_v, w.month, w.month / 12 + 1, st.get("government", {}).get("members", [])])
		var ids: Array = acc.keys()
		ids.sort_custom(func(a, b): return shares[a] > shares[b])
		for pid in ids:
			var line := "%-28s share %5.1f%%  " % [w.table("party")[pid]["name"].left(28), shares[pid] / tot * 100.0]
			for k in ["dist", "perf", "ruling", "own", "loyal", "cred", "camp", "endorse", "leader"]:
				line += "%s %+.2f " % [k, acc[pid][k] / tot]
			print(line)
	quit()


func _terms(cell: Dictionary, party: Dictionary, ctx: Dictionary) -> Dictionary:
	var sal: Dictionary = cell["salience"]
	var t := {}
	t["dist"] = -PolDefs.BETA_DISTANCE * VoteModel.distance(cell["ideology"], party["positions"], VoteModel.axis_weights(sal))
	var pid: String = party["id"]
	var gs: float = ctx["gov_share"].get(pid, 0.0)
	t["perf"] = 0.0
	if gs > 0.0:
		var appr := float(cell["approval"]) / 1000.0
		var expect := float(cell.get("expect", 50000)) / 1000.0
		t["perf"] = PolDefs.BETA_PERFORMANCE * gs * ((appr - expect) / 20.0 + (appr - 50.0) / 100.0)
	var tm: int = int(ctx["tenure"].get(pid, 0))
	t["ruling"] = -minf(PolDefs.COST_OF_RULING_CAP, PolDefs.COST_OF_RULING_PER_YEAR * float(tm) / 12.0) if tm > 0 else 0.0
	var o := 0.0
	for c in party.get("ownership", {}):
		o += float(sal.get(c, 0)) / 1000.0 * float(party["ownership"][c]) / 100.0 * (1.0 - float(cell["sat"].get(c, 50000)) / 100000.0)
	t["own"] = PolDefs.BETA_OWNERSHIP * o * 3.0
	var prev: float = float(ctx["prev_share"].get(pid, 0)) / 100000.0
	t["loyal"] = PolDefs.BETA_LOYALTY * log(0.15 + prev) if prev > 0.0 else 0.0
	t["cred"] = 0.5 * (float(party.get("credibility", 50)) - 50.0) / 50.0
	t["camp"] = float(ctx["campaign_u"].get(pid, 0.0))
	t["endorse"] = float(ctx["endorse"].get(pid, 0.0))
	t["leader"] = PolDefs.BETA_LEADER * (float(PartyLife.leader_popularity(party)) - 50.0) / 50.0
	return t

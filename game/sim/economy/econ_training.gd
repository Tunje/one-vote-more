class_name EconTraining
extends RefCounted
## E114 (Wilma-approved): on-the-job training. Skills were fixed at adulthood, so the colony ran short of skilled
## (S) and specialist (Sp) workers while general workers (G) sat unemployed. Each month, while a tier has unfilled
## vacancies, firms with those vacancies sponsor trainees from the unemployed one tier below:
##   G → S at TRAIN_RATE_S of employed G a month, S → Sp at TRAIN_RATE_SP of employed S,
##   × (0.5 + 0.5 × school access) × (1 + ECON_TRAINING_SUBSIDY / 100), capped by the upper tier's vacancies net of
##   its own unemployed and by the lower tier's unemployed net of its own vacancies (no training into a G shortage).
## Training is not free: the sponsoring firm pays each trainee one month of the wage gap between the tiers (a
## stipend to the trainee's household pool). The state pays ECON_TRAINING_SUBSIDY % of it from the
## ECON_BUDGET_TRAINING line (within its headroom). A firm without spare cash trains fewer. Higher wages then move
## the trainees up the income bands through the yearly reclassification (EconPop.reclassify).

const S := EconUtil.S
const TRAIN_RATE_S := 0.005
const TRAIN_RATE_SP := 0.002
const STEPS := [["G", "S", TRAIN_RATE_S], ["S", "Sp", TRAIN_RATE_SP]]


## Unfilled posts per org and tier (milli-persons): plants (required − staff) and builders (crew target − crew).
static func vacancies_by_org(world: WorldState) -> Dictionary:
	var out := {}
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] == "PUBJOBS":
			continue  # E117b: scheme posts are relief work, not skilled vacancies to train for
		var req := EconLabor.required(f)
		for t in req:
			var gap: int = int(req[t]) - EconLabor.tier_total(f["staff"], t)
			if gap > 0:
				if not out.has(f["org"]):
					out[f["org"]] = {}
				out[f["org"]][t] = int(out[f["org"]].get(t, 0)) + gap
	for oid in EconUtil.sorted_keys(world.table("org")):
		var o: Dictionary = world.table("org")[oid]
		if not o["is_contractor"] or o["status"] in ["LIQUIDATION", "DISSOLVED"]:
			continue
		for t in o.get("crew_target", {}):
			var gap2: int = int(o["crew_target"][t]) * S - EconLabor.tier_total(o["crew"], t)
			if gap2 > 0:
				if not out.has(oid):
					out[oid] = {}
				out[oid][t] = int(out[oid].get(t, 0)) + gap2
	return out


## Colony vacancies per tier, in persons.
static func vacancies(world: WorldState) -> Dictionary:
	var v := {"G": 0, "S": 0, "Sp": 0}
	var by := vacancies_by_org(world)
	for oid in by:
		for t in by[oid]:
			v[t] = int(v.get(t, 0)) + int(by[oid][t])
	for t in v:
		v[t] = int(v[t]) / S
	return v


static func _edu(world: WorldState) -> float:
	var e: Dictionary = EconUtil.st(world).get("edu_access", {})
	if e.is_empty():
		return 1.0
	var t := 0.0
	for d in e:
		t += float(e[d])
	return clampf(t / float(e.size()) / 1000.0, 0.0, 1.0)


## COMPANY_AI, before vacancies are posted: sponsor and promote trainees.
static func monthly(world: WorldState) -> void:
	if EconUtil.off(world, "E114"):
		return
	var s := EconUtil.st(world)
	var sub := clampf(float(EconUtil.lever(world, "ECON_TRAINING_SUBSIDY", 0)) / 100.0, 0.0, 1.0)
	var mult := (0.5 + 0.5 * _edu(world)) * (1.0 + sub)
	var by_org := vacancies_by_org(world)
	var stats := {"S": 0, "Sp": 0, "cost": 0, "subsidy": 0}
	for step in STEPS:
		var lo: String = step[0]
		var hi: String = step[1]
		var employed_lo := PopStore.count(world, {"status": "EMPLOYED"}, "skill:" + lo)
		var free_lo := PopStore.count(world, {"status": "UNEMPLOYED"}, "skill:" + lo)
		var rem: Dictionary = s.get("train_rem", {})
		s["train_rem"] = rem
		var flow := int(float(employed_lo) * float(step[2]) * mult * S) + int(rem.get(hi, 0))
		var n := flow / S
		rem[hi] = flow - n * S
		var orgs: Array = []
		var w: Array = []
		var vac := 0
		for oid in EconUtil.sorted_keys(by_org):
			var g: int = int(by_org[oid].get(hi, 0)) / S
			if g > 0:
				orgs.append(oid)
				w.append(g)
				vac += g
		# only a real mismatch: the upper tier is short net of its own unemployed, the lower tier has a net surplus
		var free_hi := PopStore.count(world, {"status": "UNEMPLOYED"}, "skill:" + hi)
		var vac_lo := 0
		for oid2 in by_org:
			vac_lo += int(by_org[oid2].get(lo, 0)) / S
		n = mini(n, mini(maxi(0, vac - free_hi), maxi(0, free_lo - vac_lo)))
		if n <= 0:
			continue
		var gap := maxi(0, int(s["wage"].get(hi, 0)) - int(s["wage"].get(lo, 0)))  # milli per person-month
		var parts := EconUtil.split_lr(n, w)
		for i in orgs.size():
			var k: int = parts[i]
			if k <= 0:
				continue
			k = mini(k, int(w[i]))
			var oid: String = orgs[i]
			var o: Dictionary = world.table("org")[oid]
			var acc := EconUtil.acct(oid)
			# the state's share first (within the training line's headroom), then the firm's from spare cash
			var cost := gap * k
			var gov_share := mini(int(float(cost) * sub), maxi(0, EconActions.headroom(world, "ECON_BUDGET_TRAINING")))
			var reserve: int = 0 if o["type"] == "PUBLIC_INSTITUTION" else int(o["pl_last"].get("wages", 0))
			var spare := world.ledger.balance(acc) + gov_share - reserve
			if gap > 0 and spare < cost:
				k = maxi(0, spare / gap)  # a firm without spare cash trains fewer
				cost = gap * k
				gov_share = mini(gov_share, int(float(cost) * sub))
			if k <= 0:
				continue
			if gov_share > 0:
				var paid := EconFinance.gov_pay(world, acc, gov_share, "TRAINING_SUBSIDY")
				EconFinance._spend_line(world, "ECON_BUDGET_TRAINING", paid)
				EconFinance.pl_add(world, oid, "subsidy", paid)
				stats["subsidy"] += paid
			var done := _promote(world, lo, hi, k, acc, gap, oid)
			stats[hi] += done
			stats["cost"] += gap * done
	var hist: Array = s.get("train_hist", [])
	hist.append([stats["S"], stats["Sp"]])
	while hist.size() > 12:
		hist.pop_front()
	s["train_hist"] = hist
	s["train_last"] = stats


## Promotes k unemployed people of skill `lo` to `hi`, paying each a stipend of `gap` from `payer`. Returns promoted.
static func _promote(world: WorldState, lo: String, hi: String, k: int, payer: String, gap: int, oid: String) -> int:
	var keys := PopStore.select(world, {"status": "UNEMPLOYED"})
	var w: Array = []
	for key in keys:
		w.append(int(world.peek("pop")[key]["skill"].get(lo, 0)))
	var parts := PopStore.split_over(k, keys, w)
	var done := 0
	for key in EconUtil.sorted_keys(parts):
		var m := EconPop.recompose(world, key, "skill", lo, hi, parts[key])
		if m <= 0:
			continue
		done += m
		var lp := PopStore.parts_of(key)
		var gid := "%s|%s" % [lp["hb"], lp["inc"]]
		if gap > 0 and world.table("hh").has(gid):
			var amt := mini(gap * m, maxi(0, world.ledger.balance(payer)))
			if amt > 0:
				world.ledger.transfer(payer, EconUtil.hh_acct(gid), amt, "TRAINING", world.month)
				EconFinance.pl_add(world, oid, "wages", amt)
	return done


## For EconQuery.essentials()["SKILLS"].
static func summary(world: WorldState) -> Dictionary:
	var v := vacancies(world)
	var p12 := {"S": 0, "Sp": 0}
	for h in EconUtil.peek_st(world).get("train_hist", []):
		p12["S"] += int(h[0])
		p12["Sp"] += int(h[1])
	return {"vacancies_G": v["G"], "vacancies_S": v["S"], "vacancies_Sp": v["Sp"],
		"unemployed_G": PopStore.count(world, {"status": "UNEMPLOYED"}, "skill:G"),
		"unemployed_S": PopStore.count(world, {"status": "UNEMPLOYED"}, "skill:S"),
		"unemployed_Sp": PopStore.count(world, {"status": "UNEMPLOYED"}, "skill:Sp"),
		"trained_12m_S": p12["S"], "trained_12m_Sp": p12["Sp"],
		"subsidy_pct": int(EconUtil.lever(world, "ECON_TRAINING_SUBSIDY", 0))}

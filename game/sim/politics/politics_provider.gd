class_name PoliticsProvider
extends PicProvider
## Political core (M2). Stateless; state lives in world tables owned by "pol":
##   pol["state"]  era, revealed commander ideology, government, calendar, movements
##   cell[key]     voter cells: pop, base/ideology (milli), sat/salience, approval, prev_share
##   party[id]     parties (PartyGen.make_party)
##   election[id], poll[id], bill[id], enactment[id] (hand-off to law)
## Reads: world.table("census") (cell_key -> pop, written by econ/stub in SOCIAL), indicators, facts, levers.

const S := 1000
const StaffOps := preload("res://sim/staff/staff_ops.gd")
const DRAFT_TIMEOUT_MONTHS := 12
const LOSS_AVERSION := 0.8          # extra weight on shortfalls below 50% satisfaction (tuning knob)
const EXPECTATION_MONTHS := 36.0
const MEDIA_PULL := 0.002            # monthly ideology pull toward a paper's line at full reading weight (PD 17.6)
const HONEYMOON := 8000.0            # approval bonus for a new government, fading over its first year
const CRISIS_SATISFACTION := 35000
const MAX_PARALLEL_DRAFTS := 3  # colony-wide concern satisfaction below this triggers crisis mode    # time constant of voter expectations (tuning knob)


func owner_id() -> String:
	return "pol"


func phases() -> Array:
	return [TickPhase.DECISIONS, TickPhase.POLITICS]


func indicator_defs() -> Array:
	return [{"id": "POL_GOV_APPROVAL", "owner": "pol", "unit": "% (milli)", "range": [0, 100000], "granularity": "COLONY",
		"polarity": 1, "concerns": {}, "normalize": {"good": 100000, "bad": 0}, "phase": TickPhase.POLITICS,
		"visibility": "PUBLIC", "perceptionLag": 0},
		# M12: what the charter costs the colony (quota x price gap, governor, recent sanctions); 0 when independent
		{"id": "POL_COLONIAL_BURDEN", "owner": "pol", "unit": "index (milli)", "range": [0, 100000], "granularity": "COLONY",
		"polarity": -1, "concerns": {"COLONIAL_BURDEN": 1.0}, "normalize": {"good": 0, "bad": 40000}, "phase": TickPhase.POLITICS,
		"visibility": "PUBLIC", "perceptionLag": 0}]


func init_world(world: WorldState) -> void:
	Planet.generate(world)  # Terra: the globe (idempotent); the colony grid lives inside its landing region
	if not Terrain.ready(world):
		Terrain.generate(world)  # M13 terrain map (Bob's A2 generates it in EconSetup; this covers earlier setups)
	var persona: Dictionary = world.meta.get("persona", {})
	var p := PolDefs.zero_axes()
	for ax in persona:
		p[ax] = int(persona[ax]) * S
	world.table("pol")["state"] = {
		"era": "FOUNDING", "revealed": PolDefs.zero_axes(), "persona": p,
		"autoplay_player": world.meta.get("autoplay_player", true),
		"next_election": PolDefs.FOUNDING_ELECTION_MONTH, "government": {}, "caretaker": false,
		"last_bill_month": -99, "movements": [], "grievance_months": {}, "elections": [],
		"term_levers": {}, "last_poll": "",
		"culture": _make_culture(world),
	}


## The colony's political culture: cohort shares and offsets (milli-points), drawn once per game.
func _make_culture(world: WorldState) -> Dictionary:
	var r := world.rng.stream("pol.culture")
	var shift := {}
	for ax in PolDefs.AXES:
		shift[ax] = int(round(r.randfn(0.0, PolDefs.COLONY_CULTURE_SD) * S))
	var cohorts := {}
	var tot := 0
	for cname in PolDefs.COHORTS:
		var t: Dictionary = PolDefs.COHORTS[cname]
		var off := {}
		for ax in PolDefs.AXES:
			off[ax] = int(round((float(t["offset"].get(ax, 0)) + r.randfn(0.0, PolDefs.COHORT_RANDOM_SD)) * S)) + shift[ax]
		var share: int = maxi(100, int(t["share"]) + r.randi_range(-PolDefs.COHORT_SHARE_JITTER, PolDefs.COHORT_SHARE_JITTER))
		cohorts[cname] = {"share": share, "offset": off}
		tot += share
	for cname in cohorts:
		cohorts[cname]["share"] = int(round(float(cohorts[cname]["share"]) * 1000.0 / float(tot)))
	return {"shift": shift, "cohorts": cohorts}


func run_phase(phase: int, world: WorldState) -> void:
	var st: Dictionary = world.table("pol")["state"]
	if phase == TickPhase.DECISIONS:
		if PolVoters.leaves_mode(world):
			PolVoters.refresh(world)  # new people since last month get voter fields before decisions read them
		_decisions(world, st)
		return
	Philosophy.assign(world)       # M10 S3a: new people get philosophies (archetypes) and beliefs
	if PolVoters.leaves_mode(world):
		PolVoters.refresh(world)   # M10 S3: the people are the voters
	else:
		_sync_cells(world)
	_update_opinion(world, st)
	if st["era"] == "FOUNDING" and world.month < PolDefs.PARTY_FORMATION_MONTH:
		_track_movements(world, st)
	if world.month == PolDefs.PARTY_FORMATION_MONTH:
		_form_parties(world, st)
	_track_tenure(world, st)
	var have_parties := not world.table("party").is_empty()
	if have_parties and world.month > PolDefs.PARTY_FORMATION_MONTH:
		_party_life_monthly(world, st)
	if have_parties and world.month % 3 != 0 and Campaign.wants_poll(world, st):
		run_poll(world, PolDefs.POLL_MOE_DEFAULT, "pol.campaign")   # election year: monthly polls in the short campaign
	if have_parties and world.month % 3 == 0 and world.month != st["next_election"]:
		run_poll(world, PolDefs.POLL_MOE_DEFAULT, "pol.auto")
		PartyLife.check_mergers(world, st)
		PartyLife.check_dissolutions(world, st, PartyLife.latest_poll_shares(world))
	if have_parties and world.month_of_year() == 1 and world.month > PolDefs.PARTY_FORMATION_MONTH:
		_adapt_parties(world)
		var base := PartyLife.axis_baseline(world)   # (Ella) faction lines judged against the other parties
		for p in PartyLife.active(world):
			PartyLife.update_factions(world, p, base)
		PartyLife.check_foundings(world, st)
		_zeitgeist(world, st)
	if have_parties and world.month == st["next_election"]:
		run_election(world, st, false)
	elif have_parties and world.month == int(st.get("extra_election_month", -1)):
		st.erase("extra_election_month")
		if int(st["next_election"]) - world.month > 3:  # never right before an ordinary election
			run_election(world, st, true)
	elif st.has("formation"):
		GovCrisis.formation_step(world, st)
	elif have_parties and st["era"] == "PARLIAMENTARY":
		GovCrisis.cohesion_step(world, st)
		GovCrisis.no_confidence_ai(world, st)
		EmergencyPolitics.monthly(world, st)
		DistrictPolitics.monthly(world, st)
	AreaStore.yearly(world)        # January: oversized areas and private enclaves split (moves to SOCIAL with Bob's A2)
	GovBuilder.monthly(world, st)  # the state's capital programme, decided by whoever governs (not when the player does)
	if have_parties and world.month > PolDefs.PARTY_FORMATION_MONTH:
		HomeWorld.monthly(world, st)
	world.set_indicator("pol", "POL_GOV_APPROVAL", "COLONY", colony_approval(world))
	world.set_indicator("pol", "POL_COLONIAL_BURDEN", "COLONY", HomeWorld.burden(world))


## The government's agenda for drafting: its coalition agreement plus the confidence-and-supply prices it still owes
## (deals not yet withdrawn). Deals are marked so drafting gives them priority and the cabinet backs them.
static func _agenda(gov: Dictionary) -> Array:
	var out: Array = gov.get("agreement", []).duplicate()
	for d in gov.get("deals", []):
		if d["party"] in gov.get("withdrawn", []) or not (d["party"] in gov.get("support", [])):
			continue
		out.append({"lever": d["lever"], "dir": d["dir"], "deal": true})
	return out


# ======================= opinion =======================

func _sync_cells(world: WorldState) -> void:
	var cells := world.table("cell")
	var census := world.table("census")
	var rng := world.rng.stream("pol.init")
	var cohorts: Dictionary = world.table("pol")["state"]["culture"]["cohorts"]
	for key in census:
		var parts: PackedStringArray = key.split("|")
		if not PolDefs.OCC_IDEOLOGY.has(parts[1]):
			continue
		for cname in cohorts:
			var ck: String = key + "|" + cname
			if not cells.has(ck):
				var base := PolDefs.zero_axes()
				var occ_v: Array = PolDefs.OCC_IDEOLOGY[parts[1]]
				var coh: Dictionary = cohorts[cname]
				for i in PolDefs.AXES.size():
					var ax: String = PolDefs.AXES[i]
					base[ax] = clampi((occ_v[i] + rng.randi_range(-8, 8)) * S + int(coh["offset"][ax]), -100 * S, 100 * S)
				var bs: Array = PolDefs.BAND_SHIFT[parts[2]]
				base["ECON_ROLE"] += bs[0] * S
				base["REDISTRIBUTION"] += bs[1] * S
				base["FISCAL"] += bs[2] * S
				var sal := {}
				var sat := {}
				for c in PolDefs.CONCERNS:
					sal[c] = 111
					sat[c] = 50000
				cells[ck] = {"key": ck, "census_key": key, "cohort": cname, "district": parts[0], "occ": parts[1], "band": parts[2],
					"pop": 0, "base": base, "ideology": base.duplicate(), "salience": sal, "sat": sat,
					"approval": 50000, "expect": 50000, "perf_hist": [], "prev_share": {}}
			cells[ck]["pop"] = int(round(float(census[key]) * float(cohorts[cname]["share"]) / 1000.0))


func _cell_indicator_key(cell: Dictionary, granularity: String) -> String:
	match granularity:
		"COLONY": return "COLONY"
		"DISTRICT": return cell["district"]
	return cell.get("census_key", cell["key"])


func _update_opinion(world: WorldState, st: Dictionary) -> void:
	var ind := world.indicators
	var gov_facts := _blame_facts(world)
	var agenda := _agenda_monthly(world, st)
	var dmeans := _district_means(world)
	var g0: Dictionary = st.get("government", {})
	var honeymoon := 0.0
	if not g0.is_empty() and g0.has("formed_month"):
		honeymoon = HONEYMOON * maxf(0.0, 1.0 - float(world.month - int(g0["formed_month"])) / 12.0)
	var sat_memo := {}
	for cell in PolVoters.all(world):
		if cell["pop"] <= 0:
			continue
		# 1. satisfaction per concern from indicators (the same for every voter with the same district and census
		#    key, so computed once per key per month)
		var sat_key: String = String(cell["district"]) + "#" + String(cell.get("census_key", cell["key"]))
		var actual_sat: Dictionary = sat_memo.get(sat_key, {})
		if actual_sat.is_empty():
			actual_sat = _indicator_sat(world, ind, cell)
			sat_memo[sat_key] = actual_sat
		var nb: Dictionary = cell.get("news_bias", {})
		for c in PolDefs.CONCERNS:
			cell["sat"][c] = clampi(int(actual_sat[c]) + int(nb.get(c, 0)), 0, 100000)   # media: perceived = actual + bias (facts unchanged)
		# 2. salience: occupation base x (1 + 2 x unmet), renormalised to 1000
		var occ_sal: Array = PolDefs.OCC_SALIENCE[PolVoters.vocc(cell)]
		var na: Dictionary = cell.get("news_agenda", {})   # media: what your papers cover
		var raw := {}
		var tot := 0.0
		for i in PolDefs.CONCERNS.size():
			var c: String = PolDefs.CONCERNS[i]
			var unmet := 1.0 - float(cell["sat"][c]) / 100000.0
			raw[c] = maxf(1.0, float(occ_sal[i]) * (1.0 + 2.0 * unmet) + float(agenda.get(c, 0)) + float(na.get(c, 0)))
			tot += raw[c]
		for c in raw:
			cell["salience"][c] = int(round(raw[c] / tot * 1000.0))
		# 3. ideology drift: unmet concerns radicalise in the cell's own direction; slow pull back to base
		for c in PolDefs.CONCERNS:
			var unmet := 1.0 - float(cell["sat"][c]) / 100000.0
			if unmet > 0.5:
				for ax in PolDefs.CONCERN_PULL[c]:
					var sign := -1.0 if cell["base"][ax] < -20 * S else 1.0
					if c == "COLONIAL_BURDEN":
						sign = 1.0  # the charter's burden always pushes toward independence
					cell["ideology"][ax] += int(round(sign * PolDefs.CONCERN_PULL[c][ax] * (unmet - 0.5) * 2.0 * 0.5 * S))
		for ax in PolDefs.AXES:
			cell["ideology"][ax] += int(round(float(cell["base"][ax] - cell["ideology"][ax]) * 0.01))
			cell["ideology"][ax] += int(round((float(dmeans[cell["district"]][ax]) - float(cell["ideology"][ax])) * PolDefs.SOCIAL_INFLUENCE))
			cell["ideology"][ax] = clampi(cell["ideology"][ax], -100 * S, 100 * S)
		# media (PD 17.6): years of reading one paper slowly pull readers toward its line
		var diet: Dictionary = cell.get("diet", {})
		for oid in diet:
			var o: Dictionary = world.peek("outlet").get(oid, {})
			if o.is_empty():
				continue
			var wgt := MediaQuery.weight(cell, oid) * MEDIA_PULL
			for ax in PolDefs.AXES:
				cell["ideology"][ax] = clampi(cell["ideology"][ax] + int(round((float(o["line"].get(ax, 0)) - float(cell["ideology"][ax])) * wgt)), -100 * S, 100 * S)
		# 4. government approval: level + trend + attributable facts
		# Loss aversion: shortfalls below 50% hurt 1.8x as much as the same distance above helps.
		var perf := 0.0
		for c in PolDefs.CONCERNS:
			var sv := float(cell["sat"][c])
			if sv < 50000.0:
				sv -= LOSS_AVERSION * (50000.0 - sv)
			perf += float(cell["salience"][c]) * sv / 1000.0
		var hist: Array = cell["perf_hist"]
		var trend := perf - float(hist[0]) if hist.size() >= 12 else 0.0
		if trend < 0.0:
			trend *= 1.5  # bad news travels faster
		hist.append(int(perf))
		if hist.size() > 12:
			hist.pop_front()
		# Living conditions vs government approval (analysis of the 100-year chronicle): voters judge the
		# government against the conditions they have got used to (perf_expect adapts over EXPECTATION_MONTHS)
		# and on the trend; absolute misery weighs in only a little. A permanent depression therefore does not
		# pin every government at 0%, and a new government gets a short honeymoon.
		var pe := float(cell.get("perf_expect", perf))
		cell["perf_expect"] = int(round(pe + (perf - pe) / EXPECTATION_MONTHS))
		var target := 50000.0 + 0.8 * (perf - pe) + 0.25 * (perf - 50000.0) + 2.5 * trend + honeymoon
		target += float(cell.get("news_blame", 0))   # media framing: distortion vs a neutral full account
		for f in gov_facts:
			if _affects(f, cell):
				for c in f["impact"]:
					target += float(f["impact"][c]) * float(cell["salience"].get(c, 0)) / 1000.0 * f["_gov_share"] * 400.0
		cell["approval"] = clampi(int(round(0.85 * cell["approval"] + 0.15 * target)), 0, 100000)
		# Expectations adapt slowly: a government is judged against what voters have got used to.
		cell["expect"] = int(round(float(cell.get("expect", 50000)) + (float(cell["approval"]) - float(cell.get("expect", 50000))) / EXPECTATION_MONTHS))


## Satisfaction per concern (0..100000) from the indicators a voter sees (colony, district and census-key level).
func _indicator_sat(world: WorldState, ind, cell: Dictionary) -> Dictionary:
	var num := {}
	var den := {}
	for id in ind.defs:
		var d: Dictionary = ind.defs[id]
		if d["concerns"].is_empty():
			continue
		var key := _cell_indicator_key(cell, d["granularity"])
		if not ind.values[id].has(key):
			continue
		var nv: int = ind.normalized(id, ind.read_perceived(id, key, world.month))
		if d.get("exceptionOnly", false) and nv >= 100000:
			continue  # pic-core §3: exception-only indicators weigh in only when something is wrong
		for c in d["concerns"]:
			num[c] = num.get(c, 0.0) + float(d["concerns"][c]) * nv
			den[c] = den.get(c, 0.0) + float(d["concerns"][c])
	var out := {}
	for c in PolDefs.CONCERNS:
		out[c] = int(round(num[c] / den[c])) if den.get(c, 0.0) > 0.0 else 50000
	return out


## This month's public facts with government/commander responsibility (blame/credit).
func _blame_facts(world: WorldState) -> Array:
	var out: Array = []
	for f in world.facts.query("", world.month, world.month, "PUBLIC"):
		var share := 0.0
		for r in f["responsible"]:
			if r["actor"]["kind"] in ["GOVERNMENT", "COMMANDER"]:
				share += float(r["share"])
		if share > 0.0 and not f["impact"].is_empty():
			var g: Dictionary = f.duplicate()
			g["_gov_share"] = share
			out.append(g)
	return out


func _affects(f: Dictionary, cell: Dictionary) -> bool:
	var a = f["affected"]
	if typeof(a) == TYPE_STRING:
		return a == "ALL"
	if a.has("districts") and not (cell["district"] in a["districts"]):
		return false
	if a.has("occupations") and not (cell["occ"] in a["occupations"]):
		return false
	return true


func colony_approval(world: WorldState) -> int:
	var s := 0.0
	var p := 0.0
	for c in PolVoters.all(world):
		s += float(c["approval"]) * c["pop"]
		p += c["pop"]
	return int(round(s / p)) if p > 0.0 else 50000


## Pop-weighted colony averages of satisfaction and salience (for proposals and votes).
func colony_concerns(world: WorldState) -> Array:
	var sat := {}
	var sal := {}
	var p := 0.0
	for c in PolDefs.CONCERNS:
		sat[c] = 0.0
		sal[c] = 0.0
	for cell in PolVoters.all(world):
		p += cell["pop"]
		for c in PolDefs.CONCERNS:
			sat[c] += float(cell["sat"][c]) * cell["pop"]
			sal[c] += float(cell["salience"][c]) * cell["pop"]
	for c in PolDefs.CONCERNS:
		sat[c] = int(round(sat[c] / maxf(1.0, p)))
		sal[c] = int(round(sal[c] / maxf(1.0, p)))
	return [sat, sal]


## Consecutive months each party has spent in government (cost of ruling).
func _track_tenure(world: WorldState, st: Dictionary) -> void:
	var ten: Dictionary = st.get("tenure", {})
	var members: Array = st["government"].get("members", [])
	for pid in world.table("party"):
		ten[pid] = int(ten.get(pid, 0)) + 1 if pid in members else 0
	st["tenure"] = ten


# ======================= founding era =======================

func _track_movements(world: WorldState, st: Dictionary) -> void:
	var cs := colony_concerns(world)
	var sat: Dictionary = cs[0]
	var gm: Dictionary = st["grievance_months"]
	var have := {}
	for m in st["movements"]:
		have[m["concern"]] = true
	for c in PolDefs.CONCERNS:
		gm[c] = gm.get(c, 0) + 1 if sat[c] < 45000 else 0
		if gm[c] >= 6 and not have.has(c):
			st["movements"].append({"concern": c, "month": world.month})
			world.add_fact({"type": "POL_MOVEMENT_FORMED", "owner": "pol", "subjects": [],
				"responsible": [{"actor": {"kind": "COMMANDER", "id": "commander"}, "share": 1.0}],
				"impact": {c: -10}, "magnitude": 50, "visibility": "PUBLIC", "data": {"concern": c}})


func _form_parties(world: WorldState, st: Dictionary) -> void:
	var cells: Array = []
	for c in PolVoters.all(world):
		if c["pop"] > 0:
			cells.append(c)
	var mean := PolDefs.zero_axes()
	var tp := 0.0
	for c in cells:
		tp += c["pop"]
		for ax in PolDefs.AXES:
			mean[ax] += float(c["ideology"][ax]) * c["pop"]
	for ax in PolDefs.AXES:
		mean[ax] = int(round(mean[ax] / maxf(1.0, tp)))
	var player_pos: Dictionary = st["revealed"].duplicate()
	var k := 4 + (1 if st["movements"].size() >= 3 else 0)
	var centers := PartyGen.cluster(cells, [player_pos], k)
	var taken := {"Founders' Party": true}
	var player := PartyGen.make_party(world, player_pos, "Founders' Party", true, 0)
	st["player_party"] = player["id"]
	var i := 1
	for ctr in centers:
		var pos := PartyGen.exaggerate(ctr, mean)
		var n := PartyGen.name_for(pos, taken)
		taken[n] = true
		PartyGen.make_party(world, pos, n, false, i)
		i += 1
	# movements give their concern to the party already most credible on it
	for m in st["movements"]:
		var best := ""
		for pid in world.table("party"):
			var p: Dictionary = world.table("party")[pid]
			if best == "" or p["ownership"].get(m["concern"], 0) > world.table("party")[best]["ownership"].get(m["concern"], 0):
				best = pid
		var bp: Dictionary = world.table("party")[best]
		bp["ownership"][m["concern"]] = mini(100, bp["ownership"].get(m["concern"], 0) + 40)
	world.add_fact({"type": "POL_PARTIES_FORMED", "owner": "pol", "subjects": [], "responsible": [],
		"impact": {}, "magnitude": 80, "visibility": "PUBLIC", "data": {"count": world.table("party").size()}})


# ======================= decisions (bills / ordinances) =======================

func _decisions(world: WorldState, st: Dictionary) -> void:
	# Legislation needs a staffed drafting task when the staff subsystem is running (M3 exit criterion).
	# Governments draft up to MAX_PARALLEL_DRAFTS bills at once (staff capacity permitting).
	var staffed := not world.table("staff_state").is_empty()
	if staffed:
		_advance_drafts(world, st)
	# Crisis mode: a badly unmet concern (colony satisfaction < 35%) means more frequent, bigger steps.
	var crisis := false
	var cs := colony_concerns(world)
	for c in PolDefs.CONCERNS:
		if int(cs[0][c]) < CRISIS_SATISFACTION:
			crisis = true
	st["crisis"] = crisis
	var stress := Legislature.fiscal_stress(world)
	st["fiscal_stress"] = int(round(stress * 1000.0))
	var interval := PolDefs.BILL_INTERVAL_MONTHS
	if stress >= 0.5:
		interval = 1
	elif crisis:
		interval = 1 if staffed else 2
	if world.month - st["last_bill_month"] < interval:
		return
	if st.has("formation") or st.get("caretaker", false):
		return  # caretaker governments and formation periods don't table new bills
	if staffed and _drafts(st).size() >= MAX_PARALLEL_DRAFTS:
		return
	var busy := {}
	for d in _drafts(st):
		for c in d["clauses"]:
			busy[c["lever"]] = true
	var clauses: Array = []
	if st["era"] == "FOUNDING":
		if not st["autoplay_player"]:
			return
		clauses = Legislature.propose(world, st["persona"], cs[0], cs[1], [], "COMMANDER", stress, crisis, busy, Campaign.pork_pressure(world, st), _leg_stats(st))
	else:
		var gov: Dictionary = st["government"]
		if gov.is_empty():
			return
		if st.get("player_party", "") in gov["members"] and not st["autoplay_player"]:
			return  # the human government acts through the UI
		clauses = Legislature.propose(world, gov["center"], cs[0], cs[1], _agenda(gov), "PARLIAMENT", stress, crisis, busy, Campaign.pork_pressure(world, st), _leg_stats(st))
	if clauses.is_empty():
		return
	if not staffed:
		_enact(world, st, clauses, "", 50)
		return
	var bill_id := world.new_id("bill")
	var r: Dictionary = StaffOps.request_drafting(world, {"kind": "GOVERNMENT", "id": "government"}, bill_id, clauses)
	if r.get("ok", false):
		_drafts(st).append({"bill": bill_id, "clauses": clauses, "month": world.month, "era": st["era"]})
		st["last_bill_month"] = world.month


## Running counters from Legislature.propose (fiscal-guard blocks), kept in state for the measurement tools.
func _leg_stats(st: Dictionary) -> Dictionary:
	if not st.has("leg_stats"):
		st["leg_stats"] = {"guard_blocked": 0}
	return st["leg_stats"]


func _drafts(st: Dictionary) -> Array:
	if st.has("draft"):  # migrate single-draft state from older saves
		st["drafts"] = [st["draft"]]
		st.erase("draft")
	if not st.has("drafts"):
		st["drafts"] = []
	return st["drafts"]


func _advance_drafts(world: WorldState, st: Dictionary) -> void:
	var keep: Array = []
	for d in _drafts(st):
		var t: Dictionary = StaffOps.draft_for_bill(world, d["bill"])
		var stale: bool = d["era"] != st["era"] or world.month - d["month"] > DRAFT_TIMEOUT_MONTHS
		if t.is_empty() or t["status"] == "CANCELLED" or stale:
			continue
		if t["status"] != "COMPLETED":
			keep.append(d)
			continue
		_enact(world, st, d["clauses"], d["bill"], int(t.get("outputs", {}).get("draft_quality", 50)))
	st["drafts"] = keep


func _enact(world: WorldState, st: Dictionary, clauses: Array, bill_id: String, quality: int) -> void:
	st["last_bill_month"] = world.month
	if st["era"] == "FOUNDING":
		Legislature.issue_ordinance(world, clauses, bill_id)
		return
	var cs := colony_concerns(world)
	Legislature.submit_bill(world, clauses, st["government"], cs[0], cs[1], bill_id, quality)


# ======================= polls & elections =======================

func _active_parties(world: WorldState) -> Array:
	var out: Array = []
	for pid in world.table("party"):
		if world.table("party")[pid]["status"] == "ACTIVE":
			out.append(world.table("party")[pid])
	return out


## Government share used for retrospective voting. In the founding era the commander's record is the player party's.
func _gov_share(world: WorldState, st: Dictionary) -> Dictionary:
	var out := {}
	var gov: Dictionary = st["government"]
	if gov.is_empty():
		if st.has("player_party"):
			out[st["player_party"]] = 1.0
		return out
	var tot := 0
	for pid in gov["members"]:
		tot += world.table("party")[pid]["seats"]
	for pid in gov["members"]:
		out[pid] = float(world.table("party")[pid]["seats"]) / maxf(1.0, float(tot))
	return out


## Expected colony vote shares {party_id: float}. shock: {} for polls, seeded draws on election day.
func vote_shares(world: WorldState, shock: Dictionary, per_cell_out: Dictionary = {}) -> Dictionary:
	var st: Dictionary = world.table("pol")["state"]
	var parties := _active_parties(world)
	var gov_share := _gov_share(world, st)
	var campaign := Campaign.vote_cache(world)        # election year (Ella): read-only
	var mob := Campaign.mobilisation(campaign)
	var endorse := PartyLife.endorsements(world)
	var votes := {}
	for p in parties:
		votes[p["id"]] = 0.0
	for cell in PolVoters.all(world):
		if cell["pop"] <= 0:
			continue
		var ctx := {"gov_share": gov_share, "prev_share": cell["prev_share"], "shock": shock, "tenure": st.get("tenure", {}), "campaign_u": Campaign.voter_utility(campaign, cell), "endorse": PartyLife.endorsement_bonus(cell, endorse)}
		var probs := VoteModel.probabilities(cell, parties, ctx)
		var t := VoteModel.turnout(cell, parties)
		per_cell_out[cell["key"]] = probs
		for pid in probs:
			votes[pid] += float(cell["pop"]) * VoteModel.party_turnout(t, float(mob.get(pid, 1.0))) * probs[pid]
	if not campaign.is_empty():
		Campaign.tactical(world, votes)   # support votes for a governing ally under 4% (local dict only)
	return votes


## The count per district (for Election Night and district politics): each voter group's turnout × vote split,
## scaled so every party's district counts add up exactly to its national total. {district: {party: votes}}.
func _votes_by_district(world: WorldState, parties: Array, per_cell: Dictionary, votes: Dictionary) -> Dictionary:
	var raw := {}
	for c in PolVoters.all(world):
		var probs: Dictionary = per_cell.get(c["key"], {})
		if probs.is_empty() or int(c.get("pop", 0)) <= 0:
			continue
		var d := String(c.get("district", ""))
		var t := VoteModel.turnout(c, parties)
		if not raw.has(d):
			raw[d] = {}
		for pid in probs:
			raw[d][pid] = float(raw[d].get(pid, 0.0)) + float(c["pop"]) * t * float(probs[pid])
	var out := {}
	var ds: Array = raw.keys()
	ds.sort()
	for pid in votes:
		var w: Array = ds.map(func(d): return float(raw[d].get(pid, 0.0)))
		var parts := EconUtil.split_lr(int(votes[pid]), w)
		for i in ds.size():
			if not out.has(ds[i]):
				out[ds[i]] = {}
			if int(parts[i]) > 0:
				out[ds[i]][pid] = int(parts[i])
	return out


func run_poll(world: WorldState, moe_pp: float, by: String) -> Dictionary:
	var votes := vote_shares(world, {})
	var tot := 0.0
	for pid in votes:
		tot += votes[pid]
	var rng := world.rng.stream("pol.polling")
	var est := {}
	var etot := 0.0
	for pid in votes:
		var v := maxf(0.0, votes[pid] / tot * 100.0 + rng.randfn(0.0, moe_pp / 1.96))
		est[pid] = v
		etot += v
	for pid in est:
		est[pid] = int(round(est[pid] / maxf(0.001, etot) * 100000.0))
	var id := world.new_id("poll")
	var poll := {"id": id, "month": world.month, "by": by, "moe_milli": int(moe_pp * 1000.0), "estimates": est}
	world.table("poll")[id] = poll
	world.table("pol")["state"]["last_poll"] = id
	return poll


## extra: an extra election (RF-style) does NOT reset the ordinary 4-year calendar.
func run_election(world: WorldState, st: Dictionary, extra: bool = false) -> void:
	var parties := _active_parties(world)
	var rng := world.rng.stream("pol.election")
	var shock := {}
	var ids: Array = []
	for p in parties:
		ids.append(p["id"])
	ids.sort()
	for pid in ids:
		shock[pid] = rng.randfn(0.0, PolDefs.ELECTION_SHOCK_SD)
	var before := {}
	for p in parties:
		before[p["id"]] = int(p["support"])
	var per_cell := {}
	var fvotes := vote_shares(world, shock, per_cell)
	var votes := {}
	var total := 0
	for pid in ids:
		votes[pid] = int(round(fvotes[pid]))
		total += votes[pid]
	var seats := VoteModel.allocate_seats(votes)
	# promise keeping for governing parties: did the levers move the way their agenda said?
	_score_promises(world, st)
	for pid in ids:
		var p: Dictionary = world.table("party")[pid]
		p["seats"] = seats[pid]
		p["support"] = int(round(float(votes[pid]) / maxf(1.0, float(total)) * 100000.0))
		var agenda: Array = []
		var cms: Array = p["commitments"].duplicate()
		cms.sort_custom(func(a, b): return a["weight"] > b["weight"] or (a["weight"] == b["weight"] and a["lever"] < b["lever"]))
		for cm in cms.slice(0, 3):
			agenda.append({"lever": cm["lever"], "dir": cm["dir"]})
		if not p.get("agenda_locked", false):  # a human player chooses their own promises (PolActions)
			p["agenda"] = agenda
	for key in per_cell:
		var ps := {}
		for pid in per_cell[key]:
			ps[pid] = int(round(per_cell[key][pid] * 100000.0))  # ints in state (README rule 3)
		PolVoters.by_key(world, key)["prev_share"] = ps
	var eid := world.new_id("election")
	world.table("election")[eid] = {"id": eid, "month": world.month, "votes": votes, "seats": seats, "total": total,
		"by_district": _votes_by_district(world, parties, per_cell, votes), "extra": extra}
	st["elections"].append(eid)
	world.add_fact({"type": "POL_ELECTION_HELD", "owner": "pol", "subjects": [], "responsible": [],
		"impact": {}, "magnitude": 90, "visibility": "PUBLIC", "data": {"election": eid}})
	if st["elections"].size() > 1:
		PartyLife.post_election_contests(world, st, before)
	var shares := {}
	for p in PartyLife.active(world):
		shares[p["id"]] = int(p["support"])
	PartyLife.check_dissolutions(world, st, shares)
	var base := PartyLife.axis_baseline(world)
	for p in PartyLife.active(world):
		PartyLife.update_factions(world, p, base)
	PartyLife.check_foundings(world, st)
	st["campaign_spent"] = {}
	if not extra:
		st["next_election"] = world.month + PolDefs.TERM_MONTHS
	st["term_levers"] = world.levers.duplicate()
	GovCrisis.start_formation(world, st, "EXTRA_ELECTION" if extra else "ELECTION")
	GovCrisis.formation_step(world, st)


func _score_promises(world: WorldState, st: Dictionary) -> void:
	var gov: Dictionary = st["government"]
	var start: Dictionary = st["term_levers"]
	if start.is_empty():
		return
	var members: Array = gov.get("members", [])
	for pid in members:
		var p: Dictionary = world.table("party")[pid]
		if p["agenda"].is_empty():
			continue
		var kept := 0
		for a in p["agenda"]:
			var ldef: Dictionary = world.lever_defs.get(a["lever"], {})
			var moved: float = Legislature.ordinal(ldef, world.levers.get(a["lever"], 0)) - Legislature.ordinal(ldef, start.get(a["lever"], 0))
			if signf(moved) == a["dir"]:
				kept += 1
		var ratio := float(kept) / float(p["agenda"].size())
		p["credibility"] = clampi(int(round(0.5 * p["credibility"] + 0.5 * (20.0 + 70.0 * ratio))), 0, 100)


## Yearly: AI parties move 10% toward their own voters' mean, kept as distinct from the colony mean as at
## formation (PartyGen.exaggerate), so adaptation does not collapse everyone into the centre.
func _adapt_parties(world: WorldState) -> void:
	var cmean := PolDefs.zero_axes()
	var cpop := 0.0
	for c in PolVoters.all(world):
		cpop += c["pop"]
		for ax in PolDefs.AXES:
			cmean[ax] += float(c["ideology"][ax]) * c["pop"]
	for ax in PolDefs.AXES:
		cmean[ax] = int(round(cmean[ax] / maxf(1.0, cpop)))
	var autoplay: bool = world.table("pol")["state"]["autoplay_player"]
	for p in _active_parties(world):
		if p["is_player"] and not autoplay:
			continue  # a human player sets their own platform (UI, M5)
		var acc := PolDefs.zero_axes()
		var w := 0.0
		for c in PolVoters.all(world):
			var s: float = float(c["prev_share"].get(p["id"], 0)) / 100000.0 * c["pop"]
			w += s
			for ax in PolDefs.AXES:
				acc[ax] += float(c["ideology"][ax]) * s
		if w <= 0.0:
			continue
		var vmean := {}
		for ax in PolDefs.AXES:
			vmean[ax] = int(round(acc[ax] / w))
		var target := PartyGen.exaggerate(vmean, cmean)
		for ax in PolDefs.AXES:
			p["positions"][ax] += int(round((float(target[ax]) - float(p["positions"][ax])) * 0.10))
		p["commitments"] = PartyGen.commitments(p["positions"], world.lever_defs)


# ======================= M9: party life & opinion dynamics =======================

func _party_life_monthly(world: WorldState, st: Dictionary) -> void:
	PartyLife.track_grievances(world, st)
	PartyLife.leaders_monthly(world, st)
	PartyLife.pending_contests(world, st)
	Congress.monthly(world, st)   # election year (Ella): leadership races, per-term congresses, motions
	PartyLife.factions_monthly(world, st)
	PartyLife.check_splits(world, st)
	PartyLife.funds_monthly(world, st)
	Campaign.monthly(world, st)   # election year (Ella): themes, ads, ground game, debates, dirt
	UnionPolitics.monthly(world, st)   # unions in politics (Ella, A41 U3): endorsements, betrayal, union money


## Generational replacement / changing times: each value cohort drifts slowly (random walk), and so do
## the bases of its cells.
func _zeitgeist(world: WorldState, st: Dictionary) -> void:
	var r := world.rng.stream("pol.zeitgeist")
	var cohorts: Dictionary = st["culture"]["cohorts"]
	if PolVoters.leaves_mode(world):
		cohorts = Philosophy.ensure(world)  # the people's philosophies drift instead of the legacy cohorts
	var names: Array = cohorts.keys()
	names.sort()
	var delta := {}
	for cname in names:
		delta[cname] = {}
		for ax in PolDefs.AXES:
			var off: int = cohorts[cname]["offset"][ax]
			var d := int(round(r.randfn(0.0, PolDefs.ZEITGEIST_SD) * S))
			d -= int(round(float(off) * 0.02))  # weak mean reversion keeps cohorts within bounds
			cohorts[cname]["offset"][ax] = off + d
			delta[cname][ax] = d
	var gen := int(round(PolDefs.SOV_GENERATIONAL_DRIFT * S)) if HomeWorld.colonial(world) else 0
	for cell in PolVoters.all(world):
		cell["base"]["SOVEREIGNTY"] = clampi(cell["base"]["SOVEREIGNTY"] + gen, -100 * S, 100 * S)
		var dc: Dictionary = delta.get(cell["cohort"], {})
		for ax in dc:
			cell["base"][ax] = clampi(cell["base"][ax] + int(dc[ax]), -100 * S, 100 * S)


## News sets the agenda: big public facts raise the salience of the concerns they touch, decaying over months.
func _agenda_monthly(world: WorldState, st: Dictionary) -> Dictionary:
	var boost: Dictionary = st.get("agenda_boost", {})
	for c in boost.keys():
		boost[c] = int(float(boost[c]) * PolDefs.AGENDA_HALF_LIFE_FACTOR)
		if boost[c] < 5:
			boost.erase(c)
	for f in world.facts.query("", world.month, world.month, "PUBLIC"):
		if int(f.get("magnitude", 0)) < 60:
			continue
		for c in f["impact"]:
			if PolDefs.CONCERNS.has(c):
				boost[c] = mini(300, int(boost.get(c, 0)) + int(absf(float(f["impact"][c])) * float(f["magnitude"]) / 100.0 * 15.0))
	st["agenda_boost"] = boost
	return boost


## People drift toward the views of their neighbours: pop-weighted district mean ideology.
func _district_means(world: WorldState) -> Dictionary:
	var acc := {}
	var pop := {}
	for c in PolVoters.all(world):
		var d: String = c["district"]
		if not acc.has(d):
			acc[d] = PolDefs.zero_axes()
			pop[d] = 0.0
		pop[d] += c["pop"]
		for ax in PolDefs.AXES:
			acc[d][ax] += float(c["ideology"][ax]) * c["pop"]
	for d in acc:
		for ax in PolDefs.AXES:
			acc[d][ax] = acc[d][ax] / maxf(1.0, pop[d])
	return acc

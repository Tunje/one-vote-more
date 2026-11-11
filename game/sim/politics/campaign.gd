class_name Campaign
extends RefCounted
## Election year (planning/spec-election-year-v1.md; owner Ella): themes, ads, ground game, debates,
## attack ads with backfire, opposition research, held dirt and smears, momentum, tactical support votes.
## Stateless. State: world.table("campaign")[cid] (one row per campaign), pol.state["campaign_id"] = open one.
## All stored numbers are ints (utility in milli). Every fact is PUBLIC with data.channel for the media step (S8).

const S := 1000
# ---- calendar ----
const WINDOW_ORDINARY := 12          # election year opens 12 months out
const WINDOW_EXTRA := 3              # compressed campaign before an extra election
const SHORT_CAMPAIGN := 2            # months before the election: valstugor, debates, full spending
const POLITICS_WEEK_MONTH := 7       # July (Almedalen-style), ordinary campaigns only
# ---- money ----
const SPEND_LONG := 80               # per-mille of party funds per month in the long campaign
const SPEND_SHORT := 300             # per-mille per month in the short campaign
# ---- persuasion (utility, milli) ----
const BETA_AD := 45                  # ad utility increment per month at average spend and quality 1
const BETA_ATTACK := 55              # attack-ad utility loss for the target per month
const PERSUASION_DECAY := 750        # per-mille kept each month
const PERSUASION_CAP := 500
const BACKFIRE_RATE := 450           # per-mille of an attack's damage that lands on the attacker among civil voters
const CIVILITY := {"INSTITUTION": 1000, "STABILITY": 1000, "LIBERTY": 500, "ENVIRONMENT": 400,
	"TRAD": 800, "PRAG": 600, "PROG": 400}
const CIVILITY_DEFAULT := 300
const CAMPAIGN_U_CAP := 800          # total campaign utility per party per voter, ±
# ---- ground game ----
const MOB_SCALE := 30                # milli: turnout uplift among a party's leaners at average spend
const MOB_MAX := 60
const MOB_UNION := 15                # the union-endorsed party's volunteers
# ---- momentum ----
const MOMENTUM_DECAY := 700
const MOMENTUM_CAP := 400
const DEBATE_WIN := 200
const FINAL_DEBATE_WIN := 250
const DEBATE_LOSS := -150
const GAFFE_MOMENTUM := -250
const GAFFE_POPULARITY := 6
const KILLER_LINE := -100
const SPEECH_SCALE := 250            # momentum per 100 points of speech performance above the mean
const BANDWAGON := 50                # a party up 2 pp in a campaign poll
# ---- themes ----
const THEME_BOOST := 14              # per-mille salience per month at average spend
const AGENDA_CAP := 300
# ---- dirt ----
const OPPO_P := 80                   # per-mille chance per month to find something, at average spend and quality 1
const OPPO_P_MAX := 250
const LEAK_P := 60                   # held dirt leaks per month ("they sat on it")
const SMEAR_P := 300                 # a desperate low-integrity campaign fabricates something
const SMEAR_MAX_INTEGRITY := 35
const SMEAR_EXPOSE_P := 350
const SAT_ON_IT := -150
# ---- pork (valfläsk) ----
const PORK_FROM := 4                 # bills tabled later than T−4 can't be passed in time
const PORK_BETA := 600               # momentum (milli) per unit of colony relief, at full credibility
const PORK_CRED_PIVOT := 35          # below this credibility voters see through it and punish it
# ---- tactical votes ----
const TACTICAL_LOW := 2500           # per-100000 share: allies between 2.5% and the threshold get support votes
const TACTICAL_TARGET := 4300
const TACTICAL_MAX_FRAC := 0.08      # at most 8% of the largest partner's voters lend their vote

const Det := preload("res://sim/staff/det.gd")
const PF_PATH := "res://sim/law/party_finance.gd"
const JUSTICE_PATH := "res://sim/law/justice_ops.gd"
const DEFAMATION_CREDIBILITY := 8     # a smearer convicted of defamation (on top of the exposure hit)


## Optional law hooks (Anni): call a static function on PartyFinance if it exists; else return `fallback`.
static func _law_call(fn: String, args: Array, fallback: Variant, path: String = PF_PATH) -> Variant:
	var s: Script = load(path)
	if s == null:
		return fallback
	for m in s.get_script_method_list():
		if String(m["name"]) == fn:
			return s.callv(fn, args)
	return fallback


# ======================================================================= calendar

## {month, extra} of the next election, or {} when none is scheduled.
static func next_election(st: Dictionary, month: int) -> Dictionary:
	var ord := int(st.get("next_election", -1))
	var ex := int(st.get("extra_election_month", -1))
	if ex >= month and ord - ex > 3:
		return {"month": ex, "extra": true}
	if ord >= month:
		return {"month": ord, "extra": false}
	return {}


static func current(world: WorldState) -> Dictionary:
	var st: Dictionary = world.peek("pol").get("state", {})
	var cid := String(st.get("campaign_id", ""))
	return world.peek("campaign").get(cid, {}) if cid != "" else {}


## Election-year pork pressure for AI governments' bills (Legislature.propose): 1 from T−12 to T−4, else 0.
## world.meta["pork"] = false switches it off (A/B measurement).
static func pork_pressure(world: WorldState, st: Dictionary) -> float:
	if not bool(world.meta.get("pork", true)):
		return 0.0
	var c := current(world)
	if c.is_empty():
		return 0.0
	var to_go := int(c["election_month"]) - world.month
	return 1.0 if to_go >= PORK_FROM and to_go <= WINDOW_ORDINARY else 0.0


## Pollsters swarm the short campaign: a poll every month from T−2 to T−1 (not on election day).
static func wants_poll(world: WorldState, st: Dictionary) -> bool:
	var c := current(world)
	if c.is_empty():
		return false
	var to_go := int(c["election_month"]) - world.month
	return to_go >= 1 and to_go <= SHORT_CAMPAIGN


static func is_open(world: WorldState) -> bool:
	return not current(world).is_empty()


# ======================================================================= monthly

## Called from PoliticsProvider._party_life_monthly (before the election in the same month).
static func monthly(world: WorldState, st: Dictionary) -> void:
	_defamation_verdicts(world, st)
	_finalize_past(world, st)
	var ne := next_election(st, world.month)
	if ne.is_empty():
		return
	var to_go: int = int(ne["month"]) - world.month
	var window := WINDOW_EXTRA if ne["extra"] else WINDOW_ORDINARY
	var c: Dictionary = _row(world, st)
	if not c.is_empty() and int(c["election_month"]) != int(ne["month"]):
		_close(world, st, c, "SUPERSEDED")   # an extra election was called mid-campaign
		c = {}
	if c.is_empty():
		if to_go > window:
			return
		c = _open(world, st, int(ne["month"]), bool(ne["extra"]))
	if int(c.get("month", -1)) == world.month:
		return   # idempotent within a month (tests may call it next to the provider's hook)
	c["month"] = world.month
	c["to_go"] = to_go
	var seg := segments(world)
	_ensure_parties(world, st, c, seg)
	_decay(c)
	if to_go == SHORT_CAMPAIGN or (bool(c["extra"]) and to_go == WINDOW_EXTRA):
		_replan_tone(world, st, c)
	var spend := _spend(world, c, to_go)
	_ads(world, c, seg, spend)
	_ground(world, c, spend)
	_themes(world, st, c, spend)
	_bandwagon(world, c)
	if not bool(c["extra"]) and world.month_of_year() == POLITICS_WEEK_MONTH and to_go >= 1:
		_politics_week(world, c)
	if to_go <= 1:
		_debate(world, st, c, to_go == 0)
	_oppo(world, c, spend, to_go)
	_dirt(world, st, c, to_go)
	_pork(world, st, c)
	# legacy hook: the old spend counter (UI/chronicle readers)
	var spent := {}
	for pid in c["parties"]:
		spent[pid] = int(c["parties"][pid]["spent"])
	st["campaign_spent"] = spent


static func _row(world: WorldState, st: Dictionary) -> Dictionary:
	var cid := String(st.get("campaign_id", ""))
	return world.table("campaign").get(cid, {}) if cid != "" else {}


static func _open(world: WorldState, st: Dictionary, month: int, extra: bool) -> Dictionary:
	var cid := world.new_id("campaign")
	var start := PartyLife.latest_poll_shares(world)
	if start.is_empty():
		for p in PartyLife.active(world):
			start[p["id"]] = int(p["support"])
	var c := {"id": cid, "election_month": month, "extra": extra, "opened": world.month, "to_go": month - world.month,
		"status": "OPEN", "parties": {}, "debates": [], "events": [], "start_poll": start.duplicate(),
		"last_poll_seen": "", "result": {}}
	world.table("campaign")[cid] = c
	st["campaign_id"] = cid
	world.add_fact({"type": "POL_CAMPAIGN_OPENED", "owner": "pol", "subjects": [], "responsible": [], "impact": {},
		"magnitude": 50 if not extra else 60, "visibility": "PUBLIC",
		"data": {"campaign": cid, "election_month": month, "extra": extra, "channel": "CAMPAIGN"}})
	return c


static func _close(world: WorldState, st: Dictionary, c: Dictionary, status: String) -> void:
	c["status"] = status
	st.erase("campaign_id")


## The month after the vote: record what the campaign did to the parties (pp moved since it opened).
static func _finalize_past(world: WorldState, st: Dictionary) -> void:
	var c := _row(world, st)
	if c.is_empty() or int(c["election_month"]) >= world.month:
		return
	var els: Array = st.get("elections", [])
	var res := {}
	if not els.is_empty():
		var e: Dictionary = world.table("election")[els.back()]
		if int(e["month"]) == int(c["election_month"]):
			for pid in e["votes"]:
				res[pid] = int(round(float(e["votes"][pid]) / maxf(1.0, float(e["total"])) * 100000.0))
	var moved := {}
	for pid in res:
		moved[pid] = int(res[pid]) - int(c["start_poll"].get(pid, 0))
	c["result"] = {"shares": res, "moved": moved}
	_close(world, st, c, "DONE")


# ======================================================================= voter segments

## Segments = district × opinion-occupation. {seg_key: {pop, sal{concern: per-mille}, cohorts{name: pop}}}
static func segments(world: WorldState) -> Dictionary:
	var out := {}
	for v in PolVoters.all(world):
		var pop := int(v["pop"])
		if pop <= 0:
			continue
		var k := seg_key(v)
		if not out.has(k):
			out[k] = {"pop": 0, "sal": {}, "cohorts": {}}
		var s: Dictionary = out[k]
		s["pop"] = int(s["pop"]) + pop
		for cn in v["salience"]:
			s["sal"][cn] = int(s["sal"].get(cn, 0)) + int(v["salience"][cn]) * pop
		var co := String(v.get("cohort", ""))
		s["cohorts"][co] = int(s["cohorts"].get(co, 0)) + pop
	for k in out:
		var s: Dictionary = out[k]
		for cn in s["sal"]:
			s["sal"][cn] = int(s["sal"][cn]) / maxi(1, int(s["pop"]))
	return out


static func seg_key(v: Dictionary) -> String:
	return "%s|%s" % [String(v.get("district", "")), PolVoters.vocc(v)]


# ======================================================================= planning

static func _ensure_parties(world: WorldState, st: Dictionary, c: Dictionary, seg: Dictionary) -> void:
	for p in PartyLife.active(world):
		var pid: String = p["id"]
		PartyLife.open_account(world, pid)
		if not c["parties"].has(pid):
			c["parties"][pid] = {"themes": [], "tone": "POSITIVE", "target": "", "split": {"ad": 550, "ground": 350, "oppo": 100},
				"spent": 0, "ad": 0, "ground": 0, "oppo": 0, "quality": 0, "momentum": 0, "mob": 0,
				"persuasion": {}, "backfire": {}, "dirt": [], "attacks": 0, "manual": false}
			_plan(world, st, c, p, seg)   # a human player starts from the AI's suggestion, then owns the plan
			c["parties"][pid]["manual"] = bool(p.get("is_player", false)) and not bool(st.get("autoplay_player", true))
		var e: Dictionary = c["parties"][pid]
		e["quality"] = quality(world, st, p)


## AI plan (a human player's plan is set through PolActions and marked manual).
static func _plan(world: WorldState, st: Dictionary, c: Dictionary, p: Dictionary, seg: Dictionary) -> void:
	var e: Dictionary = c["parties"][p["id"]]
	if bool(e["manual"]):
		return
	e["themes"] = pick_themes(world, st, p, seg)
	e["target"] = pick_target(world, st, p)
	_set_tone(world, st, c, p, e)


## Owned concerns the voters care about: the opposition picks failures, government parties their record.
static func pick_themes(world: WorldState, st: Dictionary, p: Dictionary, seg: Dictionary) -> Array:
	var gov: Array = st.get("government", {}).get("members", [])
	var in_gov := gov.has(p["id"])
	var colony_sal := {}
	var tot := 0
	for k in seg:
		tot += int(seg[k]["pop"])
		for cn in seg[k]["sal"]:
			colony_sal[cn] = int(colony_sal.get(cn, 0)) + int(seg[k]["sal"][cn]) * int(seg[k]["pop"])
	var scored: Array = []
	for cn in PolDefs.CONCERNS:
		var own := float(p.get("ownership", {}).get(cn, 0)) + 10.0
		var sal := float(colony_sal.get(cn, 0)) / maxf(1.0, float(tot))
		var sat := float(PartyLife._colony_sat(world, cn)) / 100000.0
		var fit := sat if in_gov else 1.0 - sat
		scored.append([own * sal * (0.3 + fit), cn])
	scored.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
	return [scored[0][1], scored[1][1]]


## Who to fight: the opposition goes after the PM's party; governing parties after the largest opposition party.
static func pick_target(world: WorldState, st: Dictionary, p: Dictionary) -> String:
	var gov: Dictionary = st.get("government", {})
	var members: Array = gov.get("members", [])
	var pm := String(gov.get("pm_party", ""))
	if pm != "" and not members.has(p["id"]) and world.table("party").has(pm) and world.table("party")[pm]["status"] == "ACTIVE":
		return pm
	var best := ""
	var best_s := -1
	for q in PartyLife.active(world):
		if q["id"] == p["id"] or members.has(q["id"]):
			continue
		if int(q["support"]) > best_s:
			best_s = int(q["support"])
			best = q["id"]
	return best


## Tone: trailing parties go negative, the opposition a bit more, high-integrity leaders resist.
static func _set_tone(world: WorldState, st: Dictionary, c: Dictionary, p: Dictionary, e: Dictionary) -> void:
	if bool(e["manual"]):
		return
	var integ := float(p.get("leader", {}).get("integrity", 50)) if typeof(p.get("leader")) == TYPE_DICTIONARY else 50.0
	var start := float(c["start_poll"].get(p["id"], p["support"]))
	var now := float(PartyLife.latest_poll_shares(world).get(p["id"], p["support"]))
	var trailing := clampf((start - now) / 3000.0, 0.0, 1.0) * 0.25          # lost ≥3 pp during the campaign
	var last := float(st.get("last_result", {}).get(p["id"], start))
	trailing += clampf((last - now) / 4000.0, 0.0, 1.0) * 0.2               # below the last election
	var opp := 0.1 if not st.get("government", {}).get("members", []).has(p["id"]) else 0.0
	var n := 0.2 + trailing + opp - integ / 200.0
	var tone := "NEGATIVE" if n > 0.15 else ("MIXED" if n > 0.0 else "POSITIVE")
	if e["target"] == "":
		tone = "POSITIVE"
	e["tone"] = tone
	e["split"] = SPLITS[tone].duplicate()


static func _replan_tone(world: WorldState, st: Dictionary, c: Dictionary) -> void:
	for p in PartyLife.active(world):
		var e: Dictionary = c["parties"][p["id"]]
		var before := String(e["tone"])
		if not bool(e["manual"]):
			e["target"] = pick_target(world, st, p)
		_set_tone(world, st, c, p, e)
		if before != "NEGATIVE" and e["tone"] == "NEGATIVE":
			_event(world, c, "POL_CAMPAIGN_GOES_NEGATIVE", "AD", [p["id"], e["target"]], 45,
				{"party": p["id"], "target": e["target"]})


## 0.5..1.0 (milli): staff campaign effort (a9's STAFF_T_CAMPAIGN) and the leader's charisma.
static func quality(world: WorldState, st: Dictionary, p: Dictionary) -> int:
	var eff := 0
	var pm := String(st.get("government", {}).get("pm_party", ""))
	var tasks := world.peek("task")
	for tid in Det.ordered(tasks):
		var t: Dictionary = tasks[tid]
		if t.get("def_id", "") != "STAFF_T_CAMPAIGN" or t.get("status", "") != "ACTIVE":
			continue
		var o: Dictionary = t.get("owner", {})
		var mine: bool = (o.get("kind", "") == "PARTY" and o.get("id", "") == p["id"]) or (o.get("kind", "") == "GOVERNMENT" and pm == p["id"])
		if mine:
			eff = maxi(eff, int(t.get("effectiveness", 0)))
	var ch := float(p.get("leader", {}).get("charisma", 50)) if typeof(p.get("leader")) == TYPE_DICTIONARY else 50.0
	return int(round(500.0 + 250.0 * clampf(float(eff) / 1000.0, 0.0, 1.0) + 250.0 * ch / 100.0))


# ======================================================================= money

## Spending this month per party {pid: {ad, ground, oppo}} (milli-credits), paid to households (closed economy).
static func _spend(world: WorldState, c: Dictionary, to_go: int) -> Dictionary:
	var rate := SPEND_SHORT if (to_go <= SHORT_CAMPAIGN or bool(c["extra"])) else SPEND_LONG
	var out := {}
	for pid in Det.ordered(c["parties"]):
		var p: Dictionary = world.table("party").get(pid, {})
		if p.is_empty() or p["status"] != "ACTIVE":
			continue
		var e: Dictionary = c["parties"][pid]
		var acc: String = "party:" + pid
		var amt := 0
		if world.ledger.has_account(acc):
			amt = maxi(0, world.ledger.balance(acc)) * rate / 1000
		var oppo := amt * int(e["split"]["oppo"]) / 1000 if to_go >= 1 else 0
		var ground := amt * int(e["split"]["ground"]) / 1000
		var ad := amt - oppo - ground
		if amt > 0:
			PartyLife._household_receive(world, acc, amt, "CAMPAIGN")
		e["spent"] = int(e["spent"]) + amt
		e["ad"] = int(e["ad"]) + ad
		e["ground"] = int(e["ground"]) + ground
		e["oppo"] = int(e["oppo"]) + oppo
		out[pid] = {"ad": ad, "ground": ground, "oppo": oppo}
	return out


## amount / mean of the positive amounts (0 when nobody spends).
static func _rel(spend: Dictionary, pid: String, kind: String) -> float:
	var tot := 0.0
	var n := 0
	for q in spend:
		var a := float(spend[q][kind])
		if a > 0.0:
			tot += a
			n += 1
	if n == 0 or not spend.has(pid):
		return 0.0
	return float(spend[pid][kind]) / (tot / float(n))


# ======================================================================= persuasion

static func _decay(c: Dictionary) -> void:
	for pid in c["parties"]:
		var e: Dictionary = c["parties"][pid]
		for k in e["persuasion"].keys():
			e["persuasion"][k] = int(e["persuasion"][k]) * PERSUASION_DECAY / 1000
			if absi(int(e["persuasion"][k])) < 2:
				e["persuasion"].erase(k)
		for k in e["backfire"].keys():
			e["backfire"][k] = int(e["backfire"][k]) * PERSUASION_DECAY / 1000
			if absi(int(e["backfire"][k])) < 2:
				e["backfire"].erase(k)
		e["momentum"] = int(e["momentum"]) * MOMENTUM_DECAY / 1000


## Targeting weights: segments where the party's themes are salient (and its owned concerns matter).
static func _targeting(c: Dictionary, p: Dictionary, seg: Dictionary) -> Dictionary:
	var e: Dictionary = c["parties"][p["id"]]
	var w := {}
	var tot := 0.0
	var n := 0
	for k in Det.ordered(seg):
		var fit := 0.3
		for cn in e["themes"]:
			fit += (float(p.get("ownership", {}).get(cn, 0)) + 20.0) / 100.0 * float(seg[k]["sal"].get(cn, 0)) / 100.0
		w[k] = fit
		tot += fit
		n += 1
	var mean := tot / maxf(1.0, float(n))
	for k in w:
		w[k] = clampf(float(w[k]) / maxf(0.001, mean), 0.2, 2.5)
	return w


static func _ads(world: WorldState, c: Dictionary, seg: Dictionary, spend: Dictionary) -> void:
	for pid in Det.ordered(spend):
		var p: Dictionary = world.table("party")[pid]
		var e: Dictionary = c["parties"][pid]
		var rel := _rel(spend, pid, "ad")
		if rel <= 0.0:
			continue
		var q := float(e["quality"]) / 1000.0
		var power := sqrt(minf(rel, 4.0)) * q
		var attack_share := {"POSITIVE": 0.0, "MIXED": 0.25, "NEGATIVE": 0.5}[e["tone"]] as float
		var tgt := String(e["target"])
		if tgt == "" or not c["parties"].has(tgt):
			attack_share = 0.0
		var w := _targeting(c, p, seg)
		var hit := 0.0
		for k in w:
			var inc := float(BETA_AD) * power * (1.0 - attack_share) * float(w[k])
			_add(e["persuasion"], k, inc, PERSUASION_CAP)
			if attack_share > 0.0:
				var dmg := float(BETA_ATTACK) * power * attack_share * float(w[k]) * vulnerability(world.table("party")[tgt])
				_add(c["parties"][tgt]["persuasion"], k, -dmg, PERSUASION_CAP)
				hit += dmg * float(seg[k]["pop"])
		if hit > 0.0:
			e["attacks"] = int(e["attacks"]) + 1
			_backfire(c, pid, seg, hit)
			if int(e["attacks"]) == 1:
				_event(world, c, "POL_ATTACK_AD", "AD", [pid, tgt], 40, {"party": pid, "target": tgt, "tone": e["tone"]})


## 0.6..1.2: low credibility (broken promises) and an unpopular leader make attacks stick.
static func vulnerability(p: Dictionary) -> float:
	var v := 0.6 + 0.4 * (1.0 - float(p.get("credibility", 50)) / 100.0)
	if PartyLife.leader_popularity(p) < 40:
		v += 0.2
	return v


## Voters who prize civility punish the attacker: per-cohort utility loss.
static func _backfire(c: Dictionary, pid: String, seg: Dictionary, hit_popweighted: float) -> void:
	var pop := 0.0
	for k in seg:
		pop += float(seg[k]["pop"])
	var mean_dmg := hit_popweighted / maxf(1.0, pop)
	var e: Dictionary = c["parties"][pid]
	for co in CIVILITY:
		_add(e["backfire"], co, -mean_dmg * float(BACKFIRE_RATE) / 1000.0 * float(CIVILITY[co]) / 1000.0 * 3.0, PERSUASION_CAP)
	_add(e["backfire"], "*", -mean_dmg * float(BACKFIRE_RATE) / 1000.0 * float(CIVILITY_DEFAULT) / 1000.0 * 3.0, PERSUASION_CAP)


static func _add(d: Dictionary, k: String, v: float, cap: int) -> void:
	d[k] = clampi(int(d.get(k, 0)) + int(round(v)), -cap, cap)


# ======================================================================= ground game & themes

static func _ground(world: WorldState, c: Dictionary, spend: Dictionary) -> void:
	var cum := {}
	var tot := 0.0
	var n := 0
	for pid in c["parties"]:
		if not spend.has(pid):
			continue
		cum[pid] = float(c["parties"][pid]["ground"])
		if cum[pid] > 0.0:
			tot += cum[pid]
			n += 1
	var mean := tot / maxf(1.0, float(n))
	var union := String(PartyLife.endorsements(world).get("union", ""))
	for pid in cum:
		var e: Dictionary = c["parties"][pid]
		var rel := float(cum[pid]) / maxf(1.0, mean) if mean > 0.0 else 0.0
		var m := float(MOB_SCALE) * sqrt(minf(rel, 4.0)) * float(e["quality"]) / 1000.0
		if pid == union:
			m += float(MOB_UNION)
		e["mob"] = clampi(int(round(m)), 0, MOB_MAX)


## The battle over what the election is about: pushed themes become salient (news agenda, decays monthly).
static func _themes(world: WorldState, st: Dictionary, c: Dictionary, spend: Dictionary) -> void:
	var boost: Dictionary = st.get("agenda_boost", {})
	for pid in Det.ordered(spend):
		var e: Dictionary = c["parties"][pid]
		var rel := _rel(spend, pid, "ad")
		var b := int(round(float(THEME_BOOST) * sqrt(minf(rel, 4.0)) * float(e["quality"]) / 1000.0 / float(maxi(1, e["themes"].size()))))
		for cn in e["themes"]:
			boost[cn] = mini(AGENDA_CAP, int(boost.get(cn, 0)) + b)
	st["agenda_boost"] = boost


# ======================================================================= momentum: polls, speeches, debates

static func _bandwagon(world: WorldState, c: Dictionary) -> void:
	var st: Dictionary = world.table("pol")["state"]
	var lp := String(st.get("last_poll", ""))
	if lp == "" or lp == String(c["last_poll_seen"]) or not world.table("poll").has(lp):
		return
	var prev := String(c["last_poll_seen"])
	c["last_poll_seen"] = lp
	if prev == "" or not world.table("poll").has(prev):
		return
	var a: Dictionary = world.table("poll")[prev]["estimates"]
	var b: Dictionary = world.table("poll")[lp]["estimates"]
	for pid in Det.ordered(c["parties"]):
		if int(b.get(pid, 0)) - int(a.get(pid, 0)) >= 2000:
			_momentum(c, pid, BANDWAGON)


static func _momentum(c: Dictionary, pid: String, d: int) -> void:
	var e: Dictionary = c["parties"][pid]
	e["momentum"] = clampi(int(e["momentum"]) + d, -MOMENTUM_CAP, MOMENTUM_CAP)


static func _leader(p: Dictionary) -> Dictionary:
	return p["leader"] if typeof(p.get("leader")) == TYPE_DICTIONARY else {"name": String(p.get("leader", "")), "charisma": 50, "competence": 50, "integrity": 50, "popularity": 50}


## 0..100-ish performance on a stage: charisma, competence, staff preparation, luck.
static func performance(c: Dictionary, p: Dictionary, r: RandomNumberGenerator, sd: float) -> float:
	var l := _leader(p)
	var prep := float(c["parties"][p["id"]]["quality"]) / 10.0 - 50.0  # 0..50
	return 0.5 * float(l["charisma"]) + 0.3 * float(l["competence"]) + 0.2 * prep * 2.0 + r.randfn(0.0, sd)


static func _stage_parties(world: WorldState, c: Dictionary) -> Array:
	var out: Array = []
	var poll := PartyLife.latest_poll_shares(world)
	for p in PartyLife.active(world):
		var share := maxi(int(p["support"]), int(poll.get(p["id"], 0)))
		if c["parties"].has(p["id"]) and (int(p["seats"]) > 0 or share >= 2000):
			out.append(p)
	return out


## Politics week (Almedalen-style): one speech per leader sets the summer narrative.
static func _politics_week(world: WorldState, c: Dictionary) -> void:
	var r := world.rng.stream("pol.campaign.stage")
	var ps := _stage_parties(world, c)
	if ps.size() < 2:
		return
	var perf := {}
	var tot := 0.0
	for p in ps:
		perf[p["id"]] = performance(c, p, r, 12.0)
		tot += perf[p["id"]]
	var mean := tot / float(ps.size())
	var best := ""
	var worst := ""
	for p in ps:
		var pid: String = p["id"]
		_momentum(c, pid, int(round((float(perf[pid]) - mean) / 100.0 * float(SPEECH_SCALE))))
		if best == "" or perf[pid] > perf[best]:
			best = pid
		if worst == "" or perf[pid] < perf[worst]:
			worst = pid
	_event(world, c, "POL_POLITICS_WEEK", "RALLY", [best, worst], 45, {"best": best, "worst": worst})


## Leaders' debate (to_go 1) and the final debate (election month, before the vote).
static func _debate(world: WorldState, st: Dictionary, c: Dictionary, final: bool) -> void:
	var r := world.rng.stream("pol.campaign.stage")
	var ps := _stage_parties(world, c)
	if ps.size() < 2:
		return
	var perf := {}
	var gaffes: Array = []
	for p in ps:
		var pid: String = p["id"]
		perf[pid] = performance(c, p, r, 15.0)
		var l := _leader(p)
		var pg := clampf(0.04 + (60.0 - float(l["competence"])) / 600.0, 0.01, 0.12)
		if r.randf() < pg:
			gaffes.append(pid)
			perf[pid] -= 25.0
	var order: Array = perf.keys()
	order.sort_custom(func(a, b): return perf[a] > perf[b] or (perf[a] == perf[b] and a < b))
	var winner: String = order[0]
	var loser: String = order[order.size() - 1]
	_momentum(c, winner, FINAL_DEBATE_WIN if final else DEBATE_WIN)
	_momentum(c, loser, DEBATE_LOSS)
	# the winner's killer line lands on their campaign target
	var tgt := String(c["parties"][winner]["target"])
	var killer := ""
	if tgt != "" and c["parties"].has(tgt) and tgt != winner and world.table("party")[tgt]["status"] == "ACTIVE":
		killer = tgt
		_momentum(c, tgt, int(round(float(KILLER_LINE) * vulnerability(world.table("party")[tgt]))))
	for pid in gaffes:
		_momentum(c, pid, GAFFE_MOMENTUM)
		var l: Dictionary = world.table("party")[pid]["leader"] if typeof(world.table("party")[pid].get("leader")) == TYPE_DICTIONARY else {}
		if not l.is_empty():
			l["popularity"] = clampi(int(l["popularity"]) - GAFFE_POPULARITY, 0, 100)
		_event(world, c, "POL_DEBATE_GAFFE", "DEBATE", [pid], 60,
			{"party": pid, "leader": PartyLife.leader_name(world.table("party")[pid]), "final": final})
	var d := {"month": world.month, "final": final, "winner": winner, "loser": loser, "killer_on": killer, "gaffes": gaffes}
	c["debates"].append(d)
	var data := d.duplicate()
	_event(world, c, "POL_DEBATE_HELD", "DEBATE", [winner, loser], 70 if final else 55, data)


# ======================================================================= dirt

## Opposition research: a chance each month to find something on the target. Real secrets (illegal donations
## tracked by law) first; else the leader's personal failings (likelier for low-integrity leaders); a desperate
## low-integrity campaign may fabricate a smear instead.
static func _oppo(world: WorldState, c: Dictionary, spend: Dictionary, to_go: int) -> void:
	if to_go < 1:
		return
	var r := world.rng.stream("pol.campaign.oppo")
	for pid in Det.ordered(spend):
		var e: Dictionary = c["parties"][pid]
		var tgt := String(e["target"])
		if tgt == "" or not world.table("party").has(tgt) or world.table("party")[tgt]["status"] != "ACTIVE":
			continue
		var rel := _rel(spend, pid, "oppo")
		var found := false
		if rel > 0.0:
			var pf := minf(float(OPPO_P_MAX), float(OPPO_P) * sqrt(minf(rel, 4.0)) * float(e["quality"]) / 1000.0) / 1000.0
			if r.randf() < pf:
				found = _find_dirt(world, c, pid, tgt, r)
		var me := _leader(world.table("party")[pid])
		if not found and e["tone"] == "NEGATIVE" and int(me["integrity"]) <= SMEAR_MAX_INTEGRITY and not _has_smear(e) \
				and to_go <= SHORT_CAMPAIGN + 1 and r.randf() < float(SMEAR_P) / 1000.0:
			e["dirt"].append({"kind": "SMEAR", "target": tgt, "fid": "", "sev": 30, "found": world.month, "released": -1, "exposed": false})


static func _has_smear(e: Dictionary) -> bool:
	for d in e["dirt"]:
		if d["kind"] == "SMEAR":
			return true
	return false


static func _taken(c: Dictionary, fid: String) -> bool:
	for pid in c["parties"]:
		for d in c["parties"][pid]["dirt"]:
			if d["fid"] == fid:
				return true
	return false


static func _find_dirt(world: WorldState, c: Dictionary, pid: String, tgt: String, r: RandomNumberGenerator) -> bool:
	var e: Dictionary = c["parties"][pid]
	var track := world.peek("donation_track")
	for fid in Det.ordered(track):
		var t: Dictionary = track[fid]
		if String(t.get("party", "")) == tgt and not bool(t.get("revealed", true)) and not _taken(c, fid):
			e["dirt"].append({"kind": "DONATION", "target": tgt, "fid": fid, "sev": 60, "found": world.month, "released": -1, "exposed": false})
			return true
	var tl := _leader(world.table("party")[tgt])
	var n_personal := 0
	for q in c["parties"]:   # one leader's private life is one story per campaign, whoever digs it up first
		for d in c["parties"][q]["dirt"]:
			if d["kind"] == "PERSONAL" and d["target"] == tgt:
				n_personal += 1
	if n_personal == 0 and r.randf() < (100.0 - float(tl["integrity"])) / 100.0:
		var sev := clampi(int(round(15.0 + (100.0 - float(tl["integrity"])) / 4.0 + r.randfn(0.0, 5.0))), 10, 45)
		e["dirt"].append({"kind": "PERSONAL", "target": tgt, "fid": "", "sev": sev, "found": world.month, "released": -1, "exposed": false})
		return true
	return false


## Release or hold. Honest leaders release at once; strategists hold for a late hit in the final weeks,
## at the risk of it leaking that they sat on it. Exposed smears backfire (and go to court when law allows).
static func _dirt(world: WorldState, st: Dictionary, c: Dictionary, to_go: int) -> void:
	var r := world.rng.stream("pol.campaign.dirt")
	for pid in Det.ordered(c["parties"]):
		var e: Dictionary = c["parties"][pid]
		if not world.table("party").has(pid) or world.table("party")[pid]["status"] != "ACTIVE":
			continue
		var integ := int(_leader(world.table("party")[pid])["integrity"])
		for d in e["dirt"]:
			if int(d["released"]) >= 0:
				if d["kind"] == "SMEAR" and not bool(d["exposed"]) and r.randf() < float(SMEAR_EXPOSE_P) / 1000.0:
					_expose_smear(world, c, pid, d)
				continue
			if not world.table("party").has(String(d["target"])) or world.table("party")[d["target"]]["status"] != "ACTIVE":
				d["released"] = 0   # moot
				continue
			var hold: bool = bool(e["manual"]) or (integ < 60 and to_go > 1)
			if bool(e["manual"]) and to_go == 0:
				hold = false     # a player who never pulled the trigger: it comes out on election day anyway
			if hold:
				if not bool(e["manual"]) and r.randf() < float(LEAK_P) / 1000.0:
					release(world, c, pid, d, true)
				continue
			release(world, c, pid, d, false)


## Release one piece of dirt (also the player's action). leaked: it came out that the holder sat on it.
static func release(world: WorldState, c: Dictionary, pid: String, d: Dictionary, leaked: bool = false) -> void:
	d["released"] = world.month
	var tgt: String = d["target"]
	var tp: Dictionary = world.table("party")[tgt]
	var revealed_by_law := false
	if d["kind"] == "DONATION":
		revealed_by_law = bool(_law_call("reveal_by_rival", [world, String(d["fid"]), pid], false))
	if not revealed_by_law:
		var tl: Dictionary = tp["leader"] if typeof(tp.get("leader")) == TYPE_DICTIONARY else {}
		if not tl.is_empty():
			tl["popularity"] = clampi(int(tl["popularity"]) - int(d["sev"]) / 3, 0, 100)
	_momentum(c, tgt, -int(d["sev"]) * 5)
	var seg := segments(world)
	_backfire(c, pid, seg, float(d["sev"]) * 0.5 * _total_pop(seg))
	if leaked:
		_momentum(c, pid, SAT_ON_IT)
	_event(world, c, "POL_DIRT_RELEASED", "OPPO", [pid, tgt], clampi(45 + int(d["sev"]) / 2, 45, 80),
		{"party": pid, "target": tgt, "kind": d["kind"], "severity": d["sev"], "leaked": leaked, "fact": d["fid"],
			"leader": PartyLife.leader_name(tp), "by_law": revealed_by_law})


static func _total_pop(seg: Dictionary) -> float:
	var t := 0.0
	for k in seg:
		t += float(seg[k]["pop"])
	return t


## Anni's courts rule on exposed smears (JUSTICE runs before POLITICS): a guilty smearer loses credibility.
## Verdicts can come after the campaign closed, so this runs every month; handled verdicts are remembered.
static func _defamation_verdicts(world: WorldState, st: Dictionary) -> void:
	for f in world.facts.query("LAW_DEFAMATION_RULED", world.month, world.month):
		var done: Dictionary = st.get("defamation_done", {})
		if done.has(f["id"]):
			continue
		done[f["id"]] = 1
		st["defamation_done"] = done
		var sm := String(f["data"].get("smearer", ""))
		if bool(f["data"].get("guilty", false)) and world.table("party").has(sm):
			var p: Dictionary = world.table("party")[sm]
			p["credibility"] = clampi(int(p["credibility"]) - DEFAMATION_CREDIBILITY, 0, 100)


static func _expose_smear(world: WorldState, c: Dictionary, pid: String, d: Dictionary) -> void:
	d["exposed"] = true
	var p: Dictionary = world.table("party")[pid]
	p["credibility"] = clampi(int(p["credibility"]) - 10, 0, 100)
	var l: Dictionary = p["leader"] if typeof(p.get("leader")) == TYPE_DICTIONARY else {}
	if not l.is_empty():
		l["popularity"] = clampi(int(l["popularity"]) - 8, 0, 100)
	_momentum(c, pid, -300)
	if c["parties"].has(d["target"]):
		_momentum(c, d["target"], 150)
	var case_id := String(_law_call("file_defamation", [world, String(d["target"]), pid, int(d["sev"])], "", JUSTICE_PATH))
	_event(world, c, "POL_SMEAR_EXPOSED", "OPPO", [pid, d["target"]], 65,
		{"party": pid, "target": d["target"], "leader": PartyLife.leader_name(p), "case": case_id})


# ======================================================================= pork

## Voters' reaction to crowd-pleasing laws passed in election year. Credible governments get the credit;
## parties with a record of broken promises are seen through and lose. Read-only on the bills.
static func _pork(world: WorldState, st: Dictionary, c: Dictionary) -> void:
	var batches: Array = []
	for f in world.facts.query("POL_BILL_PASSED", world.month, world.month):
		var b: Dictionary = world.peek("bill").get(String(f["data"].get("bill", "")), {})
		if not b.is_empty():
			batches.append(b.get("clauses", []))
	for f in world.facts.query("POL_ORDINANCE_ISSUED", world.month, world.month):
		batches.append(f["data"].get("clauses", []))
	if batches.is_empty():
		return
	var gov: Dictionary = st.get("government", {})
	var members: Array = gov.get("members", [])
	if members.is_empty() and st.get("player_party", "") != "":
		members = [st["player_party"]]   # founding era: the commander's record is the founders' party's
	var cs := colony_concerns(world)
	for clauses in batches:
		var value := 0.0
		for cl in clauses:
			var def: Dictionary = world.lever_defs.get(String(cl.get("lever", "")), {})
			if def.is_empty() or def.get("type", "") != "NUMBER":
				continue
			value += maxf(0.0, Legislature.relief(def, Legislature.clause_delta(def, cl), cs[0], cs[1]))
		if value <= 0.01:
			continue
		for pid in members:
			if not c["parties"].has(pid) or not world.table("party").has(pid):
				continue
			var cred := float(world.table("party")[pid].get("credibility", 50))
			var k := (cred - float(PORK_CRED_PIVOT)) / (100.0 - float(PORK_CRED_PIVOT))
			var d := int(round(float(PORK_BETA) * minf(value, 1.0) * k))
			_momentum(c, pid, d)
			_event(world, c, "POL_ELECTION_PORK", "CAMPAIGN", [pid], 40,
				{"party": pid, "value": int(round(value * 1000.0)), "believed": d >= 0, "momentum": d})


## Colony-wide [sat, sal] (same shape as PoliticsProvider.colony_concerns), read-only.
static func colony_concerns(world: WorldState) -> Array:
	var sat := {}
	var sal := {}
	var p := 0.0
	for cn in PolDefs.CONCERNS:
		sat[cn] = 0.0
		sal[cn] = 0.0
	for v in PolVoters.all(world):
		var pop := float(v["pop"])
		if pop <= 0.0:
			continue
		p += pop
		for cn in PolDefs.CONCERNS:
			sat[cn] += float(v["sat"][cn]) * pop
			sal[cn] += float(v["salience"][cn]) * pop
	for cn in PolDefs.CONCERNS:
		sat[cn] = int(round(sat[cn] / maxf(1.0, p)))
		sal[cn] = int(round(sal[cn] / maxf(1.0, p)))
	return [sat, sal]


# ======================================================================= player actions (Campaign panel)

const TONES := ["POSITIVE", "MIXED", "NEGATIVE"]
const SPLITS := {"POSITIVE": {"ad": 600, "ground": 350, "oppo": 50}, "MIXED": {"ad": 550, "ground": 330, "oppo": 120},
	"NEGATIVE": {"ad": 500, "ground": 300, "oppo": 200}}


static func _player_entry(world: WorldState) -> Dictionary:
	var st: Dictionary = world.table("pol")["state"]
	var c := _row(world, st)
	var pp := String(st.get("player_party", ""))
	if c.is_empty():
		return {"ok": false, "error": "No campaign is running. Election year opens 12 months before the election."}
	if pp == "" or not c["parties"].has(pp):
		return {"ok": false, "error": "Your party is not in this campaign."}
	return {"ok": true, "c": c, "e": c["parties"][pp], "pid": pp}


## Up to two concerns to campaign on.
static func player_set_themes(world: WorldState, themes: Array) -> Dictionary:
	var r := _player_entry(world)
	if not r["ok"]:
		return r
	if themes.is_empty() or themes.size() > 2:
		return {"ok": false, "error": "Pick one or two themes."}
	for cn in themes:
		if not PolDefs.CONCERNS.has(cn):
			return {"ok": false, "error": "Unknown concern " + str(cn)}
	r["e"]["themes"] = themes.duplicate()
	r["e"]["manual"] = true
	return {"ok": true}


## Tone (POSITIVE / MIXED / NEGATIVE) and who the attacks and opposition research go after.
static func player_set_tone(world: WorldState, tone: String, target: String = "") -> Dictionary:
	var r := _player_entry(world)
	if not r["ok"]:
		return r
	if not TONES.has(tone):
		return {"ok": false, "error": "Unknown tone."}
	if tone != "POSITIVE" and (target == "" or target == r["pid"] or not r["c"]["parties"].has(target)):
		return {"ok": false, "error": "Choose a rival to target."}
	var e: Dictionary = r["e"]
	if tone == "NEGATIVE" and e["tone"] != "NEGATIVE":
		_event(world, r["c"], "POL_CAMPAIGN_GOES_NEGATIVE", "AD", [r["pid"], target], 45, {"party": r["pid"], "target": target})
	e["tone"] = tone
	e["target"] = target if tone != "POSITIVE" else String(e["target"])
	e["split"] = SPLITS[tone].duplicate()
	e["manual"] = true
	return {"ok": true}


## Budget split in per-mille (ad + ground + oppo = 1000).
static func player_set_split(world: WorldState, ad: int, ground: int, oppo: int) -> Dictionary:
	var r := _player_entry(world)
	if not r["ok"]:
		return r
	if ad < 0 or ground < 0 or oppo < 0 or ad + ground + oppo != 1000:
		return {"ok": false, "error": "The split must add up to 100%."}
	r["e"]["split"] = {"ad": ad, "ground": ground, "oppo": oppo}
	r["e"]["manual"] = true
	return {"ok": true}


## Publish a piece of held dirt now (index into the party's dirt list).
static func player_release_dirt(world: WorldState, index: int) -> Dictionary:
	var r := _player_entry(world)
	if not r["ok"]:
		return r
	var dirt: Array = r["e"]["dirt"]
	if index < 0 or index >= dirt.size() or int(dirt[index]["released"]) >= 0:
		return {"ok": false, "error": "Nothing to release."}
	var tgt := String(dirt[index]["target"])
	if not world.table("party").has(tgt) or world.table("party")[tgt]["status"] != "ACTIVE":
		return {"ok": false, "error": "That party is gone."}
	release(world, r["c"], r["pid"], dirt[index], false)
	return {"ok": true}


# ======================================================================= vote model hooks

## Per-campaign cache for the vote model; {} when no campaign is running.
static func vote_cache(world: WorldState) -> Dictionary:
	var c := current(world)
	if c.is_empty():
		return {}
	return c


## {party_id: utility} for one voter (persuasion in the voter's segment + momentum + civility backfire), capped.
static func voter_utility(cache: Dictionary, v: Dictionary) -> Dictionary:
	var out := {}
	if cache.is_empty():
		return out
	var k := seg_key(v)
	var co := String(v.get("cohort", ""))
	for pid in cache["parties"]:
		var e: Dictionary = cache["parties"][pid]
		var u := int(e["persuasion"].get(k, 0)) + int(e["momentum"])
		u += int(e["backfire"].get(co, e["backfire"].get("*", 0)))
		if u != 0:
			out[pid] = float(clampi(u, -CAMPAIGN_U_CAP, CAMPAIGN_U_CAP)) / 1000.0
	return out


## {party_id: turnout multiplier} from the ground game (applied to the party's own votes).
static func mobilisation(cache: Dictionary) -> Dictionary:
	var out := {}
	if cache.is_empty():
		return out
	for pid in cache["parties"]:
		out[pid] = 1.0 + float(cache["parties"][pid]["mob"]) / 1000.0
	return out


## Support votes (stödröster): a governing ally just under the 4% threshold borrows votes from its largest
## partner. Applied to raw votes {pid: float}; returns {pid: moved} for the record.
static func tactical(world: WorldState, votes: Dictionary) -> Dictionary:
	var st: Dictionary = world.peek("pol").get("state", {})
	var bloc: Array = st.get("government", {}).get("members", []).duplicate()
	for sp in st.get("government", {}).get("support", []):
		if not bloc.has(sp):
			bloc.append(sp)
	if bloc.size() < 2:
		return {}
	var tot := 0.0
	for pid in votes:
		tot += float(votes[pid])
	if tot <= 0.0:
		return {}
	var big := ""
	for pid in bloc:
		if votes.has(pid) and (big == "" or float(votes[pid]) > float(votes[big])):
			big = pid
	var moved := {}
	bloc.sort()
	for pid in bloc:
		if pid == big or not votes.has(pid):
			continue
		var sh := float(votes[pid]) / tot * 100000.0
		if sh < float(TACTICAL_LOW) or sh >= float(PartyLife.THRESHOLD):
			continue
		var need := (float(TACTICAL_TARGET) - sh) / 100000.0 * tot
		var give := minf(need, float(votes[big]) * TACTICAL_MAX_FRAC)
		votes[big] = float(votes[big]) - give
		votes[pid] = float(votes[pid]) + give
		moved[pid] = int(round(give))
	return moved


# ======================================================================= facts

static func _event(world: WorldState, c: Dictionary, type: String, channel: String, parties: Array, mag: int, data: Dictionary) -> void:
	var subj: Array = []
	for pid in parties:
		if String(pid) != "":
			subj.append({"kind": "PARTY", "id": String(pid)})
	data["channel"] = channel
	data["campaign"] = c["id"]
	var fid := world.add_fact({"type": type, "owner": "pol", "subjects": subj,
		"responsible": [{"actor": subj[0], "share": 1.0}] if not subj.is_empty() else [], "impact": {},
		"magnitude": mag, "visibility": "PUBLIC", "data": data})
	c["events"].append(fid)

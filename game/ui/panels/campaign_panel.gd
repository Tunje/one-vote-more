extends VBoxContainer
## Campaign (election year; owner Ella): the calendar, your themes, tone, target and budget, dirt you hold,
## the race (momentum, spending) and the campaign news feed. Writes only through Campaign.player_* actions.

const Kit := preload("res://ui/panels/panel_kit.gd")

var session
var body: VBoxContainer
var msg := ""


func panel_title() -> String:
	return "Campaign"


func setup(s) -> void:
	session = s
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	body = Kit.scroll_body(self)


func _do(res: Dictionary) -> void:
	msg = "Done." if res.get("ok", false) else "✗ " + String(res.get("error", "failed"))
	get_tree().call_group("pcs_refresh", "refresh_all")


func _pname(w: WorldState, pid) -> String:
	return String(w.peek("party").get(String(pid), {}).get("name", "-"))


func refresh() -> void:
	if session == null or body == null:
		return
	Kit.clear(body)
	var w: WorldState = session.world()
	var st: Dictionary = session.pol_state()
	var pp := String(st.get("player_party", ""))
	if msg != "":
		Kit.label(body, msg, 13, Color(1, 0.85, 0.5))
	_congress(w, pp)
	var ne := Campaign.next_election(st, w.month)
	var c := Campaign.current(w)
	if c.is_empty():
		if ne.is_empty():
			Kit.label(body, "No election is scheduled.", 14)
		else:
			var opens := int(ne["month"]) - (Campaign.WINDOW_EXTRA if ne["extra"] else Campaign.WINDOW_ORDINARY)
			Kit.label(body, "Next %s in %d months. Election year opens in %d months: then the parties pick themes, spend their funds, debate and dig for dirt." % [
				"snap election" if ne["extra"] else "election", int(ne["month"]) - w.month, maxi(0, opens - w.month)], 14)
		_past(w)
		return
	var to_go := int(c["election_month"]) - w.month
	var phase := "final week: the last debate" if to_go == 0 else ("short campaign: election huts, posters, debates" if to_go <= Campaign.SHORT_CAMPAIGN else "long campaign")
	Kit.header(body, "%s · %d month(s) to go · %s" % ["Snap election" if c["extra"] else "Election year", to_go, phase])
	if pp != "" and c["parties"].has(pp):
		_debate_night(w, c, pp)
		_my_campaign(w, c, pp)
	Kit.sep(body)
	_race(w, c)
	Kit.sep(body)
	Kit.header(body, "Campaign news")
	var evs: Array = c["events"].duplicate()
	evs.reverse()
	if evs.is_empty():
		Kit.label(body, "Quiet so far.", 13, Color(0.7, 0.7, 0.7))
	for fid in evs.slice(0, 15):
		var f: Dictionary = w.facts.get_fact(fid)
		if not f.is_empty():
			Kit.label(body, "m%d  %s" % [int(f["month"]), NewsText.sentence(w, f).replace("[b]", "").replace("[/b]", "")], 13)


func _my_campaign(w: WorldState, c: Dictionary, pp: String) -> void:
	var e: Dictionary = c["parties"][pp]
	var acc := "party:" + pp
	Kit.header(body, "Your campaign")
	Kit.label(body, "Funds %d · spent %d · campaign quality %d%% (staff + leader charisma)%s" % [
		(w.ledger.balance(acc) / 1000) if w.ledger.has_account(acc) else 0, int(e["spent"]) / 1000, int(e["quality"]) / 10,
		"" if e["manual"] else " · run by your staff (autoplay)"], 13)
	# themes
	Kit.label(body, "Themes: %s. Pushing a theme makes voters care about it; that pays off on concerns your party owns." % ", ".join(e["themes"]), 13)
	var row := Kit.hbox(body)
	var own: Dictionary = w.peek("party")[pp].get("ownership", {})
	var cs: Array = PolDefs.CONCERNS.duplicate()
	cs.sort_custom(func(a, b): return int(own.get(a, 0)) > int(own.get(b, 0)))
	var hs := HotIssues.heat(w)
	var shown: Array = cs.slice(0, 6)
	for cn in cs.slice(6):
		if HotIssues.issue_for(hs, cn) != "":
			shown.append(cn)   # a hot issue is always on the menu
	for cn in shown:
		var concern: String = cn
		var on: bool = e["themes"].has(concern)
		var iss := HotIssues.issue_for(hs, concern)
		var hot := (" · hot: " + HotIssues.label(iss)) if iss != "" else ""
		Kit.button(row, ("✓ " if on else "") + "%s (%d)%s" % [concern.capitalize(), int(own.get(concern, 0)), hot], func(): _toggle_theme(concern))
	# tone & target
	Kit.label(body, "Tone: %s%s. Going negative hurts the target but costs you with voters who value civility (institution- and stability-minded)." % [
		String(e["tone"]).to_lower(), (" · target " + _pname(w, e["target"])) if String(e["target"]) != "" else ""], 13)
	var trow := Kit.hbox(body)
	var tgt := String(e["target"])
	if tgt == "" or tgt == pp:
		tgt = Campaign.pick_target(w, session.pol_state(), w.peek("party")[pp])
	for tone in Campaign.TONES:
		var t: String = tone
		Kit.button(trow, t.capitalize(), func(): _do(Campaign.player_set_tone(session.world(), t, tgt)), t == e["tone"])
	var rrow := Kit.hbox(body)
	Kit.label(rrow, "Target:", 13)
	for pid in Det_ordered(c["parties"]):
		if pid == pp:
			continue
		var target_pid: String = pid
		var tone_now := String(e["tone"]) if String(e["tone"]) != "POSITIVE" else "MIXED"
		Kit.button(rrow, _pname(w, pid).get_slice(" ", 0), func(): _do(Campaign.player_set_tone(session.world(), tone_now, target_pid)), pid == String(e["target"]))
	# budget
	var sp: Dictionary = e["split"]
	Kit.label(body, "Budget: ads %d%% · ground game %d%% · opposition research %d%%" % [int(sp["ad"]) / 10, int(sp["ground"]) / 10, int(sp["oppo"]) / 10], 13)
	var brow := Kit.hbox(body)
	for preset in [["Air war", 700, 250, 50], ["Balanced", 550, 350, 100], ["Ground war", 350, 600, 50], ["Dig deep", 450, 250, 300]]:
		var pr: Array = preset
		Kit.button(brow, pr[0], func(): _do(Campaign.player_set_split(session.world(), pr[1], pr[2], pr[3])))
	# dirt
	var dirt: Array = e["dirt"]
	if not dirt.is_empty():
		Kit.header(body, "Opposition research")
		for i in dirt.size():
			var d: Dictionary = dirt[i]
			var what: String = {"DONATION": "hidden, unlawful donations", "PERSONAL": "the leader's private conduct", "SMEAR": "an unproven allegation (a smear: if it's exposed, it backfires and they can sue)"}.get(String(d["kind"]), "?")
			var drow := Kit.hbox(body)
			var state := "released m%d" % int(d["released"]) if int(d["released"]) >= 0 else "held since m%d" % int(d["found"])
			Kit.label(drow, "On %s: %s (severity %d) — %s" % [_pname(w, d["target"]), what, int(d["sev"]), state], 13,
				Color(1, 0.7, 0.6) if d["kind"] == "SMEAR" else Color.WHITE)
			if int(d["released"]) < 0:
				var idx: int = i
				Kit.button(drow, "Release now", func(): _do(Campaign.player_release_dirt(session.world(), idx)))
		Kit.label(body, "Held dirt hits harder late, but it may leak that you sat on it. Anything still held comes out on election day.", 11, Color(0.75, 0.75, 0.75))


## Party congress: a rebel motion waiting for the leader's answer.
func _congress(w: WorldState, pp: String) -> void:
	if pp == "":
		return
	var row := Congress.latest(w, pp)
	var m: Dictionary = row.get("motion", {}) if not row.is_empty() else {}
	if m.get("status", "") != "PENDING":
		return
	var p: Dictionary = w.peek("party")[pp]
	Kit.header(body, "Party congress: a motion against the leadership")
	Kit.label(body, "A discontented faction wants the platform moved %d points %s on %s. Accept it to calm them (it uses this year's platform-move allowance and costs some credibility), or fight it (your leader loses popularity and the faction gets angrier; angry factions can split the party). If you don't answer by m%d, the party staff accept it." % [
		absi(int(m["points"])), "up" if int(m["points"]) > 0 else "down", String(m["axis"]).capitalize(), int(m["deadline"])], 13, Color(1, 0.85, 0.5))
	Kit.label(body, "Faction discontent: %d · leader popularity %d" % [int(p["factions"][int(m["faction"])]["discontent"]), PartyLife.leader_popularity(p)], 12)
	var row2 := Kit.hbox(body)
	Kit.button(row2, "Accept the motion", func(): _do(Congress.player_answer_motion(session.world(), "ACCEPT")))
	Kit.button(row2, "Fight it", func(): _do(Congress.player_answer_motion(session.world(), "FIGHT")))
	Kit.sep(body)


## Debate night: next debate's questions, the facts that matter for each, and a stance per question.
func _debate_night(w: WorldState, c: Dictionary, pp: String) -> void:
	var st: Dictionary = session.pol_state()
	var prep: Dictionary = c.get("debate_prep", {})
	if not prep.is_empty():
		Kit.header(body, "Debate night: %s, %s" % ["the final debate" if prep["final"] else "the leaders' debate", "next month" if int(prep["month"]) > w.month else "tonight"])
		Kit.label(body, "Choose how your leader answers each question. Attack goes after %s; defend stands on the record; pivot turns to your themes (%s)." % [
			_pname(w, c["parties"][pp]["target"]) if String(c["parties"][pp]["target"]) != "" else "nobody (no target set)", ", ".join(c["parties"][pp]["themes"])], 12, Color(0.75, 0.75, 0.75))
		var cs := Campaign.colony_concerns(w)
		var own: Dictionary = w.peek("party")[pp].get("ownership", {})
		var members: Array = st.get("government", {}).get("members", [])
		for i in prep["questions"].size():
			var q: Dictionary = prep["questions"][i]
			var topic: String = q["topic"]
			var chosen := String(prep["answers"].get(str(i), ""))
			var about := topic.capitalize()
			if String(q.get("issue", "")) != "":
				about = "%s (%s)" % [HotIssues.label(String(q["issue"])), topic.capitalize()]
			Kit.label(body, "%d. %s asks about %s. Colony satisfaction %d%%, how much people care %s, your ownership %d%s." % [i + 1,
				"The moderator" if q["asker"] == "MODERATOR" else "Someone in the audience", about,
				int(cs[0][topic]) / 1000, "high" if int(cs[1][topic]) > 130 else ("low" if int(cs[1][topic]) < 90 else "average"),
				int(own.get(topic, 0)), " · you govern: it's your record" if members.has(pp) else ""], 13)
			var row := Kit.hbox(body)
			for stance in Campaign.STANCES:
				var sname: String = stance
				var idx: int = i
				Kit.button(row, ("✓ " if chosen == sname else "") + sname.capitalize(), func(): _do(Campaign.player_debate_answer(session.world(), idx, sname)))
			if chosen == "":
				Kit.label(row, "(unanswered: staff will choose)", 11, Color(0.7, 0.7, 0.7))
	# feedback on the last debate
	if not c["debates"].is_empty():
		var d: Dictionary = c["debates"].back()
		if d.has("answers") and d["answers"].has(pp):
			Kit.label(body, "Last debate (m%d): %s" % [int(d["month"]), "; ".join(d["answers"][pp].map(func(a):
				var verdict := "landed" if int(a["fit"]) >= 250 else ("fell flat" if int(a["fit"]) < 0 else "was fine")
				return "%s on %s %s" % [String(a["stance"]).to_lower(), String(a["topic"]).capitalize(), verdict]))], 13, Color(0.85, 0.9, 1.0))


func _toggle_theme(concern: String) -> void:
	var c := Campaign.current(session.world())
	var pp := String(session.pol_state().get("player_party", ""))
	var themes: Array = c["parties"][pp]["themes"].duplicate()
	if themes.has(concern):
		themes.erase(concern)
	else:
		themes.append(concern)
		if themes.size() > 2:
			themes.pop_front()
	_do(Campaign.player_set_themes(session.world(), themes))


func _race(w: WorldState, c: Dictionary) -> void:
	Kit.header(body, "The race")
	var poll := PartyLife.latest_poll_shares(w)
	for pid in Det_ordered(c["parties"]):
		var e: Dictionary = c["parties"][pid]
		var mom := int(e["momentum"])
		var arrow := "▲" if mom > 50 else ("▼" if mom < -50 else "•")
		Kit.label(body, "%s %s  poll %.1f%% (start %.1f%%) · %s · themes %s · spent %d%s" % [arrow, _pname(w, pid),
			float(poll.get(pid, 0)) / 1000.0, float(c["start_poll"].get(pid, 0)) / 1000.0, String(e["tone"]).to_lower(),
			", ".join(e["themes"].map(func(x): return String(x).capitalize())), int(e["spent"]) / 1000,
			(" · attacking " + _pname(w, e["target"])) if String(e["tone"]) != "POSITIVE" and String(e["target"]) != "" else ""], 13)
	for d in c["debates"]:
		Kit.label(body, "%s m%d: %s won, %s struggled%s" % ["Final debate" if d["final"] else "Debate", int(d["month"]), _pname(w, d["winner"]),
			_pname(w, d["loser"]), (" · gaffes: " + ", ".join(d["gaffes"].map(func(x): return _pname(w, x)))) if not d["gaffes"].is_empty() else ""], 13, Color(0.85, 0.9, 1.0))


## Last finished campaign: who moved.
func _past(w: WorldState) -> void:
	var last: Dictionary = {}
	for cid in w.peek("campaign"):
		var c: Dictionary = w.peek("campaign")[cid]
		if c["status"] == "DONE":
			last = c
	if last.is_empty() or last["result"].get("moved", {}).is_empty():
		return
	Kit.sep(body)
	Kit.header(body, "Last campaign: change since election year opened")
	for pid in Det_ordered(last["result"]["moved"]):
		Kit.label(body, "%s  %+.1f pp" % [_pname(w, pid), float(last["result"]["moved"][pid]) / 1000.0], 13)


static func Det_ordered(d: Dictionary) -> Array:
	var ks: Array = d.keys()
	ks.sort()
	return ks

extends SceneTree
## Century chronicle: runs one colony for N years on the full simulation (economy, companies, law, staff,
## politics; the player's party on autoplay) and writes everything that happened to one Markdown file
## for analysis:
##   - every party: when and why it appeared (trigger data, platform, which voter groups it spoke for),
##     its leaders, its fate
##   - every election: colony result, seats, and how EVERY voter group voted (turnout, party shares, mood)
##   - every decision: bills (clauses, each party's vote, result), ordinances, lever changes, governments,
##     crises, scandals, court cases
##   - a yearly table of the colony's condition and a yearly log of notable events
##   godot --headless --path game --script res://tools/chronicle.gd -- [years=100] [seed=1] [out.md]
const EconSim := preload("res://sim/economy/econ_sim.gd")

const NOTABLE_ECON := ["ECON_STRIKE", "ECON_LOCKOUT", "ECON_LAYOFFS_MASS", "ECON_SOVEREIGN_DEFAULT", "ECON_GOV_BORROWED",
	"ECON_FOOD_AID", "ECON_UTILITY_OUTAGE", "ECON_POLLUTION_THRESHOLD", "ECON_FACILITY_SOLD", "COMP_INSOLVENCY",
	"COMP_LIQUIDATED", "COMP_WORKPLACE_ACCIDENT"]
const SKIP := ["POL_DONATION", "STAFF_DRAFT_COMPLETED", "ECON_LEVER_EFFECTIVE"]  # summarised elsewhere
const YEAR_INDICATORS := [["ECON_UNEMPLOYMENT_RATE", "Unemployment %", 1000.0], ["ECON_CPI_INFLATION", "Inflation %", 1000.0],
	["ECON_REAL_INCOME_INDEX", "Real income idx", 1000.0], ["ECON_PUBLIC_DEBT_RATIO", "Debt % GDP", 1000.0],
	["ECON_POLLUTION_INDEX", "Pollution", 1000.0], ["POL_GOV_APPROVAL", "Gov approval %", 1000.0],
	["ECON_TRADE_BALANCE", "Trade bal. k cr", 1000000.0]]

var w: WorldState
var party_snap := {}      # pid -> snapshot at birth
var elections: Array = []  # [{month, eid, extra, rows: [...], parties: [...]}]
var lever_log: Array = []  # [{month, lever, from, to, source}]
var events := {}           # year -> [line]
var counts := {}           # year -> {type: n}
var years_tbl: Array = []  # [{year, pop, gov, pm, indicators{}, seats{}}]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var years := int(args[0]) if args.size() > 0 else 100
	var seed_v := int(args[1]) if args.size() > 1 else 1
	var out := args[2] if args.size() > 2 else ProjectSettings.globalize_path("res://").path_join("../chronicles/chronicle_seed%d_%dy.md" % [seed_v, years])
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	var sim: Simulation = EconSim.make(seed_v, "BALANCED", {}, true)
	w = sim.world
	var t0 := Time.get_ticks_msec()
	var prev_levers := w.levers.duplicate(true)
	for _m in years * 12:
		sim.step()
		var m := w.month - 1
		_month(m, prev_levers)
		prev_levers = w.levers.duplicate(true)
		if (m + 1) % 120 == 0:
			print("year %d  (%ds)  parties %d" % [(m + 1) / 12, (Time.get_ticks_msec() - t0) / 1000, PartyLife.active(w).size()])
	var md := _render(seed_v, years)
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(md)
	f.close()
	print("wrote %s (%d KB) in %ds" % [out, md.length() / 1024, (Time.get_ticks_msec() - t0) / 1000])
	quit(0)


# ======================================================================= collection

func _month(m: int, prev_levers: Dictionary) -> void:
	var y := m / 12 + 1
	var facts: Array = w.facts.query("", m, m)
	if not counts.has(y):
		counts[y] = {}
		events[y] = []
	# lever changes and their source (bill / ordinance / decree)
	var src := {}
	for f in facts:
		if f["type"] == "ECON_LEVER_EFFECTIVE" or String(f["type"]).ends_with("_LEVER_EFFECTIVE"):
			src[f["data"].get("lever", "")] = String(f["data"].get("source_bill", f["data"].get("enactment", "")))
	for k in w.levers:
		if str(prev_levers.get(k)) != str(w.levers[k]):
			lever_log.append({"month": m, "lever": k, "from": prev_levers.get(k), "to": w.levers[k], "source": src.get(k, "")})
	for f in facts:
		var t: String = f["type"]
		counts[y][t] = int(counts[y].get(t, 0)) + 1
		match t:
			"POL_PARTIES_FORMED":
				for p in PartyLife.active(w):
					_snap_party(p, m, "FOUNDING", {"note": "one of the first parties, formed from the colony's main voter clusters in Year 3"})
			"POL_PARTY_FOUNDED":
				_snap_party(w.table("party")[f["data"]["party"]], m, String(f["data"].get("kind", "")), f["data"])
			"POL_PARTY_SPLIT":
				_snap_party(w.table("party")[f["data"]["splinter"]], m, "SPLINTER", f["data"])
			"POL_ELECTION_HELD":
				_snap_election(m, f["data"]["election"])
		if t in SKIP or f.get("visibility", "") != "PUBLIC" and not t.begins_with("POL_"):
			continue
		if t.begins_with("POL_") or t.begins_with("LAW_") or t.begins_with("HOME_") or t == "ECON_SHIP_ARRIVED" or t.begins_with("STAFF_OFFICIAL") or t == "STAFF_OVERSIGHT_REPORT" or t in NOTABLE_ECON:
			events[y].append("m%d (%s) **%s** %s" % [m, _date(m), t, _describe(f)])
	if (m + 1) % 12 == 0:
		_snap_year(y)


func _snap_party(p: Dictionary, m: int, kind: String, why: Dictionary) -> void:
	if party_snap.has(p["id"]):
		return
	# who it speaks for: voter groups whose nearest party it is (by ideology distance)
	var parties := PartyLife.active(w)
	var base: Array = []
	var base_pop := 0
	var all_pop := 0
	for c in PolVoters.all(w):
		if c["pop"] <= 0:
			continue
		all_pop += c["pop"]
		var best := ""
		var bd := INF
		for q in parties:
			var d := VoteModel.distance(c["ideology"], q["positions"])
			if d < bd:
				bd = d
				best = q["id"]
		if best == p["id"]:
			base.append(c)
			base_pop += c["pop"]
	base.sort_custom(func(a, b): return a["pop"] > b["pop"] or (a["pop"] == b["pop"] and a["key"] < b["key"]))
	var sats := {}
	for cn in PolDefs.CONCERNS:
		var s := 0.0
		var n := 0.0
		for c in PolVoters.all(w):
			s += float(c["sat"][cn]) * c["pop"]
			n += c["pop"]
		sats[cn] = int(s / maxf(1.0, n) / 1000.0)
	party_snap[p["id"]] = {"month": m, "kind": kind, "why": why.duplicate(true), "name": p["name"],
		"positions": p["positions"].duplicate(), "ownership": p["ownership"].duplicate(), "leader": PartyLife.leader_name(p),
		"base_share": float(base_pop) / maxf(1.0, all_pop) * 100.0, "base": base.slice(0, 6).map(func(c): return "%s (%d)" % [_cell_name(c), c["pop"]]),
		"colony_sat": sats}


func _snap_election(m: int, eid: String) -> void:
	var e: Dictionary = w.table("election")[eid]
	var ran: Array = e["votes"].keys()
	ran.sort()
	var pdicts: Array = ran.map(func(pid): return w.table("party")[pid])
	var rows: Array = []
	for c in PolVoters.all(w):
		if c["pop"] <= 0:
			continue
		var worst := ""
		var wv := -1.0
		for cn in PolDefs.CONCERNS:
			var v := float(c["salience"][cn]) * (1.0 - float(c["sat"][cn]) / 100000.0)
			if v > wv:
				wv = v
				worst = cn
		rows.append({"cell": c, "name": _cell_name(c), "pop": c["pop"], "turnout": VoteModel.turnout(c, pdicts),
			"shares": c["prev_share"].duplicate(), "approval": int(c["approval"]) / 1000, "worry": worst})
	elections.append({"month": m, "eid": eid, "ran": ran, "rows": rows, "votes": e["votes"].duplicate(), "seats": e["seats"].duplicate(),
		"total": e["total"], "campaign": Campaign.current(w).duplicate(true)})


func _snap_year(y: int) -> void:
	var st: Dictionary = w.peek("pol").get("state", {})
	var g: Dictionary = st.get("government", {})
	var ind := {}
	for spec in YEAR_INDICATORS:
		if w.indicators.values.has(spec[0]):
			ind[spec[1]] = _colony_value(spec[0]) / spec[2]
	var pop := 0
	for c in PolVoters.all(w):
		pop += c["pop"]
	var seats := {}
	for p in PartyLife.active(w):
		if int(p["seats"]) > 0:
			seats[p["id"]] = int(p["seats"])
	var sv: Dictionary = preload("res://sim/law/law_query.gd").sovereignty(w)
	var hm: Dictionary = st.get("home", {})
	years_tbl.append({"sov": "%s q%d%% p%d%%%s" % [String(sv.get("status", "")).to_lower(), int(sv.get("quota_share", 0)), int(sv.get("price_pct", 0)),
		" gov" if sv.get("governor", false) else ""], "home": "need %d pat %d" % [int(hm.get("need", 0)), int(hm.get("patience", 0))],
		"year": y, "adults": pop, "gov": g.get("members", []).duplicate(), "pm": g.get("pm_party", ""),
		"ind": ind, "seats": seats, "active": PartyLife.active(w).size()})


## Colony value of an indicator: its COLONY key, else the adult-weighted mean over district / voter-group keys.
func _colony_value(id: String) -> float:
	var vals: Dictionary = w.indicators.values[id]
	if vals.has("COLONY"):
		return float(vals["COLONY"])
	var wsum := {}
	for c in PolVoters.all(w):
		for k in [c["district"], c.get("census_key", "")]:
			if vals.has(k):
				wsum[k] = float(wsum.get(k, 0.0)) + float(c["pop"])
	var num := 0.0
	var den := 0.0
	for k in wsum:
		num += float(vals[k]) * wsum[k]
		den += wsum[k]
	return num / den if den > 0.0 else 0.0


# ======================================================================= rendering

func _render(seed_v: int, years: int) -> String:
	var L: PackedStringArray = []
	L.append("# Colony chronicle — seed %d, %d years" % [seed_v, years])
	L.append("")
	L.append("Generated by `game/tools/chronicle.gd` on the full simulation (economy, companies, law, staff, politics). The player's party (Founders') runs on autoplay. Month m0 = January, Year 1; parties form in Year 3; elections every 4 years plus any extra elections.")
	L.append("")
	L.append("Contents: 1 Summary · 2 Parties (why each appeared) · 3 Governments · 4 Elections (campaign and every voter group) · 5 Bills and decisions · 6 Lever changes · 7 Year-by-year condition · 8 Event log · 9 Unions, trade, industry and the press")
	L.append("")
	_summary(L)
	_parties(L)
	_governments(L)
	_elections(L)
	_bills(L)
	_levers(L)
	_years(L)
	_event_log(L)
	_society(L)
	return "\n".join(L)


func _summary(L: PackedStringArray) -> void:
	L.append("## 1. Summary")
	L.append("")
	var tot := {}
	for y in counts:
		for t in counts[y]:
			tot[t] = int(tot.get(t, 0)) + int(counts[y][t])
	var parties: Array = w.table("party").values()
	L.append("- Parties that ever existed: %d (active at the end: %d)" % [parties.size(), PartyLife.active(w).size()])
	L.append("- Elections: %d · governments formed: %d · bills passed: %d, defeated: %d · ordinances: %d" % [elections.size(),
		tot.get("POL_GOVERNMENT_FORMED", 0), tot.get("POL_BILL_PASSED", 0), tot.get("POL_BILL_DEFEATED", 0), tot.get("POL_ORDINANCE_ISSUED", 0)])
	L.append("- New parties: %d · splits: %d · mergers: %d · dissolutions: %d · leader changes: %d · scandals: %d" % [
		tot.get("POL_PARTY_FOUNDED", 0), tot.get("POL_PARTY_SPLIT", 0), tot.get("POL_PARTIES_MERGED", 0), tot.get("POL_PARTY_DISSOLVED", 0),
		tot.get("POL_LEADER_CHANGED", 0), tot.get("POL_SCANDAL_REVEALED", 0)])
	var rej := 0
	for e in w.table("enactment").values():
		if e["status"] == "REJECTED":
			rej += 1
	L.append("- Enactments rejected by legal review: %d" % rej)
	L.append("- Lever changes: %d · no-confidence votes passed: %d · extra elections: %d · strikes: %d · insolvencies: %d" % [lever_log.size(),
		tot.get("POL_NO_CONFIDENCE_PASSED", 0), tot.get("POL_EXTRA_ELECTION_CALLED", 0), int(tot.get("ECON_STRIKE", 0)) + int(tot.get("UNION_STRIKE_CALLED", 0)), tot.get("COMP_INSOLVENCY", 0)])
	L.append("")
	L.append("Party codes used in tables:")
	L.append("")
	L.append("| Code | Party | Kind | Founded | Status |")
	L.append("|---|---|---|---|---|")
	for pid in _sorted_pids():
		var p: Dictionary = w.table("party")[pid]
		L.append("| %s | %s | %s | %s | %s |" % [_code(pid), p["name"], p.get("kind", ""), _date(int(p["founded_month"])), p["status"]])
	L.append("")


func _parties(L: PackedStringArray) -> void:
	L.append("## 2. Parties — why each appeared, who it spoke for, what became of it")
	L.append("")
	for pid in _sorted_pids():
		var p: Dictionary = w.table("party")[pid]
		var s: Dictionary = party_snap.get(pid, {})
		L.append("### %s %s" % [_code(pid), p["name"]])
		L.append("")
		if s.is_empty():
			L.append("- Founded %s (%s); no founding snapshot." % [_date(int(p["founded_month"])), p.get("kind", "")])
		else:
			L.append("- **Founded:** %s — %s" % [_date(int(s["month"])), _why(s)])
			L.append("- **Platform at founding** (−100..+100): %s" % _axes(s["positions"]))
			if not s["ownership"].is_empty():
				L.append("- **Issues it owned:** %s" % ", ".join(s["ownership"].keys().map(func(k): return "%s %d" % [k, s["ownership"][k]])))
			L.append("- **Spoke for** %.1f%% of adults (groups closest to its platform). Largest: %s" % [s["base_share"], ", ".join(s["base"])])
			var low: Array = s["colony_sat"].keys()
			low.sort_custom(func(a, b): return s["colony_sat"][a] < s["colony_sat"][b])
			L.append("- **Colony mood then** (lowest satisfaction): %s" % ", ".join(low.slice(0, 3).map(func(k): return "%s %d%%" % [k, s["colony_sat"][k]])))
			L.append("- **First leader:** %s" % s["leader"])
		var hist: Array = []
		for t in ["POL_LEADER_CHANGED", "POL_PARTY_SPLIT", "POL_PARTIES_MERGED", "POL_PARTY_DISSOLVED", "POL_SCANDAL_REVEALED", "POL_PLATFORM_CHANGED", "LAW_LEADER_CONVICTED"]:
			for f in w.facts.query(t):
				var d: Dictionary = f["data"]
				if d.get("party", "") == pid or d.get("into", "") == pid or d.get("absorbed", "") == pid or d.get("splinter", "") == pid:
					hist.append([int(f["month"]), "%s: %s" % [t.trim_prefix("POL_"), _describe(f)]])
		hist.sort_custom(func(a, b): return a[0] < b[0])
		if not hist.is_empty():
			L.append("- **History:**")
			for h in hist:
				L.append("  - %s %s" % [_date(h[0]), h[1]])
		L.append("- **Fate:** %s%s; seats at the end %d; leader at the end %s" % [p["status"],
			(" into " + w.table("party").get(p.get("merged_into", ""), {}).get("name", "")) if p.has("merged_into") else "", int(p["seats"]), PartyLife.leader_name(p)])
		L.append("")


func _governments(L: PackedStringArray) -> void:
	L.append("## 3. Governments")
	L.append("")
	L.append("Support = confidence-and-supply partners a minority cabinet needs for a majority; each states its price (a policy it must get within 18 months, or it withdraws).")
	L.append("")
	L.append("| Formed | PM party | Coalition | Cabinet seats | Confidence & supply (price) | With support | Reason |")
	L.append("|---|---|---|---|---|---|---|")
	for f in w.facts.query("POL_GOVERNMENT_FORMED"):
		var d: Dictionary = f["data"]
		var price := {}
		for x in d.get("deals", []):
			price[x["party"]] = "%s %s" % [x["lever"], "up" if int(x["dir"]) > 0 else "down"]
		L.append("| %s | %s | %s | %s | %s | %s | %s |" % [_date(int(f["month"])), _pname(d.get("pm_party", "")), ", ".join(d.get("members", []).map(_pname)),
			str(d.get("seats", "")), ", ".join(d.get("support", []).map(func(pid): return "%s (%s)" % [_pname(pid), price.get(pid, "-")])),
			str(d.get("seats_with_support", "")), d.get("reason", "")])
	L.append("")
	var others: Array = []
	for t in ["POL_NO_CONFIDENCE_PASSED", "POL_NO_CONFIDENCE_FAILED", "POL_SUPPORT_WITHDRAWN", "POL_PARTNER_LEFT", "POL_FORMATION_FAILED", "POL_PM_VOTE_FAILED", "POL_EXTRA_ELECTION_CALLED"]:
		for f in w.facts.query(t):
			others.append([int(f["month"]), "%s %s" % [t.trim_prefix("POL_"), _describe(f)]])
	others.sort_custom(func(a, b): return a[0] < b[0])
	if not others.is_empty():
		L.append("Crises:")
		L.append("")
		for o in others:
			L.append("- %s %s" % [_date(o[0]), o[1]])
		L.append("")


func _elections(L: PackedStringArray) -> void:
	L.append("## 4. Elections — result and how every voter group voted")
	L.append("")
	L.append("A voter group is district · occupation · income band · values cohort (TRAD traditional, PRAG pragmatic, PROG progressive). Adults = voting-age people in the group. Shares are the group's vote split (%). Approval = the group's approval of the government (%). Biggest worry = the concern with the highest salience × dissatisfaction.")
	L.append("")
	for e in elections:
		L.append("### Election %s%s" % [_date(e["month"]), ""])
		L.append("")
		var ran: Array = e["ran"]
		L.append("| Party | Votes | % | Seats |")
		L.append("|---|---|---|---|")
		var ordered: Array = ran.duplicate()
		ordered.sort_custom(func(a, b): return e["votes"][a] > e["votes"][b])
		for pid in ordered:
			L.append("| %s %s | %d | %.1f | %d |" % [_code(pid), _pname(pid), e["votes"][pid], float(e["votes"][pid]) / maxf(1.0, e["total"]) * 100.0, int(e["seats"].get(pid, 0))])
		L.append("")
		_campaign(L, e)
		var head := "| Group | Adults | Turnout % | " + " | ".join(ran.map(_code)) + " | Approval | Biggest worry |"
		L.append(head)
		L.append("|" + "---|".repeat(ran.size() + 5))
		for r in e["rows"]:
			var cols: Array = []
			for pid in ran:
				cols.append("%.0f" % (float(r["shares"].get(pid, 0)) / 1000.0))
			L.append("| %s | %d | %.0f | %s | %d | %s |" % [r["name"], r["pop"], r["turnout"] * 100.0, " | ".join(cols), r["approval"], r["worry"]])
		L.append("")


## Election year (Ella): each party's themes, tone and target, pp moved since the campaign opened, and its big moments.
func _campaign(L: PackedStringArray, e: Dictionary) -> void:
	var c: Dictionary = e.get("campaign", {})
	if c.is_empty() or int(c.get("election_month", -1)) != int(e["month"]):
		return
	L.append("**Campaign** (%s, opened %s):" % ["snap election" if c.get("extra", false) else "election year", _date(int(c["opened"]))])
	L.append("")
	L.append("| Party | Themes | Tone | Target | Spent | Poll at start % | Moved pp |")
	L.append("|---|---|---|---|---|---|---|")
	for pid in e["ran"]:
		if not c["parties"].has(pid):
			continue
		var ce: Dictionary = c["parties"][pid]
		var sh := float(e["votes"][pid]) / maxf(1.0, e["total"]) * 100.0
		var st0 := float(c["start_poll"].get(pid, 0)) / 1000.0
		L.append("| %s %s | %s | %s | %s | %d | %.1f | %+.1f |" % [_code(pid), _pname(pid), ", ".join(ce["themes"]), ce["tone"],
			_pname(ce["target"]) if String(ce["target"]) != "" else "-", int(ce["spent"]) / 1000, st0, sh - st0])
	L.append("")
	for fid in c.get("events", []):
		var f: Dictionary = w.facts.get_fact(fid)
		if f.is_empty() or f["type"] == "POL_CAMPAIGN_OPENED":
			continue
		L.append("- %s: %s" % [_date(int(f["month"])), NewsText.sentence(w, f).replace("[b]", "**").replace("[/b]", "**")])
	for f in w.facts.query("POL_SCANDAL_REVEALED", int(c["opened"]), int(e["month"])):
		L.append("- %s: scandal: %s, %s (%s)" % [_date(int(f["month"])), _pname(f["data"].get("party", "")), f["data"].get("leader", ""), String(f["data"].get("channel", "")).to_lower()])
	L.append("")


func _bills(L: PackedStringArray) -> void:
	L.append("## 5. Bills and decisions")
	L.append("")
	L.append("Every bill put to parliament: who proposed it, what it changed, how each party voted, and in [brackets] what became of each clause after the vote (EFFECTIVE = in force; REJECTED = thrown out by legal review; CANCELLED = superseded).")
	L.append("")
	var bills: Array = w.table("bill").values()
	bills.sort_custom(func(a, b): return a["month"] < b["month"] or (a["month"] == b["month"] and a["id"] < b["id"]))
	var fate := {}  # "bill|lever" -> enactment status (+ errors)
	for e in w.table("enactment").values():
		var st := String(e["status"])
		if st == "REJECTED":
			st += " (" + "; ".join(e.get("errors", [])) + ")"
		fate[String(e.get("source_bill", "")) + "|" + String(e["lever"])] = st
	for b in bills:
		var cl: Array = b.get("clauses", []).map(func(c): return "%s %s→%s [%s]" % [c["lever"], str(c.get("from", "?")), str(c["to"]),
			fate.get(String(b["id"]) + "|" + String(c["lever"]), "not enacted") if b.get("status", "") == "PASSED" else "-"])
		var vt: Array = []
		var vk: Array = b.get("votes", {}).keys()
		vk.sort()
		for pid in vk:
			vt.append("%s %s" % [_code(pid), String(b["votes"][pid]).substr(0, 1)])
		L.append("- %s **%s** %s by %s (%d–%d): %s. Votes: %s" % [_date(int(b["month"])), b["id"], b.get("status", ""), _pname(b.get("sponsor", "")),
			int(b.get("yes", 0)), int(b.get("no", 0)), "; ".join(cl), ", ".join(vt)])
	L.append("")
	L.append("Ordinances (before parliament) and decrees:")
	L.append("")
	for f in w.facts.query("POL_ORDINANCE_ISSUED"):
		L.append("- %s %s" % [_date(int(f["month"])), "; ".join(f["data"].get("clauses", []).map(func(c): return "%s %s→%s" % [c["lever"], str(c.get("from", "?")), str(c["to"])]))])
	L.append("")


func _levers(L: PackedStringArray) -> void:
	L.append("## 6. Every lever change (when it took effect)")
	L.append("")
	L.append("| Month | Lever | From | To | Source |")
	L.append("|---|---|---|---|---|")
	for r in lever_log:
		L.append("| %s | %s | %s | %s | %s |" % [_date(r["month"]), r["lever"], str(r["from"]), str(r["to"]), r["source"]])
	L.append("")


func _years(L: PackedStringArray) -> void:
	L.append("## 7. Year by year")
	L.append("")
	var names: Array = YEAR_INDICATORS.map(func(s): return s[1])
	L.append("Colony = sovereignty status, charter quota share and charter price (% of value), gov = a home-world governor. Home = the home world's need and patience.")
	L.append("")
	L.append("| Year | Adults | Parties | Government (PM first) | " + " | ".join(names) + " | Colony | Home | Seats |")
	L.append("|" + "---|".repeat(names.size() + 7))
	for r in years_tbl:
		var gov: Array = [_code(r["pm"])] if r["pm"] != "" else []
		for pid in r["gov"]:
			if pid != r["pm"]:
				gov.append(_code(pid))
		var vals: Array = names.map(func(n): return ("%.1f" % r["ind"][n]) if r["ind"].has(n) else "")
		var sk: Array = r["seats"].keys()
		sk.sort_custom(func(a, b): return r["seats"][a] > r["seats"][b])
		L.append("| %d | %d | %d | %s | %s | %s | %s | %s |" % [r["year"], r["adults"], r["active"], " ".join(gov), " | ".join(vals), r.get("sov", ""), r.get("home", ""),
			" ".join(sk.map(func(pid): return "%s %d" % [_code(pid), r["seats"][pid]]))])
	L.append("")


func _event_log(L: PackedStringArray) -> void:
	L.append("## 8. Event log (political, legal and notable economic events)")
	L.append("")
	var ys: Array = events.keys()
	ys.sort()
	for y in ys:
		L.append("### Year %d" % y)
		L.append("")
		var c: Dictionary = counts[y]
		var ck: Array = c.keys()
		ck.sort()
		L.append("Counts: " + ", ".join(ck.map(func(t): return "%s %d" % [t, c[t]])))
		L.append("")
		for line in events[y]:
			L.append("- " + line)
		L.append("")


# ======================================================================= helpers

var _codes := {}


func _sorted_pids() -> Array:
	var ids: Array = w.table("party").keys()
	ids.sort_custom(func(a, b): return int(w.table("party")[a]["founded_month"]) < int(w.table("party")[b]["founded_month"]) or \
		(int(w.table("party")[a]["founded_month"]) == int(w.table("party")[b]["founded_month"]) and int(a.get_slice(":", 1)) < int(b.get_slice(":", 1))))
	return ids


func _code(pid: String) -> String:
	if pid == "":
		return ""
	if _codes.is_empty():
		var i := 1
		for id in _sorted_pids():
			_codes[id] = "P%d" % i
			i += 1
	return _codes.get(pid, pid)


func _pname(pid) -> String:
	return String(w.table("party").get(String(pid), {}).get("name", str(pid)))


func _date(m: int) -> String:
	return "Y%d-%02d" % [m / 12 + 1, m % 12 + 1]


func _cell_name(c: Dictionary) -> String:
	var d: String = c["district"]
	var dn: String = EconData.DISTRICTS.get(d, {}).get("name", d)
	return "%s · %s · %s · %s" % [dn, String(c["occ"]).to_lower(), String(c["band"]).to_lower(), c["cohort"]]


func _axes(pos: Dictionary) -> String:
	return ", ".join(PolDefs.AXES.map(func(ax): return "%s %+d" % [ax.to_lower(), int(pos[ax]) / 1000]))


func _why(s: Dictionary) -> String:
	var d: Dictionary = s["why"]
	match s["kind"]:
		"FOUNDING":
			return "one of the first parties, formed in Year 3 from the colony's main voter clusters"
		"UNREPRESENTED":
			return "voters nobody represented: %.1f%% of adults were far (> %d points) from every existing party" % [float(d.get("share", 0)) / 10.0, int(PartyLife.UNREP_DISTANCE)]
		"POPULIST":
			return "anti-establishment revolt: average government approval %d%%, satisfaction with governance %d%%" % [int(d.get("approval", 0)) / 1000, int(d.get("governance", 0)) / 1000]
		"SINGLE_ISSUE":
			return "single issue: %s badly unmet for %d+ months and no party credibly owned it" % [d.get("concern", "?"), PartyLife.ISSUE_MONTHS]
		"SPLINTER":
			return "breakaway: %d MPs left %s after their faction (on the %s axis) stayed rebellious for a year" % [int(d.get("mps", 0)), _pname(d.get("party", "")), String(d.get("axis", "")).to_lower()]
	return "%s %s" % [s["kind"], str(d)]


func _describe(f: Dictionary) -> String:
	var d: Dictionary = f["data"]
	var parts: Array = []
	for k in d:
		var v = d[k]
		if typeof(v) == TYPE_STRING and String(v).begins_with("party:"):
			v = _pname(v)
		elif typeof(v) == TYPE_ARRAY:
			v = ", ".join(v.map(func(x): return _pname(x) if typeof(x) == TYPE_STRING and String(x).begins_with("party:") else str(x)))
		elif typeof(v) in [TYPE_DICTIONARY]:
			v = str(v).left(160)
		parts.append("%s=%s" % [k, str(v)])
	return ", ".join(parts)


## 9. Unions, trade, industry and the press (A41, A42, media): built at the end from tables and facts.
func _society(L: PackedStringArray) -> void:
	L.append("## 9. Unions, trade, industry and the press")
	L.append("")
	var by_type := {}
	for f in w.facts.query("", -1, 1 << 30):
		var t: String = f["type"]
		if not by_type.has(t):
			by_type[t] = []
		by_type[t].append(f)
	_unions_section(L, by_type)
	_trade_section(L, by_type)
	_industry_section(L, by_type)
	_press_section(L, by_type)


func _unions_section(L: PackedStringArray, by_type: Dictionary) -> void:
	L.append("### Unions")
	L.append("")
	var unions: Array = w.peek("union").values()
	if unions.is_empty():
		L.append("No unions were founded.")
		L.append("")
		return
	var stats := {}
	for f in by_type.get("UNION_LEADER_ELECTED", []):
		if not f["data"].get("re_elected", false):
			_bump(stats, String(f["data"].get("union", "")) + "|lead")
	for f in by_type.get("UNION_DEMAND", []):
		_bump(stats, String(f["data"].get("union", "")) + "|demand")
	for f in by_type.get("UNION_STRIKE_CALLED", []):
		_bump(stats, String(f["data"].get("union", "")) + "|strikes")
	for f in by_type.get("UNION_SETTLED", []):
		_bump(stats, String(f["data"].get("union", "")) + "|" + String(f["data"].get("outcome", "")))
	for t in ["UNION_ENDORSED", "UNION_ENDORSEMENT_WITHDRAWN"]:
		for f in by_type.get(t, []):
			_bump(stats, String(f["data"].get("union", "")) + "|" + t)
	L.append("| Union | Sectors | Founded | Status | New leaders | Demands | Strikes | Won / compromise / lost | Settled in talks | Endorsed / withdrawn |")
	L.append("|---|---|---|---|---|---|---|---|---|---|")
	unions.sort_custom(func(a, b): return int(a.get("founded", 0)) < int(b.get("founded", 0)) or (int(a.get("founded", 0)) == int(b.get("founded", 0)) and String(a["id"]) < String(b["id"])))
	for u in unions:
		var id := String(u["id"])
		var secs: Array = u.get("sectors", []).map(func(x): return String(x).to_lower())
		L.append("| %s%s | %s | %s | %s | %d | %d | %d | %d / %d / %d | %d | %d / %d |" % [u["name"], " (federation)" if u.get("federation", false) else "",
			", ".join(secs), _date(int(u.get("founded", 0))), String(u.get("status", "")).to_lower(),
			int(stats.get(id + "|lead", 0)), int(stats.get(id + "|demand", 0)), int(stats.get(id + "|strikes", 0)),
			int(stats.get(id + "|WON", 0)), int(stats.get(id + "|COMPROMISE", 0)) + int(stats.get(id + "|ARBITRATED", 0)), int(stats.get(id + "|LOST", 0)),
			int(stats.get(id + "|ACCEPTED", 0)) + int(stats.get(id + "|COUNTER", 0)),
			int(stats.get(id + "|UNION_ENDORSED", 0)), int(stats.get(id + "|UNION_ENDORSEMENT_WITHDRAWN", 0))])
	L.append("")
	var dec := {}
	for f in by_type.get("UNION_STRIKE_CALLED", []):
		_bump(dec, str(int(f["month"]) / 120))
	var dl: Array = []
	for d in 10:
		dl.append("Y%d–%d: %d" % [d * 10 + 1, d * 10 + 10, int(dec.get(str(d), 0))])
	L.append("Strikes per decade: " + " · ".join(dl))
	L.append("")
	var ends: Array = by_type.get("UNION_ENDORSED", []) + by_type.get("UNION_ENDORSEMENT_WITHDRAWN", [])
	ends.sort_custom(func(a, b): return int(a["month"]) < int(b["month"]) or (a["month"] == b["month"] and String(a["id"]) < String(b["id"])))
	if not ends.is_empty():
		L.append("Endorsement history:")
		L.append("")
		for f in ends:
			var dd: Dictionary = f["data"]
			var un := String(w.peek("union").get(String(dd.get("union", "")), {}).get("name", dd.get("union", "?")))
			if f["type"] == "UNION_ENDORSED":
				var prev := String(dd.get("prev", ""))
				L.append("- %s %s backs %s%s" % [_date(int(f["month"])), un, _pcode(String(dd.get("party", ""))), (" (was %s)" % _pcode(prev)) if prev != "" else ""])
			else:
				L.append("- %s %s withdraws from %s (%s)" % [_date(int(f["month"])), un, _pcode(String(dd.get("party", ""))), String(dd.get("reason", "")).to_lower()])
		L.append("")
	L.append("Public employment scheme: %d hiring waves, %d cuts." % [by_type.get("ECON_PUBLIC_JOBS_HIRED", []).size(), by_type.get("ECON_PUBLIC_JOBS_CUT", []).size()])
	L.append("")


func _trade_section(L: PackedStringArray, by_type: Dictionary) -> void:
	L.append("### Trade (ships)")
	L.append("")
	var sold: Array = by_type.get("ECON_EXPORTS_SOLD", [])
	if sold.is_empty():
		L.append("No exports were sold.")
		L.append("")
		return
	L.append("| Ship | Exports (cr) | Export tax | Home levy | Main goods (units) | Top exporter | Imports (cr) |")
	L.append("|---|---|---|---|---|---|---|")
	var total := 0
	for f in sold:
		var d2: Dictionary = f["data"]
		var gs: Dictionary = d2.get("goods", {})
		var gk: Array = gs.keys()
		gk.sort_custom(func(a, b): return int(gs[a]) > int(gs[b]) or (gs[a] == gs[b] and String(a) < String(b)))
		total += int(d2.get("value", 0))
		var top := String(d2.get("top_exporter", ""))
		L.append("| %s | %d | %d | %d | %s | %s | %d |" % [_date(int(f["month"])), int(d2.get("value", 0)), int(d2.get("tax", 0)), int(d2.get("levy", 0)),
			", ".join(gk.slice(0, 3).map(func(g): return "%s %d" % [String(g).to_lower(), int(gs[g])])),
			String(w.table("org").get(top, {}).get("name", top)), int(d2.get("import_value", 0))])
	L.append("")
	L.append("Total exports: %d credits in %d ships. Home-price swings of 20%%+: %d. Port full: %d times." % [total, sold.size(),
		by_type.get("ECON_HOME_PRICE_SWING", []).size(), by_type.get("ECON_PORT_FULL", []).size()])
	L.append("")


func _industry_section(L: PackedStringArray, by_type: Dictionary) -> void:
	L.append("### Industry at the end, and investment by decade")
	L.append("")
	var ft := {}
	for fid in w.table("facility"):
		var fac: Dictionary = w.table("facility")[fid]
		_bump(ft, String(fac["type"]).to_lower() + (" (mothballed)" if fac.get("mothball", false) else ""))
	var fk: Array = ft.keys()
	fk.sort()
	L.append("Facilities: " + ", ".join(fk.map(func(k): return "%s %d" % [k, ft[k]])))
	L.append("")
	var inv := {}
	for f in by_type.get("COMP_INVESTMENT", []):
		_bump(inv, "%d|%s" % [int(f["month"]) / 120, String(f["data"].get("type", "?")).to_lower()])
	for d in 10:
		var ks: Array = inv.keys().filter(func(k): return String(k).begins_with("%d|" % d))
		ks.sort()
		if not ks.is_empty():
			L.append("- Y%d–%d: %s" % [d * 10 + 1, d * 10 + 10, ", ".join(ks.map(func(k): return "%s %d" % [String(k).get_slice("|", 1), inv[k]]))])
	L.append("")
	L.append("Plants scrapped: %d · mothballed: %d." % [by_type.get("ECON_FACILITY_SCRAPPED", []).size(), by_type.get("ECON_FACILITY_MOTHBALLED", []).size()])
	L.append("")


func _press_section(L: PackedStringArray, by_type: Dictionary) -> void:
	L.append("### The press")
	L.append("")
	var outs: Array = w.peek("outlet").values()
	if outs.is_empty():
		L.append("No newspapers.")
		L.append("")
		return
	L.append("| Paper | Owner | Founded | Status | Credibility |")
	L.append("|---|---|---|---|---|")
	outs.sort_custom(func(a, b): return String(a["id"]) < String(b["id"]))
	for o in outs:
		var own: Dictionary = o.get("owner", {})
		L.append("| %s | %s | %s | %s | %d |" % [o.get("name", "?"), "the state" if String(own.get("kind", "")) == "STATE" else "%s (%s)" % [_owner_name(own), String(own.get("kind", "")).to_lower()],
			_date(int(o.get("founded", 0))), String(o.get("status", "ACTIVE")).to_lower(), int(o.get("cred", 0)) / 1000])
	L.append("")
	L.append("Reports exposed as false or misleading: %d · investigations: %d · censorship: %d." % [by_type.get("MEDIA_REPORT_EXPOSED", []).size(),
		by_type.get("MEDIA_INVESTIGATION_PUBLISHED", []).size(), by_type.get("MEDIA_CENSORED", []).size()])
	L.append("")


static func _bump(d: Dictionary, k: String) -> void:
	d[k] = int(d.get(k, 0)) + 1


func _pcode(pid: String) -> String:
	if pid == "":
		return "nobody"
	return "%s %s" % [_code(pid), _pname(pid)]


func _owner_name(own: Dictionary) -> String:
	var id := String(own.get("id", ""))
	match String(own.get("kind", "")):
		"PARTY": return String(w.table("party").get(id, {}).get("name", id))
		"COMPANY", "ORG": return String(w.table("org").get(id, {}).get("name", id))
		"UNION": return String(w.peek("union").get(id, {}).get("name", id))
	return id

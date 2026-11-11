extends Control
## The colony newspaper: a front page built from last month's public facts (until the media step adds real
## outlets with editorial lines). Masthead, a lead story with a headline, second stories in columns, and side
## boxes for the poll, the government, the weather and the markets. Read-only.

const PAPER := Color("#f2ead6")
const INK := Color("#1d1a16")
const RULE := Color("#3a332a")
const MUTED := Color("#5c5348")
const MONTHS := ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

var session
var body: VBoxContainer
var _serif: SystemFont
var _serif_bold: SystemFont


func panel_title() -> String:
	return "Gazette"


func setup(s) -> void:
	session = s
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_serif = SystemFont.new()
	_serif.font_names = PackedStringArray(["Georgia", "Times New Roman", "Liberation Serif", "DejaVu Serif", "serif"])
	_serif_bold = SystemFont.new()
	_serif_bold.font_names = _serif.font_names
	_serif_bold.font_weight = 800
	var bg := ColorRect.new()
	bg.color = PAPER
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(sc)
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 28)
	sc.add_child(m)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	m.add_child(body)


# ---------------------------------------------------------------- building blocks

func _text(parent: Node, t: String, size_px: int, bold: bool = false, color: Color = INK, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", _serif_bold if bold else _serif)
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = align
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(l)
	return l


func _rule(parent: Node, thick: int = 1) -> void:
	var r := ColorRect.new()
	r.color = RULE
	r.custom_minimum_size = Vector2(0, thick)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(r)


func _vrule(parent: Node) -> void:
	var r := ColorRect.new()
	r.color = RULE
	r.custom_minimum_size = Vector2(1, 0)
	r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(r)


func _col(parent: Node, stretch: float) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_stretch_ratio = stretch
	v.add_theme_constant_override("separation", 6)
	parent.add_child(v)
	return v


static func plain(s: String) -> String:
	var r := RegEx.new()
	r.compile("\\[/?[a-z]+(=[^\\]]*)?\\]")
	return r.sub(s, "", true)


# ---------------------------------------------------------------- the page

func refresh() -> void:
	if session == null or body == null:
		return
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()
	var w: WorldState = session.world()
	var m := maxi(0, w.month - 1)
	var facts: Array = w.facts.query("", m, m, "PUBLIC").filter(func(f): return int(f["magnitude"]) >= 25 and not String(f["type"]).ends_with("_DONATION"))
	var stories := _stories(w, facts)
	# masthead
	var home: String = String(AreaStore.get_area(w, "hb:1").get("name", "Landing")) if w.peek("area").has("hb:1") else "Landing"
	_rule(body, 3)
	_text(body, "THE %s GAZETTE" % home.to_upper(), 46, true, INK, HORIZONTAL_ALIGNMENT_CENTER)
	_text(body, "“All the news the colony can bear”", 14, false, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_rule(body, 1)
	var dl := HBoxContainer.new()
	body.add_child(dl)
	_text(dl, "Vol. %d · No. %d" % [m / 12 + 1, m % 12 + 1], 13, false, MUTED)
	_text(dl, "%s, Year %d" % [MONTHS[m % 12], m / 12 + 1], 13, true, INK, HORIZONTAL_ALIGNMENT_CENTER)
	_text(dl, "Price: 2 credits", 13, false, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	_rule(body, 3)
	if stories.is_empty():
		_text(body, "A QUIET MONTH IN THE COLONY", 34, true, INK, HORIZONTAL_ALIGNMENT_CENTER)
		_text(body, "Nothing of note was reported. The colony went about its business.", 16, false, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		_boxes(w, body)
		return
	# lead story + side boxes
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	body.add_child(row)
	var lead := _col(row, 2.2)
	_vrule(row)
	var side := _col(row, 1.0)
	var top: Dictionary = stories[0]
	_text(lead, top["head"], 34, true)
	_text(lead, top["sub"], 17, false, MUTED)
	_rule(lead)
	_text(lead, top["body"], 15)
	_boxes(w, side)
	# second stories in three columns
	_rule(body, 2)
	var rest: Array = stories.slice(1, 10)
	if not rest.is_empty():
		var cols := HBoxContainer.new()
		cols.add_theme_constant_override("separation", 14)
		body.add_child(cols)
		var cs: Array = []
		for i in 3:
			if i > 0:
				_vrule(cols)
			cs.append(_col(cols, 1.0))
		for i in rest.size():
			var col: VBoxContainer = cs[i % 3]
			_text(col, rest[i]["head"], 18, true)
			_text(col, rest[i]["sub"], 14)
			_rule(col)


func _boxes(w: WorldState, parent: VBoxContainer) -> void:
	# government
	_text(parent, "THE GOVERNMENT", 15, true)
	_text(parent, plain(session.government_text()), 13)
	_text(parent, "Approval: %.0f%%" % (w.indicators.read("POL_GOV_APPROVAL") / 1000.0), 13, false, MUTED)
	_rule(parent)
	# latest poll
	var est: Dictionary = PartyLife.latest_poll_shares(w)
	if not est.is_empty():
		_text(parent, "LATEST POLL", 15, true)
		var ids: Array = est.keys()
		ids.sort_custom(func(a, b): return int(est[a]) > int(est[b]))
		for pid in ids.slice(0, 6):
			var p: Dictionary = w.peek("party").get(pid, {})
			var pct := float(est[pid]) / 1000.0
			_text(parent, "%-22s %5.1f%%  %s" % [String(p.get("name", pid)).left(22), pct, "▮".repeat(int(round(pct / 3.0)))], 12)
		_rule(parent)
	# weather (Terra)
	if w.indicators.values.has("PLANET_RAIN_PCT"):
		_text(parent, "WEATHER", 15, true)
		_text(parent, "Rain %d%% of normal · temperature %+.1f° · %d dry months" % [
			w.indicators.read("PLANET_RAIN_PCT") / 1000, w.indicators.read("PLANET_TEMP_ANOM") / 1000.0,
			w.indicators.read("PLANET_DROUGHT_MONTHS") / 1000], 13)
		_rule(parent)
	# markets (Bob)
	var mk: Array = EconQuery.market_overview(w).filter(func(r): return r.has("price") and r.get("good", "") in ["FOOD", "MATERIAL", "COMPONENT", "CONSUMER"])
	if not mk.is_empty():
		_text(parent, "MARKETS", 15, true)
		for r in mk:
			var ratio := float(r["price"]) / maxf(0.001, float(r["base_price"]))
			_text(parent, "%-10s %8.0f cr  %s" % [String(r["good"]).capitalize(), float(r["price"]), "▲" if ratio > 1.15 else ("▼" if ratio < 0.85 else "•")], 12)


## Editorial weight by kind of news: politics, scandal and disaster lead; routine delays go to the back.
const WEIGHT := {"POL_": 30, "HOME_": 40, "LAW_LEADER": 30, "LAW_CHARTER": 35, "LAW_PETITION": 30, "LAW_EVICTION": 25,
	"ECON_FAMINE": 60, "ECON_SOVEREIGN": 50, "PLANET_": 25, "COMP_WORKPLACE": 15, "ECON_STRIKE": 20, "ECON_LAYOFFS": 15,
	"COMP_LIQUIDATED": 10, "ECON_SHIP": 20, "ECON_CONTRACT": -40, "ECON_TENDER": -40, "ECON_RENT": -10, "ECON_SHORTAGE": -15,
	"ECON_LEVER_EFFECTIVE": -60, "POL_PROJECT_ORDERED": -20, "POL_BILL_PASSED": -15}
const GROUP_HEAD := {"ECON_CONTRACT_DELAYED": "BUILDING DELAYS PILE UP", "ECON_CONTRACT_SEVERELY_DELAYED": "BUILDING PROJECTS BADLY BEHIND",
	"ECON_TENDER_FAILED": "NO BUILDERS FOR PUBLIC PROJECTS", "COMP_LIQUIDATED": "COMPANIES GO UNDER", "ECON_SHORTAGE": "SHORTAGES SPREAD",
	"ECON_LAYOFFS_MASS": "WAVE OF LAYOFFS", "ECON_STRIKE": "STRIKES SPREAD", "POL_BILL_PASSED": "PARLIAMENT PASSES A RAFT OF BILLS",
	"ECON_FACILITY_CLOSED_UNSAFE": "PLANTS SHUT AS UNSAFE", "COMP_WORKPLACE_ACCIDENT": "ACCIDENTS AT THE WORKS",
	"LAW_CHARTER_AMENDED": "HOME WORLD REWRITES THE CHARTER"}


static func _weight(t: String) -> int:
	var best := 0
	var best_len := 0
	for k in WEIGHT:
		if t.begins_with(k) and String(k).length() > best_len:
			best = WEIGHT[k]
			best_len = String(k).length()
	return best


## Stories for the front page: repeated routine items grouped into one, ranked by magnitude + editorial weight.
func _stories(w: WorldState, facts: Array) -> Array:
	var by_type := {}
	for f in facts:
		var t: String = f["type"]
		if not by_type.has(t):
			by_type[t] = []
		by_type[t].append(f)
	var out: Array = []
	var types: Array = by_type.keys()
	types.sort()
	for t in types:
		var fs: Array = by_type[t]
		if fs.size() > 1 and GROUP_HEAD.has(t):
			var ex: Array = fs.slice(0, 4).map(func(x): return plain(NewsText.sentence(w, x)))
			out.append({"head": GROUP_HEAD[t], "sub": "%d reports this month" % fs.size(),
				"body": ". ".join(ex) + ("…" if fs.size() > 4 else "."), "score": fs.map(func(x): return int(x["magnitude"])).max() + _weight(t) + mini(15, 3 * fs.size())})
		else:
			for f in fs:
				out.append({"head": headline(w, f), "sub": plain(NewsText.sentence(w, f)), "body": article(w, f), "score": int(f["magnitude"]) + _weight(t)})
	out.sort_custom(func(a, b): return a["score"] > b["score"] or (a["score"] == b["score"] and a["head"] < b["head"]))
	return out


## Newspaper headline for a fact: short, punchy, upper case.
static func headline(w: WorldState, f: Dictionary) -> String:
	var d: Dictionary = f.get("data", {})
	var pn := func(pid): return String(w.peek("party").get(String(pid), {}).get("name", "PARTY")).to_upper()
	var h := ""
	match String(f["type"]):
		"POL_ELECTION_HELD": h = "THE COLONY HAS VOTED"
		"POL_GOVERNMENT_FORMED": h = "%s TO LEAD NEW GOVERNMENT" % pn.call(d.get("pm_party", ""))
		"POL_NO_CONFIDENCE_PASSED": h = "GOVERNMENT FALLS"
		"POL_PARTY_SPLIT": h = "REBELS QUIT %s" % pn.call(d.get("party", ""))
		"POL_PARTY_FOUNDED": h = "NEW PARTY ENTERS THE FRAY"
		"POL_SCANDAL_REVEALED": h = "SCANDAL ROCKS %s" % pn.call(d.get("party", ""))
		"POL_LEADER_CHANGED": h = "%s CHANGES LEADER" % pn.call(d.get("party", ""))
		"POL_BILL_DEFEATED": h = "GOVERNMENT DEFEATED IN PARLIAMENT"
		"POL_INDEPENDENCE_REFERENDUM": h = "COLONY VOTES ON INDEPENDENCE"
		"HOME_DEMAND_RAISED": h = "HOME WORLD TIGHTENS THE SCREWS"
		"LAW_CHARTER_AMENDED": h = "HOME WORLD REWRITES THE CHARTER"
		"HOME_PETITION_ANSWERED", "LAW_PETITION_ANSWERED": h = "HOME WORLD %s COLONY'S PLEA" % ("GRANTS" if d.get("accepted", false) else "REJECTS")
		"LAW_PETITION_SENT": h = "PARLIAMENT PETITIONS THE HOME WORLD"
		"HOME_INSPECTION_REPORT": h = "HOME INSPECTOR FINDS SMUGGLING" if int(d.get("found", 0)) > 0 else "HOME INSPECTOR GIVES ALL CLEAR"
		"HOME_EXPEDITION_SENT": h = "HOME WORLD SENDS WARSHIPS"
		"ECON_FAMINE": h = "FAMINE GRIPS THE COLONY"
		"ECON_SOVEREIGN_DEFAULT": h = "GOVERNMENT DEFAULTS ON ITS DEBTS"
		"ECON_STRIKE": h = "WORKERS WALK OUT"
		"ECON_LAYOFFS_MASS": h = "MASS LAYOFFS AT %s" % NewsText.org(w, d.get("org", "")).to_upper()
		"COMP_LIQUIDATED": h = "COMPANY GOES UNDER"
		"COMP_WORKPLACE_ACCIDENT": h = "ACCIDENT AT THE WORKS"
		"ECON_SHIP_ARRIVED": h = "SHIP FROM HOME!"
		"LAW_LEADER_CONVICTED": h = "LEADER CONVICTED"
		"LAW_EVICTION_ORDERED": h = "FAMILIES EVICTED"
		"PLANET_CYCLONE": h = "CYCLONE STRIKES"
		"PLANET_DROUGHT": h = "DROUGHT TIGHTENS ITS GRIP"
		"PLANET_SOLAR_FLARE": h = "SKIES ABLAZE: SOLAR FLARE"
		"PLANET_MOON_SURGE": h = "MOON SURGE FLOODS THE SHORE"
		"PLANET_SPORE_BLOOM": h = "SPORE BLOOM DRIFTS IN"
		_:
			var s := plain(NewsText.sentence(w, f))
			h = s.get_slice(":", 0).to_upper()
			if h.length() > 60:
				h = h.left(57) + "…"
	return h


## A short article body for the lead story.
static func article(w: WorldState, f: Dictionary) -> String:
	var d: Dictionary = f.get("data", {})
	var who := ""
	for r in f.get("responsible", []):
		if r["actor"]["kind"] in ["GOVERNMENT", "COMMANDER"] and float(r["share"]) >= 0.5:
			who = " Critics were quick to lay the blame at the government's door."
	var where := ""
	if f.get("location") != null:
		where = " The news came from %s." % NewsText.district(w, f["location"])
	var t := plain(NewsText.sentence(w, f)) + "." + where + who
	match String(f["type"]):
		"POL_ELECTION_HELD":
			var e: Dictionary = w.peek("election").get(String(d.get("election", "")), {})
			if not e.is_empty():
				var ids: Array = e["votes"].keys()
				ids.sort_custom(func(a, b): return e["votes"][a] > e["votes"][b])
				var parts: Array = []
				for pid in ids.slice(0, 4):
					parts.append("%s %.1f%% (%d seats)" % [w.peek("party")[pid]["name"], float(e["votes"][pid]) / maxf(1.0, e["total"]) * 100.0, int(e["seats"].get(pid, 0))])
				t = "Voters went to the polls across the colony. Leading results: %s. Coalition talks begin at once." % "; ".join(parts)
		"ECON_FAMINE":
			t += " Queues formed at the ration halls as stocks ran out. Families are being told to expect less in the weeks ahead."
	return t

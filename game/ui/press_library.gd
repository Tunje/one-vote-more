extends RefCounted
## The written articles and pictures in res://data/press (the user, 2026-11-16: a writer drops article files and
## pictures there; the paper uses what exists and falls back to its own one sentence for the rest). Preload by const.
##
## A file is articles/<EVENT>__<FLAVOUR>__<STANCE>__<KIND>.json with some variants {headline, sub, body}; blanks in
## curly braces are filled from what the game knows. A variant with a blank the game cannot fill is not used.

## An article says who it is about (the user, 2026-11-16: "at a company? No it should be named"). For these events a
## written variant is printed only if it uses every one of these blanks; the same list is `must_name` in wanted.json.
const MUST_NAME := {
	"POL_GOVERNMENT_FORMED": ["members"], "POL_SCANDAL_REVEALED": ["leader", "party"], "POL_PARTNER_LEFT": ["party"],
	"POL_LEADER_CHANGED": ["new", "party"], "POL_LEADERSHIP_RACE_OPENED": ["party"], "POL_PARTY_SPLIT": ["party", "splinter"],
	"UNION_STRIKE_CALLED": ["name"], "UNION_STRIKE_COLLAPSED": ["name"], "ECON_CONTRACT_SEVERELY_DELAYED": ["project"],
	"COMP_WORKPLACE_ACCIDENT": ["facility"], "POL_DEBATE_GAFFE": ["leader", "party"], "COMP_LIQUIDATED": ["company"],
	"ECON_LAYOFFS_MASS": ["company"],
}

static var dir := "res://data/press"
static var _files := {}     # path -> Dictionary ({} = missing or unreadable)
static var _pics := {}      # path -> Texture2D or null


## Which of the five voices an outlet writes in.
static func flavour(o: Dictionary) -> String:
	match String((o.get("owner", {}) as Dictionary).get("kind", "")):
		"STATE": return "STATE"
		"PARTY": return "PARTY"
		"UNION": return "UNION"
		"COMPANY":  # the louder company papers are the tabloids; at the usual loudness every other one is
			var sens := int(o.get("sens", 0))
			return "TABLOID" if sens > 600 or (sens == 600 and absi(hash(String(o.get("id", "")))) % 2 == 1) else "BUSINESS"
	return "STATE"


## How a report treats whoever is mainly responsible. `slant` > 0 plays a story up, < 0 plays it down; `valence` is
## whether the news is bad (-1), good (+1) or neither. Blaming someone outright is always AGAINST.
static func stance(angle: String, slant: float, valence: int) -> String:
	if angle != "NEUTRAL":
		return "AGAINST"
	if valence == 0 or absf(slant) < 0.2:
		return "NEUTRAL"
	return "AGAINST" if (slant > 0.0) == (valence < 0) else "FOR"


static func _file(event: String, fl: String, st: String, kind: String) -> Dictionary:
	var path := "%s/articles/%s__%s__%s__%s.json" % [dir, event, fl, st, kind]
	if kind == "FEATURE":
		path = "%s/articles/%s__%s.json" % [dir, event, fl]
	if not _files.has(path):
		var d := {}
		if FileAccess.file_exists(path):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary and (parsed as Dictionary).get("variants") is Array:
				d = parsed
		_files[path] = d
	return _files[path]


## Fills the blanks of one text. Returns "" when a blank cannot be filled (the text had content) .
static func fill(text: String, blanks: Dictionary) -> String:
	var out := text
	var r := RegEx.new()
	r.compile("\\{([a-z_]+)\\}")
	for m in r.search_all(text):
		var k := m.get_string(1)
		if not blanks.has(k) or String(blanks[k]) == "":
			return ""
		out = out.replace("{%s}" % k, String(blanks[k]))
	return "" if out.contains("{") or out.contains("}") else out


## The written article for this event, voice, stance and kind, with its blanks filled: {headline, sub, body}, or {}
## when none is written or none of its variants can be filled. `pick` chooses the variant (the same number gives the
## same variant). A stance that is not written falls back to NEUTRAL.
static func article(event: String, fl: String, st: String, kind: String, blanks: Dictionary, pick: int) -> Dictionary:
	for s in ([st, "NEUTRAL"] if st != "NEUTRAL" else ["NEUTRAL"]):
		var vs: Array = _file(event, fl, s, kind).get("variants", [])
		for i in vs.size():
			var v = vs[(absi(pick) + i) % vs.size()]
			if not (v is Dictionary):
				continue
			var raw := "%s %s %s" % [String(v.get("headline", "")), String(v.get("sub", "")), String(v.get("body", ""))]
			var named := true
			for k in MUST_NAME.get(event, []):
				named = named and raw.contains("{%s}" % k)
			if not named:
				continue
			var head := fill(String(v.get("headline", "")), blanks)
			var body := fill(String(v.get("body", "")), blanks)
			var sub_raw := String(v.get("sub", ""))
			var sub := fill(sub_raw, blanks)
			if head == "" or body == "" or (sub == "" and sub_raw != ""):
				continue
			return {"headline": head, "sub": sub, "body": body}
	return {}


## A picture for this kind of event (images/<EVENT>_1.png or _2.png), or null when none has been made.
static func picture(event: String, pick: int) -> Texture2D:
	var first := 1 + absi(pick) % 2
	for n in [first, 3 - first]:
		var path := "%s/images/%s_%d.png" % [dir, event, n]
		if not _pics.has(path):
			var tex: Texture2D = null
			if FileAccess.file_exists(path):
				var img := Image.load_from_file(ProjectSettings.globalize_path(path) if path.begins_with("res://") else path)
				if img != null and not img.is_empty():
					tex = ImageTexture.create_from_image(img)
			_pics[path] = tex
		if _pics[path] != null:
			return _pics[path]
	return null


## One value of a fact's data as a reader would see it: a name for an id, words for a code, a number as it is.
## "" when it cannot be said in words (yes/no values, empty lists).
static func value(w: WorldState, key: String, v) -> String:
	match typeof(v):
		TYPE_BOOL, TYPE_NIL, TYPE_DICTIONARY:
			return ""
		TYPE_INT:
			return str(v)
		TYPE_FLOAT:
			return str(int(round(v)))
		TYPE_ARRAY:
			var parts: Array = []
			for x in v:
				var s := value(w, key, x)
				if s == "":
					return ""
				parts.append(s)
			if parts.is_empty():
				return ""
			return String(parts[0]) if parts.size() == 1 else "%s and %s" % [", ".join(parts.slice(0, parts.size() - 1)), parts[parts.size() - 1]]
	var s := String(v)
	if s == "":
		return ""
	if w.peek("party").has(s):
		return NewsText.party(w, s)
	match key:
		"project": return NewsText.project(w, s)
		"facility": return NewsText.facility(w, s)
		"employer":
			if s == "gov":
				return "the government"
		"district": return NewsText.district(w, s)
	if w.peek("org").has(s):
		return NewsText.org(w, s)
	if key == "employer" or key == "company":
		return ""  # a company the game cannot name
	if s == s.to_upper() and s != s.to_lower():  # a code such as TRADE_EMBARGO
		return s.to_lower().replace("_", " ")
	return s


## Everything the game can put into an article about fact `f` printed by outlet `o` in `month`. `target` is who the
## paper holds mainly responsible ("" = work it out from the fact); `run` is how many months the story has run.
static func blanks(w: WorldState, f: Dictionary, o: Dictionary, month: int, run: int, target: String = "") -> Dictionary:
	var months: Array = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
	var b := {"paper": String(o.get("name", "the paper")), "month": months[month % 12], "year": "Year %d" % (month / 12 + 1)}
	b["colony"] = String(AreaStore.get_area(w, "hb:1").get("name", "Landing")) if w.peek("area").has("hb:1") else "Landing"
	var st: Dictionary = w.peek("pol").get("state", {})
	var pm: Dictionary = w.peek("party").get(String((st.get("government", {}) as Dictionary).get("pm_party", "")), {})
	if not pm.is_empty():
		b["governing_party"] = String(pm.get("name", ""))
		b["first_minister"] = PartyLife.leader_name(pm)
	var d: Dictionary = f.get("data", {})
	for k in d:
		var s := value(w, String(k), d[k])
		if s != "":
			b[String(k)] = s
	for sub in f.get("subjects", []):  # the company the event is about
		if sub is Dictionary and String(sub.get("kind", "")) in ["COMPANY", "ORG"] and w.peek("org").has(String(sub.get("id", ""))) and not b.has("company"):
			b["company"] = NewsText.org(w, sub["id"])
	if not b.has("company") and w.peek("org").has(String(d.get("org", ""))):
		b["company"] = NewsText.org(w, d["org"])
	if f.get("location") != null and not b.has("district"):
		b["district"] = NewsText.district(w, f["location"])
	if target == "":
		var best := 0.0
		for r in f.get("responsible", []):
			if float(r["share"]) > best:
				best = float(r["share"])
				target = "the government" if String(r["actor"].get("kind", "")) in ["GOVERNMENT", "COMMANDER"] else NewsText.actor(w, r["actor"])
		if target == "" or target == "someone":
			target = "the home world" if String(f.get("type", "")).begins_with("HOME_") else "the government"
	b["target"] = target
	if run > 0:
		b["months_running"] = str(run + 1)
		var m0 := month - run
		b["first_reported"] = "%s of Year %d" % [months[m0 % 12], m0 / 12 + 1]
	return b

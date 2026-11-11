extends VBoxContainer
## Parties: every party's leader, internal factions, money and history (spec-politics-v2, M9).

const Kit := preload("res://ui/panels/panel_kit.gd")
const KIND_TEXT := {"FOUNDING": "founding party", "UNREPRESENTED": "new party (voters nobody spoke for)",
	"POPULIST": "anti-establishment", "SINGLE_ISSUE": "single-issue", "SPLINTER": "breakaway faction"}
const EVENTS := {"POL_PARTY_FOUNDED": "founded", "POL_PARTY_SPLIT": "split", "POL_PARTIES_MERGED": "merger",
	"POL_PARTY_DISSOLVED": "dissolved", "POL_LEADER_CHANGED": "new leader", "POL_LEADER_SURVIVED": "leader survived a challenge",
	"POL_SCANDAL_REVEALED": "scandal"}

var session
var body: VBoxContainer


func panel_title() -> String:
	return "Parties"


func setup(s) -> void:
	session = s
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	body = Kit.scroll_body(self)


func refresh() -> void:
	if session == null or body == null:
		return
	Kit.clear(body)
	var w: WorldState = session.world()
	var parties := PartyLife.active(w)
	if parties.is_empty():
		Kit.label(body, "Political parties form in Year 3.", 14)
		return
	parties.sort_custom(func(a, b): return a["seats"] > b["seats"] or (a["seats"] == b["seats"] and a["id"] < b["id"]))
	for p in parties:
		_party(w, p)
		Kit.sep(body)
	Kit.header(body, "Party history")
	var rows: Array = []
	for t in EVENTS:
		for f in w.facts.query(t, -1, 1 << 30, "PUBLIC"):
			rows.append(f)
	rows.sort_custom(func(a, b): return a["month"] > b["month"])
	for f in rows.slice(0, 25):
		Kit.label(body, "Year %d: %s" % [f["month"] / 12 + 1, _event_text(w, f)], 12)
	var gone: Array = w.table("party").values().filter(func(q): return q["status"] != "ACTIVE")
	if not gone.is_empty():
		Kit.label(body, "Gone: " + ", ".join(gone.map(func(q): return "%s (%s)" % [q["name"], String(q["status"]).to_lower()])), 12, Color("#aaaaaa"))


func _party(w: WorldState, p: Dictionary) -> void:
	Kit.header(body, "%s  —  %d seats%s" % [p["name"], p["seats"], "  (you)" if p["is_player"] else ""])
	Kit.label(body, "%s, founded Year %d. Credibility %d/100. Funds %d cr." % [
		KIND_TEXT.get(p.get("kind", "FOUNDING"), "party"), p["founded_month"] / 12 + 1, p["credibility"],
		w.ledger.balance("party:" + p["id"]) / 1000 if w.ledger.has_account("party:" + p["id"]) else 0], 12, Color("#aaaaaa"))
	var l: Dictionary = p["leader"] if typeof(p["leader"]) == TYPE_DICTIONARY else {}
	if not l.is_empty():
		Kit.label(body, "Leader %s since Year %d: popularity %d, charisma %d, competence %d, integrity %d" % [
			l["name"], int(l["since"]) / 12 + 1, l["popularity"], l["charisma"], l["competence"], l["integrity"]], 13)
	if p.has("factions") and p["factions"].size() == 2:
		var ax: String = p["faction_axis"]
		for i in 2:
			var f: Dictionary = p["factions"][i]
			var mood := "content"
			if int(f["discontent"]) >= PartyLife.SPLIT_DISCONTENT:
				mood = "⚠ rebellious, may break away"
			elif int(f["discontent"]) >= 50:
				mood = "restless"
			Kit.label(body, "  %s faction on %s (%d%% of voters, %s)%s" % [
				"Low" if i == 0 else "High", ax.to_lower().replace("_", " "), int(f["strength"]) / 10, mood,
				"  ← leader's faction" if int(l.get("faction", -1)) == i else ""], 12)


func _event_text(w: WorldState, f: Dictionary) -> String:
	var d: Dictionary = f["data"]
	var nm := func(pid): return String(w.table("party").get(pid, {}).get("name", "?"))
	match f["type"]:
		"POL_PARTY_FOUNDED": return "%s founded (%s)" % [nm.call(d.get("party", "")), KIND_TEXT.get(d.get("kind", ""), "")]
		"POL_PARTY_SPLIT": return "%s split: %d MPs left to form %s" % [nm.call(d["party"]), d["mps"], nm.call(d["splinter"])]
		"POL_PARTIES_MERGED": return "%s merged into %s" % [nm.call(d["absorbed"]), nm.call(d["into"])]
		"POL_PARTY_DISSOLVED": return "%s dissolved" % nm.call(d["party"])
		"POL_LEADER_CHANGED": return "%s: %s replaced %s (%s)" % [nm.call(d["party"]), d["new"], d["old"], String(d["reason"]).to_lower().replace("_", " ")]
		"POL_LEADER_SURVIVED": return "%s: %s survived a leadership challenge" % [nm.call(d["party"]), d["leader"]]
		"POL_SCANDAL_REVEALED": return "%s: donation scandal (severity %d)" % [nm.call(d.get("party", "")), int(d.get("severity", 0))]
	return EVENTS.get(f["type"], f["type"])

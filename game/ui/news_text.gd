class_name NewsText
extends RefCounted
## Turns facts into readable news: names instead of ids, real sentences instead of event codes, and repeated
## routine events grouped into one line ("8 building projects are running late: ..."). Used by the monthly
## briefing and the news feed. Read-only (world.peek).


static func district(w: WorldState, id) -> String:
	if id == null:
		return "the colony"
	var d: Dictionary = w.peek("district").get(str(id), {})
	if not d.is_empty():
		return str(d.get("name", id))
	return str(EconData.DISTRICTS.get(str(id), {}).get("name", id))


static func org(w: WorldState, id) -> String:
	return String(w.peek("org").get(str(id), {}).get("name", "a company"))


static func party(w: WorldState, id) -> String:
	return String(w.peek("party").get(str(id), {}).get("name", "a party"))


const NICE := {"CONSUMERF": "consumer goods factory", "SERVICEHUB": "service hub", "MEDWORKS": "medical works",
	"COMPONENTS": "component works", "PROCESSING": "processing plant", "POWER": "power plant", "WATERWORKS": "waterworks",
	"DEPOT": "freight depot", "FARM": "farm", "MINE": "mine", "HOUSING": "housing block", "CLINIC": "clinic", "SCHOOL": "school"}


static func _kind(t) -> String:
	return String(NICE.get(str(t), str(t).to_lower().replace("_", " ")))


## Capitalise only the first letter (String capitalises every word).
static func cap1(s: String) -> String:
	return s if s.is_empty() else s.substr(0, 1).to_upper() + s.substr(1)


static func project(w: WorldState, id) -> String:
	var p: Dictionary = w.peek("project").get(str(id), {})
	if p.is_empty():
		return "a project"
	if p.get("type", "") == "EXPAND":
		var f: Dictionary = w.peek("facility").get(String(p.get("target", "")), {})
		return "the %s expansion in %s" % [_kind(f.get("type", "plant")), district(w, p.get("district", ""))]
	return "a new %s in %s" % [_kind(p.get("type", "building")), district(w, p.get("district", ""))]


static func facility(w: WorldState, id) -> String:
	var f: Dictionary = w.peek("facility").get(str(id), {})
	if f.is_empty():
		return "a plant"
	return "the %s in %s (%s)" % [_kind(f.get("type", "plant")), district(w, f.get("district", "")), org(w, f.get("org", ""))]


static func _subject_org(w: WorldState, f: Dictionary) -> String:
	for s in f.get("subjects", []):
		if s.get("kind", "") in ["COMPANY", "ORG"]:
			return org(w, s["id"])
	return org(w, f["data"].get("org", ""))


## Blame is shown only for bad news (a fact whose impact on voters' concerns is negative overall).
static func _gov(f: Dictionary) -> String:
	var net := 0.0
	for c in f.get("impact", {}):
		net += float(f["impact"][c])
	if net >= 0.0:
		return ""
	for r in f.get("responsible", []):
		if r["actor"]["kind"] in ["GOVERNMENT", "COMMANDER"] and float(r["share"]) >= 0.5:
			return " [color=#ff8a65](blamed on the government)[/color]"
	return ""


## One fact as a sentence.
static func sentence(w: WorldState, f: Dictionary) -> String:
	var d: Dictionary = f.get("data", {})
	var t: String = f["type"]
	var where := " in " + district(w, f["location"]) if f.get("location") != null else ""
	var s := ""
	match t:
		"ECON_CONTRACT_DELAYED": s = cap1("%s is running %d month(s) late" % [project(w, d.get("project", "")), int(d.get("months_late", 1))])
		"ECON_CONTRACT_SEVERELY_DELAYED": s = cap1("%s is now %d months late" % [project(w, d.get("project", "")), int(d.get("months_late", 0))])
		"ECON_CONTRACT_FAILED": s = "The builder walked away from %s" % project(w, d.get("project", ""))
		"ECON_CONTRACT_PAYMENT_MISSED": s = "Payment for %s is %d month(s) overdue" % [project(w, d.get("project", "")), int(d.get("months_overdue", 1))]
		"ECON_TENDER_FAILED": s = "Nobody bid to build %s" % project(w, d.get("project", ""))
		"ECON_TENDER_OPENED": s = "Tender opened for %s" % project(w, d.get("project", ""))
		"ECON_CONTRACT_AWARDED": s = "Contract awarded for %s" % project(w, d.get("project", ""))
		"ECON_PROJECT_COMPLETED": s = "Finished: %s" % project(w, d.get("project", ""))
		"ECON_LAYOFFS_MASS":
			s = "%s laid off %d workers (%d%% of its staff)%s" % [org(w, d.get("org", "")), int(d.get("persons", 0)), int(d.get("share_pct", 0)), ", and is closing" if d.get("closing", false) else ""]
		"ECON_STRIKE": s = "%d %s workers at %s are on strike over %s" % [int(d.get("persons", 0)), _kind(d.get("occupation", "")), org(w, d.get("org", "")), _kind(d.get("cause", "pay"))]
		"ECON_LOCKOUT": s = "%s locked out %d workers" % [org(w, d.get("org", "")), int(d.get("persons", 0))]
		"COMP_LIQUIDATED": s = "%s has gone out of business" % _subject_org(w, f)
		"COMP_INSOLVENCY": s = "%s is insolvent (%d employees)" % [_subject_org(w, f), int(d.get("employees", 0))]
		"COMP_DISTRESSED": s = "%s is in financial trouble" % _subject_org(w, f)
		"COMP_RESTRUCTURED": s = "%s restructured its debts" % _subject_org(w, f)
		"COMP_CEO_REPLACED": s = "%s replaced its management" % _subject_org(w, f)
		"COMP_COMPANY_FOUNDED": s = "New company: %s" % _subject_org(w, f)
		"COMP_WORKPLACE_ACCIDENT": s = "Accident at %s: %d workers hurt%s" % [facility(w, d.get("facility", "")), int(d.get("workers_affected", 0)), " (safety rules were being broken)" if d.get("in_violation", false) else ""]
		"ECON_FACILITY_CLOSED_UNSAFE": s = cap1("%s was shut down as unsafe" % facility(w, d.get("facility", "")))
		"ECON_FACILITY_REOPENED": s = cap1("%s reopened" % facility(w, d.get("facility", "")))
		"ECON_FACILITY_MOTHBALLED": s = cap1("%s was mothballed" % facility(w, d.get("facility", "")))
		"ECON_FACILITY_SOLD":
			var to: String = {"FIRM": " to another company", "WORKERS_COOP": " to its workers as a co-op", "STATE": " to the state"}.get(String(d.get("buyer_kind", "")), " to the state" if d.get("nationalized", false) else "")
			var why := " because its owner could not afford repairs" if d.get("reason", "") == "UNREPAIRABLE" else ""
			s = cap1("%s was sold%s%s%s" % [facility(w, d.get("facility", "")), why, to, " (the whole company)" if d.get("whole_company", false) else ""])
		"ECON_SHORTAGE": s = "Shortage%s: %d%% of demand could not be met" % [(" of " + _kind(d.get("good", ""))) if d.has("good") else "", int(d.get("shortfall_permille", 0)) / 10]
		"ECON_UTILITY_OUTAGE": s = "Power or water outages%s" % where
		"ECON_FOOD_AID": s = "Food aid handed out (%d rations)" % int(d.get("qty", 0))
		"ECON_FAMINE": s = "[color=#ff5252]FAMINE: the colony cannot feed itself[/color]"
		"ECON_RENT_INCREASE": s = "Rents rose %d%%%s" % [int(d.get("pct", 0)), where]
		"ECON_SOVEREIGN_DEFAULT": s = "[color=#ff5252]The government has defaulted on its debts[/color]"
		"ECON_DEBT_RESTRUCTURED": s = "Creditors wrote off part of the government's debt"
		"ECON_GOV_BORROWED": s = "The government borrowed money (debt now %d%% of the economy)" % int(d.get("debt_ratio_pct", 0))
		"ECON_SHIP_ARRIVED": s = "A ship from the home world arrived with %d migrants" % int(d.get("migrants", 0))
		"ECON_IMPORT_ARRIVED": s = "Imports arrived: %d %s" % [int(d.get("qty", 0)) / 1000, _kind(d.get("good", "goods"))]
		"POL_PROJECT_ORDERED": s = "The %s ordered a new %s in %s" % ["commander" if d.get("by", "") == "commander" else "government", _kind(d.get("type", "")), district(w, d.get("district", ""))]
		"POL_ELECTION_HELD": s = "[b]Election held[/b]"
		"POL_GOVERNMENT_FORMED": s = "[b]New government[/b]: %s" % ", ".join(d.get("members", []).map(func(p): return party(w, p)))
		"POL_BILL_PASSED": s = "Parliament passed a bill (%d–%d)" % [int(d.get("yes", 0)), int(d.get("no", 0))]
		"POL_BILL_DEFEATED": s = "Parliament [b]defeated[/b] a government bill (%d–%d)" % [int(d.get("yes", 0)), int(d.get("no", 0))]
		"POL_PARTY_FOUNDED": s = "New party: [b]%s[/b]" % party(w, d.get("party", ""))
		"POL_PARTY_SPLIT": s = "%d MPs left %s to form [b]%s[/b]" % [int(d.get("mps", 0)), party(w, d.get("party", "")), party(w, d.get("splinter", ""))]
		"POL_PARTIES_MERGED": s = "%s merged into %s" % [party(w, d.get("absorbed", "")), party(w, d.get("into", ""))]
		"POL_LEADER_CHANGED": s = "%s has a new leader: %s" % [party(w, d.get("party", "")), d.get("new", "")]
		"POL_SCANDAL_REVEALED": s = "[color=#ff8a65]Scandal[/color]: %s, %s" % [party(w, d.get("party", "")), d.get("leader", "")]
		"POL_NO_CONFIDENCE_PASSED": s = "[color=#ff5252][b]The government lost a vote of no confidence[/b][/color]"
		"POL_NO_CONFIDENCE_FAILED": s = "The government survived a vote of no confidence"
		"POL_SUPPORT_WITHDRAWN": s = "%s withdrew its support from the government" % party(w, d.get("party", ""))
		"POL_PARTNER_LEFT": s = "%s left the government" % party(w, d.get("party", ""))
		"POL_EMERGENCY_VOTE": s = "Parliament %s the state of emergency" % ("approved" if d.get("passed", false) else "rejected")
		"HOME_SHIP_CALLED": s = "A ship from the home world called"
		"HOME_DEMAND_RAISED": s = "[color=#ff8a65]The home world raised its demands[/color]"
		"HOME_SANCTION": s = "The home world imposed a sanction: %s" % _kind(d.get("kind", ""))
		"HOME_EXPEDITION_SENT": s = "[color=#ff5252][b]The home world has sent a punitive expedition[/b][/color]"
		_:
			s = cap1(t.replace("_", " ").to_lower())
	return s + _gov(f)


## Group key for routine events that come in batches.
const GROUPED := {
	"ECON_CONTRACT_DELAYED": "%d building projects are running late",
	"ECON_CONTRACT_SEVERELY_DELAYED": "%d building projects are badly delayed",
	"ECON_TENDER_FAILED": "%d projects got no bids",
	"ECON_CONTRACT_PAYMENT_MISSED": "%d project payments are overdue",
	"COMP_LIQUIDATED": "%d companies went out of business",
	"COMP_INSOLVENCY": "%d companies are insolvent",
	"ECON_FACILITY_CLOSED_UNSAFE": "%d plants were shut down as unsafe",
	"ECON_LAYOFFS_MASS": "%d companies made mass layoffs",
	"COMP_WORKPLACE_ACCIDENT": "%d workplace accidents",
	"ECON_SHORTAGE": "%d shortages",
	"ECON_UTILITY_OUTAGE": "%d power or water outages",
	"ECON_STRIKE": "%d strikes",
	"POL_BILL_PASSED": "Parliament passed %d bills",
}


## Readable digest of a list of facts: most important first, batches folded into one line with a few examples.
static func digest(w: WorldState, facts: Array, max_lines: int = 12, min_magnitude: int = 30) -> Array:
	var groups := {}
	var order: Array = []
	for f in facts:
		if int(f["magnitude"]) < min_magnitude:
			continue
		var key: String = f["type"] if GROUPED.has(f["type"]) else f["type"] + "#" + str(order.size())
		if not groups.has(key):
			groups[key] = []
			order.append(key)
		groups[key].append(f)
	order.sort_custom(func(a, b):
		var ma: int = groups[a].map(func(x): return int(x["magnitude"])).max()
		var mb: int = groups[b].map(func(x): return int(x["magnitude"])).max()
		return ma > mb or (ma == mb and a < b))
	var out: Array = []
	for key in order.slice(0, max_lines):
		var fs: Array = groups[key]
		if fs.size() == 1:
			out.append(sentence(w, fs[0]))
		else:
			var ex: Array = fs.slice(0, 3).map(func(x): return sentence(w, x).replace(" [color=#ff8a65](blamed on the government)[/color]", ""))
			out.append("%s: %s%s" % [GROUPED[fs[0]["type"]] % fs.size(), "; ".join(ex), " …" if fs.size() > 3 else ""])
	return out

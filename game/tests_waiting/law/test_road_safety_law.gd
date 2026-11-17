extends TestCase
## Anni: the law side of road safety (sim/law/road_safety_law.gd, flag ROAD_SAFETY): who sets limits, the default limit
## near homes, the minister's limit decision, liability for deaths where a pass was refused or a private road neglected.

const SL := preload("res://sim/law/road_safety_law.gd")
const Staff := preload("res://sim/staff/staff_ops.gd")


func _game(on: bool = true) -> Simulation:
	var sim := EconFace.sim_make(1, "BALANCED", {}, true)
	if on:
		(sim.world.meta["on"] as Array).append(RoadSafety.FLAG)
	for _m in 3:
		sim.step()
	return sim


## The colony link with homes in reach and the most people near it, made a fast, busy paved road.
func _fast_home_road(w: WorldState) -> String:
	var best := ""
	var bw := -1
	for lid in CoreUtil.sorted_keys(Transport._links(w)):
		if not SL.near_homes(w, String(lid)):
			continue
		var s := 0
		for sp in RoadSafety.spots(w, String(lid)):
			s += int(sp[1])
		if s > bw:
			bw = s
			best = String(lid)
	if best != "":
		var l: Dictionary = w.table("transport")["links"][best]
		l["kind"] = "PAVED"
		l["cond"] = 1000
		l["traffic_last"] = 3000
		Transport._bump(w)
	return best


func _econ(w: WorldState, v: int) -> void:
	var pm := Staff.pm_party(w)
	if w.table("party").has(pm):
		w.table("party")[pm]["positions"]["ECON_ROLE"] = v


func _accident(w: WorldState, lid: String, owner: String, refused: bool, killed: int) -> String:
	return w.add_fact({"type": "TRANSPORT_ROAD_ACCIDENT", "owner": "transport", "subjects": [], "responsible": [], "impact": {},
		"magnitude": 50, "visibility": "PUBLIC", "data": {"district": "d:1", "link": lid, "tile": "0,0", "kmh": 100, "limit": 0,
			"kind": "PAVED", "owner": owner, "people": 3, "near": "HOUSING", "facility": "", "pass_here": false,
			"pass_refused": refused, "offered_since": w.month - 6 if refused else -1, "killed": killed, "injured": 1}})


func _cases_for(w: WorldState, fid: String) -> Array:
	var out: Array = []
	for c in w.peek("case").values():
		if String(c["type"]) == "TORT" and String(c["data"].get("fact", "")) == fid:
			out.append(c)
	return out


func test_lever_gated_and_flag_off_writes_nothing() -> void:
	var w := _game(false).world
	var d: Dictionary = w.lever_defs[SL.LEVER]
	check(bool(d["legislative"]) and String(d["legalLevel"]) == "LAW", "the default limit is parliament's")
	check_eq(d.get("requires", []), ["ROAD_SAFETY"], "only with the flag")
	check(not Legislature.lever_available(w, d), "not draftable without the flag")
	w.levers[SL.LEVER] = 3
	SL.monthly(w)
	SL.justice(w)
	check(w.peek("speed_law").is_empty(), "nothing written")
	check(SL.may_set_limit(w, "x", 50, "MINISTER") != "", "no limits without the flag")


func test_the_default_limit_near_homes() -> void:
	var w := _game().world
	var lid := _fast_home_road(w)
	check(lid != "", "a road with homes in reach")
	w.levers[SL.LEVER] = 2
	SL.apply_statutory(w)
	check_eq(int(Transport._links(w)[lid].get("limit", 0)), 50, "the law sets 50 km/h near homes")
	check_eq(w.facts.query("LAW_SPEED_LIMITS_BY_LAW").size(), 1, "in public")
	SL.apply_statutory(w)
	check_eq(w.facts.query("LAW_SPEED_LIMITS_BY_LAW").size(), 1, "nothing new: no new fact")
	w.levers[SL.LEVER] = 1
	SL.apply_statutory(w)
	check_eq(int(Transport._links(w)[lid].get("limit", 0)), 70, "loosened: the law's own limit follows")
	w.levers[SL.LEVER] = 0
	SL.apply_statutory(w)
	check_eq(int(Transport._links(w)[lid].get("limit", 0)), 0, "repealed: lifted")
	# an exempt road keeps its speed
	SL.exempt(w, lid, "AI")
	w.levers[SL.LEVER] = 3
	SL.apply_statutory(w)
	check_eq(int(Transport._links(w)[lid].get("limit", 0)), 0, "exempt from the default limit")
	check_eq(w.facts.query("LAW_SPEED_EXEMPTION").size(), 1, "the exemption is public")


func test_who_may_set_a_limit() -> void:
	var w := _game().world
	var lid := _fast_home_road(w)
	check_eq(SL.may_set_limit(w, lid, 90, "MINISTER"), "", "the minister may")
	check(SL.may_set_limit(w, lid, 50, "org:x") != "", "a stranger may not")
	w.table("transport")["links"][lid]["owner"] = "org:x"
	check_eq(SL.may_set_limit(w, lid, 50, "org:x"), "", "the owner may slow its own road")
	check(SL.may_set_limit(w, lid, 0, "org:x") != "", "but not lift a limit")
	w.levers[SL.LEVER] = 2
	SL.apply_statutory(w)
	check(SL.may_set_limit(w, lid, 70, "org:x") != "", "nor go above the law's")
	check_eq(SL.may_set_limit(w, lid, 30, "org:x"), "", "below it is fine")


func test_the_minister_raising_the_laws_limit_exempts_the_road() -> void:
	var w := _game().world
	var lid := _fast_home_road(w)
	Transport.set_limit(w, lid, 90)
	w.levers[SL.LEVER] = 2
	SL.apply_statutory(w)
	check_eq(int(Transport._links(w)[lid].get("limit", 0)), 50, "the law lowers the road's 90")
	check(SL.exempts(w, lid, 70) and SL.exempts(w, lid, 0) and not SL.exempts(w, lid, 30), "above the law's limit is an exemption")
	Transport.set_limit(w, lid, 30)
	SL.apply_statutory(w)
	check(int(Transport._links(w)[lid].get("limit", 0)) == 30 and w.facts.query("LAW_SPEED_EXEMPTION").is_empty(), "lower: it governs")
	w.levers[SL.LEVER] = 0
	SL.apply_statutory(w)
	check_eq(int(Transport._links(w)[lid].get("limit", 0)), 30, "repeal leaves the minister's own limit")
	w.levers[SL.LEVER] = 2
	Transport.set_limit(w, lid, 0)
	SL.apply_statutory(w)
	Transport.set_limit(w, lid, 0)   # the minister lifts the law's limit
	SL.apply_statutory(w)
	check(int(Transport._links(w)[lid].get("limit", 0)) == 0 and w.facts.query("LAW_SPEED_EXEMPTION").size() == 1, "lifted by the minister: exempt")
	w.levers[SL.LEVER] = 0
	SL.apply_statutory(w)
	check_eq(int(Transport._links(w)[lid].get("limit", 0)), 0, "repealed: still none")
	w.levers[SL.LEVER] = 2
	Transport.set_limit(w, lid, 90)
	SL.apply_statutory(w)
	check_eq(int(Transport._links(w)[lid].get("limit", 0)), 90, "repealed and back: the exempt road keeps the minister's limit")


func test_the_owner_sets_its_own_limit() -> void:
	var w := _game().world
	var lid := _fast_home_road(w)
	w.table("transport")["links"][lid]["owner"] = "org:x"
	check_eq(SL.owner_limit(w, lid, 70, "org:x"), "", "the owner slows its road")
	check_eq(SL.owner_limit(w, lid, 90, "org:x"), "", "and may change its own limit")
	Transport.set_limit(w, lid, 50)   # the minister
	check(SL.owner_limit(w, lid, 70, "org:x") != "", "not above the minister's")


func test_a_death_where_a_pass_was_refused() -> void:
	var w := _game().world
	var lid := _fast_home_road(w)
	var a := _accident(w, lid, "", true, 1)
	SL.justice(w)
	var f: Array = w.facts.query("LAW_ROAD_LIABLE_PASS")
	check(f.size() == 1 and f[0]["responsible"][0]["actor"] == SL.GOV and not (f[0]["affected"]["districts"] as Array).is_empty(), "a public road: the state's")
	var c := _cases_for(w, a)
	check(c.size() == 1 and String(c[0]["respondent"]["kind"]) == "GOVERNMENT", "the victims sue the state")
	SL.justice(w)
	check_eq(_cases_for(w, a).size(), 1, "once per accident")
	var b := _accident(w, lid, "org:x", true, 1)
	SL.justice(w)
	var c2 := _cases_for(w, b)
	check(c2.size() == 1 and String(c2[0]["respondent"]["id"]) == "org:x" and is_equal_approx(float(c2[0]["data"]["gov_share"]), 1.0 - SL.LIABLE_OWNER_SHARE),
		"a private road: the owner, the traffic authority sharing")
	var n := _accident(w, lid, "", false, 1)
	SL.justice(w)
	check(_cases_for(w, n).is_empty(), "no pass refused, no limit declined: no case")


func test_deaths_after_a_declined_limit_or_an_exemption() -> void:
	var w := _game().world
	var lid := _fast_home_road(w)
	var item := Office.post(w, {"kind": "EMAIL", "role": "ENGINEER", "subject": "Speed", "summary_lines": [],
		"options": [{"id": "WAIT", "label": "No change", "action": {}}], "default_option": "WAIT", "deadline": w.month + 2,
		"source": {"system": "decision_case", "ref": "SAFE_LIMIT|" + lid}})
	var o: Dictionary = w.table("office_item")[item]
	o["status"] = "ANSWERED"
	o["answer"] = "WAIT"
	o["answered_month"] = w.month - 3
	check(SL.declined(w, lid), "the government's case declined a limit")
	var a := _accident(w, lid, "", false, 1)
	SL.justice(w)
	check_eq(w.facts.query("LAW_ROAD_DEATH_LIMIT_DECLINED").size(), 1, "blame for the declined limit")
	check(_cases_for(w, a).is_empty(), "but no tort: limits are policy")
	SL.exempt(w, lid, "AI")
	_accident(w, lid, "", false, 1)
	SL.justice(w)
	check_eq(w.facts.query("LAW_ROAD_DEATH_EXEMPT").size(), 1, "a death on an exempt road is the government's")


func test_a_neglected_private_road() -> void:
	var w := _game().world
	var lid := _fast_home_road(w)
	w.table("road_watch")[lid] = {"lid": lid, "owner": "org:x", "notice": w.month}
	var a := _accident(w, lid, "org:x", false, 1)
	SL.justice(w)
	var f: Array = w.facts.query("LAW_ROAD_LIABLE_NEGLECT")
	check(f.size() == 1 and f[0]["responsible"].size() == 1, "the owner's alone")
	var c := _cases_for(w, a)
	check(c.size() == 1 and String(c[0]["respondent"]["id"]) == "org:x" and float(c[0]["data"]["gov_share"]) == 0.0, "the owner pays")


func test_a_limit_declined_at_make_the_call() -> void:
	var w := _game().world
	var lid := _fast_home_road(w)
	check(not SL.declined(w, lid), "nothing declined yet")
	w.add_fact({"type": "POL_CASE_CALLED", "owner": "pol", "subjects": [], "responsible": [], "impact": {}, "magnitude": 5,
		"visibility": "OFFICIAL", "data": {"ref": "SAFE_LIMIT|" + lid, "type": "SPEED_LIMIT", "answer": "WAIT", "role": "ENGINEER", "person": ""}})
	check(SL.declined(w, lid), "the minister's call to wait counts")
	_accident(w, lid, "", false, 1)
	SL.justice(w)
	check_eq(w.facts.query("LAW_ROAD_DEATH_LIMIT_DECLINED").size(), 1, "and a death then is the government's")

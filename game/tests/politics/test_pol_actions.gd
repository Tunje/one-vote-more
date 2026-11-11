extends TestCase
## The human player's legislative loop: draft -> staff drafting completes -> submit.

const EconSim := preload("res://sim/economy/econ_sim.gd")
const StaffOps := preload("res://sim/staff/staff_ops.gd")


func _human_game() -> Simulation:
	var sim: Simulation = EconSim.make(3, "BALANCED", {}, false)  # autoplay off: the player acts
	sim.run(1)
	return sim


func test_commander_ordinance_flow() -> void:
	var sim := _human_game()
	var w := sim.world
	var lever := "ECON_BUDGET_HOUSING"
	var cur := int(w.levers[lever])
	var r := PolActions.player_draft(w, [{"lever": lever, "to": cur + 500}])
	check(r["ok"], "draft starts: %s" % [r])
	var early := PolActions.player_submit(w, r.get("bill_id", ""))
	check(not early["ok"], "cannot submit before drafting completes")
	var done := false
	for _i in 18:
		StaffOps.auto_staff(w, PolActions.GOV)  # what a player does in the personnel screen
		sim.step()
		if PolActions.player_drafts(w)[0]["ready"]:
			done = true
			break
	check(done, "drafting completes within 18 months")
	var s := PolActions.player_submit(w, r["bill_id"])
	check(s["ok"] and s["result"] == "ORDINANCE_ISSUED", "ordinance issued: %s" % [s])
	var queued := false
	for e in w.peek("enactment").values():
		if e["lever"] == lever and e["source_bill"] == r["bill_id"]:
			queued = true
	check(queued, "ordinance queued for law")
	check(not PolActions.player_submit(w, r["bill_id"])["ok"], "no double submit")
	check(int(w.peek("pol")["state"]["revealed"]["FISCAL"]) != 0 or int(w.peek("pol")["state"]["revealed"]["REDISTRIBUTION"]) != 0, "ordinance shapes commander identity")


func test_draft_validation() -> void:
	var w := _human_game().world
	check(not PolActions.player_draft(w, [])["ok"], "empty bill refused")
	check(not PolActions.player_draft(w, [{"lever": "NOPE", "to": 1}])["ok"], "unknown lever refused")
	var lever := "ECON_BUDGET_HOUSING"
	check(not PolActions.player_draft(w, [{"lever": lever, "to": int(w.levers[lever])}])["ok"], "no-op refused")


func test_predict_vote_is_pure() -> void:
	var sim: Simulation = EconSim.make(4, "BALANCED", {}, true)
	sim.run(50)  # parliament exists
	var h := sim.world.state_hash()
	var pv := PolActions.predict_vote(sim.world, [{"lever": "ECON_BUDGET_HOUSING", "from": 1200, "to": 1700}])
	check(pv.has("passes"), "prediction shape")
	check_eq(sim.world.state_hash(), h, "predict_vote must not change state")


func test_platform_and_agenda() -> void:
	var sim: Simulation = EconSim.make(5, "BALANCED", {}, false)
	sim.run(26)  # parties formed at m24
	var w := sim.world
	var pf := PolActions.player_platform(w)
	check(pf["ok"], "platform readable: %s" % [pf])
	var before: int = pf["axes"]["ENVIRONMENT"]["position"]
	var cred0: int = pf["credibility"]
	var r := PolActions.player_shift_platform(w, "ENVIRONMENT", 10)
	check(r["ok"], "shift ok: %s" % [r])
	check_eq(PolActions.player_platform(w)["axes"]["ENVIRONMENT"]["position"], before + 10, "moved")
	check(PolActions.player_platform(w)["credibility"] < cred0, "flip-flop costs credibility")
	check(not PolActions.player_shift_platform(w, "ENVIRONMENT", 10)["ok"], "yearly cap enforced")
	var ag := PolActions.player_set_agenda(w, [{"lever": "ECON_BUDGET_HOUSING", "dir": 1}])
	check(ag["ok"], "agenda set")
	sim.run(20)  # through the founding election (m44)
	var p: Dictionary = w.peek("party")[w.peek("pol")["state"]["player_party"]]
	check_eq(p["agenda"], [{"lever": "ECON_BUDGET_HOUSING", "dir": 1}], "player agenda survives the election")


func test_enum_lever_draft() -> void:
	var w := _human_game().world
	var enum_id := ""
	for lid in w.lever_defs:
		var d: Dictionary = w.lever_defs[lid]
		if d["type"] == "ENUM" and d["foundingEra"] == "COMMANDER":
			enum_id = lid
			break
	if enum_id == "":
		return  # no commander-era ENUM lever in this configuration
	var vals: Array = w.lever_defs[enum_id]["values"]
	var other = vals[0] if str(w.levers[enum_id]) != str(vals[0]) else vals[1]
	var r := PolActions.player_draft(w, [{"lever": enum_id, "to": other}])
	check(r["ok"], "enum draft accepted: %s" % [r])
	check(not PolActions.player_draft(w, [{"lever": enum_id, "to": "NOT_A_VALUE"}])["ok"], "bad enum value refused")

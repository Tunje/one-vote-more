extends TestCase
## MEDIA v1 M1 (planning/spec-media-v1.md): outlets, editions, framing, readership, news vector, hooks.

const LawOps := preload("res://sim/law/law_ops.gd")
const MD := preload("res://sim/media/media_data.gd")

const LEFT := {"ECON_ROLE": 60000, "REDISTRIBUTION": 60000, "LABOR": 60000}


func _line(d: Dictionary) -> Dictionary:
	var l := {}
	for ax in PolDefs.AXES:
		l[ax] = int(d.get(ax, 0))
	return l


func _biz() -> Dictionary:
	return Media._vec(PolDefs.OCC_IDEOLOGY["BUSINESS_OWNER"])


func _world(seed_value: int = 7) -> WorldState:
	var w := WorldState.new(seed_value)
	LawOps.init_world(w)
	w.month = 5
	return w


func _cell(w: WorldState, key: String, district: String, band: String, ideology: Dictionary, pop: int = 1000) -> Dictionary:
	var sal := {}
	for c in PolDefs.CONCERNS:
		sal[c] = 100
	var c := {"key": key, "district": district, "band": band, "pop": pop, "occ": "SERVICES", "ideology": _line(ideology),
		"salience": sal}
	w.table("cell")[key] = c
	return c


func _fact(w: WorldState, type: String, mag: int, resp: Array = [], impact: Dictionary = {}) -> String:
	return w.add_fact({"type": type, "owner": "test", "subjects": resp.map(func(r): return r["actor"]),
		"responsible": resp, "impact": impact, "magnitude": mag, "visibility": "PUBLIC"})


func _paper(w: WorldState, owner: Dictionary, line: Dictionary, extra: Dictionary = {}) -> String:
	var opts := {"line": _line(line), "quality": 100}
	opts.merge(extra, true)
	var r := Media.found_outlet(w, owner, opts)
	check(r["ok"], "founded %s" % [r])
	return r["out_id"]


func _gazette(w: WorldState) -> String:
	for id in Media.outlets(w):
		if w.peek("outlet")[id]["owner"]["kind"] == "STATE":
			return id
	return ""


func _picked(w: WorldState, out_id: String) -> Array:
	var ed := MediaQuery.edition(w, out_id, w.month)
	return ed.get("stories", []).map(func(s): return s["fact"])


func test_founding_paper_and_diet() -> void:
	var w := _world()
	_cell(w, "c1", "district:1", "MID", {})
	var el := _fact(w, "POL_ELECTION_HELD", 60)
	Media.run(w)
	var outs := MediaQuery.outlets(w)
	check_eq(outs.size(), 1, "one founding paper")
	check(String(outs[0]["name"]).ends_with("Gazette") and outs[0]["owner"]["kind"] == "STATE", "the state Gazette")
	check(el in _picked(w, outs[0]["id"]), "it covers the month's public news")
	var diet: Dictionary = w.table("cell")["c1"]["diet"]
	var s := 0
	for k in diet:
		s += int(diet[k])
	check(s > 0 and s < 1000, "diet share of the paper, the rest is word of mouth (%d)" % s)
	Media.run(w)
	check_eq(MediaQuery.outlets(w).size(), 1, "founded once")
	check(_picked(w, outs[0]["id"]).is_empty(), "nothing new: an empty edition")


func test_owner_buries_its_own_accident() -> void:
	var w := _world()
	Media.ensure_founding(w)
	var co := _paper(w, {"kind": "COMPANY", "id": "org:1"}, {}, {"quality": 0, "ethics": 0.0, "sens": 0.0})
	var gz: String = _gazette(w)
	w.table("outlet")[gz]["quality"] = 0
	var acc := _fact(w, "COMP_WORKPLACE_ACCIDENT", 55, [{"actor": {"kind": "COMPANY", "id": "org:1"}, "share": 1.0}])
	for i in 5:
		_fact(w, "ECON_SHIP_ARRIVED", 45)
	Media.run(w)
	check(not (acc in _picked(w, co)), "the company paper buries its owner's accident")
	check(acc in _picked(w, gz), "the state paper runs it")
	var big := _fact(w, "COMP_WORKPLACE_ACCIDENT", 80, [{"actor": {"kind": "COMPANY", "id": "org:1"}, "share": 1.0}])
	w.month += 1
	Media.run(w)
	check(big in _picked(w, co), "a disaster this big can't be buried")


func test_slant_frames_without_changing_the_fact() -> void:
	var w := _world()
	_cell(w, "c1", "district:1", "MID", {})
	var resp := [{"actor": {"kind": "COMPANY", "id": "org:1"}, "share": 0.5}, {"actor": {"kind": "GOVERNMENT", "id": "government"}, "share": 0.5}]
	var fid := _fact(w, "ECON_CONTRACT_SEVERELY_DELAYED", 50, resp, {"INFRASTRUCTURE": -4})
	var before: Dictionary = w.facts.get_fact(fid).duplicate(true)
	var left := _paper(w, {"kind": "UNION", "id": "union:fed"}, LEFT)
	var right := _paper(w, {"kind": "COMPANY", "id": "org:9"}, _biz())
	var f := w.facts.get_fact(fid)
	var rng := RandomNumberGenerator.new()
	var fl := Media.frame(w, w.table("outlet")[left], f, Media.stance(w, w.table("outlet")[left], f), rng)
	var fr := Media.frame(w, w.table("outlet")[right], f, Media.stance(w, w.table("outlet")[right], f), rng)
	check(fl["truth"] == "SLANTED" and fl["blame_actor"]["kind"] == "COMPANY" and float(fl["gov_share"]) < 0.5,
		"the labour paper blames the contractor (%s)" % [fl])
	check(fr["truth"] == "SLANTED" and fr["blame_actor"]["kind"] == "GOVERNMENT" and float(fr["gov_share"]) > 0.5,
		"the business paper blames the government (%s)" % [fr])
	check_eq(w.facts.get_fact(fid), before, "the fact itself never changes")
	Media.ensure_founding(w)
	var gz: String = _gazette(w)
	var fg := Media.frame(w, w.table("outlet")[gz], f, Media.stance(w, w.table("outlet")[gz], f), rng)
	check_eq(fg["truth"], "ACCURATE", "an independent public paper does not slant")


func test_readership_price_and_fit() -> void:
	var w := _world()
	Media.ensure_founding(w)
	var gz: String = Media.outlets(w)[0]
	w.table("outlet")[gz]["price_mw"] = 30     # expensive: 3% of W_ref a month
	var cheap := _paper(w, {"kind": "UNION", "id": "union:fed"}, LEFT, {"price_mw": 1})
	var low := _cell(w, "low", "district:1", "LOW", LEFT)
	var high := _cell(w, "high", "district:1", "HIGH", {})
	var rich_left := _cell(w, "hl", "district:1", "HIGH", LEFT)
	Media.run(w)
	check(not low["diet"].has(gz) and low["diet"].has(cheap), "the poor read the cheap paper only (%s)" % [low["diet"]])
	check(high["diet"].has(gz), "the well-off can afford the Gazette (%s)" % [high["diet"]])
	check(int(rich_left["diet"].get(cheap, 0)) > int(high["diet"].get(cheap, 0)), "readers prefer papers they agree with")
	check(int(w.table("outlet")[cheap]["circulation"]) > 0, "circulation counted")
	check(Media.demand(w)[cheap].has("district:1"), "demand per district for Bob")


func test_news_vector_reaches_only_readers() -> void:
	var w := _world()
	Media.ensure_founding(w)
	var right := _paper(w, {"kind": "COMPANY", "id": "org:9"}, _biz(), {"reach": ["district:1"], "sens": 0.0})
	var reader := _cell(w, "r", "district:1", "HIGH", _biz())
	var other := _cell(w, "o", "district:2", "HIGH", _biz())
	w.table("outlet")[_gazette(w)]["reach"] = []
	_cell(w, "mass", "district:3", "MID", {}, 100000)   # the colony (and so the government) sits near the centre      # no Gazette anywhere in this test
	var resp := [{"actor": {"kind": "COMPANY", "id": "org:1"}, "share": 0.5}, {"actor": {"kind": "GOVERNMENT", "id": "government"}, "share": 0.5}]
	_fact(w, "ECON_CONTRACT_SEVERELY_DELAYED", 50, resp, {"INFRASTRUCTURE": -4})
	Media.run(w)
	check(reader["diet"].has(right), "reader")
	check(int(reader["news_blame"]) < 0, "the business paper's readers blame the government more (%d)" % int(reader["news_blame"]))
	check_eq(int(other["news_blame"]), 0, "people who don't read it are not affected")



func test_exaggeration_biases_perception_and_fades() -> void:
	var w := _world()
	Media.ensure_founding(w)
	w.table("outlet")[_gazette(w)]["reach"] = []
	_cell(w, "mass", "district:3", "MID", {}, 100000)
	var left := _paper(w, {"kind": "UNION", "id": "union:fed"}, LEFT, {"reach": ["district:1"]})
	var reader := _cell(w, "r", "district:1", "LOW", LEFT)
	_fact(w, "ECON_LAYOFFS_MASS", 50, [{"actor": {"kind": "COMPANY", "id": "org:1"}, "share": 1.0}], {"JOBS": -4})
	Media.run(w)
	check(reader["diet"].has(left), "reader")
	check(int(reader["news_bias"].get("JOBS", 0)) < 0, "an exaggerated story lowers perceived conditions (%s)" % [reader["news_bias"]])
	var b0 := int(reader["news_bias"]["JOBS"])
	w.month += 1
	Media.run(w)
	check(int(reader["news_bias"].get("JOBS", 0)) > b0, "perceived bias fades without new stories")
	check_eq(w.table("cell")["mass"].get("news_bias", {}), {}, "non-readers keep the facts as they are")


func test_neutral_paper_adds_almost_nothing() -> void:
	var w := _world()
	_cell(w, "c1", "district:1", "MID", {})
	for i in 6:
		_fact(w, "ECON_SHORTAGE", 40 + i * 5, [{"actor": {"kind": "GOVERNMENT", "id": "government"}, "share": 1.0}], {"COST_OF_LIVING": -3})
	Media.run(w)
	var c: Dictionary = w.table("cell")["c1"]
	check(absi(int(c["news_blame"])) <= 100, "one neutral paper: news blame about zero (%d)" % int(c["news_blame"]))
	check(c["news_bias"].is_empty(), "no perceived bias")


func test_determinism() -> void:
	var eds: Array = []
	for _r in 2:
		var w := _world(11)
		_cell(w, "c1", "district:1", "MID", LEFT)
		_paper(w, {"kind": "UNION", "id": "union:fed"}, LEFT, {"quality": 20})
		for i in 12:
			_fact(w, "ECON_STRIKE", 30 + (i * 7) % 40, [{"actor": {"kind": "COMPANY", "id": "org:%d" % i}, "share": 1.0}], {"JOBS": -2})
		Media.run(w)
		eds.append([w.peek("report").duplicate(true), w.table("cell")["c1"].duplicate(true)])
	check_eq(eds[0], eds[1], "same seed, same editions and readers")


func test_campaign_tilt_and_ads() -> void:
	var w := _world()
	w.table("party")["party:1"] = {"id": "party:1", "name": "Labour", "positions": _line(LEFT), "status": "ACTIVE"}
	w.table("party")["party:2"] = {"id": "party:2", "name": "Business", "positions": _biz(), "status": "ACTIVE"}
	Media.ensure_founding(w)
	var pp := _paper(w, {"kind": "PARTY", "id": "party:1"}, LEFT)
	var c := _cell(w, "c1", "district:1", "MID", LEFT)
	Media.run(w)
	var t1 := MediaQuery.campaign_tilt(w, c, "party:1")
	var t2 := MediaQuery.campaign_tilt(w, c, "party:2")
	check(t1 > 1.0 and t2 < 1.0, "friendly papers amplify, hostile ones dampen (%.3f / %.3f)" % [t1, t2])
	check(MediaQuery.campaign_tilt_district(w, "district:1", "party:1") > 1.0, "district version")
	var snap: Dictionary = w.peek("outlet").duplicate(true)
	MediaQuery.campaign_tilt(w, c, "party:1")
	check_eq(w.peek("outlet"), snap, "tilt is read-only")
	w.ledger.open_account("party:2", false)
	w.ledger.transfer(Ledger.EXTERNAL, "party:2", 10000, "seed", w.month)
	var paid := Media.pay_ads(w, "party:2", 10000, {"district:1": 1.0, "district:9": 1.0}, "ads")
	check(paid > 0 and paid <= 5000, "half the ad money targets a district with readers (%d)" % paid)
	check_eq(w.ledger.balance("party:2"), 0, "all of it is spent")
	check(w.ledger.balance(String(w.peek("outlet")[pp]["account"])) > 0, "the party's own paper earns ad money too")


func test_owner_rules() -> void:
	var w := _world()
	w.levers["LAW_PARTY_PRESS"] = false
	check_eq(Media.found_outlet(w, {"kind": "PARTY", "id": "party:1"})["reason"], "PARTY_PRESS_BANNED", "party press banned")
	w.levers["LAW_PARTY_PRESS"] = true
	var id: String = Media.found_outlet(w, {"kind": "COMPANY", "id": "org:1"})["out_id"]
	check_eq(MediaQuery.owned_by(w, {"kind": "COMPANY", "id": "org:1"}), [id], "owned_by")
	check(Media.transfer_outlet(w, id, {"kind": "COMPANY", "id": "org:2"}, 500)["ok"], "sold")
	check_eq(MediaQuery.owned_by(w, {"kind": "COMPANY", "id": "org:2"}), [id], "new owner")
	Media.on_insolvent(w, id)
	check_eq(MediaQuery.outlets(w).size(), 0, "an insolvent paper closes")
	check(not w.facts.query("MEDIA_OUTLET_CLOSED").is_empty(), "public closure fact")

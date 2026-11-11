extends TestCase
## M13 land law (planning/spec-areas-v1.md §9.4, A37).

const Land := preload("res://sim/law/land_law.gd")
const LQ := preload("res://sim/law/law_query.gd")
const LawOps := preload("res://sim/law/law_ops.gd")
const J := preload("res://sim/law/justice_ops.gd")
const RE := preload("res://sim/law/rules_engine.gd")

const GOV := {"kind": "GOVERNMENT", "id": "government"}
const CO := {"kind": "COMPANY", "id": "org:1"}
const HH := {"kind": "HOUSEHOLD", "id": "hh:p3"}


func _world() -> WorldState:
	var w := WorldState.new(23)
	Terrain.generate(w)
	LawOps.init_world(w)
	Land.ensure_rules(w)
	AreaStore.change_listeners = []
	AreaStore.district_resolver = Callable()
	Land.land_value_fn = Callable()
	Land.on_land_taken_fn = Callable()
	for lid in ["LAW_LAND_DISPOSAL", "LAW_LAND_PRICE_FLOOR_PCT", "LAW_RENT_CONTROL", "LAW_EVICTION_NOTICE_MONTHS"]:
		for d in preload("res://sim/law/law_data.gd").LEVERS:
			if d["id"] == lid:
				w.levers[lid] = d["default"]
	return w


func _free(w: WorldState, dx: int = 3) -> Vector2i:
	var l := Terrain.landing(w)
	return Terrain.nearest_free(w, clampi(l.x + dx, 0, Terrain.W - 1), l.y, Terrain.BUILDABLE_HOUSING, 8)


func test_state_owns_all_land_at_founding() -> void:
	var w := _world()
	var t := _free(w)
	check_eq(Land.title(w, t)["owner"], "gov", "the state owns the land")
	check(w.peek("land_title").is_empty(), "no rows stored for state land")
	check(Land.can_build(w, GOV, t, "HOUSING")["ok"], "the state builds on its own land")
	check(not Land.can_build(w, CO, t, "INDUSTRY")["ok"], "a company needs a title or a lease")


func test_lease_and_sale_follow_land_policy() -> void:
	var w := _world()
	var t := _free(w)
	var value := Land.land_value(w, t)
	var off := LQ.land_offer(w, t, CO, "INDUSTRY")
	check(off["allowed"] and off["mode"] == "LEASE" and off["lease_rent"] == int(round(value * 0.006)), "default: lease (%s)" % [off])
	check(not Land.grant_land(w, t, CO, "SELL", value)["ok"], "no sale under the LEASE policy")
	check(Land.grant_land(w, t, CO, "LEASE", off["lease_rent"], 240)["ok"], "lease granted")
	check_eq(Land.right_of(w, CO, t), "LESSEE", "company leases the tile")
	check(Land.can_build(w, CO, t, "INDUSTRY")["ok"], "and may build")
	w.levers["LAW_LAND_DISPOSAL"] = "KEEP"
	var t2 := _free(w, 6)
	check(not LQ.land_offer(w, t2, CO)["allowed"], "KEEP: nothing on offer")
	w.levers["LAW_LAND_DISPOSAL"] = "SELL"
	w.levers["LAW_LAND_PRICE_FLOOR_PCT"] = 30
	check_eq(LQ.land_offer(w, t2, HH)["price"], int(round(value * 0.3)), "cheap land for households")
	check_eq(LQ.land_offer(w, t2, CO)["price"], int(round(value * 0.9)), "companies still pay 90%")
	check(not Land.grant_land(w, t2, CO, "SELL", int(value * 0.5))["ok"], "below the floor: rejected")
	check(Land.grant_land(w, t2, HH, "SELL", int(round(value * 0.3)))["ok"], "cheap household purchase")
	var sold := w.facts.query("LAND_SOLD")
	check(sold.size() == 1 and int(sold[0]["data"]["discount_pct"]) == 70, "public sale fact with discount")
	check_eq(Land.right_of(w, HH, t2), "OWNER", "household owns its plot")


func test_zoning_is_grandfathered() -> void:
	var w := _world()
	var t := _free(w)
	var a := AreaStore.place_housing(w, t, 40, "GOV")
	check(Land.zone(w, [t], "RESERVE")["ok"], "the government zones")
	check(Terrain.use_at(w, t.x, t.y).get("area", "") == a, "existing housing stays (grandfathered)")
	check(not Land.can_build(w, GOV, t, "HOUSING")["ok"], "no new building in a reserve")
	check(not Land.zone(w, [t], "MOON")["ok"], "unknown zone")
	check(not Land.zone(w, [t], "INDUSTRIAL", CO)["ok"], "a company cannot zone")


func test_expropriation_needs_purpose_and_full_compensation() -> void:
	var w := _world()
	w.levers["LAW_LAND_DISPOSAL"] = "SELL"
	var t := _free(w)
	var value := Land.land_value(w, t)
	Land.grant_land(w, t, CO, "SELL", value)
	check(not Land.expropriate(w, [t], GOV, "", value)["ok"], "no public purpose")
	check(not Land.expropriate(w, [t], GOV, "WATERWORKS", value / 2)["ok"], "half compensation is unlawful")
	var r := Land.expropriate(w, [t], GOV, "WATERWORKS", value)
	check(r["ok"] and Land.title(w, t)["owner"] == "gov", "expropriated with full compensation")
	check(not w.facts.query("LAND_EXPROPRIATED").is_empty(), "public fact")


func test_arrears_eviction_and_clearance() -> void:
	var w := _world()
	var t := _free(w)
	var a := AreaStore.place_housing(w, t, 50, "COMPANY")
	PopStore.seed_leaf(w, {"hb": a, "inc": "I2", "occ": "MINING", "status": "EMPLOYED", "arch": "PRAG"}, 40)
	var total0 := PopStore.total(w)
	check(Land.grant_land(w, t, CO, "LEASE", 1000, 120)["ok"], "company housing on leased land")
	var mc := LQ.may_clear(w, a)
	check(not mc["allowed"] and mc["residents"] == 40 and mc["needs_rehousing"], "no clearance of 40 residents without rehousing")
	check(LQ.may_clear(w, a, GOV, {"rehousing_units": 40})["allowed"], "with committed rehousing it is lawful")
	check_eq(RE.validate(w, CO, "EVICT", {})["result"], "PROHIBITED", "a landlord may not evict without an order")
	Land.report_arrears(w, t, 3)
	check_eq(Land.title(w, t)["tenure"], "OWNED", "lease ended after 3 months' arrears")
	check(w.peek("land_eviction").size() == 1, "eviction filed for the occupants")
	for _i in int(w.levers["LAW_EVICTION_NOTICE_MONTHS"]):
		w.month += 1
		Land.tick(w)
	var ord := w.facts.query("LAND_EVICTION_ORDERED")
	check(ord.size() == 1 and int(ord[0]["data"]["residents"]) == 40, "order after the notice period")
	check(ord[0].has("exposure") and ord[0]["exposure"]["kind"] == "DISPLACEMENT", "displacement exposure for S4")
	check(LQ.may_clear(w, a)["allowed"], "the order makes clearance lawful")
	check_eq(PopStore.total(w), total0, "law never deletes people")


func test_illegal_eviction_is_reported_by_tenants() -> void:
	var w := _world()
	var fid := LawOps.record_greed(w, "org:1", {"kind": "ILLEGAL_EVICTION", "facility": "hb:1"})
	check(w.table("violation_track")[fid]["unlawful"], "unlawful")
	check(J.detect_p(J.detect_ctx(w), w.table("violation_track")[fid])["inspect"] >= 0.29, "tenants complain: high detection")
	var sq := LawOps.record_greed(w, "org:2", {"kind": "SQUATTING_BUILD", "facility": "5,5"})
	check(w.table("violation_track")[sq]["unlawful"], "building without a title is unlawful")

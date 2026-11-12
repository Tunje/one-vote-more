class_name EconHousing
extends RefCounted
## S3 (A46 / A37, spec-areas §9, spec-settlements §S3): housing ages on an S-curve, needs more and more maintenance,
## and owners decide to renovate or let it slide.
##   - Age = months since the block was built (f.opened; a renovation resets it to RENO_AGE_M). Beyond the ordinary
##     upkeep model (materials keep a plant from decaying), housing loses condition with age: barely for 20 years,
##     then fast — DECAY_EARLY + DECAY_LATE × logistic((age − DECAY_MID) / DECAY_WIDTH) points a month; good upkeep
##     halves it.
##   - Each quarter the owner of a block below RENO_TRIGGER decides: the Housing Office (public) renovates if the
##     ECON_BUDGET_HOUSING line has room; a private landlord renovates if it can pay a third and borrow the rest.
##     Otherwise the block slides: its rent falls with condition (EconFinance.district_rent) and below RUNDOWN it is
##     run-down housing (a fact); a district whose housing averages below SLUM_COND is a slum (with EconCohorts).
##   - A renovation is a construction project (RENO_SHARE of a new block's work and materials): steady work for the
##     builders as the founding stock ages together (a renovation wave around Year 25–35).

const S := EconUtil.S
const DECAY_EARLY := 0.03  # points a month while young
const DECAY_LATE := 0.8  # added at full age
const DECAY_MID := 28.0  # years: the S-curve's midpoint
const DECAY_WIDTH := 4.0
const RENO_TRIGGER := 55
const RUNDOWN := 35
const SLUM_COND := 35
const RENO_SHARE := 0.35
const RENO_AGE_M := 60  # a renovated block counts as 5 years old


static func age_months(world: WorldState, f: Dictionary) -> int:
	return world.month - int(f.get("opened", 0))


## Condition points (of 100) lost to age this month.
static func decay_pts(world: WorldState, f: Dictionary) -> float:
	var y := float(age_months(world, f)) / 12.0
	var r := DECAY_EARLY + DECAY_LATE / (1.0 + exp(-(y - DECAY_MID) / DECAY_WIDTH))
	if int(f.get("upkeep_frac", 1000)) >= 900:
		r *= 0.5  # well maintained
	return r


## COMPANY_AI: ageing every month; owners' decisions every quarter.
static func monthly(world: WorldState) -> void:
	if EconUtil.off(world, "S3"):
		return
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] != "HOUSING" or f["mothball"]:
			continue
		var before := int(f["condition"])
		f["condition"] = maxi(0, before - int(decay_pts(world, f) * float(S)))
		if before >= RUNDOWN * S and int(f["condition"]) < RUNDOWN * S:
			EconFacts.emit(world, "ECON_HOUSING_RUNDOWN", f["district"], [["COMPANY", f["org"]]], EconFacts.company_blame(world, f["org"], 0.6),
				{"HOUSING": -15}, 25, "PUBLIC", {"facility": fid, "age_years": age_months(world, f) / 12, "owner": f["org"]}, {"districts": [f["district"]]})
	if world.month % 3 == 0:
		_owners_decide(world)


static func renovation_pending(world: WorldState, fid: String) -> bool:
	for pid in world.peek("project"):
		var p: Dictionary = world.peek("project")[pid]
		if p["type"] == "RENOVATE" and p.get("target", "") == fid and p["status"] in ["TENDER", "TENDERABLE", "ACTIVE"]:
			return true
	return false


static func _owners_decide(world: WorldState) -> void:
	var est := renovation_estimate()
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] != "HOUSING" or f["mothball"] or int(f["condition"]) >= RENO_TRIGGER * S or renovation_pending(world, fid):
			continue
		var o: Dictionary = world.table("org").get(f["org"], {})
		if o.is_empty() or not (o["status"] in ["ACTIVE", "DISTRESSED"]):
			continue
		if o["type"] in EconData.PUBLIC_TYPES:
			if EconActions.headroom(world, "ECON_BUDGET_HOUSING") >= est * 11 / 10:
				create_renovation(world, fid, "gov", "ECON_BUDGET_HOUSING")
		elif o["status"] == "ACTIVE":
			var cash := world.ledger.balance(EconUtil.acct(f["org"]))
			if cash >= est * 3 / 10 and (cash >= est or EconFinance.new_loan(world, f["org"], est * 7 / 10, 0, true)):
				create_renovation(world, fid, f["org"], "")


static func renovation_estimate() -> int:
	var b: Array = EconData.BUILD["HOUSING"]
	return int((float(b[0]) * RENO_SHARE * EconData.WU_COST_EST + float(b[1]) * RENO_SHARE * EconData.BASE_PRICE["MATERIAL"]
		+ float(b[2]) * 0.5 * EconData.BASE_PRICE["COMPONENT"]) * 1.15) * S


static func create_renovation(world: WorldState, fid: String, owner: String, line: String) -> String:
	var f: Dictionary = world.table("facility")[fid]
	var b: Array = EconData.BUILD["HOUSING"]
	var wu := int(float(b[0]) * RENO_SHARE)
	var id := world.new_id("project")
	world.table("project")[id] = {"id": id, "type": "RENOVATE", "target": fid, "district": f["district"], "owner": owner,
		"operator": f["org"], "line": line, "wu_total": wu * S, "wu_done": 0, "mat_total": int(float(b[1]) * RENO_SHARE) * S,
		"comp_total": int(float(b[2]) * 0.5) * S, "min_months": 4, "status": "TENDER", "tender_month": world.month, "bids": [],
		"contractor": "", "price": 0, "paid": 0, "bid_duration": 0, "start_month": -1, "size_class": EconConstruction.size_class(wu),
		"prog_m": 0, "unpaid_m": 0, "late_noted": false, "supervision": 1000, "staff_task": "", "est_cost": renovation_estimate()}
	EconFacts.emit(world, "ECON_TENDER_OPENED", f["district"], [["GOVERNMENT" if owner == "gov" else "COMPANY", owner]],
		[["GOVERNMENT", "government", 1.0]] if owner == "gov" else [["COMPANY", owner, 1.0]], {}, 10, "PUBLIC", {"project": id, "type": "RENOVATE"})
	return id


## Called when a RENOVATE project completes (EconConstruction._complete).
static func on_renovated(world: WorldState, p: Dictionary) -> String:
	var fid: String = p.get("target", "")
	if not world.table("facility").has(fid):
		return ""
	var f: Dictionary = world.table("facility")[fid]
	f["condition"] = 100 * S
	f["opened"] = world.month - RENO_AGE_M
	f["book"] = int(f.get("book", 0)) + int(p["price"])
	EconFacts.emit(world, "ECON_HOUSING_RENOVATED", f["district"], [["COMPANY", f["org"]]], [["COMPANY", f["org"], 0.5], ["GOVERNMENT", "government", 0.5]],
		{"HOUSING": 10}, 20, "PUBLIC", {"facility": fid, "owner": f["org"]}, {"districts": [f["district"]]})
	return fid


## Mean condition (0..100) of a district's housing, or 100 without housing.
static func district_condition(world: WorldState, d: String) -> int:
	var sc := 0
	var n := 0
	for fid in world.peek("facility"):
		var f: Dictionary = world.peek("facility")[fid]
		if f["type"] == "HOUSING" and f["district"] == d and not f["mothball"]:
			sc += int(f["condition"]) / S
			n += 1
	return 100 if n == 0 else sc / n


## Rent multiplier (‰) for a block's condition: run-down housing lets for less.
static func rent_factor(f: Dictionary) -> int:
	return 500 + int(f["condition"]) / S * 5

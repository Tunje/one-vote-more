class_name EconOffice
extends RefCounted
## Support economy part A (planning/plan-support-economy.md; user ruling "you have completely missed the support
## workers ... who pushes the papers at a power plant"): every organisation keeps an office staff — admin, planning,
## cleaning, reception, logistics — in proportion to its production crew, at an OFFICE facility of its own (one per
## organisation, in its head-office district; facility scale = posts × 100, the OFFICE recipe staffs 10 per unit).
## Office wages go through the ordinary payroll, so they are real costs and real household income; unit_cost carries
## the overhead (prices rise rather than offices being trimmed — Wilma). Public organisations' office staff are
## PUBLIC_SECTOR, firms' are SERVICES (EconLabor.occupation_of).
## v1: offices are rented space (no construction; on the map and built later with Terra). A firm in liquidation gives
## its office up (abandoned, scale 0: the staff are laid off through the vacancy machinery, the office is never sold).
## OPT-IN until its A/B (world.meta["on"] has "SUPPORT_A"); phased in at OFFICE_PHASE_PM of the target ratios.

const S := EconUtil.S
const OFFICE_PHASE_PM := 500  # Wilma: half of the target ratios for the first A/B, then full
const POSTS_PER_UNIT := 10  # OFFICE recipe labour per 1000 scale (5 G + 4 S + 1 Sp)
## Office posts per production post (‰) by facility type (plan §2A).
const RATIO_PM := {
	"FARM": 150, "MINE": 300, "PROCESSING": 300, "COMPONENTS": 300, "CONSUMERF": 250,
	"TEXTILE": 250, "FURNITURE": 250, "BAKERY": 250, "SERVICEHUB": 250, "DEPOT": 300,
	"POWER": 450, "WATERWORKS": 450, "MEDWORKS": 300,
	"CLINIC": 500, "SCHOOL": 500, "ADMIN": 500,
}
const CREW_RATIO_PM := 200  # builders' office staff per crew member
const NO_OFFICE_TYPES := ["OFFICE", "PUBJOBS", "HOUSING", "ROAD"]


static func active(world: WorldState) -> bool:
	return world.meta.has("on") and (world.meta["on"] as Array).has("SUPPORT_A") and not EconUtil.off(world, "SUPPORT_A")


## Support economy E (building upkeep, same office mechanism): caretakers and cleaners for the owner's housing —
## UPKEEP_PER_BLOCK_PM posts per 50-home block (1 per 150 homes), × up to 1.5 for old stock (age 20 → 40 years).
const UPKEEP_PER_BLOCK_PM := 333


static func upkeep_active(world: WorldState) -> bool:
	return EconSanitation.active(world)


## Overhead factor for a facility type's unit cost (1.0 when off): office posts ride on every production post.
static func cost_factor(world: WorldState, ftype: String) -> float:
	if not active(world):
		return 1.0
	return 1.0 + float(RATIO_PM.get(ftype, 0)) / 1000.0 * float(OFFICE_PHASE_PM) / 1000.0


## The organisation's office facility id ("" if it has none).
static func office_of(world: WorldState, oid: String) -> String:
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] == "OFFICE" and f["org"] == oid and not f.get("abandoned", false):
			return fid
	return ""


## Target office posts (persons) for an organisation from its production crews this month.
static func target_posts(world: WorldState, oid: String) -> int:
	var o: Dictionary = world.table("org")[oid]
	var pm := 0  # office posts × 1000 (milli-persons × ratio ‰ / 1000)
	var pm_upkeep := 0  # building upkeep (milli-persons), not phased
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["org"] != oid or f["type"] in NO_OFFICE_TYPES:
			continue
		var crew := 0
		var req := EconLabor.required(f)
		for t in req:
			crew += int(req[t])
		pm += crew * int(RATIO_PM.get(f["type"], 250)) / 1000
	if upkeep_active(world):
		var up := 0.0
		for fid2 in EconUtil.sorted_keys(world.table("facility")):
			var h: Dictionary = world.table("facility")[fid2]
			if h["org"] != oid or h["type"] != "HOUSING" or h["mothball"]:
				continue
			var age_y := float(EconHousing.age_months(world, h)) / 12.0
			up += EconUtil.fscale(h) * float(UPKEEP_PER_BLOCK_PM) / 1000.0 * (1.0 + 0.5 * clampf((age_y - 20.0) / 20.0, 0.0, 1.0))
		pm_upkeep = int(up * float(S))
	if o["is_contractor"]:
		var ct := 0
		for t in o["crew_target"]:
			ct += int(o["crew_target"][t])
		pm += ct * S * CREW_RATIO_PM / 1000
	var office := pm * OFFICE_PHASE_PM / 1000 if active(world) else 0
	return (office + pm_upkeep) / S


## COMPANY_AI, before FirmAI.run (so the office posts are advertised with the others this month).
static func monthly(world: WorldState) -> void:
	if not active(world) and not upkeep_active(world):
		return
	for oid in EconUtil.sorted_keys(world.table("org")):
		var o: Dictionary = world.table("org")[oid]
		var fid := office_of(world, oid)
		if o["status"] in ["LIQUIDATION", "DISSOLVED"] or o.get("key", "") == "PES":
			if fid != "":
				var f0: Dictionary = world.table("facility")[fid]
				f0["scale"] = 0
				f0["abandoned"] = true
			continue
		if o["status"] == "FORMING":
			continue
		var posts := target_posts(world, oid)
		if posts <= 0 and fid == "":
			continue
		if fid == "":
			var hq: String = o["hq"] if EconData.DISTRICTS.has(o["hq"]) else "d:1"
			fid = EconSetup.add_facility(world, "OFFICE", oid, hq, false)
			world.table("facility")[fid]["book"] = 0
		var f: Dictionary = world.table("facility")[fid]
		f["scale"] = posts * 1000 / POSTS_PER_UNIT
		f["T"] = 1000


## Office posts held and wanted, colony-wide (persons), for probes and the office.
static func summary(world: WorldState) -> Dictionary:
	var held := 0
	var wanted := 0
	var n := 0
	for fid in world.table("facility"):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] != "OFFICE" or f.get("abandoned", false):
			continue
		n += 1
		held += EconLabor.staff_total(f["staff"]) / S
		wanted += int(f.get("scale", 0)) * POSTS_PER_UNIT / 1000
	return {"offices": n, "posts_held": held, "posts_wanted": wanted}

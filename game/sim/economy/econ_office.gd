class_name EconOffice
extends RefCounted
## Support economy part A (planning/plan-support-economy.md; user ruling "you have completely missed the support
## workers ... who pushes the papers at a power plant"): every organisation keeps an office staff — admin, planning,
## cleaning, reception, logistics — at an OFFICE facility of its own (one per organisation, in its head-office
## district; public organisations' office staff are PUBLIC_SECTOR, firms' SERVICES).
## COST-NEUTRAL SPLIT (after the A/B, plan §10): the office is not an extra layer. A share of each plant's recipe crew
## — RATIO_PM office posts per production post, i.e. ratio / (1 + ratio) of the crew — works at the office instead
## of on the plant floor, tier by tier. Total posts, wages, unit costs and prices are exactly as before; the plants'
## output is unchanged (their staff fill is measured against the reduced floor crew). The added-cost version halved real
## income and revived the food trap on two of three seeds. The office posts are the base for workload / stress (27-W).
## Building upkeep (part E, "SUPPORT_E") is still additive: caretakers paid by the housing owner, at its office.
## v1: offices are rented space (no construction; on the map later with Terra). A firm in liquidation gives its office
## up (abandoned: the staff are laid off through the vacancy machinery, the office is never auctioned).
## OPT-IN until its A/B (world.meta["on"] has "SUPPORT_A").

const S := EconUtil.S
## Office posts per production post (‰) by facility type (plan §2A).
const RATIO_PM := {
	"FARM": 150, "MINE": 300, "PROCESSING": 300, "COMPONENTS": 300, "CONSUMERF": 250,
	"TEXTILE": 250, "FURNITURE": 250, "BAKERY": 250, "SERVICEHUB": 250, "DEPOT": 300,
	"POWER": 450, "WATERWORKS": 450, "MEDWORKS": 300,
	"CLINIC": 500, "SCHOOL": 500, "ADMIN": 500,
}
## Support economy E (building upkeep): caretakers and cleaners for the owner's housing — UPKEEP_PER_BLOCK_PM posts per
## 50-home block (1 per 150 homes), × up to 1.5 for old stock (age 20 → 40 years).
const UPKEEP_PER_BLOCK_PM := 333


static func active(world: WorldState) -> bool:
	return world.meta.has("on") and (world.meta["on"] as Array).has("SUPPORT_A") and not EconUtil.off(world, "SUPPORT_A")


static func upkeep_active(world: WorldState) -> bool:
	return EconSanitation.active(world)


## Unit-cost factor: 1.0 — the split moves posts, it adds no cost (kept for callers).
static func cost_factor(_world: WorldState, _ftype: String) -> float:
	return 1.0


## Share (‰) of a facility type's crew that works at the office: ratio / (1 + ratio).
static func share_pm(ftype: String) -> int:
	var ratio := int(RATIO_PM.get(ftype, 0))
	return ratio * 1000 / (1000 + ratio)


## The organisation's office facility id ("" if it has none).
static func office_of(world: WorldState, oid: String) -> String:
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] == "OFFICE" and f["org"] == oid and not f.get("abandoned", false):
			return fid
	return ""


## Office posts per tier (milli-persons) for an organisation this month: the split share of its plants' crews (A) plus
## building upkeep (E, General). Also stamps each plant's off_share_pm.
static func _office_req(world: WorldState, oid: String, split: bool, upkeep: bool) -> Dictionary:
	var req := {"G": 0, "S": 0, "Sp": 0}
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["org"] != oid or f["type"] == "OFFICE":
			continue
		var sh := share_pm(f["type"]) if split else 0
		f["off_share_pm"] = sh
		if sh > 0:
			var full := EconLabor.required_full(f)
			for tier in full:
				req[tier] = int(req.get(tier, 0)) + int(full[tier]) * sh / 1000
		if upkeep and f["type"] == "HOUSING" and not f["mothball"]:
			var age_y := float(EconHousing.age_months(world, f)) / 12.0
			var up := EconUtil.fscale(f) * float(UPKEEP_PER_BLOCK_PM) / 1000.0 * (1.0 + 0.5 * clampf((age_y - 20.0) / 20.0, 0.0, 1.0))
			req["G"] = int(req["G"]) + int(up * float(S))
	return req


## Target office posts (persons) for an organisation (tests and probes).
static func target_posts(world: WorldState, oid: String) -> int:
	var req := _office_req(world, oid, active(world), upkeep_active(world))
	var n := 0
	for tier in req:
		n += int(req[tier])
	return n / S


## COMPANY_AI, before FirmAI.run (so office posts and the smaller floor crews are advertised this month).
static func monthly(world: WorldState) -> void:
	var split := active(world)
	var upkeep := upkeep_active(world)
	if not split and not upkeep:
		return
	for oid in EconUtil.sorted_keys(world.table("org")):
		var o: Dictionary = world.table("org")[oid]
		var fid := office_of(world, oid)
		if o["status"] in ["LIQUIDATION", "DISSOLVED"] or o.get("key", "") == "PES":
			if fid != "":
				var f0: Dictionary = world.table("facility")[fid]
				f0["office_req"] = {"G": 0, "S": 0, "Sp": 0}
				f0["abandoned"] = true
			for fid2 in world.table("facility"):
				if world.table("facility")[fid2]["org"] == oid:
					world.table("facility")[fid2]["off_share_pm"] = 0  # a dead firm's plants keep their full crews (sale)
			continue
		if o["status"] == "FORMING":
			continue
		var req := _office_req(world, oid, split, upkeep)
		var total := int(req["G"]) + int(req["S"]) + int(req["Sp"])
		if total <= 0 and fid == "":
			continue
		if fid == "":
			var hq: String = o["hq"] if EconData.DISTRICTS.has(o["hq"]) else "d:1"
			fid = EconSetup.add_facility(world, "OFFICE", oid, hq, false)
			world.table("facility")[fid]["book"] = 0
		var f: Dictionary = world.table("facility")[fid]
		f["office_req"] = req
		f["scale"] = 1000
		f["T"] = 1000
		# an office is sized by its plants, never by the recipe: no E49 hoarding, and a firm whose plants are all gone
		# closes its office (diagnosis: such zombie offices paid ~8k a month of wages with no revenue until the firm died)
		f["no_hoard"] = true
		f["mothball"] = total <= 0


## Fill (0..1) of an organisation's office this month: production at its split plants cannot outrun its office —
## otherwise unfilled office posts were a hidden productivity gain (same output with fewer people, more unemployment).
static func office_fill(world: WorldState, oid: String) -> float:
	var fid := office_of(world, oid)
	if fid == "":
		return 1.0
	var f: Dictionary = world.table("facility")[fid]
	var req := 0
	for tier in f.get("office_req", {}):
		req += int(f["office_req"][tier])
	if req <= 0:
		return 1.0
	return clampf(float(EconLabor.staff_total(f["staff"])) / float(maxi(req - S / 2, req / 2)), 0.0, 1.0)


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
		for tier in f.get("office_req", {}):
			wanted += int(f["office_req"][tier])
	return {"offices": n, "posts_held": held, "posts_wanted": wanted / S}

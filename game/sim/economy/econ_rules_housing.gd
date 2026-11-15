class_name EconRulesHousing
extends RefCounted
## R8 step 8, housing (planning/eight-rules.md: "rent rules 1/2 stay as they are (district occupancy); rule 5 =
## developers on occupancy plus rent and profit; rule 6 none"). OPT-IN: R8 + R8_HOUSING (EconRules.sector_on). Otto.
## Without the switch FirmAI._developers runs as before (E120: the most crowded district ≥ 105% gets one block a
## quarter), so base is unchanged.
##
## A developer judges one more 50-home block in a district from what anyone can see this month (never the block's true
## future):
##   rent it would earn a month = 50 × the district's private rent × min(1, households ÷ (homes + homes being built +
##     this block)) × (1 − the share of rent in arrears). (Rent is split among a district's landlords by homes, so a new
##     block takes its share of what the district's households pay.)
##   costs a month = the block's crew and upkeep at today's wages and material price + depreciation + interest on the
##     loan (DEV_EQUITY_PM of the build cost is equity, the rest borrowed at the bank's monthly firm rate).
## Rule 5 (build): forecast profit ≥ HURDLE_PM ‰ a year of the developer's equity. Rents rise in crowded districts
##   (EconHouseholds._housing, 3% a quarter at ≥ 97% full) until building pays, so the rent is the signal.
## Rule 8 (don't): the district would be under OCC_MIN_PM full with the block (homes being built count), or no builder
##   could take the job (EconConstruction.quoted_wait = −1), or the forecast fails rule 5.
## Rule 7 (a new developer): as E120, a housing company is founded from the richest household's savings when no company
##   can put in the equity, but only for a block that passes rule 5.
## Up to MAX_BLOCKS_Q blocks a quarter colony-wide, the most profitable district first, each next block in a district
## judged with the earlier ones counted as being built.

const S := EconUtil.S
const BLOCK_UNITS := 50
const OCC_MIN_PM := 950
const HURDLE_PM := 100  # 10% a year on the developer's equity
const MAX_BLOCKS_Q := 3


static func on(world: WorldState) -> bool:
	return EconRules.sector_on(world, "HOUSING")


static func _stat(world: WorldState, key: String, n: int = 1) -> void:
	var s := EconUtil.st(world)
	var r: Dictionary = s.get("r8h_stats", {})
	r[key] = int(r.get(key, 0)) + n
	s["r8h_stats"] = r


## Homes (S-scaled) in housing projects not yet finished in `d`.
static func pending_units(world: WorldState, d: String) -> int:
	var n := 0
	for pid in world.peek("project"):
		var p: Dictionary = world.peek("project")[pid]
		if p["type"] == "HOUSING" and p["district"] == d and p["status"] in ["TENDER", "TENDERABLE", "ACTIVE"]:
			n += BLOCK_UNITS * S * int(p.get("size_pm", 1000)) / 1000
	return n


## Rule 5/8 forecast for one more block in `d`, with `extra` homes (S-scaled) already planned this round. Pure.
## {rent_m, costs_m, profit_y, equity, occ_after_pm, ok, why}
static func block_forecast(world: WorldState, d: String, extra: int = 0) -> Dictionary:
	var s := EconUtil.peek_st(world)
	var dr: Dictionary = world.peek("district")[d]
	var hh := int(dr.get("households", 0))
	var units := int(dr.get("units", 0)) + pending_units(world, d) + extra + BLOCK_UNITS * S
	var occ_after := int(float(hh) * 1000.0 / float(maxi(1, units)))
	var rent := int(dr.get("rent_private", EconData.PRIVATE_RENT * S))
	var due := float(hh) / float(S) * float(rent)
	var arrears := minf(1.0, float(int(s.get("rent_arrears", {}).get(d, 0))) / maxf(1.0, due))
	var rent_m := int(float(BLOCK_UNITS) * float(rent) * minf(1.0, float(occ_after) / 1000.0) * (1.0 - arrears))
	var r: Dictionary = EconData.RECIPES["HOUSING"]
	var est := EconConstruction.estimate("HOUSING")
	var equity := est * FirmAI.DEV_EQUITY_PM / 1000
	var crew := 0
	for t in r["labor"]:
		crew += int(r["labor"][t]) * int(s.get("wage", {}).get(t, 0))
	var costs_m := crew + int(r["upkeep"]) * int(s.get("prices", {}).get("MATERIAL", 0)) + est / EconData.DEPRECIATION_MONTHS \
		+ int(float(est - equity) * EconData.BANK_FIRM_BASE_PM)
	var profit_y := 12 * (rent_m - costs_m)
	var why := ""
	if occ_after < OCC_MIN_PM:
		why = "empty"
	elif profit_y < equity * HURDLE_PM / 1000:
		why = "profit"
	elif EconConstruction.quoted_wait(world, "HOUSING", d) < 0:
		why = "no_builder"
	return {"rent_m": rent_m, "costs_m": costs_m, "profit_y": profit_y, "equity": equity, "occ_after_pm": occ_after,
		"ok": why == "", "why": why}


## Pure: the forecast for every district (for queries and the A/B).
static func signals(world: WorldState) -> Dictionary:
	var out := {}
	for d in EconUtil.sorted_keys(world.peek("district")):
		out[d] = block_forecast(world, d)
	return out


## Replaces FirmAI._developers' choice under R8_HOUSING (same cadence: called where E120 runs).
static func developers(world: WorldState) -> void:
	var est := EconConstruction.estimate("HOUSING")
	var extra := {}  # d -> homes planned this round
	for i in MAX_BLOCKS_Q:
		var best_d := ""
		var best_p := 0
		for d in EconUtil.sorted_keys(world.table("district")):
			var f := block_forecast(world, d, int(extra.get(d, 0)))
			if not bool(f["ok"]):
				if i == 0 and int(world.table("district")[d].get("households", 0)) > 0:
					_stat(world, "no_" + String(f["why"]))
				continue
			if best_d == "" or int(f["profit_y"]) > best_p:
				best_d = d
				best_p = int(f["profit_y"])
		if best_d == "":
			return
		if not _build(world, best_d, est):
			return
		extra[best_d] = int(extra.get(best_d, 0)) + BLOCK_UNITS * S


## Pure: would the bank lend `amount` now (the same test EconFinance.new_loan makes with move_cash)?
static func _bank_can(world: WorldState, amount: int) -> bool:
	if EconBank.active(world):
		return amount <= EconBank.room(world)
	return world.ledger.balance(EconUtil.BANK) - amount >= EconData.BANK_MIN_CASH * S


static func _build(world: WorldState, d: String, est: int) -> bool:
	var equity := est * FirmAI.DEV_EQUITY_PM / 1000
	if not _bank_can(world, est - equity):  # ask the bank first, so no developer is founded for a block it can't finance
		_stat(world, "no_loan")
		return false
	var owner := ""
	var cash := 0
	for oid in EconUtil.sorted_keys(world.table("org")):
		var o: Dictionary = world.table("org")[oid]
		if o["status"] != "ACTIVE" or o["is_contractor"] or not (o["type"] in ["PRIVATE", "COOPERATIVE"]):
			continue
		var c := world.ledger.balance(EconUtil.acct(oid))
		if c >= equity and c > cash:
			cash = c
			owner = oid
	if owner == "":
		owner = FirmAI._found_developer(world, d, est)  # rule 7: a housing company from household savings
		if owner != "":
			_stat(world, "founded")
	if owner == "":
		_stat(world, "no_developer")
		return false
	if not LawBridge.allowed(world, owner, "BUILD_FACILITY", {"facility_type": "HOUSING", "district": d, "owner_kind": "COMPANY",
			"value_wref": est / maxi(1, int(world.values.get("ECON_W_REF", 1200 * S)))}):
		_stat(world, "no_law")
		return false
	if not EconFinance.new_loan(world, owner, est - equity, 0, true):
		_stat(world, "no_loan")
		return false
	var ids: Array = EconConstruction.create_lots(world, "HOUSING", d, owner, owner, "")
	var occ := int(world.table("district")[d].get("occupancy", 0))
	_stat(world, "blocks")
	EconFacts.emit(world, "COMP_INVESTMENT", d, [["COMPANY", owner]], [["COMPANY", owner, 1.0]], {"HOUSING": 5, "JOBS": 3}, 25, "PUBLIC",
		{"type": "HOUSING", "project": str(ids[0]) if not ids.is_empty() else "", "reason": "rent", "occupancy_pct": occ / 10})
	return true

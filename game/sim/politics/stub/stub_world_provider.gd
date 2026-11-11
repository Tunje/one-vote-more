class_name StubWorldProvider
extends PicProvider
## Synthetic colony for developing politics before the real economy exists (MASTER-PLAN M2).
## Publishes a census and 9 indicators covering all concerns. They respond to stub levers (with their lag)
## and to a scenario curve, so policy and circumstances both matter. Agent 88's economy replaces this in M4.
## Scenario via world.meta["scenario"]: BALANCED | BOOM | RECESSION | INEQUALITY | POLLUTION.

const DISTRICTS := {
	# id: [name, industry_weight, mining_weight, services_weight, pop_scale]
	"d:1": ["Landing", 0.6, 0.1, 1.4, 1.4],
	"d:2": ["Foundry Flats", 1.6, 0.3, 0.7, 1.1],
	"d:3": ["Red Quarry", 0.6, 2.0, 0.5, 0.8],
	"d:4": ["Greenfold", 0.4, 0.2, 0.9, 0.7],
	"d:5": ["Harbor Ridge", 1.0, 0.4, 1.1, 0.9],
	"d:6": ["Outer Reach", 0.5, 1.2, 0.5, 0.5],
}
## Base headcount per occupation in a pop_scale=1 district, and income band split (LOW, MID, HIGH) in percent.
const OCC_BASE := {
	"INDUSTRY": [220, [40, 50, 10]], "MINING": [150, [35, 50, 15]], "SERVICES": [240, [50, 40, 10]],
	"PUBLIC_SECTOR": [120, [20, 60, 20]], "BUSINESS_OWNER": [40, [10, 30, 60]],
	"UNEMPLOYED": [50, [90, 10, 0]], "RETIRED": [60, [50, 40, 10]],
}


func owner_id() -> String:
	return "stub"


func phases() -> Array:
	return [TickPhase.SOCIAL]


func lever_defs() -> Array:
	return [
		_lever("STUB_INCOME_TAX", 0, 50, 20, {"REDISTRIBUTION": 3.0, "FISCAL": 1.0}, {"PUBLIC_SERVICES": 40, "COST_OF_LIVING": -20, "FAIRNESS": 30}),
		_lever("STUB_CORP_TAX", 0, 50, 20, {"ECON_ROLE": 2.0, "REDISTRIBUTION": 2.0}, {"JOBS": -30, "FAIRNESS": 20, "PUBLIC_SERVICES": 20}),
		_lever("STUB_WELFARE", 0, 100, 30, {"REDISTRIBUTION": 1.5, "FISCAL": 1.0}, {"COST_OF_LIVING": 40, "FAIRNESS": 30, "JOBS": -10}),
		_lever("STUB_PUBLIC_INVESTMENT", 0, 100, 30, {"ECON_ROLE": 1.0, "FISCAL": 1.5}, {"JOBS": 30, "INFRASTRUCTURE": 50, "HOUSING": 30}),
		_lever("STUB_ENV_STANDARD", 0, 100, 20, {"ENVIRONMENT": 2.0, "ECON_ROLE": 0.5}, {"ENVIRONMENT_QUALITY": 60, "JOBS": -20, "SAFETY": 10}),
		_lever("STUB_LABOR_PROTECTION", 0, 100, 20, {"LABOR": 2.0}, {"SAFETY": 60, "JOBS": -15, "FAIRNESS": 20}),
		_lever("STUB_DISTRICT_AUTONOMY", 0, 100, 10, {"AUTONOMY": 2.0, "INSTITUTIONS": 0.5}, {"GOVERNANCE": 20, "INFRASTRUCTURE": 10}),
	]


func _lever(id: String, lo: int, hi: int, def: int, ideo: Dictionary, concerns: Dictionary) -> Dictionary:
	return {"id": id, "owner": "stub", "type": "NUMBER", "range": [lo, hi], "default": def, "legalLevel": "LAW",
		"foundingEra": "COMMANDER", "ideology": ideo, "concerns": concerns, "implementation": "STAFF_T_IMPL_FISCAL",
		"lag": 1, "scope": "COLONY", "fiscal": null}


func indicator_defs() -> Array:
	return [
		_ind("STUB_UNEMPLOYMENT", "VOTER_CELL", -1, {"JOBS": 1.0}, 3000, 20000, 1),
		_ind("STUB_PRICE_BURDEN", "VOTER_CELL", -1, {"COST_OF_LIVING": 1.0}, 90000, 140000, 1),
		_ind("STUB_HOUSING_SHORTAGE", "DISTRICT", -1, {"HOUSING": 1.0}, 0, 25000, 0),
		_ind("STUB_SERVICE_ACCESS", "DISTRICT", 1, {"PUBLIC_SERVICES": 1.0}, 90000, 40000, 0),
		_ind("STUB_ACCIDENTS", "VOTER_CELL", -1, {"SAFETY": 1.0}, 2000, 15000, 0),
		_ind("STUB_POLLUTION", "DISTRICT", -1, {"ENVIRONMENT_QUALITY": 1.0}, 10000, 70000, 0),
		_ind("STUB_INFRASTRUCTURE", "DISTRICT", 1, {"INFRASTRUCTURE": 1.0}, 85000, 40000, 0),
		_ind("STUB_INEQUALITY", "COLONY", -1, {"FAIRNESS": 1.0}, 25000, 50000, 3),
		_ind("STUB_GOV_EFFECTIVENESS", "COLONY", 1, {"GOVERNANCE": 1.0}, 80000, 30000, 0),
	]


func _ind(id: String, gran: String, pol: int, concerns: Dictionary, good: int, bad: int, lag: int) -> Dictionary:
	return {"id": id, "owner": "stub", "unit": "milli", "range": [0, 200000], "granularity": gran, "polarity": pol,
		"concerns": concerns, "normalize": {"good": good, "bad": bad}, "phase": TickPhase.SOCIAL,
		"visibility": "PUBLIC", "perceptionLag": lag}


func init_world(world: WorldState) -> void:
	world.ledger.open_account("treasury")
	world.ledger.transfer(Ledger.EXTERNAL, "treasury", 5_000_000 * Ledger.SCALE, "founding funds", 0)


## Scenario curve: extra pressure (0..1) on a concern at a given month.
func _scn(world: WorldState, kind: String) -> float:
	var s: String = world.meta.get("scenario", "BALANCED")
	var m := float(world.month)
	match [s, kind]:
		["BOOM", "growth"]: return 1.0
		["BOOM", "prices"]: return 0.6
		["RECESSION", "jobs"]: return clampf((m - 20.0) / 30.0, 0.0, 1.0) * (1.0 if m < 150.0 else 0.4)
		["INEQUALITY", "inequality"]: return clampf(m / 60.0, 0.0, 1.0)
		["INEQUALITY", "prices"]: return 0.5
		["POLLUTION", "pollution"]: return clampf(m / 40.0, 0.0, 1.0)
	return 0.0


func run_phase(_phase: int, world: WorldState) -> void:
	var L := world.levers
	var rng := world.rng.stream("stub.world")
	var growth := 1.0 + float(world.month) * (0.0012 + 0.0015 * _scn(world, "growth"))
	var census := world.table("census")
	var inv := float(L["STUB_PUBLIC_INVESTMENT"])
	var env := float(L["STUB_ENV_STANDARD"])
	var lab := float(L["STUB_LABOR_PROTECTION"])
	var ctax := float(L["STUB_CORP_TAX"])
	var itax := float(L["STUB_INCOME_TAX"])
	var wel := float(L["STUB_WELFARE"])
	var aut := float(L["STUB_DISTRICT_AUTONOMY"])
	var base_unemp := 6.0 + 10.0 * _scn(world, "jobs") - 2.5 * _scn(world, "growth") + 0.12 * ctax - 0.06 * inv + 0.05 * env + 0.04 * lab
	var price := 100.0 + 18.0 * _scn(world, "prices") - 0.15 * wel + 0.2 * itax
	for did in DISTRICTS:
		var dv: Array = DISTRICTS[did]
		var pollution: float = 15.0 + 25.0 * dv[1] + 15.0 * dv[2] + 30.0 * _scn(world, "pollution") * (dv[1] + dv[2]) - 0.45 * env
		world.set_indicator("stub", "STUB_POLLUTION", did, _m(pollution + rng.randf_range(-1.0, 1.0)))
		world.set_indicator("stub", "STUB_HOUSING_SHORTAGE", did, _m(16.0 + 8.0 * _scn(world, "growth") - 0.18 * inv))
		world.set_indicator("stub", "STUB_SERVICE_ACCESS", did, _m(38.0 + 1.1 * itax + 0.15 * wel - 6.0 * (growth - 1.0) + 4.0 * (dv[3] - 1.0)))
		world.set_indicator("stub", "STUB_INFRASTRUCTURE", did, _m(42.0 + 0.5 * inv + 0.12 * aut - (8.0 if dv[4] < 0.8 else 0.0)))
		for occ in OCC_BASE:
			var spec: Array = OCC_BASE[occ]
			var w := 1.0
			if occ == "INDUSTRY": w = dv[1]
			elif occ == "MINING": w = dv[2]
			elif occ == "SERVICES": w = dv[3]
			for bi in PolDefs.BANDS.size():
				var band: String = PolDefs.BANDS[bi]
				var pop := int(round(float(spec[0]) * w * dv[4] * growth * float(spec[1][bi]) / 100.0))
				if pop <= 0:
					continue
				var key := PolDefs.cell_key(did, occ, band)
				census[key] = pop
				var u := base_unemp * (2.5 if occ == "UNEMPLOYED" else (0.4 if occ in ["PUBLIC_SECTOR", "RETIRED"] else 1.0))
				if occ == "MINING": u *= 1.0 + 0.4 * _scn(world, "jobs")
				world.set_indicator("stub", "STUB_UNEMPLOYMENT", key, _m(u + rng.randf_range(-0.5, 0.5)))
				var bf: float = [1.15, 1.0, 0.8][bi]
				world.set_indicator("stub", "STUB_PRICE_BURDEN", key, _m(price * bf))
				var acc := ({"MINING": 14.0, "INDUSTRY": 9.0}.get(occ, 2.5) as float) * (1.0 - lab / 140.0)
				world.set_indicator("stub", "STUB_ACCIDENTS", key, _m(acc))
	world.set_indicator("stub", "STUB_INEQUALITY", "COLONY", _m(34.0 + 12.0 * _scn(world, "inequality") - 0.15 * ctax - 0.12 * itax - 0.06 * wel))
	world.set_indicator("stub", "STUB_GOV_EFFECTIVENESS", "COLONY", _m(55.0 + 0.1 * aut + rng.randf_range(-3.0, 3.0)))


func _m(v: float) -> int:
	return int(round(maxf(0.0, v) * 1000.0))

class_name EconReport
extends RefCounted
## Text summaries and the M4 soak verdict (conservation, bounded prices, fed population, solvency).

const S := EconUtil.S


static func header() -> String:
	return "  yr   pop  unemp%  cpi  food  mat  cons  wageG  treas(M)  debt(M)  orgs A/D/X  foodShort‰  crowd  built  W_ref"


static func year_line(world: WorldState) -> String:
	var s := EconUtil.st(world)
	var pop := 0
	var lf := 0
	var emp := 0
	for gid in world.peek("hh"):
		var g: Dictionary = world.peek("hh")[gid]
		pop += EconHouseholds.persons(g)
		lf += g["lf"]
		emp += EconLabor.employed(g)
	var a := 0
	var d := 0
	var x := 0
	for oid in world.peek("org"):
		var st: String = world.peek("org")[oid]["status"]
		if st in ["ACTIVE", "FORMING"]: a += 1
		elif st in ["DISSOLVED", "LIQUIDATION"]: x += 1
		else: d += 1
	var units := 0
	for fid in world.peek("facility"):
		if world.peek("facility")[fid]["type"] == "HOUSING":
			units += 50
	var built := 0
	for pid in world.peek("project"):
		if world.peek("project")[pid]["status"] == "DONE":
			built += 1
	return "  %2d %5d  %5.1f  %4.0f  %4.0f %4.0f  %4.0f  %5.0f  %8.2f  %7.2f   %2d/%d/%d     %4d     %4.2f  %4d  %5.0f" % [
		world.year() - 1, pop / S, 100.0 * (1.0 - float(emp) / maxf(1.0, float(lf))), float(s["cpi"]) / S,
		float(s["prices"]["FOOD"]) / S, float(s["prices"]["MATERIAL"]) / S, float(s["prices"]["CONSUMER"]) / S,
		float(s["wage"]["G"]) / S, float(world.ledger.balance(EconUtil.TREASURY)) / S / 1e6,
		float(EconFinance.debt_of(world, "gov")) / S / 1e6, a, d, x, s.get("food_shortfall", 0),
		float(pop) / S / EconData.HOUSEHOLD_SIZE / maxf(1.0, float(units)), built, float(world.values.get("ECON_W_REF", 0)) / S]


## Goods conservation: Σ stock == initial + made + imported − burned, per good.
static func goods_errors(world: WorldState) -> Array:
	var errs: Array = []
	var f: Dictionary = EconUtil.st(world)["qflow"]
	for good in EconData.MARKET_GOODS:
		var q: Dictionary = f.get(good, {"initial": 0, "made": 0, "imported": 0, "burned": 0})
		var expect: int = q["initial"] + q["made"] + q["imported"] - q["burned"]
		var actual := EconUtil.inv_sum(world, good)
		if absi(expect - actual) > 0:
			errs.append("%s stock %d != flows %d" % [good, actual, expect])
	return errs


static func verdict(world: WorldState) -> Dictionary:
	var s := EconUtil.st(world)
	var problems: Array = []
	if world.ledger.total() != 0 or world.meta.has("violations"):
		problems.append("money not conserved: %s" % [world.meta.get("violations", world.ledger.total())])
	problems.append_array(goods_errors(world))
	for good in EconData.BASE_PRICE:
		var r := float(s["prices"][good]) / float(s["base"][good])
		if r < 0.4 or r > 3.0:
			problems.append("%s price %.2fx base" % [good, r])
	if s["famine"]:
		problems.append("famine occurred")
	if s.get("food_shortfall", 0) > 50:
		problems.append("food shortfall %d‰ at end" % s["food_shortfall"])
	if s["sovereign_default"]:
		problems.append("sovereign default")
	var lf := 0
	var emp := 0
	var pop := 0
	for gid in world.peek("hh"):
		var g: Dictionary = world.peek("hh")[gid]
		lf += g["lf"]
		emp += EconLabor.employed(g)
		pop += EconHouseholds.persons(g)
	var u := 1.0 - float(emp) / maxf(1.0, float(lf))
	if u < 0.01 or u > 0.25:
		problems.append("unemployment %.1f%% outside 1–25%%" % (100.0 * u))
	if pop < 1500 * S:
		problems.append("population collapsed to %d" % (pop / S))
	return {"ok": problems.is_empty(), "text": "  verdict: " + ("OK" if problems.is_empty() else "; ".join(problems))}

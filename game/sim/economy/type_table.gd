extends RefCounted
## THE TYPE TABLE (rebuild plan section 4; planning/rebuild-type-table.md). "it's just a 2d array of wich items a
## company type makes, if they pick from first or second output". One row per company type; each output its own line
## of inputs, labour and quantity, for ONE full-size (large) unit per month. Every number is new and set in testing.
## Preload it: const TypeTable := preload("res://sim/economy/type_table.gd"). Pure: nothing here reads or writes a world.
##
## Units: money in milli-credits (CoreUtil.S = 1000 per credit); quantities in the table in whole units, and every
## function that returns a quantity for a size returns milli-units (whole units × 1000), so a family farm's 47 FOOD is
## 47000 and a family share of a truck is not lost to rounding.

const S := 1000

## The four sizes (plan section 5): share of the full row in sixths, and the output penalty in per mille.
const SIZES: Array[String] = ["FAMILY", "SMALL", "AVERAGE", "LARGE"]
const SIXTHS := {"FAMILY": 1, "SMALL": 2, "AVERAGE": 4, "LARGE": 6}
const PENALTY_PM := {"FAMILY": 60, "SMALL": 40, "AVERAGE": 20, "LARGE": 0}

## Skill tiers, highest first, and the starting salary of each. The anchor of every starting price is the general
## salary (rebuild-type-table.md section 1); S is 1.5 and Sp 2.25 times it.
const TIERS: Array[String] = ["Sp", "S", "G"]
const SALARY_G := 300
const TIER_PM := {"G": 1000, "S": 1500, "Sp": 2250}

## The pricing rule's numbers (section 1): the build bill and its land are spread over this many years of full output.
const PAYBACK_Y := 10.0
const PAYBACK_HOMES_Y := 13.5     # homes and office places: the middle of the user's "12 to 15 years" (9.8)
## A home's starting rent is this many per mille of what the solve works out (rebuild-company.md 9.2, "The rent is
## doubled", the user, 2026-11-18: "Screw lowering food, double the rent. Make the rent more reasonable in comparison
## to food."). Homes only (LANDLORD's "@home"); no other price reads it, so nothing else in the table moves.
const HOME_RENT_PM := 2000
const LAND_PM := 100              # land = 10% of the bill (stand-in until Terra's land price)
## Otto's upkeep column (rebuild-building.md 3): 1/400 of the MATERIAL bill a month, and 2% of the BW a year as a job.
const UPKEEP_MAT_DIV := 400
const UPKEEP_BW_PM_Y := 20

## The items (section 2). unit, freight mass per unit (0 = not carried by truck), spoiling per mille a month, and
## whether it only travels on the grid (cannot be stocked, 12.7).
const ITEMS := {
	"FOOD": {"unit": "one person's basic food for a month", "mass": 1, "spoil_pm": 10, "grid": false},
	"BREAD": {"unit": "one person's food for a month, baked", "mass": 1, "spoil_pm": 250, "grid": false},
	"FINE_FOOD": {"unit": "one portion-month", "mass": 1, "spoil_pm": 100, "grid": false},
	"MINERAL": {"unit": "one tonne of ore", "mass": 2, "spoil_pm": 0, "grid": false},
	"MATERIAL": {"unit": "one tonne of building material", "mass": 2, "spoil_pm": 0, "grid": false},
	"COMPONENT": {"unit": "one crate of machined parts", "mass": 1, "spoil_pm": 0, "grid": false},
	"TRUCK": {"unit": "one truck", "mass": 0, "spoil_pm": 0, "grid": false},
	"CONSUMER": {"unit": "one household good", "mass": 1, "spoil_pm": 0, "grid": false},
	"CLOTHING": {"unit": "one garment-set", "mass": 1, "spoil_pm": 0, "grid": false},
	"FURNISHINGS": {"unit": "one piece", "mass": 2, "spoil_pm": 0, "grid": false},
	"MEDICAL": {"unit": "one treatment kit", "mass": 1, "spoil_pm": 5, "grid": false},
	"ENERGY": {"unit": "one unit on the grid", "mass": 0, "spoil_pm": 0, "grid": true},
	"WATER": {"unit": "one unit on the grid", "mass": 0, "spoil_pm": 0, "grid": true},
}

## What a company sells that is not an item: building work, freight, and the client places of services.
## A line's "out" is an item name, or one of these with "@" in front: "@BW", "@FREIGHT" (unit-km), or a client kind.

## The rows. Each: lines (first, then second output), way, setting (TOWN or COUNTRY, Terra's siting), occupation,
## outdoor, pollution (units a month), noise (0..5), accidents (per 1000 workers a year), hazard, bill
## [BW, MATERIAL, COMPONENT, fewest months] for one full unit (agreed with Otto), freight room (per truck, a load).
## way: sells (ITEM | BW | FREIGHT | CLIENTS | HOMES | PLACES | LOANS), reads (UNSOLD | EMPTY_SLOTS: what rules 2 and 4
## read), price (ITEM | PER_BW | PER_ROUTE | PER_CLIENT | RENT | RATE), reach (ROAD | GRID | CLIENTS_COME | IN_REACH).
const _ITEM_WAY := {"sells": "ITEM", "reads": "UNSOLD", "price": "ITEM", "reach": "ROAD"}
const _GRID_WAY := {"sells": "ITEM", "reads": "UNSOLD", "price": "ITEM", "reach": "GRID"}
const _SVC_WAY := {"sells": "CLIENTS", "reads": "EMPTY_SLOTS", "price": "PER_CLIENT", "reach": "CLIENTS_COME"}

const ROWS := {
	# one farm worker feeds ten people (rebuild-company.md 9.2, the user, 2026-11-18: "10 purple each"): 24 posts, 240 FOOD
	"FARM": {"lines": [{"out": "FOOD", "qty": 240, "in": {}, "lab": {"G": 18, "S": 5, "Sp": 1}}],
		"way": _ITEM_WAY, "setting": "COUNTRY", "occ": "AGRICULTURE", "outdoor": true,
		"pollution": 10, "noise": 1, "accidents": 8, "hazard": false, "bill": [240, 240, 12, 4]},
	"BAKERY": {"lines": [
			{"out": "BREAD", "qty": 1500, "in": {"FOOD": 1300, "ENERGY": 3000, "WATER": 1500}, "lab": {"G": 12, "S": 5, "Sp": 1}},
			{"out": "FINE_FOOD", "qty": 400, "in": {"FOOD": 700, "ENERGY": 3000, "WATER": 1000}, "lab": {"G": 10, "S": 6, "Sp": 2}}],
		"way": _ITEM_WAY, "setting": "TOWN", "occ": "FOOD_TRADES", "outdoor": false,
		"pollution": 5, "noise": 1, "accidents": 4, "hazard": false, "bill": [300, 240, 24, 4]},
	"MINE": {"lines": [{"out": "MINERAL", "qty": 2000, "in": {"ENERGY": 8000, "WATER": 2000}, "lab": {"G": 20, "S": 8, "Sp": 2}}],
		"way": _ITEM_WAY, "setting": "COUNTRY", "occ": "MINING", "outdoor": true,
		"pollution": 40, "noise": 5, "accidents": 25, "hazard": true, "bill": [600, 480, 72, 6]},
	"PROCESSING": {"lines": [{"out": "MATERIAL", "qty": 800, "in": {"MINERAL": 1600, "ENERGY": 12000, "WATER": 4000}, "lab": {"G": 18, "S": 10, "Sp": 2}}],
		"way": _ITEM_WAY, "setting": "COUNTRY", "occ": "INDUSTRY", "outdoor": false,
		"pollution": 60, "noise": 4, "accidents": 15, "hazard": true, "bill": [720, 600, 96, 8]},
	"COMPONENTS": {"lines": [
			{"out": "COMPONENT", "qty": 200, "in": {"MATERIAL": 250, "ENERGY": 8000}, "lab": {"G": 10, "S": 14, "Sp": 6}},
			{"out": "TRUCK", "qty": 4, "in": {"MATERIAL": 60, "COMPONENT": 40, "ENERGY": 6000}, "lab": {"G": 10, "S": 14, "Sp": 6}}],
		"way": _ITEM_WAY, "setting": "COUNTRY", "occ": "INDUSTRY", "outdoor": false,
		"pollution": 25, "noise": 3, "accidents": 8, "hazard": false, "bill": [720, 600, 120, 8]},
	"CONSUMERF": {"lines": [{"out": "CONSUMER", "qty": 1200, "in": {"MATERIAL": 150, "COMPONENT": 20, "ENERGY": 6000}, "lab": {"G": 16, "S": 10, "Sp": 2}}],
		"way": _ITEM_WAY, "setting": "COUNTRY", "occ": "INDUSTRY", "outdoor": false,
		"pollution": 15, "noise": 3, "accidents": 6, "hazard": false, "bill": [480, 480, 60, 6]},
	"TEXTILE": {"lines": [{"out": "CLOTHING", "qty": 1000, "in": {"FOOD": 100, "MATERIAL": 40, "ENERGY": 4000, "WATER": 2000}, "lab": {"G": 18, "S": 6, "Sp": 1}}],
		"way": _ITEM_WAY, "setting": "COUNTRY", "occ": "INDUSTRY", "outdoor": false,
		"pollution": 20, "noise": 2, "accidents": 5, "hazard": false, "bill": [420, 360, 48, 5]},
	"FURNITURE": {"lines": [{"out": "FURNISHINGS", "qty": 300, "in": {"MATERIAL": 200, "COMPONENT": 5, "ENERGY": 3000}, "lab": {"G": 14, "S": 8, "Sp": 1}}],
		"way": _ITEM_WAY, "setting": "COUNTRY", "occ": "CRAFTS", "outdoor": false,
		"pollution": 10, "noise": 3, "accidents": 6, "hazard": false, "bill": [420, 360, 48, 5]},
	"MEDWORKS": {"lines": [{"out": "MEDICAL", "qty": 600, "in": {"MATERIAL": 30, "COMPONENT": 10, "ENERGY": 5000, "WATER": 3000}, "lab": {"G": 6, "S": 10, "Sp": 6}}],
		"way": _ITEM_WAY, "setting": "COUNTRY", "occ": "INDUSTRY", "outdoor": false,
		"pollution": 10, "noise": 1, "accidents": 4, "hazard": true, "bill": [480, 360, 96, 6]},
	"POWER": {"lines": [{"out": "ENERGY", "qty": 120000, "in": {"MINERAL": 1200, "WATER": 5000}, "lab": {"G": 8, "S": 8, "Sp": 4}}],
		"way": _GRID_WAY, "setting": "COUNTRY", "occ": "UTILITIES", "outdoor": false,
		"pollution": 80, "noise": 4, "accidents": 10, "hazard": true, "bill": [840, 840, 180, 8]},
	"WATERWORKS": {"lines": [{"out": "WATER", "qty": 120000, "in": {"ENERGY": 15000, "MATERIAL": 10}, "lab": {"G": 6, "S": 5, "Sp": 2}}],
		"way": _GRID_WAY, "setting": "COUNTRY", "occ": "UTILITIES", "outdoor": false,
		"pollution": 3, "noise": 2, "accidents": 5, "hazard": false, "bill": [540, 540, 72, 6]},
	"BUILDER": {"lines": [{"out": "@BW", "qty": 60, "in": {}, "lab": {"G": 36, "S": 18, "Sp": 6}}],
		"way": {"sells": "BW", "reads": "EMPTY_SLOTS", "price": "PER_BW", "reach": "ROAD"}, "setting": "COUNTRY",
		"occ": "CONSTRUCTION", "outdoor": true, "pollution": 5, "noise": 3, "accidents": 20, "hazard": false,
		"bill": [120, 120, 6, 2]},
	"HAULIER": {"lines": [{"out": "@FREIGHT", "qty": 36000, "in": {"ENERGY": 12000}, "lab": {"G": 2, "S": 6, "Sp": 0}}],
		"way": {"sells": "FREIGHT", "reads": "EMPTY_SLOTS", "price": "PER_ROUTE", "reach": "ROAD"}, "setting": "COUNTRY",
		"occ": "TRANSPORT", "outdoor": true, "pollution": 10, "noise": 3, "accidents": 15, "hazard": false,
		"bill": [300, 240, 48, 4], "freight_room": 20, "trucks": 6},
	"TRUCKSHOP": {"lines": [
			{"out": "@truck repair", "qty": 12, "in": {"COMPONENT": 6, "ENERGY": 2000}, "lab": {"G": 2, "S": 5, "Sp": 1}},
			{"out": "TRUCK", "qty": 1, "in": {"MATERIAL": 15, "COMPONENT": 10, "ENERGY": 2000}, "lab": {"G": 2, "S": 5, "Sp": 1}}],
		"way": _SVC_WAY, "setting": "TOWN", "occ": "TRANSPORT_TRADES", "outdoor": false,
		"pollution": 5, "noise": 3, "accidents": 6, "hazard": false, "bill": [240, 180, 24, 3]},
	"LANDLORD": {"lines": [{"out": "@home", "qty": 50, "in": {}, "lab": {"G": 2, "S": 0, "Sp": 0}}],
		"way": {"sells": "HOMES", "reads": "EMPTY_SLOTS", "price": "RENT", "reach": "CLIENTS_COME"}, "setting": "TOWN",
		"occ": "PROPERTY", "outdoor": false, "pollution": 0, "noise": 0, "accidents": 1, "hazard": false,
		"bill": [1200, 720, 24, 6]},
	"OFFICEBLOCK": {"lines": [{"out": "@office place", "qty": 10, "in": {"ENERGY": 4000, "WATER": 1000}, "lab": {"G": 2, "S": 0, "Sp": 0}}],
		"way": {"sells": "PLACES", "reads": "EMPTY_SLOTS", "price": "RENT", "reach": "CLIENTS_COME"}, "setting": "TOWN",
		"occ": "PROPERTY", "outdoor": false, "pollution": 1, "noise": 1, "accidents": 1, "hazard": false,
		"bill": [300, 300, 15, 4]},
	"BANK": {"lines": [{"out": "@loan", "qty": 60, "in": {"ENERGY": 1000}, "lab": {"G": 2, "S": 6, "Sp": 4}}],
		"way": {"sells": "LOANS", "reads": "EMPTY_SLOTS", "price": "RATE", "reach": "CLIENTS_COME"}, "setting": "TOWN",
		"occ": "FINANCE", "outdoor": false, "pollution": 1, "noise": 1, "accidents": 1, "hazard": false,
		"bill": [240, 240, 12, 3]},
	"SHOP": {"lines": [{"out": "@household", "qty": 400, "in": {"ENERGY": 3000}, "lab": {"G": 8, "S": 2, "Sp": 0}}],
		"way": {"sells": "ITEM", "reads": "UNSOLD", "price": "ITEM", "reach": "IN_REACH"}, "setting": "TOWN",
		"occ": "RETAIL", "outdoor": false, "pollution": 2, "noise": 1, "accidents": 2, "hazard": false,
		"bill": [240, 240, 12, 3]},
	"CAFE": {"lines": [{"out": "@visit", "qty": 1500, "in": {"FOOD": 150, "FINE_FOOD": 60, "ENERGY": 3000, "WATER": 2000}, "lab": {"G": 8, "S": 2, "Sp": 0}}],
		"way": _SVC_WAY, "setting": "TOWN", "occ": "HOSPITALITY", "outdoor": false,
		"pollution": 2, "noise": 2, "accidents": 2, "hazard": false, "bill": [240, 240, 12, 3]},
	"SERVICEHUB": {"lines": [{"out": "@household", "qty": 300, "in": {"ENERGY": 2000, "WATER": 1000}, "lab": {"G": 6, "S": 4, "Sp": 0}}],
		"way": _SVC_WAY, "setting": "TOWN", "occ": "PERSONAL_SERVICES", "outdoor": false,
		"pollution": 2, "noise": 1, "accidents": 2, "hazard": false, "bill": [240, 240, 12, 3]},
	"CHILDCARE": {"lines": [{"out": "@child", "qty": 120, "in": {"FOOD": 60, "ENERGY": 2000, "WATER": 1000}, "lab": {"G": 4, "S": 10, "Sp": 1}}],
		"way": _SVC_WAY, "setting": "TOWN", "occ": "CARE", "outdoor": false,
		"pollution": 1, "noise": 2, "accidents": 2, "hazard": false, "bill": [240, 240, 12, 3]},
	"ELDERCARE": {"lines": [{"out": "@resident", "qty": 80, "in": {"FOOD": 80, "MEDICAL": 20, "ENERGY": 3000, "WATER": 2000}, "lab": {"G": 8, "S": 10, "Sp": 2}}],
		"way": _SVC_WAY, "setting": "TOWN", "occ": "CARE", "outdoor": false,
		"pollution": 1, "noise": 1, "accidents": 3, "hazard": false, "bill": [240, 240, 12, 3]},
	"CLINIC": {"lines": [{"out": "@person", "qty": 2000, "in": {"MEDICAL": 80, "ENERGY": 4000, "WATER": 2000}, "lab": {"G": 4, "S": 10, "Sp": 6}}],
		"way": _SVC_WAY, "setting": "TOWN", "occ": "HEALTH", "outdoor": false,
		"pollution": 3, "noise": 1, "accidents": 3, "hazard": false, "bill": [480, 420, 36, 6], "reach_m": 2000},
	"SCHOOL": {"lines": [{"out": "@pupil", "qty": 300, "in": {"MATERIAL": 5, "ENERGY": 3000, "WATER": 1000}, "lab": {"G": 2, "S": 12, "Sp": 4}}],
		"way": _SVC_WAY, "setting": "TOWN", "occ": "EDUCATION", "outdoor": false,
		"pollution": 1, "noise": 2, "accidents": 2, "hazard": false, "bill": [480, 480, 18, 6], "reach_m": 1500},
	"POLICE": {"lines": [{"out": "@resident", "qty": 2500, "in": {"ENERGY": 2000}, "lab": {"G": 4, "S": 10, "Sp": 1}}],
		"way": _SVC_WAY, "setting": "TOWN", "occ": "PUBLIC_ORDER", "outdoor": true,
		"pollution": 2, "noise": 1, "accidents": 6, "hazard": false, "bill": [360, 360, 24, 4]},
	"PRISON": {"lines": [{"out": "@prisoner", "qty": 50, "in": {"FOOD": 50, "ENERGY": 3000, "WATER": 2000}, "lab": {"G": 4, "S": 10, "Sp": 1}}],
		"way": _SVC_WAY, "setting": "COUNTRY", "occ": "PUBLIC_ORDER", "outdoor": false,
		"pollution": 3, "noise": 1, "accidents": 5, "hazard": false, "bill": [600, 720, 36, 6]},
	"ADMIN": {"lines": [{"out": "@resident", "qty": 3000, "in": {"ENERGY": 2000}, "lab": {"G": 4, "S": 8, "Sp": 3}}],
		"way": _SVC_WAY, "setting": "TOWN", "occ": "PUBLIC_ADMINISTRATION", "outdoor": false,
		"pollution": 1, "noise": 1, "accidents": 2, "hazard": false, "bill": [360, 360, 12, 4]},
	"TRANSIT": {"lines": [{"out": "@rider", "qty": 1000, "in": {"ENERGY": 20000}, "lab": {"G": 2, "S": 10, "Sp": 0}}],
		"way": _SVC_WAY, "setting": "COUNTRY", "occ": "TRANSPORT", "outdoor": true,
		"pollution": 8, "noise": 2, "accidents": 6, "hazard": false, "bill": [300, 240, 48, 4]},
	"SANITATION": {"lines": [{"out": "@home", "qty": 1500, "in": {"ENERGY": 4000, "WATER": 6000}, "lab": {"G": 10, "S": 2, "Sp": 0}}],
		"way": _SVC_WAY, "setting": "COUNTRY", "occ": "SANITATION", "outdoor": true,
		"pollution": 15, "noise": 2, "accidents": 6, "hazard": false, "bill": [240, 240, 12, 3]},
	"NEWSPAPER": {"lines": [{"out": "@reader", "qty": 2000, "in": {"MATERIAL": 4, "ENERGY": 2000}, "lab": {"G": 3, "S": 6, "Sp": 3}}],
		"way": _SVC_WAY, "setting": "TOWN", "occ": "MEDIA", "outdoor": false,
		"pollution": 1, "noise": 1, "accidents": 2, "hazard": false, "bill": [180, 180, 12, 3]},
}

## The bank's price is the interest rate (12.8, 50): per mille a month at the start.
const BANK_RATE_PM := 5


# ---------------------------------------------------------------- reading the rows

static func types() -> Array:
	var k := ROWS.keys()
	k.sort()
	return k


static func has_type(type: String) -> bool:
	return ROWS.has(type)


static func row(type: String) -> Dictionary:
	return ROWS[type]


static func line_count(type: String) -> int:
	return (ROWS[type]["lines"] as Array).size()


static func line(type: String, idx: int = 0) -> Dictionary:
	return ROWS[type]["lines"][idx]


## What a line sells: an item name, or a non-item with "@" in front ("@BW", "@FREIGHT", "@pupil", ...).
static func out_of(type: String, idx: int = 0) -> String:
	return String(line(type, idx)["out"])


static func is_item(name: String) -> bool:
	return ITEMS.has(name)


## How much of an item spoils in a month, per mille of what is held (0 for goods that keep).
static func spoil_pm(item: String) -> int:
	return int(ITEMS.get(item, {}).get("spoil_pm", 0))


static func way(type: String) -> Dictionary:
	return ROWS[type]["way"]


static func setting(type: String) -> String:
	return String(ROWS[type]["setting"])


static func occupation(type: String, _idx: int = 0) -> Dictionary:
	return {"occ": String(ROWS[type]["occ"]), "outdoor": bool(ROWS[type]["outdoor"])}


static func sixths(size: String) -> int:
	return int(SIXTHS[size])


static func penalty_pm(size: String) -> int:
	return int(PENALTY_PM[size])


static func is_size(size: String) -> bool:
	return SIXTHS.has(size)


## Posts in whole persons for a plant of this size: the row's labour × the size's share, split over the tiers by
## largest remainder so the total is the rounded share of the row's total.
static func posts(type: String, size: String, idx: int = 0) -> Dictionary:
	var lab: Dictionary = line(type, idx)["lab"]
	var tiers := ["G", "S", "Sp"]
	var weights: Array = []
	var total := 0
	for t in tiers:
		weights.append(float(int(lab.get(t, 0))))
		total += int(lab.get(t, 0))
	var n := int(round(float(total) * sixths(size) / 6.0))
	var parts := CoreUtil.split_lr(n, weights)
	return {"G": int(parts[0]), "S": int(parts[1]), "Sp": int(parts[2])}


## Output a month at full use, in milli-units: the row's quantity × share × (1 − penalty).
static func output_milli(type: String, size: String, idx: int = 0) -> int:
	var q := int(line(type, idx)["qty"])
	return q * S * sixths(size) * (1000 - penalty_pm(size)) / (6 * 1000)


## Inputs a month at full use, in milli-units: the row's inputs × share (the penalty is on output, not inputs).
static func inputs_milli(type: String, size: String, idx: int = 0) -> Dictionary:
	var out := {}
	var inp: Dictionary = line(type, idx)["in"]
	for k in inp:
		out[k] = int(inp[k]) * S * sixths(size) / 6
	return out


## The build bill for this size (Otto, rebuild-building.md 3): BW, MATERIAL and COMPONENT in milli-units by the
## size's share; the fewest months = max(2, ceil(full months × (1 + share) / 2)), the full months for LARGE.
static func bill(type: String, size: String) -> Dictionary:
	var b: Array = ROWS[type]["bill"]
	var six := sixths(size)
	var months := int(b[3]) if six == 6 else maxi(2, ceili(float(int(b[3])) * float(6 + six) / 12.0))
	return {"bw": int(b[0]) * S * six / 6, "material": int(b[1]) * S * six / 6, "component": int(b[2]) * S * six / 6, "months": months}


## Upkeep a month, in milli-units: MATERIAL (1/400 of the bill's) and BW (2% of the bill's a year, as a builder's job).
static func upkeep_milli(type: String, size: String) -> Dictionary:
	var b := bill(type, size)
	return {"material": int(b["material"]) / UPKEEP_MAT_DIV, "bw": int(b["bw"]) * UPKEEP_BW_PM_Y / (1000 * 12)}


## Clients a month at full use for a line that sells client places, or 0.
static func clients(type: String, size: String, idx: int = 0) -> int:
	if is_item(out_of(type, idx)):
		return 0
	return output_milli(type, size, idx) / S


# ---------------------------------------------------------------- prices

static func salary(tier: String) -> int:
	return SALARY_G * S * int(TIER_PM[tier]) / 1000


## The making price of a line (plan 12.3, 14), in milli-credits per unit: a month's cost of making at full use
## (wages at `wages` per tier, inputs at `prices`, upkeep, and `other_costs` a month: rent, freight, interest) divided
## by the output at full use. prices: {item or "BW": milli-credits per unit}; wages: {tier: milli-credits a month}.
static func making_price(type: String, size: String, idx: int, prices: Dictionary, wages: Dictionary, other_costs: int = 0) -> int:
	var out := output_milli(type, size, idx)
	if out <= 0:
		return 0
	var cost := other_costs
	var p := posts(type, size, idx)
	for t in p:
		cost += int(p[t]) * int(wages[t])
	var inp := inputs_milli(type, size, idx)
	for k in inp:
		cost += int(inp[k]) * int(prices.get(k, 0)) / S
	var u := upkeep_milli(type, size)
	cost += int(u["material"]) * int(prices.get("MATERIAL", 0)) / S + int(u["bw"]) * int(prices.get("BW", 0)) / S
	return cost * S / out


static var _start := {}


## The starting prices (rebuild-type-table.md section 1): making price at full output, plus the bill and its land
## spread over PAYBACK_Y years (PAYBACK_HOMES_Y for homes and office places), solved together since every price is
## in every other. Returns {item: milli-credits}, plus "BW", "FREIGHT" (per unit-km), and per type "@<TYPE>" (a client
## place a month; for LANDLORD a home's rent, for OFFICEBLOCK a place's rent). Pure in the table, so it is kept.
static func start_prices() -> Dictionary:
	if not _start.is_empty():
		return _start
	var p := {}
	for it in ITEMS:
		p[it] = 1.0
	p["BW"] = 1.0
	p["@FREIGHT"] = 1.0
	var w := {}
	for t in TIER_PM:
		w[t] = float(SALARY_G * int(TIER_PM[t])) / 1000.0
	var svc := {}
	for _i in 300:
		var seen := {}
		for type in ROWS:
			var b: Array = ROWS[type]["bill"]
			var bill_cr: float = float(b[0]) * p["BW"] + float(b[1]) * p["MATERIAL"] + float(b[2]) * p["COMPONENT"]
			var upkeep: float = float(b[1]) / UPKEEP_MAT_DIV * p["MATERIAL"] + float(b[0]) * UPKEEP_BW_PM_Y / 1000.0 / 12.0 * p["BW"]
			var years := PAYBACK_HOMES_Y if type in ["LANDLORD", "OFFICEBLOCK"] else PAYBACK_Y
			var capital := bill_cr * (1000 + LAND_PM) / 1000.0 / (years * 12.0)
			for ln in ROWS[type]["lines"]:
				var cost := upkeep
				for t in ln["lab"]:
					cost += float(int(ln["lab"][t])) * float(w[t])
				for k in ln["in"]:
					cost += float(int(ln["in"][k])) * float(p[k])
				var unit := (cost + capital) / float(int(ln["qty"]))
				var o := String(ln["out"])
				if is_item(o):
					# an item two rows make (TRUCK: the components works and the truck workshop) starts at the cheaper
					# of the two, since a buyer takes the cheaper offer
					p[o] = minf(float(p[o]), unit) if seen.has(o) else unit
					seen[o] = true
				elif o == "@BW":
					p["BW"] = unit
				elif o == "@FREIGHT":
					p["@FREIGHT"] = unit
				elif not svc.has(type) or ln == ROWS[type]["lines"][0]:
					svc[type] = unit
	var out := {}
	for k in p:
		out[k if k != "@FREIGHT" else "FREIGHT"] = int(round(float(p[k]) * S))
	for type in svc:
		var times := HOME_RENT_PM / 1000.0 if type == "LANDLORD" else 1.0
		out["@" + type] = int(round(float(svc[type]) * times * S))
	_start = out
	return out


## The starting price of an item, "BW" or "FREIGHT", in milli-credits.
static func start_price(name: String) -> int:
	return int(start_prices().get(name, 0))


## The starting price a company of this type posts for what it sells on a line: an item's price, the BW price, the
## freight price, a client place's price a month, a home's rent, or the bank's rate in per mille.
static func start_price_of(type: String, idx: int = 0) -> int:
	var o := out_of(type, idx)
	if is_item(o):
		return start_price(o)
	match String(way(type)["price"]):
		"PER_BW":
			return start_price("BW")
		"PER_ROUTE":
			return start_price("FREIGHT")
		"RATE":
			return BANK_RATE_PM
	return int(start_prices().get("@" + type, 0))


## The salary line of the user's formula (plan 9.2, 12.5 rule 37 as revised): "avrage living in the area and food plus
## half of both again". One salary carries a household: 1.5 × (the rent of a home + the food of a household), with no
## division by earners. rent and food price in milli-credits; persons per household in milli (2.5 = 2500).
static func salary_line(rent: int, food_price: int, persons_milli: int) -> int:
	return (rent + food_price * persons_milli / 1000) * 1500 / 1000

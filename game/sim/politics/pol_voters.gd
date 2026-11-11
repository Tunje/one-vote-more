class_name PolVoters
extends RefCounted
## M10 S3b/S3c: the single accessor for "voter groups". Two sources:
##   CELLS  - the legacy voter cells (district × occupation × band × cohort, rebuilt from the census)
##   LEAVES - the population leaves themselves (population.md): opinion state lives on the people and travels
##            with them through PopStore transfers. Derived fields are refreshed monthly:
##            key, district, area, vocc (voter-table occupation), band, cohort (= archetype), census_key,
##            pop (= eligible voters under the electoral law, LQ.eligible_with).
## world.meta["voters"] = "LEAVES" selects the new source (default CELLS until S3c flips it).

const LQ := preload("res://sim/law/law_query.gd")
const S := 1000
## Derived fields: refreshed each month, never mixed when people move (PopStore.NON_STATE covers them).
const DERIVED := ["district", "area", "vocc", "band", "cohort", "census_key", "pop"]


static func leaves_mode(world: WorldState) -> bool:
	return String(world.meta.get("voters", "CELLS")) == "LEAVES" and not world.peek("pop").is_empty()


## All voter groups with pop > 0 or not (callers filter). Sorted by key in LEAVES mode (deterministic).
static func all(world: WorldState) -> Array:
	if not leaves_mode(world):
		return world.table("cell").values()
	return _leaves(world)  # reads never refresh (reads must not change state); refresh runs at phase starts


static func _leaves(world: WorldState) -> Array:
	var out: Array = []
	var keys: Array = world.peek("pop").keys()
	keys.sort()
	for k in keys:
		out.append(world.table("pop")[k])
	return out


static func by_key(world: WorldState, key: String) -> Dictionary:
	if leaves_mode(world):
		return world.peek("pop").get(key, {})
	return world.table("cell").get(key, {})


## Occupation name used by the opinion tables (OCC_SALIENCE, OCC_IDEOLOGY, turnout).
static func vocc(c: Dictionary) -> String:
	return String(c.get("vocc", c.get("occ", "SERVICES")))


static func district_of_hb(world: WorldState, hb: String) -> String:
	if hb.begins_with("hb:d:"):
		return hb.substr(3)          # transition: today's leaves are keyed hb:d:N (one area per district)
	var a: Dictionary = AreaStore.get_area(world, hb)
	return String(a.get("district", hb)) if not a.is_empty() else hb


## Monthly (LEAVES mode): refresh derived fields and make sure every leaf has opinion state.
static func refresh(world: WorldState) -> void:
	if not leaves_mode(world):
		return
	var e: Dictionary = LQ.eligibility(world, world.month)
	for l in _leaves(world):
		var occ: String = l["occ"]
		var status: String = l["status"]
		var v := "UNEMPLOYED" if status == "UNEMPLOYED" else ("RETIRED" if status == "RETIRED" else String(Philosophy.OCC_BASE.get(occ, occ)))
		l["vocc"] = v
		l["band"] = Philosophy.BAND_OF.get(l["inc"], "MID")
		l["cohort"] = l["arch"]
		l["area"] = l["hb"]
		l["district"] = district_of_hb(world, l["hb"])
		l["census_key"] = PolDefs.cell_key(l["district"], v, l["band"])
		l["pop"] = LQ.eligible_with(e, l)
		if not l.has("ideology"):
			var b := Philosophy.beliefs(world, occ, status, l["inc"], l["arch"] if l["arch"] != "MIX" else "LABOR")
			for f in b:
				l[f] = b[f]
		if not l.has("sat"):
			var sal := {}
			var sat := {}
			for c in PolDefs.CONCERNS:
				sal[c] = 111
				sat[c] = 50000
			l["salience"] = sal
			l["sat"] = sat
			l["approval"] = 50000
			l["expect"] = 50000
			l["perf_hist"] = []
			l["prev_share"] = {}

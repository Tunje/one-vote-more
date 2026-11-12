class_name Philosophy
extends RefCounted
## M10 S3a (planning/spec-population-v1.md §5.1; population.md §6): philosophy blocks.
## The eight archetypes of PD §6.3 are template vectors on the political axes. Each colony draws its own
## variants (offsets) and its own mix; the mix inside a work block comes from occupation × income priors, so
## miners hold several philosophies (PD §6.7). Leaves with the placeholder archetype "MIX" (new people from the
## economy) are spread over the archetypes that fit their work and income, and get beliefs: occupation base +
## income shift + archetype vector + colony variant. Beliefs live on the leaves and travel with people.
## State: pol.state["archetypes"] = {name: {offset: {axis: milli}, weight: milli}}.

const S := 1000
const ARCHETYPES := {
	"LABOR":       {"LABOR": 45, "REDISTRIBUTION": 25, "ECON_ROLE": 15},
	"MARKET":      {"ECON_ROLE": -45, "REDISTRIBUTION": -30, "FISCAL": -20, "LABOR": -20},
	"ENVIRONMENT": {"ENVIRONMENT": 50, "INSTITUTIONS": 10},
	"EQUALITY":    {"REDISTRIBUTION": 50, "ECON_ROLE": 20, "INSTITUTIONS": 10},
	"LIBERTY":     {"INSTITUTIONS": 40, "AUTONOMY": 30, "ECON_ROLE": -15, "SOVEREIGNTY": 15},
	"STABILITY":   {"INSTITUTIONS": -35, "SOVEREIGNTY": -20, "FISCAL": -15},
	"DEVELOPMENT": {"ENVIRONMENT": -45, "FISCAL": 25, "ECON_ROLE": -5},
	"INSTITUTION": {"INSTITUTIONS": -15, "AUTONOMY": -30, "SOVEREIGNTY": -25},
}
## Prior weight of each archetype by occupation (relative). Unlisted = 1.
const OCC_PRIOR := {
	"MINING":        {"LABOR": 3.0, "DEVELOPMENT": 2.0, "STABILITY": 1.5, "ENVIRONMENT": 0.5},
	"CONSTRUCTION":  {"LABOR": 2.5, "DEVELOPMENT": 2.0, "MARKET": 1.2},
	"MANUFACTURING": {"LABOR": 3.0, "EQUALITY": 1.5, "DEVELOPMENT": 1.5},
	"AGRICULTURE":   {"STABILITY": 2.0, "LIBERTY": 1.5, "ENVIRONMENT": 1.5, "LABOR": 0.7},
	"LOGISTICS":     {"LABOR": 2.0, "MARKET": 1.3},
	"SERVICES":      {"EQUALITY": 1.5, "LIBERTY": 1.3, "LABOR": 1.2},
	"PROFESSIONAL":  {"LIBERTY": 2.0, "ENVIRONMENT": 1.8, "MARKET": 1.5, "INSTITUTION": 1.3, "LABOR": 0.6},
	"PUBLIC_SECTOR": {"INSTITUTION": 2.5, "EQUALITY": 2.0, "ENVIRONMENT": 1.3, "MARKET": 0.5},
	"BUSINESS_OWNER": {"MARKET": 4.0, "DEVELOPMENT": 2.0, "LIBERTY": 1.5, "LABOR": 0.2, "EQUALITY": 0.3},
	"NONE":          {},
}
const STATUS_PRIOR := {"UNEMPLOYED": {"EQUALITY": 2.0, "LABOR": 1.5, "MARKET": 0.5}, "RETIRED": {"STABILITY": 2.0, "INSTITUTION": 1.5}}
const BAND_PRIOR := {"I1": {"EQUALITY": 1.8, "MARKET": 0.5}, "I2": {"EQUALITY": 1.3}, "I4": {"MARKET": 1.4}, "I5": {"MARKET": 2.2, "EQUALITY": 0.4}}
const MAX_PER_BLOCK := 4          # sparse: the 4 most likely archetypes per work block × band
## Old occupation names used by the opinion tables (OCC_IDEOLOGY) for the new 10 occupations.
const OCC_BASE := {"MANUFACTURING": "INDUSTRY", "CONSTRUCTION": "INDUSTRY", "LOGISTICS": "SERVICES", "NONE": "SERVICES"}
const BAND_OF := {"I1": "LOW", "I2": "LOW", "I3": "MID", "I4": "HIGH", "I5": "HIGH"}


## Per-colony archetype variants: random offsets per axis and a colony-wide popularity weight.
static func ensure(world: WorldState) -> Dictionary:
	var st: Dictionary = world.table("pol")["state"]
	if st.has("archetypes"):
		return st["archetypes"]
	var r := world.rng.stream("pol.arch")
	var out := {}
	var names: Array = ARCHETYPES.keys()
	names.sort()
	for n in names:
		var off := {}
		for ax in PolDefs.AXES:
			off[ax] = int(round((float(ARCHETYPES[n].get(ax, 0)) + r.randfn(0.0, 8.0)) * S))
		out[n] = {"offset": off, "weight": int(round(exp(r.randfn(0.0, 0.4)) * 1000.0))}  # milli (integer state survives save/load)
	st["archetypes"] = out
	return out


## Archetype shares for a work block and income band: {name: share}, the MAX_PER_BLOCK most likely.
static func mix(world: WorldState, occ: String, status: String, inc: String) -> Dictionary:
	var arch := ensure(world)
	var w := {}
	for n in arch:
		var x := float(arch[n]["weight"]) / 1000.0
		x *= float(OCC_PRIOR.get(occ, {}).get(n, 1.0))
		x *= float(STATUS_PRIOR.get(status, {}).get(n, 1.0))
		x *= float(BAND_PRIOR.get(inc, {}).get(n, 1.0))
		w[n] = x
	var names: Array = w.keys()
	names.sort_custom(func(a, b): return w[a] > w[b] or (w[a] == w[b] and a < b))
	var out := {}
	var tot := 0.0
	for n in names.slice(0, MAX_PER_BLOCK):
		tot += w[n]
	for n in names.slice(0, MAX_PER_BLOCK):
		out[n] = w[n] / tot
	return out


## Initial beliefs of a leaf: occupation base + income-band shift + archetype vector + colony variant.
static func beliefs(world: WorldState, occ: String, status: String, inc: String, arch_name: String) -> Dictionary:
	var arch := ensure(world)
	var occ_key: String = "UNEMPLOYED" if status == "UNEMPLOYED" else ("RETIRED" if status == "RETIRED" else String(OCC_BASE.get(occ, occ)))
	var base: Array = PolDefs.OCC_IDEOLOGY.get(occ_key, PolDefs.OCC_IDEOLOGY["SERVICES"])
	var bs: Array = PolDefs.BAND_SHIFT[BAND_OF.get(inc, "MID")]
	var ideo := {}
	for i in PolDefs.AXES.size():
		var ax: String = PolDefs.AXES[i]
		var v := int(base[i]) * S if i < base.size() else 0
		v += int(arch.get(arch_name, {}).get("offset", {}).get(ax, 0))
		ideo[ax] = v
	ideo["ECON_ROLE"] += int(bs[0]) * S
	ideo["REDISTRIBUTION"] += int(bs[1]) * S
	ideo["FISCAL"] += int(bs[2]) * S
	for ax in ideo:
		ideo[ax] = clampi(ideo[ax], -100 * S, 100 * S)
	return {"ideology": ideo, "base": ideo.duplicate(), "commitment": 50, "openness": 50, "engagement": 50}


## Spread every placeholder ("MIX") leaf over the archetypes that fit it; new leaves get beliefs.
## Returns the number of people assigned.
static func assign(world: WorldState) -> int:
	var moved := 0
	for key in PopStore.select(world, {"arch": "MIX"}):
		var l: Dictionary = world.peek("pop").get(key, {})
		if l.is_empty():
			continue
		var m := mix(world, l["occ"], l["status"], l["inc"])
		var names: Array = m.keys()
		names.sort()
		var parts := PopStore.split_over(int(l["n"]), names, names.map(func(n): return m[n]))
		for n in names:
			var k := int(parts.get(n, 0))
			if k <= 0:
				continue
			var dst := PopStore.relabel(key, {"arch": n})
			var fresh: bool = not world.peek("pop").has(dst)
			PopStore.transfer(world, key, dst, k, "PHILOSOPHY")
			var d: Dictionary = world.table("pop")[dst]
			if fresh or not d.has("ideology"):
				var b := beliefs(world, d["occ"], d["status"], d["inc"], n)
				for f in b:
					d[f] = b[f]
			moved += k
	return moved

extends RefCounted
## The signal for untreated illness (the user, 2026-11-17: "This needs signals, pandemic in the newpaper").
##
## The economy already keeps people out of work when a district's clinics cannot treat them (EconLabor.match: up to
## 8% of a district's labour force, in proportion to the clinic access it lacks). Until now nothing said so: no
## fact, no news, nothing for voters, parties or a government to react to. v12 ran for decades with clinic access
## near zero in five districts and nobody was told.
##
## Each month this counts the people kept from work by illness the same way the labour market does. While they are
## at least SHARE_FROM of the labour force it raises the public fact ECON_PANDEMIC: the government answers for it
## (clinics are public), voters' concern for public services and safety falls with its size, the papers print it,
## and at CRISIS_FROM it is a crisis a government can declare an emergency over.
## OPT-IN: world.meta["on"] has "HEALTH_SIGNAL". No class_name; preload by const.

const SICK_MAX := 0.08       # the labour market's own figure: the share of a district's labour force illness can hold back
const SHARE_FROM := 0.02     # the pandemic is news from 2% of the colony's labour force too ill to work
const CRISIS_FROM := 0.04    # and a crisis from 4%


static func on(world: WorldState) -> bool:
	return (world.meta.get("on", []) as Array).has("HEALTH_SIGNAL")


## {sick, labour, share, worst (district id), worst_access (‰), districts (how many have people too ill to work)}.
static func measure(world: WorldState) -> Dictionary:
	var health: Dictionary = EconUtil.st(world).get("health_access", {})
	var unemp := EconPop.people_by_lab(world, "UNEMPLOYED")
	var empl := EconPop.people_by_lab(world, "EMPLOYED")
	var lf_d := {}
	for src in [unemp, empl]:
		for k in src:
			var d := EconPop.district_of(EconPop.lab_parts(k)[0])
			lf_d[d] = int(lf_d.get(d, 0)) + int(src[k])
	var sick := 0
	var labour := 0
	var worst := ""
	var worst_sick := 0
	var n := 0
	for d in EconUtil.sorted_keys(lf_d):
		var lf := int(lf_d[d])
		labour += lf
		var here := int(float(lf) * SICK_MAX * (1.0 - float(health.get(d, 1000)) / 1000.0))
		sick += here
		if here > 0:
			n += 1
		if here > worst_sick:
			worst_sick = here
			worst = d
	return {"sick": sick, "labour": labour, "share": float(sick) / float(maxi(1, labour)), "worst": worst,
		"worst_access": int(health.get(worst, 1000)) if worst != "" else 1000, "districts": n}


static func monthly(world: WorldState) -> void:
	if not on(world):
		return
	var m := measure(world)
	var share: float = m["share"]
	if share < SHARE_FROM:
		return
	var pct := share * 100.0
	EconFacts.emit(world, "ECON_PANDEMIC", m["worst"] if String(m["worst"]) != "" else null, [], [["GOVERNMENT", "government", 1.0]],
		{"PUBLIC_SERVICES": -int(round(10.0 * pct)), "SAFETY": -int(round(5.0 * pct))}, 40 + int(round(7.5 * pct)), "PUBLIC",
		{"sick": int(m["sick"]), "share_pct": int(round(pct)), "district": String(m["worst"]), "access_pct": int(m["worst_access"]) / 10,
			"districts": int(m["districts"]), "crisis": share >= CRISIS_FROM, "crisis_type": "PANDEMIC"})

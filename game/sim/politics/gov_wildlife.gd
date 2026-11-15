class_name GovWildlife
extends RefCounted
## The politics of Terra's food pyramid (planet ecology stage 2, opt-in ECO; user 2026-11-15: "at the top things that
## can hurt humans, then we can have worry affecting politics: what if X kills someone on a new farm the government
## just granted ... real fodder for planet-first parties").
##
## 1. Blame. Terra's planet facts name nobody. Each wildlife attack becomes a public POL_WILDLIFE_OUTCRY: people feel
##    less safe, and the government carries part of it: more when its policy protects the predators, more when the farm
##    was one it had just funded with a grant, less when it culls. A collapse of a level of the food web near the colony
##    becomes POL_WILDLIFE_ALARM: the environment suffers, and a culling government carries most of it.
## 2. Policy. Once a year (and after a deadly attack) an elected government reviews ECO_WILDLIFE_POLICY
##    (PROTECT / MANAGE / CULL) and tables a bill to move one step toward what it wants: its ENVIRONMENT leaning pulls
##    toward PROTECT, attacks and deaths toward CULL, a weak food web back toward PROTECT. Parliament votes on it
##    like any bill (the lever's ideology and concern hints decide the other parties' votes).
## Nothing here knows what a policy will do beforehand; governments react to what has happened.

const LEVER := "ECO_WILDLIFE_POLICY"
const POLICIES := ["PROTECT", "MANAGE", "CULL"]
const REVIEW_MONTH := 3          # March
const GRANT_FRESH_M := 36        # "the farm the government just granted": a grant paid within this many months
const BLAME_BASE := 0.25
const BLAME_PROTECT := 0.25
const BLAME_CULL := -0.15
const BLAME_GRANT := 0.25
const W_ENV := 1.5               # weight of the government's ENVIRONMENT leaning (-1..1)
const W_ATTACK := 0.15           # per attack in the last 12 months
const W_DEATH := 0.5             # per person killed in the last 12 months
const W_WEB := 1.0               # per unit of food-web weakness (0 = healthy, 1 = a level gone)
const BAR := 0.7                 # preference beyond which a government wants PROTECT (+) or CULL (-)


static func on(world: WorldState) -> bool:
	return world.meta.has("on") and (world.meta["on"] as Array).has("ECO") and not EconUtil.off(world, "ECO")


static func monthly(world: WorldState, st: Dictionary) -> void:
	if not on(world):
		return
	var from_m := int(st.get("wildlife_seen_m", world.month - 1)) + 1
	st["wildlife_seen_m"] = world.month
	var deadly := false
	for f in world.facts.query("PLANET_WILDLIFE_ATTACK", from_m, world.month):
		if String(f["type"]) != "PLANET_WILDLIFE_ATTACK":
			continue
		_outcry(world, f)
		if int(f["data"].get("killed", 0)) > 0:
			deadly = true
	for f in world.facts.query("PLANET_WILDLIFE_COLLAPSE", from_m, world.month):
		_alarm(world, f)
	for f in world.facts.query("PLANET_BIRDS_FAILED", from_m, world.month):
		_birds_missed(world, f)
	if deadly:
		st["wildlife_review"] = true
	if world.month_of_year() == REVIEW_MONTH or bool(st.get("wildlife_review", false)):
		if _review(world, st):
			st["wildlife_review"] = false


## Share of an attack the government carries (0.1..0.9); the rest is nature's.
static func blame_share(policy: String, grant_funded: bool, months_since_grant: int) -> float:
	var g := BLAME_BASE
	if policy == "PROTECT":
		g += BLAME_PROTECT
	elif policy == "CULL":
		g += BLAME_CULL
	if grant_funded and months_since_grant >= 0 and months_since_grant <= GRANT_FRESH_M:
		g += BLAME_GRANT
	return clampf(g, 0.1, 0.9)


static func _outcry(world: WorldState, f: Dictionary) -> void:
	var d: Dictionary = f["data"]
	var killed := int(d.get("killed", 0))
	var injured := int(d.get("injured", 0))
	var granted := bool(d.get("grant_funded", false))
	var since := int(f["month"]) - int(d.get("grant_month", -1)) if int(d.get("grant_month", -1)) >= 0 else -1
	var g := blame_share(String(d.get("policy", "MANAGE")), granted, since)
	var fresh_grant: bool = granted and since >= 0 and since <= GRANT_FRESH_M
	world.add_fact({"type": "POL_WILDLIFE_OUTCRY", "owner": "pol", "subjects": [],
		"responsible": [{"actor": {"kind": "GOVERNMENT", "id": "government"}, "share": g}, {"actor": {"kind": "NATURE", "id": "wildlife"}, "share": 1.0 - g}],
		"impact": {"SAFETY": -(3 + 4 * killed + injured), "GOVERNANCE": -3 if fresh_grant else 0},
		"magnitude": mini(95, 30 + 25 * killed + 5 * injured + (10 if fresh_grant else 0)), "visibility": "PUBLIC", "causes": [f.get("id", "")],
		"data": {"creature": d.get("creature", ""), "killed": killed, "injured": injured, "site": d.get("site", ""), "place": d.get("place", ""),
			"district": d.get("district", ""), "family_farm": bool(d.get("family_farm", false)), "grant_funded": granted, "fresh_grant": fresh_grant,
			"policy": d.get("policy", "MANAGE"), "gov_share_pm": int(round(1000.0 * g))}})


static func _alarm(world: WorldState, f: Dictionary) -> void:
	var d: Dictionary = f["data"]
	var policy := String(d.get("policy", "MANAGE"))
	var g := 0.3 + (0.4 if policy == "CULL" else 0.0) - (0.15 if policy == "PROTECT" else 0.0)
	world.add_fact({"type": "POL_WILDLIFE_ALARM", "owner": "pol", "subjects": [],
		"responsible": [{"actor": {"kind": "GOVERNMENT", "id": "government"}, "share": g}, {"actor": {"kind": "NATURE", "id": "wildlife"}, "share": 1.0 - g}],
		"impact": {"ENVIRONMENT_QUALITY": -8 if String(d.get("level", "")) == "pol" else -5}, "magnitude": 45, "visibility": "PUBLIC",
		"causes": [f.get("id", "")],
		"data": {"group": d.get("group", ""), "creature": d.get("creature", ""), "colony": bool(d.get("colony", false)), "policy": policy,
			"gov_share_pm": int(round(1000.0 * g))}})


## Stage 3: "the birds didn't come this year". A sign people read as the land going wrong. When the worst-harmed place
## on the flock's route is the colony's own hex, the government carries a good part of it (its pollution, its
## clearing); harm further along the route is harder to pin on anyone.
static func _birds_missed(world: WorldState, f: Dictionary) -> void:
	var d: Dictionary = f["data"]
	var own: bool = bool(d.get("worst_is_colony", false))
	var g := 0.45 if own else 0.15
	world.add_fact({"type": "POL_BIRDS_MISSED", "owner": "pol", "subjects": [],
		"responsible": [{"actor": {"kind": "GOVERNMENT", "id": "government"}, "share": g}, {"actor": {"kind": "NATURE", "id": "wildlife"}, "share": 1.0 - g}],
		"impact": {"ENVIRONMENT_QUALITY": -6 if own else -3}, "magnitude": 40 if own else 30, "visibility": "PUBLIC", "causes": [f.get("id", "")],
		"data": {"name": d.get("name", ""), "role": d.get("role", ""), "size": int(d.get("size", 0)), "last_year": int(d.get("last_year", 0)),
			"worst_is_colony": own, "worst_harm": int(d.get("worst_harm", 0)), "gov_share_pm": int(round(1000.0 * g))}})


## What a government with ENVIRONMENT leaning `env` (-1..1) wants, given the last year: attacks, deaths, and the
## weakest level of the food web near the colony (`web` 0..1, 1 = natural).
static func target(env: float, attacks: float, deaths: float, web: float) -> String:
	var p := W_ENV * env - W_ATTACK * attacks - W_DEATH * deaths + W_WEB * clampf(1.0 - web, 0.0, 1.0)
	if p > BAR:
		return "PROTECT"
	if p < -BAR:
		return "CULL"
	return "MANAGE"


static func deaths_12m(world: WorldState) -> int:
	var n := 0
	for f in world.facts.query("PLANET_WILDLIFE_ATTACK", world.month - 11, world.month):
		if String(f["type"]) == "PLANET_WILDLIFE_ATTACK":
			n += int(f["data"].get("killed", 0))
	return n


## True when the review ran (whether or not it tabled anything).
static func _review(world: WorldState, st: Dictionary) -> bool:
	if st.get("era", "") != "PARLIAMENTARY" or not world.lever_defs.has(LEVER):
		return false
	var g: Dictionary = st.get("government", {})
	if g.is_empty() or (st.get("player_party", "") in g.get("members", []) and not st.get("autoplay_player", true)):
		return false
	if Legislature._pending_for(world, LEVER):
		return false
	var env := float(g.get("center", {}).get("ENVIRONMENT", 0)) / 100000.0
	var attacks := float(world.indicators.read("PLANET_WILDLIFE_ATTACKS", "COLONY", 0)) / 1000.0
	var web := float(world.indicators.read("PLANET_WEB_HEALTH", "COLONY", 1000000)) / 1000000.0
	var want := target(env, attacks, float(deaths_12m(world)), web)
	var cur := String(world.levers.get(LEVER, "MANAGE"))
	if not (cur in POLICIES) or want == cur:
		return true
	var step := 1 if POLICIES.find(want) > POLICIES.find(cur) else -1
	var to: String = POLICIES[POLICIES.find(cur) + step]   # one step at a time
	var cs := Intel.picture(world, "gov")
	Legislature.submit_bill(world, [{"lever": LEVER, "from": cur, "to": to}], g, cs[0], cs[1], world.new_id("bill"), 50)
	return true

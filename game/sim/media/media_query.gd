class_name MediaQuery
extends RefCounted
## Read-only media queries (UI, campaign, AI). Never writes state, never draws RNG.

const TILT_K := 0.3


## Outlets for the UI: [{id, name, owner, cred, circulation, price_mw, status, founded}] (active first, by id).
static func outlets(world: WorldState, include_closed: bool = false) -> Array:
	var out: Array = []
	for id in Media.outlets(world, not include_closed):
		var o: Dictionary = world.peek("outlet")[id]
		out.append({"id": id, "name": o["name"], "owner": o["owner"].duplicate(), "cred": int(o["cred"]),
			"circulation": int(o.get("circulation", 0)), "price_mw": int(o["price_mw"]), "status": o["status"],
			"founded": int(o["founded"])})
	return out


## One paper's edition: {outlet, month, circulation, stories: [{report, fact, kind, rank, head_actor, angle, slant,
## gov_share, corrected, exposed, also}]}. `also`: more facts of the same type grouped under this story. The truth class is hidden (companies §15.5); `exposed` marks reports shown false later.
static func edition(world: WorldState, out_id: String, month: int) -> Dictionary:
	var ed: Dictionary = world.peek("edition").get("%s|%d" % [out_id, month], {})
	if ed.is_empty():
		return {}
	var stories: Array = []
	for rid in ed["reports"]:
		var r: Dictionary = world.peek("report").get(rid, {})
		if r.is_empty():
			continue
		var fr: Dictionary = r["frame"]
		stories.append({"report": rid, "fact": r["fact"], "kind": r["kind"], "rank": int(r["rank"]),
			"head_actor": fr.get("blame_actor", {}).duplicate(), "angle": fr.get("angle", "NEUTRAL"),
			"slant": float(fr.get("slant", 0)) / 1000.0, "gov_share": float(fr.get("gov_share", 0)) / 1000.0,
			"corrected": String(r.get("corrected_by", "")) != "", "exposed": bool(r.get("exposed", false)),
			"also": r.get("also", []).duplicate()})
	var o: Dictionary = world.peek("outlet").get(out_id, {})
	return {"outlet": out_id, "name": o.get("name", out_id), "owner": o.get("owner", {}).duplicate(), "month": month,
		"circulation": int(ed.get("circulation", 0)), "stories": stories}


## Latest month with an edition for this paper (or -1).
static func latest_month(world: WorldState, out_id: String) -> int:
	var best := -1
	for k in world.peek("edition"):
		var e: Dictionary = world.peek("edition")[k]
		if String(e["outlet"]) == out_id and int(e["month"]) > best:
			best = int(e["month"])
	return best


## Outlets owned by an actor ({kind, id}).
static func owned_by(world: WorldState, owner: Dictionary) -> Array:
	return Media.owned_by(world, owner)


## Campaign multiplier for a voter group and party, 0.7..1.3: friendly papers amplify, hostile ones dampen.
## Cheap and read-only (Ella calls it from Campaign.voter_utility).
static func campaign_tilt(world: WorldState, leaf: Dictionary, party_id: String) -> float:
	var diet: Dictionary = leaf.get("diet", {})
	if diet.is_empty():
		return 1.0
	var trust: Dictionary = leaf.get("trust", {})
	var t := 0.0
	var ot := world.peek("outlet")
	for id in diet:
		var o: Dictionary = ot.get(id, {})
		if o.is_empty():
			continue
		t += float(diet[id]) / 1000.0 * float(trust.get(id, 50000)) / 100000.0 * float(o.get("party_tilt", {}).get(party_id, 0)) / 1000.0
	return clampf(1.0 + TILT_K * t, 0.7, 1.3)


## Same, averaged over a district's readers (computed monthly by Media.run).
static func campaign_tilt_district(world: WorldState, district: String, party_id: String) -> float:
	var td: Dictionary = world.peek("media").get("s", {}).get("tilt_district", {})
	return clampf(1.0 + TILT_K * float(td.get(district, {}).get(party_id, 0)) / 1000.0, 0.7, 1.3)


## The news vector of a voter group (what PoliticsProvider applies; spec §7).
static func news(leaf: Dictionary) -> Dictionary:
	return {"blame": int(leaf.get("news_blame", 0)), "bias": leaf.get("news_bias", {}), "agenda": leaf.get("news_agenda", {}),
		"diet": leaf.get("diet", {}), "trust": leaf.get("trust", {})}


## Weight of outlet o in a group's beliefs: diet × trust (0..1). Wilma's ideology pull uses it.
static func weight(leaf: Dictionary, out_id: String) -> float:
	return float(leaf.get("diet", {}).get(out_id, 0)) / 1000.0 * float(leaf.get("trust", {}).get(out_id, 0)) / 100000.0

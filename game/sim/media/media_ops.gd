class_name Media
extends RefCounted
## MEDIA v1 (planning/spec-media-v1.md). Owner: Anni.
## Outlets (table "outlet") publish a monthly edition (tables "edition", "report") chosen and framed from the
## PUBLIC facts since their last edition. Readers (voter groups: leaves or cells) get a diet over the outlets,
## a trust per outlet and a per-leaf news vector that PoliticsProvider applies (news_blame, news_bias,
## news_agenda). Facts are never edited: a report is a claim that points at a fact.
## Runs at the end of the JUSTICE phase (LawProvider). Streams: media.cover.

const MD := preload("res://sim/media/media_data.gd")
const Det := preload("res://sim/staff/det.gd")
const S := 1000


# =================================================================================== outlets

static func outlets(world: WorldState, active_only: bool = true) -> Array:
	var t := world.peek("outlet")
	var out: Array = []
	for id in Det.ordered(t):
		if not active_only or String(t[id].get("status", "")) == "ACTIVE":
			out.append(String(id))
	return out


static func outlet(world: WorldState, out_id: String) -> Dictionary:
	return world.peek("outlet").get(out_id, {})


static func owned_by(world: WorldState, owner: Dictionary) -> Array:
	return outlets(world).filter(func(id): return _same(outlet(world, id)["owner"], owner))


static func _same(a: Dictionary, b: Dictionary) -> bool:
	return String(a.get("kind", "")) == String(b.get("kind", "")) and String(a.get("id", "")) == String(b.get("id", ""))


## Integer-only state (README rule 3: floats don't round-trip through saves). Outlet sens/ethics (0..1) and invest
## (W_ref) are stored in milli; frame shares/amps, agg, party tilt and sales factor too. Convert at read time.
static func _m(x) -> int:
	return int(round(float(x) * 1000.0))


static func _sens(o: Dictionary) -> float:
	return float(o.get("sens", 0)) / 1000.0


static func _eth(o: Dictionary) -> float:
	return float(o.get("ethics", 500)) / 1000.0


static func _inv(o: Dictionary) -> float:
	return float(o.get("invest", 0)) / 1000.0


## A report frame as stored (milli ints) -> floats, and back.
static func _frame_store(fr: Dictionary) -> Dictionary:
	var out := fr.duplicate(true)
	for k in ["gov_share", "amp", "gov_amp", "slant"]:
		if out.has(k):
			out[k] = _m(out[k])
	for b in out.get("blame", []):
		b["share"] = _m(b["share"])
	return out


static func _fv(fr: Dictionary, k: String, dflt: float) -> float:
	return float(fr[k]) / 1000.0 if fr.has(k) else dflt


static func _milli_tree(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		if d[k] is Dictionary:
			out[k] = _milli_tree(d[k])
		else:
			out[k] = _m(d[k])
	return out


static func state(world: WorldState) -> Dictionary:
	var m := world.table("media")
	if not m.has("s"):
		m["s"] = {"circ": {}, "tilt_district": {}, "sales": {}}
	return m["s"]


static func _zero_line() -> Dictionary:
	var l := {}
	for ax in PolDefs.AXES:
		l[ax] = 0
	return l


## Population-weighted mean ideology of the voter groups (milli points); zeros before voters exist.
static func colony_mean(world: WorldState) -> Dictionary:
	var sum := {}
	var n := 0.0
	for ax in PolDefs.AXES:
		sum[ax] = 0.0
	for c in PolVoters.all(world):
		if not c.has("ideology") or int(c.get("pop", 0)) <= 0:
			continue
		var p := float(c["pop"])
		n += p
		for ax in PolDefs.AXES:
			sum[ax] += float(c["ideology"].get(ax, 0)) * p
	var out := _zero_line()
	if n > 0.0:
		for ax in PolDefs.AXES:
			out[ax] = int(round(sum[ax] / n))
	return out


## Founds an outlet. owner {kind STATE|COMPANY|PARTY|UNION, id}; opts may set name, line, sens, ethics, quality,
## cred, price_mw (milli-W_ref per copy-month), invest (W_ref/month), reach (Array of districts or "ALL").
static func found_outlet(world: WorldState, owner: Dictionary, opts: Dictionary = {}) -> Dictionary:
	var kind := String(owner.get("kind", ""))
	if not (kind in ["STATE", "COMPANY", "PARTY", "UNION"]):
		return {"ok": false, "reason": "UNKNOWN_OWNER_KIND", "out_id": ""}
	if outlets(world).size() >= MD.MAX_OUTLETS:
		return {"ok": false, "reason": "MARKET_FULL", "out_id": ""}
	if kind == "PARTY" and not bool(world.levers.get("LAW_PARTY_PRESS", true)):
		return {"ok": false, "reason": "PARTY_PRESS_BANNED", "out_id": ""}
	var cap := int(world.levers.get("LAW_MEDIA_OWNERSHIP_CAP", 100))
	if cap < 100 and kind != "STATE" and owner_share(world, owner) * 100.0 >= float(cap):
		return {"ok": false, "reason": "OWNERSHIP_CAP", "out_id": ""}
	if String(world.levers.get("LAW_PRESS_LICENSING", "NONE")) == "LICENCE" and kind != "STATE" \
			and not bool(opts.get("licensed", true)):
		return {"ok": false, "reason": "NO_PRESS_LICENCE", "out_id": ""}
	var base: Dictionary = {"STATE": MD.STATE_PAPER, "PARTY": MD.PARTY_PAPER, "UNION": MD.UNION_PAPER,
		"COMPANY": MD.COMPANY_PAPER}[kind]
	var id := world.new_id("out")
	var line: Dictionary = opts.get("line", colony_mean(world))
	var o := {"id": id, "name": String(opts.get("name", "Paper %s" % id.get_slice(":", 1))), "owner": owner.duplicate(),
		"founded": world.month, "account": "media:" + id, "line": line.duplicate(),
		"cred": int(opts.get("cred", base["cred"])), "price_mw": int(opts.get("price_mw", base["price_mw"])),
		"quality": int(opts.get("quality", base["quality"])), "sens": _m(opts.get("sens", base["sens"])),
		"ethics": _m(opts.get("ethics", base.get("ethics", 0.5))), "invest": _m(opts.get("invest", base.get("invest", 0.0))),
		"reach": opts.get("reach", "ALL"), "status": "ACTIVE", "last_fid": int(opts.get("last_fid", _last_fid(world))),
		"agg": {}, "party_tilt": {}, "circulation": 0, "lies": [], "cred0": int(opts.get("cred", base["cred"])),
		"pending_corrections": [], "scoops": []}
	world.table("outlet")[id] = o
	if not world.ledger.has_account(o["account"]):
		world.ledger.open_account(o["account"])
	world.add_fact({"type": "MEDIA_OUTLET_FOUNDED", "owner": "law", "subjects": [{"kind": "OUTLET", "id": id}],
		"responsible": [], "impact": {}, "magnitude": 30, "visibility": "PUBLIC",
		"data": {"outlet": id, "name": o["name"], "owner": owner.duplicate()}})
	return {"ok": true, "reason": "", "out_id": id}


static func transfer_outlet(world: WorldState, out_id: String, new_owner: Dictionary, price: int = 0) -> Dictionary:
	var o: Dictionary = world.table("outlet").get(out_id, {})
	if o.is_empty() or o["status"] != "ACTIVE":
		return {"ok": false, "reason": "NO_SUCH_OUTLET"}
	if String(new_owner.get("kind", "")) == "PARTY" and not bool(world.levers.get("LAW_PARTY_PRESS", true)):
		return {"ok": false, "reason": "PARTY_PRESS_BANNED"}
	var cap := int(world.levers.get("LAW_MEDIA_OWNERSHIP_CAP", 100))
	var circ := float(o.get("circulation", 0)) / maxf(1.0, _total_circ(world))
	if cap < 100 and (owner_share(world, new_owner) + circ) * 100.0 > float(cap):
		return {"ok": false, "reason": "OWNERSHIP_CAP"}
	var old: Dictionary = o["owner"]
	o["owner"] = new_owner.duplicate()
	o["deficit_months"] = 0          # a new owner gets a fresh start (the seller's unpaid months are not its own)
	world.add_fact({"type": "MEDIA_OUTLET_SOLD", "owner": "law", "subjects": [{"kind": "OUTLET", "id": out_id}],
		"responsible": [], "impact": {}, "magnitude": 35, "visibility": "PUBLIC",
		"data": {"outlet": out_id, "from": old.duplicate(), "to": new_owner.duplicate(), "price": price}})
	return {"ok": true, "reason": ""}


static func close_outlet(world: WorldState, out_id: String, reason: String) -> void:
	var o: Dictionary = world.table("outlet").get(out_id, {})
	if o.is_empty() or o["status"] == "CLOSED":
		return
	o["status"] = "CLOSED"
	o["closed"] = world.month
	_refund(world, o)
	world.add_fact({"type": "MEDIA_OUTLET_CLOSED", "owner": "law", "subjects": [{"kind": "OUTLET", "id": out_id}],
		"responsible": [], "impact": {}, "magnitude": 35, "visibility": "PUBLIC",
		"data": {"outlet": out_id, "name": o["name"], "reason": reason}})


## Bob's quarterly settlement could not cover the deficit (v1: the paper closes; sales come in M4).
static func on_insolvent(world: WorldState, out_id: String) -> void:
	close_outlet(world, out_id, "INSOLVENT")


static func _total_circ(world: WorldState) -> float:
	var t := 0.0
	for id in outlets(world):
		t += float(outlet(world, id).get("circulation", 0))
	return t


## Owner's share of total circulation (0..1).
static func owner_share(world: WorldState, owner: Dictionary) -> float:
	var tot := _total_circ(world)
	if tot <= 0.0:
		return 0.0
	var mine := 0.0
	for id in owned_by(world, owner):
		mine += float(outlet(world, id).get("circulation", 0))
	return mine / tot


static func _last_fid(world: WorldState) -> int:
	var fs: Array = world.facts.facts
	return _fnum(String(fs[fs.size() - 1]["id"])) if not fs.is_empty() else 0


static func _fnum(fid: String) -> int:
	return int(fid.substr(1))


## The founding state paper: today's Gazette. Created once.
static func ensure_founding(world: WorldState) -> void:
	var st := state(world)
	if bool(st.get("founded", false)) and int(st.get("units", 0)) < 1:
		_to_milli(world)
	st["units"] = 1
	if bool(st.get("founded", false)):
		return
	st["founded"] = true
	var home := "Landing"
	if world.peek("area").has("hb:1"):
		home = String(AreaStore.get_area(world, "hb:1").get("name", "Landing"))
	found_outlet(world, {"kind": "STATE", "id": "state"}, {"name": "The %s Gazette" % home, "last_fid": 0})


## One-off conversion of a pre-milli save (floats in outlets, reports, lies and the district tilt).
static func _to_milli(world: WorldState) -> void:
	for id in Det.ordered(world.table("outlet")):
		var o: Dictionary = world.table("outlet")[id]
		for k in ["sens", "ethics", "invest"]:
			o[k] = _m(o.get(k, 0.0))
		o["sales_pm"] = _m(o.get("sales_f", 1.0))
		o.erase("sales_f")
		o["agg"] = {}
		o["party_tilt"] = {}
	for rid in Det.ordered(world.table("report")):
		var r: Dictionary = world.table("report")[rid]
		r["frame"] = _frame_store(r["frame"])
	for lid in Det.ordered(world.table("media_lie")):
		var cb: Dictionary = world.table("media_lie")[lid].get("claim_bias", {})
		for c in cb.keys():
			cb[c] = int(round(float(cb[c])))
	state(world)["tilt_district"] = {}


# =================================================================================== positions & stance

static func _vec(arr: Array) -> Dictionary:
	var out := {}
	for i in PolDefs.AXES.size():
		out[PolDefs.AXES[i]] = int(arr[i]) * S if i < arr.size() else 0
	return out


## Political position of an actor (milli points), or {} when it has none.
static func actor_pos(world: WorldState, actor: Dictionary) -> Dictionary:
	match String(actor.get("kind", "")):
		"PARTY":
			return world.peek("party").get(String(actor.get("id", "")), {}).get("positions", {})
		"GOVERNMENT", "COMMANDER":
			var g: Dictionary = world.peek("pol").get("state", {}).get("government", {})
			var mem: Array = g.get("members", [])
			if mem.is_empty():
				return colony_mean(world)
			var out := _zero_line()
			var n := 0
			for pid in mem:
				var pos: Dictionary = world.peek("party").get(String(pid), {}).get("positions", {})
				if pos.is_empty():
					continue
				n += 1
				for ax in PolDefs.AXES:
					out[ax] += int(pos.get(ax, 0))
			if n > 0:
				for ax in PolDefs.AXES:
					out[ax] = int(round(float(out[ax]) / n))
			return out
		"COMPANY":
			return _vec(PolDefs.OCC_IDEOLOGY["BUSINESS_OWNER"])
		"UNION":
			return _vec(PolDefs.OCC_IDEOLOGY["INDUSTRY"])
	return {}


## -1 (ally: same line) .. +1 (opponent: ≥ 80 points apart). 0 for actors without a position.
static func opposition(line: Dictionary, pos: Dictionary) -> float:
	if pos.is_empty():
		return 0.0
	var d := 0.0
	for ax in PolDefs.AXES:
		d += absf(float(line.get(ax, 0)) - float(pos.get(ax, 0)))
	d = d / PolDefs.AXES.size() / float(S)
	return clampf((d - 25.0) / 25.0, -1.0, 1.0)


## -1 bad news for the responsible actors, +1 good news, 0 neutral.
static func valence(f: Dictionary) -> int:
	var t: String = f["type"]
	for p in MD.NEGATIVE:
		if t.begins_with(p):
			return -1
	var s := 0.0
	for c in f["impact"]:
		s += float(f["impact"][c])
	return -1 if s < 0.0 else (1 if s > 0.0 else 0)


static func _gov_share(f: Dictionary) -> float:
	var g := 0.0
	for r in f["responsible"]:
		if String(r["actor"]["kind"]) in ["GOVERNMENT", "COMMANDER"]:
			g += float(r["share"])
	return g


## The actors whose interests the outlet protects (bury) and serves.
static func owner_actors(world: WorldState, o: Dictionary) -> Array:
	var ow: Dictionary = o["owner"]
	match String(ow["kind"]):
		"COMPANY":
			return [{"kind": "COMPANY", "id": ow["id"]}]
		"PARTY":
			return [{"kind": "PARTY", "id": ow["id"]}]
		"STATE":
			if String(world.levers.get("LAW_PUBLIC_MEDIA", "INDEPENDENT")) == "GOVERNMENT_RUN":
				return [{"kind": "GOVERNMENT", "id": "government"}, {"kind": "COMMANDER", "id": "commander"}]
	return []


static func _owner_hit(world: WorldState, o: Dictionary, f: Dictionary) -> bool:
	var own := owner_actors(world, o)
	if own.is_empty() or valence(f) >= 0:
		return false
	var actors: Array = f["subjects"].duplicate()
	for r in f["responsible"]:
		actors.append(r["actor"])
	for a in actors:
		for x in own:
			if String(a.get("kind", "")) == String(x["kind"]) and (String(x["kind"]) in ["GOVERNMENT", "COMMANDER"] \
					or String(a.get("id", "")) == String(x["id"])):
				return true
	return false


## An independent public paper has no politics of its own: no slant, no party tilt (spec §2: day one = today).
static func neutral_public(world: WorldState, o: Dictionary) -> bool:
	return String(o["owner"]["kind"]) == "STATE" and String(world.levers.get("LAW_PUBLIC_MEDIA", "INDEPENDENT")) == "INDEPENDENT"


## How good this fact is for the outlet's politics: >0 it hurts the outlet's opponents (or credits allies).
static func stance(world: WorldState, o: Dictionary, f: Dictionary, cache: Dictionary = {}) -> float:
	var v := valence(f)
	if v == 0 or f["responsible"].is_empty() or neutral_public(world, o):
		return 0.0
	var s := 0.0
	for r in f["responsible"]:
		s += float(r["share"]) * _opp_cached(world, o, r["actor"], cache)
	return clampf(-float(v) * s, -1.0, 1.0)


static func _opp_cached(world: WorldState, o: Dictionary, actor: Dictionary, cache: Dictionary) -> float:
	var k := "%s|%s" % [actor.get("kind", ""), actor.get("id", "")]
	if String(actor.get("kind", "")) in ["GOVERNMENT", "COMMANDER"]:
		k = "GOV"
	if not cache.has(k):
		cache[k] = opposition(o["line"], actor_pos(world, actor))
	return cache[k]


# =================================================================================== editions

static func _weight(t: String) -> int:
	var best := 0
	var best_len := 0
	for k in MD.WEIGHT:
		if t.begins_with(k) and String(k).length() > best_len:
			best = MD.WEIGHT[k]
			best_len = String(k).length()
	return best


static func _sensational(t: String) -> bool:
	for p in MD.SENSATIONAL:
		if t.begins_with(p):
			return true
	return false


static func newsworthy(f: Dictionary) -> bool:
	var t: String = f["type"]
	if f["visibility"] != "PUBLIC" or int(f["magnitude"]) < MD.MIN_MAGNITUDE or t in MD.SKIP_TYPES:
		return false
	if String(f.get("data", {}).get("channel", "")) == "AD":
		return false        # paid space, not news (spec §3.1)
	for s in MD.SKIP_SUFFIX:
		if t.ends_with(s):
			return false
	return true


## PUBLIC facts after `last_fid` from this or last month (walks back from the end: O(recent facts)).
static func candidates(world: WorldState, last_fid: int) -> Array:
	var out: Array = []
	var fs: Array = world.facts.facts
	var i := fs.size() - 1
	while i >= 0:
		var f: Dictionary = fs[i]
		if _fnum(String(f["id"])) <= last_fid or int(f["month"]) < world.month - 1:
			break
		if newsworthy(f):
			out.append(f)
		i -= 1
	out.reverse()
	return out


static func edition_size(o: Dictionary) -> int:
	return 4 + int(o["quality"]) / 20


## Runs all editions, then readership and the per-leaf news vector. Called at the end of JUSTICE.
static func run(world: WorldState) -> void:
	ensure_founding(world)
	_close_orphans(world)
	_found_ai(world)
	_expose(world)
	_investigate(world)
	var censored := censorship_active(world)
	var mean := colony_mean(world)
	var rng := world.rng.stream("media.cover")
	var cands: Array = []
	var cand_from := -1
	for id in outlets(world):
		var o: Dictionary = world.table("outlet")[id]
		if o["owner"]["kind"] == "STATE" and String(world.levers.get("LAW_PUBLIC_MEDIA", "INDEPENDENT")) == "INDEPENDENT":
			for ax in PolDefs.AXES:
				o["line"][ax] = int(round(float(o["line"].get(ax, 0)) + (float(mean[ax]) - float(o["line"].get(ax, 0))) * MD.STATE_RECENTRE))
		if cand_from != int(o["last_fid"]):
			cand_from = int(o["last_fid"])
			cands = candidates(world, cand_from)
		_edition(world, o, cands, rng, censored)
		o["last_fid"] = _last_fid(world)
		_party_tilt(world, o)
		_credibility_drift(world, o)
	if censored:
		_record_censorship(world)
	_readers(world)
	_finances(world)
	_prune(world)


## Picks and frames one outlet's stories; stores the edition and the outlet's aggregate distortion `agg`.
static func _edition(world: WorldState, o: Dictionary, cands: Array, rng: RandomNumberGenerator, censored: bool = false) -> void:
	var cache := {}
	var k := edition_size(o)
	var scored: Array = []
	var bench: Array = []
	var scoops: Array = o.get("scoops", [])
	for f in cands:
		var news := float(f["magnitude"]) + float(_weight(f["type"]))
		bench.append({"f": f, "score": news + (MD.SENS_BONUS * 0.2 if _sensational(f["type"]) else 0.0)})
		if censored and _gov_share(f) > 0.0 and valence(f) < 0:
			continue     # the emergency censor strikes it (spec §8.3); readers miss it (the bench still has it)
		if f["id"] in scoops:
			news += MD.SCOOP_BONUS
		var sens_t := MD.SENS_BONUS if _sensational(f["type"]) else 0.0
		var st := stance(world, o, f, cache)
		var bury := 0.0
		if int(f["magnitude"]) < MD.BURY_MAX_MAGNITUDE and _owner_hit(world, o, f):
			bury = MD.BURY * (1.0 - _eth(o))
		var slant := MD.SLANT_SCORE * st
		if String(world.levers.get("LAW_DEFAMATION_STANDARD", "ACTUAL_MALICE")) == "STRICT":
			slant *= 0.7   # chilling effect
		var score := news + _sens(o) * sens_t + slant - bury + rng.randfn(0.0, 5.0)
		scored.append({"f": f, "score": score, "stance": st})
	var by_score := func(a, b): return a["score"] > b["score"] or (a["score"] == b["score"] and String(a["f"]["id"]) < String(b["f"]["id"]))
	scored.sort_custom(by_score)
	bench.sort_custom(by_score)
	var picked := _top_by_type(scored, k)
	var neutral := _top_by_type(bench, k)
	var rows: Array = []
	var agg := {"blame": {}, "bias": {}, "agenda": {}}
	var any_slant := false
	# corrections first (front page under LAW_CORRECTION_DUTY, inside pages otherwise)
	var duty := bool(world.levers.get("LAW_CORRECTION_DUTY", true))
	var tail: Array = []
	for lfid in o.get("pending_corrections", []):
		var lie: Dictionary = world.peek("media_lie").get(lfid, {})
		if lie.is_empty():
			continue
		var decay := pow(1.0 - MD.BIAS_DECAY, maxf(0.0, float(world.month - int(lie["month"]))))
		for c in lie.get("claim_bias", {}):
			agg["bias"][c] = float(agg["bias"].get(c, 0.0)) - float(lie["claim_bias"][c]) * MD.CORRECTION_ACCEPT * decay
		var row := {"outlet": o["id"], "month": world.month, "fact": String(world.peek("report").get(lie["report"], {}).get("fact", "")),
			"kind": "CORRECTION", "frame": {"truth": "ACCURATE", "gov_share": 0.0, "amp": 1.0, "blame": [], "blame_actor": {},
			"angle": "NEUTRAL", "slant": 0.0}, "truth": "ACCURATE", "corrected_by": "", "also": [], "corrects": lie["report"]}
		if duty:
			rows.append(row)
		else:
			tail.append(row)
	o["pending_corrections"] = []
	for i in picked.size():
		var f: Dictionary = picked[i]["f"]
		var fr := frame(world, o, f, float(picked[i]["stance"]), rng, cache)
		if fr["truth"] != "ACCURATE":
			any_slant = true
		rows.append({"outlet": o["id"], "month": world.month, "fact": f["id"], "kind": "INVESTIGATION" if f["id"] in scoops else "NEWS",
			"frame": fr, "truth": fr["truth"], "corrected_by": "", "also": picked[i]["also"]})
		for c in f["impact"]:
			var imp := float(f["impact"][c])
			agg["blame"][c] = float(agg["blame"].get(c, 0.0)) + imp * float(fr["gov_share"]) * float(fr.get("gov_amp", 1.0))
			agg["bias"][c] = float(agg["bias"].get(c, 0.0)) + (float(fr["amp"]) - 1.0) * imp * S
			agg["agenda"][c] = float(agg["agenda"].get(c, 0.0)) + absf(imp) * (1.0 + _sens(o))
	for b in neutral:
		var f: Dictionary = b["f"]
		var g := _gov_share(f)
		for c in f["impact"]:
			var imp := float(f["impact"][c])
			agg["blame"][c] = float(agg["blame"].get(c, 0.0)) - imp * g
			agg["agenda"][c] = float(agg["agenda"].get(c, 0.0)) - absf(imp) * 1.2
	var fab := _fabricate(world, o, cache)
	if not fab.is_empty():
		rows.insert(mini(1, rows.size()), fab)
		for c in fab["claim"]["impact"]:
			var imp := float(fab["claim"]["impact"][c])
			agg["blame"][c] = float(agg["blame"].get(c, 0.0)) + imp * float(fab["frame"]["gov_share"])
			agg["bias"][c] = float(agg["bias"].get(c, 0.0)) + imp * S
			agg["agenda"][c] = float(agg["agenda"].get(c, 0.0)) + absf(imp) * (1.0 + _sens(o))
	rows.append_array(tail)
	var reps: Array = []
	for i in rows.size():
		var row: Dictionary = rows[i]
		var rid := world.new_id("rep")
		row["id"] = rid
		row["rank"] = i + 1
		row["frame"] = _frame_store(row["frame"])
		world.table("report")[rid] = row
		reps.append(rid)
		if row.has("corrects") and world.table("report").has(row["corrects"]):
			world.table("report")[row["corrects"]]["corrected_by"] = rid
		if row["truth"] in ["MISLEADING", "ERROR", "FALSE"]:
			_record_lie(world, o, row)
	o["agg"] = _milli_tree(agg)
	o["scoops"] = []
	o["slanted_this_month"] = any_slant
	world.table("edition")["%s|%d" % [o["id"], world.month]] = {"outlet": o["id"], "month": world.month, "reports": reps,
		"circulation": int(o.get("circulation", 0))}


## The best k stories, one per fact type: repeats of a type are grouped under its best story ("also").
static func _top_by_type(sorted: Array, k: int) -> Array:
	var out: Array = []
	var at := {}
	for x in sorted:
		var t: String = x["f"]["type"]
		if at.has(t):
			out[at[t]]["also"].append(x["f"]["id"])
			continue
		if out.size() >= k:
			continue
		var y: Dictionary = x.duplicate()
		y["also"] = []
		at[t] = out.size()
		out.append(y)
	return out


## Frame for one printed fact: {truth, gov_share, amp, blame: [{actor, share}], blame_actor, angle}. Never edits f.
static func frame(world: WorldState, o: Dictionary, f: Dictionary, st: float, rng: RandomNumberGenerator, cache: Dictionary = {}) -> Dictionary:
	var g := _gov_share(f)
	var g2 := g
	var amp := 1.0
	var truth := "ACCURATE"
	var resp: Array = f["responsible"]
	var v := valence(f)
	var pressure := absf(st) * (1.0 - _eth(o))
	if _owner_hit(world, o, f):
		pressure = maxf(pressure, 1.0 - _eth(o))
	if not resp.is_empty() and rng.randf() < MD.P_ERROR * (1.0 - float(o["quality"]) / 100.0):
		truth = "ERROR"
		g2 = 1.0 - g
	elif pressure >= MD.MISLEAD_PRESSURE and not resp.is_empty() and v != 0 and not neutral_public(world, o) 			and rng.randf() < (pressure - MD.MISLEAD_PRESSURE) * MD.MISLEAD_P_SCALE:
		truth = "MISLEADING"
		var og := _opp_cached(world, o, {"kind": "GOVERNMENT"}, cache)
		var shift := maxf(0.5, MD.MISLEAD_SHIFT * absf(st))
		if (v < 0) == (og > 0.0):
			g2 = g + (1.0 - g) * shift
		else:
			g2 = g * (1.0 - shift)
		amp = 1.5 if st >= 0.0 else 0.6
	elif absf(st) > MD.SLANT_THRESHOLD and not resp.is_empty() and v != 0:
		truth = "SLANTED"
		var og := _opp_cached(world, o, {"kind": "GOVERNMENT"}, cache)
		var shift := MD.SLANT_BLAME * absf(st)
		var hostile := og > 0.0
		if (v < 0) == hostile:
			g2 = g + (1.0 - g) * shift      # blame the government it opposes / credit the one it backs
		else:
			g2 = g * (1.0 - shift)
		amp = 1.0 + 0.2 * absf(st) if st > 0.0 else 1.0 - 0.2 * absf(st)
	var blame: Array = []
	var other := 1.0 - g
	for r in resp:
		var is_gov := String(r["actor"]["kind"]) in ["GOVERNMENT", "COMMANDER"]
		var sh := float(r["share"])
		if is_gov:
			sh = sh / g * g2 if g > 0.0 else 0.0
		else:
			sh = sh / other * (1.0 - g2) if other > 0.0 else 0.0
		blame.append({"actor": r["actor"].duplicate(), "share": sh})
	if g <= 0.0 and g2 > 0.0:
		blame.append({"actor": {"kind": "GOVERNMENT", "id": "government"}, "share": g2})
	var top := {}
	var best := -1.0
	for b in blame:
		if float(b["share"]) > best:
			best = float(b["share"])
			top = b["actor"]
	var angle := "NEUTRAL"
	if truth != "ACCURATE" and not top.is_empty():
		angle = "GOVERNMENT" if String(top["kind"]) in ["GOVERNMENT", "COMMANDER"] else "SUBJECT"
	# The government's part is played up by papers hostile to it and down by friendly ones (any partisan paper).
	var gov_amp := 1.0
	if g2 > 0.0 and v != 0 and not neutral_public(world, o):
		var og2 := _opp_cached(world, o, {"kind": "GOVERNMENT"}, cache)
		gov_amp = 1.0 + 0.2 * og2 * (1.0 if v < 0 else -1.0)
	return {"truth": truth, "gov_share": g2, "amp": amp, "gov_amp": gov_amp, "blame": blame, "blame_actor": top,
		"angle": angle, "slant": st}


## Per party: -1 (hostile paper) .. +1 (friendly). Read by campaign_tilt.
static func _party_tilt(world: WorldState, o: Dictionary) -> void:
	var t := {}
	if neutral_public(world, o):
		o["party_tilt"] = t
		return
	for pid in Det.ordered(world.peek("party")):
		var p: Dictionary = world.peek("party")[pid]
		if String(p.get("status", "ACTIVE")) != "ACTIVE":
			continue
		var x := 0.0 if neutral_public(world, o) else -opposition(o["line"], p.get("positions", {}))
		if String(o["owner"]["kind"]) == "PARTY":
			x = 1.0 if String(o["owner"]["id"]) == String(pid) else minf(x, 0.0)
		t[pid] = _m(x)
	o["party_tilt"] = t


# =================================================================================== readers

static func _fit(c: Dictionary, line: Dictionary) -> float:
	return _fit_w(c["ideology"], line, VoteModel.axis_weights(c.get("salience", {})))


## exp(-weighted distance / FIT_SCALE); weights computed once per group by the caller.
static func _fit_w(ideo: Dictionary, line: Dictionary, wts: Dictionary) -> float:
	var num := 0.0
	var den := 0.0
	for ax in PolDefs.AXES:
		var wt: float = wts.get(ax, 1.0)
		num += wt * absf(float(ideo.get(ax, 0)) - float(line.get(ax, 0)))
		den += wt
	return exp(-(num / den / 1000.0) / MD.FIT_SCALE) if den > 0.0 else 1.0


static func _afford(world: WorldState, o: Dictionary, band: String) -> float:
	var disp: float = MD.BAND_DISPOSABLE.get(band, 1.0)
	return clampf(1.0 - float(o["price_mw"]) / 1000.0 / (0.02 * disp), 0.0, 1.0)


static func _access(o: Dictionary, district: String) -> bool:
	var r = o["reach"]
	return typeof(r) == TYPE_STRING or district in r


## Diet, trust and the news vector for every voter group (spec §4, §7). Groups with pop 0 are skipped.
static func _readers(world: WorldState) -> void:
	var ids := outlets(world)
	var ot := world.table("outlet")
	var os: Array = []
	for id in ids:
		os.append(ot[id])
	var n := ids.size()
	var circ: Array = []
	var circ_d: Array = []
	for i in n:
		circ.append(0.0)
		circ_d.append({})
	var tilt_num := {}     # district -> {party: Σ pop × w × tilt}
	var tilt_den := {}     # district -> Σ pop
	var aff_cache := {}
	for c in PolVoters.all(world):
		var pop := float(c.get("pop", 0))
		if pop <= 0.0 or not c.has("ideology"):
			continue
		var dist := String(c.get("district", ""))
		var band := String(c.get("band", "MID"))
		var sal: Dictionary = c.get("salience", {})
		var wts := VoteModel.axis_weights(sal)
		var trust: Dictionary = c.get("trust", {})
		var nt := {}
		var appeal: Array = []
		var tot := MD.A_NONE
		for i in n:
			var o: Dictionary = os[i]
			var id: String = ids[i]
			var fit := _fit_w(c["ideology"], o["line"], wts)
			var tgt := float(o["cred"]) * (0.5 + 0.5 * fit)
			var tr := float(trust.get(id, tgt))
			tr += (tgt - tr) * MD.TRUST_DRIFT
			nt[id] = int(round(tr))
			var a := 0.0
			if _access(o, dist):
				var ak := "%d|%s" % [i, band]
				if not aff_cache.has(ak):
					aff_cache[ak] = _afford(world, o, band)
				a = float(aff_cache[ak]) * (0.3 + 0.7 * fit) * (0.4 + 0.6 * tr / 100000.0) * (0.6 + float(o["quality"]) / 250.0) \
					* float(o.get("sales_pm", 1000)) / 1000.0
			appeal.append(a)
			tot += a
		var diet := {}
		var blame := 0.0
		var bias: Dictionary = c.get("news_bias", {})
		for k in bias.keys():
			bias[k] = int(round(float(bias[k]) * (1.0 - MD.BIAS_DECAY)))
			if bias[k] == 0:
				bias.erase(k)
		var agenda := {}
		if not tilt_den.has(dist):
			tilt_den[dist] = 0.0
			tilt_num[dist] = {}
		tilt_den[dist] += pop
		var tn: Dictionary = tilt_num[dist]
		for i in n:
			if float(appeal[i]) <= 0.0:
				continue
			var pm := int(round(float(appeal[i]) / tot * 1000.0))
			if pm <= 0:
				continue
			var o: Dictionary = os[i]
			var id: String = ids[i]
			diet[id] = pm
			var w := float(pm) / 1000.0 * float(nt[id]) / 100000.0
			var agg: Dictionary = o.get("agg", {})
			var ab: Dictionary = agg.get("blame", {})
			for cn in ab:
				blame += w * float(ab[cn]) / 1000.0 * float(sal.get(cn, 0)) / 1000.0 * MD.BLAME_SCALE
			var abi: Dictionary = agg.get("bias", {})
			for cn in abi:
				var b := w * float(abi[cn]) / 1000.0 * MD.K_BIAS
				if absf(b) >= 0.5:
					bias[cn] = int(round(float(bias.get(cn, 0)) + b))
			var aa: Dictionary = agg.get("agenda", {})
			for cn in aa:
				agenda[cn] = float(agenda.get(cn, 0.0)) + w * float(aa[cn]) / 1000.0 * MD.AGENDA_PER_IMPACT
			var copies := pop * float(pm) / 1000.0
			circ[i] = float(circ[i]) + copies
			circ_d[i][dist] = float(circ_d[i].get(dist, 0.0)) + copies
			var pt: Dictionary = o.get("party_tilt", {})
			for pid in pt:
				tn[pid] = float(tn.get(pid, 0.0)) + pop * w * float(pt[pid]) / 1000.0
		c["diet"] = diet
		c["trust"] = nt
		c["news_bias"] = bias
		c["news_blame"] = int(round(blame * MD.K_BLAME))
		var ag := {}
		for cn in agenda:
			var v := clampi(int(round(float(agenda[cn]))), -MD.AGENDA_CAP, MD.AGENDA_CAP)
			if v != 0:
				ag[cn] = v
		c["news_agenda"] = ag
	var st := state(world)
	var cd := {}
	for i in n:
		var id: String = ids[i]
		os[i]["circulation"] = int(round(float(circ[i])))
		var dd := {}
		for d in Det.ordered(circ_d[i]):
			dd[d] = int(round(float(circ_d[i][d])))
		cd[id] = dd
		var ed: Dictionary = world.table("edition").get("%s|%d" % [id, world.month], {})
		if not ed.is_empty():
			ed["circulation"] = int(round(float(circ[i])))
	st["circ"] = cd
	var td := {}
	for d in Det.ordered(tilt_den):
		if float(tilt_den[d]) <= 0.0:
			continue
		var row := {}
		for pid in Det.ordered(tilt_num[d]):
			row[pid] = _m(float(tilt_num[d][pid]) / float(tilt_den[d]))
		td[d] = row
	st["tilt_district"] = td


static func _prune(world: WorldState) -> void:
	var cut := world.month - MD.REPORT_KEEP_MONTHS
	var ed := world.table("edition")
	for k in ed.keys():
		if int(ed[k]["month"]) < cut:
			for rid in ed[k]["reports"]:
				world.table("report").erase(rid)
			ed.erase(k)


# =================================================================================== economy & campaign hooks

## Copies wanted: {hh group id: {outlet id: copies (milli)}}. Each district's readers (from the last reader pass)
## are split over that district's household groups by persons. Bob buys them in EconHouseholds._buy_media.
static func demand(world: WorldState) -> Dictionary:
	var circ: Dictionary = state(world).get("circ", {})
	var by_d := {}       # district -> [[gid, persons]]
	var tot_d := {}
	var hh := world.peek("hh")
	for gid in Det.ordered(hh):
		var g: Dictionary = hh[gid]
		var d := String(g.get("district", ""))
		var n := EconHouseholds.persons(g)
		if n <= 0:
			continue
		if not by_d.has(d):
			by_d[d] = []
			tot_d[d] = 0
		by_d[d].append([String(gid), n])
		tot_d[d] = int(tot_d[d]) + n
	var out := {}
	for oid in Det.ordered(circ):
		if String(outlet(world, oid).get("status", "")) != "ACTIVE":
			continue
		for d in Det.ordered(circ[oid]):
			var copies := int(circ[oid][d]) * S
			if copies <= 0 or not by_d.has(d):
				continue
			var parts := EconUtil.split_lr(copies, by_d[d].map(func(r): return int(r[1])))
			for i in by_d[d].size():
				if int(parts[i]) <= 0:
					continue
				var gid: String = by_d[d][i][0]
				if not out.has(gid):
					out[gid] = {}
				out[gid][oid] = int(parts[i])
	return out


## Copies actually bought {outlet id: copies (milli)} (Bob, SETTLEMENT). Readership follows sales: an outlet's
## appeal is scaled by `sales_pm` (‰), which drops to what was bought and recovers SALES_RECOVER a month.
static func record_sales(world: WorldState, sold: Dictionary) -> void:
	var st := state(world)
	st["sales"] = sold.duplicate(true)
	var circ: Dictionary = st.get("circ", {})
	for oid in outlets(world):
		var wanted := 0
		for d in circ.get(oid, {}):
			wanted += int(circ[oid][d]) * S
		if wanted <= 0:
			continue
		var o: Dictionary = world.table("outlet")[oid]
		var r := clampf(float(sold.get(oid, 0)) / float(wanted), 0.0, 1.0)
		o["sales_pm"] = _m(clampf(float(o.get("sales_pm", 1000)) / 1000.0 * r + MD.SALES_RECOVER, MD.SALES_F_MIN, 1.0))


## Ella's ad spend: paid to outlets by circulation share in the targeted districts; the rest goes to
## households as before (closed ledger). Returns the amount paid to outlets.
static func pay_ads(world: WorldState, from_acc: String, amount: int, district_weights: Dictionary, memo: String) -> int:
	if amount <= 0:
		return 0
	var circ: Dictionary = state(world).get("circ", {})
	var ids := outlets(world).filter(func(id): return circ.has(id))
	var wsum := 0.0
	for d in district_weights:
		wsum += float(district_weights[d])
	var shares: Array = []
	var weights: Array = []
	if wsum > 0.0:
		for id in ids:
			var s := 0.0
			for d in Det.ordered(district_weights):
				var tot := 0.0
				for j in ids:
					tot += float(circ[j].get(d, 0))
				if tot > 0.0:
					s += float(district_weights[d]) / wsum * float(circ[id].get(d, 0)) / tot
			if s > 0.0:
				shares.append(id)
				weights.append(s)
	var covered := 0.0
	for x in weights:
		covered += float(x)
	var to_media := int(floor(float(amount) * minf(1.0, covered)))
	var paid := 0
	if to_media > 0:
		var iw: Array = weights.map(func(x): return int(round(float(x) * 1000000.0)))
		var parts := EconUtil.split_lr(to_media, iw)
		for i in shares.size():
			if int(parts[i]) > 0:
				world.ledger.transfer(from_acc, String(outlet(world, shares[i])["account"]), int(parts[i]), memo, world.month)
				paid += int(parts[i])
	if amount - paid > 0:
		PartyLife._household_receive(world, from_acc, amount - paid, memo)
	return paid


# =================================================================================== M2: lies and their exposure

const JO := preload("res://sim/law/justice_ops.gd")
const PFN := preload("res://sim/law/party_finance.gd")
const REN := preload("res://sim/law/rules_engine.gd")
const LOPS := preload("res://sim/law/law_ops.gd")
const LDATA := preload("res://sim/law/law_data.gd")


## Every MISLEADING, ERROR or FALSE report leaves a SECRET MEDIA_FALSE_REPORT fact (the ground truth that the paper
## got it wrong) and a row in "media_lie" that exposure, corrections and defamation work from (spec §3.4, §5).
static func _record_lie(world: WorldState, o: Dictionary, row: Dictionary) -> void:
	var fr: Dictionary = row["frame"]
	var deliberate: bool = row["truth"] != "ERROR"
	var victim: Dictionary = {}
	var mag := 40
	var claim_bias := {}
	if row["truth"] == "FALSE":
		victim = row["claim"]["victim"]
		mag = int(row["claim"]["magnitude"])
		for c in row["claim"]["impact"]:
			claim_bias[c] = int(row["claim"]["impact"][c]) * S
	else:
		var f := world.facts.get_fact(String(row["fact"]))
		mag = int(f.get("magnitude", 40))
		var g := _gov_share(f)
		if _fv(fr, "gov_share", 0.0) > g + 0.0005:
			victim = {"kind": "GOVERNMENT", "id": "government"}
		else:
			for r in f.get("responsible", []):
				if not (String(r["actor"]["kind"]) in ["GOVERNMENT", "COMMANDER"]):
					victim = r["actor"].duplicate()
					break
		for c in f.get("impact", {}):
			var b := int(round((_fv(fr, "amp", 1.0) - 1.0) * float(f["impact"][c]) * S))
			if b != 0:
				claim_bias[c] = b
	var me := {"kind": "OUTLET", "id": o["id"]}
	var subj: Array = [me]
	if not victim.is_empty():
		subj.append(victim)
	var fid := world.add_fact({"type": "MEDIA_FALSE_REPORT", "owner": "law", "subjects": subj,
		"responsible": [{"actor": me, "share": 1.0}], "impact": {}, "magnitude": mag, "visibility": "SECRET",
		"data": {"outlet": o["id"], "report": row["id"], "victim": victim, "deliberate": deliberate, "truth": row["truth"]}})
	world.table("media_lie")[fid] = {"fid": fid, "outlet": o["id"], "report": row["id"], "victim": victim,
		"truth": row["truth"], "deliberate": deliberate, "month": world.month, "magnitude": mag, "claim_bias": claim_bias,
		"revealed": false}


## At most one fabricated story a month per paper (spec §3.4). -> report row (without id/rank) or {}.
static func _fabricate(world: WorldState, o: Dictionary, cache: Dictionary) -> Dictionary:
	if neutral_public(world, o):
		return {}
	var kind := String(o["owner"]["kind"])
	var st: Dictionary = world.peek("pol").get("state", {})
	var nxt := int(st.get("next_election", -1))
	var months_to := nxt - world.month if nxt >= 0 else 99
	var pressure := 0.5
	if kind == "PARTY" and months_to <= 12:
		pressure = 1.0
	elif kind == "COMPANY" and _owner_under_investigation(world, String(o["owner"]["id"])):
		pressure = 1.0
	var prox := 1.0 if months_to >= 0 and months_to <= 3 else 0.0
	var legal: float = MD.LEGAL_FACTOR.get(String(world.levers.get("LAW_DEFAMATION_STANDARD", "ACTUAL_MALICE")), 1.0)
	var p := float(world.meta.get("media_p_fabricate", MD.P_FABRICATE)) * pressure * (1.0 - _eth(o)) * (1.0 + prox) * legal
	var rng := world.rng.stream("media.lie")
	if rng.randf() >= p:
		return {}
	# the chief opponent: the government, or the most opposed active party
	var victim := {}
	var best := 0.2
	var og := _opp_cached(world, o, {"kind": "GOVERNMENT"}, cache)
	if og > best and not st.get("government", {}).is_empty():
		best = og
		victim = {"kind": "GOVERNMENT", "id": "government"}
	for pid in Det.ordered(world.peek("party")):
		var pt: Dictionary = world.peek("party")[pid]
		if String(pt.get("status", "ACTIVE")) != "ACTIVE" or (kind == "PARTY" and String(o["owner"]["id"]) == String(pid)):
			continue
		var x := _opp_cached(world, o, {"kind": "PARTY", "id": pid}, cache)
		if x > best:
			best = x
			victim = {"kind": "PARTY", "id": pid}
	if victim.is_empty():
		return {}
	var c1: String = MD.FAB_CONCERNS[rng.randi_range(0, MD.FAB_CONCERNS.size() - 1)]
	var impact := {c1: -rng.randi_range(3, 5)}
	if victim["kind"] == "PARTY":
		impact = {"GOVERNANCE": -rng.randi_range(3, 5)}
	var mag := rng.randi_range(40, 60)
	var gs := 1.0 if victim["kind"] == "GOVERNMENT" else 0.0
	var fr := {"truth": "FALSE", "gov_share": gs, "amp": 1.0, "gov_amp": 1.0, "blame": [{"actor": victim, "share": 1.0}],
		"blame_actor": victim, "angle": "GOVERNMENT" if gs > 0.0 else "SUBJECT", "slant": 1.0}
	return {"outlet": o["id"], "month": world.month, "fact": "", "kind": "NEWS", "frame": fr, "truth": "FALSE",
		"corrected_by": "", "also": [], "claim": {"victim": victim, "impact": impact, "magnitude": mag}}


static func _owner_under_investigation(world: WorldState, org: String) -> bool:
	for v in world.peek("violation_track").values():
		if String(v.get("company", "")) == org and bool(v.get("revealed", false)) and not v.has("sanctioned_month"):
			return true
	return false


## Monthly: unrevealed lies are found by the victim, a rival paper or an insider (spec §5).
static func _expose(world: WorldState) -> void:
	var lies := world.table("media_lie")
	if lies.is_empty():
		return
	var rng := world.rng.stream("media.expose")
	var whistle := MD.P_MEDIA_WHISTLE_PROTECTED if bool(world.levers.get("LAW_WHISTLEBLOWER_PROTECTION", false)) else MD.P_MEDIA_WHISTLE
	for fid in Det.ordered(lies):
		var l: Dictionary = lies[fid]
		if l["revealed"]:
			continue
		if world.month - int(l["month"]) > MD.LIE_WATCH_MONTHS:
			lies.erase(fid)      # nobody checks any more
			continue
		var liar: Dictionary = world.peek("outlet").get(l["outlet"], {})
		var by := ""
		var channel := ""
		if not l["victim"].is_empty() and int(l["magnitude"]) >= MD.COMPLAINT_MIN_MAGNITUDE 				and rng.randf() < float(MD.P_COMPLAINT_BY.get(String(l["truth"]), MD.P_COMPLAINT)):
			channel = "COMPLAINT"
		if channel == "" and not liar.is_empty():
			for rid in outlets(world):
				if rid == l["outlet"]:
					continue
				var r: Dictionary = world.peek("outlet")[rid]
				if _inv(r) < MD.DEBUNK_MIN_INVEST:
					continue
				var p := MD.P_DEBUNK * _inv(r) * (1.5 if opposition(r["line"], liar["line"]) > 0.0 else 1.0)
				if rng.randf() < p:
					channel = "RIVAL"
					by = rid
					break
		if channel == "" and rng.randf() < whistle:
			channel = "WHISTLEBLOWER"
		if channel != "":
			expose_lie(world, fid, channel, by)


## Reveals one lie: public MEDIA_REPORT_EXPOSED, credibility and trust hits, correction, defamation suit.
static func expose_lie(world: WorldState, fid: String, channel: String, by_outlet: String = "") -> bool:
	var l: Dictionary = world.table("media_lie").get(fid, {})
	if l.is_empty() or l["revealed"]:
		return false
	l["revealed"] = true
	l["revealed_month"] = world.month
	l["channel"] = channel
	var by := {"kind": "OUTLET", "id": by_outlet} if by_outlet != "" else {"kind": "PRESS", "id": channel}
	var causes: Array = [fid]
	if not world.table("revealed_fact").has(fid):
		world.table("revealed_fact")[fid] = true
		causes.append(world.facts.reveal(world.month, fid, [by]))
	var o: Dictionary = world.table("outlet").get(l["outlet"], {})
	var rep: Dictionary = world.table("report").get(l["report"], {})
	if not rep.is_empty():
		rep["exposed"] = true
	var will_correct: bool = not o.is_empty() and o["status"] == "ACTIVE" \
		and (bool(world.levers.get("LAW_CORRECTION_DUTY", true)) or _eth(o) >= 0.5)
	var hit := MD.CRED_ERROR
	if l["deliberate"]:
		var recent := 0
		for m in o.get("lies", []):
			if world.month - int(m) <= 24:
				recent += 1
		recent = mini(recent, MD.REPEAT_CAP)
		if l["truth"] == "MISLEADING":
			hit = MD.CRED_SPIN + MD.CRED_SPIN_REPEAT * recent      # exposed spin: true facts, dishonest framing
		else:
			hit = MD.CRED_LIE + MD.CRED_LIE_REPEAT * recent
	elif will_correct:
		hit = MD.CRED_ERROR_CORRECTED
	if not o.is_empty():
		o["cred"] = maxi(0, int(o["cred"]) - hit)
		if l["deliberate"]:
			o["lies"].append(world.month)
		if will_correct:
			o["pending_corrections"].append(fid)
		for c in PolVoters.all(world):
			var tr: Dictionary = c.get("trust", {})
			if not tr.has(o["id"]):
				continue
			var k := 0.5 if c.get("diet", {}).has(o["id"]) else 0.2
			tr[o["id"]] = maxi(0, int(tr[o["id"]]) - int(round(k * hit)))
	var me := {"kind": "OUTLET", "id": l["outlet"]}
	var subj: Array = [me]
	if not l["victim"].is_empty():
		subj.append(l["victim"])
	var xid := world.add_fact({"type": "MEDIA_REPORT_EXPOSED", "owner": "law", "subjects": subj,
		"responsible": [{"actor": me, "share": 1.0}], "impact": {}, "magnitude": 55 if l["deliberate"] else 35,
		"visibility": "PUBLIC", "causes": causes,
		"data": {"outlet": l["outlet"], "name": o.get("name", l["outlet"]), "report": l["report"], "victim": l["victim"],
			"deliberate": l["deliberate"], "truth": l["truth"], "channel": channel, "by": by_outlet}})
	if by_outlet != "" and world.table("outlet").has(by_outlet):
		world.table("outlet")[by_outlet]["scoops"].append(xid)
	_maybe_sue(world, l)
	return true


## Defamation (spec §8.2): parties and companies sue; a government does not. Liability depends on the standard.
static func _maybe_sue(world: WorldState, l: Dictionary) -> void:
	var v: Dictionary = l["victim"]
	if v.is_empty() or not (String(v["kind"]) in ["PARTY", "COMPANY"]):
		return
	var std := String(world.levers.get("LAW_DEFAMATION_STANDARD", "ACTUAL_MALICE"))
	if std == "NONE":
		return
	var liable := false
	if std == "ACTUAL_MALICE":
		liable = l["truth"] == "FALSE"
	else:
		liable = l["truth"] in ["FALSE", "MISLEADING", "ERROR"]
	if not liable and l["truth"] != "FALSE":
		return     # nobody sues over a frame the court would call lawful
	l["case"] = JO.file_defamation_outlet(world, v, String(l["outlet"]), int(l["magnitude"]), liable)


## Justice calls this on a defamation verdict against an outlet.
static func on_defamation_verdict(world: WorldState, out_id: String, guilty: bool) -> void:
	var o: Dictionary = world.table("outlet").get(out_id, {})
	if o.is_empty() or not guilty:
		return
	o["cred"] = maxi(0, int(o["cred"]) - MD.CRED_LIE_REPEAT)
	var conv: Array = o.get("convictions", [])
	conv.append(world.month)
	o["convictions"] = conv


static func _credibility_drift(world: WorldState, o: Dictionary) -> void:
	var c0 := int(o.get("cred0", o["cred"]))
	if String(o["owner"]["kind"]) == "STATE" and not neutral_public(world, o) and bool(o.get("slanted_this_month", false)):
		o["cred"] = maxi(0, int(o["cred"]) - MD.CRED_GOV_RUN_SLANT)
	elif int(o["cred"]) < c0:
		o["cred"] = mini(c0, int(o["cred"]) + MD.CRED_RECOVERY)


# =================================================================================== M2: investigations

## Each paper's investigation budget buys a chance to uncover a SECRET wrong (spec §6): an illegal donation, an
## unlawful company practice or a rival's lie. Reveals go through the existing justice paths (channel PRESS).
static func _investigate(world: WorldState) -> void:
	var rng := world.rng.stream("media.invest")
	var transp := MD.FOI_TRANSPARENCY if bool(world.levers.get("LAW_FOI", false)) else MD.NO_FOI_TRANSPARENCY
	for id in outlets(world):
		var o: Dictionary = world.table("outlet")[id]
		var p := minf(MD.INVEST_P_MAX, _inv(o) * MD.INVEST_P_PER_WREF) * transp
		if p <= 0.0 or rng.randf() >= p:
			continue
		var targets: Array = []   # [kind, fid, weight]
		var cache := {}
		for fid in Det.ordered(world.peek("donation_track")):
			var t: Dictionary = world.peek("donation_track")[fid]
			if not bool(t.get("revealed", true)):
				targets.append(["DONATION", fid, 1.0 + maxf(0.0, _opp_cached(world, o, {"kind": "PARTY", "id": t.get("party", "")}, cache))])
		for fid in Det.ordered(world.peek("violation_track")):
			var v: Dictionary = world.peek("violation_track")[fid]
			if bool(v.get("unlawful", true)) and not bool(v.get("revealed", false)) and bool(v.get("active", true)) \
					and String(v.get("company", "")) != String(o["owner"]["id"]):
				targets.append(["VIOLATION", fid, 1.0 + maxf(0.0, _opp_cached(world, o, {"kind": "COMPANY", "id": v.get("company", "")}, cache))])
		for fid in Det.ordered(world.peek("media_lie")):
			var l: Dictionary = world.peek("media_lie")[fid]
			if not l["revealed"] and String(l["outlet"]) != id:
				targets.append(["LIE", fid, 1.5])
		if targets.is_empty():
			continue
		var tot := 0.0
		for t in targets:
			tot += float(t[2])
		var x := rng.randf() * tot
		var pick: Array = targets[targets.size() - 1]
		for t in targets:
			x -= float(t[2])
			if x <= 0.0:
				pick = t
				break
		var before := world.facts.facts.size()
		var by := {"kind": "OUTLET", "id": id}
		match String(pick[0]):
			"DONATION":
				PFN._scandal(world, String(pick[1]), by, "PRESS")
			"VIOLATION":
				JO._reveal_violation(world, String(pick[1]), by, "PRESS")
			"LIE":
				expose_lie(world, String(pick[1]), "RIVAL", id)
		var sc: Array = o["scoops"]
		for i in range(before, world.facts.facts.size()):
			var f: Dictionary = world.facts.facts[i]
			if f["visibility"] == "PUBLIC" and not (f["id"] in sc):
				sc.append(f["id"])
		world.add_fact({"type": "MEDIA_INVESTIGATION_PUBLISHED", "owner": "law", "subjects": [by], "responsible": [],
			"impact": {}, "magnitude": 15, "visibility": "OFFICIAL", "data": {"outlet": id, "target": pick[0], "fact": pick[1]}})


# =================================================================================== M2: censorship

## Lawful censorship only during a declared emergency with LAW_EMERGENCY_PRESS_CONTROL (spec §8.3), validated by the
## rules engine (CENSOR_REPORT is otherwise a charter-level PROHIBIT, like RESTRICT_EXPRESSION).
static func censorship_active(world: WorldState) -> bool:
	if not bool(world.levers.get("LAW_EMERGENCY_PRESS_CONTROL", false)):
		return false
	var actor := {"kind": "GOVERNMENT", "id": "government"}
	if world.peek("pol").get("state", {}).get("government", {}).is_empty():
		actor = {"kind": "COMMANDER", "id": "commander"}
	return String(REN.validate(world, actor, "CENSOR_REPORT", {})["result"]) in ["AUTHORIZED", "AUTHORIZED_WITH_CONDITIONS"]


static func _record_censorship(world: WorldState) -> void:
	world.add_fact({"type": "MEDIA_CENSORED", "owner": "law", "subjects": [{"kind": "GOVERNMENT", "id": "government"}],
		"responsible": [{"actor": {"kind": "GOVERNMENT", "id": "government"}, "share": 1.0}], "impact": {}, "magnitude": 20,
		"visibility": "OFFICIAL", "exposure": {"kind": "PRESS_RESTRICTION", "scope": "ALL"}, "data": {"month": world.month}})


## Media rules (versioned): censorship is prohibited at charter level unless the emergency press-control lever is on,
## and authorised only during a declared emergency with it.
static func ensure_rules(world: WorldState) -> void:
	var s := LOPS.state(world)
	if int(s.get("media_rules_v", 0)) >= MD.RULES_VERSION:
		return
	s["media_rules_v"] = MD.RULES_VERSION
	var rules := world.table("legal_rule")
	for rid in Det.ordered(rules):
		if rules[rid].get("source", "") == "MEDIA_LAW" and rules[rid]["status"] == "ACTIVE":
			rules[rid]["status"] = "REPEALED"
	var lever_on := {"field": "lever.LAW_EMERGENCY_PRESS_CONTROL", "op": "EQ", "value": true}
	var exec := [{"field": "actor.kind", "op": "IN", "value": ["GOVERNMENT", "COMMANDER"]}]
	var r1 := LDATA._r("PROHIBIT", "CENSOR_REPORT", LDATA.PUBLIC_SUBJECT, [], {"source": "MEDIA_LAW", "right": "RESTRICT_EXPRESSION",
		"unless": [lever_on]})
	var r2 := LDATA._r("AUTHORIZE", "CENSOR_REPORT", exec, [{"field": "world.emergency", "op": "EQ", "value": true}, lever_on],
		{"source": "MEDIA_LAW"})
	for r in [r1, r2]:
		r["effective_month"] = world.month
		LOPS.add_rule(world, r)
	LOPS.bump_rules_version(world)


# =================================================================================== AI founding (spec §2.1, §15)

## How many more papers the market carries: active outlets < 1 + voters / POP_PER_PAPER, at most MAX_OUTLETS.
static func market_room(world: WorldState) -> int:
	var pop := 0
	for c in PolVoters.all(world):
		pop += maxi(0, int(c.get("pop", 0)))
	var cap := mini(MD.MAX_OUTLETS, 1 + pop / MD.POP_PER_PAPER)
	return maxi(0, cap - outlets(world).size())


## Under LAW_PRESS_LICENSING = LICENCE the government licenses only owners not opposed to it.
static func licensed(world: WorldState, owner: Dictionary) -> bool:
	if String(world.levers.get("LAW_PRESS_LICENSING", "NONE")) != "LICENCE":
		return true
	return opposition(actor_pos(world, {"kind": "GOVERNMENT", "id": "government"}), actor_pos(world, owner)) < 0.5


## Occupations at or above UNION_FOUND_DENSITY.
static func _union_strong_occs(world: WorldState) -> int:
	var n := 0
	var dens: Dictionary = EconUtil.peek_st(world).get("union", {}).get("density", {})
	for occ in dens:
		if int(dens[occ]) >= MD.UNION_FOUND_DENSITY:
			n += 1
	return n


## Public query (Bob's firm AI at M4): bad PUBLIC stories about one company in the last 12 months.
static func bad_press_12m(world: WorldState, org_id: String) -> int:
	return int(_bad_press(world).get(org_id, 0))


## Bad PUBLIC stories per company over the last BAD_PRESS_MONTHS (responsible or subject, negative valence).
static func _bad_press(world: WorldState) -> Dictionary:
	var out := {}
	for f in Det.recent_facts(world, "", world.month - MD.BAD_PRESS_MONTHS, "PUBLIC"):
		if valence(f) >= 0 or not newsworthy(f):
			continue
		var seen := {}
		var actors: Array = f["subjects"].duplicate()
		for r in f["responsible"]:
			actors.append(r["actor"])
		for a in actors:
			if typeof(a) == TYPE_DICTIONARY and String(a.get("kind", "")) == "COMPANY" and not seen.has(String(a.get("id", ""))):
				seen[String(a["id"])] = true
				out[String(a["id"])] = int(out.get(String(a["id"]), 0)) + 1
	return out


## Staff per org (milli-persons), facilities plus contractor crews.
static func _org_staff(world: WorldState) -> Dictionary:
	var out := {}
	var facs := world.peek("facility")
	for fid in facs:
		var f: Dictionary = facs[fid]
		out[String(f.get("org", ""))] = int(out.get(String(f.get("org", "")), 0)) + EconLabor.staff_total(f.get("staff", {}))
	var orgs := world.peek("org")
	for oid in orgs:
		if bool(orgs[oid].get("is_contractor", false)):
			out[String(oid)] = int(out.get(String(oid), 0)) + EconLabor.staff_total(orgs[oid].get("crew", {}))
	return out


## Would-be founders this month: [{owner, p, from, endow, opts}] in a fixed order.
static func founding_candidates(world: WorldState) -> Array:
	var out: Array = []
	var wref := float(maxi(1, int(world.values.get("ECON_W_REF", 1200 * S))))
	# parties (spec §2.1: funds ≥ 6 W_ref and ≥ 8% in the polls; ethics follows the leader's integrity)
	if bool(world.levers.get("LAW_PARTY_PRESS", true)):
		var parties := world.peek("party")
		for pid in Det.ordered(parties):
			var p: Dictionary = parties[pid]
			var owner := {"kind": "PARTY", "id": String(pid)}
			if String(p.get("status", "")) != "ACTIVE" or int(p.get("support", 0)) < MD.PARTY_FOUND_SUPPORT \
					or p.get("positions", {}).is_empty() or not owned_by(world, owner).is_empty():
				continue
			var acc := "party:" + String(pid)
			if float(world.ledger.balance(acc)) < MD.PARTY_FOUND_CASH * wref:
				continue
			var lead = p.get("leader", {})
			var integ := float(lead.get("integrity", 50)) if typeof(lead) == TYPE_DICTIONARY else 50.0
			out.append({"owner": owner, "p": MD.P_FOUND_PARTY * (1.0 + float(p["support"]) / 20000.0), "from": acc,
				"endow": int(MD.PARTY_FOUND_ENDOW * wref), "opts": {"name": "The %s Herald" % String(p.get("name", pid)),
				"line": p["positions"].duplicate(), "ethics": clampf(integ / 100.0, 0.0, 1.0)}})
	# the union federation (spec-unions-v1 §4: Bob's U1 row; density ≥ 30% in two occupations and a fund to pay
	# for it; line pulled toward LABOR and REDISTRIBUTION). Endowed from the federation's account.
	var fed := Unions.federation(world)
	if not fed.is_empty():
		var uowner := {"kind": "UNION", "id": String(fed["id"])}
		var spare := Unions.spare_fund(world, String(fed["id"]))
		if owned_by(world, uowner).is_empty() and _union_strong_occs(world) >= MD.UNION_FOUND_OCCS 				and spare >= int(MD.UNION_FOUND_CASH * wref):
			var line := colony_mean(world)
			for ax in MD.UNION_LINE_PULL:
				line[ax] = clampi(int(line.get(ax, 0)) + int(MD.UNION_LINE_PULL[ax]), -100 * S, 100 * S)
			out.append({"owner": uowner, "p": MD.P_FOUND_UNION, "from": String(fed["acct"]),
				"endow": int(MD.UNION_FOUND_ENDOW * wref), "opts": {"name": "The Worker", "line": line}})
	# large private companies, more so after bad press
	var orgs := world.peek("org")
	if not orgs.is_empty():
		var staff := {}
		var bad := {}
		var scanned := false
		for oid in Det.ordered(orgs):
			var o: Dictionary = orgs[oid]
			if String(o.get("status", "")) != "ACTIVE" or String(o.get("type", "")).begins_with("PUBLIC"):
				continue
			var owner := {"kind": "COMPANY", "id": String(oid)}
			var acc := EconUtil.acct(String(oid))
			if float(world.ledger.balance(acc)) < MD.COMPANY_FOUND_CASH * wref or not owned_by(world, owner).is_empty():
				continue
			if not scanned:
				staff = _org_staff(world)
				bad = _bad_press(world)
				scanned = true
			if int(staff.get(String(oid), 0)) < MD.COMPANY_FOUND_STAFF:
				continue
			var nbad := mini(3, int(bad.get(String(oid), 0)))
			var word := String(o.get("name", oid)).get_slice(" ", 0)
			out.append({"owner": owner, "p": MD.P_FOUND_COMPANY + MD.P_FOUND_BAD_PRESS * nbad, "from": acc,
				"endow": int(MD.COMPANY_FOUND_ENDOW * wref), "bad_press": nbad,
				"opts": {"name": "The %s Courier" % word, "line": _vec(PolDefs.OCC_IDEOLOGY["BUSINESS_OWNER"])}})
	return out


## An owner whose paper closed within REFOUND_COOLDOWN months does not found another (no found-fail-refound churn).
static func _recently_closed(world: WorldState, owner: Dictionary) -> bool:
	var t := world.peek("outlet")
	for id in t:
		var o: Dictionary = t[id]
		if String(o.get("status", "")) == "CLOSED" and _same(o["owner"], owner) \
				and world.month - int(o.get("closed", -999)) < MD.REFOUND_COOLDOWN:
			return true
	return false


## Monthly: at most one new paper, if the market has room. Every candidate rolls; one hit is drawn.
static func _found_ai(world: WorldState) -> void:
	if world.month < MD.FOUND_FROM_MONTH or market_room(world) <= 0:
		return
	var cands := founding_candidates(world).filter(func(c): return not _recently_closed(world, c["owner"]))
	if cands.is_empty():
		return
	var rng := world.rng.stream("media.found")
	var scale := float(world.meta.get("media_found_scale", 1.0))     # tests and probes
	var hits: Array = []
	for c in cands:
		if rng.randf() < float(c["p"]) * scale:
			hits.append(c)
	if hits.is_empty():
		return
	var pick: Dictionary = hits[rng.randi_range(0, hits.size() - 1)]
	var opts: Dictionary = pick["opts"].duplicate()
	opts["reach"] = "ALL"
	opts["licensed"] = licensed(world, pick["owner"])
	var r := found_outlet(world, pick["owner"], opts)
	if not bool(r["ok"]):
		return
	if String(pick["owner"]["kind"]) == "COMPANY" and world.table("org").has(String(pick["owner"]["id"])):
		world.table("org")[String(pick["owner"]["id"])]["media_out"] = String(r["out_id"])   # Bob reads it (M4: sell as an asset)
	if int(pick["endow"]) > 0:      # pay_upto reads the live balance at payment time
		EconUtil.pay_upto(world, String(pick["from"]), "media:" + String(r["out_id"]), int(pick["endow"]), "MEDIA_FOUNDING")


## A paper dies with its owner: a party no longer ACTIVE, a company in liquidation. Unknown owners are kept.
static func _close_orphans(world: WorldState) -> void:
	for id in outlets(world):
		var ow: Dictionary = outlet(world, id)["owner"]
		match String(ow.get("kind", "")):
			"PARTY":
				var p: Dictionary = world.peek("party").get(String(ow["id"]), {})
				if not p.is_empty() and String(p.get("status", "")) != "ACTIVE":
					close_outlet(world, id, "OWNER_GONE")
				elif not bool(world.levers.get("LAW_PARTY_PRESS", true)):
					close_outlet(world, id, "PARTY_PRESS_BANNED")
			"COMPANY":
				var o: Dictionary = world.peek("org").get(String(ow["id"]), {})
				if not o.is_empty() and String(o.get("status", "")) in ["LIQUIDATION", "DISSOLVED"]:
					close_outlet(world, id, "OWNER_GONE")
			"UNION":
				var u := Unions.get_union(world, String(ow["id"]))
				if u.is_empty() and String(ow["id"]) == "union:fed":
					# pre-U1 saves: the abstract federation's paper passes to the real one once it exists
					var fed := Unions.federation(world)
					if not fed.is_empty():
						world.table("outlet")[id]["owner"] = {"kind": "UNION", "id": String(fed["id"])}
				elif not u.is_empty() and String(u.get("status", "")) != "ACTIVE":
					close_outlet(world, id, "OWNER_GONE")


# =================================================================================== M4: money (spec §9, §16)

static func _has_economy(world: WorldState) -> bool:
	return not world.peek("hh").is_empty()


## Monthly running cost of an outlet in mcr (spec §9): staff quality × 0.02 W_ref, investigation `invest`,
## printing 0.1 W_ref + 0.0005 W_ref per copy.
static func running_cost(world: WorldState, o: Dictionary) -> int:
	var wref := float(maxi(1, int(world.values.get("ECON_W_REF", 1200 * S))))
	var w := float(o["quality"]) * MD.COST_STAFF_PER_QUALITY + _inv(o) + MD.COST_PRINT_BASE \
		+ MD.COST_PRINT_PER_COPY * float(o.get("circulation", 0))
	return int(round(w * wref))


## Months in a row the outlet could not pay its running costs (Bob's firm AI reads it for company papers).
static func deficit_months(world: WorldState, out_id: String) -> int:
	return int(outlet(world, out_id).get("deficit_months", 0))


static func _top_district(world: WorldState, out_id: String) -> String:
	var cd: Dictionary = state(world).get("circ", {}).get(out_id, {})
	var best := ""
	var bv := -1
	for d in Det.ordered(cd):
		if int(cd[d]) > bv:
			bv = int(cd[d])
			best = String(d)
	return best


## LAW_PRESS_SUBSIDY (W_ref/month, colony total): treasury → outlets by circulation, inside the subsidies budget.
static func _press_subsidy(world: WorldState) -> void:
	var lv := float(world.levers.get("LAW_PRESS_SUBSIDY", 0))
	if lv <= 0.0:
		return
	var wref := maxi(1, int(world.values.get("ECON_W_REF", 1200 * S)))
	var total := mini(int(lv * wref), maxi(0, EconActions.headroom(world, "ECON_BUDGET_SUBSIDIES")))
	var ids := outlets(world).filter(func(id): return int(outlet(world, id).get("circulation", 0)) > 0)
	if total <= 0 or ids.is_empty():
		return
	var parts := EconUtil.split_lr(total, ids.map(func(id): return int(outlet(world, id)["circulation"])))
	for i in ids.size():
		var paid := EconFinance.gov_pay(world, String(outlet(world, ids[i])["account"]), int(parts[i]), "PRESS_SUBSIDY")
		if paid > 0:
			EconFinance._spend_line(world, "ECON_BUDGET_SUBSIDIES", paid)


## The owner covers this month's shortfall: the state always (public media), a party up to PARTY_COVER_MAX W_ref
## while it keeps PARTY_COVER_RESERVE W_ref; a union from its spare fund (UNION_COVER_*). Companies top up in Bob's
## COMPANY_AI.
static func _owner_cover(world: WorldState, o: Dictionary, short: int) -> void:
	if short <= 0:
		return
	var wref := maxi(1, int(world.values.get("ECON_W_REF", 1200 * S)))
	match String(o["owner"]["kind"]):
		"STATE":
			var paid := EconFinance.gov_pay(world, String(o["account"]), short, "PUBLIC_MEDIA")
			if paid > 0:
				EconFinance._spend_line(world, "ECON_BUDGET_SUBSIDIES", paid)
		"PARTY":
			var acc := "party:" + String(o["owner"]["id"])
			var spare := world.ledger.balance(acc) - int(MD.PARTY_COVER_RESERVE * wref)
			var amt := mini(short, mini(int(MD.PARTY_COVER_MAX * wref), spare))
			if amt > 0:
				world.ledger.transfer(acc, String(o["account"]), amt, "MEDIA_OWNER_COVER", world.month)
		"UNION":
			# the union pays from what it can spare (Unions.spare_fund keeps a strike reserve), keeping a floor
			var uid := String(o["owner"]["id"])
			var u := Unions.get_union(world, uid)
			if u.is_empty() or not world.ledger.has_account(String(u.get("acct", ""))):
				return
			var spare_u := Unions.spare_fund(world, uid) - int(MD.UNION_COVER_RESERVE * wref)
			var amt_u := mini(short, mini(int(MD.UNION_COVER_MAX * wref), spare_u))
			if amt_u > 0:
				world.ledger.transfer(String(u["acct"]), String(o["account"]), amt_u, "MEDIA_OWNER_COVER", world.month)


## Monthly (end of Media.run): subsidy, owner cover, wages; deficit months; insolvency after DEFICIT_CLOSE_MONTHS.
static func _finances(world: WorldState) -> void:
	if not _has_economy(world) or EconUtil.off(world, "MEDIA_M4"):
		return
	_press_subsidy(world)
	for id in outlets(world):
		var o: Dictionary = world.table("outlet")[id]
		var cost := running_cost(world, o)
		_owner_cover(world, o, cost - world.ledger.balance(String(o["account"])))
		var dist := _top_district(world, id)
		var paid := EconHouseholds.pay_media_wages(world, String(o["account"]), cost, dist)
		if paid < cost and dist != "":
			paid += EconHouseholds.pay_media_wages(world, String(o["account"]), cost - paid, "")
		o["fin"] = {"month": world.month, "cost": cost, "paid": paid, "balance": world.ledger.balance(String(o["account"])),
			"sales": int(state(world).get("sales", {}).get(id, 0))}
		if paid < cost:
			o["deficit_months"] = int(o.get("deficit_months", 0)) + 1
		else:
			o["deficit_months"] = 0
		if int(o["deficit_months"]) >= MD.DEFICIT_CLOSE_MONTHS and String(o["owner"]["kind"]) != "STATE":
			close_outlet(world, id, "INSOLVENT")


## Leftover cash goes back to the owner (party, company) or to households (closed ledger).
static func _refund(world: WorldState, o: Dictionary) -> void:
	var acc := String(o.get("account", ""))
	if acc == "" or not world.ledger.has_account(acc):
		return
	var bal := world.ledger.balance(acc)
	if bal <= 0:
		return
	var ow: Dictionary = o["owner"]
	var to := ""
	match String(ow.get("kind", "")):
		"PARTY":
			to = "party:" + String(ow["id"])
		"COMPANY":
			to = EconUtil.acct(String(ow["id"]))
		"STATE":
			to = EconUtil.TREASURY
		"UNION":
			to = String(Unions.get_union(world, String(ow["id"])).get("acct", ""))
	if to != "" and world.ledger.has_account(to):
		world.ledger.transfer(acc, to, bal, "MEDIA_CLOSED", world.month)
	else:
		PartyLife._household_receive(world, acc, bal, "MEDIA_CLOSED")

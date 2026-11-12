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
		"quality": int(opts.get("quality", base["quality"])), "sens": float(opts.get("sens", base["sens"])),
		"ethics": float(opts.get("ethics", base.get("ethics", 0.5))), "invest": float(opts.get("invest", 0.0)),
		"reach": opts.get("reach", "ALL"), "status": "ACTIVE", "last_fid": int(opts.get("last_fid", _last_fid(world))),
		"agg": {}, "party_tilt": {}, "circulation": 0, "lies": []}
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
	if bool(st.get("founded", false)):
		return
	st["founded"] = true
	var home := "Landing"
	if world.peek("area").has("hb:1"):
		home = String(AreaStore.get_area(world, "hb:1").get("name", "Landing"))
	found_outlet(world, {"kind": "STATE", "id": "state"}, {"name": "The %s Gazette" % home, "last_fid": 0})


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
		_edition(world, o, cands, rng)
		o["last_fid"] = _last_fid(world)
		_party_tilt(world, o)
	_readers(world)
	_prune(world)


## Picks and frames one outlet's stories; stores the edition and the outlet's aggregate distortion `agg`.
static func _edition(world: WorldState, o: Dictionary, cands: Array, rng: RandomNumberGenerator) -> void:
	var cache := {}
	var k := edition_size(o)
	var scored: Array = []
	var bench: Array = []
	for f in cands:
		var news := float(f["magnitude"]) + float(_weight(f["type"]))
		var sens_t := MD.SENS_BONUS if _sensational(f["type"]) else 0.0
		var st := stance(world, o, f, cache)
		var bury := 0.0
		if int(f["magnitude"]) < MD.BURY_MAX_MAGNITUDE and _owner_hit(world, o, f):
			bury = MD.BURY * (1.0 - float(o["ethics"]))
		var slant := MD.SLANT_SCORE * st
		if String(world.levers.get("LAW_DEFAMATION_STANDARD", "ACTUAL_MALICE")) == "STRICT":
			slant *= 0.7   # chilling effect
		var score := news + float(o["sens"]) * sens_t + slant - bury + rng.randfn(0.0, 5.0)
		scored.append({"f": f, "score": score, "stance": st})
		bench.append({"f": f, "score": news + 0.2 * sens_t})
	var by_score := func(a, b): return a["score"] > b["score"] or (a["score"] == b["score"] and String(a["f"]["id"]) < String(b["f"]["id"]))
	scored.sort_custom(by_score)
	bench.sort_custom(by_score)
	var picked := _top_by_type(scored, k)
	var neutral := _top_by_type(bench, k)
	var reps: Array = []
	var agg := {"blame": {}, "bias": {}, "agenda": {}}
	for i in picked.size():
		var f: Dictionary = picked[i]["f"]
		var fr := frame(world, o, f, float(picked[i]["stance"]), rng, cache)
		var rid := world.new_id("rep")
		world.table("report")[rid] = {"id": rid, "outlet": o["id"], "month": world.month, "fact": f["id"], "kind": "NEWS",
			"rank": i + 1, "frame": fr, "truth": fr["truth"], "corrected_by": "", "also": picked[i]["also"]}
		reps.append(rid)
		for c in f["impact"]:
			var imp := float(f["impact"][c])
			agg["blame"][c] = float(agg["blame"].get(c, 0.0)) + imp * float(fr["gov_share"]) * float(fr.get("gov_amp", 1.0))
			agg["bias"][c] = float(agg["bias"].get(c, 0.0)) + (float(fr["amp"]) - 1.0) * imp * S
			agg["agenda"][c] = float(agg["agenda"].get(c, 0.0)) + absf(imp) * (1.0 + float(o["sens"]))
	for b in neutral:
		var f: Dictionary = b["f"]
		var g := _gov_share(f)
		for c in f["impact"]:
			var imp := float(f["impact"][c])
			agg["blame"][c] = float(agg["blame"].get(c, 0.0)) - imp * g
			agg["agenda"][c] = float(agg["agenda"].get(c, 0.0)) - absf(imp) * 1.2
	o["agg"] = agg
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
	if not resp.is_empty() and rng.randf() < MD.P_ERROR * (1.0 - float(o["quality"]) / 100.0):
		truth = "ERROR"
		g2 = 1.0 - g
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
		t[pid] = x
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
				a = float(aff_cache[ak]) * (0.3 + 0.7 * fit) * (0.4 + 0.6 * tr / 100000.0) * (0.6 + float(o["quality"]) / 250.0)
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
				blame += w * float(ab[cn]) * float(sal.get(cn, 0)) / 1000.0 * MD.BLAME_SCALE
			var abi: Dictionary = agg.get("bias", {})
			for cn in abi:
				var b := w * float(abi[cn]) * MD.K_BIAS
				if absf(b) >= 0.5:
					bias[cn] = int(round(float(bias.get(cn, 0)) + b))
			var aa: Dictionary = agg.get("agenda", {})
			for cn in aa:
				agenda[cn] = float(agenda.get(cn, 0.0)) + w * float(aa[cn]) * MD.AGENDA_PER_IMPACT
			var copies := pop * float(pm) / 1000.0
			circ[i] = float(circ[i]) + copies
			circ_d[i][dist] = float(circ_d[i].get(dist, 0.0)) + copies
			var pt: Dictionary = o.get("party_tilt", {})
			for pid in pt:
				tn[pid] = float(tn.get(pid, 0.0)) + pop * w * float(pt[pid])
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
			row[pid] = float(tilt_num[d][pid]) / float(tilt_den[d])
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

## Copies wanted per outlet and district (Bob books them in _buy_services; spec §9).
static func demand(world: WorldState) -> Dictionary:
	return state(world).get("circ", {}).duplicate(true)


## Copies actually bought (Bob, after scaling down what poor groups cannot pay).
static func record_sales(world: WorldState, sold: Dictionary) -> void:
	state(world)["sales"] = sold.duplicate(true)


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

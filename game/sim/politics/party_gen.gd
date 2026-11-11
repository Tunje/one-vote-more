class_name PartyGen
extends RefCounted
## Party creation from the colony's actual voter distribution (project §8.3).
## Ideology vectors everywhere in politics are stored as int milli-points (−100000..100000).

## Party names by defining axis: [names for the + pole], [names for the − pole]. The first free name is used,
## so later parties on the same axis still carry a name that says what they stand for.
const NAMES := {
	"ECON_ROLE": [["Colonial Solidarity Party", "Public Colony Movement", "Commonwealth League", "Planned Colony Party"],
		["Free Enterprise Party", "Open Market League", "Private Initiative Party", "Free Colony Union"]],
	"REDISTRIBUTION": [["Equal Share Movement", "Fair Share Party", "Social Equality League", "Common Wealth Party"],
		["Low Tax Alliance", "Keep What You Earn", "Taxpayers' League", "Self-Reliance Party"]],
	"LABOR": [["Workers' Union Party", "Labour Front", "Shift Workers' League", "Fair Work Movement"],
		["Enterprise & Growth", "Flexible Work Party", "Employers' Alliance", "Jobs Through Growth"]],
	"ENVIRONMENT": [["Green Frontier", "Clean Planet Party", "Ecology League", "Living Colony Movement"],
		["Development First", "Build & Extract Party", "Industrial Progress League", "Frontier Expansion Party"]],
	"AUTONOMY": [["District Autonomy League", "Local Power Party", "Free Districts Movement", "Self-Rule Alliance"],
		["Colony Unity Party", "One Colony Party", "Central Authority League", "United Settlement Party"]],
	"FISCAL": [["Builders' Party", "Invest Now Party", "Public Works League", "Growth Spending Alliance"],
		["Fiscal Prudence Party", "Balanced Budget League", "Debt-Free Colony", "Sound Finance Party"]],
	"INSTITUTIONS": [["Civic Liberty Party", "Reform & Rights League", "Open Government Party", "Citizens' Movement"],
		["Order & Stability", "Law & Order League", "Strong Institutions Party", "Colonial Tradition Party"]],
	"SOVEREIGNTY": [["Independence Party", "Free Colony Movement", "Sovereign Colony League", "Self-Determination Party"],
		["Loyalist Party", "Charter Loyalty League", "Homeworld Union", "Crown & Colony Party"]],
}
const SPARE_NAMES := ["Reform Party", "Colony First", "Progress Party", "Centre Alliance", "Pioneer Party", "Renewal", "New Democrats", "People's Alliance", "Common Ground", "Frontier League"]
const FIRST := ["Ana", "Bo", "Cyrus", "Dela", "Eskil", "Farah", "Gunn", "Hiro", "Ines", "Jarl", "Kaia", "Lev", "Mina", "Nils", "Oona", "Pavel", "Rune", "Sana", "Tove", "Ulf", "Vera", "Yusuf"]
const LAST := ["Ahlgren", "Bakr", "Castell", "Dahl", "Ekberg", "Frost", "Grahn", "Holm", "Ivarsson", "Jansen", "Kovac", "Lind", "Moreau", "Nyqvist", "Okafor", "Palm", "Quist", "Rask", "Sundin", "Tran", "Vik", "Wennberg"]


## Weighted k-means in 7-D. `fixed` = centers that never move (e.g. the player's party).
## Returns the free centers. Deterministic: farthest-point initialisation, then a fixed number of iterations.
static func cluster(cells: Array, fixed: Array, k_free: int) -> Array:
	var centers: Array = []
	for f in fixed:
		centers.append(f.duplicate())
	# farthest-point init (pop-weighted distance to nearest existing center)
	for _i in k_free:
		var best_c: Dictionary = {}
		var best_v := -1.0
		for c in cells:
			var d := INF
			for ctr in centers:
				d = minf(d, VoteModel.distance(c["ideology"], ctr))
			if centers.is_empty():
				d = 1.0
			var v := d * sqrt(float(c["pop"]))
			if v > best_v:
				best_v = v
				best_c = c
		centers.append(best_c["ideology"].duplicate())
	var nf := fixed.size()
	for _it in 20:
		var sums: Array = []
		var wts: Array = []
		for _j in centers.size():
			sums.append(PolDefs.zero_axes())
			wts.append(0.0)
		for c in cells:
			var j := _nearest(c["ideology"], centers)
			for ax in PolDefs.AXES:
				sums[j][ax] += float(c["ideology"][ax]) * c["pop"]
			wts[j] += c["pop"]
		for j in range(nf, centers.size()):
			if wts[j] > 0.0:
				for ax in PolDefs.AXES:
					centers[j][ax] = int(round(sums[j][ax] / wts[j]))
	return centers.slice(nf)


static func _nearest(v: Dictionary, centers: Array) -> int:
	var bi := 0
	var bd := INF
	for j in centers.size():
		var d := VoteModel.distance(v, centers[j])
		if d < bd:
			bd = d
			bi = j
	return bi


## Parties are more distinct than the voters they draw on (activists, platforms): push a voter-cluster
## centre away from the colony mean, and push its defining axis further still.
const PLATFORM_SPREAD := 1.8
const DEFINING_AXIS_BOOST := 1.35
const MAX_PLATFORM_DEVIATION := 65000.0   # milli-points from the colony mean; keeps outliers electable


static func exaggerate(center: Dictionary, mean: Dictionary, factor: float = PLATFORM_SPREAD) -> Dictionary:
	var top := ""
	for ax in PolDefs.AXES:
		if top == "" or absf(float(center[ax]) - float(mean[ax])) > absf(float(center[top]) - float(mean[top])):
			top = ax
	var out := {}
	for ax in PolDefs.AXES:
		var f := factor * (DEFINING_AXIS_BOOST if ax == top else 1.0)
		var dev := clampf((float(center[ax]) - float(mean[ax])) * f, -MAX_PLATFORM_DEVIATION, MAX_PLATFORM_DEVIATION)
		out[ax] = clampi(int(round(float(mean[ax]) + dev)), -100000, 100000)
	return out


static func dominant_axis(pos: Dictionary) -> Array:
	var axes := PolDefs.AXES.duplicate()
	axes.sort_custom(func(a, b): return absi(pos[a]) > absi(pos[b]) or (absi(pos[a]) == absi(pos[b]) and a < b))
	return axes


static func name_for(pos: Dictionary, taken: Dictionary, prefer_axis: String = "", prefer_sign: int = 0) -> String:
	var order: Array = dominant_axis(pos)
	if prefer_axis != "":
		order.erase(prefer_axis)
		order.push_front(prefer_axis)
	for ax in order:
		var sgn := prefer_sign if ax == prefer_axis and prefer_sign != 0 else (1 if pos[ax] >= 0 else -1)
		for n in NAMES[ax][0 if sgn > 0 else 1]:
			if not taken.has(n):
				return n
	for n in SPARE_NAMES:
		if not taken.has(n):
			return n
	return "Independent List %d" % (taken.size() + 1)


## Concerns a party is credible on: positions aligned with the direction dissatisfaction pulls voters.
static func ownership(pos: Dictionary) -> Dictionary:
	var own := {}
	for c in PolDefs.CONCERNS:
		var s := 0.0
		for ax in PolDefs.CONCERN_PULL[c]:
			s += PolDefs.CONCERN_PULL[c][ax] * float(pos[ax]) / 1000.0
		var v := clampi(int(round(s * 1.6)), 0, 100)
		if v > 0:
			own[c] = v
	if pos["ECON_ROLE"] < -20000:  # market parties are trusted on growth & management
		own["JOBS"] = maxi(own.get("JOBS", 0), 35)
		own["INFRASTRUCTURE"] = maxi(own.get("INFRASTRUCTURE", 0), 25)
		own["GOVERNANCE"] = maxi(own.get("GOVERNANCE", 0), 25)
	return own


## Commitments as lever-direction pairs (DECISIONS A9). Alignment = normalised dot product of the lever's
## ideology slope with the party's position, in -100..100.
static func commitments(pos: Dictionary, lever_defs: Dictionary) -> Array:
	var out: Array = []
	for lid in lever_defs:
		var ideo: Dictionary = lever_defs[lid].get("ideology", {})
		if ideo.is_empty():
			continue
		var dot := 0.0
		var norm := 0.0
		for ax in ideo:
			dot += float(ideo[ax]) * float(pos[ax]) / 1000.0
			norm += absf(float(ideo[ax]))
		var align := dot / norm if norm > 0.0 else 0.0  # -100..100
		var kind := ""
		if absf(align) >= 40.0:
			kind = "CORE"
		elif absf(align) >= 15.0:
			kind = "NEGOTIABLE"
		if kind != "":
			out.append({"lever": lid, "dir": 1 if align > 0 else -1, "kind": kind, "weight": int(round(absf(align)))})
	return out


static func leader_name(rng: RandomNumberGenerator) -> String:
	return "%s %s" % [FIRST[rng.randi_range(0, FIRST.size() - 1)], LAST[rng.randi_range(0, LAST.size() - 1)]]


static func make_party(world: WorldState, pos: Dictionary, party_name: String, is_player: bool, color_idx: int) -> Dictionary:
	var id := world.new_id("party")
	var p := {
		"id": id, "name": party_name, "color": PolDefs.PARTY_COLORS[color_idx % PolDefs.PARTY_COLORS.size()],
		"is_player": is_player, "founded_month": world.month, "positions": pos.duplicate(),
		"ownership": ownership(pos), "commitments": commitments(pos, world.lever_defs),
		"leader": PartyLife.make_leader(world, 0), "seats": 0, "kind": "FOUNDING", "support": 0,
		"credibility": 50, "agenda": [], "trust_in_player": 50, "status": "ACTIVE", "low_since": -1,
	}
	PartyLife.ensure_factions(p)
	PartyLife.open_account(world, id)
	world.table("party")[id] = p
	return p

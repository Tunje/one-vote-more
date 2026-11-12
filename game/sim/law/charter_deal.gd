extends RefCounted
## The expedition's charter deal (planning/spec-expedition-v1.md X4–X5, law side). Owner: Anni. Preload it (no
## class_name). Who paid for the expedition writes the charter:
##   - the home-world government: higher quota share, lower charter price, an export levy and, when it paid most,
##     a governor with veto powers (CharterOps.governor_veto);
##   - private investors: a sector privilege for a big backer, a council seat for a very big one;
##   - the colonists' own savings: softer terms and autonomy (status AUTONOMY when they paid a large share).
## Loans are Bob's debts and do not change the charter.
##
## terms(mix) is pure (the review screen shows it before signing); sign(world, terms) applies it once at founding.
## The Balanced reference mix reproduces today's start exactly (lever defaults, no governor, COLONY status).
##
## mix = {"HOME_GOV": int, "INVESTORS": int, "COLONISTS": int, "LOANS": int} (any unit, e.g. mcr; normalised here),
##   optional "investors": [{"id": String, "sector": String, "amount": int}] (same unit as the mix).

const CO := preload("res://sim/law/charter_ops.gd")

const SOURCES := ["HOME_GOV", "INVESTORS", "COLONISTS", "LOANS"]
## Balanced reference shares (‰ of the charter-relevant money, loans excluded): today's start.
const REF := {"HOME_GOV": 400, "INVESTORS": 400, "COLONISTS": 200}
## Charter terms per ‰ away from the reference (whole-range points per 1000‰).
const QUOTA_BASE := 40
const QUOTA_PER_HOME := 60          # +60 points if the home world paid everything instead of 40%
const QUOTA_PER_COLONISTS := -40
const PRICE_BASE := 35
const PRICE_PER_HOME := -40          # the home world buys its quota cheaper the more it paid
const PRICE_PER_COLONISTS := 30
const LEVY_PER_HOME := 25            # export levy (%) per 1000‰ of home share above the reference
const LEVY_MAX := 20
const QUOTA_RANGE := [10, 80]
const PRICE_RANGE := [10, 80]
const GOVERNOR_HOME_PM := 600        # the home world paid at least this share: a governor with veto power
const AUTONOMY_BASE := 30
const AUTONOMY_PER_COLONISTS := 100
const AUTONOMY_PER_HOME := -50
const AUTONOMY_STATUS_AT := 60       # autonomy ≥ this: the colony starts in AUTONOMY (softer charter)
const PRIVILEGE_PM := 150            # an investor with ≥ 15% of the money gets a privilege in its sector …
const COUNCIL_SEAT_PM := 250         # … and ≥ 25% a seat on the colony council


## Shares in ‰ of the charter-relevant money (HOME_GOV + INVESTORS + COLONISTS). All-zero: the reference.
static func shares(mix: Dictionary) -> Dictionary:
	var tot := 0
	for k in REF:
		tot += maxi(0, int(mix.get(k, 0)))
	if tot <= 0:
		return REF.duplicate()
	var out := {}
	for k in REF:
		out[k] = int(round(1000.0 * float(maxi(0, int(mix.get(k, 0)))) / float(tot)))
	return out


## The charter the backers will write. Pure. -> {LAW_CHARTER_QUOTA_SHARE, LAW_CHARTER_PRICE_PCT,
## LAW_CHARTER_EXPORT_LEVY, governor: bool, autonomy 0..100, status COLONY|AUTONOMY, shares, privileges:
## [{investor, sector, share_pm}], council_seats: [investor]}
static func terms(mix: Dictionary) -> Dictionary:
	var sh := shares(mix)
	var dh := float(int(sh["HOME_GOV"]) - int(REF["HOME_GOV"])) / 1000.0
	var dc := float(int(sh["COLONISTS"]) - int(REF["COLONISTS"])) / 1000.0
	var quota := clampi(int(round(QUOTA_BASE + QUOTA_PER_HOME * dh + QUOTA_PER_COLONISTS * dc)), QUOTA_RANGE[0], QUOTA_RANGE[1])
	var price := clampi(int(round(PRICE_BASE + PRICE_PER_HOME * dh + PRICE_PER_COLONISTS * dc)), PRICE_RANGE[0], PRICE_RANGE[1])
	var levy := clampi(int(round(LEVY_PER_HOME * maxf(0.0, dh))), 0, LEVY_MAX)
	var autonomy := clampi(int(round(AUTONOMY_BASE + AUTONOMY_PER_COLONISTS * dc + AUTONOMY_PER_HOME * dh)), 0, 100)
	var tot := 0
	for k in REF:
		tot += maxi(0, int(mix.get(k, 0)))
	var privileges: Array = []
	var seats: Array = []
	for inv in mix.get("investors", []):
		var pm := int(round(1000.0 * float(maxi(0, int(inv.get("amount", 0)))) / float(maxi(1, tot))))
		if pm >= PRIVILEGE_PM:
			privileges.append({"investor": String(inv["id"]), "sector": String(inv.get("sector", "")), "share_pm": pm})
		if pm >= COUNCIL_SEAT_PM:
			seats.append(String(inv["id"]))
	return {"LAW_CHARTER_QUOTA_SHARE": quota, "LAW_CHARTER_PRICE_PCT": price, "LAW_CHARTER_EXPORT_LEVY": levy,
		"governor": int(sh["HOME_GOV"]) >= GOVERNOR_HOME_PM, "autonomy": autonomy,
		"status": "AUTONOMY" if autonomy >= AUTONOMY_STATUS_AT else "COLONY", "shares": sh,
		"privileges": privileges, "council_seats": seats}


## Signing (X5): sets the charter levers, the governor and the status, and records the deal. Once per game, at
## founding (after LawOps.init_world). Returns {ok, reason}.
static func sign(world: WorldState, t: Dictionary) -> Dictionary:
	var st := CO.sov(world)
	if st.has("deal"):
		return {"ok": false, "reason": "the charter is already signed"}
	for lever in CO.CHARTER_LEVERS:
		if t.has(lever) and world.lever_defs.has(lever):
			var rg: Array = world.lever_defs[lever]["range"]
			world.levers[lever] = clampi(int(t[lever]), int(rg[0]), int(rg[1]))
	st["status"] = String(t.get("status", "COLONY"))
	st["since"] = world.month
	st["governor"] = bool(t.get("governor", false))
	st["governor_month"] = world.month if st["governor"] else -1
	st["deal"] = {"month": world.month, "autonomy": int(t.get("autonomy", AUTONOMY_BASE)), "shares": t.get("shares", {}).duplicate(),
		"privileges": t.get("privileges", []).duplicate(true), "council_seats": t.get("council_seats", []).duplicate()}
	world.add_fact({"type": "LAW_CHARTER_SIGNED", "owner": "law", "subjects": [CO.HOME, CO.GOVERNMENT], "responsible": [],
		"impact": {}, "magnitude": 60, "visibility": "PUBLIC",
		"data": {"quota": int(world.levers.get("LAW_CHARTER_QUOTA_SHARE", 40)), "price": int(world.levers.get("LAW_CHARTER_PRICE_PCT", 35)),
			"levy": int(world.levers.get("LAW_CHARTER_EXPORT_LEVY", 0)), "governor": st["governor"], "status": st["status"],
			"privileges": st["deal"]["privileges"].duplicate(true), "council_seats": st["deal"]["council_seats"].duplicate()}})
	return {"ok": true, "reason": ""}


## The signed deal ({} for old saves and games without an expedition).
static func deal(world: WorldState) -> Dictionary:
	return world.peek("law_state").get("s", {}).get("sovereignty", {}).get("deal", {})


## The investor holding a charter privilege in this sector ("" if none). While the charter binds, Bob's licensing
## of a rival in that sector may refuse or charge it (his call); after independence privileges lapse.
static func privilege_holder(world: WorldState, sector: String) -> String:
	if not CO.is_colonial(world):
		return ""
	for p in deal(world).get("privileges", []):
		if String(p.get("sector", "")) == sector:
			return String(p["investor"])
	return ""


static func council_seats(world: WorldState) -> Array:
	return deal(world).get("council_seats", []) if CO.is_colonial(world) else []


static func autonomy(world: WorldState) -> int:
	return int(deal(world).get("autonomy", AUTONOMY_BASE))

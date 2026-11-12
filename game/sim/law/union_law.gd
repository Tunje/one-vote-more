extends RefCounted
## Union law (planning/spec-unions-v1.md §4, U4). Owner: Anni (law). Pure reads of the union levers plus the
## unlawful-strike suit; Bob's union AI (U1/U2) and the politics side (U3) call these. Preload it (no class_name).
##
## Levers (all NUMBER, so AI governments can draft them; defaults keep the M9 behaviour):
##   LAW_STRIKE_BALLOT        % yes of members a strike needs (0 = no ballot)
##   LAW_CLOSED_SHOP          1 = closed-shop agreements enforceable, 0 = banned
##   LAW_PUBLIC_SECTOR_STRIKE 1 = public servants may strike, 0 = disputes go to arbitration
##   LAW_UNION_RECOGNITION    density (%) at which an employer must bargain (100 = no duty)
##   LAW_STRIKE_LIABILITY     % of the employer's losses a court may award against the union fund (0 = immunity)
##   LAW_POLITICAL_LEVY       0 = dues fund politics freely, 1 = opt-out, 2 = opt-in
##   LAW_ESSENTIAL_SERVICES   (ENUM, Bob's EconUnions) NONE / MIN_SERVICE / NO_STRIKE

const J := preload("res://sim/law/justice_ops.gd")

## Share of the fund a union may spend on parties by LAW_POLITICAL_LEVY (members who opt out, or never opt in).
const LEVY_SHARE := [1.0, 0.85, 0.35]
## Probability the employer sues over an unlawful strike (when liability > 0 and it has a claim).
const P_SUE := 0.6


static func _lever(world: WorldState, id: String, dflt: int) -> int:
	return int(world.levers.get(id, dflt))


## Yes share of members (‰) a strike ballot needs; 0 = no ballot required.
static func ballot_needed_pm(world: WorldState) -> int:
	return clampi(_lever(world, "LAW_STRIKE_BALLOT", 0), 0, 100) * 10


static func ballot_passes(world: WorldState, yes_pm: int) -> bool:
	var need := ballot_needed_pm(world)
	return need == 0 or yes_pm >= need


static func closed_shop(world: WorldState) -> bool:
	return _lever(world, "LAW_CLOSED_SHOP", 0) >= 1


static func public_strike_allowed(world: WorldState) -> bool:
	return _lever(world, "LAW_PUBLIC_SECTOR_STRIKE", 1) >= 1


## Recognition duty: with the union at this density (‰) of the employer's workers, the employer may not REFUSE
## talks (only ACCEPT or COUNTER). LAW_UNION_RECOGNITION 100 = no duty.
static func must_bargain(world: WorldState, density_pm: int) -> bool:
	var thr := _lever(world, "LAW_UNION_RECOGNITION", 100)
	return thr < 100 and density_pm >= thr * 10


## Share of a union's fund it may give to parties (U3 donations).
static func levy_share(world: WorldState) -> float:
	return float(LEVY_SHARE[clampi(_lever(world, "LAW_POLITICAL_LEVY", 0), 0, 2)])


## Share (0..1) of the employer's losses a court awards against the union fund for an unlawful strike.
static func liability_share(world: WorldState) -> float:
	return clampf(float(_lever(world, "LAW_STRIKE_LIABILITY", 50)) / 100.0, 0.0, 1.0)


## Public-sector employer: the government ("gov") or a public institution; and public-sector staff anywhere.
static func is_public(world: WorldState, employer: String, occ: String) -> bool:
	if employer == "gov" or occ == "PUBLIC_SECTOR":
		return true
	return String(world.peek("org").get(employer, {}).get("type", "")) == "PUBLIC_INSTITUTION"


## Is this strike lawful? Called by Bob's union AI (U2) right after talks fail. employer: an org id, or "gov" for
## the public sector. ballot_yes_pm: the members' yes share (‰), or -1 when no ballot was held.
## -> {lawful: bool, reasons: [NO_BALLOT | BALLOT_FAILED | PUBLIC_SECTOR_BAN]}
static func strike_check(world: WorldState, _union_id: String, employer: String, occ: String, ballot_yes_pm: int) -> Dictionary:
	var reasons: Array = []
	var need := ballot_needed_pm(world)
	if need > 0:
		if ballot_yes_pm < 0:
			reasons.append("NO_BALLOT")
		elif ballot_yes_pm < need:
			reasons.append("BALLOT_FAILED")
	if is_public(world, employer, occ) and not public_strike_allowed(world):
		reasons.append("PUBLIC_SECTOR_BAN")
	return {"lawful": reasons.is_empty(), "reasons": reasons}


## An unlawful strike ended: the employer may sue the union fund. losses = Unions.strike_losses (mcr). Only
## companies sue ("gov" answers a public strike through the ban itself). Claim = LAW_STRIKE_LIABILITY × losses;
## the court decides as for other civil cases (the strike happened, so the claim is true); damages come from the
## union's row["acct"] up to its balance (a suit can empty the fund). -> case id, or "" when nobody sues.
static func sue_unlawful_strike(world: WorldState, employer: String, union_id: String, losses: int, reasons: Array,
		force: bool = false) -> String:
	if employer == "gov" or not world.peek("org").has(employer) or losses <= 0:
		return ""
	var claim := int(round(float(losses) * liability_share(world)))
	if claim <= 0:
		return ""
	if not force and world.rng.stream("law.strike_suit").randf() >= P_SUE:
		return ""
	J.init_courts(world)
	return J.file_case(world, "STRIKE", {"kind": "COMPANY", "id": employer}, {"kind": "UNION", "id": union_id}, true,
		{"claim": claim, "losses": losses, "reasons": reasons.duplicate(), "union": union_id})

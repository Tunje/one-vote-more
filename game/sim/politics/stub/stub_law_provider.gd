class_name StubLawProvider
extends PicProvider
## Placeholder for the law subsystem's lever pipeline (DECISIONS A8: law is the single writer of operative levers).
## Applies PENDING rows in world.table("enactment") once earliest_effective_month is reached.
## Agent a9's LawProvider replaces this in M3 (validation + staff implementation tasks + lag).
## Register it BEFORE PoliticsProvider so levers are current when politics decides.

func owner_id() -> String:
	return "law"


func phases() -> Array:
	return [TickPhase.DECISIONS]


func run_phase(_phase: int, world: WorldState) -> void:
	for e in world.table("enactment").values():
		if e["status"] == "PENDING" and e["earliest_effective_month"] <= world.month:
			var old = world.levers[e["lever"]]
			world.levers[e["lever"]] = e["value"]
			e["status"] = "EFFECTIVE"
			e["effective_month"] = world.month
			var owner: String = world.lever_defs[e["lever"]]["owner"].to_upper()
			var is_ord: bool = e["legal_level"] == "ORDINANCE"
			world.add_fact({"type": "%s_LEVER_EFFECTIVE" % owner, "owner": "law", "subjects": [],
				"responsible": [{"actor": {"kind": "COMMANDER" if is_ord else "GOVERNMENT", "id": "commander" if is_ord else "government"}, "share": 1.0}],
				"impact": {}, "magnitude": 20, "visibility": "PUBLIC",
				"data": {"lever": e["lever"], "from": old, "to": e["value"], "enactment": e["id"]}})

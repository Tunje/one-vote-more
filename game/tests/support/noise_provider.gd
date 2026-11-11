extends PicProvider
## Test provider: exercises RNG, ledger, facts, indicators and levers with no real game meaning.
## Stateless, as required: everything it needs lives in world.entities["noise"].

func owner_id() -> String:
	return "stub"


func indicator_defs() -> Array:
	return [{
		"id": "STUB_NOISE", "owner": "stub", "unit": "index", "range": [0, 100000], "granularity": "COLONY",
		"polarity": 1, "concerns": {"JOBS": 1.0}, "normalize": {"good": 100000, "bad": 0},
		"phase": TickPhase.SOCIAL, "visibility": "PUBLIC", "perceptionLag": 0,
	}]


func lever_defs() -> Array:
	return [{
		"id": "STUB_RATE", "owner": "stub", "type": "NUMBER", "range": [0, 100], "default": 10,
		"legalLevel": "LAW", "foundingEra": "COMMANDER", "ideology": {"REDISTRIBUTION": 4},
		"implementation": null, "lag": 0, "scope": "COLONY",
	}]


func phases() -> Array:
	return [TickPhase.SETTLEMENT, TickPhase.SOCIAL]


func init_world(world: WorldState) -> void:
	world.ledger.open_account("gov")
	world.ledger.open_account("co:1")
	world.ledger.transfer(Ledger.EXTERNAL, "gov", 1_000_000 * Ledger.SCALE, "founding funds", world.month)
	world.table("noise")["n:1"] = {"acc": 0}


func run_phase(phase: int, world: WorldState) -> void:
	var r := world.rng.stream("stub.noise")
	match phase:
		TickPhase.SETTLEMENT:
			var amt := r.randi_range(0, 5000) * Ledger.SCALE
			world.ledger.transfer("gov", "co:1", amt, "contract", world.month)
			world.ledger.transfer("co:1", "gov", amt / 10, "tax", world.month)
			if r.randf() < 0.3:
				world.add_fact({"type": "STUB_EVENT", "owner": "stub", "subjects": [], "magnitude": r.randi_range(0, 60),
					"responsible": [{"actor": {"kind": "GOVERNMENT", "id": "gov"}, "share": 1.0}],
					"impact": {"JOBS": r.randi_range(-10, 10)}, "visibility": "PUBLIC"})
		TickPhase.SOCIAL:
			var e: Dictionary = world.table("noise")["n:1"]
			e["acc"] += r.randi_range(0, 1000)
			world.set_indicator("stub", "STUB_NOISE", "COLONY", e["acc"] % 100000)

class_name PicProvider
extends RefCounted
## Base class for every subsystem (planning/pic-core.md §8).
##
## HARD RULE: providers are STATELESS. All simulation state lives in WorldState
## (world.entities[<kind>], world.levers, ledger, facts, indicators). Then save/load is complete by construction,
## because providers are re-created from code after loading.

## Subsystem id: "econ" | "comp" | "staff" | "law" | "map" | "pol" | "stub" | ...
func owner_id() -> String:
	return "unknown"

func indicator_defs() -> Array:   # pic-core §3
	return []

func lever_defs() -> Array:       # pic-core §5
	return []

func action_defs() -> Array:      # pic-core §6
	return []

## TickPhase values this provider runs in.
func phases() -> Array:
	return []

## Called once on a NEW game (not after load) to create initial entities/accounts.
func init_world(_world: WorldState) -> void:
	pass

func run_phase(_phase: int, _world: WorldState) -> void:
	pass

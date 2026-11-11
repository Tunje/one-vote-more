class_name WorldState
extends RefCounted
## The single shared game state (project §17.2). Everything that must survive save/load lives here.

const SAVE_VERSION := 1

var month: int = 0                 # months elapsed since founding; month 0 = first month of Year 1
var current_phase: int = 0         # phase being executed (0 = between ticks)
var rng: RngStreams
var ledger: Ledger
var facts: FactStore
var indicators: IndicatorStore
var lever_defs: Dictionary = {}    # id -> def (re-registered from code)
var levers: Dictionary = {}        # id -> current effective value (int / String / bool)
var entities: Dictionary = {}      # kind -> {id -> Dictionary}; subsystems own their kinds
var id_counters: Dictionary = {}   # prefix -> next int
var values: Dictionary = {}        # shared scalar values, owner-prefixed (e.g. ECON_W_REF, LAW_RULES_VERSION); ints only
var meta: Dictionary = {}          # free-form (scenario name, flags)


func _init(seed_value: int = 0) -> void:
	rng = RngStreams.new(seed_value)
	ledger = Ledger.new()
	facts = FactStore.new()
	indicators = IndicatorStore.new()


# ---------- ids & entities ----------

## Stable id like "company:17". Never reused.
func new_id(prefix: String) -> String:
	var n: int = id_counters.get(prefix, 1)
	id_counters[prefix] = n + 1
	return "%s:%d" % [prefix, n]


func table(kind: String) -> Dictionary:
	if not entities.has(kind):
		entities[kind] = {}
	return entities[kind]


## Read-only access: returns the table or an empty dict WITHOUT creating it. UI and query code must use
## this, because table() creates missing tables and would change the save hash.
func peek(kind: String) -> Dictionary:
	return entities.get(kind, {})


func year() -> int:
	return month / 12 + 1


func month_of_year() -> int:
	return month % 12 + 1


# ---------- convenience wrappers that carry phase/ownership context ----------

func set_indicator(writer: String, id: String, key: String, value: int) -> void:
	indicators.write(id, key, value, current_phase, writer)


func add_fact(fact: Dictionary) -> String:
	return facts.add(month, fact)


func define_lever(def: Dictionary) -> void:
	for k in ["id", "owner", "type", "default", "legalLevel", "foundingEra", "ideology", "lag", "scope"]:
		assert(def.has(k), "lever def missing '%s': %s" % [k, def.get("id", "?")])
	assert(not lever_defs.has(def["id"]), "duplicate lever " + def["id"])
	lever_defs[def["id"]] = def
	if not levers.has(def["id"]):
		levers[def["id"]] = def["default"]


# ---------- persistence ----------

func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION, "month": month, "rng": rng.to_dict(), "ledger": ledger.to_dict(),
		"facts": facts.to_dict(), "indicators": indicators.to_dict(), "levers": levers.duplicate(true),
		"entities": entities.duplicate(true), "values": values.duplicate(true), "id_counters": id_counters.duplicate(), "meta": meta.duplicate(true),
	}


## Restores state into a world whose defs were already registered by Simulation.
func load_dict(d: Dictionary) -> void:
	assert(d["version"] == SAVE_VERSION, "save version %s unsupported (migrations go in SaveIO)" % d["version"])
	month = d["month"]
	rng = RngStreams.from_dict(d["rng"])
	ledger = Ledger.from_dict(d["ledger"])
	facts = FactStore.from_dict(d["facts"])
	indicators.load_state(d["indicators"])
	for k in d["levers"]:
		levers[k] = d["levers"][k]
	entities = d["entities"].duplicate(true)
	values = d.get("values", {}).duplicate(true)
	id_counters = d["id_counters"].duplicate()
	meta = d["meta"].duplicate(true)


## Deterministic fingerprint of the whole state (used by determinism and save tests).
func state_hash() -> String:
	return var_to_str(to_dict()).sha256_text()

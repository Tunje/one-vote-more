class_name TickPhase
extends RefCounted
## Master monthly tick order (planning/pic-core.md §7). The order is fixed; providers run in registration order within a phase.

enum {
	DECISIONS = 1,  # pol: apply queued player/AI actions, legal validation
	STAFF,          # staff: work progress; implementations complete -> levers become effective
	TRADE,          # econ: logistics, shipments, imports
	PRODUCTION,     # econ/comp: labor allocation, production, construction
	SETTLEMENT,     # econ: wages, sales, taxes, ledger, insolvency checks
	COMPANY_AI,     # comp: firm decisions for next month
	JUSTICE,        # law: incidents, inspections, cases, rulings
	SOCIAL,         # econ/map: households, housing, migration -> indicators final
	POLITICS,       # pol: perception, opinion, parties, polls, parliament, AI gov
	EVENTS,         # pol/all: condition-triggered events
	RECORD,         # kernel: history, compaction, briefing
}

const ORDER: Array[int] = [DECISIONS, STAFF, TRADE, PRODUCTION, SETTLEMENT, COMPANY_AI, JUSTICE, SOCIAL, POLITICS, EVENTS, RECORD]

const NAMES := {
	DECISIONS: "DECISIONS", STAFF: "STAFF", TRADE: "TRADE", PRODUCTION: "PRODUCTION",
	SETTLEMENT: "SETTLEMENT", COMPANY_AI: "COMPANY_AI", JUSTICE: "JUSTICE", SOCIAL: "SOCIAL",
	POLITICS: "POLITICS", EVENTS: "EVENTS", RECORD: "RECORD",
}

## The last phase in which indicators may be finalized. Politics only reads after this.
const INDICATORS_FINAL_BY: int = SOCIAL


static func name_of(phase: int) -> String:
	return NAMES.get(phase, "UNKNOWN(%d)" % phase)

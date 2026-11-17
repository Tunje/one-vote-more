class_name Logbook
extends RefCounted
## The log of everything that happens in the economy, to investigate from (the user, 2026-11-17: "a backend column
## somhere that records all things happening like a log we can investigate from").
##
## One row per thing that happened: a rule acting, a sale, a hire, a plan made or given up, a contract signed, a loan,
## a company ending. Each row says WHEN (month and phase), WHAT KIND, WHO, WITH WHOM, ABOUT WHICH RECORD, WHAT, WHY (the
## numbers the decision read) and what CHANGED (from, to). Money has its own log already: every payment is in
## world.ledger.journal.
##
## The log is not part of the game's state. The rows live on the world (WorldState.log_rows) but are not saved and not
## hashed, so a loaded game starts with an empty log, and a world's log goes when the world goes. NOTHING IN THE GAME
## MAY READ THE LOG TO DECIDE ANYTHING: game code may only call note(), trim() and clear(). rows(), counts(), story()
## and write() are for tests, tools and screens that show the log. A test checks this (tests/core/test_logbook.gd).
##
## Every piece of the rebuilt economy writes here when it decides or does something. A decision with no row is a fault.

## How many months back rows are kept, besides the current month. 0 = everything (tests, tools). The game sets a number
## from its first month; a long test game that writes a row per sale should set one too, or it holds millions of rows.
static var keep_months := 0


## Write one row.
## kind: a short word in capitals (RULE, SALE, HIRE, LAYOFF, PLAN, QUOTE, CONTRACT, WORK, PAY, OPEN, LOAN, END, ...).
## who: the id of the company, household pool, plan, bank or government the row is about.
## what: what happened, as a short code (for a rule: "R1 raise price").
## why: the numbers it read. change: what it changed, as {name: [from, to]}.
## with: the other party, if there is one (the builder on a plan's row, the buyer on a seller's row).
## ref: the record the row is about, if there is one (a contract id, a plan id, a loan id). The row that opens a
##      company carries the plan's id as ref and the new company's id as who, so a plan can be followed into its company.
static func note(world: WorldState, kind: String, who: String, what: String, why: Dictionary = {}, change: Dictionary = {}, with: String = "", ref: String = "") -> void:
	world.log_rows.append({"m": world.month, "phase": world.current_phase, "kind": kind, "who": who, "with": with, "ref": ref,
		"what": what, "why": why.duplicate(true), "change": change.duplicate(true)})


static func _match(r: Dictionary, filter: Dictionary) -> bool:
	if filter.has("kind") and String(r["kind"]) != String(filter["kind"]):
		return false
	if filter.has("who") and String(r["who"]) != String(filter["who"]):
		return false
	if filter.has("party") and String(r["who"]) != String(filter["party"]) and String(r["with"]) != String(filter["party"]):
		return false
	if filter.has("ref") and String(r["ref"]) != String(filter["ref"]):
		return false
	if filter.has("what") and String(r["what"]) != String(filter["what"]):
		return false
	if filter.has("what_has") and not String(r["what"]).contains(String(filter["what_has"])):
		return false
	if filter.has("from") and int(r["m"]) < int(filter["from"]):
		return false
	if filter.has("to") and int(r["m"]) > int(filter["to"]):
		return false
	return true


## Copies of the rows that match, oldest first. A reader cannot change the log through them.
## filter keys, all optional: kind, who, party (who OR with), ref, what (exact), what_has (text inside what), from, to (months).
static func rows(world: WorldState, filter: Dictionary = {}) -> Array:
	var out: Array = []
	for r in world.log_rows:
		if _match(r, filter):
			out.append((r as Dictionary).duplicate(true))
	return out


## How many rows of each kind and what: {"KIND what": n}. For a first look at a game.
static func counts(world: WorldState, filter: Dictionary = {}) -> Dictionary:
	var out := {}
	for r in world.log_rows:
		if _match(r, filter):
			var k := "%s %s" % [String(r["kind"]), String(r["what"])]
			out[k] = int(out.get(k, 0)) + 1
	return out


## Everything one company, plan, pool or other id took part in, on either side of a deal, oldest first, as text.
static func story(world: WorldState, id: String) -> PackedStringArray:
	var out := PackedStringArray()
	for r in world.log_rows:
		if _match(r, {"party": id}):
			out.append("m%d %s %s%s%s  why %s  change %s" % [int(r["m"]), String(r["kind"]), String(r["what"]),
				(" [%s with %s]" % [String(r["who"]), String(r["with"])]) if String(r["with"]) != "" else "",
				(" ref %s" % String(r["ref"])) if String(r["ref"]) != "" else "",
				JSON.stringify(r["why"]), JSON.stringify(r["change"])])
	return out


## Writes the matching rows to a file, one JSON object per line. Returns how many rows (-1 if the file could not be opened).
static func write(world: WorldState, path: String, filter: Dictionary = {}) -> int:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return -1
	var n := 0
	for r in world.log_rows:
		if _match(r, filter):
			f.store_line(JSON.stringify(r))
			n += 1
	f.close()
	return n


## Drops every row older than keep_months before the current month (nothing when keep_months is 0). The game calls it
## once a month. It does not depend on the rows being in month order.
static func trim(world: WorldState) -> void:
	if keep_months <= 0:
		return
	var first := world.month - keep_months
	world.log_rows = world.log_rows.filter(func(r): return int(r["m"]) >= first)


static func clear(world: WorldState) -> void:
	world.log_rows = []

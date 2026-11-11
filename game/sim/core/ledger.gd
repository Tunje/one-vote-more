class_name Ledger
extends RefCounted
## Money ledger (economic-simulator.md §19 Rule 4: every transfer has a source and a destination).
## All amounts are ints in milli-credits (1 credit = 1000).
## Money can only enter or leave the colony via the EXTERNAL account (origin civilization / lender, DECISIONS A6),
## so the sum of all balances is always exactly 0. That is the conservation invariant.
## Owner after M1: agent 88 (economy).

const EXTERNAL := "EXTERNAL"
const SCALE := 1000

var balances: Dictionary = {}       # account_id -> int
var allow_negative: Dictionary = {} # account_id -> bool
var journal: Array = []             # [{m, from, to, amt, memo}]


func _init() -> void:
	open_account(EXTERNAL, true)


func open_account(account_id: String, may_go_negative: bool = false) -> void:
	assert(not balances.has(account_id), "account exists: " + account_id)
	balances[account_id] = 0
	allow_negative[account_id] = may_go_negative


func has_account(account_id: String) -> bool:
	return balances.has(account_id)


func balance(account_id: String) -> int:
	return balances[account_id]


## Returns false (and changes nothing) if the payer would go negative without permission.
func transfer(from_id: String, to_id: String, amount: int, memo: String, month: int) -> bool:
	assert(amount >= 0, "negative transfer")
	assert(balances.has(from_id) and balances.has(to_id), "unknown account %s/%s" % [from_id, to_id])
	if amount == 0:
		return true
	if not allow_negative[from_id] and balances[from_id] < amount:
		return false
	balances[from_id] -= amount
	balances[to_id] += amount
	journal.append({"m": month, "from": from_id, "to": to_id, "amt": amount, "memo": memo})
	return true


## Conservation check: must always be 0.
func total() -> int:
	var t := 0
	for a in balances:
		t += balances[a]
	return t


## Drop journal entries older than keep_months (balances are unaffected).
func compact(current_month: int, keep_months: int = 24) -> void:
	var cutoff := current_month - keep_months
	journal = journal.filter(func(e): return e["m"] > cutoff)


func to_dict() -> Dictionary:
	return {"balances": balances.duplicate(), "allow_negative": allow_negative.duplicate(), "journal": journal.duplicate(true)}


static func from_dict(d: Dictionary) -> Ledger:
	var l := Ledger.new()
	l.balances = d["balances"].duplicate()
	l.allow_negative = d["allow_negative"].duplicate()
	l.journal = d["journal"].duplicate(true)
	return l

class_name EconUnfinished
extends RefCounted
## E169 (user via Wilma: "half-built buildings should be able to be repurposed to a new company"; design Bob, agreed by
## Wilma; built by Otto, planning/design-e166-e169.md). OPT-IN "E169". Off → nothing here runs (every hook tests active()).
##
## A project for a new plant that is ended with work done (a plan abandoned, a builder walking off an unpaid private job,
## the government cancelling a public job) leaves an UNFINISHED building instead of nothing:
##   world.table("unfinished")[uid] = {type, district, wu_done, wu_total, mat_total, comp_total, min_months, book (paid to
##   the builder), bank_cap (what the bank wrote off on it), rest (the account that gets the rest), since}.
## A new plant project (EconConstruction.create) in the same district takes it over first:
##   same use: same type and size, all work counts, for SAME_PRICE_PM of book;
##   repurposed: another type, half the work done counts (capped at half the new plant's work) if that is worth at least
##   REPURPOSE_MIN_M months of a standard builder crew, for REPURPOSE_PRICE_PM of book.
## The owner pays the holder (the bank first, up to its write-off; the rest to the founder household / owner firm /
## treasury); the project is tendered for the remaining work only; the plant's book adds the price paid. Unsold after
## DECAY_M months it is written off for good.

const S := EconUtil.S
const SAME_PRICE_PM := 600
const REPURPOSE_PRICE_PM := 300
const REPURPOSE_MIN_M := 3
const DECAY_M := 60


static func active(world: WorldState) -> bool:
	return (world.meta.get("on", []) as Array).has("E169") and not EconUtil.off(world, "E169")


static func eligible(p: Dictionary) -> bool:
	return EconData.BUILD.has(p["type"]) and p["type"] != "ROAD" and not p.has("link") and not p.has("target")


static func _stat(world: WorldState, key: String, n: int) -> void:
	var s := EconUtil.st(world)
	var r: Dictionary = s.get("e169_stats", {})
	r[key] = int(r.get(key, 0)) + n
	s["e169_stats"] = r


## A project is ended with work done: leave the building. holder_rest = the account that is paid (after the bank's
## claim of bank_cap). Returns the unfinished id ("" when nothing is left).
static func leave(world: WorldState, p: Dictionary, holder_rest: String, bank_cap: int = 0) -> String:
	if not active(world) or not eligible(p) or int(p["wu_done"]) < S:
		return ""
	var c: String = p.get("contractor", "")
	if c != "" and world.table("org").has(c):
		(world.table("org")[c]["contracts"] as Array).erase(p["id"])
	var id := world.new_id("unf")
	world.table("unfinished")[id] = {"id": id, "type": p["type"], "district": p["district"], "wu_done": int(p["wu_done"]),
		"wu_total": int(p["wu_total"]), "mat_total": int(p["mat_total"]), "comp_total": int(p["comp_total"]),
		"min_months": int(p["min_months"]), "book": int(p["paid"]), "bank_cap": maxi(0, bank_cap), "rest": holder_rest,
		"since": world.month, "from_project": p["id"]}
	_stat(world, "left", 1)
	EconFacts.emit(world, "ECON_UNFINISHED_LEFT", p["district"], [["COMPANY" if p["owner"] != "gov" else "GOVERNMENT", p["owner"]]],
		[["COMPANY", p["owner"], 1.0]] if p["owner"] != "gov" else [["GOVERNMENT", "government", 1.0]], {}, 10, "PUBLIC",
		{"unfinished": id, "type": p["type"], "work_done_pm": int(p["wu_done"]) * 1000 / maxi(1, int(p["wu_total"])), "book": int(p["paid"]) / S})
	return id


## Monthly: decay the ones unsold for DECAY_M months.
static func monthly(world: WorldState) -> void:
	if not active(world):
		return
	var t := world.table("unfinished")
	for id in EconUtil.sorted_keys(t):
		if world.month - int(t[id]["since"]) >= DECAY_M:
			_stat(world, "decayed", 1)
			t.erase(id)


## The best unfinished building a new project of `ftype` / `wu_total` in `district` could take over: [id, credit_wu,
## price, kind] or [] (pure).
static func match(world: WorldState, ftype: String, district: String, wu_total: int) -> Array:
	var best: Array = []
	var month_wu := EconConstruction.entrant_year(world) / 12
	for id in EconUtil.sorted_keys(world.peek("unfinished")):
		var u: Dictionary = world.peek("unfinished")[id]
		if u["district"] != district:
			continue
		if u["type"] == ftype and int(u["wu_total"]) == wu_total:
			return [id, mini(int(u["wu_done"]), wu_total - S), int(u["book"]) * SAME_PRICE_PM / 1000, "same"]
		if best.is_empty():
			var credit := mini(int(u["wu_done"]) / 2, wu_total / 2)
			if credit >= REPURPOSE_MIN_M * month_wu:
				best = [id, credit, int(u["book"]) * REPURPOSE_PRICE_PM / 1000, "repurpose"]
	return best


## Called at the end of EconConstruction.create for a new plant project: take over a matching unfinished building.
static func try_take(world: WorldState, p: Dictionary) -> bool:
	if not active(world) or not eligible(p) or p.has("size_pm"):
		return false
	var m := match(world, p["type"], p["district"], int(p["wu_total"]))
	if m.is_empty():
		return false
	var price: int = int(m[2])
	var paid := 0
	# A/B 1 (2026-11-15): 7 of 11 firms' takeovers were cancelled again: the owner spent on the shell and couldn't pay
	# the builder. Take over only what the owner can carry: the shell plus the remaining work at this month's prices.
	var rem_est := _remaining_estimate(world, p, int(m[1]))
	if p["owner"] == "gov":
		if String(p.get("line", "")) != "" and EconActions.headroom(world, p["line"]) < price:
			return false
		if price > 0:
			paid = _pay_holder(world, EconUtil.TREASURY, world.table("unfinished")[m[0]], price, true)
			if String(p.get("line", "")) != "":
				EconFinance._spend_line(world, p["line"], paid)
	else:
		var o: Dictionary = world.table("org").get(p["owner"], {})
		if o.is_empty():
			return false
		var acc := EconUtil.acct(p["owner"])
		if world.ledger.balance(acc) + int(o.get("plan_credit", 0)) < price + rem_est:
			return false
		EconInsolvency.draw_plan_credit(world, p["owner"], price)
		if world.ledger.balance(acc) < price:
			return false
		paid = _pay_holder(world, acc, world.table("unfinished")[m[0]], price, false)
	var u: Dictionary = world.table("unfinished")[m[0]]
	var credit: int = int(m[1])
	var rem := float(int(p["wu_total"]) - credit) / float(maxi(1, int(p["wu_total"])))
	var saved := credit * int(p["min_months"]) / maxi(1, int(p["wu_total"]))
	p["wu_total"] = int(p["wu_total"]) - credit
	p["mat_total"] = int(float(p["mat_total"]) * rem)
	p["comp_total"] = int(float(p["comp_total"]) * rem)
	p["min_months"] = maxi(1, int(ceil(float(p["min_months"]) * rem)))
	p["est_cost"] = int(float(p["est_cost"]) * rem)
	p["book_carry"] = paid
	p["took_over"] = m[0]
	p["size_class"] = EconConstruction.size_class(int(p["wu_total"]) / S)
	_stat(world, "taken_" + String(m[3]), 1)
	_stat(world, "months_saved", saved)
	EconFacts.emit(world, "ECON_UNFINISHED_TAKEN", p["district"], [["COMPANY" if p["owner"] != "gov" else "GOVERNMENT", p["owner"]]],
		[["COMPANY", p["owner"], 1.0]] if p["owner"] != "gov" else [["GOVERNMENT", "government", 1.0]], {"INFRASTRUCTURE": 1}, 15, "PUBLIC",
		{"unfinished": m[0], "from_type": u["type"], "to_type": p["type"], "kind": m[3], "price": paid / S, "project": p["id"]})
	world.table("unfinished").erase(m[0])
	return true


## Pay `amount` from `from_acct` to the holder: the bank first up to its write-off, the rest to `rest`. Returns paid.
static func _pay_holder(world: WorldState, from_acct: String, u: Dictionary, amount: int, gov: bool) -> int:
	var to_bank := mini(amount, int(u["bank_cap"]))
	var paid := 0
	if to_bank > 0:
		var b := EconFinance.gov_pay(world, EconUtil.BANK, to_bank, "UNFINISHED_SALE") if gov else EconUtil.pay_upto(world, from_acct, EconUtil.BANK, to_bank, "UNFINISHED_SALE")
		paid += b
		_stat(world, "bank_recovered", b)
	var rest := amount - to_bank
	if rest > 0:
		var to := _live_holder(world, String(u["rest"]))
		var r := 0
		if to == EconUtil.TREASURY and gov:
			r = rest  # the government buys back its own building: no money moves
		else:
			r = EconFinance.gov_pay(world, to, rest, "UNFINISHED_SALE") if gov else EconUtil.pay_upto(world, from_acct, to, rest, "UNFINISHED_SALE")
		paid += r
		_stat(world, "paid_rest", r)
	return paid


## The holder firm may have died since (A/B 1: shell prices paid into dead firms' accounts left circulation): its part
## goes to its owner household, or the treasury.
static func _live_holder(world: WorldState, to: String) -> String:
	if not to.begins_with("co:"):
		return to
	var o: Dictionary = world.table("org").get(to.substr(3), {})
	if not o.is_empty() and o["status"] in ["ACTIVE", "DISTRESSED", "ADMINISTRATION", "FORMING"]:
		return to
	if not o.is_empty() and String(o.get("owner_group", "")) != "" and world.table("hh").has(o["owner_group"]):
		return EconUtil.hh_acct(o["owner_group"])
	return EconUtil.TREASURY


## The owner's estimate of the work left after a takeover crediting `credit` work units (this month's prices).
static func _remaining_estimate(world: WorldState, p: Dictionary, credit: int) -> int:
	var full := EconBuilders.owner_estimate(world, p)
	return int(float(full) * float(int(p["wu_total"]) - credit) / float(maxi(1, int(p["wu_total"]))))


## Pure query for UI / gov_builder: the unfinished buildings on the market.
static func on_market(world: WorldState) -> Array:
	var out: Array = []
	for id in EconUtil.sorted_keys(world.peek("unfinished")):
		var u: Dictionary = world.peek("unfinished")[id]
		out.append({"id": id, "type": u["type"], "district": u["district"], "work_done_pm": int(u["wu_done"]) * 1000 / maxi(1, int(u["wu_total"])),
			"book": int(u["book"]), "same_price": int(u["book"]) * SAME_PRICE_PM / 1000, "months": world.month - int(u["since"])})
	return out

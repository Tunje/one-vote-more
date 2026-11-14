extends TestCase
## E148 supplier credit (EconCredit, opt-in "E148"): firm-to-firm purchases on account, paid a month later.
const SAVE_PATH := "user://test_credit_save.json"


func _firm(w: WorldState, kind: String = "PRIVATE") -> String:
	for oid in EconUtil.sorted_keys(w.table("org")):
		var o: Dictionary = w.table("org")[oid]
		if o["type"] == kind and o["status"] == "ACTIVE" and EconAnnual.months(o) > 0 and EconAnnual.avg_rev(o) > 0:
			return oid
	return ""


func test_off_by_default() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.run(6)
	check(sim.world.peek("invoice").is_empty(), "no invoices unless E148 is on")


func test_invoice_room_and_payment() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["E148"]
	sim.run(4)
	var buyer := _firm(w)
	var seller := ""
	for oid in EconUtil.sorted_keys(w.table("org")):
		if oid != buyer and EconCredit.trades_on_account(w, oid):
			seller = oid
			break
	check(buyer != "" and seller != "", "two firms")
	var owed0 := EconCredit.owed(w, buyer)  # invoices from its real trade so far
	var r0 := EconCredit.room(w, buyer)
	check(r0 > 0, "credit room from 12-month sales (%d)" % (r0 / EconUtil.S))
	var got := EconCredit.invoice(w, buyer, seller, r0 * 2)
	check_eq(got, r0, "invoiced up to the room only")
	check_eq(EconCredit.room(w, buyer), 0, "room used up")
	check_eq(EconCredit.owed(w, buyer), owed0 + r0, "owed")
	# due next month: pay it (fund the buyer so it can)
	w.ledger.transfer(Ledger.EXTERNAL, EconUtil.acct(buyer), owed0 + r0, "TEST", w.month)
	w.month += 1
	EconCredit.settle(w)
	check_eq(EconCredit.owed(w, buyer), 0, "paid when due")
	check_eq(w.ledger.total(), 0, "ledger closed")


func test_unpaid_is_missed_and_dead_written_off() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["E148"]
	sim.run(4)
	var buyer := _firm(w)
	var seller := ""
	for oid in EconUtil.sorted_keys(w.table("org")):
		if oid != buyer and EconCredit.trades_on_account(w, oid):
			seller = oid
			break
	var owed0 := EconCredit.owed(w, buyer)
	var amt := EconCredit.invoice(w, buyer, seller, EconCredit.room(w, buyer))
	EconUtil.pay_upto(w, EconUtil.acct(buyer), Ledger.EXTERNAL, w.ledger.balance(EconUtil.acct(buyer)), "TEST")
	w.table("org")[buyer]["missed_this_month"] = false
	w.month += 1
	EconCredit.settle(w)
	check(bool(w.table("org")[buyer]["missed_this_month"]), "an unpaid invoice is a missed payment")
	check_eq(EconCredit.owed(w, buyer), owed0 + amt, "still owed")
	w.table("org")[buyer]["status"] = "LIQUIDATION"
	var rev0 := int(w.table("org")[seller]["pl"].get("rev", 0))
	EconCredit.settle(w)
	check_eq(EconCredit.owed(w, buyer), 0, "a dead buyer's invoice is written off")
	check(int(w.table("org")[seller]["pl"].get("rev", 0)) <= rev0 - amt, "the seller books the bad debt")
	check_eq(w.ledger.total(), 0, "ledger closed")


func test_run_closes_and_saves() -> void:
	var ref := EconSim.make_econ_only(7)
	ref.world.meta["on"] = ["E148"]
	ref.run(14)
	check(not ref.world.peek("invoice").is_empty(), "invoices in use")
	check_eq(ref.world.ledger.total(), 0, "ledger closed")
	check(EconPop.check(ref.world).is_empty(), "jobs equal people")
	check_eq(SaveIO.save(ref, SAVE_PATH), OK, "save")
	ref.run(6)
	var loaded := EconSim.econ_only_for_load()
	check_eq(SaveIO.load_into(loaded, SAVE_PATH), OK, "load")
	loaded.run(6)
	check_eq(loaded.world.state_hash(), ref.world.state_hash(), "continued state hash (save/load pure)")

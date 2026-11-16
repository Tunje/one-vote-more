extends TestCase
## Rule 5 for material as the user stated it (2026-11-16): "if your selling out and all plants at max build a new one
## ... and of course money is a limitor". No windows, no price test, no size limit.

const S := EconUtil.S


func _setup() -> Array:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["R8", "R8_MATERIAL"]
	sim.run(2)
	var oid := ""
	for fid in EconUtil.sorted_keys(w.table("facility")):
		var f: Dictionary = w.table("facility")[fid]
		if f["type"] == "PROCESSING":
			oid = String(f["org"])
			f["target"] = 1000
			f["mothball"] = false
	return [w, oid]


func _projects(w: WorldState, oid: String) -> int:
	var n := 0
	for pid in w.table("project"):
		var p: Dictionary = w.table("project")[pid]
		if p["type"] == "PROCESSING" and p["owner"] == oid:
			n += 1
	return n


func _sold_out(w: WorldState, oid: String, cash: int) -> void:
	var o: Dictionary = w.table("org")[oid]
	o["sold"] = {"MATERIAL": 100 * S}
	EconUtil.st(w)["unsold_px_by"] = {}
	var acct := EconUtil.acct(oid)
	var bal := w.ledger.balance(acct)
	if bal > cash:
		w.ledger.transfer(acct, Ledger.EXTERNAL, bal - cash, "TEST", w.month)
	elif bal < cash:
		w.ledger.transfer(Ledger.EXTERNAL, acct, cash - bal, "TEST", w.month)


func test_sold_out_at_full_output_builds_a_new_plant() -> void:
	var r := _setup()
	var w: WorldState = r[0]
	var oid: String = r[1]
	if oid == "":
		check(false, "a processing plant exists")
		return
	var n0 := _projects(w, oid)
	_sold_out(w, oid, EconConstruction.estimate("PROCESSING") * 2)
	EconRulesMat.capacity(w)
	check_eq(_projects(w, oid), n0 + 1, "sold everything, every plant at full: one more plant is ordered, in the first quarter")


func test_unsold_stock_or_a_plant_with_room_builds_nothing() -> void:
	var r := _setup()
	var w: WorldState = r[0]
	var oid: String = r[1]
	var n0 := _projects(w, oid)
	_sold_out(w, oid, EconConstruction.estimate("PROCESSING") * 2)
	EconUtil.st(w)["unsold_px_by"] = {oid + "|MATERIAL": 10 * S}
	EconRulesMat.capacity(w)
	check_eq(_projects(w, oid), n0, "it did not sell out: nothing is built")
	_sold_out(w, oid, EconConstruction.estimate("PROCESSING") * 2)
	for fid in w.table("facility"):
		var f: Dictionary = w.table("facility")[fid]
		if f["type"] == "PROCESSING" and f["org"] == oid:
			f["target"] = 600
			break
	EconRulesMat.capacity(w)
	check_eq(_projects(w, oid), n0, "a plant of its own has room: it makes more there first, no new plant")


func test_money_is_the_limiter() -> void:
	var r := _setup()
	var w: WorldState = r[0]
	var oid: String = r[1]
	if w.table("org")[oid]["type"] == "PUBLIC_ENTERPRISE":
		return  # a public company may be paid by the treasury; the private case is the test
	var n0 := _projects(w, oid)
	_sold_out(w, oid, 0)
	EconRulesMat.capacity(w)
	check_eq(_projects(w, oid), n0, "sold out, at full, and no money: nothing is built")

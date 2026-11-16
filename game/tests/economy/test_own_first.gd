extends TestCase
## OWN_FIRST: a producer keeps back from its sale offer what its own plants need of the good (inputs and upkeep), so
## the material chain's own plants are kept up (Otto's trace: they decayed while their owner sold all it made).

var SAVE_PATH: String = TestCase.save_path("own_first.sav")
const S := EconUtil.S


func _sim(extra: Array, months: int) -> Simulation:
	var sim := EconSim.make_econ_only(3)
	var on: Array = EconSim.DEFAULT_ON.duplicate()
	on.append_array(extra)
	sim.world.meta["on"] = on
	sim.run(months)
	return sim


## The processing plant's owner, its district, and what it offers of MATERIAL there when it holds `stock`.
func _offered(w: WorldState, stock: int) -> Array:
	var fid := ""
	for f_id in EconUtil.sorted_keys(w.table("facility")):
		var f: Dictionary = w.table("facility")[f_id]
		if f["type"] == "PROCESSING" and not f["mothball"]:
			fid = f_id
			break
	if fid == "":
		return []
	var f: Dictionary = w.table("facility")[fid]
	var oid: String = f["org"]
	var d: String = f["district"]
	var have := EconUtil.inv_get(w, oid, "MATERIAL", d)
	if have > 0:
		EconUtil.inv_take(w, oid, "MATERIAL", d, have)
	EconUtil.inv_add(w, oid, "MATERIAL", d, stock, 300 * S)
	var s := EconUtil.st(w)
	s["orders"] = []
	s["offers"] = []
	FirmAI._post_inputs_and_offers(w)
	var q := 0
	for o in s["offers"]:
		if o["seller"] == oid and o["good"] == "MATERIAL" and o["district"] == d:
			q += int(o["qty"])
	var upkeep := int(float(EconData.RECIPES["PROCESSING"]["upkeep"]) * S * EconUtil.fscale(f))
	return [q, upkeep]


func test_off_the_whole_stock_is_offered() -> void:
	var sim := _sim([], 6)
	var r := _offered(sim.world, 1000 * S)
	if r.is_empty():
		check(false, "a processing plant runs")
		return
	check_eq(int(r[0]), 1000 * S, "everything on offer, as before")


func test_on_the_owner_keeps_its_own_plants_upkeep_back() -> void:
	var sim := _sim(["OWN_FIRST"], 6)
	var r := _offered(sim.world, 1000 * S)
	if r.is_empty():
		check(false, "a processing plant runs")
		return
	check(int(r[0]) <= 1000 * S - int(r[1]), "at least its plant's upkeep is kept back (offered %d of %d)" % [int(r[0]) / S, 1000])
	check(int(r[0]) > 0, "the rest is still sold")
	var r2 := _offered(sim.world, int(r[1]) / 2)
	check_eq(int(r2[0]), 0, "less than its own need: nothing offered")


func test_the_chain_keeps_its_condition() -> void:
	var sim := _sim(["OWN_FIRST"], 72)
	var low := 100 * S
	for fid in sim.world.table("facility"):
		var f: Dictionary = sim.world.table("facility")[fid]
		if f["type"] in ["MINE", "PROCESSING", "COMPONENTS"] and not f["mothball"]:
			low = mini(low, int(f["condition"]))
	check(low >= 90 * S, "after six years every open chain plant is at condition ≥ 90 (lowest %d)" % [low / S])
	check_eq(sim.world.ledger.total(), 0, "ledger closed")
	check(EconPop.check(sim.world).is_empty(), "jobs equal people")


func test_save_load_identical() -> void:
	var ref := _sim(["OWN_FIRST"], 14)
	check_eq(SaveIO.save(ref, SAVE_PATH), OK, "save")
	ref.run(10)
	var loaded := EconSim.econ_only_for_load()
	check_eq(SaveIO.load_into(loaded, SAVE_PATH), OK, "load")
	loaded.run(10)
	check_eq(loaded.world.state_hash(), ref.world.state_hash(), "continued state hash")

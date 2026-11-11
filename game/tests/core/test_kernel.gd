extends TestCase
## M1 exit criteria: deterministic months, save -> load -> continue identical, conservation, fact rules.

const NoiseProvider := preload("res://tests/support/noise_provider.gd")
var SAVE_PATH := save_path("kernel.sav")


func _sim(seed_value: int) -> Simulation:
	var s := Simulation.new(seed_value, [NoiseProvider.new()])
	s.new_game()
	return s


func test_same_seed_same_state_after_100_months() -> void:
	var a := _sim(42)
	var b := _sim(42)
	a.run(100)
	b.run(100)
	check_eq(a.world.month, 100, "month")
	check_eq(a.world.state_hash(), b.world.state_hash(), "state hash")


func test_different_seed_diverges() -> void:
	var a := _sim(1)
	var b := _sim(2)
	a.run(24)
	b.run(24)
	check(a.world.state_hash() != b.world.state_hash(), "different seeds should diverge")


func test_save_load_continue_identical() -> void:
	var ref := _sim(7)
	ref.run(30)
	check_eq(SaveIO.save(ref, SAVE_PATH), OK, "save")
	ref.run(30)

	var loaded := Simulation.new(999, [NoiseProvider.new()])  # seed is overwritten by the save
	check_eq(SaveIO.load_into(loaded, SAVE_PATH), OK, "load")
	check_eq(loaded.world.month, 30, "loaded month")
	loaded.run(30)
	check_eq(loaded.world.state_hash(), ref.world.state_hash(), "continued state hash")


func test_table_order_survives_save_load() -> void:
	var s := _sim(9)
	var t := s.world.table("thing")
	for k in ["thing:10", "thing:2", "zeta", "alpha", "thing:1"]:
		t[k] = {"b": 1, "a": 2}
	check_eq(SaveIO.save(s, save_path("order.sav")), OK, "save")
	var l := Simulation.new(0, [NoiseProvider.new()])
	check_eq(SaveIO.load_into(l, save_path("order.sav")), OK, "load")
	check_eq(l.world.table("thing").keys(), ["thing:10", "thing:2", "zeta", "alpha", "thing:1"], "table key order")
	check_eq(l.world.table("thing")["thing:2"].keys(), ["b", "a"], "nested key order")


func test_peek_does_not_create_tables() -> void:
	var s := _sim(4)
	var h := s.world.state_hash()
	check(s.world.peek("nonexistent").is_empty(), "empty")
	check_eq(s.world.state_hash(), h, "peek must not change state")


func test_money_conserved() -> void:
	var s := _sim(3)
	s.run(120)
	check_eq(s.world.ledger.total(), 0, "ledger total")
	check(not s.world.meta.has("violations"), "no violations: %s" % [s.world.meta.get("violations", [])])


func test_ledger_refuses_overdraft() -> void:
	var l := Ledger.new()
	l.open_account("a")
	l.open_account("b")
	check(not l.transfer("a", "b", 5, "x", 0), "overdraft must fail")
	check_eq(l.balance("a"), 0, "unchanged")
	check(l.transfer(Ledger.EXTERNAL, "a", 5, "mint", 0), "external may go negative")
	check_eq(l.total(), 0, "conserved")


func test_rng_stream_independent_of_creation_order() -> void:
	var a := RngStreams.new(5)
	var b := RngStreams.new(5)
	a.stream("x"); a.stream("y")
	b.stream("y"); b.stream("x")
	check_eq(a.stream("y").randi(), b.stream("y").randi(), "stream y")


func test_facts_immutable_and_reveal() -> void:
	var fs := FactStore.new()
	var id := fs.add(3, {"type": "LAW_BRIBE", "owner": "law", "subjects": [], "magnitude": 70,
		"responsible": [{"actor": {"kind": "OFFICIAL", "id": "p:1"}, "share": 1.0}],
		"impact": {"GOVERNANCE": -30}, "visibility": "SECRET"})
	check(fs.get_fact(id).is_read_only(), "fact read-only")
	var rid := fs.reveal(9, id, [{"kind": "INSTITUTION", "id": "audit"}])
	var r := fs.get_fact(rid)
	check_eq(r["type"], "LAW_BRIBE_REVEALED", "type")
	check_eq(r["visibility"], "PUBLIC", "visibility")
	check_eq(r["month"], 9, "reveal month")
	check_eq(fs.explain(rid).size(), 1, "explain chain")


func test_fact_compaction_keeps_causes_and_big_facts() -> void:
	var fs := FactStore.new()
	var base := {"owner": "stub", "subjects": [], "responsible": [], "impact": {}, "visibility": "PUBLIC"}
	var small := base.duplicate(); small["type"] = "S"; small["magnitude"] = 5
	var big := base.duplicate(); big["type"] = "B"; big["magnitude"] = 80
	var cause := base.duplicate(); cause["type"] = "C"; cause["magnitude"] = 5
	var s_id := fs.add(0, small)
	var b_id := fs.add(0, big)
	var c_id := fs.add(0, cause)
	var child := base.duplicate(); child["type"] = "K"; child["magnitude"] = 50; child["causes"] = [c_id]
	fs.add(40, child)
	fs.compact(40)
	check(fs.get_fact(s_id).is_empty(), "small old fact compacted")
	check(not fs.get_fact(b_id).is_empty(), "big fact kept")
	check(not fs.get_fact(c_id).is_empty(), "referenced cause kept")
	check_eq(fs.aggregates.get("0|S", 0), 1, "aggregate count")


func test_levers_registered_with_defaults() -> void:
	var s := _sim(1)
	check_eq(s.world.levers.get("STUB_RATE"), 10, "lever default")

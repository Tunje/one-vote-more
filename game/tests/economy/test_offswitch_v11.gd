extends TestCase
## Re-evaluation of the switched-off systems (user 2026-11-16, planning/reeval-off-switches.md), desk review step 1:
## each of Otto's switches on top of the v11 defaults (EconSim.DEFAULT_ON) is really read (the run differs from the
## same seed without it, and its own counters move), and the run stays closed (ledger, jobs = people).

const MONTHS := 48


func _run(extra: Array) -> WorldState:
	var sim := EconSim.make_econ_only(1)
	var on: Array = EconSim.DEFAULT_ON.duplicate()
	for f in extra:
		if not on.has(f):
			on.append(f)
	sim.world.meta["on"] = on
	sim.run(MONTHS)
	return sim.world


## Changes whenever the economy takes a different path: firms by status, cash of every firm.
func _print(w: WorldState) -> String:
	var parts := []
	for oid in EconUtil.sorted_keys(w.table("org")):
		var o: Dictionary = w.table("org")[oid]
		parts.append("%s:%s:%d" % [oid, o["status"], w.ledger.balance(EconUtil.acct(oid))])
	return ",".join(parts)


func _case(label: String, base_extra: Array, flag: String, stats_key: String) -> void:
	var a := _run(base_extra)
	var b := _run(base_extra + [flag])
	check_eq(b.ledger.total(), 0, label + ": ledger closed")
	check(EconPop.check(b).is_empty(), label + ": jobs equal people")
	check(_print(a) != _print(b), label + ": the switch is read on v11 (the run differs)")
	var st: Dictionary = EconUtil.st(b).get(stats_key, {}) if stats_key != "" else {}
	if stats_key != "":
		check(not st.is_empty(), label + ": its counters move (" + stats_key + ")")
	print("  %s: orgs %d -> %d; %s %s" % [label, a.table("org").size(), b.table("org").size(), stats_key, str(st)])


func test_e165_plans() -> void:
	_case("E165", [], "E165", "plan_stats")


func test_e165b_plan_credit() -> void:
	_case("E165B", ["E165"], "E165B", "plan_stats")


func test_e165q_order_book() -> void:
	_case("E165Q", ["E165", "E165B"], "E165Q", "")


func test_e155bld_builders() -> void:
	_case("E155BLD", ["E165", "E165B"], "E155BLD", "")


func test_e166_rescues() -> void:
	_case("E166", ["E165", "E165B"], "E166", "rescue_stats")


func test_e169_shells() -> void:
	_case("E169", ["E165", "E165B"], "E169", "e169_stats")


func test_r8_builders() -> void:
	_case("R8_BUILDERS", [], "R8_BUILDERS", "r8b_stats")


func test_r8_housing() -> void:
	_case("R8_HOUSING", [], "R8_HOUSING", "r8h_stats")

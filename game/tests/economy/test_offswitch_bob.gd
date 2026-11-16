extends TestCase
## Re-evaluation of the switched-off systems (user 2026-11-16, planning/reeval-off-switches.md), desk review step 1:
## each of Bob's switches on top of the v11 defaults (EconSim.DEFAULT_ON), with the switches it needs, is really read
## (the run differs from the same seed without it) and the run stays closed (ledger, jobs = people). E151 and E171
## live in the legislature and the charter law, which the economy-only game does not run: they use the full game.

const MONTHS := 48
const FULL_MONTHS := 36


func _run(extra: Array, full: bool) -> WorldState:
	var on: Array = EconSim.DEFAULT_ON.duplicate()
	for f in extra:
		if not on.has(f):
			on.append(f)
	var sim: Simulation = EconSim.make(1) if full else EconSim.make_econ_only(1)
	sim.world.meta["on"] = on  # the switches are read month by month, so setting them after new_game is enough
	sim.run(FULL_MONTHS if full else MONTHS)
	return sim.world


## Changes whenever the economy takes a different path: firms by status, cash of every firm.
func _print(w: WorldState) -> String:
	var parts := []
	for oid in EconUtil.sorted_keys(w.table("org")):
		var o: Dictionary = w.table("org")[oid]
		parts.append("%s:%s:%d" % [oid, o["status"], w.ledger.balance(EconUtil.acct(oid))])
	return ",".join(parts)


func _priv_alive(w: WorldState) -> int:
	var n := 0
	for oid in w.table("org"):
		var o: Dictionary = w.table("org")[oid]
		if o["type"] == "PRIVATE" and o["status"] in ["ACTIVE", "DISTRESSED"]:
			n += 1
	return n


## inert: a switch known to change nothing on this seed and span (planning/reeval-bob.md says why); the test records
## that it is still inert, so a change in the code that wakes it shows up here.
func _case(flag: String, needs: Array = [], full: bool = false, inert: bool = false) -> void:
	var a := _run(needs, full)
	var b := _run(needs + [flag], full)
	check_eq(b.ledger.total(), 0, flag + ": ledger closed")
	check(EconPop.check(b).is_empty(), flag + ": jobs equal people")
	if inert:
		check(_print(a) == _print(b), flag + ": still inert on v11 (see reeval-bob.md)")
	else:
		check(_print(a) != _print(b), flag + ": the switch is read on v11 (the run differs)")
	print("  %s (+%s, %s %dm): private alive %d -> %d, bank capital %dk -> %dk" % [flag, ",".join(needs),
		"full" if full else "econ", FULL_MONTHS if full else MONTHS, _priv_alive(a), _priv_alive(b),
		EconBank.capital(a) / EconUtil.S / 1000, EconBank.capital(b) / EconUtil.S / 1000])


func test_e136() -> void: _case("E136")
func test_e137() -> void: _case("E137")
func test_e138() -> void: _case("E138")
func test_e139() -> void: _case("E139", [], false, true)  # E149 cost-plus (v11) overwrites its price on every good it covers
func test_e140p() -> void: _case("E140P")
func test_e143() -> void: _case("E143")
func test_e150b() -> void: _case("E150B")
func test_e150c() -> void: _case("E150C")
func test_e150p() -> void: _case("E150P")
func test_e151() -> void: _case("E151", [], true)
func test_e152() -> void: _case("E152")
func test_e153() -> void: _case("E153")
func test_e155() -> void: _case("E155")
func test_e156() -> void: _case("E156")
func test_e168() -> void: _case("E168", [], false, true)  # FOOD in the 0-5% unfilled band below farm cost: not on seed 1 by month 48
func test_e171() -> void: _case("E171", [], true, true)  # nothing in the game calls CharterOps.record_delivery
func test_s7() -> void: _case("S7")
func test_s7f() -> void: _case("S7F")
func test_s7c() -> void: _case("S7C", [], false, true)  # FOOD fully supplied with surplus cover: not on seed 1 by month 48
func test_support_b() -> void: _case("SUPPORT_B")
func test_support_c() -> void: _case("SUPPORT_C")
func test_support_d() -> void: _case("SUPPORT_D")
func test_support_e() -> void: _case("SUPPORT_E")
func test_support_s() -> void: _case("SUPPORT_S")
func test_inv_expect() -> void: _case("INV_EXPECT")
func test_exp() -> void: _case("EXP")
func test_exp_port() -> void: _case("EXP_PORT", ["EXP"])
func test_exp_keep() -> void: _case("EXP_KEEP", ["EXP"])
func test_r8m_px() -> void: _case("R8M_PX")
func test_r8m_novalue() -> void: _case("R8M_NOVALUE")


## The standing rule: meta "off" wins. A switch listed in both "on" and "off" runs exactly as if it were not on.
func test_meta_off_wins() -> void:
	for f in ["E150B", "E150C", "E150P", "E156", "R8M_PX", "E155BLD", "PAYOUT", "R8_MATERIAL", "FREIGHT_ROADS"]:
		var on: Array = EconSim.DEFAULT_ON.duplicate()
		on.erase(f)
		var a := EconSim.make_econ_only(1)
		a.world.meta["on"] = on.duplicate()
		a.run(18)
		var b := EconSim.make_econ_only(1)
		b.world.meta["on"] = on + [f]
		b.world.meta["off"] = [f]
		b.run(18)
		check(_print(a.world) == _print(b.world), f + ": listed in off, it does nothing")

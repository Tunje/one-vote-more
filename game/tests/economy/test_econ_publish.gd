extends TestCase
## Rebuild step 2, what politics reads of the purse (planning/rebuild-politics-face.md; sim/economy/econ_publish.gd):
## the levers and indicators under their old names, the figures exact from the ledger, nothing in the voters' concerns
## before step 11, the same figures after a save and load, and the doorway answers step 2 fills.

const EconPublish := preload("res://sim/economy/econ_publish.gd")
var SAVE_PATH := save_path("econ_publish.sav")


func _sim() -> Simulation:
	var s := Simulation.new(5, [EconPublish.new()])
	s.new_game()
	if not s.world.ledger.has_account(CoreUtil.TREASURY):
		s.world.ledger.open_account(CoreUtil.TREASURY)
	return s


## One month: `inn` comes into the treasury from outside, `out` is paid to a household, then the month runs.
func _month(s: Simulation, inn: int, out: int) -> void:
	var w := s.world
	if not w.ledger.has_account("hh:test"):
		w.ledger.open_account("hh:test")
	if inn > 0:
		w.ledger.transfer(Ledger.EXTERNAL, CoreUtil.TREASURY, inn, "TEST_IN", w.month)
	if out > 0:
		w.ledger.transfer(CoreUtil.TREASURY, "hh:test", out, "TEST_OUT", w.month)
	s.step()


func test_the_step_2_names_are_published() -> void:
	var w := _sim().world
	for id in EconPublish.STEP2_LEVERS:
		check(w.lever_defs.has(id), "lever %s is in the lever table" % id)
		check(w.levers.has(id), "and has its starting value")
	for id in EconPublish.STEP2_INDICATORS:
		check(w.indicators.defs.has(id), "indicator %s is defined" % id)


func test_nothing_reaches_the_voters_before_step_11() -> void:
	var w := _sim().world
	for id in EconPublish.STEP2_INDICATORS:
		var d: Dictionary = w.indicators.defs[id]
		check((d["concerns"] as Dictionary).is_empty(), "%s carries no concern weight until step 11" % id)
		check(not d.has("fiscalStress") and not d.has("fiscalGuard"), "%s puts no fiscal stress or guard on the legislature yet" % id)


func test_the_figures_are_exact_from_the_ledger() -> void:
	var s := _sim()
	var w := s.world
	_month(s, 12000, 1000)
	# treasury 11000; spending 1000 a month -> 11 months; balance (12000 - 1000) / 1000 = 1100% -> the top, 100%
	check_eq(w.indicators.read("ECON_TREASURY_RUNWAY"), 11000, "runway: 11 months")
	check_eq(w.indicators.read("ECON_BUDGET_BALANCE"), 100000, "balance at the top of its range")
	check_eq(w.indicators.read("ECON_OPERATING_BALANCE"), w.indicators.read("ECON_BUDGET_BALANCE"), "no capital spending before step 8: the same figure")
	_month(s, 0, 3000)
	# treasury 8000; spending 4000 over 2 months = 2000 a month -> 4 months; balance (12000 - 4000) / 4000 = 200% -> 100%
	check_eq(w.indicators.read("ECON_TREASURY_RUNWAY"), 4000, "runway: 4 months")
	_month(s, 1000, 0)
	_month(s, 0, 8000)
	# months kept: in 13000, out 12000 over 4 months = 3000 a month; treasury 1000 -> a third of a month
	check_eq(w.indicators.read("ECON_TREASURY_RUNWAY"), 333, "runway: a third of a month")
	check_eq(w.indicators.read("ECON_BUDGET_BALANCE"), 8333, "balance: (13000 - 12000) / 12000 = 8.333%")


func test_only_the_last_twelve_months_count() -> void:
	var s := _sim()
	var w := s.world
	_month(s, 100000, 50000)   # a big first month that falls out of the window
	for i in 12:
		_month(s, 1000, 2000)
	var f: Dictionary = EconPublish.figures(w)
	check_eq(int(f["months"]), 12, "twelve months kept")
	check_eq(int(f["out_pm"]), 2000, "spending a month from the last twelve only")
	check_eq(w.indicators.read("ECON_BUDGET_BALANCE"), -50000, "balance: (12000 - 24000) / 24000 = -50%")


func test_a_treasury_that_spends_nothing_lasts() -> void:
	var s := _sim()
	_month(s, 0, 0)
	check_eq(s.world.indicators.read("ECON_TREASURY_RUNWAY"), EconPublish.RUNWAY_MAX_M * 1000, "no spending: the top of the range")
	check_eq(s.world.indicators.read("ECON_BUDGET_BALANCE"), 0, "nothing in, nothing out: balance 0")


func test_a_transfer_inside_the_purse_counts_neither_way() -> void:
	var s := _sim()
	var w := s.world
	w.ledger.open_account("gov:fines_revenue")
	w.ledger.transfer(Ledger.EXTERNAL, CoreUtil.TREASURY, 5000, "TEST_IN", w.month)
	w.ledger.transfer(CoreUtil.TREASURY, CoreUtil.TREASURY, 4000, "TEST_SELF", w.month)
	w.ledger.transfer(CoreUtil.TREASURY, "gov:fines_revenue", 1000, "TEST_MOVE", w.month)
	var f := EconPublish.month_flows(w, EconPublish.PURSE, w.month)
	check_eq(int(f["in"]), 5000, "in")
	check_eq(int(f["out"]), 0, "out")
	check_eq(EconPublish.purse_balance(w), 5000, "the purse holds both accounts together")


## Fines are paid into the law's own account (justice_ops._fine -> "gov:fines_revenue"); they are the purse's income.
func test_fines_are_income_of_the_purse() -> void:
	var s := _sim()
	var w := s.world
	w.ledger.open_account("gov:fines_revenue")
	w.ledger.open_account("co:company:1")
	w.ledger.transfer(Ledger.EXTERNAL, "co:company:1", 3000, "TEST", w.month)
	w.ledger.transfer("co:company:1", "gov:fines_revenue", 2000, "FINE", w.month)
	w.ledger.transfer(Ledger.EXTERNAL, CoreUtil.TREASURY, 2000, "TEST_IN", w.month)
	w.ledger.open_account("hh:test")
	w.ledger.transfer(CoreUtil.TREASURY, "hh:test", 1000, "TEST_OUT", w.month)
	s.step()
	# in 4000 (2000 of it fines), out 1000: purse 3000 -> 3 months; balance (4000 - 1000) / 1000 = 300% -> the top
	check_eq(w.indicators.read("ECON_TREASURY_RUNWAY"), 3000, "the fines count toward the runway")
	var f: Dictionary = EconPublish.figures(w)
	check_eq(int(f["in_pm"]), 4000, "and as income")


func test_a_loaded_game_publishes_the_same() -> void:
	var ref := _sim()
	for i in 5:
		_month(ref, 3000 * (i % 2), 1000 + 100 * i)
	check_eq(SaveIO.save(ref, SAVE_PATH), OK, "save")
	var loaded := Simulation.new(999, [EconPublish.new()])
	check_eq(SaveIO.load_into(loaded, SAVE_PATH), OK, "load")
	for i in 4:
		_month(ref, 500, 900)
		_month(loaded, 500, 900)
	for id in EconPublish.STEP2_INDICATORS:
		check_eq(loaded.world.indicators.read(id), ref.world.indicators.read(id), "%s after load" % id)
	check_eq(loaded.world.state_hash(), ref.world.state_hash(), "the same state")


func test_the_doorway_answers_step_2_fills() -> void:
	var s := _sim()
	var w := s.world
	_month(s, 12000, 1000)
	var b := EconFace.query_budget_view(w)
	check_eq(int(b["runway_months"]), 11, "the budget view shows the runway")
	check_eq(int(b["balance_pct"]), 100, "and the balance")
	check_eq(float(b["treasury"]), 11.0, "and the treasury in credits")
	check(not EconFace.running(w), "no economy is running at step 2")
	var h := w.state_hash()
	EconFace.running(w)
	check_eq(w.state_hash(), h, "asking whether there is an economy creates nothing")
	w.table("econ")["s"] = {}
	check(EconFace.running(w), "an economy's state means it runs")


func test_the_press_waits_for_an_economy_not_for_households() -> void:
	var w := _sim().world
	w.table("hh")["pool:1"] = {}   # step 2's household pools exist ...
	check(not Media._has_economy(w), "... but no wages can be paid yet, so the press's money does not run")
	w.table("econ")["s"] = {}
	check(Media._has_economy(w), "with an economy it runs")


func test_the_game_registers_it() -> void:
	var s := GameSim.make(3)
	check(s.world.indicators.defs.has("ECON_TREASURY_RUNWAY"), "the game publishes the runway")
	s.run(2)
	check(s.world.indicators.values["ECON_TREASURY_RUNWAY"].has("COLONY"), "every month")

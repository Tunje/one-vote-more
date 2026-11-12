extends TestCase
## E111: age-structured demography. Retirees die at about 1 / (life expectancy − retirement age) a year, births come
## from working-age adults, retirement follows career length (18 → retirement age), and food shortage softly brakes births.


func _status(w: WorldState, st: String) -> int:
	return PopStore.count(w, {"status": st})


func test_retirees_do_not_pile_up() -> void:
	var sim := EconSim.make_econ_only(5)
	var w := sim.world
	var r0 := _status(w, "RETIRED")
	sim.run(120)
	var r1 := _status(w, "RETIRED")
	var adults := _status(w, "EMPLOYED") + _status(w, "UNEMPLOYED") + _status(w, "NOT_IN_LF")
	# steady state ≈ working age × (LE − RA) / (RA − 18) ≈ 0.36 × working age; the founding colony starts below it
	check(float(r1) < 0.5 * float(adults), "retirees %d stay below half the working-age %d after 10 years (start %d)" % [r1, adults, r0])
	check(adults > 1200, "working-age population holds up: %d" % adults)


func test_retirement_age_lever_and_food_brake() -> void:
	var sim := EconSim.make_econ_only(5)
	var w := sim.world
	check_eq(EconHouseholds.retirement_age(w), EconData.RETIREMENT_AGE, "default retirement age")
	w.levers["LAW_RETIREMENT_AGE"] = 67
	check_eq(EconHouseholds.retirement_age(w), 67, "law lever read when present")
	EconUtil.st(w)["food_shortfall"] = 0
	check_eq(EconHouseholds.food_brake(w), 1.0, "no brake without shortfall")
	EconUtil.st(w)["food_shortfall"] = 1000
	check_eq(EconHouseholds.food_brake(w), EconData.FOOD_BRAKE_FLOOR, "soft brake: never below the floor")

extends TestCase
## Untreated illness is signalled (the user, 2026-11-17: "This needs signals, pandemic in the newpaper"): when the
## clinics cannot treat people and enough of them are too ill to work, a public fact says so.

const HealthSignal := preload("res://sim/politics/health_signal.gd")
const Gazette := preload("res://ui/panels/gazette_panel.gd")


func _world(on: bool) -> WorldState:
	var sim := EconSim.make_econ_only(3)
	sim.run(2)
	var flags: Array = (sim.world.meta.get("on", []) as Array).duplicate()
	if on:
		flags.append("HEALTH_SIGNAL")
	sim.world.meta["on"] = flags
	return sim.world


func _set_access(w: WorldState, pm: int) -> void:
	var s := EconUtil.st(w)
	var h := {}
	for d in EconData.DISTRICTS:
		h[d] = pm
	s["health_access"] = h


func test_no_clinics_is_a_pandemic_and_a_crisis() -> void:
	var w := _world(true)
	_set_access(w, 0)
	var m: Dictionary = HealthSignal.measure(w)
	check(int(m["sick"]) > 0, "people are too ill to work (%d of %d)" % [int(m["sick"]), int(m["labour"])])
	check(float(m["share"]) > 0.06, "close to the 8% the labour market holds back")
	HealthSignal.monthly(w)
	var fs: Array = w.facts.query("ECON_PANDEMIC", w.month, w.month)
	check_eq(fs.size(), 1, "the pandemic is a public fact")
	var f: Dictionary = fs[0]
	check_eq(int(f["data"]["sick"]), int(m["sick"]), "it says how many")
	check(bool(f["data"]["crisis"]), "at this size it is a crisis")
	check(int(f["impact"]["PUBLIC_SERVICES"]) < 0, "voters' concern for public services falls")
	check_eq(String(f["responsible"][0]["actor"]["kind"]), "GOVERNMENT", "the government answers for it")
	check_eq(EmergencyPolitics.kind_of("ECON_PANDEMIC PANDEMIC"), "HEALTH", "it is a health emergency")
	check(Gazette.headline(w, f).begins_with("PANDEMIC"), "the paper's headline says pandemic (%s)" % Gazette.headline(w, f))
	check(NewsText.sentence(w, f).contains("too ill to work"), "and its sentence says what it means")


func test_working_clinics_are_not_news() -> void:
	var w := _world(true)
	_set_access(w, 1000)
	HealthSignal.monthly(w)
	check_eq(w.facts.query("ECON_PANDEMIC", w.month, w.month).size(), 0, "full clinic access: nothing to report")
	_set_access(w, 900)
	HealthSignal.monthly(w)
	check_eq(w.facts.query("ECON_PANDEMIC", w.month, w.month).size(), 0, "a few ill people are not a pandemic")


func test_it_is_off_without_its_switch() -> void:
	var w := _world(false)
	_set_access(w, 0)
	HealthSignal.monthly(w)
	check_eq(w.facts.query("ECON_PANDEMIC", w.month, w.month).size(), 0, "without HEALTH_SIGNAL nothing is raised")

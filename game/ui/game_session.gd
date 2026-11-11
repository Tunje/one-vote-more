class_name GameSession
extends RefCounted
## The only place the UI touches the simulation. Reads go through query modules and world.peek;
## mutations go through action entry points (staff/law A.apply, EconActions) or the few game options here.

const SAVE_PATH := "user://saves/slot1.sav"

var sim: Simulation


func new_game(seed_value: int, autoplay: bool = true) -> void:
	sim = EconSim.make(seed_value, "BALANCED", {}, autoplay)


func world() -> WorldState:
	return sim.world


func end_month() -> void:
	sim.step()


func save() -> Error:
	return SaveIO.save(sim, SAVE_PATH)


func load_game() -> Error:
	var s := EconSim.for_load()
	var err := SaveIO.load_into(s, SAVE_PATH)
	if err == OK:
		sim = s
	return err


## Game option (not a simulation decision): let the AI play the player's role this month.
func set_autoplay(on: bool) -> void:
	var st: Dictionary = sim.world.peek("pol").get("state", {})
	if not st.is_empty():
		st["autoplay_player"] = on


func autoplay() -> bool:
	return bool(sim.world.peek("pol").get("state", {}).get("autoplay_player", true))


# ---------------- read helpers ----------------

func pol_state() -> Dictionary:
	return sim.world.peek("pol").get("state", {})


func date_text() -> String:
	var w := sim.world
	const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "%s, Year %d" % [MONTHS[w.month_of_year() - 1], w.year()]


func party_name(pid: String) -> String:
	return sim.world.peek("party").get(pid, {}).get("name", "?")


func government_text() -> String:
	var st := pol_state()
	if st.get("era", "FOUNDING") == "FOUNDING":
		return "Founding era: you are Commander"
	var g: Dictionary = st.get("government", {})
	if g.is_empty():
		return "Caretaker government"
	var names: Array = g["members"].map(func(pid): return party_name(pid))
	return "Gov: %s (%d seats%s)" % [" + ".join(names), g.get("yes", 0), ", minority" if g.get("yes", 0) < PolDefs.MAJORITY else ""]


func next_election_month() -> int:
	return int(pol_state().get("next_election", PolDefs.FOUNDING_ELECTION_MONTH))


## Population-weighted per-district aggregates from voter cells: approval and economic lean (+ = left).
func district_politics() -> Dictionary:
	var out := {}
	for c in PolVoters.all(sim.world):
		var d: String = c["district"]
		if not out.has(d):
			out[d] = {"pop": 0.0, "approval": 0.0, "lean": 0.0}
		var p := float(c["pop"])
		out[d]["pop"] += p
		out[d]["approval"] += float(c["approval"]) / 1000.0 * p
		out[d]["lean"] += (float(c["ideology"]["ECON_ROLE"]) + float(c["ideology"]["REDISTRIBUTION"])) / 2000.0 * p
	for d in out:
		var p: float = maxf(1.0, out[d]["pop"])
		out[d]["approval"] /= p
		out[d]["lean"] /= p
	return out

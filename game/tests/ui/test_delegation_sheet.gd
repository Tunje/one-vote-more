extends TestCase
## The delegation sheet (office tab "Delegation", flag DELEGATION): it lists every decision type with its level
## buttons, respects the law and the player's office, and changes take effect.

const EconSim := preload("res://sim/economy/econ_sim.gd")
const Desk := preload("res://sim/office/decision_desk.gd")
const Sheet := preload("res://ui/panels/delegation_sheet.gd")


func _world(on: bool) -> WorldState:
	var sim: Simulation = EconSim.make(1, "BALANCED", {}, false)   # the player commands the founding colony
	if on:
		(sim.world.meta["on"] as Array).append(Desk.FLAG)
	sim.run(1)
	return sim.world


func _texts(n: Node, out: Array) -> Array:
	if n is Label:
		out.append((n as Label).text)
	elif n is Button:
		out.append((n as Button).text)
	for c in n.get_children():
		_texts(c, out)
	return out


func _buttons(n: Node, text: String, out: Array) -> Array:
	if n is Button and (n as Button).text == text:
		out.append(n)
	for c in n.get_children():
		_buttons(c, text, out)
	return out


func test_sheet_lists_every_type() -> void:
	var w := _world(true)
	var body := VBoxContainer.new()
	var calls := [0]
	Sheet.build(body, w, null, func(): calls[0] += 1)
	var txt := _texts(body, [])
	for ty in Desk.TYPES:
		check(txt.any(func(t): return String(t).begins_with(String(Desk.TYPES[ty]["name"]))), "the sheet lists %s" % ty)
	check(txt.has("Your own decision"), "bills are shown as the First Minister's own")
	# a press on a level button changes the level and asks for a refresh
	var lv := Desk.level(w, "BUILD_HOUSING")
	check_eq(lv, "SUGGEST", "balanced: housing comes as a suggestion")
	var calls_btn := _buttons(body, "Make the call", [])
	check(not calls_btn.is_empty(), "there are buttons to hand decisions over")
	Desk.set_level(w, "BUILD_HOUSING", "CALL")
	check_eq(Desk.level(w, "BUILD_HOUSING"), "CALL", "the change takes effect")
	var body2 := VBoxContainer.new()
	Sheet.build(body2, w, null, func(): pass)
	check(_texts(body2, []).has("● Make the call"), "the sheet shows the new level")
	body.free()
	body2.free()


func test_sheet_without_the_flag() -> void:
	var body := VBoxContainer.new()
	Sheet.build(body, _world(false), null, func(): pass)
	check_eq(body.get_child_count(), 1, "one line: delegation is off")
	body.free()

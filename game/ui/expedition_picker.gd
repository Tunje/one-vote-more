class_name ExpeditionPicker
extends HBoxContainer
## Terra (A47 §X2): choose the world. The candidate planets of this game seed, each previewed on the globe, with the
## survey card: surveyed facts exact, estimates as ranges ("est. 3–7"). Emits chosen(k); Wilma's expedition flow
## (X1) embeds it and calls ExpeditionWorlds.choose(world, k) before the game is set up.

signal chosen(k: int)

const ARCH_HINT := {"TEMPERATE": "temperate coast", "COOL": "cold north", "WARM_WET": "warm and wet", "DRY": "dry steppe",
	"HIGHLAND": "high country"}
const PH_NAMES := {"SOLAR_FLARE": "solar flares", "SPORE_BLOOM": "spore blooms", "MOON_SURGE": "twin-moon surges"}
const HAZ_NAMES := {"CYCLONE": "cyclones", "DUST": "dust storms", "RAIN_FRONT": "rain fronts", "BLIZZARD": "blizzards"}

var seed_value := 1
var selected := 0
var _globe: PlanetView
var _list: VBoxContainer
var _card: RichTextLabel
var _cards: Array = []


func _init() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


## Show this game seed's candidates (call once, and again for another seed).
func setup(seed_v: int) -> void:
	seed_value = seed_v
	for c in get_children():
		c.queue_free()
	_globe = PlanetView.new()
	_globe.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_globe.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_globe.size_flags_stretch_ratio = 1.4
	add_child(_globe)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.custom_minimum_size = Vector2(420, 0)
	add_child(right)
	var title := Label.new()
	title.text = "Choose the world"
	title.add_theme_font_size_override("font_size", 20)
	right.add_child(title)
	_list = VBoxContainer.new()
	right.add_child(_list)
	_card = RichTextLabel.new()
	_card.bbcode_enabled = true
	_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_card.add_theme_font_size_override("normal_font_size", 14)
	_card.add_theme_font_size_override("bold_font_size", 14)
	right.add_child(_card)
	var go := Button.new()
	go.text = "Choose this world"
	go.pressed.connect(func(): chosen.emit(selected))
	right.add_child(go)
	_cards = ExpeditionWorlds.candidates(seed_v)
	for c in _cards:
		var k := int(c["index"])
		var w := ExpeditionWorlds.world(seed_v, k)
		var b := Button.new()
		b.toggle_mode = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "%s (%s) · %d ly · harshness %d" % [c["name"], ARCH_HINT.get(String(w.peek("planet").get("arch", "")), ""),
			int(c["distance_ly"]), int(c["harshness"])]
		b.pressed.connect(func(): select(k))
		_list.add_child(b)
	select(0)


func select(k: int) -> void:
	selected = k
	for i in _list.get_child_count():
		(_list.get_child(i) as Button).set_pressed_no_signal(i == k)
	var s := GameSession.new()   # a viewing session on the candidate world (nothing runs)
	s.sim = Simulation.new(seed_value)
	s.sim.world = ExpeditionWorlds.world(seed_value, k)
	_globe.session = s
	_globe._built_for = ""
	_globe.refresh()
	_card.text = card_text(_cards[k] if k < _cards.size() else {})


## The survey card as text (BBCode). Estimates show their range and say so.
static func card_text(c: Dictionary) -> String:
	if c.is_empty():
		return ""
	var sv: Dictionary = c["survey"]
	var f := func(key: String, unit: String = "") -> String:
		var x: Dictionary = sv[key]
		if x["certainty"] == "SURVEYED":
			return "%d%s" % [int(x["value"]), unit]
		return "[color=#ffd166]est. %d–%d%s[/color]" % [int(x["lo"]), int(x["hi"]), unit]
	var t := "[b]%s[/b], around %s\n" % [c["name"], c["star"]]
	t += "%d light-years away: a ship every %d–%d months · reaching it costs %d (100 = average)\n\n" % [int(c["distance_ly"]),
		int(c["ship_months"][0]), int(c["ship_months"][1]), int(c["cost_index"])]
	var ld: Dictionary = c["landing"]
	t += "[b]Landing[/b]: %s at %d°%s, %d m%s\n" % [String(ld["biome"]), absi(int(ld["lat"])), "N" if int(ld["lat"]) >= 0 else "S",
		int(ld["height_m"]), ", on the coast" if ld["coast"] else ", inland"]
	t += "[b]Climate[/b]: %s to %s °C over the year, %d mm of rain\n" % [f.call("cold_c"), f.call("warm_c"), int(c["climate"]["rain_mm"])]
	var land: Dictionary = c["land"]
	t += "[b]Land[/b]: %s fertile%s · %d%% buildable\n" % [f.call("fertile_pct", "%"), ", a river" if land["river"] else ", no river",
		int(land["buildable_pct"])]
	t += "[b]Deposits[/b]: ore %s · rare minerals %s · native-crop land %s tiles\n" % [f.call("ore"), f.call("rare"), f.call("native")]
	t += "[b]Phenomena[/b]: %s\n" % ", ".join(c["phenomena"].map(func(p): return String(PH_NAMES.get(p["kind"], p["kind"])) + (" (likely)" if p["certainty"] == "ESTIMATED" else "")))
	t += "[b]Sights[/b]: %s, the best %s (%d)\n" % [f.call("sights"), String(c["sights"]["best"]), int(c["sights"]["best_attraction"])]
	var hz: Dictionary = c["hazards"]
	t += "[b]Hazards[/b]: %s strong storms a decade (%s) · %s droughts a century\n" % [f.call("storms_per_decade"),
		", ".join(hz["kinds"].map(func(k): return String(HAZ_NAMES.get(k, k)))) if not hz["kinds"].is_empty() else "calm skies", f.call("droughts")]
	t += "\n[b]Harshness[/b] %d/100\n" % int(c["harshness"])
	t += "[i][color=#aaaaaa]Orbital surveys measure climate and land; deposits, sights and hazards are estimates (yellow).[/color][/i]"
	return t

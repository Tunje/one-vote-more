extends SceneTree
## Terra (A5): render the colony map to a PNG (needs a window, not --headless).
## godot --path game --script res://tools/shot_colony.gd -- <seed> <out.png> [mode INSPECT|BUILD|DISTRICTS|DRAW] [months] [fixture 0|1] [bridge|waste|siting]
## fixture 1 builds a few areas (Landing, a mining camp, a farm village, a private enclave) with residents, as the
## economy will once A2/A3 land, so the area tools can be seen today.
const DL := preload("res://sim/law/districting.gd")
var _view: ColonyMap
var _frames := 0
var _out := "user://colony.png"
var _mode := "INSPECT"
var _bridge := false
var _waste := ""       # arg 6 = "waste": a demo landfill, cemetery and sewage in the river; "siting": the landfill siting study   # arg 6 = "bridge": zoom in on the first river crossing and open its link panel


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_v := int(args[0]) if args.size() > 0 else 1
	if args.size() > 1:
		_out = args[1]
	if args.size() > 2:
		_mode = args[2]
	var months := int(args[3]) if args.size() > 3 else 40
	_bridge = args.size() > 5 and args[5] == "bridge"
	_waste = args[5] if args.size() > 5 and args[5] in ["waste", "siting"] else ""
	var s := GameSession.new()
	s.new_game(seed_v, true)
	for _m in months:
		s.end_month()
	if args.size() > 4 and args[4] == "1":
		fixture(s.world())
	if _waste == "waste":
		var w := s.world()
		WasteMap.register_site(w, "demo:landfill", "LANDFILL", WasteMap.candidates(w, "LANDFILL")[0]["tiles"])
		WasteMap.set_fill(w, "demo:landfill", 620)
		WasteMap.register_site(w, "demo:cemetery", "CEMETERY", WasteMap.candidates(w, "CEMETERY")[0]["tiles"])
		WasteMap.add_burials(w, "demo:cemetery", 700)
		for _m in 3:
			WasteMap.add_discharge(w, Transport.tile_int(Terrain.landing(w)), 2500)
			WasteMap.step_month(w)
	_view = ColonyMap.new()
	_view.session = s
	root.size = Vector2i(1600, 900)
	_view.size = Vector2(1600, 900)
	root.add_child(_view)


## A small settled colony on the terrain (display fixture; mirrors tests/politics/test_district_politics.gd).
static func fixture(w: WorldState) -> void:
	var l := Terrain.landing(w)
	var hbs: Array = []
	# Landing: a 3x3 block of public housing around the landing site
	for dy in range(-1, 2):
		for dx in range(-2, 2):
			var a := AreaStore.place_housing(w, Vector2i(l.x + dx, l.y + dy), 60, "GOV", "", "Landing")
			if a != "" and not (a in hbs):
				hbs.append(a)
	# a private enclave a little apart
	var e := Terrain.nearest_free(w, l.x + 4, l.y - 3, Terrain.BUILDABLE_HOUSING, 6)
	var ea := AreaStore.place_housing(w, e, 8, "PRIVATE", "I5")
	AreaStore.place_housing(w, e + Vector2i(1, 0), 8, "PRIVATE", "I5")
	hbs.append(ea)
	# outposts: a mining camp next to the nearest ore and a farm village on fertile land
	var ore := Terrain.nearest_free(w, l.x, l.y, ["o"], 40)
	var camp := Terrain.nearest_free(w, ore.x, ore.y, Terrain.BUILDABLE_HOUSING, 6)
	var ca := AreaStore.place_housing(w, camp, 40, "COMPANY", "", "")
	AreaStore.place_housing(w, camp + Vector2i(0, 1), 40, "COMPANY")
	hbs.append(ca)
	var fert := Terrain.nearest_free(w, l.x + 12, l.y + 8, ["f"], 20)
	var va := AreaStore.place_housing(w, fert, 30, "COMPANY")
	if va != "":
		w.table("area")[va]["kind"] = "VILLAGE"
		AreaStore.place_housing(w, fert + Vector2i(1, 0), 30, "COMPANY")
		hbs.append(va)
	var sv := Terrain.nearest_free(w, l.x - 10, l.y + 6, Terrain.BUILDABLE_HOUSING, 10)
	for k in 4:
		AreaStore.place_housing(w, sv + Vector2i(k % 2, k / 2), 50, "GOV")
	var sa := AreaStore.area_of(w, sv)
	if sa != "":
		hbs.append(sa)
	var mix := {"I1": 0.2, "I2": 0.3, "I3": 0.3, "I4": 0.15, "I5": 0.05}
	var i := 0
	for a in hbs:
		var n := 120 + 60 * i
		for band in mix:
			var share: float = 0.9 if (a == ea and band == "I5") else (0.025 if a == ea else float(mix[band]))
			PopStore.seed_leaf(w, {"hb": a, "inc": band, "occ": "MINING" if a == ca else ("FARMING" if a == va else "SERVICES"),
				"status": "EMPLOYED", "arch": "PRAG"}, maxi(1, roundi(n * share)))
		PopStore.seed_leaf(w, {"hb": a, "inc": "I1", "occ": "SERVICES", "status": "UNEMPLOYED", "arch": "LABOR"}, 10 + 5 * i)
		i += 1
	DL.ensure_founding_district(w)
	DL.tick(w)
	PolVoters.refresh(w)


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 2:
		_view.refresh()
		_view.set_mode(_mode)
		var w := _view.session.world()
		var areas := AreaStore.areas(w)
		if _mode == "INSPECT":
			if not areas.is_empty():
				_view.click_tile(AreaStore.tiles_of(w, areas[0]["id"])[0])
			else:
				_view.click_tile(Terrain.landing(w))
		elif _mode == "BUILD":
			var l := Terrain.landing(w)
			_view.click_tile(Terrain.nearest_free(w, l.x + 3, l.y + 3, Terrain.BUILDABLE_HOUSING, 8))
			_view._hover = Vector2i(l.x - 1, l.y)
		elif _mode == "DRAW" and areas.size() >= 3:
			_view.new_group()
			_view.assign_area(areas[areas.size() - 1]["id"], _view.draw_group)
			_view.assign_area(areas[areas.size() - 2]["id"], _view.draw_group)
			_view.click_tile(Vector2i(-5, -5))
			_view.refresh()
		if _waste == "siting":
			_view.set_mode("BUILD")
			_view.build_type = "LANDFILL"
			_view._build_pick.select(ColonyMap.BUILD_TYPES.find("LANDFILL"))
			_view._refresh_siting()
			_view._update_panel()
		if _bridge:
			for l in Transport.network(w)["links"]:
				if not l.get("spans", []).is_empty():
					var tl := Transport.int_tile(int(l["path"][int(l["spans"][0][0])]))
					_view._zoom = 3.5
					_view._user_view = true
					_view._pan = Vector2.ZERO
					_view._pan = _view._map_rect().get_center() - _view._tile_center(tl)
					_view.set_mode("INSPECT")
					_view.selected = {"kind": "LINK", "id": l["id"], "tile": tl}
					_view._update_panel()
					_view.queue_redraw()
					break
	if _frames < 8:
		return false
	root.get_texture().get_image().save_png(_out)
	print("saved ", _out)
	return true

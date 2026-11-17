extends PicProvider
## The population's place in the game (rebuild step 1, planning/rebuild-company.md 12.1 points 1–2, 9.12; Maja with
## Terra). "no sectors beyond landfallpoint that's up to where things are built": a new game has ONE area, the
## Landing, on the landfall tile. Areas grow out of where homes are built (AreaStore); law draws districts from them
## (its charter puts the Landing in "The Colony" in the first month). Then the founding settlers land there
## (Households.settle_founders). The government's start-up, registered after this provider, lays the landing shelters
## (the housing office's plant, on Terra's town grid) and the month-one companies hire their crews from the settlers.

const Households := preload("res://sim/population/households.gd")
const Demography := preload("res://sim/population/demography.gd")
const OWNER := "population"


func owner_id() -> String:
	return OWNER


## Ages follow people when areas split or merge (Demography.on_area_moves). AreaStore's listeners are static hooks,
## not state: registered here, for every game this provider runs.
func _init() -> void:
	var cb := func(world: WorldState, moves: Array) -> void: Demography.on_area_moves(world, moves)
	if not AreaStore.change_listeners.any(func(c): return c is Callable and String(c.get_method()) == String(cb.get_method())):
		AreaStore.change_listeners.append(cb)


func phases() -> Array:
	return [TickPhase.SOCIAL]


## First month: the start-up has had its turn to lay the landing shelters. If the Landing holds fewer homes than its
## households, say so (Terra's review): a Logbook row, and an official fact for the government.
func run_phase(_phase: int, world: WorldState) -> void:
	# the households' SOCIAL month (rebuild step 3, the joins): life (births, deaths, growing up, retiring, January's
	# band moves), then the labour month (negotiation, quitting for better pay), then January's yearly raise
	Demography.monthly(world)
	Households.labour_month(world)
	Households.yearly_raise_month(world)
	if world.month != 0:
		return
	var land := AreaStore.found_landing(world)
	if land == "":
		return
	var homes := AreaStore.capacity(world, land)
	var hh := 0
	for pid in Households.pools(world):
		if String(world.peek("pool")[pid]["area"]) == land:
			hh += int(Households.counts(world, pid)["households"]) / CoreUtil.S
	if homes < hh:
		Logbook.note(world, "HOMES", land, "landing homes short", {"homes": homes, "households": hh})
		world.add_fact({"type": "POP_HOMES_SHORT", "owner": "pop", "subjects": [], "responsible": [], "impact": {},
			"magnitude": 30, "visibility": "OFFICIAL", "data": {"area": land, "homes": homes, "households": hh}})


## Makes the planet and the colony map, then the Landing. Registered before PoliticsProvider, so this is where a new
## game's map is made now (PoliticsProvider's own "Terrain if not ready" finds it done; both are idempotent).
func init_world(world: WorldState) -> void:
	Planet.generate(world)   # idempotent; the colony map is the landing region of the globe
	if not Terrain.ready(world):
		Terrain.generate(world)
	var landing := AreaStore.found_landing(world)
	Households.settle_founders(world, landing)   # the founding settlers, their pools and their savings (12.2, 10)

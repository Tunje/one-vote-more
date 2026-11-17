extends PicProvider
## The population's place in the game (rebuild step 1, planning/rebuild-company.md 12.1 points 1–2, 9.12; Maja with
## Terra). "no sectors beyond landfallpoint that's up to where things are built": a new game has ONE area, the
## Landing, on the landfall tile. Areas grow out of where homes are built (AreaStore); law draws districts from them
## (its charter puts the Landing in "The Colony" in the first month). People, pools and the landing shelters come with
## build step 2.

const OWNER := "population"


func owner_id() -> String:
	return OWNER


## Makes the planet and the colony map, then the Landing. Registered before PoliticsProvider, so this is where a new
## game's map is made now (PoliticsProvider's own "Terrain if not ready" finds it done; both are idempotent).
func init_world(world: WorldState) -> void:
	Planet.generate(world)   # idempotent; the colony map is the landing region of the globe
	if not Terrain.ready(world):
		Terrain.generate(world)
	AreaStore.found_landing(world)

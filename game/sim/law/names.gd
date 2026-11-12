extends RefCounted
## Player-visible names of the colony's institutions (user decision, names and the Cabinet): the First Minister
## leads THE CABINET; the legislature is THE COLONIAL ASSEMBLY (151 seats), THE NATIONAL ASSEMBLY after
## independence. No dependencies, so any sim file can preload it. (NewsText.assembly is the UI's capitalised form.)

const LEADER := "First Minister"
const CABINET := "the Cabinet"


## "the Colonial Assembly" / "the National Assembly" (mid-sentence; cap1 it at the start of a sentence).
static func assembly(world: WorldState) -> String:
	var st := String(world.peek("law_state").get("s", {}).get("sovereignty", {}).get("status", "COLONY"))
	return "the National Assembly" if st == "INDEPENDENT" else "the Colonial Assembly"

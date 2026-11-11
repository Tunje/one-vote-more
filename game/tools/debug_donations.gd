extends SceneTree
## Donation & scandal probe: where do POL_SCANDAL_REVEALED facts come from?
const EconSim := preload("res://sim/economy/econ_sim.gd")
func _initialize() -> void:
	var sim: Simulation = EconSim.make(1, "BALANCED", {}, true)
	sim.run(150)
	var don: Array = sim.world.facts.query("POL_DONATION")
	var by := {}
	for f in don:
		var k := "%s %s lawful=%s" % [f["type"], f["visibility"], f["data"].get("lawful", "rev")]
		by[k] = by.get(k, 0) + 1
	print("donations ", don.size(), " ", by)
	print("revealed ", sim.world.facts.query("POL_DONATION_REVEALED").size())
	var ch := {}
	for f in sim.world.facts.query("POL_SCANDAL_REVEALED"):
		var k := "%s exc=%s undis=%s" % [f["data"].get("channel", "?"), f["data"].get("excess", 0) > 0, f["data"].get("undisclosed", false)]
		ch[k] = ch.get(k, 0) + 1
	print("scandals ", ch)
	for f in sim.world.facts.query("POL_SCANDAL_REVEALED").slice(0, 3):
		print(f["data"])
	print("cap lever ", sim.world.levers.get("LAW_DONATION_CAP"), " disclosure ", sim.world.levers.get("LAW_DONATION_DISCLOSURE"))
	quit(0)

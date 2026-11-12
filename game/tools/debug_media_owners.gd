extends SceneTree
## Company-paper trace (Media M4): per month and company-owned outlet, balance, running cost, deficit months, the
## owner's last cover decision (short / willing / spare in W_ref, status) and Anni's fin record.
## Usage: godot --headless --path . --script res://tools/debug_media_owners.gd -- [seed] [from_month] [to_month]
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sd := int(a[0]) if a.size() > 0 else 1
	var m0 := int(a[1]) if a.size() > 1 else 100
	var m1 := int(a[2]) if a.size() > 2 else 125
	var sim := Simulation.new(sd)
	sim.world.meta["scenario"] = "BALANCED"
	sim.world.meta["persona"] = {}
	sim.world.meta["autoplay_player"] = true
	sim.world.meta["off"] = []
	EconSim._register(sim)
	sim.new_game()
	var w := sim.world
	var wref := float(w.values.get("ECON_W_REF", 1200000))
	for m in m1:
		sim.step()
		if w.month < m0:
			continue
		for id in EconUtil.sorted_keys(w.peek("outlet")):
			var o: Dictionary = w.peek("outlet")[id]
			if String(o["owner"]["kind"]) != "COMPANY" or o["status"] != "ACTIVE" and int(o.get("closed", -1)) != w.month:
				continue
			print("M%d %s %s owner %s | bal %.2f cost %.2f | def %d | dec %s | fin %s" % [w.month, id, o["status"], o["owner"]["id"],
				w.ledger.balance(String(o["account"])) / wref, Media.running_cost(w, o) / wref, int(o.get("deficit_months", 0)),
				str(o.get("owner_decision", {})), str(o.get("fin", {}))])
	quit()

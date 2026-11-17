extends SceneTree
## Trace the AI government's legislative behaviour on the real economy.
const EconSim := preload("res://sim/economy/econ_sim.gd")
const StaffOps := preload("res://sim/staff/staff_ops.gd")

func _initialize() -> void:
	var sim: Simulation = EconSim.make(1, "BALANCED", {}, true)
	var w := sim.world
	for m in 120:
		sim.step()
		var st: Dictionary = w.peek("pol")["state"]
		if w.month % 6 == 0:
			var dl: Array = st.get("drafts", [])
			var d: Dictionary = dl[0] if not dl.is_empty() else {}
			var dstat := "-"
			if not d.is_empty():
				var t: Dictionary = StaffOps.draft_for_bill(w, d["bill"])
				dstat = "%s since m%d %s" % [t.get("status", "NOTASK"), d["month"], d["clauses"].map(func(c): return c["lever"].replace("ECON_", ""))]
			print("m%3d era=%s crisis=%s stress=%.2f room=%.2f guard=%s unemp=%.1f%% JOBSsat=%d | PW=%s TRAIN=%s | last_bill=m%d | draft: %s" % [
				w.month, st["era"].substr(0, 4), st.get("crisis", false), Legislature.fiscal_stress(w), Legislature.fiscal_room(w), Legislature.fiscal_guard(w),
				w.indicators.read("ECON_UNEMPLOYMENT", "COLONY") / 1000.0, PoliticsProvider.new().colony_concerns(w)[0]["JOBS"] / 1000,
				w.levers.get("ECON_BUDGET_PUBLIC_WORKS"), w.levers.get("ECON_BUDGET_TRAINING"), st["last_bill_month"], dstat])
	var en := {}
	for e in w.peek("enactment").values():
		en[e["status"]] = en.get(e["status"], 0) + 1
	print("enactments by status: ", en)
	quit(0)

extends SceneTree
## Terra scratch probe: planet stats for seeds 1-3.
func _init() -> void:
	for s in [1, 2, 3]:
		var w := WorldState.new(s)
		var t0 := Time.get_ticks_msec()
		Planet.generate(w)
		var geo := Planet.geometry()
		var pent := 0
		for c in geo["corners"]:
			if c.size() == 5:
				pent += 1
		var bad := 0
		for en in geo["edge_nbr"]:
			for x in en:
				if x < 0:
					bad += 1
		var counts := {}
		for ch in String(w.peek("planet")["biome"]):
			counts[ch] = int(counts.get(ch, 0)) + 1
		var L := Planet.landing(w)
		print("seed ", s, " cells ", Planet.cell_count(w), " pent ", pent, " badedges ", bad, " ms ", Time.get_ticks_msec() - t0)
		print("  ", counts)
		print("  landing ", L, " ", Planet.describe(w, L))
		var w2 := WorldState.new(s)
		Planet.generate(w2)
		print("  deterministic ", w.state_hash() == w2.state_hash())
	quit()

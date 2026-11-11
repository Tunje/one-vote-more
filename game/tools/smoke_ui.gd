extends SceneTree
## Headless UI smoke test: boots the main scene, plays 50 months, renders every tab and overlay, saves and loads.
func _initialize() -> void:
	var main = load("res://ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._advance(50)
	for i in main.tabs.get_child_count():
		main.tabs.current_tab = i
		main._refresh_panels()
		var tab: Node = main.tabs.get_child(i)
		if tab in main.extra_panels:   # auto-discovered interactive panels (ui/panels/*_panel.gd)
			await process_frame
			print("tab %s: %d nodes" % [tab.name, _count(tab)])
		else:
			print("tab %s: %d chars" % [tab.name, main.panels[tab.name].get_parsed_text().length()])
	for o in ["UNEMPLOYMENT", "APPROVAL", "LEAN", "DISTRICTS"]:
		main.map.overlay = o
		main.map.refresh()
	main._on_save()
	main._on_load()
	main._advance(1)
	print("top bar: ", main.lbl_date.text, " | ", main.lbl_gov.text, " | ", main.lbl_stats.text)
	# Every ui/panels/*_panel.gd must have loaded, otherwise the game silently loses tabs.
	if not main.failed_panels.is_empty():
		print("SMOKE FAIL: panels failed to load: ", main.failed_panels)
		quit(1)
		return
	print("panels loaded: %d" % main.extra_panels.size())
	print("SMOKE OK")
	quit(0)


func _count(n: Node) -> int:
	var c := 1
	for ch in n.get_children():
		c += _count(ch)
	return c

# Interactive panels

Each `*_panel.gd` file here becomes a tab in the main screen automatically. Nobody edits `ui/main.gd` to add a panel.

```gdscript
extends VBoxContainer                     # any Control
func panel_title() -> String: return "Personnel"
func setup(session: GameSession) -> void: ...   # keep the session; never cache world (load replaces it)
func refresh() -> void: ...               # rebuild from queries using session.world()
```
Rules:
- **Reads:** query modules (SQ, LQ, EconQuery) and `world.peek`. Never `world.table`.
- **Writes:** only through action entry points (staff/law `A.apply`, `EconActions`). Then call
  `get_tree().call_group("pcs_refresh", "refresh_all")`.
- **Who the player is:** `session.pol_state()["player_party"]` (after Year 3). In the founding era the player is the
  commander, i.e. GOVERNMENT. When `session.autoplay()` is on, the AI also acts, so panels must handle that.
- **Smoke test:** `godot --headless --path game --script res://tools/smoke_ui.gd` must print SMOKE OK.

class_name ElectionNight
extends Control
## Election night: the count, district by district. Ballot boxes open one after another; the running vote bars
## and the 151-seat hemicycle fill in as districts report (projected seats from the running tally with the same
## Sainte-Laguë rule and 4% threshold as the real allocation); the final screen shows the real result and the
## 76-seat majority line. Opened by main.gd after an election; a Skip button jumps to the end. Read-only.

const BG := Color("#14181d")
const PANEL := Color("#1f252c")
const TEXT := Color("#e8ecef")
const MUTED := Color("#8a96a3")
const STEP_SECONDS := 1.1          # one district reports every STEP_SECONDS
const MONTHS := ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

var world: WorldState
var election: Dictionary = {}
var districts: Array = []          # reporting order
var reported := 0
var _t := 0.0
var _done := false
var _parties: Array = []           # party ids, largest first (final)
var _font: Font


func show_election(w: WorldState, eid: String) -> void:
	world = w
	election = w.peek("election").get(eid, {})
	var bd: Dictionary = election.get("by_district", {})
	districts = bd.keys()
	# smallest districts report first, the big city last (as on a real night)
	districts.sort_custom(func(a, b): return _dist_total(a) < _dist_total(b) or (_dist_total(a) == _dist_total(b) and a < b))
	reported = 0
	_t = 0.0
	_done = districts.is_empty()
	_parties = election.get("votes", {}).keys()
	_parties.sort_custom(func(a, b): return int(election["votes"][a]) > int(election["votes"][b]))
	_font = get_theme_default_font()
	set_process(true)
	queue_redraw()


func skip() -> void:
	reported = districts.size()
	_done = true
	queue_redraw()


func _process(delta: float) -> void:
	if _done or election.is_empty():
		return
	_t += delta
	if _t >= STEP_SECONDS:
		_t = 0.0
		reported += 1
		if reported >= districts.size():
			_done = true
		queue_redraw()


func _dist_total(d: String) -> int:
	var t := 0
	for pid in election.get("by_district", {}).get(d, {}):
		t += int(election["by_district"][d][pid])
	return t


func _tally() -> Dictionary:
	var out := {}
	if _done:
		return election.get("votes", {}).duplicate()
	for i in reported:
		var dv: Dictionary = election["by_district"][districts[i]]
		for pid in dv:
			out[pid] = int(out.get(pid, 0)) + int(dv[pid])
	return out


func _color(pid: String) -> Color:
	var p: Dictionary = world.peek("party").get(pid, {})
	return Color(String(p.get("color", "#888888")))


func _name(pid: String) -> String:
	return String(world.peek("party").get(pid, {}).get("name", pid))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	if election.is_empty():
		return
	var m := int(election["month"])
	var W := size.x
	_txt(Vector2(30, 46), "ELECTION NIGHT", 30, TEXT)
	_txt(Vector2(30, 74), "%s, Year %d%s" % [MONTHS[m % 12], m / 12 + 1, "  ·  extra election" if election.get("extra", false) else ""], 16, MUTED)
	var tally := _tally()
	var counted := 0
	for pid in tally:
		counted += int(tally[pid])
	var total := maxi(1, int(election.get("total", 1)))
	var pct := 100.0 if _done else 100.0 * float(counted) / float(total)
	_txt(Vector2(W - 330, 46), "%.0f%% of votes counted" % pct, 20, TEXT if _done else Color("#ffd166"))
	_txt(Vector2(W - 330, 72), "%d of %d districts reported" % [mini(reported, districts.size()), districts.size()], 15, MUTED)
	# ballot boxes: one per district
	var bx := 30.0
	var by := 100.0
	for i in districts.size():
		var open := i < reported or _done
		var r := Rect2(bx, by, 150, 54)
		draw_rect(r, PANEL)
		draw_rect(Rect2(bx, by, 150, 4), Color("#4caf50") if open else Color("#555f69"))
		var nm := NewsText.district(world, districts[i])
		_txt(Vector2(bx + 10, by + 24), nm.left(18), 14, TEXT if open else MUTED)
		if open:
			var dv: Dictionary = election["by_district"][districts[i]]
			var win := ""
			for pid in dv:
				if win == "" or int(dv[pid]) > int(dv[win]):
					win = pid
			draw_rect(Rect2(bx + 10, by + 34, 12, 12), _color(win))
			_txt(Vector2(bx + 28, by + 45), _name(win).left(16), 12, MUTED)
		else:
			_txt(Vector2(bx + 10, by + 45), "▣ counting…" if i == reported else "▣ sealed", 12, MUTED)
		bx += 160
		if bx + 150 > W - 20:
			bx = 30
			by += 62
	# running vote bars
	var top := by + 80
	var order: Array = _parties.duplicate()
	order.sort_custom(func(a, b): return int(tally.get(a, 0)) > int(tally.get(b, 0)) or (tally.get(a, 0) == tally.get(b, 0) and a < b))
	var y := top
	var bar_w := W * 0.26
	for pid in order:
		var share := float(tally.get(pid, 0)) / maxf(1.0, float(counted))
		_txt(Vector2(30, y + 15), _name(pid).left(26), 15, TEXT)
		draw_rect(Rect2(250, y + 2, bar_w, 18), PANEL)
		draw_rect(Rect2(250, y + 2, bar_w * share, 18), _color(pid))
		_txt(Vector2(260 + bar_w, y + 16), "%.1f%%" % (share * 100.0), 14, TEXT)
		if share < 0.04 and counted > 0:
			_txt(Vector2(320 + bar_w, y + 16), "below 4%", 12, Color("#ff8a65"))
		y += 28
	# hemicycle: projected seats from the running tally (or the final allocation)
	var seats: Dictionary = election.get("seats", {}) if _done else (VoteModel.allocate_seats(tally) if counted > 0 else {})
	var hx := W * 0.765
	var hr := minf(W * 0.2, 250.0)
	if _done:
		_txt(Vector2(hx - hr, top - 6), "FINAL RESULT  ·  majority = %d seats" % PolDefs.MAJORITY, 16, Color("#ffd166"))
	else:
		_txt(Vector2(hx - hr, top - 6), "PROJECTED SEATS  ·  counting…", 16, MUTED)
	_hemicycle(Vector2(hx, top + 40 + hr), hr, seats)


## 151 seats as dots in concentric arcs, filled left to right by party (largest first), majority marked.
func _hemicycle(center: Vector2, radius: float, seats: Dictionary) -> void:
	var rows := 7
	var pos: Array = []
	var per_row: Array = []
	var total_len := 0.0
	for r in rows:
		var rr := radius * (0.45 + 0.55 * float(r) / float(rows - 1))
		total_len += rr
	var placed := 0
	for r in rows:
		var rr := radius * (0.45 + 0.55 * float(r) / float(rows - 1))
		var n := int(round(float(PolDefs.SEATS) * rr / total_len)) if r < rows - 1 else PolDefs.SEATS - placed
		per_row.append(n)
		placed += n
		for i in n:
			var a := PI - PI * (float(i) + 0.5) / float(n)
			pos.append([a, center + Vector2(cos(a), -sin(a)) * rr])
	pos.sort_custom(func(p, q): return p[0] > q[0])  # left to right across all rows
	var order: Array = seats.keys()
	order.sort_custom(func(a, b): return int(seats[a]) > int(seats[b]) or (seats[a] == seats[b] and a < b))
	var colors: Array = []
	for pid in order:
		for _k in int(seats[pid]):
			colors.append(_color(pid))
	var dot := maxf(3.0, radius / 30.0)
	for i in pos.size():
		var c: Color = colors[i] if i < colors.size() else Color("#39424c")
		draw_circle(pos[i][1], dot, c)
	# majority marker: a tick at the angle where seat 76 falls
	if pos.size() >= PolDefs.MAJORITY:
		var a: float = pos[PolDefs.MAJORITY - 1][0]
		draw_line(center + Vector2(cos(a), -sin(a)) * radius * 0.38, center + Vector2(cos(a), -sin(a)) * radius * 1.06, Color("#ffd166"), 2.0)
	# seat counts
	var ly := center.y + 24
	for pid in order.slice(0, 8):
		draw_rect(Rect2(center.x - radius, ly - 10, 10, 10), _color(pid))
		_txt(Vector2(center.x - radius + 16, ly), "%s  %d" % [_name(pid).left(24), int(seats[pid])], 13, TEXT)
		ly += 18


func _txt(p: Vector2, s: String, sz: int, c: Color) -> void:
	draw_string(_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, c)

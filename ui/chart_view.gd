class_name ChartView
extends Control
## The plot on the chart table, north up and centred on the boat: own track, TDC marks and
## the target track they give, sonar bearing lines, and pencil marks anyone can add.

const PAPER := Color("#E8DFC4")
const GRID := Color("#B9C7C9")
const PENCIL := Color("#3B3A36")
const RED := Color("#B23A2E")
const BLUE := Color("#2B5C8A")
const BEARING_FADE := 180.0 ## seconds a sonar bearing line stays on the plot

var half_width := 5000.0 ## metres from the boat to the left/right edge
var font: Font


func _ready() -> void:
	font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func scale_m() -> float:
	return size.x * 0.5 / half_width


## World metres (x east, y north) to a point on the chart.
func to_chart(p: Vector2) -> Vector2:
	var rel := p - Sim.world.sub.pos
	return size * 0.5 + Vector2(rel.x, -rel.y) * scale_m()


func to_world(c: Vector2) -> Vector2:
	var rel := (c - size * 0.5) / scale_m()
	return Sim.world.sub.pos + Vector2(rel.x, -rel.y)


func _draw() -> void:
	if Sim.world == null or Game.instance == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), PAPER)
	_draw_grid()
	var crew: Dictionary = Game.instance.crew
	var now := Sim.world.time
	for b: Dictionary in crew.get("plot", []):
		var age := now - float(b.t)
		if age > BEARING_FADE:
			continue
		var from := Vector2(b.x, b.y)
		var rad := deg_to_rad(float(b.b))
		var col := BLUE
		col.a = 1.0 - age / BEARING_FADE
		draw_line(to_chart(from), to_chart(from + Vector2(sin(rad), cos(rad)) * 12000.0), col, 2.0)
	_draw_tdc(crew, now)
	var track: Array = Game.instance.track
	if track.size() >= 2:
		var pts := PackedVector2Array()
		for p: Vector2 in track:
			pts.append(to_chart(p))
		pts.append(to_chart(Sim.world.sub.pos))
		draw_polyline(pts, PENCIL, 2.0)
	var pencil: Array = crew.get("pencil", [])
	for i in pencil.size():
		var c := to_chart(Vector2(pencil[i].x, pencil[i].y))
		draw_arc(c, 10.0, 0.0, TAU, 20, PENCIL, 2.0)
		draw_string(font, c + Vector2(12, -8), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, PENCIL)
	_draw_boat()
	draw_string(font, Vector2(12, size.y - 12), "%d km across   north up" % roundi(half_width * 2.0 / 1000.0),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, PENCIL)


func _draw_grid() -> void:
	var step := 1000.0 if half_width <= 6000.0 else 5000.0
	var origin := Sim.world.sub.pos
	var x0 := floorf((origin.x - half_width) / step) * step
	var x := x0
	while x <= origin.x + half_width:
		var c := to_chart(Vector2(x, origin.y))
		draw_line(Vector2(c.x, 0), Vector2(c.x, size.y), GRID, 1.0)
		x += step
	var span_y := half_width * size.y / size.x
	var y := floorf((origin.y - span_y) / step) * step
	while y <= origin.y + span_y:
		var c := to_chart(Vector2(origin.x, y))
		draw_line(Vector2(0, c.y), Vector2(size.x, c.y), GRID, 1.0)
		y += step


func _draw_tdc(crew: Dictionary, now: float) -> void:
	var tdc: Dictionary = crew.get("tdc", {})
	var marks: Array = tdc.get("marks", [])
	for m: Dictionary in marks:
		var c := to_chart(Tdc.mark_pos(m))
		draw_line(c + Vector2(-6, -6), c + Vector2(6, 6), RED, 2.0)
		draw_line(c + Vector2(-6, 6), c + Vector2(6, -6), RED, 2.0)
	if marks.is_empty():
		return
	var est := Tdc.estimate(marks, tdc.speed_adj, tdc.course_adj)
	var now_pos := Tdc.target_at(est, now)
	var ahead: Vector2 = now_pos + est.vel * 600.0 # ten minutes on
	draw_dashed_line(to_chart(now_pos), to_chart(ahead), RED, 2.0, 8.0)
	draw_circle(to_chart(now_pos), 5.0, RED)
	draw_string(font, to_chart(now_pos) + Vector2(8, 16), "TDC %.0f kn %03d°" % [est.speed_kn, roundi(est.course) % 360],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, RED)


func _draw_boat() -> void:
	var sub := Sim.world.sub
	var c := to_chart(sub.pos)
	var rad := deg_to_rad(sub.heading)
	var fwd := Vector2(sin(rad), -cos(rad))
	var side := Vector2(-fwd.y, fwd.x)
	draw_colored_polygon(PackedVector2Array([c + fwd * 14.0, c - fwd * 9.0 + side * 7.0, c - fwd * 9.0 - side * 7.0]), PENCIL)

class_name ChartView
extends Control
## The plot on the chart table, north up and centred on the boat: land, reefs and shoal water
## with soundings, own track, every target where it was last marked, TDC marks and the target
## track they give, sonar bearing lines, and pencil marks anyone can add.

const PAPER := Color("#E8DFC4")
const GRID := Color("#B9C7C9")
const PENCIL := Color("#3B3A36")
const RED := Color("#B23A2E")
const BLUE := Color("#2B5C8A")
const BEARING_FADE := 180.0 ## seconds a sonar bearing line stays on the plot
const LAND := Color("#C9B27A")
const SHOAL := Color("#8FBCD0") ## under 12 m: reefs, keep off
const SHALLOW := Color("#B9D3D8") ## under 100 m: room to bottom out
const DARK_RED := Color("#7A2A22")
const LAND_SAMPLES := 180 ## across the chart, for the land and shoal picture

var half_width := 5000.0 ## metres from the boat to the left/right edge
var font: Font
var _land_tex: ImageTexture
var _land_rect := Rect2() ## world rect (x east, y north) the land picture covers
var _land_key := ""


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
	_draw_land()
	_draw_grid()
	_draw_soundings()
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
	_draw_contacts(crew, now)
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


## Land, reefs and shoal water, sampled from the seabed into a picture a little bigger than the
## chart, redrawn when the zoom or seabed changes or the boat moves a fair way.
func _draw_land() -> void:
	var seabed := Sim.world.seabed
	if seabed.features.is_empty():
		return
	var span := Vector2(half_width, half_width * size.y / maxf(size.x, 1.0)) * 1.3
	var here := Sim.world.sub.pos
	var key := "%d/%d/%d" % [seabed.version, roundi(half_width), roundi(size.y)]
	var moved := not _land_rect.grow(-half_width * 0.15).has_point(here)
	if key != _land_key or moved or _land_tex == null:
		_land_key = key
		_land_rect = Rect2(here - span, span * 2.0)
		var w := LAND_SAMPLES
		var h := maxi(1, roundi(w * span.y / span.x))
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for j in h:
			for i in w:
				var p := Vector2(_land_rect.position.x + (i + 0.5) / w * _land_rect.size.x,
					_land_rect.end.y - (j + 0.5) / h * _land_rect.size.y)
				var d := seabed.floor_depth(p)
				img.set_pixel(i, j, LAND if d < 0.0 else (SHOAL if d < 12.0 else (SHALLOW if d < 100.0 else Color(SHALLOW, 0.0))))
		_land_tex = ImageTexture.create_from_image(img)
	var tl := to_chart(Vector2(_land_rect.position.x, _land_rect.end.y))
	var br := to_chart(Vector2(_land_rect.end.x, _land_rect.position.y))
	draw_texture_rect(_land_tex, Rect2(tl, br - tl), false)


## The least depth over each seamount and shelf, as a chart sounding.
func _draw_soundings() -> void:
	for f: Dictionary in Sim.world.seabed.features:
		if f.kind == "island":
			continue
		var c := to_chart(Vector2(f.x, f.y))
		if Rect2(Vector2.ZERO, size).has_point(c):
			draw_string(font, c - Vector2(12, -5), "%d" % roundi(float(f.top)), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, BLUE)


## Every target the periscope has marked, where it was last marked and how long ago: the
## picture of the convoy after the TDC has moved on to another ship.
func _draw_contacts(crew: Dictionary, now: float) -> void:
	var current := int(crew.get("tdc", {}).get("target", -1))
	var contacts: Dictionary = crew.get("contacts", {})
	for id: int in contacts:
		if id == current:
			continue # the TDC's own target is drawn live
		var k: Dictionary = contacts[id]
		var c := to_chart(Vector2(k.x, k.y))
		var col := PENCIL if k.sunk else DARK_RED
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7), c + Vector2(7, 0), c + Vector2(0, 7), c + Vector2(-7, 0)]), col)
		var ago := roundi((now - float(k.t)) / 60.0)
		var note := "%s  sunk" % k.name if k.sunk else "%s  %s" % [k.name, "just now" if ago < 1 else "%d min ago" % ago]
		draw_string(font, c + Vector2(10, 5), note, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)


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

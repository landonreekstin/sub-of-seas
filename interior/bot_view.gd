class_name BotView
extends Node3D
## A bot crewman standing his station (see BotCrew): a crewman model where a player would
## stand, hands on the gear, with a name tag. E opens his orders, B stands him down.

var station_id := ""
var _arms := {}
var _pose := Vector2(0.9, 0.9)
var _lean := 0.0
var _tag: Label3D
var _look := {}


static func create(station: Station, bot: Dictionary) -> BotView:
	var v := BotView.new()
	v.station_id = station.station_id
	# Stand at the station's spot on its deck, facing the gear, held the way the station says.
	var view := station.get_view_transform()
	var fwd := -view.basis.z
	fwd.y = 0.0
	var spot := station.global_transform * station.bot_spot()
	v.position = Vector3(spot.x, station.global_position.y - station.mounted, spot.z) - fwd.normalized() * 0.1
	v.rotation.y = atan2(-fwd.x, -fwd.z)
	v._pose = station.bot_arms
	v._lean = station.bot_lean
	if station.get("seated") == true: # in the chair, his legs under the console
		v.position.y -= 0.42
	v.refresh(bot)
	return v


func refresh(bot: Dictionary) -> void:
	var look: Dictionary = bot.get("look", {})
	if _tag == null:
		_tag = Label3D.new()
		_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_tag.position.y = 1.95
		_tag.font_size = 32
		_tag.pixel_size = 0.0022 # small enough not to crowd the next man's
		add_child(_tag)
		Build.area(self, Vector3(0.5, 1.8, 0.5), Vector3(0, 0.9, 0))
	_tag.text = "%s (%s)%s" % [bot.name, BotCrew.job(station_id), "" if bot.auto else " — on orders"]
	if look == _look:
		return
	_look = look
	for c in get_children():
		if c != _tag and not c is Area3D:
			c.queue_free()
	var hips := Node3D.new() # leans him forward over a table
	hips.position.y = 0.95
	hips.rotation.x = -_lean
	add_child(hips)
	var body := Node3D.new()
	body.position.y = -0.95
	hips.add_child(body)
	var parts := Crewman.build_body(body, look, Color.from_hsv(float(look.get("hue", 0.58)), 0.45, 0.85))
	_arms = {"l": parts.arm_l, "r": parts.arm_r}
	var face := Node3D.new()
	face.position.y = Player.EYE_HEIGHT - 0.95
	hips.add_child(face)
	Crewman.build_face(face, look)
	Player._make_hat(face, look.get("hat", "watch"))


func _process(_delta: float) -> void:
	# Hands on the gear, working it a little.
	var t := Time.get_ticks_msec() / 1000.0
	if _arms.has("l"):
		_arms.l.rotation.x = _pose.x + sin(t * 1.3) * 0.06
		_arms.r.rotation.x = _pose.y + sin(t * 1.7 + 1.0) * 0.06


func get_prompt(_player: Player) -> String:
	var b: Dictionary = Game.instance.crew.get("bots", {}).get(station_id, {})
	return "[E] orders for %s    [%s] stand him down" % [b.get("name", "the bot"), OS.get_keycode_string(Settings.key_for("bot"))]


func interact(_player: Player) -> void:
	Game.instance.open_bot_orders(station_id)

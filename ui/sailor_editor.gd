class_name SailorEditor
extends Control
## Make your crewman: build, skin, hair, beard, extras, hat and shirt, with a turning preview.
## Saves to the profile as you pick; hats still unlock with rank.

signal closed

var _preview_root: Node3D
var _model: Node3D
var _profile: Profile


func _ready() -> void:
	_profile = Net.profile
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.88)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var p := UiKit.panel()
	center.add_child(p)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	p.add_child(row)
	row.add_child(_preview())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	box.custom_minimum_size.x = 340
	row.add_child(box)
	box.add_child(UiKit.label("YOUR SAILOR", 28, UiKit.BRASS))
	_choice(box, "Build", Crewman.BUILDS.map(func(b: Array) -> String: return b[0]), "build")
	_choice(box, "Skin", range(Crewman.SKINS.size()).map(func(i: int) -> String: return "Tone %d" % (i + 1)), "skin", Crewman.SKINS)
	_choice(box, "Hair", Crewman.HAIRS, "hair")
	_choice(box, "Hair colour", range(Crewman.HAIR_COLOURS.size()).map(func(i: int) -> String: return "Colour %d" % (i + 1)), "hair_col", Crewman.HAIR_COLOURS)
	_choice(box, "Beard", Crewman.BEARDS, "beard")
	_choice(box, "Extra", Crewman.EXTRAS, "extra")
	_hat_choice(box)
	_shirt_choice(box)
	var done := Button.new()
	done.text = "Done"
	done.pressed.connect(func() -> void:
		closed.emit()
		queue_free())
	box.add_child(done)
	_refresh()


func _preview() -> Control:
	var frame := SubViewportContainer.new()
	frame.custom_minimum_size = Vector2(300, 420)
	frame.stretch = true
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = false
	frame.add_child(vp)
	_preview_root = Node3D.new()
	vp.add_child(_preview_root)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#14324F")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#9DB59A")
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	_preview_root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 30, 0)
	_preview_root.add_child(sun)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.05, -3.9)
	cam.fov = 40.0
	_preview_root.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0, 0.95, 0))
	return frame


func _process(delta: float) -> void:
	if _model != null:
		_model.rotation.y += delta * 0.6


func _refresh() -> void:
	if _model != null:
		_model.queue_free()
	var look := _profile.looks()
	_model = Node3D.new()
	_preview_root.add_child(_model)
	var hue: float = look.get("hue", -1.0)
	Crewman.build_body(_model, look, Color.from_hsv(0.58 if hue < 0.0 else hue, 0.45, 0.85))
	var face := Node3D.new()
	face.position.y = Player.EYE_HEIGHT
	_model.add_child(face)
	Crewman.build_face(face, look)
	Player._make_hat(face, look.get("hat", "dixie"))


func _choice(box: VBoxContainer, title: String, items: Array, key: String, swatches: Array = []) -> void:
	var row := HBoxContainer.new()
	var l := UiKit.label(title, 16)
	l.custom_minimum_size.x = 120
	row.add_child(l)
	var o := OptionButton.new()
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in items.size():
		if i < swatches.size():
			o.add_icon_item(MainMenu.swatch(swatches[i]), items[i])
		else:
			o.add_item(items[i])
	o.select(int(_profile.face.get(key, 0)))
	o.item_selected.connect(func(i: int) -> void:
		_profile.face[key] = i
		_profile.save()
		_refresh())
	row.add_child(o)
	box.add_child(row)


func _hat_choice(box: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	var l := UiKit.label("Hat", 16)
	l.custom_minimum_size.x = 120
	row.add_child(l)
	var o := OptionButton.new()
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var keys := Profile.HATS.keys()
	for i in keys.size():
		var need: int = Profile.HATS[keys[i]][1]
		o.add_item(Profile.HATS[keys[i]][0] + ("" if _profile.unlocked(keys[i]) else "  (%s)" % Profile.RANKS[need][0]))
		o.set_item_disabled(i, not _profile.unlocked(keys[i]))
	o.select(keys.find(_profile.hat))
	o.item_selected.connect(func(i: int) -> void:
		_profile.hat = keys[i]
		_profile.save()
		_refresh())
	row.add_child(o)
	box.add_child(row)


func _shirt_choice(box: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	var l := UiKit.label("Shirt", 16)
	l.custom_minimum_size.x = 120
	row.add_child(l)
	var o := OptionButton.new()
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	o.add_item("By crew number")
	for hue: float in Profile.SHIRTS:
		o.add_icon_item(MainMenu.swatch(Color.from_hsv(hue, 0.45, 0.85)), "Shirt")
	o.select(0 if _profile.shirt_hue < 0.0 else maxi(Profile.SHIRTS.find(_profile.shirt_hue), 0) + 1)
	o.item_selected.connect(func(i: int) -> void:
		_profile.shirt_hue = -1.0 if i == 0 else Profile.SHIRTS[i - 1]
		_profile.save()
		_refresh())
	row.add_child(o)
	box.add_child(row)

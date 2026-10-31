class_name AmmoStation
extends Station
## The ammunition scuttle over the magazine (lando: "with ammunition passed up"): hold [Space]
## and the rounds go up hand to hand to the gun's ready-use locker, one every Game.PASS_TIME.
## The gun starts with its ready-use rounds; after those it fires only as fast as they come up.
## A flush hatch in the deck: the passer stands on its +z side.

const SEND_EVERY := 0.25 ## s between "pass" orders while Space is held (the host paces the rounds)

var _lines: Array[Label] = []
var _send_timer := 0.0
var _shells: Array[Node3D] = []


func _ready() -> void:
	# The scuttle: a hatch flush with the deck, its lid laid back, and the brass noses of the
	# rounds racked in the magazine showing down the hole. Players walk over it.
	Build.box(self, Vector3(0.8, 0.03, 0.8), Vector3(0, 0.015, 0), Color("#4A5248"), false)
	Build.box(self, Vector3(0.62, 0.035, 0.62), Vector3(0, 0.018, 0), Color("#141614"), false)
	Build.box(self, Vector3(0.66, 0.03, 0.66), Vector3(0, 0.02, 0.75), Color("#5E6B5C"), false) # the lid, laid back
	Build.box(self, Vector3(0.3, 0.04, 0.05), Vector3(0, 0.05, 0.75), UiKit.BRASS, false)
	for i in 6:
		var shell := Node3D.new()
		shell.position = Vector3(-0.18 + (i % 3) * 0.18, -0.45, -0.12 + (i / 3) * 0.24)
		add_child(shell)
		Build.lathe(shell, [Vector2(0, 0), Vector2(0.055, 0), Vector2(0.055, 0.3), Vector2(0.05, 0.36), Vector2(0.02, 0.48), Vector2(0, 0.5)],
			Vector3.ZERO, UiKit.BRASS)
		_shells.append(shell)
	var l := Build.label(self, "AMMUNITION SCUTTLE", Vector3(0, 0.05, -0.5), 22, UiKit.BRASS)
	l.rotation.x = -PI / 2.0
	Build.area(self, Vector3(0.8, 0.5, 0.8), Vector3(0, 0.25, 0))
	set_view(Vector3(0, 1.5, 0.9), Vector3(0, 0, 0))


func _process(delta: float) -> void:
	if Sim.world == null or Game.instance == null:
		return
	var gun: Dictionary = Game.instance.crew.get("gun", {})
	var data := Sim.world.sub.data
	var magazine := int(gun.get("magazine", 0))
	for i in _shells.size():
		_shells[i].visible = magazine > i * maxi(1, (data.gun_rounds - data.gun_ready) / _shells.size())
	sound_on_change("passed", magazine, "clang", Vector3(0, 0.2, 0), -12.0)
	if overlay == null:
		return
	var ready := int(gun.get("ready", 0))
	_lines[0].text = "AT THE GUN %d / %d    IN THE MAGAZINE %d" % [ready, data.gun_ready, magazine]
	if magazine <= 0:
		_lines[1].text = "The magazine is empty."
	elif ready >= data.gun_ready:
		_lines[1].text = "The gun's ready-use locker is full."
	else:
		_lines[1].text = "[Space] hold to pass rounds up to the gun, one every %.1f s." % Game.PASS_TIME
	_send_timer -= delta
	if Input.is_physical_key_pressed(KEY_SPACE) and _send_timer <= 0.0 and magazine > 0 and ready < data.gun_ready:
		_send_timer = SEND_EVERY
		order("pass")


func _build_overlay(root: Control) -> void:
	var box := UiKit.bottom_panel(root)
	box.add_child(UiKit.label("AMMUNITION SCUTTLE — %s" % Sim.world.sub.data.gun_name, 22, UiKit.BRASS))
	_lines.clear()
	for i in 2:
		var l := UiKit.label()
		box.add_child(l)
		_lines.append(l)
	box.add_child(UiKit.label(footer(cluster != ""), 14, UiKit.DIM))

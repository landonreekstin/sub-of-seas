class_name BandCrew
extends Node3D
## The Typhoon's band at the skipper's word (Blaney): eight sailors with the instruments in the
## rec room, on the band's own clock so they're a whole song, and a few more clapping along.

const RING := [Vector3(-1.2, 0, -2.4), Vector3(0, 0, -2.6), Vector3(1.2, 0, -2.4), Vector3(-1.4, 0, -0.8),
	Vector3(1.4, 0, -0.8), Vector3(-1.2, 0, 0.8), Vector3(0, 0, 1.0), Vector3(1.2, 0, 0.8)]

var interior: SubInterior
var _men: Array[Node3D] = []
var _sounds: Array[AudioStreamPlayer3D] = []


func _ready() -> void:
	for i in Tools.INSTRUMENTS.size():
		var kind: String = Tools.INSTRUMENTS[i]
		var look := {"build": i % 4, "skin": i % 3, "hair": i % 7, "hair_col": i % 7, "hat": "watch", "hue": 0.62}
		var man := interior._sailor(look)
		man.get_parent().remove_child(man)
		add_child(man)
		man.position = RING[i]
		man.rotation.y = atan2(RING[i].x, RING[i].z) # facing into the ring
		var held := Tools.model(kind)
		held.position = Vector3(0.0, 1.05, -0.32)
		man.add_child(held)
		_men.append(man)
		var p := AudioStreamPlayer3D.new()
		p.bus = "Music"
		p.unit_size = 8.0
		p.max_distance = 80.0
		p.position.y = 1.2
		man.add_child(p)
		_sounds.append(p)


func _process(_delta: float) -> void:
	if Game.instance == null:
		return
	var play := TyphoonLayout.band_audible(Game.instance.crew)
	var t := Time.get_ticks_msec() / 1000.0
	for i in _men.size():
		Band.keep_time(_sounds[i], Tools.INSTRUMENTS[i], play)
		_men[i].rotation.z = sin(t * TAU * 84.0 / 60.0 + i) * 0.03

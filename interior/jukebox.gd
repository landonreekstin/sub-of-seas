class_name Jukebox
extends Node3D
## The rec room's jukebox. E puts the next record on (or switches it off); everyone in the
## room hears it. The record playing is crew state, so all agree.

const RECORDS := [["Off", ""], ["The shanty", "menu"], ["Slow watch", "patrol"]]

var _player: AudioStreamPlayer3D
var _playing := -1
var _glow: MeshInstance3D


func _ready() -> void:
	Build.box(self, Vector3(0.7, 1.2, 0.5), Vector3(0, 0.6, 0), Color("#7A3A22"))
	var arch := Build.cyl(self, 0.35, 0.5, Vector3(0, 1.2, 0), Color("#7A3A22"), Vector3.BACK)
	arch.scale.y = 0.6
	_glow = Build.box(self, Vector3(0.5, 0.5, 0.02), Vector3(0, 0.85, -0.26), Color("#FFB34A"), false)
	for i in 3:
		Build.box(self, Vector3(0.52, 0.03, 0.03), Vector3(0, 0.45 + i * 0.12, -0.26), Color("#C9A04A"), false)
	Build.label(self, "JUKEBOX", Vector3(0, 1.32, -0.27), 22, Color("#F2E8CF"))
	Build.area(self, Vector3(0.7, 1.3, 0.5), Vector3(0, 0.65, 0))
	_player = AudioStreamPlayer3D.new()
	_player.bus = "Music"
	_player.unit_size = 3.0
	_player.max_distance = 14.0
	_player.position.y = 0.9
	add_child(_player)


func _process(_delta: float) -> void:
	if Game.instance == null:
		return
	var rec: int = Game.instance.crew.get("jukebox", 0)
	if rec == _playing:
		return
	_playing = rec
	var track: String = RECORDS[rec % RECORDS.size()][1]
	_glow.material_override = Build.mat(Color("#FFB34A"), 1.5 if track != "" else 0.0)
	if track == "":
		_player.stop()
		return
	var s: AudioStreamOggVorbis = load(Music.PATH % track).duplicate()
	s.loop = true
	_player.stream = s
	_player.play()


func get_prompt(_player_node: Player) -> String:
	var rec: int = Game.instance.crew.get("jukebox", 0)
	var next: Array = RECORDS[(rec + 1) % RECORDS.size()]
	return "[E] Jukebox: %s" % ("switch it off" if next[1] == "" else "put on \"%s\"" % next[0])


func interact(_player_node: Player) -> void:
	Game.instance.rq_jukebox.rpc_id(1)

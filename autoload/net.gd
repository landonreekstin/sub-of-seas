extends Node
## LAN session over ENet: the host is a listen server (and a player), others join by IP.
## Command line (after `--`): --host | --join <ip> | --name <name> | --address <ip> (prefill)

const DEFAULT_PORT := 7000
const MAX_PLAYERS := 8

enum Mode { NONE, HOST, CLIENT }

var mode := Mode.NONE
var address := "127.0.0.1"
var player_name := "Sailor"
var last_error := "" ## shown by the main menu after a session ends badly
var cli_start := Mode.NONE ## set from the command line, consumed by the main menu once
var profile := Profile.load_or_new() ## this player's career and look, saved on this machine
var debug_spawn: Variant = null ## --spawn x,y,z: start this player there (testing)
var port := DEFAULT_PORT ## --port n (the packaged game uses 7845, forwarded over the homelab VPN)
## Which build this is: tools/publish.sh writes the commit into build.txt in the pack.
## Peers must match (RPCs are checked against each other); "dev" (run from source) matches anything.
var build := "dev"
var sub_key := "gato" ## the boat the host takes out (--sub s_boat | gato | narwhal)
var mission := "convoy" ## a MissionData key or "training"; chosen by the host (--mission, --training)
var debug_charges := false ## --test-charges: the host drops a pattern on the boat (testing)
var debug_station := "" ## --station <id>: man this station as soon as you are aboard (testing)
var debug_look := 0.0 ## --look <deg>: turn the spawned player this far right (testing)
var debug_win := false ## --test-win: the host sinks everything a few seconds in (objectives, debrief)
var debug_air := false ## --test-air: the host starts with foul air, and a fire and thick smoke in the shut-in control room


func _ready() -> void:
	if FileAccess.file_exists("res://build.txt"):
		build = FileAccess.get_file_as_string("res://build.txt").strip_edges()
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		match args[i]:
			"--host":
				cli_start = Mode.HOST
			"--join":
				cli_start = Mode.CLIENT
				if i + 1 < args.size():
					address = args[i + 1]
			"--port":
				if i + 1 < args.size():
					port = args[i + 1].to_int()
			"--address":
				if i + 1 < args.size():
					address = args[i + 1]
			"--sub":
				if i + 1 < args.size():
					sub_key = args[i + 1]
			"--mission": # host this patrol
				if i + 1 < args.size():
					mission = args[i + 1]
					cli_start = Mode.HOST
			"--training": # host the training patrol
				mission = "training"
				cli_start = Mode.HOST
			"--test-charges":
				debug_charges = true
			"--test-air":
				debug_air = true
			"--test-win":
				debug_win = true
			"--station":
				if i + 1 < args.size():
					debug_station = args[i + 1]
			"--look":
				if i + 1 < args.size():
					debug_look = args[i + 1].to_float()
			"--spawn":
				if i + 1 < args.size():
					var v := args[i + 1].split_floats(",")
					debug_spawn = Vector3(v[0], v[1], v[2])
			"--name":
				if i + 1 < args.size():
					player_name = args[i + 1]


func start() -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err: Error
	if mode == Mode.HOST:
		err = peer.create_server(port, MAX_PLAYERS - 1)
	else:
		err = peer.create_client(address, port)
	if err == OK:
		multiplayer.multiplayer_peer = peer
	return err


func stop() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	mode = Mode.NONE

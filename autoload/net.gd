extends Node
## LAN session over ENet: the host is a listen server (and a player), others join by IP.
## Command line (after `--`): --host | --join <ip> | --name <name>

const DEFAULT_PORT := 7000
const MAX_PLAYERS := 8

enum Mode { NONE, HOST, CLIENT }

var mode := Mode.NONE
var address := "127.0.0.1"
var player_name := "Sailor"
var last_error := "" ## shown by the main menu after a session ends badly
var cli_start := Mode.NONE ## set from the command line, consumed by the main menu once
var debug_spawn: Variant = null ## --spawn x,y,z: start this player there (testing)
var port := DEFAULT_PORT ## --port n (testing two sessions on one machine)
var debug_charges := false ## --test-charges: the host drops a pattern on the boat (testing)


func _ready() -> void:
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
			"--test-charges":
				debug_charges = true
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

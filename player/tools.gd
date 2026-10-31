class_name Tools
## The hand tools a crewman can carry, one at a time. Racks hand them out.

const KINDS := {
	"torch": {"name": "welding torch", "use": "weld the leak", "color": Color("#3A6EA5")},
	"extinguisher": {"name": "extinguisher", "use": "put out the fire", "color": Color("#C0392B")},
	"wrench": {"name": "wrench", "use": "repair", "color": Color("#8A8F86")},
	"pump": {"name": "portable pump", "use": "set the pump down", "color": Color("#D4A017")},
	"parts": {"name": "spare parts box", "use": "fit the parts", "color": Color("#7A5A34")},
}
const PUMPS_ABOARD := 2
## The crew's band (Blaney): one of each aboard, each plays its own part of the song (Band).
const INSTRUMENTS := ["whistle", "fiddle", "concertina", "bodhran", "guitar", "bass", "drums", "synth"]
const INSTRUMENT_NAMES := {
	"whistle": "tin whistle", "fiddle": "fiddle", "concertina": "concertina", "bodhran": "bodhrán",
	"guitar": "electric guitar", "bass": "bass guitar", "drums": "snare and sticks", "synth": "keytar synth",
}


static func is_instrument(kind: String) -> bool:
	return INSTRUMENTS.has(kind)


static func display_name(kind: String) -> String:
	if is_instrument(kind):
		return INSTRUMENT_NAMES[kind]
	return KINDS[kind].name if KINDS.has(kind) else ""


static func exists(kind: String) -> bool:
	return KINDS.has(kind) or is_instrument(kind)


## A small model of the tool, for the first-person hand or another crewman's hands.
static func model(kind: String) -> Node3D:
	var root := Node3D.new()
	if is_instrument(kind):
		_instrument(root, kind)
		return root
	var c: Color = KINDS[kind].color
	match kind:
		"torch":
			Build.cyl(root, 0.04, 0.3, Vector3(0, 0, 0), c, Vector3.FORWARD)
			Build.cyl(root, 0.015, 0.2, Vector3(0, 0.02, -0.24), Color("#C9A04A"), Vector3.FORWARD)
		"extinguisher":
			Build.cyl(root, 0.07, 0.36, Vector3(0, 0, 0), c)
			Build.box(root, Vector3(0.04, 0.04, 0.14), Vector3(0, 0.2, -0.05), Color("#2B2B26"), false)
		"wrench":
			Build.box(root, Vector3(0.04, 0.03, 0.34), Vector3(0, 0, -0.05), c, false)
			Build.box(root, Vector3(0.1, 0.03, 0.06), Vector3(0, 0, -0.23), c, false)
		"parts":
			Build.box(root, Vector3(0.3, 0.18, 0.2), Vector3.ZERO, c, false)
			Build.box(root, Vector3(0.31, 0.03, 0.21), Vector3(0, 0.06, 0), Color("#C9A04A"), false)
		"pump":
			Build.box(root, Vector3(0.3, 0.22, 0.22), Vector3.ZERO, c, false)
			Build.cyl(root, 0.03, 0.3, Vector3(0.18, -0.05, 0), Color("#2B2B26"))
	return root


## The instruments, small and simple, held out in front.
static func _instrument(root: Node3D, kind: String) -> void:
	var wood := Color("#8A5A2E")
	var dark := Color("#2A2620")
	var metal := Color("#B8B4A8")
	match kind:
		"whistle":
			Build.cyl(root, 0.012, 0.3, Vector3(0, 0, -0.1), Color("#C9C4B4"), Vector3.FORWARD)
			Build.cyl(root, 0.014, 0.06, Vector3(0, 0, 0.05), Color("#3A6E3A"), Vector3.FORWARD) # the mouthpiece
		"fiddle":
			var body := Build.sphere(root, 0.1, Vector3(0, 0, 0), wood)
			body.scale = Vector3(1.0, 0.35, 1.6)
			Build.box(root, Vector3(0.03, 0.02, 0.24), Vector3(0, 0.02, -0.26), dark, false) # neck
			Build.box(root, Vector3(0.008, 0.008, 0.5), Vector3(0.1, 0.06, -0.05), Color("#D8C9A0"), false) # bow
		"concertina":
			for side in [-1.0, 1.0]:
				Build.box(root, Vector3(0.06, 0.15, 0.15), Vector3(side * 0.12, 0, 0), wood, false)
			Build.box(root, Vector3(0.18, 0.13, 0.13), Vector3.ZERO, Color("#7A1E1E"), false) # bellows
		"bodhran":
			Build.cyl(root, 0.2, 0.08, Vector3.ZERO, Color("#E2D3A8"), Vector3.FORWARD)
			Build.cyl(root, 0.205, 0.07, Vector3(0, 0, 0.005), wood, Vector3.FORWARD)
			Build.box(root, Vector3(0.015, 0.015, 0.2), Vector3(0.15, 0.1, -0.1), dark, false) # the tipper
		"guitar":
			var g := Build.sphere(root, 0.16, Vector3(0, 0, 0.05), Color("#B23A2E"))
			g.scale = Vector3(1.0, 0.25, 1.2)
			Build.box(root, Vector3(0.04, 0.025, 0.42), Vector3(0, 0.02, -0.3), dark, false)
		"bass":
			var b := Build.sphere(root, 0.17, Vector3(0, 0, 0.05), Color("#1E3A5A"))
			b.scale = Vector3(1.0, 0.25, 1.25)
			Build.box(root, Vector3(0.045, 0.025, 0.55), Vector3(0, 0.02, -0.38), dark, false)
		"drums":
			Build.cyl(root, 0.17, 0.1, Vector3(0, -0.05, 0), metal)
			Build.cyl(root, 0.168, 0.012, Vector3(0, 0.003, 0), Color("#EDE8DC"))
			for side in [-1.0, 1.0]:
				Build.box(root, Vector3(0.012, 0.012, 0.3), Vector3(side * 0.08, 0.08, -0.05), wood, false)
		"synth":
			Build.box(root, Vector3(0.12, 0.05, 0.5), Vector3.ZERO, Color("#E8E4DA"), false)
			for k in 8:
				Build.box(root, Vector3(0.05, 0.012, 0.03), Vector3(0.02, 0.03, -0.18 + k * 0.045), dark if k % 2 else Color.WHITE, false)

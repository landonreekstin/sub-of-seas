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


static func display_name(kind: String) -> String:
	return KINDS[kind].name if KINDS.has(kind) else ""


## A small model of the tool, for the first-person hand or another crewman's hands.
static func model(kind: String) -> Node3D:
	var root := Node3D.new()
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

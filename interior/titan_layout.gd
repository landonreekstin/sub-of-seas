class_name TitanLayout
extends RefCounted
## The Titan (OceanGate, 2021-23): one carbon-fibre tube between two titanium domes, the
## viewport in the bow dome. Five aboard sat on the floor; the pilot drove her with a game
## controller, watching a screen. Ours is a little roomier than the real 1.4 m tube, so the
## crew can stand, stooped. Interior axes as every boat: bow -Z, the cabin ends at z 0.

const LENGTH := 4.2
const R := 1.2 ## the tube's inside radius
const AXIS_Y := 1.0 ## its centre above the floor
const CARBON := Color("#2B2D30")
const TITANIUM := Color("#8E9499")
const MAT := Color("#3C4654")
const LED := Color("#E6F0FF")


static func lay_out(i: SubInterior) -> void:
	i.has_conning_tower = false
	i.compartments.append({"type": "control", "name": "cabin", "z0": -LENGTH, "z1": 0.0})


static func build(i: SubInterior) -> void:
	var z0 := -LENGTH
	# The tube: carbon slats round it, a flat floor of mats.
	var n := 20
	for k in n:
		var a := TAU * k / n
		var p := Vector3(sin(a) * R, AXIS_Y + cos(a) * R, z0 * 0.5)
		var slat := Build.box(i, Vector3(2.0 * R * sin(PI / n) + 0.02, 0.06, LENGTH), p, CARBON.lightened(0.04 * (k % 2)))
		slat.rotation.z = -a
	var floor_w := 2.0 * sqrt(R * R - AXIS_Y * AXIS_Y)
	Build.box(i, Vector3(floor_w + 0.2, 0.1, LENGTH), Vector3(0, -0.05, z0 * 0.5), MAT)
	for k in 5: # seat cushions along the floor, one per crewman
		Build.box(i, Vector3(0.5, 0.08, 0.6), Vector3(0.38 * (1 if k % 2 == 0 else -1), 0.04, z0 + 0.6 + k * 0.72), Color("#1F2A38"), false)
	# The titanium domes' insides at each end, seen face on, bolted round the edge.
	for z in [z0 - 0.05, 0.05]:
		Build.cyl(i, R + 0.02, 0.1, Vector3(0, AXIS_Y, z), TITANIUM.darkened(0.25), Vector3.BACK)
		for k in 12: # the bolts round the ring
			var a := TAU * k / 12.0
			Build.sphere(i, 0.025, Vector3(sin(a) * (R - 0.08), AXIS_Y + cos(a) * (R - 0.08), z + (0.06 if z < 0.0 else -0.06)), TITANIUM)
	for z in [z0 - 0.2, 0.2]: # stop anyone walking into the domes
		Build.hitbox(i, Vector3(2.4, 2.4, 0.2), Vector3(0, AXIS_Y, z))
	# The viewport in the bow dome, low, where you lie on your front to look out.
	var vp := Porthole.create(Vector3(0, 0.75, z0 + 0.02), 1.0)
	vp.rotation.y = PI * 0.5
	vp.scale = Vector3.ONE * 1.5
	i.add_child(vp)
	i.portholes.append(vp)
	Build.label(i, "VIEWPORT", Vector3(0, 1.25, z0 + 0.02), 20, Color("#C8D2DC"))
	# LED strips overhead, cold and bright.
	for z in [z0 + 1.0, z0 + 3.0]:
		Build.box(i, Vector3(0.5, 0.03, 0.08), Vector3(0, AXIS_Y + R - 0.08, z), LED, false).material_override = Build.mat(LED, 2.0)
		var l := OmniLight3D.new()
		l.position = Vector3(0, AXIS_Y + R - 0.3, z)
		l.light_color = LED
		l.light_energy = 1.1
		l.omni_range = 4.0
		i.add_child(l)
	# Stations: the pilot aft, facing forward with the controller; the scrubber forward.
	var pilot := PilotStation.new()
	pilot.setup("helm", "Pilot")
	i._add_station(pilot, Vector3(0, 0, -0.35))
	var air := AirStation.new()
	air.setup("air", "Air (scrubber, O2)")
	i._add_station(air, Vector3(0.95, -0.25, z0 + 1.2))
	for k in 5:
		i.spawn_points.append(Vector3(0.3 * (1 if k % 2 == 0 else -1), 0.1, z0 + 0.9 + k * 0.6))


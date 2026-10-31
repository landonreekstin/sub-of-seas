class_name Crewman
extends RefCounted
## Builds a crewman's body and face from a look: a WWII US submariner at sea, in ordinary
## human proportions (Blaney: the Sea of Thieves-style crew were "way too cartoony to the point
## where they are almost creepy": look like sub sailors and take less space). Chambray work
## shirt, dungarees, black boots; a plain face with small features. Still simple shapes in the
## painted toon look. The body hangs from the player's origin; the face from its Head (the
## camera's pivot), so it turns with where they look.

## [name, torso radius, torso length, shoulder half-width]
const BUILDS := [["Average", 0.15, 0.46, 0.2], ["Wiry", 0.13, 0.48, 0.185], ["Stocky", 0.18, 0.44, 0.22], ["Broad", 0.17, 0.47, 0.225]]
const SKINS: Array[Color] = [Color("#EFCFB2"), Color("#E2B48E"), Color("#C48F66"), Color("#A16B47"), Color("#744A30"), Color("#4F3222")]
const HAIRS := ["Cropped", "Crew cut", "Slicked back", "Side parting", "Wavy", "Short back and sides", "Curly"]
const HAIR_COLOURS: Array[Color] = [Color("#2A1E16"), Color("#5A3A22"), Color("#8E6034"), Color("#C9A468"), Color("#9C4A2C"), Color("#8C8C8C"), Color("#D8D4CA")]
const BEARDS := ["Clean-shaven", "Stubble", "Full beard", "Pencil moustache", "Sideburns", "Moustache", "Patrol beard"]
const EXTRAS := ["Nothing", "Glasses", "Cigarette", "Scar", "Pipe", "Bandage"]
const DUNGAREE := Color("#3A4A66")
const BOOTS := Color("#1E1E20")
const BELT := Color("#2A2620")

## Shoulder height; the head sits at the player's eye height (1.6 m).
const SHOULDER_Y := 1.43


## Body parts on `root` (rebuilt fresh). Returns {"arm_l", "arm_r", "leg_l", "leg_r", "shirt"}.
static func build_body(root: Node3D, look: Dictionary, shirt: Color) -> Dictionary:
	var b: Array = BUILDS[clampi(int(look.get("build", 0)), 0, BUILDS.size() - 1)]
	var skin := SKINS[clampi(int(look.get("skin", 0)), 0, SKINS.size() - 1)]
	var r: float = b[1]
	var torso_len: float = b[2]
	var shoulder: float = b[3]
	# A work shirt is a faded, greyed blue-ish take on the crewman's colour, not a bright one.
	var cloth := shirt.lerp(Color("#8DA2BC"), 0.82).darkened(0.05)
	var hip_y := SHOULDER_Y + 0.04 - torso_len
	var limbs := {"shirt": []}
	var torso := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = torso_len + r * 0.6
	torso.mesh = cm
	torso.material_override = Build.mat(cloth, 0.0, "cloth")
	torso.position.y = hip_y + cm.height * 0.5 - r * 0.3
	torso.scale.z = 0.62
	root.add_child(torso)
	limbs.shirt.append(torso)
	# Neck, an open collar, and a belt over the dungarees.
	Build.cyl(root, 0.05, 0.14, Vector3(0, SHOULDER_Y + 0.08, 0), skin).material_override = Build.mat(skin, 0.0, "skin")
	for side in [-1.0, 1.0]:
		var lapel := Build.box(root, Vector3(0.05, 0.08, 0.012), Vector3(side * 0.04, SHOULDER_Y - 0.01, -r * 0.6), cloth.darkened(0.12), false)
		lapel.rotation.z = side * 0.5
	var belt := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = r * 1.02
	bm.bottom_radius = r * 1.02
	bm.height = 0.05
	belt.mesh = bm
	belt.material_override = Build.mat(BELT)
	belt.position.y = hip_y + 0.02
	belt.scale.z = 0.66
	root.add_child(belt)
	Build.box(root, Vector3(0.05, 0.04, 0.01), Vector3(0, hip_y + 0.02, -r * 0.68), Color("#B89A4A"), false) # buckle
	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(side * r * 0.5, hip_y, 0)
		root.add_child(leg)
		# Dungarees: straight legs, a little wider at the cuff over the boot.
		var ll := hip_y - 0.08
		Build.lathe(leg, [Vector2(0, -ll), Vector2(0.072, -ll), Vector2(0.066, -ll * 0.5), Vector2(0.078, 0.0), Vector2(0, 0.0)],
				Vector3.ZERO, DUNGAREE, Vector3.UP, 12).material_override = Build.mat(DUNGAREE, 0.0, "cloth")
		Build.box(leg, Vector3(0.1, 0.09, 0.26), Vector3(0, -hip_y + 0.045, -0.04), BOOTS, false) # work boots
		limbs["leg_l" if side < 0.0 else "leg_r"] = leg
		var arm := Node3D.new()
		arm.position = Vector3(side * shoulder, SHOULDER_Y - 0.03, 0)
		root.add_child(arm)
		# Sleeves rolled to the elbow, forearm and a hand in proportion.
		var sleeve := Build.lathe(arm, [Vector2(0, 0.03), Vector2(0.05, 0.03), Vector2(0.046, -0.26), Vector2(0.05, -0.29), Vector2(0, -0.29)],
				Vector3.ZERO, cloth, Vector3.UP, 12)
		sleeve.material_override = Build.mat(cloth, 0.0, "cloth")
		limbs.shirt.append(sleeve)
		Build.cyl(arm, 0.036, 0.25, Vector3(0, -0.41, 0), skin).material_override = Build.mat(skin, 0.0, "skin")
		var hand := Build.sphere(arm, 0.042, Vector3(0, -0.56, 0), skin)
		hand.scale = Vector3(0.8, 1.2, 0.6)
		hand.material_override = Build.mat(skin, 0.0, "skin")
		limbs["arm_l" if side < 0.0 else "arm_r"] = arm
	return limbs


## The face on `face` (a node at the head's centre, looking down -Z): a head in proportion,
## small eyes under straight brows, a plain nose and mouth.
static func build_face(face: Node3D, look: Dictionary) -> void:
	var skin := SKINS[clampi(int(look.get("skin", 0)), 0, SKINS.size() - 1)]
	var hair_c := HAIR_COLOURS[clampi(int(look.get("hair_col", 0)), 0, HAIR_COLOURS.size() - 1)]
	var dark := skin.darkened(0.1)
	var head := Build.sphere(face, 0.105, Vector3(0, 0.0, 0), skin)
	head.scale = Vector3(0.92, 1.13, 1.0)
	var jaw := Build.sphere(face, 0.08, Vector3(0, -0.06, -0.025), skin)
	jaw.scale = Vector3(1.05, 0.85, 1.0)
	var nose := Build.sphere(face, 0.015, Vector3(0, -0.022, -0.1), dark)
	nose.scale = Vector3(0.8, 1.35, 1.0)
	for side in [-1.0, 1.0]:
		var ear := Build.sphere(face, 0.02, Vector3(side * 0.095, -0.01, 0.01), dark)
		ear.scale = Vector3(0.4, 1.0, 0.7)
		var white := Build.sphere(face, 0.014, Vector3(side * 0.034, 0.012, -0.092), Color("#E8E2D6"))
		white.scale = Vector3(1.2, 0.7, 0.4)
		Build.sphere(face, 0.008, Vector3(side * 0.033, 0.012, -0.097), Color("#2A2420")).scale = Vector3(1.0, 1.0, 0.5)
		var brow := Build.box(face, Vector3(0.036, 0.008, 0.012), Vector3(side * 0.035, 0.034, -0.096), hair_c.darkened(0.2), false)
		brow.rotation.z = side * -0.08
		brow.material_override = Build.mat(hair_c.darkened(0.2), 0.0, "hair")
	Build.box(face, Vector3(0.038, 0.007, 0.01), Vector3(0, -0.058, -0.094), skin.lerp(Color("#7A3A30"), 0.45), false) # mouth
	for m in face.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var c: Color = (mi.material_override as ShaderMaterial).get_shader_parameter("albedo") if mi.material_override is ShaderMaterial else Color.BLACK
		if c.is_equal_approx(skin) or c.is_equal_approx(dark):
			mi.material_override = Build.mat(c, 0.0, "skin")
	var before := face.get_child_count()
	_hair(face, int(look.get("hair", 0)), hair_c)
	_beard(face, int(look.get("beard", 0)), hair_c, skin)
	for i in range(before, face.get_child_count()):
		for m in [face.get_child(i)] + face.get_child(i).find_children("*", "MeshInstance3D", true, false):
			if m is MeshInstance3D and (m as MeshInstance3D).material_override is ShaderMaterial:
				var c: Color = (m as MeshInstance3D).material_override.get_shader_parameter("albedo")
				if c.is_equal_approx(hair_c) or c.is_equal_approx(hair_c.darkened(0.1)):
					(m as MeshInstance3D).material_override = Build.mat(c, 0.0, "hair")
	_extra(face, int(look.get("extra", 0)), skin)


static func _hair(face: Node3D, kind: int, c: Color) -> void:
	# The cap of hair: a sphere a touch bigger than the skull, set up and back so the hairline
	# sits above the brows and the back and sides are short.
	var cap := func(lift: float, back: float, sy: float) -> MeshInstance3D:
		var m := Build.sphere(face, 0.106, Vector3(0, lift, back), c)
		m.scale = Vector3(0.97, sy, 1.0)
		return m
	match HAIRS[clampi(kind, 0, HAIRS.size() - 1)]:
		"Crew cut":
			cap.call(0.05, 0.02, 0.95)
		"Slicked back":
			cap.call(0.045, 0.028, 1.0)
		"Side parting":
			cap.call(0.045, 0.02, 1.0)
			Build.sphere(face, 0.04, Vector3(0.045, 0.1, -0.05), c).scale = Vector3(1.4, 0.55, 1.1) # the swept side
		"Wavy":
			cap.call(0.045, 0.02, 1.0)
			for k in 3:
				Build.sphere(face, 0.034, Vector3(-0.04 + k * 0.04, 0.11, -0.045 + k * 0.01), c).scale = Vector3(1.2, 0.6, 1.0)
		"Short back and sides":
			cap.call(0.06, 0.015, 0.92)
		"Curly":
			cap.call(0.045, 0.02, 1.0)
			for k in 7:
				var a := k * TAU / 7.0
				Build.sphere(face, 0.032, Vector3(cos(a) * 0.065, 0.115, sin(a) * 0.065 + 0.015), c)
		_: # cropped
			cap.call(0.045, 0.022, 1.0)


static func _beard(face: Node3D, kind: int, c: Color, skin: Color) -> void:
	match BEARDS[clampi(kind, 0, BEARDS.size() - 1)]:
		"Stubble":
			var s := Build.sphere(face, 0.088, Vector3(0, -0.055, -0.022), skin.lerp(c, 0.3))
			s.scale = Vector3(1.04, 0.72, 1.0)
		"Full beard":
			var s := Build.sphere(face, 0.085, Vector3(0, -0.07, -0.03), c)
			s.scale = Vector3(1.08, 0.9, 0.95)
		"Pencil moustache":
			Build.box(face, Vector3(0.036, 0.005, 0.008), Vector3(0, -0.044, -0.1), c, false)
		"Sideburns":
			for side in [-1.0, 1.0]:
				Build.box(face, Vector3(0.016, 0.055, 0.03), Vector3(side * 0.093, -0.02, -0.005), c, false)
		"Moustache":
			Build.box(face, Vector3(0.05, 0.013, 0.014), Vector3(0, -0.045, -0.099), c, false)
		"Patrol beard": # weeks at sea without a razor
			var s := Build.sphere(face, 0.088, Vector3(0, -0.062, -0.026), c.lerp(skin, 0.25))
			s.scale = Vector3(1.08, 0.85, 0.98)


static func _extra(face: Node3D, kind: int, skin: Color) -> void:
	match EXTRAS[clampi(kind, 0, EXTRAS.size() - 1)]:
		"Glasses":
			for side in [-1.0, 1.0]:
				Build.box(face, Vector3(0.032, 0.024, 0.004), Vector3(side * 0.034, 0.012, -0.106), Color("#2A2620"), false)
				Build.box(face, Vector3(0.004, 0.004, 0.1), Vector3(side * 0.05, 0.018, -0.06), Color("#2A2620"), false)
			Build.box(face, Vector3(0.02, 0.004, 0.004), Vector3(0, 0.016, -0.107), Color("#2A2620"), false)
		"Cigarette":
			Build.cyl(face, 0.004, 0.05, Vector3(0.018, -0.06, -0.12), Color("#EDE8DC"), Vector3.BACK)
			Build.sphere(face, 0.005, Vector3(0.018, -0.06, -0.146), Color("#E2683A"), 1.5)
		"Scar":
			var s := Build.box(face, Vector3(0.006, 0.05, 0.006), Vector3(0.045, -0.012, -0.1), skin.lerp(Color("#B06058"), 0.5), false)
			s.rotation.z = 0.35
		"Pipe":
			Build.cyl(face, 0.005, 0.06, Vector3(0.02, -0.064, -0.125), Color("#4A3020"), Vector3.BACK)
			Build.cyl(face, 0.014, 0.03, Vector3(0.022, -0.052, -0.158), Color("#5A3A22"))
		"Bandage":
			var band := Build.box(face, Vector3(0.05, 0.022, 0.01), Vector3(-0.045, 0.06, -0.098), Color("#EDE8DC"), false)
			band.rotation.z = 0.3

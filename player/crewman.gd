class_name Crewman
extends RefCounted
## Builds a crewman's body and face from a look (lando: customisable, like Sea of Thieves
## crew): stylised and exaggerated, with big forearms and hands, chunky boots, and a face with
## character. The body hangs from the player's origin; the face from its Head (the camera's
## pivot), so it turns with where they look.

## [name, torso radius, torso length, shoulder width]
const BUILDS := [["Average", 0.27, 0.62, 0.34], ["Wiry", 0.21, 0.66, 0.29], ["Stocky", 0.34, 0.56, 0.4], ["Barrel-chested", 0.36, 0.64, 0.42]]
const SKINS: Array[Color] = [Color("#F3D2B3"), Color("#E9B98F"), Color("#C98F62"), Color("#A86B43"), Color("#7A4A2C"), Color("#553220")]
const HAIRS := ["Cropped", "Bald", "Slicked back", "Long", "Ponytail", "Mohawk", "Curly"]
const HAIR_COLOURS: Array[Color] = [Color("#2A1E16"), Color("#5A3A22"), Color("#A0682E"), Color("#D9B26A"), Color("#B5452A"), Color("#9A9A9A"), Color("#E8E4DA")]
const BEARDS := ["Clean-shaven", "Stubble", "Full beard", "Goatee", "Mutton chops", "Big moustache", "Braided beard"]
const EXTRAS := ["Nothing", "Eyepatch", "Gold earring", "Scar", "Pipe", "Bandana"]
const NAVY := Color("#2B3A55")
const BOOTS := Color("#1E1E20")

## Shoulder height and the hip it hangs down to; the head sits at the player's eye height.
const SHOULDER_Y := 1.36


## Body parts on `root` (rebuilt fresh). Returns {"arm_l", "arm_r", "leg_l", "leg_r", "shirt"}.
static func build_body(root: Node3D, look: Dictionary, shirt: Color) -> Dictionary:
	var b: Array = BUILDS[clampi(int(look.get("build", 0)), 0, BUILDS.size() - 1)]
	var skin := SKINS[clampi(int(look.get("skin", 0)), 0, SKINS.size() - 1)]
	var r: float = b[1]
	var torso_len: float = b[2]
	var shoulder: float = b[3]
	var hip_y := SHOULDER_Y + 0.05 - torso_len - r * 0.6
	var limbs := {"shirt": []}
	var torso := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = torso_len + r * 1.2
	torso.mesh = cm
	torso.material_override = Build.mat(shirt, 0.0, "cloth")
	torso.position.y = hip_y + cm.height * 0.5 - r * 0.15
	torso.scale.z = 0.8
	root.add_child(torso)
	limbs.shirt.append(torso)
	# Sailor's collar flap behind and a neckerchief in front.
	Build.box(root, Vector3(r * 1.6, 0.22, 0.04), Vector3(0, SHOULDER_Y - 0.02, r * 0.82), NAVY, false)
	var tie := Build.box(root, Vector3(0.1, 0.14, 0.04), Vector3(0, SHOULDER_Y - 0.12, -r * 0.82), Color("#1E1E20"), false)
	tie.rotation.z = PI / 4.0
	Build.box(root, Vector3(r * 2.0, 0.1, r * 1.4), Vector3(0, hip_y + 0.02, 0), NAVY, false).material_override = Build.mat(NAVY, 0.0, "cloth") # belt line
	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(side * r * 0.45, hip_y, 0)
		root.add_child(leg)
		# Dungarees: wide bell-bottoms flaring to a turned-up cuff over the boot.
		var ll := hip_y - 0.1
		Build.lathe(leg, [Vector2(0, -ll), Vector2(0.13, -ll), Vector2(0.135, -ll + 0.06), Vector2(0.12, -ll + 0.07),
				Vector2(0.1, -ll * 0.45), Vector2(0.115, 0.0), Vector2(0, 0.0)], Vector3.ZERO, NAVY, Vector3.UP, 14) \
				.material_override = Build.mat(NAVY, 0.0, "cloth")
		Build.box(leg, Vector3(0.21, 0.15, 0.34), Vector3(0, -hip_y + 0.075, -0.06), BOOTS, false) # chunky boots
		limbs["leg_l" if side < 0.0 else "leg_r"] = leg
		var arm := Node3D.new()
		arm.position = Vector3(side * shoulder, SHOULDER_Y, 0)
		root.add_child(arm)
		var sleeve := Build.lathe(arm, [Vector2(0, 0.04), Vector2(0.085, 0.04), Vector2(0.09, -0.24), Vector2(0.1, -0.3), Vector2(0, -0.3)],
				Vector3.ZERO, shirt, Vector3.UP, 14) # sleeve, a little wider at the cuff
		sleeve.material_override = Build.mat(shirt, 0.0, "cloth")
		limbs.shirt.append(sleeve)
		Build.cyl(arm, 0.095, 0.3, Vector3(0, -0.42, 0), skin) # big forearm
		Build.sphere(arm, 0.1, Vector3(0, -0.62, 0), skin) # big hand
		limbs["arm_l" if side < 0.0 else "arm_r"] = arm
	return limbs


## The face on `face` (a node at the head's centre, looking down -Z): Sea of Thieves-ish,
## a round head on a chunky jaw, big eyes with a glint under heavy brows, rosy cheeks, a
## bulbous nose, a crooked smile, ears with a fold in them.
static func build_face(face: Node3D, look: Dictionary) -> void:
	var skin := SKINS[clampi(int(look.get("skin", 0)), 0, SKINS.size() - 1)]
	var hair_c := HAIR_COLOURS[clampi(int(look.get("hair_col", 0)), 0, HAIR_COLOURS.size() - 1)]
	var dark := skin.darkened(0.08)
	var head := Build.sphere(face, 0.24, Vector3(0, -0.05, 0), skin)
	head.scale = Vector3(0.95, 1.05, 1.0)
	var jaw := Build.sphere(face, 0.17, Vector3(0, -0.15, -0.07), skin)
	jaw.scale = Vector3(1.2, 0.85, 1.0)
	var nose := Build.sphere(face, 0.062, Vector3(0, -0.07, -0.255), dark)
	nose.scale = Vector3(0.95, 0.9, 1.25)
	Build.sphere(face, 0.035, Vector3(0, -0.02, -0.235), dark).scale = Vector3(0.9, 1.6, 1.0) # bridge
	for side in [-1.0, 1.0]:
		var ear := Build.sphere(face, 0.06, Vector3(side * 0.235, -0.05, 0.0), dark)
		ear.scale = Vector3(0.45, 1.0, 0.75)
		var fold := Build.sphere(face, 0.035, Vector3(side * 0.255, -0.05, -0.005), skin.darkened(0.25))
		fold.scale = Vector3(0.3, 1.0, 0.7)
		# The eye: white, a dark iris looking a touch inward, and a glint.
		var white := Build.sphere(face, 0.042, Vector3(side * 0.085, 0.015, -0.205), Color("#F4F0E6"))
		white.scale = Vector3(1.0, 1.1, 0.55)
		Build.sphere(face, 0.024, Vector3(side * 0.08, 0.012, -0.229), Color("#1C1A18")).scale = Vector3(1.0, 1.15, 0.5)
		Build.sphere(face, 0.008, Vector3(side * 0.08 + 0.008, 0.024, -0.241), Color.WHITE, 1.5)
		var lid := Build.sphere(face, 0.046, Vector3(side * 0.085, 0.032, -0.2), dark)
		lid.scale = Vector3(1.05, 0.45, 0.6) # heavy upper lid
		var brow := Build.box(face, Vector3(0.12, 0.04, 0.05), Vector3(side * 0.09, 0.085, -0.21), hair_c.darkened(0.2), false)
		brow.rotation.z = side * -0.18
		brow.material_override = Build.mat(hair_c.darkened(0.2), 0.0, "hair")
		var cheek := Build.sphere(face, 0.05, Vector3(side * 0.12, -0.075, -0.185), skin.lerp(Color("#D9665A"), 0.28))
		cheek.scale = Vector3(1.0, 0.8, 0.5)
	# A crooked smile, and a lower lip under it.
	var mouth := Build.arc(face, Vector2(0.01, -0.105), 0.065, PI * 1.2, PI * 1.82, 0.016, -0.232, -0.212, Color("#5A2420"), 8)
	mouth.position.z = -0.222
	var lip := Build.sphere(face, 0.03, Vector3(0.01, -0.185, -0.215), skin.lerp(Color("#C0605A"), 0.35))
	lip.scale = Vector3(1.4, 0.5, 0.6)
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
	match HAIRS[clampi(kind, 0, HAIRS.size() - 1)]:
		"Bald":
			pass
		"Slicked back":
			var cap := Build.sphere(face, 0.245, Vector3(0, 0.0, 0.03), c)
			cap.scale = Vector3(1.0, 0.75, 1.05)
		"Long":
			Build.sphere(face, 0.25, Vector3(0, 0.02, 0.02), c).scale = Vector3(1.0, 0.8, 1.0)
			Build.box(face, Vector3(0.42, 0.42, 0.14), Vector3(0, -0.2, 0.14), c, false)
		"Ponytail":
			Build.sphere(face, 0.248, Vector3(0, 0.02, 0.02), c).scale = Vector3(1.0, 0.78, 1.0)
			var tail := Build.cyl(face, 0.05, 0.3, Vector3(0, -0.1, 0.28), c)
			tail.rotation.x = 0.4
		"Mohawk":
			Build.box(face, Vector3(0.06, 0.16, 0.4), Vector3(0, 0.21, 0.02), c, false)
		"Curly":
			for k in 9:
				var a := k * TAU / 9.0
				Build.sphere(face, 0.09, Vector3(cos(a) * 0.17, 0.13, sin(a) * 0.17 + 0.03), c)
		_: # cropped
			Build.sphere(face, 0.245, Vector3(0, 0.03, 0.02), c).scale = Vector3(1.0, 0.7, 1.0)


static func _beard(face: Node3D, kind: int, c: Color, skin: Color) -> void:
	match BEARDS[clampi(kind, 0, BEARDS.size() - 1)]:
		"Stubble":
			var s := Build.sphere(face, 0.235, Vector3(0, -0.1, -0.02), skin.lerp(c, 0.35))
			s.scale = Vector3(1.0, 0.6, 1.02)
		"Full beard":
			var s := Build.sphere(face, 0.2, Vector3(0, -0.2, -0.1), c)
			s.scale = Vector3(1.1, 1.0, 0.9)
		"Goatee":
			Build.box(face, Vector3(0.08, 0.12, 0.06), Vector3(0, -0.24, -0.2), c, false)
		"Mutton chops":
			for side in [-1.0, 1.0]:
				Build.box(face, Vector3(0.08, 0.2, 0.12), Vector3(side * 0.19, -0.12, -0.1), c, false)
		"Big moustache":
			for side in [-1.0, 1.0]:
				var m := Build.box(face, Vector3(0.14, 0.05, 0.05), Vector3(side * 0.07, -0.11, -0.24), c, false)
				m.rotation.z = side * 0.35
		"Braided beard":
			var s := Build.sphere(face, 0.17, Vector3(0, -0.2, -0.1), c)
			s.scale = Vector3(1.0, 0.8, 0.9)
			for k in 3:
				Build.sphere(face, 0.05, Vector3(0, -0.36 - k * 0.08, -0.16), c.darkened(0.1 * (k % 2)))


static func _extra(face: Node3D, kind: int, skin: Color) -> void:
	match EXTRAS[clampi(kind, 0, EXTRAS.size() - 1)]:
		"Eyepatch":
			Build.box(face, Vector3(0.09, 0.09, 0.03), Vector3(-0.085, 0.02, -0.235), Color.BLACK, false)
			var strap := Build.box(face, Vector3(0.5, 0.02, 0.02), Vector3(0, 0.07, -0.05), Color.BLACK, false)
			strap.rotation.z = -0.3
		"Gold earring":
			Build.sphere(face, 0.025, Vector3(0.24, -0.12, 0.0), Color("#E8C04A"))
		"Scar":
			var s := Build.box(face, Vector3(0.02, 0.14, 0.02), Vector3(0.1, -0.04, -0.225), skin.lerp(Color("#C0605A"), 0.6), false)
			s.rotation.z = 0.4
		"Pipe":
			var stem := Build.cyl(face, 0.012, 0.14, Vector3(0.05, -0.16, -0.29), Color("#4A3020"), Vector3.BACK)
			stem.rotation.y = 0.3
			Build.cyl(face, 0.035, 0.07, Vector3(0.09, -0.13, -0.35), Color("#5A3A22"))
		"Bandana":
			var band := Build.sphere(face, 0.25, Vector3(0, 0.05, 0.0), Color("#B23A2E"))
			band.scale = Vector3(1.0, 0.6, 1.0)
			Build.box(face, Vector3(0.08, 0.08, 0.12), Vector3(0.06, 0.0, 0.26), Color("#B23A2E"), false)

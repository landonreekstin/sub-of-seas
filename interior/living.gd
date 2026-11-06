class_name Living
extends RefCounted
## The boat lived in (Blaney: "accurate kitchen quarters and living areas, the sub should look
## lived in"; lived in but tidy, family photos and 1940s pin-ups, a busy galley): the galley
## with its cook, pots steaming and a pan frying; place settings in the mess and wardroom;
## photos, pin-ups, curtains, sea bags and sleepers in the bunks; bunks over the reload
## torpedoes, as in the real boats. All of it is built on `i._at`, and none collides but the
## galley counter and the benches.

const STEEL := Color("#B8BCB4")
const IRON := Color("#2B2B26")
const CREAM := Color("#E8DFC4")
const SKIN := Color("#E0B48C")
const TINS := [Color("#B23A2E"), Color("#2F4A2E"), Color("#3E5770"), Color("#C9A04A"), Color("#E8DFC4")]


## The galley along one wall, `side` (-1 port), from `za` to `zb`: the range with pots on it at
## the forward end, a work counter with bread, the sink, shelves of tins behind fiddle rails,
## and the cook at the stove. Keeps the wall clutter off it (`wall_gear`).
static func galley(i: SubInterior, c: Dictionary, side: float, za: float, zb: float) -> void:
	var red := i.sub_class.key == "typhoon"
	var at := i._at
	var w := SubInterior.HALF_WIDTH
	var x := side * (w - 0.32)
	var span := zb - za
	c["wall_gear"] = c.get("wall_gear", []) + [[side, za - 0.3, zb + 0.3]]
	Build.box(at, Vector3(0.6, 0.88, span), Vector3(x, 0.44, (za + zb) * 0.5), STEEL)
	var face := side * (w - 0.625) # the cupboard fronts
	var k := za + 0.3
	while k < zb - 0.2:
		Build.box(at, Vector3(0.02, 0.6, 0.02), Vector3(face, 0.45, k + 0.25), Color("#8A8F86"), false)
		Build.box(at, Vector3(0.03, 0.03, 0.12), Vector3(face - side * 0.015, 0.7, k + 0.12), SubInterior.BRASS, false)
		k += 0.5
	# The range: black iron top, two oven doors, rings glowing dull under the pots.
	var rz := za + 0.65
	Build.box(at, Vector3(0.62, 0.05, 1.2), Vector3(x, 0.905, rz), IRON, false)
	for dz in [-0.28, 0.28]:
		Build.box(at, Vector3(0.02, 0.4, 0.5), Vector3(face - side * 0.01, 0.5, rz + dz), IRON, false)
		Build.box(at, Vector3(0.03, 0.03, 0.3), Vector3(face - side * 0.03, 0.66, rz + dz), STEEL, false)
	for p: Array in [[-0.32, 0.16, 0.34, true], [0.0, 0.13, 0.2, true], [0.32, 0.0, 0.0, false]]:
		var pz: float = rz + float(p[0])
		Build.cyl(at, 0.12, 0.01, Vector3(x, 0.935, pz), Color("#E2643A").darkened(0.3), Vector3.UP).material_override = Build.mat(Color("#E2643A"), 0.6)
		if p[1] > 0.0: # a pot with its lid, steaming
			Build.cyl(at, p[1], p[2], Vector3(x, 0.94 + p[2] * 0.5, pz), Color("#8A8F86"))
			Build.cyl(at, float(p[1]) + 0.01, 0.02, Vector3(x, 0.95 + p[2], pz), Color("#6E756C"))
			Build.sphere(at, 0.02, Vector3(x, 0.97 + p[2], pz), IRON)
			var steam := Build.particles(at, Color(1, 1, 1, 0.3), 10, 2.2, Vector3.UP, 0.25, 20.0, Vector3(0, 0.04, 0), 0.09)
			steam.position = Vector3(x, 0.98 + p[2], pz)
		else: # the frying pan, and what's in it
			Build.cyl(at, 0.14, 0.03, Vector3(x, 0.955, pz), IRON)
			Build.box(at, Vector3(0.03, 0.02, 0.22), Vector3(x - side * 0.05, 0.96, pz + 0.24), IRON, false).rotation.y = side * 0.4
			for e in 3:
				Build.cyl(at, 0.035, 0.015, Vector3(x + (e - 1) * 0.06, 0.975, pz + (e % 2) * 0.05 - 0.02), Color("#8A5A32"))
			Sfx.loop_at(at, "galley_loop", Vector3(x, 1.0, pz), -4.0, 2.5)
			var smoke := Build.particles(at, Color(1, 1, 1, 0.18), 8, 1.6, Vector3.UP, 0.3, 30.0, Vector3(0, 0.05, 0), 0.07)
			smoke.position = Vector3(x, 1.0, pz)
	# A hood over the range.
	Build.box(at, Vector3(0.5, 0.3, 1.3), Vector3(side * (w - 0.27), 1.95, rz), STEEL, false)
	# The work counter: maple top, a cutting board and knife, loaves, a mixing bowl.
	var wz := minf(za + 1.6, zb - 0.9)
	Build.box(at, Vector3(0.62, 0.04, maxf(0.4, zb - za - 2.0)), Vector3(x, 0.9, (za + 1.25 + zb - 0.75) * 0.5), Color("#C8A878"), false)
	Build.box(at, Vector3(0.3, 0.02, 0.4), Vector3(x, 0.93, wz), Color("#A88458"), false)
	Build.box(at, Vector3(0.02, 0.01, 0.2), Vector3(x + 0.05, 0.945, wz), STEEL, false)
	for b in 2:
		Build.box(at, Vector3(0.13, 0.1, 0.26), Vector3(x - side * 0.05, 0.97, wz + 0.4 + b * 0.18), Color("#C08A4A"), false)
	Build.cyl(at, 0.12, 0.09, Vector3(x + side * 0.08, 0.965, wz - 0.35), CREAM)
	# The sink at the after end, a faucet over it.
	var sz := zb - 0.4
	Build.box(at, Vector3(0.44, 0.02, 0.5), Vector3(x, 0.925, sz), Color("#6E756C"), false)
	Build.cyl(at, 0.015, 0.3, Vector3(side * (w - 0.12), 1.05, sz), STEEL)
	Build.cyl(at, 0.015, 0.16, Vector3(side * (w - 0.2), 1.19, sz), STEEL, Vector3.RIGHT)
	# Shelves of tins behind fiddle rails (so they stay put in a seaway), over the counter.
	var s0 := za + 1.4
	for y in [1.4, 1.72]:
		Build.box(at, Vector3(0.26, 0.03, zb - s0), Vector3(side * (w - 0.15), y, (s0 + zb) * 0.5), SubInterior.WOOD, false)
		Build.box(at, Vector3(0.01, 0.06, zb - s0), Vector3(side * (w - 0.28), y + 0.05, (s0 + zb) * 0.5), STEEL, false)
		var t := s0 + 0.06
		var n := 0
		while t < zb - 0.05:
			var tin := Build.cyl(at, 0.04, 0.11, Vector3(side * (w - 0.15), y + 0.07, t), TINS[(n / 3) % TINS.size()])
			tin.position.x += side * ((n % 2) * 0.06 - 0.03)
			t += 0.09
			n += 1
	# Ladles and a skimmer on a rail between the counter and the shelves.
	for u in 4:
		var uz := s0 + 0.2 + u * 0.15
		Build.cyl(at, 0.008, 0.28, Vector3(side * (w - 0.1), 1.17, uz), STEEL)
		Build.sphere(at, 0.035, Vector3(side * (w - 0.1), 1.02, uz), STEEL)
	var title := Build.label(at, "КАМБУЗ" if red else "GALLEY", Vector3(side * (w - 0.04), 2.2, rz), 22, IRON)
	title.rotation.y = -side * PI / 2.0
	var spot := Vector3(side * (w - 0.95), 0, rz)
	var range_ := GalleyStation.new().setup("galley", "Galley range") as GalleyStation
	range_.pan = Vector3(side * 0.32, 0.955, -0.63)
	i._add_station(range_, spot, -side * PI / 2.0)
	range_.cook = cook(i, spot, -side * PI / 2.0)
	FunSpot.add(at, "Cook's special", "[E] at the range: take over the stove and fry a meal; [Space] flips it in the green", Vector3(x, 1.35, rz + 0.3))


## The cook at his stove, in his whites and toque, stirring.
static func cook(i: SubInterior, pos: Vector3, rot_y: float) -> Node3D:
	var v := Node3D.new()
	v.position = pos
	v.rotation.y = rot_y
	i._at.add_child(v)
	var body := Node3D.new()
	v.add_child(body)
	var look := {"build": 2, "skin": 1, "hair": 3, "hair_col": 2, "beard": 0}
	var parts := Crewman.build_body(body, look, Color("#F2F0E8"))
	var face := Node3D.new()
	face.position.y = Player.EYE_HEIGHT
	v.add_child(face)
	Crewman.build_face(face, look)
	Build.cyl(face, 0.11, 0.08, Vector3(0, 0.1, 0.01), Color("#F2F0E8"))
	Build.cyl(face, 0.13, 0.12, Vector3(0, 0.2, 0.01), Color("#F2F0E8"))
	Build.box(v, Vector3(0.34, 0.6, 0.02), Vector3(0, 0.85, -0.2), Color("#F2F0E8"), false) # apron
	i._stirring.append(parts.arm_r)
	parts.arm_l.rotation.x = 0.7
	return v


## Benches along a mess table at `tx`, `tz` (length along z), and, when `set`, places laid:
## plates with knives and forks, salt, pepper and the ketchup, a bread plate.
static func table_settings(i: SubInterior, tx: float, tz: float, top: float, length: float, laid: bool) -> void:
	var at := i._at
	for bx in [tx - 0.68, tx + 0.58]:
		if i.stations.values().any(func(st: Station) -> bool: return st.get_parent() == at and absf(st.position.x - bx) < 0.6 and absf(st.position.z - tz) < length * 0.5 + 0.3):
			continue # a station stands there
		Build.box(at, Vector3(0.26, 0.42, length - 0.1), Vector3(bx, 0.21, tz), SubInterior.WOOD)
		Build.box(at, Vector3(0.28, 0.03, length - 0.05), Vector3(bx, 0.43, tz), Color("#3E5770"), false) # the cushion
	if not laid:
		return
	for px in [tx - 0.3, tx + 0.3]:
		for pz in [tz - 0.5, tz + 0.5]:
			Build.cyl(at, 0.1, 0.015, Vector3(px, top + 0.01, pz), CREAM)
			Build.box(at, Vector3(0.015, 0.005, 0.15), Vector3(px, top + 0.005, pz - 0.14), STEEL, false)
			Build.box(at, Vector3(0.015, 0.005, 0.15), Vector3(px, top + 0.005, pz + 0.14), STEEL, false)
			Build.cyl(at, 0.035, 0.08, Vector3(px + signf(tx - px) * 0.14, top + 0.04, pz + 0.12), CREAM)
	Build.cyl(at, 0.018, 0.06, Vector3(tx - 0.04, top + 0.03, tz), Color("#F2F0E8"))
	Build.cyl(at, 0.018, 0.06, Vector3(tx + 0.04, top + 0.03, tz), Color("#5A5E56"))
	Build.cyl(at, 0.03, 0.17, Vector3(tx, top + 0.085, tz + 0.12), Color("#B23A2E"))
	Build.cyl(at, 0.015, 0.03, Vector3(tx, top + 0.18, tz + 0.12), Color("#F2F0E8"))
	Build.cyl(at, 0.13, 0.015, Vector3(tx, top + 0.01, tz - 0.2), CREAM)
	for b in 3:
		Build.box(at, Vector3(0.07, 0.04, 0.05), Vector3(tx - 0.04 + b * 0.04, top + 0.035, tz - 0.2 + (b % 2) * 0.03), Color("#C08A4A"), false)


## The arm-wrestling seats across a table at `tx`, `tz`: one each side, on the benches.
static func arm_table(i: SubInterior, tx: float, tz: float, top: float) -> void:
	for k in 2:
		var a := ArmStation.new().setup(Pastimes.ARM[k], "Arm wrestling") as ArmStation
		a.top = top
		a.reach = 0.68 if k == 0 else 0.58
		i._add_station(a, Vector3(tx - 0.68 if k == 0 else tx + 0.58, 0, tz), -PI / 2.0 if k == 0 else PI / 2.0)
	FunSpot.add(i._at, "Arm wrestling", "[E] at a seat across the table, then tap [Space] as fast as you can; [B] at the empty seat sits a bot down to take you on", Vector3(tx, top + 0.6, tz))


## Seats at a card table (blackjack against the house): [x, z, rot_y] each, the table's top.
static func card_seats(i: SubInterior, seats: Array, top: float, centre: Vector3) -> void:
	for k in seats.size():
		var c := CardsStation.new().setup(Pastimes.CARDS[k], "Blackjack") as CardsStation
		c.top = top
		c.reach = Vector2(seats[k][0], seats[k][1]).distance_to(Vector2(centre.x, centre.z))
		i._add_station(c, Vector3(seats[k][0], 0, seats[k][1]), seats[k][2])
	FunSpot.add(i._at, "Blackjack", "[E] at a seat at the card table: [Space] deals and hits, [S] stands; beat the house to 21", centre + Vector3(0, top + 0.6, 0))


## A cribbage board mid-game and a deck of cards.
static func cribbage(i: SubInterior, pos: Vector3) -> void:
	Build.box(i._at, Vector3(0.1, 0.025, 0.36), pos + Vector3(0, 0.012, 0), Color("#A88458"), false)
	Build.cyl(i._at, 0.008, 0.04, pos + Vector3(-0.02, 0.04, -0.05), Color("#B23A2E"))
	Build.cyl(i._at, 0.008, 0.04, pos + Vector3(0.02, 0.04, 0.08), Color("#3E5770"))
	Build.box(i._at, Vector3(0.065, 0.03, 0.09), pos + Vector3(0.14, 0.015, 0), Color("#F2F0E8"), false)


## Something pinned up, facing +Z then turned by `rot_y`: "pinup" (a painted 1940s girl, fully
## dressed, the Typhoon's a Soviet film poster), "family" (a framed photo of home), "letter".
static func picture(i: SubInterior, pos: Vector3, rot_y: float, kind: String, k: int) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rot_y
	i._at.add_child(n)
	var red := i.sub_class.key == "typhoon"
	match kind:
		"pinup":
			var skies := [Color("#4F8A9A"), Color("#D9845A"), Color("#E8C25A"), Color("#7FA6C9")]
			var dresses := [Color("#C23A32"), Color("#2B4A8A"), Color("#2F6A4A"), Color("#E8DFC4")]
			var hairs := [Color("#E8C27A"), Color("#5A3A22"), Color("#8A2E1E"), Color("#1E1E20")]
			Build.box(n, Vector3(0.3, 0.42, 0.006), Vector3.ZERO, CREAM, false)
			Build.box(n, Vector3(0.26, 0.32, 0.004), Vector3(0, 0.03, 0.004), Color("#B23A2E") if red else skies[k % 4], false)
			var dress: Color = dresses[(k / 4) % 4]
			for lx in [-0.018, 0.018]:
				Build.box(n, Vector3(0.018, 0.1, 0.004), Vector3(lx, -0.08, 0.008), SKIN, false)
			Build.box(n, Vector3(0.11, 0.08, 0.004), Vector3(0, -0.01, 0.009), dress, false) # skirt
			Build.box(n, Vector3(0.06, 0.07, 0.004), Vector3(0, 0.06, 0.009), dress, false) # bodice
			var arm := Build.box(n, Vector3(0.014, 0.08, 0.004), Vector3(0.045, 0.11, 0.009), SKIN, false)
			arm.rotation.z = -0.6
			Build.cyl(n, 0.032, 0.004, Vector3(0, 0.13, 0.008), hairs[(k / 2) % 4], Vector3.BACK)
			Build.cyl(n, 0.024, 0.004, Vector3(0, 0.122, 0.011), SKIN, Vector3.BACK)
			var captions := ["КИНО", "СЛАВА ФЛОТУ", "ЛЮБИМАЯ"] if red else ["MISS PACIFIC", "KEEP 'EM SAILING", "SWEETHEART"]
			Build.label(n, captions[k % 3], Vector3(0, -0.17, 0.008), 9, IRON)
		"family":
			Build.box(n, Vector3(0.16, 0.12, 0.01), Vector3.ZERO, Color("#5A3E26"), false)
			Build.box(n, Vector3(0.13, 0.09, 0.004), Vector3(0, 0, 0.006), Color("#C8B48A"), false)
			for f in 2 + k % 2:
				var fx := -0.035 + f * 0.035
				Build.cyl(n, 0.012, 0.003, Vector3(fx, 0.01 - (f % 2) * 0.008, 0.009), Color("#6B5A44"), Vector3.BACK)
				Build.box(n, Vector3(0.026, 0.03, 0.003), Vector3(fx, -0.025 - (f % 2) * 0.008, 0.009), Color("#8A7458"), false)
		"letter":
			var l := Build.box(n, Vector3(0.12, 0.16, 0.003), Vector3.ZERO, Color("#F2F0E8"), false)
			l.rotation.z = (k % 5 - 2) * 0.06
			for r in 5:
				Build.box(n, Vector3(0.08, 0.004, 0.002), Vector3(0, 0.05 - r * 0.022, 0.003), Color("#3E5770"), false)


## A sailor asleep in his bunk on his back, head forward on the pillow, the blanket over him.
static func sleeper(i: SubInterior, pos: Vector3, bay: float, n: int) -> void:
	var pivot := Node3D.new()
	pivot.position = pos + Vector3(0, 0, bay * 0.42)
	pivot.rotation.y = PI
	i._at.add_child(pivot)
	var v := Node3D.new()
	v.rotation.x = PI / 2.0
	v.scale = Vector3.ONE * 0.92
	pivot.add_child(v)
	var body := Node3D.new()
	v.add_child(body)
	var look := {"build": n % 4, "skin": n % 3, "hair": n % 7, "hair_col": (n + 2) % 7, "beard": n % 3}
	Crewman.build_body(body, look, Color.from_hsv(0.58, 0.45, 0.85))
	var face := Node3D.new()
	face.position.y = Player.EYE_HEIGHT
	v.add_child(face)
	Crewman.build_face(face, look)
	Build.box(i._at, Vector3(0.66, 0.06, bay * 0.6), pos + Vector3(0, 0.2, bay * 0.12), Color("#3E5770"), false)


## Lived-in touches on one bunk at `pos` (the pan's centre) against the wall on `side`.
## `low`: the bottom tier, with shoes under it; `top`: no picture over it (the pipes).
static func bunk_touches(i: SubInterior, pos: Vector3, side: float, bay: float, n: int, low: bool, top: bool) -> void:
	var w := SubInterior.HALF_WIDTH
	if not top and n % 3 != 2:
		picture(i, Vector3(side * (w - 0.03), pos.y + 0.42, pos.z + (n % 2 - 0.5) * 0.4), -side * PI / 2.0, ["family", "pinup", "family", "letter"][n % 4], n)
	if n % 3 == 0: # a curtain drawn part way along the aisle side, on its rod
		Build.cyl(i._at, 0.008, bay - 0.2, Vector3(side * 1.24, pos.y + 0.58, pos.z), STEEL, Vector3.BACK)
		for f in 4: # gathered in folds
			Build.box(i._at, Vector3(0.015, 0.46, bay * 0.1), Vector3(side * (1.24 + (f % 2) * 0.03), pos.y + 0.35, pos.z + bay * (0.12 + f * 0.09)), Color("#CFC6A8").darkened((f % 2) * 0.12), false)
	if n % 4 == 1: # his sea bag at the foot
		Build.cyl(i._at, 0.11, 0.42, Vector3(side * 1.6, pos.y + 0.24, pos.z + bay * 0.36), CREAM, Vector3.RIGHT)
	elif n % 4 == 3: # a book or a magazine
		Build.box(i._at, Vector3(0.14, 0.025, 0.2), Vector3(side * 1.5, pos.y + 0.21, pos.z), TINS[n % TINS.size()], false).rotation.y = 0.4
	if low and n % 2 == 0: # his shoes under the bunk, side by side
		for s in 2:
			Build.box(i._at, Vector3(0.1, 0.07, 0.26), Vector3(side * 1.45 - s * 0.12 * side, 0.035, pos.z - 0.3), IRON, false)
	if n % 5 == 2: # a towel over the stanchion
		Build.box(i._at, Vector3(0.03, 0.4, 0.16), Vector3(side * 1.2, pos.y + 0.2, pos.z - bay * 0.5 + 0.08), Color("#F2F0E8"), false)


## Fold-down bunks over the top reload torpedoes, slung on chains, as in the real boats' torpedo
## rooms, where men slept with the fish.
static func torpedo_bunks(i: SubInterior, rz0: float, rz1: float) -> void:
	var count := maxi(1, int((rz1 - rz0) / 2.1))
	var bay := (rz1 - rz0) / count
	for side in [-1.0, 1.0]:
		for b in count:
			var mid := rz0 + bay * (b + 0.5)
			var k := int(absf(mid) * 7.0) + (3 if side > 0.0 else 0)
			Build.box(i._at, Vector3(0.7, 0.05, bay - 0.15), Vector3(side * 1.5, 1.6, mid), Color("#5A5E56"), false)
			Build.box(i._at, Vector3(0.62, 0.08, bay - 0.3), Vector3(side * 1.5, 1.66, mid), SubInterior.BUNK, false)
			Build.box(i._at, Vector3(0.6, 0.04, (bay - 0.3) * 0.55), Vector3(side * 1.5, 1.72, mid + bay * 0.15), Color("#3E5770"), false)
			Build.box(i._at, Vector3(0.4, 0.07, 0.25), Vector3(side * 1.5, 1.73, mid - bay * 0.32), Color("#F2F0E8"), false)
			for dz in [-0.5, 0.5]:
				Build.cyl(i._at, 0.01, 0.7, Vector3(side * 1.16, 1.95, mid + dz * (bay - 0.3)), Color("#8A8F86"))
			if k % 3 == 0:
				Build.cyl(i._at, 0.1, 0.38, Vector3(side * 1.5, 1.78, mid + bay * 0.34), CREAM, Vector3.RIGHT)

class_name Profile
extends RefCounted
## A player's own record, kept on their machine (user://profile.cfg): career totals, rank,
## and the look they picked. Rank comes from merit: tons sunk plus 5,000 per patrol brought
## home. Each rank unlocks a hat. Training patrols don't count.

const PATH := "user://profile.cfg"
const RANKS := [
	["Seaman", "S1c", 0], ["Petty Officer", "PO", 15000], ["Chief", "CPO", 40000],
	["Ensign", "Ens", 80000], ["Lieutenant", "Lt", 140000], ["Commander", "Cdr", 220000],
]
## Hat key -> [name, rank index it unlocks at].
const HATS := {
	"dixie": ["White Dixie cup", 0], "watch": ["Watch cap", 1], "ball": ["Ball cap", 2],
	"officer": ["Officer's cap", 3], "skipper": ["Salt-stained skipper's cap", 5],
}
const SHIRTS := [0.58, 0.0, 0.08, 0.15, 0.33, 0.5, 0.7, 0.85] ## hues to pick from; -1 = by player number

var merit := 0
var tons := 0
var ships := 0
var patrols := 0
var hat := "dixie"
var shirt_hue := -1.0
## Indexes into Crewman's lists: build, skin, hair, hair colour, beard, extra.
var face := {"build": 0, "skin": 0, "hair": 0, "hair_col": 0, "beard": 0, "extra": 0}


static func load_or_new() -> Profile:
	var p := Profile.new()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		p.merit = cfg.get_value("career", "merit", 0)
		p.tons = cfg.get_value("career", "tons", 0)
		p.ships = cfg.get_value("career", "ships", 0)
		p.patrols = cfg.get_value("career", "patrols", 0)
		p.hat = cfg.get_value("look", "hat", "dixie")
		p.shirt_hue = cfg.get_value("look", "shirt_hue", -1.0)
		for k: String in p.face:
			p.face[k] = int(cfg.get_value("look", k, 0))
	if not p.unlocked(p.hat):
		p.hat = "dixie"
	return p


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("career", "merit", merit)
	cfg.set_value("career", "tons", tons)
	cfg.set_value("career", "ships", ships)
	cfg.set_value("career", "patrols", patrols)
	cfg.set_value("look", "hat", hat)
	cfg.set_value("look", "shirt_hue", shirt_hue)
	for k: String in face:
		cfg.set_value("look", k, face[k])
	cfg.save(PATH)


static func rank_for(m: int) -> int:
	var r := 0
	for i in RANKS.size():
		if m >= int(RANKS[i][2]):
			r = i
	return r


func rank() -> int:
	return rank_for(merit)


func unlocked(h: String) -> bool:
	return HATS.has(h) and rank() >= int(HATS[h][1])


## Credit a finished patrol. Returns the new rank's name if this was a promotion, else "".
func credit(sunk_tons: int, sunk_ships: int, came_home: bool) -> String:
	var before := rank()
	tons += sunk_tons
	ships += sunk_ships
	merit += sunk_tons + (5000 if came_home else 0)
	if came_home:
		patrols += 1
	save()
	return RANKS[rank()][0] if rank() > before else ""


## What the host and other players need to draw this sailor.
func looks() -> Dictionary:
	var l := {"hat": hat, "hue": shirt_hue, "rank": rank()}
	l.merge(face)
	return l

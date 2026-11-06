class_name CardsStation
extends Station
## A seat at the card table (Blaney: cards in the mess): blackjack against the house, which the
## host deals (Pastimes.cards_order). The hands lie face up on the table for anyone to see.

var seated := true
var reach := 0.75 ## from the seat to the middle of the table
var top := 0.74
var _cards: Node3D
var _shown := ""
var _lines: Array[Label] = []


func _ready() -> void:
	Build.area(self, Vector3(0.6, 0.3, 0.5), Vector3(0, top + 0.1, -reach * 0.55))
	set_view(Vector3(0, 1.2, 0.05), Vector3(0, top, -reach * 0.7))
	bot_arms = Vector2(0.9, 1.1)
	bot_lean = 0.25
	_cards = Node3D.new()
	add_child(_cards)


func _table() -> Dictionary:
	return Game.instance.crew.get("cards", {}).get(station_id, {}) if Game.instance != null else {}


func _process(_delta: float) -> void:
	var t := _table()
	var key := str(t)
	if key != _shown:
		_shown = key
		_lay(t)
	if overlay == null:
		return
	if t.is_empty() or t.get("state", "idle") == "idle":
		_lines[0].text = "Press Space for a hand. Get closer to 21 than the house without going over."
		_lines[1].text = ""
		_lines[2].text = ""
	else:
		_lines[0].text = "YOUR HAND  %s   = %d" % [_names(t.hand), Pastimes.hand_value(t.hand)]
		_lines[1].text = "THE HOUSE  %s   = %d" % [_names(t.house), Pastimes.hand_value(t.house)]
		_lines[2].text = String(t.result) if t.state == "done" else ""
		_lines[2].add_theme_color_override("font_color", UiKit.GOOD if String(t.result) in ["YOU WIN", "BLACKJACK!"] else (UiKit.BAD if t.result != "PUSH" else UiKit.WARN))
	var wins: Dictionary = Game.instance.crew.get("cards_wins", {})
	_lines[3].text = "Hands won: %d" % int(wins.get(Game.instance.crew_name(multiplayer.get_unique_id()), 0))
	_lines[4].text = ("[Space] another hand    " if t.get("state", "idle") != "play" else "[Space] hit (another card)   [S] stand    ") + footer(false)


func _names(hand: Array) -> String:
	var out: Array[String] = []
	for c: int in hand:
		out.append(Pastimes.card_name(c))
	return "  ".join(out)


## The hands face up on the baize: ours in front of us, the house's further over.
func _lay(t: Dictionary) -> void:
	for c in _cards.get_children():
		c.queue_free()
	for row: Array in [[t.get("hand", []), -0.3], [t.get("house", []), -0.55]]:
		var hand: Array = row[0]
		for k in hand.size():
			var at := Vector3((k - (hand.size() - 1) * 0.5) * 0.075, top + 0.004, float(row[1]))
			Build.box(_cards, Vector3(0.065, 0.004, 0.09), at, Color("#F2F0E8"), false)
			var red: bool = int(hand[k]) / 13 in [1, 2]
			var l := Build.label(_cards, Pastimes.card_name(int(hand[k])), at + Vector3(0, 0.004, 0), 28, Color("#B23A2E") if red else Color("#1E1E20"))
			l.pixel_size = 0.0011
			l.rotation.x = -PI / 2.0


func _build_overlay(root: Control) -> void:
	var box := UiKit.bottom_panel(root)
	box.add_child(UiKit.label("BLACKJACK — against the house", 22, UiKit.BRASS))
	_lines.clear()
	for k in 5:
		var l := UiKit.label("", 18 if k < 3 else 14, UiKit.CREAM if k < 4 else UiKit.DIM)
		box.add_child(l)
		_lines.append(l)


func station_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_echo():
		return
	if key_pressed(event, KEY_SPACE):
		order("hit" if _table().get("state", "idle") == "play" else "deal")
		click(0.0, 1.6)
	elif key_pressed(event, KEY_S) and _table().get("state", "idle") == "play":
		order("stand")
		click(0.0, 1.2)

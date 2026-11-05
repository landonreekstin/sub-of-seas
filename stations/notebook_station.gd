class_name NotebookStation
extends Station
## The notebooks in the Typhoon's command bay (Blaney). The first mate's lists everything wrong
## with the boat; a bot or a player can hold it, a bot sends the damage parties himself and a
## player with [F]. The skipper's says what's most pressing, and to check in with the first mate
## when he has news.

var kind := "first_mate"
var _page: Label
var _sub_line: Label


func _ready() -> void:
	Build.box(self, Vector3(0.5, 1.0, 0.4), Vector3(0, 0.5, 0), Color("#6B5A44"))
	var book := Build.box(self, Vector3(0.36, 0.03, 0.26), Vector3(0, 1.03, 0), Color("#E8DFC4"), false)
	book.rotation.y = 0.15
	Build.box(self, Vector3(0.02, 0.035, 0.26), Vector3(0, 1.035, 0), Color("#7A2E25") if kind == "first_mate" else Color("#3E5770"), false).rotation.y = 0.15
	Build.label(self, "ПОМОЩНИК" if kind == "first_mate" else "КОМАНДИР", Vector3(0, 0.8, 0.21), 22, UiKit.BRASS)
	Build.hitbox(self, Vector3(0.6, 1.15, 0.5), Vector3(0, 0.55, 0))
	set_view(Vector3(0, 1.75, 0.55), Vector3(0, 1.0, 0))
	bot_arms = Vector2(0.7, 0.7)
	bot_lean = 0.15 # reading


func _build_overlay(root: Control) -> void:
	var paper := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#E8DFC4")
	sb.set_content_margin_all(26.0)
	sb.border_color = Color("#6B5A44")
	sb.set_border_width_all(3)
	paper.add_theme_stylebox_override("panel", sb)
	root.add_child(paper)
	paper.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	paper.grow_horizontal = Control.GROW_DIRECTION_BOTH
	paper.grow_vertical = Control.GROW_DIRECTION_BOTH
	var box := VBoxContainer.new()
	paper.add_child(box)
	var ink := Color("#2B2B26")
	var title := UiKit.label("FIRST MATE'S LIST" if kind == "first_mate" else "SKIPPER'S NOTEBOOK", 26, Color("#7A2E25"))
	box.add_child(title)
	_page = UiKit.label("", 19, ink)
	_page.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page.custom_minimum_size = Vector2(760, 320)
	box.add_child(_page)
	_sub_line = UiKit.label("", 15, Color("#5A5444"))
	box.add_child(_sub_line)


func _process(_delta: float) -> void:
	if overlay == null or Sim.world == null or _page == null or not is_instance_valid(_page):
		return
	var game := Game.instance
	var lines: Array[String] = game.bot_crew.problems() if kind == "first_mate" else game.bot_crew.pressing()
	if kind == "first_mate":
		var teams := Sim.world.hull.teams.size()
		_page.text = ("Nothing wrong with the boat." if lines.is_empty() else "• " + "\n• ".join(lines)) + "\n\nDamage parties out: %d" % teams
		_sub_line.text = "[F] turn out the damage parties    " + footer(false)
	else:
		var news: int = int(game.crew.get("mate_news", 0)) - int(game.crew.get("mate_read", 0))
		var head := "CHECK IN WITH THE FIRST MATE: %d new since you last asked.\n\n" % news if news > 0 else ""
		_page.text = head + ("All quiet." if lines.is_empty() else "• " + "\n• ".join(lines))
		_sub_line.text = "[R] read the first mate's list    The PA is by the after bulkhead.    " + footer(false)


func station_input(event: InputEvent) -> void:
	if kind == "first_mate" and key_pressed(event, KEY_F):
		order("party")
	elif kind == "skipper" and key_pressed(event, KEY_R):
		order("read")
		var list: Array[String] = Game.instance.bot_crew.problems()
		Game.instance.hud.show_message("First mate: " + ("nothing wrong, Skipper." if list.is_empty() else " ".join(list.slice(0, 4))), 8.0)

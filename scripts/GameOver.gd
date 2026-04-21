extends Control

const C_BG_TOP := Color(0.04, 0.04, 0.10)
const C_BG_BOT := Color(0.10, 0.05, 0.05)
const C_GOLD   := Color(0.95, 0.78, 0.20)
const C_WHITE  := Color(0.95, 0.95, 0.95)
const C_RED    := Color(0.85, 0.20, 0.20)
const C_BLUE   := Color(0.10, 0.30, 0.70)

var _won: bool = false
var _time: float = 0.0
var _title_label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_won = GameData.stage_won
	_build_background()
	_build_ui()

func _build_background() -> void:
	var grad := Gradient.new()
	grad.set_color(0, C_BG_TOP)
	if _won:
		grad.set_color(1, Color(0.08, 0.10, 0.22))
	else:
		grad.set_color(1, C_BG_BOT)

	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 2
	tex.height = 540

	var tr := TextureRect.new()
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.anchor_right = 1.0
	tr.anchor_bottom = 1.0
	tr.texture = tex
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(tr)

func _build_ui() -> void:
	var title_text := "ניצחון!" if _won else "המשחק נגמר"
	var title_color := C_GOLD if _won else C_RED

	_title_label = _label(title_text, 72, title_color)
	_title_label.size = Vector2(960, 100)
	_title_label.position = Vector2(0, 90)
	_title_label.add_theme_constant_override("shadow_offset_x", 4)
	_title_label.add_theme_constant_override("shadow_offset_y", 4)
	_title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	add_child(_title_label)

	var sub := _label("VICTORY" if _won else "GAME OVER", 20, Color(C_WHITE, 0.55))
	sub.size = Vector2(960, 28)
	sub.position = Vector2(0, 200)
	add_child(sub)

	# Score panel
	var score_panel := Panel.new()
	score_panel.size = Vector2(400, 120)
	score_panel.position = Vector2(280, 250)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0.4)
	s.border_color = C_GOLD
	s.border_width_top    = 2
	s.border_width_bottom = 2
	s.border_width_left   = 2
	s.border_width_right  = 2
	s.corner_radius_top_left     = 10
	s.corner_radius_top_right    = 10
	s.corner_radius_bottom_left  = 10
	s.corner_radius_bottom_right = 10
	score_panel.add_theme_stylebox_override("panel", s)
	add_child(score_panel)

	var score_lbl := _label("ניקוד: %d" % GameData.final_score, 38, C_WHITE)
	score_lbl.size = Vector2(400, 50)
	score_lbl.position = Vector2(0, 14)
	score_panel.add_child(score_lbl)

	var hi_lbl := _label("שיא שלך: %d" % GameData.high_score, 22, C_GOLD)
	hi_lbl.size = Vector2(400, 32)
	hi_lbl.position = Vector2(0, 70)
	score_panel.add_child(hi_lbl)

	# Buttons
	var replay := _button("▶  שחק שוב", Vector2(280, 410), _on_replay)
	add_child(replay)

	var menu := _button("תפריט ראשי", Vector2(500, 410), _on_menu)
	add_child(menu)

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

func _button(text: String, pos: Vector2, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.size = Vector2(200, 52)
	btn.position = pos
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", C_WHITE)
	btn.add_theme_color_override("font_hover_color", C_GOLD)

	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.15, 0.15, 0.35, 0.95)
	s.border_color = Color(C_WHITE, 0.4)
	s.border_width_top    = 2
	s.border_width_bottom = 2
	s.border_width_left   = 2
	s.border_width_right  = 2
	s.corner_radius_top_left     = 10
	s.corner_radius_top_right    = 10
	s.corner_radius_bottom_left  = 10
	s.corner_radius_bottom_right = 10
	btn.add_theme_stylebox_override("normal", s)

	var s2 := s.duplicate() as StyleBoxFlat
	s2.bg_color = Color(0.25, 0.25, 0.55)
	s2.border_color = C_GOLD
	btn.add_theme_stylebox_override("hover", s2)

	btn.pressed.connect(cb)
	return btn

func _process(delta: float) -> void:
	_time += delta
	if is_instance_valid(_title_label):
		var pulse := 1.0 + sin(_time * 2.5) * 0.04
		_title_label.scale = Vector2(pulse, pulse)
		_title_label.pivot_offset = _title_label.size / 2.0

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_on_replay()
	elif event.is_action_pressed("ui_cancel"):
		_on_menu()

func _on_replay() -> void:
	GameData.final_score = 0
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_menu() -> void:
	GameData.final_score = 0
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

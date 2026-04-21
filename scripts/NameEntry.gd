extends Control

const C_BG_TOP := Color(0.03, 0.03, 0.10)
const C_BG_BOT := Color(0.08, 0.10, 0.22)
const C_GOLD := Color(0.95, 0.78, 0.20)
const C_WHITE := Color(0.95, 0.95, 0.95)

var _name_edit: LineEdit
var _error_lbl: Label

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_background()
	_build_ui()


func _build_background() -> void:
	var grad := Gradient.new()
	grad.set_color(0, C_BG_TOP)
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
	var title := Label.new()
	title.text = "איך קוראים לגיבור?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 56)
	title.size = Vector2(960, 48)
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", C_GOLD)
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	var sub := Label.new()
	sub.text = GameData.get_char_data()["name_he"] + " — הזן שם לוחם (עד 16 תווים)"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, 108)
	sub.size = Vector2(960, 28)
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", Color(C_WHITE, 0.6))
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sub)

	_name_edit = LineEdit.new()
	_name_edit.position = Vector2(280, 200)
	_name_edit.size = Vector2(400, 48)
	_name_edit.max_length = 16
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.text = GameData.player_hero_name
	_name_edit.placeholder_text = "למשל: דוד, יוסי..."
	_name_edit.add_theme_font_size_override("font_size", 22)
	add_child(_name_edit)

	_error_lbl = Label.new()
	_error_lbl.position = Vector2(0, 258)
	_error_lbl.size = Vector2(960, 24)
	_error_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_lbl.add_theme_font_size_override("font_size", 14)
	_error_lbl.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35))
	_error_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_error_lbl.visible = false
	add_child(_error_lbl)

	var go := Button.new()
	go.text = "▶  המשך לפתיח"
	go.position = Vector2(330, 320)
	go.size = Vector2(300, 46)
	go.add_theme_font_size_override("font_size", 20)
	_style_button(go)
	go.pressed.connect(_on_continue)
	add_child(go)

	var back := Button.new()
	back.text = "← חזור לבחירת לוחם"
	back.position = Vector2(330, 378)
	back.size = Vector2(300, 36)
	back.flat = true
	back.add_theme_font_size_override("font_size", 16)
	back.add_theme_color_override("font_color", Color(C_WHITE, 0.75))
	back.pressed.connect(_on_back)
	add_child(back)

	call_deferred("_focus_edit")


func _focus_edit() -> void:
	if is_instance_valid(_name_edit):
		_name_edit.grab_focus()


func _style_button(btn: Button) -> void:
	btn.add_theme_color_override("font_color", Color(0.06, 0.06, 0.12))
	var s := StyleBoxFlat.new()
	s.bg_color = C_GOLD
	s.corner_radius_top_left = 10
	s.corner_radius_top_right = 10
	s.corner_radius_bottom_left = 10
	s.corner_radius_bottom_right = 10
	s.border_width_left = 2
	s.border_width_right = 2
	s.border_width_top = 2
	s.border_width_bottom = 2
	s.border_color = Color(1, 1, 1, 0.35)
	btn.add_theme_stylebox_override("normal", s)
	var h := s.duplicate() as StyleBoxFlat
	h.bg_color = C_GOLD.lightened(0.12)
	btn.add_theme_stylebox_override("hover", h)
	var p := s.duplicate() as StyleBoxFlat
	p.bg_color = C_GOLD.darkened(0.12)
	btn.add_theme_stylebox_override("pressed", p)


func _on_continue() -> void:
	var raw: String = _name_edit.text.strip_edges()
	if raw.is_empty():
		_error_lbl.text = "נא להזין שם (אפשר קצר)."
		_error_lbl.visible = true
		return
	GameData.player_hero_name = raw
	_error_lbl.visible = false
	get_tree().change_scene_to_file("res://scenes/IntroSequence.tscn")


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/CharacterSelect.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
	elif event.is_action_pressed("ui_accept") and _name_edit and not _name_edit.has_focus():
		_on_continue()

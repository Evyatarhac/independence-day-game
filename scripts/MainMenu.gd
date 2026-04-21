extends Control

# ─── Palette ───────────────────────────────────────────────────────────────
const C_BLUE := Color(0.10, 0.30, 0.70)
const C_WHITE := Color(0.97, 0.97, 0.97)
const C_BTN := Color(0.06, 0.08, 0.15, 0.86)
const C_BTN_HOV := Color(0.10, 0.14, 0.26, 0.92)

var _title_label: Label
var _time: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchors_preset = Control.PRESET_FULL_RECT
	_build_background()
	_build_ui()

# ─── Background ─────────────────────────────────────────────────────────────
func _build_background() -> void:
	# Solid base behind letterboxing
	var base := ColorRect.new()
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.anchors_preset = Control.PRESET_FULL_RECT
	base.color = Color(0, 0, 0, 1)
	base.z_index = 0
	add_child(base)

	# User-provided citadel/wall photo (CONTAIN: always fully inside screen, centered)
	var wall := TextureRect.new()
	wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wall.anchors_preset = Control.PRESET_FULL_RECT
	wall.texture = _load_tex2d("res://assets/user_jerusalem_citadel.png")
	wall.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	wall.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	wall.z_index = 1
	add_child(wall)

	# User-provided "map of Israel + flag" art (subtle layer)
	var map := TextureRect.new()
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map.anchors_preset = Control.PRESET_FULL_RECT
	map.texture = _load_tex2d("res://assets/user_israel_map_flag.png")
	map.modulate = Color(1, 1, 1, 0.18)
	map.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	map.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map.z_index = 2
	add_child(map)

	# Subtle readability vignette
	var dim := ColorRect.new()
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.anchors_preset = Control.PRESET_FULL_RECT
	dim.color = Color(0, 0, 0, 0.30)
	dim.z_index = 3
	add_child(dim)

func _load_tex2d(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		push_error("Missing texture file: %s" % path)
		return null

	# Ignore any stale cached import failures while the editor re-imports assets.
	var tex := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
	if tex != null:
		return tex

	# Fallback: load raw bytes from disk (works even if the texture importer/cache is unhappy).
	var disk_path := ProjectSettings.globalize_path(path)
	var img := Image.new()
	var err := img.load(disk_path)
	if err != OK:
		push_error("Failed to load image bytes: %s (Error %s)" % [disk_path, str(err)])
		return null

	return ImageTexture.create_from_image(img)

# ─── UI ────────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	var ui_root := Control.new()
	ui_root.name = "MenuUI"
	ui_root.mouse_filter = Control.MOUSE_FILTER_PASS
	ui_root.z_index = 10
	add_child(ui_root)
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	ui_root.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vbox.add_theme_constant_override("separation", 14)
	center.add_child(vbox)

	var title_box := VBoxContainer.new()
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 2)
	vbox.add_child(title_box)

	var t1 := _make_label("30 November", 64, C_WHITE)
	t1.add_theme_constant_override("shadow_offset_x", 3)
	t1.add_theme_constant_override("shadow_offset_y", 3)
	t1.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.78))
	title_box.add_child(t1)

	var t2 := _make_label("Beat 'em up style", 22, Color(C_WHITE, 0.85))
	t2.add_theme_constant_override("shadow_offset_x", 2)
	t2.add_theme_constant_override("shadow_offset_y", 2)
	t2.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.70))
	title_box.add_child(t2)

	_title_label = _make_label("יום העצמאות 78 למדינת ישראל", 34, Color(C_WHITE, 0.95))
	_title_label.add_theme_constant_override("shadow_offset_x", 2)
	_title_label.add_theme_constant_override("shadow_offset_y", 2)
	_title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.70))
	title_box.add_child(_title_label)

	var btn_box := VBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_box.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_box)

	btn_box.add_child(_make_button("▶  התחל משחק", _on_start_pressed))
	btn_box.add_child(_make_button("עזרה ושליטה", _on_help_pressed))
	btn_box.add_child(_make_button("יציאה", _on_quit_pressed))

	var credits := VBoxContainer.new()
	credits.mouse_filter = Control.MOUSE_FILTER_IGNORE
	credits.alignment = BoxContainer.ALIGNMENT_CENTER
	credits.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	credits.add_theme_constant_override("separation", 2)
	vbox.add_child(credits)

	credits.add_child(_make_label("Made by Ariya studio", 14, Color(C_WHITE, 0.75)))
	credits.add_child(_make_label("-Evyatar hacohen", 14, Color(C_WHITE, 0.75)))

# ─── Helpers ───────────────────────────────────────────────────────────────
func _make_label(text: String, font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl

func _make_button(text: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(360, 54)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 26)
	btn.add_theme_color_override("font_color", C_WHITE)
	btn.add_theme_color_override("font_hover_color", C_WHITE)
	btn.add_theme_color_override("font_pressed_color", C_WHITE)
	btn.add_theme_stylebox_override("normal", _make_stylebox(C_BTN, 14, Color(C_WHITE, 0.20)))
	btn.add_theme_stylebox_override("hover", _make_stylebox(C_BTN_HOV, 14, Color(C_WHITE, 0.35)))
	btn.add_theme_stylebox_override("pressed", _make_stylebox(C_BLUE, 14, Color(C_WHITE, 0.55)))
	btn.add_theme_stylebox_override("focus", _make_stylebox(C_BTN_HOV, 14, Color(C_WHITE, 0.45)))
	btn.pressed.connect(cb)
	return btn

func _make_stylebox(color: Color, radius: float, border_color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	s.border_width_top = 2
	s.border_width_bottom = 2
	s.border_width_left = 2
	s.border_width_right = 2
	s.border_color = border_color
	return s

# ─── Process ───────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	_time += delta
	# Subtle pulse title
	if is_instance_valid(_title_label):
		var pulse := 1.0 + sin(_time * 2.0) * 0.03
		_title_label.scale = Vector2(pulse, pulse)
		_title_label.pivot_offset = _title_label.size / 2.0

# ─── Input ─────────────────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_on_start_pressed()
	elif event.is_action_pressed("ui_cancel"):
		get_tree().quit()

# ─── Button callbacks ──────────────────────────────────────────────────────
func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/CharacterSelect.tscn")

func _on_help_pressed() -> void:
	var popup := AcceptDialog.new()
	popup.title = "עזרה ושליטה"
	popup.dialog_text = (
		"שליטה במקלדת:\n"
		+ "  תנועה:  WASD  או  ↑ ↓ ← →\n"
		+ "  מכה:     Z  או  J\n"
		+ "  בעיטה:  X  או  K\n"
		+ "  מיוחד:   C  או  L\n\n"
		+ "שליטה במגע (מובייל):\n"
		+ "  ג'ויסטיק וירטואלי משמאל\n"
		+ "  כפתורי תקיפה מימין\n\n"
		+ "המטרה:\n"
		+ "הכה אויבים, צבור ניקוד,\n"
		+ "הגע לסוף השלב ונצח!"
	)
	add_child(popup)
	popup.popup_centered(Vector2i(500, 420))

func _on_quit_pressed() -> void:
	get_tree().quit()

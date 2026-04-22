extends Node

signal ad_started(kind: String, placement: String)
signal ad_finished(kind: String, placement: String, completed: bool)

var enabled: bool = true
var _ad_showing: bool = false
var creative_paths: Array[String] = [
	"res://assets/ad_first.jpg",
	"res://assets/ad_second.jpg",
	"res://assets/ad_asila.jpg",
]
var _creative_index: int = 0

func is_showing() -> bool:
	return _ad_showing

func show_interstitial(placement: String, duration_sec: float = 5.0, skip_after_sec: float = 5.0) -> bool:
	if not enabled or _ad_showing:
		return false
	_ad_showing = true
	ad_started.emit("interstitial", placement)
	var completed := await _run_ad_ui("פרסומת", placement, duration_sec, skip_after_sec, true)
	ad_finished.emit("interstitial", placement, completed)
	_ad_showing = false
	return completed

func show_rewarded(placement: String, duration_sec: float = 30.0) -> bool:
	if not enabled or _ad_showing:
		return false
	_ad_showing = true
	ad_started.emit("rewarded", placement)
	# Rewarded: no skip until finished.
	var completed := await _run_ad_ui("פרסומת לתגמול", placement, duration_sec, duration_sec + 999.0, false)
	ad_finished.emit("rewarded", placement, completed)
	_ad_showing = false
	return completed

func _run_ad_ui(title: String, placement: String, duration_sec: float, skip_after_sec: float, show_skip: bool) -> bool:
	get_tree().call_group("touch_controls_overlay", "push_touch_ui_block")
	# Must be on a CanvasLayer above TouchControls (20) / HUD (10); z_index alone does not beat higher layers.
	var ad_layer := CanvasLayer.new()
	ad_layer.layer = 100
	get_tree().root.add_child(ad_layer)

	var root := Control.new()
	root.name = "AdOverlay"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	ad_layer.add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	var panel := Panel.new()
	panel.size = Vector2(740, 420)
	panel.position = Vector2(110, 60)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.06, 0.07, 0.12, 0.98)
	ps.border_color = Color(0.95, 0.78, 0.20, 0.85)
	ps.set_border_width_all(2)
	ps.corner_radius_top_left = 16
	ps.corner_radius_top_right = 16
	ps.corner_radius_bottom_left = 16
	ps.corner_radius_bottom_right = 16
	panel.add_theme_stylebox_override("panel", ps)
	root.add_child(panel)

	var lbl_title := Label.new()
	lbl_title.text = title
	lbl_title.position = Vector2(0, 16)
	lbl_title.size = Vector2(740, 34)
	lbl_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_title.add_theme_font_size_override("font_size", 24)
	lbl_title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.20))
	panel.add_child(lbl_title)

	var ad_box := Panel.new()
	ad_box.position = Vector2(24, 68)
	ad_box.size = Vector2(692, 260)
	var abs := StyleBoxFlat.new()
	abs.bg_color = Color(0.02, 0.02, 0.03, 0.92)
	abs.border_color = Color(0.95, 0.78, 0.20, 0.35)
	abs.set_border_width_all(2)
	abs.corner_radius_top_left = 10
	abs.corner_radius_top_right = 10
	abs.corner_radius_bottom_left = 10
	abs.corner_radius_bottom_right = 10
	ad_box.add_theme_stylebox_override("panel", abs)
	ad_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(ad_box)

	var tex_rect := TextureRect.new()
	tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Show creative as large as possible (cover), preserving aspect ratio.
	# Any area outside the image remains a dead "safe zone" because the overlay blocks input.
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ad_box.add_child(tex_rect)

	var path := _pick_creative_path()
	var tex := _load_ad_texture(path)
	if tex == null:
		for p in creative_paths:
			if p == path:
				continue
			tex = _load_ad_texture(p)
			if tex != null:
				break
	tex_rect.texture = tex

	var ad_txt := Label.new()
	# Placement ids (e.g. enter_shop) are for analytics — hide when the creative renders.
	if tex == null:
		ad_txt.text = "לא ניתן לטעון תמונת פרסומת (%s)" % placement
		push_error("AdsManager: missing creative for placement '%s' (tried %s)" % [placement, str(creative_paths)])
	else:
		ad_txt.text = ""
	ad_txt.position = Vector2(0, 166)
	ad_txt.size = Vector2(740, 30)
	ad_txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ad_txt.add_theme_font_size_override("font_size", 18)
	ad_txt.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95, 0.9))
	ad_txt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(ad_txt)

	var lbl_time := Label.new()
	lbl_time.text = ""
	lbl_time.position = Vector2(24, 342)
	lbl_time.size = Vector2(460, 28)
	lbl_time.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_time.add_theme_font_size_override("font_size", 15)
	lbl_time.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95, 0.75))
	panel.add_child(lbl_time)

	var btn_skip := Button.new()
	btn_skip.text = "דלג"
	btn_skip.position = Vector2(580, 336)
	btn_skip.size = Vector2(136, 44)
	btn_skip.disabled = true
	btn_skip.visible = show_skip
	btn_skip.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_button(btn_skip)
	panel.add_child(btn_skip)

	var finished: bool = false
	var did_skip: bool = false
	btn_skip.pressed.connect(func():
		did_skip = true
		finished = true
	)

	var t := 0.0
	var prev_usec := Time.get_ticks_usec()
	while not finished and t < duration_sec:
		await get_tree().process_frame
		var now_usec := Time.get_ticks_usec()
		t += float(now_usec - prev_usec) / 1_000_000.0
		prev_usec = now_usec
		var left := maxf(0.0, duration_sec - t)
		lbl_time.text = "נותרו %.0f שניות" % ceil(left)
		if show_skip:
			btn_skip.disabled = t < skip_after_sec

	if not did_skip:
		lbl_time.text = "הפרסומת הסתיימה."

	if is_instance_valid(ad_layer):
		ad_layer.queue_free()
	get_tree().call_group("touch_controls_overlay", "pop_touch_ui_block")

	return not did_skip

func _pick_creative_path() -> String:
	if creative_paths.is_empty():
		return ""
	var tries := creative_paths.size()
	while tries > 0:
		var idx := _creative_index % creative_paths.size()
		_creative_index += 1
		var p := creative_paths[idx]
		if _ad_source_file_exists(p):
			return p
		tries -= 1
	return creative_paths[0]


func _ad_source_file_exists(path: String) -> bool:
	var disk := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(disk):
		return true
	return ResourceLoader.exists(path)


func _load_ad_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if ResourceLoader.exists(path):
		var tex := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
		if tex != null:
			return tex
	var disk_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(disk_path):
		var img_disk := Image.new()
		if img_disk.load(disk_path) == OK:
			return ImageTexture.create_from_image(img_disk)
	# Export / PCK: loose files are not on disk; read packed resource via res:// stream.
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("AdsManager: cannot open creative: %s" % path)
		return null
	var buf := f.get_buffer(f.get_length())
	var img := Image.new()
	var err: Error
	if buf.size() >= 2 and buf[0] == 0xFF and buf[1] == 0xD8:
		err = img.load_jpg_from_buffer(buf)
	else:
		err = img.load_png_from_buffer(buf)
	if err != OK:
		push_error("AdsManager: image buffer load failed for %s (err %s)" % [path, str(err)])
		return null
	return ImageTexture.create_from_image(img)

func _style_button(btn: Button) -> void:
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.18, 0.20, 0.40, 0.98)
	s.border_color = Color(0.95, 0.78, 0.20, 0.65)
	s.set_border_width_all(2)
	s.corner_radius_top_left = 10
	s.corner_radius_top_right = 10
	s.corner_radius_bottom_left = 10
	s.corner_radius_bottom_right = 10
	btn.add_theme_stylebox_override("normal", s)
	var sh := s.duplicate() as StyleBoxFlat
	sh.bg_color = Color(0.24, 0.26, 0.50, 0.98)
	sh.border_color = Color(0.95, 0.78, 0.20, 0.95)
	btn.add_theme_stylebox_override("hover", sh)

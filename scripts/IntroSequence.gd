extends Control

## Comic-book story. Cinematic phase uses in-engine intro (recommended). Set true to use Theora file instead.
const USE_OGV_CINEMATIC := false
const VIDEO_PATH := "res://assets/intro_cinematic.ogv"

const C_INK := Color(0.05, 0.05, 0.08)
const C_PANEL := Color(0.98, 0.94, 0.88)
const C_GOLD := Color(0.95, 0.78, 0.20)
const C_HALFTONE := Color(0.12, 0.12, 0.18)

enum Phase { GLOBE_STORY, HERO_DROP, CINEMATIC, JERUSALEM }

var _phase: Phase = Phase.GLOBE_STORY
var _phase_elapsed: float = 0.0
var _caption: RichTextLabel
var _visual_host: Control
var _globe: Control
var _map_root: Control
var _fighter: Node2D
var _video: VideoStreamPlayer
var _film_overlay: Control
var _skip_hint: Label
var _using_video: bool = false
var _caption_top: float = 360.0
const PHASE_SEC := 2.0
const CINEMATIC_SEC := 6.0

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_chrome()
	_enter_phase(Phase.GLOBE_STORY)


func _build_chrome() -> void:
	var bg := ColorRect.new()
	bg.color = C_HALFTONE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 10
	frame.offset_top = 10
	frame.offset_right = -10
	frame.offset_bottom = -10
	var fs := StyleBoxFlat.new()
	fs.bg_color = Color(0, 0, 0, 0)
	fs.border_color = C_GOLD
	fs.set_border_width_all(4)
	fs.corner_radius_top_left = 6
	fs.corner_radius_top_right = 6
	fs.corner_radius_bottom_left = 6
	fs.corner_radius_bottom_right = 6
	frame.add_theme_stylebox_override("panel", fs)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)

	_visual_host = Control.new()
	_visual_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	_visual_host.offset_left = 24
	_visual_host.offset_top = 24
	_visual_host.offset_right = -24
	_visual_host.offset_bottom = -200
	_visual_host.clip_contents = true
	add_child(_visual_host)

	_caption = RichTextLabel.new()
	_caption.fit_content = false
	_caption.scroll_active = false
	_caption.bbcode_enabled = true
	_caption.set_anchors_preset(Control.PRESET_FULL_RECT)
	_caption.offset_left = 32
	_caption.offset_top = 360
	_caption.offset_right = -32
	_caption.offset_bottom = -52
	_caption.add_theme_font_size_override("normal_font_size", 20)
	_caption.add_theme_color_override("default_color", C_INK)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_caption)

	_skip_hint = Label.new()
	_skip_hint.text = "Enter — דלג לשלב הבא   |   Esc — דלג ישירות למשחק"
	_skip_hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_skip_hint.offset_top = 508
	_skip_hint.offset_bottom = -8
	_skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skip_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_skip_hint.add_theme_font_size_override("font_size", 11)
	_skip_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	_skip_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_skip_hint)


func _apply_layout_for_phase(p: Phase) -> void:
	## Full-bleed cinematic image; comic panels stay inset.
	if p == Phase.CINEMATIC:
		_visual_host.offset_left = 0
		_visual_host.offset_top = 0
		_visual_host.offset_right = 0
		_visual_host.offset_bottom = -72
		_caption_top = 418.0
		_caption.offset_top = _caption_top
		_caption.offset_left = 20
		_caption.offset_right = -20
		_caption.offset_bottom = -10
	else:
		_visual_host.offset_left = 24
		_visual_host.offset_top = 24
		_visual_host.offset_right = -24
		_visual_host.offset_bottom = -200
		_caption_top = 360.0
		_caption.offset_top = _caption_top
		_caption.offset_left = 32
		_caption.offset_right = -32
		_caption.offset_bottom = -52


func _enter_phase(p: Phase) -> void:
	_phase = p
	_phase_elapsed = 0.0
	for c in _visual_host.get_children():
		c.queue_free()
	_fighter = null
	_globe = null
	_map_root = null
	if is_instance_valid(_video):
		_video.stop()
		_video.queue_free()
		_video = null
	if is_instance_valid(_film_overlay):
		_film_overlay.queue_free()
		_film_overlay = null

	_apply_layout_for_phase(p)

	match p:
		Phase.GLOBE_STORY:
			_globe = _make_globe_panel()
			_visual_host.add_child(_globe)
			_set_caption(
				"[center][b]1947 · פאנל 1[/b][/center]\n\n"
				+ "מזרח תיכון קטן — דרמה שמזיזה יבשות.\n"
				+ "הגלובוס מסמן: כאן נפגשים גורל וזיכרון.\n\n"
				+ "[i]העם חוזר הביתה. העצמאות בדרך.[/i]"
			)
		Phase.HERO_DROP:
			_map_root = _make_map_panel()
			_visual_host.add_child(_map_root)
			var n: String = GameData.player_hero_name
			_set_caption(
				"[center][b]פאנל 2 · נקודת נחיתה[/b][/center]\n\n"
				+ ("[color=#f2c814][b]%s[/b][/color] — נוחת על המפה.\n" % n)
				+ "לוחם אחד. רגע לפני הסערה."
			)
			_fighter = _make_mini_fighter(GameData.get_char_data())
			_fighter.position = Vector2(480, -40)
			_map_root.add_child(_fighter)
			var tw := create_tween()
			tw.tween_property(_fighter, "position:y", 210.0, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Phase.CINEMATIC:
			_start_cinematic_phase()
		Phase.JERUSALEM:
			_visual_host.add_child(_make_jerusalem_panel())
			var n2: String = GameData.player_hero_name
			_set_caption(
				"[center][b]פאנל 4 · ירושלים[/b][/center]\n\n"
				+ ("[color=#f2c814][b]%s[/b][/color] נכנס לסימטאות — " % n2)
				+ "כאן נלחמים על החופש."
			)

	_comic_reveal()


func get_story_time() -> float:
	return _phase_elapsed


func _set_caption(bb: String) -> void:
	_caption.text = bb


func _comic_reveal() -> void:
	_visual_host.modulate = Color(1, 1, 1, 0)
	_caption.modulate = Color(1, 1, 1, 0)
	_caption.visible_ratio = 0.0
	_caption.scale = Vector2(0.9, 0.9)
	_caption.offset_top = _caption_top + 18
	call_deferred("_run_comic_reveal_tweens")


func _run_comic_reveal_tweens() -> void:
	if not is_instance_valid(_caption):
		return
	_caption.pivot_offset = _caption.size * 0.5
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_visual_host, "modulate", Color(1, 1, 1, 1), 0.18).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(_caption, "modulate", Color(1, 1, 1, 1), 0.16).set_delay(0.02).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_caption, "offset_top", _caption_top, 0.2).set_delay(0.02).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_caption, "scale", Vector2(1.04, 1.04), 0.22).set_delay(0.02).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_caption, "visible_ratio", 1.0, 0.32).set_delay(0.03).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(_caption, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)


func _phase_duration() -> float:
	if _phase == Phase.CINEMATIC:
		return CINEMATIC_SEC
	return PHASE_SEC


func _process(delta: float) -> void:
	_phase_elapsed += delta
	match _phase:
		Phase.GLOBE_STORY:
			if is_instance_valid(_globe):
				_globe.queue_redraw()
			if _phase_elapsed > _phase_duration():
				_enter_phase(Phase.HERO_DROP)
		Phase.HERO_DROP:
			if _phase_elapsed > _phase_duration():
				_enter_phase(Phase.CINEMATIC)
		Phase.CINEMATIC:
			if _phase_elapsed > _phase_duration():
				_enter_phase(Phase.JERUSALEM)
		Phase.JERUSALEM:
			if _phase_elapsed > _phase_duration():
				get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_advance_phase()
	elif event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _advance_phase() -> void:
	match _phase:
		Phase.GLOBE_STORY:
			_enter_phase(Phase.HERO_DROP)
		Phase.HERO_DROP:
			_enter_phase(Phase.CINEMATIC)
		Phase.CINEMATIC:
			_enter_phase(Phase.JERUSALEM)
		Phase.JERUSALEM:
			get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _make_globe_panel() -> Control:
	var p := ComicGlobe.new()
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	return p


func _make_map_panel() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sand := ColorRect.new()
	sand.color = Color(0.82, 0.72, 0.55)
	sand.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(sand)
	for i in 8:
		var lane := ColorRect.new()
		lane.color = Color(0.55, 0.45, 0.34, 0.55)
		lane.size = Vector2(6, 316)
		lane.position = Vector2(80 + i * 110, 0)
		root.add_child(lane)
	var old := ColorRect.new()
	old.color = Color(0.45, 0.55, 0.38)
	old.size = Vector2(220, 140)
	old.position = Vector2(360, 80)
	root.add_child(old)
	var lbl := Label.new()
	lbl.text = "העיר העתיקה"
	lbl.position = Vector2(400, 125)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", C_INK)
	root.add_child(lbl)
	var flag_tex := _load_tex2d("res://assets/israel_flag.png")
	if flag_tex != null:
		var flag := TextureRect.new()
		flag.texture = flag_tex
		flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		flag.size = Vector2(120, 120)
		flag.position = Vector2(760, 20)
		flag.modulate = Color(1, 1, 1, 0.85)
		root.add_child(flag)
	return root


func _make_jerusalem_panel() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	var wall_tex := _load_tex2d("res://assets/jerusalem_wall.jpg")
	if wall_tex != null:
		var bg := TextureRect.new()
		bg.texture = wall_tex
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		c.add_child(bg)
	else:
		var sky := ColorRect.new()
		sky.color = Color(0.45, 0.62, 0.82)
		sky.set_anchors_preset(Control.PRESET_FULL_RECT)
		sky.offset_bottom = -80
		c.add_child(sky)
		var wall := ColorRect.new()
		wall.color = Color(0.72, 0.68, 0.58)
		wall.position = Vector2(0, 200)
		wall.size = Vector2(912, 120)
		c.add_child(wall)
	return c


func _start_cinematic_phase() -> void:
	_using_video = false
	if USE_OGV_CINEMATIC and ResourceLoader.exists(VIDEO_PATH):
		var stream: Resource = load(VIDEO_PATH)
		if stream is VideoStream:
			_video = VideoStreamPlayer.new()
			_video.set_anchors_preset(Control.PRESET_FULL_RECT)
			_video.expand = true
			_video.stream = stream
			_visual_host.add_child(_video)
			_video.play()
			_using_video = true
			_set_caption(
				"[center][b]פאנל 3 · חיתוך קולנועי[/b][/center]\n\n"
				+ "המסך נדלק — הזמן נעצר. מה שקורה כאן לא צריך הסבר."
			)
	if not _using_video:
		var cinematic := EngineCinematicIntro.new()
		cinematic.set_anchors_preset(Control.PRESET_FULL_RECT)
		_visual_host.add_child(cinematic)
		_set_caption(
			"[center][b]פאנל 3 · זריחה[/b][/center]\n\n"
			+ "אור על העיר — [i]רגע לפני הקרב.[/i]"
		)
	_film_overlay = _make_film_grain_overlay(true)
	add_child(_film_overlay)


func _make_film_grain_overlay(cinematic_video: bool) -> Control:
	var o := Control.new()
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar_h: int = 54 if cinematic_video else 36
	var bar_a: float = 0.82 if cinematic_video else 0.88
	var top := ColorRect.new()
	top.color = Color(0, 0, 0, bar_a)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = bar_h
	o.add_child(top)
	var bot := ColorRect.new()
	bot.color = Color(0, 0, 0, bar_a)
	bot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bot.offset_top = -bar_h
	o.add_child(bot)
	if cinematic_video:
		var gold := Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.4)
		var hair_top := ColorRect.new()
		hair_top.color = gold
		hair_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
		hair_top.offset_top = bar_h
		hair_top.offset_bottom = bar_h + 1
		o.add_child(hair_top)
		var hair_bot := ColorRect.new()
		hair_bot.color = gold
		hair_bot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		hair_bot.offset_top = -bar_h - 1
		hair_bot.offset_bottom = -bar_h
		o.add_child(hair_bot)
	return o


func _load_tex2d(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var tex := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
		if tex != null:
			return tex
	var disk_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(disk_path):
		var img := Image.new()
		if img.load(disk_path) == OK:
			return ImageTexture.create_from_image(img)
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var buf := f.get_buffer(f.get_length())
	var img2 := Image.new()
	var err: Error
	if buf.size() >= 2 and buf[0] == 0xFF and buf[1] == 0xD8:
		err = img2.load_jpg_from_buffer(buf)
	else:
		err = img2.load_png_from_buffer(buf)
	if err != OK:
		return null
	return ImageTexture.create_from_image(img2)


func _make_mini_fighter(data: Dictionary) -> Node2D:
	var n := Node2D.new()
	n.scale = Vector2(1.8, 1.8)
	var skin: Color = data["color_skin"]
	var suit: Color = data["color_body"]
	var accent: Color = data["color_accent"]
	var torso := Polygon2D.new()
	torso.polygon = PackedVector2Array([Vector2(-10, -6), Vector2(10, -6), Vector2(9, 10), Vector2(-9, 10)])
	torso.color = suit
	n.add_child(torso)
	var head := Polygon2D.new()
	head.polygon = PackedVector2Array([Vector2(-7, -22), Vector2(7, -22), Vector2(8, -8), Vector2(-8, -8)])
	head.color = skin
	n.add_child(head)
	var cap := Polygon2D.new()
	cap.polygon = PackedVector2Array([Vector2(-8, -26), Vector2(8, -26), Vector2(6, -22), Vector2(-6, -22)])
	cap.color = suit.darkened(0.1)
	n.add_child(cap)
	var star := Polygon2D.new()
	star.polygon = PackedVector2Array([
		Vector2(0, -2), Vector2(2, 2), Vector2(5, 2), Vector2(2, 5),
		Vector2(3, 9), Vector2(0, 7), Vector2(-3, 9), Vector2(-2, 5),
		Vector2(-5, 2), Vector2(-2, 2)
	])
	star.color = accent
	n.add_child(star)
	return n


class ComicGlobe extends Control:
	const INK := Color(0.05, 0.05, 0.08)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var host: Node = get_parent()
		if host == null:
			return
		var seq: Node = host.get_parent()
		var t: float = 0.0
		if seq and seq.has_method("get_story_time"):
			t = seq.get_story_time()
		var zoom: float = clampf((t - 0.12) / 0.95, 0.0, 1.0)
		var center := size * 0.5
		var focus := Vector2(86, -54) * zoom
		var z: float = lerpf(1.0, 1.55, ease(zoom, 0.4))
		draw_set_transform(center + focus, 0, Vector2(z, z))
		var r: float = minf(size.x, size.y) * 0.26
		draw_circle(Vector2.ZERO, r, Color(0.18, 0.42, 0.78))
		draw_arc(Vector2.ZERO, r, 0, TAU, 48, INK, 3.0, true)
		for i in 5:
			var a: float = TAU * i / 5.0
			draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(a) * r, INK, 2.0)
		draw_circle(Vector2(38, -32), 22.0, Color(0.35, 0.62, 0.38, 0.85))
		draw_circle(Vector2(52, -28), 9.0, Color(0.92, 0.76, 0.22))
		draw_arc(Vector2(52, -28), 9.0, 0, TAU, 24, INK, 2.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Full-screen style cinematic: dawn sky, sun glow, Jerusalem-ish silhouette, slow zoom, grain (no external video).
class EngineCinematicIntro extends Control:
	const INK := Color(0.04, 0.04, 0.07)

	func _seq_time() -> float:
		var h := get_parent()
		if h == null:
			return 0.0
		var seq: Node = h.get_parent()
		if seq and seq.has_method("get_story_time"):
			return seq.get_story_time()
		return 0.0

	func _process(_delta: float) -> void:
		queue_redraw()

	func _sky_sample(u: float) -> Color:
		if u < 0.5:
			return Color(0.02, 0.04, 0.12).lerp(Color(0.08, 0.14, 0.38), u / 0.5)
		if u < 0.78:
			return Color(0.08, 0.14, 0.38).lerp(Color(0.45, 0.28, 0.42), (u - 0.5) / 0.28)
		return Color(0.45, 0.28, 0.42).lerp(Color(0.98, 0.72, 0.38), clampf((u - 0.78) / 0.22, 0.0, 1.0))

	func _draw() -> void:
		var t: float = _seq_time()
		var w: float = size.x
		var h: float = size.y
		if w < 8.0 or h < 8.0:
			return
		var prog: float = clampf(t / 5.5, 0.0, 1.0)
		var z: float = lerpf(1.0, 1.09, ease(prog, 0.35))
		var cx: float = w * 0.5
		var cy: float = h * 0.48

		var steps: int = 28
		for i in steps:
			var y0: float = h * float(i) / float(steps)
			var y1: float = h * float(i + 1) / float(steps)
			var u0: float = float(i) / float(steps)
			var c: Color = _sky_sample(u0)
			draw_rect(Rect2(0, y0, w, y1 - y0 + 0.5), c)

		draw_set_transform(Vector2(cx, cy), 0.0, Vector2(z, z))
		var sx := w * 0.5
		var sy := h * 0.5
		var sun: Vector2 = Vector2(sx * 0.42, -sy * 0.52 + sin(t * 0.7) * 6.0)
		for ri in range(8):
			var rr: float = lerpf(140.0, 18.0, float(ri) / 8.0)
			var a: float = lerpf(0.02, 0.14, 1.0 - float(ri) / 8.0)
			draw_circle(sun, rr, Color(1.0, 0.88, 0.45, a))
		draw_circle(sun, 22.0, Color(1.0, 0.95, 0.65, 0.95))

		var star_seed := 41
		for i in 48:
			var wx: float = fposmod(sin(float(i * star_seed)) * 10000.0, w)
			var wy: float = fposmod(cos(float(i * 17 + star_seed)) * 10000.0, h * 0.55)
			var tw: float = 0.35 + 0.65 * pow(0.5 + 0.5 * sin(t * 2.2 + float(i)), 2.0)
			draw_circle(Vector2(wx - cx, wy - cy), 1.2, Color(1, 1, 1, 0.15 * tw))

		var dome_x: float = -sx * 0.55
		var dome_y: float = sy * 0.35
		draw_arc(Vector2(dome_x, dome_y), 26.0, PI * 0.85, PI * 2.15, 28, Color(0.72, 0.58, 0.22, 0.9), 4.0, true)
		draw_circle(Vector2(dome_x, dome_y + 6.0), 8.0, Color(0.55, 0.48, 0.38, 0.85))

		var wall_pts := PackedVector2Array([
			Vector2(-sx - 40, sy + 10), Vector2(-sx * 0.92, sy * 0.22), Vector2(-sx * 0.75, sy * 0.18),
			Vector2(-sx * 0.55, sy * 0.35), Vector2(-sx * 0.35, sy * 0.12), Vector2(-sx * 0.1, sy * 0.28),
			Vector2(sx * 0.05, sy * 0.08), Vector2(sx * 0.22, sy * 0.32), Vector2(sx * 0.42, sy * 0.05),
			Vector2(sx * 0.58, sy * 0.22), Vector2(sx * 0.78, sy * 0.15), Vector2(sx + 40, sy * 0.28),
			Vector2(sx + 40, sy + 10)
		])
		draw_colored_polygon(wall_pts, Color(0.07, 0.06, 0.09, 1.0))
		if wall_pts.size() > 1:
			draw_polyline(wall_pts, INK, 2.0, true)

		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		var vig_a: float = 0.45
		draw_rect(Rect2(0, 0, w * 0.12, h), Color(0, 0, 0, vig_a))
		draw_rect(Rect2(w * 0.88, 0, w * 0.12, h), Color(0, 0, 0, vig_a))
		draw_rect(Rect2(0, 0, w, h * 0.08), Color(0, 0, 0, vig_a * 0.85))
		draw_rect(Rect2(0, h * 0.92, w, h * 0.08), Color(0, 0, 0, vig_a * 0.75))

		var gr_i: int = int(w * 0.15)
		var gr_j: int = int(h * 0.12)
		for gx in range(gr_i):
			for gy in range(gr_j):
				if hash(Vector2i(gx, gy) + Vector2i(int(t * 24.0), 0)) % 7 == 0:
					draw_rect(Rect2(float(gx) * 6.4, float(gy) * 6.4, 1.5, 1.5), Color(1, 1, 1, 0.04))


class FilmPlaceholder extends Control:
	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var g1 := (sin(_t * 2.1) * 0.5 + 0.5) * 0.08
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05 + g1, 0.05 + g1, 0.08 + g1))
		var stripes := int(size.x / 28)
		for i in stripes:
			var a: float = 0.12 + 0.04 * sin(_t * 3.0 + i * 0.4)
			draw_line(Vector2(i * 28.0, 0), Vector2(i * 28.0 + 14.0, size.y), Color(1, 1, 1, a), 10.0)

extends Control

const C_BG_TOP  := Color(0.03, 0.03, 0.10)
const C_BG_BOT  := Color(0.08, 0.10, 0.22)
const C_BLUE    := Color(0.10, 0.30, 0.70)
const C_WHITE   := Color(0.95, 0.95, 0.95)
const C_GOLD    := Color(0.95, 0.78, 0.20)
const C_CARD    := Color(0.12, 0.12, 0.25, 0.95)
const C_CARD_H  := Color(0.20, 0.22, 0.40, 1.00)

const CHAR_KEYS := ["palmach", "lehi", "haganah", "irgun"]

var _selected_idx := 0
var _cards: Array[Panel] = []
var _time: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_background()
	_build_ui()

func _build_background() -> void:
	# Gradient
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
	# Title
	var header := _make_label("בחר את הלוחם שלך", 42, C_GOLD)
	header.size = Vector2(960, 58)
	header.position = Vector2(0, 18)
	header.add_theme_constant_override("shadow_offset_x", 2)
	header.add_theme_constant_override("shadow_offset_y", 2)
	header.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	add_child(header)

	var sub := _make_label("CHOOSE YOUR FIGHTER", 16, Color(C_WHITE, 0.55))
	sub.size = Vector2(960, 22)
	sub.position = Vector2(0, 70)
	add_child(sub)

	# Character cards (2x2 grid)
	var positions := [
		Vector2(100, 110),  Vector2(530, 110),
		Vector2(100, 300),  Vector2(530, 300),
	]

	for i in CHAR_KEYS.size():
		var key: String = CHAR_KEYS[i]
		var data: Dictionary = GameData.CHARACTERS[key]
		var card := _make_card(data, positions[i], i)
		add_child(card)
		_cards.append(card)

	_refresh_selection()

	# Confirm button
	var btn := _make_button("▶  התחל להילחם!", Vector2(480, 500), _on_confirm, C_GOLD, Color(0.05, 0.05, 0.12))
	btn.size = Vector2(280, 48)
	btn.position = Vector2(340, 480)
	add_child(btn)

	# Back button
	var back := _make_button("← חזור", Vector2(80, 500), _on_back, Color(0.3, 0.3, 0.5, 0.9), C_WHITE)
	back.size = Vector2(120, 36)
	back.position = Vector2(20, 486)
	add_child(back)

	# Selection hint
	var hint := _make_label("לחץ על כרטיסייה לבחירה   |   Enter לאישור", 12, Color(C_WHITE, 0.4))
	hint.size = Vector2(540, 16)
	hint.position = Vector2(200, 522)
	add_child(hint)

func _make_card(data: Dictionary, pos: Vector2, idx: int) -> Panel:
	var card := Panel.new()
	card.size = Vector2(320, 170)
	card.position = pos
	card.mouse_filter = Control.MOUSE_FILTER_STOP  # card accepts clicks

	# Fighter figure
	var figure := _make_fighter_figure(data)
	figure.position = Vector2(64, 90)
	card.add_child(figure)

	# Name
	var name_lbl := Label.new()
	name_lbl.text = data["name_he"]
	name_lbl.add_theme_font_size_override("font_size", 30)
	name_lbl.add_theme_color_override("font_color", data["color_accent"])
	name_lbl.add_theme_constant_override("shadow_offset_x", 2)
	name_lbl.add_theme_constant_override("shadow_offset_y", 2)
	name_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_lbl.size = Vector2(200, 36)
	name_lbl.position = Vector2(120, 14)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(name_lbl)

	var en_lbl := Label.new()
	en_lbl.text = data["name_en"]
	en_lbl.add_theme_font_size_override("font_size", 14)
	en_lbl.add_theme_color_override("font_color", Color(C_WHITE, 0.5))
	en_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	en_lbl.size = Vector2(200, 18)
	en_lbl.position = Vector2(120, 48)
	en_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(en_lbl)

	# Description
	var desc := Label.new()
	desc.text = data["description"]
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(C_WHITE, 0.85))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size = Vector2(190, 42)
	desc.position = Vector2(120, 72)
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(desc)

	# Ideology skill bars (1-5 scale) — match HUD colors
	_add_ideology_bar(card, "כוח",     data.get("ideology_power",   3), Color(0.90, 0.38, 0.10), Vector2(120, 122))
	_add_ideology_bar(card, "מהירות",  data.get("ideology_speed",   3), Color(0.10, 0.78, 0.92), Vector2(120, 138))
	_add_ideology_bar(card, "תחבולה",  data.get("ideology_tactics", 3), Color(0.68, 0.18, 0.88), Vector2(120, 154))

	# Overlay button for click
	var btn := Button.new()
	btn.flat = true
	btn.size = card.size
	btn.position = Vector2.ZERO
	btn.pressed.connect(func(): _select(idx))
	card.add_child(btn)

	return card

func _make_fighter_figure(data: Dictionary) -> Node2D:
	var node := Node2D.new()
	node.scale = Vector2(1.25, 1.25)

	var skin:   Color = data["color_skin"]
	var suit:   Color = data["color_body"]
	var accent: Color = data["color_accent"]
	var dark_s: Color = suit.darkened(0.26)
	var boot_c    := Color(0.16, 0.13, 0.09)
	var char_type : String = data.get("char_type", "palmach")

	# ── Shadow
	var shadow := Polygon2D.new()
	shadow.polygon  = PackedVector2Array([Vector2(-18,0),Vector2(18,0),Vector2(13,6),Vector2(-13,6)])
	shadow.color    = Color(0, 0, 0, 0.35)
	shadow.position = Vector2(0, 34)
	node.add_child(shadow)

	# ── Boots
	for bx: int in [-8, 2]:
		var boot := Polygon2D.new()
		boot.polygon = PackedVector2Array([
			Vector2(bx,30),   Vector2(bx+8,30),
			Vector2(bx+9,37), Vector2(bx-1,37)
		])
		boot.color = boot_c
		node.add_child(boot)

	# ── Legs
	for lx: int in [-7, 3]:
		var leg := Polygon2D.new()
		leg.polygon = PackedVector2Array([
			Vector2(lx,12),   Vector2(lx+7,12),
			Vector2(lx+7,30), Vector2(lx,30)
		])
		leg.color = dark_s
		node.add_child(leg)

	# ── Torso
	var torso := Polygon2D.new()
	torso.polygon = PackedVector2Array([
		Vector2(-13,-8),  Vector2(13,-8),
		Vector2(12,14),   Vector2(-12,14)
	])
	torso.color = suit
	node.add_child(torso)

	# ── Chest pockets
	for px: int in [-9, 3]:
		var pocket := Polygon2D.new()
		pocket.polygon = PackedVector2Array([
			Vector2(px,-6),  Vector2(px+6,-6),
			Vector2(px+6,-1),Vector2(px,-1)
		])
		pocket.color = dark_s
		node.add_child(pocket)

	# ── Belt + buckle
	var belt := Polygon2D.new()
	belt.polygon = PackedVector2Array([
		Vector2(-13,8), Vector2(13,8),
		Vector2(13,12), Vector2(-13,12)
	])
	belt.color = accent.darkened(0.40)
	node.add_child(belt)
	var buckle := Polygon2D.new()
	buckle.polygon = PackedVector2Array([
		Vector2(-3,8),Vector2(3,8),
		Vector2(3,12),Vector2(-3,12)
	])
	buckle.color = accent
	node.add_child(buckle)

	# ── Arms
	for ax: int in [-17, 11]:
		var arm := Polygon2D.new()
		arm.polygon = PackedVector2Array([
			Vector2(ax,-6), Vector2(ax+6,-6),
			Vector2(ax+5,10),Vector2(ax+1,10)
		])
		arm.color = suit
		node.add_child(arm)

	# ── Hands
	for hx: int in [-17, 11]:
		var hand := Polygon2D.new()
		hand.polygon = PackedVector2Array([
			Vector2(hx+1,10), Vector2(hx+5,10),
			Vector2(hx+5,16), Vector2(hx+1,16)
		])
		hand.color = skin
		node.add_child(hand)

	# ── Neck
	var neck := Polygon2D.new()
	neck.polygon = PackedVector2Array([
		Vector2(-3,-10),Vector2(3,-10),
		Vector2(3,-8),  Vector2(-3,-8)
	])
	neck.color = skin
	node.add_child(neck)

	# ── Head (rounded)
	var head := Polygon2D.new()
	head.polygon = PackedVector2Array([
		Vector2(-8,-30), Vector2(0,-34), Vector2(8,-30),
		Vector2(10,-24), Vector2(9,-14),
		Vector2(0,-12),  Vector2(-9,-14), Vector2(-10,-24)
	])
	head.color = skin
	node.add_child(head)

	# ── Ears
	for side: int in [-1, 1]:
		var ear := Polygon2D.new()
		ear.polygon = PackedVector2Array([
			Vector2(side*10,-25), Vector2(side*12,-25),
			Vector2(side*12,-20), Vector2(side*10,-20)
		])
		ear.color = skin.darkened(0.10)
		node.add_child(ear)

	# ── Stubble
	var stub := Polygon2D.new()
	stub.polygon = PackedVector2Array([
		Vector2(-8,-19), Vector2(8,-19),
		Vector2(8,-14),  Vector2(-8,-14)
	])
	stub.color = Color(skin.r*0.58, skin.g*0.48, skin.b*0.38, 0.52)
	node.add_child(stub)

	# ── Eyes
	for ex: int in [-5, 2]:
		var eye := Polygon2D.new()
		eye.polygon = PackedVector2Array([
			Vector2(ex,-24),   Vector2(ex+4,-24),
			Vector2(ex+4,-22), Vector2(ex,-22)
		])
		eye.color = Color(0.13, 0.09, 0.06)
		node.add_child(eye)

	# ── Eyebrows
	for bx: int in [-6, 1]:
		var brow := Polygon2D.new()
		brow.polygon = PackedVector2Array([
			Vector2(bx,-27),   Vector2(bx+5,-27),
			Vector2(bx+5,-25), Vector2(bx,-25)
		])
		brow.color = Color(skin.r*0.44, skin.g*0.35, skin.b*0.25)
		node.add_child(brow)

	# ── Military cap brim
	var brim := Polygon2D.new()
	brim.polygon = PackedVector2Array([
		Vector2(-13,-30), Vector2(14,-30),
		Vector2(12,-32),  Vector2(-11,-32)
	])
	brim.color = suit.darkened(0.08)
	node.add_child(brim)

	# ── Cap crown
	var cap := Polygon2D.new()
	cap.polygon = PackedVector2Array([
		Vector2(-10,-32), Vector2(10,-32),
		Vector2(8,-40),   Vector2(-8,-40)
	])
	cap.color = suit
	node.add_child(cap)

	# ── Badge
	var badge := Polygon2D.new()
	badge.polygon = PackedVector2Array([
		Vector2(-3,-39), Vector2(0,-42), Vector2(3,-39),
		Vector2(3,-37),  Vector2(0,-35), Vector2(-3,-37)
	])
	badge.color = accent
	node.add_child(badge)

	# ── Star of David (chest)
	var star := Polygon2D.new()
	star.polygon = PackedVector2Array([
		Vector2(0,-5), Vector2(2,-1),  Vector2(5,-1),
		Vector2(2,2),  Vector2(3,6),   Vector2(0,4),
		Vector2(-3,6), Vector2(-2,2),  Vector2(-5,-1),
		Vector2(-2,-1)
	])
	star.color = accent
	node.add_child(star)

	# ── Character-specific detail
	match char_type:
		"lehi":
			var pistol := Polygon2D.new()
			pistol.polygon = PackedVector2Array([
				Vector2(11,10), Vector2(16,10),
				Vector2(17,14), Vector2(11,14)
			])
			pistol.color = Color(0.30, 0.27, 0.22)
			node.add_child(pistol)
		"palmach":
			var sling := Polygon2D.new()
			sling.polygon = PackedVector2Array([
				Vector2(-1,-8), Vector2(2,-8),
				Vector2(4,14),  Vector2(1,14)
			])
			sling.color = Color(0.38, 0.30, 0.14)
			node.add_child(sling)
		"haganah":
			for cx: int in range(-10, 11, 4):
				var cart := Polygon2D.new()
				cart.polygon = PackedVector2Array([
					Vector2(cx,-7), Vector2(cx+2,-7),
					Vector2(cx+2,-4),Vector2(cx,-4)
				])
				cart.color = Color(0.72, 0.62, 0.22)
				node.add_child(cart)
		"irgun":
			var xbrim := Polygon2D.new()
			xbrim.polygon = PackedVector2Array([
				Vector2(-15,-29), Vector2(16,-29),
				Vector2(13,-31), Vector2(-12,-31)
			])
			xbrim.color = suit.lightened(0.08)
			node.add_child(xbrim)

	return node

func _add_stat_bar(parent: Control, label: String, value: int, max_val: int, pos: Vector2) -> void:
	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(C_WHITE, 0.7))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl.size = Vector2(60, 12)
	lbl.position = pos
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lbl)

	var bg := ColorRect.new()
	bg.size = Vector2(85, 8)
	bg.position = pos + Vector2(0, 13)
	bg.color = Color(0.15, 0.15, 0.2)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)

	var fill := ColorRect.new()
	var pct: float = clampf(value / float(max_val), 0.0, 1.0)
	fill.size = Vector2(pct * 85, 8)
	fill.position = pos + Vector2(0, 13)
	fill.color = C_GOLD
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(fill)

# Skill bar based on ideology level (1-5). Inline horizontal layout:
# [label ~52px]  [bar 110px with 5 pips]
func _add_ideology_bar(parent: Control, label: String, level: int, bar_color: Color, pos: Vector2) -> void:
	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(C_WHITE, 0.85))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.size     = Vector2(52, 14)
	lbl.position = pos
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lbl)

	# Bar background
	var bar_w  := 110.0
	var bar_h  := 10.0
	var bar_x  := pos.x + 54
	var bar_y  := pos.y + 2

	var bg := ColorRect.new()
	bg.size     = Vector2(bar_w, bar_h)
	bg.position = Vector2(bar_x, bar_y)
	bg.color    = Color(0.08, 0.08, 0.10, 0.95)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)

	# Fill
	var pct: float = clampf(level / 5.0, 0.0, 1.0)
	var fill := ColorRect.new()
	fill.size     = Vector2(bar_w * pct, bar_h)
	fill.position = Vector2(bar_x, bar_y)
	fill.color    = bar_color
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(fill)

	# Shine on top half
	var shine := ColorRect.new()
	shine.size     = Vector2(bar_w * pct, bar_h * 0.35)
	shine.position = Vector2(bar_x, bar_y)
	shine.color    = Color(1, 1, 1, 0.22)
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(shine)

	# 4 inner pip dividers (5 segments)
	for p in 4:
		var mark := ColorRect.new()
		mark.size     = Vector2(1, bar_h)
		mark.position = Vector2(bar_x + bar_w * (p + 1) / 5.0, bar_y)
		mark.color    = Color(0, 0, 0, 0.55)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(mark)

func _refresh_selection() -> void:
	for i in _cards.size():
		var card := _cards[i]
		var style := StyleBoxFlat.new()
		if i == _selected_idx:
			style.bg_color = C_CARD_H
			style.border_color = C_GOLD
			style.border_width_top    = 4
			style.border_width_bottom = 4
			style.border_width_left   = 4
			style.border_width_right  = 4
			# Subtle scale for selected
			card.scale = Vector2(1.04, 1.04)
			card.pivot_offset = card.size / 2.0
		else:
			style.bg_color = C_CARD
			style.border_color = Color(C_WHITE, 0.15)
			style.border_width_top    = 2
			style.border_width_bottom = 2
			style.border_width_left   = 2
			style.border_width_right  = 2
			card.scale = Vector2(1.0, 1.0)

		style.corner_radius_top_left     = 10
		style.corner_radius_top_right    = 10
		style.corner_radius_bottom_left  = 10
		style.corner_radius_bottom_right = 10
		card.add_theme_stylebox_override("panel", style)

func _select(idx: int) -> void:
	_selected_idx = idx
	GameData.selected_character = CHAR_KEYS[idx]
	_refresh_selection()

func _process(delta: float) -> void:
	_time += delta

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_right"):
		_select((_selected_idx + 1) % 4)
	elif event.is_action_pressed("ui_left"):
		_select((_selected_idx - 1 + 4) % 4)
	elif event.is_action_pressed("ui_down"):
		_select((_selected_idx + 2) % 4)
	elif event.is_action_pressed("ui_up"):
		_select((_selected_idx - 2 + 4) % 4)
	elif event.is_action_pressed("ui_accept"):
		_on_confirm()
	elif event.is_action_pressed("ui_cancel"):
		_on_back()

func _on_confirm() -> void:
	print("Confirm pressed — name entry with ", GameData.selected_character)
	get_tree().change_scene_to_file("res://scenes/NameEntry.tscn")

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _make_label(text: String, size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl

func _make_button(text: String, _center: Vector2, cb: Callable, bg: Color, fg: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_color_override("font_hover_color", fg)

	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.corner_radius_top_left     = 8
	s.corner_radius_top_right    = 8
	s.corner_radius_bottom_left  = 8
	s.corner_radius_bottom_right = 8
	s.border_width_top    = 2
	s.border_width_bottom = 2
	s.border_width_left   = 2
	s.border_width_right  = 2
	s.border_color = Color(fg, 0.4)
	btn.add_theme_stylebox_override("normal", s)

	var s2 := s.duplicate() as StyleBoxFlat
	s2.bg_color = bg.lightened(0.15)
	s2.border_color = fg
	btn.add_theme_stylebox_override("hover", s2)

	var s3 := s.duplicate() as StyleBoxFlat
	s3.bg_color = bg.darkened(0.15)
	btn.add_theme_stylebox_override("pressed", s3)

	btn.pressed.connect(cb)
	return btn

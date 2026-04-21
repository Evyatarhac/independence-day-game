extends CanvasLayer

# ─── Palette ───────────────────────────────────────────────────────────────
const C_GOLD   := Color(0.95, 0.78, 0.20)
const C_WHITE  := Color(0.95, 0.95, 0.95)
const C_RED    := Color(0.85, 0.15, 0.15)
const C_GREEN  := Color(0.30, 0.80, 0.30)
const C_YELLOW := Color(0.90, 0.80, 0.20)
const C_BLUE   := Color(0.10, 0.30, 0.70)
const C_BG     := Color(0, 0, 0, 0.55)

# ─── State ─────────────────────────────────────────────────────────────────
var _health_fill:   ColorRect
var _health_bg:     ColorRect
var _health_text:   Label
var _score_label:   Label
var _score_value:   int = 0
var _score_display: int = 0
var _lives_container: HBoxContainer
var _char_icon:     Node2D
var _char_label:    Label
var _max_hp:        int = 100
var _econ_coins_lbl: Label
var _econ_stones_lbl: Label
var _skill_rank_lbl: Label
var _weapon_lbl: Label
var _player_ref: CharacterBody2D = null
var _journey_book_root: Control = null
var _alive: bool = true

func _exit_tree() -> void:
	_alive = false
	if GameData.economy_changed.is_connected(_on_run_economy_changed):
		GameData.economy_changed.disconnect(_on_run_economy_changed)
	if GameData.collection_updated.is_connected(_on_meta_collection_updated):
		GameData.collection_updated.disconnect(_on_meta_collection_updated)

func _await_seconds(seconds: float) -> bool:
	if seconds <= 0.0:
		return _alive
	var end_ms := Time.get_ticks_msec() + int(seconds * 1000.0)
	while _alive and Time.get_ticks_msec() < end_ms:
		await get_tree().process_frame
	return _alive

func _ready() -> void:
	layer = 10
	_build()
	GameData.economy_changed.connect(_on_run_economy_changed)
	GameData.collection_updated.connect(_on_meta_collection_updated)
	_on_run_economy_changed(
		GameData.wallet_coins,
		GameData.run_stones_progress,
		GameData.run_skill_rank,
		GameData.run_weapon_tier
	)
	set_process(true)

func set_player(p: CharacterBody2D) -> void:
	_player_ref = p


func _on_meta_collection_updated() -> void:
	if _journey_book_root != null and is_instance_valid(_journey_book_root):
		_journey_refresh_tabs(_journey_book_root)

# ─── Build ─────────────────────────────────────────────────────────────────
func _build() -> void:
	# Top bar backdrop with gradient
	var topbar := ColorRect.new()
	topbar.color    = C_BG
	topbar.size     = Vector2(960, 56)
	topbar.position = Vector2.ZERO
	add_child(topbar)
	_build_ideology_panel()

	# Gold separator line
	var sep := ColorRect.new()
	sep.color    = Color(C_GOLD, 0.7)
	sep.size     = Vector2(960, 2)
	sep.position = Vector2(0, 54)
	add_child(sep)

	# ── HP section ──────────────────────────────────────────────────────────
	var hp_title := Label.new()
	hp_title.text = "HP"
	hp_title.position = Vector2(14, 8)
	hp_title.add_theme_font_size_override("font_size", 13)
	hp_title.add_theme_color_override("font_color", Color(C_WHITE, 0.85))
	add_child(hp_title)

	_health_bg = ColorRect.new()
	_health_bg.color    = Color(0.18, 0.04, 0.04)
	_health_bg.size     = Vector2(200, 18)
	_health_bg.position = Vector2(40, 8)
	add_child(_health_bg)

	# HP border
	var hp_border_top := ColorRect.new()
	hp_border_top.color = Color(C_WHITE, 0.25)
	hp_border_top.size = Vector2(200, 1)
	hp_border_top.position = Vector2(40, 8)
	add_child(hp_border_top)
	var hp_border_bot := ColorRect.new()
	hp_border_bot.color = Color(C_WHITE, 0.25)
	hp_border_bot.size = Vector2(200, 1)
	hp_border_bot.position = Vector2(40, 25)
	add_child(hp_border_bot)

	_health_fill = ColorRect.new()
	_health_fill.color    = C_GREEN
	_health_fill.size     = Vector2(200, 18)
	_health_fill.position = Vector2(40, 8)
	add_child(_health_fill)

	_health_text = Label.new()
	_health_text.text = "100 / 100"
	_health_text.position = Vector2(40, 28)
	_health_text.size = Vector2(200, 16)
	_health_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_health_text.add_theme_font_size_override("font_size", 11)
	_health_text.add_theme_color_override("font_color", Color(C_WHITE, 0.75))
	add_child(_health_text)

	# ── Lives ────────────────────────────────────────────────────────────────
	var lives_lbl := Label.new()
	lives_lbl.text = "♥"
	lives_lbl.position = Vector2(256, 6)
	lives_lbl.add_theme_font_size_override("font_size", 20)
	lives_lbl.add_theme_color_override("font_color", C_RED)
	add_child(lives_lbl)

	_lives_container = HBoxContainer.new()
	_lives_container.position     = Vector2(276, 12)
	_lives_container.add_theme_constant_override("separation", 4)
	add_child(_lives_container)
	_refresh_lives(3)

	# ── Character name + icon (center) ────────────────────────────────────────
	var data: Dictionary = GameData.get_char_data()
	_char_icon = _make_char_icon(data)
	_char_icon.position = Vector2(530, 28)
	add_child(_char_icon)

	_char_label = Label.new()
	_char_label.text     = _hero_label_text(data)
	_char_label.position = Vector2(360, 8)
	_char_label.size     = Vector2(240, 22)
	_char_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_char_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_char_label.add_theme_font_size_override("font_size", 16)
	_char_label.add_theme_color_override("font_color", data["color_accent"])
	_char_label.add_theme_constant_override("shadow_offset_x", 1)
	_char_label.add_theme_constant_override("shadow_offset_y", 1)
	_char_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	add_child(_char_label)

	# ── Score ─────────────────────────────────────────────────────────────────
	var sc_title := Label.new()
	sc_title.text = "SCORE"
	sc_title.position = Vector2(720, 4)
	sc_title.size = Vector2(220, 16)
	sc_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sc_title.add_theme_font_size_override("font_size", 11)
	sc_title.add_theme_color_override("font_color", Color(C_WHITE, 0.55))
	add_child(sc_title)

	_score_label = Label.new()
	_score_label.text     = "000000"
	_score_label.size     = Vector2(220, 32)
	_score_label.position = Vector2(720, 20)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_score_label.vertical_alignment   = VERTICAL_ALIGNMENT_TOP
	_score_label.add_theme_font_size_override("font_size", 24)
	_score_label.add_theme_color_override("font_color", C_GOLD)
	_score_label.add_theme_constant_override("shadow_offset_x", 2)
	_score_label.add_theme_constant_override("shadow_offset_y", 2)
	_score_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	add_child(_score_label)

	# Run economy (coins, Jerusalem stones toward skill jump, skill rank)
	var econ_bg := ColorRect.new()
	econ_bg.color = Color(0, 0, 0, 0.35)
	econ_bg.size = Vector2(448, 22)
	econ_bg.position = Vector2(480, 58)
	add_child(econ_bg)

	_econ_coins_lbl = Label.new()
	_econ_coins_lbl.position = Vector2(488, 59)
	_econ_coins_lbl.add_theme_font_size_override("font_size", 12)
	_econ_coins_lbl.add_theme_color_override("font_color", C_GOLD)
	add_child(_econ_coins_lbl)

	_econ_stones_lbl = Label.new()
	_econ_stones_lbl.position = Vector2(600, 59)
	_econ_stones_lbl.add_theme_font_size_override("font_size", 12)
	_econ_stones_lbl.add_theme_color_override("font_color", Color(0.88, 0.80, 0.68))
	add_child(_econ_stones_lbl)

	_skill_rank_lbl = Label.new()
	_skill_rank_lbl.position = Vector2(780, 59)
	_skill_rank_lbl.add_theme_font_size_override("font_size", 12)
	_skill_rank_lbl.add_theme_color_override("font_color", Color(0.75, 0.92, 0.55))
	add_child(_skill_rank_lbl)

	_weapon_lbl = Label.new()
	_weapon_lbl.position = Vector2(360, 34)
	_weapon_lbl.size = Vector2(240, 18)
	_weapon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_weapon_lbl.add_theme_font_size_override("font_size", 11)
	_weapon_lbl.add_theme_color_override("font_color", Color(C_WHITE, 0.65))
	add_child(_weapon_lbl)

	_build_journey_button()

func _build_journey_button() -> void:
	var btn := Button.new()
	btn.text = "✡"
	btn.size = Vector2(52, 52)
	btn.position = Vector2(898, 86)
	btn.add_theme_font_size_override("font_size", 34)
	btn.add_theme_color_override("font_color", C_GOLD)
	btn.add_theme_color_override("font_hover_color", C_WHITE)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0.35)
	s.border_color = Color(C_GOLD, 0.65)
	s.set_border_width_all(2)
	s.corner_radius_top_left = 12
	s.corner_radius_top_right = 12
	s.corner_radius_bottom_left = 12
	s.corner_radius_bottom_right = 12
	btn.add_theme_stylebox_override("normal", s)
	var sh := s.duplicate() as StyleBoxFlat
	sh.bg_color = Color(0.10, 0.10, 0.20, 0.55)
	sh.border_color = C_GOLD
	btn.add_theme_stylebox_override("hover", sh)
	btn.pressed.connect(_open_journey_book)
	add_child(btn)

func _open_journey_book() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.z_index = 60
	add_child(root)
	_journey_book_root = root
	root.tree_exited.connect(func():
		_journey_book_root = null
	)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			root.queue_free()
	)
	root.add_child(dim)

	var panel := Panel.new()
	panel.name = "JourneyMainPanel"
	panel.position = Vector2(618, 48)
	panel.size = Vector2(334, 486)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.04, 0.06, 0.12, 0.96)
	ps.border_color = Color(C_GOLD, 0.88)
	ps.set_border_width_all(3)
	ps.corner_radius_top_left = 6
	ps.corner_radius_top_right = 6
	ps.corner_radius_bottom_left = 16
	ps.corner_radius_bottom_right = 16
	panel.add_theme_stylebox_override("panel", ps)
	root.add_child(panel)

	var star := Node2D.new()
	star.position = Vector2(167, 38)
	panel.add_child(star)
	var tri_u := Polygon2D.new()
	tri_u.polygon = PackedVector2Array([Vector2(0, -26), Vector2(-28, 18), Vector2(28, 18)])
	tri_u.color = Color(0.16, 0.38, 0.72)
	star.add_child(tri_u)
	var tri_d := Polygon2D.new()
	tri_d.polygon = PackedVector2Array([Vector2(0, 26), Vector2(-28, -18), Vector2(28, -18)])
	tri_d.color = Color(C_GOLD)
	star.add_child(tri_d)

	var hdr := Label.new()
	hdr.text = "ספר הישגים"
	hdr.position = Vector2(0, 64)
	hdr.size = Vector2(334, 22)
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_theme_font_size_override("font_size", 15)
	hdr.add_theme_color_override("font_color", Color(C_GOLD, 0.92))
	panel.add_child(hdr)

	var tab_row := HBoxContainer.new()
	tab_row.name = "JourneyTabRow"
	tab_row.position = Vector2(8, 86)
	tab_row.size = Vector2(318, 34)
	tab_row.add_theme_constant_override("separation", 6)
	panel.add_child(tab_row)

	var bt_cards := Button.new()
	bt_cards.text = "קלפים היסטוריים"
	bt_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bt_shop := Button.new()
	bt_shop.text = "חנות"
	bt_shop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bt_inv := Button.new()
	bt_inv.text = "תיק"
	bt_inv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for b in [bt_cards, bt_shop, bt_inv]:
		b.custom_minimum_size = Vector2(96, 30)
		_style_shop_button(b)
		tab_row.add_child(b)

	var stack := Control.new()
	stack.name = "JourneyStack"
	stack.position = Vector2(8, 122)
	stack.size = Vector2(318, 318)
	panel.add_child(stack)

	var scroll_cards := ScrollContainer.new()
	scroll_cards.name = "CardsScroll"
	scroll_cards.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll_cards.offset_right = 318
	scroll_cards.offset_bottom = 318
	var grid_cards := GridContainer.new()
	grid_cards.name = "CardsGrid"
	grid_cards.columns = 2
	grid_cards.add_theme_constant_override("h_separation", 8)
	grid_cards.add_theme_constant_override("v_separation", 8)
	scroll_cards.add_child(grid_cards)

	var wrap_c := Control.new()
	wrap_c.name = "JourneyPageCards"
	wrap_c.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap_c.offset_right = 318
	wrap_c.offset_bottom = 318
	wrap_c.add_child(scroll_cards)
	stack.add_child(wrap_c)

	var scroll_shop := ScrollContainer.new()
	scroll_shop.name = "ShopScroll"
	scroll_shop.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll_shop.offset_right = 318
	scroll_shop.offset_bottom = 318
	var vbox_shop := VBoxContainer.new()
	vbox_shop.name = "ShopVBox"
	vbox_shop.add_theme_constant_override("separation", 8)
	vbox_shop.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox_shop.offset_right = 318
	vbox_shop.offset_bottom = 318
	scroll_shop.add_child(vbox_shop)

	var wrap_s := Control.new()
	wrap_s.name = "JourneyPageShop"
	wrap_s.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap_s.offset_right = 318
	wrap_s.offset_bottom = 318
	wrap_s.visible = false
	wrap_s.add_child(scroll_shop)
	stack.add_child(wrap_s)

	var scroll_inv := ScrollContainer.new()
	scroll_inv.name = "InvScroll"
	scroll_inv.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll_inv.offset_right = 318
	scroll_inv.offset_bottom = 318
	var grid_inv := GridContainer.new()
	grid_inv.name = "InvGrid"
	grid_inv.columns = 2
	grid_inv.add_theme_constant_override("h_separation", 6)
	grid_inv.add_theme_constant_override("v_separation", 6)
	grid_inv.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid_inv.offset_right = 318
	grid_inv.offset_bottom = 318
	scroll_inv.add_child(grid_inv)

	var wrap_i := Control.new()
	wrap_i.name = "JourneyPageInv"
	wrap_i.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap_i.offset_right = 318
	wrap_i.offset_bottom = 318
	wrap_i.visible = false
	wrap_i.add_child(scroll_inv)
	stack.add_child(wrap_i)

	var _pick := func(idx: int):
		for j in stack.get_child_count():
			var pg: Control = stack.get_child(j) as Control
			if pg != null:
				pg.visible = (j == idx)

	bt_cards.pressed.connect(func(): _pick.call(0))
	bt_shop.pressed.connect(func(): _pick.call(1))
	bt_inv.pressed.connect(func(): _pick.call(2))

	var btn_close := Button.new()
	btn_close.text = "סגור"
	btn_close.position = Vector2(86, 448)
	btn_close.size = Vector2(160, 32)
	_style_shop_button(btn_close)
	btn_close.pressed.connect(root.queue_free)
	panel.add_child(btn_close)

	var btn_field := Button.new()
	btn_field.text = "חנות בין גלים"
	btn_field.position = Vector2(176, 448)
	btn_field.size = Vector2(160, 32)
	_style_shop_button(btn_field)
	btn_field.pressed.connect(func():
		root.queue_free()
		if is_instance_valid(_player_ref):
			call_deferred("run_interwave_shop", _player_ref)
	)
	panel.add_child(btn_field)

	_journey_refresh_tabs(root)

	await root.tree_exited


func _journey_try_meta_purchase(root: Control, item_id: String, wallet_lbl: Label) -> void:
	if GameData.try_buy_meta_shop_item(item_id, _player_ref):
		_journey_refresh_tabs(root)
	else:
		wallet_lbl.text = "לא ניתן לקנות — בדוק מטבעות, שלב נשק, או שחקן פעיל (לב)."


func _journey_refresh_tabs(root: Control) -> void:
	var panel: Panel = root.get_node_or_null("JourneyMainPanel") as Panel
	if panel == null:
		return

	var grid_c: GridContainer = panel.get_node_or_null("JourneyStack/JourneyPageCards/CardsScroll/CardsGrid") as GridContainer
	if grid_c == null:
		return
	for c in grid_c.get_children():
		c.queue_free()
	if GameData.collected_history_card_ids.is_empty():
		var empty_l := Label.new()
		empty_l.text = "אין עדיין קלפים.\nנצח את בוס העיר העתיקה כדי לקבל קלף היסטוריה."
		empty_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_l.custom_minimum_size = Vector2(280, 80)
		empty_l.add_theme_font_size_override("font_size", 13)
		empty_l.add_theme_color_override("font_color", Color(C_WHITE, 0.75))
		grid_c.add_child(empty_l)
	else:
		for cid: String in GameData.collected_history_card_ids:
			var cdata: Dictionary = GameData.get_history_card_by_id(cid)
			if cdata.is_empty():
				continue
			var cap: Dictionary = cdata.duplicate(true)
			var thumb := _make_history_thumb_button(cap)
			thumb.pressed.connect(_show_journey_card_reading.bind(cap.duplicate(true)))
			grid_c.add_child(thumb)

	var vshop: VBoxContainer = panel.get_node_or_null("JourneyStack/JourneyPageShop/ShopScroll/ShopVBox") as VBoxContainer
	if vshop == null:
		return
	for c in vshop.get_children():
		c.queue_free()
	var wlab := Label.new()
	wlab.name = "WalletLine"
	wlab.add_theme_font_size_override("font_size", 14)
	wlab.add_theme_color_override("font_color", C_GOLD)
	wlab.text = "מטבעות בארנק: %d" % GameData.wallet_coins
	vshop.add_child(wlab)
	for it in GameData.META_SHOP_ITEMS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var info := Label.new()
		var d: Dictionary = it as Dictionary
		info.text = "%s — %d מטבעות\n%s" % [str(d.get("name_he", "")), int(d.get("price", 0)), str(d.get("desc", ""))]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_theme_font_size_override("font_size", 12)
		info.add_theme_color_override("font_color", C_WHITE)
		info.custom_minimum_size = Vector2(160, 48)
		row.add_child(info)
		var buy := Button.new()
		buy.text = "קנה"
		buy.custom_minimum_size = Vector2(72, 40)
		_style_shop_button(buy)
		var item_id: String = str(d.get("id", ""))
		var can_buy := true
		match item_id:
			"meta_heart":
				can_buy = _player_ref != null and is_instance_valid(_player_ref)
			"meta_weapon_sword":
				can_buy = GameData.run_weapon_tier == 0
			"meta_weapon_knife":
				can_buy = GameData.run_weapon_tier == 1
			"meta_weapon_rifle":
				can_buy = GameData.run_weapon_tier == 2
			"meta_stones":
				can_buy = true
			_:
				can_buy = false
		buy.disabled = not can_buy
		buy.pressed.connect(_journey_try_meta_purchase.bind(root, item_id, wlab))
		row.add_child(buy)
		vshop.add_child(row)

	var grid_i: GridContainer = panel.get_node_or_null("JourneyStack/JourneyPageInv/InvScroll/InvGrid") as GridContainer
	if grid_i == null:
		return
	for c in grid_i.get_children():
		c.queue_free()
	GameData.ensure_inventory_slots()
	for si in GameData.INVENTORY_MAX_SLOTS:
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(148, 52)
		var ss := StyleBoxFlat.new()
		ss.bg_color = Color(0, 0, 0, 0.35)
		ss.border_color = Color(C_GOLD, 0.35)
		ss.set_border_width_all(1)
		ss.corner_radius_top_left = 6
		ss.corner_radius_top_right = 6
		ss.corner_radius_bottom_left = 6
		ss.corner_radius_bottom_right = 6
		slot.add_theme_stylebox_override("panel", ss)
		var sl := Label.new()
		sl.position = Vector2(6, 4)
		sl.size = Vector2(136, 44)
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sl.add_theme_font_size_override("font_size", 11)
		sl.add_theme_color_override("font_color", C_WHITE)
		var entry: Variant = GameData.inventory_slots[si] if si < GameData.inventory_slots.size() else null
		if entry is Dictionary:
			var ed: Dictionary = entry
			var iid: String = str(ed.get("id", ""))
			sl.text = "%s ×%d" % [GameData.get_inventory_item_name_he(iid), int(ed.get("qty", 1))]
		else:
			sl.text = "— ריק —"
			sl.add_theme_color_override("font_color", Color(C_WHITE, 0.35))
		slot.add_child(sl)
		grid_i.add_child(slot)


func _make_history_thumb_button(card: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(148, 108)
	btn.flat = true
	var face := ColorRect.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.position = Vector2(6, 4)
	face.size = Vector2(136, 52)
	var g := Gradient.new()
	g.set_color(0, card.get("face_a", Color.WHITE) as Color)
	g.set_color(1, card.get("face_b", Color.LIGHT_GRAY) as Color)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 0)
	gt.fill_to = Vector2(0.5, 1)
	gt.width = 2
	gt.height = 128
	var tr := TextureRect.new()
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.texture = gt
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	face.add_child(tr)
	btn.add_child(face)
	var accent := ColorRect.new()
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	accent.position = Vector2(6, 4)
	accent.size = Vector2(136, 14)
	accent.color = (card.get("accent_a", C_GOLD) as Color).lightened(0.05)
	btn.add_child(accent)
	var lbl := Label.new()
	lbl.text = str(card.get("title", ""))
	lbl.position = Vector2(8, 60)
	lbl.size = Vector2(132, 44)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", card.get("title_color", C_WHITE) as Color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(lbl)
	return btn


func _show_journey_card_reading(card: Dictionary) -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 80
	add_child(overlay)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	overlay.add_child(dim)

	var th := _history_theme_from_card(card)
	var panel := Panel.new()
	panel.position = Vector2(200, 70)
	panel.size = Vector2(560, 400)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(th.face_b.r * 0.2, th.face_b.g * 0.2, th.face_b.b * 0.25, 0.97)
	ps.border_color = th.border
	ps.set_border_width_all(3)
	ps.corner_radius_top_left = 12
	ps.corner_radius_top_right = 12
	ps.corner_radius_bottom_left = 12
	ps.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", ps)
	overlay.add_child(panel)

	var t := Label.new()
	t.text = str(card.get("title", ""))
	t.position = Vector2(20, 16)
	t.size = Vector2(520, 48)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.add_theme_font_size_override("font_size", 20)
	t.add_theme_color_override("font_color", th.title_c)
	panel.add_child(t)

	var body := Label.new()
	body.text = str(card.get("body", ""))
	body.position = Vector2(20, 72)
	body.size = Vector2(520, 240)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 15)
	body.add_theme_color_override("font_color", th.body_c)
	panel.add_child(body)

	var url: String = str(card.get("wiki_url", GameData.WIKI_ISRAEL_HISTORY))
	var btn_w := Button.new()
	btn_w.text = "מאמר ויקיפדיה"
	btn_w.position = Vector2(20, 322)
	btn_w.size = Vector2(240, 36)
	_style_history_card_button(btn_w, th)
	btn_w.pressed.connect(func():
		OS.shell_open(url)
	)
	panel.add_child(btn_w)

	var btn_x := Button.new()
	btn_x.text = "סגור"
	btn_x.position = Vector2(300, 322)
	btn_x.size = Vector2(240, 36)
	_style_history_card_button(btn_x, th)
	btn_x.pressed.connect(overlay.queue_free)
	panel.add_child(btn_x)

# ─── Ideology stat bars (bottom-left) ─────────────────────────────────────
func _build_ideology_panel() -> void:
	var data: Dictionary = GameData.get_char_data()
	var stats := [
		["כוח",     data["ideology_power"],   Color(0.90, 0.38, 0.10)],
		["מהירות",  data["ideology_speed"],   Color(0.10, 0.78, 0.92)],
		["תחבולה",  data["ideology_tactics"], Color(0.68, 0.18, 0.88)],
	]

	# Background panel
	var panel := ColorRect.new()
	panel.color    = C_BG
	panel.size     = Vector2(142, 50)
	panel.position = Vector2(8, 484)
	add_child(panel)

	# Gold top border
	var border := ColorRect.new()
	border.color    = Color(C_GOLD, 0.5)
	border.size     = Vector2(142, 1)
	border.position = Vector2(8, 484)
	add_child(border)

	for i in stats.size():
		var stat_name: String = stats[i][0]
		var value: int        = stats[i][1]
		var bar_color: Color  = stats[i][2]
		var y := 488.0 + i * 14.0

		var lbl := Label.new()
		lbl.text     = stat_name
		lbl.position = Vector2(12, y)
		lbl.add_theme_font_size_override("font_size", 9)
		lbl.add_theme_color_override("font_color", Color(C_WHITE, 0.80))
		add_child(lbl)

		# Bar background
		var bar_bg := ColorRect.new()
		bar_bg.color    = Color(0.08, 0.08, 0.08, 0.85)
		bar_bg.size     = Vector2(76, 8)
		bar_bg.position = Vector2(62, y + 1)
		add_child(bar_bg)

		# Bar fill (width = 76 * value/5)
		var bar_fill := ColorRect.new()
		bar_fill.color    = bar_color
		bar_fill.size     = Vector2(76.0 * value / 5.0, 8)
		bar_fill.position = Vector2(62, y + 1)
		add_child(bar_fill)

		# Subtle shine on top of fill
		var shine := ColorRect.new()
		shine.color    = Color(1, 1, 1, 0.18)
		shine.size     = Vector2(76.0 * value / 5.0, 3)
		shine.position = Vector2(62, y + 1)
		add_child(shine)

		# Pip markers every 20% (5 pips)
		for pip in 4:
			var mark := ColorRect.new()
			mark.color    = Color(0, 0, 0, 0.55)
			mark.size     = Vector2(1, 8)
			mark.position = Vector2(62 + 76.0 * (pip + 1) / 5.0, y + 1)
			add_child(mark)

# ─── Character mini icon (little flag/shield) ───────────────────────────────
func _make_char_icon(data: Dictionary) -> Node2D:
	var n := Node2D.new()

	var bg := Polygon2D.new()
	bg.polygon = PackedVector2Array([
		Vector2(-14, -10), Vector2(14, -10),
		Vector2(14, 6), Vector2(0, 14), Vector2(-14, 6)
	])
	bg.color = data["color_body"]
	n.add_child(bg)

	# Accent stripe
	var stripe := Polygon2D.new()
	stripe.polygon = PackedVector2Array([
		Vector2(-14, -2), Vector2(14, -2),
		Vector2(14, 2), Vector2(-14, 2)
	])
	stripe.color = data["color_accent"]
	n.add_child(stripe)

	return n

# ─── Lives ──────────────────────────────────────────────────────────────────
func _refresh_lives(count: int) -> void:
	for child in _lives_container.get_children():
		child.queue_free()
	for i in count:
		var heart := _make_heart()
		_lives_container.add_child(heart)

func _make_heart() -> Control:
	# Simple heart using two Polygon2D nodes on a Control wrapper for sizing
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(18, 18)
	var heart := Polygon2D.new()
	heart.polygon = PackedVector2Array([
		Vector2(9, 16),
		Vector2(1, 8), Vector2(1, 4),
		Vector2(4, 1), Vector2(7, 1), Vector2(9, 4),
		Vector2(11, 1), Vector2(14, 1), Vector2(17, 4),
		Vector2(17, 8),
	])
	heart.color = C_RED
	wrap.add_child(heart)
	var shine := Polygon2D.new()
	shine.polygon = PackedVector2Array([
		Vector2(4, 4), Vector2(6, 3), Vector2(7, 5), Vector2(5, 6)
	])
	shine.color = Color(1, 1, 1, 0.45)
	wrap.add_child(shine)
	return wrap

# ─── Public API ────────────────────────────────────────────────────────────
func update_health(hp: int, max_hp: int) -> void:
	_max_hp = max_hp
	var pct: float = clampf(hp / float(max_hp), 0.0, 1.0)
	_health_fill.size.x = 200.0 * pct
	# Color: green > yellow > red as it drains
	if pct > 0.6:
		_health_fill.color = C_GREEN
	elif pct > 0.3:
		_health_fill.color = C_YELLOW
	else:
		_health_fill.color = C_RED
	_health_text.text = "%d / %d" % [max(hp, 0), max_hp]

	# Flash the bar on change
	var tween: Tween = create_tween()
	tween.tween_property(_health_fill, "modulate", Color(1.6, 1.6, 1.6), 0.05)
	tween.tween_property(_health_fill, "modulate", Color.WHITE, 0.15)

func update_lives(count: int) -> void:
	_refresh_lives(max(0, count))

func update_score(value: int) -> void:
	_score_value = value
	# Animate score counting (display catches up gradually)
	# (Actual update happens in _process)


func _on_run_economy_changed(coins: int, stones_progress: int, skill_rank: int, _weapon_tier: int) -> void:
	if is_instance_valid(_econ_coins_lbl):
		_econ_coins_lbl.text = "מטבעות: %d" % coins
	if is_instance_valid(_econ_stones_lbl):
		_econ_stones_lbl.text = "אבני ירושלים: %d/10" % stones_progress
	if is_instance_valid(_skill_rank_lbl):
		_skill_rank_lbl.text = "מיומנות: %d" % skill_rank
	if is_instance_valid(_weapon_lbl):
		_weapon_lbl.text = "נשק: %s" % GameData.get_weapon_name_he()


func _process(delta: float) -> void:
	if _score_display != _score_value:
		var diff: int = _score_value - _score_display
		var step: int = int(max(1, abs(diff) * delta * 6.0))
		if diff > 0:
			_score_display = min(_score_display + step, _score_value)
		else:
			_score_display = max(_score_display - step, _score_value)
		_score_label.text = "%06d" % _score_display

# ─── Center banner message (wave announcements) ────────────────────────────
func show_wave_message(text: String, duration: float = 1.5) -> void:
	var banner := Control.new()
	banner.size = Vector2(960, 540)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(banner)

	# Dim overlay
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.0)
	dim.size = Vector2(960, 80)
	dim.position = Vector2(0, 215)
	banner.add_child(dim)

	var lbl := Label.new()
	lbl.text = text
	lbl.size = Vector2(960, 80)
	lbl.position = Vector2(0, 220)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 54)
	lbl.add_theme_color_override("font_color", C_GOLD)
	lbl.add_theme_constant_override("shadow_offset_x", 3)
	lbl.add_theme_constant_override("shadow_offset_y", 3)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	lbl.scale = Vector2(0.6, 0.6)
	lbl.pivot_offset = lbl.size / 2.0
	lbl.modulate.a = 0.0
	banner.add_child(lbl)

	# Animate in
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "modulate:a", 1.0, 0.22)
	tw.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(dim, "color", Color(0, 0, 0, 0.35), 0.22)

	if not await _await_seconds(duration):
		return

	# Animate out
	if is_instance_valid(lbl):
		var tw2: Tween = create_tween()
		tw2.set_parallel(true)
		tw2.tween_property(lbl, "modulate:a", 0.0, 0.3)
		tw2.tween_property(lbl, "scale", Vector2(1.15, 1.15), 0.3)
		tw2.tween_property(dim, "color", Color(0, 0, 0, 0.0), 0.3)
		if not await _await_seconds(0.32):
			return

	if is_instance_valid(banner):
		banner.queue_free()

# Alias for older calls
func _hero_label_text(data: Dictionary) -> String:
	var hero: String = GameData.player_hero_name.strip_edges()
	if hero.is_empty():
		hero = data["name_he"]
	return "%s · %s" % [hero, data["name_he"]]

func show_message(text: String, duration: float = 2.0) -> void:
	show_wave_message(text, duration)


func run_interwave_shop(player: CharacterBody2D) -> void:
	# Ad on shop entry (5s) then optional rewarded (30s) for a free life.
	if is_instance_valid(_journey_book_root):
		_journey_book_root.queue_free()
	await AdsManager.show_interstitial("enter_shop", 5.0, 5.0)
	var wants_reward := await _prompt_reward_ad()
	if wants_reward:
		var completed := await AdsManager.show_rewarded("shop_free_life", 30.0)
		if completed and player != null and is_instance_valid(player) and player.has_method("grant_bonus_life"):
			player.grant_bonus_life(1)
			show_wave_message("קיבלת לב חינם!", 1.4)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.z_index = 30
	add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.52)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	var panel := Panel.new()
	panel.position = Vector2(200, 90)
	panel.size = Vector2(560, 360)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.06, 0.07, 0.12, 0.96)
	ps.border_color = Color(C_GOLD, 0.75)
	ps.set_border_width_all(2)
	ps.corner_radius_top_left = 12
	ps.corner_radius_top_right = 12
	ps.corner_radius_bottom_left = 12
	ps.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", ps)
	root.add_child(panel)

	var title := Label.new()
	title.text = "חנות בין גלים"
	title.position = Vector2(0, 12)
	title.size = Vector2(560, 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", C_GOLD)
	panel.add_child(title)

	var info := Label.new()
	info.position = Vector2(24, 48)
	info.size = Vector2(512, 52)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.text = "מטבעות: %d  ·  נשק נוכחי: %s\n%s" % [
		GameData.wallet_coins,
		GameData.get_weapon_name_he(),
		GameData.get_interwave_shop_summary_line(),
	]
	info.add_theme_font_size_override("font_size", 13)
	info.add_theme_color_override("font_color", C_WHITE)
	panel.add_child(info)

	var status := Label.new()
	status.name = "ShopStatus"
	status.position = Vector2(24, 248)
	status.size = Vector2(512, 36)
	status.add_theme_font_size_override("font_size", 13)
	status.add_theme_color_override("font_color", Color(C_GOLD, 0.9))
	panel.add_child(status)

	var _refresh_status := func():
		if is_instance_valid(status):
			status.text = "מטבעות אחרי רכישה: %d" % GameData.wallet_coins

	var _refresh_info := func():
		info.text = "מטבעות: %d  ·  נשק נוכחי: %s\n%s" % [
			GameData.wallet_coins,
			GameData.get_weapon_name_he(),
			GameData.get_interwave_shop_summary_line(),
		]

	var btn_heart := Button.new()
	btn_heart.text = "קנה לב נוסף (+%d מטבעות)" % GameData.SHOP_HEART_PRICE
	btn_heart.position = Vector2(40, 108)
	btn_heart.size = Vector2(240, 38)
	_style_shop_button(btn_heart)
	btn_heart.pressed.connect(func():
		if player.has_method("try_shop_buy_heart") and player.try_shop_buy_heart():
			_refresh_status.call()
			_refresh_info.call()
		else:
			status.text = "אין מספיק מטבעות או הרכישה נכשלה."
	)
	panel.add_child(btn_heart)

	var btn_weapon := Button.new()
	btn_weapon.text = GameData.get_next_weapon_button_text()
	btn_weapon.position = Vector2(300, 108)
	btn_weapon.size = Vector2(220, 38)
	btn_weapon.disabled = GameData.run_weapon_tier >= 3
	_style_shop_button(btn_weapon)
	btn_weapon.pressed.connect(func():
		if player.has_method("try_shop_buy_weapon") and player.try_shop_buy_weapon():
			_refresh_status.call()
			_refresh_info.call()
			btn_weapon.text = GameData.get_next_weapon_button_text()
			btn_weapon.disabled = GameData.run_weapon_tier >= 3
		else:
			status.text = "אין מספיק מטבעות או נשק מלא (רובה ישן)."
	)
	panel.add_child(btn_weapon)

	var btn_stones := Button.new()
	btn_stones.text = "אבני ירושלים ×%d (+%d מטבעות)" % [
		GameData.SHOP_STONES_BUNDLE_AMOUNT,
		GameData.SHOP_PRICE_STONES_BUNDLE,
	]
	btn_stones.position = Vector2(40, 156)
	btn_stones.size = Vector2(480, 38)
	_style_shop_button(btn_stones)
	btn_stones.pressed.connect(func():
		if GameData.try_buy_meta_shop_item("meta_stones", player):
			_refresh_status.call()
			_refresh_info.call()
		else:
			status.text = "אין מספיק מטבעות."
	)
	panel.add_child(btn_stones)

	var btn_go := Button.new()
	btn_go.text = "המשך לגל הבא"
	btn_go.position = Vector2(180, 302)
	btn_go.size = Vector2(200, 44)
	_style_shop_button(btn_go)
	btn_go.pressed.connect(root.queue_free)
	panel.add_child(btn_go)

	_refresh_status.call()
	await root.tree_exited

func _prompt_reward_ad() -> bool:
	get_tree().call_group("touch_controls_overlay", "push_touch_ui_block")
	# Add to the HUD (self) so Godot's GUI input system works correctly and the
	# dialog renders above the game world inside the HUD's canvas layer (10).
	# z_index 100 puts it above all other HUD overlays (max used elsewhere is 80).
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.z_index = 100
	add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.60)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	var panel := Panel.new()
	panel.position = Vector2(190, 160)
	panel.size = Vector2(580, 220)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.06, 0.07, 0.12, 0.98)
	ps.border_color = Color(C_GOLD, 0.85)
	ps.set_border_width_all(2)
	ps.corner_radius_top_left = 14
	ps.corner_radius_top_right = 14
	ps.corner_radius_bottom_left = 14
	ps.corner_radius_bottom_right = 14
	panel.add_theme_stylebox_override("panel", ps)
	root.add_child(panel)

	var t := Label.new()
	t.text = "חיים חינם?"
	t.position = Vector2(0, 16)
	t.size = Vector2(580, 28)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 22)
	t.add_theme_color_override("font_color", C_GOLD)
	panel.add_child(t)

	var msg := Label.new()
	msg.text = "במידה ותרצה לקבל חיים חינם תצפה בפרסומת במשך 30 שניות."
	msg.position = Vector2(34, 58)
	msg.size = Vector2(512, 60)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	msg.add_theme_font_size_override("font_size", 15)
	msg.add_theme_color_override("font_color", C_WHITE)
	panel.add_child(msg)

	var btn_yes := Button.new()
	btn_yes.text = "צפה עכשיו"
	btn_yes.position = Vector2(70, 140)
	btn_yes.size = Vector2(200, 52)
	btn_yes.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_shop_button(btn_yes)
	panel.add_child(btn_yes)

	var btn_no := Button.new()
	btn_no.text = "אולי אחר כך"
	btn_no.position = Vector2(310, 140)
	btn_no.size = Vector2(200, 52)
	btn_no.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_shop_button(btn_no)
	panel.add_child(btn_no)

	# Use an Array so the lambda captures a reference, not a copy of a bool.
	# GDScript closures in coroutines capture primitive types (bool/int) by value,
	# so assigning "decided = true" inside a lambda never updates the outer variable.
	# All other dialogs in this file use the same await-tree_exited pattern.
	var chose_yes := [false]
	btn_yes.pressed.connect(func():
		chose_yes[0] = true
		root.queue_free()
	)
	btn_no.pressed.connect(root.queue_free)

	await root.tree_exited
	get_tree().call_group("touch_controls_overlay", "pop_touch_ui_block")

	return chose_yes[0]


func _style_shop_button(btn: Button) -> void:
	btn.add_theme_font_size_override("font_size", 15)
	btn.add_theme_color_override("font_color", C_WHITE)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.14, 0.16, 0.32, 0.95)
	s.border_color = Color(C_WHITE, 0.35)
	s.set_border_width_all(2)
	s.corner_radius_top_left = 8
	s.corner_radius_top_right = 8
	s.corner_radius_bottom_left = 8
	s.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", s)
	var sh := s.duplicate() as StyleBoxFlat
	sh.bg_color = Color(0.22, 0.24, 0.44)
	sh.border_color = C_GOLD
	btn.add_theme_stylebox_override("hover", sh)


func show_history_card(card_data: Dictionary) -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.z_index = 40
	add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.04, 0.08, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	var th := _history_theme_from_card(card_data)

	var hint := Label.new()
	hint.text = "+ קלף חדש נוסף לאוסף"
	hint.position = Vector2(0, 28)
	hint.size = Vector2(960, 22)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", _color_with_alpha(th.border, 0.95))
	hint.modulate.a = 0.0
	root.add_child(hint)

	const CARD_W := 360.0
	const CARD_H := 500.0
	var card_wrap := Control.new()
	card_wrap.position = Vector2((960.0 - CARD_W) * 0.5, (540.0 - CARD_H) * 0.5 + 8.0)
	card_wrap.size = Vector2(CARD_W, CARD_H)
	card_wrap.pivot_offset = Vector2(CARD_W * 0.5, CARD_H * 0.5)
	card_wrap.rotation = -0.12
	card_wrap.scale = Vector2(0.35, 0.35)
	card_wrap.modulate.a = 0.0
	root.add_child(card_wrap)

	var shadow := Panel.new()
	shadow.position = Vector2(10, 14)
	shadow.size = Vector2(CARD_W, CARD_H)
	var shs := StyleBoxFlat.new()
	shs.bg_color = Color(0, 0, 0, 0.45)
	shs.corner_radius_top_left = 18
	shs.corner_radius_top_right = 18
	shs.corner_radius_bottom_left = 18
	shs.corner_radius_bottom_right = 18
	shadow.add_theme_stylebox_override("panel", shs)
	card_wrap.add_child(shadow)

	var card_panel := Panel.new()
	card_panel.position = Vector2.ZERO
	card_panel.size = Vector2(CARD_W, CARD_H)
	card_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0, 0, 0, 0.0)
	frame.border_color = th.border
	frame.set_border_width_all(5)
	frame.corner_radius_top_left = 16
	frame.corner_radius_top_right = 16
	frame.corner_radius_bottom_left = 16
	frame.corner_radius_bottom_right = 16
	frame.shadow_color = Color(0, 0, 0, 0.35)
	frame.shadow_size = 12
	frame.shadow_offset = Vector2(2, 4)
	card_panel.add_theme_stylebox_override("panel", frame)
	card_wrap.add_child(card_panel)

	var face := ColorRect.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.position = Vector2(10, 10)
	face.size = Vector2(CARD_W - 20, CARD_H - 20)
	var g := Gradient.new()
	g.set_color(0, th.face_a)
	g.set_color(1, th.face_b)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	gt.width = 4
	gt.height = 256
	var face_tex := TextureRect.new()
	face_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face_tex.texture = gt
	face_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face_tex.stretch_mode = TextureRect.STRETCH_SCALE
	face_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	face_tex.offset_left = 0
	face_tex.offset_top = 0
	face_tex.offset_right = 0
	face_tex.offset_bottom = 0
	face.add_child(face_tex)
	card_panel.add_child(face)

	var inner := StyleBoxFlat.new()
	inner.bg_color = Color(0, 0, 0, 0.0)
	var inner_edge: Color = th.border.lightened(0.15)
	inner.border_color = _color_with_alpha(inner_edge, 0.55)
	inner.set_border_width_all(1)
	inner.corner_radius_top_left = 12
	inner.corner_radius_top_right = 12
	inner.corner_radius_bottom_left = 12
	inner.corner_radius_bottom_right = 12
	var inner_line := Panel.new()
	inner_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_line.position = Vector2(14, 14)
	inner_line.size = Vector2(CARD_W - 28, CARD_H - 28)
	inner_line.add_theme_stylebox_override("panel", inner)
	card_panel.add_child(inner_line)

	var band_h := 128.0
	var band := TextureRect.new()
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.position = Vector2(14, 14)
	band.size = Vector2(CARD_W - 28, band_h)
	var gb := Gradient.new()
	gb.set_color(0, th.accent_a)
	gb.set_color(1, th.accent_b)
	var gtb := GradientTexture2D.new()
	gtb.gradient = gb
	gtb.fill_from = Vector2(0.0, 0.5)
	gtb.fill_to = Vector2(1.0, 0.5)
	gtb.width = 256
	gtb.height = 4
	band.texture = gtb
	band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	band.stretch_mode = TextureRect.STRETCH_SCALE
	card_panel.add_child(band)

	var ornament := _history_make_ornament(str(card_data.get("ornament", "flag_star")), th.accent_a, th.accent_b, th.border)
	ornament.position = Vector2(CARD_W * 0.5, 14.0 + band_h * 0.5)
	card_panel.add_child(ornament)

	var rarity := Label.new()
	rarity.text = "★ נדיר · היסטוריה"
	rarity.position = Vector2(22, 22)
	rarity.size = Vector2(200, 16)
	rarity.add_theme_font_size_override("font_size", 10)
	rarity.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	card_panel.add_child(rarity)

	var t := Label.new()
	t.text = str(card_data.get("title", ""))
	t.position = Vector2(22, 14 + band_h + 8)
	t.size = Vector2(CARD_W - 44, 56)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 19)
	t.add_theme_color_override("font_color", th.title_c)
	t.add_theme_constant_override("shadow_offset_x", 1)
	t.add_theme_constant_override("shadow_offset_y", 1)
	t.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.25))
	card_panel.add_child(t)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 14 + band_h + 68)
	scroll.size = Vector2(CARD_W - 40, 218)
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	card_panel.add_child(scroll)

	var body := Label.new()
	body.text = str(card_data.get("body", ""))
	body.size = Vector2(CARD_W - 56, 0)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", th.body_c)
	scroll.add_child(body)
	await get_tree().process_frame
	body.custom_minimum_size.y = max(120.0, body.get_content_height() + 8.0)

	var url: String = str(card_data.get("wiki_url", GameData.WIKI_ISRAEL_HISTORY))

	var btn_wiki := Button.new()
	btn_wiki.text = "ויקיפדיה · היסטוריה של מדינת ישראל"
	btn_wiki.position = Vector2(22, CARD_H - 92)
	btn_wiki.size = Vector2(CARD_W - 44, 36)
	_style_history_card_button(btn_wiki, th)
	btn_wiki.pressed.connect(func():
		OS.shell_open(url)
	)
	card_panel.add_child(btn_wiki)

	var btn_close := Button.new()
	btn_close.text = "המשך"
	btn_close.position = Vector2(22, CARD_H - 50)
	btn_close.size = Vector2(CARD_W - 44, 36)
	_style_history_card_button(btn_close, th)
	btn_close.pressed.connect(root.queue_free)
	card_panel.add_child(btn_close)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(card_wrap, "modulate:a", 1.0, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(hint, "modulate:a", 1.0, 0.45).set_delay(0.08)
	tw.tween_property(card_wrap, "scale", Vector2(1.0, 1.0), 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card_wrap, "rotation", 0.0, 0.52).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	await root.tree_exited


func _color_with_alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)


func _history_theme_from_card(card: Dictionary) -> _HistoryCardTheme:
	# Small theme bag so we can pass grouped colors without a dedicated class file.
	var bag := _HistoryCardTheme.new()
	bag.accent_a = card.get("accent_a", Color(0.12, 0.18, 0.42)) as Color
	bag.accent_b = card.get("accent_b", Color(0.3, 0.4, 0.65)) as Color
	bag.face_a = card.get("face_a", Color(0.96, 0.97, 1.0)) as Color
	bag.face_b = card.get("face_b", Color(0.78, 0.82, 0.9)) as Color
	bag.border = card.get("border", C_GOLD) as Color
	bag.title_c = card.get("title_color", Color(0.08, 0.1, 0.18)) as Color
	bag.body_c = card.get("body_color", Color(0.14, 0.16, 0.22)) as Color
	return bag


class _HistoryCardTheme extends RefCounted:
	var accent_a: Color
	var accent_b: Color
	var face_a: Color
	var face_b: Color
	var border: Color
	var title_c: Color
	var body_c: Color


func _style_history_card_button(btn: Button, th: _HistoryCardTheme) -> void:
	btn.add_theme_font_size_override("font_size", 14)
	var lum: float = th.face_a.get_luminance()
	btn.add_theme_color_override("font_color", th.title_c if lum > 0.45 else th.title_c.lightened(0.55))
	var s := StyleBoxFlat.new()
	s.bg_color = _color_with_alpha(th.accent_a, 0.38)
	s.border_color = _color_with_alpha(th.border, 0.82)
	s.set_border_width_all(2)
	s.corner_radius_top_left = 8
	s.corner_radius_top_right = 8
	s.corner_radius_bottom_left = 8
	s.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", s)
	var sh := s.duplicate() as StyleBoxFlat
	sh.bg_color = _color_with_alpha(th.accent_b, 0.55)
	sh.border_color = th.border
	btn.add_theme_stylebox_override("hover", sh)


func _history_make_ornament(kind: String, ca: Color, cb: Color, gold: Color) -> Node2D:
	var n := Node2D.new()
	match kind:
		"flag_star":
			var field := ColorRect.new()
			field.size = Vector2(120, 72)
			field.position = Vector2(-60, -36)
			field.color = ca
			n.add_child(field)
			var stripe := ColorRect.new()
			stripe.size = Vector2(120, 24)
			stripe.position = Vector2(-60, -12)
			stripe.color = Color(0.95, 0.95, 0.95)
			n.add_child(stripe)
			var st := Polygon2D.new()
			st.polygon = PackedVector2Array([
				Vector2(0, -18), Vector2(6, -6), Vector2(18, -6),
				Vector2(8, 2), Vector2(12, 16), Vector2(0, 8),
				Vector2(-12, 16), Vector2(-8, 2), Vector2(-18, -6),
				Vector2(-6, -6),
			])
			st.color = gold
			n.add_child(st)
		"olive_shield":
			var sh := Polygon2D.new()
			sh.polygon = PackedVector2Array([
				Vector2(0, -40), Vector2(34, -18), Vector2(34, 22),
				Vector2(0, 42), Vector2(-34, 22), Vector2(-34, -18),
			])
			sh.color = ca.darkened(0.05)
			n.add_child(sh)
			var drip := ColorRect.new()
			drip.size = Vector2(8, 22)
			drip.position = Vector2(-4, -8)
			drip.color = Color(0.62, 0.1, 0.08)
			n.add_child(drip)
		"ship_waves":
			for i in 3:
				var wv := ColorRect.new()
				wv.size = Vector2(100 - i * 18, 6)
				wv.position = Vector2(-50 + i * 6, 14 + i * 10)
				wv.color = cb.darkened(0.15 + i * 0.06)
				n.add_child(wv)
			var hull := Polygon2D.new()
			hull.polygon = PackedVector2Array([
				Vector2(-40, 8), Vector2(40, 8), Vector2(20, -28), Vector2(-10, -32),
			])
			hull.color = ca.darkened(0.08)
			n.add_child(hull)
		"desert_sun":
			var sun := Polygon2D.new()
			var pts := PackedVector2Array()
			for i in 16:
				var ang := TAU * i / 16.0
				var rad := 38.0 if i % 2 == 0 else 28.0
				pts.append(Vector2(cos(ang) * rad, sin(ang) * rad - 6))
			sun.polygon = pts
			sun.color = cb.lightened(0.12)
			n.add_child(sun)
			var dune := ColorRect.new()
			dune.size = Vector2(140, 18)
			dune.position = Vector2(-70, 18)
			dune.color = ca.darkened(0.12)
			n.add_child(dune)
		"golan_mist":
			for i in 4:
				var fog := ColorRect.new()
				fog.size = Vector2(120, 16)
				fog.position = Vector2(-60, -28 + i * 14)
				fog.color = _color_with_alpha(cb, 0.18 + float(i) * 0.08)
				n.add_child(fog)
			var peak := Polygon2D.new()
			peak.polygon = PackedVector2Array([
				Vector2(-50, 18), Vector2(0, -32), Vector2(50, 18),
			])
			peak.color = ca.darkened(0.05)
			n.add_child(peak)
		"peace_arc":
			var arc := Polygon2D.new()
			arc.polygon = PackedVector2Array([
				Vector2(-52, 18), Vector2(-52, 0), Vector2(-30, -22),
				Vector2(0, -32), Vector2(30, -22), Vector2(52, 0),
				Vector2(52, 18),
			])
			arc.color = _color_with_alpha(cb, 0.55)
			n.add_child(arc)
			var arc2 := Polygon2D.new()
			arc2.polygon = PackedVector2Array([
				Vector2(-40, 18), Vector2(-40, 4), Vector2(-20, -14),
				Vector2(0, -20), Vector2(20, -14), Vector2(40, 4), Vector2(40, 18),
			])
			arc2.color = ca.lightened(0.2)
			n.add_child(arc2)
		"olive_branch":
			for side: int in [-1, 1]:
				var stem := ColorRect.new()
				stem.size = Vector2(4, 52)
				stem.position = Vector2(side * 6 - 2, -26)
				stem.rotation = side * 0.15
				stem.color = ca.darkened(0.2)
				n.add_child(stem)
			for i in 5:
				var lf := Polygon2D.new()
				var sx := -1.0 if i % 2 == 0 else 1.0
				lf.polygon = PackedVector2Array([
					Vector2(sx * 8, -20 + i * 10), Vector2(sx * 28, -14 + i * 10), Vector2(sx * 10, -6 + i * 10),
				])
				lf.color = cb.darkened(0.05 + i * 0.02)
				n.add_child(lf)
		"circuit_glow":
			for gx in range(-2, 3):
				for gy in range(-2, 3):
					if (gx + gy) % 2 != 0:
						continue
					var cell := ColorRect.new()
					cell.size = Vector2(14, 10)
					cell.position = Vector2(gx * 22 - 7, gy * 16 - 5)
					cell.color = _color_with_alpha(cb, 0.35)
					n.add_child(cell)
			var core := ColorRect.new()
			core.size = Vector2(36, 8)
			core.position = Vector2(-18, -4)
			core.color = gold
			n.add_child(core)
		_:
			var d := Polygon2D.new()
			d.polygon = PackedVector2Array([
				Vector2(0, -32), Vector2(28, 0), Vector2(0, 32), Vector2(-28, 0),
			])
			d.color = cb
			n.add_child(d)
	return n

# ─── Pre-fight countdown (3 → 2 → 1 → go) ─────────────────────────────────
func play_game_countdown() -> void:
	var overlay := Control.new()
	overlay.size = Vector2(960, 540)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.size = Vector2(960, 540)
	overlay.add_child(dim)

	var lbl := Label.new()
	lbl.size = Vector2(960, 200)
	lbl.position = Vector2(0, 170)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 110)
	lbl.add_theme_color_override("font_color", C_GOLD)
	lbl.add_theme_constant_override("shadow_offset_x", 4)
	lbl.add_theme_constant_override("shadow_offset_y", 4)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	overlay.add_child(lbl)

	var steps := ["3", "2", "1", "קדימה!"]
	for i in steps.size():
		if not _alive:
			return
		lbl.text = steps[i]
		lbl.scale = Vector2(0.4, 0.4)
		lbl.modulate.a = 0.0
		lbl.pivot_offset = Vector2(480, 100)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(lbl, "modulate:a", 1.0, 0.12)
		tw.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if not await _await_seconds(0.85 if i < 3 else 0.55):
			return
		var tw2 := create_tween()
		tw2.tween_property(lbl, "modulate:a", 0.0, 0.18)
		if not await _await_seconds(0.12):
			return

	if is_instance_valid(overlay):
		overlay.queue_free()

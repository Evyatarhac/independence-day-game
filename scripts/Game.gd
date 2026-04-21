extends Node2D

# ─── Stage settings ─────────────────────────────────────────────────────────
const STAGE_WIDTH    := 3200.0
const FLOOR_Y        := 420.0
const SPAWN_X_OFFSET := 560.0
const CAM_LERP       := 5.0

# ─── Wave system ────────────────────────────────────────────────────────────
var _waves: Array[Dictionary] = []
var _wave_index    := 0
var _enemies_alive := 0

# ─── Nodes ──────────────────────────────────────────────────────────────────
var _player: CharacterBody2D
var _camera: Camera2D
var _hud: CanvasLayer
var _touch: CanvasLayer
var _stage: Node2D
var _bg_layers: Array[Node2D] = []

var _game_over := false
var _time: float = 0.0
## Prevents overlapping _spawn_next_wave() (e.g. intro timer + position trigger).
var _spawning_wave := false
var _next_wave_scheduled := false

# ─── Scripts ────────────────────────────────────────────────────────────────
const PLAYER_SCRIPT := preload("res://scripts/Player.gd")
const ENEMY_SCRIPT  := preload("res://scripts/Enemy.gd")
const HUD_SCRIPT    := preload("res://scripts/HUD.gd")
const TOUCH_SCRIPT  := preload("res://scripts/TouchControls.gd")
const PICKUP_SCRIPT := preload("res://scripts/Pickup.gd")

## After final boss dies, show one Israeli-history “card” before the victory screen.
var _boss_card_pending := false

func _ready() -> void:
	GameData.reset_run_economy()
	GameData.stage_won = false
	_build_waves()
	_build_background()
	_build_stage()
	# HUD must exist before player so initial signal emissions update it
	_build_hud()
	_build_player()
	_build_camera()
	_build_touch()
	if is_instance_valid(_player):
		_player.input_locked = true
	if is_instance_valid(_hud):
		await _hud.play_game_countdown()
	if is_instance_valid(_player):
		_player.input_locked = false
	_spawn_next_wave()

# ─── Wave definitions ────────────────────────────────────────────────────────
## Seven combat waves (1,1,2,3,4,5,7 enemies) then boss. Enemy *kind* cycles:
## בריטי רגיל → מקומי → בריטי חזק (קצין) → חוזר מההתחלה.
func _build_waves() -> void:
	_waves.clear()
	var counts: Array[int] = [1, 1, 2, 3, 4, 5, 7]
	for w in counts.size():
		var n: int = counts[w]
		var types: Array = _types_for_wave_index(w + 1, n)
		_waves.append({"types": types, "trigger_x": -1})
	_waves.append({"types": ["old_city_boss"], "trigger_x": -1})

func _types_for_wave_index(wave_num: int, count: int) -> Array:
	# שלב 1 / 4 / 7… חייל בריטי, שלב 2 / 5… מקומי, שלב 3 / 6… קצין בריטי (חזק יותר).
	var phase: int = (wave_num - 1) % 3
	var etype: String
	match phase:
		0:
			etype = "british_soldier"
		1:
			etype = "local_fighter"
		_:
			etype = "british_officer"

	var out: Array[String] = []
	for _i in count:
		out.append(etype)
	return out

# ─── Background (parallax layers) ────────────────────────────────────────────
func _build_background() -> void:
	# Sky — warm Jerusalem alley light
	var sky_grad := Gradient.new()
	sky_grad.set_color(0, Color(0.52, 0.58, 0.72))
	sky_grad.set_color(1, Color(0.78, 0.72, 0.62))
	var sky_tex := GradientTexture2D.new()
	sky_tex.gradient = sky_grad
	sky_tex.fill_from = Vector2(0, 0)
	sky_tex.fill_to = Vector2(0, 1)
	sky_tex.width = 2
	sky_tex.height = 340

	var sky := Sprite2D.new()
	sky.texture = sky_tex
	sky.centered = false
	sky.z_index = -20
	sky.scale = Vector2(480, 1)  # stretch width
	add_child(sky)

	# Sun
	var sun_node := Node2D.new()
	sun_node.position = Vector2(820, 55)
	sun_node.z_index = -19
	add_child(sun_node)
	var sun := Polygon2D.new()
	var sun_pts := PackedVector2Array()
	for i in 24:
		var ang := TAU * i / 24.0
		sun_pts.append(Vector2(cos(ang) * 42, sin(ang) * 42))
	sun.polygon = sun_pts
	sun.color = Color(1.0, 0.95, 0.60, 0.7)
	sun_node.add_child(sun)

	# Far limestone mass (Old City silhouette)
	_build_building_layer(-18, Color(0.50, 0.46, 0.40), 0.12, 16, 90, 220)
	# Mid domes / roofs
	_build_building_layer(-15, Color(0.62, 0.55, 0.44), 0.22, 14, 70, 160)
	# Near façades
	_build_building_layer(-12, Color(0.72, 0.66, 0.54), 0.38, 12, 85, 200)

	_build_jerusalem_alley_walls()

	# Ground layer — stone lane
	var ground := ColorRect.new()
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground.color = Color(0.44, 0.38, 0.30)
	ground.size = Vector2(STAGE_WIDTH + 1000, 200)
	ground.position = Vector2(-500, 340)
	ground.z_index = -8
	add_child(ground)

	# Road surface — worn flagstones
	var road := ColorRect.new()
	road.mouse_filter = Control.MOUSE_FILTER_IGNORE
	road.color = Color(0.36, 0.32, 0.26)
	road.size = Vector2(STAGE_WIDTH + 1000, 110)
	road.position = Vector2(-500, 360)
	road.z_index = -7
	add_child(road)

	# Road edge highlights
	var edge_top := ColorRect.new()
	edge_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge_top.color = Color(0.48, 0.42, 0.30)
	edge_top.size = Vector2(STAGE_WIDTH + 1000, 3)
	edge_top.position = Vector2(-500, 358)
	edge_top.z_index = -6
	add_child(edge_top)

func _build_building_layer(z: int, color: Color, parallax: float, count: int, min_w: int, max_h: int) -> void:
	var container := Node2D.new()
	container.z_index = z
	container.set_meta("parallax", parallax)
	add_child(container)
	_bg_layers.append(container)

	var rng := RandomNumberGenerator.new()
	rng.seed = int(parallax * 1000 + 17)
	var x := -200.0
	for _i in count:
		var w := rng.randf_range(min_w, min_w * 2)
		var h := rng.randf_range(80, max_h)
		var bld := ColorRect.new()
		bld.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bld.size = Vector2(w, h)
		bld.position = Vector2(x, 340 - h)
		bld.color = color
		container.add_child(bld)

		# Windows
		var win_rng := RandomNumberGenerator.new()
		win_rng.seed = int(x + h)
		var win_rows := int(h / 30)
		var win_cols := int(w / 20)
		for r in win_rows:
			for c in win_cols:
				if win_rng.randf() < 0.35:
					var win := ColorRect.new()
					win.mouse_filter = Control.MOUSE_FILTER_IGNORE
					win.size = Vector2(8, 10)
					win.position = Vector2(x + 8 + c * 20, 340 - h + 10 + r * 30)
					win.color = color.lightened(0.25 + win_rng.randf() * 0.15)
					container.add_child(win)

		x += w + rng.randf_range(20, 80)

## Static limestone façades + arch hints (does not use parallax meta).
func _build_jerusalem_alley_walls() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 901
	var facades := Node2D.new()
	facades.z_index = -11
	add_child(facades)

	var lx := -100.0
	while lx < STAGE_WIDTH + 120:
		var h: float = rng.randf_range(200, 290)
		var seg := ColorRect.new()
		seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		seg.position = Vector2(lx, 340 - h)
		seg.size = Vector2(65 + rng.randf() * 55, h)
		seg.color = Color(0.80, 0.72, 0.60).darkened(rng.randf_range(0.0, 0.18))
		facades.add_child(seg)
		lx += seg.size.x - 18.0

	for ax in range(200, int(STAGE_WIDTH), 480):
		var arch := ColorRect.new()
		arch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		arch.position = Vector2(ax, 120)
		arch.size = Vector2(52, 100)
		arch.color = Color(0.42, 0.36, 0.30)
		facades.add_child(arch)

# ─── Stage ────────────────────────────────────────────────────────────────────
func _build_stage() -> void:
	_stage = Node2D.new()
	_stage.y_sort_enabled = true
	add_child(_stage)

	# Floor debris for visual interest
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for _i in 50:
		var debris := ColorRect.new()
		debris.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var w := rng.randf_range(10, 50)
		debris.size = Vector2(w, rng.randf_range(3, 7))
		debris.position = Vector2(rng.randf_range(0, STAGE_WIDTH), rng.randf_range(370, 475))
		debris.color = Color(0.20, 0.16, 0.12).lightened(rng.randf_range(0.0, 0.2))
		debris.z_index = -5
		_stage.add_child(debris)

	# Road dashes (every 200px)
	for i in range(0, int(STAGE_WIDTH), 200):
		var dash := ColorRect.new()
		dash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dash.size = Vector2(40, 4)
		dash.position = Vector2(i, 440)
		dash.color = Color(0.55, 0.48, 0.30)
		dash.z_index = -4
		_stage.add_child(dash)

	_build_market_props(rng)

# ─── Old City market lane (stalls, bins, distant crowd) ─────────────────────
func _build_market_props(rng: RandomNumberGenerator) -> void:
	for sx in range(220, int(STAGE_WIDTH), 460):
		var stall := Node2D.new()
		stall.position = Vector2(sx, 358)
		stall.z_index = -2

		var table := ColorRect.new()
		table.mouse_filter = Control.MOUSE_FILTER_IGNORE
		table.size = Vector2(76, 12)
		table.position = Vector2(-38, 0)
		table.color = Color(0.42, 0.28, 0.16)
		stall.add_child(table)

		for px: int in [-34, 30]:
			var post := ColorRect.new()
			post.mouse_filter = Control.MOUSE_FILTER_IGNORE
			post.position = Vector2(px, -48)
			post.size = Vector2(6, 50)
			post.color = Color(0.34, 0.22, 0.12)
			stall.add_child(post)

		var awning := Polygon2D.new()
		awning.polygon = PackedVector2Array([
			Vector2(-52, -52), Vector2(52, -52),
			Vector2(44, -14), Vector2(-44, -14),
		])
		awning.color = Color(0.72, 0.22, 0.14)
		stall.add_child(awning)

		var stripe := ColorRect.new()
		stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stripe.position = Vector2(-40, -44)
		stripe.size = Vector2(80, 3)
		stripe.color = Color(0.92, 0.88, 0.70, 0.35)
		stall.add_child(stripe)

		_stage.add_child(stall)

	for _j in 14:
		var bx: float = rng.randf_range(100, STAGE_WIDTH - 100)
		var bin := ColorRect.new()
		bin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bin.position = Vector2(bx, 384)
		bin.size = Vector2(24, 30)
		bin.color = Color(0.20, 0.22, 0.24)
		bin.z_index = -3
		_stage.add_child(bin)
		var lid := ColorRect.new()
		lid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lid.position = Vector2(bx - 3, 378)
		lid.size = Vector2(30, 8)
		lid.color = Color(0.30, 0.32, 0.34)
		lid.z_index = -3
		_stage.add_child(lid)

	for _k in 26:
		var cx: float = rng.randf_range(40, STAGE_WIDTH - 40)
		var cy: float = rng.randf_range(300, 332)
		var sil := ColorRect.new()
		sil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sil.position = Vector2(cx, cy)
		sil.size = Vector2(8 + rng.randi_range(0, 8), 20 + rng.randi_range(0, 22))
		sil.color = Color(0.10, 0.09, 0.08, 0.5)
		sil.z_index = -4
		_stage.add_child(sil)

# ─── Player ───────────────────────────────────────────────────────────────────
func _build_player() -> void:
	_player = CharacterBody2D.new()
	_player.set_script(PLAYER_SCRIPT)
	_player.position = Vector2(200, FLOOR_Y)
	_player.z_index = 0

	# Connect signals BEFORE adding to tree so initial emissions in _ready() reach the HUD
	_player.health_changed.connect(_on_health_changed)
	_player.lives_changed.connect(_on_lives_changed)
	_player.score_changed.connect(_on_score_changed)
	_player.player_died.connect(_on_player_died)

	_stage.add_child(_player)
	if is_instance_valid(_hud) and _hud.has_method("set_player"):
		_hud.set_player(_player)

# ─── Camera ───────────────────────────────────────────────────────────────────
func _build_camera() -> void:
	_camera = Camera2D.new()
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = CAM_LERP
	_camera.limit_left = 0
	_camera.limit_right = int(STAGE_WIDTH)
	_camera.limit_top = 0
	_camera.limit_bottom = 540
	_camera.offset = Vector2(80, -30)  # Look slightly ahead
	_player.add_child(_camera)

# ─── HUD ─────────────────────────────────────────────────────────────────────
func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.set_script(HUD_SCRIPT)
	_hud.layer = 10
	add_child(_hud)

# ─── Touch controls ───────────────────────────────────────────────────────────
func _build_touch() -> void:
	_touch = CanvasLayer.new()
	_touch.set_script(TOUCH_SCRIPT)
	_touch.layer = 11
	add_child(_touch)
	_touch.call_deferred("set_player", _player)

# ─── Process ──────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if _game_over:
		return
	_time += delta

	# Parallax backgrounds
	if is_instance_valid(_player):
		var cam_x := _player.global_position.x
		for layer in _bg_layers:
			var p: float = layer.get_meta("parallax", 0.3)
			layer.position.x = cam_x * (1.0 - p) - cam_x

# ─── Waves & enemies ─────────────────────────────────────────────────────────
func _run_interwave_then_spawn() -> void:
	await get_tree().create_timer(1.05).timeout
	_next_wave_scheduled = false
	if _game_over or _spawning_wave:
		return
	if _wave_index < _waves.size() and is_instance_valid(_hud) and is_instance_valid(_player):
		_player.input_locked = true
		await _hud.run_interwave_shop(_player)
		_player.input_locked = false
	_spawn_next_wave()

func _spawn_next_wave() -> void:
	if _spawning_wave:
		return
	if _wave_index >= _waves.size():
		if _boss_card_pending and is_instance_valid(_hud):
			_boss_card_pending = false
			if is_instance_valid(_player):
				_player.input_locked = true
			await AdsManager.show_interstitial("after_boss", 5.0, 5.0)
			var _boss_card: Dictionary = GameData.get_next_history_card()
			await _hud.show_history_card(_boss_card)
			GameData.unlock_history_card(str(_boss_card.get("id", "")))
			if is_instance_valid(_player):
				_player.input_locked = false
		_on_stage_complete()
		return

	_spawning_wave = true
	var wave: Dictionary = _waves[_wave_index]
	_wave_index += 1
	_enemies_alive += wave["types"].size()

	var cam_x: float = _player.global_position.x if is_instance_valid(_player) else 480.0
	var rng := RandomNumberGenerator.new()
	rng.seed = _wave_index * 17

	if is_instance_valid(_hud):
		var boss_wave := false
		for t in wave["types"]:
			if str(t) == "old_city_boss":
				boss_wave = true
				break
		if boss_wave:
			_hud.show_wave_message("בוס!", 1.6)
		else:
			_hud.show_wave_message("גל %d" % _wave_index, 1.15)

	var n_enemies: int = wave["types"].size()
	var step: float = 0.28 + (0.22 if n_enemies > 5 else 0.38)

	for i: int in range(wave["types"].size()):
		var etype: String = wave["types"][i]
		await get_tree().create_timer(0.25 + i * step).timeout
		if _game_over:
			_spawning_wave = false
			return
		var from_right: bool = (i % 2 == 0)
		var spawn_x: float
		if from_right:
			spawn_x = min(cam_x + SPAWN_X_OFFSET + i * 28.0, STAGE_WIDTH - 40.0)
		else:
			spawn_x = max(cam_x - SPAWN_X_OFFSET - i * 22.0, 40.0)
		_spawn_enemy(etype, spawn_x, FLOOR_Y + rng.randf_range(-38, 38))

	_spawning_wave = false

func _spawn_enemy(etype: String, x: float, y: float) -> void:
	var e := CharacterBody2D.new()
	e.set_script(ENEMY_SCRIPT)
	e.set("enemy_type", etype)
	e.position = Vector2(x, clamp(y, 375.0, 460.0))
	e.z_index = 0
	# Connect before adding to tree
	e.enemy_died.connect(_on_enemy_died)
	e.loot_pickup_requested.connect(_on_loot_pickup_requested)
	_stage.add_child(e)
	if e.has_method("set_target"):
		e.set_target(_player)

# ─── Signal handlers ──────────────────────────────────────────────────────────
func _on_loot_pickup_requested(kind: String, pos: Vector2, value: int) -> void:
	_spawn_pickup(kind, pos, value)


func _spawn_pickup(kind: String, pos: Vector2, value: int) -> void:
	if not is_instance_valid(_stage) or not is_instance_valid(_player):
		return
	var p := Area2D.new()
	p.set_script(PICKUP_SCRIPT)
	p.setup(kind, value, _player)
	_stage.add_child(p)
	p.global_position = pos


func _on_enemy_died(score_val: int, pos: Vector2, is_final_alley_boss: bool = false) -> void:
	if is_final_alley_boss:
		_boss_card_pending = true
	_enemies_alive = max(0, _enemies_alive - 1)
	if is_instance_valid(_player):
		_player.register_kill()
		_player.add_score(score_val)
	_spawn_score_popup(score_val, pos)

	if _enemies_alive == 0 and not _game_over and not _next_wave_scheduled:
		_next_wave_scheduled = true
		_run_interwave_then_spawn()

func _spawn_score_popup(value: int, pos: Vector2) -> void:
	var lbl := Label.new()
	lbl.text = "+%d" % value
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.78, 0.20))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.position = pos - Vector2(20, 40)
	lbl.z_index = 5
	_stage.add_child(lbl)

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "position:y", lbl.position.y - 30, 0.8)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.8)
	tween.chain().tween_callback(lbl.queue_free)

func _on_health_changed(hp: int, max_hp: int) -> void:
	if is_instance_valid(_hud):
		_hud.update_health(hp, max_hp)

func _on_lives_changed(lives: int) -> void:
	if is_instance_valid(_hud):
		_hud.update_lives(lives)

func _on_score_changed(score: int) -> void:
	if is_instance_valid(_hud):
		_hud.update_score(score)
	GameData.final_score = score
	if score > GameData.high_score:
		GameData.high_score = score
		GameData.save_persistent()

func _on_player_died() -> void:
	GameData.stage_won = false
	_game_over = true
	if is_instance_valid(_hud):
		_hud.show_wave_message("נפלת בקרב...", 2.5)
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://scenes/GameOver.tscn")

func _on_stage_complete() -> void:
	GameData.stage_won = true
	_game_over = true
	if is_instance_valid(_hud):
		_hud.show_wave_message("ניצחון! ✡", 2.5)
	await AdsManager.show_interstitial("between_stages", 5.0, 5.0)
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://scenes/GameOver.tscn")

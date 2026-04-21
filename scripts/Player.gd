extends CharacterBody2D

# ─── Signals ───────────────────────────────────────────────────────────────
signal health_changed(hp: int, max_hp: int)
signal lives_changed(lives: int)
signal score_changed(score: int)
signal player_died()

# ─── Floor constraints (beat 'em up flat plane) ────────────────────────────
const FLOOR_Y_MIN := 370.0
const FLOOR_Y_MAX := 460.0

# ─── Stats (loaded from GameData) ─────────────────────────────────────────
var char_data: Dictionary = {}
var max_health := 100
var health    := 100
var lives     := 3
var score     := 0
## Enemies defeated this stage — scales damage up over time (weak early, strong late).
var kills := 0

# ─── Combat ────────────────────────────────────────────────────────────────
var is_attacking       := false
var attack_cooldown    := 0.0
var attack_active_time := 0.0         # active hitbox window
var current_attack_type:= ""
var current_attack_dmg := 0
var _hit_enemies_this_swing: Array = []
var invincible         := false
var invincible_timer   := 0.0
var facing_right       := true
## When true (e.g. pre-fight countdown), movement and attacks are ignored.
var input_locked := false

# ─── Animation state ───────────────────────────────────────────────────────
var _time: float = 0.0
var _walk_phase: float = 0.0
var _is_walking: bool = false

# ─── Visual nodes ──────────────────────────────────────────────────────────
var _body: Node2D
var _torso: ColorRect
var _head: ColorRect
var _hat: ColorRect
var _arm_l: ColorRect
var _arm_r: ColorRect
var _leg_l: ColorRect
var _leg_r: ColorRect
var _swing: Polygon2D   # attack swing arc
var _attack_area: Area2D
var _attack_shape: CollisionShape2D

func _ready() -> void:
	char_data  = GameData.get_char_data().duplicate()
	_apply_ideology_multipliers()
	max_health = char_data["max_health"]
	health     = max_health
	add_to_group("player")
	_build_body()
	_build_attack_area()
	_build_collision()
	# Emit once so HUD updates immediately
	health_changed.emit(health, max_health)

# level 3 = baseline x1.0 | level 5 = x1.30 | level 1 = x0.70
func _ideology_mult(level: int) -> float:
	return 0.70 + (level - 1) * 0.15

func _apply_ideology_multipliers() -> void:
	var p: float = _ideology_mult(int(char_data["ideology_power"]))
	var s: float = _ideology_mult(int(char_data["ideology_speed"]))
	var t: float = _ideology_mult(int(char_data["ideology_tactics"]))
	char_data["max_health"]     = int(char_data["max_health"]     * p)
	char_data["punch_damage"]   = int(char_data["punch_damage"]   * p)
	char_data["kick_damage"]    = int(char_data["kick_damage"]     * p)
	char_data["special_damage"] = int(char_data["special_damage"] * t)
	char_data["speed"]         *= s
	char_data["attack_rate"]   *= s
	# Early stage: intentionally fragile / low damage; grows with kills + economy.
	const RUN_WEAK_DMG := 0.58
	const RUN_WEAK_HP := 0.76
	char_data["punch_damage"]   = max(4, int(char_data["punch_damage"]   * RUN_WEAK_DMG))
	char_data["kick_damage"]    = max(5, int(char_data["kick_damage"]    * RUN_WEAK_DMG))
	char_data["special_damage"] = max(8, int(char_data["special_damage"] * RUN_WEAK_DMG))
	char_data["max_health"]     = max(40, int(char_data["max_health"]     * RUN_WEAK_HP))
	lives_changed.emit(lives)
	score_changed.emit(score)


func _run_damage_multiplier() -> float:
	var kill_m: float = 0.52 + minf(0.72, kills * 0.024)
	var w: float = 1.0 + float(GameData.run_weapon_tier) * 0.12
	var sk: float = 1.0 + float(GameData.run_skill_rank) * 0.065
	return kill_m * w * sk


func register_kill() -> void:
	kills += 1


func receive_pickup(kind: String, _value: int) -> void:
	match kind:
		"coin":
			GameData.add_run_coins(_value)
		"stone":
			GameData.add_run_stone_pickup()


func try_shop_buy_heart() -> bool:
	if not GameData.try_buy_extra_heart():
		return false
	lives += 1
	lives_changed.emit(lives)
	return true


func try_shop_buy_weapon() -> bool:
	return GameData.try_buy_weapon_upgrade()

func _build_body() -> void:
	_body = Node2D.new()
	add_child(_body)

	var skin:   Color = char_data["color_skin"]
	var suit:   Color = char_data["color_body"]
	var accent: Color = char_data["color_accent"]
	var dark_s: Color = suit.darkened(0.28)
	var boot_c    := Color(0.16, 0.13, 0.09)
	var char_type : String = char_data.get("char_type", "palmach")

	# ── Shadow
	var shadow := Polygon2D.new()
	shadow.polygon  = PackedVector2Array([Vector2(-22,0),Vector2(22,0),Vector2(16,9),Vector2(-16,9)])
	shadow.color    = Color(0, 0, 0, 0.35)
	shadow.position = Vector2(0, 4)
	_body.add_child(shadow)

	# ── Boots (drawn before legs so legs overlap at top)
	for bx: int in [-9, 3]:
		var boot := Polygon2D.new()
		boot.polygon = PackedVector2Array([
			Vector2(bx,38),   Vector2(bx+11,38),
			Vector2(bx+12,45),Vector2(bx-1,45)
		])
		boot.color = boot_c
		_body.add_child(boot)
		var shine := ColorRect.new()
		shine.size     = Vector2(3, 5)
		shine.position = Vector2(bx + 2, 39)
		shine.color    = Color(boot_c.r+0.10, boot_c.g+0.08, boot_c.b+0.06)
		_body.add_child(shine)

	# ── Legs (kept as ColorRect – used by _animate)
	_leg_l = ColorRect.new()
	_leg_l.size     = Vector2(10, 22)
	_leg_l.position = Vector2(-8, 16)
	_leg_l.color    = dark_s
	_body.add_child(_leg_l)

	_leg_r = ColorRect.new()
	_leg_r.size     = Vector2(10, 22)
	_leg_r.position = Vector2(4, 16)
	_leg_r.color    = dark_s
	_body.add_child(_leg_r)

	# ── Torso
	_torso = ColorRect.new()
	_torso.size     = Vector2(28, 26)
	_torso.position = Vector2(-14, -10)
	_torso.color    = suit
	_body.add_child(_torso)

	# ── Chest pockets
	for px: int in [-10, 4]:
		var pocket := ColorRect.new()
		pocket.size     = Vector2(8, 6)
		pocket.position = Vector2(px, -7)
		pocket.color    = dark_s
		_body.add_child(pocket)

	# ── Belt with buckle
	var belt := Polygon2D.new()
	belt.polygon = PackedVector2Array([
		Vector2(-14,10), Vector2(14,10),
		Vector2(14,14),  Vector2(-14,14)
	])
	belt.color = accent.darkened(0.45)
	_body.add_child(belt)
	var buckle := ColorRect.new()
	buckle.size     = Vector2(7, 4)
	buckle.position = Vector2(-3, 10)
	buckle.color    = accent
	_body.add_child(buckle)

	# ── Arms (kept as ColorRect – used by _animate)
	_arm_l = ColorRect.new()
	_arm_l.size     = Vector2(8, 20)
	_arm_l.position = Vector2(-22, -8)
	_arm_l.color    = suit
	_body.add_child(_arm_l)

	_arm_r = ColorRect.new()
	_arm_r.size     = Vector2(8, 20)
	_arm_r.position = Vector2(14, -8)
	_arm_r.color    = suit
	_body.add_child(_arm_r)

	# ── Hands (skin at end of arms)
	for hx: int in [-22, 14]:
		var hand := ColorRect.new()
		hand.size     = Vector2(8, 7)
		hand.position = Vector2(hx, 10)
		hand.color    = skin
		_body.add_child(hand)

	# ── Neck
	var neck := ColorRect.new()
	neck.size     = Vector2(8, 5)
	neck.position = Vector2(-4, -13)
	neck.color    = skin
	_body.add_child(neck)

	# ── Head base (ColorRect, kept for reference)
	_head = ColorRect.new()
	_head.size     = Vector2(22, 22)
	_head.position = Vector2(-11, -32)
	_head.color    = skin
	_body.add_child(_head)

	# ── Head rounded overlay
	var head_ov := Polygon2D.new()
	head_ov.polygon = PackedVector2Array([
		Vector2(-10,-34), Vector2(0,-38), Vector2(10,-34),
		Vector2(12,-28),  Vector2(11,-18),
		Vector2(0,-16),   Vector2(-11,-18), Vector2(-12,-28)
	])
	head_ov.color = skin
	_body.add_child(head_ov)

	# ── Ears
	for side: int in [-1, 1]:
		var ear := ColorRect.new()
		ear.size     = Vector2(3, 6)
		ear.position = Vector2(side * 11 + (0 if side > 0 else -3), -29)
		ear.color    = skin.darkened(0.10)
		_body.add_child(ear)

	# ── Beard/stubble shadow
	var stub := Polygon2D.new()
	stub.polygon = PackedVector2Array([
		Vector2(-9,-22), Vector2(9,-22),
		Vector2(10,-16), Vector2(-10,-16)
	])
	stub.color = Color(skin.r*0.58, skin.g*0.48, skin.b*0.38, 0.58)
	_body.add_child(stub)

	# ── Eyes
	for ex: int in [-6, 3]:
		var white := ColorRect.new()
		white.size     = Vector2(4, 3)
		white.position = Vector2(ex, -28)
		white.color    = Color(0.92, 0.92, 0.90)
		_body.add_child(white)
		var pupil := ColorRect.new()
		pupil.size     = Vector2(2, 2)
		pupil.position = Vector2(ex + 1, -28)
		pupil.color    = Color(0.14, 0.10, 0.06)
		_body.add_child(pupil)

	# ── Eyebrows
	for bx: int in [-7, 2]:
		var brow := ColorRect.new()
		brow.size     = Vector2(5, 2)
		brow.position = Vector2(bx, -31)
		brow.color    = Color(skin.r*0.44, skin.g*0.35, skin.b*0.25)
		_body.add_child(brow)

	# ── Military cap: brim (ColorRect kept as _hat for reference)
	_hat = ColorRect.new()
	_hat.size     = Vector2(30, 5)
	_hat.position = Vector2(-15, -37)
	_hat.color    = suit.darkened(0.10)
	_body.add_child(_hat)

	# ── Cap crown
	var cap := Polygon2D.new()
	cap.polygon = PackedVector2Array([
		Vector2(-12,-39), Vector2(12,-39),
		Vector2(10,-48),  Vector2(-10,-48)
	])
	cap.color = suit
	_body.add_child(cap)

	# ── Cap badge (מגן דוד / insignia)
	var badge := Polygon2D.new()
	badge.polygon = PackedVector2Array([
		Vector2(-4,-47), Vector2(0,-51), Vector2(4,-47),
		Vector2(4,-44),  Vector2(0,-40), Vector2(-4,-44)
	])
	badge.color = accent
	_body.add_child(badge)

	# ── Shoulder patch
	var patch := ColorRect.new()
	patch.size     = Vector2(6, 4)
	patch.position = Vector2(-20, -5)
	patch.color    = accent.darkened(0.20)
	_body.add_child(patch)

	# ── Star of David on chest
	var star := Polygon2D.new()
	star.polygon = PackedVector2Array([
		Vector2(0,-6),  Vector2(2,-2), Vector2(6,-2),
		Vector2(3,1),   Vector2(4,5),  Vector2(0,3),
		Vector2(-4,5),  Vector2(-3,1), Vector2(-6,-2),
		Vector2(-2,-2)
	])
	star.color    = accent
	star.position = Vector2(0, 0)
	_body.add_child(star)

	# ── Character-specific accessories
	match char_type:
		"lehi":
			# שני אקדחים (כמו בתמונת הייחוס)
			for hx: int in [-22, 14]:
				var grip := ColorRect.new()
				grip.size     = Vector2(5, 9)
				grip.position = Vector2(hx + 1, 17)
				grip.color    = Color(0.22, 0.18, 0.14)
				_body.add_child(grip)
				var barrel := ColorRect.new()
				barrel.size     = Vector2(9, 3)
				barrel.position = Vector2(hx - 2 if hx > 0 else hx, 18)
				barrel.color    = Color(0.35, 0.32, 0.28)
				_body.add_child(barrel)
		"palmach":
			# רצועת רובה (Sten gun sling)
			var sling := ColorRect.new()
			sling.size     = Vector2(3, 28)
			sling.position = Vector2(-1, -9)
			sling.color    = Color(0.38, 0.30, 0.14)
			sling.rotation = 0.22
			_body.add_child(sling)
		"haganah":
			# חגורת תחמושת – bandolier
			var band := Polygon2D.new()
			band.polygon = PackedVector2Array([
				Vector2(-14,-8), Vector2(14,-8),
				Vector2(14,-5),  Vector2(-14,-5)
			])
			band.color = Color(0.40, 0.32, 0.14)
			_body.add_child(band)
			for cx: int in range(-12, 13, 4):
				var cart := ColorRect.new()
				cart.size     = Vector2(2, 4)
				cart.position = Vector2(cx, -9)
				cart.color    = Color(0.72, 0.62, 0.22)
				_body.add_child(cart)
		"irgun":
			# כומתה רחבת שוליים
			var xbrim := Polygon2D.new()
			xbrim.polygon = PackedVector2Array([
				Vector2(-17,-37), Vector2(19,-37),
				Vector2(16,-39),  Vector2(-14,-39)
			])
			xbrim.color = suit.lightened(0.08)
			_body.add_child(xbrim)

	# ── Swing arc (hidden by default)
	_swing = Polygon2D.new()
	_swing.polygon = PackedVector2Array([
		Vector2(10,-18), Vector2(55,-24), Vector2(65,0),
		Vector2(55,22),  Vector2(10,14)
	])
	_swing.color = Color(1.0, 0.95, 0.4, 0.0)
	_body.add_child(_swing)

func _build_attack_area() -> void:
	_attack_area = Area2D.new()
	_attack_area.name           = "AttackArea"
	_attack_area.collision_layer = 0
	_attack_area.collision_mask  = 2   # layer 2 = enemies
	_attack_area.monitoring      = true
	_attack_area.monitorable     = false

	_attack_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(70, 40)
	_attack_shape.shape    = rect
	_attack_shape.disabled = true
	_attack_area.add_child(_attack_shape)
	add_child(_attack_area)

func _build_collision() -> void:
	var col := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius = 14.0
	cap.height = 44.0
	col.shape    = cap
	col.position = Vector2(0, -18)
	add_child(col)
	collision_layer = 1
	collision_mask  = 2

# ─── Per-frame ─────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	_time += delta

	if attack_cooldown > 0.0:
		attack_cooldown -= delta
		if attack_cooldown <= 0.0:
			is_attacking = false
			_attack_shape.disabled = true

	# Active hitbox window
	if attack_active_time > 0.0:
		attack_active_time -= delta
		# Resolve hits on enemies currently inside the area
		for body in _attack_area.get_overlapping_bodies():
			if body.is_in_group("enemies") and not _hit_enemies_this_swing.has(body):
				if body.has_method("take_damage"):
					body.take_damage(current_attack_dmg, global_position)
				_hit_enemies_this_swing.append(body)
		if attack_active_time <= 0.0:
			_attack_shape.disabled = true
			_swing.color = Color(1.0, 0.95, 0.4, 0.0)

	if invincible_timer > 0.0:
		invincible_timer -= delta
		# Flicker while invincible
		_body.modulate.a = 0.5 if int(invincible_timer * 12.0) % 2 == 0 else 1.0
		if invincible_timer <= 0.0:
			invincible = false
			_body.modulate = Color.WHITE

	if not is_attacking and not input_locked:
		_handle_movement()
		_handle_attack_input()
	elif input_locked:
		velocity = Vector2.ZERO
		_is_walking = false

	move_and_slide()
	# Clamp to floor band
	position.y = clamp(position.y, FLOOR_Y_MIN, FLOOR_Y_MAX)

	# Animate
	_animate(delta)

func _animate(delta: float) -> void:
	if is_attacking:
		# Punch forward pose
		_arm_r.position.x = 14 + 6
		_arm_l.position.x = -22
		return
	# Reset arms
	_arm_r.position.x = 14
	_arm_l.position.x = -22

	if _is_walking:
		_walk_phase += delta * 10.0
		var bob := sin(_walk_phase) * 2.0
		_body.position.y = bob
		_leg_l.position.y = 16 + sin(_walk_phase) * 2.0
		_leg_r.position.y = 16 - sin(_walk_phase) * 2.0
	else:
		_body.position.y = lerp(_body.position.y, 0.0, 0.2)
		_leg_l.position.y = 16
		_leg_r.position.y = 16

func _handle_movement() -> void:
	var spd: float = char_data["speed"]
	var dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up",   "move_down")
	)
	if dir.length_squared() > 0.01:
		velocity = dir.normalized() * spd
		_is_walking = true
		if dir.x > 0.1:
			facing_right = true
			_body.scale.x = 1.0
		elif dir.x < -0.1:
			facing_right = false
			_body.scale.x = -1.0
	else:
		velocity = Vector2.ZERO
		_is_walking = false

func _handle_attack_input() -> void:
	if attack_cooldown > 0.0:
		return
	if Input.is_action_just_pressed("punch"):
		_do_attack("punch", char_data["punch_damage"], 0.30, 65.0, 36.0)
	elif Input.is_action_just_pressed("kick"):
		_do_attack("kick", char_data["kick_damage"], 0.45, 85.0, 44.0)
	elif Input.is_action_just_pressed("special"):
		_do_attack("special", char_data["special_damage"], 1.10, 120.0, 70.0)

func _do_attack(type: String, damage: int, cd: float, range_w: float, range_h: float) -> void:
	is_attacking         = true
	attack_cooldown      = cd / char_data["attack_rate"]
	attack_active_time   = 0.18
	current_attack_type  = type
	current_attack_dmg   = max(1, int(damage * _run_damage_multiplier()))
	velocity             = Vector2.ZERO
	_hit_enemies_this_swing.clear()

	# Configure hitbox
	var rect := _attack_shape.shape as RectangleShape2D
	rect.size = Vector2(range_w, range_h)
	_attack_shape.position.x = (range_w * 0.5 + 14.0) * (1.0 if facing_right else -1.0)
	_attack_shape.position.y = -10.0
	_attack_shape.disabled   = false

	# Swing arc visual color by type
	var arc_color: Color
	match type:
		"punch":   arc_color = Color(1.0, 0.95, 0.5, 0.75)
		"kick":    arc_color = Color(0.6, 0.8, 1.0, 0.75)
		"special": arc_color = Color(1.0, 0.5, 0.9, 0.85)
		_:         arc_color = Color(1.0, 1.0, 1.0, 0.7)
	_swing.color = arc_color

	# Scale swing size
	var scl := 1.0 if type == "punch" else (1.25 if type == "kick" else 1.6)
	_swing.scale = Vector2(scl, scl)

	# Color flash
	_body.modulate = Color(1.4, 1.2, 0.6)
	var tw: Tween = create_tween()
	tw.tween_property(_body, "modulate", Color.WHITE, 0.10)

	# For special: screen pop — brief camera shake via offset (if camera exists)
	if type == "special":
		_special_flash()

func _special_flash() -> void:
	var cam := _get_camera()
	if cam == null:
		return
	var orig := cam.offset
	var tw: Tween = create_tween()
	for i in 5:
		var off := Vector2(randf_range(-8, 8), randf_range(-6, 6))
		tw.tween_property(cam, "offset", orig + off, 0.04)
	tw.tween_property(cam, "offset", orig, 0.08)

func _get_camera() -> Camera2D:
	for c in get_children():
		if c is Camera2D:
			return c
	return null

# ─── Damage ────────────────────────────────────────────────────────────────
func take_damage(amount: int) -> void:
	if invincible:
		return
	health            -= amount
	health             = max(0, health)
	invincible         = true
	invincible_timer   = 1.2
	health_changed.emit(health, max_health)

	# Red flash + knockback pulse
	_body.modulate = Color(2.0, 0.3, 0.3)
	var tw: Tween = create_tween()
	tw.tween_property(_body, "modulate", Color.WHITE, 0.18)

	# Small camera shake
	var cam := _get_camera()
	if cam:
		var orig := cam.offset
		var tw2: Tween = create_tween()
		for i in 3:
			tw2.tween_property(cam, "offset", orig + Vector2(randf_range(-5, 5), randf_range(-4, 4)), 0.04)
		tw2.tween_property(cam, "offset", orig, 0.08)

	if health <= 0:
		_on_died()

func _on_died() -> void:
	lives -= 1
	lives_changed.emit(lives)
	GameData.run_lives_lost += 1

	# Ad trigger: every 2 lives lost.
	if GameData.run_lives_lost > 0 and GameData.run_lives_lost % 2 == 0:
		await AdsManager.show_interstitial("every_2_lives_lost", 5.0, 5.0)

	if lives <= 0:
		set_physics_process(false)
		velocity = Vector2.ZERO

		# Optional continue (one per run): watch a short ad.
		if not GameData.run_continue_used:
			var wants_continue := await _prompt_continue_ad()
			if wants_continue:
				GameData.run_continue_used = true
				await AdsManager.show_interstitial("continue_on_game_over", 5.0, 5.0)
				lives = 1
				health = max_health
				lives_changed.emit(lives)
				health_changed.emit(health, max_health)
				set_physics_process(true)
				return

		player_died.emit()
		return

	health = max_health
	health_changed.emit(health, max_health)

func grant_bonus_life(amount: int = 1) -> void:
	if amount <= 0:
		return
	lives += amount
	lives_changed.emit(lives)

func _prompt_continue_ad() -> bool:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.z_index = 9998
	get_tree().root.add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.65)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	var panel := Panel.new()
	panel.size = Vector2(640, 260)
	panel.position = Vector2(160, 140)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.05, 0.06, 0.10, 0.97)
	ps.border_color = Color(0.95, 0.78, 0.20, 0.85)
	ps.set_border_width_all(2)
	ps.corner_radius_top_left = 14
	ps.corner_radius_top_right = 14
	ps.corner_radius_bottom_left = 14
	ps.corner_radius_bottom_right = 14
	panel.add_theme_stylebox_override("panel", ps)
	root.add_child(panel)

	var title := Label.new()
	title.text = "נגמרו החיים"
	title.position = Vector2(0, 16)
	title.size = Vector2(640, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.20))
	panel.add_child(title)

	var msg := Label.new()
	msg.text = "רוצה להמשיך? צפה בפרסומת קצרה (5 שניות) ותקבל עוד חיים אחד."
	msg.position = Vector2(40, 64)
	msg.size = Vector2(560, 60)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.add_theme_font_size_override("font_size", 16)
	msg.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95, 0.9))
	panel.add_child(msg)

	var btn_yes := Button.new()
	btn_yes.text = "כן, רוצה להמשיך"
	btn_yes.position = Vector2(70, 150)
	btn_yes.size = Vector2(240, 52)
	_style_dialog_button(btn_yes, true)
	panel.add_child(btn_yes)

	var btn_no := Button.new()
	btn_no.text = "לא תודה"
	btn_no.position = Vector2(330, 150)
	btn_no.size = Vector2(240, 52)
	_style_dialog_button(btn_no, false)
	panel.add_child(btn_no)

	var chose_yes := [false]
	btn_yes.pressed.connect(func():
		chose_yes[0] = true
		root.queue_free()
	)
	btn_no.pressed.connect(root.queue_free)

	await root.tree_exited

	return chose_yes[0]

func _style_dialog_button(btn: Button, primary: bool) -> void:
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.14, 0.16, 0.32, 0.95) if primary else Color(0.12, 0.12, 0.14, 0.95)
	s.border_color = Color(0.95, 0.78, 0.20, 0.80) if primary else Color(0.95, 0.95, 0.95, 0.35)
	s.set_border_width_all(2)
	s.corner_radius_top_left = 10
	s.corner_radius_top_right = 10
	s.corner_radius_bottom_left = 10
	s.corner_radius_bottom_right = 10
	btn.add_theme_stylebox_override("normal", s)
	var sh := s.duplicate() as StyleBoxFlat
	sh.bg_color = s.bg_color.lightened(0.15)
	sh.border_color = Color(0.95, 0.78, 0.20, 0.95) if primary else Color(0.95, 0.78, 0.20, 0.65)
	btn.add_theme_stylebox_override("hover", sh)

# ─── Called externally (touch controls) ────────────────────────────────────
func virtual_attack(type: String) -> void:
	if attack_cooldown > 0.0 or is_attacking:
		return
	match type:
		"punch":
			_do_attack("punch", char_data["punch_damage"], 0.30, 65.0, 36.0)
		"kick":
			_do_attack("kick", char_data["kick_damage"], 0.45, 85.0, 44.0)
		"special":
			_do_attack("special", char_data["special_damage"], 1.10, 120.0, 70.0)

func add_score(pts: int) -> void:
	score += pts
	score_changed.emit(score)

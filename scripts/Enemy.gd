extends CharacterBody2D

# ─── Enemy types ────────────────────────────────────────────────────────────
# type: "british_soldier" | "british_officer" | "british_commander"
#       "local_fighter"   | "arab_warlord"   | "old_city_boss"

@export var enemy_type: String = "british_soldier"

## Third flag: final “Old City” boss — awards the history card on stage clear.
signal enemy_died(score_value: int, pos: Vector2, is_final_alley_boss: bool)
signal loot_pickup_requested(kind: String, pos: Vector2, value: int)

const FLOOR_Y_MIN := 370.0
const FLOOR_Y_MAX := 460.0

# ─── Type presets ───────────────────────────────────────────────────────────
const TYPES := {
	"british_soldier": {
		"color_body":   Color(0.60, 0.53, 0.35),  # khaki service dress
		"color_skin":   Color(0.88, 0.75, 0.60),
		"color_accent": Color(0.55, 0.48, 0.28),  # cap/belt leather
		"max_health": 40,
		"speed": 80.0,
		"damage": 8,
		"attack_range": 50.0,
		"attack_cd": 1.2,
		"score_value": 100,
		"scale": 1.0,
		"label": "חייל בריטי",
		"is_boss": false,
	},
	"british_officer": {
		"color_body":   Color(0.42, 0.46, 0.28),  # darker olive dress
		"color_skin":   Color(0.88, 0.75, 0.60),
		"color_accent": Color(0.78, 0.68, 0.32),  # brass/gold
		"max_health": 80,
		"speed": 65.0,
		"damage": 14,
		"attack_range": 55.0,
		"attack_cd": 1.5,
		"score_value": 250,
		"scale": 1.2,
		"label": "קצין בריטי",
		"is_boss": false,
	},
	"british_commander": {  # BOSS
		"color_body":   Color(0.28, 0.32, 0.18),  # deep olive
		"color_skin":   Color(0.88, 0.75, 0.60),
		"color_accent": Color(0.85, 0.75, 0.25),  # gold
		"max_health": 240,
		"speed": 52.0,
		"damage": 22,
		"attack_range": 65.0,
		"attack_cd": 1.8,
		"score_value": 900,
		"scale": 1.45,
		"label": "מפקד בריטי",
		"is_boss": true,
	},
	"local_fighter": {
		"color_body":   Color(0.84, 0.78, 0.58),  # cream robe
		"color_skin":   Color(0.62, 0.44, 0.28),  # olive/dark skin
		"color_accent": Color(0.18, 0.14, 0.10),  # dark belt
		"max_health": 30,
		"speed": 110.0,
		"damage": 6,
		"attack_range": 42.0,
		"attack_cd": 0.9,
		"score_value": 75,
		"scale": 0.9,
		"label": "לוחם ערבי",
		"is_boss": false,
	},
	"arab_warlord": {  # BOSS
		"color_body":   Color(0.20, 0.16, 0.12),  # dark robes
		"color_skin":   Color(0.58, 0.40, 0.24),
		"color_accent": Color(0.68, 0.12, 0.08),  # dark red
		"max_health": 200,
		"speed": 68.0,
		"damage": 18,
		"attack_range": 58.0,
		"attack_cd": 1.0,
		"score_value": 700,
		"scale": 1.35,
		"label": "ראש הכנופייה",
		"is_boss": true,
	},
	# Final alley boss — pressure roughly like clearing ~wave 5 (several regulars).
	"old_city_boss": {
		"color_body":   Color(0.26, 0.22, 0.18),
		"color_skin":   Color(0.72, 0.58, 0.44),
		"color_accent": Color(0.62, 0.48, 0.12),
		"max_health":   168,
		"speed":        56.0,
		"damage":       14,
		"attack_range": 58.0,
		"attack_cd":    1.15,
		"score_value":  650,
		"scale":        1.58,
		"label":        "בוס השכונה",
		"is_boss":      true,
	},
}

# ─── State machine ──────────────────────────────────────────────────────────
enum State { WALK, WIND_UP, ATTACK, HURT, DEAD }
var state: State = State.WALK

var max_health   := 40
var health       := 40
var attack_cd_timer := 0.0
var hurt_timer   := 0.0
var windup_timer := 0.0
var attack_time  := 0.0
var data: Dictionary = {}
var _target: Node2D = null

## Loot caps: regular up to 3 stones (per hit) + 1–2 coins on death; final boss up to 5 + 1–7.
var _stones_spawned := 0
var _loot_stones_cap := 3
var _loot_coins_cap := 2

# Animation
var _walk_phase: float = 0.0

# Visual refs
var _body: Node2D
var _arm_r: ColorRect
var _leg_l: ColorRect
var _leg_r: ColorRect
var _health_fill: ColorRect

func _ready() -> void:
	data = TYPES.get(enemy_type, TYPES["british_soldier"])
	max_health = data["max_health"]
	health     = max_health
	_config_loot_caps()
	add_to_group("enemies")
	if data.get("is_boss", false):
		add_to_group("bosses")

	_build_body()
	_build_collision()
	scale = Vector2.ONE * data["scale"]


func _config_loot_caps() -> void:
	if enemy_type == "old_city_boss":
		_loot_stones_cap = 5
		_loot_coins_cap = 7
	else:
		_loot_stones_cap = 3
		_loot_coins_cap = 2
	_stones_spawned = 0

# ─── Body construction ───────────────────────────────────────────────────────
func _build_body() -> void:
	_body = Node2D.new()
	add_child(_body)

	# Shadow
	var shadow := Polygon2D.new()
	shadow.polygon = PackedVector2Array([Vector2(-18,0),Vector2(18,0),Vector2(12,7),Vector2(-12,7)])
	shadow.color   = Color(0, 0, 0, 0.30)
	shadow.position = Vector2(0, 4)
	_body.add_child(shadow)

	# Legs
	_leg_l = ColorRect.new()
	_leg_l.size     = Vector2(9, 22)
	_leg_l.position = Vector2(-7, 14)
	_leg_l.color    = data["color_body"].darkened(0.22)
	_body.add_child(_leg_l)

	_leg_r = ColorRect.new()
	_leg_r.size     = Vector2(9, 22)
	_leg_r.position = Vector2(3, 14)
	_leg_r.color    = data["color_body"].darkened(0.22)
	_body.add_child(_leg_r)

	# Torso
	var torso := ColorRect.new()
	torso.size     = Vector2(24, 24)
	torso.position = Vector2(-12, -10)
	torso.color    = data["color_body"]
	_body.add_child(torso)

	# Arms
	var arm_l := ColorRect.new()
	arm_l.size     = Vector2(7, 18)
	arm_l.position = Vector2(-19, -8)
	arm_l.color    = data["color_body"]
	_body.add_child(arm_l)

	_arm_r = ColorRect.new()
	_arm_r.size     = Vector2(7, 18)
	_arm_r.position = Vector2(12, -8)
	_arm_r.color    = data["color_body"]
	_body.add_child(_arm_r)

	# Head
	var head := ColorRect.new()
	head.size     = Vector2(20, 20)
	head.position = Vector2(-10, -30)
	head.color    = data["color_skin"]
	_body.add_child(head)

	# Angry eyes
	for ex in [-6, 3]:
		var eye := ColorRect.new()
		eye.size     = Vector2(3, 2)
		eye.position = Vector2(ex, -22)
		eye.color    = Color(0.08, 0.06, 0.06)
		_body.add_child(eye)

	# Angry brow
	var brow := ColorRect.new()
	brow.size     = Vector2(16, 2)
	brow.position = Vector2(-8, -25)
	brow.color    = data["color_skin"].darkened(0.35)
	_body.add_child(brow)

	# Type-specific outfit & headwear
	match enemy_type:
		"british_soldier", "british_officer", "british_commander":
			_build_british_outfit()
		"local_fighter", "arab_warlord", "old_city_boss":
			_build_arab_outfit()

	# Health bar (wider for bosses)
	var bar_w: float = 60.0 if bool(data["is_boss"]) else 40.0
	var hbar_bg := ColorRect.new()
	hbar_bg.size     = Vector2(bar_w, 6)
	hbar_bg.position = Vector2(-bar_w * 0.5, -54)
	hbar_bg.color    = Color(0.12, 0.0, 0.0, 0.9)
	_body.add_child(hbar_bg)

	_health_fill = ColorRect.new()
	_health_fill.size     = Vector2(bar_w, 6)
	_health_fill.position = Vector2(-bar_w * 0.5, -54)
	_health_fill.color    = Color(0.85, 0.15, 0.15)
	_body.add_child(_health_fill)

	# Boss name label
	if data["is_boss"]:
		var lbl := Label.new()
		lbl.text = "★ " + data["label"] + " ★"
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.20))
		lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
		lbl.add_theme_constant_override("shadow_offset_x", 1)
		lbl.add_theme_constant_override("shadow_offset_y", 1)
		lbl.position = Vector2(-35, -68)
		_body.add_child(lbl)

func _build_british_outfit() -> void:
	# Waist belt
	var belt := ColorRect.new()
	belt.size     = Vector2(24, 3)
	belt.position = Vector2(-12, 11)
	belt.color    = data["color_accent"].darkened(0.45)
	_body.add_child(belt)

	# Sam Browne diagonal shoulder strap (left shoulder → right hip)
	var strap := Polygon2D.new()
	strap.polygon = PackedVector2Array([
		Vector2(-10, -8), Vector2(-6, -8),
		Vector2(11, 11),  Vector2(7, 11),
	])
	strap.color = data["color_accent"].darkened(0.20)
	_body.add_child(strap)

	# Service dress peaked cap — crown
	var crown := ColorRect.new()
	crown.size     = Vector2(22, 9)
	crown.position = Vector2(-11, -39)
	crown.color    = data["color_body"]
	_body.add_child(crown)

	# Cap band (thin strip at base of crown)
	var band := ColorRect.new()
	band.size     = Vector2(22, 3)
	band.position = Vector2(-11, -30)
	band.color    = data["color_accent"].darkened(0.30)
	_body.add_child(band)

	# Peaked brim (wider, angled polygon projecting forward)
	var brim := Polygon2D.new()
	brim.polygon = PackedVector2Array([
		Vector2(-14, 0), Vector2(14, 0),
		Vector2(11, 5),  Vector2(-11, 5),
	])
	brim.color    = data["color_body"].darkened(0.28)
	brim.position = Vector2(0, -30)
	_body.add_child(brim)

	if enemy_type in ["british_officer", "british_commander"]:
		# Cap badge (diamond shape)
		var badge := Polygon2D.new()
		badge.polygon = PackedVector2Array([
			Vector2(0,-4), Vector2(3,0), Vector2(0,4), Vector2(-3,0),
		])
		badge.color    = data["color_accent"]
		badge.position = Vector2(0, -34)
		_body.add_child(badge)

		# Shoulder rank pips
		for px in [-8, 1, 10]:
			var pip := ColorRect.new()
			pip.size     = Vector2(4, 4)
			pip.position = Vector2(px, -10)
			pip.color    = data["color_accent"]
			_body.add_child(pip)

	if enemy_type == "british_commander":
		# Taller crown for commanding look
		crown.size     = Vector2(24, 12)
		crown.position = Vector2(-12, -42)

		# Medal ribbons on chest
		var medal_colors := [Color(0.75,0.15,0.15), Color(0.78,0.68,0.15), Color(0.15,0.35,0.75)]
		for i in 3:
			var m := ColorRect.new()
			m.size     = Vector2(5, 4)
			m.position = Vector2(-8 + i * 6, -1)
			m.color    = medal_colors[i]
			_body.add_child(m)

func _build_arab_outfit() -> void:
	# Robe — wider than standard torso
	var robe := ColorRect.new()
	robe.size     = Vector2(30, 28)
	robe.position = Vector2(-15, -12)
	robe.color    = data["color_body"]
	_body.add_child(robe)

	# Sash / belt
	var sash := ColorRect.new()
	sash.size     = Vector2(30, 4)
	sash.position = Vector2(-15, 11)
	sash.color    = data["color_accent"]
	_body.add_child(sash)

	# Warlord: dark outer cloak over robe
	if enemy_type == "arab_warlord":
		var cloak := Polygon2D.new()
		cloak.polygon = PackedVector2Array([
			Vector2(-17, -12), Vector2(17, -12),
			Vector2(14, 36),   Vector2(-14, 36),
		])
		cloak.color = Color(0.10, 0.07, 0.05, 0.85)
		_body.add_child(cloak)

	# Keffiyeh cloth (draped over head, sides hanging down)
	var keff_color: Color
	if enemy_type == "local_fighter":
		keff_color = Color(0.90, 0.88, 0.80)
	elif enemy_type == "old_city_boss":
		keff_color = Color(0.35, 0.32, 0.30)
	else:
		keff_color = Color(0.70, 0.10, 0.08)
	var keff := Polygon2D.new()
	keff.polygon = PackedVector2Array([
		Vector2(-17, -4), Vector2(17, -4),
		Vector2(13, 14),  Vector2(-13, 14),
	])
	keff.color    = keff_color
	keff.position = Vector2(0, -38)
	_body.add_child(keff)

	# Keffiyeh check pattern lines
	for i in 3:
		var stripe := ColorRect.new()
		stripe.size          = Vector2(26, 1)
		stripe.position      = Vector2(-13, -36 + i * 6)
		stripe.color         = keff_color.darkened(0.40)
		stripe.modulate.a    = 0.45
		_body.add_child(stripe)

	# Agal — dark rope ring holding keffiyeh on head
	var agal := ColorRect.new()
	agal.size     = Vector2(24, 4)
	agal.position = Vector2(-12, -41)
	agal.color    = Color(0.10, 0.08, 0.05)
	_body.add_child(agal)

func _build_collision() -> void:
	var col := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius   = 12.0
	cap.height   = 40.0
	col.shape    = cap
	col.position = Vector2(0, -16)
	add_child(col)
	collision_layer = 2
	collision_mask  = 1

func set_target(t: Node2D) -> void:
	_target = t

# ─── Per-frame AI ──────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	match state:
		State.WALK:    _state_walk(delta)
		State.WIND_UP: _state_windup(delta)
		State.ATTACK:  _state_attack(delta)
		State.HURT:    _state_hurt(delta)
		State.DEAD:    pass

func _state_walk(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var diff := _target.global_position - global_position
	var dist := diff.length()
	var spd  := data["speed"] as float
	var rng  := data["attack_range"] as float

	if dist < rng:
		velocity = Vector2.ZERO
		if attack_cd_timer <= 0.0:
			state = State.WIND_UP
			windup_timer = 0.35
			_arm_r.position.y = -14
	else:
		velocity = diff.normalized() * spd
		_body.scale.x = -1.0 if diff.x < 0 else 1.0
		_walk_phase += delta * 8.0
		_leg_l.position.y = 14 + sin(_walk_phase) * 1.5
		_leg_r.position.y = 14 - sin(_walk_phase) * 1.5

	move_and_slide()
	position.y = clamp(position.y, FLOOR_Y_MIN, FLOOR_Y_MAX)

	if attack_cd_timer > 0.0:
		attack_cd_timer -= delta

func _state_windup(delta: float) -> void:
	velocity     = Vector2.ZERO
	windup_timer -= delta
	var t := 1.0 - windup_timer / 0.35
	_body.modulate = Color(1.0, 1.0 - t * 0.3, 1.0 - t * 0.3)
	if windup_timer <= 0.0:
		state = State.ATTACK
		attack_time = 0.15
		_do_attack_hit()

func _do_attack_hit() -> void:
	if _target != null and is_instance_valid(_target) and _target.has_method("take_damage"):
		var diff := _target.global_position - global_position
		if diff.length() < data["attack_range"] * 1.4:
			_target.take_damage(data["damage"])

func _state_attack(delta: float) -> void:
	velocity = Vector2.ZERO
	_body.modulate = Color(1.5, 1.0, 0.4)
	attack_time -= delta
	if attack_time <= 0.0:
		_body.modulate    = Color.WHITE
		_arm_r.position.y = -8
		attack_cd_timer   = data["attack_cd"]
		state = State.WALK

func _state_hurt(delta: float) -> void:
	hurt_timer -= delta
	velocity = velocity.lerp(Vector2.ZERO, delta * 6.0)
	move_and_slide()
	position.y = clamp(position.y, FLOOR_Y_MIN, FLOOR_Y_MAX)
	if hurt_timer <= 0.0:
		_body.modulate = Color.WHITE
		state = State.WALK

# ─── Damage ────────────────────────────────────────────────────────────────
func take_damage(amount: int, source_pos: Vector2 = Vector2.ZERO) -> void:
	if state == State.DEAD:
		return

	health -= amount
	_update_health_bar()
	_body.modulate = Color(2.0, 0.3, 0.3)

	# Jerusalem stone flies out on each hit while under per-enemy cap
	if amount > 0 and _stones_spawned < _loot_stones_cap:
		_stones_spawned += 1
		var drop_pos: Vector2 = global_position + Vector2(randf_range(-10.0, 10.0), randf_range(-26.0, -10.0))
		loot_pickup_requested.emit("stone", drop_pos, 1)

	if health <= 0:
		_die()
		return

	state      = State.HURT
	hurt_timer = 0.28
	if source_pos != Vector2.ZERO:
		velocity = (global_position - source_pos).normalized() * 160.0

	var tw: Tween = create_tween()
	tw.tween_property(_body, "modulate", Color.WHITE, 0.25)

func _update_health_bar() -> void:
	if not is_instance_valid(_health_fill):
		return
	var bar_w: float = 60.0 if bool(data["is_boss"]) else 40.0
	var pct: float = clampf(health / float(max_health), 0.0, 1.0)
	_health_fill.size.x = bar_w * pct
	if pct > 0.6:
		_health_fill.color = Color(0.85, 0.15, 0.15)
	elif pct > 0.3:
		_health_fill.color = Color(0.90, 0.60, 0.10)
	else:
		_health_fill.color = Color(0.60, 0.10, 0.10)

func _die() -> void:
	state = State.DEAD
	set_physics_process(false)
	collision_layer = 0
	collision_mask  = 0
	var is_final_alley_boss: bool = (enemy_type == "old_city_boss")
	enemy_died.emit(data["score_value"], global_position, is_final_alley_boss)

	var n_coins: int = randi_range(1, _loot_coins_cap)
	for _c in range(n_coins):
		var cpos: Vector2 = global_position + Vector2(randf_range(-18.0, 18.0), randf_range(-8.0, 4.0))
		loot_pickup_requested.emit("coin", cpos, 1)

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(_body, "rotation", PI * 0.5,       0.4)
	tween.tween_property(_body, "modulate", Color(1,1,1,0), 0.6)
	tween.chain().tween_callback(queue_free)

extends Area2D

## "coin" | "stone"
var pickup_kind: String = "coin"
var coin_value: int = 1

var _vel: Vector2 = Vector2.ZERO
var _player: Node2D = null
var _magnet_range := 200.0
var _magnet_speed := 420.0
var _life := 0.0

func setup(kind: String, value: int, player_ref: Node2D) -> void:
	pickup_kind = kind
	coin_value = max(1, value)
	_player = player_ref


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)

	var shape := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 10.0
	shape.shape = circ
	add_child(shape)

	var vis := ColorRect.new()
	vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vis.size = Vector2(14, 14)
	vis.position = Vector2(-7, -7)
	if pickup_kind == "coin":
		vis.color = Color(0.95, 0.78, 0.18)
	else:
		vis.color = Color(0.82, 0.74, 0.62)
	add_child(vis)

	var ang := randf() * TAU
	_vel = Vector2(cos(ang), sin(ang)) * randf_range(90.0, 160.0)
	_vel.y -= 60.0


func _physics_process(delta: float) -> void:
	_life += delta
	if _life > 22.0:
		queue_free()
		return

	if is_instance_valid(_player):
		var d: Vector2 = _player.global_position - global_position
		if d.length() < _magnet_range:
			var dir: Vector2 = d.normalized()
			global_position += dir * _magnet_speed * delta
		else:
			global_position += _vel * delta
			_vel *= 0.985
	else:
		global_position += _vel * delta
		_vel *= 0.985


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("receive_pickup"):
		body.receive_pickup(pickup_kind, coin_value)
	queue_free()

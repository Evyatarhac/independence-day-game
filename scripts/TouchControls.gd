extends CanvasLayer

# Virtual controls for mobile — emits InputEventAction so Player.gd works identically.
# Auto-hides on desktop platforms unless debug mode is on.

const C_BG    := Color(1, 1, 1, 0.10)
const C_RING  := Color(1, 1, 1, 0.18)
const C_KNOB  := Color(0.95, 0.95, 0.95, 0.55)
const C_GOLD  := Color(0.95, 0.78, 0.20, 0.90)
const C_RED   := Color(0.90, 0.25, 0.25, 0.85)
const C_BLUE  := Color(0.25, 0.60, 0.95, 0.85)
const C_PURPL := Color(0.85, 0.35, 0.95, 0.90)

var _player: Node = null
var _dpad_center: Vector2 = Vector2.ZERO
var _dpad_radius: float = 64.0
var _dpad_touch_idx: int = -1
var _dpad_knob: ColorRect

# Actions currently held down via touch
var _held: Dictionary = {}

# Show controls?
var _show_controls: bool = true
## While > 0, hide this layer so full-screen modals/ads always receive touch/mouse first.
var _ui_block_depth: int = 0

func _ready() -> void:
	add_to_group("touch_controls_overlay")
	layer = 20
	_show_controls = _should_show_controls()
	if _show_controls:
		_build()
	_apply_layer_visibility()


func push_touch_ui_block() -> void:
	_ui_block_depth += 1
	_apply_layer_visibility()


func pop_touch_ui_block() -> void:
	_ui_block_depth = maxi(0, _ui_block_depth - 1)
	_apply_layer_visibility()


func _apply_layer_visibility() -> void:
	visible = _show_controls and _ui_block_depth == 0

func _should_show_controls() -> bool:
	# Show on mobile/touchscreen. On desktop, only if touchscreen hardware is detected.
	if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return true
	if DisplayServer.is_touchscreen_available():
		return true
	return false

func set_player(p: Node) -> void:
	_player = p

func _build() -> void:
	# ── D-Pad (left side) ────────────────────────────────────────────────────
	_dpad_center = Vector2(110, 430)

	# Outer ring
	var ring := _circle(_dpad_radius, C_RING)
	ring.position = _dpad_center
	add_child(ring)

	# Inner center dot
	var dot := _circle(6, Color(1, 1, 1, 0.3))
	dot.position = _dpad_center
	add_child(dot)

	# Direction arrows for visual hint
	for ang_i in 4:
		var ang: float = ang_i * PI / 2.0
		var arrow := Polygon2D.new()
		arrow.polygon = PackedVector2Array([
			Vector2(_dpad_radius - 16, -6),
			Vector2(_dpad_radius - 4, 0),
			Vector2(_dpad_radius - 16, 6),
		])
		arrow.color = Color(1, 1, 1, 0.35)
		arrow.position = _dpad_center
		arrow.rotation = ang
		add_child(arrow)

	# Knob (moves with touch)
	_dpad_knob = ColorRect.new()
	_dpad_knob.size     = Vector2(36, 36)
	_dpad_knob.position = _dpad_center - Vector2(18, 18)
	_dpad_knob.color    = C_KNOB
	var knob_style := StyleBoxFlat.new()
	knob_style.bg_color = C_KNOB
	knob_style.corner_radius_top_left = 18
	knob_style.corner_radius_top_right = 18
	knob_style.corner_radius_bottom_left = 18
	knob_style.corner_radius_bottom_right = 18
	add_child(_dpad_knob)

	# ── Attack Buttons (right side) ──────────────────────────────────────────
	var btn_configs := [
		{"label": "מכה",    "action": "punch",   "pos": Vector2(760, 460), "color": C_RED},
		{"label": "בעיטה",  "action": "kick",    "pos": Vector2(850, 420), "color": C_BLUE},
		{"label": "מיוחד",  "action": "special", "pos": Vector2(870, 330), "color": C_PURPL},
	]

	for cfg in btn_configs:
		_make_touch_button(cfg["label"], cfg["action"], cfg["pos"], cfg["color"])

func _circle(radius: float, color: Color) -> Node2D:
	# Return a Polygon2D approximating a circle at its local origin
	var p := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		pts.append(Vector2(cos(a) * radius, sin(a) * radius))
	p.polygon = pts
	p.color = color
	return p

func _make_touch_button(label: String, action: String, pos: Vector2, color: Color) -> void:
	var btn := Button.new()
	btn.text     = label
	btn.size     = Vector2(76, 76)
	btn.position = pos - Vector2(38, 38)
	btn.add_theme_font_size_override("font_size", 15)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)

	var s := StyleBoxFlat.new()
	s.bg_color              = color
	s.corner_radius_top_left     = 38
	s.corner_radius_top_right    = 38
	s.corner_radius_bottom_left  = 38
	s.corner_radius_bottom_right = 38
	s.border_color = Color(1, 1, 1, 0.4)
	s.border_width_top = 2
	s.border_width_bottom = 2
	s.border_width_left = 2
	s.border_width_right = 2
	btn.add_theme_stylebox_override("normal",  s)

	var s_hover := s.duplicate() as StyleBoxFlat
	s_hover.bg_color = color.lightened(0.15)
	btn.add_theme_stylebox_override("hover",   s_hover)

	var s_press := s.duplicate() as StyleBoxFlat
	s_press.bg_color = color.darkened(0.2)
	s_press.border_color = C_GOLD
	btn.add_theme_stylebox_override("pressed", s_press)

	btn.pressed.connect(func(): _fire_action(action))
	add_child(btn)

func _input(event: InputEvent) -> void:
	if not _show_controls:
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_handle_dpad(event)

func _handle_dpad(event: InputEvent) -> void:
	var pos := Vector2.ZERO

	if event is InputEventScreenTouch:
		pos = event.position
		if event.pressed:
			# Only claim touches in the left half of the screen for the dpad
			if pos.x < 480 and pos.distance_to(_dpad_center) < _dpad_radius * 1.8:
				_dpad_touch_idx = event.index
		elif event.index == _dpad_touch_idx:
			_dpad_touch_idx = -1
			_release_all_dpad()
			_dpad_knob.position = _dpad_center - Vector2(18, 18)
			return

	elif event is InputEventScreenDrag:
		if event.index != _dpad_touch_idx:
			return
		pos = event.position

	if _dpad_touch_idx == -1:
		return

	var diff := pos - _dpad_center
	var clamped: Vector2 = diff.normalized() * min(diff.length(), _dpad_radius)
	_dpad_knob.position = _dpad_center + clamped - Vector2(18, 18)

	# Threshold for direction
	var threshold := 16.0
	_set_action("move_left",  clamped.x < -threshold)
	_set_action("move_right", clamped.x >  threshold)
	_set_action("move_up",    clamped.y < -threshold)
	_set_action("move_down",  clamped.y >  threshold)

func _release_all_dpad() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		_set_action(a, false)

func _set_action(action: String, active: bool) -> void:
	if _held.get(action, false) == active:
		return
	_held[action] = active
	var ev := InputEventAction.new()
	ev.action   = action
	ev.pressed  = active
	Input.parse_input_event(ev)

func _fire_action(action: String) -> void:
	# Prefer direct call for immediate response
	if _player != null and is_instance_valid(_player) and _player.has_method("virtual_attack"):
		_player.virtual_attack(action)
		return
	# Fallback: synthesize press-then-release
	var ev := InputEventAction.new()
	ev.action  = action
	ev.pressed = true
	Input.parse_input_event(ev)
	var ev2 := InputEventAction.new()
	ev2.action  = action
	ev2.pressed = false
	Input.parse_input_event(ev2)

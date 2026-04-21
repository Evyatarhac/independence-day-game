extends SceneTree

const GAME_SCENE := "res://scenes/Game.tscn"
const FRAMES := 240

func _initialize() -> void:
	if not ResourceLoader.exists(GAME_SCENE):
		push_error("Runtime smoke failed: missing scene file: %s" % GAME_SCENE)
		quit(1)
		return

	var packed := load(GAME_SCENE) as PackedScene
	if packed == null:
		push_error("Runtime smoke failed: cannot load PackedScene: %s" % GAME_SCENE)
		quit(1)
		return

	var inst := packed.instantiate()
	if inst == null:
		push_error("Runtime smoke failed: instantiate() returned null for: %s" % GAME_SCENE)
		quit(1)
		return

	root.add_child(inst)

	for _i in range(FRAMES):
		await process_frame

	if is_instance_valid(inst):
		inst.queue_free()
		await process_frame

	quit(0)


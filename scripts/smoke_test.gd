extends SceneTree

var SCENES := PackedStringArray([
	"res://scenes/MainMenu.tscn",
	"res://scenes/CharacterSelect.tscn",
	"res://scenes/IntroSequence.tscn",
	"res://scenes/NameEntry.tscn",
	"res://scenes/Game.tscn",
	"res://scenes/GameOver.tscn",
])

func _initialize() -> void:
	for path in SCENES:
		if not ResourceLoader.exists(path):
			push_error("Smoke test failed: missing scene file: %s" % path)
			quit(1)
			return

		var packed := ResourceLoader.load(path) as PackedScene
		if packed == null:
			push_error("Smoke test failed: cannot load PackedScene: %s" % path)
			quit(1)
			return

		var inst := packed.instantiate()
		if inst == null:
			push_error("Smoke test failed: instantiate() returned null for: %s" % path)
			quit(1)
			return

		inst.free()
		print("OK: %s" % path)

	quit(0)


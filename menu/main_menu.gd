extends Control

func _start(is_server: bool):
	# Create packed scene resource
	var next_scene = load("res://root.tscn")
	
	# Set parameters through autoload or scene instantiation
	var scene_instance = next_scene.instantiate()
	scene_instance.is_server = is_server
	
	# Change scene to the instantiated scene
	get_tree().root.add_child.call_deferred(scene_instance)
	get_tree().current_scene.queue_free()
	#get_tree().current_scene = scene_instance
	

func _on_button_pressed() -> void:
	_start(true)


func _on_connect_pressed() -> void:
	_start(false)

func _ready() -> void:
	# check for dedicated server feature tag
	if OS.has_feature("dedicated_server"):
		_start(true)
	else:
		await get_tree().create_timer(3.0).timeout
		_start(false)

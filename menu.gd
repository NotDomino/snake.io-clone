extends Control


func _ready() -> void:
	var label = $VBoxContainer/Label
	var tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	tween.tween_property(label, "scale", Vector2(1.05,1.05), 0.5)
	tween.tween_property(label, "scale", Vector2(1,1), 0.5)


func _on_quit_pressed():
	get_tree().quit()  # Graceful web exit


func _on_start_button_pressed() -> void:
	print('loading main')
	get_tree().change_scene_to_file("res://main.tscn")  # Web-safe transition; no fade for load speed

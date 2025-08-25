extends Snake

func _physics_process(delta):
	var mouse_pos = get_global_mouse_position()
	var target_dir = (mouse_pos - position).normalized()
	if target_dir != Vector2.ZERO:
		next_direction = target_dir
	is_boosting = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and body_segments.size() > 0
	speed = boost_speed if is_boosting else base_speed
	super._physics_process(delta)

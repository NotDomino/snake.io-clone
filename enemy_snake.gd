extends Snake

var ai_timer: Timer
var target_pos: Vector2 = position
var wander_angle: float = 0.0


func _ready() -> void:
	super._ready()
	ai_timer = Timer.new()
	ai_timer.wait_time = 0.2
	ai_timer.autostart = true
	ai_timer.timeout.connect(_update_ai_target)
	add_child(ai_timer)
	add_to_group("Enemy")  # Optional


func _physics_process(delta):
	var target_dir = (target_pos - position).normalized()
	if target_dir != Vector2.ZERO:
		next_direction = target_dir.lerp(direction, 0.1)
	if position.distance_to(target_pos) < 200 and randf() < 0.05 * delta:
		speed = boost_speed
	else:
		speed = base_speed
	super._physics_process(delta)


func _update_ai_target():
	var foods = get_parent().foods
	if foods.is_empty():
		wander_angle += randf_range(-PI/4, PI/4)
		target_pos = position + direction * 100 + Vector2(cos(wander_angle), sin(wander_angle)) * 50
	else:
		var nearest_food = foods[0]
		var min_dist_sq = position.distance_squared_to(nearest_food.position)
		for food in foods.slice(1):
			var dist_sq = position.distance_squared_to(food.position)
			if dist_sq < min_dist_sq:
				min_dist_sq = dist_sq
				nearest_food = food
		target_pos = nearest_food.position

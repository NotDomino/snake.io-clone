extends Area2D

signal died  # For future game over handling

@export var segment_scene: PackedScene  # Assign body_segment.tscn in Inspector

var parent: Node  # Cache for add_segment perf
var body_segments = []  # Array for tail nodes later

var points: int = 0  # Total eaten; drives scale/growth
var next_growth_cost: int = 1  # Starts low; increases per segment
var growth_multiplier: float = 1.2  # Exponent base; tweak for balance (1.1-1.5)

var speed = 300  # Pixels per second, optimized for smooth web perf
var base_speed = speed
var boost_speed = 450
var is_boosting = false
var drain_rate: float = 5.0  # Segments/points per sec; tweak for balance (web-opt float accum vs int ticks)
var drain_accum: float = 0.0  # Delta-based for smooth web frames

var direction = Vector2.RIGHT
var segment_size = 16
var next_direction = direction
var follow_speed: float = speed / segment_size
var ai_timer: Timer
var target_pos: Vector2 = position
var wander_angle: float = 0.0
var is_dying: bool = false  # Flag avoids double-die signals on mutual head-head

func _ready() -> void:
	parent = get_parent()
	ai_timer = Timer.new()
	ai_timer.wait_time = 0.5
	ai_timer.autostart = true
	ai_timer.timeout.connect(_update_ai_target)
	add_child(ai_timer)
	add_to_group("SnakeHead")
	add_to_group("Enemy")  # Optional for other logic
	for seg in body_segments:
		seg.add_to_group("SnakeBody")
		seg.add_to_group("EnemyBody")  # If needed separately
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _physics_process(delta):
	var target_dir = (target_pos - position).normalized()
	if target_dir != Vector2.ZERO:
		next_direction = target_dir.lerp(direction, 0.1)  # Smooth turn for natural AI feel; web-vec opt
	direction = next_direction
	
	if position.distance_to(target_pos) < 200 and randf() < 0.05 * delta: speed = boost_speed
	else: speed = base_speed  # Rare near-food dashes for playful aggression
	
	if is_boosting:
		drain_accum += drain_rate * delta
		while drain_accum >= 1.0:  # Batch drain if laggy frames; opt for rare instantiate
			var lost_seg = body_segments.pop_back()
			var spawn_pos = lost_seg.position if lost_seg else position  # Tail-safe
			lost_seg.queue_free()
			drain_accum -= 1.0
			spawn_trail_food(spawn_pos, 1)  # Value matches loss; define below
	
	rotation = direction.angle()  # Head faces movement
	position += direction * speed * delta
	update_body_segments(delta) # Makes body segments follow


func spawn_trail_food(pos: Vector2, value: int):
	var food = parent.food_scene.instantiate()  # Reuse main's @export; low-instantiate rate
	food.position = pos
	food.food_value = value
	food.scale *= 0.7  # Smaller trail dots for visual cue; web-light scale
	parent.add_child(food)


func update_body_segments(delta):
	var prev_pos = position
	var prev_dir = direction
	for seg in body_segments:
		var target_dir = (prev_pos - seg.position).normalized()
		if target_dir != Vector2.ZERO:
			seg.rotation = target_dir.angle()  # Rotate to face movement for curved worm look
		var distance = seg.position.distance_to(prev_pos)
		if distance > segment_size:
			seg.position = seg.position.lerp(prev_pos - target_dir * segment_size, follow_speed * delta)
			seg.position += Vector2(
				sin(Time.get_ticks_msec() * 0.01 + body_segments.find(seg) * 0.5), 
				cos(Time.get_ticks_msec() * 0.01 + body_segments.find(seg) * 0.5)) * 1  # firefly bob
		prev_pos = seg.position
		prev_dir = target_dir


func add_segment():
	var new_seg = segment_scene.instantiate()
	if body_segments.is_empty():
		new_seg.position = position
	else:
		new_seg.position = body_segments.back().position
	
	new_seg.snake = self
	new_seg.add_to_group("SnakeBody")

	body_segments.append(new_seg)
	var new_scale = 1.0 + (body_segments.size() * 0.01)  # Linear girth; caps ~2x at 100 length, tweak 0.005-0.02
	modulate = Color(1, 1 - (body_segments.size() * 0.005), 1 - (body_segments.size() * 0.005))  # Reddens as grows for 'heated' playful menace, zero-cost tint ramp
	scale = Vector2(new_scale, new_scale)
	for seg in body_segments:
		seg.scale = Vector2(new_scale, new_scale)
	new_seg.modulate = Color(1, randf_range(0.5,1), randf_range(0.5,1))  # Pastel hues
	parent.add_child(new_seg)
	var eat_tween = create_tween()
	eat_tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
	eat_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)



func _on_area_entered(area: Area2D):
	if is_dying: return
	if area.is_in_group("SnakeBody") and area.snake != self:
		is_dying = true
		died.emit()
		var burst_tween = create_tween(); for seg in body_segments:
			burst_tween.parallel().tween_property(seg, "modulate:a", 0, 0.3);
			burst_tween.parallel().tween_property(seg, "scale", Vector2(1.5,1.5), 0.3)  # Playful fade-pop anim before free, low-cost parallel
	elif area.is_in_group("SnakeHead") and area != self:
		is_dying = true
		died.emit()
		area.died.emit()  # Mutual; flag prevents chain loops
		var burst_tween = create_tween(); for seg in body_segments:
			burst_tween.parallel().tween_property(seg, "modulate:a", 0, 0.3);
			burst_tween.parallel().tween_property(seg, "scale", Vector2(1.5,1.5), 0.3)  # Playful fade-pop anim before free, low-cost parallel
	if area.is_in_group("Food"):
		area.queue_free()
		points += area.food_value
		while points >= next_growth_cost:
			add_segment()
			points -= next_growth_cost
			next_growth_cost = int(next_growth_cost * growth_multiplier) + 1  # Min +1 avoids stall; web-int math fast


func _on_area_exited(area: Area2D):
	if area.name == "ArenaBoundary":
		died.emit()
		queue_free()  # Temp; add particle burst later for playful death


func _update_ai_target():
	var foods = get_tree().get_nodes_in_group("Food")
	if foods.is_empty():  # Wander if none
		wander_angle += randf_range(-PI/4, PI/4)
		target_pos = position + direction * 100 + Vector2(cos(wander_angle), sin(wander_angle)) * 50
	else:
		foods.sort_custom(func(a,b): return a.position.distance_squared_to(position) < b.position.distance_squared_to(position))  # Fast sq dist sort; top 1
		target_pos = foods[0].position

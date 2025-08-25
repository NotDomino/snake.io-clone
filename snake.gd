class_name Snake
extends Area2D

signal died  # For future game over handling
var parent: Node  # Cache for add_segment perf
var body_segments = []  # Array for tail nodes later
var points: int = 0  # Total eaten; drives scale/growth
var total_points: int = 0 
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
var is_dying: bool = false  # Avoids double-die on mutual hits
var username: String = "Bot"


var skin_colors: Array[Color] = [
	Color(1.0, 0.3, 0.3), Color(0.8, 0.2, 0.2), Color(1.0, 0.5, 0.5),
	Color(0.9, 0.1, 0.1), Color(0.7, 0.4, 0.4)
]

var skin_hue_offset: int = 0  # Per-snake shift for varied rainbow starts; zero-cost int

func _ready() -> void:
	parent = get_parent()
	add_to_group("SnakeHead")
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func _physics_process(delta):
	direction = next_direction
	if is_boosting:
		drain_accum += drain_rate * delta
		while drain_accum >= 1.0:
			var lost_seg = body_segments.pop_back()
			var spawn_pos = lost_seg.position if lost_seg else position
			lost_seg.queue_free()
			drain_accum -= 1.0
			spawn_trail_food(spawn_pos, 1)
	rotation = direction.angle()  # Head faces movement
	position += direction * speed * delta
	update_body_segments(delta)

func spawn_trail_food(pos: Vector2, value: int):
	var food = parent.food_scene.instantiate()
	food.position = pos
	food.food_value = value
	food.scale *= 0.7
	parent.add_child(food)

func update_body_segments(delta):
	var prev_pos = position
	var prev_dir = direction
	for seg in body_segments:
		var target_dir = (prev_pos - seg.position).normalized()
		if target_dir != Vector2.ZERO:
			seg.rotation = target_dir.angle()
		var distance = seg.position.distance_to(prev_pos)
		if distance > segment_size:
			seg.position = seg.position.lerp(prev_pos - target_dir * segment_size, follow_speed * delta)
		prev_pos = seg.position
		prev_dir = target_dir

func add_segment():
	var new_seg = Global.BODY_SEGMENT.instantiate()
	new_seg.position = body_segments.back().position if body_segments else position
	new_seg.snake = self
	new_seg.add_to_group("SnakeBody")
	body_segments.append(new_seg)
	var new_scale = 1.0 + (body_segments.size() * 0.01)
	modulate = Color(1, 1 - (body_segments.size() * 0.005), 1 - (body_segments.size() * 0.005))
	scale = Vector2(new_scale, new_scale)
	for seg in body_segments:
		seg.scale = Vector2(new_scale, new_scale)
	var color_index = (body_segments.size() + skin_hue_offset) % skin_colors.size()
	new_seg.modulate = skin_colors[color_index]
	parent.call_deferred("add_child", new_seg)
	var current_scale = scale
	var eat_tween = create_tween()
	eat_tween.tween_property(self, "scale", current_scale * 1.2, 0.1)
	eat_tween.tween_property(self, "scale", current_scale, 0.1)

func _on_area_entered(area: Area2D):
	if is_dying: return
	if area.is_in_group("SnakeBody") and area.snake != self:
		is_dying = true
		died.emit()
	elif area.is_in_group("SnakeHead") and area != self:
		is_dying = true
		died.emit()
		area.died.emit()
		var kill_fx = create_tween()
		kill_fx.tween_property(self, "modulate", Color(1,0.5,0.5), 0.1)
		kill_fx.tween_property(self, "modulate", Color(1,1,1), 0.1)
	
	if area.is_in_group("Food"):
		area.call_deferred("queue_free")
		get_parent().foods.erase(area)
		points += area.food_value
		total_points += area.food_value  # Base eat score
		while points >= next_growth_cost:
			add_segment()
			points -= next_growth_cost
			next_growth_cost = int(next_growth_cost * growth_multiplier) + 1

func _on_area_exited(area: Area2D):
	if area.name == "ArenaBoundary" and not is_dying:
		is_dying = true
		var burst_tween = create_tween()
		for seg in body_segments:
			burst_tween.parallel().tween_property(seg, "modulate:a", 0, 0.3)
			burst_tween.parallel().tween_property(seg, "scale", Vector2(1.5,1.5), 0.3)
		burst_tween.tween_callback(died.emit)

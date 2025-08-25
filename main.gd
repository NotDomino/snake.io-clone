extends Node2D

@onready var snake_head = $SnakeHead
@onready var arena_boundary: Area2D = $ArenaBoundary

@export var food_scene: PackedScene  # Assign food.tscn in Inspector

var arena_center
var arena_radius

var target_food_density: int = 1  # Per 100x100 area; tweak for playful scatter without web node overload (aim <500 total)
var center_bonus: float = 3.0  # Max density multiplier at exact center; tweak 2-5 for balance


func _ready():
	snake_head.area_entered.connect(func(area): if area.is_in_group("Food"): spawn_food())  # Respawn on eat
	
	# Spawn initial snake head at center
	snake_head.position = arena_boundary.position
	
	arena_center = arena_boundary.position
	arena_radius = (600 - 32) * 20  # 20x scale; web-ok floats, no precision loss under 1e5
	
	
	for i in 40:  # Initial playful length; scales well for web start
		snake_head.add_segment()
	
	snake_head.died.connect(_on_snake_died)
	
	spawn_food()


func _process(delta):
	var cam_rect = get_viewport_rect()  # Simpler bounds; assumes camera centered on head, web-opt no inverse
	cam_rect.position = snake_head.position - cam_rect.size / 2  # Offset to player view
	var near_foods = get_tree().get_nodes_in_group("Food").filter(func(f): return cam_rect.has_point(f.position) or f.position.distance_to(snake_head.position) < 2000)
	var dist_to_center = snake_head.position.distance_to(arena_center)
	var effective_density = target_food_density * (1 + center_bonus / (1 + dist_to_center / arena_radius * 0.1))  # Falloff bias; denser central, normalizes to radius scale
	var target_count = effective_density * (cam_rect.size.x * cam_rect.size.y / 10000.0)
	if near_foods.size() < target_count:
		for i in max(1, int(target_count - near_foods.size())):  # Dynamic batch to exact gap; avoids over-spawn web spikes
			spawn_food()


func spawn_food():
	var food = food_scene.instantiate()
	var angle = randf() * TAU
	var dist = sqrt(randf()) * 1000  # 0-1000 uniform area; far enough for scatter, close for respawn perf
	food.position = snake_head.position + Vector2(cos(angle), sin(angle)) * dist
	food.scale = Vector2(randf_range(0.8,1.2), randf_range(0.8,1.2))
	food.food_value = randi_range(1, 3)
	add_child(food)

func _on_food_eaten(body: Node2D, food: Area2D):
	if body == snake_head:
		# Grow snake later; for now, respawn
		food.queue_free()
		spawn_food()


func _on_snake_died():
	# Quick reset for web playtesting; expand to score/UI later
	for seg in snake_head.body_segments:
		seg.queue_free()
	snake_head.body_segments.clear()
	snake_head.position = arena_center
	
	for i in 3:
		snake_head.add_segment()

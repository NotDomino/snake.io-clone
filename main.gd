extends Node2D

@onready var snake_head = $SnakeHead
@onready var arena_boundary: Area2D = $ArenaBoundary

@export var food_scene: PackedScene  # Assign food.tscn in Inspector
@export var enemy_scene: PackedScene  # Duplicate snake_head.tscn as enemy.tscn, assign in Inspector
var arena_center
var arena_radius

var enemies: Array = []  # Track for web-opt iteration (no heavy groups)

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
	
	
	for i in 20:  # Bot count; low for web perf (<500 nodes total with segments)
		spawn_enemy()
		
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


func spawn_enemy():
	var enemy = enemy_scene.instantiate()
	var angle = randf() * TAU
	var dist = sqrt(randf()) * arena_radius * 0.8  # Buffer from edge
	enemy.position = arena_center + Vector2(cos(angle), sin(angle)) * dist
	enemy.modulate = Color(randf_range(0.5,1), randf_range(0.5,1), randf_range(0.5,1))  # Unique hues for playful bot variety
	enemy.area_entered.connect(_on_enemy_collision.bind(enemy))  # Handle hits; define below
	enemy.died.connect(_on_enemy_died.bind(enemy))  # Respawn
	add_child(enemy)
	enemies.append(enemy)


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


func _on_enemy_collision(area: Area2D, enemy: Area2D):
	if area == snake_head:  # Player kills enemy head-on
		enemy.died.emit()
	elif area.is_in_group("EnemyBody") and area.get_parent() != enemy:  # Cross-body kills
		enemy.died.emit()


func _on_enemy_died(enemy: Area2D):
	var positions: Array = enemy.body_segments.map(func(seg): return seg.position)
	positions.insert(0, enemy.position)  # Head first for tail-to-head spread
	var total_length: int = positions.size()
	var drop_total: int = int(total_length * 0.8)
	for k in range(drop_total):
		var index: int = int(k * float(total_length) / drop_total)  # Even spacing math; fast int cast
		var pos: Vector2 = positions[index]
		var food = food_scene.instantiate()
		food.position = pos + Vector2(randf_range(-8,8), randf_range(-8,8))  # Micro-scatter avoids overlap without collision checks
		food.food_value = 1
		food.scale *= 1.2; food.modulate = Color(1,0.8,0)  # Slightly larger golden drops for playful loot glow, zero extra vram
		add_child(food)
	for seg in enemy.body_segments:
		seg.queue_free()
	enemy.body_segments.clear()
	enemy.queue_free()
	enemies.erase(enemy)
	spawn_enemy()

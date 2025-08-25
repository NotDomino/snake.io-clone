extends Node2D

@onready var player_snake: Area2D = $PlayerSnake
@onready var arena_boundary: Area2D = $ArenaBoundary
@onready var leaderboard_container: VBoxContainer = %Leaderboard  # Add in UI.tscn: VBox top-right, font playful

@export var food_scene: PackedScene  # Assign food.tscn in Inspector
@export var enemy_scene: PackedScene  # Duplicate snake_head.tscn as enemy.tscn, assign in Inspector
var arena_center
var arena_radius

var enemies: Array = []  # Track for web-opt iteration (no heavy groups)
var foods: Array = []  # Cache for opt access; web-fast array ops
var enemy_pool: Array = []  # Pre-alloc; size to max expected (e.g., 30 >20)

var target_food_density: int = 1  # Per 100x100 area; tweak for playful scatter without web node overload (aim <500 total)
var center_bonus: float = 3.0  # Max density multiplier at exact center; tweak 2-5 for balance

var leaderboard_timer: Timer
var leaderboard: Array = []  # Sorted [snake, name, score]; fast array


func _ready():
	player_snake.area_entered.connect(func(area): if area.is_in_group("Food"): spawn_food())  # Respawn on eat
	
	# Spawn initial snake head at center
	player_snake.position = arena_boundary.position
	
	arena_center = arena_boundary.position
	arena_radius = (600 - 32) * 20  # 20x scale; web-ok floats, no precision loss under 1e5
	
	
	for i in 3:  # Initial playful length; scales well for web start
		player_snake.add_segment()
	
	
	for i in 50:  # Oversize pool for buffer; web-instantiate only at load
		var enemy = enemy_scene.instantiate()
		enemy.visible = false
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(enemy)  # Tree early for refs
		enemy_pool.append(enemy)
	
	for i in 40:
		activate_enemy()
		
	player_snake.died.connect(_on_snake_died)
	leaderboard_timer = Timer.new()
	leaderboard_timer.wait_time = 1.0  # Low freq for web CPU opt
	leaderboard_timer.autostart = true
	leaderboard_timer.timeout.connect(update_leaderboard)
	add_child(leaderboard_timer)
	update_leaderboard()  # Initial
	
	spawn_food()


func _process(delta):
	var cam_rect = get_viewport_rect()  # Simpler bounds; assumes camera centered on head, web-opt no inverse
	cam_rect.position = player_snake.position - cam_rect.size / 2  # Offset to player view
	foods = foods.filter(is_instance_valid)  # Prune freed refs; web-safe array clean to avoid crashes
	var near_foods = foods.filter(func(f): return cam_rect.has_point(f.position) or f.position.distance_to(player_snake.position) < 2000)
	var dist_to_center = player_snake.position.distance_to(arena_center)
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
	enemies.append(enemy)
	add_child(enemy)


func activate_enemy():
	if enemy_pool.is_empty(): return  # Fallback; rare on web
	var enemy = enemy_pool.pop_front()
	var angle = randf() * TAU
	var dist = sqrt(randf()) * arena_radius * 0.8
	enemy.position = arena_center + Vector2(cos(angle), sin(angle)) * dist
	enemy.skin_hue_offset = randi_range(0, enemy.skin_colors.size() - 1)  # Per-bot shift for varied rainbow starts;
	enemy.username = Global.name_pool[randi() % Global.name_pool.size()] + str(randi_range(1,99))  # e.g., "Slithy42"; web-light randi
	
	enemy.visible = true
	enemy.process_mode = Node.PROCESS_MODE_INHERIT
	enemy.area_entered.connect(_on_enemy_collision.bind(enemy))
	enemy.died.connect(_on_enemy_died.bind(enemy))
	enemies.append(enemy)


func spawn_food():
	var food = food_scene.instantiate()
	var angle = randf() * TAU
	var dist = sqrt(randf()) * 1000
	food.position = player_snake.position + Vector2(cos(angle), sin(angle)) * dist
	food.scale = Vector2(randf_range(0.8,1.2), randf_range(0.8,1.2))
	food.food_value = randi_range(1, 3)
	call_deferred("add_child", food)  # Safe during physics flush; web-opt defer
	foods.append(food)


func update_leaderboard():
	leaderboard.clear()
	leaderboard.append([player_snake, player_snake.username, player_snake.total_points])
	for enemy in enemies:
		leaderboard.append([enemy, enemy.username, enemy.total_points])  # bot_name from below
	leaderboard.sort_custom(func(a,b): return a[2] > b[2])  # Descending score; fast for <30
	if leaderboard.size() > 10: leaderboard.resize(10)  # Cap for UI/perf

func _on_food_eaten(body: Node2D, food: Area2D):
	if body == player_snake:
		# Grow snake later; for now, respawn
		food.queue_free()
		spawn_food()


func _on_snake_died():
	get_tree().change_scene_to_file("res://menu.tscn")  # Instant menu return; web-opt lightweight transition


func _on_enemy_collision(area: Area2D, enemy: Area2D):
	if area == player_snake:  # Player kills enemy head-on
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
	
	enemy.visible = false
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	enemies.erase(enemy)
	enemy_pool.append(enemy)  # Recycle; zero alloc stutter
	for seg in enemy.body_segments:
		seg.queue_free()
	enemy.body_segments.clear()
	enemy.queue_free()
	enemies.erase(enemy)
	spawn_enemy()

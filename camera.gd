extends Camera2D

@onready var snake_head = $"../SnakeHead"  # Adjust path if needed

func _physics_process(_delta):
	global_position = snake_head.global_position

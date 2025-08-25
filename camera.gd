extends Camera2D

@onready var player_snake: Area2D = $"../PlayerSnake"

func _physics_process(_delta):
	global_position = player_snake.global_position

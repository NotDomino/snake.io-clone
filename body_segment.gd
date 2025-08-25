extends Area2D

var snake: Node = null  # Owner ref for collision checks; web-light null check

func _ready():
	modulate.a = 0.8  # Slight transparency for depth illusion in long chains, zero-cost tint

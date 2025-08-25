extends Area2D

@onready var sprite = $Sprite2D

func _ready():
	var tween = create_tween().set_loops().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "modulate:a", 0.6, 1.0)
	tween.tween_property(sprite, "modulate:a", 1.0, 1.0)

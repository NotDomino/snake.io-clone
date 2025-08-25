extends CanvasLayer

@onready var score_label = $Score
@onready var snake_head: Area2D = $"../SnakeHead"

func _process(_delta):
	score_label.text = "Length: %d" % (snake_head.body_segments.size() + 1)
	score_label.modulate = Color(1,1,1, sin(Time.get_ticks_msec() * 0.001) * 0.2 + 0.8)  # Subtle pulse for playful UI glow, zero extra draw calls

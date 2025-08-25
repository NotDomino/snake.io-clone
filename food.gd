class_name Food
extends Area2D

@onready var white_inner_circle: Sprite2D = $WhiteInnerCircle
@onready var white_circle_ring: Sprite2D = $WhiteCircleRing

var initial_pos: Vector2
var wiggle_phase: float = randf() * TAU  # Random start per food for desync variety
var wiggle_speed: float = randf_range(1.0, 2.0)  # Per-food variance; playful without perf hit

var food_value: int = 1  # Growth worth; web-opt int math

func _ready():
	add_to_group("Food")
	var new_colour := Color(randf_range(0.8,1), randf_range(0.8,1), randf_range(0.8,1))
	white_inner_circle.modulate = new_colour  # Pastel variety for playful dots; zero-cost
	white_circle_ring.modulate = new_colour
	
	scale *= (1 + food_value * 0.2)  # Bigger for higher worth; playful visual cue, zero extra draw cost

	
	modulate.a = 0.0  # Start faded for appear_tween; zero-cost
	var base_color = new_colour  # Cache for glow pulse without override
	var low_color = base_color * 0.7  # Dim tint for brightness pulse
	var high_color = base_color  # Full tint
	initial_pos = position
	scale = Vector2(randf_range(0.8,1.2), randf_range(0.8,1.2))  # Varied sizes for playful scatter; zero-draw overhead
	
	var appear_tween = create_tween()
	appear_tween.tween_property(self, "modulate:a", 1.0, 0.5)  # Fade in on spawn
	
	var glow_tween = create_tween().set_loops().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	glow_tween.tween_property(white_inner_circle, "modulate", low_color, 0.8)
	glow_tween.parallel().tween_property(white_circle_ring, "modulate", low_color, 0.8)
	glow_tween.tween_property(white_inner_circle, "modulate", high_color, 0.8)
	glow_tween.parallel().tween_property(white_circle_ring, "modulate", high_color, 0.8)


func _process(delta):
	position = (initial_pos + Vector2(
	sin(Time.get_ticks_msec() * 0.001 + wiggle_phase * 0.5),
	cos(Time.get_ticks_msec() * 0.001 + wiggle_phase * 0.5)) * 3  # Balanced firefly bob
			)
	

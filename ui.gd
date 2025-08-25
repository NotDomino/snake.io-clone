extends CanvasLayer

@onready var score_label: Label = %Score
@onready var total_score: Label = %"Total Score"
@onready var snake_length: Label = %SnakeLength
@onready var player_snake: Area2D = $"../PlayerSnake"
@onready var fps: Label = %FPS
@onready var leaderboard: VBoxContainer = %Leaderboard

func _process(_delta):
	score_label.modulate = Color(1,1,1, sin(Time.get_ticks_msec() * 0.001) * 0.2 + 0.8)  # Subtle pulse for playful UI glow, zero extra draw calls
	snake_length.text = "Snake Length: %d" % (player_snake.body_segments.size() + 1)
	score_label.text = "Score: %d" % (player_snake.points)
	total_score.text = "Total Score: %d" % (player_snake.total_points)
	fps.text = str(Engine.get_frames_per_second())
	
	for child in leaderboard.get_children():
		child.queue_free()  # Clear; web-mem opt over hide
	for i in get_parent().leaderboard.size():
		var entry = Label.new()
		var lb = get_parent().leaderboard[i]
		entry.text = "%d. %s: %d" % [i+1, lb[1], lb[2]]
		entry.modulate = Color(1 - i*0.2, 1, 1 - i*0.2)  # Gold to silver fade for playful rank vibe
		leaderboard.add_child(entry)

extends Node3D

@onready var video_player: VideoStreamPlayer = $SubViewport/VideoStreamPlayer
@onready var sprite: Sprite3D = $Sprite3D

@export var video_stream: VideoStream:
	set(value):
		video_stream = value
		if is_inside_tree() and video_player:
			video_player.stream = value
			video_player.play()

var max_pos: float = 0.0

func _ready():
	if video_stream:
		video_player.stream = video_stream
	video_player.play()
	# Ensure the player doesn't start with a giant gray box
	sprite.visible = false
	video_player.finished.connect(_on_video_finished)

func _process(_delta):
	# Track max position to find the "middle" for looping
	if video_player.is_playing():
		max_pos = max(max_pos, video_player.stream_position)
		
	var tex = video_player.get_video_texture()
	if tex and tex.get_width() > 0:
		sprite.texture = tex
		
		# Set the shader parameter
		var mat = sprite.material_override as ShaderMaterial
		if mat:
			mat.set_shader_parameter("tex", tex)

		# Only show after a valid texture is produced
		if not sprite.visible:
			sprite.visible = true
	
	# Fallback loop
	if video_player.is_playing() == false:
		_on_video_finished()

func _on_video_finished():
	video_player.play()
	# Loop from middle if requested by the user
	if max_pos > 0.1:
		video_player.stream_position = max_pos / 2.0

func play_video(stream: VideoStream):
	if video_player.stream != stream:
		video_player.stream = stream
		video_player.play()

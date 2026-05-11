@tool
extends Sprite3D

@export var frame_path: String = "res://sprites/walking-fast-seq/"
@export var frame_prefix: String = "ezgif-frame-"
@export var frame_count: int = 240
@export var fps: float = 30.0
@export var playing: bool = false
@export var loop: bool = true

var frames: Array[Texture2D] = []
var current_frame_idx: float = 0.0

func _ready():
	load_frames()

func load_frames():
	frames.clear()
	print("SequenceSprite: Loading frames from ", frame_path)
	for i in range(1, frame_count + 1):
		var frame_num = str(i).pad_zeros(3)
		var full_path = frame_path + frame_prefix + frame_num + ".png"
		
		# ResourceLoader is better for caching
		if ResourceLoader.exists(full_path):
			var tex = load(full_path)
			if tex:
				frames.append(tex)
			else:
				break
		else:
			break
	
	if frames.size() > 0:
		texture = frames[0]
		var mat = material_override as ShaderMaterial
		if mat:
			mat.set_shader_parameter("tex", texture)
		print("SequenceSprite: Loaded ", frames.size(), " frames successfully.")
	else:
		printerr("SequenceSprite ERROR: No frames found at ", frame_path)

func _process(delta):
	# Allow animation in editor if playing is true
	if playing and frames.size() > 0:
		current_frame_idx += delta * fps
		if current_frame_idx >= frames.size():
			if loop:
				current_frame_idx = fmod(current_frame_idx, float(frames.size()))
			else:
				current_frame_idx = frames.size() - 1
				playing = false
		
		var idx = int(current_frame_idx)
		if idx < frames.size() and texture != frames[idx]:
			texture = frames[idx]
			# Also update the shader parameter if using the chroma key shader
			var mat = material_override as ShaderMaterial
			if mat:
				mat.set_shader_parameter("tex", texture)

func play():
	playing = true

func pause():
	playing = false

func stop():
	playing = false
	current_frame_idx = 0.0
	if frames.size() > 0:
		texture = frames[0]

extends Sprite3D

@export_group("Tilt Settings")
@export var enabled: bool = true
@export var min_distance: float = 2.0
@export var max_distance: float = 40.0   # Increased range for "far side"
@export var tilt_strength: float = 1.0 
@export var max_tilt_deg: float = 10.0    # Reduced strength as requested
@export var base_tilt_deg: float = 0.0

var initial_rotation_x: float

func _ready():
	initial_rotation_x = rotation.x

func _process(_delta):
	if not enabled:
		return
		
	var viewport = get_viewport()
	if not viewport:
		return
		
	var camera = viewport.get_camera_3d()
	if not camera:
		return
		
	var dist = global_position.distance_to(camera.global_position)
	
	# Determine if camera is in front or behind the sprite's plane
	var sprite_forward = global_transform.basis.z 
	var to_camera = (camera.global_position - global_position).normalized()
	var dot = sprite_forward.dot(to_camera)
	
	# Distance factor (0 far, 1 close)
	var t = 1.0 - clamp((dist - min_distance) / (max_distance - min_distance), 0.0, 1.0)
	
	# Tilt away from camera: 
	# If dot > 0 (front), tilt top away (positive X rotation)
	# If dot < 0 (behind), tilt top away (negative X rotation)
	var tilt_amount = t * deg_to_rad(max_tilt_deg) * tilt_strength * sign(dot)
	
	# Flip direction if the user says it's wrong (trying -sign for now)
	# Actually, I'll use -sign(dot) to see if that's what they meant by "wrong direction"
	rotation.x = initial_rotation_x - tilt_amount

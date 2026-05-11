@tool
extends CharacterBody3D

const SPEED = 9.0
const JUMP_VELOCITY = 15.0
const GRAVITY_MULTIPLIER = 3.5

@export_category("Camera Settings")
@export var camera_offset: Vector3 = Vector3(0, 8, 14)
@export_range(-90.0, 0.0) var camera_pitch: float = -30.0

@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var sequence_sprite = $SequenceSprite
@onready var walking_audio = $WalkingAudio

var current_animation: String = ""

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	# Video sprite logic removed as requested
	pass

func _physics_process(delta):
	if Engine.is_editor_hint():
		return
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * GRAVITY_MULTIPLIER * delta

	# Handle Jump.
	if Input.is_physical_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	var input_dir = Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W): input_dir.y -= 1
	if Input.is_physical_key_pressed(KEY_S): input_dir.y += 1
	if Input.is_physical_key_pressed(KEY_A): input_dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D): input_dir.x += 1
	
	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
		
	# 3D movement is along the X and Z axes
	var direction = Vector3(input_dir.x, 0, input_dir.y)
	
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		
		# For a 2D sprite, we flip it instead of rotating the whole node
		if sequence_sprite:
			if direction.x < -0.1:
				sequence_sprite.flip_h = true
			elif direction.x > 0.1:
				sequence_sprite.flip_h = false
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	update_sprite_state(direction.length() > 0.1)

func update_sprite_state(is_moving_input: bool):
	if not sequence_sprite:
		return
		
	# Use input as primary, but also check velocity if we want it to stop when hitting walls
	# For now, input-only is better for "letting go of keys" problem.
	var is_moving = is_moving_input
	
	if is_moving:
		if not sequence_sprite.playing:
			sequence_sprite.play()
		if walking_audio and not walking_audio.playing:
			walking_audio.play()
	else:
		if sequence_sprite.playing:
			sequence_sprite.stop()
		if walking_audio and walking_audio.playing:
			walking_audio.stop()

func _process(_delta):
	if camera:
		camera.position = camera_offset
		camera.rotation_degrees.x = camera_pitch

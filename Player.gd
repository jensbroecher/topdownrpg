@tool
extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 6.36

@export_category("Camera Settings")
@export var camera_offset: Vector3 = Vector3(0, 8, 14)
@export_range(-90.0, 0.0) var camera_pitch: float = -30.0

@onready var camera: Camera3D = $CameraPivot/Camera3D

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _physics_process(delta):
	if Engine.is_editor_hint():
		return
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

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
		
		# Make the player model face the direction of movement
		var look_target = position - direction
		if position.distance_to(look_target) > 0.001:
			var target_transform = transform.looking_at(look_target, Vector3.UP)
			# Only rotate the mesh, not the camera. Assuming MeshInstance3D is a child named "MeshInstance3D"
			var mesh = get_node_or_null("Elf")
			if mesh:
				var current_quat = mesh.quaternion
				var target_quat = Quaternion(target_transform.basis)
				mesh.quaternion = current_quat.slerp(target_quat, 10.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

func _process(_delta):
	if camera:
		camera.position = camera_offset
		camera.rotation_degrees.x = camera_pitch

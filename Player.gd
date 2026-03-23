@tool
extends CharacterBody3D

const SPEED = 9.0
const JUMP_VELOCITY = 15.0
const GRAVITY_MULTIPLIER = 3.5

@export_category("Camera Settings")
@export var camera_offset: Vector3 = Vector3(0, 8, 14)
@export_range(-90.0, 0.0) var camera_pitch: float = -30.0

@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var animation_player: AnimationPlayer = $Elf/AnimationPlayer if has_node("Elf/AnimationPlayer") else null

var current_animation: String = ""

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

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
	update_animations()

	if animation_player:
		create_custom_idle()
		print("Found AnimationPlayer on Elf. Available animations: ", animation_player.get_animation_list())
	else:
		print("Warning: No AnimationPlayer found on Elf node!")

func find_bone_path(bone_name: String) -> String:
	if not animation_player: return ""
	var skeleton = $Elf.find_child("Skeleton3D", true)
	if not skeleton: return ""
	
	var skeleton_path = animation_player.get_parent().get_path_to(skeleton)
	
	for i in range(skeleton.get_bone_count()):
		var name = skeleton.get_bone_name(i)
		# Case-insensitive fuzzy match
		if name.to_lower().contains(bone_name.to_lower()):
			return str(skeleton_path) + ":" + name
	return ""

func get_rest_quat(bone_name: String) -> Quaternion:
	var skeleton = $Elf.find_child("Skeleton3D", true)
	if not skeleton: return Quaternion()
	for i in range(skeleton.get_bone_count()):
		var name = skeleton.get_bone_name(i)
		if name.to_lower().contains(bone_name.to_lower()):
			return skeleton.get_bone_rest(i).basis.get_rotation_quaternion()
	return Quaternion()


func create_custom_idle():
	if not animation_player:
		return
		
	# Create a new animation for the idle pose
	var idle_anim = Animation.new()
	idle_anim.length = 1.0
	idle_anim.loop_mode = Animation.LOOP_LINEAR
	
	# Find Arm bones
	var l_arm = find_bone_path("LeftArm")
	var r_arm = find_bone_path("RightArm")
	
	# Rotate arms down, RELATIVE to rest_quat
	if l_arm != "":
		var track = idle_anim.add_track(Animation.TYPE_ROTATION_3D)
		idle_anim.track_set_path(track, l_arm)
		var rest = get_rest_quat("LeftArm")
		idle_anim.rotation_track_insert_key(track, 0.0, rest * Quaternion(Vector3(0, 0, 1), deg_to_rad(65.0)))
	
	if r_arm != "":
		var track = idle_anim.add_track(Animation.TYPE_ROTATION_3D)
		idle_anim.track_set_path(track, r_arm)
		var rest = get_rest_quat("RightArm")
		idle_anim.rotation_track_insert_key(track, 0.0, rest * Quaternion(Vector3(0, 0, 1), deg_to_rad(-65.0)))

	# Reset Legs to REST POSE (not Identity)
	for leg_name in ["LeftUpLeg", "RightUpLeg", "LeftLeg", "RightLeg"]:
		var leg_path = find_bone_path(leg_name)
		if leg_path != "":
			var track = idle_anim.add_track(Animation.TYPE_ROTATION_3D)
			idle_anim.track_set_path(track, leg_path)
			var rest = get_rest_quat(leg_name)
			idle_anim.rotation_track_insert_key(track, 0.0, rest)

	# Optional gentle head tilt up at rest (relative to rest pose)
	var head_path = find_bone_path("Head")
	if head_path == "": head_path = find_bone_path("Neck")
	if head_path != "":
		var track = idle_anim.add_track(Animation.TYPE_ROTATION_3D)
		idle_anim.track_set_path(track, head_path)
		var bone_name = "Head" if find_bone_path("Head") != "" else "Neck"
		var rest = get_rest_quat(bone_name)
		idle_anim.rotation_track_insert_key(track, 0.0, rest * Quaternion(Vector3(1, 0, 0), deg_to_rad(-15.0)))


	# Add to library
	var library = animation_player.get_animation_library("")
	if not library:
		library = AnimationLibrary.new()
		animation_player.add_animation_library("", library)
	
	# Remove old if exists
	if library.has_animation("idle_pose"):
		library.remove_animation("idle_pose")
	
	library.add_animation("idle_pose", idle_anim)


func update_animations():
	if not animation_player:
		return
		
	var is_moving = velocity.length() > 0.1
	var target_animation = ""
	
	if is_moving:
		# Try common movement animation names
		var moves = ["running", "Run", "mixamo.com", "Scene", "walk", "Walking", "Armature|adfdbf684181c5eb805e222e9ed2f87b_remap"]
		for anim in moves:
			if animation_player.has_animation(anim):
				target_animation = anim
				break
		
		# If still not found, just use the first available animation if it exists
		if target_animation == "" and animation_player.get_animation_list().size() > 0:
			target_animation = animation_player.get_animation_list()[0]
	else:
		# Try common idle animation names
		for anim in ["idle_pose", "idle", "Idle", "Static"]:
			if animation_player.has_animation(anim):
				target_animation = anim
				break
				
	if target_animation != "" and current_animation != target_animation:
		# Ensure movement animations are looping and fast
		var anim_res = animation_player.get_animation(target_animation)
		if is_moving and anim_res:
			anim_res.loop_mode = Animation.LOOP_LINEAR
			animation_player.speed_scale = 1.5 # Run faster
		else:
			animation_player.speed_scale = 1.0
			
		animation_player.play(target_animation, 0.2) # 0.2s blend time
		current_animation = target_animation

func _process(_delta):
	if camera:
		camera.position = camera_offset
		camera.rotation_degrees.x = camera_pitch

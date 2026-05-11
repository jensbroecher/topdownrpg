@tool
extends Node3D

@export var grass_count: int = 20000 : set = set_grass_count
@export var extents: Vector2 = Vector2(50, 50) : set = set_extents
@export var mesh_size: Vector2 = Vector2(0.4, 0.6) : set = set_mesh_size
@export var grass_texture: Texture2D = preload("res://sprites/grass_blade.png")
@export var grass_shader: Shader = preload("res://grass_blade.gdshader")

var multimesh_instance: MultiMeshInstance3D

func _ready():
	setup_grass()

func setup_grass():
	# Clean up existing
	if multimesh_instance:
		multimesh_instance.queue_free()
	
	for child in get_children():
		if child is MultiMeshInstance3D:
			child.queue_free()
			
	multimesh_instance = MultiMeshInstance3D.new()
	multimesh_instance.name = "GrassMultiMesh"
	add_child(multimesh_instance)
	
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = grass_count
	
	# Create a simple quad mesh for the blade
	var quad = QuadMesh.new()
	quad.size = mesh_size
	quad.center_offset = Vector3(0, mesh_size.y * 0.5, 0) # Base on ground
	
	var mat = ShaderMaterial.new()
	mat.shader = grass_shader
	mat.set_shader_parameter("texture_albedo", grass_texture)
	quad.material = mat
	
	mm.mesh = quad
	multimesh_instance.multimesh = mm
	
	# Find GridMap to check terrain
	var gridmap: GridMap = get_parent().get_node_or_null("GridMap")
	
	# Create noise for the organic bleed effect, matching the shader's frequency
	var noise = FastNoiseLite.new()
	noise.seed = 12345
	noise.frequency = 0.02 
	
	var rng = RandomNumberGenerator.new()
	rng.seed = 12345
	
	var visible_count = 0
	for i in range(grass_count):
		var pos = Vector3(
			rng.randf_range(-extents.x, extents.x),
			0,
			rng.randf_range(-extents.y, extents.y)
		)
		
		var is_on_grass = true
		
		# Check terrain if GridMap exists
		if gridmap:
			# Convert GrassSystem local 'pos' to GridMap local
			var local_pos = gridmap.to_local(global_transform * pos)
			
			# Scan Layers: Instead of a hardcoded height, we scan vertically
			# to find if there's a grass tile at this (X, Z).
			var found_grass = false
			var base_cell_pos = gridmap.local_to_map(local_pos)
			
			# Check layers from -10 to 10 (wide enough for common terrain)
			for ly in range(-10, 11):
				var cell_pos = Vector3i(base_cell_pos.x, ly, base_cell_pos.z)
				var item_id = gridmap.get_cell_item(cell_pos)
				
				if item_id == 0: # Grass
					is_on_grass = true
					found_grass = true
					# Use the tile's Y position to align grass height?
					# For now, keep simple but could add query_pos.y alignment here.
					break
			
			if !found_grass:
				is_on_grass = false
				
				# Refined Bleed: Only if VERY close to a grass tile and noise allows it
				var n_val = (noise.get_noise_2d(pos.x * 0.1, pos.z * 0.1) + 1.0) * 0.5
				
				if n_val > 0.7:
					# Check neighbors for grass in a 1-tile radius
					for dx in [-1, 0, 1]:
						for dz in [-1, 0, 1]:
							# We also need to scan layers for neighbors...
							# But let's check the current layer range we scanned
							for ly in range(-10, 11):
								if gridmap.get_cell_item(Vector3i(base_cell_pos.x + dx, ly, base_cell_pos.z + dz)) == 0:
									is_on_grass = true
									found_grass = true
									break
							if found_grass: break
						if found_grass: break
		
		# Skip if too close to center
		if pos.length() < 3.0: 
			is_on_grass = false
			
		if !is_on_grass:
			pos.y = -10.0 # Hide it
		else:
			visible_count += 1
			
		var basis = Basis().rotated(Vector3.UP, rng.randf_range(0, TAU))
		var scale_factor = rng.randf_range(0.8, 1.4)
		var transform = Transform3D(basis.scaled(Vector3(scale_factor, scale_factor, scale_factor)), pos)
		
		mm.set_instance_transform(i, transform)
	
	print("GrassSystem: Setup complete. Visible blades: ", visible_count)

func set_grass_count(val):
	grass_count = val
	if is_inside_tree(): setup_grass()

func set_extents(val):
	extents = val
	if is_inside_tree(): setup_grass()

func set_mesh_size(val):
	mesh_size = val
	if is_inside_tree(): setup_grass()

func _process(_delta):
	# The setup_grass will be called by setters in editor
	pass

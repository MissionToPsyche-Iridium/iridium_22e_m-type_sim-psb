extends MeshInstance3D

@export var hasPOI: bool = false
@export var poi_prefab: PackedScene
@export var scatter_count: int = 10
@export var poi_name: String = "Generic"
@export var poi_value: float = 100
@export var poi_material: BaseMaterial3D

func accept_mesh(surface_array: Array) -> void:
	mesh = ArrayMesh.new()
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
	genCollisions()

func runScatter() -> void:
	if hasPOI and poi_prefab:
		# Get mesh data
		var arrays = mesh.surface_get_arrays(0)
		if arrays.is_empty():
			printerr("Mesh arrays are empty, cannot place POI.")
			return
		var vertices = arrays[Mesh.ARRAY_VERTEX]
		var indices = arrays[Mesh.ARRAY_INDEX]

		if indices.is_empty():
			printerr("Mesh indices are empty, cannot place POI.")
			return
			
		if indices.size() % 3 != 0:
			printerr("Indices size is not a multiple of 3, cannot determine triangles.")
			return
		
		for i in range(scatter_count):
			# Select a random triangle
			var triangle_index = randi() % (indices.size() / 3)
			var i1 = indices[triangle_index * 3]
			var i2 = indices[triangle_index * 3 + 1]
			var i3 = indices[triangle_index * 3 + 2]

			if max(i1, i2, i3) >= vertices.size():
				printerr("Index out of bounds for vertices array.")
				return

			var v1 = vertices[i1]
			var v2 = vertices[i2]
			var v3 = vertices[i3]

			# Calculate random point using barycentric coordinates
			var u = randf()
			var v = randf()
			if u + v > 1.0:
				u = 1.0 - u
				v = 1.0 - v
			var random_local_point = v1 + u * (v2 - v1) + v * (v3 - v1)

			# Instantiate and position POI
			var poi_instance = poi_prefab.instantiate()
			add_child(poi_instance) # Add as child first to have proper transform parent

			poi_instance.set_script(load("res://script/poi.gd"))

			poi_instance.add_to_group("poi_marker")

			poi_instance.poi_name = poi_name
			poi_instance.poi_value = poi_value

			poi_instance.get_node("Icosphere").set_material_override(poi_material)
			
			var random_scale = randf_range(0.3, 1.0)
			poi_instance.scale = Vector3(random_scale, random_scale, random_scale)
			poi_instance.rotation = Vector3(randf_range(0, 360), randf_range(0, 360), randf_range(0, 360))
			poi_instance.global_position = to_global(random_local_point)

func genCollisions() -> void:
	var static_body = $StaticBody3D

	var collision_shape = static_body.get_node("CollisionShape3D")
	
	if not static_body.get_node_or_null("StaticBody3D"):
		collision_shape = CollisionShape3D.new()
		static_body.add_child(collision_shape)
	
	var shape = ConcavePolygonShape3D.new()
	var arrays = mesh.surface_get_arrays(0)
	var vertices = arrays[Mesh.ARRAY_VERTEX]
	var indices = arrays[Mesh.ARRAY_INDEX]
	
	# Create faces array
	var faces = []
	for i in range(0, indices.size(), 3):
		faces.append(vertices[indices[i]])
		faces.append(vertices[indices[i + 1]])
		faces.append(vertices[indices[i + 2]])
	
	shape.set_faces(faces)
	collision_shape.shape = shape

func _ready() -> void:
	randomize() # Seed the random number generator

func _process(_delta: float) -> void:
	pass

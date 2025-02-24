extends MeshInstance3D

func accept_mesh(surface_array: Array) -> void:
	mesh = ArrayMesh.new()
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
	genCollisions()

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
	pass

func _process(_delta: float) -> void:
	pass

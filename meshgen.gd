extends MeshInstance3D

signal regen_mesh

var size = 200  # Size of the plane
var segments = 400  # Number of segments in each direction

func meshRegen() -> void:
	print("regenerating")
	var texture = NoiseTexture2D.new()
	texture.noise = FastNoiseLite.new()
	texture.noise.seed = randi()
	await texture.changed
	var image = texture.get_image()
	
	var surface_array = []
	surface_array.resize(Mesh.ARRAY_MAX)
	
	var verts = PackedVector3Array()
	var uvs = PackedVector2Array()
	var normals = PackedVector3Array()
	var indices = PackedInt32Array()

	# Create vertices
	for i in range(segments + 1):
		for j in range(segments + 1):
			var x = float(j) / segments * size - size/2
			var z = float(i) / segments * size - size/2
			
			# Sample noise texture for height
			var u = float(j) / segments
			var v = float(i) / segments
			var height = image.get_pixel(
				u * (image.get_width() - 1), 
				v * (image.get_height() - 1)
			).r

			var vert = Vector3(x, height * 20.0, z)  # Multiply height by 5.0 for more pronounced effect
			verts.append(vert)
			uvs.append(Vector2(u, v))
			normals.append(Vector3(0, 1, 0))  # Simple normal pointing up

	# Create triangles
	for i in range(segments):
		for j in range(segments):
			var current = i * (segments + 1) + j
			var next = current + 1
			var bottom = current + (segments + 1)
			var bottom_next = bottom + 1

			# First triangle
			indices.append(current)
			indices.append(next)
			indices.append(bottom)

			# Second triangle
			indices.append(next)
			indices.append(bottom_next)
			indices.append(bottom)

	surface_array[Mesh.ARRAY_VERTEX] = verts
	surface_array[Mesh.ARRAY_TEX_UV] = uvs
	surface_array[Mesh.ARRAY_NORMAL] = normals
	surface_array[Mesh.ARRAY_INDEX] = indices
	# Clear any existing surfaces
	if mesh:
		mesh.clear_surfaces()

	# Add the new surface
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
	
	genCollisions()
	
	var rigid_body = get_node("/root").find_child("TestBall", true, false)
	rigid_body.position = Vector3(randf() * 20, 30, randf() * 20)
	
	var camera = get_node("/root").find_child("Camera3D", true, false)
	camera.position = Vector3(rigid_body.position.x + 30, camera.position.y, rigid_body.position.z)

func genCollisions() -> void:
	var static_body = $StaticBody3D
	
	if not static_body.get_node_or_null("StaticBody3D"):
		var collision_shape = CollisionShape3D.new()
		static_body.add_child(collision_shape)
	
	var collision_shape = static_body.get_node("CollisionShape3D")
	
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
	mesh = ArrayMesh.new()
	regen_mesh.connect(meshRegen)
	regen_mesh.emit()

func _process(_delta: float) -> void:
	pass

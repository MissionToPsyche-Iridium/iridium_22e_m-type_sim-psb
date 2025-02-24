extends Node3D

const MESH_SIZE = 64  # Size of each mesh_gen
const MESH_SEGMENTS = 64  # Number of segments in each direction
const VIEW_DISTANCE = 16  # How many meshes to load in each direction

var mesh_scene = preload("res://scene/prefab/mesh_gen.tscn")

@export var noise: FastNoiseLite
@export var noise_amplitude: float
@export var noise_scale: float
# the real amount is 6250
@export var psyche_radius = MESH_SIZE * 10

var current_meshes = {}
var player: Node3D

var max_queued_generations = 250
var max_instantiations_per_frame = 4

var generation_queue = []
var finished_meshes = {}

var generation_mutex: Mutex
var finished_mutex: Mutex
var exit_mutex: Mutex

var generation_thread: Thread
var exit_thread: bool = false

func generate_mesh(chunk_position: Vector2i) -> Array:
	var surface_array = []
	surface_array.resize(Mesh.ARRAY_MAX)
	
	noise.seed = 6408
	
	var verts = PackedVector3Array()
	var uvs = PackedVector2Array()
	var normals = PackedVector3Array()
	var indices = PackedInt32Array()

	# Create vertices
	for i in range(MESH_SEGMENTS + 1):
		for j in range(MESH_SEGMENTS + 1):
			# Calculate exact positions at chunk boundaries
			var x = (float(j) * MESH_SIZE / MESH_SEGMENTS) - (MESH_SIZE / 2.0)
			var z = (float(i) * MESH_SIZE / MESH_SEGMENTS) - (MESH_SIZE / 2.0)
			
			var world_x = x + (chunk_position.x * MESH_SIZE)
			var world_z = z + (chunk_position.y * MESH_SIZE)
			
			var height = noise.get_noise_2d(world_x, world_z) * noise_amplitude

			var flat_distance = sqrt(world_x * world_x + world_z * world_z) + 0.0001 # avoid division by zero
			var theta = flat_distance / psyche_radius
			var phi = atan2(world_z, world_x)

			var point_on_sphere = Vector3(
				cos(phi) * sin(theta),
				cos(theta),
				sin(phi) * sin(theta)
			) * psyche_radius
			
			var normal = point_on_sphere.normalized()
			
			var vert = point_on_sphere + (normal * height) - Vector3(chunk_position.x * MESH_SIZE, 0, chunk_position.y * MESH_SIZE)
			verts.append(vert)
			uvs.append(Vector2(world_x * noise_scale, world_z * noise_scale))
			normals.append(normal)

	# Create triangles
	for i in range(MESH_SEGMENTS):
		for j in range(MESH_SEGMENTS):
			var current = i * (MESH_SEGMENTS + 1) + j
			var next = current + 1
			var bottom = current + (MESH_SEGMENTS + 1)
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

	return surface_array

func _ready() -> void:
	player = get_parent().get_node("Craft")
	if not player:
		push_error("Player node not found!")
	
	player.position = Vector3(0, psyche_radius + 100, 0)
	
	generation_mutex = Mutex.new()
	finished_mutex = Mutex.new()
	exit_mutex = Mutex.new()

	generation_thread = Thread.new()
	generation_thread.start(generation_main)

func _process(_delta: float) -> void:
	update_meshes()

func generation_main() -> void:
	while true:
		exit_mutex.lock()
		if exit_thread:
			exit_mutex.unlock()
			break
		exit_mutex.unlock()

		generation_mutex.lock()
		if generation_queue.size() == 0:
			generation_mutex.unlock()
			continue
		
		var chunk_position = generation_queue.pop_front()
		generation_mutex.unlock()

		var surface = generate_mesh(chunk_position)
		finished_mutex.lock()
		finished_meshes[chunk_position] = surface
		finished_mutex.unlock()

func update_meshes() -> void:
	if not player:
		return
		
	var player_mesh_x = floor(player.global_position.x / MESH_SIZE)
	var player_mesh_z = floor(player.global_position.z / MESH_SIZE)
	
	# create list of chunks to generate
	var chunks_to_process = []
	for dx in range(-VIEW_DISTANCE, VIEW_DISTANCE + 1):
		for dz in range(-VIEW_DISTANCE, VIEW_DISTANCE + 1):
			var chunk_pos = Vector2i(player_mesh_x + dx, player_mesh_z + dz)
			
			# Calculate the center point of this chunk in world space
			var chunk_center_x = (chunk_pos.x * MESH_SIZE)
			var chunk_center_z = (chunk_pos.y * MESH_SIZE)
			
			# Calculate the angular distance from the center
			var flat_distance = sqrt(chunk_center_x * chunk_center_x + chunk_center_z * chunk_center_z)
			var theta = flat_distance / psyche_radius
			
			# Skip chunks that would wrap around the sphere (more than 180 degrees)
			if theta >= PI:
				continue
			
			# Calculate squared distance for sorting
			var dist_sq = dx*dx + dz*dz
			if dist_sq > VIEW_DISTANCE*VIEW_DISTANCE:
				continue
			
			chunks_to_process.append({"pos": chunk_pos, "dist": dist_sq})
	
	# sort chunks by distance from player
	chunks_to_process.sort_custom(func(a, b): return a["dist"] < b["dist"])
	
	# add to generation queue in order
	if generation_mutex.try_lock():
		for chunk in chunks_to_process:
			if generation_queue.size() >= max_queued_generations:
				break

			var mesh_key = chunk["pos"]
			if not current_meshes.has(mesh_key) and not generation_queue.has(mesh_key):
				generation_queue.append(mesh_key)
		generation_mutex.unlock()
	
	# add finished meshes to current meshes
	if finished_mutex.try_lock():
		var processed_this_frame = 0
		for chunk_position in finished_meshes.keys():
			if not current_meshes.has(chunk_position):
				current_meshes[chunk_position] = mesh_scene.instantiate()
				current_meshes[chunk_position].accept_mesh(finished_meshes[chunk_position])
				current_meshes[chunk_position].position = Vector3(chunk_position.x * MESH_SIZE, 0, chunk_position.y * MESH_SIZE)
				add_child(current_meshes[chunk_position])

				processed_this_frame += 1
				if processed_this_frame >= max_instantiations_per_frame:
					break

			finished_meshes.erase(chunk_position)
		
		finished_mutex.unlock()
	
	# unload meshes that are too far away
	for chunk_position in current_meshes.keys():
		if chunk_position.distance_to(Vector2i(player_mesh_x, player_mesh_z)) > VIEW_DISTANCE:
			current_meshes[chunk_position].queue_free()
			current_meshes.erase(chunk_position)

func _exit_tree():
	exit_mutex.lock()
	exit_thread = true
	exit_mutex.unlock()

	generation_thread.wait_to_finish()

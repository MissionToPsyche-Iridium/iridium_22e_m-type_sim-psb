extends Node

@onready var list = [$"VBoxContainer/POI1", $"VBoxContainer/POI2", $"VBoxContainer/POI3", $"VBoxContainer/POI4"]
@onready var craft = $"../Craft"
@onready var take_sample_button = $"VBoxContainer/Take Sample"
var popupTime: float = 0
var updateTime: float = 0

var points: float = 0
var times_sampled: Dictionary = {}

func _process(_delta: float) -> void:
	$"VBoxContainer/Points".text = "Points: %.2f" % points
	if updateTime < 0.1:
		updateTime += _delta
		return
	
	updateTime = 0

	var pois = get_tree().root.get_tree().get_nodes_in_group("poi_marker")
	pois.sort_custom(func(a, b): return a.global_position.distance_to(craft.global_position) < b.global_position.distance_to(craft.global_position))

	if popupTime > 0:
		$"../SamplePopup".visible = true
		popupTime -= _delta
	else:
		$"../SamplePopup".visible = false
		popupTime = 0

	var filtered_pois = []
	var seen_parents = {}

	for poi in pois:
		var parent = poi.get_parent()
		if not seen_parents.has(parent) and poi.visible:
			filtered_pois.append(poi)
			seen_parents[parent] = true

	for i in range(list.size()):
		if i < filtered_pois.size():
			var poi = filtered_pois[i]
			var distance = poi.global_position.distance_to(craft.global_position)
			list[i].text = str(poi.poi_name) + " (%.2fm)" % distance
		else:
			list[i].text = ""
	
	if pois.size() < 1:
		return
	
	if craft.lock_controls:
		take_sample_button.text = "L.O.S."
		take_sample_button.disabled = true
		return
	
	if craft.animation_time != 0:
		return

	var distance = pois[0].global_position.distance_to(craft.global_position)
	if distance < 10:
		if craft.linear_velocity.length() < 0.1:
			if is_craft_grounded():
				take_sample_button.text = "Take Sample"
				take_sample_button.disabled = false
			else:
				take_sample_button.text = "Not grounded"
				take_sample_button.disabled = true
		else:
			take_sample_button.text = "Moving too fast"
			take_sample_button.disabled = true
	else:
		take_sample_button.text = "Too far away"
		take_sample_button.disabled = true

func decay_times_sampled(base_value: float, name: String) -> float:
	var decay_rate: float = 0.5  # Value multiplier for each sample taken
	var n_samples: int = times_sampled.get(name, 0) # Get number of times this POI was sampled
	var decayed_value: float = base_value * pow(decay_rate, n_samples) # Apply exponential decay
	return decayed_value

func is_craft_grounded() -> bool:
	var space_state = craft.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		craft.global_position,					# from
		craft.global_position + Vector3.DOWN * 2,  # to (10 units down)
		craft.collision_mask,					 # collision mask (optional)
		[craft]							 # array of objects to exclude
	)
	var result = space_state.intersect_ray(query)
	
	if result:
		return true
	return false

func _on_take_sample_pressed() -> void:
	var pois = get_tree().root.get_tree().get_nodes_in_group("poi_marker")
	pois.sort_custom(func(a, b): return a.global_position.distance_to(craft.global_position) < b.global_position.distance_to(craft.global_position))

	var closest
	for poi in pois:
		if poi.visible:
			closest = poi
			break

	var distance = closest.global_position.distance_to(craft.global_position)
	if is_craft_grounded() and craft.linear_velocity.length() < 0.1 and distance < 10:
		var success = func(): 
			take_sample_button.text = "Take Sample"
			take_sample_button.disabled = false
			popupTime = 1
			points += decay_times_sampled(closest.poi_value, closest.poi_name)
			times_sampled[closest.poi_name] = times_sampled.get(closest.poi_name, 0) + 1
			closest.visible = false
		
		var fail = func():
			take_sample_button.text = "Take Sample"
			take_sample_button.disabled = false
			popupTime = 0

		take_sample_button.text = "Sampling..."
		take_sample_button.disabled = true
		craft.startAnimation(success, fail)

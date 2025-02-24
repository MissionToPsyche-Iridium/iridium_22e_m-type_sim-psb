shader_type spatial;

uniform sampler3D noise;

void vertex() {
	vec4 height = texture(noise, VERTEX / 10.0) * 2.0;
	height.y *= 1.1;
  	VERTEX += NORMAL * height.xyz;
}

void fragment() {
	vec4 world = INV_VIEW_MATRIX * vec4(VERTEX, 1.0);
	vec4 sample = texture(noise, world.xyz / 10.0 + 0.5);
	vec4 height = texture(noise, world.xyz / 10.0) * 2.0;

	ALBEDO = vec3(height.x, height.y, height.z);
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}

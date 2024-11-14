shader_type spatial;

uniform sampler2D noise;

void vertex() {
	float height = texture(noise, VERTEX.xz / 10.0 + 0.5).x;
  	VERTEX.y += height;
}

void fragment() {
	// Called for every pixel the material is visible on.
	vec4 world = INV_VIEW_MATRIX * vec4(VERTEX, 1.0);
	
	vec4 sample = texture(noise, world.xz / 10.0 + 0.5);
	
	ALBEDO = vec3(sample.x, sample.x, sample.x);
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}

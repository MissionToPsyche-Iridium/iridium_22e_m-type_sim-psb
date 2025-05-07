shader_type spatial;
render_mode blend_mix,cull_back,diffuse_burley,specular_schlick_ggx
;
uniform vec3 uv1_offset = vec3(0.0, 0.0, 0.0);
uniform vec3 uv1_scale = vec3(1.0, 1.0, 1.0);
uniform int depth_min_layers = 8;
uniform int depth_max_layers = 16;
uniform vec2 depth_flip = vec2(1.0);
uniform float variation = 0.0;
varying float elapsed_time;
void vertex() {
	elapsed_time = TIME;
	UV = UV*uv1_scale.xy+uv1_offset.xy;
}
float rand(vec2 x) {
    return fract(cos(mod(dot(x, vec2(13.9898, 8.141)), 3.14)) * 43758.5453);
}
vec2 rand2(vec2 x) {
    return fract(cos(mod(vec2(dot(x, vec2(13.9898, 8.141)),
						      dot(x, vec2(3.4562, 17.398))), vec2(3.14))) * 43758.5453);
}
vec3 rand3(vec2 x) {
    return fract(cos(mod(vec3(dot(x, vec2(13.9898, 8.141)),
							  dot(x, vec2(3.4562, 17.398)),
                              dot(x, vec2(13.254, 5.867))), vec3(3.14))) * 43758.5453);
}
float param_rnd(float minimum, float maximum, float seed) {
	return minimum+(maximum-minimum)*rand(vec2(seed));
}
vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = c.g < c.b ? vec4(c.bg, K.wz) : vec4(c.gb, K.xy);
	vec4 q = c.r < p.x ? vec4(p.xyw, c.r) : vec4(c.r, p.yzx);
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}
vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}
float perlin(vec2 uv, vec2 size, int iterations, float persistence, float seed) {
	vec2 seed2 = rand2(vec2(seed, 1.0-seed));
	float rv = 0.0;
	float coef = 1.0;
	float acc = 0.0;
	for (int i = 0; i < iterations; ++i) {
		vec2 step = vec2(1.0)/size;
		vec2 xy = floor(uv*size);
		float f0 = rand(seed2+mod(xy, size));
		float f1 = rand(seed2+mod(xy+vec2(1.0, 0.0), size));
		float f2 = rand(seed2+mod(xy+vec2(0.0, 1.0), size));
		float f3 = rand(seed2+mod(xy+vec2(1.0, 1.0), size));
		vec2 mixval = smoothstep(0.0, 1.0, fract(uv*size));
		rv += coef * mix(mix(f0, f1, mixval.x), mix(f2, f3, mixval.x), mixval.y);
		acc += coef;
		size *= 2.0;
		coef *= persistence;
	}

	return rv / acc;
}
float wavelet(vec2 uv, vec2 size, float s, float frequency, float offset) {
	uv = mod(uv, size);
	vec2 seed = fract(floor(uv)*0.1236754+vec2(s));
	uv = fract(uv);
	vec2 ruv = uv-0.5;
	float a = rand(seed)*6.28;
	float ca = cos(a);
	float sa = sin(a);
	ruv = vec2(ca*ruv.x + sa*ruv.y, -sa*ruv.x + ca*ruv.y);
	return (0.5*sin(ruv.x*6.28*frequency+offset)+0.5)*max(0.0, 1.0-2.0*length(uv-vec2(0.5)));
}
float wavelet_noise(vec2 uv, vec2 size, int iterations, float persistence, float seed, float frequency, float offset, float type) {
	float rv = 0.0;
	float acc = 0.0;
	vec2 seed2 = rand2(vec2(seed));
	vec2 local_uv = uv * size;
	float q = 1.0;
	for (int i = 0; i < iterations; ++i) {
		rv += q*wavelet(local_uv, size, seed, frequency, offset);
		rv += q*wavelet(local_uv+vec2(0.5), size, seed+0.1, frequency, offset);
		acc += q;
		if (type > 0.0) {
			local_uv += type*uv;
			size += vec2(type);
		} else {
			local_uv *= -type;
			size *= -type;
		}
		local_uv += seed2;
		seed2 = rand2(seed2);
		q *= persistence;
		seed += 0.1;
	}
	return rv / acc;
}
vec3 blend_normal(vec2 uv, vec3 c1, vec3 c2, float opacity) {
	return opacity*c1 + (1.0-opacity)*c2;
}
vec3 blend_dissolve(vec2 uv, vec3 c1, vec3 c2, float opacity) {
	if (rand(uv) < opacity) {
		return c1;
	} else {
		return c2;
	}
}
vec3 blend_multiply(vec2 uv, vec3 c1, vec3 c2, float opacity) {
	return opacity*c1*c2 + (1.0-opacity)*c2;
}
vec3 blend_screen(vec2 uv, vec3 c1, vec3 c2, float opacity) {
	return opacity*(1.0-(1.0-c1)*(1.0-c2)) + (1.0-opacity)*c2;
}
float blend_overlay_f(float c1, float c2) {
	return (c1 < 0.5) ? (2.0*c1*c2) : (1.0-2.0*(1.0-c1)*(1.0-c2));
}
vec3 blend_overlay(vec2 uv, vec3 c1, vec3 c2, float opacity) {
	return opacity*vec3(blend_overlay_f(c1.x, c2.x), blend_overlay_f(c1.y, c2.y), blend_overlay_f(c1.z, c2.z)) + (1.0-opacity)*c2;
}
vec3 blend_hard_light(vec2 uv, vec3 c1, vec3 c2, float opacity) {
	return opacity*0.5*(c1*c2+blend_overlay(uv, c1, c2, 1.0)) + (1.0-opacity)*c2;
}
float blend_soft_light_f(float c1, float c2) {
	return (c2 < 0.5) ? (2.0*c1*c2+c1*c1*(1.0-2.0*c2)) : 2.0*c1*(1.0-c2)+sqrt(c1)*(2.0*c2-1.0);
}
vec3 blend_soft_light(vec2 uv, vec3 c1, vec3 c2, float opacity) {
	return opacity*vec3(blend_soft_light_f(c1.x, c2.x), blend_soft_light_f(c1.y, c2.y), blend_soft_light_f(c1.z, c2.z)) + (1.0-opacity)*c2;
}
float blend_burn_f(float c1, float c2) {
	return (c1==0.0)?c1:max((1.0-((1.0-c2)/c1)),0.0);
}
vec3 blend_burn(vec2 uv, vec3 c1, vec3 c2, float opacity) {
	return opacity*vec3(blend_burn_f(c1.x, c2.x), blend_burn_f(c1.y, c2.y), blend_burn_f(c1.z, c2.z)) + (1.0-opacity)*c2;
}
float blend_dodge_f(float c1, float c2) {
	return (c1==1.0)?c1:min(c2/(1.0-c1),1.0);
}
vec3 blend_dodge(vec2 uv, vec3 c1, vec3 c2, float opacity) {
	return opacity*vec3(blend_dodge_f(c1.x, c2.x), blend_dodge_f(c1.y, c2.y), blend_dodge_f(c1.z, c2.z)) + (1.0-opacity)*c2;
}
vec3 blend_lighten(vec2 uv, vec3 c1, vec3 c2, float opacity) {
	return opacity*max(c1, c2) + (1.0-opacity)*c2;
}
vec3 blend_darken(vec2 uv, vec3 c1, vec3 c2, float opacity) {
	return opacity*min(c1, c2) + (1.0-opacity)*c2;
}
vec3 blend_difference(vec2 uv, vec3 c1, vec3 c2, float opacity) {
	return opacity*clamp(c2-c1, vec3(0.0), vec3(1.0)) + (1.0-opacity)*c2;
}
vec3 blend_additive(vec2 uv, vec3 c1, vec3 c2, float oppacity) {
	return c2 + c1 * oppacity;
}
vec3 blend_addsub(vec2 uv, vec3 c1, vec3 c2, float oppacity) {
	return c2 + (c1 - .5) * 2.0 * oppacity;
}
float blend_linear_light_f(float c1, float c2) {
	return (c1 + 2.0 * c2) - 1.0;
}
vec3 blend_linear_light(vec2 uv, vec3 c1, vec3 c2, float opacity) {
return opacity*vec3(blend_linear_light_f(c1.x, c2.x), blend_linear_light_f(c1.y, c2.y), blend_linear_light_f(c1.z, c2.z)) + (1.0-opacity)*c2;
}
float blend_vivid_light_f(float c1, float c2) {
	return (c1 < 0.5) ? 1.0 - (1.0 - c2) / (2.0 * c1) : c2 / (2.0 * (1.0 - c1));
}
vec3 blend_vivid_light(vec2 uv, vec3 c1, vec3 c2, float opacity) {
	return opacity*vec3(blend_vivid_light_f(c1.x, c2.x), blend_vivid_light_f(c1.y, c2.y), blend_vivid_light_f(c1.z, c2.z)) + (1.0-opacity)*c2;
}
float blend_pin_light_f( float c1, float c2) {
	return (2.0 * c1 - 1.0 > c2) ? 2.0 * c1 - 1.0 : ((c1 < 0.5 * c2) ? 2.0 * c1 : c2);
}
vec3 blend_pin_light(vec2 uv, vec3 c1, vec3 c2, float opacity) {
	return opacity*vec3(blend_pin_light_f(c1.x, c2.x), blend_pin_light_f(c1.y, c2.y), blend_pin_light_f(c1.z, c2.z)) + (1.0-opacity)*c2;
}
float blend_hard_mix_f(float c1, float c2) {
	return floor(c1 + c2);
}
vec3 blend_hard_mix(vec2 uv, vec3 c1, vec3 c2, float opacity) {
		return opacity*vec3(blend_hard_mix_f(c1.x, c2.x), blend_hard_mix_f(c1.y, c2.y), blend_hard_mix_f(c1.z, c2.z)) + (1.0-opacity)*c2;
}
float blend_exclusion_f(float c1, float c2) {
	return c1 + c2 - 2.0 * c1 * c2;
}
vec3 blend_exclusion(vec2 uv, vec3 c1, vec3 c2, float opacity) {
	return opacity*vec3(blend_exclusion_f(c1.x, c2.x), blend_exclusion_f(c1.y, c2.y), blend_exclusion_f(c1.z, c2.z)) + (1.0-opacity)*c2;
}
uniform sampler2D texture_1;
const float texture_1_size = 1024.0;
const float pack_size = 256.0;
vec2 pack_1x32_to_2x16(float s) {
	return vec2(s - mod(s, 1.0/pack_size), mod(s, 1.0/pack_size)*pack_size);
}
float pack_2x16_to_1x32(vec2 s) {
	return s.x + s.y/pack_size;
}
vec4 pack_2x32_to_4x16(vec2 s) {
	return vec4(s.xy - vec2(mod(s.x, 1.0/pack_size), mod(s.y, 1.0/pack_size)) , vec2(mod(s.x, 1.0/pack_size), mod(s.y, 1.0/pack_size))*pack_size);
}
vec2 pack_4x16_to_2x32(vec4 s) {
	return s.rg + s.ba/pack_size;
}
const vec4 p_o5895_albedo_color = vec4(1.000000000, 1.000000000, 1.000000000, 1.000000000);
const float p_o5895_metallic = 0.000000000;
const float p_o5895_roughness = 1.000000000;
const float p_o5895_emission_energy = 1.000000000;
const float p_o5895_normal = 1.000000000;
const float p_o5895_ao = 1.000000000;
const float p_o5895_depth_scale = 0.500000000;
float o5895_input_depth_tex(vec2 uv, float _seed_variation_) {
return 0.0;
}
const float p_o5957_amount1 = 0.500000000;
const float p_o5957_amount2 = 0.000000000;
const vec4 p_o5958_color = vec4(0.375000000, 0.375000000, 0.375000000, 1.000000000);
const float p_o5897_gradient_0_pos = 0.000000000;
const vec4 p_o5897_gradient_0_col = vec4(0.000000000, 0.000000000, 0.000000000, 1.000000000);
const float p_o5897_gradient_1_pos = 0.000001000;
const vec4 p_o5897_gradient_1_col = vec4(0.414227009, 0.414227009, 0.414227009, 1.000000000);
const float p_o5897_gradient_2_pos = 0.658573000;
const vec4 p_o5897_gradient_2_col = vec4(1.000000000, 1.000000000, 1.000000000, 1.000000000);
vec4 o5897_gradient_gradient_fct(float x) {
  if (x < p_o5897_gradient_0_pos) {
    return p_o5897_gradient_0_col;
  } else if (x < p_o5897_gradient_1_pos) {
    return mix(p_o5897_gradient_0_col, p_o5897_gradient_1_col, ((x-p_o5897_gradient_0_pos)/(p_o5897_gradient_1_pos-p_o5897_gradient_0_pos)));
  } else if (x < p_o5897_gradient_2_pos) {
    return mix(p_o5897_gradient_1_col, p_o5897_gradient_2_col, ((x-p_o5897_gradient_1_pos)/(p_o5897_gradient_2_pos-p_o5897_gradient_1_pos)));
  }
  return p_o5897_gradient_2_col;
}
const float seed_o5896 = 0.000000000;
const float p_o5896_scale_x = 4.000000000;
const float p_o5896_scale_y = 4.000000000;
const float p_o5896_iterations = 7.000000000;
const float p_o5896_persistence = 1.000000000;
const float p_o5959_gradient_0_pos = 0.112990605;
const vec4 p_o5959_gradient_0_col = vec4(0.000000000, 0.000000000, 0.000000000, 1.000000000);
const float p_o5959_gradient_1_pos = 0.294808683;
const vec4 p_o5959_gradient_1_col = vec4(1.000000000, 1.000000000, 1.000000000, 1.000000000);
vec4 o5959_gradient_gradient_fct(float x) {
  if (x < p_o5959_gradient_0_pos) {
    return p_o5959_gradient_0_col;
  } else if (x < p_o5959_gradient_1_pos) {
    return mix(p_o5959_gradient_0_col, p_o5959_gradient_1_col, ((x-p_o5959_gradient_0_pos)/(p_o5959_gradient_1_pos-p_o5959_gradient_0_pos)));
  }
  return p_o5959_gradient_1_col;
}
const float seed_o5955 = 0.039562000;
const float p_o5955_scale_x = 1.000000000;
const float p_o5955_scale_y = 1.000000000;
const float p_o5955_iterations = 3.000000000;
const float p_o5955_persistence = 0.500000000;
const float p_o5955_frequency = 2.000000000;
const float p_o5955_offset = 1.000000000;
const float p_o108031_gradient_0_pos = 0.009136213;
const vec4 p_o108031_gradient_0_col = vec4(0.298828125, 0.298828125, 0.298828125, 1.000000000);
const float p_o108031_gradient_1_pos = 1.000000000;
const vec4 p_o108031_gradient_1_col = vec4(1.000000000, 1.000000000, 1.000000000, 1.000000000);
vec4 o108031_gradient_gradient_fct(float x) {
  if (x < p_o108031_gradient_0_pos) {
    return p_o108031_gradient_0_col;
  } else if (x < p_o108031_gradient_1_pos) {
    return mix(p_o108031_gradient_0_col, p_o108031_gradient_1_col, ((x-p_o108031_gradient_0_pos)/(p_o108031_gradient_1_pos-p_o108031_gradient_0_pos)));
  }
  return p_o108031_gradient_1_col;
}
const float p_o5918_amount = 2.000000000;
vec3 o5923_input_source(vec2 uv, float _seed_variation_) {
vec4 o5912_0 = textureLod(texture_1, uv, 0.0);
return ((o5912_0).rgb);
}
float o5918_input_in(vec2 uv, float _seed_variation_) {
float o5923_0_1_f = pack_2x16_to_1x32(o5923_input_source((uv), _seed_variation_).xy);
return o5923_0_1_f;
}
vec3 nm_o5918(vec2 uv, float amount, float size, float _seed_variation_) {
	vec3 e = vec3(1.0/size, -1.0/size, 0);
	vec2 rv;
	if (0 == 0) {
		rv = vec2(1.0, -1.0)*o5918_input_in(uv+e.xy, _seed_variation_);
		rv += vec2(-1.0, 1.0)*o5918_input_in(uv-e.xy, _seed_variation_);
		rv += vec2(1.0, 1.0)*o5918_input_in(uv+e.xx, _seed_variation_);
		rv += vec2(-1.0, -1.0)*o5918_input_in(uv-e.xx, _seed_variation_);
		rv += vec2(2.0, 0.0)*o5918_input_in(uv+e.xz, _seed_variation_);
		rv += vec2(-2.0, 0.0)*o5918_input_in(uv-e.xz, _seed_variation_);
		rv += vec2(0.0, 2.0)*o5918_input_in(uv+e.zx, _seed_variation_);
		rv += vec2(0.0, -2.0)*o5918_input_in(uv-e.zx, _seed_variation_);
		rv *= size*amount/128.0;
	} else if (0 == 1) {
		rv = vec2(3.0, -3.0)*o5918_input_in(uv+e.xy, _seed_variation_);
		rv += vec2(-3.0, 3.0)*o5918_input_in(uv-e.xy, _seed_variation_);
		rv += vec2(3.0, 3.0)*o5918_input_in(uv+e.xx, _seed_variation_);
		rv += vec2(-3.0, -3.0)*o5918_input_in(uv-e.xx, _seed_variation_);
		rv += vec2(10.0, 0.0)*o5918_input_in(uv+e.xz, _seed_variation_);
		rv += vec2(-10.0, 0.0)*o5918_input_in(uv-e.xz, _seed_variation_);
		rv += vec2(0.0, 10.0)*o5918_input_in(uv+e.zx, _seed_variation_);
		rv += vec2(0.0, -10.0)*o5918_input_in(uv-e.zx, _seed_variation_);
		rv *= size*amount/512.0;
	} else if (0 == 2) {
		rv = vec2(2.0, 0.0)*o5918_input_in(uv+e.xz, _seed_variation_);
		rv += vec2(-2.0, 0.0)*o5918_input_in(uv-e.xz, _seed_variation_);
		rv += vec2(0.0, 2.0)*o5918_input_in(uv+e.zx, _seed_variation_);
		rv += vec2(0.0, -2.0)*o5918_input_in(uv-e.zx, _seed_variation_);
		rv *= size*amount/64.0;
	} else {
		rv = vec2(1.0, 0.0)*o5918_input_in(uv+e.xz, _seed_variation_);
		rv += vec2(0.0, 1.0)*o5918_input_in(uv+e.zx, _seed_variation_);
		rv += vec2(-1.0, -1.0)*o5918_input_in(uv, _seed_variation_);
		rv *= size*amount/20.0;
	}
	return vec3(0.5)+0.5*normalize(vec3(rv, -1.0));
}
void fragment() {
	float _seed_variation_ = variation;
	vec2 uv = fract(UV);
vec4 o5958_0_1_rgba = p_o5958_color;
float o5896_0_1_f = perlin((uv), vec2(p_o5896_scale_x, p_o5896_scale_y), int(p_o5896_iterations), p_o5896_persistence, (seed_o5896+fract(_seed_variation_)));
vec4 o5897_0_1_rgba = o5897_gradient_gradient_fct(o5896_0_1_f);
float o5955_0_1_f = wavelet_noise((uv), vec2(p_o5955_scale_x, p_o5955_scale_y), int(p_o5955_iterations), p_o5955_persistence, (seed_o5955+fract(_seed_variation_)), p_o5955_frequency, p_o5955_offset, 1);
vec4 o5959_0_1_rgba = o5959_gradient_gradient_fct(o5955_0_1_f);
vec4 o5957_0_b = o5958_0_1_rgba;
vec4 o5957_0_l;
float o5957_0_a;

o5957_0_l = o5897_0_1_rgba;
o5957_0_a = p_o5957_amount1*(dot((o5959_0_1_rgba).rgb, vec3(1.0))/3.0);
o5957_0_b = vec4(blend_normal((uv), o5957_0_l.rgb, o5957_0_b.rgb, o5957_0_a*o5957_0_l.a), min(1.0, o5957_0_b.a+o5957_0_a*o5957_0_l.a));

o5957_0_l = vec4(1.0, ((uv)).y, 1.0, 1.0);
o5957_0_a = p_o5957_amount2*1.0;
o5957_0_b = vec4(blend_normal((uv), o5957_0_l.rgb, o5957_0_b.rgb, o5957_0_a*o5957_0_l.a), min(1.0, o5957_0_b.a+o5957_0_a*o5957_0_l.a));

vec4 o5957_0_2_rgba = o5957_0_b;
vec4 o108031_0_1_rgba = o108031_gradient_gradient_fct((dot((o5959_0_1_rgba).rgb, vec3(1.0))/3.0));
vec3 o5918_0_1_rgb = nm_o5918((uv), p_o5918_amount, 1024.000000000, _seed_variation_);

	vec3 albedo_tex = ((o5957_0_2_rgba).rgb).rgb;
	albedo_tex = mix(pow((albedo_tex + vec3(0.055)) * (1.0 / (1.0 + 0.055)),vec3(2.4)),albedo_tex * (1.0 / 12.92),lessThan(albedo_tex,vec3(0.04045)));
	ALBEDO = albedo_tex*p_o5895_albedo_color.rgb;
	METALLIC = (dot((o108031_0_1_rgba).rgb, vec3(1.0))/3.0)*p_o5895_metallic;
	ROUGHNESS = (dot((o108031_0_1_rgba).rgb, vec3(1.0))/3.0)*p_o5895_roughness;
	NORMAL = o5918_0_1_rgb;
	EMISSION = vec3(0.0)*p_o5895_emission_energy;

}

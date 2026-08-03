shader_type particles;

// Stores position and velocity
uniform sampler2D agent_data;
// Stores color flags
uniform sampler2D agent_data_2;

uniform float radius = 1.0;

void start() {
	// Called when a particle is spawned.
}

void process() {
	ivec2 pos_image_size = textureSize(agent_data, 0);

	ivec2 texel_pos = ivec2(
		int(mod(float(INDEX), float(pos_image_size.x))),
		int(float(INDEX) / float(pos_image_size.x))
	);

	// The r and g color channels store the agent's x/y positions
	// The b and g color channels store the agent's velocity (used for rotation)
	vec4 agent_params = texelFetch(agent_data, texel_pos, 0);
	
	// Rotation
	float dir = atan(agent_params.a, agent_params.b) + PI / 2.0;
	TRANSFORM[0].x = cos(dir);
	TRANSFORM[0].y = sin(dir);
	TRANSFORM[1].x = -sin(dir);
	TRANSFORM[1].y = cos(dir);

	// Scale
	float texture_radius = (radius / 16.0);
	TRANSFORM[0] *= texture_radius;
	TRANSFORM[1] *= texture_radius;

	// Translation
	TRANSFORM[3].xy = vec2(agent_params.r, agent_params.g);
	vec4 agent_params_2 = texelFetch(agent_data_2, texel_pos, 0);

	if (agent_params_2.r > 0.5) {
		COLOR.rgb = vec3(1.0, 1.0, 4.0);
	} else if (agent_params_2.g > 0.5) {
		COLOR.rgb = vec3(1.0, 4.0, 1.0);
	}
	else {
		COLOR.rgb = vec3(1.0);
	}

	//COLOR.r = agent_params_2.r == 1.0 ? 0.0 : 1.0;

	//COLOR.g = agent_params_2.g == 1.0 ? 0.0 : 1.0;
}

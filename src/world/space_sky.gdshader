shader_type sky;

// Procedural starfield: random stars on a dark background plus a faint galactic band,
// and the system's star drawn in the direction of the first DirectionalLight3D.
// No textures needed. Stars are placed on a 3D grid of view directions.

uniform vec3 background : source_color = vec3(0.004, 0.005, 0.012);
uniform vec3 band_color : source_color = vec3(0.05, 0.035, 0.08);
// Fraction of grid cells that contain a star.
uniform float star_density = 0.0025;
// Grid resolution: higher means smaller, denser stars.
uniform float star_scale = 350.0;
// Angular radius of the sun disc, in radians.
uniform float sun_radius = 0.012;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 color = background;

	// Galactic band around the horizontal plane.
	color += band_color * exp(-pow(dir.y * 3.5, 2.0));

	vec3 p = dir * star_scale;
	vec3 cell = floor(p);
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			for (int z = -1; z <= 1; z++) {
				vec3 c = cell + vec3(float(x), float(y), float(z));
				if (hash(c) > 1.0 - star_density) {
					vec3 star = normalize(c + vec3(hash(c + 1.3), hash(c + 2.7), hash(c + 4.1))) * star_scale;
					float glow = smoothstep(0.6, 0.0, length(p - star));
					float brightness = 0.25 + 1.5 * pow(hash(c + 9.1), 4.0);
					vec3 tint = mix(vec3(1.0, 0.85, 0.7), vec3(0.7, 0.8, 1.0), hash(c + 3.3));
					color += tint * glow * brightness;
				}
			}
		}
	}
	if (LIGHT0_ENABLED) {
		float angle = acos(clamp(dot(dir, LIGHT0_DIRECTION), -1.0, 1.0));
		float disc = 1.0 - smoothstep(sun_radius * 0.8, sun_radius, angle);
		float halo = 0.6 * exp(-angle * 40.0) + 0.15 * exp(-angle * 6.0);
		color += LIGHT0_COLOR * (disc * 12.0 + halo);
	}
	COLOR = color;
}

shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

// Swirling energy disc inside a jump gate ring. Drawn on a quad; everything outside
// the inscribed circle is discarded. `intensity` is low when idle and high when active.

uniform vec4 energy_color : source_color = vec4(0.35, 0.65, 1.0, 1.0);
uniform float intensity = 0.25;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}
	float angle = atan(p.y, p.x);
	float swirl = 0.5 + 0.5 * sin(angle * 5.0 + r * 12.0 - TIME * 1.5);
	float rim = smoothstep(0.6, 1.0, r);
	float core = 1.0 - smoothstep(0.0, 0.35, r);
	float edge_fade = 1.0 - smoothstep(0.94, 1.0, r);
	float glow = (0.2 + 0.5 * swirl * (1.0 - r) + 0.6 * rim + 0.3 * core) * intensity * edge_fade;
	ALBEDO = energy_color.rgb;
	ALPHA = clamp(glow, 0.0, 1.0);
}

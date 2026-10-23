// Небо первого уровня: солнечный день, белые облака,
// вдали — зелёные острова, внизу — море.
// Цвета и количество облаков меняются в Inspector (материал неба → Shader Parameters).
shader_type sky;

#include "res://shaders/sky_noise.gdshaderinc"

group_uniforms sky;
uniform vec3 sky_top : source_color = vec3(0.20, 0.47, 0.92);
uniform vec3 sky_horizon : source_color = vec3(0.68, 0.85, 1.0);
uniform float sun_size : hint_range(0.0, 0.2) = 0.035;

group_uniforms clouds;
uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shadow : source_color = vec3(0.70, 0.79, 0.92);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.45;
uniform float cloud_scale : hint_range(0.2, 4.0) = 1.3;

group_uniforms islands;
uniform vec3 grass_near : source_color = vec3(0.32, 0.62, 0.24);
uniform vec3 grass_far : source_color = vec3(0.52, 0.74, 0.60);
uniform float island_height : hint_range(0.0, 0.3) = 0.07;

group_uniforms sea;
uniform vec3 sea_deep : source_color = vec3(0.07, 0.36, 0.58);
uniform vec3 sea_horizon : source_color = vec3(0.50, 0.76, 0.90);

void sky() {
	vec3 dir = EYEDIR;
	float h = dir.y;
	vec3 color;

	if (h >= 0.0) {
		// Небо: у горизонта светлое, вверху насыщенно-синее
		color = mix(sky_horizon, sky_top, sqrt(h));

		// Облака: «натягиваем» шум на плоскость высоко над головой
		vec2 uv = dir.xz / (h + 0.12) * cloud_scale;
		float n = sky_fbm(uv + vec2(4.0, 1.0), 5);
		float threshold = mix(0.72, 0.38, cloud_cover);
		float cloud = smoothstep(threshold, threshold + 0.12, n) * smoothstep(0.0, 0.15, h);
		vec3 cloud_col = mix(cloud_shadow, cloud_color, smoothstep(threshold, threshold + 0.25, n));
		color = mix(color, cloud_col, cloud);

		// Солнце и мягкое сияние вокруг него
		if (LIGHT0_ENABLED) {
			float sun = dot(dir, LIGHT0_DIRECTION);
			color += LIGHT0_COLOR * pow(max(sun, 0.0), 300.0) * 0.6;
			color = mix(color, LIGHT0_COLOR * 2.0, smoothstep(1.0 - sun_size * 0.05, 1.0 - sun_size * 0.04, sun));
		}

		// Острова на горизонте: дальние (светлые, в дымке) и ближние (сочная трава)
		float far_mask = smoothstep(0.42, 0.55, sky_ring(dir, 1.6, 3.0, 3));
		float far_top = far_mask * island_height * (0.35 + 0.65 * sky_ring(dir, 7.0, 11.0, 4));
		if (h < far_top) {
			color = mix(grass_far, sky_horizon, 0.35);
		}
		float near_mask = smoothstep(0.48, 0.6, sky_ring(dir, 2.3, 27.0, 3));
		float near_top = near_mask * island_height * 0.8 * (0.3 + 0.7 * sky_ring(dir, 9.0, 41.0, 4));
		if (h < near_top) {
			// Вершины чуть светлее — как освещённая солнцем трава
			color = mix(grass_near * 0.8, grass_near * 1.15, smoothstep(0.0, near_top, h));
		}
	} else {
		// Море: у горизонта светлое, под ногами — глубокое синее
		float depth = -h;
		color = mix(sea_horizon, sea_deep, smoothstep(0.0, 0.35, depth));
		// Лёгкая рябь
		vec2 uv = dir.xz / (depth + 0.05) * 6.0;
		color *= 0.94 + 0.08 * sky_noise(uv);
		// Солнечная дорожка на воде
		if (LIGHT0_ENABLED) {
			vec3 mirrored = vec3(dir.x, -dir.y, dir.z);
			float glint = pow(max(dot(mirrored, LIGHT0_DIRECTION), 0.0), 60.0);
			color += LIGHT0_COLOR * glint * 0.35 * step(0.55, sky_noise(uv * 3.0));
		}
	}

	COLOR = color;
}

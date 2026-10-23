// Небо второго уровня: суровые каменные горы, тяжёлые тучи,
// у горизонта — красноватый просвет, внизу — море облаков над пропастью.
// Цвета меняются в Inspector (материал неба → Shader Parameters).
shader_type sky;

#include "res://shaders/sky_noise.gdshaderinc"

group_uniforms sky;
uniform vec3 sky_top : source_color = vec3(0.22, 0.25, 0.30);
uniform vec3 sky_horizon : source_color = vec3(0.62, 0.60, 0.58);
// Тёплый просвет у горизонта и вокруг солнца
uniform vec3 glow_color : source_color = vec3(0.95, 0.55, 0.30);
uniform float glow_strength : hint_range(0.0, 2.0) = 0.8;

group_uniforms clouds;
uniform vec3 cloud_dark : source_color = vec3(0.25, 0.26, 0.30);
uniform vec3 cloud_light : source_color = vec3(0.60, 0.60, 0.63);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.7;

group_uniforms mountains;
uniform vec3 rock_far : source_color = vec3(0.42, 0.42, 0.46);
uniform vec3 rock_near : source_color = vec3(0.23, 0.23, 0.27);
uniform float mountain_height : hint_range(0.0, 0.5) = 0.2;

group_uniforms abyss;
uniform vec3 mist_color : source_color = vec3(0.55, 0.55, 0.58);
uniform vec3 abyss_color : source_color = vec3(0.26, 0.27, 0.31);

// Острые хребты: «перевёрнутый модуль» шума даёт пики вместо холмов
float ridges(vec3 dir, float frequency, float seed) {
	float n = sky_ring(dir, frequency, seed, 5);
	float r = 1.0 - abs(n * 2.0 - 1.0);
	return r * r;
}

void sky() {
	vec3 dir = EYEDIR;
	float h = dir.y;
	vec3 color;

	// Насколько мы смотрим в сторону солнца (по горизонтали): там просвет ярче
	float toward_sun = 0.0;
	if (LIGHT0_ENABLED) {
		toward_sun = max(dot(normalize(dir.xz + vec2(0.00001)), normalize(LIGHT0_DIRECTION.xz + vec2(0.00001))), 0.0);
	}

	if (h >= -0.06) {
		color = mix(sky_horizon, sky_top, sqrt(max(h, 0.0)));
		// Красноватая полоса у горизонта
		float band = exp(-max(h, 0.0) * 9.0);
		color += glow_color * band * glow_strength * (0.25 + 0.75 * toward_sun) * 0.45;

		// Тяжёлые тучи
		vec2 uv = dir.xz / (max(h, 0.0) + 0.1) * 0.9;
		float n = sky_fbm(uv + vec2(2.0, 7.0), 6);
		float threshold = mix(0.7, 0.3, cloud_cover);
		float cloud = smoothstep(threshold - 0.05, threshold + 0.2, n) * smoothstep(0.0, 0.2, h);
		vec3 cloud_col = mix(cloud_dark, cloud_light, smoothstep(threshold + 0.25, threshold - 0.05, n));
		// Края туч подсвечены солнцем
		cloud_col += glow_color * toward_sun * 0.18 * (1.0 - cloud);
		color = mix(color, cloud_col, cloud * 0.92);

		// Солнце пробивается сквозь тучи
		if (LIGHT0_ENABLED) {
			float sun = max(dot(dir, LIGHT0_DIRECTION), 0.0);
			color += glow_color * pow(sun, 24.0) * 0.5 * glow_strength;
			color += LIGHT0_COLOR * pow(sun, 600.0) * 1.5 * (1.0 - cloud * 0.7);
		}

		// Горы: дальние (светлее, в дымке) и ближние (тёмные, острые)
		float far_top = -0.06 + mountain_height * (0.25 + 0.75 * ridges(dir, 3.0, 5.0));
		if (h < far_top) {
			float shade = sky_noise(vec2(atan(dir.x, dir.z) * 40.0, h * 60.0));
			color = mix(rock_far, sky_horizon, 0.3) * (0.92 + 0.12 * shade);
		}
		float near_top = -0.06 + mountain_height * 0.7 * ridges(dir, 5.0, 19.0) * smoothstep(0.35, 0.6, sky_ring(dir, 1.5, 7.0, 3));
		if (h < near_top) {
			float shade = sky_noise(vec2(atan(dir.x, dir.z) * 80.0, h * 120.0));
			// Склоны к солнцу чуть светлее
			color = rock_near * (0.85 + 0.25 * shade) + glow_color * toward_sun * 0.05;
		}
	} else {
		// Под ногами: море облаков, чем ниже — тем темнее пропасть
		float depth = -h;
		vec2 uv = dir.xz / (depth + 0.08) * 1.6;
		float n = sky_fbm(uv + vec2(9.0, 3.0), 5);
		color = mix(mist_color, abyss_color, smoothstep(0.0, 0.6, depth));
		color = mix(color, mist_color * 1.08, smoothstep(0.45, 0.75, n) * 0.6);
		color += glow_color * toward_sun * 0.08 * (1.0 - smoothstep(0.0, 0.3, depth));
	}

	COLOR = color;
}

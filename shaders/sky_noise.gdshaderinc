// Общие «шумы» для неба: из них получаются облака и силуэты гор.
// Подключается в шейдеры неба строкой #include.

float sky_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Плавный шум: случайные значения в узлах сетки, между ними — мягкий переход
float sky_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(sky_hash(i), sky_hash(i + vec2(1.0, 0.0)), u.x),
			mix(sky_hash(i + vec2(0.0, 1.0)), sky_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Несколько слоёв шума разного размера: крупные формы + мелкие детали
float sky_fbm(vec2 p, int octaves) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < octaves; i++) {
		value += amplitude * sky_noise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		amplitude *= 0.5;
	}
	return value;
}

// Высота силуэта на горизонте. Берём шум по кругу вокруг игрока —
// так у гор нет «шва», где круг замыкается.
float sky_ring(vec3 dir, float frequency, float seed, int octaves) {
	vec2 ring = normalize(dir.xz + vec2(0.00001));
	return sky_fbm(ring * frequency + vec2(seed, seed * 1.7), octaves);
}

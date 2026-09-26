// Água pixelada e opaca, com brilhos que piscam em alguns texels.
// Opaca de propósito: combina com o visual pixel art e não briga com o contorno.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform vec3 cor_rasa : source_color = vec3(0.24, 0.55, 0.78);
uniform vec3 cor_funda : source_color = vec3(0.13, 0.33, 0.6);
uniform vec3 cor_brilho : source_color = vec3(0.85, 0.95, 1.0);
uniform float texels_por_metro = 8.0;
uniform float velocidade = 1.5;

varying vec3 pos_mundo;
varying vec3 normal_mundo;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void vertex() {
	pos_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normal_mundo = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(normal_mundo);
	vec3 texel = floor(pos_mundo * texels_por_metro - n * 0.5);
	// Faixas diagonais que andam devagar, quantizadas por texel.
	float onda = sin((texel.x + texel.z) * 0.7 + TIME * velocidade) * 0.5 + 0.5;
	vec3 cor = mix(cor_funda, cor_rasa, step(0.5, onda));
	// Cada texel tem sua fase: de vez em quando pisca um brilho.
	float fase = hash(texel);
	float pisca = hash(texel + floor(TIME * 2.0 + fase * 8.0));
	if (n.y > 0.5 && pisca > 0.97) {
		cor = cor_brilho;
	}
	ALBEDO = cor;
	ROUGHNESS = 0.4;
}

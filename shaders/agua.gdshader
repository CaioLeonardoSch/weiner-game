// Água pixelada e opaca, com brilhos que piscam em alguns texels.
// Opaca de propósito: combina com o visual pixel art e não briga com o contorno.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform vec3 cor_rasa : source_color = vec3(0.24, 0.55, 0.78);
uniform vec3 cor_funda : source_color = vec3(0.13, 0.33, 0.6);
uniform vec3 cor_brilho : source_color = vec3(0.85, 0.95, 1.0);
uniform float texels_por_metro = 8.0;
uniform float velocidade = 1.5;
// Correnteza: > 0 faz as faixas andarem no sentido +X do tile (girado no editor).
uniform float velocidade_fluxo = 0.0;

// Clima (ver scripts/clima.gd): com chuva, pingos abrem anéis na superfície.
global uniform float chuva;

varying vec3 pos_mundo;
varying vec3 normal_mundo;
varying vec2 fluxo;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void vertex() {
	pos_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normal_mundo = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	fluxo = normalize((MODEL_MATRIX * vec4(1.0, 0.0, 0.0, 0.0)).xz);
}

void fragment() {
	vec3 n = normalize(normal_mundo);
	vec3 texel = floor(pos_mundo * texels_por_metro - n * 0.5);
	// Faixas diagonais que andam devagar, quantizadas por texel. Na correnteza, as faixas
	// ficam de través e descem o rio.
	float onda = sin((texel.x + texel.z) * 0.7 + TIME * velocidade) * 0.5 + 0.5;
	if (velocidade_fluxo > 0.0) {
		float ao_longo = dot(texel.xz, fluxo);
		float de_lado = dot(texel.xz, vec2(-fluxo.y, fluxo.x));
		onda = sin(ao_longo * 0.9 + sin(de_lado * 0.8) * 0.8 - TIME * velocidade_fluxo * 6.0) * 0.5 + 0.5;
	}
	vec3 cor = mix(cor_funda, cor_rasa, step(0.5, onda));
	// Cada texel tem sua fase: de vez em quando pisca um brilho.
	float fase = hash(texel);
	float pisca = hash(texel + floor(TIME * 2.0 + fase * 8.0));
	if (n.y > 0.5 && pisca > 0.97) {
		cor = cor_brilho;
	}
	// Pingos: em cada meio metro, um anel que abre e some.
	if (n.y > 0.5 && chuva > 0.0) {
		vec2 pixel = (floor(pos_mundo.xz * texels_por_metro * 2.0) + 0.5) / (texels_por_metro * 2.0);
		vec2 celula = floor(pixel * 2.0);
		vec2 local = fract(pixel * 2.0);
		float t = TIME * 1.1 + hash(vec3(celula.x, 3.3, celula.y));
		float ciclo = floor(t);
		float passo = fract(t);
		vec2 onde = 0.3 + 0.4 * vec2(hash(vec3(celula.x, ciclo, 1.7)), hash(vec3(ciclo, celula.y, 5.9)));
		float anel = 0.03 + passo * 0.3;
		if (abs(length(local - onde) - anel) < 0.07 && hash(vec3(celula, ciclo + 0.5)) < chuva) {
			cor = mix(cor, cor_brilho, (1.0 - passo) * 0.8);
		}
	}
	ALBEDO = cor;
	ROUGHNESS = 0.4;
}

// Material "pixel art" do mundo: cor chapada + textura de pixels gerada pela posição no mundo.
//
// Os "texels" são uma grade fixa no mundo (texels_por_metro), então blocos vizinhos
// emendam sem costura e tudo tem a mesma densidade de pixels. Serve para os tiles do
// terreno e para os modelos voxel (com usar_cor_vertice).
//
// Franja: nas faces laterais, a faixa logo abaixo do topo usa cor_topo com borda irregular
// (a grama "descendo" pela lateral do bloco). A distância até o topo vem no UV.y da malha
// (ver scripts/assets/tiles.gd); malhas sem essa informação usam franja_texels = 0.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform vec3 cor_lado : source_color = vec3(0.5, 0.36, 0.22);
uniform vec3 cor_topo : source_color = vec3(0.3, 0.56, 0.22);
// Intensidade das manchas claras/escuras de cada texel.
uniform float variacao : hint_range(0.0, 0.6) = 0.12;
// Fração de texels escuros e claros (o resto fica na cor base).
uniform float fracao_escuros : hint_range(0.0, 1.0) = 0.22;
uniform float fracao_claros : hint_range(0.0, 1.0) = 0.15;
uniform float texels_por_metro = 8.0;
// Altura da franja (em texels); 0 desliga.
uniform float franja_texels = 0.0;
uniform bool usar_cor_vertice = false;

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
	// Texel "dentro" da superfície (meio texel para trás na direção da normal): estável na face.
	vec3 texel = floor(pos_mundo * texels_por_metro - n * 0.5);
	bool topo = n.y > 0.5;

	vec3 base = topo ? cor_topo : cor_lado;
	if (!topo && franja_texels > 0.0) {
		// Coluna do texel na face (ignora a altura) → cada coluna tem uma franja diferente.
		float coluna = hash(texel * vec3(1.0, 0.0, 1.0) + vec3(3.1, 0.0, 7.7));
		float abaixo_do_topo = UV.y * texels_por_metro;
		if (abaixo_do_topo < franja_texels + floor(coluna * 2.5) - 0.5) {
			base = cor_topo;
		}
	}

	float r = hash(texel);
	float nivel = r < fracao_escuros ? -1.0 : (r > 1.0 - fracao_claros ? 1.0 : 0.0);
	// Longe da câmera os texels ficam menores que um pixel e a textura cintila: suaviza.
	float tamanho_texel_na_tela = length(fwidth(pos_mundo)) * texels_por_metro;
	nivel *= clamp(2.2 - tamanho_texel_na_tela, 0.0, 1.0);

	vec3 cor = base * (1.0 + nivel * variacao);
	if (usar_cor_vertice) {
		cor *= COLOR.rgb;
	}
	ALBEDO = cor;
	ROUGHNESS = 1.0;
}

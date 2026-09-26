// Contorno pixelado, desenhado num quad de tela cheia preso à câmera (scenes/contorno_pixel.tscn).
//
// Roda na resolução interna do 3D (baixa), então cada teste compara pixels "do jogo":
// - contorno escuro no pixel da frente quando o vizinho está bem mais longe (silhuetas);
// - realce claro em quinas convexas (mudança de normal sem salto de profundidade).
// Só escreve onde há borda (o resto é descartado), então não apaga objetos transparentes.
shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled;

uniform sampler2D tex_profundidade : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D tex_normal : hint_normal_roughness_texture, filter_nearest, repeat_disable;

uniform vec3 cor_contorno : source_color = vec3(0.07, 0.05, 0.09);
uniform float forca_contorno : hint_range(0.0, 1.0) = 0.65;
uniform float forca_realce : hint_range(0.0, 1.0) = 0.14;
// Diferença mínima de profundidade (m) para virar contorno. Na perspectiva cresce com a
// distância (limiar_relativo); na câmera ortográfica (isométrica) é fixa.
uniform float limiar_profundidade : hint_range(0.0, 1.0) = 0.12;
uniform float limiar_relativo : hint_range(0.0, 0.2) = 0.03;

void vertex() {
	// Quad de tela cheia (Godot 4.3+ usa Z invertido: 1.0 = plano próximo).
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float profundidade_linear(vec2 uv, mat4 inv_proj) {
	float d = textureLod(tex_profundidade, uv, 0.0).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -v.z / v.w;
}

vec3 normal_em(vec2 uv) {
	return normalize(textureLod(tex_normal, uv, 0.0).xyz * 2.0 - 1.0);
}

void fragment() {
	vec2 texel = 1.0 / VIEWPORT_SIZE;
	vec2 uv = SCREEN_UV;
	float d = profundidade_linear(uv, INV_PROJECTION_MATRIX);
	vec3 n = normal_em(uv);
	bool ortografica = PROJECTION_MATRIX[3][3] > 0.5;
	float limiar = limiar_profundidade + (ortografica ? 0.0 : d * limiar_relativo);
	// Em superfícies muito inclinadas em relação à câmera a profundidade muda rápido
	// de um pixel para o outro; aumenta o limiar para não riscar o chão.
	limiar /= max(abs(n.z), 0.25);

	vec2 vizinhos[4] = vec2[](vec2(texel.x, 0.0), vec2(-texel.x, 0.0), vec2(0.0, texel.y), vec2(0.0, -texel.y));
	float borda = 0.0;
	float realce = 0.0;
	for (int i = 0; i < 4; i++) {
		vec2 uv2 = uv + vizinhos[i];
		float d2 = profundidade_linear(uv2, INV_PROJECTION_MATRIX);
		float dif = d2 - d;
		borda = max(borda, step(limiar, dif));
		// Realce só de um lado da quina (viés fixo), para a linha ter 1 pixel.
		vec3 n2 = normal_em(uv2);
		float lado = step(0.0, dot(n - n2, vec3(1.0, 1.0, 1.0)));
		float mesma_superficie = step(abs(dif), limiar);
		realce = max(realce, (1.0 - dot(n, n2)) * lado * mesma_superficie);
	}

	if (borda > 0.0) {
		ALBEDO = cor_contorno;
		ALPHA = forca_contorno;
	} else if (realce > 0.15) {
		ALBEDO = vec3(1.0);
		ALPHA = forca_realce;
	} else {
		discard;
	}
}

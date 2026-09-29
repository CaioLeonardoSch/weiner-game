// Material "pixel art" do mundo: cor chapada + textura de pixels gerada pela posição no mundo.
//
// Os "texels" são uma grade fixa no mundo (texels_por_metro), então blocos vizinhos
// emendam sem costura e tudo tem a mesma densidade de pixels. Serve para os tiles do
// terreno e para os modelos voxel (com usar_cor_vertice).
//
// Franja: nas faces laterais, a faixa logo abaixo do topo usa cor_topo com borda irregular
// (a grama "descendo" pela lateral do bloco). A distância até o topo vem no UV.y da malha
// (ver scripts/assets/tiles.gd); malhas sem essa informação usam franja_texels = 0.
//
// Poças (grama com poças, lama): manchas de água no topo de cada célula de 1 m, desenhadas
// numa grade de pixels duas vezes mais fina (a mesma dos modelos voxel pequenos). Com chuva
// (global `chuva`), anéis de pingos aparecem nelas.
//
// Vento: com `balanco` > 0 (árvores, capim), o modelo balança com o vento global `vento`
// (direção × força, em XZ). O ponto de cima balança mais; a base fica parada. A textura acompanha
// o modelo (os texels vêm da posição de antes do balanço).
//
// Transparência na frente (árvores): o que fica entre a câmera e o cachorro (global `alvo_visao`)
// some em pontilhado (dither) num cilindro em volta da linha de visão, para a árvore não tapar o
// cachorro. `transparencia_na_frente` (0 a 1) é ligada pelo jogo (0 no editor e no menu).
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
// Cintilado (neve, gelo): uma fração pequena de texels bem claros, só no topo.
uniform float fracao_brilho : hint_range(0.0, 0.3) = 0.0;
uniform vec3 cor_brilho : source_color = vec3(1.0, 1.0, 1.0);
// Chance de cada célula ter uma poça (0 desliga); uma segunda poça menor sai com metade da chance.
uniform float pocas : hint_range(0.0, 1.0) = 0.0;
uniform vec3 cor_poca : source_color = vec3(0.36, 0.52, 0.64);
// Chão molhado em volta da poça.
uniform vec3 cor_margem : source_color = vec3(0.34, 0.27, 0.17);
// Poças congeladas (neve): sem anéis de chuva, com riscos claros.
uniform bool pocas_congeladas = false;
// Gelo liso: faixas diagonais claras no topo (superfície polida, reflete o céu).
uniform bool reflexos = false;
// Quanto o modelo balança com o vento (0 = parado). Árvores ~1; capim baixo, mais.
uniform float balanco = 0.0;
// Este material fica pontilhado quando tapa o cachorro (ver acima).
uniform bool some_na_frente = false;

// Clima (ver scripts/clima.gd): intensidade da chuva (0 a 1) e vento (XZ = direção × força).
global uniform float chuva;
global uniform vec3 vento;
// Onde está o cachorro e quanto a árvore na frente dele some (0 = nada).
global uniform vec3 alvo_visao;
global uniform float transparencia_na_frente;

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
	if (balanco > 0.0) {
		float forca = length(vento.xz);
		vec3 origem = MODEL_MATRIX[3].xyz;
		float fase = dot(origem.xz, vec2(0.37, 0.61));
		float altura = max(VERTEX.y, 0.0);
		// Inclina a favor do vento, oscilando; um tremido de lado nas folhas.
		float onda = 0.55 + 0.45 * sin(TIME * 1.6 + fase) + 0.15 * sin(TIME * 4.3 + fase * 2.0);
		vec2 lado = forca > 0.001 ? vec2(-vento.z, vento.x) / forca : vec2(0.0);
		vec2 desvio = (vento.xz * onda + lado * forca * 0.25 * sin(TIME * 5.1 + fase + VERTEX.y * 2.0))
			* altura * altura * 0.008 * balanco;
		VERTEX += inverse(mat3(MODEL_MATRIX)) * vec3(desvio.x, 0.0, desvio.y);
	}
}

// Poças no topo: devolve a cor com as poças (ou a própria `cor` fora delas).
vec3 desenhar_pocas(vec3 cor, float suavizar) {
	float grade = texels_por_metro * 2.0;
	// Centro do pixel fino: a borda da poça sai pixelada.
	vec2 fino = (floor(pos_mundo.xz * grade) + 0.5) / grade;
	vec2 celula = floor(fino);
	vec2 local = fino - celula;
	float serrilhado = hash(vec3(floor(pos_mundo.xz * grade), 4.2).xzy) - 0.5;
	bool margem = false;
	for (int k = 0; k < 2; k++) {
		vec3 semente = vec3(celula.x, float(k) * 3.7 + 1.3, celula.y);
		if (hash(semente) > pocas * (k == 0 ? 1.0 : 0.5)) {
			continue;
		}
		float tamanho = k == 0 ? 1.0 : 0.6;
		vec2 raio = vec2(0.15 + 0.14 * hash(semente + vec3(1.1, 0.0, 0.0)),
			0.13 + 0.12 * hash(semente + vec3(0.0, 0.0, 2.3))) * tamanho;
		vec2 folga = raio * 1.35 + 0.04;
		vec2 centro = mix(folga, 1.0 - folga, vec2(hash(semente + vec3(5.1, 0.0, 0.0)),
			hash(semente + vec3(0.0, 0.0, 7.9))));
		vec2 q = (local - centro) / raio;
		float d = dot(q, q) + serrilhado * 0.35;
		if (d > 1.0) {
			// Margem molhada (se o pixel não estiver na água da outra poça).
			margem = margem || d < 1.8;
			continue;
		}
		vec3 agua = cor_poca;
		// Reflexo do céu: mais claro no lado de trás da poça, uns pixels de brilho.
		if (q.y < -0.35 && q.x > -0.4) {
			agua *= 1.12;
		}
		float r = hash(vec3(floor(pos_mundo.xz * grade), 9.7).xzy);
		if (r < 0.06) {
			agua = mix(agua, vec3(0.9, 0.95, 1.0), 0.45 * suavizar);
		}
		if (pocas_congeladas) {
			if (abs(q.x + q.y * 0.6 - 0.2) < 0.12 || abs(q.x * 0.4 - q.y - 0.3) < 0.1) {
				agua = mix(agua, vec3(0.95, 0.98, 1.0), 0.5 * suavizar);
			}
			return agua;
		}
		// Pingos: anéis que abrem e somem (três por poça, cada um no seu ritmo).
		if (chuva > 0.0) {
			for (int i = 0; i < 3; i++) {
				float t = TIME * (0.9 + 0.2 * float(i)) + hash(semente + vec3(float(i) * 2.9, 0.0, 0.0));
				float ciclo = floor(t);
				float passo = fract(t);
				vec2 onde = centro + (vec2(hash(vec3(ciclo, float(i), semente.x)), hash(vec3(semente.z, float(i), ciclo))) - 0.5) * raio;
				float distancia = length((local - onde) * vec2(1.0, raio.x / raio.y));
				float anel = 0.015 + passo * 0.14 * tamanho;
				if (abs(distancia - anel) < 0.5 / grade && hash(vec3(ciclo, float(i) + 7.0, semente.z)) < chuva * 1.3) {
					agua = mix(agua, vec3(0.88, 0.94, 1.0), (1.0 - passo) * 0.7 * suavizar);
				}
			}
		}
		return agua;
	}
	if (margem) {
		return mix(cor, cor_margem * (1.0 + (hash(vec3(fino * 50.0, 1.9).xzy) - 0.5) * 0.1), 0.75);
	}
	return cor;
}

// Raio (m) do cilindro em volta da linha câmera → cachorro onde a árvore some; na borda, some menos.
const float RAIO_VISAO = 1.1;
const float BORDA_VISAO = 0.5;

// Limiar do pontilhado ordenado 4×4 (Bayer) no pixel da tela: 0 a 1.
float bayer4(vec2 pixel) {
	int x = int(mod(pixel.x, 4.0));
	int y = int(mod(pixel.y, 4.0));
	int indice = x + y * 4;
	int matriz[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(matriz[indice]) + 0.5) / 16.0;
}

void fragment() {
	if (some_na_frente && transparencia_na_frente > 0.0) {
		// Para a câmera: na ortogonal, a direção da vista; na perspectiva, rumo à câmera.
		bool ortogonal = PROJECTION_MATRIX[3][3] == 1.0;
		vec3 para_camera = ortogonal ? normalize(INV_VIEW_MATRIX[2].xyz)
			: normalize(CAMERA_POSITION_WORLD - alvo_visao);
		vec3 relativo = pos_mundo - alvo_visao;
		float adiante = dot(relativo, para_camera);
		float distancia = length(relativo - para_camera * adiante);
		// Só o que está na frente do cachorro (do lado da câmera), não atrás.
		float quanto = smoothstep(RAIO_VISAO + BORDA_VISAO, RAIO_VISAO, distancia)
			* smoothstep(0.2, 0.8, adiante) * transparencia_na_frente;
		if (quanto * 0.8 > bayer4(FRAGCOORD.xy)) {
			discard;
		}
	}
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
	if (topo && fracao_brilho > 0.0 && hash(texel + vec3(11.3, 5.1, 2.7)) < fracao_brilho) {
		cor = mix(cor, cor_brilho, clamp(2.2 - tamanho_texel_na_tela, 0.0, 1.0));
	}
	if (topo && reflexos) {
		// Duas faixas por metro, de larguras diferentes, na diagonal do mundo (contínuas entre blocos).
		float diagonal = texel.x + texel.z;
		float faixa = mod(diagonal, 8.0);
		if (faixa < 1.0 || (faixa > 3.0 && faixa < 3.5 + 0.5 * step(0.5, hash(vec3(floor(diagonal / 8.0), 1.0, 2.0))))) {
			cor = mix(cor, cor_brilho, 0.35 * clamp(2.2 - tamanho_texel_na_tela, 0.0, 1.0));
		}
	}
	if (topo && pocas > 0.0) {
		cor = desenhar_pocas(cor, clamp(2.2 - tamanho_texel_na_tela, 0.0, 1.0));
	}
	if (usar_cor_vertice) {
		cor *= COLOR.rgb;
	}
	// Tudo fica um pouco mais escuro na chuva (molhado).
	cor *= 1.0 - 0.14 * chuva;
	ALBEDO = cor;
	ROUGHNESS = 1.0;
}

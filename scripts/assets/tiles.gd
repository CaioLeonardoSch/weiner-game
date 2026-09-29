@tool
class_name Tiles
## Tiles do terreno (itens do GridMap "Terreno" de cada fase).
##
## Os IDs ficam gravados dentro das fases: nunca renumere nem reaproveite um ID.
## Para criar um tile novo: acrescente uma constante e uma entrada em `definicoes()` (sempre
## no fim) e gere a biblioteca de novo (ver ferramentas/gerar_tiles.gd). A aparência vem
## dos materiais em assets/materiais/ — mudar as cores lá não exige gerar de novo.

const CAMINHO_BIBLIOTECA := "res://assets/tiles/tiles.tres"
## Uma biblioteca por bioma (mesmos IDs e colisões, materiais trocados — ver MATERIAIS_POR_BIOMA).
## Índice = bioma (ver Biomas): 0 floresta, 1 neve.
const BIBLIOTECAS := ["res://assets/tiles/tiles.tres", "res://assets/tiles/tiles_neve.tres"]
## Materiais que cada bioma troca: na neve, a grama vira grama coberta de neve, a pedra ganha
## neve em cima etc. O resto (água, madeira, terra fofa, tiles de neve) fica igual.
const MATERIAIS_POR_BIOMA := {
	1: {"grama": "neve", "mato": "mato_nevado", "terra": "terra_gelada", "pedra": "pedra_nevada",
		"grama_pocas": "neve_pocas"},
}

const GRAMA := 0
const TERRA := 1
const PEDRA := 2
const MATO := 3
const RAMPA_BAIXA := 4
const RAMPA_ALTA := 5
const MEIO_BLOCO := 6
const MATO_BAIXO := 7
const AGUA := 8
const TABUA := 9
const TERRA_FOFA := 10
const AGUA_RASA := 11
const CORRENTEZA := 12
const ESCADA_BAIXA := 13
const ESCADA_ALTA := 14
const CANTO_RAMPA_BAIXA := 15
const CANTO_RAMPA_ALTA := 16
const CANTO_INTERNO_BAIXA := 17
const CANTO_INTERNO_ALTA := 18
const BURACO := 19
const RAMPA_LISA_BAIXA := 20
const RAMPA_LISA_ALTA := 21
const DEGRAU_ALTO := 22
const NEVE_FOFA := 23
const MONTE_DE_NEVE := 24
const GELO := 25
const GRAMA_COM_POCAS := 26
const LAMA := 27
const GELO_LISO := 28

## Quanto (m) a malha VISUAL de cada tile passa da célula em X e Z, para os vizinhos se
## sobreporem um fio. Sem isso, na emenda entre dois blocos de 8×8 células do GridMap (os
## "octantes", cada um desenhado com a sua transformação) o arredondamento abria frestas de
## menos de um pixel, e o contorno pixelado virava cada fresta numa linha clara e escura
## atravessando o chão. A colisão continua do tamanho exato da célula.
const FOLGA_VISUAL := 0.002

## Altura (no espaço do tile, de -0.5 a 0.5) da superfície da água.
const SUPERFICIE_AGUA := 0.35
## Água rasa: o leito (colisão) é o topo do bloco, rente ao chão em volta, e a água fica
## um pouco acima, cobrindo as patas.
const SUPERFICIE_AGUA_RASA := 0.58

# Perfis: polígono convexo no plano XY (anti-horário), dentro de [-0.5, 0.5],
# extrudado ao longo de Z. As rampas sobem no sentido +X (gire no editor com Q/E).
const _BLOCO := [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]
const _MEIO := [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.0), Vector2(-0.5, 0.0)]
const _RAMPA_BAIXA := [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.0)]
const _RAMPA_ALTA := [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.0)]
const _AGUA := [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, SUPERFICIE_AGUA), Vector2(-0.5, SUPERFICIE_AGUA)]
const _AGUA_RASA := [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, SUPERFICIE_AGUA_RASA), Vector2(-0.5, SUPERFICIE_AGUA_RASA)]
# Escadas: dois degraus de 0,25 m em cada célula, seguindo as rampas (a colisão é a rampa,
# então o cachorro sobe sem pular).
const _ESCADA_BAIXA := [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, -0.125), Vector2(0.0, -0.125),
	Vector2(0.0, -0.375), Vector2(-0.5, -0.375)]
const _ESCADA_ALTA := [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.375), Vector2(0.0, 0.375),
	Vector2(0.0, 0.125), Vector2(-0.5, 0.125)]
# Tábua estreita rente ao chão da célula (o topo fica na altura do chão vizinho), para
# atravessar água ou buracos. Largura em Z: 0,36 m.
# Degrau alto: 0,72 m — só pulando, e com graveto na boca o pulo não chega (medido: sem
# graveto o cachorro sobe até ~0,75 m; com graveto, até ~0,65 m).
const _DEGRAU := [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.22), Vector2(-0.5, 0.22)]
const _TABUA := [Vector2(-0.5, -0.58), Vector2(0.5, -0.58), Vector2(0.5, -0.5), Vector2(-0.5, -0.5)]


## Cada tile: nome (editor), perfil (ou `forma`), material (assets/materiais/<nome>.tres), colisão
## ("perfil" = o próprio formato, "nenhuma"), z (profundidade da extrusão) e cor no editor.
## `agua`: o cachorro que cai dentro volta para o último ponto seguro.
## `estreita`: passagem estreita — com graveto grande e pesado, o cachorro se desequilibra.
## `cavavel`: o cachorro (com a habilidade Cavar) desfaz o bloco cavando; no chão (camada -1),
## cavar vira um `buraco` (meio metro fundo: o cachorro sai escalando; um bloco empurrado para
## dentro tapa o buraco).
## `escorregadia`: com graveto pesado na boca o cachorro escorrega e não sobe (rampa lisa).
## `rasa`: água rasa, dá para atravessar a pé; `lentidao` multiplica a velocidade e
## `correnteza` (m/s) arrasta o cachorro no sentido +X do tile (gire no editor com Q/E).
## `aderencia` (0 a 1, padrão 1): com menos, o cachorro demora a arrancar e a parar (neve fofa)
## ou desliza (gelo). `deslizante`: gelo liso — o cachorro e os blocos empurrados deslizam em
## linha reta, sem controle, até bater em algo ou sair do gelo. `lama`: chão de lama (por enquanto só a aparência; no futuro, suja o
## cachorro). As poças da grama e da lama são só visuais (o material desenha). `derrete_em`: o fogo aceso por perto troca o tile por este (-1 = some).
## Colisão: "perfil" (o formato), "bloco" (cubo cheio) ou "nenhuma"; `colisao_perfil` usa
## outro perfil para a colisão (escadas colidem como rampa).
## Cantos de rampa (`forma` "canto_externo"/"canto_interno", `base` = altura de onde a rampa
## sai): juntam duas rampas em L. A rampa sobe para +X e +Z (gire com Q/E no editor).
static func definicoes() -> Array[Dictionary]:
	return [
		{id = GRAMA, nome = "Grama", perfil = _BLOCO, material = "grama", cor = Color("5da03a")},
		{id = TERRA, nome = "Terra", perfil = _BLOCO, material = "terra", cor = Color("8a5a34")},
		{id = PEDRA, nome = "Pedra", perfil = _BLOCO, material = "pedra", cor = Color("8d9098")},
		{id = MATO, nome = "Mato", perfil = _BLOCO, material = "mato", cor = Color("2f7a33")},
		{id = RAMPA_BAIXA, nome = "Rampa baixa", perfil = _RAMPA_BAIXA, material = "grama", cor = Color("7cbf55")},
		{id = RAMPA_ALTA, nome = "Rampa alta", perfil = _RAMPA_ALTA, material = "grama", cor = Color("6aae48")},
		{id = MEIO_BLOCO, nome = "Meio bloco", perfil = _MEIO, material = "grama", cor = Color("92c96e")},
		{id = MATO_BAIXO, nome = "Mato baixo", perfil = _MEIO, material = "mato", cor = Color("4d9a45")},
		{id = AGUA, nome = "Água", perfil = _AGUA, material = "agua", colisao = "nenhuma", agua = true, cor = Color("3d8ccf")},
		{id = TABUA, nome = "Tábua", perfil = _TABUA, material = "madeira", z = 0.18, estreita = true, cor = Color("a8773f")},
		{id = TERRA_FOFA, nome = "Terra fofa", perfil = _BLOCO, material = "terra_fofa", cavavel = true, cor = Color("a87b4f")},
		{id = AGUA_RASA, nome = "Água rasa", perfil = _AGUA_RASA, material = "agua_rasa", colisao = "bloco", rasa = true, lentidao = 0.6, cor = Color("6fb6e0")},
		{id = CORRENTEZA, nome = "Correnteza", perfil = _AGUA_RASA, material = "agua_correnteza", colisao = "bloco", rasa = true, lentidao = 0.5, correnteza = 3.2, cor = Color("4f9fd6")},
		{id = ESCADA_BAIXA, nome = "Escada baixa", perfil = _ESCADA_BAIXA, colisao_perfil = _RAMPA_BAIXA, material = "pedra", cor = Color("9aa0a8")},
		{id = ESCADA_ALTA, nome = "Escada alta", perfil = _ESCADA_ALTA, colisao_perfil = _RAMPA_ALTA, material = "pedra", cor = Color("8a9098")},
		{id = CANTO_RAMPA_BAIXA, nome = "Canto de rampa baixa", forma = "canto_externo", base = -0.5, material = "grama", cor = Color("86c460")},
		{id = CANTO_RAMPA_ALTA, nome = "Canto de rampa alta", forma = "canto_externo", base = 0.0, material = "grama", cor = Color("74b350")},
		{id = CANTO_INTERNO_BAIXA, nome = "Canto interno baixa", forma = "canto_interno", base = -0.5, material = "grama", cor = Color("8fcf66")},
		{id = CANTO_INTERNO_ALTA, nome = "Canto interno alta", forma = "canto_interno", base = 0.0, material = "grama", cor = Color("7dbd57")},
		{id = BURACO, nome = "Buraco", perfil = _MEIO, material = "terra", buraco = true, cor = Color("6e4a2a")},
		{id = RAMPA_LISA_BAIXA, nome = "Rampa lisa baixa", perfil = _RAMPA_BAIXA, material = "pedra_lisa", escorregadia = true, cor = Color("9fb3c0")},
		{id = RAMPA_LISA_ALTA, nome = "Rampa lisa alta", perfil = _RAMPA_ALTA, material = "pedra_lisa", escorregadia = true, cor = Color("8aa0ae")},
		{id = DEGRAU_ALTO, nome = "Degrau alto", perfil = _DEGRAU, material = "pedra", cor = Color("a0a4ac")},
		{id = NEVE_FOFA, nome = "Neve fofa", perfil = _BLOCO, material = "neve_fofa", lentidao = 0.7, aderencia = 0.25, derrete_em = TERRA, cor = Color("f2f5fb")},
		{id = MONTE_DE_NEVE, nome = "Monte de neve", perfil = _BLOCO, material = "monte_neve", cavavel = true, derrete_em = -1, cor = Color("dde6f2")},
		{id = GELO, nome = "Gelo", perfil = _BLOCO, material = "gelo", aderencia = 0.06, cor = Color("a6d4f0")},
		{id = GRAMA_COM_POCAS, nome = "Grama com poças", perfil = _BLOCO, material = "grama_pocas", cor = Color("4f9a5a")},
		{id = LAMA, nome = "Lama", perfil = _BLOCO, material = "lama", lama = true, cor = Color("5e4028")},
		{id = GELO_LISO, nome = "Gelo liso", perfil = _BLOCO, material = "gelo_liso", deslizante = true, cor = Color("c4e6fa")},
	]


static func definicao(id: int) -> Dictionary:
	for d in definicoes():
		if d.id == id:
			return d
	return {}


static func eh_agua(id: int) -> bool:
	return definicao(id).get("agua", false)


static func eh_estreita(id: int) -> bool:
	return definicao(id).get("estreita", false)


static func eh_cavavel(id: int) -> bool:
	return definicao(id).get("cavavel", false)


static func eh_buraco(id: int) -> bool:
	return definicao(id).get("buraco", false)


static func eh_lama(id: int) -> bool:
	return definicao(id).get("lama", false)


static func eh_escorregadia(id: int) -> bool:
	return definicao(id).get("escorregadia", false)


## Gelo liso (o "gelo de puzzle"): quem pisa desliza em linha reta até bater em algo.
static func eh_deslizante(id: int) -> bool:
	return definicao(id).get("deslizante", false)


## O fogo derrete este tile?
static func derrete(id: int) -> bool:
	return definicao(id).has("derrete_em")


## Meia largura (m) da passagem estreita, no eixo Z do tile.
static func meia_largura(id: int) -> float:
	return definicao(id).get("z", 0.5)


## Caminho da biblioteca de um bioma (a da floresta, se não houver).
static func biblioteca_do_bioma(bioma: int) -> String:
	return BIBLIOTECAS[bioma] if bioma >= 0 and bioma < BIBLIOTECAS.size() else CAMINHO_BIBLIOTECA


## Monta a MeshLibrary a partir das definições, com os materiais do bioma.
static func construir_biblioteca(bioma := 0) -> MeshLibrary:
	var trocas: Dictionary = MATERIAIS_POR_BIOMA.get(bioma, {})
	var biblioteca := MeshLibrary.new()
	for d in definicoes():
		var malha: ArrayMesh
		var formas := []
		match d.get("forma", "prisma"):
			"canto_externo", "canto_interno":
				var interno: bool = d.forma == "canto_interno"
				malha = malha_canto(d.base, interno)
				formas = _formas_canto(d.base, interno)
			_:
				malha = malha_prisma(PackedVector2Array(d.perfil), d.get("z", 0.5))
				match d.get("colisao", "perfil"):
					"perfil":
						var perfil_colisao := PackedVector2Array(d.get("colisao_perfil", d.perfil))
						formas = [_forma_convexa(malha_prisma(perfil_colisao, d.get("z", 0.5))), Transform3D.IDENTITY]
					"bloco":
						var caixa := BoxShape3D.new()
						caixa.size = Vector3.ONE
						formas = [caixa, Transform3D.IDENTITY]
		malha = _com_folga(malha)
		malha.surface_set_material(0, load("res://assets/materiais/%s.tres" % trocas.get(d.material, d.material)))
		biblioteca.create_item(d.id)
		biblioteca.set_item_name(d.id, d.nome)
		biblioteca.set_item_mesh(d.id, malha)
		if not formas.is_empty():
			biblioteca.set_item_shapes(d.id, formas)
	return biblioteca


## A mesma malha um pouco mais larga em X e Z (ver FOLGA_VISUAL); a altura não muda.
static func _com_folga(malha: ArrayMesh) -> ArrayMesh:
	var arrays := malha.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var escala := (0.5 + FOLGA_VISUAL) / 0.5
	for i in vertices.size():
		vertices[i] = Vector3(vertices[i].x * escala, vertices[i].y, vertices[i].z * escala)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var nova := ArrayMesh.new()
	nova.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return nova


static func _forma_convexa(malha: ArrayMesh) -> ConvexPolygonShape3D:
	var forma := ConvexPolygonShape3D.new()
	forma.points = malha.get_faces()
	return forma


## Canto de rampa: a superfície é o menor (canto externo) ou o maior (canto interno) entre
## uma rampa que sobe em +X e outra que sobe em +Z, saindo da altura `base` e subindo 0,5 m.
static func malha_canto(base: float, interno: bool) -> ArrayMesh:
	var altura := func(x: float, z: float) -> float:
		var u := x + 0.5
		var v := z + 0.5
		return base + 0.5 * (maxf(u, v) if interno else minf(u, v))
	var cantos := [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]
	var triangulos: Array[Vector3] = []
	var topo := func(c: Vector2) -> Vector3: return Vector3(c.x, altura.call(c.x, c.y), c.y)
	var chao := func(c: Vector2) -> Vector3: return Vector3(c.x, -0.5, c.y)
	# Topo: duas faces planas, divididas na diagonal do canto baixo ao canto alto.
	triangulos.append_array([topo.call(cantos[0]), topo.call(cantos[1]), topo.call(cantos[2])])
	triangulos.append_array([topo.call(cantos[0]), topo.call(cantos[2]), topo.call(cantos[3])])
	# Fundo e laterais.
	triangulos.append_array([chao.call(cantos[0]), chao.call(cantos[1]), chao.call(cantos[2])])
	triangulos.append_array([chao.call(cantos[0]), chao.call(cantos[2]), chao.call(cantos[3])])
	for i in 4:
		var a: Vector2 = cantos[i]
		var b: Vector2 = cantos[(i + 1) % 4]
		triangulos.append_array([chao.call(a), chao.call(b), topo.call(b)])
		triangulos.append_array([chao.call(a), topo.call(b), topo.call(a)])
	return malha_triangulos(triangulos, Vector3(0.0, -0.45, 0.0), altura)


## Colisão dos cantos: o externo é convexo (uma forma); o interno é a união das duas rampas.
static func _formas_canto(base: float, interno: bool) -> Array:
	if not interno:
		return [_forma_convexa(malha_canto(base, false)), Transform3D.IDENTITY]
	var perfil := PackedVector2Array(_RAMPA_BAIXA if base < 0.0 else _RAMPA_ALTA)
	var rampa := _forma_convexa(malha_prisma(perfil, 0.5))
	# A mesma rampa girada para subir em +Z.
	return [rampa, Transform3D.IDENTITY, rampa, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3.ZERO)]


## Malha a partir de uma lista de triângulos (3 vértices cada). A face da frente fica virada
## para longe de `ponto_interno`; `altura(x, z)` dá o topo para a franja de grama (UV.y).
static func malha_triangulos(triangulos: Array[Vector3], ponto_interno: Vector3, altura: Callable) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normais := PackedVector3Array()
	var uvs := PackedVector2Array()
	for i in range(0, triangulos.size(), 3):
		var a := triangulos[i]
		var b := triangulos[i + 1]
		var c := triangulos[i + 2]
		var normal := (b - a).cross(c - a)
		if normal.length_squared() < 0.000001:
			continue  # degenerado (lateral de altura zero)
		normal = normal.normalized()
		if normal.dot((a + b + c) / 3.0 - ponto_interno) < 0.0:
			normal = -normal
		# Godot desenha a face da frente com os vértices em sentido horário.
		if (b - a).cross(c - a).dot(normal) > 0.0:
			var troca := b
			b = c
			c = troca
		for v: Vector3 in [a, b, c]:
			vertices.append(v)
			normais.append(normal)
			uvs.append(Vector2(0.0, altura.call(v.x, v.z) - v.y))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normais
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var malha := ArrayMesh.new()
	malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return malha


## Prisma: `perfil` (XY) extrudado de -z a +z. Normais chapadas.
## UV.y = distância (m) até o topo do perfil naquela coordenada X — o shader usa isso para
## desenhar a franja de grama nas laterais, inclusive nas rampas.
static func malha_prisma(perfil: PackedVector2Array, z: float) -> ArrayMesh:
	# Arrays comuns (não Packed*): a lambda abaixo precisa alterar estes mesmos objetos,
	# e arrays Packed seriam copiados ao serem capturados.
	var vertices: Array[Vector3] = []
	var normais: Array[Vector3] = []
	var uvs: Array[Vector2] = []

	var adicionar_tri := func(a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
		# Godot desenha a face da frente com os vértices em sentido horário.
		if (b - a).cross(c - a).dot(normal) > 0.0:
			var t := b
			b = c
			c = t
		for v: Vector3 in [a, b, c]:
			vertices.append(v)
			normais.append(normal)
			uvs.append(Vector2(0.0, _topo_do_perfil(perfil, v.x) - v.y))

	# Laterais (uma por aresta do perfil).
	for i in perfil.size():
		var a := perfil[i]
		var b := perfil[(i + 1) % perfil.size()]
		var direcao := b - a
		var normal := Vector3(direcao.y, -direcao.x, 0.0).normalized()
		var a0 := Vector3(a.x, a.y, -z)
		var b0 := Vector3(b.x, b.y, -z)
		var a1 := Vector3(a.x, a.y, z)
		var b1 := Vector3(b.x, b.y, z)
		adicionar_tri.call(a0, b0, b1, normal)
		adicionar_tri.call(a0, b1, a1, normal)

	# Tampas da frente e de trás (triangulação serve também para perfis côncavos, como escadas).
	var indices := Geometry2D.triangulate_polygon(perfil)
	for lado: float in [-1.0, 1.0]:
		var normal := Vector3(0.0, 0.0, lado)
		for i in range(0, indices.size(), 3):
			var a := perfil[indices[i]]
			var b := perfil[indices[i + 1]]
			var c := perfil[indices[i + 2]]
			adicionar_tri.call(Vector3(a.x, a.y, z * lado), Vector3(b.x, b.y, z * lado), Vector3(c.x, c.y, z * lado), normal)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(vertices)
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(normais)
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(uvs)
	var malha := ArrayMesh.new()
	malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return malha


## Maior Y do perfil na coordenada `x`.
static func _topo_do_perfil(perfil: PackedVector2Array, x: float) -> float:
	var topo := -INF
	for i in perfil.size():
		var a := perfil[i]
		var b := perfil[(i + 1) % perfil.size()]
		if x < minf(a.x, b.x) - 0.0001 or x > maxf(a.x, b.x) + 0.0001:
			continue
		if is_equal_approx(a.x, b.x):
			topo = maxf(topo, maxf(a.y, b.y))
		else:
			topo = maxf(topo, lerpf(a.y, b.y, (x - a.x) / (b.x - a.x)))
	return topo

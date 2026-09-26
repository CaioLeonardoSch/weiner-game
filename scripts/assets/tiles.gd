@tool
class_name Tiles
## Tiles do terreno (itens do GridMap "Terreno" de cada fase).
##
## Os IDs ficam gravados dentro das fases: nunca renumere nem reaproveite um ID.
## Para criar um tile novo: acrescente uma constante e uma entrada em `definicoes()` (sempre
## no fim) e gere a biblioteca de novo (ver ferramentas/gerar_tiles.gd). A aparência vem
## dos materiais em assets/materiais/ — mudar as cores lá não exige gerar de novo.

const CAMINHO_BIBLIOTECA := "res://assets/tiles/tiles.tres"

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

## Altura (no espaço do tile, de -0.5 a 0.5) da superfície da água.
const SUPERFICIE_AGUA := 0.35

# Perfis: polígono convexo no plano XY (anti-horário), dentro de [-0.5, 0.5],
# extrudado ao longo de Z. As rampas sobem no sentido +X (gire no editor com Q/E).
const _BLOCO := [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]
const _MEIO := [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.0), Vector2(-0.5, 0.0)]
const _RAMPA_BAIXA := [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.0)]
const _RAMPA_ALTA := [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.0)]
const _AGUA := [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, SUPERFICIE_AGUA), Vector2(-0.5, SUPERFICIE_AGUA)]
# Tábua estreita rente ao chão da célula (o topo fica na altura do chão vizinho), para
# atravessar água ou buracos. Largura em Z: 0,36 m.
const _TABUA := [Vector2(-0.5, -0.58), Vector2(0.5, -0.58), Vector2(0.5, -0.5), Vector2(-0.5, -0.5)]


## Cada tile: nome (editor), perfil, material (assets/materiais/<nome>.tres), colisão
## ("perfil" = o próprio formato, "nenhuma"), z (profundidade da extrusão) e cor no editor.
## `agua`: o cachorro que cai dentro volta para o último ponto seguro.
## `estreita`: passagem estreita — com graveto grande e pesado, o cachorro se desequilibra.
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


## Meia largura (m) da passagem estreita, no eixo Z do tile.
static func meia_largura(id: int) -> float:
	return definicao(id).get("z", 0.5)


## Monta a MeshLibrary a partir das definições.
static func construir_biblioteca() -> MeshLibrary:
	var biblioteca := MeshLibrary.new()
	for d in definicoes():
		var perfil := PackedVector2Array(d.perfil)
		var z: float = d.get("z", 0.5)
		var malha := malha_prisma(perfil, z)
		malha.surface_set_material(0, load("res://assets/materiais/%s.tres" % d.material))
		biblioteca.create_item(d.id)
		biblioteca.set_item_name(d.id, d.nome)
		biblioteca.set_item_mesh(d.id, malha)
		if d.get("colisao", "perfil") == "perfil":
			var forma := ConvexPolygonShape3D.new()
			forma.points = malha.get_faces()
			biblioteca.set_item_shapes(d.id, [forma, Transform3D.IDENTITY])
	return biblioteca


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

	# Tampas da frente e de trás (leque, o perfil é convexo).
	for lado: float in [-1.0, 1.0]:
		var normal := Vector3(0.0, 0.0, lado)
		for i in range(1, perfil.size() - 1):
			adicionar_tri.call(
				Vector3(perfil[0].x, perfil[0].y, z * lado),
				Vector3(perfil[i].x, perfil[i].y, z * lado),
				Vector3(perfil[i + 1].x, perfil[i + 1].y, z * lado),
				normal)

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

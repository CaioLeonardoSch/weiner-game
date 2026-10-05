extends SceneTree
## Gera o Dia 1 do parque, "O primeiro graveto" (scenes/parque/dia_01.tscn; ver docs/DESIGN.md):
## uma trilha no mato saindo da área central, com uma curva; um tronco semicaído para rastejar
## por baixo; dali, ao longe, a moita que se mexe; um córrego fundo com pedras; a moita, que leva
## a uma pequena clareira com o esquilo, a árvore, o raio de sol e o galho (o cajado lendário).
## Na volta, depois do córrego, o corte da volta termina o dia.
##   godot --headless --path . --script res://ferramentas/gerar_dia_01.gd
## Sobrescreve a cena: mudanças feitas no editor se perdem.
## Provisório até a arte do parque: as formas, as distâncias e o visual.

const OBJ := "res://scenes/objetos/%s.tscn"
const ARQUIVO := "res://scenes/parque/dia_01.tscn"
## Limites do gramado (células).
const X0 := -16
const X1 := 24
const Z0 := -68
const Z1 := 12
## O x do meio da trilha depois da curva, e o z de cada lugar (a trilha vai para o -Z).
const TRILHA_X := 6.5
const Z_TRONCO := -26.0
const Z_CORTE := -31.0
const Z_CORREGO := -37.5
const Z_MOITA := -46.5
const CENTRO_CLAREIRA := Vector3(6.5, 0.0, -53.5)
const RAIO_CLAREIRA := 5.5
## Espessura (células) do mato em volta do que é caminho; as árvores ficam além.
const MATO := 2

var fase: Fase
var t: GridMap
var rng := RandomNumberGenerator.new()
## Vector2i(x, z) das células de caminho (sem mato).
var livre := {}
var ocupado := {}


func _initialize() -> void:
	rng.seed = 101
	fase = Fase.nova("O primeiro graveto")
	fase.id = "parque_dia_01"
	fase.name = "Dia01"
	fase.objetivo = Fase.OBJETIVO_DIA
	fase.terceira_pessoa = true
	fase.habilidades = Fase.HABILIDADE_LATIR
	fase.raca = &"salsicha"
	fase.raca_fixa = true
	fase.regiao = &"floresta"
	t = fase.get_node("Terreno")
	_caminho()
	_terreno()
	_objetos()
	_arvores()
	DirAccess.make_dir_recursive_absolute(ARQUIVO.get_base_dir())
	var cena := PackedScene.new()
	var erro := cena.pack(fase)
	if erro == OK:
		erro = ResourceSaver.save(cena, ARQUIVO)
	print(ARQUIVO, ": ", error_string(erro))
	fase.free()
	quit()


func obj(nome: String, pos: Vector3, yaw := 0.0) -> ObjetoFase:
	return fase.adicionar_objeto(load(OBJ % nome), pos, yaw)


func _livrar(x0: int, x1: int, z0: int, z1: int) -> void:
	for x in range(x0, x1 + 1):
		for z in range(z0, z1 + 1):
			livre[Vector2i(x, z)] = true


## A trilha (3 m de largura): reta desde o começo, uma curva em diagonal e a reta comprida até a
## moita; depois da moita, a clareira redonda.
func _caminho() -> void:
	_livrar(-1, 1, -12, 3)
	for k in 6:
		_livrar(-1 + k, 2 + k, -13 - k, -12 - k)
	_livrar(5, 7, -46, -18)
	# A moita ocupa a abertura entre a trilha e a clareira; do outro lado, a entrada da clareira.
	_livrar(5, 7, -47, -47)
	_livrar(5, 7, -49, -48)
	for x in range(X0, X1):
		for z in range(Z0, Z1):
			if Vector2(x + 0.5 - CENTRO_CLAREIRA.x, z + 0.5 - CENTRO_CLAREIRA.z).length() <= RAIO_CLAREIRA:
				livre[Vector2i(x, z)] = true


func _perto_do_caminho(x: int, z: int, distancia: int) -> bool:
	for dx in range(-distancia, distancia + 1):
		for dz in range(-distancia, distancia + 1):
			if livre.has(Vector2i(x + dx, z + dz)):
				return true
	return false


## Grama em tudo, o córrego atravessando o mapa (água funda, sem mato em cima: cair nele é
## natural) e o mato em volta do caminho. A fileira da moita é mato dos lados dela.
func _terreno() -> void:
	var corrego_z0 := floori(Z_CORREGO - 1.5)
	for x in range(X0, X1):
		for z in range(Z0, Z1):
			var no_corrego := z >= corrego_z0 and z < corrego_z0 + 3
			t.set_cell_item(Vector3i(x, -1, z), Tiles.AGUA if no_corrego else Tiles.GRAMA)
			var celula := Vector2i(x, z)
			if no_corrego:
				ocupado[celula] = true
			elif livre.has(celula):
				ocupado[celula] = true
				# Terra no meio da trilha (não na clareira).
				if z > -47 and absf(x + 0.5 - _meio_da_trilha(z)) < 0.6:
					t.set_cell_item(Vector3i(x, -1, z), Tiles.TERRA)
			elif _perto_do_caminho(x, z, MATO):
				ocupado[celula] = true
				t.set_cell_item(Vector3i(x, 0, z), Tiles.MATO)
	for x in range(5, 8):
		t.set_cell_item(Vector3i(x, 0, -47), GridMap.INVALID_CELL_ITEM)


## O x do meio da trilha na altura `z`.
static func _meio_da_trilha(z: int) -> float:
	if z >= -12:
		return 0.5
	if z <= -18:
		return TRILHA_X
	return 0.5 + float(-12 - z) + 0.5


func _objetos() -> void:
	# Começo: o cachorro acabou de sair da área central, olhando trilha adentro (-Z).
	obj("inicio_cachorro", Vector3(0.5, 0.0, 1.0), PI * 0.5)
	var tronco := obj("tronco_semicaido", Vector3(TRILHA_X, 0.0, Z_TRONCO)) as TroncoSemicaido
	tronco.comprimento = 4.5
	var corte := obj("corte_da_volta", Vector3(TRILHA_X, 0.0, Z_CORTE)) as CorteDaVolta
	corte.tamanho = Vector3(3.6, 2.0, 1.0)
	var pedras := obj("pedras_corrego", Vector3(TRILHA_X, 0.0, Z_CORREGO)) as PedrasCorrego
	pedras.quantidade = 3
	pedras.espacamento = 1.1
	var moita := obj("moita_passagem", Vector3(TRILHA_X, 0.0, Z_MOITA)) as MoitaPassagem
	moita.largura = 3.0
	moita.chamar_atencao = true
	# A clareira: a árvore do esquilo, o esquilo comendo, e onde o galho cai (no raio de sol).
	var arvore := obj("arvore", Vector3(8.7, 0.0, -54.5)) as Arvore
	arvore.tipo = Voxel.TipoArvore.REDONDA
	arvore.variante = 2
	obj("esquilo_do_galho", Vector3(6.9, 0.0, -52.4), deg_to_rad(-30))
	var queda := Vector3(7.2, 0.0, -54.3)
	obj("raio_de_sol", queda)
	var galho := obj("graveto", queda, deg_to_rad(60)) as Graveto
	galho.comprimento = 1.0
	galho.formato = Graveto.Formato.CAJADO
	for i in 5:
		var angulo := rng.randf_range(-PI, PI)
		var ponto := CENTRO_CLAREIRA + Vector3(sin(angulo), 0.0, cos(angulo)) * rng.randf_range(2.5, 4.5)
		if ponto.distance_to(queda) > 1.6:
			var flores := obj("flores", ponto, rng.randf_range(-PI, PI)) as Flores
			flores.variante = rng.randi_range(0, 7)


## Floresta fechada em volta, depois do mato.
func _arvores() -> void:
	for tentativa in 6000:
		var x := rng.randi_range(X0 + 1, X1 - 2)
		var z := rng.randi_range(Z0 + 1, Z1 - 2)
		if ocupado.has(Vector2i(x, z)) or _perto_do_caminho(x, z, MATO + 1):
			continue
		var arvore := obj("arvore", Vector3(x + rng.randf_range(0.2, 0.8), 0, z + rng.randf_range(0.2, 0.8))) as Arvore
		var sorteio := rng.randf()
		arvore.tipo = Voxel.TipoArvore.PINHEIRO if sorteio < 0.4 else (Voxel.TipoArvore.REDONDA if sorteio < 0.88 else Voxel.TipoArvore.ARBUSTO)
		arvore.ao_colocar_no_editor(rng)
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				ocupado[Vector2i(x + dx, z + dz)] = true

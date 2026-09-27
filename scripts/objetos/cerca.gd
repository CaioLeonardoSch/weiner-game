@tool
class_name Cerca
extends ObjetoFase
## Cerca de madeira reta (ao longo do X local), com postes a cada metro e duas travessas.
## Bloqueia o cachorro e o graveto, mas não tapa a visão: dá para ver através dela na câmera
## isométrica — ao contrário de um muro alto, que esconde o que está atrás.
## Com `terra_fofa`, o chão embaixo dela é de terra fofa: cavando (C) de frente para a cerca,
## o cachorro abre um vão por baixo naquele metro — passagem baixa (até ALTURA_VAO): o salsicha
## e o pug passam, o border collie não; graveto comprido, só ao comprido.

## Comprimento em metros.
@export_range(1, 20) var comprimento := 2:
	set(valor):
		comprimento = maxi(valor, 1)
		_montar()
@export var terra_fofa := false:
	set(valor):
		terra_fofa = valor
		_montar()

const ALTURA := 0.8
const ESPESSURA := 0.12
const _MADEIRAS := [Color("8a6038"), Color("7a5230"), Color("94693f")]
## Altura livre embaixo da cerca onde o cachorro cavou.
const ALTURA_VAO := 0.66

## Metros (índice a partir da ponta -X) já cavados.
var cavados: Array[int] = []


func nome_no_editor() -> String:
	return "Cerca"


func categoria_no_editor() -> String:
	return "Cenário"


func propriedades_editaveis() -> Array[StringName]:
	return [&"comprimento", &"terra_fofa"]


func caixa_editor() -> AABB:
	return AABB(Vector3(-comprimento * 0.5, 0.0, -0.1), Vector3(comprimento, ALTURA, 0.2))


func _ready() -> void:
	_montar()


func _metro_em(ponto: Vector3) -> int:
	return clampi(floori(to_local(ponto).x + comprimento * 0.5), 0, comprimento - 1)


func pode_cavar_em(ponto: Vector3) -> bool:
	return terra_fofa and not _metro_em(ponto) in cavados


## Abre o vão por baixo do metro da cerca mais perto de `ponto`.
func cavar_em(ponto: Vector3) -> void:
	if pode_cavar_em(ponto):
		cavados.append(_metro_em(ponto))
		_montar()


func _montar() -> void:
	if not is_node_ready():
		return
	for filho in get_children():
		remove_child(filho)
		filho.queue_free()

	var voxels := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = comprimento * 17
	var meia := comprimento * 8
	for i in comprimento + 1:
		var x := -meia + i * 16
		var cor: Color = _MADEIRAS[rng.randi() % _MADEIRAS.size()].darkened(0.1)
		for y in 12:
			for dx in [-1, 0]:
				for dz in [-1, 0]:
					voxels[Vector3i(x + dx, y, dz)] = cor
	for x in range(-meia, meia):
		var metro := (x + meia) / 16
		# Metro cavado: só a travessa de cima fica (mais alta, acima do vão).
		var travessas := [10, 11] if metro in cavados else [4, 5, 8, 9]
		for y in travessas:
			for z in [-1, 0]:
				voxels[Vector3i(x, y, z)] = _MADEIRAS[rng.randi() % _MADEIRAS.size()]
	var modelo := MeshInstance3D.new()
	modelo.name = "Modelo"
	modelo.mesh = Voxel.malha(voxels, 1.0 / 16.0)
	add_child(modelo)
	if terra_fofa:
		add_child(_faixa_de_terra(meia))

	var corpo := StaticBody3D.new()
	corpo.name = "Corpo"
	corpo.collision_layer = 4
	corpo.collision_mask = 0
	add_child(corpo)
	# Um bloco de colisão por metro: o cavado começa acima do vão.
	for metro in comprimento:
		var base := ALTURA_VAO if metro in cavados else 0.0
		var forma := BoxShape3D.new()
		forma.size = Vector3(1.0, ALTURA - base, ESPESSURA)
		var colisao := CollisionShape3D.new()
		colisao.shape = forma
		colisao.position = Vector3(-comprimento * 0.5 + metro + 0.5, base + (ALTURA - base) * 0.5, 0)
		corpo.add_child(colisao)


## Faixa de terra fofa no chão, dos dois lados da cerca; nos metros cavados, um buraco escuro
## com a terra amontoada em volta.
func _faixa_de_terra(meia: int) -> MeshInstance3D:
	var voxels := {}
	var terra := Color("a87b4f")
	for x in range(-meia, meia):
		var metro := (x + meia) / 16
		for z in range(-5, 5):
			if metro in cavados and absi(z) <= 3 and (x + meia) % 16 >= 3 and (x + meia) % 16 <= 12:
				voxels[Vector3i(x, -1, z)] = Color("2e1d10")
				if absi(z) == 3:
					voxels[Vector3i(x, 0, z)] = terra.darkened(0.15)
			else:
				voxels[Vector3i(x, -1, z)] = terra.darkened(0.1 if (x * 7 + z * 3) % 5 == 0 else 0.0)
	var faixa := MeshInstance3D.new()
	faixa.name = "Terra"
	faixa.mesh = Voxel.malha(voxels, 1.0 / 16.0)
	# Um pouquinho acima do chão para não brigar com a grama.
	faixa.position.y = 0.065
	return faixa

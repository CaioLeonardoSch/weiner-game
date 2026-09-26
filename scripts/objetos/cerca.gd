@tool
class_name Cerca
extends ObjetoFase
## Cerca de madeira reta (ao longo do X local), com postes a cada metro e duas travessas.
## Bloqueia o cachorro e o graveto, mas não tapa a visão: dá para ver através dela na câmera
## isométrica — ao contrário de um muro alto, que esconde o que está atrás.

## Comprimento em metros.
@export_range(1, 20) var comprimento := 2:
	set(valor):
		comprimento = maxi(valor, 1)
		_montar()

const ALTURA := 0.8
const ESPESSURA := 0.12
const _MADEIRAS := [Color("8a6038"), Color("7a5230"), Color("94693f")]


func nome_no_editor() -> String:
	return "Cerca"


func categoria_no_editor() -> String:
	return "Cenário"


func propriedades_editaveis() -> Array[StringName]:
	return [&"comprimento"]


func caixa_editor() -> AABB:
	return AABB(Vector3(-comprimento * 0.5, 0.0, -0.1), Vector3(comprimento, ALTURA, 0.2))


func _ready() -> void:
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
	for y in [4, 5, 8, 9]:
		for x in range(-meia, meia):
			for z in [-1, 0]:
				voxels[Vector3i(x, y, z)] = _MADEIRAS[rng.randi() % _MADEIRAS.size()]
	var modelo := MeshInstance3D.new()
	modelo.name = "Modelo"
	modelo.mesh = Voxel.malha(voxels, 1.0 / 16.0)
	add_child(modelo)

	var corpo := StaticBody3D.new()
	corpo.name = "Corpo"
	corpo.collision_layer = 4
	corpo.collision_mask = 0
	add_child(corpo)
	var forma := BoxShape3D.new()
	forma.size = Vector3(comprimento, ALTURA, ESPESSURA)
	var colisao := CollisionShape3D.new()
	colisao.shape = forma
	colisao.position = Vector3(0, ALTURA * 0.5, 0)
	corpo.add_child(colisao)

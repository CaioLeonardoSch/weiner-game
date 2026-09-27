@tool
class_name Cercado
extends ObjetoFase
## Cercado de madeira para as ovelhas, com uma porteira aberta (1 m) no meio do lado +X
## (gire o objeto para mudar o lado). Nas fases de pastoreio, a fase termina quando todas as
## ovelhas estão dentro de algum cercado. A cerca e a colisão são geradas pelo `tamanho`.

## Largura (X) e profundidade (Z) em metros.
@export var tamanho := Vector2i(3, 3):
	set(valor):
		tamanho = Vector2i(maxi(valor.x, 2), maxi(valor.y, 2))
		_montar()

const ALTURA := 0.8
const ESPESSURA := 0.12
const PORTEIRA := 1.0
## Folga (m) das bordas para contar como "dentro": na porteira ainda não vale.
const MARGEM := 0.35
const _MADEIRAS := [Color("8a6038"), Color("7a5230"), Color("94693f")]


func nome_no_editor() -> String:
	return "Cercado"


func categoria_no_editor() -> String:
	return "Regras"


func propriedades_editaveis() -> Array[StringName]:
	return [&"tamanho"]


func caixa_editor() -> AABB:
	return AABB(Vector3(-tamanho.x * 0.5, 0.0, -tamanho.y * 0.5), Vector3(tamanho.x, ALTURA, tamanho.y))


func _ready() -> void:
	_montar()
	if not Engine.is_editor_hint():
		add_to_group(&"abrigos")


## O ponto (global) está bem dentro do cercado (longe da cerca e da porteira)?
func contem(ponto: Vector3) -> bool:
	var local := to_local(ponto)
	return absf(local.x) < tamanho.x * 0.5 - MARGEM and absf(local.z) < tamanho.y * 0.5 - MARGEM \
		and local.y > -0.6 and local.y < 1.5


func _montar() -> void:
	if not is_node_ready():
		return
	for filho in get_children():
		remove_child(filho)
		filho.queue_free()

	# --- Visual: postes a cada metro e duas travessas; a porteira fica sem travessa.
	var voxels := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = tamanho.x * 31 + tamanho.y
	var meia_x := tamanho.x * 8
	var meia_z := tamanho.y * 8
	var porteira := int(PORTEIRA * 8)
	var cantos: Array[Vector2i] = []
	for i in tamanho.x + 1:
		cantos.append(Vector2i(-meia_x + i * 16, -meia_z))
		cantos.append(Vector2i(-meia_x + i * 16, meia_z))
	for j in range(1, tamanho.y):
		cantos.append(Vector2i(-meia_x, -meia_z + j * 16))
		var z := -meia_z + j * 16
		if absi(z) >= porteira:
			cantos.append(Vector2i(meia_x, z))
	# Postes da porteira.
	cantos.append(Vector2i(meia_x, -porteira))
	cantos.append(Vector2i(meia_x, porteira))
	for poste in cantos:
		var cor: Color = _MADEIRAS[rng.randi() % _MADEIRAS.size()].darkened(0.1)
		for y in 12:
			for dx in [-1, 0]:
				for dz in [-1, 0]:
					voxels[Vector3i(poste.x + dx, y, poste.y + dz)] = cor
	for y in [4, 8]:
		for x in range(-meia_x, meia_x):
			voxels[Vector3i(x, y, -meia_z)] = _MADEIRAS[rng.randi() % _MADEIRAS.size()]
			voxels[Vector3i(x, y, meia_z - 1)] = _MADEIRAS[rng.randi() % _MADEIRAS.size()]
		for z in range(-meia_z, meia_z):
			voxels[Vector3i(-meia_x, y, z)] = _MADEIRAS[rng.randi() % _MADEIRAS.size()]
			if z < -porteira or z >= porteira:
				voxels[Vector3i(meia_x - 1, y, z)] = _MADEIRAS[rng.randi() % _MADEIRAS.size()]
	var modelo := MeshInstance3D.new()
	modelo.name = "Modelo"
	modelo.mesh = Voxel.malha(voxels, 1.0 / 16.0)
	add_child(modelo)

	# --- Colisão: uma caixa por lado; o lado da porteira em dois pedaços.
	var cerca := StaticBody3D.new()
	cerca.name = "Cerca"
	cerca.collision_layer = 4
	cerca.collision_mask = 0
	add_child(cerca)
	var largura := float(tamanho.x)
	var fundo := float(tamanho.y)
	_caixa(cerca, Vector3(0, 0, -fundo * 0.5), Vector3(largura, ALTURA, ESPESSURA))
	_caixa(cerca, Vector3(0, 0, fundo * 0.5), Vector3(largura, ALTURA, ESPESSURA))
	_caixa(cerca, Vector3(-largura * 0.5, 0, 0), Vector3(ESPESSURA, ALTURA, fundo))
	var pedaco := (fundo - PORTEIRA) * 0.5
	if pedaco > 0.01:
		_caixa(cerca, Vector3(largura * 0.5, 0, -(PORTEIRA + pedaco) * 0.5), Vector3(ESPESSURA, ALTURA, pedaco))
		_caixa(cerca, Vector3(largura * 0.5, 0, (PORTEIRA + pedaco) * 0.5), Vector3(ESPESSURA, ALTURA, pedaco))


func _caixa(corpo: StaticBody3D, centro: Vector3, medidas: Vector3) -> void:
	var forma := BoxShape3D.new()
	forma.size = medidas
	var colisao := CollisionShape3D.new()
	colisao.shape = forma
	colisao.position = centro + Vector3.UP * medidas.y * 0.5
	corpo.add_child(colisao)

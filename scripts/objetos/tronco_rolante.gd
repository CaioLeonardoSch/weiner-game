@tool
class_name TroncoRolante
extends ObjetoFase
## Tronco deitado de duas células: esta e a seguinte no +X local (gire de 90 em 90 graus).
## Empurrado de lado, ROLA uma célula; ao comprido não sai do lugar. Precisa das duas células
## livres e com chão (ou água) na frente.
## Rolando para dentro d'água (as duas células):
## - água funda: afunda até ficar rente ao chão e vira ponte (fixa);
## - água rasa: boia (em cima do leito). Na correnteza, desce o rio uma célula por vez — dá
##   para ir em cima — até encalhar na margem ou bater em algo; se parar com uma parte sobre
##   água funda (ou chegar nela), encaixa ali e vira ponte.

const DURACAO := 0.45
const RAIO := 0.25
## Tempo (s) para descer uma célula na correnteza.
const TEMPO_DERIVA := 0.8

var em_movimento := false
## Afundou na água funda: é ponte, não sai mais do lugar.
var afundado := false
## Está na água rasa (desce a correnteza, se houver).
var boiando := false
var _corpo: AnimatableBody3D
var _colisao: CollisionShape3D
var _visual: Node3D
var _deriva := 0.0


func nome_no_editor() -> String:
	return "Tronco que rola"


func caixa_editor() -> AABB:
	return AABB(Vector3(-0.5, 0, -0.3), Vector3(2.0, 0.5, 0.6))


func _ready() -> void:
	_montar()
	if not Engine.is_editor_hint():
		add_to_group(&"pesos")


## Pesado: aciona até a placa de pedra (enquanto não afundou na água).
func pesado_para_placa() -> bool:
	return peso_na_placa() > 0.0


## Um tronco pesa numa placa quase como um bloco.
func peso_na_placa() -> float:
	return 0.0 if afundado else 2.5


## As duas células que o tronco ocupa (na camada do chão + 1).
func celulas() -> Array[Vector3i]:
	var terreno := _terreno()
	var inicio := terreno.local_to_map(terreno.to_local(global_position + Vector3.UP * 0.3))
	return [inicio, inicio + _eixo()]


func _eixo() -> Vector3i:
	var x := global_basis.x
	return Vector3i(roundi(x.x), 0, roundi(x.z))


## O cachorro empurrou (só de lado: ao comprido o tronco não rola).
func empurrar(direcao: Vector3i) -> bool:
	if em_movimento or afundado or direcao == _eixo() or direcao == -_eixo():
		return false
	return await _mover(direcao, true)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not boiando or em_movimento or afundado:
		return
	_deriva += delta
	if _deriva < TEMPO_DERIVA:
		return
	_deriva = 0.0
	var sentido := _sentido_da_correnteza()
	if sentido != Vector3i.ZERO and not _destino(sentido, false).is_empty():
		_mover(sentido, false)
	elif _sobre_agua_funda():
		# Não desce mais (margem, outro objeto) com uma parte na água funda: encaixa ali.
		em_movimento = true
		await _afundar()
		em_movimento = false


func _sobre_agua_funda() -> bool:
	var terreno := _terreno()
	for celula in celulas():
		if Tiles.eh_agua(terreno.get_cell_item(celula + Vector3i.DOWN)):
			return true
	return false


## Sentido da correnteza embaixo do tronco (Vector3i.ZERO se não houver).
func _sentido_da_correnteza() -> Vector3i:
	var terreno := _terreno()
	for celula in celulas():
		var chao := celula + Vector3i.DOWN
		if Tiles.definicao(terreno.get_cell_item(chao)).get("correnteza", 0.0) > 0.0:
			var sentido := terreno.global_basis * terreno.get_cell_item_basis(chao).x
			return Vector3i(roundi(sentido.x), 0, roundi(sentido.z))
	return Vector3i.ZERO


## Para onde o tronco iria: "chao", "rasa", "funda" ou "" (não dá: sem chão, ocupado, meio na
## água e meio fora).
func _destino(direcao: Vector3i, contar_cachorro: bool) -> String:
	var terreno := _terreno()
	var tipos := {}
	for celula in celulas():
		var destino := celula + direcao
		if terreno.get_cell_item(destino) != GridMap.INVALID_CELL_ITEM:
			return ""
		var chao := terreno.get_cell_item(destino + Vector3i.DOWN)
		if chao == GridMap.INVALID_CELL_ITEM:
			return ""
		if Tiles.eh_agua(chao):
			tipos["funda"] = true
		elif Tiles.definicao(chao).get("rasa", false):
			tipos["rasa"] = true
		else:
			tipos["chao"] = true
		var centro := terreno.to_global(terreno.map_to_local(destino))
		centro.y = global_position.y
		if _ocupado(centro, contar_cachorro):
			return ""
	if tipos.size() == 1:
		return tipos.keys()[0]
	# Uma célula na funda e outra na rasa: boia (e a correnteza leva até a funda).
	return "rasa" if not tipos.has("chao") else ""


func _mover(direcao: Vector3i, rolar: bool) -> bool:
	var destino := _destino(direcao, rolar)
	if destino.is_empty():
		return false
	em_movimento = true
	var alvo := global_position + Vector3(direcao)
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, "global_position", alvo, DURACAO if rolar else TEMPO_DERIVA * 0.8) \
		.set_trans(Tween.TRANS_SINE)
	if rolar:
		# Gira em volta do próprio eixo o quanto andou (1 m / raio).
		var giro := Vector3(direcao).cross(Vector3.UP).normalized() * (-1.0 / RAIO)
		var local := global_basis.inverse() * giro
		tween.parallel().tween_property(_visual, "rotation", _visual.rotation + local, DURACAO)
	await tween.finished
	boiando = destino != "chao"
	if destino == "funda":
		await _afundar()
	em_movimento = false
	return true


## Na água funda: afunda até o topo ficar rente ao chão e vira uma ponte larga.
func _afundar() -> void:
	afundado = true
	boiando = false
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, "global_position:y", global_position.y - RAIO * 2.0, 0.4) \
		.set_trans(Tween.TRANS_BACK)
	await tween.finished
	# Encaixado no leito: colisão larga e reta, da célula inteira.
	var forma := BoxShape3D.new()
	forma.size = Vector3(2.0, 0.3, 0.95)
	_colisao.shape = forma
	_colisao.rotation = Vector3.ZERO
	_colisao.position = Vector3(0.5, RAIO * 2.0 - 0.15, 0)


## Algum objeto (ou o cachorro) no lugar?
func _ocupado(alvo: Vector3, contar_cachorro: bool) -> bool:
	var forma := BoxShape3D.new()
	forma.size = Vector3(0.8, 0.6, 0.8)
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma
	consulta.transform = Transform3D(Basis.IDENTITY, alvo + Vector3.UP * 0.4)
	consulta.collision_mask = 2 | 4 | (8 if contar_cachorro else 0)
	consulta.exclude = [_corpo.get_rid()]
	return not get_world_3d().direct_space_state.intersect_shape(consulta, 1).is_empty()


func _terreno() -> GridMap:
	return fase_do_objeto().terreno


## Casca marrom com anéis nas pontas; corpo que carrega quem está em cima (AnimatableBody).
func _montar() -> void:
	for filho in get_children():
		remove_child(filho)
		filho.queue_free()
	_visual = Node3D.new()
	_visual.name = "Visual"
	_visual.position = Vector3(0.5, RAIO, 0)
	add_child(_visual)
	var voxels := {}
	var casca := [Color("6b4428"), Color("5b3920"), Color("7a4f2e")]
	for x in range(-16, 16):
		for y in range(-4, 4):
			for z in range(-4, 4):
				var r := Vector2(y + 0.5, z + 0.5).length()
				if r > 4.0:
					continue
				var ponta := x == -16 or x == 15
				if ponta:
					voxels[Vector3i(x, y, z)] = Color("c9a36a") if int(r) % 2 == 0 else Color("a8844f")
				else:
					voxels[Vector3i(x, y, z)] = casca[posmod(x * 7 + y * 3 + z, 3)]
	var malha := MeshInstance3D.new()
	malha.mesh = Voxel.malha(voxels, 1.0 / 16.0)
	_visual.add_child(malha)

	_corpo = AnimatableBody3D.new()
	_corpo.name = "Corpo"
	_corpo.collision_layer = 4
	_corpo.collision_mask = 0
	# Movido junto com o nó (tween no passo da física): sem sync_to_physics, que ignoraria o pai.
	_corpo.sync_to_physics = false
	add_child(_corpo)
	var forma := CylinderShape3D.new()
	forma.radius = RAIO
	forma.height = 2.0
	_colisao = CollisionShape3D.new()
	_colisao.shape = forma
	_colisao.rotation = Vector3(0, 0, PI * 0.5)
	_colisao.position = Vector3(0.5, RAIO, 0)
	_corpo.add_child(_colisao)

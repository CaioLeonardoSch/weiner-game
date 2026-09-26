@tool
class_name Empurravel
extends ObjetoFase
## Bloco de pedra que o cachorro empurra andando contra ele: anda uma célula da grade por
## vez (estilo Sokoban, previsível), se a célula de destino estiver livre e tiver chão.
## Empurrado para dentro da água, afunda até ficar rente ao chão e vira passagem.
## Coloque no centro de uma célula (o editor já encaixa).

signal afundou
## Ficou encurralado (nenhum empurrão possível) e voltou para onde começou.
signal voltou_ao_inicio

const DURACAO := 0.35

@export_range(0, 7) var variante := 0:
	set(valor):
		variante = valor
		_atualizar()

var em_movimento := false
var afundado := false
var _inicio := Transform3D()


func nome_no_editor() -> String:
	return "Bloco empurrável"


func propriedades_editaveis() -> Array[StringName]:
	return [&"variante"]


func ao_colocar_no_editor(rng: RandomNumberGenerator) -> void:
	variante = rng.randi_range(0, 7)


func _ready() -> void:
	_atualizar()
	_inicio = transform


func _atualizar() -> void:
	if is_node_ready():
		($Visual as MeshInstance3D).mesh = Voxel.bloco(variante)


## Tenta empurrar uma célula na direção dada (só X ou Z). Verdadeiro se andou.
func empurrar(direcao: Vector3i) -> bool:
	var fase := _fase()
	if em_movimento or afundado or fase == null:
		return false
	var terreno := fase.terreno
	var celula := terreno.local_to_map(terreno.to_local(global_position + Vector3.UP * 0.3))
	var destino := celula + Vector3i(direcao.x, 0, direcao.z)
	if terreno.get_cell_item(destino) != GridMap.INVALID_CELL_ITEM:
		return false
	var chao := terreno.get_cell_item(destino + Vector3i.DOWN)
	if chao == GridMap.INVALID_CELL_ITEM:
		return false
	var alvo := terreno.to_global(terreno.map_to_local(destino))
	alvo.y = global_position.y
	if _ocupado(alvo, true):
		return false

	em_movimento = true
	var tween := create_tween()
	tween.tween_property(self, "global_position", alvo, DURACAO).set_trans(Tween.TRANS_SINE)
	if Tiles.eh_agua(chao):
		# Afunda até o topo ficar rente ao chão em volta.
		afundado = true
		tween.tween_property(self, "global_position:y", alvo.y - 0.9, 0.4).set_trans(Tween.TRANS_BACK)
		tween.tween_callback(afundou.emit)
	await tween.finished
	em_movimento = false
	if not afundado and not _algum_empurrao_possivel():
		_voltar_ao_inicio()
	return true


## Existe alguma direção em que o cachorro consegue empurrar o bloco? (Destino livre e com
## chão, e do lado oposto um lugar em que o cachorro possa ficar.)
func _algum_empurrao_possivel() -> bool:
	var terreno := _fase().terreno
	var celula := terreno.local_to_map(terreno.to_local(global_position + Vector3.UP * 0.3))
	for direcao: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
		if _celula_livre(celula + direcao, false) and _celula_livre(celula - direcao, true):
			return true
	return false


## Célula vazia, com chão embaixo e sem objeto sólido. `para_o_cachorro`: o chão não pode
## ser água (o cachorro ficaria ali para empurrar).
func _celula_livre(celula: Vector3i, para_o_cachorro: bool) -> bool:
	var terreno := _fase().terreno
	if terreno.get_cell_item(celula) != GridMap.INVALID_CELL_ITEM:
		return false
	var chao := terreno.get_cell_item(celula + Vector3i.DOWN)
	if chao == GridMap.INVALID_CELL_ITEM or (para_o_cachorro and Tiles.eh_agua(chao)):
		return false
	var centro := terreno.to_global(terreno.map_to_local(celula))
	centro.y = global_position.y
	return not _ocupado(centro, not para_o_cachorro)


## Encurralado num canto: some e reaparece onde começou (dá para tentar de novo sem
## reiniciar a fase). Espera o lugar de início ficar livre.
func _voltar_ao_inicio() -> void:
	em_movimento = true
	await get_tree().create_timer(0.6).timeout
	var inicio_global := (get_parent() as Node3D).global_transform * _inicio
	while _ocupado(inicio_global.origin, true):
		await get_tree().create_timer(0.5).timeout
	Efeitos.terra(get_parent(), global_position + Vector3.UP * 0.4)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.0, 0.05, 1.0), 0.2)
	tween.tween_callback(func() -> void: transform = _inicio * Transform3D.IDENTITY.scaled(Vector3(1.0, 0.05, 1.0)))
	tween.tween_property(self, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	await tween.finished
	Efeitos.terra(get_parent(), global_position + Vector3.UP * 0.4)
	em_movimento = false
	voltou_ao_inicio.emit()


## Algum objeto no lugar? Sólidos sempre (pela física). Para o destino do bloco
## (`destino_do_bloco`), conta também o cachorro e o graveto e os passarinhos, que não têm
## corpo sólido mas não podem ficar embaixo da pedra.
func _ocupado(alvo: Vector3, destino_do_bloco: bool) -> bool:
	var forma := BoxShape3D.new()
	forma.size = Vector3(0.8, 0.7, 0.8)
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma
	consulta.transform = Transform3D(Basis.IDENTITY, alvo + Vector3.UP * 0.45)
	consulta.collision_mask = 2 | 4 | (8 if destino_do_bloco else 0)
	consulta.exclude = [($Corpo as CollisionObject3D).get_rid()]
	if not get_world_3d().direct_space_state.intersect_shape(consulta, 1).is_empty():
		return true
	if not destino_do_bloco:
		return false
	for objeto in _fase().lista_objetos():
		if (objeto is Graveto or (objeto is Passaro and not (objeto as Passaro).voou)) and objeto.visible:
			var dx := absf(objeto.global_position.x - alvo.x)
			var dz := absf(objeto.global_position.z - alvo.z)
			if dx < 0.75 and dz < 0.75:
				return true
	return false


func _fase() -> Fase:
	var no := get_parent()
	while no and not no is Fase:
		no = no.get_parent()
	return no as Fase

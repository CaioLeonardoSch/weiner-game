@tool
class_name Empurravel
extends ObjetoFase
## Bloco de pedra que o cachorro empurra andando contra ele: anda uma célula da grade por
## vez (estilo Sokoban, previsível), se a célula de destino estiver livre e tiver chão.
## Segurando `puxar` de frente para ele e andando para trás, o cachorro puxa (sem graveto).
## Empurrado para dentro da água, afunda até ficar rente ao chão e vira passagem; num buraco,
## cai e tapa o buraco.
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
	if not Engine.is_editor_hint():
		add_to_group(&"pesos")


## Um bloco de pedra segura qualquer placa de pressão (pesa 3).
func peso_na_placa() -> float:
	return 0.0 if afundado else 3.0


func _atualizar() -> void:
	if is_node_ready():
		($Visual as MeshInstance3D).mesh = Voxel.bloco(variante)


## Tenta empurrar uma célula na direção dada (só X ou Z). Verdadeiro se andou.
func empurrar(direcao: Vector3i) -> bool:
	return await _mover(direcao, false)


## Puxado pelo cachorro: anda uma célula na direção dele (o cachorro recua junto, então o
## lugar dele não conta como ocupado).
func puxar(direcao: Vector3i) -> bool:
	return await _mover(direcao, true)


## Pode andar uma célula nessa direção agora?
func pode_mover(direcao: Vector3i, ignorar_cachorro: bool) -> bool:
	var fase := _fase()
	if em_movimento or afundado or fase == null:
		return false
	var terreno := fase.terreno
	var destino := _celula() + Vector3i(direcao.x, 0, direcao.z)
	if terreno.get_cell_item(destino) != GridMap.INVALID_CELL_ITEM:
		return false
	if terreno.get_cell_item(destino + Vector3i.DOWN) == GridMap.INVALID_CELL_ITEM:
		return false
	var alvo := terreno.to_global(terreno.map_to_local(destino))
	alvo.y = global_position.y
	return not _ocupado(alvo, true, ignorar_cachorro)


func _celula() -> Vector3i:
	var terreno := _fase().terreno
	return terreno.local_to_map(terreno.to_local(global_position + Vector3.UP * 0.3))


func _mover(direcao: Vector3i, ignorar_cachorro: bool) -> bool:
	if not pode_mover(direcao, ignorar_cachorro):
		return false
	var terreno := _fase().terreno
	var destino := _celula() + Vector3i(direcao.x, 0, direcao.z)
	var chao := terreno.get_cell_item(destino + Vector3i.DOWN)
	var alvo := terreno.to_global(terreno.map_to_local(destino))
	alvo.y = global_position.y

	em_movimento = true
	var tween := create_tween()
	tween.tween_property(self, "global_position", alvo, DURACAO).set_trans(Tween.TRANS_SINE)
	if Tiles.eh_agua(chao):
		# Afunda até o topo ficar rente ao chão em volta.
		afundado = true
		tween.tween_property(self, "global_position:y", alvo.y - 0.9, 0.4).set_trans(Tween.TRANS_BACK)
		tween.tween_callback(afundou.emit)
	elif Tiles.eh_buraco(chao):
		# Cai no buraco e tapa: o topo fica rente ao chão, e vira chão.
		afundado = true
		tween.tween_property(self, "global_position:y", alvo.y - 1.0, 0.25).set_trans(Tween.TRANS_QUAD)
		tween.tween_callback(afundou.emit)
	await tween.finished
	em_movimento = false
	if not afundado and not _algum_empurrao_possivel():
		_voltar_ao_inicio()
	return true


## Existe alguma direção em que o cachorro consegue empurrar ou puxar o bloco? (Destino
## livre e com chão, e lugar para o cachorro ficar — e, ao puxar, para recuar.)
func _algum_empurrao_possivel() -> bool:
	var celula := _celula()
	for direcao: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
		if _celula_livre(celula + direcao, false) and _celula_livre(celula - direcao, true):
			return true
		# Puxar: o cachorro fica em celula + direcao e recua para celula + 2 * direcao.
		if _celula_livre(celula + direcao, true) and _celula_livre(celula + direcao * 2, true):
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


## Encurralado (nem empurrar nem puxar): some e reaparece onde começou (dá para tentar de novo sem
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
func _ocupado(alvo: Vector3, destino_do_bloco: bool, ignorar_cachorro := false) -> bool:
	var forma := BoxShape3D.new()
	forma.size = Vector3(0.8, 0.7, 0.8)
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma
	consulta.transform = Transform3D(Basis.IDENTITY, alvo + Vector3.UP * 0.45)
	consulta.collision_mask = 2 | 4 | (8 if destino_do_bloco and not ignorar_cachorro else 0)
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

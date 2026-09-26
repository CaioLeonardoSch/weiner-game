@tool
class_name Empurravel
extends ObjetoFase
## Bloco de pedra que o cachorro empurra andando contra ele: anda uma célula da grade por
## vez (estilo Sokoban, previsível), se a célula de destino estiver livre e tiver chão.
## Empurrado para dentro da água, afunda até ficar rente ao chão e vira passagem.
## Coloque no centro de uma célula (o editor já encaixa).

signal afundou

const DURACAO := 0.35

@export_range(0, 7) var variante := 0:
	set(valor):
		variante = valor
		_atualizar()

var em_movimento := false
var afundado := false


func nome_no_editor() -> String:
	return "Bloco empurrável"


func propriedades_editaveis() -> Array[StringName]:
	return [&"variante"]


func ao_colocar_no_editor(rng: RandomNumberGenerator) -> void:
	variante = rng.randi_range(0, 7)


func _ready() -> void:
	_atualizar()


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
	if _ocupado(alvo):
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
	return true


## Algum outro objeto sólido (ou o cachorro) no lugar de destino?
func _ocupado(alvo: Vector3) -> bool:
	var forma := BoxShape3D.new()
	forma.size = Vector3(0.8, 0.7, 0.8)
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma
	consulta.transform = Transform3D(Basis.IDENTITY, alvo + Vector3.UP * 0.45)
	consulta.collision_mask = 2 | 4 | 8
	consulta.exclude = [($Corpo as CollisionObject3D).get_rid()]
	return not get_world_3d().direct_space_state.intersect_shape(consulta, 1).is_empty()


func _fase() -> Fase:
	var no := get_parent()
	while no and not no is Fase:
		no = no.get_parent()
	return no as Fase

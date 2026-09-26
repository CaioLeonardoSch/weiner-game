@tool
class_name ZonaSemLargar
extends ObjetoFase
## Região onde o cachorro não pode largar o graveto. Use onde largar deixaria o cachorro
## preso — por exemplo dentro de um túnel cujas bocas fecham na visão isométrica.

@export var tamanho := Vector3(3.0, 1.2, 1.0):
	set(valor):
		tamanho = valor
		_atualizar()


func nome_no_editor() -> String:
	return "Zona sem largar"


func categoria_no_editor() -> String:
	return "Regras"


func propriedades_editaveis() -> Array[StringName]:
	return [&"tamanho"]


func prioridade_no_editor() -> int:
	return 0


func caixa_editor() -> AABB:
	return AABB(Vector3(-tamanho.x * 0.5, 0.0, -tamanho.z * 0.5), tamanho)


func contem(corpo: Node3D) -> bool:
	return ($Area as Area3D).overlaps_body(corpo)


func _ready() -> void:
	_atualizar()


func _atualizar() -> void:
	if not is_node_ready():
		return
	var forma := BoxShape3D.new()
	forma.size = tamanho
	var colisao := $Area/Colisao as CollisionShape3D
	colisao.shape = forma
	colisao.position.y = tamanho.y * 0.5

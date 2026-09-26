@tool
class_name Ponte
extends ObjetoFase
## Ponte de madeira larga, com o tamanho que quiser. O topo fica na altura da origem
## (coloque no chão ao lado do riacho e ela fica rente ao chão).
## Com visibilidade "Só isométrico" vira uma ponte que só existe na ida.

@export var tamanho := Vector3(2.4, 0.12, 2.0):
	set(valor):
		tamanho = valor
		_atualizar()


func nome_no_editor() -> String:
	return "Ponte de madeira"


func propriedades_editaveis() -> Array[StringName]:
	return [&"tamanho"]


func _ready() -> void:
	_atualizar()


func _atualizar() -> void:
	if not is_node_ready():
		return
	var visual := $Visual as MeshInstance3D
	(visual.mesh as BoxMesh).size = tamanho
	visual.position.y = -tamanho.y * 0.5
	var forma := BoxShape3D.new()
	forma.size = tamanho
	var colisao := $Corpo/Colisao as CollisionShape3D
	colisao.shape = forma
	colisao.position.y = -tamanho.y * 0.5

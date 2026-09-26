@tool
class_name Flores
extends ObjetoFase
## Tufo de capim e flores (decoração rasteira, sem colisão). Bom para enfeitar a frente
## do cenário na visão isométrica sem tapar o caminho.

@export_range(0, 7) var variante := 0:
	set(valor):
		variante = valor
		_atualizar()


func nome_no_editor() -> String:
	return "Flores"


func propriedades_editaveis() -> Array[StringName]:
	return [&"variante"]


func ao_colocar_no_editor(rng: RandomNumberGenerator) -> void:
	variante = rng.randi_range(0, 7)
	rotation.y = rng.randf_range(-PI, PI)


func _ready() -> void:
	_atualizar()


func _atualizar() -> void:
	if is_node_ready():
		($Visual as MeshInstance3D).mesh = Voxel.flores(variante)

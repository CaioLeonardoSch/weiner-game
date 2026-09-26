@tool
class_name Pedra
extends ObjetoFase
## Pedra voxel gerada por código. Obstáculo fixo.
## TODO (etapas futuras): pedras empurráveis — ver ROADMAP.md.

@export_range(0, 7) var variante := 0:
	set(valor):
		variante = valor
		_atualizar()


func nome_no_editor() -> String:
	return "Pedra"


func propriedades_editaveis() -> Array[StringName]:
	return [&"variante"]


func ao_colocar_no_editor(rng: RandomNumberGenerator) -> void:
	variante = rng.randi_range(0, 7)
	rotation.y = rng.randf_range(-PI, PI)


func _ready() -> void:
	_atualizar()


func _atualizar() -> void:
	if not is_node_ready():
		return
	var malha := Voxel.pedra(variante)
	($Visual as MeshInstance3D).mesh = malha
	if not Engine.is_editor_hint():
		var caixa := malha.get_aabb()
		var forma := BoxShape3D.new()
		forma.size = caixa.size
		var colisao := $Corpo/Colisao as CollisionShape3D
		colisao.shape = forma
		colisao.position = caixa.get_center()

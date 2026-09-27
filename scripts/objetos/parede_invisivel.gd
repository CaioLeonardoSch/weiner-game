@tool
class_name ParedeInvisivel
extends ObjetoFase
## Bloqueio invisível (camada de colisão "bordas": a câmera 3D passa por ela).
## Para limitar o caminho sem nada visível — prefira mato/cerca quando der, o jogador
## entende melhor por onde pode andar.

@export var tamanho := Vector3(1.0, 2.0, 1.0):
	set(valor):
		tamanho = valor
		_atualizar()


func nome_no_editor() -> String:
	return "Parede invisível"


func categoria_no_editor() -> String:
	return "Regras"


func propriedades_editaveis() -> Array[StringName]:
	return [&"tamanho"]


func icone_desenhado() -> String:
	return "parede"


func prioridade_no_editor() -> int:
	return 0


func caixa_editor() -> AABB:
	return AABB(Vector3(-tamanho.x * 0.5, 0.0, -tamanho.z * 0.5), tamanho)


func _ready() -> void:
	_atualizar()


func _atualizar() -> void:
	if not is_node_ready():
		return
	var forma := BoxShape3D.new()
	forma.size = tamanho
	var colisao := $Corpo/Colisao as CollisionShape3D
	colisao.shape = forma
	colisao.position.y = tamanho.y * 0.5
	mostrar_volume_no_editor(tamanho, Color(0.55, 0.85, 1.0, 0.18))

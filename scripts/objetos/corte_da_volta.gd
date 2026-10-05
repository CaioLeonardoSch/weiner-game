@tool
class_name CorteDaVolta
extends ObjetoFase
## Num dia do parque, o pedaço da volta que um *fade* corta (ver docs/DESIGN.md): o cachorro
## entrando aqui com o graveto lendário na boca termina a fase, e o jogo segue direto para a
## chegada ao dono, no parque (ObjetivoDia).

signal cachorro_entrou(cachorro: Dachshund)

@export var tamanho := Vector3(4.0, 2.0, 1.0):
	set(valor):
		tamanho = valor
		_atualizar()


func nome_no_editor() -> String:
	return "Corte da volta"


func categoria_no_editor() -> String:
	return "Regras"


func propriedades_editaveis() -> Array[StringName]:
	return [&"tamanho"]


func icone_desenhado() -> String:
	return "corte"


func prioridade_no_editor() -> int:
	return 0


func caixa_editor() -> AABB:
	return AABB(Vector3(-tamanho.x * 0.5, 0.0, -tamanho.z * 0.5), tamanho)


func _ready() -> void:
	_atualizar()
	if not Engine.is_editor_hint():
		($Area as Area3D).body_entered.connect(func(corpo: Node3D) -> void:
			if corpo is Dachshund:
				cachorro_entrou.emit(corpo))


func contem(corpo: Node3D) -> bool:
	return ($Area as Area3D).overlaps_body(corpo)


func _atualizar() -> void:
	if not is_node_ready():
		return
	var forma := BoxShape3D.new()
	forma.size = tamanho
	var colisao := $Area/Colisao as CollisionShape3D
	colisao.shape = forma
	colisao.position.y = tamanho.y * 0.5
	mostrar_volume_no_editor(tamanho, Color(0.1, 0.1, 0.12, 0.25))

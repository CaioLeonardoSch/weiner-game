@tool
class_name Dono
extends ObjetoFase
## O dono. Chegar perto dele com o graveto na boca conclui a fase.

signal cachorro_chegou(corpo: Node3D)

@onready var area_entrega: Area3D = $AreaEntrega


func nome_no_editor() -> String:
	return "Dono"


func categoria_no_editor() -> String:
	return "Regras"


func _ready() -> void:
	if not Engine.is_editor_hint():
		area_entrega.body_entered.connect(cachorro_chegou.emit)


func contem(corpo: Node3D) -> bool:
	return area_entrega.overlaps_body(corpo)

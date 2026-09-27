@tool
class_name Dono
extends ObjetoFase
## O dono. Chegar perto dele com o graveto na boca conclui a fase.
## `dormindo`: cochilando ("Zzz"), não recebe o graveto até um latido acordar ele — e com o
## graveto na boca o cachorro não late (larga, late, pega de novo; ou um cão vizinho late).

signal cachorro_chegou(corpo: Node3D)
signal acordou

@export var dormindo := false:
	set(valor):
		dormindo = valor
		_atualizar_sono()

var _zzz: Label3D
var _tempo := 0.0

@onready var area_entrega: Area3D = $AreaEntrega


func nome_no_editor() -> String:
	return "Dono"


func categoria_no_editor() -> String:
	return "Regras"


func propriedades_editaveis() -> Array[StringName]:
	return [&"dormindo"]


func _ready() -> void:
	_atualizar_sono()
	if not Engine.is_editor_hint():
		area_entrega.body_entered.connect(cachorro_chegou.emit)


func contem(corpo: Node3D) -> bool:
	return area_entrega.overlaps_body(corpo)


func ao_ouvir_latido(_origem: Vector3) -> void:
	if not dormindo:
		return
	dormindo = false
	var susto := Label3D.new()
	susto.text = "!"
	susto.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	susto.font_size = 72
	susto.outline_size = 16
	susto.pixel_size = 0.008
	susto.modulate = Color(1.0, 0.92, 0.5)
	susto.no_depth_test = true
	susto.position = Vector3(0, 2.1, 0)
	add_child(susto)
	var tween := susto.create_tween()
	tween.tween_property(susto, "position:y", 2.5, 0.25).set_trans(Tween.TRANS_BACK)
	tween.tween_interval(0.6)
	tween.tween_property(susto, "modulate:a", 0.0, 0.3)
	tween.tween_callback(susto.queue_free)
	acordou.emit()


func _process(delta: float) -> void:
	if _zzz == null:
		return
	# "Zzz" subindo e voltando, devagar.
	_tempo += delta
	var ciclo := fmod(_tempo, 2.0) / 2.0
	_zzz.position = Vector3(0.25 + ciclo * 0.2, 2.0 + ciclo * 0.45, 0)
	_zzz.modulate.a = 1.0 - ciclo * 0.8


func _atualizar_sono() -> void:
	if not is_node_ready():
		return
	if dormindo and _zzz == null:
		_zzz = Label3D.new()
		_zzz.name = "Zzz"
		_zzz.text = "Zzz"
		_zzz.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_zzz.font_size = 48
		_zzz.outline_size = 12
		_zzz.pixel_size = 0.008
		_zzz.modulate = Color(0.85, 0.9, 1.0)
		_zzz.position = Vector3(0.25, 2.0, 0)
		add_child(_zzz)
	elif not dormindo and _zzz:
		_zzz.queue_free()
		_zzz = null
	# Cochilando, o dono fica um pouco curvado.
	($Modelo as Node3D).rotation.x = 0.12 if dormindo else 0.0

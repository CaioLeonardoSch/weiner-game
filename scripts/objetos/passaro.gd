@tool
class_name Passaro
extends ObjetoFase
## Passarinho. Pousado perto do graveto (até 1 m), não deixa o cachorro pegar; com
## `bloqueia_passagem`, fica no caminho e não deixa passar. Um latido por perto e ele voa
## embora para sempre (até reiniciar a fase).

const DISTANCIA_GUARDA := 1.0

@export var bloqueia_passagem := false:
	set(valor):
		bloqueia_passagem = valor
		_atualizar()

var voou := false
var _tempo := 0.0

@onready var modelo: Node3D = $Modelo


func nome_no_editor() -> String:
	return "Passarinho"


func categoria_no_editor() -> String:
	return "Bichos"


func propriedades_editaveis() -> Array[StringName]:
	return [&"bloqueia_passagem"]


func ao_colocar_no_editor(rng: RandomNumberGenerator) -> void:
	rotation.y = rng.randf_range(-PI, PI)


func _ready() -> void:
	_atualizar()
	if not Engine.is_editor_hint():
		add_to_group(&"passaros")
		_tempo = randf() * 2.0


func _atualizar() -> void:
	if is_node_ready():
		($Corpo/Colisao as CollisionShape3D).disabled = not bloqueia_passagem


## Está guardando `ponto` (ainda não voou e está perto)?
func guarda(ponto: Vector3) -> bool:
	return not voou and global_position.distance_to(ponto) <= DISTANCIA_GUARDA


func _process(delta: float) -> void:
	if voou or Engine.is_editor_hint():
		return
	# Pulinhos de vez em quando.
	_tempo += delta
	var ciclo := fmod(_tempo, 1.7)
	modelo.position.y = maxf(sin(ciclo * PI / 0.3), 0.0) * 0.06 if ciclo < 0.3 else 0.0


func ao_ouvir_latido(origem: Vector3) -> void:
	if voou:
		return
	voou = true
	remove_from_group(&"passaros")
	($Corpo/Colisao as CollisionShape3D).set_deferred("disabled", true)
	var fuga := global_position - origem
	fuga.y = 0.0
	fuga = fuga.normalized() if fuga.length() > 0.01 else Vector3.RIGHT
	rotation.y = atan2(-fuga.z, fuga.x)
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "global_position", global_position + fuga * 7.0 + Vector3.UP * 5.0, 1.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Bater de asas: o corpo "pisca" de altura.
	var asas := create_tween().set_loops(7)
	asas.tween_property(modelo, "scale:y", 0.6, 0.1)
	asas.tween_property(modelo, "scale:y", 1.0, 0.1)
	tween.chain().tween_callback(hide)

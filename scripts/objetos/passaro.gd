@tool
class_name Passaro
extends ObjetoFase
## Passarinho. Pousado perto do graveto (até 1 m), não deixa o cachorro pegar; com
## `bloqueia_passagem`, fica no caminho e não deixa passar. Um latido por perto e ele voa
## embora — para sempre (até reiniciar a fase) ou, com `volta_depois`, volta para o mesmo
## lugar depois de uns segundos (pousado numa placa, é um contrapeso que vai e volta).

const DISTANCIA_GUARDA := 1.0

@export var bloqueia_passagem := false:
	set(valor):
		bloqueia_passagem = valor
		_atualizar()
## Segundos até voltar para o mesmo lugar depois de voar (0 = não volta).
@export_range(0.0, 60.0, 0.5) var volta_depois := 0.0

var voou := false
var _tempo := 0.0

@onready var modelo: Node3D = $Modelo


func nome_no_editor() -> String:
	return "Passarinho"


func categoria_no_editor() -> String:
	return "Bichos"


func propriedades_editaveis() -> Array[StringName]:
	return [&"bloqueia_passagem", &"volta_depois"]


func ao_colocar_no_editor(rng: RandomNumberGenerator) -> void:
	rotation.y = rng.randf_range(-PI, PI)


func _ready() -> void:
	_atualizar()
	if not Engine.is_editor_hint():
		add_to_group(&"passaros")
		add_to_group(&"pesos")
		_tempo = randf() * 2.0


func _atualizar() -> void:
	if is_node_ready():
		($Corpo/Colisao as CollisionShape3D).disabled = not bloqueia_passagem


## Um passarinho pousado pesa pouco — um bando, um pouco mais.
func peso_na_placa() -> float:
	return 0.0 if voou else 0.3


## Está guardando `ponto` (ainda não voou e está perto)?
func guarda(ponto: Vector3) -> bool:
	return not voou and visible and global_position.distance_to(ponto) <= DISTANCIA_GUARDA


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
	var poleiro := global_transform
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
	if volta_depois > 0.0:
		var de_onde := global_position + fuga * 7.0 + Vector3.UP * 5.0
		tween.chain().tween_interval(volta_depois)
		tween.chain().tween_callback(_voltar.bind(poleiro, de_onde))


## Volta voando de `de_onde` e pousa no `poleiro` de antes, guardando/pesando de novo.
func _voltar(poleiro: Transform3D, de_onde: Vector3) -> void:
	global_position = de_onde
	var chegada := poleiro.origin - de_onde
	rotation.y = atan2(-chegada.z, chegada.x)
	show()
	var asas := create_tween().set_loops(7)
	asas.tween_property(modelo, "scale:y", 0.6, 0.1)
	asas.tween_property(modelo, "scale:y", 1.0, 0.1)
	var tween := create_tween()
	tween.tween_property(self, "global_position", poleiro.origin, 1.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	global_transform = poleiro
	modelo.scale = Vector3.ONE
	voou = false
	add_to_group(&"passaros")
	_atualizar()

class_name Graveto
extends Area3D
## Graveto no chão. Quando o cachorro encosta, emite `pego`.
##
## TODO: nesta demo o graveto é só visual na boca do cachorro. No futuro ele terá
## colisão própria (ver CONCEITO.md) e os túneis/passagens precisarão ser largos o
## bastante para ele — isso vira o puzzle de espaço/ângulo.

signal pego(cachorro: Dachshund)

## Amplitude (m) e velocidade da flutuação enquanto está no chão, só para chamar atenção.
@export var amplitude_flutuacao := 0.05
@export var velocidade_flutuacao := 3.0
## Depois de largado, por quantos segundos o graveto ignora o cachorro
## (senão ele seria pego de novo na hora).
@export var tempo_para_repegar := 0.5

var ja_pego := false
var _tempo := 0.0
var _bloqueio := 0.0

@onready var visual: Node3D = $Visual


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if ja_pego:
		return
	_bloqueio = maxf(_bloqueio - delta, 0.0)
	_tempo += delta
	visual.position.y = sin(_tempo * velocidade_flutuacao) * amplitude_flutuacao
	visual.rotation.y += delta


## Volta a ficar disponível no chão (quem posiciona é a fase).
func soltar() -> void:
	ja_pego = false
	_bloqueio = tempo_para_repegar
	set_deferred("monitoring", true)


func _on_body_entered(body: Node3D) -> void:
	if ja_pego or _bloqueio > 0.0 or not body is Dachshund:
		return
	ja_pego = true
	# Não dá para mudar o monitoring dentro do próprio callback de física.
	set_deferred("monitoring", false)
	visual.position = Vector3.ZERO
	visual.rotation = Vector3.ZERO
	pego.emit(body)

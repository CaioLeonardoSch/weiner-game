class_name Dachshund
extends CharacterBody3D
## O cachorro salsicha.
##
## Movimento livre no plano XZ, relativo à câmera (8 direções no modo isométrico,
## analógico/WASD na terceira pessoa). O Y fica por conta da gravidade + move_and_slide.

@export var velocidade := 3.5
## Velocidade com que o modelo gira para a direção do movimento.
@export var velocidade_giro := 10.0

## Câmera usada como referência de direção (definida pela fase).
var camera_referencia: Camera3D
var tem_graveto := false
## Quando true, ignora a entrada do jogador (transição de câmera, fim de fase).
var entrada_bloqueada := false

var _gravidade: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _yaw_alvo := 0.0
var _ultimo_ponto_seguro := Vector3.ZERO

@onready var modelo: Node3D = $Modelo
@onready var boca: Marker3D = $Modelo/Boca


func _ready() -> void:
	_ultimo_ponto_seguro = global_position


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravidade * delta

	var horizontal := Vector3.ZERO if entrada_bloqueada else _velocidade_entrada()
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	move_and_slide()
	_girar_modelo(delta)
	_checar_queda()


func pegar_graveto(graveto: Graveto) -> void:
	tem_graveto = true
	# Graveto atravessado na boca: a cena do graveto já deixa ele deitado no eixo Z,
	# que é "de lado" em relação ao focinho (o modelo olha para +X).
	graveto.reparent(boca, false)
	graveto.transform = Transform3D.IDENTITY


## Só marca que soltou; quem reposiciona o graveto no chão é a fase.
func largar_graveto() -> void:
	tem_graveto = false


func _velocidade_entrada() -> Vector3:
	var entrada := Input.get_vector("mover_esquerda", "mover_direita", "mover_frente", "mover_tras")
	if entrada == Vector2.ZERO or camera_referencia == null:
		return Vector3.ZERO

	# "Frente" = para cima na tela, projetado no chão.
	var frente := -camera_referencia.global_basis.z
	frente.y = 0.0
	frente = frente.normalized()
	var direita := camera_referencia.global_basis.x
	direita.y = 0.0
	direita = direita.normalized()

	var direcao := direita * entrada.x - frente * entrada.y
	_yaw_alvo = atan2(-direcao.z, direcao.x)
	return direcao * velocidade


func _girar_modelo(delta: float) -> void:
	# O modelo olha para +X quando rotation.y == 0.
	modelo.rotation.y = lerp_angle(modelo.rotation.y, _yaw_alvo, 1.0 - exp(-velocidade_giro * delta))


func _checar_queda() -> void:
	if is_on_floor():
		_ultimo_ponto_seguro = global_position
	elif global_position.y < -10.0:
		global_position = _ultimo_ponto_seguro + Vector3.UP * 0.2
		velocity = Vector3.ZERO

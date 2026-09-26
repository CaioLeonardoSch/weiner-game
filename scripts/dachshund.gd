class_name Dachshund
extends CharacterBody3D
## O cachorro salsicha.
##
## Movimento livre no plano XZ, relativo à câmera (8 direções no modo isométrico,
## analógico/WASD na terceira pessoa). O Y fica por conta da gravidade + move_and_slide.

## Caiu num lugar sem volta (água, abismo) e foi levado de volta para terra firme.
signal voltou_ao_ponto_seguro(motivo: String)

@export var velocidade := 3.5
## Velocidade com que o modelo gira para a direção do movimento.
@export var velocidade_giro := 10.0

## Câmera usada como referência de direção (definida pelo jogo).
var camera_referencia: Camera3D
## Fase atual (para saber onde tem água etc.).
var fase: Fase
var tem_graveto := false
var graveto: Graveto
## Quando true, ignora a entrada do jogador (transição de câmera, fim de fase).
var entrada_bloqueada := false

var _gravidade: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _yaw_alvo := 0.0
## Últimas posições em chão firme (a mais antiga é usada ao voltar, para não
## reaparecer bem na beirada de onde caiu).
var _pontos_seguros: Array[Vector3] = []
var _tempo_ponto_seguro := 0.0

@onready var modelo: Node3D = $Modelo
@onready var boca: Marker3D = $Modelo/Boca


func _ready() -> void:
	_guardar_ponto_seguro()


## Coloca o cachorro numa posição, olhando para `yaw` (radianos; 0 = +X).
func posicionar(posicao: Vector3, yaw: float) -> void:
	global_position = posicao
	velocity = Vector3.ZERO
	_yaw_alvo = yaw
	modelo.rotation.y = yaw
	_pontos_seguros.clear()
	_guardar_ponto_seguro()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravidade * delta

	var horizontal := Vector3.ZERO if entrada_bloqueada else _velocidade_entrada()
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	move_and_slide()
	_girar_modelo(delta)
	_checar_queda(delta)


func pegar_graveto(novo_graveto: Graveto) -> void:
	tem_graveto = true
	graveto = novo_graveto
	# Graveto atravessado na boca: a cena do graveto já deixa ele deitado no eixo Z,
	# que é "de lado" em relação ao focinho (o modelo olha para +X).
	graveto.reparent(boca, false)
	graveto.transform = Transform3D.IDENTITY


## Só marca que soltou; quem reposiciona o graveto no chão é o jogo.
func largar_graveto() -> void:
	tem_graveto = false
	graveto = null


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
	var fator := graveto.fator_velocidade() if tem_graveto and graveto else 1.0
	return direcao * velocidade * fator


func _girar_modelo(delta: float) -> void:
	# O modelo olha para +X quando rotation.y == 0.
	modelo.rotation.y = lerp_angle(modelo.rotation.y, _yaw_alvo, 1.0 - exp(-velocidade_giro * delta))


func _checar_queda(delta: float) -> void:
	if fase and fase.dentro_da_agua(global_position):
		_voltar_ao_ponto_seguro("agua")
	elif global_position.y < -10.0:
		_voltar_ao_ponto_seguro("queda")
	elif is_on_floor():
		_tempo_ponto_seguro += delta
		if _tempo_ponto_seguro >= 0.25:
			_guardar_ponto_seguro()


func _guardar_ponto_seguro() -> void:
	_tempo_ponto_seguro = 0.0
	_pontos_seguros.append(global_position)
	if _pontos_seguros.size() > 4:
		_pontos_seguros.pop_front()


func _voltar_ao_ponto_seguro(motivo: String) -> void:
	global_position = _pontos_seguros[0] + Vector3.UP * 0.2
	velocity = Vector3.ZERO
	var ponto := _pontos_seguros[0]
	_pontos_seguros.clear()
	_pontos_seguros.append(ponto)
	voltou_ao_ponto_seguro.emit(motivo)

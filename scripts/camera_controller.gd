class_name CameraController
extends Node3D
## Câmera da fase, sempre em terceira pessoa (ver docs/DESIGN.md, "Câmera"): rig com SpringArm3D
## atrás do cachorro, orbitando com mouse/analógico. Numa cena (`focar`), ela vai até o que
## importa e o jogador não a controla.
##
## A Camera3D não é filha do SpringArm3D: ela copia a ponta do braço (origem + direção *
## get_hit_length()), e assim uma cena pode levar o braço até outra coisa sem brigar com ele.

## Inclinação (graus; negativo = olhando de cima) no começo e ao voltar de uma cena.
@export var pitch_inicial := -15.0
@export var fov := 70.0
@export var distancia := 4.0
@export var altura_pivo := 0.6
@export var sensibilidade_mouse := 0.003
## Radianos por segundo com o analógico direito no máximo.
@export var velocidade_analogico := 2.5
@export var pitch_min := -70.0
@export var pitch_max := 15.0

@export_group("Cena (foco)")
## Distância (m) e FOV da câmera focando alguma coisa numa cena (ver `focar`).
@export var distancia_foco := 2.6
@export var fov_foco := 50.0
@export var pitch_foco := -12.0

var alvo: CharacterBody3D
## Numa cena, o que a câmera mostra (ver `focar`), ou nulo.
var foco: Node3D
## 0 = câmera no cachorro, 1 = no foco. Animado por `focar`/`soltar_foco`.
var mistura_foco := 0.0

var _yaw := 0.0
var _pitch := 0.0
## Pivô da câmera na cena: segue o foco suavemente (trocar de foco vira um movimento de câmera).
var _pivo_foco := Vector3.ZERO
var _tween_foco: Tween
var _olhar_de := Vector3.INF
var _distancia_da_cena := 2.6
## Soltando o foco: giro e inclinação vão de onde estavam (`_yaw_de`) até os de seguir o cachorro.
var _soltando := false
var _yaw_de := 0.0
var _pitch_de := 0.0
var _yaw_ao_soltar := 0.0

@onready var braco: SpringArm3D = $BracoCamera
@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	braco.spring_length = distancia
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = fov
	_pitch = deg_to_rad(pitch_inicial)


## Define quem a câmera segue e já a põe atrás dele, girada `yaw` graus (0° = câmera em +Z
## olhando para -Z; o modelo do cachorro olha para +X, então atrás dele é o yaw dele - 90°).
func configurar(novo_alvo: CharacterBody3D, yaw := 0.0) -> void:
	alvo = novo_alvo
	braco.add_excluded_object(alvo.get_rid())
	olhar(yaw)


## Põe a câmera atrás do alvo, girada `yaw` graus (ver `configurar`), sem transição.
func olhar(yaw: float) -> void:
	_yaw = deg_to_rad(yaw)
	_pitch = deg_to_rad(pitch_inicial)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if alvo:
		braco.global_position = alvo.global_position + Vector3.UP * altura_pivo
		braco.rotation = Vector3(_pitch, _yaw, 0.0)
		camera.global_transform = _transform_braco()


## Cena (o jogador não mexe a câmera): a câmera se aproxima de `no` e o acompanha, olhando do
## lado do cachorro para ele (ou do lado de `olhar_de`, se dado), a `distancia_cena` m (0 =
## `distancia_foco`). Chamar de novo com outra coisa leva a câmera até ela. Com `duracao` 0 já
## começa lá. Aguarde com `await` para esperar a aproximação; `soltar_foco` devolve a câmera ao
## cachorro.
func focar(no: Node3D, duracao := 0.8, olhar_de := Vector3.INF, distancia_cena := 0.0) -> void:
	if foco == null or duracao <= 0.0:
		_pivo_foco = no.global_position if duracao <= 0.0 else braco.global_position
	foco = no
	_olhar_de = olhar_de
	_distancia_da_cena = distancia_cena if distancia_cena > 0.0 else distancia_foco
	_soltando = false
	if duracao <= 0.0:
		if _tween_foco:
			_tween_foco.kill()
		mistura_foco = 1.0
		_yaw = _yaw_do_foco(_yaw)
		_pitch = deg_to_rad(pitch_foco)
		return
	await _animar_foco(1.0, duracao)


## Fim da cena: a câmera volta para o cachorro. Com `yaw` (graus, ver `configurar`), gira até
## ficar atrás dele assim; senão continua olhando para onde estava.
func soltar_foco(duracao := 0.8, yaw := NAN) -> void:
	_soltando = true
	_yaw_de = _yaw
	_pitch_de = _pitch
	_yaw_ao_soltar = _yaw if is_nan(yaw) else deg_to_rad(yaw)
	await _animar_foco(0.0, duracao)
	if _soltando:
		foco = null
		_soltando = false


## Em cena agora (a câmera não obedece ao jogador)?
func em_cena() -> bool:
	return foco != null


func _animar_foco(destino: float, duracao: float) -> void:
	if _tween_foco:
		_tween_foco.kill()
	_tween_foco = create_tween()
	_tween_foco.tween_property(self, "mistura_foco", destino, duracao) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _tween_foco.finished


## Yaw (rad) olhando para o foco do lado do cachorro (ou de `_olhar_de`); `atual` se não der.
func _yaw_do_foco(atual: float) -> float:
	var de := alvo.global_position if _olhar_de == Vector3.INF else _olhar_de
	var de_frente := de - _pivo_foco
	de_frente.y = 0.0
	return atan2(de_frente.x, de_frente.z) if de_frente.length() > 0.2 else atual


## Pivô, giro e distância da câmera numa cena, misturados com os de seguir o cachorro.
func _seguir_foco(delta: float) -> void:
	var suave := 1.0 - exp(-4.0 * delta)
	if is_instance_valid(foco):
		_pivo_foco = _pivo_foco.lerp(foco.global_position, suave)
	if _soltando:
		_yaw = lerp_angle(_yaw_ao_soltar, _yaw_de, mistura_foco)
		_pitch = lerpf(deg_to_rad(pitch_inicial), _pitch_de, mistura_foco)
	elif is_instance_valid(foco):
		_yaw = lerp_angle(_yaw, _yaw_do_foco(_yaw), suave * mistura_foco)
		_pitch = lerpf(_pitch, deg_to_rad(pitch_foco), suave * mistura_foco)
	braco.global_position = braco.global_position.lerp(_pivo_foco, mistura_foco)
	braco.rotation = Vector3(_pitch, _yaw, 0.0)
	braco.spring_length = lerpf(distancia, _distancia_da_cena, mistura_foco)
	camera.fov = lerpf(fov, fov_foco, mistura_foco)


func _unhandled_input(event: InputEvent) -> void:
	if em_cena():
		return
	# Esc (liberar_mouse) é do jogo: abre a pausa, que solta o mouse e prende de novo ao voltar.
	if event.is_action_pressed("capturar_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Movimento do mouse não é mapeável no InputMap; o analógico usa as ações camera_*.
		var movimento := event as InputEventMouseMotion
		_girar(-movimento.relative.x * sensibilidade_mouse, -movimento.relative.y * sensibilidade_mouse)


func _physics_process(delta: float) -> void:
	if alvo == null:
		return
	if not em_cena():
		var analogico := Input.get_vector("camera_esquerda", "camera_direita", "camera_cima", "camera_baixo")
		_girar(-analogico.x * velocidade_analogico * delta, -analogico.y * velocidade_analogico * delta)
	braco.global_position = alvo.global_position + Vector3.UP * altura_pivo
	braco.rotation = Vector3(_pitch, _yaw, 0.0)
	if foco or mistura_foco > 0.0:
		_seguir_foco(delta)
	camera.global_transform = _transform_braco()


func _girar(delta_yaw: float, delta_pitch: float) -> void:
	# Sensibilidade e "inverter Y" das Opções (mouse e analógico).
	var opcoes := get_node_or_null(^"/root/Opcoes")
	if opcoes:
		var fator := float(opcoes.valor("controles", "sensibilidade"))
		delta_yaw *= fator
		delta_pitch *= fator * (-1.0 if opcoes.valor("controles", "inverter_y") else 1.0)
	_yaw = wrapf(_yaw + delta_yaw, -PI, PI)
	_pitch = clampf(_pitch + delta_pitch, deg_to_rad(pitch_min), deg_to_rad(pitch_max))


## Ponta do SpringArm, olhando para o pivô (o +Z do braço aponta para a câmera).
func _transform_braco() -> Transform3D:
	var base := braco.global_basis
	return Transform3D(base, braco.global_position + base.z * braco.get_hit_length())

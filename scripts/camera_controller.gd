class_name CameraController
extends Node3D
## Câmera da fase.
##
## ISOMETRICO: câmera ortográfica fixa, vista de cima, seguindo o cachorro.
## TRANSICAO: mistura a câmera isométrica com a de terceira pessoa (tween em `mistura`),
## nos dois sentidos (pegar o graveto → 3D; largar o graveto → isométrica).
## TERCEIRA_PESSOA: rig com SpringArm3D atrás do cachorro, orbitando com mouse/analógico.
##
## A Camera3D não é filha do SpringArm3D: o SpringArm reposiciona todos os filhos a cada
## frame de física, o que brigaria com a câmera isométrica e com a transição. Em vez disso,
## no modo 3D a câmera copia a ponta do braço (origem + direção * get_hit_length()).

signal transicao_concluida

enum Estado { ISOMETRICO, TRANSICAO, TERCEIRA_PESSOA }

@export_group("Modo isométrico")
## Giro da câmera em volta do cachorro. 0° = câmera em +Z olhando para -Z (de frente).
## Assim as faces ±X ficam de perfil e não aparecem: as bocas do túnel e a parede do barranco.
@export var yaw_iso := 0.0
## Inclinação para baixo (negativo = olhando de cima).
@export var pitch_iso := -55.0
## Altura visível (m) da câmera ortográfica. Maior = mais afastada.
@export var tamanho_iso := 11.0
## Distância da câmera até o cachorro (só precisa ficar fora do cenário).
@export var distancia_iso := 30.0
@export var suavizacao_iso := 6.0

@export_group("Transição")
@export var duracao_transicao := 1.2
## Direção inicial da câmera 3D. 90° = câmera em +X olhando para -X.
## O jogo recalcula a cada fase para a câmera olhar do cachorro para o dono.
@export var yaw_inicial_3d := 78.0
@export var pitch_inicial_3d := -15.0

@export_group("Modo 3D (terceira pessoa)")
@export var fov_3d := 70.0
@export var distancia_3d := 4.0
@export var altura_pivo_3d := 0.6
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
## Enquanto não for nulo, a câmera gira em volta dele em vez do cachorro (mirante).
var ponto_de_vista: Node3D
var estado := Estado.ISOMETRICO
## 0 = câmera isométrica, 1 = terceira pessoa. Animado pelo tween da transição.
var mistura := 0.0
## Numa cena, o que a câmera mostra (ver `focar`), ou nulo.
var foco: Node3D
## 0 = câmera no cachorro, 1 = no foco. Animado por `focar`/`soltar_foco`.
var mistura_foco := 0.0

var _yaw := 0.0
var _pitch := 0.0
var _foco_iso := Vector3.ZERO
## FOV (perspectiva) que enquadra o mesmo que a ortográfica na distância do cachorro.
var _fov_iso := 0.0
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
	braco.spring_length = distancia_3d
	_fov_iso = rad_to_deg(2.0 * atan(tamanho_iso * 0.5 / distancia_iso))
	_usar_ortografica()


## Define quem a câmera segue e já posiciona a câmera isométrica nele.
func configurar(novo_alvo: CharacterBody3D) -> void:
	alvo = novo_alvo
	braco.add_excluded_object(alvo.get_rid())
	_foco_iso = alvo.global_position
	camera.global_transform = _alinhar_ao_pixel(_transform_iso())


## O alvo mudou de lugar de uma vez (saiu pela outra toca): a isométrica vai junto, sem deslizar.
func recentralizar() -> void:
	if alvo:
		_foco_iso = alvo.global_position


## Começa direto na terceira pessoa, sem transição (fases só em terceira pessoa, como o parque):
## a câmera atrás do alvo, girada `yaw` graus (ver `yaw_inicial_3d`).
func comecar_em_3d(yaw: float) -> void:
	_yaw = deg_to_rad(yaw)
	_pitch = deg_to_rad(pitch_inicial_3d)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = fov_3d
	mistura = 1.0
	estado = Estado.TERCEIRA_PESSOA
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if alvo:
		braco.global_position = alvo.global_position + Vector3.UP * altura_pivo_3d
		braco.rotation = Vector3(_pitch, _yaw, 0.0)
		camera.global_transform = _transform_3d()


## Cena (o jogador não mexe a câmera): a câmera se aproxima de `no` e o acompanha, olhando do
## lado do cachorro para ele (ou do lado de `olhar_de`, se dado), a `distancia` m (0 =
## `distancia_foco`). Chamar de novo com outra coisa leva a câmera até ela. Com `duracao` 0 já
## começa lá. Aguarde com `await` para esperar a aproximação; `soltar_foco` devolve a câmera ao
## cachorro.
func focar(no: Node3D, duracao := 0.8, olhar_de := Vector3.INF, distancia := 0.0) -> void:
	if foco == null or duracao <= 0.0:
		_pivo_foco = no.global_position if duracao <= 0.0 else braco.global_position
	foco = no
	_olhar_de = olhar_de
	_distancia_da_cena = distancia if distancia > 0.0 else distancia_foco
	_soltando = false
	if duracao <= 0.0:
		if _tween_foco:
			_tween_foco.kill()
		mistura_foco = 1.0
		_yaw = _yaw_do_foco(_yaw)
		_pitch = deg_to_rad(pitch_foco)
		return
	await _animar_foco(1.0, duracao)


## Fim da cena: a câmera volta para o cachorro. Com `yaw` (graus, ver `yaw_inicial_3d`), gira
## até ficar atrás dele assim; senão continua olhando para onde estava.
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
		_pitch = lerpf(deg_to_rad(pitch_inicial_3d), _pitch_de, mistura_foco)
	elif is_instance_valid(foco):
		_yaw = lerp_angle(_yaw, _yaw_do_foco(_yaw), suave * mistura_foco)
		_pitch = lerpf(_pitch, deg_to_rad(pitch_foco), suave * mistura_foco)
	braco.global_position = braco.global_position.lerp(_pivo_foco, mistura_foco)
	braco.rotation = Vector3(_pitch, _yaw, 0.0)
	braco.spring_length = lerpf(distancia_3d, _distancia_da_cena, mistura_foco)
	camera.fov = lerpf(fov_3d, fov_foco, mistura_foco)


func transicionar_para_3d() -> void:
	if estado != Estado.ISOMETRICO:
		return
	_yaw = deg_to_rad(yaw_inicial_3d)
	_pitch = deg_to_rad(pitch_inicial_3d)

	# Troca para perspectiva com o FOV equivalente: a imagem fica praticamente igual
	# e daí dá para animar o FOV.
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = _fov_iso
	await _animar_mistura(1.0)

	estado = Estado.TERCEIRA_PESSOA
	camera.fov = fov_3d
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	transicao_concluida.emit()


func transicionar_para_iso() -> void:
	if estado != Estado.TERCEIRA_PESSOA:
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_foco_iso = alvo.global_position
	await _animar_mistura(0.0)

	estado = Estado.ISOMETRICO
	_usar_ortografica()
	transicao_concluida.emit()


func _animar_mistura(destino: float) -> void:
	estado = Estado.TRANSICAO
	var tween := create_tween()
	tween.tween_property(self, "mistura", destino, duracao_transicao) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


func _usar_ortografica() -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = tamanho_iso


func _unhandled_input(event: InputEvent) -> void:
	if estado != Estado.TERCEIRA_PESSOA or em_cena():
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

	if estado == Estado.TERCEIRA_PESSOA and not em_cena():
		var analogico := Input.get_vector("camera_esquerda", "camera_direita", "camera_cima", "camera_baixo")
		_girar(-analogico.x * velocidade_analogico * delta, -analogico.y * velocidade_analogico * delta)

	var seguido: Node3D = ponto_de_vista if ponto_de_vista else alvo
	braco.global_position = seguido.global_position + Vector3.UP * altura_pivo_3d
	braco.rotation = Vector3(_pitch, _yaw, 0.0)

	match estado:
		Estado.ISOMETRICO:
			_foco_iso = _foco_iso.lerp(seguido.global_position, 1.0 - exp(-suavizacao_iso * delta))
			camera.global_transform = _alinhar_ao_pixel(_transform_iso())
		Estado.TRANSICAO:
			# Orbita em volta do cachorro interpolando ângulos e distância separadamente
			# (interpolar as rotações direto faz a câmera "rolar" no meio do caminho).
			var yaw := lerp_angle(deg_to_rad(yaw_iso), _yaw, mistura)
			var pitch := lerpf(deg_to_rad(pitch_iso), _pitch, mistura)
			var distancia := lerpf(distancia_iso, braco.get_hit_length(), mistura)
			var pivo := _foco_iso.lerp(braco.global_position, mistura)
			camera.global_transform = _transform_orbita(pivo, yaw, pitch, distancia)
			camera.fov = lerpf(_fov_iso, fov_3d, mistura)
		Estado.TERCEIRA_PESSOA:
			if foco or mistura_foco > 0.0:
				_seguir_foco(delta)
			camera.global_transform = _transform_3d()


func _girar(delta_yaw: float, delta_pitch: float) -> void:
	# Sensibilidade e "inverter Y" das Opções (mouse e analógico).
	var opcoes := get_node_or_null(^"/root/Opcoes")
	if opcoes:
		var fator := float(opcoes.valor("controles", "sensibilidade"))
		delta_yaw *= fator
		delta_pitch *= fator * (-1.0 if opcoes.valor("controles", "inverter_y") else 1.0)
	_yaw = wrapf(_yaw + delta_yaw, -PI, PI)
	_pitch = clampf(_pitch + delta_pitch, deg_to_rad(pitch_min), deg_to_rad(pitch_max))


func _transform_iso() -> Transform3D:
	return _transform_orbita(_foco_iso, deg_to_rad(yaw_iso), deg_to_rad(pitch_iso), distancia_iso)


## Alinha a câmera ortográfica à grade de pixels da imagem 3D (que é de baixa resolução,
## ver autoload Visual): sem isso o cenário "treme" um pixel enquanto a câmera desliza.
func _alinhar_ao_pixel(t: Transform3D) -> Transform3D:
	var tamanho_texel := tamanho_iso / Visual.altura_interna()
	var o := t.origin
	var x := snappedf(o.dot(t.basis.x), tamanho_texel)
	var y := snappedf(o.dot(t.basis.y), tamanho_texel)
	t.origin = t.basis.x * x + t.basis.y * y + t.basis.z * o.dot(t.basis.z)
	return t


## Câmera olhando para `pivo`, afastada dele na direção do seu próprio +Z.
func _transform_orbita(pivo: Vector3, yaw: float, pitch: float, distancia: float) -> Transform3D:
	var base := Basis.from_euler(Vector3(pitch, yaw, 0.0))
	return Transform3D(base, pivo + base.z * distancia)


## Ponta do SpringArm, olhando para o pivô (o +Z do braço aponta para a câmera).
func _transform_3d() -> Transform3D:
	var base := braco.global_basis
	return Transform3D(base, braco.global_position + base.z * braco.get_hit_length())

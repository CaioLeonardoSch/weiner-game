@tool
class_name Ovelha
extends ObjetoFase
## Ovelha: pasta andando à toa e foge do cachorro que chega perto. Um latido espanta de vez
## (corre para longe do latido). As ovelhas andam juntas (se aproximam das vizinhas quando
## fogem) e não entram na água funda nem pulam de barrancos.
## Dentro de um abrigo (Cercado ou Celeiro) ela se acalma e não sai mais — nas fases de
## pastoreio, o objetivo é levar todas para dentro.
## De vez em quando ela bale ("Béé!", com som): longe do cachorro, é assim que se acha uma ovelha
## perdida num mapa grande.

## Distância (m) em que a ovelha começa a fugir do cachorro.
const RAIO_MEDO := 2.6
const VELOCIDADE_FUGA := 2.6
const VELOCIDADE_ESPANTO := 3.8
const VELOCIDADE_PASTAR := 0.45
const DURACAO_ESPANTO := 0.9
## Intervalo (s) entre balidos, sorteado nesta faixa.
const INTERVALO_BALIDO := Vector2(7.0, 15.0)

## Aparência (a 7 é a ovelha negra).
@export_range(0, 7) var variante := 0:
	set(valor):
		variante = valor
		_atualizar_modelo()

## Já entrou num cercado: fica calma lá dentro.
var guardada := false

@onready var corpo: CharacterBody3D = $Corpo
@onready var modelo: MeshInstance3D = $Corpo/Modelo

var _fase: Fase
var _cachorro: Node3D
var _espanto := 0.0
var _direcao_espanto := Vector3.ZERO
var _direcao_pastar := Vector3.ZERO
var _tempo_pastar := 0.0
var _passo := 0.0
## Lado do desvio escolhido ao ficar bloqueada (mantido enquanto dura o bloqueio, senão
## ela ficaria indecisa, trocando de lado a cada quadro).
var _lado_desvio := 0.0
## Último lugar firme onde esteve (se mesmo assim cair, volta para ele).
var _ponto_seguro := Vector3.ZERO
var _gravidade: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _proximo_balido := 0.0


func nome_no_editor() -> String:
	return "Ovelha"


func categoria_no_editor() -> String:
	return "Bichos"


func propriedades_editaveis() -> Array[StringName]:
	return [&"variante"]


func ao_colocar_no_editor(rng: RandomNumberGenerator) -> void:
	# De vez em quando sai a ovelha negra.
	variante = 7 if rng.randf() < 0.1 else rng.randi_range(0, 6)
	rotation.y = rng.randf_range(-PI, PI)


func _ready() -> void:
	_atualizar_modelo()
	if Engine.is_editor_hint():
		return
	add_to_group(&"ovelhas")
	add_to_group(&"pesos")
	var no := get_parent()
	while no and not no is Fase:
		no = no.get_parent()
	_fase = no as Fase
	_tempo_pastar = randf_range(0.5, 2.5)
	_ponto_seguro = global_position
	_proximo_balido = randf_range(2.0, INTERVALO_BALIDO.y)


func _atualizar_modelo() -> void:
	if is_node_ready():
		modelo.mesh = Voxel.ovelha(variante)


func peso_na_placa() -> float:
	return 1.5


func ao_ouvir_latido(origem: Vector3) -> void:
	if guardada:
		return
	var longe := global_position - origem
	longe.y = 0.0
	if longe.length() < 0.01:
		longe = Vector3.RIGHT
	_direcao_espanto = longe.normalized()
	_espanto = DURACAO_ESPANTO
	balir()


## "Béé!": o som (tom pela variante: a ovelha negra é mais grave) e o balão subindo.
func balir() -> void:
	_proximo_balido = randf_range(INTERVALO_BALIDO.x, INTERVALO_BALIDO.y)
	var tom := 0.85 if variante == 7 else 0.95 + variante * 0.03
	Som.balido(get_parent(), global_position + Vector3.UP * 0.6, tom)
	var texto := Label3D.new()
	texto.text = "Béé!"
	texto.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	texto.font_size = 44
	texto.outline_size = 12
	texto.pixel_size = 0.008
	texto.modulate = Color(1.0, 1.0, 1.0)
	texto.no_depth_test = true
	get_parent().add_child(texto)
	texto.global_position = global_position + Vector3.UP * 0.9
	var tween := texto.create_tween().set_parallel()
	tween.tween_property(texto, "global_position:y", texto.global_position.y + 0.6, 1.0)
	tween.tween_property(texto, "modulate:a", 0.0, 0.6).set_delay(0.5)
	tween.chain().tween_callback(texto.queue_free)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _cachorro == null:
		_cachorro = get_tree().get_first_node_in_group(&"cachorro") as Node3D
	# Longe do cachorro e ainda solta, bale de vez em quando (para ser achada).
	if not guardada:
		_proximo_balido -= delta
		if _proximo_balido <= 0.0:
			if _cachorro == null or _cachorro.global_position.distance_to(global_position) > 5.0:
				balir()
			else:
				_proximo_balido = randf_range(INTERVALO_BALIDO.x, INTERVALO_BALIDO.y)

	var desejo := Vector3.ZERO
	var velocidade := 0.0
	var fugindo := false
	var do_cachorro := Vector3.ZERO
	if _cachorro:
		do_cachorro = global_position - _cachorro.global_position
		do_cachorro.y = 0.0
	if _espanto > 0.0:
		_espanto -= delta
		desejo = _direcao_espanto
		velocidade = VELOCIDADE_ESPANTO
		fugindo = true
	elif not guardada and _cachorro and do_cachorro.length() < RAIO_MEDO:
		desejo = do_cachorro.normalized()
		# Quanto mais perto, mais rápido.
		velocidade = VELOCIDADE_FUGA * clampf(1.3 - do_cachorro.length() / RAIO_MEDO, 0.45, 1.0)
		fugindo = true
	else:
		_tempo_pastar -= delta
		if _tempo_pastar <= 0.0:
			_tempo_pastar = randf_range(1.5, 3.5)
			# Metade do tempo parada, pastando.
			_direcao_pastar = Vector3.ZERO if randf() < 0.5 \
				else Vector3.RIGHT.rotated(Vector3.UP, randf() * TAU)
		desejo = _direcao_pastar
		velocidade = VELOCIDADE_PASTAR

	# Rebanho: não se amontoam, e fugindo vão juntas.
	for outra in get_tree().get_nodes_in_group(&"ovelhas"):
		if outra == self:
			continue
		var ate := (outra as Node3D).global_position - global_position
		ate.y = 0.0
		var distancia := ate.length()
		if distancia < 0.75 and distancia > 0.001:
			desejo -= ate / distancia * (0.75 - distancia) * 2.0
		elif fugindo and distancia < 3.5:
			desejo += ate.normalized() * 0.2

	# Neve fofa e água rasa atrasam as ovelhas também.
	if _fase and corpo.is_on_floor():
		velocidade *= Tiles.definicao(_fase.tile_em(corpo.global_position + Vector3.DOWN * 0.05)).get("lentidao", 1.0)
	var horizontal := Vector3.ZERO
	if desejo.length() > 0.05:
		horizontal = _evitar_perigo(desejo.normalized() * velocidade)
	var atual := Vector3(corpo.velocity.x, 0.0, corpo.velocity.z)
	atual = atual.move_toward(horizontal, (14.0 if fugindo else 4.0) * delta)
	# Freia na hora se o embalo (ainda na direção antiga) levaria para a água ou o barranco.
	if atual.length() > 0.05 and not _seguro(atual):
		atual = horizontal
	corpo.velocity.x = atual.x
	corpo.velocity.z = atual.z
	corpo.velocity.y = 0.0 if corpo.is_on_floor() else corpo.velocity.y - _gravidade * delta
	corpo.move_and_slide()

	# Rede de segurança: caiu mesmo assim (empurrada, quina de colisão)? Volta ao último
	# lugar firme.
	if corpo.global_position.y < _ponto_seguro.y - 1.5 \
			or (_fase and _fase.dentro_da_agua(corpo.global_position)):
		corpo.global_position = _ponto_seguro
		corpo.velocity = Vector3.ZERO
	elif corpo.is_on_floor() and _seguro_aqui():
		_ponto_seguro = corpo.global_position

	# A raiz acompanha o corpo: a posição do objeto é onde a ovelha está (latido, cercado).
	var posicao := corpo.global_position
	global_position = posicao
	corpo.position = Vector3.ZERO

	var plano := Vector2(atual.x, atual.z)
	if plano.length() > 0.2:
		var alvo := atan2(-atual.z, atual.x) - rotation.y
		modelo.rotation.y = lerp_angle(modelo.rotation.y, alvo, 1.0 - exp(-8.0 * delta))
	# Pulinhos ao correr.
	_passo += delta * plano.length() * 5.0
	modelo.position.y = absf(sin(_passo)) * 0.05 * clampf(plano.length() / 2.0, 0.0, 1.0)


## Não anda para onde cairia (água funda, barranco), nem de cara num obstáculo, nem para fora
## do cercado depois de guardada. Bloqueada, escapa ao longo da parede: tenta desvios cada
## vez maiores (45°, 90°, 135°), para o lado que continua longe do cachorro.
func _evitar_perigo(velocidade: Vector3) -> Vector3:
	if _seguro(velocidade):
		_lado_desvio = 0.0
		return velocidade
	if _lado_desvio == 0.0:
		_lado_desvio = 1.0
		if _cachorro:
			var do_cachorro := global_position - _cachorro.global_position
			if velocidade.rotated(Vector3.UP, 0.1).dot(do_cachorro) < velocidade.dot(do_cachorro):
				_lado_desvio = -1.0
	for angulo in [PI * 0.25, PI * 0.5, PI * 0.75]:
		for sentido in [_lado_desvio, -_lado_desvio]:
			var desvio := velocidade.rotated(Vector3.UP, angulo * sentido)
			if _seguro(desvio):
				_lado_desvio = sentido
				return desvio
	return Vector3.ZERO


func _seguro(velocidade: Vector3) -> bool:
	var frente := global_position + velocidade.normalized() * 0.5
	var espaco := corpo.get_world_3d().direct_space_state
	# Obstáculo na frente (cerca, árvore, parede, outra ovelha).
	var olhar := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.3,
		global_position + velocidade.normalized() * 0.75 + Vector3.UP * 0.3, 1 | 2 | 4, [corpo.get_rid()])
	if not espaco.intersect_ray(olhar).is_empty():
		return false
	if guardada:
		var dentro := false
		for abrigo in get_tree().get_nodes_in_group(&"abrigos"):
			if abrigo.contem(frente):
				dentro = true
		if not dentro:
			return false
	var raio := PhysicsRayQueryParameters3D.create(frente + Vector3.UP * 0.4, frente + Vector3.DOWN * 0.6, 1)
	var chao := espaco.intersect_ray(raio)
	if chao.is_empty():
		return false
	if _fase and Tiles.eh_agua(_fase.tile_em((chao.position as Vector3) + Vector3.DOWN * 0.05)):
		return false
	return true


## Parada em chão firme (não na água funda nem na beirada dela)?
func _seguro_aqui() -> bool:
	if _fase == null:
		return true
	for desvio in [Vector3.ZERO, Vector3(0.3, 0, 0), Vector3(-0.3, 0, 0), Vector3(0, 0, 0.3), Vector3(0, 0, -0.3)]:
		if Tiles.eh_agua(_fase.tile_em(corpo.global_position + desvio + Vector3.DOWN * 0.1)):
			return false
	return true

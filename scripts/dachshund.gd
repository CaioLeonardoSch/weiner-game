class_name Dachshund
extends CharacterBody3D
## O cachorro do jogador (o salsicha, ou a raça que a fase escolher — ver `aplicar_raca`).
##
## Movimento livre no plano XZ, relativo à câmera (8 direções no modo isométrico,
## analógico/WASD na terceira pessoa). O Y fica por conta da gravidade + move_and_slide.
##
## O graveto na boca tem colisão própria (a forma `ColisaoGraveto` do corpo): se ele não
## passa, o cachorro não passa, e o cachorro não gira se o graveto bater em algo no giro.
## `virar_graveto()` alterna entre atravessado (padrão) e ao comprido (apontando para a
## frente) — o jeito de passar por vãos estreitos com um graveto grande.
## Em passagens estreitas (tábua), graveto grande e pesado desequilibra o cachorro.

## Caiu num lugar sem volta (água, abismo) e foi levado de volta para terra firme.
signal voltou_ao_ponto_seguro(motivo: String)
## Tentou puxar um bloco e não deu ("boca_cheia", "sem_espaco"); uma vez por aperto de F.
signal puxar_falhou(motivo: String)

## Até onde o latido chega (m).
const ALCANCE_LATIDO := 5.0

@export var velocidade := 3.5
## Velocidade com que o modelo gira para a direção do movimento.
@export var velocidade_giro := 10.0
## Multiplicador da velocidade segurando `andar_devagar`.
@export var fator_devagar := 0.4
## Altura do pulo (m) sem graveto. Passa de meio bloco (0,5 m), não de um bloco inteiro.
@export var altura_pulo := 0.65

@export_group("Equilíbrio")
## Carga (peso × comprimento do graveto) que ainda não desequilibra. O graveto padrão
## (0,8 m, peso 1) fica abaixo disso.
@export var carga_sem_balanco := 1.2
## Empurrão lateral máximo (m/s) do balanço.
@export var forca_balanco := 2.1
## Ao comprido o peso fica alinhado com o corpo: balança menos.
@export var fator_ao_comprido := 0.35

## Câmera usada como referência de direção (definida pelo jogo).
var camera_referencia: Camera3D
## Fase atual (para saber onde tem água etc.).
var fase: Fase
var tem_graveto := false
var graveto: Graveto
## Graveto apontando para a frente (true) ou atravessado na boca (false).
var graveto_ao_comprido := false
## Quando true, ignora a entrada do jogador (transição de câmera, fim de fase).
var entrada_bloqueada := false
## Habilidades liberadas pela fase.
var pode_pular := false
var pode_cavar := false
var pode_latir := false
## Balanço atual, de -1 a 1 (para o HUD). Só muda em passagens estreitas.
var balanco := 0.0
var em_passagem_estreita := false
## O graveto está impedindo o cachorro de andar (e não há encaixe para o lado).
var graveto_travado := false

var _gravidade: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _yaw_alvo := 0.0
## Últimas posições em chão firme (a mais antiga é usada ao voltar, para não
## reaparecer bem na beirada de onde caiu).
var _pontos_seguros: Array[Vector3] = []
var _tempo_ponto_seguro := 0.0
var _fase_balanco := 0.0
var _tempo_fora_da_passagem := 0.0
## Forma um pouco menor que a do graveto, para testar giros sem contar o simples encostar.
var _forma_teste := CapsuleShape3D.new()
var _tween_graveto: Tween
var _cavando := false
var _espera_latido := 0.0
var _empurrando: Node
## Na água rasa: multiplicador da velocidade e se há correnteza embaixo.
var _lentidao_agua := 1.0
var em_correnteza := false
## Puxando um bloco: o cachorro recua uma célula junto com ele.
const DURACAO_PUXAR := 0.35
var _tempo_puxando := 0.0
## Motivo já avisado neste aperto de F (para não repetir o aviso a cada quadro).
var _motivo_puxar_avisado := ""
var _sentido_puxar := Vector3.ZERO
var _tempo_empurrando := 0.0

@onready var modelo: Node3D = $Modelo
@onready var boca: Marker3D = $Modelo/Boca
@onready var voxel: ModeloCachorro = $Modelo/Voxel
## Raça atual (formato, pelagem, velocidade). Ver assets/racas/.
var raca: Raca
@onready var colisao_graveto: CollisionShape3D = $ColisaoGraveto


func _ready() -> void:
	colisao_graveto.disabled = true
	raca = voxel.raca
	add_to_group(&"cachorro")
	_guardar_ponto_seguro()


## Troca a raça e a pelagem do cachorro. A boca (onde fica o graveto) acompanha o modelo, e
## a cápsula de colisão segue as medidas da raça.
func aplicar_raca(nova_raca: Raca, indice_pelagem: int) -> void:
	raca = nova_raca
	voxel.montar(nova_raca, indice_pelagem)
	boca.position = voxel.boca
	var forma := CapsuleShape3D.new()
	forma.radius = nova_raca.raio_colisao
	forma.height = maxf(nova_raca.altura_colisao, nova_raca.raio_colisao * 2.0)
	var colisao := $Colisao as CollisionShape3D
	colisao.shape = forma
	colisao.position.y = forma.height * 0.5


## Peso sobre uma placa de pressão: o da raça mais o do graveto na boca.
func peso_total() -> float:
	var peso := raca.peso if raca else 1.0
	if tem_graveto and graveto:
		peso += graveto.peso_atual()
	return peso


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
	elif pode_pular and not entrada_bloqueada and Input.is_action_just_pressed("pular"):
		velocity.y = sqrt(2.0 * _gravidade * altura_pulo_atual())

	_espera_latido = maxf(_espera_latido - delta, 0.0)
	var horizontal := Vector3.ZERO if entrada_bloqueada or _cavando else _velocidade_entrada()
	if _tempo_puxando > 0.0:
		_tempo_puxando -= delta
		horizontal = _sentido_puxar / DURACAO_PUXAR
	elif not entrada_bloqueada and Input.is_action_pressed("acao"):
		var motivo := _tentar_puxar(horizontal)
		if not motivo.is_empty() and motivo != _motivo_puxar_avisado:
			_motivo_puxar_avisado = motivo
			puxar_falhou.emit(motivo)
	if not Input.is_action_pressed("acao"):
		_motivo_puxar_avisado = ""
	horizontal += _desvio_de_encaixe(horizontal, delta)
	horizontal += _empurrao_do_balanco(delta, horizontal)
	horizontal = _rampa_lisa(horizontal)
	var arrasto := _efeito_da_agua()
	# Parado à força (câmera em transição, mirante, fase concluída): a água não leva o cachorro
	# embora sem ele poder reagir.
	if entrada_bloqueada:
		arrasto = Vector3.ZERO
	horizontal *= _lentidao_agua
	velocity.x = horizontal.x + arrasto.x
	velocity.z = horizontal.z + arrasto.z

	move_and_slide()
	_soltar_se_pendurado()
	_escalar_do_buraco(horizontal)
	voxel.velocidade = Vector2(get_real_velocity().x, get_real_velocity().z).length()
	voxel.no_chao = is_on_floor()
	_empurrar(delta, horizontal)
	_girar_modelo(delta)
	_checar_queda(delta)


## Altura do pulo agora: o peso do graveto puxa para baixo.
## Com graveto na boca o pulo é um pouco mais baixo (não passa do Degrau alto); graveto pesado,
## mais baixo ainda.
func altura_pulo_atual() -> float:
	if tem_graveto and graveto:
		return altura_pulo * 0.88 / (1.0 + maxf(graveto.peso_atual() - 1.0, 0.0) * 0.35)
	return altura_pulo


func pegar_graveto(novo_graveto: Graveto) -> void:
	tem_graveto = true
	graveto = novo_graveto
	graveto_ao_comprido = false
	# Graveto atravessado na boca: a cena do graveto já deixa ele deitado no eixo Z,
	# que é "de lado" em relação ao focinho (o modelo olha para +X).
	graveto.reparent(boca, false)
	graveto.transform = _transform_visual_graveto(false)

	var forma := CapsuleShape3D.new()
	forma.radius = 0.07
	forma.height = graveto.comprimento
	colisao_graveto.shape = forma
	_forma_teste.radius = forma.radius - 0.02
	_forma_teste.height = forma.height - 0.06
	_atualizar_colisao_graveto()
	colisao_graveto.disabled = false


## Só marca que soltou; quem reposiciona o graveto no chão é o jogo.
func largar_graveto() -> void:
	tem_graveto = false
	graveto = null
	graveto_ao_comprido = false
	colisao_graveto.set_deferred("disabled", true)
	if _tween_graveto:
		_tween_graveto.kill()


## Alterna entre atravessado e ao comprido. Falso se não houver espaço para virar.
func virar_graveto() -> bool:
	if not tem_graveto or not _graveto_cabe(modelo.rotation.y, not graveto_ao_comprido):
		return false
	graveto_ao_comprido = not graveto_ao_comprido
	_atualizar_colisao_graveto()
	if _tween_graveto:
		_tween_graveto.kill()
	_tween_graveto = create_tween()
	_tween_graveto.tween_property(graveto, "transform", _transform_visual_graveto(graveto_ao_comprido), 0.2) \
		.set_trans(Tween.TRANS_SINE)
	return true


# --- Cavar, latir, empurrar ---------------------------------------------------------------

## Cava na frente do focinho, nesta ordem: um graveto enterrado (desenterra), a terra fofa
## embaixo de uma cerca (abre uma passagem baixa), um bloco de terra fofa (desfaz) ou a terra
## fofa do chão (vira um buraco). Devolve "" se começou a cavar, ou o motivo:
## "sem_habilidade", "boca_cheia", "ocupado" ou "nada" (nada cavável na frente).
func cavar() -> String:
	if not pode_cavar:
		return "sem_habilidade"
	if tem_graveto:
		return "boca_cheia"
	if _cavando or not is_on_floor():
		return "ocupado"
	var enterrado := _enterrado_na_frente()
	if enterrado:
		_animar_cavar(fase.terreno.local_to_map(fase.terreno.to_local(enterrado.global_position)),
			enterrado.desenterrar)
		return ""
	var cerca: Variant = _cerca_cavavel_na_frente()
	if cerca != null:
		_animar_cavar(fase.terreno.local_to_map(fase.terreno.to_local(cerca[1])),
			(cerca[0] as Cerca).cavar_em.bind(cerca[1]))
		return ""
	var celula: Variant = _celula_cavavel_na_frente()
	if celula != null:
		_animar_cavar(celula, fase.terreno.set_cell_item.bind(celula, GridMap.INVALID_CELL_ITEM))
		return ""
	var chao: Variant = _chao_cavavel_na_frente()
	if chao != null:
		_animar_cavar(chao, _abrir_buraco.bind(chao))
		return ""
	return "nada"


func _celula_cavavel_na_frente() -> Variant:
	var frente := Vector3(cos(modelo.rotation.y), 0.0, -sin(modelo.rotation.y))
	for distancia: float in [0.55, 0.8, 1.0]:
		var ponto := global_position + Vector3.UP * 0.3 + frente * distancia
		var celula := fase.terreno.local_to_map(fase.terreno.to_local(ponto))
		if Tiles.eh_cavavel(fase.terreno.get_cell_item(celula)):
			return celula
	return null


## Graveto enterrado bem na frente do focinho (até ~1 m).
func _enterrado_na_frente() -> Graveto:
	var frente := Vector3(cos(modelo.rotation.y), 0.0, -sin(modelo.rotation.y))
	var ponto := global_position + frente * 0.6
	for no in get_tree().get_nodes_in_group(&"enterrados"):
		var graveto := no as Graveto
		var ate := graveto.global_position - ponto
		if Vector2(ate.x, ate.z).length() < 0.6:
			return graveto
	return null


## Cerca com terra fofa embaixo, à frente: [cerca, ponto onde o focinho encosta] ou null.
func _cerca_cavavel_na_frente() -> Variant:
	var frente := Vector3(cos(modelo.rotation.y), 0.0, -sin(modelo.rotation.y))
	var origem := global_position + Vector3.UP * 0.3
	var raio := PhysicsRayQueryParameters3D.create(origem, origem + frente * 1.0, 4, [get_rid()])
	var achado := get_world_3d().direct_space_state.intersect_ray(raio)
	if achado.is_empty():
		return null
	var cerca := (achado.collider as Node).get_parent() as Cerca
	if cerca == null or not cerca.pode_cavar_em(achado.position):
		return null
	return [cerca, achado.position]


## Terra fofa no chão, logo à frente (a célula da camada do chão, sem nada em cima).
func _chao_cavavel_na_frente() -> Variant:
	var frente := Vector3(cos(modelo.rotation.y), 0.0, -sin(modelo.rotation.y))
	for distancia: float in [0.7, 0.95]:
		var ponto := global_position + frente * distancia + Vector3.DOWN * 0.3
		var celula := fase.terreno.local_to_map(fase.terreno.to_local(ponto))
		if Tiles.eh_cavavel(fase.terreno.get_cell_item(celula)) \
				and fase.terreno.get_cell_item(celula + Vector3i.UP) == GridMap.INVALID_CELL_ITEM:
			return celula
	return null


func _abrir_buraco(celula: Vector3i) -> void:
	fase.terreno.set_cell_item(celula, Tiles.BURACO)


## Três cavadas (o corpo mexe, a terra voa) e então `ao_terminar`.
func _animar_cavar(celula: Vector3i, ao_terminar: Callable) -> void:
	_cavando = true
	var centro := fase.terreno.to_global(fase.terreno.map_to_local(celula))
	var tween := create_tween()
	for i in 3:
		tween.tween_property(modelo, "rotation:z", -0.35, 0.09)
		tween.tween_property(modelo, "rotation:z", 0.0, 0.09)
		tween.tween_callback(Efeitos.terra.bind(get_parent(), centro + Vector3.DOWN * 0.3))
	await tween.finished
	ao_terminar.call()
	Efeitos.terra(get_parent(), centro)
	_cavando = false


## Late: objetos até ALCANCE_LATIDO ouvem (pássaros voam). Devolve "" ou o motivo de não ter
## latido ("sem_habilidade", "boca_cheia", "ocupado").
func latir() -> String:
	if not pode_latir:
		return "sem_habilidade"
	if tem_graveto:
		return "boca_cheia"
	if _espera_latido > 0.0:
		return "ocupado"
	_espera_latido = 0.6
	Efeitos.latido(get_parent(), boca.global_position)
	Som.latido(get_parent(), boca.global_position, Som.tom_da_raca(raca))
	var tween := create_tween()
	tween.tween_property(modelo, "rotation:z", 0.25, 0.08)
	tween.tween_property(modelo, "rotation:z", 0.0, 0.15)
	if fase:
		fase.espalhar_latido(global_position, self)
	return ""


## Objeto com ação do botão F (`ObjetoFase.acao_da_boca`) à frente do focinho: o mais perto
## até 1,2 m, dentro de ~60° da direção em que o cachorro olha. Null se não houver.
func objeto_da_acao() -> ObjetoFase:
	if fase == null or entrada_bloqueada:
		return null
	var frente := Vector3(cos(modelo.rotation.y), 0.0, -sin(modelo.rotation.y))
	var melhor: ObjetoFase = null
	var melhor_distancia := 1.2
	for no in get_tree().get_nodes_in_group(&"com_acao"):
		var objeto := no as ObjetoFase
		if objeto == null or not objeto.visible or objeto.acao_da_boca(self).is_empty():
			continue
		var ate := objeto.ponto_da_acao(self) - global_position
		ate.y = 0.0
		var distancia := ate.length()
		if distancia < melhor_distancia and (distancia < 0.3 or ate.normalized().dot(frente) > 0.5):
			melhor = objeto
			melhor_distancia = distancia
	return melhor


## Bloco empurrável logo à frente do focinho (ou null).
func _bloco_na_frente() -> Empurravel:
	var frente := Vector3(cos(modelo.rotation.y), 0.0, -sin(modelo.rotation.y))
	var origem := global_position + Vector3.UP * 0.3
	var raio := PhysicsRayQueryParameters3D.create(origem, origem + frente * 1.0, 4, [get_rid()])
	var achado := get_world_3d().direct_space_state.intersect_ray(raio)
	if achado.is_empty():
		return null
	return (achado.collider as Node).get_parent() as Empurravel


## Segurando `puxar` de frente para um bloco e andando para trás: o bloco vem uma célula e
## o cachorro recua junto. Sem graveto (a boca é que segura). Devolve o motivo se não deu.
func _tentar_puxar(horizontal: Vector3) -> String:
	if horizontal.length_squared() < 0.1:
		return ""
	var frente := Vector3(cos(modelo.rotation.y), 0.0, -sin(modelo.rotation.y))
	if horizontal.normalized().dot(frente) > -0.7:
		return ""
	var bloco := _bloco_na_frente()
	if bloco == null:
		return ""
	if tem_graveto:
		return "boca_cheia"
	# Direção da grade mais próxima de "para trás".
	var passo := Vector3i(-int(signf(frente.x)), 0, 0) if absf(frente.x) >= absf(frente.z) \
		else Vector3i(0, 0, -int(signf(frente.z)))
	var recuo := Vector3(passo)
	# O cachorro precisa de espaço e chão firme para recuar uma célula.
	if test_move(global_transform, recuo):
		return "sem_espaco"
	var chao := fase.tile_em(global_position + recuo + Vector3.DOWN * 0.3) if fase else -1
	if chao == GridMap.INVALID_CELL_ITEM or Tiles.eh_agua(chao):
		return "sem_espaco"
	if not bloco.pode_mover(passo, true):
		return "sem_espaco"
	bloco.puxar(passo)
	_sentido_puxar = recuo
	_tempo_puxando = DURACAO_PUXAR
	return ""


## Andar contra um objeto empurrável (bloco, tronco — quem tem `empurrar(direcao)`) por um
## instante empurra ele uma célula. O graveto na boca também empurra; ao comprido, a ponta vai
## longe à frente — alcance maior (dá para empurrar algo do outro lado de um vão).
func _empurrar(delta: float, horizontal: Vector3) -> void:
	var alvo: Node = null
	if horizontal.length_squared() > 0.1:
		var direcao := horizontal.normalized()
		for i in get_slide_collision_count():
			var colisao := get_slide_collision(i)
			var corpo := colisao.get_collider() as Node
			var empurravel := corpo.get_parent() if corpo else null
			if empurravel == null or not empurravel.has_method(&"empurrar"):
				continue
			if colisao.get_normal().dot(direcao) < -0.6:
				alvo = empurravel
	if alvo != _empurrando:
		_empurrando = alvo
		_tempo_empurrando = 0.0
	if alvo == null:
		return
	_tempo_empurrando += delta
	if _tempo_empurrando > 0.25:
		_tempo_empurrando = 0.0
		# Direção da grade mais próxima da direção em que o cachorro anda.
		var passo := Vector3i(int(signf(horizontal.x)), 0, 0) if absf(horizontal.x) >= absf(horizontal.z) \
			else Vector3i(0, 0, int(signf(horizontal.z)))
		alvo.empurrar(passo)


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
	if raca:
		fator *= raca.fator_velocidade
	if Input.is_action_pressed("andar_devagar"):
		fator *= fator_devagar
	return direcao * velocidade * fator


func _girar_modelo(delta: float) -> void:
	# Puxando, o cachorro não vira: fica de frente para o bloco e anda de ré.
	if _tempo_puxando > 0.0:
		return
	var alvo := _yaw_alvo
	# Segurando F com um bloco à frente: agarra — vira de frente para ele, alinhado à grade (dá
	# para chegar meio de lado), e fica assim enquanto segurar, andando de ré para puxar.
	if Input.is_action_pressed("acao") and not tem_graveto:
		var bloco := _bloco_na_frente()
		if bloco:
			var para_o_bloco := bloco.global_position - global_position
			alvo = snappedf(atan2(-para_o_bloco.z, para_o_bloco.x), PI * 0.5)
	# O modelo olha para +X quando rotation.y == 0.
	var novo := lerp_angle(modelo.rotation.y, alvo, 1.0 - exp(-velocidade_giro * delta))
	if is_equal_approx(novo, modelo.rotation.y):
		return
	# Com o graveto na boca, só gira se o graveto não bater em nada no caminho.
	if tem_graveto and not _graveto_cabe(novo, graveto_ao_comprido):
		return
	modelo.rotation.y = novo
	if tem_graveto:
		_atualizar_colisao_graveto()


# --- Graveto -----------------------------------------------------------------------------

## Posição do graveto em relação à boca: atravessado (centrado) ou ao comprido
## (apontando para a frente, quase inteiro fora do focinho).
func _transform_visual_graveto(ao_comprido: bool) -> Transform3D:
	if not ao_comprido:
		return Transform3D.IDENTITY
	var comprimento := graveto.comprimento if graveto else 0.8
	return Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(comprimento * 0.5 - 0.1, 0.0, 0.0))


## Transform da forma de colisão do graveto (no espaço do corpo) para um giro do modelo.
func _transform_colisao_graveto(yaw: float, ao_comprido: bool) -> Transform3D:
	var no_modelo := Transform3D(Basis.IDENTITY, boca.position) * _transform_visual_graveto(ao_comprido)
	# A cápsula é vertical (eixo Y); o graveto fica deitado ao longo do Z da cena dele.
	no_modelo.basis = no_modelo.basis * Basis(Vector3.RIGHT, PI * 0.5)
	return Transform3D(Basis(Vector3.UP, yaw), Vector3.ZERO) * no_modelo


func _atualizar_colisao_graveto() -> void:
	colisao_graveto.transform = _transform_colisao_graveto(modelo.rotation.y, graveto_ao_comprido)


## O graveto cabe com este giro (e deslocando o cachorro, se pedido)?
func _graveto_cabe(yaw: float, ao_comprido: bool, deslocamento := Vector3.ZERO) -> bool:
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = _forma_teste
	consulta.transform = Transform3D(Basis.IDENTITY, global_position + deslocamento) \
		* _transform_colisao_graveto(yaw, ao_comprido)
	consulta.collision_mask = collision_mask
	consulta.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(consulta, 1).is_empty()


func _graveto_bate_em_empurravel(yaw: float, deslocamento: Vector3) -> bool:
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = _forma_teste
	consulta.transform = Transform3D(Basis.IDENTITY, global_position + deslocamento) \
		* _transform_colisao_graveto(yaw, graveto_ao_comprido)
	consulta.collision_mask = collision_mask
	consulta.exclude = [get_rid()]
	for achado in get_world_3d().direct_space_state.intersect_shape(consulta, 4):
		var dono := (achado.collider as Node).get_parent()
		if dono and dono.has_method(&"empurrar"):
			return true
	return false


## Correção de quina: se é o graveto que bate na entrada de um vão, mas ele passaria um
## pouco mais para o lado, desliza o cachorro para lá (como os jogos de plataforma fazem
## nas quinas). Sem isso, passar com o graveto atravessado exigiria mira de milímetros.
func _desvio_de_encaixe(horizontal: Vector3, delta: float) -> Vector3:
	if not tem_graveto or horizontal.length_squared() < 0.01:
		graveto_travado = false
		return Vector3.ZERO
	var direcao := horizontal.normalized()
	var passo := direcao * 0.08
	var yaw := modelo.rotation.y
	# Só quando quem bate é o graveto (o corpo passaria).
	graveto_travado = false
	if _graveto_cabe(yaw, graveto_ao_comprido, passo):
		return Vector3.ZERO
	# Ao comprido, contra algo empurrável (bloco, tronco), a ponta empurra: nada de desviar.
	if graveto_ao_comprido and _graveto_bate_em_empurravel(yaw, passo):
		return Vector3.ZERO
	var lado := Vector3(-direcao.z, 0.0, direcao.x)
	for i in range(1, 9):
		var distancia := i * 0.05
		for sentido: float in [1.0, -1.0]:
			var desvio := lado * distancia * sentido
			if not test_move(global_transform, desvio) \
					and _graveto_cabe(yaw, graveto_ao_comprido, desvio + passo):
				return lado * sentido * minf(horizontal.length(), distancia / delta)
	graveto_travado = true
	return Vector3.ZERO


# --- Equilíbrio --------------------------------------------------------------------------

## Em passagens estreitas, um graveto grande e pesado faz o cachorro balançar de um lado
## para o outro; o balanço cresce com a velocidade. O jogador compensa andando devagar,
## virando o graveto ao comprido e corrigindo para o lado contrário.
## Com o centro do corpo fora da tábua, o cachorro escorrega (com ou sem graveto).
func _empurrao_do_balanco(delta: float, horizontal: Vector3) -> Vector3:
	var passagem := fase.passagem_estreita_em(global_position + Vector3.UP * 0.2) if fase else {}
	em_passagem_estreita = not passagem.is_empty()

	# Centro do corpo fora da tábua: escorrega e, logo depois, cai (a física deixaria a
	# cápsula "montada" na aresta).
	var empurrao := Vector3.ZERO
	if em_passagem_estreita and absf(passagem.desvio) > passagem.meia_largura + 0.06:
		empurrao = passagem.lado * signf(passagem.desvio) * 2.5
		_tempo_fora_da_passagem += delta
		if _tempo_fora_da_passagem > 0.2:
			_tempo_fora_da_passagem = 0.0
			var embaixo := fase.tile_em(global_position + Vector3.DOWN * 0.6)
			_voltar_ao_ponto_seguro.call_deferred("agua" if Tiles.eh_agua(embaixo) else "queda")
	else:
		_tempo_fora_da_passagem = 0.0

	if not em_passagem_estreita:
		balanco = move_toward(balanco, 0.0, delta * 2.0)
		modelo.rotation.x = balanco * 0.4
		return Vector3.ZERO

	var carga := graveto.peso_atual() * graveto.comprimento if tem_graveto and graveto else 0.0
	var excesso := maxf(carga - carga_sem_balanco, 0.0)
	if excesso <= 0.0 or not is_on_floor():
		balanco = move_toward(balanco, 0.0, delta * 2.0)
		modelo.rotation.x = balanco * 0.4
		return empurrao

	# Rápido balança muito mais que devagar (cresce com o quadrado da velocidade).
	var ritmo := clampf(horizontal.length() / velocidade, 0.0, 1.0)
	_fase_balanco += delta * (2.5 + 1.0 * ritmo)
	var amplitude := clampf(excesso * 0.5, 0.0, 1.0) * (0.08 + 0.92 * ritmo * ritmo)
	amplitude *= 0.75 + 0.25 * sin(_fase_balanco * 0.37)
	if graveto_ao_comprido:
		amplitude *= fator_ao_comprido
	balanco = lerpf(balanco, sin(_fase_balanco) * amplitude, 1.0 - exp(-6.0 * delta))
	modelo.rotation.x = balanco * 0.4
	# Empurra para o lado do corpo (eixo Z do modelo).
	var lado := modelo.global_basis.z
	lado.y = 0.0
	return empurrao + lado.normalized() * balanco * forca_balanco


## O graveto tem colisão própria: numa beirada na altura da boca (pulando contra um degrau alto),
## ele poderia "segurar" o cachorro no ar, pendurado. Apoiado só pelo graveto, o cachorro
## escorrega para trás, para longe da beirada, e cai.
func _soltar_se_pendurado() -> void:
	if not tem_graveto or not is_on_floor():
		return
	var pelo_graveto := Vector3.ZERO
	for i in get_slide_collision_count():
		var colisao := get_slide_collision(i)
		if colisao.get_normal().y <= 0.7:
			continue
		if colisao.get_local_shape() != colisao_graveto:
			return
		pelo_graveto = colisao.get_position()
	if pelo_graveto == Vector3.ZERO:
		return
	var para_longe := global_position - pelo_graveto
	para_longe.y = 0.0
	global_position += para_longe.normalized() * 0.06
	velocity.y = minf(velocity.y, -1.0)


# --- Buraco e rampa lisa ---

## Dentro de um buraco (meio metro), andando contra a borda: o cachorro escala para fora com
## um impulso (sem precisar da habilidade de pular).
func _escalar_do_buraco(horizontal: Vector3) -> void:
	if fase == null or not is_on_floor() or not is_on_wall() or horizontal.length_squared() < 0.1:
		return
	if not Tiles.eh_buraco(fase.tile_em(global_position + Vector3.DOWN * 0.1)):
		return
	if get_wall_normal().dot(horizontal.normalized()) < -0.5:
		velocity.y = sqrt(2.0 * _gravidade * 0.62)


## Rampa lisa: com graveto pesado (1,5 ou mais) na boca o cachorro não firma as patas — não
## sobe e ainda escorrega para baixo.
func _rampa_lisa(horizontal: Vector3) -> Vector3:
	if fase == null or not is_on_floor() or not (tem_graveto and graveto and graveto.peso_atual() >= 1.5):
		return horizontal
	if not Tiles.eh_escorregadia(fase.tile_em(global_position + Vector3.DOWN * 0.1)):
		return horizontal
	var descida := get_floor_normal()
	descida.y = 0.0
	if descida.length() < 0.05:
		return horizontal
	descida = descida.normalized()
	var subindo := minf(horizontal.dot(descida), 0.0)
	return horizontal - descida * subindo + descida * 2.2


# --- Água rasa e correnteza ---

## Água rasa deixa o cachorro mais lento; correnteza arrasta no sentido do tile. Graveto
## pesado na boca deixa o cachorro mais firme contra a correnteza. Devolve o arrasto (m/s).
func _efeito_da_agua() -> Vector3:
	_lentidao_agua = 1.0
	em_correnteza = false
	if fase == null or not is_on_floor():
		return Vector3.ZERO
	var terreno := fase.terreno
	var celula := terreno.local_to_map(terreno.to_local(global_position + Vector3.DOWN * 0.05))
	var definicao := Tiles.definicao(terreno.get_cell_item(celula))
	if not definicao.get("rasa", false):
		return Vector3.ZERO
	_lentidao_agua = definicao.get("lentidao", 1.0)
	# O graveto na boca encharca na água rasa (pesa mais por um tempo).
	if tem_graveto and graveto:
		graveto.molhar()
	var forca: float = definicao.get("correnteza", 0.0)
	if forca <= 0.0:
		return Vector3.ZERO
	em_correnteza = true
	var sentido := terreno.global_basis * terreno.get_cell_item_basis(celula).x
	sentido.y = 0.0
	var firmeza := maxf(graveto.peso_atual(), 1.0) if tem_graveto and graveto else 1.0
	return sentido.normalized() * forca / firmeza


# --- Quedas ------------------------------------------------------------------------------

func _checar_queda(delta: float) -> void:
	if fase and (fase.dentro_da_agua(global_position) or _na_beira_da_agua()):
		_voltar_ao_ponto_seguro("agua")
	elif global_position.y < -10.0:
		_voltar_ao_ponto_seguro("queda")
	elif is_on_floor() and not em_passagem_estreita and not em_correnteza:
		_tempo_ponto_seguro += delta
		if _tempo_ponto_seguro >= 0.25:
			_guardar_ponto_seguro()


## O centro do corpo já está sobre água funda, sem nada embaixo, mas a cápsula ainda se
## apoia na beirada (a física deixaria o cachorro "montado" na aresta).
func _na_beira_da_agua() -> bool:
	# A correnteza leva o cachorro até a beira da água funda: com o centro já sobre ela e apoiado
	# só no leito da água rasa, ele cai. Na beira de chão firme (ou de um objeto) nada muda.
	if not is_on_floor() or not Tiles.eh_agua(fase.tile_em(global_position + Vector3.DOWN * 0.1)):
		return false
	var apoios := 0
	for i in get_slide_collision_count():
		var colisao := get_slide_collision(i)
		if colisao.get_normal().y <= 0.7:
			continue
		if colisao.get_collider() != fase.terreno:
			return false
		var tile := fase.tile_em(colisao.get_position() + Vector3.DOWN * 0.05)
		if not Tiles.definicao(tile).get("rasa", false):
			return false
		apoios += 1
	return apoios > 0


func _guardar_ponto_seguro() -> void:
	_tempo_ponto_seguro = 0.0
	_pontos_seguros.append(global_position)
	if _pontos_seguros.size() > 4:
		_pontos_seguros.pop_front()


func _voltar_ao_ponto_seguro(motivo: String) -> void:
	global_position = _pontos_seguros[0] + Vector3.UP * 0.2
	velocity = Vector3.ZERO
	balanco = 0.0
	var ponto := _pontos_seguros[0]
	_pontos_seguros.clear()
	_pontos_seguros.append(ponto)
	voltou_ao_ponto_seguro.emit(motivo)

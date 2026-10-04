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
## Não pulou ("agua": água funda logo à frente — o salsicha não pula na água).
signal pulo_recusado(motivo: String)
## Gelou (fase com frio, calor chegou a zero) e voltou para perto do último fogo.
signal gelou

## Até onde o latido chega (m).
const ALCANCE_LATIDO := 5.0
## Maior giro do modelo num quadro (rad) e de quanto em quanto o caminho do graveto é conferido.
const GIRO_MAXIMO := 0.5
const PASSO_CONFERIR_GIRO := 0.15
## Só vira pelo lado mais longo (quando o curto bate) se falta girar ao menos isto (rad); abaixo
## disso também não conta como "giro travado".
const GIRO_MINIMO_OUTRO_LADO := PI * 0.5

@export var velocidade := 3.5
## Velocidade com que o modelo gira para a direção do movimento.
@export var velocidade_giro := 10.0
## Multiplicador da velocidade segurando `andar_devagar`.
@export var fator_devagar := 0.4
## Multiplicador da velocidade segurando `correr`.
@export var fator_corrida := 1.7
## Altura do pulo (m) sem graveto. Passa de meio bloco (0,5 m), não de um bloco inteiro.
@export var altura_pulo := 0.65
## Velocidade horizontal máxima no ar depois de um pulo (m/s): o salsicha pula para subir, não
## para saltar longe (nem correndo).
@export var velocidade_no_pulo := 1.4

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
## Brincadeiras da área central do parque: rolar na grama (`rolar`), se sacudir e deitar quando
## fica parado um tempo.
var pode_brincar := false
## Brinquedo na boca (a bolinha do parque): não é graveto, não tem colisão nem troca a câmera.
var brinquedo: Node3D
## No ar depois de um pulo (a velocidade horizontal fica limitada; ver velocidade_no_pulo).
var pulando := false
## Balanço atual, de -1 a 1 (para o HUD). Só muda em passagens estreitas.
var balanco := 0.0
var em_passagem_estreita := false
## O graveto está impedindo o cachorro de andar (e não há encaixe para o lado).
var graveto_travado := false
## O graveto bate nos dois sentidos de giro e o cachorro não consegue virar para onde anda.
var giro_travado := false

var _gravidade: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _yaw_alvo := 0.0
## Girando pelo lado mais longo (o curto bateu com o graveto): +1 ou -1; 0 = pelo mais curto.
var _sentido_giro_longo := 0.0
## Últimas posições em chão firme (a mais antiga é usada ao voltar, para não
## reaparecer bem na beirada de onde caiu).
var _pontos_seguros: Array[Vector3] = []
var _tempo_ponto_seguro := 0.0
## Andou por cima de uma ponte ou objeto desde o último ponto seguro: ao pisar de novo no
## terreno, os pontos antigos (talvez da outra margem) são descartados.
var _saiu_do_terreno := false
## O único ponto seguro é o da beirada, de quando voltou ao terreno: vale só até guardar o próximo.
var _ponto_provisorio := false
var _fase_balanco := 0.0
var _tempo_fora_da_passagem := 0.0
## Forma um pouco menor que a do graveto, para testar giros sem contar o simples encostar.
var _forma_teste := CapsuleShape3D.new()
var _tween_graveto: Tween
var _cavando := false
## Rolando ou se sacudindo: fica parado enquanto isso.
var _brincando := false
## Segundos parado (com `pode_brincar`): passou de TEMPO_PARA_DEITAR, deita.
var _tempo_parado := 0.0
const TEMPO_PARA_DEITAR := 6.0
var _espera_latido := 0.0
var _empurrando: Node
## Pelo chão embaixo (água rasa, neve fofa): multiplicador da velocidade e se há correnteza.
var _lentidao_piso := 1.0
var em_correnteza := false
var _na_agua_rasa := false
## Aderência do chão (Tiles: `aderencia`): abaixo de 1 o cachorro demora a arrancar e a parar
## (neve fofa) ou desliza (gelo). `_embalo` é a velocidade que ele carrega.
var _aderencia := 1.0
var _embalo := Vector3.ZERO
## Aceleração (m/s²) com aderência 1; a do chão é esta vezes a aderência dele.
const ACELERACAO_MAXIMA := 30.0

## Gelo liso: direção em que o cachorro está deslizando (±X ou ±Z; zero = parado/andando).
var deslizando := Vector3.ZERO
var _no_gelo_liso := false
const VELOCIDADE_DESLIZE := 5.0

## Fase com frio (Fase.frio): o calor cai longe do fogo. O jogo liga isto.
var sente_frio := false
## Segundos, bem aquecido, até gelar (Fase.tempo_de_frio).
var tempo_de_frio := 60.0
## Calor do cachorro, de 0 (gelado) a 1 (quentinho). Com pouco calor ele fica lento e treme.
var calor := 1.0
## Está sendo aquecido agora (perto de uma fogueira acesa, dentro do celeiro).
var aquecendo := false
## Onde volta ao gelar: o último lugar em que esteve aquecido (ou o começo da fase).
var _ponto_quente := Vector3.ZERO
var _tremor := 0.0
## Puxando um bloco: o cachorro recua uma célula junto com ele.
const DURACAO_PUXAR := 0.35
var _tempo_puxando := 0.0
## Quanto dura o movimento puxando (ou girando o tronco): o cachorro anda `_sentido_puxar` nesse tempo.
var _duracao_puxando := DURACAO_PUXAR
## Motivo já avisado neste aperto de F (para não repetir o aviso a cada quadro).
var _motivo_puxar_avisado := ""
var _sentido_puxar := Vector3.ZERO
## Girando um tronco pela ponta: o cachorro acompanha a ponta pelo arco (em vez de `_sentido_puxar`).
var _tronco_girando: TroncoRolante
var _ponta_girando := -1
var _tempo_empurrando := 0.0
## Atravessando uma passagem (toca, portinhola): quem conduz é `atravessar`; a física fica parada.
var atravessando := false
## Pendurado pelo graveto numa beirada: o cachorro escorrega nesta direção (sem o jogador
## controlar) até o graveto sair da quina e ele cair.
var _escorregando := Vector3.ZERO
var _tempo_escorregando := 0.0
const DURACAO_ESCORREGAR := 0.3
const VELOCIDADE_ESCORREGAR := 1.5
## Forma para testar se o corpo tem chão embaixo (a cápsula dele, um pouco mais fina).
var _forma_corpo_teste := CapsuleShape3D.new()

@onready var modelo: Node3D = $Modelo
@onready var boca: Marker3D = $Modelo/Boca
@onready var voxel: ModeloCachorro = $Modelo/Voxel
## Raça atual (formato, pelagem, velocidade). Ver assets/racas/.
var raca: Raca
@onready var colisao_graveto: CollisionShape3D = $ColisaoGraveto


func _ready() -> void:
	colisao_graveto.disabled = true
	var forma := ($Colisao as CollisionShape3D).shape as CapsuleShape3D
	_forma_corpo_teste.radius = maxf(forma.radius - 0.03, 0.02)
	_forma_corpo_teste.height = forma.height
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
	_forma_corpo_teste.radius = maxf(forma.radius - 0.03, 0.02)
	_forma_corpo_teste.height = forma.height


## Coloca o cachorro numa posição, olhando para `yaw` (radianos; 0 = +X).
func posicionar(posicao: Vector3, yaw: float) -> void:
	global_position = posicao
	velocity = Vector3.ZERO
	_embalo = Vector3.ZERO
	_ponto_quente = posicao
	_yaw_alvo = yaw
	modelo.rotation.y = yaw
	_pontos_seguros.clear()
	_guardar_ponto_seguro()


func _physics_process(delta: float) -> void:
	if atravessando:
		velocity = Vector3.ZERO
		return
	if not is_on_floor():
		velocity.y -= _gravidade * delta
	else:
		pulando = false
		if pode_pular and not entrada_bloqueada and Input.is_action_just_pressed("pular"):
			if _agua_funda_na_frente():
				pulo_recusado.emit("agua")
			else:
				velocity.y = sqrt(2.0 * _gravidade * altura_pulo_atual())
				pulando = true

	_espera_latido = maxf(_espera_latido - delta, 0.0)
	var horizontal := Vector3.ZERO if entrada_bloqueada or _cavando or _brincando else _velocidade_entrada()
	if _tempo_puxando > 0.0:
		_tempo_puxando -= delta
		horizontal = _sentido_puxar / _duracao_puxando
		if _tronco_girando:
			var ate := _tronco_girando.onde_segurar(_ponta_girando) - global_position
			ate.y = 0.0
			horizontal = (ate / delta).limit_length(velocidade * 2.0)
			if _tempo_puxando <= 0.0:
				_tronco_girando = null
	elif _tempo_escorregando > 0.0:
		_tempo_escorregando -= delta
		horizontal = _escorregando
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
	var arrasto := _efeito_do_piso()
	# Parado à força (câmera em transição, mirante, fase concluída): a água não leva o cachorro
	# embora sem ele poder reagir.
	if entrada_bloqueada:
		arrasto = Vector3.ZERO
	var vento := _efeito_do_vento()
	horizontal *= _lentidao_piso * _fator_do_frio()
	horizontal = _com_aderencia(horizontal, delta)
	horizontal = _deslizar_no_gelo(horizontal, vento)
	if pulando:
		horizontal = horizontal.limit_length(velocidade_no_pulo)
	# Deslizando no gelo liso o vento não tira o cachorro da linha.
	if deslizando == Vector3.ZERO:
		arrasto += vento
	velocity.x = horizontal.x + arrasto.x
	velocity.z = horizontal.z + arrasto.z

	move_and_slide()
	# Bateu em algo (ou foi parado): o deslize termina.
	if deslizando != Vector3.ZERO and is_on_floor() \
			and get_real_velocity().dot(deslizando) < VELOCIDADE_DESLIZE * 0.3:
		deslizando = Vector3.ZERO
		_embalo = Vector3.ZERO
	if is_on_wall():
		# Deslizando contra uma parede, o embalo não continua empurrando para dentro dela.
		var parede := get_wall_normal()
		parede.y = 0.0
		if parede.length() > 0.1 and _embalo.dot(parede) < 0.0:
			_embalo = _embalo.slide(parede.normalized())
	_atualizar_calor(delta)
	_soltar_se_pendurado()
	_escalar_do_buraco(horizontal)
	voxel.velocidade = Vector2(get_real_velocity().x, get_real_velocity().z).length()
	voxel.no_chao = is_on_floor()
	_descansar(delta, horizontal)
	_empurrar(delta, horizontal)
	_girar_modelo(delta)
	_checar_queda(delta)


## Segurando `correr` (e andando): o cachorro corre.
func correndo() -> bool:
	return not entrada_bloqueada and Input.is_action_pressed("correr") \
		and not Input.is_action_pressed("andar_devagar")


## Altura do pulo agora: o peso do graveto puxa para baixo.
## Com graveto na boca o pulo é um pouco mais baixo (não passa do Degrau alto); graveto pesado,
## mais baixo ainda.
func altura_pulo_atual() -> float:
	if tem_graveto and graveto:
		return altura_pulo * 0.88 / (1.0 + maxf(graveto.peso - 1.0, 0.0) * 0.35)
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


# --- Brinquedos e brincadeiras (área central do parque) -----------------------------------

## Algo na boca (graveto ou brinquedo): não pega outra coisa nem late.
func boca_ocupada() -> bool:
	return tem_graveto or brinquedo != null


## Põe o brinquedo na boca (ele vira filho da boca; a origem do brinquedo é o ponto de baixo).
func pegar_brinquedo(novo: Node3D) -> void:
	brinquedo = novo
	novo.reparent(boca, false)
	novo.position = Vector3(0.06, -0.1, 0.0)
	_tempo_parado = 0.0


## Tira o brinquedo da boca e devolve (quem chamou decide onde ele vai parar).
func largar_brinquedo() -> Node3D:
	var solto := brinquedo
	brinquedo = null
	if solto and fase:
		solto.reparent(fase.objetos)
	return solto


## Rola na grama (de costas, de um lado para o outro) e se sacode no fim. Só parado no chão, com a
## boca vazia; falso se não deu.
func rolar() -> bool:
	if not pode_brincar or _brincando or _cavando or entrada_bloqueada or atravessando \
			or boca_ocupada() or not is_on_floor():
		return false
	_brincando = true
	voxel.deitado = 1.0
	var tween := create_tween()
	tween.tween_interval(0.15)
	tween.tween_property(voxel, "giro", TAU, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(voxel, "giro", TAU + 0.6, 0.18)
	tween.tween_property(voxel, "giro", TAU, 0.18)
	await tween.finished
	voxel.giro = 0.0
	voxel.deitado = 0.0
	await sacudir()
	return true


## Se sacode (depois de rolar, de sair da água): o corpo chacoalha e voa um pouco de sujeira.
func sacudir() -> void:
	_brincando = true
	voxel.sacudida = 1.0
	Efeitos.terra(get_parent(), global_position + Vector3.UP * 0.35)
	var tween := create_tween()
	tween.tween_property(voxel, "sacudida", 0.0, 0.7).set_ease(Tween.EASE_IN)
	await tween.finished
	_brincando = false
	_tempo_parado = 0.0


## Parado um tempo (sem ser mandado andar, no chão, com a boca vazia), o cachorro deita; ao andar,
## levanta.
func _descansar(delta: float, horizontal: Vector3) -> void:
	if not pode_brincar or _brincando:
		return
	var parado := horizontal.length() < 0.05 and is_on_floor() and not entrada_bloqueada \
		and not atravessando and not boca_ocupada()
	_tempo_parado = _tempo_parado + delta if parado else 0.0
	voxel.deitado = move_toward(voxel.deitado, 1.0 if _tempo_parado > TEMPO_PARA_DEITAR else 0.0,
		delta * (1.5 if _tempo_parado > TEMPO_PARA_DEITAR else 5.0))


## Deitado (ou deitando) agora?
func deitado() -> bool:
	return voxel.deitado > 0.5


# --- Passagens ---------------------------------------------------------------------------

## Atravessa uma passagem (portinhola, toca) sozinho: segue os `pontos` em `duracao` segundos,
## sem colisão e sem o jogador controlar, olhando para `yaw` (radianos; 0 = +X). Com
## `esconder`, some no começo (entrou na toca). Aguarde com `await`.
func atravessar(pontos: PackedVector3Array, duracao: float, yaw: float, esconder := false) -> void:
	atravessando = true
	velocity = Vector3.ZERO
	_embalo = Vector3.ZERO
	($Colisao as CollisionShape3D).set_deferred("disabled", true)
	colisao_graveto.set_deferred("disabled", true)
	_yaw_alvo = yaw
	modelo.rotation.y = yaw
	var total := 0.0
	var anterior := global_position
	for ponto in pontos:
		total += anterior.distance_to(ponto)
		anterior = ponto
	voxel.velocidade = total / maxf(duracao, 0.01)
	voxel.no_chao = true
	var tween := create_tween()
	anterior = global_position
	for ponto in pontos:
		var parte := anterior.distance_to(ponto) / total if total > 0.001 else 1.0 / pontos.size()
		tween.tween_property(self, "global_position", ponto, duracao * parte)
		anterior = ponto
	if esconder:
		tween.parallel().tween_callback(hide).set_delay(duracao * 0.6)
	await tween.finished
	voxel.velocidade = 0.0


## Fim da travessia: colisão de volta e o novo lugar vira o ponto seguro.
func terminar_travessia() -> void:
	show()
	($Colisao as CollisionShape3D).disabled = false
	colisao_graveto.disabled = not tem_graveto
	if tem_graveto:
		_atualizar_colisao_graveto()
	velocity = Vector3.ZERO
	_embalo = Vector3.ZERO
	_pontos_seguros.clear()
	_guardar_ponto_seguro()
	atravessando = false


## Direção (no chão, normalizada) para onde o jogador está mandando andar, ou zero.
func direcao_desejada() -> Vector3:
	if entrada_bloqueada or atravessando or camera_referencia == null:
		return Vector3.ZERO
	var entrada := Input.get_vector("mover_esquerda", "mover_direita", "mover_frente", "mover_tras")
	if entrada == Vector2.ZERO:
		return Vector3.ZERO
	var frente := -camera_referencia.global_basis.z
	frente.y = 0.0
	var direita := camera_referencia.global_basis.x
	direita.y = 0.0
	return (direita.normalized() * entrada.x - frente.normalized() * entrada.y).normalized()


## O graveto da boca cabe numa passagem? `so_ao_comprido`: atravessado não entra;
## `comprimento_maximo` (m, 0 = qualquer). Sem graveto, cabe sempre.
func graveto_passa(so_ao_comprido: bool, comprimento_maximo: float) -> bool:
	if not tem_graveto or graveto == null:
		return true
	if so_ao_comprido and not graveto_ao_comprido:
		return false
	return comprimento_maximo <= 0.0 or graveto.comprimento <= comprimento_maximo + 0.001


## Quanto o graveto ao comprido passa da frente do corpo, com o cachorro olhando para `direcao`
## (no chão): a ponta bate antes na toca ou na portinhola, e elas contam a distância a partir
## dela. 0 sem graveto ao comprido ou olhando para outro lado.
func alcance_extra_do_graveto(direcao: Vector3) -> float:
	if not tem_graveto or graveto == null or not graveto_ao_comprido:
		return 0.0
	var frente := modelo.global_basis.x
	frente.y = 0.0
	direcao.y = 0.0
	if frente.normalized().dot(direcao.normalized()) < 0.7:
		return 0.0
	var raio := raca.raio_colisao if raca else 0.28
	return maxf(boca.position.x + graveto.comprimento - 0.1 - raio, 0.0)


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
	if boca_ocupada():
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
	if fase == null or entrada_bloqueada or atravessando:
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


## Tronco com uma ponta ao alcance da boca: [tronco, índice da ponta] ou [].
func _ponta_de_tronco_na_frente() -> Array:
	if fase == null:
		return []
	for tronco in fase.todos(TroncoRolante):
		var ponta := (tronco as TroncoRolante).ponta_perto(global_position)
		if ponta < 0:
			continue
		var ate := (tronco as TroncoRolante).ponto_da_ponta(ponta) - global_position
		ate.y = 0.0
		var frente := Vector3(cos(modelo.rotation.y), 0.0, -sin(modelo.rotation.y))
		if ate.length() < 1.25 and ate.normalized().dot(frente) > 0.6:
			return [tronco, ponta]
	return []


## Mordendo a ponta de um tronco (segurando F de frente para ela): andar para o lado gira o
## tronco 90° em volta da outra ponta (o cachorro vai junto, segurando a ponta); andar para trás
## puxa o tronco ao comprido. Devolve o motivo se não deu ("" = deu ou nada a fazer).
func _morder_tronco(horizontal: Vector3, mordido: Array) -> String:
	var tronco: TroncoRolante = mordido[0]
	if tronco.em_movimento:
		return ""
	if tem_graveto:
		return "boca_cheia"
	var frente := Vector3(cos(modelo.rotation.y), 0.0, -sin(modelo.rotation.y))
	var direcao := horizontal.normalized()
	var para_o_tronco := _na_grade(frente)
	if direcao.dot(frente) < -0.7:
		var recuo := -para_o_tronco
		if test_move(global_transform, Vector3(recuo)):
			return "sem_espaco"
		var chao := fase.tile_em(global_position + Vector3(recuo) + Vector3.DOWN * 0.3)
		if chao == GridMap.INVALID_CELL_ITEM or Tiles.eh_agua(chao):
			return "sem_espaco"
		if not tronco.pode_puxar(recuo):
			return "sem_espaco"
		tronco.puxar(recuo)
		_sentido_puxar = Vector3(recuo)
		_tempo_puxando = DURACAO_PUXAR
		_duracao_puxando = DURACAO_PUXAR
		return ""
	if absf(direcao.dot(frente)) < 0.5:
		var destino: Variant = tronco.girar(mordido[1], _na_grade(direcao))
		if destino == null:
			return "sem_espaco_girar"
		_tronco_girando = tronco
		_ponta_girando = mordido[1]
		_tempo_puxando = TroncoRolante.DURACAO * 1.3 + 0.1
		_duracao_puxando = _tempo_puxando
		return ""
	return ""


## A direção da grade (±X ou ±Z) mais próxima de `v`.
static func _na_grade(v: Vector3) -> Vector3i:
	return Vector3i(int(signf(v.x)), 0, 0) if absf(v.x) >= absf(v.z) else Vector3i(0, 0, int(signf(v.z)))


## Segurando `puxar` de frente para um bloco e andando para trás: o bloco vem uma célula e
## o cachorro recua junto. Sem graveto (a boca é que segura). Devolve o motivo se não deu.
## De frente para a ponta de um tronco, morde o tronco (ver _morder_tronco).
func _tentar_puxar(horizontal: Vector3) -> String:
	if horizontal.length_squared() < 0.1:
		return ""
	var mordido := _ponta_de_tronco_na_frente()
	if not mordido.is_empty():
		return _morder_tronco(horizontal, mordido)
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
	_duracao_puxando = DURACAO_PUXAR
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
	if Input.is_action_pressed("andar_devagar"):
		fator *= fator_devagar
	elif correndo():
		fator *= fator_corrida
	return direcao * velocidade * fator


func _girar_modelo(delta: float) -> void:
	# Girando um tronco: continua de frente para a ponta que segura.
	if _tronco_girando:
		var para_a_ponta := _tronco_girando.ponto_da_ponta_agora(_ponta_girando) - global_position
		modelo.rotation.y = atan2(-para_a_ponta.z, para_a_ponta.x)
		return
	# Puxando, o cachorro não vira: fica de frente para o bloco e anda de ré.
	if _tempo_puxando > 0.0:
		return
	var alvo := _yaw_alvo
	# Segurando F com um bloco à frente: agarra — vira de frente para ele, alinhado à grade (dá
	# para chegar meio de lado), e fica assim enquanto segurar, andando de ré para puxar.
	if Input.is_action_pressed("acao") and not tem_graveto:
		var bloco := _bloco_na_frente()
		var mordido := _ponta_de_tronco_na_frente()
		if not mordido.is_empty():
			var para_a_ponta: Vector3 = (mordido[0] as TroncoRolante).ponto_da_ponta(mordido[1]) - global_position
			alvo = snappedf(atan2(-para_a_ponta.z, para_a_ponta.x), PI * 0.5)
		elif bloco:
			var para_o_bloco := bloco.global_position - global_position
			alvo = snappedf(atan2(-para_o_bloco.z, para_o_bloco.x), PI * 0.5)
	# O modelo olha para +X quando rotation.y == 0.
	var atual := modelo.rotation.y
	var curto := wrapf(alvo - atual, -PI, PI)
	# Já passou da metade pelo lado longo (daqui em diante ele é o curto) ou largou o graveto.
	if _sentido_giro_longo != 0.0 and (signf(curto) == _sentido_giro_longo or absf(curto) < 0.01
			or not tem_graveto):
		_sentido_giro_longo = 0.0
	var peso := 1.0 - exp(-velocidade_giro * delta)
	var diferenca := curto if _sentido_giro_longo == 0.0 else curto - signf(curto) * TAU
	var passo := clampf(diferenca * peso, -GIRO_MAXIMO, GIRO_MAXIMO)
	if is_zero_approx(snappedf(passo, 0.0001)):
		giro_travado = false
		return
	# Com o graveto na boca, só gira se o graveto não bater em nada no caminho. Se o giro mais
	# curto bate (ex.: o graveto encostado numa cerca) e é uma meia-volta, tenta pelo outro lado;
	# num giro pequeno, dar a volta inteira seria estranho.
	if tem_graveto and not _giro_cabe(atual, passo):
		var outro := clampf((diferenca - signf(diferenca) * TAU) * peso, -GIRO_MAXIMO, GIRO_MAXIMO)
		if (_sentido_giro_longo == 0.0 and absf(curto) < GIRO_MINIMO_OUTRO_LADO) \
				or not _giro_cabe(atual, outro):
			# Não deu: conta como travado se ele fica de lado ou de costas para onde anda.
			giro_travado = absf(curto) >= GIRO_MINIMO_OUTRO_LADO
			return
		passo = outro
		_sentido_giro_longo = 0.0 if _sentido_giro_longo != 0.0 else signf(outro)
	giro_travado = false
	modelo.rotation.y = wrapf(atual + passo, -PI, PI)
	if tem_graveto:
		_atualizar_colisao_graveto()


## O graveto cabe em todo o caminho do giro de `de` até `de + passo` (conferido em pedaços, para
## um giro grande não atravessar uma cerca fina)?
func _giro_cabe(de: float, passo: float) -> bool:
	var pedacos := maxi(ceili(absf(passo) / PASSO_CONFERIR_GIRO), 1)
	for i in range(1, pedacos + 1):
		if not _graveto_cabe(de + passo * i / pedacos, graveto_ao_comprido):
			return false
	return true


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
	# Subindo rampa ou escada, o graveto só encosta no chão que sobe (e o corpo sobe junto):
	# não é quina, e desviar jogaria o cachorro para fora da escada.
	if is_on_floor() and _graveto_cabe(yaw, graveto_ao_comprido, passo + Vector3.UP * passo.length()):
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

	var carga := graveto.peso * graveto.comprimento if tem_graveto and graveto else 0.0
	# Passagens redondas (troncos) balançam até sem graveto.
	var excesso := maxf(carga - carga_sem_balanco, 0.0) + float(passagem.get("instabilidade", 0.0))
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
## (Parado, o chão vem do "snap" do move_and_slide, sem colisão de deslize — por isso o teste é
## direto: o corpo sozinho tem chão logo embaixo?)
func _soltar_se_pendurado() -> void:
	if not tem_graveto or not is_on_floor() or _tempo_escorregando > 0.0 or _corpo_tem_chao():
		return
	var para_longe := global_position - colisao_graveto.global_position
	para_longe.y = 0.0
	if para_longe.length_squared() < 0.0001:
		para_longe = -modelo.global_basis.x
		para_longe.y = 0.0
	_escorregando = para_longe.normalized() * VELOCIDADE_ESCORREGAR
	_tempo_escorregando = DURACAO_ESCORREGAR
	velocity.y = minf(velocity.y, -1.0)


func _corpo_tem_chao() -> bool:
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = _forma_corpo_teste
	consulta.transform = ($Colisao as CollisionShape3D).global_transform.translated(Vector3.DOWN * 0.1)
	consulta.collision_mask = collision_mask
	consulta.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_shape(consulta, 1).is_empty()


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
	if fase == null or not is_on_floor() or not (tem_graveto and graveto and graveto.peso >= 1.5):
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


# --- Chão: água rasa, correnteza, neve e gelo ---

## O chão embaixo muda o passo: água rasa e neve fofa deixam o cachorro mais lento (`lentidao`),
## neve fofa e gelo tiram a aderência; a correnteza arrasta no sentido do tile (mais forte que o
## passo do cachorro: atravessar a correnteza a pé leva rio abaixo). Devolve o arrasto (m/s).
func _efeito_do_piso() -> Vector3:
	_lentidao_piso = 1.0
	em_correnteza = false
	_na_agua_rasa = false
	# No ar, continua valendo o último chão (quem pula deslizando cai deslizando).
	if is_on_floor():
		_no_gelo_liso = false
	if fase == null or not is_on_floor() or not _pisando_no_terreno():
		return Vector3.ZERO
	var terreno := fase.terreno
	var celula := terreno.local_to_map(terreno.to_local(global_position + Vector3.DOWN * 0.05))
	var definicao := Tiles.definicao(terreno.get_cell_item(celula))
	_lentidao_piso = definicao.get("lentidao", 1.0)
	_aderencia = definicao.get("aderencia", 1.0)
	_na_agua_rasa = definicao.get("rasa", false)
	_no_gelo_liso = definicao.get("deslizante", false)
	if not _na_agua_rasa:
		return Vector3.ZERO
	var forca: float = definicao.get("correnteza", 0.0)
	if forca <= 0.0:
		return Vector3.ZERO
	em_correnteza = true
	var sentido := terreno.global_basis * terreno.get_cell_item_basis(celula).x
	sentido.y = 0.0
	return sentido.normalized() * forca


## Apoiado no terreno (e não só em cima de um objeto — um tronco boiando, uma ponte)?
## (O leito da água rasa fica na mesma altura do topo de um tronco boiando: conta o objeto.)
func _pisando_no_terreno() -> bool:
	var consulta := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.2,
		global_position + Vector3.DOWN * 0.15, 4, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(consulta).is_empty()


## Aderência: com o chão firme o cachorro faz o que o jogador manda na hora; na neve fofa demora
## a arrancar e a parar; no gelo desliza. No ar, mantém a aderência do último chão.
func _com_aderencia(desejo: Vector3, delta: float) -> Vector3:
	if _aderencia >= 1.0 or _tempo_puxando > 0.0:
		_embalo = desejo
		return desejo
	_embalo = _embalo.move_toward(desejo, ACELERACAO_MAXIMA * _aderencia * delta)
	return _embalo


## Gelo liso (o gelo dos puzzles clássicos): pisando nele o cachorro sai deslizando em linha
## reta, na direção da grade mais próxima de onde andava, e só para ao bater em algo ou ao sair
## do gelo — no meio do caminho não dá para virar nem frear. Parado no gelo, uma rajada de
## vento também põe o cachorro para deslizar.
func _deslizar_no_gelo(horizontal: Vector3, vento: Vector3) -> Vector3:
	if fase == null or entrada_bloqueada or _tempo_puxando > 0.0 or (is_on_floor() and not _no_gelo_liso):
		deslizando = Vector3.ZERO
		return horizontal
	if deslizando == Vector3.ZERO:
		if not is_on_floor():
			return horizontal
		var impulso := horizontal
		if impulso.length_squared() < 0.25:
			impulso = vento if vento.length() > 1.5 else Vector3.ZERO
		if impulso == Vector3.ZERO:
			return Vector3.ZERO
		var direcao := Vector3(_na_grade(impulso))
		if test_move(global_transform, direcao * 0.1):
			# Encostado em algo nessa direção: não desliza, só força contra (empurra um bloco).
			_yaw_alvo = atan2(-direcao.z, direcao.x)
			return direcao * velocidade
		deslizando = direcao
	_yaw_alvo = atan2(-deslizando.z, deslizando.x)
	# Puxa o cachorro para o meio da fileira de células (o deslize fica certinho na grade).
	var terreno := fase.terreno
	var centro := terreno.to_global(terreno.map_to_local(terreno.local_to_map(terreno.to_local(global_position))))
	var lado := centro - global_position
	lado.y = 0.0
	lado -= deslizando * lado.dot(deslizando)
	_embalo = deslizando * VELOCIDADE_DESLIZE + (lado * 8.0).limit_length(2.0)
	return _embalo


# --- Vento ---------------------------------------------------------------------------------

## Empurrão do vento (ver Vento). O graveto na boca pega vento como uma vela: quanto mais
## comprido e mais atravessado ao vento, mais empurra; o peso segura o cachorro no lugar.
func _efeito_do_vento() -> Vector3:
	if fase == null or entrada_bloqueada:
		return Vector3.ZERO
	var forca := Vento.total_em(self, global_position + Vector3.UP * 0.25)
	if forca == Vector3.ZERO or not (tem_graveto and graveto):
		return forca
	# Eixo do graveto: atravessado fica de lado no focinho; ao comprido, para a frente.
	var yaw := modelo.rotation.y
	var eixo := Vector3(cos(yaw), 0.0, -sin(yaw)) if graveto_ao_comprido else Vector3(sin(yaw), 0.0, cos(yaw))
	var exposicao := absf(eixo.cross(forca.normalized()).y)
	var fator := 1.0 + 0.35 * graveto.comprimento * exposicao
	return forca * fator / (1.0 + maxf(graveto.peso - 1.0, 0.0) * 0.6)


# --- Frio ----------------------------------------------------------------------------------

## Perto de uma fonte de calor (grupo "fontes_de_calor", com `aquece(ponto)`) o calor sobe
## rápido; longe, cai em `tempo_de_frio` segundos (mais rápido na água). Gelado, volta para o
## último lugar quente.
func _atualizar_calor(delta: float) -> void:
	aquecendo = false
	if not sente_frio:
		calor = 1.0
		return
	for fonte in get_tree().get_nodes_in_group(&"fontes_de_calor"):
		if fonte.aquece(global_position):
			aquecendo = true
			break
	if aquecendo:
		calor = minf(calor + delta * 0.6, 1.0)
		if is_on_floor():
			_ponto_quente = global_position
	elif not entrada_bloqueada:
		var ritmo := 1.0 / maxf(tempo_de_frio, 1.0)
		if _na_agua_rasa:
			ritmo *= 2.0
		calor = maxf(calor - ritmo * delta, 0.0)
	# Tremendo de frio.
	if calor < 0.35:
		_tremor += delta * 40.0
		voxel.tremor = sin(_tremor) * 0.012 * (1.0 - calor / 0.35)
	elif voxel.tremor != 0.0:
		voxel.tremor = 0.0
	if calor <= 0.0:
		calor = 1.0
		_embalo = Vector3.ZERO
		global_position = _ponto_quente + Vector3.UP * 0.2
		velocity = Vector3.ZERO
		_pontos_seguros.clear()
		_guardar_ponto_seguro()
		gelou.emit()


## Com frio o cachorro anda mais devagar (até 30% abaixo do normal, quase gelado).
func _fator_do_frio() -> float:
	if not sente_frio or calor >= 0.35:
		return 1.0
	return lerpf(0.7, 1.0, calor / 0.35)


# --- Quedas ------------------------------------------------------------------------------

func _checar_queda(delta: float) -> void:
	if fase and (fase.dentro_da_agua(global_position) or _na_beira_da_agua() or _caindo_na_agua()):
		_voltar_ao_ponto_seguro("agua")
	elif global_position.y < (fase.limite_de_queda if fase else -10.0):
		_voltar_ao_ponto_seguro("queda")
	elif is_on_floor() and not em_correnteza:
		if em_passagem_estreita or not _pisando_no_terreno():
			_saiu_do_terreno = true
		elif _saiu_do_terreno:
			# Voltou ao terreno depois de uma ponte ou objeto: o ponto seguro fica deste lado. A
			# beirada vale só até o próximo ponto, um pouco mais para dentro.
			_saiu_do_terreno = false
			_pontos_seguros.clear()
			_guardar_ponto_seguro()
			_ponto_provisorio = true
		else:
			_tempo_ponto_seguro += delta
			if _tempo_ponto_seguro >= 0.25:
				_guardar_ponto_seguro()


## Saiu da beirada e já está abaixo dela, por cima de água funda: caiu (correndo, sem isto, a
## cápsula passaria "quicando" por cima de um riacho estreito).
func _caindo_na_agua() -> bool:
	return not is_on_floor() and global_position.y < -0.02 \
		and Tiles.eh_agua(fase.tile_em(global_position + Vector3.DOWN * 0.1))


## Água funda logo à frente (para onde o cachorro olha): ele não pula — assim riacho estreito
## continua sendo obstáculo, e a travessia é pela ponte, bloco, tronco...
func _agua_funda_na_frente() -> bool:
	if fase == null:
		return false
	var sentidos: Array[Vector3] = [Vector3(cos(modelo.rotation.y), 0.0, -sin(modelo.rotation.y))]
	var andando := Vector3(velocity.x, 0.0, velocity.z)
	if andando.length() > 0.3:
		sentidos.append(andando.normalized())
	for frente in sentidos:
		for distancia in [0.35, 0.7, 1.05]:
			var ponto: Vector3 = global_position + frente * distancia + Vector3.DOWN * 0.1
			if Tiles.eh_agua(fase.tile_em(ponto)):
				return true
	return false


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
	if _ponto_provisorio:
		_ponto_provisorio = false
		_pontos_seguros.clear()
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
	_saiu_do_terreno = false
	voltou_ao_ponto_seguro.emit(motivo)

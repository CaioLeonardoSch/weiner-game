extends Node3D
## O jogo: carrega a fase escolhida (autoload Fases) e aplica as regras.
##
## Ida em visão isométrica → pega o graveto → transição para 3D (terceira pessoa) →
## volta até o dono com o graveto. Largar o graveto (`largar_graveto`) volta para a
## isométrica; pegar de novo volta para o 3D.
## Objetos "só isométrico" (ex.: a folhagem que tampa o túnel) somem no 3D, e "só 3D"
## (ex.: árvores da frente, que tapariam a visão iso) só aparecem nele — a mudança de
## perspectiva literalmente abre (ou fecha) caminhos. F1 abre o editor nesta fase; Esc pausa.

@onready var cachorro: Dachshund = $Dachshund
@onready var camera_controller: CameraController = $CameraController
@onready var aviso: Label = $HUD/Area/Aviso
@onready var mensagem: Label = $HUD/Area/Mensagem
@onready var indicador_equilibrio: Control = $HUD/Area/Equilibrio

var fase: Fase
## O graveto na boca (ou o último que esteve nela).
var graveto: Graveto
## O primeiro dono da fase (a câmera 3D começa olhando para ele); pode não existir.
var dono: Dono
## O que a fase pede para terminar (ver scripts/objetivos/).
var objetivo: Objetivo
var concluida := false
var _tween_aviso: Tween
## O aviso na tela é importante (escrito pela fase: dica, ponte que caiu) — não se perde sob outro.
var _aviso_importante := false
var _texto_aviso := ""
var _segundos_aviso := 0.0
## Avisos importantes esperando a vez (interrompidos ou que chegaram durante outro):
## [texto, segundos, importante].
var _avisos_na_fila: Array[Array] = []
var _proxima_fase := ""
var _tempo_travado := 0.0
var _dica_virar_mostrada := false
var _tempo_sem_girar := 0.0
var _dica_girar_mostrada := false
var _pausa := MenuPausa.new()
## O objetivo da fase ("Leve o graveto ao dono", "Ovelhas no celeiro: 1 / 2"), numa pílula com
## a plaquinha no canto de cima à esquerda. Sem texto, a pílula some.
var contador := Coleira.rotulo("", 18)
var _pilula_objetivo := Coleira.pilula_com_peca()
## Controles que valem agora (tecla + o que faz), no canto de baixo à direita.
var controles := VBoxContainer.new()
var _texto_controles := ""
## Ação disponível no botão F ("[F] morder o mirante"), embaixo, no centro.
var rotulo_acao := Coleira.linha_tecla("F", "", 18)
var _pilula_acao := Coleira.pilula_com_peca()
## Balão curto em cima do cachorro ("Brrr!", "Splash!").
var _balao := Coleira.pilula(Coleira.CREME, 12.0, 2.0)
var _tempo_balao := 0.0
## Fim da fase: a plaquinha grande, o título e as opções (pílulas com a tecla).
var _cartao_fim := VBoxContainer.new()
## Mirante sendo usado (a câmera gira em volta dele, mostrando a fase da volta).
var _mirante: Mirante
## Fundo semitransparente do aviso (o rótulo `aviso` fica dentro dele).
var aviso_painel := PanelContainer.new()
## Flocos caindo em volta do cachorro (biomas com neve).
var clima: Clima
## Termômetro (fases com frio), no canto de baixo à direita.
var indicador_calor := IndicadorCalor.new()
## Fogueira → rótulo 2D em cima dela com os gravetos que faltam ("0 / 2"). Em 2D, no HUD: um
## texto 3D passaria pelo pixelado e ficaria ilegível (ainda mais sobre a neve).
var marcas_fogueira := {}
## Tela preta por cima de tudo (entrar numa toca), ver `escurecer`.
var _escuro := ColorRect.new()

## Avisos: largura máxima e tamanhos de letra (curto e de uma linha = grande, na faixa
## vermelha; senão, menor, na pílula creme).
const AVISO_LARGURA_MAXIMA := 640.0
const AVISO_FONTE_GRANDE := 34
const AVISO_FONTE_PEQUENA := 19
const AVISO_CURTO := 40
## Um aviso importante interrompido volta por pelo menos isto (s), para dar tempo de ler.
const AVISO_VOLTA_MINIMO := 2.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_montar_aviso()
	_montar_hud()
	mensagem.hide()
	cachorro.camera_referencia = camera_controller.camera
	indicador_equilibrio.cachorro = cachorro
	add_child(_pausa)
	indicador_calor.cachorro = cachorro
	_escuro.color = Color(0.02, 0.015, 0.01, 0.0)
	_escuro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_escuro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_escuro.hide()
	$HUD.add_child(_escuro)
	_atualizar_dica()

	var cena := Fases.cena_atual()
	if cena == null:
		_mostrar_erro("Nenhuma fase para jogar.\nF1: abrir o editor e criar uma")
		return
	fase = cena.instantiate() as Fase
	if fase == null:
		_mostrar_erro("A cena escolhida não é uma fase (raiz sem o script fase.gd).\nF1: abrir o editor")
		return
	add_child(fase)
	move_child(fase, 0)
	Biomas.aplicar_ambiente($Ambiente, fase.bioma)
	trocar_clima(Clima.efetivo(fase))
	# Chão e floresta em volta, para monitores largos nunca mostrarem o fim do mundo.
	var entorno := Entorno.new()
	entorno.name = "Entorno"
	add_child(entorno)
	entorno.montar(fase)
	cachorro.fase = fase
	# Pelo menu, a raça é a que o jogador escolheu para a região; testando no editor, a da fase.
	if not Fases.testando and not Fases.caminho_atual.is_empty():
		fase.raca = Fases.raca_para_jogar(Fases.caminho_atual).id
	var raca := Racas.por_id(fase.raca)
	if raca:
		cachorro.aplicar_raca(raca, Racas.pelagem_escolhida(raca))
	# Progressão: as habilidades das fases anteriores. Testando no editor, vale o id da fase
	# (fase nova, sem id, fica só com as dela).
	if not Fases.testando and not Fases.caminho_atual.is_empty():
		fase.habilidades_herdadas = Fases.habilidades_anteriores(Fases.id_da_fase(Fases.caminho_atual))
	var habilidades := fase.habilidades_efetivas()
	cachorro.pode_pular = habilidades & Fase.HABILIDADE_PULAR != 0
	cachorro.pode_cavar = habilidades & Fase.HABILIDADE_CAVAR != 0
	cachorro.pode_latir = habilidades & Fase.HABILIDADE_LATIR != 0
	cachorro.sente_frio = fase.frio
	cachorro.tempo_de_frio = fase.tempo_de_frio
	_atualizar_dica()
	fase.preparar_isometrica()

	objetivo = Objetivo.criar(fase.objetivo)
	var faltando := objetivo.faltando(fase)
	if not faltando.is_empty():
		_mostrar_erro("A fase precisa de %s.\nF1: abrir o editor" % ", ".join(faltando))
		return

	var inicio := fase.primeiro(InicioCachorro)
	cachorro.posicionar(inicio.global_position, inicio.global_rotation.y)
	# "Testar daqui" (F2 no editor): começa onde o cursor estava.
	if Fases.testando and Fases.inicio_do_teste != null:
		cachorro.posicionar(Fases.inicio_do_teste, inicio.global_rotation.y)
	camera_controller.configurar(cachorro)
	cachorro.voltou_ao_ponto_seguro.connect(_on_cachorro_voltou)
	cachorro.puxar_falhou.connect(_on_puxar_falhou)
	cachorro.gelou.connect(func() -> void:
		mostrar_balao("Brrr!")
		mostrar_aviso("Brrr! Frio demais — de volta para perto do fogo", 3.0))
	cachorro.pulo_recusado.connect(func(_motivo: String) -> void: mostrar_aviso("Água funda: salsicha não pula na água", 2.0))
	for bloco in fase.todos(Empurravel):
		(bloco as Empurravel).voltou_ao_inicio.connect(
			mostrar_aviso.bind("O bloco ficou preso no canto e voltou para o lugar"))
	for zona in fase.todos(ZonaDica):
		(zona as ZonaDica).ativada.connect(func(texto: String) -> void: mostrar_aviso(_com_teclas(texto), 4.5, true))
	_preparar_objetivo()
	mostrar_aviso(fase.nome)


func _preparar_objetivo() -> void:
	dono = fase.primeiro(Dono) as Dono
	for objeto in fase.todos(Graveto):
		var um_graveto := objeto as Graveto
		um_graveto.pego.connect(_on_graveto_pego.bind(um_graveto))
		um_graveto.protegido.connect(func() -> void: mostrar_aviso("Tem um passarinho no graveto!" +
			("  %s: latir" % Teclas.nome(&"latir") if cachorro.pode_latir else "")))
		um_graveto.boca_cheia.connect(func() -> void:
			mostrar_aviso("Boca cheia! %s larga este graveto para pegar outro" % Teclas.nome(&"largar_graveto")))
	for ponte in fase.todos(Ponte):
		var aviso := (ponte as Ponte).aviso_ao_quebrar
		(ponte as Ponte).quebrou.connect(mostrar_aviso.bind(
			_com_teclas(aviso) if not aviso.is_empty() else "A ponte caiu! A água levou as tábuas", 4.5, true))
	for tronco in fase.todos(TroncoRolante):
		(tronco as TroncoRolante).voltou_ao_inicio.connect(
			mostrar_aviso.bind("O tronco encalhou longe — ele voltou para o lugar", 3.0))
	for placa in fase.todos(Placa):
		(placa as Placa).pisada_sem_peso.connect(
			mostrar_aviso.bind("Placa de pedra: só algo pesado aciona — uma pedra, um tronco", 3.0))
	for objeto in fase.todos(Fogueira):
		var fogueira := objeto as Fogueira
		marcas_fogueira[fogueira] = _criar_marca()
		fogueira.acendeu.connect(mostrar_aviso.bind("A fogueira acendeu! Perto do fogo é quentinho", 3.0))
		fogueira.cresceu.connect(mostrar_aviso.bind("O fogo cresceu!"))
		fogueira.recebeu.connect(func(_gravetos: int, faltam: int) -> void:
			if faltam <= 0:
				mostrar_aviso("Lenha pronta! Falta o fogo: encoste um graveto aceso", 3.0)
			else:
				mostrar_aviso("Mais %d graveto%s para acender a fogueira" % [faltam, "" if faltam == 1 else "s"]))
	objetivo.preparar(self)


func _unhandled_input(event: InputEvent) -> void:
	if _mirante:
		# No mirante: F ou Esc saem de uma vez; reiniciar e o editor continuam valendo.
		if event.is_action_pressed("acao") or event.is_action_pressed("liberar_mouse"):
			get_viewport().set_input_as_handled()
			_sair_do_mirante()
			return
		if not (event.is_action_pressed("reiniciar") or event.is_action_pressed("alternar_editor")):
			return
	if event.is_action_pressed("reiniciar"):
		get_tree().reload_current_scene()
	elif event.is_action_pressed("alternar_editor"):
		Fases.abrir_editor()
	elif event.is_action_pressed("liberar_mouse"):
		_abrir_pausa()
	elif event.is_action_pressed("acao") and not concluida:
		var alvo := cachorro.objeto_da_acao()
		if alvo:
			alvo.executar_acao(cachorro)
	elif event.is_action_pressed("largar_graveto"):
		_tentar_largar_graveto()
	elif event.is_action_pressed("virar_graveto"):
		_tentar_virar_graveto()
	elif event.is_action_pressed("cavar") and not concluida and not cachorro.entrada_bloqueada:
		_avisar_motivo(cachorro.cavar(), "cavar", "Aqui não tem terra fofa para cavar")
	elif event.is_action_pressed("latir") and not concluida and not cachorro.entrada_bloqueada:
		_avisar_motivo(cachorro.latir(), "latir", "")
	elif concluida and fase and not Fases.testando and event.is_action_pressed("ui_accept"):
		if _proxima_fase.is_empty():
			Fases.abrir_menu()
		elif _muda_de_regiao():
			# Região nova: antes, a história dela e a escolha da raça.
			Fases.antes_de_jogar(_proxima_fase)
		else:
			Fases.jogar(_proxima_fase)



## Troca o clima (ver Clima), com o céu e a luz do bioma de novo por baixo.
func trocar_clima(tipo: int) -> void:
	if clima:
		remove_child(clima)
		clima.queue_free()
		Biomas.aplicar_ambiente($Ambiente, fase.bioma)
	clima = Clima.new()
	clima.name = "Clima"
	add_child(clima)
	clima.configurar(tipo, fase.bioma, $Ambiente, cachorro)


func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set(&"transparencia_na_frente", 0.0)


func _process(delta: float) -> void:
	if objetivo and not concluida:
		objetivo.processar(delta)
	# As árvores entre a câmera e o cachorro ficam pontilhadas (shaders/pixel_mundo.gdshader).
	RenderingServer.global_shader_parameter_set(&"alvo_visao", cachorro.global_position + Vector3.UP * 0.35)
	RenderingServer.global_shader_parameter_set(&"transparencia_na_frente", 1.0)
	_atualizar_marcas()
	_atualizar_rotulo_acao()
	_atualizar_balao(delta)
	_pilula_objetivo.visible = not contador.text.is_empty() and not concluida and _mirante == null
	# Graveto grande emperrado num vão: lembra que dá para virar (uma vez por fase).
	_tempo_travado = _tempo_travado + delta if cachorro.graveto_travado else 0.0
	if _tempo_travado > 0.8 and not _dica_virar_mostrada and not cachorro.graveto_ao_comprido:
		_dica_virar_mostrada = true
		mostrar_aviso("O graveto não passa atravessado — %s vira ao comprido" % Teclas.nome(&"virar_graveto"))
	# O graveto bate dos dois lados e o cachorro anda de lado/de ré: explica (uma vez por fase).
	_tempo_sem_girar = _tempo_sem_girar + delta if cachorro.giro_travado else 0.0
	if _tempo_sem_girar > 0.8 and not _dica_girar_mostrada:
		_dica_girar_mostrada = true
		mostrar_aviso("O graveto bate e não deixa virar — afaste-se um pouco ou %s vira o graveto" % Teclas.nome(&"virar_graveto"))


func _on_graveto_pego(quem: Dachshund, pego: Graveto) -> void:
	graveto = pego
	# Pego ainda durante a transição de largar (a física empurrou o cachorro para dentro
	# da área, ex.: uma tampa voltando): a câmera só vai para o 3D depois que ela terminar.
	if camera_controller.estado == CameraController.Estado.TRANSICAO:
		await camera_controller.transicao_concluida
	quem.entrada_bloqueada = true
	# Reparent fora do callback de física da Area3D.
	quem.pegar_graveto.call_deferred(graveto)
	camera_controller.yaw_inicial_3d = _yaw_olhando_para_o_dono() + fase.desvio_camera_3d
	camera_controller.transicionar_para_3d()
	# Abre as passagens no meio do movimento da câmera, quando a mudança passa despercebida.
	_agendar(camera_controller.duracao_transicao * 0.5,
		fase.ativar.bind(ObjetoFase.Visibilidade.SO_ISO, false))

	await camera_controller.transicao_concluida
	# Os objetos "só 3D" aparecem no fim: no meio do caminho a câmera passaria por eles.
	fase.ativar(ObjetoFase.Visibilidade.SO_3D, true)
	quem.entrada_bloqueada = false
	_atualizar_dica()
	var texto := "Nova perspectiva!"
	var grande := graveto.comprimento >= 1.1
	var pesado := graveto.peso >= 1.6
	if grande and pesado:
		texto += "\nGraveto grande e pesado (%.1f m) — %s vira ao comprido" % [graveto.comprimento, Teclas.nome(&"virar_graveto")]
	elif grande:
		texto += "\nGraveto grande (%.1f m) — %s vira ao comprido" % [graveto.comprimento, Teclas.nome(&"virar_graveto")]
	elif pesado:
		texto += "\nGraveto pesado — mais devagar"
	mostrar_aviso(texto)
	objetivo.ao_pegar_graveto(pego)


## Yaw (graus) da câmera atrás do cachorro, olhando na direção do dono.
func _yaw_olhando_para_o_dono() -> float:
	if dono == null:
		return camera_controller.yaw_inicial_3d
	var direcao := dono.global_position - cachorro.global_position
	if Vector2(direcao.x, direcao.z).length() < 0.01:
		return camera_controller.yaw_inicial_3d
	return rad_to_deg(atan2(-direcao.x, -direcao.z))


func _tentar_largar_graveto() -> void:
	if concluida or not cachorro.tem_graveto \
			or camera_controller.estado != CameraController.Estado.TERCEIRA_PESSOA:
		return
	# No ar (caindo de uma beirada) o graveto ficaria flutuando.
	if not cachorro.is_on_floor():
		return
	for zona in fase.todos(ZonaSemLargar):
		if (zona as ZonaSemLargar).contem(cachorro):
			mostrar_aviso("Aqui não dá para largar o graveto")
			return

	cachorro.entrada_bloqueada = true
	# Cai onde estava na boca, na mesma direção (atravessado ou ao comprido). Sem chão
	# embaixo (beira de barranco, água), cai num ponto alcançável (ver _ponto_para_largar).
	var yaw := graveto.global_basis.get_euler().y
	var ponto: Variant = _chao_embaixo(graveto.global_position)
	if ponto == null:
		ponto = _ponto_para_largar()
	cachorro.largar_graveto()
	graveto.reparent(fase.objetos)
	graveto.global_transform = Transform3D(Basis(Vector3.UP, yaw), ponto + Vector3.UP * 0.08)
	graveto.soltar()

	# Largado junto de uma fogueira, um graveto comum vai para o fogo.
	for objeto in fase.todos(Fogueira):
		var fogueira := objeto as Fogueira
		if fogueira.aceita(graveto) and _plano(fogueira.global_position - graveto.global_position).length() < 1.3:
			fogueira.receber_graveto(graveto)
			break
	_voltar_para_isometrica()


## Entrega o graveto da boca a um objeto (F perto da fogueira): o objeto recebe o graveto
## (`receber_graveto`) e a câmera volta para a isométrica, como ao largar.
func entregar_graveto(destino: ObjetoFase) -> void:
	if concluida or not cachorro.tem_graveto or camera_controller.estado != CameraController.Estado.TERCEIRA_PESSOA:
		return
	cachorro.entrada_bloqueada = true
	var entregue := graveto
	cachorro.largar_graveto()
	entregue.reparent(fase.objetos)
	destino.receber_graveto(entregue)
	_voltar_para_isometrica()


## Sem o graveto na boca: a câmera volta para a isométrica e as passagens da ida voltam.
func _voltar_para_isometrica() -> void:
	fase.ativar(ObjetoFase.Visibilidade.SO_3D, false)
	camera_controller.transicionar_para_iso()
	# Fecha as passagens de novo no meio do movimento da câmera.
	_agendar(camera_controller.duracao_transicao * 0.5,
		fase.ativar.bind(ObjetoFase.Visibilidade.SO_ISO, true))

	await camera_controller.transicao_concluida
	cachorro.entrada_bloqueada = false
	_atualizar_dica()


static func _plano(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _tentar_virar_graveto() -> void:
	if concluida or not cachorro.tem_graveto or cachorro.entrada_bloqueada:
		return
	if not cachorro.virar_graveto():
		mostrar_aviso("Sem espaço para virar o graveto")


## Mostra por que a ação não aconteceu (se valer a pena avisar).
func _avisar_motivo(motivo: String, acao: String, sem_alvo: String) -> void:
	match motivo:
		"boca_cheia":
			mostrar_aviso("Com o graveto na boca não dá para %s" % acao)
		"nada":
			if not sem_alvo.is_empty():
				mostrar_aviso(sem_alvo)


## Controles do canto: só o que vale agora (reiniciar e editor ficam na pausa, com as teclas).
func _atualizar_dica() -> void:
	var t := Teclas.nome
	if _mirante:
		_mostrar_controles([["Mouse", "olhar"], ["%s / Esc" % t.call(&"acao"), "sair do mirante"]])
		return
	var andar := "%s%s%s%s" % [t.call(&"mover_frente"), t.call(&"mover_esquerda"), t.call(&"mover_tras"), t.call(&"mover_direita")]
	var partes: Array = [[andar, "andar"], [t.call(&"correr"), "correr"]]
	var em_3d := cachorro.tem_graveto
	if em_3d:
		partes.append(["Mouse", "câmera"])
	if cachorro.pode_pular:
		partes.append([t.call(&"pular"), "pular"])
	if cachorro.pode_cavar and not cachorro.tem_graveto:
		partes.append([t.call(&"cavar"), "cavar"])
	if cachorro.pode_latir and not cachorro.tem_graveto:
		partes.append([t.call(&"latir"), "latir"])
	if not cachorro.tem_graveto and fase and not fase.todos(Empurravel).is_empty():
		partes.append([t.call(&"acao"), "+ trás: puxar bloco"])
	if not cachorro.tem_graveto and fase and not fase.todos(TroncoRolante).is_empty():
		partes.append([t.call(&"acao"), "na ponta do tronco + lado: girar"])
	if em_3d:
		partes.append_array([[t.call(&"virar_graveto"), "virar graveto"],
			[t.call(&"andar_devagar"), "devagar"], [t.call(&"largar_graveto"), "largar"]])
	partes.append(["Esc", "pausa"])
	_mostrar_controles(partes)


## Uma linha "[tecla] o que faz" para cada par [tecla, texto], alinhadas à direita.
func _mostrar_controles(pares: Array) -> void:
	var textos: PackedStringArray = []
	for i in pares.size():
		var linha: HBoxContainer
		if i < controles.get_child_count():
			linha = controles.get_child(i) as HBoxContainer
		else:
			linha = Coleira.linha_tecla("", "", 15, Color.WHITE, 6)
			linha.size_flags_horizontal = Control.SIZE_SHRINK_END
			controles.add_child(linha)
		Coleira.mudar_linha(linha, pares[i][0], pares[i][1])
		linha.show()
		textos.append("%s: %s" % pares[i])
	for i in range(pares.size(), controles.get_child_count()):
		controles.get_child(i).hide()
	_texto_controles = "    ".join(textos)


## Os controles do canto num texto só ("W: andar    Espaço: pular").
func texto_dos_controles() -> String:
	return _texto_controles


## Ponto do chão logo abaixo de `posicao` (até 0,6 m), ou null.
func _chao_embaixo(posicao: Vector3) -> Variant:
	var espaco := cachorro.get_world_3d().direct_space_state
	var raio := PhysicsRayQueryParameters3D.create(posicao + Vector3.UP * 0.2,
		Vector3(posicao.x, cachorro.global_position.y - 0.6, posicao.z), 1 | 4, [cachorro.get_rid()])
	var chao := espaco.intersect_ray(raio)
	return chao.position if not chao.is_empty() else null


## Onde o graveto cai: no chão, na frente do focinho. Se ali não der (parede, árvore, beira
## de barranco, água), cai embaixo do cachorro — na frente ele ficaria fora de alcance, e o
## cachorro preso sem ele (ex.: largado encostado no mato, com o túnel já fechado).
func _ponto_para_largar() -> Vector3:
	var espaco := cachorro.get_world_3d().direct_space_state
	var excluir: Array[RID] = [cachorro.get_rid()]
	var pe := cachorro.global_position
	var boca := cachorro.boca.global_position
	var frente := Vector3(boca.x, pe.y, boca.z)
	var altura := Vector3.UP * 0.3
	# Caminho livre até um pouco além do ponto (a área de pegar tem 0,2 m para cada lado).
	var alem := frente + (frente - pe).normalized() * 0.2
	var raio := PhysicsRayQueryParameters3D.create(pe + altura, alem + altura, cachorro.collision_mask, excluir)
	if espaco.intersect_ray(raio).is_empty():
		raio = PhysicsRayQueryParameters3D.create(frente + altura, frente + Vector3.DOWN * 0.3, cachorro.collision_mask, excluir)
		var chao := espaco.intersect_ray(raio)
		if not chao.is_empty():
			return chao.position
	return pe


## Pausa (Esc): some com o aviso do momento, para ele não ficar por cima do painel.
func _abrir_pausa() -> void:
	_limpar_avisos()
	_pausa.abrir()


func _on_puxar_falhou(motivo: String) -> void:
	match motivo:
		"boca_cheia":
			mostrar_aviso("Com o graveto na boca não dá para puxar")
		"sem_espaco":
			mostrar_aviso("Sem espaço atrás para puxar")
		"sem_espaco_girar":
			mostrar_aviso("Sem espaço para girar o tronco")


func _on_cachorro_voltou(motivo: String) -> void:
	if motivo == "agua":
		mostrar_balao("Splash!")
		mostrar_aviso("Splash! %s não nada..." % (cachorro.raca.nome if cachorro.raca else "Salsicha"))
	elif motivo == "queda":
		mostrar_aviso("Opa! Caiu...")


func concluir() -> void:
	if concluida:
		return
	concluida = true
	cachorro.entrada_bloqueada = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Senão um clique na tela de "fase concluída" prenderia o mouse de novo.
	camera_controller.set_process_unhandled_input(false)
	_limpar_avisos()
	var subtitulo := fase.nome
	var opcoes: Array = []
	if Fases.testando:
		opcoes = [[Teclas.nome(&"alternar_editor"), "Voltar ao editor"], [Teclas.nome(&"reiniciar"), "Jogar de novo"]]
	else:
		Fases.marcar_concluida(Fases.caminho_atual, fase.raca)
		_proxima_fase = Fases.proxima()
		if _proxima_fase.is_empty():
			subtitulo += " · última fase!"
			opcoes = [["Enter", "Menu"], [Teclas.nome(&"reiniciar"), "Jogar de novo"]]
		elif _muda_de_regiao():
			var regiao := Regioes.por_id(Fases.regiao_da_fase(_proxima_fase))
			subtitulo += " · próxima região: %s" % (regiao.nome if regiao else "?")
			opcoes = [["Enter", "Próxima região"], [Teclas.nome(&"reiniciar"), "Jogar de novo"], ["Esc", "Pausa"]]
		else:
			opcoes = [["Enter", "Próxima fase"], [Teclas.nome(&"reiniciar"), "Jogar de novo"], ["Esc", "Pausa"]]
	_mostrar_cartao_fim("Fase concluída!", subtitulo, opcoes)


func _muda_de_regiao() -> bool:
	return Fases.regiao_da_fase(_proxima_fase) != Fases.regiao_da_fase(Fases.caminho_atual)


## Cartão do fim: a plaquinha grande, o título contornado, o nome da fase e as opções (a
## primeira dourada).
func _mostrar_cartao_fim(titulo: String, subtitulo: String, opcoes: Array) -> void:
	for filho in _cartao_fim.get_children():
		filho.queue_free()
	var plaquinha := Coleira.Plaquinha.new(96.0)
	plaquinha.rotation = deg_to_rad(-8.0)
	plaquinha.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_cartao_fim.add_child(plaquinha)
	var rotulo_titulo := Coleira.rotulo(titulo, 56, Color.WHITE, true, 16)
	rotulo_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cartao_fim.add_child(rotulo_titulo)
	var rotulo_nome := Coleira.rotulo(subtitulo, 19, Color.WHITE, false, 7)
	rotulo_nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cartao_fim.add_child(rotulo_nome)
	var linha := HBoxContainer.new()
	linha.alignment = BoxContainer.ALIGNMENT_CENTER
	linha.add_theme_constant_override(&"separation", 14)
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in opcoes.size():
		var pilula := Coleira.pilula_com_peca(Coleira.DOURADO if i == 0 else Coleira.CREME)
		var conteudo := Coleira.linha_tecla(opcoes[i][0], opcoes[i][1], 17)
		pilula.add_child(conteudo)
		linha.add_child(pilula)
	_cartao_fim.add_child(linha)
	_cartao_fim.show()
	# A plaquinha cai girando, e o resto aparece junto.
	_cartao_fim.modulate.a = 0.0
	plaquinha.scale = Vector2.ONE * 1.6
	var tween := create_tween().set_parallel()
	tween.tween_property(_cartao_fim, "modulate:a", 1.0, 0.25)
	tween.tween_property(plaquinha, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _mostrar_erro(texto: String) -> void:
	camera_controller.configurar(cachorro)
	concluida = true
	cachorro.entrada_bloqueada = true
	cachorro.process_mode = Node.PROCESS_MODE_DISABLED
	cachorro.hide()
	mensagem.text = texto
	mensagem.show()


## Chama `acao` daqui a `segundos`. Usa tween do próprio nó: se a cena for reiniciada
## no meio, ele morre junto em vez de chamar um nó já liberado.
func _agendar(segundos: float, acao: Callable) -> void:
	var tween := create_tween()
	tween.tween_interval(segundos)
	tween.tween_callback(acao)


## O rótulo do aviso vai para dentro de um painel centralizado no topo (a faixa vermelha ou a
## pílula creme, ver `_exibir_aviso`).
func _montar_aviso() -> void:
	aviso_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aviso_painel.name = "AvisoPainel"
	var area := aviso.get_parent()
	area.add_child(aviso_painel)
	area.move_child(aviso_painel, aviso.get_index())
	aviso.reparent(aviso_painel, false)
	aviso.autowrap_mode = TextServer.AUTOWRAP_OFF
	aviso.add_theme_constant_override(&"outline_size", 0)
	aviso_painel.hide()


## Mostra um aviso no topo da tela por `segundos`. Um aviso novo toma o lugar do anterior, mas
## um `importante` (o que a fase quer dizer ao jogador: dica, ponte que caiu) não se perde: se um
## comum o interrompe (ex.: a resposta a uma tecla), ele volta depois com o tempo que faltava; se
## chega outro importante, este espera a vez.
func mostrar_aviso(texto: String, segundos := 2.0, importante := false) -> void:
	var na_tela := aviso_painel.visible and not _texto_aviso.is_empty()
	# O mesmo aviso de novo: só fica mais tempo.
	if na_tela and texto == _texto_aviso:
		_exibir_aviso(texto, maxf(segundos, _tempo_restante_aviso()), importante or _aviso_importante)
		return
	if na_tela and _aviso_importante:
		if importante:
			if not _avisos_na_fila.any(func(a: Array) -> bool: return a[0] == texto):
				_avisos_na_fila.append([texto, segundos, true])
			return
		_avisos_na_fila.push_front([_texto_aviso, maxf(_tempo_restante_aviso(), AVISO_VOLTA_MINIMO), true])
	_exibir_aviso(texto, segundos, importante)


func _tempo_restante_aviso() -> float:
	if _tween_aviso == null or not _tween_aviso.is_valid():
		return 0.0
	return maxf(_segundos_aviso - _tween_aviso.get_total_elapsed_time(), 0.0)


func _exibir_aviso(texto: String, segundos: float, importante: bool) -> void:
	_aviso_importante = importante
	_texto_aviso = texto
	_segundos_aviso = segundos
	var curto := texto.length() <= AVISO_CURTO and not "\n" in texto
	var tamanho := AVISO_FONTE_GRANDE if curto else AVISO_FONTE_PEQUENA
	# Curto: faixa vermelha torta, letra de título branca. Comprido: pílula creme, texto escuro.
	var fonte := Coleira.fonte_titulo() if curto else Coleira.fonte_texto()
	aviso.add_theme_font_override(&"font", fonte)
	aviso.add_theme_font_size_override(&"font_size", tamanho)
	aviso.add_theme_color_override(&"font_color", Color.WHITE if curto else Coleira.CONTORNO)
	aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso_painel.add_theme_stylebox_override(&"panel", Coleira.caixa(
		Coleira.VERMELHO if curto else Coleira.CREME, 12 if curto else 16, 3, 4, 26.0 if curto else 22.0,
		4.0 if curto else 8.0))
	var linhas: PackedStringArray = []
	for paragrafo in texto.split("\n"):
		linhas.append(_quebrar_linhas(paragrafo.split(" "), " ", fonte, tamanho, AVISO_LARGURA_MAXIMA))
	aviso.text = "\n".join(linhas)
	aviso_painel.show()
	# Encolhe para o texto novo e centraliza no topo.
	aviso_painel.reset_size()
	aviso_painel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 64)
	aviso_painel.pivot_offset = aviso_painel.size * 0.5
	aviso_painel.rotation = deg_to_rad(-1.5) if curto else 0.0
	if _tween_aviso:
		_tween_aviso.kill()
	_tween_aviso = create_tween()
	_tween_aviso.tween_interval(segundos)
	_tween_aviso.tween_callback(_proximo_aviso)


## Some com o aviso da tela e com os que esperavam a vez.
func _limpar_avisos() -> void:
	if _tween_aviso:
		_tween_aviso.kill()
	_avisos_na_fila.clear()
	_proximo_aviso()


func _proximo_aviso() -> void:
	aviso_painel.hide()
	_aviso_importante = false
	_texto_aviso = ""
	if not _avisos_na_fila.is_empty():
		var proximo: Array = _avisos_na_fila.pop_front()
		_exibir_aviso(proximo[0], proximo[1], proximo[2])


## Junta `pedacos` com `separador` em linhas de até `largura` px (um pedaço nunca é partido).
static func _quebrar_linhas(pedacos: PackedStringArray, separador: String, fonte: Font, tamanho: int,
		largura: float) -> String:
	var linhas: PackedStringArray = []
	var linha := ""
	for pedaco in pedacos:
		var tentativa := pedaco if linha.is_empty() else linha + separador + pedaco
		if not linha.is_empty() and fonte.get_string_size(tentativa, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x > largura:
			linhas.append(linha)
			linha = pedaco
		else:
			linha = tentativa
	linhas.append(linha)
	return "\n".join(linhas)


## Troca "{acao}" pelo nome da tecla atual da ação (textos das Zonas de dica).
func _com_teclas(texto: String) -> String:
	var resultado := texto
	for item in Teclas.REMAPEAVEIS:
		resultado = resultado.replace("{%s}" % item[0], Teclas.nome(item[0]))
	return resultado


## Pílula creme com contorno escuro: legível sobre neve clara e em 720p.
func _criar_marca() -> PanelContainer:
	var painel := Coleira.pilula(Coleira.CREME, 12.0, 2.0)
	var rotulo := Coleira.rotulo("", 22, Coleira.CONTORNO, true)
	rotulo.name = "Texto"
	painel.add_child(rotulo)
	painel.hide()
	$HUD.add_child(painel)
	return painel


## Cada marca acompanha a sua fogueira na tela (some acesa, escondida ou atrás da câmera).
func _atualizar_marcas() -> void:
	var camera := camera_controller.camera
	for fogueira: Fogueira in marcas_fogueira:
		var painel: PanelContainer = marcas_fogueira[fogueira]
		var texto := fogueira.texto_do_contador() if fogueira.visible else ""
		var ponto := fogueira.global_position + Vector3.UP * 1.2
		if texto.is_empty() or camera.is_position_behind(ponto):
			painel.hide()
			continue
		var rotulo := painel.get_node(^"Texto") as Label
		if rotulo.text != "🔥 " + texto:
			rotulo.text = "🔥 " + texto
			painel.reset_size()
		painel.position = (camera.unproject_position(ponto) - painel.size * 0.5).round()
		painel.show()


func _atualizar_rotulo_acao() -> void:
	var alvo := cachorro.objeto_da_acao() if fase and not concluida else null
	if alvo == null:
		_pilula_acao.hide()
		return
	var texto: String = alvo.acao_da_boca(cachorro)
	var rotulo_texto := rotulo_acao.get_node(^"Texto") as Label
	if rotulo_texto.text != texto or not _pilula_acao.visible:
		Coleira.mudar_linha(rotulo_acao, Teclas.nome(&"acao"), texto)
		_pilula_acao.reset_size()
		_pilula_acao.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 96)
	_pilula_acao.show()


## Escurece (ou clareia) a tela em `duracao` segundos. Aguarde com `await`.
func escurecer(ligar: bool, duracao: float) -> void:
	_escuro.show()
	var tween := create_tween()
	tween.tween_property(_escuro, "color:a", 1.0 if ligar else 0.0, duracao)
	if not ligar:
		tween.tween_callback(_escuro.hide)
	await tween.finished


## O cachorro foi de um lugar para outro de uma vez (saiu pela outra toca): a câmera vai junto.
func cachorro_mudou_de_lugar() -> void:
	camera_controller.recentralizar()


# --- HUD (estilo Coleira, ver scripts/ui/coleira.gd) ----------------------------------------

## Monta as peças do HUD que não estão na cena: objetivo, controles, ação, balão, fim da fase.
func _montar_hud() -> void:
	var area := $HUD/Area as Control
	# Objetivo: plaquinha + texto, no canto de cima à esquerda.
	var linha_objetivo := HBoxContainer.new()
	linha_objetivo.add_theme_constant_override(&"separation", 10)
	linha_objetivo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linha_objetivo.add_child(Coleira.Plaquinha.new(30.0))
	contador.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	linha_objetivo.add_child(contador)
	_pilula_objetivo.add_child(linha_objetivo)
	_pilula_objetivo.name = "Objetivo"
	_pilula_objetivo.position = Vector2(18, 16)
	_pilula_objetivo.hide()
	area.add_child(_pilula_objetivo)
	# Controles: coluna de "[tecla] o que faz" no canto de baixo à direita.
	controles.name = "Controles"
	controles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controles.alignment = BoxContainer.ALIGNMENT_END
	controles.add_theme_constant_override(&"separation", 6)
	controles.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 18)
	controles.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	controles.grow_vertical = Control.GROW_DIRECTION_BEGIN
	area.add_child(controles)
	# Ação do F: pílula com a tecla, embaixo no centro.
	_pilula_acao.name = "Acao"
	_pilula_acao.add_child(rotulo_acao)
	_pilula_acao.hide()
	area.add_child(_pilula_acao)
	# Termômetro: no canto de cima à direita.
	indicador_calor.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 18)
	indicador_calor.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	area.add_child(indicador_calor)
	# Balão do cachorro.
	_balao.name = "Balao"
	var texto_balao := Coleira.rotulo("", 20, Coleira.CONTORNO, true)
	texto_balao.name = "Texto"
	_balao.add_child(texto_balao)
	_balao.draw.connect(_desenhar_rabinho_do_balao)
	_balao.hide()
	$HUD.add_child(_balao)
	# Fim da fase, no meio da tela.
	_cartao_fim.name = "Fim"
	_cartao_fim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cartao_fim.alignment = BoxContainer.ALIGNMENT_CENTER
	_cartao_fim.add_theme_constant_override(&"separation", 12)
	_cartao_fim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cartao_fim.hide()
	area.add_child(_cartao_fim)
	# Mensagem de erro (fase que não abre).
	mensagem.add_theme_font_override(&"font", Coleira.fonte_titulo())
	mensagem.add_theme_font_size_override(&"font_size", 36)
	mensagem.add_theme_color_override(&"font_outline_color", Coleira.CONTORNO)
	mensagem.add_theme_constant_override(&"outline_size", 12)


## Balão curto em cima da cabeça do cachorro por `segundos`.
func mostrar_balao(texto: String, segundos := 1.6) -> void:
	(_balao.get_node(^"Texto") as Label).text = texto
	_balao.reset_size()
	_tempo_balao = segundos
	_atualizar_balao(0.0)


func _atualizar_balao(delta: float) -> void:
	_tempo_balao -= delta
	var ponto := cachorro.global_position + Vector3.UP * 0.9
	var camera := camera_controller.camera
	if _tempo_balao <= 0.0 or camera == null or camera.is_position_behind(ponto):
		_balao.hide()
		return
	var tela := camera.unproject_position(ponto)
	_balao.position = (tela - Vector2(_balao.size.x * 0.4, _balao.size.y + 12.0)).round()
	_balao.show()


## O rabinho do balão, apontando para o cachorro.
func _desenhar_rabinho_do_balao() -> void:
	var base := Vector2(_balao.size.x * 0.4, _balao.size.y - 4.0)
	_balao.draw_colored_polygon(PackedVector2Array([base + Vector2(-2, 0), base + Vector2(14, 0),
		base + Vector2(1, 14)]), Coleira.CONTORNO)


# --- Mirante -------------------------------------------------------------------------------

## Morder o mirante: a câmera vai para o 3D em volta dele e mostra a fase como ela fica na
## volta (só o visual). O cachorro fica parado.
func entrar_no_mirante(mirante: Mirante) -> void:
	if _mirante or concluida or camera_controller.estado != CameraController.Estado.ISOMETRICO:
		return
	_mirante = mirante
	cachorro.entrada_bloqueada = true
	camera_controller.ponto_de_vista = mirante.ponto_de_vista()
	# Olhando para o graveto lendário (o caminho da fase), de um pouco mais alto.
	var alvo := mirante.global_position + Vector3.RIGHT
	for objeto in fase.todos(Graveto):
		if (objeto as Graveto).lendario and not (objeto as Graveto).ja_pego:
			alvo = objeto.global_position
	var direcao := alvo - mirante.global_position
	camera_controller.yaw_inicial_3d = rad_to_deg(atan2(-direcao.x, -direcao.z))
	var pitch_normal := camera_controller.pitch_inicial_3d
	camera_controller.pitch_inicial_3d = -28.0
	camera_controller.braco.spring_length = 7.0
	fase.previa_da_volta(true)
	camera_controller.transicionar_para_3d()
	await camera_controller.transicao_concluida
	camera_controller.pitch_inicial_3d = pitch_normal
	_atualizar_dica()
	mostrar_aviso("Do mirante você vê a fase como ela fica na volta", 3.0)


func _sair_do_mirante() -> void:
	if _mirante == null or camera_controller.estado != CameraController.Estado.TERCEIRA_PESSOA:
		return
	camera_controller.transicionar_para_iso()
	await camera_controller.transicao_concluida
	camera_controller.ponto_de_vista = null
	camera_controller.braco.spring_length = camera_controller.distancia_3d
	fase.previa_da_volta(false)
	_mirante = null
	cachorro.entrada_bloqueada = false
	_atualizar_dica()

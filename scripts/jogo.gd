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
@onready var dica: Label = $HUD/Area/Dica
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
## Contador do objetivo (ex.: ovelhas no cercado), no canto de baixo.
var contador := Label.new()
## Ação disponível no botão F ("F: morder o mirante"), embaixo, no centro.
var rotulo_acao := Label.new()
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

## Avisos: largura máxima e tamanhos de letra (curto e de uma linha = grande; senão, menor).
const AVISO_LARGURA_MAXIMA := 720.0
const AVISO_FONTE_GRANDE := 34
const AVISO_FONTE_PEQUENA := 22
const AVISO_CURTO := 40
## Um aviso importante interrompido volta por pelo menos isto (s), para dar tempo de ler.
const AVISO_VOLTA_MINIMO := 2.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_montar_aviso()
	# Com teclas de nome comprido (ex.: "Mouse esq.") a dica quebra em duas linhas, sem sair da
	# tela; o tamanho da área muda com a janela.
	dica.resized.connect(_atualizar_dica)
	mensagem.hide()
	cachorro.camera_referencia = camera_controller.camera
	indicador_equilibrio.cachorro = cachorro
	add_child(_pausa)
	contador.hide()
	contador.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 16)
	contador.grow_vertical = Control.GROW_DIRECTION_BEGIN
	contador.add_theme_font_size_override("font_size", 24)
	contador.add_theme_color_override("font_outline_color", Color.BLACK)
	contador.add_theme_constant_override("outline_size", 8)
	$HUD/Area.add_child(contador)
	rotulo_acao.hide()
	rotulo_acao.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 110)
	rotulo_acao.grow_horizontal = Control.GROW_DIRECTION_BOTH
	rotulo_acao.grow_vertical = Control.GROW_DIRECTION_BEGIN
	rotulo_acao.add_theme_font_size_override("font_size", 26)
	rotulo_acao.add_theme_color_override("font_color", TemaUI.COR_DESTAQUE)
	rotulo_acao.add_theme_color_override("font_outline_color", Color.BLACK)
	rotulo_acao.add_theme_constant_override("outline_size", 8)
	$HUD/Area.add_child(rotulo_acao)
	indicador_calor.cachorro = cachorro
	indicador_calor.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	indicador_calor.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	indicador_calor.grow_vertical = Control.GROW_DIRECTION_BEGIN
	$HUD/Area.add_child(indicador_calor)
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
	cachorro.gelou.connect(func() -> void: mostrar_aviso("Brrr! Frio demais — de volta para perto do fogo", 3.0))
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


## Dica do topo: só o que vale agora (reiniciar e editor ficam na pausa, com as teclas).
func _atualizar_dica() -> void:
	var t := Teclas.nome
	if _mirante:
		_mostrar_dicas(["Mouse: olhar", "%s ou Esc: sair do mirante" % t.call(&"acao")])
		return
	var andar := "%s%s%s%s" % [t.call(&"mover_frente"), t.call(&"mover_esquerda"), t.call(&"mover_tras"), t.call(&"mover_direita")]
	var partes: PackedStringArray = ["%s / ←↑↓→: andar" % andar]
	var em_3d := cachorro.tem_graveto
	if em_3d:
		partes.append("Mouse: câmera")
	if cachorro.pode_pular:
		partes.append("%s: pular" % t.call(&"pular"))
	if cachorro.pode_cavar and not cachorro.tem_graveto:
		partes.append("%s: cavar" % t.call(&"cavar"))
	if cachorro.pode_latir and not cachorro.tem_graveto:
		partes.append("%s: latir" % t.call(&"latir"))
	if not cachorro.tem_graveto and fase and not fase.todos(Empurravel).is_empty():
		partes.append("%s + trás: puxar bloco" % t.call(&"acao"))
	if not cachorro.tem_graveto and fase and not fase.todos(TroncoRolante).is_empty():
		partes.append("%s na ponta do tronco + lado: girar" % t.call(&"acao"))
	if em_3d:
		partes.append_array(["%s: virar graveto" % t.call(&"virar_graveto"),
			"%s: devagar" % t.call(&"andar_devagar"), "%s: largar" % t.call(&"largar_graveto")])
	partes.append("Esc: pausa")
	_mostrar_dicas(partes)


## Dicas separadas por espaço largo; se não couberem numa linha, quebram entre uma dica e outra.
func _mostrar_dicas(partes: PackedStringArray) -> void:
	var tamanho := dica.get_theme_font_size(&"font_size")
	dica.text = _quebrar_linhas(partes, "    ", dica.get_theme_font(&"font"), tamanho, dica.size.x)


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
	var texto := "Fase concluída! 🦴\n"
	if Fases.testando:
		texto += "%s: voltar ao editor    %s: jogar de novo" % [Teclas.nome(&"alternar_editor"), Teclas.nome(&"reiniciar")]
	else:
		Fases.marcar_concluida(Fases.caminho_atual, fase.raca)
		_proxima_fase = Fases.proxima()
		if _proxima_fase.is_empty():
			texto += "Última fase! Enter: menu    %s: jogar de novo" % Teclas.nome(&"reiniciar")
		elif _muda_de_regiao():
			var regiao := Regioes.por_id(Fases.regiao_da_fase(_proxima_fase))
			texto += "Enter: próxima região (%s)    %s: jogar de novo    Esc: pausa" % [
				regiao.nome if regiao else "?", Teclas.nome(&"reiniciar")]
		else:
			texto += "Enter: próxima fase    %s: jogar de novo    Esc: pausa" % Teclas.nome(&"reiniciar")
	mensagem.text = texto
	mensagem.show()


func _muda_de_regiao() -> bool:
	return Fases.regiao_da_fase(_proxima_fase) != Fases.regiao_da_fase(Fases.caminho_atual)


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


## O rótulo do aviso vai para dentro de um painel semitransparente, centralizado no topo.
func _montar_aviso() -> void:
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(0, 0, 0, 0.5)
	fundo.set_corner_radius_all(6)
	fundo.content_margin_left = 18
	fundo.content_margin_right = 18
	fundo.content_margin_top = 6
	fundo.content_margin_bottom = 8
	aviso_painel.add_theme_stylebox_override("panel", fundo)
	aviso_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aviso_painel.name = "AvisoPainel"
	var area := aviso.get_parent()
	area.add_child(aviso_painel)
	area.move_child(aviso_painel, aviso.get_index())
	aviso.reparent(aviso_painel, false)
	aviso.autowrap_mode = TextServer.AUTOWRAP_OFF
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
	aviso.add_theme_font_size_override("font_size", tamanho)
	aviso.add_theme_constant_override("outline_size", 8 if curto else 6)
	var linhas: PackedStringArray = []
	for paragrafo in texto.split("\n"):
		linhas.append(_quebrar_linhas(paragrafo.split(" "), " ", aviso.get_theme_font(&"font"), tamanho, AVISO_LARGURA_MAXIMA))
	aviso.text = "\n".join(linhas)
	aviso_painel.show()
	# Encolhe para o texto novo e centraliza no topo.
	aviso_painel.reset_size()
	aviso_painel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 72)
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


## Rótulo com fundo escuro, letra grande e contorno: legível sobre neve clara e em 720p.
func _criar_marca() -> PanelContainer:
	var painel := PanelContainer.new()
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(0.08, 0.06, 0.05, 0.72)
	fundo.set_corner_radius_all(6)
	fundo.content_margin_left = 10
	fundo.content_margin_right = 10
	fundo.content_margin_top = 2
	fundo.content_margin_bottom = 4
	painel.add_theme_stylebox_override("panel", fundo)
	painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rotulo := Label.new()
	rotulo.name = "Texto"
	rotulo.add_theme_font_size_override("font_size", 26)
	rotulo.add_theme_color_override("font_color", TemaUI.COR_DESTAQUE)
	rotulo.add_theme_color_override("font_outline_color", Color.BLACK)
	rotulo.add_theme_constant_override("outline_size", 6)
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
		rotulo_acao.hide()
		return
	rotulo_acao.text = "%s: %s" % [Teclas.nome(&"acao"), alvo.acao_da_boca(cachorro)]
	rotulo_acao.show()


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

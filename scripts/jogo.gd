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
@onready var aviso: Label = $HUD/Aviso
@onready var mensagem: Label = $HUD/Mensagem
@onready var dica: Label = $HUD/Dica
@onready var indicador_equilibrio: Control = $HUD/Equilibrio

var fase: Fase
var graveto: Graveto
var dono: Dono
var concluida := false
var _tween_aviso: Tween
var _proxima_fase := ""
var _tempo_travado := 0.0
var _dica_virar_mostrada := false
var _pausa := MenuPausa.new()


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	aviso.hide()
	mensagem.hide()
	cachorro.camera_referencia = camera_controller.camera
	indicador_equilibrio.cachorro = cachorro
	add_child(_pausa)
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
	cachorro.fase = fase
	var raca := Racas.por_id(fase.raca)
	if raca:
		cachorro.aplicar_raca(raca, Racas.pelagem_escolhida(raca))
	var habilidades := fase.habilidades | (raca.habilidades_nativas if raca else 0)
	cachorro.pode_pular = habilidades & Fase.HABILIDADE_PULAR != 0
	cachorro.pode_cavar = habilidades & Fase.HABILIDADE_CAVAR != 0
	cachorro.pode_latir = habilidades & Fase.HABILIDADE_LATIR != 0
	_atualizar_dica()
	fase.preparar_isometrica()

	var inicio := fase.primeiro(InicioCachorro)
	graveto = fase.primeiro(Graveto) as Graveto
	dono = fase.primeiro(Dono) as Dono
	var faltando: PackedStringArray = []
	if inicio == null:
		faltando.append("Início do cachorro")
	if graveto == null:
		faltando.append("Graveto")
	if dono == null:
		faltando.append("Dono")
	if not faltando.is_empty():
		_mostrar_erro("A fase precisa de: %s.\nF1: abrir o editor" % ", ".join(faltando))
		return

	cachorro.posicionar(inicio.global_position, inicio.global_rotation.y)
	camera_controller.configurar(cachorro)
	cachorro.voltou_ao_ponto_seguro.connect(_on_cachorro_voltou)
	graveto.pego.connect(_on_graveto_pego)
	for bloco in fase.todos(Empurravel):
		(bloco as Empurravel).voltou_ao_inicio.connect(
			_mostrar_aviso.bind("O bloco ficou preso no canto e voltou para o lugar"))
	graveto.protegido.connect(_mostrar_aviso.bind("Tem um passarinho no graveto!" +
		("  B: latir" if cachorro.pode_latir else "")))
	dono.cachorro_chegou.connect(_on_dono_cachorro_chegou)
	_mostrar_aviso(fase.nome)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reiniciar"):
		get_tree().reload_current_scene()
	elif event.is_action_pressed("alternar_editor"):
		Fases.abrir_editor()
	elif event.is_action_pressed("liberar_mouse"):
		_pausa.abrir()
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
		else:
			Fases.jogar(_proxima_fase)


func _process(delta: float) -> void:
	# Graveto grande emperrado num vão: lembra que dá para virar (uma vez por fase).
	_tempo_travado = _tempo_travado + delta if cachorro.graveto_travado else 0.0
	if _tempo_travado > 0.8 and not _dica_virar_mostrada and not cachorro.graveto_ao_comprido:
		_dica_virar_mostrada = true
		_mostrar_aviso("O graveto não passa atravessado — Q vira ao comprido")


func _on_graveto_pego(quem: Dachshund) -> void:
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
		texto += "\nGraveto grande e pesado (%.1f m) — Q vira ao comprido" % graveto.comprimento
	elif grande:
		texto += "\nGraveto grande (%.1f m) — Q vira ao comprido" % graveto.comprimento
	elif pesado:
		texto += "\nGraveto pesado — mais devagar, mas firme na correnteza"
	_mostrar_aviso(texto)
	# Caso tenha largado e pegado o graveto de novo já do lado do dono.
	if dono.contem(cachorro):
		_concluir()


## Yaw (graus) da câmera atrás do cachorro, olhando na direção do dono.
func _yaw_olhando_para_o_dono() -> float:
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
			_mostrar_aviso("Aqui não dá para largar o graveto")
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

	fase.ativar(ObjetoFase.Visibilidade.SO_3D, false)
	camera_controller.transicionar_para_iso()
	# Fecha as passagens de novo no meio do movimento da câmera.
	_agendar(camera_controller.duracao_transicao * 0.5,
		fase.ativar.bind(ObjetoFase.Visibilidade.SO_ISO, true))

	await camera_controller.transicao_concluida
	cachorro.entrada_bloqueada = false
	_atualizar_dica()


func _tentar_virar_graveto() -> void:
	if concluida or not cachorro.tem_graveto or cachorro.entrada_bloqueada:
		return
	if not cachorro.virar_graveto():
		_mostrar_aviso("Sem espaço para virar o graveto")


## Mostra por que a ação não aconteceu (se valer a pena avisar).
func _avisar_motivo(motivo: String, acao: String, sem_alvo: String) -> void:
	match motivo:
		"boca_cheia":
			_mostrar_aviso("Com o graveto na boca não dá para %s" % acao)
		"nada":
			if not sem_alvo.is_empty():
				_mostrar_aviso(sem_alvo)


func _atualizar_dica() -> void:
	var partes: PackedStringArray = ["WASD / ←↑↓→: andar"]
	var em_3d := cachorro.tem_graveto
	if em_3d:
		partes.append("Mouse: câmera")
	if cachorro.pode_pular:
		partes.append("Espaço: pular")
	if cachorro.pode_cavar and not cachorro.tem_graveto:
		partes.append("C: cavar")
	if cachorro.pode_latir and not cachorro.tem_graveto:
		partes.append("B: latir")
	if not cachorro.tem_graveto and fase and not fase.todos(Empurravel).is_empty():
		partes.append("F + trás: puxar bloco")
	if em_3d:
		partes.append_array(["Q: virar graveto", "Shift: devagar", "E: largar"])
	partes.append_array(["R: reiniciar", "Esc: pausa", "F1: editor"])
	if not em_3d:
		partes.append("F3: pixel")
	dica.text = "    ".join(partes)


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


func _on_dono_cachorro_chegou(body: Node3D) -> void:
	if body == cachorro and cachorro.tem_graveto:
		_concluir()


func _on_cachorro_voltou(motivo: String) -> void:
	if motivo == "agua":
		_mostrar_aviso("Splash! Salsicha não nada...")
	elif motivo == "queda":
		_mostrar_aviso("Opa! Caiu...")


func _concluir() -> void:
	if concluida:
		return
	concluida = true
	cachorro.entrada_bloqueada = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Senão um clique na tela de "fase concluída" prenderia o mouse de novo.
	camera_controller.set_process_unhandled_input(false)
	aviso.hide()
	var texto := "Fase concluída! 🦴\n"
	if Fases.testando:
		texto += "F1: voltar ao editor    R: jogar de novo"
	else:
		Fases.marcar_concluida(Fases.caminho_atual)
		_proxima_fase = Fases.proxima()
		if _proxima_fase.is_empty():
			texto += "Última fase! Enter: menu    R: jogar de novo"
		else:
			texto += "Enter: próxima fase    R: jogar de novo    Esc: pausa"
	mensagem.text = texto
	mensagem.show()


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


func _mostrar_aviso(texto: String) -> void:
	aviso.text = texto
	aviso.show()
	if _tween_aviso:
		_tween_aviso.kill()
	_tween_aviso = create_tween()
	_tween_aviso.tween_interval(2.0)
	_tween_aviso.tween_callback(aviso.hide)

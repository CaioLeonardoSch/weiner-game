extends Node3D
## O jogo: carrega a fase escolhida (autoload Fases) e aplica as regras.
##
## Ida em visão isométrica → pega o graveto → transição para 3D (terceira pessoa) →
## volta até o dono com o graveto. Largar o graveto (`largar_graveto`) volta para a
## isométrica; pegar de novo volta para o 3D.
## Objetos "só isométrico" (ex.: a folhagem que tampa o túnel) somem no 3D, e "só 3D"
## (ex.: árvores da frente, que tapariam a visão iso) só aparecem nele — a mudança de
## perspectiva literalmente abre (ou fecha) caminhos. F1 abre o editor nesta fase.

@onready var cachorro: Dachshund = $Dachshund
@onready var camera_controller: CameraController = $CameraController
@onready var aviso: Label = $HUD/Aviso
@onready var mensagem: Label = $HUD/Mensagem
@onready var dica: Label = $HUD/Dica

const DICA_ISO := "WASD / ←↑↓→: andar    R: reiniciar    F1: editor de fases    F3: pixel"
const DICA_3D := "WASD / ←↑↓→: andar    Mouse: câmera    E: largar graveto    Esc: soltar mouse    R: reiniciar    F1: editor"

var fase: Fase
var graveto: Graveto
var dono: Dono
var concluida := false
var _tween_aviso: Tween
var _proxima_fase := ""


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	aviso.hide()
	mensagem.hide()
	dica.text = DICA_ISO
	cachorro.camera_referencia = camera_controller.camera

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
	dono.cachorro_chegou.connect(_on_dono_cachorro_chegou)
	_mostrar_aviso(fase.nome)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reiniciar"):
		get_tree().reload_current_scene()
	elif event.is_action_pressed("alternar_editor"):
		Fases.abrir_editor()
	elif event.is_action_pressed("largar_graveto"):
		_tentar_largar_graveto()
	elif concluida and not _proxima_fase.is_empty() and event.is_action_pressed("ui_accept"):
		Fases.jogar(_proxima_fase)


func _on_graveto_pego(quem: Dachshund) -> void:
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
	dica.text = DICA_3D
	_mostrar_aviso("Nova perspectiva!")
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
	for zona in fase.todos(ZonaSemLargar):
		if (zona as ZonaSemLargar).contem(cachorro):
			_mostrar_aviso("Aqui não dá para largar o graveto")
			return

	cachorro.entrada_bloqueada = true
	var boca := cachorro.boca.global_position
	cachorro.largar_graveto()
	graveto.reparent(fase.objetos)
	# No chão, na frente do focinho, ainda atravessado em relação ao cachorro.
	graveto.global_transform = Transform3D(
		Basis(Vector3.UP, cachorro.modelo.rotation.y),
		Vector3(boca.x, cachorro.global_position.y + 0.08, boca.z))
	graveto.soltar()

	fase.ativar(ObjetoFase.Visibilidade.SO_3D, false)
	camera_controller.transicionar_para_iso()
	# Fecha as passagens de novo no meio do movimento da câmera.
	_agendar(camera_controller.duracao_transicao * 0.5,
		fase.ativar.bind(ObjetoFase.Visibilidade.SO_ISO, true))

	await camera_controller.transicao_concluida
	cachorro.entrada_bloqueada = false
	dica.text = DICA_ISO


func _on_dono_cachorro_chegou(body: Node3D) -> void:
	if body == cachorro and cachorro.tem_graveto:
		_concluir()


func _on_cachorro_voltou(motivo: String) -> void:
	if motivo == "agua":
		_mostrar_aviso("Splash! Salsicha não nada...")


func _concluir() -> void:
	if concluida:
		return
	concluida = true
	cachorro.entrada_bloqueada = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	aviso.hide()
	var texto := "Fase concluída! 🦴\n"
	if Fases.testando:
		texto += "F1: voltar ao editor    R: jogar de novo"
	else:
		_proxima_fase = Fases.proxima()
		if _proxima_fase.is_empty():
			texto += "R: jogar de novo"
		else:
			texto += "Enter: próxima fase    R: jogar de novo"
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

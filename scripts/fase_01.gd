extends Node3D
## Fase 01 — "O Primeiro Graveto".
##
## Ida em visão isométrica → pega o graveto → transição para 3D (terceira pessoa) →
## volta pelo túnel do mato até o dono. Largar o graveto (`largar_graveto`) volta para a
## isométrica; pegar de novo volta para o 3D.
## Grupo "so_3d": nós visíveis só no 3D (ex.: árvores da frente, que tapariam a visão iso).
## Grupo "so_iso": nós que só existem no modo isométrico (ex.: a folhagem que tampa o túnel).
## Escondidos, os filhos de um CSGCombiner3D saem da malha e da colisão — então a mudança
## de perspectiva literalmente abre (ou fecha) o caminho.

@onready var cachorro: Dachshund = $Dachshund
@onready var graveto: Graveto = $Graveto
@onready var camera_controller: CameraController = $CameraController
@onready var area_dono: Area3D = $AreaDono
## Onde não dá para largar o graveto (dentro/perto do túnel, senão as tampas voltariam
## com o cachorro preso lá dentro).
@onready var zona_sem_largar: Area3D = $ZonaSemLargar
@onready var aviso: Label = $HUD/Aviso
@onready var mensagem: Label = $HUD/Mensagem
@onready var dica: Label = $HUD/Dica

const DICA_ISO := "WASD / ←↑↓→: andar    R: reiniciar"
const DICA_3D := "WASD / ←↑↓→: andar    Mouse: câmera    E: largar graveto    Esc: soltar mouse    R: reiniciar"

var concluida := false
var _tween_aviso: Tween


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_mostrar_so_3d(false)
	_mostrar_so_iso(true)
	camera_controller.configurar(cachorro)
	cachorro.camera_referencia = camera_controller.camera
	graveto.pego.connect(_on_graveto_pego)
	area_dono.body_entered.connect(_on_area_dono_body_entered)
	aviso.hide()
	mensagem.hide()
	dica.text = DICA_ISO


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reiniciar"):
		get_tree().reload_current_scene()
	elif event.is_action_pressed("largar_graveto"):
		_tentar_largar_graveto()


func _on_graveto_pego(quem: Dachshund) -> void:
	quem.entrada_bloqueada = true
	# Reparent fora do callback de física da Area3D.
	quem.pegar_graveto.call_deferred(graveto)
	camera_controller.transicionar_para_3d()
	# Abre o túnel no meio do movimento da câmera, quando a mudança passa despercebida.
	_agendar(camera_controller.duracao_transicao * 0.5, _mostrar_so_iso.bind(false))

	await camera_controller.transicao_concluida
	# As árvores da frente só aparecem no fim: no meio do caminho a câmera passaria por elas.
	_mostrar_so_3d(true)
	quem.entrada_bloqueada = false
	dica.text = DICA_3D
	_mostrar_aviso("Nova perspectiva!")
	# Caso tenha largado e pegado o graveto de novo já do lado do dono.
	if area_dono.overlaps_body(cachorro):
		_concluir()


func _tentar_largar_graveto() -> void:
	if concluida or not cachorro.tem_graveto \
			or camera_controller.estado != CameraController.Estado.TERCEIRA_PESSOA:
		return
	if zona_sem_largar.overlaps_body(cachorro):
		_mostrar_aviso("Aqui não dá para largar o graveto")
		return

	cachorro.entrada_bloqueada = true
	var boca := cachorro.boca.global_position
	cachorro.largar_graveto()
	graveto.reparent(self)
	# No chão, na frente do focinho, ainda atravessado em relação ao cachorro.
	graveto.global_transform = Transform3D(
		Basis(Vector3.UP, cachorro.modelo.rotation.y),
		Vector3(boca.x, cachorro.global_position.y + 0.08, boca.z))
	graveto.soltar()

	_mostrar_so_3d(false)
	camera_controller.transicionar_para_iso()
	# Fecha o túnel de novo no meio do movimento da câmera.
	_agendar(camera_controller.duracao_transicao * 0.5, _mostrar_so_iso.bind(true))

	await camera_controller.transicao_concluida
	cachorro.entrada_bloqueada = false
	dica.text = DICA_ISO


func _on_area_dono_body_entered(body: Node3D) -> void:
	if body == cachorro and cachorro.tem_graveto:
		_concluir()


func _concluir() -> void:
	if concluida:
		return
	concluida = true
	cachorro.entrada_bloqueada = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	aviso.hide()
	mensagem.text = "Fase concluída! 🦴\nPressione R para jogar de novo"
	mensagem.show()


func _mostrar_so_3d(visivel: bool) -> void:
	for no in get_tree().get_nodes_in_group("so_3d"):
		(no as Node3D).visible = visivel


func _mostrar_so_iso(visivel: bool) -> void:
	for no in get_tree().get_nodes_in_group("so_iso"):
		(no as Node3D).visible = visivel


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

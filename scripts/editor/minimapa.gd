class_name MinimapaEditor
extends Control
## Minimapa do editor de fases (canto de baixo, M liga/desliga): o mapa visto de cima, com a
## cor do bloco mais alto de cada coluna (mais claro quanto mais alto), o Início (branco), o
## graveto (amarelo), o dono (vermelho) e onde a câmera olha. Clicar ou arrastar leva a câmera.
## O desenho é refeito só quando a fase muda (`marcar_desatualizado`), no máximo 4 vezes por
## segundo.

## Maior lado do minimapa (pixels da interface).
const LADO_MAXIMO := 180.0
const INTERVALO := 0.25
## Folga (pixels) até o painel de propriedades e a barra de status.
const MARGEM := 8.0
const COR_FUNDO := Color(0.08, 0.1, 0.12, 0.85)

var editor: EditorFase
## Fica no canto de baixo à direita da vista: à esquerda deste painel e acima da barra.
var painel_direito: Control
var barra_de_baixo: Control
var _textura: ImageTexture
## Canto (x, z) do mapa, em células, e tamanho em células.
var _origem := Vector2i.ZERO
var _tamanho := Vector2i.ONE
var _desatualizado := true
var _espera := 0.0
var _arrastando := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Minimapa: clique para levar a câmera (M esconde)"


func marcar_desatualizado() -> void:
	_desatualizado = true


func _process(delta: float) -> void:
	_espera -= delta
	if _desatualizado and _espera <= 0.0 and visible and editor and editor.terreno:
		_desatualizado = false
		_espera = INTERVALO
		_redesenhar_mapa()
	if painel_direito and barra_de_baixo:
		position = Vector2(painel_direito.position.x, barra_de_baixo.position.y) - size - Vector2.ONE * MARGEM
	queue_redraw()


func _redesenhar_mapa() -> void:
	var terreno := editor.terreno
	var celulas := terreno.get_used_cells()
	if celulas.is_empty():
		_textura = null
		return
	var minimo := Vector2i(celulas[0].x, celulas[0].z)
	var maximo := minimo
	var topo := {}  # Vector2i → [altura, tile]
	var baixo := INF
	var alto := -INF
	for celula in celulas:
		var coluna := Vector2i(celula.x, celula.z)
		minimo = Vector2i(mini(minimo.x, coluna.x), mini(minimo.y, coluna.y))
		maximo = Vector2i(maxi(maximo.x, coluna.x), maxi(maximo.y, coluna.y))
		var tile := terreno.get_cell_item(celula)
		var altura := float(celula.y) + float(EditorFase.TOPO_TILE.get(tile, 1.0))
		if not topo.has(coluna) or altura > topo[coluna][0]:
			topo[coluna] = [altura, tile]
	for coluna: Vector2i in topo:
		baixo = minf(baixo, topo[coluna][0])
		alto = maxf(alto, topo[coluna][0])
	_origem = minimo - Vector2i.ONE
	_tamanho = maximo - minimo + Vector2i(3, 3)
	var imagem := Image.create(_tamanho.x, _tamanho.y, false, Image.FORMAT_RGBA8)
	imagem.fill(COR_FUNDO)
	for coluna: Vector2i in topo:
		var cor: Color = Tiles.definicao(topo[coluna][1]).get("cor", Color.MAGENTA)
		var nivel: float = 0.5 if alto - baixo < 0.01 else (topo[coluna][0] - baixo) / (alto - baixo)
		cor = cor.darkened(0.35 * (1.0 - nivel)) if nivel < 0.5 else cor.lightened(0.35 * (nivel - 0.5))
		imagem.set_pixelv(coluna - _origem, cor)
	if _textura and _textura.get_size() == Vector2(_tamanho):
		_textura.update(imagem)
	else:
		_textura = ImageTexture.create_from_image(imagem)
	var escala := LADO_MAXIMO / float(maxi(_tamanho.x, _tamanho.y))
	size = Vector2(_tamanho) * escala


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COR_FUNDO)
	if _textura == null:
		return
	draw_texture_rect(_textura, Rect2(Vector2.ZERO, size), false)
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.5), false, 1.0)
	var fase := editor.fase
	for objeto in fase.lista_objetos():
		var cor := Color.TRANSPARENT
		var raio := 2.5
		if objeto is InicioCachorro:
			cor = Color.WHITE
			raio = 3.5
		elif objeto is Graveto:
			cor = Color(1.0, 0.85, 0.2) if (objeto as Graveto).lendario else Color(0.85, 0.65, 0.35)
			raio = 3.5 if (objeto as Graveto).lendario else 2.0
		elif objeto is Dono:
			cor = Color(0.95, 0.25, 0.2)
			raio = 3.5
		elif objeto is Ovelha:
			cor = Color(0.95, 0.95, 0.9)
			raio = 2.0
		elif objeto is Arvore:
			cor = Color(0.1, 0.3, 0.12, 0.8)
			raio = 1.5
		if cor.a > 0.0:
			draw_circle(_para_tela(objeto.global_position), raio, cor)
			if raio > 3.0:
				draw_arc(_para_tela(objeto.global_position), raio, 0.0, TAU, 12, Color.BLACK, 1.0)
	# A câmera: o foco e para onde ela olha.
	var camera := editor.camera_editor
	var foco := _para_tela(camera.foco)
	var frente := Vector2(-sin(camera.yaw), -cos(camera.yaw))
	draw_line(foco, foco + frente * 10.0, Color(0.6, 0.9, 1.0), 2.0)
	draw_arc(foco, 4.0, 0.0, TAU, 12, Color(0.6, 0.9, 1.0), 2.0)


func _para_tela(ponto: Vector3) -> Vector2:
	var celulas := Vector2(ponto.x - _origem.x, ponto.z - _origem.y)
	return celulas / Vector2(_tamanho) * size


func _para_mundo(ponto: Vector2) -> Vector2:
	var celulas := ponto / size * Vector2(_tamanho)
	return celulas + Vector2(_origem)


func _gui_input(event: InputEvent) -> void:
	var botao := event as InputEventMouseButton
	if botao and botao.button_index == MOUSE_BUTTON_LEFT:
		_arrastando = botao.pressed
		if botao.pressed:
			_levar_camera(botao.position)
		accept_event()
	elif event is InputEventMouseMotion and _arrastando:
		_levar_camera((event as InputEventMouseMotion).position)
		accept_event()


func _levar_camera(ponto: Vector2) -> void:
	if _textura == null:
		return
	var alvo := _para_mundo(ponto.clamp(Vector2.ZERO, size))
	editor.camera_editor.foco = Vector3(alvo.x, editor.camera_editor.foco.y, alvo.y)

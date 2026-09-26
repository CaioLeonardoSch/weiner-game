class_name SobreposicaoEditor
extends Control
## Desenho 2D por cima da vista 3D do editor: grade da camada, cursor, seleção e os
## objetos que não aparecem no jogo (início do cachorro, zonas, paredes invisíveis).
## Desenhado em 2D, na resolução da janela, fica nítido por cima do 3D pixelado.

const COR_GRADE := Color(1, 1, 1, 0.13)
const COR_COLOCAR := Color(0.45, 1.0, 0.45)
const COR_APAGAR := Color(1.0, 0.35, 0.3)
const COR_PINTAR := Color(1.0, 0.85, 0.3)
const COR_SELECAO := Color(1.0, 0.85, 0.2)
const COR_SOB_MOUSE := Color(1, 1, 1, 0.8)
const COR_REGRAS := Color(0.35, 0.85, 1.0)
const COR_SO_ISO := Color(1.0, 0.45, 0.95)
const COR_SO_3D := Color(0.4, 0.9, 1.0)

var editor: EditorFase
var camera: Camera3D


func _draw() -> void:
	if editor == null or camera == null or editor.fase == null:
		return
	_desenhar_grade()
	_desenhar_objetos_especiais()
	_desenhar_cursor()


func _desenhar_grade() -> void:
	if not editor.alvo_valido:
		return
	var centro: Vector3i = editor.celula_alvo
	var y := float(editor.camada_da_grade())
	var raio := 8
	for i in range(-raio, raio + 2):
		var x := float(centro.x + i)
		var z := float(centro.z + i)
		_linha(Vector3(x, y, centro.z - raio), Vector3(x, y, centro.z + raio + 1), COR_GRADE, 1.0)
		_linha(Vector3(centro.x - raio, y, z), Vector3(centro.x + raio + 1, y, z), COR_GRADE, 1.0)


func _desenhar_cursor() -> void:
	if not editor.alvo_valido:
		return
	match editor.modo:
		EditorFase.Modo.TERRENO:
			if editor.acao_do_cursor() == "apagar":
				if editor.atingiu_bloco:
					_caixa(AABB(Vector3(editor.celula_atingida), Vector3.ONE), Transform3D.IDENTITY, COR_APAGAR, 2.0)
			elif editor.acao_do_cursor() == "pintar":
				if editor.atingiu_bloco:
					_caixa(AABB(Vector3(editor.celula_atingida), Vector3.ONE), Transform3D.IDENTITY, COR_PINTAR, 2.0)
			else:
				_caixa(AABB(Vector3(editor.celula_alvo), Vector3.ONE), Transform3D.IDENTITY, COR_COLOCAR, 2.0)
				_seta_orientacao(Vector3(editor.celula_alvo) + Vector3(0.5, 0.02, 0.5), editor.orientacao * PI * 0.5, COR_COLOCAR)
	var sob: ObjetoFase = editor.objeto_sob_mouse
	if sob and sob != editor.selecionado and editor.modo != EditorFase.Modo.TERRENO:
		var cor := COR_APAGAR if editor.acao_do_cursor() == "apagar" else COR_SOB_MOUSE
		_caixa(editor.caixa_local(sob), sob.global_transform, cor, 1.5)
		_texto(sob.global_position + Vector3.UP * (editor.caixa_local(sob).end.y + 0.2) * sob.scale.y, sob.nome_no_editor(), cor)
	var selecionado: ObjetoFase = editor.selecionado
	if selecionado and is_instance_valid(selecionado):
		_caixa(editor.caixa_local(selecionado), selecionado.global_transform, COR_SELECAO, 2.0)


## Objetos invisíveis no jogo e marcas de visibilidade (só iso / só 3D).
func _desenhar_objetos_especiais() -> void:
	for objeto in editor.fase.lista_objetos():
		if not objeto.visible:
			continue
		if objeto is InicioCachorro:
			_caixa(objeto.caixa_editor(), objeto.global_transform, COR_REGRAS, 1.5)
			_seta_orientacao(objeto.global_position + Vector3.UP * 0.02, objeto.global_rotation.y, COR_REGRAS)
			_texto(objeto.global_position + Vector3.UP * 0.8, "Início", COR_REGRAS)
		elif objeto is ZonaSemLargar or objeto is ParedeInvisivel:
			var cor := COR_REGRAS if objeto is ZonaSemLargar else Color(0.8, 0.8, 0.8)
			_caixa(objeto.caixa_editor(), objeto.global_transform, cor, 1.0)
			_texto(objeto.global_position + Vector3.UP * (objeto.caixa_editor().end.y + 0.1), objeto.nome_no_editor(), cor)
		if objeto.visibilidade != ObjetoFase.Visibilidade.SEMPRE:
			var cor := COR_SO_ISO if objeto.visibilidade == ObjetoFase.Visibilidade.SO_ISO else COR_SO_3D
			var topo: Vector3 = objeto.global_position + Vector3.UP * (editor.caixa_local(objeto).end.y * objeto.scale.y + 0.15)
			if not camera.is_position_behind(topo):
				var p := camera.unproject_position(topo)
				draw_colored_polygon(PackedVector2Array([p + Vector2(0, -5), p + Vector2(5, 0), p + Vector2(0, 5), p + Vector2(-5, 0)]), cor)


func _seta_orientacao(origem: Vector3, yaw: float, cor: Color) -> void:
	var frente := Vector3(cos(yaw), 0.0, -sin(yaw))
	var lado := Vector3(-frente.z, 0.0, frente.x)
	var ponta := origem + frente * 0.45
	_linha(origem - frente * 0.3, ponta, cor, 2.0)
	_linha(ponta, ponta - frente * 0.2 + lado * 0.15, cor, 2.0)
	_linha(ponta, ponta - frente * 0.2 - lado * 0.15, cor, 2.0)


func _caixa(caixa: AABB, transformacao: Transform3D, cor: Color, largura: float) -> void:
	var cantos: Array[Vector3] = []
	for i in 8:
		cantos.append(transformacao * caixa.get_endpoint(i))
	# Arestas de uma AABB pelos índices de get_endpoint (bits: x=4, y=2, z=1).
	for par in [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]:
		_linha(cantos[par[0]], cantos[par[1]], cor, largura)


func _linha(a: Vector3, b: Vector3, cor: Color, largura: float) -> void:
	if camera.is_position_behind(a) or camera.is_position_behind(b):
		return
	draw_line(camera.unproject_position(a), camera.unproject_position(b), cor, largura)


func _texto(posicao: Vector3, texto: String, cor: Color) -> void:
	if camera.is_position_behind(posicao):
		return
	var fonte := get_theme_default_font()
	var p := camera.unproject_position(posicao)
	var largura := fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string_outline(fonte, p - Vector2(largura * 0.5, 0), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color.BLACK)
	draw_string(fonte, p - Vector2(largura * 0.5, 0), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, cor)

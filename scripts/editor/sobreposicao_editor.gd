class_name SobreposicaoEditor
extends Control
## Desenho 2D por cima da vista 3D do editor: grade da camada, cursor, seleção e os
## objetos que não aparecem no jogo (início do cachorro, zonas, paredes invisíveis).
## Desenhado em 2D, na resolução da janela, fica nítido por cima do 3D pixelado.
## Sem textos em cima dos objetos (atrapalham a vista): o nome do que está sob o mouse vai para
## a barra de status. Só medidas passageiras (retângulo, linha, trecho) aparecem escritas.

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


## Retângulo do trecho marcado (ou sendo marcado) e a caixa do que vai ser colado.
func _desenhar_trecho() -> void:
	if editor.modo == EditorFase.Modo.TRECHO and editor.tem_trecho:
		var cantos: Array[Vector2i] = editor.cantos_do_trecho()
		var camadas: Vector2i = editor.camadas_trecho
		var caixa := AABB(Vector3(cantos[0].x, camadas.x, cantos[0].y),
			Vector3(cantos[1].x - cantos[0].x + 1, camadas.y - camadas.x + 1, cantos[1].y - cantos[0].y + 1))
		_caixa(caixa, Transform3D.IDENTITY, COR_SELECAO, 2.0)
		_texto(caixa.get_center() + Vector3.UP * (caixa.size.y * 0.5 + 0.5), "%d × %d" % [caixa.size.x, caixa.size.z], COR_SELECAO)
	elif editor.modo == EditorFase.Modo.COLAR and editor.colagem and editor.alvo_valido:
		var colagem: Trecho = editor.colagem
		var camadas := colagem.camadas()
		var origem: Vector3i = editor.origem_colagem
		var caixa := AABB(Vector3(origem.x, origem.y + camadas.x, origem.z),
			Vector3(colagem.largura, camadas.y - camadas.x + 1, colagem.profundidade))
		_caixa(caixa, Transform3D.IDENTITY, COR_COLOCAR, 2.0)


func _desenhar_cursor() -> void:
	_desenhar_trecho()
	if not editor.alvo_valido:
		return
	match editor.modo:
		EditorFase.Modo.TERRENO:
			var retangulo = editor.retangulo_em_andamento()
			if editor.linha_ativa:
				var celulas: Array[Vector3i] = editor.celulas_da_linha()
				var cor := COR_APAGAR if editor.acao_do_cursor() == "apagar" else COR_COLOCAR
				var fim := Vector3(celulas[-1]) + Vector3(0.5, 1.2, 0.5)
				_texto(fim, "%d" % celulas.size(), cor)
			elif retangulo != null:
				var cor := COR_APAGAR if editor.acao_do_cursor() == "apagar" else \
					(COR_PINTAR if editor.acao_do_cursor() == "pintar" else COR_COLOCAR)
				_caixa(retangulo, Transform3D.IDENTITY, cor, 2.0)
				var tamanho: Vector3 = retangulo.size
				_texto(retangulo.get_center() + Vector3.UP, "%d × %d" % [tamanho.x, tamanho.z], cor)
			elif editor.acao_do_cursor() == "apagar":
				if editor.atingiu_bloco:
					_caixa(_area_do_pincel(editor.celula_atingida), Transform3D.IDENTITY, COR_APAGAR, 2.0)
			elif editor.acao_do_cursor() == "pintar":
				if editor.atingiu_bloco:
					_caixa(_area_do_pincel(editor.celula_atingida), Transform3D.IDENTITY, COR_PINTAR, 2.0)
			else:
				_caixa(_area_do_pincel(editor.celula_alvo), Transform3D.IDENTITY, COR_COLOCAR, 2.0)
				_seta_orientacao(Vector3(editor.celula_alvo) + Vector3(0.5, 0.02, 0.5), editor.orientacao * PI * 0.5, COR_COLOCAR)
	var sob: ObjetoFase = editor.objeto_sob_mouse
	if sob and sob != editor.selecionado and editor.modo != EditorFase.Modo.TERRENO:
		var cor := COR_APAGAR if editor.acao_do_cursor() == "apagar" else COR_SOB_MOUSE
		_caixa(editor.caixa_local(sob), sob.global_transform, cor, 1.5)
	var selecionado: ObjetoFase = editor.selecionado
	if selecionado and is_instance_valid(selecionado):
		_caixa(editor.caixa_local(selecionado), selecionado.global_transform, COR_SELECAO, 2.0)


## Objetos invisíveis no jogo e marcas de visibilidade (só iso / só 3D).
func _desenhar_objetos_especiais() -> void:
	_desenhar_canais()
	for objeto in editor.fase.lista_objetos():
		if not objeto.visible:
			continue
		if objeto is InicioCachorro:
			_caixa(objeto.caixa_editor(), objeto.global_transform, COR_REGRAS, 1.5)
			_seta_orientacao(objeto.global_position + Vector3.UP * 0.02, objeto.global_rotation.y, COR_REGRAS)
		if objeto.visibilidade != ObjetoFase.Visibilidade.SEMPRE:
			var cor := COR_SO_ISO if objeto.visibilidade == ObjetoFase.Visibilidade.SO_ISO else COR_SO_3D
			var topo: Vector3 = objeto.global_position + Vector3.UP * (editor.caixa_local(objeto).end.y * objeto.scale.y + 0.15)
			if not camera.is_position_behind(topo):
				var p := camera.unproject_position(topo)
				draw_colored_polygon(PackedVector2Array([p + Vector2(0, -5), p + Vector2(5, 0), p + Vector2(0, 5), p + Vector2(-5, 0)]), cor)


## Linhas tracejadas na cor do canal ligando quem aciona (placas) a quem reage (portões), com a
## regra (OU / E) em cima de quem reage a mais de uma placa. Na ferramenta Ligar, os mecanismos
## ganham uma caixa na cor deles e uma linha sai da primeira peça clicada até o mouse.
func _desenhar_canais() -> void:
	var acionam: Array[ObjetoFase] = []
	var reagem: Array[ObjetoFase] = []
	for objeto in editor.mecanismos():
		(acionam if objeto.papel_no_canal() == "aciona" else reagem).append(objeto)
	for alvo in reagem:
		var canal: int = alvo.get(&"canal")
		var cor := Canais.cor(canal)
		var fontes := 0
		for fonte in acionam:
			if fonte.get(&"canal") != canal:
				continue
			fontes += 1
			_tracejada(fonte.global_position + Vector3.UP * 0.1, alvo.global_position + Vector3.UP * 0.5, cor)
		var todas: bool = alvo.get(&"regra") == Portao.REGRA_TODAS
		# A regra (OU / E) só aparece escrita apontando para o portão ou ligando peças.
		var em_foco := alvo == editor.objeto_sob_mouse or alvo == editor.selecionado or editor.modo == EditorFase.Modo.LIGAR
		if (fontes > 1 or todas) and em_foco:
			var topo := alvo.global_position + Vector3.UP * (editor.caixa_local(alvo).end.y + 0.35)
			_texto(topo, "E (todas)" if todas else "OU (qualquer)", cor)
	if editor.modo != EditorFase.Modo.LIGAR:
		return
	for objeto in acionam + reagem:
		_caixa(editor.caixa_local(objeto), objeto.global_transform, Canais.cor(objeto.get(&"canal")), 1.0)
	var origem: ObjetoFase = editor.ligar_origem
	if origem and is_instance_valid(origem) and origem.is_inside_tree():
		var cor := Canais.cor(origem.get(&"canal"))
		_caixa(editor.caixa_local(origem), origem.global_transform, cor, 3.0)
		var destino: Vector3 = editor.ponto_livre
		if editor.objeto_sob_mouse:
			destino = editor.objeto_sob_mouse.global_position + Vector3.UP * 0.5
		_linha(origem.global_position + Vector3.UP * 0.3, destino, cor, 3.0)


## Caixa do pincel (tamanho × tamanho) em volta da célula do cursor.
func _area_do_pincel(centro: Vector3i) -> AABB:
	var inicio := -(editor.tamanho_pincel - 1) / 2
	return AABB(Vector3(centro.x + inicio, centro.y, centro.z + inicio),
		Vector3(editor.tamanho_pincel, 1, editor.tamanho_pincel))


func _tracejada(a: Vector3, b: Vector3, cor: Color) -> void:
	var partes := maxi(int(a.distance_to(b) / 0.3), 1)
	for i in range(0, partes, 2):
		_linha(a.lerp(b, float(i) / partes), a.lerp(b, float(i + 1) / partes), cor, 2.0)


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

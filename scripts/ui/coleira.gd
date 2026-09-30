class_name Coleira
## Estilo "Coleira" do HUD: peças gordinhas de fundo creme, contorno marrom-escuro e sombra dura
## embaixo, nas cores de uma coleira (vermelho) e da plaquinha de nome (dourado). Títulos e
## teclas em Lilita One; textos em Nunito ExtraBold (fontes OFL, em assets/fontes/).

const CONTORNO := Color("2b1a10")
const VERMELHO := Color("d64a3b")
const DOURADO := Color("f4c24a")
const DOURADO_ESCURO := Color("d9a42f")
const CREME := Color("fffaf0")
const TRILHO := Color("d8e6f2")

static var _fonte_titulo: Font
static var _fonte_texto: Font


## Lilita One: títulos, avisos curtos e teclas.
static func fonte_titulo() -> Font:
	if _fonte_titulo == null:
		_fonte_titulo = load("res://assets/fontes/LilitaOne-Regular.ttf") as Font
	return _fonte_titulo


## Nunito ExtraBold (a fonte é variável: o peso 800 sai do eixo "wght").
static func fonte_texto() -> Font:
	if _fonte_texto == null:
		var variacao := FontVariation.new()
		variacao.base_font = load("res://assets/fontes/Nunito.ttf") as Font
		variacao.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 800}
		_fonte_texto = variacao
	return _fonte_texto


## Caixa com contorno escuro; a sombra dura é a borda de baixo mais grossa.
static func caixa(fundo := CREME, raio := 999, borda := 3, sombra := 3, margem_x := 14.0,
		margem_y := 4.0) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = fundo
	estilo.border_color = CONTORNO
	estilo.set_border_width_all(borda)
	estilo.border_width_bottom = borda + sombra
	estilo.set_corner_radius_all(raio)
	estilo.corner_detail = 10
	estilo.content_margin_left = margem_x
	estilo.content_margin_right = margem_x
	estilo.content_margin_top = margem_y
	estilo.content_margin_bottom = margem_y
	return estilo


## Rótulo com a fonte e as cores do estilo. `contorno` > 0: letra clara contornada (sobre o 3D).
static func rotulo(texto := "", tamanho := 18, cor := CONTORNO, titulo := false, contorno := 0) -> Label:
	var novo := Label.new()
	novo.text = texto
	novo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	novo.add_theme_font_override(&"font", fonte_titulo() if titulo else fonte_texto())
	novo.add_theme_font_size_override(&"font_size", tamanho)
	novo.add_theme_color_override(&"font_color", cor)
	if contorno > 0:
		novo.add_theme_color_override(&"font_outline_color", CONTORNO)
		novo.add_theme_constant_override(&"outline_size", contorno)
		novo.add_theme_color_override(&"font_shadow_color", CONTORNO)
		novo.add_theme_constant_override(&"shadow_offset_x", 0)
		novo.add_theme_constant_override(&"shadow_offset_y", maxi(2, contorno / 3))
	return novo


## Pílula (fundo creme, contorno, sombra) com o que for posto dentro.
static func pilula(fundo := CREME, margem_x := 14.0, margem_y := 4.0) -> PanelContainer:
	var painel := PanelContainer.new()
	painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel.add_theme_stylebox_override(&"panel", caixa(fundo, 999, 3, 3, margem_x, margem_y))
	return painel


## Pílula que começa com uma tecla ou com a plaquinha: pouca margem à esquerda (a peça quase
## encosta na borda) e mais à direita, depois do texto.
static func pilula_com_peca(fundo := CREME) -> PanelContainer:
	var painel := pilula(fundo, 5.0, 4.0)
	(painel.get_theme_stylebox(&"panel") as StyleBoxFlat).content_margin_right = 16.0
	return painel


## Tecla (tampinha creme com a letra em Lilita One). O texto fica no filho "Texto".
static func tecla(texto: String, tamanho := 16) -> PanelContainer:
	var painel := PanelContainer.new()
	painel.name = "Tecla"
	painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel.add_theme_stylebox_override(&"panel", caixa(CREME, 7, 2, 3, 7.0, 1.0))
	painel.custom_minimum_size = Vector2(tamanho * 1.7, 0)
	var letra := rotulo(texto, tamanho, CONTORNO, true)
	letra.name = "Texto"
	letra.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letra.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	painel.add_child(letra)
	return painel


## Linha "[tecla] texto" (a tecla fica no filho "Tecla", o texto no filho "Texto").
static func linha_tecla(tecla_texto: String, texto: String, tamanho := 16, cor := CONTORNO,
		contorno := 0) -> HBoxContainer:
	var linha := HBoxContainer.new()
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linha.add_theme_constant_override(&"separation", 8)
	linha.add_child(tecla(tecla_texto, tamanho))
	var rotulo_texto := rotulo(texto, tamanho, cor, false, contorno)
	rotulo_texto.name = "Texto"
	rotulo_texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	linha.add_child(rotulo_texto)
	return linha


## Troca o texto de uma `linha_tecla`.
static func mudar_linha(linha: HBoxContainer, tecla_texto: String, texto: String) -> void:
	(linha.get_node(^"Tecla/Texto") as Label).text = tecla_texto
	(linha.get_node(^"Texto") as Label).text = texto


## Medidor em pílula (calor, equilíbrio): o nome à esquerda e um trilho à direita. `valor`
## de 0 a 1 enche o trilho (`marcador` = false) ou põe o marcador nessa posição (true).
static func desenhar_medidor(no: Control, nome: String, valor: float, cor: Color, marcador: bool) -> void:
	var tamanho := no.size
	caixa(CREME, 999, 3, 3).draw(no.get_canvas_item(), Rect2(Vector2.ZERO, tamanho))
	var fonte := fonte_texto()
	var letra := 17
	var alto := tamanho.y - 3.0
	var base := alto * 0.5 + fonte.get_ascent(letra) * 0.5 - fonte.get_descent(letra) * 0.35
	no.draw_string(fonte, Vector2(16, base), nome, HORIZONTAL_ALIGNMENT_LEFT, -1, letra, CONTORNO)
	var inicio := 16.0 + maxf(fonte.get_string_size("Equilíbrio", HORIZONTAL_ALIGNMENT_LEFT, -1, letra).x,
		fonte.get_string_size(nome, HORIZONTAL_ALIGNMENT_LEFT, -1, letra).x) + 12.0
	var trilho := Rect2(Vector2(inicio, alto * 0.5 - 8.0), Vector2(tamanho.x - inicio - 8.0, 16.0))
	caixa(TRILHO, 999, 2, 0, 0, 0).draw(no.get_canvas_item(), trilho)
	var dentro := trilho.grow(-2.0)
	if marcador:
		var x := dentro.position.x + clampf(valor, 0.0, 1.0) * (dentro.size.x - 10.0)
		no.draw_rect(Rect2(Vector2(x, dentro.position.y), Vector2(10, dentro.size.y)), cor)
	elif valor > 0.0:
		var cheio := caixa(cor, 999, 0, 0, 0, 0)
		cheio.draw(no.get_canvas_item(), Rect2(dentro.position, Vector2(maxf(dentro.size.x * valor, dentro.size.y), dentro.size.y)))


## A plaquinha de nome do cachorro: medalha dourada com contorno e um osso gravado.
class Plaquinha extends Control:
	func _init(diametro := 34.0) -> void:
		custom_minimum_size = Vector2(diametro, diametro + diametro * 0.08)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		pivot_offset = custom_minimum_size * 0.5


	func _draw() -> void:
		var raio := custom_minimum_size.x * 0.5
		var centro := Vector2(raio, raio)
		var borda := maxf(2.0, raio * 0.09)
		draw_circle(centro + Vector2(0, raio * 0.1), raio, CONTORNO)
		draw_circle(centro, raio, CONTORNO)
		draw_circle(centro, raio - borda, DOURADO_ESCURO)
		draw_circle(centro - Vector2(0, raio * 0.06), raio - borda - raio * 0.04, DOURADO)
		_osso(centro, raio * 1.05, CONTORNO, raio * 0.09)
		_osso(centro, raio * 1.05, CREME, 0.0)


	## Osso deitado de largura `largura`; `engorda` > 0 desenha o contorno (maior).
	func _osso(centro: Vector2, largura: float, cor: Color, engorda: float) -> void:
		var meio := largura * 0.3
		var espessura := largura * 0.13 + engorda * 2.0
		var bolinha := largura * 0.12 + engorda
		draw_rect(Rect2(centro + Vector2(-meio, -espessura * 0.5), Vector2(meio * 2.0, espessura)), cor)
		for lado in [-1.0, 1.0]:
			for alto in [-1.0, 1.0]:
				draw_circle(centro + Vector2(lado * meio, alto * largura * 0.08), bolinha, cor)

class_name TelaOpcoes
extends Control
## Tela de opções (menu principal e pausa): abas Tela, Gráficos, Áudio e Controles.
## Cada controle lê e grava direto no autoload Opcoes, que aplica na hora e salva.

signal fechada

const OPCOES_MODO := [["Janela", "janela"], ["Tela cheia", "tela_cheia"], ["Tela cheia exclusiva", "exclusiva"]]
const OPCOES_TAMANHO := [
	["1280 × 720", Vector2i(1280, 720)], ["1600 × 900", Vector2i(1600, 900)],
	["1920 × 1080", Vector2i(1920, 1080)], ["2560 × 1440", Vector2i(2560, 1440)],
	["3440 × 1440", Vector2i(3440, 1440)], ["3840 × 2160", Vector2i(3840, 2160)],
]
const OPCOES_FPS := [["30", 30], ["60", 60], ["120", 120], ["144", 144], ["165", 165], ["240", 240], ["Sem limite", 0]]
const OPCOES_PIXEL := [["Forte (pixels grandes)", 180], ["Normal", 240], ["Suave", 320], ["Desligado (sem pixelado)", 0]]
const OPCOES_SOMBRAS := [["Desligadas", 0], ["Baixa", 1], ["Alta", 2]]

var _abas: TabContainer
var _botoes_teclas := {}
var _capturando: StringName = &""
var _aviso_teclas: Label


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	# "and_offsets": já dentro da árvore, só as âncoras manteriam o tamanho atual (zero).
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = TemaUI.criar()

	var escurecer := ColorRect.new()
	escurecer.color = Color(0, 0, 0, 0.55)
	escurecer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(escurecer)

	var area := AreaSegura.new()
	add_child(area)
	var margem := MarginContainer.new()
	margem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right"]:
		margem.add_theme_constant_override("margin_" + lado, 48)
	for lado in ["top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 24)
	area.add_child(margem)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 12)
	margem.add_child(coluna)

	var titulo := Label.new()
	titulo.text = "Opções"
	titulo.add_theme_font_size_override("font_size", 34)
	titulo.add_theme_color_override("font_color", TemaUI.COR_DESTAQUE)
	coluna.add_child(titulo)

	_abas = TabContainer.new()
	_abas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	coluna.add_child(_abas)
	_aba_tela()
	_aba_graficos()
	_aba_audio()
	_aba_controles()

	var rodape := HBoxContainer.new()
	rodape.add_theme_constant_override("separation", 10)
	coluna.add_child(rodape)
	var voltar := Button.new()
	voltar.text = "← Voltar"
	voltar.pressed.connect(fechar)
	rodape.add_child(voltar)
	var restaurar := Button.new()
	restaurar.text = "Restaurar esta aba"
	restaurar.pressed.connect(_restaurar_aba)
	rodape.add_child(restaurar)
	voltar.grab_focus.call_deferred()


func fechar() -> void:
	fechada.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if _capturando.is_empty() and event.is_action_pressed("ui_cancel"):
		fechar()
		get_viewport().set_input_as_handled()


# --- Abas ----------------------------------------------------------------------------------

func _nova_aba(nome: String) -> VBoxContainer:
	var rolagem := ScrollContainer.new()
	rolagem.name = nome
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_abas.add_child(rolagem)
	var lista := VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 10)
	rolagem.add_child(lista)
	return lista


func _aba_tela() -> void:
	var lista := _nova_aba("Tela")
	_escolha(lista, "Modo", "tela", "modo", OPCOES_MODO)
	_escolha(lista, "Tamanho da janela", "tela", "tamanho_janela", OPCOES_TAMANHO)
	_marca(lista, "Sincronia vertical (VSync)", "tela", "vsync")
	_escolha(lista, "Limite de quadros por segundo", "tela", "fps_max", OPCOES_FPS)
	_deslizador(lista, "Tamanho da interface", "tela", "escala_interface", Opcoes.ESCALA_MINIMA,
		Opcoes.ESCALA_MAXIMA, 0.05, "%d%%", 100.0)
	_nota(lista, "Em monitores largos (21:9, 32:9) o jogo ocupa a tela toda: o mundo aparece dos lados e a interface fica no centro.")


func _aba_graficos() -> void:
	var lista := _nova_aba("Gráficos")
	_escolha(lista, "Pixelado", "graficos", "pixel", OPCOES_PIXEL)
	_marca(lista, "Contorno nas bordas", "graficos", "contorno")
	_escolha(lista, "Sombras", "graficos", "sombras", OPCOES_SOMBRAS)
	_deslizador(lista, "Brilho", "graficos", "brilho", 0.7, 1.3, 0.05, "%d%%", 100.0)
	_nota(lista, "%s liga e desliga o pixelado a qualquer momento, para comparar." % Teclas.nome(&"alternar_pixel"))


func _aba_audio() -> void:
	var lista := _nova_aba("Áudio")
	_deslizador(lista, "Volume geral", "audio", "geral", 0.0, 1.0, 0.05, "%d%%", 100.0)
	_deslizador(lista, "Música", "audio", "musica", 0.0, 1.0, 0.05, "%d%%", 100.0)
	_deslizador(lista, "Efeitos", "audio", "efeitos", 0.0, 1.0, 0.05, "%d%%", 100.0)
	_deslizador(lista, "Ambiente", "audio", "ambiente", 0.0, 1.0, 0.05, "%d%%", 100.0)
	_marca(lista, "Mudo", "audio", "mudo")
	_nota(lista, "O jogo ainda não tem sons — as opções já ficam guardadas para quando tiver.")


func _aba_controles() -> void:
	var lista := _nova_aba("Controles")
	_deslizador(lista, "Sensibilidade da câmera", "controles", "sensibilidade", 0.3, 3.0, 0.1, "%.1f×", 1.0)
	_marca(lista, "Inverter o eixo vertical da câmera", "controles", "inverter_y")
	var titulo := Label.new()
	titulo.text = "Teclas — clique e aperte a nova tecla (Esc cancela)"
	titulo.add_theme_color_override("font_color", TemaUI.COR_DESTAQUE)
	lista.add_child(titulo)
	for item in Teclas.REMAPEAVEIS:
		var acao: StringName = item[0]
		var botao := Button.new()
		botao.custom_minimum_size.x = 220
		botao.alignment = HORIZONTAL_ALIGNMENT_CENTER
		botao.pressed.connect(_capturar.bind(acao))
		_botoes_teclas[acao] = botao
		_linha(lista, item[1], botao)
	_atualizar_teclas()
	_aviso_teclas = Label.new()
	_aviso_teclas.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	lista.add_child(_aviso_teclas)
	var restaurar := Button.new()
	restaurar.text = "Restaurar as teclas de fábrica"
	restaurar.pressed.connect(func() -> void:
		Opcoes.restaurar_secao("teclas")
		_atualizar_teclas()
		_aviso_teclas.text = "Teclas de fábrica restauradas.")
	lista.add_child(restaurar)
	_nota(lista, "As setas também andam, e o controle (gamepad) continua com o mapeamento de fábrica.")


# --- Controles de cada opção ---------------------------------------------------------------

func _linha(lista: VBoxContainer, titulo: String, controle: Control) -> void:
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 16)
	var rotulo := Label.new()
	rotulo.text = titulo
	rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(rotulo)
	controle.custom_minimum_size.x = maxf(controle.custom_minimum_size.x, 320)
	linha.add_child(controle)
	lista.add_child(linha)


func _nota(lista: VBoxContainer, texto: String) -> void:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo.add_theme_font_size_override("font_size", 16)
	rotulo.add_theme_color_override("font_color", Color(0.65, 0.68, 0.65))
	lista.add_child(rotulo)


func _escolha(lista: VBoxContainer, titulo: String, secao: String, chave: String, opcoes: Array) -> void:
	var botao := OptionButton.new()
	var atual: Variant = Opcoes.valor(secao, chave)
	for i in opcoes.size():
		botao.add_item(opcoes[i][0], i)
		if opcoes[i][1] == atual:
			botao.select(i)
	botao.item_selected.connect(func(indice: int) -> void: Opcoes.definir(secao, chave, opcoes[indice][1]))
	_linha(lista, titulo, botao)


func _marca(lista: VBoxContainer, titulo: String, secao: String, chave: String) -> void:
	var marca := CheckBox.new()
	marca.text = "Ligado"
	marca.button_pressed = bool(Opcoes.valor(secao, chave))
	marca.toggled.connect(func(ligado: bool) -> void: Opcoes.definir(secao, chave, ligado))
	_linha(lista, titulo, marca)


func _deslizador(lista: VBoxContainer, titulo: String, secao: String, chave: String,
		minimo: float, maximo: float, passo: float, formato: String, escala: float) -> void:
	var caixa := HBoxContainer.new()
	var deslizador := HSlider.new()
	deslizador.min_value = minimo
	deslizador.max_value = maximo
	deslizador.step = passo
	deslizador.value = float(Opcoes.valor(secao, chave))
	deslizador.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deslizador.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var valor := Label.new()
	valor.custom_minimum_size.x = 70
	valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var mostrar := func(v: float) -> void:
		valor.text = formato % (roundi(v * escala) if formato.contains("%d") else v * escala)
	mostrar.call(deslizador.value)
	deslizador.value_changed.connect(mostrar)
	# O tamanho da interface só se aplica ao soltar o mouse: mudando a cada passo, o próprio
	# deslizador mudaria de tamanho embaixo do cursor.
	var ao_soltar := chave == "escala_interface"
	deslizador.value_changed.connect(func(v: float) -> void:
		if not (ao_soltar and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
			Opcoes.definir(secao, chave, v))
	if ao_soltar:
		deslizador.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and not e.pressed:
				Opcoes.definir(secao, chave, deslizador.value))
	caixa.add_child(deslizador)
	caixa.add_child(valor)
	caixa.custom_minimum_size.x = 320
	_linha(lista, titulo, caixa)


func _restaurar_aba() -> void:
	var secao: String = ["tela", "graficos", "audio", "controles"][_abas.current_tab]
	Opcoes.restaurar_secao(secao)
	# Remonta a aba com os valores de fábrica.
	var atual := _abas.current_tab
	for filho in _abas.get_children():
		_abas.remove_child(filho)
		filho.queue_free()
	_botoes_teclas.clear()
	_aba_tela()
	_aba_graficos()
	_aba_audio()
	_aba_controles()
	_abas.current_tab = atual


# --- Trocar teclas -------------------------------------------------------------------------

func _capturar(acao: StringName) -> void:
	_capturando = acao
	(_botoes_teclas[acao] as Button).text = "Aperte uma tecla…"
	_aviso_teclas.text = ""


func _input(event: InputEvent) -> void:
	if _capturando.is_empty() or not event.is_pressed() or event.is_echo():
		return
	var evento: InputEvent = null
	if event is InputEventKey:
		var tecla := event as InputEventKey
		if tecla.keycode == KEY_ESCAPE:
			_capturando = &""
			_atualizar_teclas()
			get_viewport().set_input_as_handled()
			return
		var nova := InputEventKey.new()
		nova.physical_keycode = tecla.physical_keycode if tecla.physical_keycode != KEY_NONE else tecla.keycode
		evento = nova
	elif event is InputEventMouseButton:
		var botao := (event as InputEventMouseButton).button_index
		# O clique esquerdo é o que abriu a captura; roda do mouse não serve.
		if botao == MOUSE_BUTTON_LEFT or botao >= MOUSE_BUTTON_WHEEL_UP and botao <= MOUSE_BUTTON_WHEEL_RIGHT:
			return
		var novo := InputEventMouseButton.new()
		novo.button_index = botao
		evento = novo
	if evento == null:
		return
	get_viewport().set_input_as_handled()
	var acao := _capturando
	_capturando = &""
	var trocada := Opcoes.trocar_tecla(acao, evento)
	_atualizar_teclas()
	if not trocada.is_empty():
		_aviso_teclas.text = "A tecla era de \"%s\" — as duas trocaram." % _nome_da_acao(trocada)


func _atualizar_teclas() -> void:
	for acao in _botoes_teclas:
		(_botoes_teclas[acao] as Button).text = Teclas.nome(acao)


static func _nome_da_acao(acao: StringName) -> String:
	for item in Teclas.REMAPEAVEIS:
		if item[0] == acao:
			return item[1]
	return String(acao)

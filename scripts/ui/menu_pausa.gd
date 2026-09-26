class_name MenuPausa
extends CanvasLayer
## Pausa do jogo (Esc): continuar, reiniciar, editar a fase ou voltar ao menu principal.
## Pausa a árvore inteira; só este nó continua recebendo entrada.

var _botoes: VBoxContainer


func _init() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.theme = TemaUI.criar()
	add_child(raiz)

	var escurecer := ColorRect.new()
	escurecer.color = Color(0, 0, 0, 0.45)
	escurecer.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(escurecer)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(centro)

	var painel := PanelContainer.new()
	painel.custom_minimum_size.x = 360
	centro.add_child(painel)
	var margem := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 24)
	painel.add_child(margem)

	_botoes = VBoxContainer.new()
	_botoes.add_theme_constant_override("separation", 8)
	margem.add_child(_botoes)

	var titulo := Label.new()
	titulo.text = "Pausa"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 34)
	titulo.add_theme_color_override("font_color", TemaUI.COR_DESTAQUE)
	_botoes.add_child(titulo)

	_botao("Continuar", fechar)
	_botao("Reiniciar a fase", func() -> void:
		get_tree().paused = false
		get_tree().reload_current_scene())
	if Fases.testando:
		_botao("Voltar ao editor", Fases.abrir_editor)
	else:
		_botao("Editar esta fase", Fases.editar.bind(Fases.caminho_atual))
	_botao("Menu principal", Fases.abrir_menu)
	hide()


func abrir() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show()
	(_botoes.get_child(1) as Button).grab_focus()


func fechar() -> void:
	hide()
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		fechar()
		get_viewport().set_input_as_handled()


func _botao(texto: String, acao: Callable) -> void:
	var botao := Button.new()
	botao.text = texto
	botao.pressed.connect(acao)
	_botoes.add_child(botao)

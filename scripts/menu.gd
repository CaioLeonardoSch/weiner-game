extends Node3D
## Menu principal: continuar, escolher fase, escolher a pelagem do cachorro, abrir o editor
## (fase existente ou nova).
##
## Ao fundo, a primeira fase com o cachorro e a câmera girando devagar. A interface é montada por código
## (tema em `scripts/ui/tema_ui.gd`), então para mudar cores e tamanhos não é preciso abrir cena nenhuma.

const COR_TITULO := TemaUI.COR_DESTAQUE
const VELOCIDADE_ORBITA := 0.06
const RAIO_ORBITA := 14.0
const ALTURA_ORBITA := 9.5

@onready var camera: Camera3D = $Camera3D
@onready var ui: CanvasLayer = $UI

var _tela: VBoxContainer
var _titulo_tela: Label
var _angulo := 0.8
var _centro := Vector3.ZERO
var _cachorro: ModeloCachorro
## Enquadramento da câmera: geral (fase) ou de perto (tela do cachorro). Muda suavemente.
var _perto := false
var _mistura := 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_montar_fundo()
	_montar_interface()
	_tela_principal()


func _process(delta: float) -> void:
	_angulo += VELOCIDADE_ORBITA * delta * (2.5 if _perto else 1.0)
	_mistura = move_toward(_mistura, 1.0 if _perto else 0.0, delta * 1.5)
	var t := smoothstep(0.0, 1.0, _mistura)
	var perto := _cachorro.global_position + Vector3.UP * 0.35 if _cachorro else _centro
	var centro := _centro.lerp(perto, t)
	var raio := lerpf(RAIO_ORBITA, 2.6, t)
	var altura := lerpf(ALTURA_ORBITA, 1.1, t)
	camera.position = centro + Vector3(cos(_angulo) * raio, altura, sin(_angulo) * raio)
	camera.look_at(centro)
	# A interface fica à esquerda: desloca a imagem para o centro ficar à direita dela.
	camera.h_offset = lerpf(-3.0, -0.75, t)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _titulo_tela.visible:
		_tela_principal()
		get_viewport().set_input_as_handled()


# --- Fundo -------------------------------------------------------------------------------

func _montar_fundo() -> void:
	var lista := Fases.listar()
	if lista.is_empty():
		return
	var cena := ResourceLoader.load(lista[0], "PackedScene") as PackedScene
	var fase := cena.instantiate() as Fase if cena else null
	if fase == null:
		return
	add_child(fase)
	fase.process_mode = Node.PROCESS_MODE_DISABLED
	fase.preparar_isometrica()
	var inicio := fase.primeiro(InicioCachorro)
	var graveto := fase.primeiro(Graveto)
	if inicio and graveto:
		_centro = inicio.global_position.lerp(graveto.global_position, 0.35)
	elif inicio:
		_centro = inicio.global_position
	if inicio:
		_cachorro = ModeloCachorro.new()
		add_child(_cachorro)
		_cachorro.global_position = inicio.global_position
		_cachorro.rotation.y = inicio.global_rotation.y
		_mostrar_cachorro(Racas.por_id(Racas.PADRAO))


# --- Interface ---------------------------------------------------------------------------

func _montar_interface() -> void:
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.theme = TemaUI.criar()
	ui.add_child(raiz)

	var painel := PanelContainer.new()
	painel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	painel.custom_minimum_size.x = 440
	raiz.add_child(painel)

	var margem := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 28)
	painel.add_child(margem)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 10)
	margem.add_child(coluna)

	var titulo := Label.new()
	titulo.text = "Weiner Game"
	titulo.add_theme_font_size_override("font_size", 54)
	titulo.add_theme_color_override("font_color", COR_TITULO)
	titulo.add_theme_color_override("font_outline_color", Color.BLACK)
	titulo.add_theme_constant_override("outline_size", 12)
	coluna.add_child(titulo)

	var subtitulo := Label.new()
	subtitulo.text = "o salsicha e os gravetos lendários"
	subtitulo.add_theme_color_override("font_color", Color(0.8, 0.84, 0.8))
	coluna.add_child(subtitulo)

	var espaco := Control.new()
	espaco.custom_minimum_size.y = 18
	coluna.add_child(espaco)

	_titulo_tela = Label.new()
	_titulo_tela.add_theme_font_size_override("font_size", 28)
	_titulo_tela.add_theme_color_override("font_color", COR_TITULO)
	coluna.add_child(_titulo_tela)

	var rolagem := ScrollContainer.new()
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	coluna.add_child(rolagem)

	_tela = VBoxContainer.new()
	_tela.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tela.add_theme_constant_override("separation", 8)
	rolagem.add_child(_tela)

	var rodape := Label.new()
	rodape.text = "Setas/Enter ou mouse  ·  Esc: voltar  ·  F3: pixelado"
	rodape.add_theme_font_size_override("font_size", 15)
	rodape.add_theme_color_override("font_color", Color(0.7, 0.72, 0.7))
	coluna.add_child(rodape)


func _limpar(titulo: String) -> void:
	if _perto and titulo != "Cachorro":
		_perto = false
		_mostrar_cachorro(Racas.por_id(Racas.PADRAO))
	for filho in _tela.get_children():
		_tela.remove_child(filho)
		filho.queue_free()
	_titulo_tela.text = titulo
	_titulo_tela.visible = not titulo.is_empty()


func _botao(texto: String, acao: Callable, pai: Control = null) -> Button:
	if pai == null:
		pai = _tela
	var botao := Button.new()
	botao.text = texto
	botao.alignment = HORIZONTAL_ALIGNMENT_LEFT
	botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	botao.pressed.connect(acao)
	pai.add_child(botao)
	return botao


func _rotulo(texto: String) -> Label:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo.add_theme_color_override("font_color", Color(0.75, 0.78, 0.75))
	_tela.add_child(rotulo)
	return rotulo


func _focar_primeiro() -> void:
	for filho in _tela.get_children():
		var botao := filho as Button
		if botao == null and filho is HBoxContainer:
			botao = filho.get_child(filho.get_child_count() - 2) as Button
		if botao and not botao.disabled:
			botao.grab_focus.call_deferred()
			return


# --- Telas -------------------------------------------------------------------------------

func _tela_principal() -> void:
	_limpar("")
	var lista := Fases.listar()
	var continuar := Fases.fase_para_continuar()
	if continuar.is_empty():
		_rotulo("Nenhuma fase ainda — crie a primeira no editor.")
	else:
		var alguma_feita := Array(lista).any(func(c: String) -> bool: return Fases.concluida(c))
		var texto := "▶  Continuar: " if alguma_feita else "▶  Jogar: "
		_botao(texto + _nome_curto(continuar), Fases.jogar.bind(continuar))
	_botao("Fases", _tela_fases).disabled = lista.is_empty()
	_botao("Cachorro", _tela_cachorro)
	_botao("Editor de fases", _tela_editor)
	if not OS.has_feature("web"):
		_botao("Sair", get_tree().quit)
	_focar_primeiro()


func _tela_cachorro() -> void:
	_limpar("Cachorro")
	_perto = true
	for raca in Racas.todas():
		var titulo := Label.new()
		titulo.text = raca.nome
		titulo.add_theme_font_size_override("font_size", 22)
		titulo.add_theme_color_override("font_color", COR_TITULO)
		_tela.add_child(titulo)
		if not raca.descricao.is_empty():
			_rotulo(raca.descricao)
		var escolhida := Racas.pelagem_escolhida(raca)
		for i in raca.pelagens.size():
			var marca := "✓  " if i == escolhida else "     "
			var botao := _botao(marca + raca.pelagens[i].nome, _escolher_pelagem.bind(raca, i))
			# Passar o mouse ou o foco por uma pelagem já mostra no cachorro.
			botao.mouse_entered.connect(_mostrar_cachorro.bind(raca, i))
			botao.focus_entered.connect(_mostrar_cachorro.bind(raca, i))
	_rotulo("A raça de cada fase é escolhida no editor (propriedades da fase).")
	var voltar := _botao("← Voltar", _tela_principal)
	voltar.focus_entered.connect(_mostrar_cachorro.bind(Racas.por_id(Racas.PADRAO)))
	_focar_primeiro()


func _escolher_pelagem(raca: Raca, indice: int) -> void:
	Racas.escolher_pelagem(raca, indice)
	var foco := get_viewport().gui_get_focus_owner()
	var indice_foco := foco.get_index() if foco else -1
	_tela_cachorro()
	if indice_foco >= 0 and indice_foco < _tela.get_child_count():
		(_tela.get_child(indice_foco) as Control).grab_focus.call_deferred()
	_mostrar_cachorro(raca, indice)


func _mostrar_cachorro(raca: Raca, indice := -1) -> void:
	if _cachorro == null or raca == null:
		return
	_cachorro.montar(raca, Racas.pelagem_escolhida(raca) if indice < 0 else indice)


func _tela_fases() -> void:
	_limpar("Fases")
	for caminho in Fases.listar():
		var linha := HBoxContainer.new()
		linha.add_theme_constant_override("separation", 6)
		_tela.add_child(linha)
		var marca := Label.new()
		marca.text = "✓" if Fases.concluida(caminho) else "·"
		marca.custom_minimum_size.x = 22
		marca.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		marca.add_theme_color_override("font_color", Color(0.5, 0.9, 0.45) if Fases.concluida(caminho) else Color(0.5, 0.5, 0.5))
		linha.add_child(marca)
		_botao(_nome(caminho), Fases.jogar.bind(caminho), linha)
		var editar := _botao("Editar", Fases.editar.bind(caminho), linha)
		editar.size_flags_horizontal = Control.SIZE_SHRINK_END
		editar.tooltip_text = "Abrir esta fase no editor"
	_botao("← Voltar", _tela_principal)
	_focar_primeiro()


func _tela_editor() -> void:
	_limpar("Editor de fases")
	_botao("+  Nova fase (do zero)", Fases.editar.bind(""))
	var lista := Fases.listar()
	if not lista.is_empty():
		_rotulo("Editar uma fase existente:")
		for caminho in lista:
			_botao(_nome(caminho), Fases.editar.bind(caminho))
	_rotulo("No editor: H mostra os atalhos, F1 testa a fase e o botão ◀ Menu volta para cá.")
	_botao("← Voltar", _tela_principal)
	_focar_primeiro()


func _nome(caminho: String) -> String:
	var nome := Fases.nome_da_fase(caminho)
	return nome + ("  (sua)" if caminho.begins_with(Fases.PASTA_USUARIO) else "")


## "Fase 02 — A Pinguela" → "A Pinguela" (o número já aparece na lista de fases).
func _nome_curto(caminho: String) -> String:
	var nome := Fases.nome_da_fase(caminho)
	var partes := nome.split("—", false, 1)
	return partes[1].strip_edges() if partes.size() == 2 else nome

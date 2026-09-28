extends Node3D
## Menu principal: continuar, escolher região → raça → fase, escolher a pelagem (só aparência),
## abrir o editor (fase existente ou nova).
##
## Antes de jogar, a tela da região (ou "antes de jogar", no Continuar e ao chegar numa região
## nova) mostra a história da região e as raças compatíveis (Regiao.racas); a escolhida fica
## guardada por região no progresso e é a do cachorro no jogo.
##
## Ao fundo, uma fase (a da região escolhida) com o cachorro e a câmera girando devagar. A interface é montada por código
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
## A fase montada ao fundo, e os nós dela (trocados ao escolher outra região).
var _caminho_fundo := ""
var _fundo: Array[Node] = []
## Tela para onde Esc volta.
var _voltar := Callable()


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_montar_interface()
	var pendente := Fases.antes_de_jogar_pendente
	Fases.antes_de_jogar_pendente = ""
	if not pendente.is_empty() and pendente in Fases.listar():
		_tela_antes_de_jogar(pendente)
	else:
		var lista := Fases.listar()
		_montar_fundo(lista[0] if not lista.is_empty() else "")
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
	if event.is_action_pressed("ui_cancel") and _voltar.is_valid():
		_voltar.call()
		get_viewport().set_input_as_handled()


# --- Fundo -------------------------------------------------------------------------------

## Monta a fase `caminho` ao fundo (no lugar da que estava), com o cachorro no início dela.
func _montar_fundo(caminho: String) -> void:
	if caminho == _caminho_fundo or caminho.is_empty():
		return
	var cena := ResourceLoader.load(caminho, "PackedScene") as PackedScene
	var fase := cena.instantiate() as Fase if cena else null
	if fase == null:
		return
	for no in _fundo:
		no.queue_free()
	_fundo.clear()
	_caminho_fundo = caminho
	_cachorro = null
	_centro = Vector3.ZERO
	add_child(fase)
	_fundo.append(fase)
	fase.process_mode = Node.PROCESS_MODE_DISABLED
	fase.preparar_isometrica()
	Biomas.aplicar_ambiente(get_node_or_null(^"Ambiente"), fase.bioma)
	var entorno := Entorno.new()
	add_child(entorno)
	_fundo.append(entorno)
	entorno.montar(fase)
	var inicio := fase.primeiro(InicioCachorro)
	var graveto := fase.primeiro(Graveto)
	if inicio and graveto:
		_centro = inicio.global_position.lerp(graveto.global_position, 0.35)
	elif inicio:
		_centro = inicio.global_position
	if inicio:
		_cachorro = ModeloCachorro.new()
		add_child(_cachorro)
		_fundo.append(_cachorro)
		_cachorro.global_position = inicio.global_position
		_cachorro.rotation.y = inicio.global_rotation.y
		_mostrar_cachorro(Fases.raca_para_jogar(caminho))


# --- Interface ---------------------------------------------------------------------------

func _montar_interface() -> void:
	# Área segura: em monitores largos o menu fica no centro, e o 3D preenche a tela toda.
	var raiz := AreaSegura.new()
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.theme = TemaUI.criar()
	ui.add_child(raiz)

	var painel := PanelContainer.new()
	painel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	painel.custom_minimum_size.x = 440
	raiz.add_child(painel)

	var margem := MarginContainer.new()
	# Margens e espaços contidos: com a interface em 125% o menu inteiro ainda cabe na altura.
	for lado in ["left", "right"]:
		margem.add_theme_constant_override("margin_" + lado, 28)
	for lado in ["top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 20)
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
	espaco.custom_minimum_size.y = 10
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
	_tela.add_theme_constant_override("separation", 6)
	rolagem.add_child(_tela)

	var rodape := Label.new()
	rodape.text = "Setas/Enter ou mouse  ·  Esc: voltar  ·  %s: pixelado" % Teclas.nome(&"alternar_pixel")
	rodape.add_theme_font_size_override("font_size", 15)
	rodape.add_theme_color_override("font_color", Color(0.7, 0.72, 0.7))
	coluna.add_child(rodape)


## Esvazia a tela. `perto`: a câmera chega perto do cachorro (telas de raça e pelagem);
## `voltar`: para onde Esc leva.
func _limpar(titulo: String, perto := false, voltar := Callable()) -> void:
	_perto = perto
	_voltar = voltar
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


## Um título de seção dentro da tela ("Raça", "Fases", nome da região...).
func _secao(texto: String) -> Label:
	var titulo := Label.new()
	titulo.text = texto
	titulo.add_theme_font_size_override("font_size", 22)
	titulo.add_theme_color_override("font_color", COR_TITULO)
	_tela.add_child(titulo)
	return titulo


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
		_botao(texto + _nome_curto(continuar), _tela_antes_de_jogar.bind(continuar))
		_mostrar_cachorro(Fases.raca_para_jogar(_caminho_fundo if not _caminho_fundo.is_empty() else continuar))
	_botao("Regiões", _tela_regioes).disabled = lista.is_empty()
	_botao("Pelagens", _tela_pelagens)
	_botao("Opções", _abrir_opcoes)
	_botao("Editor de fases", _tela_editor)
	if not OS.has_feature("web"):
		_botao("Sair", get_tree().quit)
	_focar_primeiro()


func _abrir_opcoes() -> void:
	var tela := TelaOpcoes.new()
	var painel := ui.get_child(0) as Control
	painel.hide()
	tela.fechada.connect(func() -> void:
		painel.show()
		_tela_principal())
	ui.add_child(tela)


## Antes de jogar uma fase (Continuar, região nova, "Trocar de raça" na pausa): a história da
## região, a raça (entre as compatíveis) e Jogar.
func _tela_antes_de_jogar(caminho: String) -> void:
	var regiao := Regioes.por_id(Fases.regiao_da_fase(caminho))
	_limpar(regiao.nome if regiao else "Jogar", true, _tela_principal)
	_montar_fundo(caminho)
	var nome := Label.new()
	nome.text = _nome(caminho)
	nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nome.add_theme_font_size_override("font_size", 20)
	_tela.add_child(nome)
	if regiao and not regiao.descricao.is_empty():
		_rotulo(regiao.descricao).add_theme_font_size_override("font_size", 15)
	_escolha_da_raca(caminho, regiao, _tela_antes_de_jogar.bind(caminho))
	var jogar := _botao("▶  Jogar", Fases.jogar.bind(caminho))
	jogar.name = "Jogar"
	if regiao:
		_botao("Outras fases de %s" % regiao.nome, _tela_regiao.bind(regiao))
	_botao("← Voltar", _tela_principal)
	jogar.grab_focus.call_deferred()


## As regiões, na ordem: quantas fases já foram feitas e com que raças se joga cada uma.
func _tela_regioes() -> void:
	_limpar("Regiões", false, _tela_principal)
	for regiao in Regioes.todas():
		var fases := Fases.fases_da_regiao(regiao.id)
		var feitas := Array(fases).filter(func(c: String) -> bool: return Fases.concluida(c)).size()
		var texto := regiao.nome + ("    %d/%d ✓" % [feitas, fases.size()] if not fases.is_empty() else "    em breve")
		var botao := _botao(texto, _tela_regiao.bind(regiao))
		botao.disabled = fases.is_empty()
		var racas := regiao.racas_compativeis().map(func(r: Raca) -> String: return r.nome)
		var detalhe := _rotulo("Raças: " + ", ".join(racas))
		detalhe.add_theme_font_size_override("font_size", 15)
		if fases.is_empty() and OS.has_feature("editor"):
			# Para quem joga, "em breve"; a dica do editor só rodando pelo Godot.
			_rotulo("Nenhuma fase ainda — crie no editor (painel da fase → Região: %s)." % regiao.nome) \
				.add_theme_font_size_override("font_size", 15)
	# Fases de uma região que não existe (arquivo apagado, id trocado) não somem do menu.
	if not _fases_avulsas().is_empty():
		_botao("Outras    %d fase(s)" % _fases_avulsas().size(), _tela_regiao.bind(null))
	_botao("← Voltar", _tela_principal)
	_focar_primeiro()


## Uma região: a história, a raça e as fases (✓ = feita com a raça escolhida; ✓ apagado = feita
## com outra raça).
func _tela_regiao(regiao: Regiao) -> void:
	_limpar(regiao.nome if regiao else "Outras", true, _tela_regioes)
	var fases := Fases.fases_da_regiao(regiao.id) if regiao else PackedStringArray(_fases_avulsas())
	var proxima := ""
	for caminho in fases:
		if not Fases.concluida(caminho):
			proxima = caminho
			break
	if proxima.is_empty() and not fases.is_empty():
		proxima = fases[0]
	_montar_fundo(proxima)
	if regiao and not regiao.descricao.is_empty():
		_rotulo(regiao.descricao).add_theme_font_size_override("font_size", 15)
	if regiao:
		_escolha_da_raca("", regiao, _tela_regiao.bind(regiao))
	_secao("Fases")
	var raca := Fases.raca_da_regiao(regiao.id) if regiao else Racas.por_id(Racas.PADRAO)
	var foco: Button = null
	for caminho in fases:
		var botao := _linha_fase(caminho, raca)
		if caminho == proxima:
			foco = botao
	_botao("← Voltar", _tela_regioes)
	if foco and get_viewport().gui_get_focus_owner() == null:
		foco.grab_focus.call_deferred()
	elif foco == null:
		_focar_primeiro()


## "Raça": um botão por raça compatível (✓ na escolhida; passar o mouse ou o foco mostra o
## cachorro), a descrição e a pelagem. Numa fase de raça fixa, só diz qual é.
func _escolha_da_raca(caminho: String, regiao: Regiao, remontar: Callable) -> void:
	_secao("Raça")
	if not caminho.is_empty() and Fases.raca_fixa(caminho):
		var fixa := Fases.raca_para_jogar(caminho)
		_rotulo("Nesta fase você é o %s. %s" % [fixa.nome, fixa.descricao])
		_mostrar_cachorro(fixa)
		return
	if regiao == null:
		return
	var escolhida := Fases.raca_da_regiao(regiao.id)
	var linha := HFlowContainer.new()
	linha.add_theme_constant_override("h_separation", 6)
	linha.add_theme_constant_override("v_separation", 6)
	_tela.add_child(linha)
	for raca in regiao.racas_compativeis():
		var botao := _botao(("✓ " if raca == escolhida else "") + raca.nome,
			_escolher_raca.bind(regiao, raca, remontar), linha)
		botao.name = "Raca_" + raca.id
		botao.size_flags_horizontal = Control.SIZE_FILL
		botao.alignment = HORIZONTAL_ALIGNMENT_CENTER
		botao.custom_minimum_size.x = 120
		botao.mouse_entered.connect(_mostrar_cachorro.bind(raca))
		botao.focus_entered.connect(_mostrar_cachorro.bind(raca))
		botao.mouse_exited.connect(_mostrar_cachorro.bind(escolhida))
	var sobre := escolhida.descricao
	var nativas := _habilidades_nativas(escolhida)
	if not nativas.is_empty():
		sobre += " Já sabe %s." % nativas
	sobre += "\nPelagem: %s (troque em Pelagens, no menu principal)." % \
		escolhida.pelagem(Racas.pelagem_escolhida(escolhida)).nome
	_rotulo(sobre).add_theme_font_size_override("font_size", 15)
	_mostrar_cachorro(escolhida)


func _escolher_raca(regiao: Regiao, raca: Raca, remontar: Callable) -> void:
	Fases.escolher_raca(regiao.id, raca.id)
	remontar.call()
	# O foco fica no botão da raça (a tela foi remontada).
	var botao := _tela.find_child("Raca_" + raca.id, true, false) as Button
	if botao:
		botao.grab_focus.call_deferred()


func _habilidades_nativas(raca: Raca) -> String:
	var nomes: PackedStringArray = []
	for i in 3:
		if raca.habilidades_nativas & (1 << i):
			nomes.append(["pular", "cavar", "latir"][i])
	return ", ".join(nomes)


## A pelagem de cada raça: só aparência.
func _tela_pelagens() -> void:
	_limpar("Pelagens", true, _tela_principal)
	_rotulo("Só a aparência: a raça se escolhe antes de jogar, entre as da região.") \
		.add_theme_font_size_override("font_size", 15)
	for raca in Racas.todas():
		_secao(raca.nome)
		var escolhida := Racas.pelagem_escolhida(raca)
		for i in raca.pelagens.size():
			var marca := "✓  " if i == escolhida else "     "
			var botao := _botao(marca + raca.pelagens[i].nome, _escolher_pelagem.bind(raca, i))
			# Passar o mouse ou o foco por uma pelagem já mostra no cachorro.
			botao.mouse_entered.connect(_mostrar_cachorro.bind(raca, i))
			botao.focus_entered.connect(_mostrar_cachorro.bind(raca, i))
	_botao("← Voltar", _tela_principal)
	_focar_primeiro()


func _escolher_pelagem(raca: Raca, indice: int) -> void:
	Racas.escolher_pelagem(raca, indice)
	var foco := get_viewport().gui_get_focus_owner()
	var indice_foco := foco.get_index() if foco else -1
	_tela_pelagens()
	if indice_foco >= 0 and indice_foco < _tela.get_child_count():
		(_tela.get_child(indice_foco) as Control).grab_focus.call_deferred()
	_mostrar_cachorro(raca, indice)


func _mostrar_cachorro(raca: Raca, indice := -1) -> void:
	if _cachorro == null or raca == null:
		return
	_cachorro.montar(raca, Racas.pelagem_escolhida(raca) if indice < 0 else indice)


func _fases_avulsas() -> Array:
	return Array(Fases.listar()).filter(func(c: String) -> bool:
		return Regioes.por_id(Fases.regiao_da_fase(c)) == null)


func _cabecalho_regiao(regiao: Regiao) -> void:
	_secao(regiao.nome if regiao else "Outras")


## Uma fase da região: ✓ (verde = feita com esta raça; apagado = com outra), o nome (com a raça,
## se for fixa) e Editar. Devolve o botão de jogar.
func _linha_fase(caminho: String, raca: Raca) -> Button:
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 6)
	_tela.add_child(linha)
	var fixa := Fases.raca_fixa(caminho)
	var com_esta := Fases.concluida_com(caminho, Fases.raca_para_jogar(caminho).id if fixa else raca.id)
	var marca := Label.new()
	marca.custom_minimum_size.x = 22
	marca.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if com_esta or (fixa and Fases.concluida(caminho)):
		marca.text = "✓"
		marca.add_theme_color_override("font_color", Color(0.5, 0.9, 0.45))
	elif Fases.concluida(caminho):
		marca.text = "✓"
		marca.add_theme_color_override("font_color", Color(0.45, 0.55, 0.45))
	else:
		marca.text = "·"
		marca.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	linha.add_child(marca)
	var texto := _nome(caminho)
	if fixa:
		texto += "  (%s)" % Fases.raca_para_jogar(caminho).nome
	var jogar := _botao(texto, Fases.jogar.bind(caminho), linha)
	var feitas := Array(Fases.racas_que_concluiram(caminho)).map(func(id: String) -> String:
		return Racas.por_id(StringName(id)).nome)
	if not feitas.is_empty():
		jogar.tooltip_text = "Feita com: " + ", ".join(feitas)
	elif Fases.concluida(caminho):
		jogar.tooltip_text = "Feita"
	var editar := _botao("Editar", Fases.editar.bind(caminho), linha)
	editar.size_flags_horizontal = Control.SIZE_SHRINK_END
	editar.tooltip_text = "Abrir esta fase no editor"
	return jogar


func _tela_editor() -> void:
	_limpar("Editor de fases", false, _tela_principal)
	_botao("+  Nova fase (do zero)", Fases.editar.bind(""))
	var lista := Fases.listar()
	if not lista.is_empty():
		_rotulo("Editar uma fase existente:")
		var regiao_atual := &""
		for caminho in lista:
			var regiao := Fases.regiao_da_fase(caminho)
			if regiao != regiao_atual:
				regiao_atual = regiao
				_cabecalho_regiao(Regioes.por_id(regiao))
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

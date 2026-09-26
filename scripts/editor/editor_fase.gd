class_name EditorFase
extends Node3D
## Editor de fases dentro do jogo (F1 abre/fecha, a partir do jogo ou daqui).
##
## Terreno: blocos de 1 m numa grade (GridMap). Clique esquerdo coloca o tile escolhido
## em cima/ao lado do bloco apontado (ou no plano da camada atual, se não houver bloco);
## arrastar pinta na mesma camada. Clique direito apaga; Shift + clique troca o tile.
## Objetos: escolha na paleta e clique para colocar; a ferramenta Selecionar (Esc) seleciona,
## arrasta e mostra as propriedades no painel da direita.
## Tudo passa pelo desfazer/refazer (Ctrl+Z / Ctrl+Y). Ctrl+S salva em scenes/fases/.
## F1 testa a fase como está (sem salvar) e volta para cá no mesmo ponto.

enum Modo { SELECAO, TERRENO, OBJETO }
enum Visao { TUDO, ISO, TERCEIRA }

const NOMES_VISAO := ["tudo", "isométrica", "3D"]
## Quanto (pixels) o mouse anda com o botão apertado até virar arrasto: um clique só seleciona.
const DISTANCIA_INICIO_ARRASTO := 6.0
## Altura do topo de cada tile (para apoiar objetos em cima); o padrão é 1 (bloco cheio).
const TOPO_TILE := {
	Tiles.MEIO_BLOCO: 0.5, Tiles.MATO_BAIXO: 0.5, Tiles.RAMPA_BAIXA: 0.25,
	Tiles.RAMPA_ALTA: 0.75, Tiles.AGUA: 0.85, Tiles.TABUA: 0.0,
}

var fase: Fase
var terreno: GridMap
## Arquivo da fase ("" = ainda não salva).
var caminho := ""
var modificado := false
var undo := UndoRedo.new()
var rng := RandomNumberGenerator.new()

var modo := Modo.TERRENO
var tile_atual := Tiles.GRAMA
## Giro do tile em quartos de volta (0 a 3).
var orientacao := 0
var entrada_objeto: Dictionary
## Prévia do objeto que será colocado (não faz parte da fase).
var fantasma: ObjetoFase
var camada := 0
var visao := Visao.TUDO

# Estado do cursor, recalculado a cada quadro.
var alvo_valido := false
var celula_alvo := Vector3i.ZERO
var celula_atingida := Vector3i.ZERO
var atingiu_bloco := false
var ponto_alvo := Vector3.ZERO
var objeto_sob_mouse: ObjetoFase
var selecionado: ObjetoFase

# Arrastos em andamento.
var _pincel := ""  # "", "colocar", "apagar", "pintar"
var _camada_pincel := 0
var _mudancas_pincel := {}  # Vector3i → [item antigo, orientação antiga, item novo, orientação nova]
var _arrastando_objeto := false
## Só vira true depois de o mouse andar DISTANCIA_INICIO_ARRASTO desde o clique.
var _arrasto_iniciado := false
var _mouse_inicio_arrasto := Vector2.ZERO
var _transform_antes_arrasto: Transform3D
var _altura_arrasto := 0.0
var _orbitando := false
var _caixas := {}  # cache de caixa_editor() por objeto
var _catalogo: Array[Dictionary] = []
var _botoes_paleta := ButtonGroup.new()
var _tween_aviso: Tween

@onready var camera_editor: CameraEditor = $CameraEditor
@onready var camera: Camera3D = $CameraEditor/Camera3D
@onready var icones: GeradorIcones = $Icones
@onready var sobreposicao: SobreposicaoEditor = $UI/Sobreposicao
@onready var paleta: VBoxContainer = %Paleta
@onready var inspetor: InspetorEditor = %Inspetor
@onready var status: Label = %Status
@onready var campo_nome: LineEdit = %NomeFase
@onready var botao_visao: Button = %BotaoVisao
@onready var menu_abrir: MenuButton = %BotaoAbrir
@onready var confirmar: ConfirmationDialog = %Confirmar
@onready var ajuda: Control = %Ajuda
@onready var aviso: Label = %Aviso


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	rng.randomize()
	sobreposicao.editor = self
	sobreposicao.camera = camera
	undo.version_changed.connect(_on_versao_mudou)
	inspetor.propriedade_alterada.connect(_alterar_propriedade)
	inspetor.pedido_apagar.connect(_apagar_selecionado)
	inspetor.pedido_duplicar.connect(_duplicar_selecionado)
	campo_nome.text_submitted.connect(func(_texto: String) -> void: campo_nome.release_focus())
	campo_nome.focus_exited.connect(_renomear_fase)
	%BotaoNova.pressed.connect(_confirmar_se_modificado.bind(_nova_fase))
	%BotaoSalvar.pressed.connect(_salvar)
	%BotaoSalvarComo.pressed.connect(_salvar_como)
	%BotaoTestar.pressed.connect(_testar)
	%BotaoAjuda.pressed.connect(func() -> void: ajuda.visible = not ajuda.visible)
	botao_visao.pressed.connect(_proxima_visao)
	menu_abrir.about_to_popup.connect(_preencher_menu_abrir)
	menu_abrir.get_popup().id_pressed.connect(_on_menu_abrir)
	ajuda.hide()
	aviso.hide()

	_catalogo = Catalogo.objetos()
	_montar_paleta()

	var cena := Fases.cena_atual()
	caminho = Fases.caminho_atual
	if cena:
		_carregar(cena.instantiate(Fase.estado_de_edicao(true)) as Fase)
		modificado = Fases.rascunho != null and Fases.rascunho_modificado
	else:
		_carregar(_fase_modelo("Fase nova"))
		caminho = ""
		modificado = true
	Fases.rascunho = null
	_restaurar_estado(Fases.estado_editor)
	_atualizar_status()


func _exit_tree() -> void:
	# UndoRedo não é contado por referência: libera o histórico (e os objetos apagados que
	# só ele guardava) e depois ele mesmo. Sem mudar a versão: a cena já está saindo.
	undo.clear_history(false)
	undo.free()


# --- Carregar / salvar / testar ----------------------------------------------------------

func _carregar(nova: Fase) -> void:
	undo.clear_history()
	_selecionar(null)
	if fase:
		remove_child(fase)
		fase.queue_free()
	fase = nova
	add_child(fase)
	# Parada: nada de graveto girando ou áreas funcionando enquanto edita.
	fase.process_mode = Node.PROCESS_MODE_DISABLED
	terreno = fase.terreno
	campo_nome.text = fase.nome
	_caixas.clear()
	_aplicar_visao()
	_selecionar(null)
	var inicio := fase.primeiro(InicioCachorro)
	camera_editor.foco = inicio.global_position if inicio else Vector3.ZERO


## Fase nova: um gramado com o início, o dono, o graveto e algumas árvores.
func _fase_modelo(nome: String) -> Fase:
	var nova := Fase.nova(nome)
	var chao := nova.get_node("Terreno") as GridMap
	for x in range(-8, 13):
		for z in range(-6, 4):
			chao.set_cell_item(Vector3i(x, -1, z), Tiles.GRAMA)
	nova.adicionar_objeto(load(Catalogo.PASTA + "inicio_cachorro.tscn"), Vector3(-3.5, 0, -1.5))
	nova.adicionar_objeto(load(Catalogo.PASTA + "dono.tscn"), Vector3(-5.5, 0, -1.5), deg_to_rad(-60.0))
	var graveto := nova.adicionar_objeto(load(Catalogo.PASTA + "graveto.tscn"), Vector3(8.5, 0.08, -1.5))
	graveto.position.y = 0.08
	var cena_arvore: PackedScene = load(Catalogo.PASTA + "arvore.tscn")
	for posicao in [Vector3(-7, 0, -5), Vector3(-2, 0, -5.5), Vector3(4, 0, -5), Vector3(10, 0, -5.5), Vector3(11, 0, 2)]:
		var arvore := nova.adicionar_objeto(cena_arvore, posicao)
		arvore.ao_colocar_no_editor(rng)
	return nova


func _nova_fase() -> void:
	_carregar(_fase_modelo("Fase nova"))
	caminho = ""
	modificado = true
	_avisar("Fase nova — dê um nome e salve (Ctrl+S)")
	_atualizar_status()


func _preencher_menu_abrir() -> void:
	var menu := menu_abrir.get_popup()
	menu.clear()
	var lista := Fases.listar()
	for i in lista.size():
		menu.add_item(lista[i].get_file().get_basename() + ("  (usuário)" if lista[i].begins_with("user://") else ""), i)
		menu.set_item_metadata(menu.get_item_index(i), lista[i])
	if lista.is_empty():
		menu.add_item("(nenhuma fase salva)", -1)
		menu.set_item_disabled(0, true)


func _on_menu_abrir(id: int) -> void:
	var menu := menu_abrir.get_popup()
	var alvo: String = menu.get_item_metadata(menu.get_item_index(id))
	_confirmar_se_modificado(func() -> void:
		var cena := ResourceLoader.load(alvo, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		var nova: Fase = null
		if cena:
			nova = cena.instantiate(Fase.estado_de_edicao(true)) as Fase
		if nova == null:
			_avisar("Não consegui abrir %s" % alvo.get_file())
			return
		_carregar(nova)
		caminho = alvo
		Fases.caminho_atual = alvo
		modificado = false
		_avisar("Aberta: %s" % alvo.get_file())
		_atualizar_status())


func _confirmar_se_modificado(acao: Callable) -> void:
	if not modificado:
		acao.call()
		return
	confirmar.dialog_text = "Há alterações não salvas nesta fase. Continuar e perdê-las?"
	for conexao in confirmar.confirmed.get_connections():
		confirmar.confirmed.disconnect(conexao.callable)
	confirmar.confirmed.connect(acao, CONNECT_ONE_SHOT)
	confirmar.popup_centered()


## Empacota a fase no estado "limpo" (tudo visível, processamento normal) para salvar/testar.
func _empacotar() -> PackedScene:
	var visao_antes := visao
	visao = Visao.TUDO
	_aplicar_visao()
	fase.process_mode = Node.PROCESS_MODE_INHERIT
	var cena := PackedScene.new()
	var erro := cena.pack(fase)
	fase.process_mode = Node.PROCESS_MODE_DISABLED
	visao = visao_antes
	_aplicar_visao()
	if erro != OK:
		_avisar("Erro ao empacotar a fase: %s" % error_string(erro))
		return null
	return cena


## Salva por cima do arquivo da fase. Fase nova (ou só de leitura, no jogo exportado): "Salvar como".
func _salvar() -> void:
	if caminho.is_empty() or not _pode_gravar(caminho):
		_salvar_como()
	else:
		_gravar(caminho)


## Salva num arquivo novo com o nome da fase ("Fase 02 — A ponte!" → fase_02_a_ponte.tscn).
## É assim que se cria uma fase a partir de outra: abrir, renomear, Salvar como.
func _salvar_como() -> void:
	_renomear_fase()
	var arquivo := _nome_de_arquivo(fase.nome)
	if arquivo.is_empty():
		_avisar("Dê um nome à fase antes de salvar")
		return
	var pasta := Fases.pasta_para_salvar()
	var destino := pasta + arquivo + ".tscn"
	var numero := 2
	while destino != caminho and FileAccess.file_exists(destino):
		destino = pasta + "%s_%d.tscn" % [arquivo, numero]
		numero += 1
	_gravar(destino)


func _gravar(destino: String) -> void:
	_renomear_fase()
	var cena := _empacotar()
	if cena == null:
		return
	DirAccess.make_dir_recursive_absolute(destino.get_base_dir())
	var erro := ResourceSaver.save(cena, destino)
	if erro != OK:
		_avisar("Não consegui salvar em %s (%s)" % [destino, error_string(erro)])
		return
	caminho = destino
	Fases.caminho_atual = destino
	modificado = false
	_avisar("Salva: %s" % destino)
	_atualizar_status()


## A pasta do projeto é só leitura no jogo exportado.
static func _pode_gravar(arquivo: String) -> bool:
	return not (arquivo.begins_with("res://") and OS.has_feature("template"))


## "Fase 02 — A ponte!" → "fase_02_a_ponte".
static func _nome_de_arquivo(nome: String) -> String:
	var texto := nome.strip_edges().to_lower()
	var trocas := {"á": "a", "à": "a", "â": "a", "ã": "a", "é": "e", "ê": "e", "í": "i",
		"ó": "o", "ô": "o", "õ": "o", "ú": "u", "ü": "u", "ç": "c"}
	for letra in trocas:
		texto = texto.replace(letra, trocas[letra])
	var resultado := ""
	for letra in texto:
		var valida := (letra >= "a" and letra <= "z") or (letra >= "0" and letra <= "9")
		if valida:
			resultado += letra
		elif not resultado.is_empty() and not resultado.ends_with("_"):
			resultado += "_"
	return resultado.trim_suffix("_")


func _testar() -> void:
	var cena := _empacotar()
	if cena == null:
		return
	Fases.caminho_atual = caminho
	Fases.estado_editor = _estado()
	Fases.testar(cena, modificado)


func _estado() -> Dictionary:
	return {
		fase = caminho, camera = camera_editor.estado(), modo = modo, tile = tile_atual, orientacao = orientacao,
		camada = camada, objeto = entrada_objeto.get("caminho", ""), visao = visao,
	}


func _restaurar_estado(estado: Dictionary) -> void:
	if estado.is_empty():
		_escolher_tile(tile_atual)
		return
	# A câmera só volta para onde estava se for a mesma fase.
	if estado.fase == caminho:
		camera_editor.restaurar(estado.camera)
	camada = estado.camada
	orientacao = estado.orientacao
	visao = estado.visao
	_aplicar_visao()
	match estado.modo:
		Modo.OBJETO:
			for entrada in _catalogo:
				if entrada.caminho == estado.objeto:
					_escolher_objeto(entrada)
		Modo.SELECAO:
			_escolher_selecao()
		_:
			_escolher_tile(estado.tile)
	_marcar_botao_da_ferramenta()


# --- Paleta ------------------------------------------------------------------------------

func _montar_paleta() -> void:
	var selecionar := _botao_paleta("Selecionar (Esc)", null)
	selecionar.set_meta(&"ferramenta", "selecao")
	selecionar.pressed.connect(_escolher_selecao)

	_cabecalho("Terreno")
	var biblioteca: MeshLibrary = load(Tiles.CAMINHO_BIBLIOTECA)
	for definicao in Tiles.definicoes():
		var botao := _botao_paleta(definicao.nome, icones.icone_tile(biblioteca, definicao.id))
		botao.set_meta(&"ferramenta", "tile_%d" % definicao.id)
		botao.pressed.connect(_escolher_tile.bind(definicao.id))

	var categoria := ""
	for entrada in _catalogo:
		if entrada.categoria != categoria:
			categoria = entrada.categoria
			_cabecalho(categoria)
		var amostra := entrada.cena.instantiate() as ObjetoFase
		var botao := _botao_paleta(entrada.nome, icones.icone(amostra))
		botao.set_meta(&"ferramenta", entrada.caminho)
		botao.pressed.connect(_escolher_objeto.bind(entrada))


func _cabecalho(texto: String) -> void:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	paleta.add_child(rotulo)


func _botao_paleta(texto: String, icone: Texture2D) -> Button:
	var botao := Button.new()
	botao.text = texto
	botao.icon = icone
	botao.toggle_mode = true
	botao.button_group = _botoes_paleta
	botao.alignment = HORIZONTAL_ALIGNMENT_LEFT
	botao.expand_icon = false
	botao.focus_mode = Control.FOCUS_NONE
	paleta.add_child(botao)
	return botao


func _marcar_botao_da_ferramenta() -> void:
	var chave := "selecao"
	match modo:
		Modo.TERRENO:
			chave = "tile_%d" % tile_atual
		Modo.OBJETO:
			chave = entrada_objeto.get("caminho", "")
	for botao in _botoes_paleta.get_buttons():
		botao.set_pressed_no_signal(botao.get_meta(&"ferramenta") == chave)


func _escolher_selecao() -> void:
	modo = Modo.SELECAO
	_trocar_fantasma(null)
	_marcar_botao_da_ferramenta()
	_atualizar_status()


func _escolher_tile(id: int) -> void:
	modo = Modo.TERRENO
	tile_atual = id
	_trocar_fantasma(null)
	_selecionar(null)
	_marcar_botao_da_ferramenta()
	_atualizar_status()


func _escolher_objeto(entrada: Dictionary) -> void:
	modo = Modo.OBJETO
	entrada_objeto = entrada
	_trocar_fantasma(entrada.cena)
	_marcar_botao_da_ferramenta()
	_atualizar_status()


func _trocar_fantasma(cena: PackedScene) -> void:
	if fantasma:
		fantasma.queue_free()
		fantasma = null
	if cena:
		fantasma = cena.instantiate() as ObjetoFase
		fantasma.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(fantasma)
		fantasma.ao_colocar_no_editor(rng)
		fantasma.hide()


# --- Entrada -----------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	# Clicou na vista 3D: tira o foco do campo de texto (senão WASD escreve no nome).
	if event is InputEventMouseButton and event.pressed:
		get_viewport().gui_release_focus()
	if event.is_action_pressed("alternar_editor"):
		_testar()
	elif event.is_action_pressed("editor_salvar"):
		_salvar()
	elif event.is_action_pressed("editor_refazer"):
		undo.redo()
	elif event.is_action_pressed("editor_desfazer"):
		undo.undo()
	elif event.is_action_pressed("editor_duplicar"):
		_duplicar_selecionado()
	elif event.is_action_pressed("editor_apagar"):
		_apagar_selecionado()
	elif event.is_action_pressed("liberar_mouse"):
		# Esc: fecha a ajuda; senão vai para a ferramenta Selecionar; já nela, desmarca.
		if ajuda.visible:
			ajuda.hide()
		elif modo != Modo.SELECAO:
			_escolher_selecao()
		else:
			_selecionar(null)
	elif event.is_action_pressed("editor_ajuda"):
		ajuda.visible = not ajuda.visible
	elif event.is_action_pressed("editor_perspectiva"):
		_proxima_visao()
	elif event.is_action_pressed("editor_centralizar"):
		var inicio := fase.primeiro(InicioCachorro)
		camera_editor.foco = inicio.global_position if inicio else Vector3.ZERO
	elif event.is_action_pressed("editor_camada_subir"):
		camada += 1
		_atualizar_status()
	elif event.is_action_pressed("editor_camada_descer"):
		camada -= 1
		_atualizar_status()
	elif event.is_action_pressed("editor_girar_esquerda"):
		_girar(1)
	elif event.is_action_pressed("editor_girar_direita"):
		_girar(-1)
	elif event.is_action_pressed("editor_zoom_mais"):
		camera_editor.zoom(1.0 / 1.12)
	elif event.is_action_pressed("editor_zoom_menos"):
		camera_editor.zoom(1.12)
	elif event.is_action_pressed("editor_orbitar"):
		_orbitando = true
	elif event.is_action_released("editor_orbitar"):
		_orbitando = false
	elif event is InputEventMouseMotion and _orbitando:
		var relativo := (event as InputEventMouseMotion).relative
		if Input.is_action_pressed("editor_mod_shift"):
			camera_editor.arrastar(relativo)
		else:
			camera_editor.orbitar(relativo)
	elif event.is_action_pressed("editor_acao"):
		_atualizar_alvo()
		_acao_principal()
	elif event.is_action_released("editor_acao"):
		_terminar_arrastos()
	elif event.is_action_pressed("editor_remover"):
		_atualizar_alvo()
		_acao_remover()
	elif event.is_action_released("editor_remover"):
		_terminar_arrastos()


func _process(_delta: float) -> void:
	# Botão solto em cima de um painel: o evento não chega aqui, então confere o estado.
	if (_pincel != "" or _arrastando_objeto) \
			and not Input.is_action_pressed("editor_acao") and not Input.is_action_pressed("editor_remover"):
		_terminar_arrastos()
	_orbitando = _orbitando and Input.is_action_pressed("editor_orbitar")

	_atualizar_alvo()
	if _pincel != "" and alvo_valido:
		_continuar_pincel()
	if _arrastando_objeto and selecionado:
		_continuar_arrasto_objeto()
	if fantasma:
		fantasma.visible = modo == Modo.OBJETO and alvo_valido
		if fantasma.visible:
			fantasma.position = ponto_alvo + Vector3.UP * _altura_extra(fantasma)
	sobreposicao.queue_redraw()


## O que o clique faria agora (para o cursor): "colocar", "apagar" ou "pintar".
func acao_do_cursor() -> String:
	if Input.is_action_pressed("editor_remover") or _pincel == "apagar":
		return "apagar"
	if modo == Modo.TERRENO and (Input.is_action_pressed("editor_mod_shift") or _pincel == "pintar"):
		return "pintar"
	return "colocar"


## Camada em que a grade é desenhada.
func camada_da_grade() -> int:
	if _pincel != "":
		return _camada_pincel + (1 if _pincel != "colocar" else 0)
	return celula_alvo.y if modo == Modo.TERRENO else camada


func _acao_principal() -> void:
	if not alvo_valido:
		return
	match modo:
		Modo.TERRENO:
			if acao_do_cursor() == "pintar":
				if atingiu_bloco:
					_comecar_pincel("pintar", celula_atingida.y)
			else:
				_comecar_pincel("colocar", celula_alvo.y)
		Modo.OBJETO:
			_colocar_objeto()
		Modo.SELECAO:
			_selecionar(objeto_sob_mouse)
			if selecionado:
				_arrastando_objeto = true
				_arrasto_iniciado = false
				_mouse_inicio_arrasto = get_viewport().get_mouse_position()
				_transform_antes_arrasto = selecionado.transform
				_altura_arrasto = _altura_extra(selecionado)


func _acao_remover() -> void:
	if modo == Modo.TERRENO:
		if atingiu_bloco:
			_comecar_pincel("apagar", celula_atingida.y)
	elif objeto_sob_mouse:
		_remover_objeto(objeto_sob_mouse)


func _terminar_arrastos() -> void:
	if _pincel != "":
		_terminar_pincel()
	if _arrastando_objeto:
		_arrastando_objeto = false
		if selecionado and selecionado.transform != _transform_antes_arrasto:
			undo.create_action("Mover %s" % selecionado.nome_no_editor())
			undo.add_do_property(selecionado, &"transform", selecionado.transform)
			undo.add_undo_property(selecionado, &"transform", _transform_antes_arrasto)
			undo.commit_action(false)


func _girar(sentido: int) -> void:
	var passo := 15.0 if Input.is_action_pressed("editor_mod_shift") else 45.0
	if modo == Modo.TERRENO:
		orientacao = posmod(orientacao + sentido, 4)
	elif modo == Modo.OBJETO and fantasma:
		fantasma.rotation.y += deg_to_rad(passo) * sentido
	elif selecionado:
		var giro := selecionado.rotation
		giro.y = wrapf(giro.y + deg_to_rad(passo) * sentido, -PI, PI)
		_alterar_propriedade(selecionado, &"rotation", giro)
	_atualizar_status()


# --- Mira (raio do mouse) ----------------------------------------------------------------

func _atualizar_alvo() -> void:
	alvo_valido = false
	objeto_sob_mouse = null
	if get_viewport().gui_get_hovered_control() != null or fase == null:
		return
	var mouse := get_viewport().get_mouse_position()
	var origem := camera.project_ray_origin(mouse)
	var direcao := camera.project_ray_normal(mouse)

	if modo != Modo.TERRENO:
		objeto_sob_mouse = _objeto_no_raio(origem, direcao)

	var bloco := _raio_na_grade(origem, direcao, 300.0)
	var t_plano := -1.0
	if absf(direcao.y) > 0.0001:
		t_plano = (camada - origem.y) / direcao.y
	atingiu_bloco = not bloco.is_empty() and (t_plano < 0.0 or bloco.t <= t_plano + 0.001)

	if atingiu_bloco:
		celula_atingida = bloco.celula
		celula_alvo = bloco.celula + bloco.normal
		var topo: float = bloco.celula.y + TOPO_TILE.get(terreno.get_cell_item(bloco.celula), 1.0)
		if bloco.normal == Vector3i.UP:
			var ponto: Vector3 = origem + direcao * bloco.t
			ponto_alvo = Vector3(ponto.x, topo, ponto.z)
		else:
			ponto_alvo = Vector3(celula_alvo) + Vector3(0.5, 0.0, 0.5)
	elif t_plano > 0.0:
		ponto_alvo = origem + direcao * t_plano
		celula_alvo = Vector3i(floori(ponto_alvo.x), camada, floori(ponto_alvo.z))
	else:
		return
	# Objetos ficam no centro da célula; com Alt, livres.
	if not Input.is_action_pressed("editor_mod_alt"):
		ponto_alvo.x = floorf(ponto_alvo.x) + 0.5
		ponto_alvo.z = floorf(ponto_alvo.z) + 0.5
	alvo_valido = true


## Percorre as células da grade ao longo do raio (algoritmo DDA) até achar um bloco.
## Devolve {celula, normal (face por onde o raio entrou), t} ou {}.
func _raio_na_grade(origem: Vector3, direcao: Vector3, alcance: float) -> Dictionary:
	var o := terreno.to_local(origem)
	var d := (terreno.global_basis.inverse() * direcao).normalized()
	var celula := Vector3i(floori(o.x), floori(o.y), floori(o.z))
	var passo := Vector3i(int(signf(d.x)), int(signf(d.y)), int(signf(d.z)))
	var t_max := Vector3(INF, INF, INF)
	var t_delta := Vector3(INF, INF, INF)
	for eixo in 3:
		if absf(d[eixo]) > 0.000001:
			var fronteira := float(celula[eixo] + (1 if passo[eixo] > 0 else 0))
			t_max[eixo] = (fronteira - o[eixo]) / d[eixo]
			t_delta[eixo] = absf(1.0 / d[eixo])
	var normal := Vector3i.ZERO
	var t := 0.0
	while t <= alcance:
		if normal != Vector3i.ZERO and terreno.get_cell_item(celula) != GridMap.INVALID_CELL_ITEM:
			return {celula = celula, normal = normal, t = t}
		var eixo := 0
		if t_max.y < t_max[eixo]:
			eixo = 1
		if t_max.z < t_max[eixo]:
			eixo = 2
		t = t_max[eixo]
		t_max[eixo] += t_delta[eixo]
		celula[eixo] += passo[eixo]
		normal = Vector3i.ZERO
		normal[eixo] = -passo[eixo]
	return {}


## Objeto cuja caixa o raio acerta primeiro (zonas e paredes invisíveis só se nada mais).
func _objeto_no_raio(origem: Vector3, direcao: Vector3) -> ObjetoFase:
	var melhor: ObjetoFase = null
	var melhor_prioridade := -1
	var menor := INF
	for objeto in fase.lista_objetos():
		if not objeto.visible or (_arrastando_objeto and objeto == selecionado):
			continue
		var caixa := objeto.global_transform * caixa_local(objeto)
		var ponto = caixa.intersects_ray(origem, direcao)
		if ponto == null:
			# Começando dentro da caixa (câmera dentro de uma zona) não conta.
			continue
		var prioridade := objeto.prioridade_no_editor()
		var distancia := origem.distance_to(ponto)
		if prioridade > melhor_prioridade or (prioridade == melhor_prioridade and distancia < menor):
			melhor_prioridade = prioridade
			menor = distancia
			melhor = objeto
	return melhor


## caixa_editor() do objeto, com cache (algumas somam várias malhas).
func caixa_local(objeto: ObjetoFase) -> AABB:
	var id := objeto.get_instance_id()
	if not _caixas.has(id):
		_caixas[id] = objeto.caixa_editor()
	return _caixas[id]


## Quanto o objeto fica acima do chão (o graveto, por exemplo, fica um pouco levantado).
func _altura_extra(objeto: ObjetoFase) -> float:
	return 0.08 if objeto is Graveto else 0.0


# --- Terreno -----------------------------------------------------------------------------

func _comecar_pincel(tipo: String, camada_pincel: int) -> void:
	_pincel = tipo
	_camada_pincel = camada_pincel
	_mudancas_pincel.clear()
	_aplicar_pincel(celula_atingida if tipo != "colocar" else celula_alvo)


## Durante o arrasto, a pintura fica presa na camada em que começou.
func _continuar_pincel() -> void:
	var mouse := get_viewport().get_mouse_position()
	var origem := camera.project_ray_origin(mouse)
	var direcao := camera.project_ray_normal(mouse)
	if absf(direcao.y) < 0.0001:
		return
	# Colocar: plano da base da camada; apagar/pintar: plano do topo dos blocos da camada.
	var altura := float(_camada_pincel) + (0.0 if _pincel == "colocar" else 1.0)
	var t := (altura - origem.y) / direcao.y
	if t <= 0.0:
		return
	var ponto := origem + direcao * t
	_aplicar_pincel(Vector3i(floori(ponto.x), _camada_pincel, floori(ponto.z)))


func _aplicar_pincel(celula: Vector3i) -> void:
	var item_antigo := terreno.get_cell_item(celula)
	var orientacao_antiga := terreno.get_cell_item_orientation(celula)
	var item_novo := tile_atual
	var orientacao_nova := terreno.get_orthogonal_index_from_basis(Basis(Vector3.UP, orientacao * PI * 0.5))
	match _pincel:
		"apagar":
			if item_antigo == GridMap.INVALID_CELL_ITEM:
				return
			item_novo = GridMap.INVALID_CELL_ITEM
			orientacao_nova = 0
		"pintar":
			if item_antigo == GridMap.INVALID_CELL_ITEM:
				return
		"colocar":
			if item_antigo != GridMap.INVALID_CELL_ITEM:
				return
	if item_antigo == item_novo and orientacao_antiga == orientacao_nova:
		return
	if not _mudancas_pincel.has(celula):
		_mudancas_pincel[celula] = [item_antigo, orientacao_antiga, item_novo, orientacao_nova]
	else:
		_mudancas_pincel[celula][2] = item_novo
		_mudancas_pincel[celula][3] = orientacao_nova
	terreno.set_cell_item(celula, item_novo, orientacao_nova)


func _terminar_pincel() -> void:
	var tipo := _pincel
	_pincel = ""
	if _mudancas_pincel.is_empty():
		return
	var antes := []
	var depois := []
	for celula in _mudancas_pincel:
		var m: Array = _mudancas_pincel[celula]
		antes.append([celula, m[0], m[1]])
		depois.append([celula, m[2], m[3]])
	var nomes := {"colocar": "Colocar", "apagar": "Apagar", "pintar": "Pintar"}
	undo.create_action("%s %d bloco(s)" % [nomes[tipo], _mudancas_pincel.size()])
	undo.add_do_method(_aplicar_celulas.bind(depois))
	undo.add_undo_method(_aplicar_celulas.bind(antes))
	undo.commit_action(false)
	_mudancas_pincel = {}


func _aplicar_celulas(lista: Array) -> void:
	for dados in lista:
		terreno.set_cell_item(dados[0], dados[1], dados[2])


# --- Objetos -----------------------------------------------------------------------------

func _colocar_objeto() -> void:
	if fantasma == null:
		return
	var objeto := fase.adicionar_objeto(entrada_objeto.cena, fantasma.position, 0.0)
	objeto.transform = fantasma.transform
	objeto.visibilidade = fantasma.visibilidade
	for propriedade in fantasma.propriedades_editaveis():
		objeto.set(propriedade, fantasma.get(propriedade))
	_registrar_adicao(objeto, "Colocar %s" % objeto.nome_no_editor())
	_selecionar(objeto)
	# Próximo com outra variação (árvores, pedras...); objetos sem variação mantêm o giro.
	fantasma.ao_colocar_no_editor(rng)


func _registrar_adicao(objeto: ObjetoFase, nome_acao: String) -> void:
	undo.create_action(nome_acao)
	undo.add_do_method(_readicionar.bind(objeto))
	undo.add_undo_method(_retirar.bind(objeto))
	undo.add_do_reference(objeto)
	undo.commit_action(false)


func _remover_objeto(objeto: ObjetoFase) -> void:
	undo.create_action("Apagar %s" % objeto.nome_no_editor())
	undo.add_do_method(_retirar.bind(objeto))
	undo.add_undo_method(_readicionar.bind(objeto))
	undo.add_undo_reference(objeto)
	undo.commit_action()


func _readicionar(objeto: ObjetoFase) -> void:
	fase.objetos.add_child(objeto)
	objeto.owner = fase


func _retirar(objeto: ObjetoFase) -> void:
	if objeto == selecionado:
		_selecionar(null)
	fase.objetos.remove_child(objeto)


func _apagar_selecionado() -> void:
	if selecionado:
		_remover_objeto(selecionado)


func _duplicar_selecionado() -> void:
	if selecionado == null or selecionado.scene_file_path.is_empty():
		return
	var original := selecionado
	var copia := fase.adicionar_objeto(load(original.scene_file_path), original.position, 0.0)
	copia.transform = original.transform.translated(Vector3(1.0, 0.0, 0.0))
	copia.visibilidade = original.visibilidade
	for propriedade in original.propriedades_editaveis():
		copia.set(propriedade, original.get(propriedade))
	_registrar_adicao(copia, "Duplicar %s" % original.nome_no_editor())
	_selecionar(copia)


func _continuar_arrasto_objeto() -> void:
	if not alvo_valido:
		return
	# Sem isso, só clicar para selecionar já levava o objeto para o ponto do chão sob o
	# mouse (clicando na copa de uma árvore, o chão atrás dela).
	if not _arrasto_iniciado:
		if get_viewport().get_mouse_position().distance_to(_mouse_inicio_arrasto) < DISTANCIA_INICIO_ARRASTO:
			return
		_arrasto_iniciado = true
	var destino := ponto_alvo + Vector3.UP * _altura_arrasto
	if selecionado.position != destino:
		selecionado.position = destino
		inspetor.atualizar_valores()


func _alterar_propriedade(alvo: Object, propriedade: StringName, valor: Variant) -> void:
	var antigo: Variant = alvo.get(propriedade)
	if antigo == valor:
		return
	# MERGE_ENDS junta ações seguidas com o mesmo nome; o nome leva o objeto porque juntar
	# mudanças de objetos diferentes faria o desfazer perder uma delas.
	undo.create_action("Alterar %s (%d)" % [propriedade, alvo.get_instance_id()], UndoRedo.MERGE_ENDS)
	undo.add_do_property(alvo, propriedade, valor)
	undo.add_undo_property(alvo, propriedade, antigo)
	undo.commit_action()
	if alvo == fase and propriedade == &"nome":
		campo_nome.text = fase.nome


func _renomear_fase() -> void:
	if fase and campo_nome.text != fase.nome:
		_alterar_propriedade(fase, &"nome", campo_nome.text)


func _selecionar(objeto: ObjetoFase) -> void:
	selecionado = objeto
	if not is_node_ready():
		return
	inspetor.mostrar(objeto if objeto else fase)


# --- Visão (pré-visualização da perspectiva) ---------------------------------------------

func _proxima_visao() -> void:
	visao = ((visao + 1) % Visao.size()) as Visao
	_aplicar_visao()
	_avisar("Visão: %s" % NOMES_VISAO[visao])


## Tudo: mostra todos os objetos. Isométrica: como o jogador vê na ida (câmera travada,
## objetos "só 3D" escondidos). 3D: como na volta (objetos "só isométrico" escondidos).
func _aplicar_visao() -> void:
	if fase == null:
		return
	fase.ativar(ObjetoFase.Visibilidade.SO_ISO, visao != Visao.TERCEIRA)
	fase.ativar(ObjetoFase.Visibilidade.SO_3D, visao != Visao.ISO)
	camera_editor.isometrica = visao == Visao.ISO
	if is_node_ready():
		botao_visao.text = "Visão: %s (V)" % NOMES_VISAO[visao]
		_atualizar_status()
	if selecionado and not selecionado.visible:
		_selecionar(null)


# --- Interface ---------------------------------------------------------------------------

func _on_versao_mudou() -> void:
	modificado = true
	_caixas.clear()
	inspetor.atualizar_valores()
	# Objeto recolocado (desfazer "Apagar") ou com a visibilidade trocada tem de seguir a
	# visão atual (ex.: um "só 3D" não pode aparecer na visão isométrica).
	_aplicar_visao()
	_atualizar_status()


func _atualizar_status() -> void:
	if not is_node_ready():
		return
	var ferramenta := "Selecionar"
	match modo:
		Modo.TERRENO:
			ferramenta = "Terreno: %s (giro %d°)" % [Tiles.definicao(tile_atual).nome, orientacao * 90]
		Modo.OBJETO:
			ferramenta = "Objeto: %s" % entrada_objeto.get("nome", "")
	var arquivo := caminho.get_file() if not caminho.is_empty() else "(não salva)"
	status.text = "%s   |   Camada %d (PgUp/PgDn)   |   Visão: %s   |   %s%s   |   H: atalhos" % [
		ferramenta, camada, NOMES_VISAO[visao], arquivo, "  •  modificada" if modificado else ""]


func _avisar(texto: String) -> void:
	aviso.text = texto
	aviso.show()
	if _tween_aviso:
		_tween_aviso.kill()
	_tween_aviso = create_tween()
	_tween_aviso.tween_interval(2.5)
	_tween_aviso.tween_callback(aviso.hide)

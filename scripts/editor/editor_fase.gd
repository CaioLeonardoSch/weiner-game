class_name EditorFase
extends Node3D
## Editor de fases dentro do jogo (F1 abre/fecha, a partir do jogo ou daqui).
##
## Terreno: blocos de 1 m numa grade (GridMap). Ferramentas (barra no topo, teclas 1 a 5):
## Pincel (clique coloca em cima/ao lado do bloco apontado, arrastar pinta; direito apaga),
## Trocar (troca o bloco apontado), Linha (clique marca o começo, a prévia vai até o mouse,
## outro clique confirma — atalho: Shift), Retângulo (arrastar — atalho: Ctrl) e Balde (atalho:
## Alt). Ctrl + roda (ou [ e ]) muda o tamanho do pincel. A prévia translúcida mostra o que vai
## mudar. Objetos: escolha na paleta e clique para colocar (Shift: linha; Ctrl + arrastar:
## espalhar). O Cursor (Esc) não coloca nada: seleciona, arrasta objetos e, no vazio, gira a
## vista (Shift: arrasta); Espaço + botão esquerdo gira a vista em qualquer ferramenta.
## Mecanismos (placas, portões...) se ligam pela cor do canal; a ferramenta Ligar (L) liga duas
## peças com dois cliques e escolhe a cor. Um mecanismo novo já vem com uma cor livre.
## Trecho (T): marca um retângulo do mapa (blocos de todas as camadas e objetos) para copiar,
## recortar, apagar ou salvar como módulo; Ctrl+V cola (girando com Q/E), também em outra fase.
## Módulos salvos (scenes/modulos/) aparecem na paleta e colam do mesmo jeito — ver Trecho e
## Modulos. Alt + clique no terreno é o balde (troca uma mancha inteira de blocos iguais).
## Tudo passa pelo desfazer/refazer (Ctrl+Z / Ctrl+Y). Ctrl+S salva em scenes/fases/.
## F1 testa a fase como está (sem salvar) e volta para cá no mesmo ponto.

enum Modo { SELECAO, TERRENO, OBJETO, LIGAR, TRECHO, COLAR }
## Ferramentas do terreno.
enum Ferramenta { PINCEL, TROCAR, LINHA, RETANGULO, BALDE }
enum Visao { TUDO, ISO, TERCEIRA }

const NOMES_VISAO := ["tudo", "isométrica", "3D"]
const NOMES_FERRAMENTA := ["Pincel", "Trocar", "Linha", "Retângulo", "Balde"]
const ICONES_FERRAMENTA := ["pincel", "trocar", "linha", "retangulo", "balde"]
## Maior lado do pincel (células).
const PINCEL_MAXIMO := 9
## Mais blocos que isso na prévia translúcida não aparecem (retângulos enormes).
const PREVIA_MAXIMA := 4096
## Quantos itens a seção "Recentes" da paleta guarda.
const RECENTES_MAXIMO := 8
## Maior lado (células) de um retângulo de pintura, para um arrasto sem querer não travar tudo.
const RETANGULO_MAXIMO := 64
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
var ferramenta := Ferramenta.PINCEL
## Lado (células) do pincel quadrado: 1×1, 2×2, 3×3...
var tamanho_pincel := 1
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
## Ctrl + arrastar: o pincel só marca um retângulo e aplica tudo ao soltar.
var _retangulo := false
var _retangulo_inicio := Vector2i.ZERO
var _retangulo_fim := Vector2i.ZERO
## Shift + arrastar com um objeto escolhido: espalha cópias (floresta, flores, pedras).
var _espalhando := false
var _espalhados: Array[ObjetoFase] = []
var _ultimo_espalhado := Vector3.ZERO
## Ponto sob o mouse sem encaixar na grade (para espalhar objetos).
var ponto_livre := Vector3.ZERO
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
## Ferramenta Ligar: a primeira peça clicada (esperando a segunda).
var ligar_origem: ObjetoFase
## O fantasma veio do conta-gotas: mantém a cor copiada em vez de pegar uma livre.
var _fantasma_copiado := false
## Bioma cujo céu e luz estão aplicados (para refazer só quando mudar).
var _bioma_aplicado := -1
## Bioma dos ícones dos tiles na paleta, e os botões deles (id → Button).
var _bioma_icones := Biomas.FLORESTA
var _botoes_tile := {}
## Botões da seção "Módulos" da paleta (remontada ao salvar um módulo).
var _itens_modulos: Array[Control] = []
## Maior mancha (blocos) que o balde troca de uma vez.
const BALDE_MAXIMO := 6000

# Trecho: retângulo de colunas marcado (cantos inclusive) e as camadas que ele ocupa.
var tem_trecho := false
var trecho_inicio := Vector2i.ZERO
var trecho_fim := Vector2i.ZERO
var camadas_trecho := Vector2i.ZERO
var _marcando_trecho := false
# Colar: o trecho (já girado), onde vai o canto e a prévia (terreno e objetos-fantasma).
var colagem: Trecho
var origem_colagem := Vector3i.ZERO
var _colagem_base: Trecho
var _giro_colagem := 0
var _desnivel_colagem := 0
var _modulo_colando := ""
var _previa: Node3D

# Linha (Shift, ou a ferramenta Linha): começo marcado, fim seguindo o mouse, clique confirma.
var linha_ativa := false
var linha_inicio := Vector3i.ZERO
var linha_fim := Vector3i.ZERO
var _linha_acao := "colocar"
## Linha de objetos: do ponto do primeiro clique até o mouse; fantasmas mostram onde ficam.
var _linha_objetos_inicio := Vector3.ZERO
var pontos_linha_objetos: Array[Vector3] = []
var _fantasmas_linha: Array[ObjetoFase] = []
## Botão esquerdo girando a vista (Cursor no vazio, ou Espaço + botão esquerdo).
var _arrastando_camera := false
var _camera_mexeu := false
## Prévia translúcida dos tiles (pincel, linha, retângulo) e a chave do que ela mostra agora.
var _previa_tiles: MultiMeshInstance3D
var _chave_previa := ""
## Objeto sob o mouse da última vez (o nome dele vai para a barra de status).
var _ultimo_sob_mouse: ObjetoFase
## Barra de ferramentas do terreno (em cima da vista) e os botões dela.
var _barra_ferramentas: PanelContainer
var _botoes_ferramenta: Array[Button] = []
var _rotulo_tamanho: Label
## Seções da paleta: {cabecalho: Button, itens: Array[Control], nome: String}.
var _secoes: Array[Dictionary] = []
var _recolhidas := {}
var _secao_recentes: Dictionary

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
	# O editor usa a tela toda (paleta, vista, painel): o tamanho da interface não vale aqui.
	Opcoes.aplicar_escala(true)
	rng.randomize()
	sobreposicao.editor = self
	sobreposicao.camera = camera
	undo.version_changed.connect(_on_versao_mudou)
	inspetor.propriedade_alterada.connect(_alterar_propriedade)
	inspetor.pedido_apagar.connect(_apagar_selecionado)
	inspetor.pedido_duplicar.connect(_duplicar_selecionado)
	inspetor.pedido_copiar.connect(_copiar)
	inspetor.pedido_recortar.connect(_recortar)
	inspetor.pedido_apagar_trecho.connect(_apagar_trecho)
	inspetor.pedido_salvar_modulo.connect(_salvar_modulo)
	campo_nome.text_submitted.connect(func(_texto: String) -> void: campo_nome.release_focus())
	campo_nome.focus_exited.connect(_renomear_fase)
	%BotaoMenu.pressed.connect(_confirmar_se_modificado.bind(Fases.abrir_menu))
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

	# Marca a árvore: objetos invisíveis no jogo (paredes, zonas) mostram um volume translúcido.
	get_tree().root.set_meta(&"editor_de_fases", true)
	_catalogo = Catalogo.objetos()
	_montar_paleta()
	_montar_barra_ferramentas()

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
	Opcoes.aplicar_escala()
	get_tree().root.remove_meta(&"editor_de_fases")
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
	_bioma_aplicado = -1
	_aplicar_ambiente()
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
	# Arquivo novo é fase nova: id novo (senão, criada a partir de outra, dividiria o ✓ dela).
	if destino != caminho:
		fase.id = destino.get_file().get_basename()
	_gravar(destino)


func _gravar(destino: String) -> void:
	_renomear_fase()
	if fase.id.is_empty():
		fase.id = destino.get_file().get_basename()
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
	Fases.esquecer_id(destino)
	modificado = false
	var problemas := _validar()
	var lista: PackedStringArray = problemas.graves + problemas.avisos
	if lista.is_empty():
		_avisar("Salva: %s" % destino)
	else:
		_avisar("Salva: %s\nAtenção: %s" % [destino, "\n".join(lista)], 6.0)
	_atualizar_status()


## Confere a fase. `graves`: impedem jogar (falta início, dono ou graveto); `avisos`: coisas
## que provavelmente são engano (habilidade desligada, objeto no ar...).
func _validar() -> Dictionary:
	var graves: PackedStringArray = []
	var avisos: PackedStringArray = []
	var objetivo := Objetivo.criar(fase.objetivo)
	for falta in objetivo.faltando(fase):
		graves.append("Falta %s." % falta)
	avisos.append_array(objetivo.avisos(fase))
	if fase.todos(InicioCachorro).size() > 1:
		avisos.append("Há mais de um Início do cachorro — só o primeiro vale.")
	avisos.append_array(_avisos_de_mecanismos())
	var inicio := fase.primeiro(InicioCachorro)
	if inicio and not _tem_chao(inicio.global_position):
		graves.append("O Início do cachorro está no ar ou na água.")
	var graveto := fase.primeiro(Graveto)
	if graveto and not _tem_chao(graveto.global_position):
		avisos.append("O Graveto está no ar ou na água.")
	var abaixo := 0
	for objeto in fase.lista_objetos():
		if objeto.global_position.y < -3.0:
			abaixo += 1
	if abaixo > 0:
		avisos.append("%d objeto(s) bem abaixo do chão." % abaixo)
	var tem_terra_fofa := not terreno.get_used_cells_by_item(Tiles.TERRA_FOFA).is_empty()
	if tem_terra_fofa and not fase.tem_habilidade(Fase.HABILIDADE_CAVAR):
		avisos.append("Há terra fofa, mas a habilidade Cavar está desligada.")
	if not fase.todos(Passaro).is_empty() and not fase.tem_habilidade(Fase.HABILIDADE_LATIR):
		for passaro in fase.todos(Passaro):
			if graveto and (passaro as Passaro).guarda(graveto.global_position) or (passaro as Passaro).bloqueia_passagem:
				avisos.append("Um passarinho guarda o graveto ou bloqueia o caminho, mas Latir está desligado.")
				break
	var pesados := fase.todos(Empurravel).size() + fase.todos(TroncoRolante).size()
	if pesados == 0 and fase.todos(Placa).any(func(p: ObjetoFase) -> bool: return (p as Placa).tipo == Placa.PEDRA):
		avisos.append("Há placa de pedra, mas nenhum bloco de pedra nem tronco para acioná-la.")
	if fase.frio and fase.todos(Fogueira).is_empty() and fase.todos(Celeiro).is_empty():
		avisos.append("Frio ligado, mas não há Fogueira nem Celeiro para o cachorro se esquentar.")
	var comuns := fase.todos(Graveto).filter(func(g: ObjetoFase) -> bool: return not (g as Graveto).lendario).size()
	var pedidos := 0
	for fogueira in fase.todos(Fogueira):
		pedidos += (fogueira as Fogueira).gravetos_para_acender
	if pedidos > comuns:
		avisos.append("As fogueiras pedem %d graveto(s) para acender, mas a fase só tem %d graveto(s) comum(ns)." % [pedidos, comuns])
	var tem_neve := not terreno.get_used_cells_by_item(Tiles.NEVE_FOFA).is_empty() \
		or not terreno.get_used_cells_by_item(Tiles.MONTE_DE_NEVE).is_empty() \
		or not terreno.get_used_cells_by_item(Tiles.GELO).is_empty()
	if tem_neve and fase.bioma != Biomas.NEVE:
		avisos.append("Há neve ou gelo no terreno, mas o bioma da fase é Floresta.")
	for bloco in fase.todos(Empurravel):
		var local := terreno.to_local(bloco.global_position)
		if absf(fposmod(local.x, 1.0) - 0.5) > 0.05 or absf(fposmod(local.z, 1.0) - 0.5) > 0.05:
			avisos.append("Bloco empurrável fora do centro da célula (ele anda de célula em célula).")
			break
	return {graves = graves, avisos = avisos}


## Tem chão firme (bloco que não é água) logo abaixo da posição?
func _tem_chao(posicao: Vector3) -> bool:
	for descida: float in [0.1, 0.6]:
		var item := fase.tile_em(posicao + Vector3.DOWN * descida)
		if item != GridMap.INVALID_CELL_ITEM:
			return not Tiles.eh_agua(item)
	return false


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


## Testa a fase como está (sem salvar). `daqui` (F2): o cachorro começa no ponto sob o cursor,
## em vez do Início — como o "jogar daqui" do Mario Maker, para testar um trecho sem refazer tudo.
func _testar(confirmado := false, daqui := false) -> void:
	if daqui and not alvo_valido:
		_avisar("Aponte para o chão onde o cachorro deve começar e aperte F2")
		return
	var ponto := Vector3(floorf(ponto_livre.x) + 0.5, ponto_alvo.y, floorf(ponto_livre.z) + 0.5)
	var problemas := _validar()
	if not confirmado and problemas.graves.size() > 0:
		confirmar.dialog_text = "Esta fase não dá para jogar direito:\n\n• %s\n\nTestar mesmo assim?" \
			% "\n• ".join(problemas.graves)
		for conexao in confirmar.confirmed.get_connections():
			confirmar.confirmed.disconnect(conexao.callable)
		confirmar.confirmed.connect(_testar.bind(true, daqui), CONNECT_ONE_SHOT)
		confirmar.popup_centered()
		return
	var cena := _empacotar()
	if cena == null:
		return
	Fases.caminho_atual = caminho
	Fases.estado_editor = _estado()
	Fases.inicio_do_teste = ponto if daqui else null
	Fases.testar(cena, modificado)


func _estado() -> Dictionary:
	return {
		fase = caminho, camera = camera_editor.estado(), modo = modo, tile = tile_atual, orientacao = orientacao,
		camada = camada, objeto = entrada_objeto.get("caminho", ""), visao = visao,
		ferramenta = ferramenta, tamanho_pincel = tamanho_pincel,
		recentes = Fases.estado_editor.get("recentes", []),
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
	ferramenta = estado.get("ferramenta", ferramenta)
	tamanho_pincel = estado.get("tamanho_pincel", tamanho_pincel)
	visao = estado.visao
	_aplicar_visao()
	match estado.modo:
		Modo.OBJETO:
			for entrada in _catalogo:
				if entrada.caminho == estado.objeto:
					_escolher_objeto(entrada)
		Modo.SELECAO:
			_escolher_selecao()
		Modo.TRECHO, Modo.COLAR:
			_escolher_trecho()
		_:
			_escolher_tile(estado.tile)
	_marcar_botao_da_ferramenta()


# --- Paleta ------------------------------------------------------------------------------

func _montar_paleta() -> void:
	var busca := LineEdit.new()
	busca.placeholder_text = "Buscar na paleta…"
	busca.clear_button_enabled = true
	busca.text_changed.connect(_filtrar_paleta)
	busca.text_submitted.connect(func(_texto: String) -> void: busca.release_focus())
	paleta.add_child(busca)

	_secao("Ferramentas")
	var cursor := _botao_paleta("Cursor (Esc)", IconesDesenhados.textura("cursor"))
	cursor.set_meta(&"ferramenta", "selecao")
	cursor.tooltip_text = "Não coloca nada: clique seleciona, arrastar move o objeto; no vazio, arrastar gira a vista (Shift: arrasta)"
	cursor.pressed.connect(_escolher_selecao)
	var trecho := _botao_paleta("Trecho (T)", IconesDesenhados.textura("trecho"))
	trecho.set_meta(&"ferramenta", "trecho")
	trecho.tooltip_text = "Marcar um pedaço do mapa para copiar, recortar, apagar ou salvar como módulo"
	trecho.pressed.connect(_escolher_trecho)
	var ligar := _botao_paleta("Ligar mecanismos (L)", IconesDesenhados.textura("ligar"))
	ligar.set_meta(&"ferramenta", "ligar")
	ligar.pressed.connect(_escolher_ligar)

	_secao_recentes = _secao("Recentes")

	_secao("Terreno")
	var biblioteca: MeshLibrary = load(Tiles.CAMINHO_BIBLIOTECA)
	for definicao in Tiles.definicoes():
		var botao := _botao_paleta(definicao.nome, icones.icone_tile(biblioteca, definicao.id))
		botao.set_meta(&"ferramenta", "tile_%d" % definicao.id)
		botao.pressed.connect(_escolher_tile.bind(definicao.id))
		_botoes_tile[definicao.id] = botao

	var categoria := ""
	for entrada in _catalogo:
		if entrada.categoria != categoria:
			categoria = entrada.categoria
			_secao(categoria)
		var amostra := entrada.cena.instantiate() as ObjetoFase
		var desenho := amostra.icone_desenhado()
		var icone := IconesDesenhados.textura(desenho) if not desenho.is_empty() else icones.icone(amostra)
		if not desenho.is_empty():
			amostra.free()
		var botao := _botao_paleta(entrada.nome, icone)
		botao.set_meta(&"ferramenta", entrada.caminho)
		botao.pressed.connect(_escolher_objeto.bind(entrada))
	_montar_modulos()
	_montar_recentes()


## Seção "Módulos" no fim da paleta: um botão por módulo salvo (clicar começa a colar).
func _montar_modulos() -> void:
	for item in _itens_modulos:
		item.queue_free()
	_itens_modulos.clear()
	for i in range(_secoes.size() - 1, -1, -1):
		if _secoes[i].nome == "Módulos":
			_secoes.remove_at(i)
	var secao := _secao("Módulos")
	_itens_modulos.append(secao.cabecalho)
	var lista := Modulos.listar()
	if lista.is_empty():
		var dica := Label.new()
		dica.text = "Nenhum ainda: marque um trecho (T) e salve como módulo."
		dica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dica.add_theme_font_size_override("font_size", 12)
		dica.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		paleta.add_child(dica)
		secao.itens.append(dica)
		_itens_modulos.append(dica)
	for caminho in lista:
		var botao := _botao_paleta(Modulos.nome(caminho), IconesDesenhados.textura("modulo"))
		botao.set_meta(&"ferramenta", "modulo:" + caminho)
		botao.tooltip_text = caminho
		botao.pressed.connect(_colar_modulo.bind(caminho))
		_itens_modulos.append(botao)
	_filtrar_paleta(_texto_busca())


## "Recentes": os últimos itens usados (tiles, objetos, módulos), para voltar a eles rápido —
## como a barra de itens do Mario Maker e a de atalhos do Minecraft. Vale para a sessão toda.
func _montar_recentes() -> void:
	if _secao_recentes.is_empty():
		return
	for item: Control in _secao_recentes.itens:
		item.queue_free()
	_secao_recentes.itens.clear()
	var posicao: int = _secao_recentes.cabecalho.get_index() + 1
	var recentes: Array = Fases.estado_editor.get("recentes", [])
	for chave: String in recentes:
		var original := _botao_da_ferramenta(chave)
		if original == null:
			continue
		var botao := Button.new()
		botao.text = original.text
		botao.icon = original.icon
		botao.tooltip_text = original.tooltip_text
		botao.alignment = HORIZONTAL_ALIGNMENT_LEFT
		botao.focus_mode = Control.FOCUS_NONE
		botao.set_meta(&"recente", chave)
		botao.pressed.connect(func() -> void: original.pressed.emit())
		paleta.add_child(botao)
		paleta.move_child(botao, posicao)
		posicao += 1
		_secao_recentes.itens.append(botao)
	_secao_recentes.cabecalho.visible = not _secao_recentes.itens.is_empty()
	_filtrar_paleta(_texto_busca())


## Um item foi usado: vai para o começo dos recentes.
func _lembrar_recente(chave: String) -> void:
	if chave.is_empty() or _secao_recentes.is_empty():
		return
	var recentes: Array = Fases.estado_editor.get("recentes", [])
	if not recentes.is_empty() and recentes[0] == chave:
		return
	recentes.erase(chave)
	recentes.push_front(chave)
	Fases.estado_editor["recentes"] = recentes.slice(0, RECENTES_MAXIMO)
	_montar_recentes()


func _botao_da_ferramenta(chave: String) -> Button:
	for botao in _botoes_paleta.get_buttons():
		if botao.get_meta(&"ferramenta", "") == chave:
			return botao
	return null


func _texto_busca() -> String:
	return (paleta.get_child(0) as LineEdit).text if paleta.get_child_count() > 0 else ""


## Mostra só os botões cujo nome tem o texto buscado (e as seções com algum). Seções recolhidas
## (clique no título) escondem os itens, menos durante uma busca.
func _filtrar_paleta(texto: String) -> void:
	var busca := _sem_acento(texto.strip_edges().to_lower())
	for secao in _secoes:
		var cabecalho: Button = secao.cabecalho
		if not is_instance_valid(cabecalho):
			continue
		var recolhida: bool = _recolhidas.get(secao.nome, false) and busca.is_empty()
		var algum := false
		for item: Control in secao.itens:
			if not is_instance_valid(item):
				continue
			var combina := busca.is_empty() or (item is Button and busca in _sem_acento((item as Button).text.to_lower()))
			item.visible = combina and not recolhida
			algum = algum or combina
		cabecalho.visible = (algum or busca.is_empty()) and not (secao == _secao_recentes and secao.itens.is_empty())
		cabecalho.text = ("▸ " if recolhida else "▾ ") + secao.nome


static func _sem_acento(texto: String) -> String:
	var trocas := {"á": "a", "à": "a", "â": "a", "ã": "a", "é": "e", "ê": "e", "í": "i",
		"ó": "o", "ô": "o", "õ": "o", "ú": "u", "ç": "c"}
	for letra in trocas:
		texto = texto.replace(letra, trocas[letra])
	return texto


## Título de seção da paleta: um botão que recolhe e abre a seção. Os botões criados depois dele
## (até a próxima seção) são os itens dela.
func _secao(nome: String) -> Dictionary:
	var cabecalho := Button.new()
	cabecalho.flat = true
	cabecalho.alignment = HORIZONTAL_ALIGNMENT_LEFT
	cabecalho.focus_mode = Control.FOCUS_NONE
	cabecalho.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	cabecalho.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.7))
	cabecalho.text = "▾ " + nome
	paleta.add_child(cabecalho)
	var secao := {cabecalho = cabecalho, itens = [], nome = nome}
	cabecalho.pressed.connect(func() -> void:
		_recolhidas[nome] = not _recolhidas.get(nome, false)
		_filtrar_paleta(_texto_busca()))
	_secoes.append(secao)
	return secao


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
	if not _secoes.is_empty():
		_secoes[-1].itens.append(botao)
	return botao


func _marcar_botao_da_ferramenta() -> void:
	var chave := "selecao"
	match modo:
		Modo.TERRENO:
			chave = "tile_%d" % tile_atual
		Modo.OBJETO:
			chave = entrada_objeto.get("caminho", "")
		Modo.LIGAR:
			chave = "ligar"
		Modo.TRECHO:
			chave = "trecho"
		Modo.COLAR:
			chave = "modulo:" + _modulo_colando if not _modulo_colando.is_empty() else "trecho"
	for botao in _botoes_paleta.get_buttons():
		botao.set_pressed_no_signal(botao.get_meta(&"ferramenta") == chave)


func _escolher_selecao() -> void:
	_sair_do_trecho()
	_cancelar_linha()
	modo = Modo.SELECAO
	ligar_origem = null
	_trocar_fantasma(null)
	_marcar_botao_da_ferramenta()
	_atualizar_barra_ferramentas()
	_atualizar_status()


func _escolher_ligar() -> void:
	_sair_do_trecho()
	_cancelar_linha()
	modo = Modo.LIGAR
	ligar_origem = null
	_trocar_fantasma(null)
	_marcar_botao_da_ferramenta()
	_atualizar_barra_ferramentas()
	_atualizar_status()


func _escolher_tile(id: int) -> void:
	_sair_do_trecho()
	_cancelar_linha()
	modo = Modo.TERRENO
	ligar_origem = null
	tile_atual = id
	_trocar_fantasma(null)
	_selecionar(null)
	_marcar_botao_da_ferramenta()
	_atualizar_barra_ferramentas()
	_lembrar_recente("tile_%d" % id)
	_atualizar_status()


func _escolher_objeto(entrada: Dictionary) -> void:
	_sair_do_trecho()
	_cancelar_linha()
	modo = Modo.OBJETO
	ligar_origem = null
	entrada_objeto = entrada
	_trocar_fantasma(entrada.cena)
	_fantasma_copiado = false
	_cor_livre_no_fantasma()
	_marcar_botao_da_ferramenta()
	_atualizar_barra_ferramentas()
	_lembrar_recente(entrada.caminho)
	_atualizar_status()


## Ferramenta Trecho: marcar um retângulo do mapa.
func _escolher_trecho() -> void:
	_sair_do_trecho(false)
	_cancelar_linha()
	modo = Modo.TRECHO
	ligar_origem = null
	_trocar_fantasma(null)
	selecionado = null
	_mostrar_painel_do_trecho()
	_marcar_botao_da_ferramenta()
	_atualizar_barra_ferramentas()
	_atualizar_status()


## Saindo da ferramenta Trecho (ou da colagem): some a prévia; `desmarcar` tira o retângulo.
func _sair_do_trecho(desmarcar := true) -> void:
	if _previa:
		_previa.queue_free()
		_previa = null
	colagem = null
	_modulo_colando = ""
	_marcando_trecho = false
	if desmarcar and tem_trecho:
		tem_trecho = false


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
	if _tecla_de_ferramenta(event):
		return
	if event.is_action_pressed("alternar_editor"):
		_testar()
	elif event.is_action_pressed("editor_testar_daqui"):
		_testar(false, true)
	elif event.is_action_pressed("editor_copiar"):
		_copiar()
	elif event.is_action_pressed("editor_recortar"):
		_recortar()
	elif event.is_action_pressed("editor_colar"):
		_comecar_colagem(Fases.area_transferencia as Trecho)
	elif event.is_action_pressed("editor_trecho"):
		_escolher_trecho()
	elif event.is_action_pressed("editor_salvar"):
		_salvar()
	elif event.is_action_pressed("editor_refazer"):
		undo.redo()
	elif event.is_action_pressed("editor_desfazer"):
		undo.undo()
	elif event.is_action_pressed("editor_duplicar"):
		_duplicar_selecionado()
	elif event.is_action_pressed("editor_apagar"):
		if modo == Modo.TRECHO and tem_trecho:
			_apagar_trecho()
		else:
			_apagar_selecionado()
	elif event.is_action_pressed("liberar_mouse"):
		# Esc: fecha a ajuda; senão vai para a ferramenta Selecionar; já nela, desmarca.
		if ajuda.visible:
			ajuda.hide()
		elif linha_ativa:
			_cancelar_linha()
		elif modo == Modo.COLAR:
			_escolher_trecho()
		elif modo == Modo.TRECHO and tem_trecho:
			_marcar_trecho(false)
		elif modo == Modo.LIGAR and ligar_origem:
			ligar_origem = null
			_atualizar_status()
		elif modo != Modo.SELECAO:
			_escolher_selecao()
		else:
			_selecionar(null)
	elif event.is_action_pressed("editor_ajuda"):
		ajuda.visible = not ajuda.visible
	elif event.is_action_pressed("editor_perspectiva"):
		_proxima_visao()
	elif event.is_action_pressed("editor_conta_gotas"):
		_conta_gotas()
	elif event.is_action_pressed("editor_ligar"):
		_escolher_ligar()
	elif event.is_action_pressed("editor_centralizar"):
		var inicio := fase.primeiro(InicioCachorro)
		camera_editor.foco = inicio.global_position if inicio else Vector3.ZERO
	elif event.is_action_pressed("editor_camada_subir"):
		if modo == Modo.COLAR:
			_desnivel_colagem += 1
		else:
			camada += 1
		_atualizar_status()
	elif event.is_action_pressed("editor_camada_descer"):
		if modo == Modo.COLAR:
			_desnivel_colagem -= 1
		else:
			camada -= 1
		_atualizar_status()
	elif event.is_action_pressed("editor_girar_esquerda"):
		_girar(1)
	elif event.is_action_pressed("editor_girar_direita"):
		_girar(-1)
	elif event.is_action_pressed("editor_zoom_mais"):
		if Input.is_action_pressed("editor_mod_ctrl"):
			_mudar_tamanho_pincel(1)
		else:
			camera_editor.zoom(1.0 / 1.12)
	elif event.is_action_pressed("editor_zoom_menos"):
		if Input.is_action_pressed("editor_mod_ctrl"):
			_mudar_tamanho_pincel(-1)
		else:
			camera_editor.zoom(1.12)
	elif event.is_action_pressed("editor_orbitar"):
		_orbitando = true
	elif event.is_action_released("editor_orbitar"):
		_orbitando = false
	elif event is InputEventMouseMotion and (_orbitando or _arrastando_camera):
		var relativo := (event as InputEventMouseMotion).relative
		_camera_mexeu = _camera_mexeu or relativo.length() > 0.0
		if Input.is_action_pressed("editor_mod_shift") or camera_editor.isometrica:
			camera_editor.arrastar(relativo)
		else:
			camera_editor.orbitar(relativo)
	elif event.is_action_pressed("editor_acao"):
		_atualizar_alvo()
		_acao_principal()
	elif event.is_action_released("editor_acao"):
		_terminar_arrastos()
		if _arrastando_camera:
			_arrastando_camera = false
			# Clique (sem arrastar) no vazio com o Cursor: desmarca.
			if modo == Modo.SELECAO and not _camera_mexeu:
				_selecionar(null)
	elif event.is_action_pressed("editor_remover"):
		_atualizar_alvo()
		_acao_remover()
	elif event.is_action_released("editor_remover"):
		_terminar_arrastos()


## Teclas 1 a 5 escolhem a ferramenta do terreno; [ e ] mudam o tamanho do pincel. Devolve se
## a tecla foi usada.
func _tecla_de_ferramenta(event: InputEvent) -> bool:
	var tecla := event as InputEventKey
	if tecla == null or not tecla.pressed or tecla.echo or tecla.ctrl_pressed or tecla.alt_pressed:
		return false
	if tecla.physical_keycode >= KEY_1 and tecla.physical_keycode <= KEY_5:
		_escolher_ferramenta((tecla.physical_keycode - KEY_1) as Ferramenta)
		return true
	if tecla.physical_keycode == KEY_BRACKETLEFT or tecla.physical_keycode == KEY_BRACKETRIGHT:
		_mudar_tamanho_pincel(1 if tecla.physical_keycode == KEY_BRACKETRIGHT else -1)
		return true
	return false


func _process(_delta: float) -> void:
	# Botão solto em cima de um painel: o evento não chega aqui, então confere o estado.
	if (_pincel != "" or _arrastando_objeto or _espalhando or _marcando_trecho) \
			and not Input.is_action_pressed("editor_acao") and not Input.is_action_pressed("editor_remover"):
		_terminar_arrastos()
	_orbitando = _orbitando and Input.is_action_pressed("editor_orbitar")
	_arrastando_camera = _arrastando_camera and Input.is_action_pressed("editor_acao")

	_atualizar_alvo()
	if linha_ativa and alvo_valido:
		_continuar_linha()
	if _pincel != "" and alvo_valido:
		_continuar_pincel()
	if _arrastando_objeto and selecionado:
		_continuar_arrasto_objeto()
	if _espalhando and alvo_valido:
		_continuar_espalhar()
	if _marcando_trecho and alvo_valido:
		trecho_fim = coluna_alvo()
	if modo == Modo.COLAR and colagem and alvo_valido:
		var coluna := coluna_alvo()
		origem_colagem = Vector3i(coluna.x - colagem.largura / 2, _desnivel_colagem, coluna.y - colagem.profundidade / 2)
		_previa.position = Vector3(origem_colagem)
	if _previa:
		_previa.visible = modo == Modo.COLAR and alvo_valido
	if fantasma:
		fantasma.visible = modo == Modo.OBJETO and alvo_valido and not linha_ativa
		if fantasma.visible:
			fantasma.position = ponto_alvo + Vector3.UP * _altura_extra(fantasma)
	_atualizar_previa_tiles()
	if _rotulo_tamanho and _rotulo_tamanho.text != "%d × %d" % [tamanho_pincel, tamanho_pincel]:
		_atualizar_barra_ferramentas()
	if objeto_sob_mouse != _ultimo_sob_mouse:
		_ultimo_sob_mouse = objeto_sob_mouse
		_atualizar_status()
	sobreposicao.queue_redraw()


## O que o clique faria agora (para o cursor): "colocar", "apagar" ou "pintar".
func acao_do_cursor() -> String:
	if Input.is_action_pressed("editor_remover") or _pincel == "apagar" or (linha_ativa and _linha_acao == "apagar"):
		return "apagar"
	if modo == Modo.TERRENO and (ferramenta == Ferramenta.TROCAR or _pincel == "pintar"):
		return "pintar"
	return "colocar"


## A ferramenta do terreno valendo agora: os atalhos (Shift linha, Ctrl retângulo, Alt balde)
## passam na frente da escolhida na barra.
func ferramenta_efetiva() -> Ferramenta:
	if linha_ativa or Input.is_action_pressed("editor_mod_shift"):
		return Ferramenta.LINHA
	if Input.is_action_pressed("editor_mod_ctrl"):
		return Ferramenta.RETANGULO
	if Input.is_action_pressed("editor_mod_alt"):
		return Ferramenta.BALDE
	return ferramenta


## Camada em que a grade é desenhada.
func camada_da_grade() -> int:
	if _pincel != "":
		return _camada_pincel + (1 if _pincel != "colocar" else 0)
	return celula_alvo.y if modo == Modo.TERRENO else camada


func _acao_principal() -> void:
	# Espaço + botão esquerdo gira a vista em qualquer ferramenta.
	if Input.is_physical_key_pressed(KEY_SPACE) and not _digitando():
		_comecar_arrasto_camera()
		return
	if modo == Modo.LIGAR:
		_clique_ligar(objeto_sob_mouse)
		return
	if modo == Modo.SELECAO and objeto_sob_mouse == null:
		_comecar_arrasto_camera()
		return
	if not alvo_valido:
		return
	match modo:
		Modo.TRECHO:
			_marcando_trecho = true
			trecho_inicio = coluna_alvo()
			trecho_fim = trecho_inicio
			tem_trecho = true
		Modo.COLAR:
			_colar_aqui()
		Modo.TERRENO:
			var acao := "pintar" if ferramenta == Ferramenta.TROCAR else "colocar"
			match ferramenta_efetiva():
				Ferramenta.LINHA:
					_clique_linha(acao)
				Ferramenta.BALDE:
					_balde()
				Ferramenta.RETANGULO:
					_comecar_pincel(acao, (celula_atingida if acao == "pintar" else celula_alvo).y, true)
				_:
					if acao == "colocar":
						_comecar_pincel("colocar", celula_alvo.y)
					elif atingiu_bloco:
						_comecar_pincel("pintar", celula_atingida.y)
		Modo.OBJETO:
			if linha_ativa or Input.is_action_pressed("editor_mod_shift"):
				_clique_linha_objetos()
			elif Input.is_action_pressed("editor_mod_ctrl"):
				_comecar_espalhar()
			else:
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
	if modo == Modo.TRECHO:
		_marcar_trecho(false)
	elif modo == Modo.COLAR:
		_escolher_trecho()
	elif modo == Modo.TERRENO:
		match ferramenta_efetiva():
			Ferramenta.LINHA:
				_clique_linha("apagar")
			Ferramenta.RETANGULO:
				if atingiu_bloco:
					_comecar_pincel("apagar", celula_atingida.y, true)
			_:
				if atingiu_bloco:
					_comecar_pincel("apagar", celula_atingida.y)
	elif modo == Modo.OBJETO and linha_ativa:
		_cancelar_linha()
	elif modo == Modo.LIGAR:
		if objeto_sob_mouse:
			_isolar(objeto_sob_mouse)
	elif objeto_sob_mouse:
		_remover_objeto(objeto_sob_mouse)


func _terminar_arrastos() -> void:
	if _marcando_trecho:
		_marcando_trecho = false
		_marcar_trecho(true)
	if _pincel != "":
		_terminar_pincel()
	if _espalhando:
		_terminar_espalhar()
	if _arrastando_objeto:
		_arrastando_objeto = false
		if selecionado and selecionado.transform != _transform_antes_arrasto:
			undo.create_action("Mover %s" % selecionado.nome_no_editor())
			undo.add_do_property(selecionado, &"transform", selecionado.transform)
			undo.add_undo_property(selecionado, &"transform", _transform_antes_arrasto)
			undo.commit_action(false)


func _girar(sentido: int) -> void:
	var passo := 15.0 if Input.is_action_pressed("editor_mod_shift") else 45.0
	if modo == Modo.COLAR:
		_giro_colagem = posmod(_giro_colagem + sentido, 4)
		_preparar_colagem()
	elif modo == Modo.TERRENO:
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

	if modo in [Modo.SELECAO, Modo.OBJETO, Modo.LIGAR]:
		objeto_sob_mouse = _objeto_no_raio(origem, direcao)
		if modo == Modo.LIGAR and objeto_sob_mouse and objeto_sob_mouse.papel_no_canal() == "":
			objeto_sob_mouse = null

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
	ponto_livre = ponto_alvo
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

func _comecar_pincel(tipo: String, camada_pincel: int, retangulo := false) -> void:
	_pincel = tipo
	_camada_pincel = camada_pincel
	_mudancas_pincel.clear()
	var celula := celula_atingida if tipo != "colocar" else celula_alvo
	_retangulo = retangulo
	if _retangulo:
		_retangulo_inicio = Vector2i(celula.x, celula.z)
		_retangulo_fim = _retangulo_inicio
	else:
		_aplicar_pincel(celula)


## Retângulo sendo marcado (Ctrl + arrastar), em células: AABB, ou null.
func retangulo_em_andamento() -> Variant:
	if _pincel == "" or not _retangulo:
		return null
	var minimo := Vector2i(mini(_retangulo_inicio.x, _retangulo_fim.x), mini(_retangulo_inicio.y, _retangulo_fim.y))
	var maximo := Vector2i(maxi(_retangulo_inicio.x, _retangulo_fim.x), maxi(_retangulo_inicio.y, _retangulo_fim.y))
	return AABB(Vector3(minimo.x, _camada_pincel, minimo.y), Vector3(maximo.x - minimo.x + 1, 1, maximo.y - minimo.y + 1))


## A célula sob o mouse no plano de uma camada (colocar: a base da camada; apagar/pintar: o topo
## dos blocos dela), ou null. Arrastos e linhas ficam presos na camada em que começaram.
func _celula_no_plano(camada_plano: int, acao: String) -> Variant:
	var mouse := get_viewport().get_mouse_position()
	var origem := camera.project_ray_origin(mouse)
	var direcao := camera.project_ray_normal(mouse)
	if absf(direcao.y) < 0.0001:
		return null
	var altura := float(camada_plano) + (0.0 if acao == "colocar" else 1.0)
	var t := (altura - origem.y) / direcao.y
	if t <= 0.0:
		return null
	var ponto := origem + direcao * t
	return Vector3i(floori(ponto.x), camada_plano, floori(ponto.z))


## Durante o arrasto, a pintura fica presa na camada em que começou.
func _continuar_pincel() -> void:
	var achada: Variant = _celula_no_plano(_camada_pincel, _pincel)
	if achada == null:
		return
	var celula: Vector3i = achada
	if _retangulo:
		_retangulo_fim = Vector2i(
			clampi(celula.x, _retangulo_inicio.x - RETANGULO_MAXIMO + 1, _retangulo_inicio.x + RETANGULO_MAXIMO - 1),
			clampi(celula.z, _retangulo_inicio.y - RETANGULO_MAXIMO + 1, _retangulo_inicio.y + RETANGULO_MAXIMO - 1))
	else:
		_aplicar_pincel(celula)


## Posições (X, Z) do pincel quadrado em volta da célula do cursor.
func deslocamentos_do_pincel() -> Array[Vector2i]:
	var lista: Array[Vector2i] = []
	var inicio := -(tamanho_pincel - 1) / 2
	for dx in tamanho_pincel:
		for dz in tamanho_pincel:
			lista.append(Vector2i(inicio + dx, inicio + dz))
	return lista


## O pincel inteiro (tamanho × tamanho) centrado em `centro`.
func _aplicar_pincel(centro: Vector3i) -> void:
	for d in deslocamentos_do_pincel():
		_aplicar_celula(centro + Vector3i(d.x, 0, d.y))


func _aplicar_celula(celula: Vector3i) -> void:
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
	if _retangulo:
		var caixa: AABB = retangulo_em_andamento()
		for x in range(int(caixa.position.x), int(caixa.end.x)):
			for z in range(int(caixa.position.z), int(caixa.end.z)):
				_aplicar_celula(Vector3i(x, _camada_pincel, z))
		_retangulo = false
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


# --- Ferramentas do terreno, linha e prévia ------------------------------------------------

func _escolher_ferramenta(nova: Ferramenta) -> void:
	_cancelar_linha()
	ferramenta = nova
	if modo != Modo.TERRENO:
		_escolher_tile(tile_atual)
	_atualizar_barra_ferramentas()
	_atualizar_status()


func _mudar_tamanho_pincel(passo: int) -> void:
	tamanho_pincel = clampi(tamanho_pincel + passo, 1, PINCEL_MAXIMO)
	_atualizar_barra_ferramentas()
	_atualizar_status()


## Um campo de texto está com o foco (as teclas são dele).
func _digitando() -> bool:
	var foco := get_viewport().gui_get_focus_owner()
	return foco is LineEdit or foco is TextEdit


func _comecar_arrasto_camera() -> void:
	_arrastando_camera = true
	_camera_mexeu = false


## Clique da linha do terreno: o primeiro marca o começo (na camada do bloco apontado); o
## segundo confirma. Com Shift ainda apertado, a próxima linha começa onde esta terminou.
func _clique_linha(acao: String) -> void:
	if linha_ativa:
		if acao != _linha_acao:
			_cancelar_linha()
			return
		_confirmar_linha()
		return
	var precisa_de_bloco := acao != "colocar"
	if precisa_de_bloco and not atingiu_bloco:
		return
	linha_ativa = true
	_linha_acao = acao
	linha_inicio = celula_atingida if precisa_de_bloco else celula_alvo
	linha_fim = linha_inicio
	_atualizar_status()


func _continuar_linha() -> void:
	if modo == Modo.OBJETO:
		_continuar_linha_objetos()
		return
	var achada: Variant = _celula_no_plano(linha_inicio.y, _linha_acao)
	if achada != null:
		linha_fim = achada


func _cancelar_linha() -> void:
	linha_ativa = false
	for fantasma_linha in _fantasmas_linha:
		fantasma_linha.queue_free()
	_fantasmas_linha.clear()
	pontos_linha_objetos.clear()
	_atualizar_status()


## Células da linha reta do começo ao fim (na camada do começo), sem buracos na diagonal.
func celulas_da_linha() -> Array[Vector3i]:
	var lista: Array[Vector3i] = []
	var a := Vector2i(linha_inicio.x, linha_inicio.z)
	var b := Vector2i(linha_fim.x, linha_fim.z)
	var passos := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in passos + 1:
		var t := float(i) / maxf(passos, 1)
		var p := Vector2(a).lerp(Vector2(b), t).round()
		var celula := Vector3i(int(p.x), linha_inicio.y, int(p.y))
		if lista.is_empty() or lista[-1] != celula:
			lista.append(celula)
	return lista


func _confirmar_linha() -> void:
	_pincel = _linha_acao
	_camada_pincel = linha_inicio.y
	_retangulo = false
	_mudancas_pincel.clear()
	for celula in celulas_da_linha():
		_aplicar_pincel(celula)
	_terminar_pincel()
	if Input.is_action_pressed("editor_mod_shift"):
		linha_inicio = linha_fim
	else:
		linha_ativa = false
	_atualizar_status()


## Linha de objetos: primeiro clique marca o começo; fantasmas mostram as cópias (uma por metro,
## ou mais espaçadas para objetos grandes) até o mouse; o segundo clique coloca todas.
func _clique_linha_objetos() -> void:
	if fantasma == null:
		return
	if not linha_ativa:
		linha_ativa = true
		_linha_objetos_inicio = ponto_alvo
		_continuar_linha_objetos()
		_atualizar_status()
		return
	_continuar_linha_objetos()
	var colocados: Array[ObjetoFase] = []
	for ponto in pontos_linha_objetos:
		var objeto := fase.adicionar_objeto(entrada_objeto.cena, ponto, 0.0)
		objeto.transform = Transform3D(fantasma.transform.basis, ponto + Vector3.UP * _altura_extra(fantasma))
		objeto.visibilidade = fantasma.visibilidade
		for propriedade in fantasma.propriedades_editaveis():
			objeto.set(propriedade, fantasma.get(propriedade))
		colocados.append(objeto)
		fantasma.ao_colocar_no_editor(rng)
		_cor_livre_no_fantasma()
	if not colocados.is_empty():
		undo.create_action("Linha de %d objeto(s)" % colocados.size())
		for objeto in colocados:
			undo.add_do_method(_readicionar.bind(objeto))
			undo.add_undo_method(_retirar.bind(objeto))
			undo.add_do_reference(objeto)
		undo.commit_action(false)
	var fim := ponto_alvo
	_cancelar_linha()
	if Input.is_action_pressed("editor_mod_shift"):
		linha_ativa = true
		_linha_objetos_inicio = fim


func _continuar_linha_objetos() -> void:
	var fim := ponto_alvo
	var espaco := maxf(1.0, snappedf(_espacamento(), 1.0))
	var plano := Vector3(fim.x - _linha_objetos_inicio.x, 0.0, fim.z - _linha_objetos_inicio.z)
	var quantos := mini(int(plano.length() / espaco) + 1, 64)
	pontos_linha_objetos.clear()
	for i in quantos:
		var p := _linha_objetos_inicio + plano.normalized() * espaco * i if plano.length() > 0.001 \
			else _linha_objetos_inicio
		p.y = _altura_do_chao(p, lerpf(_linha_objetos_inicio.y, fim.y, float(i) / maxf(quantos - 1, 1)))
		pontos_linha_objetos.append(p)
	# Fantasmas: um por ponto (reaproveitados).
	while _fantasmas_linha.size() < pontos_linha_objetos.size():
		var novo := entrada_objeto.cena.instantiate() as ObjetoFase
		novo.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(novo)
		novo.visibilidade = fantasma.visibilidade
		for propriedade in fantasma.propriedades_editaveis():
			novo.set(propriedade, fantasma.get(propriedade))
		_fantasmas_linha.append(novo)
	for i in _fantasmas_linha.size():
		var ativo := i < pontos_linha_objetos.size()
		_fantasmas_linha[i].visible = ativo
		if ativo:
			_fantasmas_linha[i].transform = Transform3D(fantasma.transform.basis,
				pontos_linha_objetos[i] + Vector3.UP * _altura_extra(fantasma))


## Altura do topo do terreno na coluna do ponto (procurando perto de `referencia`).
func _altura_do_chao(ponto: Vector3, referencia: float) -> float:
	var x := floori(ponto.x)
	var z := floori(ponto.z)
	for y in range(floori(referencia) + 3, floori(referencia) - 5, -1):
		var item := terreno.get_cell_item(Vector3i(x, y, z))
		if item != GridMap.INVALID_CELL_ITEM:
			return y + TOPO_TILE.get(item, 1.0)
	return referencia


## O que a prévia translúcida mostra agora: [ação, células].
func celulas_da_previa() -> Array:
	if modo != Modo.TERRENO or _arrastando_camera:
		return ["", []]
	var lista: Array[Vector3i] = []
	# A linha em andamento aparece mesmo com o mouse fora do mapa (até onde ela ia).
	if linha_ativa:
		for celula in celulas_da_linha():
			for d in deslocamentos_do_pincel():
				lista.append(celula + Vector3i(d.x, 0, d.y))
		return [_linha_acao, lista]
	if not alvo_valido:
		return ["", []]
	var acao := acao_do_cursor()
	var retangulo: Variant = retangulo_em_andamento()
	if retangulo != null:
		var caixa: AABB = retangulo
		for x in range(int(caixa.position.x), int(caixa.end.x)):
			for z in range(int(caixa.position.z), int(caixa.end.z)):
				lista.append(Vector3i(x, _camada_pincel, z))
		return [_pincel, lista]
	if _pincel == "" and ferramenta_efetiva() == Ferramenta.BALDE:
		return ["", []]
	var centro := celula_alvo if acao == "colocar" else celula_atingida
	if acao != "colocar" and not atingiu_bloco:
		return ["", []]
	for d in deslocamentos_do_pincel():
		lista.append(centro + Vector3i(d.x, 0, d.y))
	return [acao, lista]


## Prévia translúcida do que vai mudar: o tile escolhido (na cor dele) onde vai ser colocado ou
## trocado; uma caixa vermelha onde vai ser apagado. Um MultiMesh só — barato mesmo com milhares.
func _atualizar_previa_tiles() -> void:
	var dados := celulas_da_previa()
	var acao: String = dados[0]
	var lista: Array = dados[1]
	var chave := "%s|%d|%d|%s" % [acao, tile_atual, orientacao, str(lista.slice(0, 1)) + str(lista.size()) + str(lista.slice(-1))]
	if lista.size() > PREVIA_MAXIMA:
		lista = []
	if chave == _chave_previa:
		return
	_chave_previa = chave
	if _previa_tiles == null:
		_previa_tiles = MultiMeshInstance3D.new()
		_previa_tiles.name = "PreviaTiles"
		_previa_tiles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_previa_tiles)
	if lista.is_empty():
		_previa_tiles.visible = false
		return
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var base := Basis.IDENTITY
	if acao == "apagar":
		var caixa := BoxMesh.new()
		caixa.size = Vector3.ONE * 1.02
		multi.mesh = caixa
		material.albedo_color = Color(1.0, 0.3, 0.25, 0.35)
	else:
		multi.mesh = terreno.mesh_library.get_item_mesh(tile_atual)
		var cor: Color = Tiles.definicao(tile_atual).get("cor", Color.WHITE)
		material.albedo_color = Color(cor.r, cor.g, cor.b, 0.5)
		base = Basis(Vector3.UP, orientacao * PI * 0.5)
	_previa_tiles.material_override = material
	multi.instance_count = lista.size()
	for i in lista.size():
		var celula: Vector3i = lista[i]
		multi.set_instance_transform(i, Transform3D(base, terreno.to_global(terreno.map_to_local(celula))))
	_previa_tiles.multimesh = multi
	_previa_tiles.visible = true


## Barra em cima da vista: as ferramentas do terreno (teclas 1 a 5) e o tamanho do pincel.
func _montar_barra_ferramentas() -> void:
	_barra_ferramentas = PanelContainer.new()
	_barra_ferramentas.name = "BarraFerramentas"
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.11, 0.12, 0.14, 0.9)
	estilo.set_corner_radius_all(6)
	estilo.content_margin_left = 6
	estilo.content_margin_right = 6
	estilo.content_margin_top = 4
	estilo.content_margin_bottom = 4
	_barra_ferramentas.add_theme_stylebox_override("panel", estilo)
	var linha := HBoxContainer.new()
	_barra_ferramentas.add_child(linha)
	var grupo := ButtonGroup.new()
	for i in NOMES_FERRAMENTA.size():
		var botao := Button.new()
		botao.icon = IconesDesenhados.textura(ICONES_FERRAMENTA[i])
		botao.tooltip_text = "%s (%d)%s" % [NOMES_FERRAMENTA[i], i + 1,
			["", "", " — ou Shift", " — ou Ctrl + arrastar", " — ou Alt + clique"][i]]
		botao.toggle_mode = true
		botao.button_group = grupo
		botao.focus_mode = Control.FOCUS_NONE
		botao.pressed.connect(_escolher_ferramenta.bind(i))
		linha.add_child(botao)
		_botoes_ferramenta.append(botao)
	linha.add_child(VSeparator.new())
	var menos := Button.new()
	menos.text = " − "
	menos.tooltip_text = "Pincel menor ([ ou Ctrl + roda)"
	menos.focus_mode = Control.FOCUS_NONE
	menos.pressed.connect(_mudar_tamanho_pincel.bind(-1))
	linha.add_child(menos)
	_rotulo_tamanho = Label.new()
	_rotulo_tamanho.custom_minimum_size.x = 64
	_rotulo_tamanho.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	linha.add_child(_rotulo_tamanho)
	var mais := Button.new()
	mais.text = " + "
	mais.tooltip_text = "Pincel maior (] ou Ctrl + roda)"
	mais.focus_mode = Control.FOCUS_NONE
	mais.pressed.connect(_mudar_tamanho_pincel.bind(1))
	linha.add_child(mais)
	$UI.add_child(_barra_ferramentas)
	get_viewport().size_changed.connect(_posicionar_barra_ferramentas)
	_posicionar_barra_ferramentas.call_deferred()
	_atualizar_barra_ferramentas()


## A barra fica no meio da vista 3D, entre a paleta e o painel da direita, logo abaixo do topo.
func _posicionar_barra_ferramentas() -> void:
	if _barra_ferramentas == null:
		return
	var esquerda := ($UI/PainelPaleta as Control).get_global_rect().end.x
	var direita := ($UI/PainelInspetor as Control).get_global_rect().position.x
	var topo := ($UI/BarraTopo as Control).get_global_rect().end.y
	_barra_ferramentas.reset_size()
	var largura := _barra_ferramentas.size.x
	_barra_ferramentas.position = Vector2(roundf((esquerda + direita - largura) * 0.5), topo + 6)


func _atualizar_barra_ferramentas() -> void:
	if _barra_ferramentas == null:
		return
	_barra_ferramentas.visible = modo == Modo.TERRENO
	for i in _botoes_ferramenta.size():
		_botoes_ferramenta[i].set_pressed_no_signal(i == ferramenta)
	_rotulo_tamanho.text = "%d × %d" % [tamanho_pincel, tamanho_pincel]


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
	_cor_livre_no_fantasma()


func _comecar_espalhar() -> void:
	if fantasma == null:
		return
	_espalhando = true
	_espalhados.clear()
	_espalhar_um(ponto_livre)


## Distância mínima entre objetos espalhados: pelo tamanho do objeto.
func _espacamento() -> float:
	var caixa := fantasma.caixa_editor()
	return clampf(maxf(caixa.size.x, caixa.size.z) * 0.75 * fantasma.scale.x, 0.6, 3.0)


func _continuar_espalhar() -> void:
	if ponto_livre.distance_to(_ultimo_espalhado) >= _espacamento():
		_espalhar_um(ponto_livre)


func _espalhar_um(ponto: Vector3) -> void:
	var jitter := Vector3(rng.randf_range(-0.25, 0.25), 0.0, rng.randf_range(-0.25, 0.25))
	var objeto := fase.adicionar_objeto(entrada_objeto.cena, ponto + jitter, 0.0)
	objeto.transform = Transform3D(fantasma.transform.basis, ponto + jitter + Vector3.UP * _altura_extra(fantasma))
	objeto.visibilidade = fantasma.visibilidade
	for propriedade in fantasma.propriedades_editaveis():
		objeto.set(propriedade, fantasma.get(propriedade))
	_espalhados.append(objeto)
	_ultimo_espalhado = ponto
	fantasma.ao_colocar_no_editor(rng)


func _terminar_espalhar() -> void:
	_espalhando = false
	if _espalhados.is_empty():
		return
	var lista := _espalhados.duplicate()
	undo.create_action("Espalhar %d objeto(s)" % lista.size())
	for objeto in lista:
		undo.add_do_method(_readicionar.bind(objeto))
		undo.add_undo_method(_retirar.bind(objeto))
		undo.add_do_reference(objeto)
	undo.commit_action(false)
	_espalhados.clear()


## Conta-gotas (G): escolhe o objeto ou o tile que está sob o cursor, com as mesmas
## propriedades (variante, visibilidade, giro).
func _conta_gotas() -> void:
	var mouse := get_viewport().get_mouse_position()
	var origem := camera.project_ray_origin(mouse)
	var direcao := camera.project_ray_normal(mouse)
	var objeto := _objeto_no_raio(origem, direcao)
	if objeto:
		for entrada in _catalogo:
			if entrada.caminho == objeto.scene_file_path:
				_escolher_objeto(entrada)
				fantasma.visibilidade = objeto.visibilidade
				fantasma.rotation = objeto.rotation
				fantasma.scale = objeto.scale
				for propriedade in objeto.propriedades_editaveis():
					fantasma.set(propriedade, objeto.get(propriedade))
				_fantasma_copiado = true
				_avisar("Conta-gotas: %s" % entrada.nome)
				return
	var bloco := _raio_na_grade(origem, direcao, 300.0)
	if not bloco.is_empty():
		var celula: Vector3i = bloco.celula
		var base := terreno.get_basis_with_orthogonal_index(terreno.get_cell_item_orientation(celula))
		orientacao = posmod(roundi(base.get_euler().y / (PI * 0.5)), 4)
		_escolher_tile(terreno.get_cell_item(celula))
		_avisar("Conta-gotas: %s" % Tiles.definicao(tile_atual).nome)


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
	elif alvo == fase and propriedade in [&"raca", &"raca_fixa", &"regiao", &"frio"]:
		# A dica das habilidades nativas depende da raça (e o frio mostra mais campos): remonta.
		inspetor.mostrar.call_deferred(fase)


func _renomear_fase() -> void:
	if fase and campo_nome.text != fase.nome:
		_alterar_propriedade(fase, &"nome", campo_nome.text)


func _selecionar(objeto: ObjetoFase) -> void:
	selecionado = objeto
	if not is_node_ready():
		return
	inspetor.mostrar(objeto if objeto else fase)


# --- Trecho, colar e módulos --------------------------------------------------------------

## Coluna (X, Z) sob o mouse: a do bloco apontado ou a do plano da camada.
func coluna_alvo() -> Vector2i:
	if atingiu_bloco:
		return Vector2i(celula_atingida.x, celula_atingida.z)
	return Vector2i(celula_alvo.x, celula_alvo.z)


## Cantos do trecho marcado: [mínimo, máximo] (inclusive).
func cantos_do_trecho() -> Array[Vector2i]:
	return [trecho_inicio.min(trecho_fim), trecho_inicio.max(trecho_fim)]


## Terminou de marcar (ou desmarcou): as camadas ocupadas e o painel da direita.
func _marcar_trecho(marcado: bool) -> void:
	tem_trecho = marcado
	if marcado:
		var cantos := cantos_do_trecho()
		camadas_trecho = Trecho.da_fase(fase, cantos[0], cantos[1]).camadas()
	_mostrar_painel_do_trecho()
	_atualizar_status()


func _mostrar_painel_do_trecho() -> void:
	if not tem_trecho:
		inspetor.mostrar_trecho({})
		return
	var cantos := cantos_do_trecho()
	var trecho := Trecho.da_fase(fase, cantos[0], cantos[1])
	inspetor.mostrar_trecho({largura = trecho.largura, profundidade = trecho.profundidade,
		blocos = trecho.celulas.size(), objetos = trecho.objetos.size()})


## Ctrl+C: copia o trecho marcado (ferramenta Trecho) ou o objeto selecionado.
func _copiar() -> bool:
	var trecho: Trecho = null
	if modo == Modo.TRECHO and tem_trecho:
		var cantos := cantos_do_trecho()
		trecho = Trecho.da_fase(fase, cantos[0], cantos[1])
	elif selecionado and not selecionado.scene_file_path.is_empty():
		trecho = Trecho.do_objeto(selecionado)
	if trecho == null or trecho.vazio():
		_avisar("Nada para copiar: marque um trecho (T) ou selecione um objeto")
		return false
	Fases.area_transferencia = trecho
	_avisar("Copiado: %d × %d (%d blocos, %d objetos) — Ctrl+V cola, também em outra fase" % [
		trecho.largura, trecho.profundidade, trecho.celulas.size(), trecho.objetos.size()], 3.5)
	return true


## Ctrl+X: copia e apaga.
func _recortar() -> void:
	if modo == Modo.TRECHO and tem_trecho:
		if _copiar():
			_apagar_trecho()
	elif selecionado:
		if _copiar():
			_apagar_selecionado()


## Apaga todos os blocos (todas as camadas) e objetos do trecho marcado, numa ação só.
func _apagar_trecho() -> void:
	if not tem_trecho:
		return
	var cantos := cantos_do_trecho()
	var antes := []
	var depois := []
	for celula in terreno.get_used_cells():
		if celula.x >= cantos[0].x and celula.x <= cantos[1].x and celula.z >= cantos[0].y and celula.z <= cantos[1].y:
			antes.append([celula, terreno.get_cell_item(celula), terreno.get_cell_item_orientation(celula)])
			depois.append([celula, GridMap.INVALID_CELL_ITEM, 0])
	var removidos: Array[ObjetoFase] = []
	for objeto in fase.lista_objetos():
		var p := objeto.position
		if p.x >= cantos[0].x and p.x < cantos[1].x + 1 and p.z >= cantos[0].y and p.z < cantos[1].y + 1:
			removidos.append(objeto)
	if antes.is_empty() and removidos.is_empty():
		return
	undo.create_action("Apagar trecho")
	undo.add_do_method(_aplicar_celulas.bind(depois))
	undo.add_undo_method(_aplicar_celulas.bind(antes))
	for objeto in removidos:
		undo.add_do_method(_retirar.bind(objeto))
		undo.add_undo_method(_readicionar.bind(objeto))
		undo.add_undo_reference(objeto)
	undo.commit_action()
	_mostrar_painel_do_trecho()


## Começa a colar `trecho` (Ctrl+V ou um módulo): a prévia segue o mouse; clique cola.
func _comecar_colagem(trecho: Trecho, modulo := "") -> void:
	if trecho == null or trecho.vazio():
		_avisar("Nada copiado ainda: marque um trecho (T) e Ctrl+C")
		return
	_sair_do_trecho(false)
	_trocar_fantasma(null)
	selecionado = null
	modo = Modo.COLAR
	_colagem_base = trecho
	_modulo_colando = modulo
	_giro_colagem = 0
	_desnivel_colagem = 0
	_preparar_colagem()
	_atualizar_barra_ferramentas()
	inspetor.mostrar_colagem({largura = trecho.largura, profundidade = trecho.profundidade,
		blocos = trecho.celulas.size(), objetos = trecho.objetos.size(), modulo = Modulos.nome(modulo) if modulo else ""})
	_marcar_botao_da_ferramenta()
	_atualizar_status()


func _colar_modulo(caminho: String) -> void:
	var trecho := Modulos.carregar(caminho)
	if trecho == null:
		_avisar("Não consegui abrir o módulo %s" % caminho.get_file())
		return
	_comecar_colagem(trecho, caminho)
	_lembrar_recente("modulo:" + caminho)


## Gira o trecho e remonta a prévia: um GridMap com os blocos e fantasmas dos objetos.
func _preparar_colagem() -> void:
	colagem = _colagem_base.girado(_giro_colagem)
	if _previa:
		_previa.queue_free()
	_previa = Node3D.new()
	_previa.name = "PreviaColagem"
	add_child(_previa)
	var grade := GridMap.new()
	grade.mesh_library = terreno.mesh_library
	grade.cell_size = terreno.cell_size
	grade.collision_layer = 0
	grade.collision_mask = 0
	_previa.add_child(grade)
	for dados in colagem.celulas:
		grade.set_cell_item(dados[0], dados[1], grade.get_orthogonal_index_from_basis(dados[2]))
	for dados in colagem.objetos:
		var cena := load(dados.cena) as PackedScene
		if cena == null:
			continue
		var fantasma_objeto := cena.instantiate() as ObjetoFase
		fantasma_objeto.process_mode = Node.PROCESS_MODE_DISABLED
		_previa.add_child(fantasma_objeto)
		fantasma_objeto.transform = dados.transform
		for nome in dados.propriedades:
			fantasma_objeto.set(nome, dados.propriedades[nome])
	_previa.visible = false


## Cola onde está a prévia (numa ação só, para desfazer).
func _colar_aqui() -> void:
	if colagem == null:
		return
	var mudancas := colagem.aplicar_em(fase, origem_colagem)
	undo.create_action("Colar trecho")
	undo.add_do_method(_aplicar_celulas.bind(mudancas.depois))
	undo.add_undo_method(_aplicar_celulas.bind(mudancas.antes))
	for objeto: ObjetoFase in mudancas.objetos:
		undo.add_do_method(_readicionar.bind(objeto))
		undo.add_undo_method(_retirar.bind(objeto))
		undo.add_do_reference(objeto)
	undo.commit_action(false)


## Salva o trecho marcado como módulo (scenes/modulos/<nome>.tscn). Nome repetido: confirma.
func _salvar_modulo(nome_modulo: String, confirmado := false) -> void:
	if not tem_trecho:
		return
	var arquivo := _nome_de_arquivo(nome_modulo)
	if arquivo.is_empty():
		_avisar("Dê um nome ao módulo")
		return
	var destino := Modulos.pasta_para_salvar() + arquivo + ".tscn"
	if not confirmado and FileAccess.file_exists(destino):
		confirmar.dialog_text = "Já existe um módulo \"%s\". Substituir?" % arquivo
		for conexao in confirmar.confirmed.get_connections():
			confirmar.confirmed.disconnect(conexao.callable)
		confirmar.confirmed.connect(_salvar_modulo.bind(nome_modulo, true), CONNECT_ONE_SHOT)
		confirmar.popup_centered()
		return
	var cantos := cantos_do_trecho()
	var trecho := Trecho.da_fase(fase, cantos[0], cantos[1])
	var salvo := Modulos.salvar(trecho, nome_modulo.strip_edges(), arquivo, fase.bioma)
	if salvo.is_empty():
		_avisar("Não consegui salvar o módulo")
		return
	_montar_modulos()
	_avisar("Módulo salvo: %s — está na paleta, em Módulos" % salvo, 3.5)


## Balde (Alt + clique no terreno): troca pelo tile escolhido a mancha inteira de blocos iguais
## ligados ao apontado, na mesma camada. Apontando para o vazio, preenche o vazio da camada
## (limitado ao retângulo do terreno que já existe).
func _balde() -> void:
	var inicio := celula_atingida if atingiu_bloco else celula_alvo
	var item_alvo := terreno.get_cell_item(inicio) if atingiu_bloco else GridMap.INVALID_CELL_ITEM
	var orientacao_nova := terreno.get_orthogonal_index_from_basis(Basis(Vector3.UP, orientacao * PI * 0.5))
	if item_alvo == tile_atual:
		return
	var limite_min := Vector2i(1 << 30, 1 << 30)
	var limite_max := -limite_min
	for celula in terreno.get_used_cells():
		limite_min = limite_min.min(Vector2i(celula.x, celula.z))
		limite_max = limite_max.max(Vector2i(celula.x, celula.z))
	var visitadas := {inicio: true}
	var fila: Array[Vector3i] = [inicio]
	var mancha: Array[Vector3i] = []
	while not fila.is_empty():
		var celula: Vector3i = fila.pop_back()
		if terreno.get_cell_item(celula) != item_alvo:
			continue
		if celula.x < limite_min.x or celula.x > limite_max.x or celula.z < limite_min.y or celula.z > limite_max.y:
			continue
		mancha.append(celula)
		if mancha.size() > BALDE_MAXIMO:
			_avisar("A mancha passa de %d blocos — use o retângulo (Ctrl + arrastar)" % BALDE_MAXIMO)
			return
		for passo in [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
			var vizinha: Vector3i = celula + passo
			if not visitadas.has(vizinha):
				visitadas[vizinha] = true
				fila.append(vizinha)
	if mancha.is_empty():
		return
	var antes := []
	var depois := []
	for celula in mancha:
		antes.append([celula, item_alvo, terreno.get_cell_item_orientation(celula)])
		depois.append([celula, tile_atual, orientacao_nova])
	undo.create_action("Balde: %d bloco(s)" % mancha.size())
	undo.add_do_method(_aplicar_celulas.bind(depois))
	undo.add_undo_method(_aplicar_celulas.bind(antes))
	undo.commit_action()
	_avisar("Balde: %d bloco(s)" % mancha.size())


# --- Mecanismos (ferramenta Ligar) --------------------------------------------------------

## Placas, portões... (objetos com papel no canal) da fase.
func mecanismos() -> Array[ObjetoFase]:
	var lista: Array[ObjetoFase] = []
	for objeto in fase.lista_objetos():
		if objeto.papel_no_canal() != "":
			lista.append(objeto)
	return lista


## Os outros mecanismos com a mesma cor de `objeto`.
func _grupo(objeto: ObjetoFase) -> Array[ObjetoFase]:
	var canal: int = objeto.get(&"canal")
	return mecanismos().filter(func(outro: ObjetoFase) -> bool:
		return outro != objeto and outro.get(&"canal") == canal)


## Primeira cor que nenhum mecanismo usa (fora `ignorar`), ou -1 se as 8 estão em uso.
func _canal_livre(ignorar: ObjetoFase = null) -> int:
	var usados := {}
	for objeto in mecanismos():
		if objeto != ignorar:
			usados[objeto.get(&"canal")] = true
	for canal in Canais.LISTA.size():
		if not usados.has(canal):
			return canal
	return -1


## Mecanismo novo vem com uma cor livre, para não se ligar sem querer ao que já existe.
func _cor_livre_no_fantasma() -> void:
	if fantasma == null or _fantasma_copiado or fantasma.papel_no_canal() == "":
		return
	var livre := _canal_livre()
	if livre >= 0:
		fantasma.set(&"canal", livre)


func _clique_ligar(objeto: ObjetoFase) -> void:
	if objeto == null or objeto == ligar_origem:
		ligar_origem = null
	elif ligar_origem == null or not is_instance_valid(ligar_origem) or not ligar_origem.is_inside_tree():
		ligar_origem = objeto
		_selecionar(objeto)
	else:
		_ligar(ligar_origem, objeto)
		if not Input.is_action_pressed("editor_mod_shift"):
			ligar_origem = null
	_atualizar_status()


## Liga `b` a `a` (a segunda peça fica com a cor da primeira). Se só a segunda já tem ligações,
## é a primeira que entra no grupo dela. Clicar num par já ligado desliga a segunda.
func _ligar(a: ObjetoFase, b: ObjetoFase) -> void:
	var canal_a: int = a.get(&"canal")
	var canal_b: int = b.get(&"canal")
	if canal_a == canal_b:
		if ligar_origem and Input.is_action_pressed("editor_mod_shift"):
			return  # Shift + clique num já ligado: nada a fazer.
		var livre := _canal_livre()
		if livre < 0:
			_avisar("As %d cores já estão em uso: não há como desligar." % Canais.LISTA.size())
			return
		_trocar_canais({b: livre}, "Desligar %s" % b.nome_no_editor())
		_avisar("%s desligado (agora %s)." % [b.nome_no_editor(), Canais.nome(livre).to_lower()])
		return
	if _grupo(a).is_empty() and not _grupo(b).is_empty():
		_trocar_canais({a: canal_b}, "Ligar %s" % a.nome_no_editor())
		_avisar("Ligados (%s)." % Canais.nome(canal_b).to_lower())
	else:
		var saiu := not _grupo(b).is_empty()
		_trocar_canais({b: canal_a}, "Ligar %s" % b.nome_no_editor())
		_avisar("Ligados (%s).%s" % [Canais.nome(canal_a).to_lower(),
			"\n%s saiu das ligações %s." % [b.nome_no_editor(), Canais.nome(canal_b).to_lower()] if saiu else ""])


## Clique direito na ferramenta Ligar: a peça ganha uma cor livre (solta de todas as ligações).
func _isolar(objeto: ObjetoFase) -> void:
	if _grupo(objeto).is_empty():
		_avisar("%s não está ligado a nada." % objeto.nome_no_editor())
		return
	var livre := _canal_livre()
	if livre < 0:
		_avisar("As %d cores já estão em uso." % Canais.LISTA.size())
		return
	if objeto == ligar_origem:
		ligar_origem = null
	_trocar_canais({objeto: livre}, "Soltar %s" % objeto.nome_no_editor())
	_avisar("%s solto (agora %s)." % [objeto.nome_no_editor(), Canais.nome(livre).to_lower()])


func _trocar_canais(mudancas: Dictionary, nome_acao: String) -> void:
	undo.create_action(nome_acao)
	for objeto: ObjetoFase in mudancas:
		undo.add_do_property(objeto, &"canal", mudancas[objeto])
		undo.add_undo_property(objeto, &"canal", objeto.get(&"canal"))
	undo.commit_action()


## Avisos da validação: quem aciona sem ninguém reagindo (e vice-versa), e regra E sem sentido.
func _avisos_de_mecanismos() -> PackedStringArray:
	var avisos: PackedStringArray = []
	var acionam := {}
	var reagem := {}
	for objeto in mecanismos():
		if objeto.canal_opcional() and _grupo(objeto).is_empty():
			continue
		var canal: int = objeto.get(&"canal")
		var lista: Dictionary = acionam if objeto.papel_no_canal() == "aciona" else reagem
		if not lista.has(canal):
			lista[canal] = []
		lista[canal].append(objeto)
	for canal: int in acionam:
		if not reagem.has(canal):
			avisos.append("%s (%s): nada da mesma cor reage a ela." % [
				acionam[canal][0].nome_no_editor(), Canais.nome(canal).to_lower()])
	for canal: int in reagem:
		if not acionam.has(canal):
			avisos.append("%s (%s): nada da mesma cor para acioná-lo." % [
				reagem[canal][0].nome_no_editor(), Canais.nome(canal).to_lower()])
		elif acionam[canal].size() == 1:
			for objeto: ObjetoFase in reagem[canal]:
				if objeto.get(&"regra") == Portao.REGRA_TODAS:
					avisos.append("%s (%s) pede todas as placas (E), mas só há uma." % [
						objeto.nome_no_editor(), Canais.nome(canal).to_lower()])
					break
	return avisos


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

## Céu e luz do bioma da fase (muda junto com a propriedade Bioma, inclusive ao desfazer).
func _aplicar_ambiente() -> void:
	if fase and fase.bioma != _bioma_aplicado:
		_bioma_aplicado = fase.bioma
		Biomas.aplicar_ambiente($Ambiente, fase.bioma)
		_atualizar_icones_dos_tiles()


## Os ícones dos tiles na paleta com as texturas do bioma da fase (grama nevada na neve...).
func _atualizar_icones_dos_tiles() -> void:
	if fase == null or fase.bioma == _bioma_icones or _botoes_tile.is_empty():
		return
	_bioma_icones = fase.bioma
	var biblioteca: MeshLibrary = load(Tiles.biblioteca_do_bioma(fase.bioma))
	for id: int in _botoes_tile:
		(_botoes_tile[id] as Button).icon = icones.icone_tile(biblioteca, id)


func _on_versao_mudou() -> void:
	modificado = true
	_aplicar_ambiente()
	_caixas.clear()
	inspetor.atualizar_valores()
	# Objeto recolocado (desfazer "Apagar") ou com a visibilidade trocada tem de seguir a
	# visão atual (ex.: um "só 3D" não pode aparecer na visão isométrica).
	_aplicar_visao()
	_atualizar_status()


func _atualizar_status() -> void:
	if not is_node_ready():
		return
	var texto := "Cursor: clique seleciona; arrastar no vazio gira a vista (Shift: arrasta)"
	match modo:
		Modo.TERRENO:
			texto = "%s %d×%d: %s (giro %d°)" % [NOMES_FERRAMENTA[self.ferramenta], tamanho_pincel,
				tamanho_pincel, Tiles.definicao(tile_atual).nome, orientacao * 90]
			if linha_ativa:
				texto += " — clique confirma a linha (Esc cancela)"
		Modo.OBJETO:
			texto = "Objeto: %s" % entrada_objeto.get("nome", "")
			if linha_ativa:
				texto += " — linha: clique confirma (Esc cancela)"
		Modo.TRECHO:
			if tem_trecho:
				var cantos := cantos_do_trecho()
				texto = "Trecho %d × %d: Ctrl+C copiar, Ctrl+X recortar, Del apagar, direito desmarca" % [
					cantos[1].x - cantos[0].x + 1, cantos[1].y - cantos[0].y + 1]
			else:
				texto = "Trecho: arraste no mapa para marcar (Ctrl+V cola o que foi copiado)"
		Modo.COLAR:
			texto = "Colar%s: clique cola, Q/E gira (%d°), PgUp/PgDn altura (%+d), Esc sai" % [
				" " + Modulos.nome(_modulo_colando) if not _modulo_colando.is_empty() else "",
				_giro_colagem * 90, _desnivel_colagem]
		Modo.LIGAR:
			if ligar_origem:
				texto = "Ligar: %s (%s) → clique no que ligar (Shift: continuar; Esc: cancelar)" % [
					ligar_origem.nome_no_editor(), Canais.nome(ligar_origem.get(&"canal")).to_lower()]
			else:
				texto = "Ligar: clique numa placa ou num portão (direito: soltar das ligações)"
	var arquivo := caminho.get_file() if not caminho.is_empty() else "(não salva)"
	var sob := "   |   " + objeto_sob_mouse.nome_no_editor() if objeto_sob_mouse else ""
	status.text = "%s%s   |   Camada %d   |   Visão: %s   |   %s%s   |   H: atalhos" % [
		texto, sob, camada, NOMES_VISAO[visao], arquivo, "  •  modificada" if modificado else ""]


func _avisar(texto: String, segundos := 2.5) -> void:
	aviso.text = texto
	aviso.show()
	if _tween_aviso:
		_tween_aviso.kill()
	_tween_aviso = create_tween()
	_tween_aviso.tween_interval(segundos)
	_tween_aviso.tween_callback(aviso.hide)

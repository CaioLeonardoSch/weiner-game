extends Node
## Qual fase jogar/editar e a troca entre o jogo e o editor (autoload "Fases").
##
## As fases são cenas em scenes/fases/ (dentro do projeto, versionadas). Num jogo exportado
## a pasta do projeto é só leitura, então o editor salva em user://fases/.

const PASTA_PROJETO := "res://scenes/fases/"
const PASTA_USUARIO := "user://fases/"
const CENA_JOGO := "res://scenes/jogo.tscn"
const CENA_EDITOR := "res://scenes/editor/editor_fase.tscn"
const CENA_MENU := "res://scenes/menu.tscn"
const ARQUIVO_PROGRESSO := "user://progresso.cfg"

## Arquivo da fase em uso ("" = fase nova, ainda não salva).
var caminho_atual := ""
## Edição ainda não salva, vinda do editor: tem prioridade sobre o arquivo.
var rascunho: PackedScene
var rascunho_modificado := false
## O jogo foi aberto pelo editor para testar (F1 volta para ele).
var testando := false
## Câmera, ferramenta etc. do editor, para voltar do teste onde estava.
var estado_editor := {}
## Progresso e preferências do jogador (fases concluídas, skin...), em user://progresso.cfg.
var progresso := ConfigFile.new()


func _ready() -> void:
	progresso.load(ARQUIVO_PROGRESSO)
	var lista := listar()
	if not lista.is_empty():
		caminho_atual = lista[0]


## Todas as fases (projeto + usuário), em ordem de nome de arquivo.
func listar() -> PackedStringArray:
	var caminhos := PackedStringArray()
	if DirAccess.dir_exists_absolute(PASTA_PROJETO):
		for arquivo in ResourceLoader.list_directory(PASTA_PROJETO):
			if arquivo.ends_with(".tscn") or arquivo.ends_with(".scn"):
				caminhos.append(PASTA_PROJETO + arquivo)
	if DirAccess.dir_exists_absolute(PASTA_USUARIO):
		for arquivo in DirAccess.get_files_at(PASTA_USUARIO):
			if arquivo.ends_with(".tscn"):
				caminhos.append(PASTA_USUARIO + arquivo)
	var ordenado := Array(caminhos)
	ordenado.sort_custom(func(a: String, b: String) -> bool: return a.get_file() < b.get_file())
	return PackedStringArray(ordenado)


## Onde o editor grava fases novas.
func pasta_para_salvar() -> String:
	return PASTA_USUARIO if OS.has_feature("template") else PASTA_PROJETO


## A cena da fase a jogar/editar (rascunho, se houver; senão o arquivo), ou null.
func cena_atual() -> PackedScene:
	if rascunho:
		return rascunho
	if caminho_atual.is_empty() or not ResourceLoader.exists(caminho_atual):
		return null
	# Sem cache: o editor pode ter acabado de salvar por cima.
	return ResourceLoader.load(caminho_atual, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)


## Fase seguinte na lista (ou "" se esta é a última).
func proxima() -> String:
	var lista := listar()
	var indice := lista.find(caminho_atual)
	if indice >= 0 and indice + 1 < lista.size():
		return lista[indice + 1]
	return ""


func jogar(caminho: String) -> void:
	caminho_atual = caminho
	rascunho = null
	rascunho_modificado = false
	testando = false
	get_tree().paused = false
	get_tree().change_scene_to_file(CENA_JOGO)


## Chamado pelo editor: joga a fase como está no editor, sem salvar.
func testar(cena: PackedScene, modificado: bool) -> void:
	rascunho = cena
	rascunho_modificado = modificado
	testando = true
	get_tree().paused = false
	get_tree().change_scene_to_file(CENA_JOGO)


## Nome da fase (propriedade `nome` da raiz), lido sem instanciar a cena.
func nome_da_fase(caminho: String) -> String:
	var cena := ResourceLoader.load(caminho, "PackedScene") as PackedScene
	if cena:
		var estado := cena.get_state()
		for i in estado.get_node_property_count(0):
			if estado.get_node_property_name(0, i) == &"nome":
				return str(estado.get_node_property_value(0, i))
	return caminho.get_file().get_basename()


func concluida(caminho: String) -> bool:
	return caminho.get_file() in progresso.get_value("fases", "concluidas", PackedStringArray())


func marcar_concluida(caminho: String) -> void:
	if caminho.is_empty() or concluida(caminho):
		return
	var lista: PackedStringArray = progresso.get_value("fases", "concluidas", PackedStringArray())
	lista.append(caminho.get_file())
	progresso.set_value("fases", "concluidas", lista)
	salvar_progresso()


func salvar_progresso() -> void:
	progresso.save(ARQUIVO_PROGRESSO)


## A primeira fase ainda não concluída (ou a primeira de todas, se já zerou).
func fase_para_continuar() -> String:
	var lista := listar()
	for caminho in lista:
		if not concluida(caminho):
			return caminho
	return lista[0] if not lista.is_empty() else ""


func abrir_menu() -> void:
	rascunho = null
	rascunho_modificado = false
	testando = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	get_tree().change_scene_to_file(CENA_MENU)


## Abre o editor numa fase existente ("" = fase nova, do zero).
func editar(caminho: String) -> void:
	caminho_atual = caminho
	rascunho = null
	rascunho_modificado = false
	testando = false
	estado_editor = {}
	abrir_editor()


func abrir_editor() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(CENA_EDITOR)

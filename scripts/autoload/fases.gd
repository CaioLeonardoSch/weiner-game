extends Node
## Qual fase jogar/editar e a troca entre o jogo e o editor (autoload "Fases").
##
## As fases são cenas em scenes/fases/ (dentro do projeto, versionadas). Num jogo exportado
## a pasta do projeto é só leitura, então o editor salva em user://fases/.

const PASTA_PROJETO := "res://scenes/fases/"
const PASTA_USUARIO := "user://fases/"
const CENA_JOGO := "res://scenes/jogo.tscn"
const CENA_EDITOR := "res://scenes/editor/editor_fase.tscn"

## Arquivo da fase em uso ("" = fase nova, ainda não salva).
var caminho_atual := ""
## Edição ainda não salva, vinda do editor: tem prioridade sobre o arquivo.
var rascunho: PackedScene
var rascunho_modificado := false
## O jogo foi aberto pelo editor para testar (F1 volta para ele).
var testando := false
## Câmera, ferramenta etc. do editor, para voltar do teste onde estava.
var estado_editor := {}


func _ready() -> void:
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
	get_tree().change_scene_to_file(CENA_JOGO)


## Chamado pelo editor: joga a fase como está no editor, sem salvar.
func testar(cena: PackedScene, modificado: bool) -> void:
	rascunho = cena
	rascunho_modificado = modificado
	testando = true
	get_tree().change_scene_to_file(CENA_JOGO)


func abrir_editor() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(CENA_EDITOR)

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
## O save do jogador. A pasta user:// é fixa (application/config/custom_user_dir_name =
## "WeinerGame" no project.godot; no Windows, %APPDATA%\\WeinerGame): NÃO MUDE, senão o jogo
## novo não acha o progresso de quem já jogava. O teste "save" confere isso.
const ARQUIVO_PROGRESSO := "user://progresso.cfg"
## Formato do progresso.cfg. Mudou o formato? Aumente o número e escreva a conversão em
## `migrar()`, e acrescente um save de exemplo da versão antiga em ferramentas/testes/saves/.
##   1 — sem chave de versão; fases concluídas pelo nome do arquivo ("fase_01.tscn").
##   2 — [save] versao; fases concluídas pelo id da fase (Fase.id, ex.: "fase_01").
const VERSAO_PROGRESSO := 2
## Fases cujo id mudou: id antigo → id novo (o ✓ passa para o novo). Renomear ou mover o
## arquivo NÃO muda o id; só anote aqui se o próprio id for trocado.
const IDS_RENOMEADOS := {}

## Arquivo da fase em uso ("" = fase nova, ainda não salva).
var caminho_atual := ""
## Edição ainda não salva, vinda do editor: tem prioridade sobre o arquivo.
var rascunho: PackedScene
var rascunho_modificado := false
## O jogo foi aberto pelo editor para testar (F1 volta para ele).
var testando := false
## Câmera, ferramenta etc. do editor, para voltar do teste onde estava.
var estado_editor := {}
## "Testar daqui" (F2 no editor): onde o cachorro começa no teste, no lugar do Início (ou null).
var inicio_do_teste: Variant = null
## O que o editor copiou (Ctrl+C: um Trecho). Fica aqui para dar para colar em outra fase.
var area_transferencia: RefCounted
## Progresso e preferências do jogador (fases concluídas, skin...), em user://progresso.cfg.
var progresso := ConfigFile.new()
## Progresso só na memória, sem ler nem gravar o save do jogador (testes automáticos).
var _so_memoria := false
## caminho da fase → id (ver id_da_fase).
var _ids := {}
## [caminho, propriedade] → valor (ver propriedade_da_fase).
var _propriedades := {}


func _ready() -> void:
	var fumaca := ""
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with("--fumaca="):
			fumaca = argumento.get_slice("=", 1)
			usar_progresso_em_memoria()
	if not _so_memoria and progresso.load(ARQUIVO_PROGRESSO) == OK and migrar(progresso):
		salvar_progresso()
	var lista := listar()
	if not lista.is_empty():
		caminho_atual = lista[0]
	if not fumaca.is_empty():
		_teste_de_fumaca.call_deferred(fumaca)


## Testes: começa com o progresso vazio e nunca lê nem grava user://progresso.cfg (fases
## concluídas e pelagens ficam só na memória). Chamado antes de o autoload entrar na árvore,
## o arquivo nem chega a ser lido.
func usar_progresso_em_memoria() -> void:
	_so_memoria = true
	progresso = ConfigFile.new()


## Todas as fases (projeto + usuário), na ordem das regiões (Regiao.ordem) e, dentro de cada
## região, pelo nome do arquivo. É a ordem do menu e da "próxima fase".
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
	var ordem := {}
	for caminho: String in ordenado:
		ordem[caminho] = Regioes.ordem(regiao_da_fase(caminho))
	ordenado.sort_custom(func(a: String, b: String) -> bool:
		if ordem[a] != ordem[b]:
			return ordem[a] < ordem[b]
		return a.get_file() < b.get_file())
	return PackedStringArray(ordenado)


## Id da região da fase (Fase.regiao).
func regiao_da_fase(caminho: String) -> StringName:
	return StringName(str(propriedade_da_fase(caminho, &"regiao", Regioes.PADRAO)))


## As fases de uma região, em ordem.
func fases_da_regiao(regiao: StringName) -> PackedStringArray:
	var lista := PackedStringArray()
	for caminho in listar():
		if regiao_da_fase(caminho) == regiao:
			lista.append(caminho)
	return lista


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
	inicio_do_teste = null
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
	var nome := str(propriedade_da_fase(caminho, &"nome", ""))
	return nome if not nome.is_empty() else caminho.get_file().get_basename()


## Id da fase (Fase.id; se vazio, o nome do arquivo sem extensão). É o que vai para o save.
func id_da_fase(caminho: String) -> String:
	if caminho.is_empty():
		return ""
	if not _ids.has(caminho):
		var id := str(propriedade_da_fase(caminho, &"id", ""))
		_ids[caminho] = id if not id.is_empty() else caminho.get_file().get_basename()
	return _ids[caminho]


## O editor gravou este arquivo: o id (e o nome, a região...) pode ter mudado.
func esquecer_id(caminho: String) -> void:
	_ids.erase(caminho)
	for chave: Array in _propriedades.keys():
		if chave[0] == caminho:
			_propriedades.erase(chave)


## Uma propriedade da raiz da cena da fase, lida sem instanciar (ou `padrao`). Guardada até o
## editor gravar o arquivo de novo (esquecer_id).
func propriedade_da_fase(caminho: String, propriedade: StringName, padrao: Variant) -> Variant:
	var chave := [caminho, propriedade]
	if _propriedades.has(chave):
		return _propriedades[chave]
	var valor: Variant = padrao
	# Sem o cache do ResourceLoader: o editor pode ter acabado de gravar por cima.
	var cena := ResourceLoader.load(caminho, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if cena:
		var estado := cena.get_state()
		for i in estado.get_node_property_count(0):
			if estado.get_node_property_name(0, i) == propriedade:
				valor = estado.get_node_property_value(0, i)
	_propriedades[chave] = valor
	return valor


func concluida(caminho: String) -> bool:
	return id_da_fase(caminho) in progresso.get_value("fases", "concluidas", PackedStringArray())


func marcar_concluida(caminho: String) -> void:
	if caminho.is_empty() or concluida(caminho):
		return
	var lista: PackedStringArray = progresso.get_value("fases", "concluidas", PackedStringArray())
	lista.append(id_da_fase(caminho))
	progresso.set_value("fases", "concluidas", lista)
	salvar_progresso()


## Converte um progresso de versão antiga para o formato atual (VERSAO_PROGRESSO) e aplica os
## ids renomeados. Devolve true se mudou algo (aí quem chamou salva). Um save de uma versão
## MAIS NOVA do jogo fica como está: nada é apagado, as chaves desconhecidas continuam lá.
static func migrar(cfg: ConfigFile, renomeados: Dictionary = IDS_RENOMEADOS) -> bool:
	var versao := int(cfg.get_value("save", "versao", 1))
	if versao > VERSAO_PROGRESSO:
		push_warning("progresso.cfg da versão %d (este jogo conhece até a %d)" % [versao, VERSAO_PROGRESSO])
		return false
	var antes := cfg.encode_to_text()
	var concluidas := PackedStringArray(cfg.get_value("fases", "concluidas", PackedStringArray()))
	if versao < 2:
		# 1 → 2: nome do arquivo → id (o id das fases de antes é o nome do arquivo).
		for i in concluidas.size():
			concluidas[i] = concluidas[i].get_file().get_basename()
	var atuais := PackedStringArray()
	for id in concluidas:
		var novo: String = renomeados.get(id, id)
		if novo not in atuais:
			atuais.append(novo)
	if cfg.has_section_key("fases", "concluidas") or not atuais.is_empty():
		cfg.set_value("fases", "concluidas", atuais)
	cfg.set_value("save", "versao", VERSAO_PROGRESSO)
	return cfg.encode_to_text() != antes


func salvar_progresso() -> void:
	if not _so_memoria:
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


## Teste de fumaça do jogo exportado (`WeinerGame -- --fumaca=<pasta>`): abre o menu, joga a
## primeira fase, salva duas fotos na pasta e confere o básico (fases e raças encontradas,
## modelos voxel em texto carregados — eles precisam do filtro *.txt na exportação).
## Sai com código 0 se deu tudo certo. Usado pela CI. Não mexe no save do jogador.
func _teste_de_fumaca(pasta: String) -> void:
	var problemas: PackedStringArray = []
	await _esperar_quadros(60)
	get_viewport().get_texture().get_image().save_png(pasta.path_join("fumaca_menu.png"))
	var lista := listar()
	if lista.size() < 5:
		problemas.append("só %d fases encontradas" % lista.size())
	if Racas.todas().size() < 3:
		problemas.append("só %d raças encontradas" % Racas.todas().size())
	if not lista.is_empty():
		jogar(lista[0])
		await _esperar_quadros(90)
		get_viewport().get_texture().get_image().save_png(pasta.path_join("fumaca_fase.png"))
		var jogo := get_tree().current_scene
		var dono: Node = jogo.get("dono") if jogo else null
		var malha: Mesh = dono.get_node("Modelo").mesh if dono else null
		if malha == null or malha.get_surface_count() == 0:
			problemas.append("o modelo voxel do dono não carregou (faltou *.txt na exportação?)")
	print("FUMACA ", "ok" if problemas.is_empty() else "falhou: " + "; ".join(problemas))
	get_tree().quit(0 if problemas.is_empty() else 1)


func _esperar_quadros(quantos: int) -> void:
	for i in quantos:
		await get_tree().process_frame

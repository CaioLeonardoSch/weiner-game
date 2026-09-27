class_name Modulos
## Módulos: trechos de fase guardados para reusar (uma ponte de troncos, um celeiro com cerca, um
## bosque nevado...). Cada módulo é uma fase pequena salva em scenes/modulos/ (no jogo exportado,
## em user://modulos/), com o canto do trecho na origem. O editor lista os módulos na paleta e
## salva um trecho selecionado como módulo; um gerador de mapas pode carregar e colar módulos
## com `Trecho.aplicar_em` (ver Trecho).

const PASTA_PROJETO := "res://scenes/modulos/"
const PASTA_USUARIO := "user://modulos/"


## Todos os módulos (projeto + usuário), pelo nome do arquivo.
static func listar() -> PackedStringArray:
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


## O módulo como Trecho (ou null se o arquivo não for uma fase).
static func carregar(caminho: String) -> Trecho:
	var cena := ResourceLoader.load(caminho, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var fase := cena.instantiate() as Fase if cena else null
	if fase == null:
		return null
	var trecho := Trecho.da_fase_inteira(fase)
	fase.free()
	return trecho


## Nome mostrado (o `nome` da fase do módulo, ou o nome do arquivo).
static func nome(caminho: String) -> String:
	var cena := ResourceLoader.load(caminho, "PackedScene") as PackedScene
	if cena:
		var estado := cena.get_state()
		for i in estado.get_node_property_count(0):
			if estado.get_node_property_name(0, i) == &"nome":
				return str(estado.get_node_property_value(0, i))
	return caminho.get_file().get_basename()


## Onde salvar módulos novos (a pasta do projeto é só leitura no jogo exportado).
static func pasta_para_salvar() -> String:
	return PASTA_USUARIO if OS.has_feature("template") else PASTA_PROJETO


## Salva o trecho como módulo (em `pasta`; padrão: pasta_para_salvar). Devolve o caminho ou ""
## se deu erro.
static func salvar(trecho: Trecho, nome_modulo: String, arquivo: String, bioma := Biomas.FLORESTA,
		pasta := "") -> String:
	var fase := trecho.para_fase(nome_modulo, bioma)
	var cena := PackedScene.new()
	var erro := cena.pack(fase)
	fase.free()
	if erro != OK:
		return ""
	var destino := (pasta if not pasta.is_empty() else pasta_para_salvar()) + arquivo + ".tscn"
	DirAccess.make_dir_recursive_absolute(destino.get_base_dir())
	if ResourceSaver.save(cena, destino) != OK:
		return ""
	return destino

class_name Catalogo
## Lista dos objetos que o editor pode colocar: toda cena em scenes/objetos/ cuja raiz
## estende ObjetoFase. Para um objeto novo aparecer na paleta, basta salvar a cena lá.

const PASTA := "res://scenes/objetos/"
## Ordem das categorias na paleta (as que não estiverem aqui vão para o fim).
const ORDEM_CATEGORIAS := ["Regras", "Cenário"]


## Cada item: {cena: PackedScene, caminho, nome, categoria}.
static func objetos() -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	for arquivo in ResourceLoader.list_directory(PASTA):
		if not (arquivo.ends_with(".tscn") or arquivo.ends_with(".scn")):
			continue
		var cena := load(PASTA + arquivo) as PackedScene
		if cena == null:
			continue
		var amostra := cena.instantiate()
		if amostra is ObjetoFase:
			lista.append({
				cena = cena,
				caminho = PASTA + arquivo,
				nome = amostra.nome_no_editor(),
				categoria = amostra.categoria_no_editor(),
			})
		amostra.free()
	lista.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ca := _indice_categoria(a.categoria)
		var cb := _indice_categoria(b.categoria)
		return ca < cb if ca != cb else a.nome.naturalnocasecmp_to(b.nome) < 0)
	return lista


static func _indice_categoria(categoria: String) -> int:
	var indice := ORDEM_CATEGORIAS.find(categoria)
	return indice if indice >= 0 else ORDEM_CATEGORIAS.size()

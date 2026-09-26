class_name Racas
## Catálogo das raças (assets/racas/*.tres) e da pelagem que o jogador escolheu para cada uma
## (guardada no progresso, ver autoload Fases).

const PASTA := "res://assets/racas/"
const PADRAO := &"salsicha"

static var _racas: Array[Raca] = []


static func todas() -> Array[Raca]:
	if _racas.is_empty():
		var arquivos := Array(ResourceLoader.list_directory(PASTA)).filter(
			func(arquivo: String) -> bool: return arquivo.ends_with(".tres"))
		arquivos.sort()
		for arquivo: String in arquivos:
			var raca := load(PASTA + arquivo) as Raca
			if raca:
				_racas.append(raca)
		# A padrão (salsicha) primeiro, depois por nome.
		_racas.sort_custom(func(a: Raca, b: Raca) -> bool:
			if (a.id == PADRAO) != (b.id == PADRAO):
				return a.id == PADRAO
			return a.nome < b.nome)
	return _racas


static func ids() -> PackedStringArray:
	var lista := PackedStringArray()
	for raca in todas():
		lista.append(raca.id)
	return lista


## A raça pelo id (ou a padrão, se não existir).
static func por_id(id: StringName) -> Raca:
	var padrao: Raca = null
	for raca in todas():
		if raca.id == id:
			return raca
		if raca.id == PADRAO:
			padrao = raca
	return padrao if padrao else (todas()[0] if not todas().is_empty() else null)


static func pelagem_escolhida(raca: Raca) -> int:
	var fases := _fases()
	return fases.progresso.get_value("pelagens", String(raca.id), 0) if fases else 0


static func escolher_pelagem(raca: Raca, indice: int) -> void:
	var fases := _fases()
	if fases:
		fases.progresso.set_value("pelagens", String(raca.id), indice)
		fases.salvar_progresso()


static func _fases() -> Node:
	var arvore := Engine.get_main_loop() as SceneTree
	return arvore.root.get_node_or_null("Fases") if arvore else null

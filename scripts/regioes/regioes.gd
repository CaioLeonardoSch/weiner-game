class_name Regioes
## Catálogo das regiões (assets/regioes/*.tres), na ordem do menu.

const PASTA := "res://assets/regioes/"
const PADRAO := &"floresta"

static var _regioes: Array[Regiao] = []


static func todas() -> Array[Regiao]:
	if _regioes.is_empty():
		for arquivo in ResourceLoader.list_directory(PASTA):
			if arquivo.ends_with(".tres"):
				var regiao := load(PASTA + arquivo) as Regiao
				if regiao:
					_regioes.append(regiao)
		_regioes.sort_custom(func(a: Regiao, b: Regiao) -> bool:
			return a.ordem < b.ordem if a.ordem != b.ordem else a.nome < b.nome)
	return _regioes


static func ids() -> PackedStringArray:
	var lista := PackedStringArray()
	for regiao in todas():
		lista.append(regiao.id)
	return lista


## A região pelo id (ou null se não existir).
static func por_id(id: StringName) -> Regiao:
	for regiao in todas():
		if regiao.id == id:
			return regiao
	return null


## Posição da região no menu; regiões desconhecidas vão para o fim.
static func ordem(id: StringName) -> int:
	var regiao := por_id(id)
	return regiao.ordem if regiao else 1000

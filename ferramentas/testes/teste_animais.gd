extends RefCounted
## Ajudantes da rota ferramentas/testes/rotas/animais.txt: põem os bichos novos (tartaruga,
## peixe-cuspidor, castor, texugo, urso) numa fase com uma lagoa e guardam as referências em
## metadados do jogo ("posicoes" guarda onde cada um estava, para conferir que andou).

const NOMES := ["tartaruga", "peixe_cuspidor", "castor", "texugo", "urso"]


static func _colocar(jogo: Node, nome: String, posicao: Vector3) -> Bicho:
	var bicho := jogo.fase.adicionar_objeto(load("res://scenes/objetos/%s.tscn" % nome), posicao) as Bicho
	jogo.set_meta(StringName(nome), bicho)
	return bicho


## No campo (cenas/campo.tscn), fora do cercado: abre uma lagoa de água funda (x 10..15,
## z -13..-9); tartaruga e peixe nela, castor na beira; texugo e urso no gramado.
static func preparar(jogo: Node) -> String:
	var terreno: GridMap = jogo.fase.terreno
	for x in range(10, 16):
		for z in range(-13, -8):
			terreno.set_cell_item(Vector3i(x, -1, z), Tiles.AGUA)
	_colocar(jogo, "tartaruga", Vector3(12.5, 0, -11.5))
	_colocar(jogo, "peixe_cuspidor", Vector3(13.5, 0, -10.5))
	_colocar(jogo, "castor", Vector3(9.5, 0, -11.0))
	_colocar(jogo, "texugo", Vector3(0.5, 0, -10.5))
	_colocar(jogo, "urso", Vector3(22.5, 0, -2.5))
	marcar(jogo)
	return "ok"


## Guarda onde cada bicho está agora.
static func marcar(jogo: Node) -> String:
	var posicoes := {}
	for nome in NOMES:
		posicoes[nome] = (jogo.get_meta(StringName(nome)) as Bicho).bicho.global_position
	jogo.set_meta(&"posicoes", posicoes)
	return str(posicoes)


## O cachorro bem do lado do texugo.
static func cachorro_no_texugo(jogo: Node) -> String:
	var texugo := jogo.get_meta(&"texugo") as Texugo
	jogo.cachorro.global_position = texugo.bicho.global_position + Vector3(1.0, 0.05, 0.0)
	return str(jogo.cachorro.global_position)

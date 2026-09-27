extends RefCounted
## Fases de neve montadas por código para os testes (rotas neve.txt e celeiro.txt): a fogueira
## com gravetos, o frio, a neve fofa, o gelo e o celeiro. As fases vão direto para o jogo como
## um teste do editor (Fases.testar), sem arquivo nenhum.


## Neve fofa, uma faixa de gelo, montes de neve, fogueira (acende com 2 gravetos), 3 gravetos
## comuns, o lendário enterrado perto da fogueira e frio ligado.
static func montar_fogueira(_jogo: Node) -> String:
	var fase := Fase.nova("Teste da fogueira")
	fase.bioma = Biomas.NEVE
	fase.regiao = &"neve"
	fase.frio = true
	fase.tempo_de_frio = 20.0
	fase.habilidades = Fase.HABILIDADE_CAVAR
	var terreno := fase.get_node("Terreno") as GridMap
	for x in range(-3, 12):
		for z in range(-3, 4):
			terreno.set_cell_item(Vector3i(x, -1, z), Tiles.NEVE_FOFA)
		terreno.set_cell_item(Vector3i(x, -1, -4), Tiles.GELO)
		terreno.set_cell_item(Vector3i(x, -1, -5), Tiles.PEDRA)
		terreno.set_cell_item(Vector3i(x, 0, -5), Tiles.PEDRA)
	terreno.set_cell_item(Vector3i(12, 0, -4), Tiles.PEDRA)
	terreno.set_cell_item(Vector3i(6, 0, 0), Tiles.MONTE_DE_NEVE)
	terreno.set_cell_item(Vector3i(7, 0, 0), Tiles.MONTE_DE_NEVE)
	var pasta := "res://scenes/objetos/"
	fase.adicionar_objeto(load(pasta + "inicio_cachorro.tscn"), Vector3(0.5, 0, 0.5))
	fase.adicionar_objeto(load(pasta + "dono.tscn"), Vector3(-2.5, 0, 0.5))
	var fogueira := fase.adicionar_objeto(load(pasta + "fogueira.tscn"), Vector3(4.5, 0, 0.5)) as Fogueira
	fogueira.gravetos_para_acender = 2
	for posicao in [Vector3(-1.5, 0.08, -2.5), Vector3(1.5, 0.08, -2.5), Vector3(1.5, 0.08, 2.5)]:
		var comum := fase.adicionar_objeto(load(pasta + "graveto_comum.tscn"), posicao) as Graveto
		comum.lendario = false
	var lendario := fase.adicionar_objeto(load(pasta + "graveto.tscn"), Vector3(5.5, 0.08, 2.0)) as Graveto
	lendario.enterrado = true
	return _testar(fase)


## Pastoreio na neve: celeiro 5×4 (porta em +X) e duas ovelhas.
static func montar_celeiro(_jogo: Node) -> String:
	var fase := Fase.nova("Teste do celeiro")
	fase.bioma = Biomas.NEVE
	fase.frio = true
	fase.objetivo = Fase.OBJETIVO_PASTOREIO
	fase.raca = &"border_collie"
	var terreno := fase.get_node("Terreno") as GridMap
	for x in range(-6, 16):
		for z in range(-6, 8):
			terreno.set_cell_item(Vector3i(x, -1, z), Tiles.GRAMA)
	var pasta := "res://scenes/objetos/"
	fase.adicionar_objeto(load(pasta + "inicio_cachorro.tscn"), Vector3(-4.5, 0, 0.5))
	fase.adicionar_objeto(load(pasta + "celeiro.tscn"), Vector3(8, 0, 0))
	fase.adicionar_objeto(load(pasta + "ovelha.tscn"), Vector3(2.5, 0, 5.5))
	fase.adicionar_objeto(load(pasta + "ovelha.tscn"), Vector3(4.5, 0, 5.5))
	return _testar(fase)


static func _testar(fase: Fase) -> String:
	var cena := PackedScene.new()
	cena.pack(fase)
	fase.free()
	(Engine.get_main_loop() as SceneTree).root.get_node("Fases").testar(cena, false)
	return "fase montada"


## O cachorro põe o graveto da boca na fogueira (o F perto dela).
static func entregar(jogo: Node) -> String:
	var fogueira := jogo.fase.primeiro(Fogueira) as Fogueira
	jogo.entregar_graveto(fogueira)
	return "gravetos na fogueira: %d" % fogueira.gravetos


static func celula(jogo: Node, x: int, y: int, z: int) -> int:
	return jogo.fase.terreno.get_cell_item(Vector3i(x, y, z))


## Guarda nos metadados do jogo os objetos que as rotas conferem (Expression não enxerga as
## classes): "fogueira", "lendario", "celeiro".
static func marcar(jogo: Node) -> String:
	jogo.set_meta(&"fogueira", jogo.fase.primeiro(Fogueira))
	jogo.set_meta(&"celeiro", jogo.fase.primeiro(Celeiro))
	for graveto in jogo.fase.todos(Graveto):
		if (graveto as Graveto).lendario:
			jogo.set_meta(&"lendario", graveto)
	return "marcados"


static func guardar_uma_ovelha(jogo: Node) -> String:
	return guardar_ovelhas(jogo, 1)


static func guardar_todas(jogo: Node) -> String:
	return guardar_ovelhas(jogo, 99)


## Põe as ovelhas dentro do celeiro (as `quantas` primeiras).
static func guardar_ovelhas(jogo: Node, quantas := 1) -> String:
	var ovelhas: Array = jogo.fase.todos(Ovelha)
	for i in mini(quantas, ovelhas.size()):
		var ovelha := ovelhas[i] as Ovelha
		ovelha.corpo.global_position = Vector3(7.0 + i, 0.05, 0.3 + i * 0.6)
		ovelha.corpo.velocity = Vector3.ZERO
	return "ovelhas no celeiro"


static func balir(jogo: Node) -> String:
	var ovelha := jogo.fase.primeiro(Ovelha) as Ovelha
	ovelha.balir()
	var baloes: Array = jogo.fase.objetos.get_children().filter(func(n: Node) -> bool: return n is Label3D and n.text == "Béé!")
	jogo.set_meta(&"baloes", baloes.size())
	return "balões: %d" % baloes.size()

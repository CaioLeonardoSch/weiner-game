extends RefCounted
## Ajudantes da rota ferramentas/testes/rotas/cavar.txt (Etapa 5: cavar).


static func _colocar(jogo: Node, nome: String, posicao: Vector3, yaw := 0.0) -> ObjetoFase:
	return jogo.fase.adicionar_objeto(load("res://scenes/objetos/%s.tscn" % nome), posicao, yaw)


## No campo (cenas/campo.tscn): graveto comum enterrado, terra fofa no chão e uma cerca com terra fofa.
static func preparar(jogo: Node) -> String:
	jogo.cachorro.pode_cavar = true
	var graveto := _colocar(jogo, "graveto_comum", Vector3(2.5, 0.08, -2.5)) as Graveto
	graveto.enterrado = true
	jogo.set_meta(&"enterrado", graveto)
	jogo.fase.terreno.set_cell_item(Vector3i(2, -1, -5), Tiles.TERRA_FOFA)
	var cerca := _colocar(jogo, "cerca", Vector3(5.5, 0, -2.5), PI * 0.5) as Cerca
	cerca.comprimento = 3
	cerca.terra_fofa = true
	jogo.set_meta(&"cerca", cerca)
	return "ok"


static func tile(jogo: Node, x: int, y: int, z: int) -> int:
	return jogo.fase.terreno.get_cell_item(Vector3i(x, y, z))


## Coloca o cachorro olhando para +X.
static func cachorro_em(jogo: Node, x: float, z: float) -> String:
	jogo.cachorro.posicionar(Vector3(x, 0.05, z), 0.0)
	return "cachorro em %s" % jogo.cachorro.global_position


static func cachorro_em_1_5_menos_2_5(jogo: Node) -> String:
	return cachorro_em(jogo, 1.4, -2.5)


static func cachorro_em_1_5_menos_4_5(jogo: Node) -> String:
	return cachorro_em(jogo, 1.4, -4.5)


static func cachorro_em_4_5_menos_2_5(jogo: Node) -> String:
	return cachorro_em(jogo, 4.4, -2.5)


static func virar_border_collie(jogo: Node) -> String:
	jogo.cachorro.aplicar_raca(Racas.por_id(&"border_collie"), 0)
	return "border collie"


## Um bloco a leste do buraco (2.5, -4.5) e o cachorro atrás dele, olhando para oeste.
static func bloco_para_buraco(jogo: Node) -> String:
	var bloco := _colocar(jogo, "bloco_empurravel", Vector3(3.5, 0, -4.5))
	jogo.set_meta(&"bloco", bloco)
	jogo.cachorro.posicionar(Vector3(4.6, 0.05, -4.5), PI)
	return "bloco em %s" % bloco.global_position

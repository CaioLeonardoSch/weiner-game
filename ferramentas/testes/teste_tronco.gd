extends RefCounted
## Ajudantes da rota ferramentas/testes/rotas/tronco.txt (o tronco que rola, desliza, é puxado
## pela ponta e volta para o lugar quando encalha; empurrar com o graveto ao comprido; tronco
## caído como pinguela; a ponte que cede).


static func _colocar(jogo: Node, nome: String, posicao: Vector3, yaw := 0.0) -> ObjetoFase:
	return jogo.fase.adicionar_objeto(load("res://scenes/objetos/%s.tscn" % nome), posicao, yaw)


static func _tronco(jogo: Node, posicao: Vector3, yaw: float, comprimento: int) -> TroncoRolante:
	var tronco := _colocar(jogo, "tronco_rolante", posicao, yaw) as TroncoRolante
	tronco.comprimento = comprimento
	return tronco


## Fase 11 (margem oeste até x = 4, correnteza em x 5-7): tira o tronco da fase e põe um de 2
## células ao longo de X (x 1 e 2, z = -3); o cachorro atrás dele (+Z), olhando para ele (-Z).
static func preparar_tronco(jogo: Node) -> String:
	var da_fase: Node = jogo.fase.get_node("Objetos").get_node("TroncoRolante")
	da_fase.get_parent().remove_child(da_fase)
	da_fase.queue_free()
	var tronco := _tronco(jogo, Vector3(1.5, 0, -2.5), 0.0, 2)
	jogo.set_meta(&"tronco", tronco)
	jogo.cachorro.posicionar(Vector3(2.0, 0.05, -1.3), PI * 0.5)
	return "tronco em %s" % [tronco.celulas()]


## Na frente da ponta oeste do tronco (fileira z = -4), olhando ao longo dele (+X).
static func cachorro_na_ponta_oeste(jogo: Node) -> String:
	var ponta: Vector3 = (jogo.get_meta(&"tronco") as TroncoRolante).ponto_da_ponta(0)
	jogo.cachorro.posicionar(Vector3(ponta.x - 1.0, 0.05, -3.5), 0.0)
	return "ok"


## Um tronco de 2 células ao longo de Z já na correnteza (x = 5, z -6 e -5): boia, desce e encalha
## na margem onde o rio estreita — e volta para o lugar. Conta as voltas em "voltas".
static func preparar_encalhe(jogo: Node) -> String:
	var tronco := _tronco(jogo, Vector3(5.5, 0, -5.5), -PI * 0.5, 2)
	jogo.set_meta(&"encalhe", tronco)
	jogo.set_meta(&"voltas", 0)
	tronco.voltou_ao_inicio.connect(func() -> void: jogo.set_meta(&"voltas", int(jogo.get_meta(&"voltas")) + 1))
	return "ok"


## Fase 06: um bloco a 2 m do cachorro, e na boca um graveto comprido (1,4 m).
static func preparar_graveto_empurra(jogo: Node) -> String:
	var bloco := _colocar(jogo, "bloco_empurravel", Vector3(4.5, 0, -1.5))
	jogo.set_meta(&"bloco", bloco)
	jogo.cachorro.posicionar(Vector3(2.4, 0.05, -1.5), 0.0)
	return dar_graveto(jogo)


## Um graveto comum comprido (1,4 m, peso 1) direto na boca (sem a troca de câmera).
static func dar_graveto(jogo: Node) -> String:
	var graveto := _colocar(jogo, "graveto_comum", jogo.cachorro.global_position) as Graveto
	graveto.comprimento = 1.4
	graveto.ja_pego = true
	jogo.cachorro.pegar_graveto(graveto)
	jogo.set_meta(&"graveto", graveto)
	return "graveto na boca"


static func virar(jogo: Node) -> String:
	return "virou" if jogo.cachorro.virar_graveto() else "não virou"


## Tronco caído como pinguela sobre o canal fundo (x = 11), ao longo de X.
static func preparar_pinguela(jogo: Node) -> String:
	var tronco := _colocar(jogo, "tronco_caido", Vector3(11.5, 0, -4.5)) as TroncoCaido
	tronco.pinguela = true
	jogo.set_meta(&"pinguela", tronco)
	return "ok"


## 2,6 m antes do bloco, olhando para ele (+X): espaço para virar o graveto ao comprido.
static func recuar_do_bloco(jogo: Node) -> String:
	var bloco: Node3D = jogo.get_meta(&"bloco")
	jogo.cachorro.posicionar(bloco.global_position - Vector3(2.6, -0.05, 0), 0.0)
	return "x = %.2f" % jogo.cachorro.global_position.x


## Fase 08 (riacho fundo em x = 8): troca a ponte por uma que cede com o tempo e põe o cachorro
## parado em cima dela.
static func preparar_ponte_que_cede(jogo: Node) -> String:
	var velha: Node = jogo.fase.get_node("Objetos").get_node("Ponte")
	velha.get_parent().remove_child(velha)
	velha.queue_free()
	var ponte := _colocar(jogo, "ponte", Vector3(8.5, 0, -2.5)) as Ponte
	ponte.tamanho = Vector3(1.0, 0.12, 1.4)
	ponte.tipo = Ponte.Tipo.CEDE
	ponte.tempo_para_ceder = 1.0
	jogo.set_meta(&"ponte", ponte)
	jogo.cachorro.posicionar(Vector3(7.0, 0.05, -2.5), 0.0)
	return "ok"


## Fase 06, num gramado livre: uma placa de pedra (32.5, 31.5) e uma de madeira (32.5, 34.5), cada
## uma com um tronco de 3 células ao longo de X deitado com o **meio** em cima (células x 31 a 33).
static func preparar_tronco_na_placa(jogo: Node) -> String:
	for dados in [["pedra", Placa.PEDRA, 31.5], ["madeira", Placa.MADEIRA, 34.5]]:
		var placa := _colocar(jogo, "placa", Vector3(32.5, 0, dados[2])) as Placa
		placa.tipo = dados[1]
		jogo.set_meta(StringName("placa_" + dados[0]), placa)
		jogo.set_meta(StringName("tronco_" + dados[0]), _tronco(jogo, Vector3(31.5, 0, dados[2]), 0.0, 3))
	return "ok"


## Os dois troncos com a origem em `x` (as células vão de x a x + 2).
static func _troncos_em(jogo: Node, x: float) -> String:
	for nome in ["pedra", "madeira"]:
		var tronco := jogo.get_meta(StringName("tronco_" + nome)) as TroncoRolante
		tronco.global_position.x = x
	return "células %s" % [(jogo.get_meta(&"tronco_pedra") as TroncoRolante).celulas()]


## A ponta 2 (a última célula) em cima das placas.
static func troncos_com_a_ponta_2(jogo: Node) -> String:
	return _troncos_em(jogo, 30.5)


## A ponta 0 (a origem) em cima das placas.
static func troncos_com_a_ponta_0(jogo: Node) -> String:
	return _troncos_em(jogo, 32.5)


## Nenhuma célula em cima das placas.
static func troncos_fora_das_placas(jogo: Node) -> String:
	return _troncos_em(jogo, 33.5)


## Um graveto comum de 2 m largado ao longo de X com o meio em x = 31.5: só a ponta leste fica
## sobre a placa de madeira (32.5, 34.5).
static func graveto_com_a_ponta_na_placa(jogo: Node) -> String:
	var graveto := _colocar(jogo, "graveto_comum", Vector3(31.5, 0.08, 34.5), PI * 0.5) as Graveto
	graveto.comprimento = 2.0
	jogo.set_meta(&"graveto_na_placa", graveto)
	return "peso %.1f" % graveto.peso_na_placa()

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


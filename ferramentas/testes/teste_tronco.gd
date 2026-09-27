extends RefCounted
## Ajudantes da rota ferramentas/testes/rotas/tronco.txt (Etapas 6 e 7: tronco que rola e boia,
## empurrar com o graveto ao comprido, tronco caído como pinguela).


static func _colocar(jogo: Node, nome: String, posicao: Vector3, yaw := 0.0) -> ObjetoFase:
	return jogo.fase.adicionar_objeto(load("res://scenes/objetos/%s.tscn" % nome), posicao, yaw)


## Fase 04: tronco na margem oeste do rio (x = 2), deitado ao longo de Z (células z -6 e -5);
## o cachorro atrás dele, olhando para o rio (+X).
static func preparar_tronco(jogo: Node) -> String:
	var tronco := _colocar(jogo, "tronco_rolante", Vector3(2.5, 0, -5.5), -PI * 0.5) as TroncoRolante
	jogo.set_meta(&"tronco", tronco)
	jogo.cachorro.posicionar(Vector3(1.35, 0.05, -5.0), 0.0)
	return "tronco em %s" % [tronco.celulas()]


## Cachorro na ponta do tronco, olhando ao longo dele (+Z): empurrar ao comprido não rola.
static func cachorro_na_ponta(jogo: Node) -> String:
	jogo.cachorro.posicionar(Vector3(2.5, 0.05, -6.75), -PI * 0.5)
	return "ok"


static func cachorro_atras(jogo: Node) -> String:
	jogo.cachorro.posicionar(Vector3(1.35, 0.05, -5.0), 0.0)
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

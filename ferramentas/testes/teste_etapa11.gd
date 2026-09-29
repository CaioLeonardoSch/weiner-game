extends RefCounted
## Ajudantes da rota ferramentas/testes/rotas/vento_gelo_fogo.txt (Etapa 11): gelo liso (o
## cachorro e o bloco deslizam até bater), vento forte (empurra, o abrigo segura, o graveto
## vira vela) e o graveto aceso (pega fogo na fogueira, derrete neve, acende a fogueira que só
## acende com fogo e apaga sozinho).
## Tudo na fase 06: chão livre em x -4..6, z -6..-1, uma cerca em z = 0 e chão de novo em z 1..5.


static func _colocar(jogo: Node, nome: String, posicao: Vector3, yaw := 0.0, propriedades := {}) -> ObjetoFase:
	var objeto := (load("res://scenes/objetos/%s.tscn" % nome) as PackedScene).instantiate() as ObjetoFase
	for chave in propriedades:
		objeto.set(chave, propriedades[chave])
	objeto.position = posicao
	objeto.rotation.y = yaw
	jogo.fase.get_node("Objetos").add_child(objeto, true)
	return objeto


## Duas fileiras de gelo liso: z = -3 (x 0..3, com um bloco parado em x = 4 no fim) para o
## cachorro, e z = -6 (x 1..4) para um bloco empurrável que começa em x = 0. O cachorro a
## oeste da primeira, olhando para ela.
static func preparar_gelo(jogo: Node) -> String:
	var terreno: GridMap = jogo.fase.terreno
	for x in range(0, 4):
		terreno.set_cell_item(Vector3i(x, -1, -3), Tiles.GELO_LISO)
	for x in range(1, 5):
		terreno.set_cell_item(Vector3i(x, -1, -6), Tiles.GELO_LISO)
	jogo.set_meta(&"parede", _colocar(jogo, "bloco_empurravel", Vector3(4.5, 0, -2.5)))
	jogo.set_meta(&"bloco", _colocar(jogo, "bloco_empurravel", Vector3(0.5, 0, -5.5)))
	jogo.cachorro.posicionar(Vector3(-0.5, 0.05, -2.5), 0.0)
	return "ok"


static func empurrar_bloco(jogo: Node) -> String:
	(jogo.get_meta(&"bloco") as Empurravel).empurrar(Vector3i(1, 0, 0))
	return "ok"


## Corredor de vento soprando para +X na fileira z = -4 (de x = -3 a 5), com rajada longa. Um
## bloco em x = 3 abriga quem estiver logo depois dele.
static func preparar_vento(jogo: Node) -> String:
	var vento := _colocar(jogo, "vento", Vector3(-3.5, 0, -3.5), PI * 0.5,
		{largura = 1, comprimento = 8, forca = 3.0, forca_rajada = 5.0, intervalo = 15.0, duracao_rajada = 10.0}) as Vento
	jogo.set_meta(&"vento", vento)
	jogo.set_meta(&"abrigo", _colocar(jogo, "bloco_empurravel", Vector3(3.5, 0, -3.5)))
	jogo.cachorro.posicionar(Vector3(4.45, 0.05, -3.5), PI * 0.5)
	return "vento %s" % vento.forca_em(Vector3(0.5, 0.25, -3.5))


static func cachorro_no_vento(jogo: Node) -> String:
	jogo.cachorro.posicionar(Vector3(-1.5, 0.05, -3.5), PI * 0.5)
	return "ok"


## Empurrão do vento com e sem um graveto atravessado na boca (o graveto vira vela).
static func medir_vela(jogo: Node) -> String:
	var cachorro: Dachshund = jogo.cachorro
	cachorro.posicionar(Vector3(0.5, 0.05, -3.5), 0.0)
	var sem := cachorro._efeito_do_vento().length()
	_dar_graveto(jogo)
	var com := cachorro._efeito_do_vento().length()
	jogo.set_meta(&"vela", com / maxf(sem, 0.01))
	(jogo.get_meta(&"vento") as Vento).visible = false
	return "sem %.2f, com %.2f" % [sem, com]


static func _dar_graveto(jogo: Node) -> Graveto:
	var cachorro: Dachshund = jogo.cachorro
	if cachorro.tem_graveto:
		return cachorro.graveto
	var graveto := _colocar(jogo, "graveto_comum", cachorro.global_position) as Graveto
	graveto.ja_pego = true
	cachorro.pegar_graveto(graveto)
	return graveto


## Do outro lado da cerca: uma fogueira acesa (-2.5, 2.5), outra que só acende com fogo (0.5,
## 4.5) e um monte de neve na célula (3, 0, 3). O cachorro, com o graveto atravessado na boca,
## encosta a ponta dele na fogueira acesa.
static func preparar_fogo(jogo: Node) -> String:
	var acesa := _colocar(jogo, "fogueira", Vector3(-2.5, 0, 2.5), 0.0, {gravetos_para_acender = 0}) as Fogueira
	var apagada := _colocar(jogo, "fogueira", Vector3(0.5, 0, 4.5), 0.0,
		{gravetos_para_acender = 0, acende_com_fogo = true}) as Fogueira
	jogo.fase.terreno.set_cell_item(Vector3i(3, 0, 3), Tiles.MONTE_DE_NEVE)
	jogo.set_meta(&"fogueira_acesa", acesa)
	jogo.set_meta(&"fogueira_apagada", apagada)
	var graveto := _dar_graveto(jogo)
	jogo.set_meta(&"graveto", graveto)
	jogo.cachorro.posicionar(Vector3(-2.5 - 0.95, 0.05, 2.5), 0.0)
	return "pontas a %.2f e %.2f da fogueira" % [
		_distancia_xz(graveto.ponta(1.0), acesa.global_position),
		_distancia_xz(graveto.ponta(-1.0), acesa.global_position)]


static func _distancia_xz(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func celula_monte(jogo: Node) -> String:
	jogo.set_meta(&"monte", jogo.fase.terreno.get_cell_item(Vector3i(3, 0, 3)))
	var graveto := jogo.get_meta(&"graveto") as Graveto
	return "célula %d, cachorro %s, pontas %s %s, aceso %s" % [jogo.get_meta(&"monte"), jogo.cachorro.global_position,
		graveto.ponta(1.0), graveto.ponta(-1.0), graveto.aceso]


## O cachorro de frente para o monte de neve, com a ponta acesa encostada nele.
static func ir_ao_monte(jogo: Node) -> String:
	jogo.cachorro.posicionar(Vector3(2.2, 0.05, 3.5), 0.0)
	return "chama %.2f" % (jogo.get_meta(&"graveto") as Graveto).chama


## O cachorro encosta o graveto aceso na fogueira que só acende com fogo.
static func ir_a_fogueira_apagada(jogo: Node) -> String:
	jogo.cachorro.posicionar(Vector3(0.5 - 0.95, 0.05, 4.5), 0.0)
	return "ok"


static func quase_apagar(jogo: Node) -> String:
	jogo.cachorro.posicionar(Vector3(4.5, 0.05, 1.5), 0.0)
	(jogo.get_meta(&"graveto") as Graveto).chama = 0.01
	return "ok"

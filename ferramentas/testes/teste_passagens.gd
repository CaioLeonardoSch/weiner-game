extends RefCounted
## Ajudantes da rota ferramentas/testes/rotas/passagens.txt (Etapa 10): tocas de texugo, a
## portinhola, a alavanca, o portão com atraso e lampadinhas, a comporta e o pássaro que volta.
## Tudo na fase 06: chão livre em x -4..6, z -6..-1, uma cerca em z = 0 e chão de novo em z 1..5.


## Como Fase.adicionar_objeto, mas com as `propriedades` postas antes de entrar na fase (como
## vêm do arquivo da fase — a alavanca registra o canal ao entrar).
static func _colocar(jogo: Node, nome: String, posicao: Vector3, yaw := 0.0, propriedades := {}) -> ObjetoFase:
	var objeto := (load("res://scenes/objetos/%s.tscn" % nome) as PackedScene).instantiate() as ObjetoFase
	for chave in propriedades:
		objeto.set(chave, propriedades[chave])
	objeto.position = posicao
	objeto.rotation.y = yaw
	jogo.fase.get_node("Objetos").add_child(objeto, true)
	return objeto


## Uma toca virada para -X em (4, -2.5) e a outra (mesma cor) do outro lado da cerca; o cachorro
## a oeste da primeira, olhando para ela.
static func preparar_tocas(jogo: Node) -> String:
	var a := _colocar(jogo, "toca", Vector3(4.0, 0, -2.5), -PI * 0.5, {canal = 5}) as Toca
	var b := _colocar(jogo, "toca", Vector3(4.0, 0, 3.5), -PI * 0.5, {canal = 5}) as Toca
	jogo.set_meta(&"toca_b", b)
	jogo.cachorro.posicionar(Vector3(2.0, 0.05, -2.5), 0.0)
	return "par: %s" % (a.par() == b)


## Portinhola atravessada no caminho (a frente, +Z local, para +X) em x = 3.5, z = -4.5; o
## cachorro a oeste, olhando para ela.
static func preparar_portinhola(jogo: Node) -> String:
	var portinhola := _colocar(jogo, "portinhola", Vector3(3.5, 0, -4.5), PI * 0.5) as Portinhola
	jogo.set_meta(&"portinhola", portinhola)
	jogo.cachorro.posicionar(Vector3(2.2, 0.05, -4.5), 0.0)
	return "ok"


static func mao_unica(jogo: Node) -> String:
	(jogo.get_meta(&"portinhola") as Portinhola).mao_unica = true
	return "ok"


## Duas alavancas (roxas) e dois portões: um com a regra E (lampadinhas) e outro, OU, com 3 s de
## atraso para fechar. Longe do cachorro, para o vão ficar livre.
static func preparar_alavancas(jogo: Node) -> String:
	var a := _colocar(jogo, "alavanca", Vector3(-3.5, 0, -5.5), 0.0, {canal = 4}) as Alavanca
	var b := _colocar(jogo, "alavanca", Vector3(-2.5, 0, -5.5), 0.0, {canal = 4}) as Alavanca
	var e := _colocar(jogo, "portao", Vector3(0.5, 0, -5.5), 0.0, {canal = 4, regra = Portao.REGRA_TODAS}) as Portao
	var ou := _colocar(jogo, "portao", Vector3(-3.5, 0, 2.5), 0.0, {canal = 4, atraso = 3.0}) as Portao
	jogo.set_meta(&"alavanca_a", a)
	jogo.set_meta(&"alavanca_b", b)
	jogo.set_meta(&"portao_e", e)
	jogo.set_meta(&"portao_ou", ou)
	return "ok"


static func puxar_a(jogo: Node) -> String:
	(jogo.get_meta(&"alavanca_a") as Alavanca).executar_acao(jogo.cachorro)
	return "ok"


static func puxar_b(jogo: Node) -> String:
	(jogo.get_meta(&"alavanca_b") as Alavanca).executar_acao(jogo.cachorro)
	return "ok"


## Guarda em metas as lâmpadas acesas do portão E e a água (funda/rasa) do trecho da comporta.
static func contar(jogo: Node) -> String:
	if jogo.has_meta(&"portao_e"):
		jogo.set_meta(&"lampadas", _lampadas_acesas(jogo))
	if jogo.has_meta(&"comporta"):
		jogo.set_meta(&"agua_funda", _celulas_com(jogo, Tiles.AGUA))
		jogo.set_meta(&"agua_rasa", _celulas_com(jogo, Tiles.AGUA_RASA))
	return "ok"


## Lâmpadas acesas do portão E (as que têm brilho).
static func _lampadas_acesas(jogo: Node) -> int:
	var acesas := 0
	for luz: MeshInstance3D in (jogo.get_meta(&"portao_e") as Portao)._luzes:
		var material := luz.material_override as StandardMaterial3D
		if material and material.emission_enabled:
			acesas += 1
	return acesas


## Água funda num trecho de 3 × 4 células (x -1..1, z 2..5) e uma comporta verde na frente.
static func preparar_comporta(jogo: Node) -> String:
	var terreno: GridMap = jogo.fase.terreno
	for x in range(-1, 2):
		for z in range(2, 6):
			terreno.set_cell_item(Vector3i(x, -1, z), Tiles.AGUA)
	var comporta := _colocar(jogo, "comporta", Vector3(0.5, 0, 1.5), 0.0, {canal = 3}) as Comporta
	var alavanca := _colocar(jogo, "alavanca", Vector3(3.5, 0, 1.5), 0.0, {canal = 3}) as Alavanca
	jogo.set_meta(&"comporta", comporta)
	jogo.set_meta(&"alavanca_comporta", alavanca)
	jogo.cachorro.posicionar(Vector3(4.5, 0.05, 3.5), 0.0)
	return "%d células guardadas" % comporta._originais.size()


static func puxar_comporta(jogo: Node) -> String:
	(jogo.get_meta(&"alavanca_comporta") as Alavanca).executar_acao(jogo.cachorro)
	return "ok"


## Quantas células do trecho estão com o tile `id`.
static func _celulas_com(jogo: Node, id: int) -> int:
	var terreno: GridMap = jogo.fase.terreno
	var total := 0
	for x in range(-1, 2):
		for z in range(2, 6):
			if terreno.get_cell_item(Vector3i(x, -1, z)) == id:
				total += 1
	return total


## Um pássaro que volta depois de 2 s; o latido vem do cachorro.
static func preparar_passaro(jogo: Node) -> String:
	var passaro := _colocar(jogo, "passaro", Vector3(-2.5, 0, -2.5), 0.7, {volta_depois = 2.0})
	jogo.set_meta(&"passaro", passaro)
	jogo.set_meta(&"passaro_giro", passaro.rotation.y)
	passaro.ao_ouvir_latido(passaro.global_position + Vector3(1, 0, 0))
	return "ok"

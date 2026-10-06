extends RefCounted
## Ajudantes da rota ferramentas/testes/rotas/hud.txt (comportamentos do HUD e dos controles).


## No campo (cenas/campo.tscn): põe o bloco encostado no portão (fechado) e o cachorro entre os dois, olhando para
## o norte. Segurando F e andando para o bloco, o cachorro vira e agarra; puxar não dá (sem
## espaço atrás, o portão).
static func puxar_contra_o_portao(jogo: Node) -> String:
	var bloco: Node3D = null
	for objeto in jogo.fase.lista_objetos():
		if objeto is Empurravel:
			bloco = objeto
	bloco.global_position = Vector3(5.5, 0, -2.5)
	jogo.cachorro.posicionar(Vector3(6.55, 0.05, -2.5), PI * 0.5)
	return "bloco em %s, cachorro em %s" % [bloco.global_position, jogo.cachorro.global_position]


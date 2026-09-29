extends RefCounted
## Ajudantes da rota ferramentas/testes/rotas/clima.txt: grama com poças e lama no chão da fase
## 06 (x -4..6, z -6..-1) e a troca de clima (chuva, ventania, tempestade, neve).


## Grama com poças a oeste e lama a leste do cachorro, que fica no meio.
static func pintar_chao(jogo: Node) -> String:
	var terreno: GridMap = jogo.fase.terreno
	for z in range(-6, 0):
		for x in range(-4, 1):
			terreno.set_cell_item(Vector3i(x, -1, z), Tiles.GRAMA_COM_POCAS)
		for x in range(2, 6):
			terreno.set_cell_item(Vector3i(x, -1, z), Tiles.LAMA)
	jogo.cachorro.posicionar(Vector3(1.5, 0.05, -3.5), 0.0)
	return "ok"


static func chuva(jogo: Node) -> String:
	jogo.trocar_clima(Clima.CHUVA)
	return "ok"


static func ventania(jogo: Node) -> String:
	jogo.trocar_clima(Clima.VENTANIA)
	return "ok"


static func tempestade(jogo: Node) -> String:
	jogo.trocar_clima(Clima.TEMPESTADE)
	return "ok"


static func neve(jogo: Node) -> String:
	jogo.trocar_clima(Clima.NEVE)
	return "ok"


static func tempo_bom(jogo: Node) -> String:
	jogo.trocar_clima(Clima.TEMPO_BOM)
	return "ok"


## Força um relâmpago agora (o trovão vem depois).
static func raio(jogo: Node) -> String:
	(jogo.clima as Clima)._raio()
	return "ok"


## Guarda em metas a chuva e o vento que o clima manda para os shaders (sem janela, o servidor
## de renderização não devolve os parâmetros globais) e quantos pontos de respingo há.
static func medir(jogo: Node) -> String:
	jogo.set_meta(&"chuva_global", (jogo.clima as Clima).chuva)
	jogo.set_meta(&"vento_global", (jogo.clima as Clima).vento.length())
	var respingos := jogo.clima.get_node_or_null(^"Respingos") as CPUParticles3D
	jogo.set_meta(&"respingos", respingos.emission_points.size() if respingos else 0)
	return "chuva %.2f, vento %.2f, respingos %d" % [jogo.get_meta(&"chuva_global"), jogo.get_meta(&"vento_global"), jogo.get_meta(&"respingos")]

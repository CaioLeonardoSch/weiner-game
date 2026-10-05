extends RefCounted
## Ajudantes da rota ferramentas/testes/rotas/parque.txt.


## Põe o cachorro em cima da bolinha (onde quer que ela tenha caído).
static func ir_na_bolinha(jogo: Node) -> String:
	var bolinha: Bolinha = jogo.objetivo.bolinha
	var cachorro: Dachshund = jogo.cachorro
	cachorro.global_position = bolinha.global_position + Vector3.UP * 0.05
	return "ok"

extends RefCounted
## Ajudantes da rota ferramentas/testes/rotas/movimento.txt (Etapa 4: rampa lisa, degrau alto).


## No campo (cenas/campo.tscn): rampa lisa baixa subindo para +X em (2, 0, -5) até um meio bloco em x = 3; e um
## degrau alto em (2, 0, -2).
static func preparar(jogo: Node) -> String:
	var terreno: GridMap = jogo.fase.terreno
	terreno.set_cell_item(Vector3i(2, 0, -5), Tiles.RAMPA_LISA_BAIXA)
	terreno.set_cell_item(Vector3i(3, 0, -5), Tiles.MEIO_BLOCO)
	terreno.set_cell_item(Vector3i(2, 0, -2), Tiles.DEGRAU_ALTO)
	jogo.cachorro.pode_pular = true
	return "ok"


## Põe um graveto comum de `peso` direto na boca (sem a troca de câmera).
static func _dar_graveto(jogo: Node, peso: float) -> String:
	var graveto := jogo.fase.adicionar_objeto(load("res://scenes/objetos/graveto_comum.tscn"),
		jogo.cachorro.global_position, 0.0) as Graveto
	graveto.peso = peso
	graveto.ja_pego = true
	jogo.cachorro.pegar_graveto(graveto)
	return "graveto peso %.1f" % peso


static func graveto_pesado(jogo: Node) -> String:
	return _dar_graveto(jogo, 2.0)


static func graveto_leve(jogo: Node) -> String:
	return _dar_graveto(jogo, 1.0)


static func tirar_graveto(jogo: Node) -> String:
	var graveto: Graveto = jogo.cachorro.graveto
	jogo.cachorro.largar_graveto()
	graveto.queue_free()
	return "sem graveto"


static func antes_da_rampa(jogo: Node) -> String:
	jogo.cachorro.posicionar(Vector3(0.8, 0.05, -4.5), 0.0)
	return "ok"


static func antes_do_degrau(jogo: Node) -> String:
	jogo.cachorro.posicionar(Vector3(1.2, 0.05, -1.5), 0.0)
	return "ok"


## Issue #28 — giro com o graveto encostado. Uma cerca viva (mato) na fileira z = -6, de x = 9 a
## 16, e outra na fileira z = -4 de x = 13 a 16: em x 13..16 fica um corredor de uma célula.
static func preparar_giro(jogo: Node) -> String:
	var terreno: GridMap = jogo.fase.terreno
	for x in range(9, 17):
		terreno.set_cell_item(Vector3i(x, 0, -6), Tiles.MATO)
	for x in range(13, 17):
		terreno.set_cell_item(Vector3i(x, 0, -4), Tiles.MATO)
	return "ok"


## Encostado na cerca ao norte, olhando para oeste, com o graveto atravessado: o giro mais curto
## para o leste (pelo norte) bate na cerca.
static func encostado_na_cerca(jogo: Node) -> String:
	jogo.cachorro.posicionar(Vector3(10.5, 0.05, -4.45), PI - 0.01)
	return _dar_graveto(jogo, 1.0)


## No corredor, olhando para oeste, com o graveto ao comprido: não dá para girar para nenhum lado.
static func no_corredor(jogo: Node) -> String:
	jogo.cachorro.posicionar(Vector3(14.5, 0.05, -4.5), PI)
	var texto := _dar_graveto(jogo, 1.0)
	return texto + (" ao comprido" if jogo.cachorro.virar_graveto() else " (não virou)")

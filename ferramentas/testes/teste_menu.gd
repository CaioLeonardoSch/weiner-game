extends RefCounted
## Ajudantes da rota ferramentas/testes/rotas/menu.txt (escolher região e raça no menu antes de
## jogar). "jogo" aqui é a cena atual: o menu ou o jogo.


static func _fases(jogo: Node) -> Node:
	return jogo.get_node(^"/root/Fases")


## Abre a tela da região Floresta (raça + fases).
static func abrir_floresta(jogo: Node) -> String:
	jogo.call(&"_tela_regiao", Regioes.por_id(&"floresta"))
	return "ok"


## Aperta o botão da raça (id) na tela aberta.
static func _apertar_raca(jogo: Node, id: String) -> String:
	var tela: Control = jogo.get(&"_tela")
	var botao := tela.find_child("Raca_" + id, true, false) as Button
	if botao == null:
		return "sem o botão da raça " + id
	botao.pressed.emit()
	return "escolheu " + id


static func escolher_pug(jogo: Node) -> String:
	return _apertar_raca(jogo, "pug")


static func escolher_salsicha(jogo: Node) -> String:
	return _apertar_raca(jogo, "salsicha")


## Aperta o primeiro botão cujo texto contém `texto`.
static func _apertar(jogo: Node, texto: String) -> String:
	var tela: Control = jogo.get(&"_tela")
	for botao in tela.find_children("*", "Button", true, false):
		if (botao as Button).text.contains(texto):
			(botao as Button).pressed.emit()
			return "apertou " + (botao as Button).text
	return "sem botão com " + texto


static func jogar_fase_01(jogo: Node) -> String:
	return _apertar(jogo, "Fase 01")


static func jogar(jogo: Node) -> String:
	return _apertar(jogo, "Jogar")


## Volta ao menu na tela "antes de jogar" da Fase 03 (como na pausa, "Trocar de raça").
static func antes_da_fase_03(jogo: Node) -> String:
	_fases(jogo).antes_de_jogar("res://scenes/fases/fase_03.tscn")
	return "ok"

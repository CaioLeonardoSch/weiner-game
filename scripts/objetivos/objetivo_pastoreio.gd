class_name ObjetivoPastoreio
extends Objetivo
## Levar todas as ovelhas para dentro de um cercado. Dentro dele a ovelha se acalma e não sai.

var ovelhas: Array[ObjetoFase] = []


func faltando(fase: Fase) -> PackedStringArray:
	var lista: PackedStringArray = []
	_falta(fase, InicioCachorro, "o Início do cachorro", lista)
	_falta(fase, Ovelha, "uma Ovelha", lista)
	_falta(fase, Cercado, "um Cercado", lista)
	return lista


func preparar(novo_jogo: Node) -> void:
	super(novo_jogo)
	ovelhas = jogo.fase.todos(Ovelha)
	_atualizar_contador()


func processar(_delta: float) -> void:
	if jogo.concluida:
		return
	var mudou := false
	for objeto in ovelhas:
		var ovelha := objeto as Ovelha
		if ovelha.guardada:
			continue
		for cercado in jogo.fase.todos(Cercado):
			if (cercado as Cercado).contem(ovelha.global_position):
				ovelha.guardada = true
				mudou = true
				break
	if not mudou:
		return
	_atualizar_contador()
	var guardadas := _guardadas()
	if guardadas == ovelhas.size():
		jogo.concluir()
	else:
		jogo.mostrar_aviso("Béé! %d de %d no cercado" % [guardadas, ovelhas.size()])


func _guardadas() -> int:
	return ovelhas.filter(func(o: ObjetoFase) -> bool: return (o as Ovelha).guardada).size()


func _atualizar_contador() -> void:
	jogo.contador.text = "Ovelhas no cercado: %d / %d" % [_guardadas(), ovelhas.size()]
	jogo.contador.show()

class_name ObjetivoPastoreio
extends Objetivo
## Levar todas as ovelhas para um abrigo: um Cercado ou um Celeiro (vale qualquer um, e pode
## haver vários). Dentro dele a ovelha se acalma e não sai.

var ovelhas: Array[ObjetoFase] = []
var abrigos: Array[ObjetoFase] = []
## "no cercado", "no celeiro" ou "guardadas" (quando há dos dois).
var _onde := "no cercado"


func faltando(fase: Fase) -> PackedStringArray:
	var lista: PackedStringArray = []
	_falta(fase, InicioCachorro, "o Início do cachorro", lista)
	_falta(fase, Ovelha, "uma Ovelha", lista)
	if fase.primeiro(Cercado) == null and fase.primeiro(Celeiro) == null:
		lista.append("um Cercado ou um Celeiro")
	return lista


func preparar(novo_jogo: Node) -> void:
	super(novo_jogo)
	ovelhas = jogo.fase.todos(Ovelha)
	abrigos = jogo.fase.todos(Cercado) + jogo.fase.todos(Celeiro)
	var tem_cercado := jogo.fase.primeiro(Cercado) != null
	var tem_celeiro := jogo.fase.primeiro(Celeiro) != null
	_onde = "guardadas" if tem_cercado and tem_celeiro else ("no celeiro" if tem_celeiro else "no cercado")
	_atualizar_contador()


func processar(_delta: float) -> void:
	if jogo.concluida:
		return
	var mudou := false
	for objeto in ovelhas:
		var ovelha := objeto as Ovelha
		if ovelha.guardada:
			continue
		for abrigo in abrigos:
			if abrigo.visible and abrigo.contem(ovelha.global_position):
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
		jogo.mostrar_aviso("Béé! %d de %d %s" % [guardadas, ovelhas.size(), _onde])


func _guardadas() -> int:
	return ovelhas.filter(func(o: ObjetoFase) -> bool: return (o as Ovelha).guardada).size()


func _atualizar_contador() -> void:
	jogo.contador.text = "Ovelhas %s: %d / %d" % [_onde, _guardadas(), ovelhas.size()]
	jogo.contador.show()

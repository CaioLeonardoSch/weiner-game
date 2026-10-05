class_name ObjetivoDia
extends Objetivo
## Um dia do parque (ver docs/DESIGN.md, "O Parque"): achar o graveto lendário e voltar com ele.
## O dono não está na fase: ao pegar o lendário o cachorro abana o rabo e ouve o dono assobiar;
## no caminho de volta, entrar no Corte da volta com o lendário na boca termina a fase (um fade
## corta o resto do caminho e o jogo volta ao parque, na chegada ao dono).
## Sem textos de objetivo na tela.

## Segundos do rabo abanando de alegria ao pegar o lendário, e até o assobio do dono.
const ALEGRIA := 2.0
const ATRASO_ASSOBIO := 1.2

var cortes: Array[CorteDaVolta] = []
var _assobiou := false


func faltando(fase: Fase) -> PackedStringArray:
	var lista: PackedStringArray = []
	_falta(fase, InicioCachorro, "o Início do cachorro", lista)
	_falta(fase, CorteDaVolta, "o Corte da volta", lista)
	if ObjetivoGraveto._lendarios(fase).is_empty():
		lista.append("o Graveto lendário")
	return lista


func avisos(fase: Fase) -> PackedStringArray:
	var lista: PackedStringArray = []
	if not fase.todos(Dono).is_empty():
		lista.append("Num dia do parque o dono espera no parque: o Dono da fase não é usado.")
	return lista


func preparar(novo_jogo: Node) -> void:
	super(novo_jogo)
	jogo.contador.text = ""
	for objeto in jogo.fase.todos(CorteDaVolta):
		var corte := objeto as CorteDaVolta
		cortes.append(corte)
		corte.cachorro_entrou.connect(func(_cachorro: Dachshund) -> void: _conferir(true))


func ao_pegar_graveto(pego: Graveto) -> void:
	if not pego.lendario:
		return
	jogo.cachorro.voxel.alegria = ALEGRIA
	if not _assobiou:
		_assobiou = true
		var tween: Tween = jogo.create_tween()
		tween.tween_interval(ATRASO_ASSOBIO)
		tween.tween_callback(Som.assobio.bind(jogo))
	# Pegou (de novo) já dentro do corte (o graveto vai para a boca no fim do quadro).
	_conferir.call_deferred(false)


## Com o lendário na boca, dentro de um corte (ou `entrou` agora num), termina.
func _conferir(entrou: bool) -> void:
	var cachorro: Dachshund = jogo.cachorro
	if jogo.concluida or not cachorro.tem_graveto or not cachorro.graveto.lendario:
		return
	if entrou or cortes.any(func(corte: CorteDaVolta) -> bool: return corte.contem(cachorro)):
		jogo.concluir()

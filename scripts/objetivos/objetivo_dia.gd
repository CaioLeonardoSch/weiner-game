class_name ObjetivoDia
extends Objetivo
## Um dia do parque (ver docs/DESIGN.md, "O Parque"): achar o graveto lendário e voltar com ele.
## O dono não está na fase: ao pegar o lendário o cachorro abana o rabo e ouve o dono assobiar;
## no caminho de volta, pular numa moita (MoitaPassagem) ou entrar num Corte da volta com o
## lendário na boca termina a fase (um fade corta o resto do caminho e o jogo volta ao parque,
## com o cachorro já chegando ao dono).
## O dia começa com o cachorro saindo da moita da chegada (MoitaPassagem com `chegada`), se houver.
## Sem textos na tela, nem o nome da fase.

## Segundos do rabo abanando de alegria ao pegar o lendário, e até o assobio do dono.
const ALEGRIA := 2.0
const ATRASO_ASSOBIO := 1.2
## Distância (m) da câmera mostrando a moita da chegada.
const DISTANCIA_CHEGADA := 5.0

var cortes: Array[CorteDaVolta] = []
var _assobiou := false


func faltando(fase: Fase) -> PackedStringArray:
	var lista: PackedStringArray = []
	_falta(fase, InicioCachorro, "o Início do cachorro", lista)
	if fase.todos(CorteDaVolta).is_empty() and fase.todos(MoitaPassagem).is_empty():
		lista.append("uma Moita ou o Corte da volta (por onde a volta termina)")
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
	for objeto in jogo.fase.todos(MoitaPassagem):
		(objeto as MoitaPassagem).cachorro_dentro.connect(func(_cachorro: Dachshund) -> void: _conferir(true))
	_chegar_pela_moita()


func titulo(_fase: Fase) -> String:
	return ""


## Começo do dia: a câmera mostra a moita da chegada, o cachorro sai dela e anda até o Início;
## aí a câmera vai para trás dele.
func _chegar_pela_moita() -> void:
	# "Testar daqui" (F2 no editor) começa onde o cursor estava, não na moita.
	var fases := jogo.get_node_or_null(^"/root/Fases")
	if fases and fases.testando and fases.inicio_do_teste != null:
		return
	for objeto in jogo.fase.todos(MoitaPassagem):
		var moita := objeto as MoitaPassagem
		if not moita.chegada:
			continue
		var camera: CameraController = jogo.camera_controller
		var cachorro: Dachshund = jogo.cachorro
		var destino := cachorro.global_position
		var adiante := destino - moita.global_position
		adiante.y = 0.0
		camera.focar(moita, 0.0, destino + adiante, DISTANCIA_CHEGADA)
		await moita.chegar(cachorro, destino)
		await camera.soltar_foco(1.0, rad_to_deg(cachorro.modelo.rotation.y) - 90.0)
		return


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

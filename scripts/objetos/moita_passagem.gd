@tool
class_name MoitaPassagem
extends Travessia
## Moita fechada numa abertura do mato (de -Z a +Z local). Andando não passa; na frente dela, F
## faz o cachorro pular para dentro (a moita sacode) e sair do outro lado.
## Com `chamar_atencao`, a moita se mexe sozinha de tempos em tempos até alguém atravessar —
## vista de longe, chama o cachorro para lá.
## Com `chegada`, é a moita por onde o cachorro chega à fase: ele começa dentro dela e sai para o
## lado do Início do cachorro (ver `chegar`); só se volta por ela com o graveto lendário na boca.
## Num dia do parque, entrar numa moita com o lendário na boca termina a fase (ObjetivoDia).

## O cachorro sumiu dentro da moita (atravessando).
signal cachorro_dentro(cachorro: Dachshund)

## Largura (m, em X) da moita: cubra a abertura no mato.
@export_range(1.0, 4.0, 0.5) var largura := 2.0:
	set(valor):
		largura = valor
		_montar()
## Mexe sozinha (de tempos em tempos) até o cachorro atravessar.
@export var chamar_atencao := false
## A moita da chegada: o cachorro começa a fase saindo dela.
@export var chegada := false

## Profundidade (m, em Z) e altura (m) da moita.
const FUNDO := 1.4
const ALTURA := 1.2
const VERDES := [Color("3f8f3a"), Color("367f34"), Color("4b9e42")]
## Intervalo (s) entre uma mexida e outra, chamando atenção.
const INTERVALO_MINIMO := 2.5
const INTERVALO_MAXIMO := 4.0
## Quanto (m) ele anda para longe da moita depois de sair.
const PASSOS_DEPOIS := 1.5

var _folhas: Node3D
var _mexida: Tween
var _proxima := 1.0
var _ja_atravessaram := false


func nome_no_editor() -> String:
	return "Moita (pular dentro)"


func propriedades_editaveis() -> Array[StringName]:
	return [&"largura", &"chamar_atencao", &"chegada"]


func caixa_editor() -> AABB:
	return AABB(Vector3(-largura * 0.5, 0, -FUNDO * 0.5), Vector3(largura, ALTURA, FUNDO))


func _ready() -> void:
	super()
	_montar()
	if not Engine.is_editor_hint():
		atravessou.connect(func(_cachorro: Dachshund) -> void: _ja_atravessaram = true)


func caminho_local() -> PackedVector3Array:
	var ponta := FUNDO * 0.5 + 0.6
	return PackedVector3Array([Vector3(0, 0, -ponta), Vector3(0, 0.25, 0), Vector3(0, 0, ponta)])


func acao_da_boca(cachorro: Dachshund) -> String:
	if chegada and not (cachorro.tem_graveto and cachorro.graveto and cachorro.graveto.lendario):
		return ""
	return super(cachorro)


## O começo da fase: o cachorro está dentro da moita, que sacode, e ele sai pulando para o lado de
## `destino` e anda até lá. Aguarde com `await`.
func chegar(cachorro: Dachshund, destino: Vector3) -> void:
	_ocupada = true
	var pontos := PackedVector3Array()
	for ponto in caminho_local():
		pontos.append(to_global(ponto))
	if pontos[0].distance_to(destino) < pontos[2].distance_to(destino):
		pontos.reverse()
	var yaw := Travessia.yaw_para(destino - pontos[1])
	await cachorro.atravessar(PackedVector3Array([pontos[1]]), 0.01, yaw)
	cachorro.hide()
	await get_tree().create_timer(0.5).timeout
	mexer(0.6)
	await get_tree().create_timer(0.5).timeout
	cachorro.show()
	await cachorro.saltar(pontos[2], 0.35, 0.35, yaw)
	await cachorro.atravessar(PackedVector3Array([destino]), pontos[2].distance_to(destino) / 2.5, yaw)
	cachorro.terminar_travessia()
	_ja_atravessaram = true
	_ocupada = false


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not chamar_atencao or _ja_atravessaram or _ocupada:
		return
	_proxima -= delta
	if _proxima <= 0.0:
		_proxima = randf_range(INTERVALO_MINIMO, INTERVALO_MAXIMO)
		mexer(0.6)


## A moita sacode por `duracao` segundos.
func mexer(duracao: float) -> void:
	if _folhas == null:
		return
	if _mexida:
		_mexida.kill()
	_mexida = create_tween()
	var vezes := maxi(int(duracao / 0.1), 2)
	for i in vezes:
		var lado := 1.0 if i % 2 == 0 else -1.0
		var forca := 1.0 - float(i) / vezes
		_mexida.tween_property(_folhas, "rotation", Vector3(0.0, 0.0, lado * 0.08 * forca), 0.05)
		_mexida.parallel().tween_property(_folhas, "scale", Vector3(1.0 + 0.04 * forca, 1.0 - 0.05 * forca, 1.0), 0.05)
		_mexida.tween_property(_folhas, "rotation", Vector3.ZERO, 0.05)
		_mexida.parallel().tween_property(_folhas, "scale", Vector3.ONE, 0.05)


func _montar() -> void:
	if not is_node_ready():
		return
	_limpar()
	# Bolas de folhas sobrepostas, cobrindo a largura (visual provisório).
	_folhas = Node3D.new()
	var bolas := maxi(roundi(largura / 0.6), 2)
	for i in bolas:
		for fileira in 2:
			var bola := MeshInstance3D.new()
			var esfera := SphereMesh.new()
			var raio := 0.5 + 0.08 * sin(i * 1.7 + fileira)
			esfera.radius = raio
			esfera.height = raio * 1.8
			esfera.radial_segments = 8
			esfera.rings = 4
			esfera.material = Travessia.material(VERDES[(i + fileira) % VERDES.size()])
			bola.mesh = esfera
			var x := -largura * 0.5 + 0.3 + (largura - 0.6) * float(i) / float(bolas - 1)
			bola.position = Vector3(x, 0.55 + 0.1 * fileira, (fileira - 0.5) * 0.5)
			_folhas.add_child(bola)
	add_child(_folhas)
	var caixa := Travessia.caixa_solida(self, Vector3(largura, ALTURA, FUNDO * 0.8), Vector3(0.0, ALTURA * 0.5, 0.0))
	# Também na camada do terreno: a câmera não fica do outro lado da moita, escondendo o cachorro.
	caixa.collision_layer |= 1


## Pula para dentro (some na moita, que sacode), sai pulando do outro lado e anda um pouco.
func _animar(cachorro: Dachshund, pontos: PackedVector3Array) -> void:
	var yaw := Travessia.yaw_para(pontos[2] - pontos[0])
	var ate_a_moita := cachorro.global_position.distance_to(pontos[0])
	await cachorro.atravessar(PackedVector3Array([pontos[0]]), maxf(ate_a_moita / 2.0, 0.15), yaw)
	await get_tree().create_timer(0.15).timeout
	await cachorro.saltar(pontos[1], 0.45, 0.35, yaw)
	cachorro.hide()
	mexer(0.7)
	cachorro_dentro.emit(cachorro)
	await get_tree().create_timer(0.7).timeout
	var jogo := get_tree().current_scene
	if jogo and jogo.get(&"concluida") == true:
		# Fim do dia: a tela escurece com ele ainda na moita.
		mexer(1.5)
		await get_tree().create_timer(3.0).timeout
	cachorro.show()
	await cachorro.saltar(pontos[2], 0.35, 0.35, yaw)
	# Uns passos para longe da moita: a câmera vem junto e não fica colada nas costas dele.
	var direcao := pontos[2] - pontos[0]
	direcao.y = 0.0
	var adiante := pontos[2] + direcao.normalized() * PASSOS_DEPOIS
	await cachorro.atravessar(PackedVector3Array([adiante]), PASSOS_DEPOIS / 2.5, yaw)

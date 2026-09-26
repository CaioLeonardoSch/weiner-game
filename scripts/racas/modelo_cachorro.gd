@tool
class_name ModeloCachorro
extends Node3D
## O cachorro em voxel, montado de uma `Raca` + `Pelagem` (ver `CachorroVoxel`), com animação
## por código: patas andando, rabo abanando, orelhas balançando.
## Quem usa só informa `velocidade` (m/s) e `no_chao` a cada quadro.

@export var raca: Raca:
	set(valor):
		raca = valor
		_montar()
@export var indice_pelagem := 0:
	set(valor):
		indice_pelagem = valor
		_montar()

## Velocidade horizontal atual (m/s) e se está no chão: comandam a animação.
var velocidade := 0.0
var no_chao := true
## Posição da boca (onde o graveto fica), no espaço deste nó.
var boca := Vector3(0.74, 0.42, 0.0)

static var _cache := {}
var _pivos := {}
var _passo := 0.0
var _tempo := 0.0
var _amplitude := 0.0


func _ready() -> void:
	if _pivos.is_empty():
		_montar()


func montar(nova_raca: Raca, indice: int) -> void:
	indice_pelagem = indice
	raca = nova_raca


func pelagem() -> Pelagem:
	return raca.pelagem(indice_pelagem) if raca else null


func _montar() -> void:
	for filho in get_children():
		remove_child(filho)
		filho.queue_free()
	_pivos.clear()
	if raca == null:
		return
	var dados := _dados(raca, raca.pelagem(indice_pelagem))
	var escala := Raca.VOXEL
	var centro := Vector3(0, 0, 0.5)
	for nome: StringName in dados.malhas:
		var pivo := Node3D.new()
		pivo.name = String(nome).capitalize().replace(" ", "")
		var ponto: Vector3 = dados.pivos[nome]
		pivo.position = (ponto - centro) * escala
		var instancia := MeshInstance3D.new()
		instancia.mesh = dados.malhas[nome]
		pivo.add_child(instancia)
		add_child(pivo)
		_pivos[nome] = pivo
	boca = (dados.boca - centro) * escala


## Malhas (em cache por raça e pelagem): cem salsichas iguais usam as mesmas malhas.
static func _dados(nova_raca: Raca, pelagem_escolhida: Pelagem) -> Dictionary:
	var chave := "%d/%d" % [nova_raca.get_instance_id(), pelagem_escolhida.get_instance_id()]
	if _cache.has(chave):
		return _cache[chave]
	var gerado := CachorroVoxel.gerar(nova_raca, pelagem_escolhida)
	var malhas := {}
	var pivos := {}
	for nome: StringName in gerado.partes:
		var parte: Dictionary = gerado.partes[nome]
		if parte.voxels.is_empty():
			continue
		malhas[nome] = Voxel.malha(parte.voxels, Raca.VOXEL, parte.pivo)
		pivos[nome] = parte.pivo
	var dados := {malhas = malhas, pivos = pivos, boca = gerado.boca}
	_cache[chave] = dados
	return dados


func _process(delta: float) -> void:
	if _pivos.is_empty():
		return
	_tempo += delta
	var alvo := clampf(velocidade / 2.5, 0.0, 1.0) if no_chao else 0.0
	_amplitude = lerpf(_amplitude, alvo, 1.0 - exp(-10.0 * delta))
	# Uma passada a cada ~0,45 m.
	_passo += delta * velocidade / 0.45 * TAU * 0.5 if no_chao else 0.0

	var balanco := sin(_passo) * 0.7 * _amplitude
	_girar_pata(&"pata_fe", balanco)
	_girar_pata(&"pata_td", balanco)
	_girar_pata(&"pata_fd", -balanco)
	_girar_pata(&"pata_te", -balanco)
	if not no_chao:
		# No ar: patas da frente esticadas para a frente, as de trás para trás.
		_girar_pata(&"pata_fe", 0.6)
		_girar_pata(&"pata_fd", 0.6)
		_girar_pata(&"pata_te", -0.6)
		_girar_pata(&"pata_td", -0.6)

	# Sobe e desce um pouquinho a cada passada.
	position.y = absf(sin(_passo)) * 0.015 * _amplitude
	if _pivos.has(&"rabo"):
		# Abana mais rápido parado (contente), mais devagar andando.
		var ritmo := lerpf(11.0, 6.0, _amplitude)
		(_pivos[&"rabo"] as Node3D).rotation.y = sin(_tempo * ritmo) * lerpf(0.55, 0.3, _amplitude)
	var orelha := sin(_passo * 2.0) * 0.18 * _amplitude + sin(_tempo * 1.7) * 0.03
	if _pivos.has(&"orelha_e"):
		(_pivos[&"orelha_e"] as Node3D).rotation.x = -orelha
	if _pivos.has(&"orelha_d"):
		(_pivos[&"orelha_d"] as Node3D).rotation.x = orelha


func _girar_pata(nome: StringName, angulo: float) -> void:
	if _pivos.has(nome):
		(_pivos[nome] as Node3D).rotation.z = angulo

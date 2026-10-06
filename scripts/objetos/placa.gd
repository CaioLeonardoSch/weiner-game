@tool
class_name Placa
extends ObjetoFase
## Placa de pressão (uma célula): aciona o canal (a cor da moldura) enquanto tiver algo em cima.
## Como no Minecraft, o material diz o quê:
## - **Madeira**: qualquer coisa — o cachorro, um graveto largado, uma ovelha, um passarinho, o
##   bloco, o tronco (tudo que tem `peso_na_placa()` acima de zero).
## - **Pedra**: só algo pesado — o bloco de pedra e o tronco (`pesado_para_placa()`).
## Não tem colisão: é rasa, o cachorro e os blocos passam por cima.

signal pisada_sem_peso

@export_enum("Amarelo", "Azul", "Vermelho", "Verde", "Roxo", "Laranja", "Ciano", "Rosa") var canal := 0:
	set(valor):
		canal = valor
		_montar()
const MADEIRA := 0
const PEDRA := 1
## Madeira: qualquer coisa aciona. Pedra: só o bloco de pedra e o tronco.
@export_enum("Madeira", "Pedra") var tipo := MADEIRA:
	set(valor):
		tipo = valor
		_montar()

const AFUNDAR := 0.04

var ativa := false
var _tampo: MeshInstance3D
var _fase: Fase
## O cachorro já pisou nesta placa de pedra sem nada pesado (para avisar uma vez por visita).
var _cachorro_em_cima := false


func nome_no_editor() -> String:
	return "Placa de pressão"


func categoria_no_editor() -> String:
	return "Mecanismos"


func propriedades_editaveis() -> Array[StringName]:
	return [&"canal", &"tipo"]


func papel_no_canal() -> String:
	return "aciona"


func caixa_editor() -> AABB:
	return AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1.0, 0.12, 1.0))


func _ready() -> void:
	_montar()
	if not Engine.is_editor_hint():
		_fase = fase_do_objeto()
		if _fase:
			_fase.definir_fonte(canal, self, false)


## Tem em cima algo que aciona esta placa? (Madeira: qualquer coisa; pedra: só o pesado.)
func acionada_por_algo() -> bool:
	if tipo == MADEIRA and _cachorro_sobre():
		return true
	for no in get_tree().get_nodes_in_group(&"pesos"):
		var objeto := no as ObjetoFase
		if objeto == null or not objeto.visible or not _algum_sobre(objeto.pontos_de_apoio()):
			continue
		var aciona := objeto.pesado_para_placa() if tipo == PEDRA else objeto.peso_na_placa() > 0.0
		if aciona:
			return true
	return false


func _cachorro_sobre() -> bool:
	for no in get_tree().get_nodes_in_group(&"cachorro"):
		if _sobre((no as Node3D).global_position):
			return true
	return false


func _algum_sobre(pontos: PackedVector3Array) -> bool:
	for ponto in pontos:
		if _sobre(ponto):
			return true
	return false


func _sobre(ponto: Vector3) -> bool:
	var local := to_local(ponto)
	return absf(local.x) < 0.5 and absf(local.z) < 0.5 and local.y > -0.4 and local.y < 0.9


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or _fase == null:
		return
	var agora := acionada_por_algo()
	if agora != ativa:
		_mudar(agora)
	# Placa de pedra: o cachorro sozinho não pesa o bastante — avisa uma vez por visita.
	var em_cima := tipo == PEDRA and _cachorro_sobre()
	if em_cima and not _cachorro_em_cima and not ativa:
		pisada_sem_peso.emit()
	_cachorro_em_cima = em_cima


func _mudar(agora: bool) -> void:
	ativa = agora
	if _fase:
		_fase.definir_fonte(canal, self, ativa)
	if _tampo:
		var tween := create_tween()
		tween.tween_property(_tampo, "position:y", -AFUNDAR if ativa else 0.0, 0.12)


## Moldura na cor do canal e o tampo (tábuas de madeira ou laje de pedra), que afunda quando a
## placa está acionada.
func _montar() -> void:
	if not is_node_ready():
		return
	for filho in get_children():
		remove_child(filho)
		filho.queue_free()
	var cor := Canais.cor(canal)
	var moldura := {}
	var tampo := {}
	for x in range(-8, 8):
		for z in range(-8, 8):
			var borda := x < -6 or x >= 6 or z < -6 or z >= 6
			if borda:
				moldura[Vector3i(x, 0, z)] = cor.darkened(0.15 if (x + z) % 3 == 0 else 0.0)
			elif tipo == PEDRA:
				tampo[Vector3i(x, 0, z)] = Color("8e9199").darkened(0.08 if (x * 7 + z * 3) % 5 == 0 else 0.0)
				var borda_laje := x == -6 or x == 5 or z == -6 or z == 5
				tampo[Vector3i(x, 1, z)] = Color("9ea1a8") if borda_laje else Color("b3b6bd").darkened(
					0.07 if (x * 3 + z * 5) % 7 == 0 else 0.0)
			else:
				# Tábuas no sentido X, com frestas escuras entre elas.
				var tabua := posmod(z + 6, 4)
				var madeira: Color = [Color("a8773f"), Color("9a6a35"), Color("b5834a")][posmod(z + 6, 12) / 4]
				tampo[Vector3i(x, 0, z)] = madeira.darkened(0.2)
				tampo[Vector3i(x, 1, z)] = madeira.darkened(0.35) if tabua == 3 else madeira
	var instancia := MeshInstance3D.new()
	instancia.name = "Moldura"
	instancia.mesh = Voxel.malha(moldura, 1.0 / 16.0)
	add_child(instancia)
	_tampo = MeshInstance3D.new()
	_tampo.name = "Tampo"
	_tampo.mesh = Voxel.malha(tampo, 1.0 / 16.0)
	add_child(_tampo)

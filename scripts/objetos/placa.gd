@tool
class_name Placa
extends ObjetoFase
## Placa de pressão (uma célula): aciona o canal (a cor da moldura) enquanto o peso em cima
## chega a `peso_minimo`. Pesos: o cachorro (peso da raça, mais o do graveto na boca), um
## graveto largado, o bloco de pedra, ovelhas, passarinhos — ver `peso_na_placa()` de cada um.
## Não tem colisão: é rasa, o cachorro e os blocos passam por cima.

@export_enum("Amarelo", "Azul", "Vermelho", "Verde", "Roxo", "Laranja", "Ciano", "Rosa") var canal := 0:
	set(valor):
		canal = valor
		_montar()
## Peso necessário (salsicha = 1; graveto grande = 2; bloco de pedra = 3). Aparece na placa
## como pontinhos (um por unidade de peso), para o jogador saber o que ela pede.
@export_range(0.3, 6.0, 0.1) var peso_minimo := 1.0:
	set(valor):
		peso_minimo = valor
		_montar()

const AFUNDAR := 0.04

var ativa := false
var _tampo: MeshInstance3D
var _fase: Fase


func nome_no_editor() -> String:
	return "Placa de pressão"


func categoria_no_editor() -> String:
	return "Mecanismos"


func propriedades_editaveis() -> Array[StringName]:
	return [&"canal", &"peso_minimo"]


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


func definir_ativo(ligado: bool) -> void:
	super(ligado)
	# Sumiu (placa "só isométrico" na volta, por exemplo): solta o canal.
	if not ligado and ativa:
		_mudar(false)


## Peso somado do que está sobre a célula da placa.
func peso_em_cima() -> float:
	var soma := 0.0
	for no in get_tree().get_nodes_in_group(&"cachorro"):
		var cachorro := no as Dachshund
		if cachorro and _sobre(cachorro.global_position):
			soma += cachorro.peso_total()
	for no in get_tree().get_nodes_in_group(&"pesos"):
		var objeto := no as ObjetoFase
		if objeto and objeto.visible and _sobre(objeto.global_position):
			soma += objeto.peso_na_placa()
	return soma


func _sobre(ponto: Vector3) -> bool:
	var local := to_local(ponto)
	return absf(local.x) < 0.5 and absf(local.z) < 0.5 and local.y > -0.4 and local.y < 0.9


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or _fase == null:
		return
	var agora := peso_em_cima() >= peso_minimo - 0.001
	if agora != ativa:
		_mudar(agora)


func _mudar(agora: bool) -> void:
	ativa = agora
	if _fase:
		_fase.definir_fonte(canal, self, ativa)
	if _tampo:
		var tween := create_tween()
		tween.tween_property(_tampo, "position:y", -AFUNDAR if ativa else 0.0, 0.12)


## Moldura na cor do canal e um tampo de pedra que afunda quando a placa está acionada.
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
			else:
				tampo[Vector3i(x, 0, z)] = Color("9ea1a8").darkened(0.08 if (x * 7 + z * 3) % 5 == 0 else 0.0)
				tampo[Vector3i(x, 1, z)] = Color("aeb1b8")
	# Pontinhos no tampo: quantas unidades de peso a placa pede.
	var pontos := clampi(roundi(peso_minimo), 1, 6)
	var inicio := -int(pontos * 3 / 2)
	for i in pontos:
		for dx in 2:
			for dz in 2:
				tampo[Vector3i(inicio + i * 3 + dx, 1, -1 + dz)] = Color("4a4d55")
	var instancia := MeshInstance3D.new()
	instancia.name = "Moldura"
	instancia.mesh = Voxel.malha(moldura, 1.0 / 16.0)
	add_child(instancia)
	_tampo = MeshInstance3D.new()
	_tampo.name = "Tampo"
	_tampo.mesh = Voxel.malha(tampo, 1.0 / 16.0)
	add_child(_tampo)

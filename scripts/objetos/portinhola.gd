@tool
class_name Portinhola
extends ObjetoFase
## Parede de tábuas com uma portinhola de cachorro no meio: o cachorro passa andando contra a
## portinhola (ou com o botão de ação) e ela balança. Todas as raças passam; quanto maior o
## cachorro, mais ele demora para se espremer. O graveto só passa ao comprido, e com
## `comprimento_maximo` (m, 0 = qualquer) os compridos demais ficam.
## Com `mao_unica`, só abre para trás: entra pela frente (+Z local, a seta) e sai atrás.
## Largura em células ao longo do X local (a portinhola fica no meio).

@export_range(1, 4) var largura := 1:
	set(valor):
		largura = valor
		_montar()
## Só abre num sentido: de quem vem pela frente (lado da seta).
@export var mao_unica := false:
	set(valor):
		mao_unica = valor
		_montar()
## Graveto mais comprido que isto (m) não passa; 0 = qualquer comprimento.
@export_range(0.0, 3.0, 0.05) var comprimento_maximo := 0.0

const ALTURA := 1.0
const ESPESSURA := 0.25
## Tempo para um cachorro do tamanho do salsicha passar (os maiores demoram mais).
const DURACAO_BASE := 0.5
const _MADEIRAS := [Color("9a7045"), Color("8b633c"), Color("a67a4c")]

var _aba: Node3D
var _ocupada := false


func nome_no_editor() -> String:
	return "Portinhola"


func categoria_no_editor() -> String:
	return "Mecanismos"


func propriedades_editaveis() -> Array[StringName]:
	return [&"largura", &"mao_unica", &"comprimento_maximo"]


func caixa_editor() -> AABB:
	return AABB(Vector3(-largura * 0.5, 0.0, -ESPESSURA * 0.5), Vector3(largura, ALTURA, ESPESSURA))


func _ready() -> void:
	_montar()
	if not Engine.is_editor_hint():
		add_to_group(&"com_acao")


## Lado do cachorro: +1 na frente (+Z local), -1 atrás, 0 se não está diante da portinhola.
func _lado(cachorro: Dachshund) -> int:
	var local := to_local(cachorro.global_position)
	if absf(local.x) > 0.3 or absf(local.y) > 0.6:
		return 0
	var lado := 1 if local.z > 0.0 else -1
	var alcance := ESPESSURA * 0.5 + cachorro.raca.raio_colisao + 0.3 if cachorro.raca else 0.8
	# Com o graveto ao comprido apontado para a portinhola, a ponta bate nas tábuas antes.
	alcance += cachorro.alcance_extra_do_graveto(-global_basis.z * lado)
	if absf(local.z) > alcance or absf(local.z) < 0.05:
		return 0
	return lado


func ponto_da_acao(cachorro: Dachshund) -> Vector3:
	var lado := _lado(cachorro)
	return global_transform * Vector3(0, 0, 0.4 * (lado if lado != 0 else 1))


func acao_da_boca(cachorro: Dachshund) -> String:
	if _ocupada or _lado(cachorro) == 0:
		return ""
	return "passar pela portinhola"


func executar_acao(cachorro: Dachshund) -> void:
	_tentar_passar(cachorro, _lado(cachorro))


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or _ocupada:
		return
	for no in get_tree().get_nodes_in_group(&"cachorro"):
		var cachorro := no as Dachshund
		if cachorro == null or cachorro.atravessando:
			continue
		var lado := _lado(cachorro)
		if lado == 0:
			continue
		# Andando contra a portinhola, para o outro lado.
		var para_la := -global_basis.z * lado
		para_la.y = 0.0
		if cachorro.direcao_desejada().dot(para_la.normalized()) > 0.7:
			_tentar_passar(cachorro, lado)


func _tentar_passar(cachorro: Dachshund, lado: int) -> void:
	var jogo := get_tree().current_scene
	if lado == 0 or _ocupada or cachorro.atravessando or (jogo and jogo.get(&"concluida") == true):
		return
	if mao_unica and lado < 0:
		return
	if not cachorro.graveto_passa(true, comprimento_maximo):
		return
	_passar(cachorro, lado)


## Quanto tempo o cachorro leva para passar: cresce com o tamanho (altura e largura) da raça.
static func duracao_para(raca: Raca) -> float:
	if raca == null:
		return DURACAO_BASE
	var porte := (raca.altura_colisao / 0.6) * (raca.raio_colisao / 0.28)
	return DURACAO_BASE * maxf(pow(porte, 1.3), 1.0)


func _passar(cachorro: Dachshund, lado: int) -> void:
	_ocupada = true
	var raio := cachorro.raca.raio_colisao if cachorro.raca else 0.28
	var chegada := global_transform * Vector3(0, 0, -lado * (ESPESSURA * 0.5 + raio + 0.08))
	chegada.y = cachorro.global_position.y
	var inicio := global_transform * Vector3(0, 0, to_local(cachorro.global_position).z)
	inicio.y = cachorro.global_position.y
	var sentido := chegada - inicio
	var duracao := duracao_para(cachorro.raca)
	# A aba se abre para o lado de lá e volta balançando depois.
	var tween := create_tween()
	tween.tween_property(_aba, "rotation:x", 1.25 * lado, 0.15)
	tween.tween_interval(maxf(duracao - 0.15, 0.0))
	tween.tween_property(_aba, "rotation:x", -0.45 * lado, 0.2)
	tween.tween_property(_aba, "rotation:x", 0.2 * lado, 0.18)
	tween.tween_property(_aba, "rotation:x", 0.0, 0.15)
	await cachorro.atravessar(PackedVector3Array([inicio, chegada]), duracao, atan2(-sentido.z, sentido.x))
	cachorro.terminar_travessia()
	await get_tree().create_timer(0.3).timeout
	_ocupada = false


## Parede de tábuas com a moldura escura da portinhola no meio e a aba (dobradiça em cima).
## Na mão única, uma seta clara na frente da aba mostra o sentido.
func _montar() -> void:
	if not is_node_ready():
		return
	for filho in get_children():
		remove_child(filho)
		filho.queue_free()
	var voxels := {}
	var meia := largura * 8
	var altura_vox := int(ALTURA * 16)
	var vao := Rect2i(-4, 0, 8, 9) # x, y, largura, altura do buraco (voxels)
	for x in range(-meia, meia):
		var poste := x < -meia + 1 or x >= meia - 1
		for y in altura_vox + (1 if poste else 0):
			for z in range(-2, 2):
				var no_vao := x >= vao.position.x and x < vao.end.x and y < vao.end.y
				if no_vao:
					continue
				var moldura := x >= vao.position.x - 1 and x < vao.end.x + 1 and y < vao.end.y + 1
				var madeira: Color = _MADEIRAS[posmod(x + meia, 12) / 4]
				if moldura:
					voxels[Vector3i(x, y, z)] = Color("4e3420")
				elif poste or y >= altura_vox - 1:
					voxels[Vector3i(x, y, z)] = madeira.darkened(0.3)
				else:
					voxels[Vector3i(x, y, z)] = madeira.darkened(0.2) if posmod(x + meia, 4) == 3 else madeira
	var modelo := MeshInstance3D.new()
	modelo.mesh = Voxel.malha(voxels, 1.0 / 16.0)
	add_child(modelo)

	var aba_voxels := {}
	for x in range(vao.position.x, vao.end.x):
		for y in range(-vao.size.y, 0):
			var borda := x == vao.position.x or x == vao.end.x - 1 or y == -vao.size.y
			aba_voxels[Vector3i(x, y, -1)] = Color("6b4a2c") if borda else Color("7d5836")
			aba_voxels[Vector3i(x, y, 0)] = Color("6b4a2c") if borda else Color("7d5836")
	if mao_unica:
		# Seta para baixo-dentro, desenhada na frente da aba.
		for p in [Vector2i(-1, -3), Vector2i(0, -3), Vector2i(-1, -4), Vector2i(0, -4), Vector2i(-1, -5),
				Vector2i(0, -5), Vector2i(-3, -5), Vector2i(2, -5), Vector2i(-2, -6), Vector2i(1, -6),
				Vector2i(-1, -7), Vector2i(0, -7), Vector2i(-2, -5), Vector2i(1, -5), Vector2i(-1, -6), Vector2i(0, -6)]:
			aba_voxels[Vector3i(p.x, p.y, 1)] = Color("f2e2b6")
	_aba = Node3D.new()
	_aba.name = "Aba"
	_aba.position.y = vao.size.y / 16.0
	var modelo_aba := MeshInstance3D.new()
	modelo_aba.mesh = Voxel.malha(aba_voxels, 1.0 / 16.0)
	_aba.add_child(modelo_aba)
	add_child(_aba)

	var corpo := StaticBody3D.new()
	corpo.collision_layer = 4
	corpo.collision_mask = 0
	var forma := BoxShape3D.new()
	forma.size = Vector3(largura, ALTURA, ESPESSURA)
	var colisao := CollisionShape3D.new()
	colisao.shape = forma
	colisao.position = Vector3(0, ALTURA * 0.5, 0)
	corpo.add_child(colisao)
	add_child(corpo)

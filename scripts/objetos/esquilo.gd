@tool
class_name Esquilo
extends ObjetoFase
## Esquilo e a toca dele (um toco oco). Junta gravetos: um graveto largado no chão até `raio`
## metros da toca, com o cachorro longe dele, o esquilo corre, pega e leva para a porta da toca —
## e ali fica de guarda (não deixa o cachorro pegar). Um latido assusta: se estava levando,
## larga o graveto onde estiver; em todo caso corre para dentro da toca e só sai de novo depois
## de alguns segundos. O graveto na boca do cachorro ele não toca.
## A porta da toca (onde ele guarda o que junta) fica no +X local: gire para mudar.

enum Estado { EM_CASA, INDO, LEVANDO, ESCONDIDO }

## Até onde (m, da toca) o esquilo vai buscar gravetos.
@export_range(1.0, 12.0, 0.5) var raio := 5.0
## Tempo (s) escondido na toca depois de um susto.
@export_range(1.0, 20.0, 0.5) var tempo_escondido := 6.0

const VELOCIDADE := 3.2
const VELOCIDADE_CARREGANDO := 2.4
## Perto assim do cachorro, o esquilo não chega.
const MEDO_DO_CACHORRO := 1.8
const DISTANCIA_GUARDA := 1.2

var estado := Estado.EM_CASA
## O graveto que ele está buscando ou levando.
var alvo: Graveto
var _bicho: Node3D
var _tempo := 0.0
var _procura := 0.0
var _escondido := 0.0


func nome_no_editor() -> String:
	return "Esquilo (e a toca)"


func categoria_no_editor() -> String:
	return "Bichos"


func propriedades_editaveis() -> Array[StringName]:
	return [&"raio", &"tempo_escondido"]


func caixa_editor() -> AABB:
	return AABB(Vector3(-0.35, 0, -0.35), Vector3(1.2, 0.6, 0.7))


func _ready() -> void:
	_montar()
	if not Engine.is_editor_hint():
		add_to_group(&"guardas")


## Porta da toca: onde o esquilo deixa o que junta.
func porta() -> Vector3:
	var frente := global_basis.x
	frente.y = 0.0
	return global_position + frente.normalized() * 0.6


## Está guardando `ponto` (em casa, perto da porta da toca)?
func guarda(ponto: Vector3) -> bool:
	return estado == Estado.EM_CASA and _plano(ponto - porta()).length() <= DISTANCIA_GUARDA


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _bicho == null:
		return
	_tempo += delta
	match estado:
		Estado.EM_CASA:
			_bicho.global_position = _bicho.global_position.move_toward(porta(), delta * VELOCIDADE)
			_procura -= delta
			if _procura <= 0.0:
				_procura = 0.4
				_procurar_graveto()
		Estado.INDO:
			if not _alvo_disponivel() or _perto_do_cachorro(alvo.global_position):
				_voltar()
			elif _andar_ate(alvo.global_position, VELOCIDADE, delta):
				estado = Estado.LEVANDO
				alvo.levar_por(self)
		Estado.LEVANDO:
			alvo.global_position = _bicho.global_position + Vector3.UP * 0.2
			if _andar_ate(porta(), VELOCIDADE_CARREGANDO, delta):
				_largar(porta())
				estado = Estado.EM_CASA
		Estado.ESCONDIDO:
			_escondido -= delta
			if _escondido <= 0.0:
				estado = Estado.EM_CASA
				_bicho.global_position = global_position
				_bicho.show()
	# Pulinhos correndo; parado, só o rabo mexe.
	var correndo := estado == Estado.INDO or estado == Estado.LEVANDO
	var modelo := _bicho.get_node(^"Modelo") as Node3D
	modelo.position.y = absf(sin(_tempo * 16.0)) * 0.06 if correndo else 0.0
	(_bicho.get_node(^"Modelo/Rabo") as Node3D).rotation.z = sin(_tempo * (9.0 if correndo else 2.5)) * 0.18


func ao_ouvir_latido(origem: Vector3) -> void:
	if estado == Estado.ESCONDIDO:
		return
	if estado == Estado.LEVANDO:
		_largar(_bicho.global_position)
	alvo = null
	_assustar(origem)


## Graveto no chão, dentro do raio, fora da toca, e o cachorro longe dele.
func _procurar_graveto() -> void:
	var fase := fase_do_objeto()
	if fase == null:
		return
	var melhor: Graveto = null
	var melhor_distancia := raio
	for objeto in fase.todos(Graveto):
		var graveto := objeto as Graveto
		if not _livre(graveto) or _plano(graveto.global_position - porta()).length() <= DISTANCIA_GUARDA:
			continue
		var distancia := _plano(graveto.global_position - global_position).length()
		if distancia <= melhor_distancia and not _perto_do_cachorro(graveto.global_position):
			melhor = graveto
			melhor_distancia = distancia
	if melhor:
		alvo = melhor
		estado = Estado.INDO


func _livre(graveto: Graveto) -> bool:
	return graveto.visible and not graveto.ja_pego and not graveto.em_ponte \
		and not graveto.enterrado and graveto.com_bicho == null


func _alvo_disponivel() -> bool:
	return alvo != null and is_instance_valid(alvo) and _livre(alvo)


func _perto_do_cachorro(ponto: Vector3) -> bool:
	for cachorro in get_tree().get_nodes_in_group(&"cachorro"):
		if _plano((cachorro as Node3D).global_position - ponto).length() < MEDO_DO_CACHORRO:
			return true
	return false


## Anda em linha reta (esquilo sobe e desce de tudo) e vira para onde vai. Verdadeiro ao chegar.
func _andar_ate(destino: Vector3, velocidade: float, delta: float) -> bool:
	var ate := _plano(destino - _bicho.global_position)
	if ate.length() < 0.08:
		return true
	_bicho.rotation.y = atan2(-ate.z, ate.x) - global_rotation.y
	var passo := ate.normalized() * minf(velocidade * delta, ate.length())
	_bicho.global_position += passo
	_bicho.global_position.y = global_position.y
	return false


func _largar(onde: Vector3) -> void:
	if alvo and is_instance_valid(alvo) and alvo.com_bicho == self:
		var chao := Vector3(onde.x, global_position.y, onde.z)
		# Não larga na água: leva até a porta.
		var fase := fase_do_objeto()
		if fase and Tiles.eh_agua(fase.tile_em(chao + Vector3.DOWN * 0.3)):
			chao = porta()
		alvo.largar_do_bicho(chao, _bicho.global_rotation.y)
	alvo = null


func _voltar() -> void:
	alvo = null
	estado = Estado.EM_CASA


## Susto: "!" e corre para dentro da toca; fica escondido um tempo.
func _assustar(_origem: Vector3) -> void:
	estado = Estado.ESCONDIDO
	_escondido = tempo_escondido
	var susto := Label3D.new()
	susto.text = "!"
	susto.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	susto.font_size = 56
	susto.outline_size = 14
	susto.pixel_size = 0.008
	susto.modulate = Color(1.0, 0.92, 0.5)
	susto.no_depth_test = true
	add_child(susto)
	susto.global_position = _bicho.global_position + Vector3.UP * 0.6
	var tween := create_tween()
	tween.tween_property(susto, "global_position:y", susto.global_position.y + 0.4, 0.2)
	tween.parallel().tween_property(_bicho, "global_position", global_position, 0.35)
	tween.tween_callback(_bicho.hide)
	tween.tween_property(susto, "modulate:a", 0.0, 0.3)
	tween.tween_callback(susto.queue_free)


static func _plano(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


# --- Visual ----------------------------------------------------------------------------------

## Toco oco (a toca, com a porta no +X) e o esquilo: corpo ruivo, barriga clara, rabo peludo
## enrolado para cima.
func _montar() -> void:
	for filho in get_children():
		remove_child(filho)
		filho.queue_free()
	var toco := {}
	for x in range(-5, 5):
		for z in range(-5, 5):
			var r := Vector2(x + 0.5, z + 0.5).length()
			if r > 5.0:
				continue
			for y in 9:
				var borda := r > 3.8
				var porta_da_toca := x >= 3 and absf(z + 0.5) < 2.0 and y >= 1 and y <= 5
				if porta_da_toca:
					continue
				if y == 8:
					toco[Vector3i(x, y, z)] = Color("b08a5a") if int(r) % 2 == 0 else Color("9a7449")
				elif borda:
					toco[Vector3i(x, y, z)] = Color("6e4a2a").darkened(0.12 if (x + y * 3 + z) % 4 == 0 else 0.0)
				elif y <= 1:
					toco[Vector3i(x, y, z)] = Color("2a1a10")
	var malha_toco := MeshInstance3D.new()
	malha_toco.name = "Toca"
	malha_toco.mesh = Voxel.malha(toco, 1.0 / 16.0)
	add_child(malha_toco)
	var corpo := StaticBody3D.new()
	corpo.name = "Corpo"
	corpo.collision_layer = 4
	corpo.collision_mask = 0
	var forma := CylinderShape3D.new()
	forma.radius = 0.3
	forma.height = 0.56
	var colisao := CollisionShape3D.new()
	colisao.shape = forma
	colisao.position.y = 0.28
	corpo.add_child(colisao)
	add_child(corpo)

	_bicho = Node3D.new()
	_bicho.name = "Bicho"
	add_child(_bicho)
	_bicho.position = Vector3(0.6, 0, 0)
	var modelo := Node3D.new()
	modelo.name = "Modelo"
	_bicho.add_child(modelo)
	var pelo := Color("b5652b")
	var barriga := Color("ecc99c")
	var corpo_vox := {}
	for x in range(-2, 3):
		for y in range(1, 5):
			for z in range(-1, 2):
				corpo_vox[Vector3i(x, y, z)] = barriga if y == 1 and absi(z) == 0 else pelo
	for x in range(2, 5):
		for y in range(3, 7):
			for z in range(-1, 2):
				corpo_vox[Vector3i(x, y, z)] = pelo
	corpo_vox[Vector3i(5, 4, 0)] = Color("1a1414")
	corpo_vox[Vector3i(4, 5, -1)] = Color("1a1414")
	corpo_vox[Vector3i(4, 5, 1)] = Color("1a1414")
	for z in [-1, 1]:
		corpo_vox[Vector3i(3, 7, z)] = pelo.darkened(0.2)
	for x in [-2, 1]:
		for z in [-1, 1]:
			corpo_vox[Vector3i(x, 0, z)] = pelo.darkened(0.25)
	var malha_corpo := MeshInstance3D.new()
	malha_corpo.mesh = Voxel.malha(corpo_vox, 1.0 / 16.0)
	modelo.add_child(malha_corpo)
	var rabo := Node3D.new()
	rabo.name = "Rabo"
	rabo.position = Vector3(-2.0, 2.0, 0.0) / 16.0
	modelo.add_child(rabo)
	var rabo_vox := {}
	for y in range(0, 9):
		var x := -1 - int(sin(y * 0.35) * 2.5)
		for dx in range(-1, 2):
			for z in range(-1, 2):
				rabo_vox[Vector3i(x + dx, y, z)] = Color("9c5024") if (dx + y) % 3 else Color("c07a3e")
	var malha_rabo := MeshInstance3D.new()
	malha_rabo.mesh = Voxel.malha(rabo_vox, 1.0 / 16.0)
	rabo.add_child(malha_rabo)

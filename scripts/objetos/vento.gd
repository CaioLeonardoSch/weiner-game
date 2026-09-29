@tool
class_name Vento
extends ObjetoFase
## Corredor de vento forte: uma biruta no poste e, à frente dela (+Z local, `largura` ×
## `comprimento` células), um vento que empurra o cachorro. Sopra fraco o tempo todo e, a cada
## `intervalo` segundos, vem uma rajada forte (a biruta levanta e os riscos de vento aparecem um
## pouco antes, para dar tempo de se abrigar).
##
## Atrás de qualquer coisa sólida (uma pedra, um bloco, um muro) o cachorro fica abrigado. O
## graveto na boca pega vento como uma vela: comprido e atravessado ao vento, empurra muito mais
## (ver Dachshund._efeito_do_vento). Parado no gelo liso, a rajada põe o cachorro para deslizar.
## Também apaga mais rápido o graveto aceso.

## Células de largura do corredor (ao longo do X local).
@export_range(1, 12) var largura := 3:
	set(valor):
		largura = valor
		_montar()
## Células de comprimento do corredor (para a frente, +Z local: o sentido do vento).
@export_range(1, 20) var comprimento := 6:
	set(valor):
		comprimento = valor
		_montar()
## Vento de sempre (m/s). O cachorro anda a 3,5.
@export_range(0.0, 4.0, 0.1) var forca := 0.8
## Rajada (m/s): acima de 3,5 o cachorro não consegue andar contra.
@export_range(0.0, 10.0, 0.25) var forca_rajada := 5.0
## Segundos entre o começo de uma rajada e o da próxima.
@export_range(1.0, 15.0, 0.5) var intervalo := 4.0
@export_range(0.3, 8.0, 0.1) var duracao_rajada := 1.6
## Atraso do ciclo (s): ventos vizinhos fora de compasso.
@export_range(0.0, 15.0, 0.25) var defasagem := 0.0

const ALTURA := 3.0
## Quanto antes da rajada a biruta avisa (s).
const AVISO := 0.8
const SUBIDA := 0.35
## Até onde, contra o vento, algo sólido abriga (m).
const ALCANCE_ABRIGO := 3.0

var _tempo := 0.0
var _biruta: Node3D
var _riscos: CPUParticles3D
var _riscos_rajada: CPUParticles3D
var _som: AudioStreamPlayer3D


func nome_no_editor() -> String:
	return "Vento forte"


func categoria_no_editor() -> String:
	return "Mecanismos"


func propriedades_editaveis() -> Array[StringName]:
	return [&"largura", &"comprimento", &"forca", &"forca_rajada", &"intervalo", &"duracao_rajada", &"defasagem"]


func caixa_editor() -> AABB:
	return AABB(Vector3(-0.3, 0.0, -0.3), Vector3(0.6, 1.4, 0.6))


func _ready() -> void:
	_montar()
	if Engine.is_editor_hint():
		return
	add_to_group(&"ventos")


## Soma do vento de todos os corredores num ponto (m/s, em XZ).
static func total_em(no: Node, ponto: Vector3) -> Vector3:
	var soma := Vector3.ZERO
	if not no.is_inside_tree():
		return soma
	for vento: Vento in no.get_tree().get_nodes_in_group(&"ventos"):
		soma += vento.forca_em(ponto)
	return soma


## Vento neste ponto: zero fora do corredor ou abrigado atrás de algo sólido.
func forca_em(ponto: Vector3) -> Vector3:
	if not visible or not is_inside_tree():
		return Vector3.ZERO
	var local := to_local(ponto)
	if absf(local.x) > largura * 0.5 or local.z < 0.5 or local.z > comprimento + 0.5 \
			or local.y < -0.5 or local.y > ALTURA:
		return Vector3.ZERO
	var sentido := _sentido()
	var alcance := minf(ALCANCE_ABRIGO, local.z - 0.5)
	if alcance > 0.05:
		var excluir: Array[RID] = []
		for cachorro in get_tree().get_nodes_in_group(&"cachorro"):
			if cachorro is CollisionObject3D:
				excluir.append((cachorro as CollisionObject3D).get_rid())
		var consulta := PhysicsRayQueryParameters3D.create(ponto, ponto - sentido * alcance, 1 | 4, excluir)
		if not get_world_3d().direct_space_state.intersect_ray(consulta).is_empty():
			return Vector3.ZERO
	return sentido * intensidade()


## Força do vento agora (m/s): a de sempre ou, na rajada, subindo até `forca_rajada`.
func intensidade() -> float:
	return lerpf(forca, forca_rajada, _rajada(_tempo))


## 0 fora da rajada, 1 no meio dela (sobe e desce em SUBIDA segundos).
func _rajada(t: float) -> float:
	var no_ciclo := fposmod(t + defasagem, intervalo)
	var subindo := clampf(no_ciclo / SUBIDA, 0.0, 1.0)
	var descendo := clampf((duracao_rajada - no_ciclo) / SUBIDA, 0.0, 1.0)
	return smoothstep(0.0, 1.0, minf(subindo, descendo))


func _sentido() -> Vector3:
	var z := global_basis.z
	z.y = 0.0
	return z.normalized()


func _process(delta: float) -> void:
	_tempo += delta
	if _biruta == null:
		return
	var agora := _rajada(_tempo)
	# A biruta sobe um pouco antes da rajada (o aviso) e cai de volta depois.
	var levantada := maxf(agora, _rajada(_tempo + AVISO) * 0.6)
	var fraco := clampf(forca / maxf(forca_rajada, 0.1), 0.0, 1.0)
	levantada = maxf(levantada, fraco)
	var tremido := sin(_tempo * (6.0 + levantada * 10.0)) * (0.05 + levantada * 0.08)
	_biruta.rotation = Vector3(deg_to_rad(lerpf(70.0, 4.0, levantada)) + tremido, tremido * 0.7, 0.0)
	if Engine.is_editor_hint():
		return
	_riscos_rajada.emitting = agora > 0.1 or _rajada(_tempo + AVISO) > 0.1
	if _som:
		_som.volume_db = linear_to_db(clampf(intensidade() / 5.0, 0.02, 1.0)) - 4.0
	# O cachorro dentro do corredor: o vento do clima (árvores, chuva, folhas) reforça junto.
	var jogo := get_tree().current_scene
	var clima: Variant = jogo.get(&"clima") if jogo else null
	if clima is Clima:
		var dentro := false
		for cachorro: Node3D in get_tree().get_nodes_in_group(&"cachorro"):
			var local := to_local(cachorro.global_position)
			dentro = dentro or (absf(local.x) <= largura * 0.5 + 1.0 and local.z > -1.0 and local.z < comprimento + 2.0)
		(clima as Clima).reforcar(self, _sentido() * intensidade() * 0.4 if dentro else Vector3.ZERO)


# --- Visual ---------------------------------------------------------------------------------

## Poste com a biruta listrada (vermelho e branco) e os riscos de vento no corredor.
func _montar() -> void:
	if not is_node_ready():
		return
	for filho in get_children():
		remove_child(filho)
		filho.queue_free()
	_som = null

	var poste := {}
	for y in 20:
		poste[Vector3i(0, y, 0)] = Color("8a8f98") if y % 6 else Color("6f747c")
	for x in range(-1, 2):
		for z in range(-1, 2):
			poste[Vector3i(x, 0, z)] = Color("6f747c")
	var malha_poste := MeshInstance3D.new()
	malha_poste.name = "Poste"
	malha_poste.mesh = Voxel.malha(poste, 1.0 / 16.0, Vector3(0.5, 0.0, 0.5))
	add_child(malha_poste)

	# Biruta: cone listrado ao longo de +Z, pendurado no alto do poste (o giro em X levanta).
	_biruta = Node3D.new()
	_biruta.name = "Biruta"
	_biruta.position = Vector3(0.0, 20.0 / 16.0, 0.0)
	add_child(_biruta)
	var biruta := {}
	for z in 10:
		var raio := lerpf(2.2, 1.0, z / 9.0)
		var cor := Color("e04b3a") if (z >> 1) % 2 == 0 else Color("f2eee6")
		var r := ceili(raio)
		for x in range(-r, r + 1):
			for y in range(-r, r + 1):
				var d := Vector2(x, y).length()
				if d <= raio and d > raio - 1.2:
					biruta[Vector3i(x, y, z + 1)] = cor
	var malha_biruta := MeshInstance3D.new()
	malha_biruta.mesh = Voxel.malha(biruta, 1.0 / 16.0, Vector3(0.5, 0.5, 0.0))
	_biruta.add_child(malha_biruta)
	_biruta.rotation.x = deg_to_rad(70.0)

	var corpo := StaticBody3D.new()
	corpo.name = "Corpo"
	corpo.collision_layer = 4
	corpo.collision_mask = 0
	var forma := BoxShape3D.new()
	forma.size = Vector3(0.12, 1.3, 0.12)
	var colisao := CollisionShape3D.new()
	colisao.shape = forma
	colisao.position.y = 0.65
	corpo.add_child(colisao)
	add_child(corpo)

	_riscos = _criar_riscos(maxi(largura * comprimento / 3, 3), 0.25)
	_riscos.name = "Riscos"
	_riscos_rajada = _criar_riscos(maxi(largura * comprimento, 8), 0.5)
	_riscos_rajada.name = "RiscosRajada"
	_riscos_rajada.emitting = false

	if not Engine.is_editor_hint():
		_som = AudioStreamPlayer3D.new()
		_som.name = "Som"
		_som.stream = Som.vento_laco()
		_som.bus = &"Efeitos"
		_som.autoplay = true
		_som.unit_size = 4.0
		_som.max_distance = 18.0
		_som.position = Vector3(0.0, 1.0, comprimento * 0.5)
		add_child(_som)

	mostrar_volume_no_editor(Vector3(largura, ALTURA, comprimento), Color(0.75, 0.9, 1.0, 0.1))
	var volume := get_node_or_null(^"VolumeEditor") as Node3D
	if volume:
		volume.position.z = comprimento * 0.5 + 0.5


## Riscos brancos voando pelo corredor, no sentido do vento.
func _criar_riscos(quantidade: int, alfa: float) -> CPUParticles3D:
	var riscos := CPUParticles3D.new()
	var malha := BoxMesh.new()
	malha.size = Vector3(0.03, 0.03, 0.55)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 1.0, 1.0, alfa)
	malha.material = material
	riscos.mesh = malha
	riscos.amount = quantidade
	riscos.lifetime = 0.9
	riscos.local_coords = true
	riscos.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	riscos.emission_box_extents = Vector3(largura * 0.5, 0.7, 0.3)
	riscos.position = Vector3(0.0, 0.9, 0.6)
	riscos.direction = Vector3(0.0, 0.0, 1.0)
	riscos.spread = 3.0
	riscos.gravity = Vector3.ZERO
	var velocidade := comprimento / riscos.lifetime
	riscos.initial_velocity_min = velocidade * 0.8
	riscos.initial_velocity_max = velocidade * 1.1
	riscos.particle_flag_align_y = false
	riscos.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	riscos.visible = not no_editor_de_fases()
	add_child(riscos)
	return riscos

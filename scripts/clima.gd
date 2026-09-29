class_name Clima
extends Node3D
## Clima da fase (`Fase.clima`): chuva caindo com respingos no chão, neve caindo, vento com
## rajadas (árvores e capim balançam, folhas voam) e tempestade com raios e trovões. Tudo
## visual e sonoro — não muda a física do cachorro (o vento que empurra é a área Vento forte).
##
## O jogo cria um Clima por fase e ele segue o `alvo` (o cachorro). A intensidade vai para os
## shaders pelos parâmetros globais `chuva` (0 a 1: poças com pingos, chão molhado, anéis na
## água) e `vento` (XZ = direção × força: balanço de árvores e capim) — ver project.godot.
##
## Para um clima novo: uma constante, o nome em NOMES (e em `Fase.clima`) e os dados em `dados()`.

const DO_BIOMA := 0
const TEMPO_BOM := 1
const CHUVA := 2
const NEVE := 3
const VENTANIA := 4
const TEMPESTADE := 5
const NOMES := ["Do bioma", "Tempo bom", "Chuva", "Neve", "Ventania", "Tempestade"]

## Metade do lado da caixa (m) onde cai a chuva e a neve, em volta do alvo.
const RAIO := 20.0
## Altura (acima do alvo) de onde a chuva e a neve caem.
const ALTURA := 14.0
## Respingos: grade de pontos (lado) medidos com raios de cima para baixo.
const GRADE_RESPINGOS := 20

var tipo := TEMPO_BOM
## Vento de agora (XZ = direção × força), com as rajadas e os reforços.
var vento := Vector3.ZERO
## Intensidade da chuva de agora (sobe devagar no começo).
var chuva := 0.0

var _dados := {}
var _alvo: Node3D
var _ruido := FastNoiseLite.new()
var _tempo := 0.0
var _angulo_base := 0.0
## Reforços de vento de outros nós (ex.: área de vento forte): fonte → vetor.
var _reforcos := {}
var _chuva: CPUParticles3D
var _respingos: CPUParticles3D
var _neve: CPUParticles3D
var _folhas: CPUParticles3D
var _som_chuva: AudioStreamPlayer
var _som_vento: AudioStreamPlayer
var _centro_respingos := Vector3.INF
var _sol: DirectionalLight3D
var _energia_sol := 1.0
var _proximo_raio := 0.0


## O clima de verdade de uma fase: "Do bioma" vira neve no bioma que neva e tempo bom nos outros.
static func efetivo(fase: Fase) -> int:
	if fase == null:
		return TEMPO_BOM
	if fase.clima != DO_BIOMA:
		return fase.clima
	return NEVE if Biomas.dados(fase.bioma).nevando else TEMPO_BOM


## vento: força média; rajada: quanto as rajadas somam; chuva: 0 a 1; escurecer: céu e sol
## mais cinzentos (0 a 1); neve, folhas, raios: o que aparece.
static func dados(qual: int) -> Dictionary:
	var d := {vento = 0.5, rajada = 0.4, chuva = 0.0, escurecer = 0.0, neve = false, folhas = false, raios = false}
	match qual:
		CHUVA:
			d.merge({vento = 1.0, rajada = 0.8, chuva = 0.8, escurecer = 0.35}, true)
		NEVE:
			d.merge({vento = 0.4, rajada = 0.3, escurecer = 0.1, neve = true}, true)
		VENTANIA:
			d.merge({vento = 2.2, rajada = 1.6, folhas = true}, true)
		TEMPESTADE:
			d.merge({vento = 2.8, rajada = 1.8, chuva = 1.0, escurecer = 0.55, folhas = true, raios = true}, true)
	return d


## Monta o clima `qual` no `bioma`, escurecendo o céu e a luz de `ambiente` (instância de
## scenes/ambiente.tscn, já com o bioma aplicado) e seguindo `alvo`.
func configurar(qual: int, bioma: int, ambiente: Node, alvo: Node3D) -> void:
	tipo = qual
	_dados = dados(qual)
	_alvo = alvo
	_ruido.seed = 17
	_ruido.frequency = 0.25
	_angulo_base = randf() * TAU
	_proximo_raio = randf_range(3.0, 6.0)
	_escurecer(ambiente, _dados.escurecer)
	if _dados.chuva > 0.0:
		_criar_chuva()
		_som_chuva = _laco(Som.chuva_laco())
	if _dados.neve:
		_neve = Biomas.criar_neve_caindo()
		add_child(_neve)
	if _dados.folhas:
		_criar_folhas(bioma)
	if _dados.vento >= 2.0:
		_som_vento = _laco(Som.vento_laco())
	_seguir()


## Soma `vetor` ao vento enquanto `fonte` quiser (ex.: o cachorro dentro de uma área de vento
## forte). Vetor zero tira o reforço.
func reforcar(fonte: Object, vetor: Vector3) -> void:
	if vetor == Vector3.ZERO:
		_reforcos.erase(fonte)
	else:
		_reforcos[fonte] = vetor


func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set(&"chuva", 0.0)
	RenderingServer.global_shader_parameter_set(&"vento", Vector3.ZERO)
	# Laço tocando ao fechar o jogo: o playback (e o som gerado) ficaria preso no AudioServer.
	for som in [_som_chuva, _som_vento]:
		if som:
			(som as AudioStreamPlayer).stop()


func _process(delta: float) -> void:
	_tempo += delta
	_seguir()
	# Rajadas: ruído devagar em cima da força média; a direção também passeia um pouco.
	var rajada := maxf(_ruido.get_noise_1d(_tempo), 0.0) * 2.0
	var forca: float = _dados.vento * (1.0 + _dados.rajada * rajada * 0.6)
	var angulo := _angulo_base + _ruido.get_noise_1d(_tempo * 0.1 + 100.0) * 0.8
	vento = Vector3(cos(angulo), 0.0, sin(angulo)) * forca
	for fonte: Object in _reforcos.keys():
		if is_instance_valid(fonte):
			vento += _reforcos[fonte]
		else:
			_reforcos.erase(fonte)
	chuva = move_toward(chuva, _dados.chuva, delta * 0.5)
	RenderingServer.global_shader_parameter_set(&"vento", vento)
	RenderingServer.global_shader_parameter_set(&"chuva", chuva)

	if _chuva:
		_chuva.direction = Vector3(vento.x * 0.12, -1.0, vento.z * 0.12)
	if _neve:
		_neve.direction = Vector3(vento.x * 0.5, -1.0, vento.z * 0.5)
	if _folhas:
		var fraco := vento.length() < 0.05
		_folhas.direction = Vector3(0.0, 0.2, 1.0) if fraco else Vector3(vento.x, 0.15 * vento.length(), vento.z).normalized()
		_folhas.initial_velocity_min = 1.5 + vento.length() * 1.2
		_folhas.initial_velocity_max = 2.5 + vento.length() * 2.0
	if _som_chuva:
		_som_chuva.volume_db = linear_to_db(maxf(chuva, 0.001)) - 8.0
	if _som_vento:
		_som_vento.volume_db = linear_to_db(clampf(vento.length() / 3.5, 0.001, 1.0)) - 6.0
	if _dados.raios:
		_proximo_raio -= delta
		if _proximo_raio <= 0.0:
			_proximo_raio = randf_range(5.0, 12.0)
			_raio()


func _physics_process(_delta: float) -> void:
	if _respingos and _alvo and _alvo.global_position.distance_to(_centro_respingos) > 3.0:
		_medir_respingos()


## A caixa da chuva e da neve anda junto com o alvo (as gotas e os flocos, não: ficam no mundo).
func _seguir() -> void:
	if _alvo and is_instance_valid(_alvo):
		global_position = _alvo.global_position


## Céu e horizonte puxados para o cinza e o sol mais fraco, conforme `quanto`.
func _escurecer(ambiente: Node, quanto: float) -> void:
	if ambiente == null:
		return
	_sol = ambiente.get_node_or_null(^"Sol") as DirectionalLight3D
	if _sol:
		_sol.light_energy *= 1.0 - quanto * 0.6
		_energia_sol = _sol.light_energy
	if quanto <= 0.0:
		return
	var mundo := ambiente.get_node_or_null(^"WorldEnvironment") as WorldEnvironment
	if mundo == null or mundo.environment == null or mundo.environment.sky == null:
		return
	var ceu := mundo.environment.sky.sky_material as ProceduralSkyMaterial
	if ceu:
		var cinza := Color(0.5, 0.53, 0.58)
		ceu.sky_top_color = ceu.sky_top_color.lerp(cinza.darkened(0.2), quanto)
		ceu.sky_horizon_color = ceu.sky_horizon_color.lerp(cinza.lightened(0.15), quanto)
		ceu.ground_horizon_color = ceu.sky_horizon_color


## Riscos finos e translúcidos (não ganham contorno), alinhados com a queda.
func _criar_chuva() -> void:
	_chuva = CPUParticles3D.new()
	_chuva.name = "Chuva"
	var risco := BoxMesh.new()
	risco.size = Vector3(0.04, 0.5, 0.04)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.75, 0.82, 0.92, 0.55)
	risco.material = material
	_chuva.mesh = risco
	_chuva.amount = int(1600 * _dados.chuva)
	_chuva.lifetime = 1.0
	_chuva.preprocess = 1.0
	_chuva.local_coords = false
	_chuva.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_chuva.emission_box_extents = Vector3(RAIO, 0.5, RAIO)
	_chuva.direction = Vector3.DOWN
	_chuva.spread = 2.0
	_chuva.gravity = Vector3(0.0, -6.0, 0.0)
	_chuva.initial_velocity_min = 15.0
	_chuva.initial_velocity_max = 17.0
	_chuva.particle_flag_align_y = true
	_chuva.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_chuva.position = Vector3.UP * ALTURA
	add_child(_chuva)

	# Respingos: pontinhos que pulam do chão em pontos medidos com raios (ver _medir_respingos).
	_respingos = CPUParticles3D.new()
	_respingos.name = "Respingos"
	_respingos.top_level = true
	var gota := BoxMesh.new()
	gota.size = Vector3.ONE * 0.05
	var material_gota := material.duplicate() as StandardMaterial3D
	material_gota.albedo_color = Color(0.85, 0.9, 0.97, 0.8)
	gota.material = material_gota
	_respingos.mesh = gota
	_respingos.amount = int(500 * _dados.chuva)
	_respingos.lifetime = 0.3
	_respingos.local_coords = false
	_respingos.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	_respingos.direction = Vector3.UP
	_respingos.spread = 40.0
	_respingos.gravity = Vector3(0.0, -12.0, 0.0)
	_respingos.initial_velocity_min = 1.2
	_respingos.initial_velocity_max = 2.0
	_respingos.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_respingos.emitting = false
	add_child(_respingos)


## Mede o chão (terreno e objetos) numa grade em volta do alvo, de cima para baixo: ali os
## respingos pulam (em cima do telhado, se houver um).
func _medir_respingos() -> void:
	var espaco := get_world_3d().direct_space_state
	var centro := _alvo.global_position
	_centro_respingos = centro
	var pontos := PackedVector3Array()
	var passo := RAIO * 2.0 / GRADE_RESPINGOS
	var consulta := PhysicsRayQueryParameters3D.new()
	consulta.collision_mask = 1 | 4
	for i in GRADE_RESPINGOS:
		for j in GRADE_RESPINGOS:
			var x := centro.x - RAIO + (i + randf()) * passo
			var z := centro.z - RAIO + (j + randf()) * passo
			consulta.from = Vector3(x, centro.y + ALTURA, z)
			consulta.to = Vector3(x, centro.y - ALTURA, z)
			var batida := espaco.intersect_ray(consulta)
			if not batida.is_empty():
				pontos.append((batida.position as Vector3) + Vector3.UP * 0.03)
	_respingos.emission_points = pontos
	_respingos.emitting = not pontos.is_empty()


## Folhas (ou pó de neve) levadas pelo vento, girando.
func _criar_folhas(bioma: int) -> void:
	_folhas = CPUParticles3D.new()
	_folhas.name = "Folhas"
	var folha := BoxMesh.new()
	folha.size = Vector3(0.09, 0.02, 0.07)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	folha.material = material
	_folhas.mesh = folha
	var cores := Gradient.new()
	if Biomas.dados(bioma).nevando:
		cores.colors = PackedColorArray([Color("f4f7fb"), Color("dde6f1")])
		cores.offsets = PackedFloat32Array([0.0, 1.0])
		_folhas.amount = 260
	else:
		cores.colors = PackedColorArray([Color("4f8a3a"), Color("7aa640"), Color("d9a93a"), Color("c8642e")])
		cores.offsets = PackedFloat32Array([0.0, 0.4, 0.7, 1.0])
		cores.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
		_folhas.amount = 90
	_folhas.color_initial_ramp = cores
	_folhas.lifetime = 5.0
	_folhas.preprocess = 5.0
	_folhas.local_coords = false
	_folhas.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_folhas.emission_box_extents = Vector3(RAIO, 3.0, RAIO)
	_folhas.spread = 25.0
	_folhas.gravity = Vector3(0.0, -0.6, 0.0)
	_folhas.particle_flag_rotate_y = true
	_folhas.angular_velocity_min = -360.0
	_folhas.angular_velocity_max = 360.0
	_folhas.angle_min = 0.0
	_folhas.angle_max = 360.0
	_folhas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_folhas.position = Vector3.UP * 3.5
	add_child(_folhas)


func _laco(stream: AudioStream) -> AudioStreamPlayer:
	var jogador := AudioStreamPlayer.new()
	jogador.stream = stream
	jogador.bus = &"Efeitos"
	jogador.volume_db = -80.0
	jogador.autoplay = true
	add_child(jogador)
	return jogador


## Relâmpago: o sol pisca duas vezes; o trovão chega depois (mais longe, mais tarde e baixo).
func _raio() -> void:
	if _sol == null:
		return
	var brilho := create_tween()
	brilho.tween_property(_sol, "light_energy", _energia_sol + 2.5, 0.04)
	brilho.tween_property(_sol, "light_energy", _energia_sol, 0.08)
	brilho.tween_interval(0.07)
	brilho.tween_property(_sol, "light_energy", _energia_sol + 1.6, 0.03)
	brilho.tween_property(_sol, "light_energy", _energia_sol, 0.2)
	var distancia := randf()
	brilho.tween_interval(0.3 + distancia * 2.0)
	brilho.tween_callback(func() -> void: Som.trovao(self, -2.0 - distancia * 8.0))

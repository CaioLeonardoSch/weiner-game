class_name Efeitos
## Efeitos visuais curtos, criados por código (sem assets): terra voando, latido.
## Cada efeito se remove sozinho quando termina.

static var _material_terra: StandardMaterial3D
static var _material_onda: StandardMaterial3D
static var _material_vapor: StandardMaterial3D


## Torrões de terra saltando de `posicao` (cavar).
static func terra(pai: Node, posicao: Vector3) -> void:
	if _material_terra == null:
		_material_terra = StandardMaterial3D.new()
		_material_terra.albedo_color = Color("7a5230")
		_material_terra.roughness = 1.0
	var particulas := CPUParticles3D.new()
	var malha := BoxMesh.new()
	malha.size = Vector3.ONE * 0.09
	malha.material = _material_terra
	particulas.mesh = malha
	particulas.one_shot = true
	particulas.amount = 18
	particulas.lifetime = 0.6
	particulas.explosiveness = 0.95
	particulas.direction = Vector3.UP
	particulas.spread = 55.0
	particulas.initial_velocity_min = 1.5
	particulas.initial_velocity_max = 3.2
	particulas.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particulas.emission_sphere_radius = 0.3
	pai.add_child(particulas)
	particulas.global_position = posicao
	particulas.emitting = true
	particulas.finished.connect(particulas.queue_free)


## "Au!" subindo e uma onda se abrindo em volta de `posicao` (latir).
static func latido(pai: Node, posicao: Vector3) -> void:
	var texto := Label3D.new()
	texto.text = "Au!"
	texto.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	texto.font_size = 56
	texto.outline_size = 14
	texto.pixel_size = 0.008
	texto.modulate = Color(1.0, 0.95, 0.6)
	texto.no_depth_test = true
	pai.add_child(texto)
	texto.global_position = posicao + Vector3.UP * 0.4
	var tween := texto.create_tween().set_parallel()
	tween.tween_property(texto, "global_position", texto.global_position + Vector3.UP * 0.6, 0.7)
	tween.tween_property(texto, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tween.chain().tween_callback(texto.queue_free)

	if _material_onda == null:
		_material_onda = StandardMaterial3D.new()
		_material_onda.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material_onda.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material_onda.albedo_color = Color(1, 1, 1, 0.6)
	var onda := MeshInstance3D.new()
	var anel := TorusMesh.new()
	anel.inner_radius = 0.42
	anel.outer_radius = 0.5
	anel.rings = 24
	anel.ring_segments = 4
	onda.mesh = anel
	onda.material_override = _material_onda.duplicate()
	onda.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(onda)
	onda.global_position = Vector3(posicao.x, posicao.y - 0.2, posicao.z)
	var tween_onda := onda.create_tween().set_parallel()
	tween_onda.tween_property(onda, "scale", Vector3.ONE * 9.0, 0.45)
	tween_onda.tween_property(onda.material_override, "albedo_color:a", 0.0, 0.45)
	tween_onda.chain().tween_callback(onda.queue_free)


## Vapor branco subindo de `posicao` (a neve derretendo perto do fogo).
static func vapor(pai: Node, posicao: Vector3) -> void:
	if _material_vapor == null:
		_material_vapor = StandardMaterial3D.new()
		_material_vapor.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material_vapor.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material_vapor.albedo_color = Color(0.95, 0.97, 1.0, 0.7)
	var particulas := CPUParticles3D.new()
	var malha := BoxMesh.new()
	malha.size = Vector3.ONE * 0.12
	malha.material = _material_vapor
	particulas.mesh = malha
	particulas.one_shot = true
	particulas.amount = 8
	particulas.lifetime = 0.9
	particulas.explosiveness = 0.8
	particulas.direction = Vector3.UP
	particulas.spread = 25.0
	particulas.gravity = Vector3(0, 0.6, 0)
	particulas.initial_velocity_min = 0.4
	particulas.initial_velocity_max = 1.0
	particulas.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particulas.emission_box_extents = Vector3(0.4, 0.1, 0.4)
	particulas.scale_amount_min = 0.6
	particulas.scale_amount_max = 1.4
	particulas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(particulas)
	particulas.global_position = posicao
	particulas.emitting = true
	particulas.finished.connect(particulas.queue_free)

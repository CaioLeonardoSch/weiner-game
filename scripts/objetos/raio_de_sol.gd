@tool
class_name RaioDeSol
extends ObjetoFase
## Luz do sol entrando por uma abertura nas copas: um facho de luz quente que desce até o chão,
## num círculo de `raio` metros. Visual provisório (um cone translúcido e um holofote), até a
## arte.

@export_range(0.5, 4.0, 0.1) var raio := 1.3:
	set(valor):
		raio = valor
		_montar()
## Altura (m) de onde a luz desce.
@export_range(3.0, 15.0, 0.5) var altura := 8.0:
	set(valor):
		altura = valor
		_montar()

const COR := Color(1.0, 0.86, 0.55)


func nome_no_editor() -> String:
	return "Raio de sol"


func categoria_no_editor() -> String:
	return "Cenário"


func propriedades_editaveis() -> Array[StringName]:
	return [&"raio", &"altura"]


func caixa_editor() -> AABB:
	return AABB(Vector3(-raio, 0, -raio), Vector3(raio * 2.0, altura, raio * 2.0))


func _ready() -> void:
	_montar()


func _montar() -> void:
	if not is_node_ready():
		return
	for filho in get_children():
		if filho.owner == null:
			remove_child(filho)
			filho.queue_free()
	var luz := SpotLight3D.new()
	luz.light_color = COR
	luz.light_energy = 6.0
	luz.spot_range = altura + 1.0
	luz.spot_angle = rad_to_deg(atan(raio * 1.15 / altura))
	luz.spot_angle_attenuation = 0.4
	# Sem sombra: as copas em volta não apagam o facho.
	luz.shadow_enabled = false
	luz.position.y = altura
	luz.rotation.x = -PI * 0.5
	add_child(luz)
	# O facho: um cone aberto embaixo, translúcido e somando luz.
	var facho := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = raio * 0.55
	cone.bottom_radius = raio
	cone.height = altura
	cone.radial_segments = 16
	cone.cap_top = false
	cone.cap_bottom = false
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(COR, 0.08)
	cone.material = material
	facho.mesh = cone
	facho.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	facho.position.y = altura * 0.5
	add_child(facho)

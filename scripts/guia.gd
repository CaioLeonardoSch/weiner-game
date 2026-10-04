class_name Guia
extends MeshInstance3D
## A guia entre a mão de um dono e a coleira de um cachorro: uma linha que faz barriga. Quem usa
## diz as pontas (`de` e `ate`, Callables que devolvem pontos globais); a linha segue a cada quadro.
## Provisório até a arte.

var de: Callable
var ate: Callable

const SEGMENTOS := 10
## Quanto a guia desce no meio (m).
const BARRIGA := 0.18

var _malha := ImmediateMesh.new()


func _init() -> void:
	mesh = _malha
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("b8322a")
	material_override = material


func _process(_delta: float) -> void:
	_malha.clear_surfaces()
	if not visible or not de.is_valid() or not ate.is_valid():
		return
	var a: Vector3 = de.call()
	var b: Vector3 = ate.call()
	_malha.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in SEGMENTOS + 1:
		var t := float(i) / SEGMENTOS
		_malha.surface_add_vertex(a.lerp(b, t) + Vector3.DOWN * sin(t * PI) * BARRIGA)
	_malha.surface_end()

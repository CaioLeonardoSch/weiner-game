class_name AreaSegura
extends Control
## Área centralizada onde fica a interface (HUD, menus, pausa). Ocupa a altura toda, mas no
## máximo 16:9 de largura: num monitor largo (21:9, 32:9) o 3D preenche a tela inteira e a
## interface fica no meio — sem esticar e sem bordas pretas.

const PROPORCAO_MAXIMA := 16.0 / 9.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if mouse_filter == Control.MOUSE_FILTER_STOP:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(_ajustar)
	var opcoes := get_node_or_null(^"/root/Opcoes")
	if opcoes:
		opcoes.mudou.connect(func(_s: String, _c: String) -> void: _ajustar.call_deferred())
	_ajustar()


func _ajustar() -> void:
	var tamanho := get_viewport_rect().size
	var largura := minf(tamanho.x, tamanho.y * PROPORCAO_MAXIMA)
	var margem := floorf((tamanho.x - largura) * 0.5)
	offset_left = margem
	offset_right = -margem
	offset_top = 0.0
	offset_bottom = 0.0

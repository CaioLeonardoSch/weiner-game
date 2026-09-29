class_name GeradorIcones
extends Node
## Gera os ícones da paleta do editor: cada item é renderizado uma única vez num
## SubViewport pequeno (com mundo próprio) e a textura dele vira o ícone.

const TAMANHO := 48


## Ícone de um nó 3D (tile ou objeto). O nó passa a pertencer ao gerador.
func icone(no: Node3D) -> Texture2D:
	var vista := SubViewport.new()
	vista.size = Vector2i(TAMANHO, TAMANHO)
	vista.own_world_3d = true
	vista.transparent_bg = true
	vista.render_target_update_mode = SubViewport.UPDATE_ONCE
	# Pixelado como o jogo.
	vista.scaling_3d_mode = Viewport.SCALING_3D_MODE_NEAREST
	vista.scaling_3d_scale = 0.5
	add_child(vista)

	var ambiente := WorldEnvironment.new()
	ambiente.environment = Environment.new()
	ambiente.environment.background_mode = Environment.BG_CLEAR_COLOR
	ambiente.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.environment.ambient_light_color = Color(0.75, 0.8, 0.9)
	ambiente.environment.ambient_light_energy = 0.6
	vista.add_child(ambiente)
	var sol := DirectionalLight3D.new()
	sol.rotation = Vector3(deg_to_rad(-50.0), deg_to_rad(30.0), 0.0)
	vista.add_child(sol)

	no.process_mode = Node.PROCESS_MODE_DISABLED
	vista.add_child(no)
	var caixa := _caixa(no)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(caixa.size.length() * 0.85, 0.3)
	var base := Basis.from_euler(Vector3(deg_to_rad(-30.0), deg_to_rad(35.0), 0.0))
	camera.transform = Transform3D(base, caixa.get_center() + base.z * 20.0)
	camera.far = 60.0
	vista.add_child(camera)
	return vista.get_texture()


## Ícone de um tile da biblioteca.
func icone_tile(biblioteca: MeshLibrary, id: int) -> Texture2D:
	var malha := MeshInstance3D.new()
	malha.mesh = biblioteca.get_item_mesh(id)
	return icone(malha)


static func _caixa(no: Node3D) -> AABB:
	var caixa := AABB()
	var primeira := true
	var visuais: Array[Node] = no.find_children("*", "VisualInstance3D", true, false)
	if no is VisualInstance3D:
		visuais.append(no)
	for filho in visuais:
		var visual := filho as VisualInstance3D
		var local := no.global_transform.affine_inverse() * visual.global_transform * visual.get_aabb()
		caixa = local if primeira else caixa.merge(local)
		primeira = false
	# Blocos de uma GridMap (a miniatura de um módulo): a GridMap não é um VisualInstance3D.
	for filho in no.find_children("*", "GridMap", true, false):
		var grade := filho as GridMap
		var para_o_no := no.global_transform.affine_inverse() * grade.global_transform
		for celula in grade.get_used_cells():
			var bloco := para_o_no * AABB(grade.map_to_local(celula) - grade.cell_size * 0.5, grade.cell_size)
			caixa = bloco if primeira else caixa.merge(bloco)
			primeira = false
	return caixa if not primeira else AABB(Vector3(-0.5, 0.0, -0.5), Vector3.ONE)

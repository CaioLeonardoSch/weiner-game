@tool
extends EditorScript
## Gera assets/tiles/tiles.tres pelo editor do Godot, já com os ícones da paleta do GridMap.
## Abra este arquivo no editor de script e use Arquivo → Executar (Ctrl+Shift+X).


func _run() -> void:
	var biblioteca := Tiles.construir_biblioteca()
	var ids := biblioteca.get_item_list()
	var malhas: Array[Mesh] = []
	for id in ids:
		malhas.append(biblioteca.get_item_mesh(id))
	var icones := EditorInterface.make_mesh_previews(malhas, 64)
	for i in ids.size():
		biblioteca.set_item_preview(ids[i], icones[i])
	var erro := ResourceSaver.save(biblioteca, Tiles.CAMINHO_BIBLIOTECA)
	print("Tiles gerados em %s (%s)" % [Tiles.CAMINHO_BIBLIOTECA, error_string(erro)])
	EditorInterface.get_resource_filesystem().scan()

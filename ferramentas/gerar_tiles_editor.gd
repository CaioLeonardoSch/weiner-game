@tool
extends EditorScript
## Gera as bibliotecas de tiles (uma por bioma) pelo editor do Godot, já com os ícones da paleta do GridMap.
## Abra este arquivo no editor de script e use Arquivo → Executar (Ctrl+Shift+X).


func _run() -> void:
	for bioma in Tiles.BIBLIOTECAS.size():
		var biblioteca := Tiles.construir_biblioteca(bioma)
		var ids := biblioteca.get_item_list()
		var malhas: Array[Mesh] = []
		for id in ids:
			malhas.append(biblioteca.get_item_mesh(id))
		var icones := EditorInterface.make_mesh_previews(malhas, 64)
		for i in ids.size():
			biblioteca.set_item_preview(ids[i], icones[i])
		var caminho: String = Tiles.BIBLIOTECAS[bioma]
		var erro := ResourceSaver.save(biblioteca, caminho)
		print("Tiles gerados em %s (%s)" % [caminho, error_string(erro)])
	EditorInterface.get_resource_filesystem().scan()

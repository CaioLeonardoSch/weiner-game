extends SceneTree
## Gera as MeshLibrary do terreno (uma por bioma: assets/tiles/tiles.tres, tiles_neve.tres...)
## a partir de scripts/assets/tiles.gd.
##
## Pela linha de comando, na pasta do projeto:
##     godot --headless --script res://ferramentas/gerar_tiles.gd
## Dentro do editor do Godot use ferramentas/gerar_tiles_editor.gd (gera também os ícones).


func _initialize() -> void:
	var falhas := 0
	for bioma in Tiles.BIBLIOTECAS.size():
		var caminho: String = Tiles.BIBLIOTECAS[bioma]
		var erro := ResourceSaver.save(Tiles.construir_biblioteca(bioma), caminho)
		print("Tiles gerados em %s (%s)" % [caminho, error_string(erro)])
		if erro != OK:
			falhas += 1
	quit(falhas)

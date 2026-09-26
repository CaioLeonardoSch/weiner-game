extends SceneTree
## Gera assets/tiles/tiles.tres (a MeshLibrary do terreno) a partir de scripts/assets/tiles.gd.
##
## Pela linha de comando, na pasta do projeto:
##     godot --headless --script res://ferramentas/gerar_tiles.gd
## Dentro do editor do Godot use ferramentas/gerar_tiles_editor.gd (gera também os ícones).


func _initialize() -> void:
	var biblioteca := Tiles.construir_biblioteca()
	var erro := ResourceSaver.save(biblioteca, Tiles.CAMINHO_BIBLIOTECA)
	print("Tiles gerados em %s (%s)" % [Tiles.CAMINHO_BIBLIOTECA, error_string(erro)])
	quit(0 if erro == OK else 1)

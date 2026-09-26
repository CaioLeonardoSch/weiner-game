@tool
class_name ModeloVoxel
extends MalhaGerada
## Mostra um modelo voxel escrito em texto (assets/voxel/*.txt).
## Editou o arquivo? Recarregue a cena (ou reabra o jogo) para ver a mudança.

@export_file("*.txt") var arquivo := "":
	set(valor):
		arquivo = valor
		_atualizar()


func _ready() -> void:
	_atualizar()


func _atualizar() -> void:
	mesh = Voxel.carregar(arquivo) if not arquivo.is_empty() else null

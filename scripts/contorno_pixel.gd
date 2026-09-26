extends MeshInstance3D
## Quad de tela cheia com o shader de contorno. Fica como filho da câmera.
## Liga/desliga junto com o visual pixelado (ver autoload Visual).


func _ready() -> void:
	Visual.mudou.connect(_atualizar)
	_atualizar()


func _atualizar() -> void:
	visible = Visual.contorno_ativo()

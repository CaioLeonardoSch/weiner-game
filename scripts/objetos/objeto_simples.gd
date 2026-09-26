@tool
class_name ObjetoSimples
extends ObjetoFase
## Objeto sem comportamento próprio (decoração, obstáculo fixo): nome e categoria no editor
## vêm das variáveis abaixo, definidas na cena do objeto.

@export var nome := "Objeto"
@export var categoria := "Cenário"


func nome_no_editor() -> String:
	return nome


func categoria_no_editor() -> String:
	return categoria

@tool
class_name InicioCachorro
extends ObjetoFase
## Onde o cachorro começa a fase, olhando para o +X local (a seta no editor).
## Invisível no jogo.


func nome_no_editor() -> String:
	return "Início do cachorro"


func categoria_no_editor() -> String:
	return "Regras"


func icone_desenhado() -> String:
	return "inicio"


func unico_na_fase() -> bool:
	return true


func caixa_editor() -> AABB:
	return AABB(Vector3(-0.45, 0.0, -0.18), Vector3(1.0, 0.55, 0.36))

@tool
class_name ZonaDica
extends ObjetoFase
## Região que mostra uma dica quando o cachorro entra nela. Só para fases de teste: as do jogo
## não explicam o que fazer (ver docs/DESIGN.md, "Textos e dicas").
## No texto, "{nome_da_ação}" vira a tecla atual dela (ex.: "{virar_graveto}" → "Q"), porque
## o jogador pode trocar as teclas nas Opções.

signal ativada(texto: String)

@export var texto := "Dica":
	set(valor):
		texto = valor
@export var tamanho := Vector3(2.0, 1.5, 2.0):
	set(valor):
		tamanho = valor
		_atualizar()
## Mostra só na primeira vez (senão, toda vez que o cachorro entrar).
@export var uma_vez := true

var _mostrada := false


func nome_no_editor() -> String:
	return "Zona de dica"


func categoria_no_editor() -> String:
	return "Regras"


func propriedades_editaveis() -> Array[StringName]:
	return [&"texto", &"tamanho", &"uma_vez"]


func icone_desenhado() -> String:
	return "dica"


func prioridade_no_editor() -> int:
	return 0


func caixa_editor() -> AABB:
	return AABB(Vector3(-tamanho.x * 0.5, 0.0, -tamanho.z * 0.5), tamanho)


func _ready() -> void:
	_atualizar()
	if not Engine.is_editor_hint():
		($Area as Area3D).body_entered.connect(_on_entrou)


func _on_entrou(corpo: Node3D) -> void:
	if not corpo is Dachshund or (uma_vez and _mostrada):
		return
	_mostrada = true
	ativada.emit(texto)


func _atualizar() -> void:
	if not is_node_ready():
		return
	var forma := BoxShape3D.new()
	forma.size = tamanho
	var colisao := $Area/Colisao as CollisionShape3D
	colisao.shape = forma
	colisao.position.y = tamanho.y * 0.5
	mostrar_volume_no_editor(tamanho, Color(1.0, 0.9, 0.4, 0.12))

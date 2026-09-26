@tool
class_name Graveto
extends ObjetoFase
## Graveto no chão. Quando o cachorro encosta, emite `pego`.
##
## `comprimento` e `peso` já existem para as fases poderem variar o graveto: hoje o
## comprimento muda o visual e o peso deixa o cachorro mais lento na volta.
## TODO: colisão própria do graveto (ver CONCEITO.md e ROADMAP.md) — túneis e passagens
## precisarão ser largos o bastante para ele; e, com o peso, equilíbrio em passagens estreitas.

signal pego(cachorro: Dachshund)
## O cachorro encostou, mas um passarinho está guardando o graveto (no máximo 1 vez a cada 2 s).
signal protegido

## Amplitude (m) e velocidade da flutuação enquanto está no chão, só para chamar atenção.
@export var amplitude_flutuacao := 0.05
@export var velocidade_flutuacao := 3.0
## Depois de largado, por quantos segundos o graveto ignora o cachorro
## (senão ele seria pego de novo na hora).
@export var tempo_para_repegar := 0.5
## Comprimento em metros (atravessado na boca do cachorro).
@export_range(0.4, 2.0, 0.05) var comprimento := 0.8:
	set(valor):
		comprimento = valor
		_atualizar_forma()
## 1 = normal. Mais pesado, mais devagar o cachorro anda carregando.
@export_range(0.5, 3.0, 0.1) var peso := 1.0

var ja_pego := false
var _tempo := 0.0
var _bloqueio := 0.0
var _espera_aviso := 0.0
## Um passarinho barrou o cachorro encostado: quando ele for embora, o graveto é pego sem o
## cachorro precisar sair e encostar de novo. Fora disso, só um encostar novo pega (senão o
## graveto recém-largado embaixo do focinho voltaria sozinho para a boca).
var _barrado_por_passaro := false

@onready var visual: Node3D = $Visual
@onready var area: Area3D = $AreaPegar


func nome_no_editor() -> String:
	return "Graveto"


func categoria_no_editor() -> String:
	return "Regras"


func propriedades_editaveis() -> Array[StringName]:
	return [&"comprimento", &"peso"]


func _ready() -> void:
	_atualizar_forma()
	if not Engine.is_editor_hint():
		area.body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if ja_pego or Engine.is_editor_hint():
		return
	_bloqueio = maxf(_bloqueio - delta, 0.0)
	_espera_aviso = maxf(_espera_aviso - delta, 0.0)
	# O cachorro pode já estar encostado quando o passarinho vai embora.
	if _barrado_por_passaro and _bloqueio <= 0.0 and area.monitoring:
		for corpo in area.get_overlapping_bodies():
			_on_body_entered(corpo)
	_tempo += delta
	visual.position.y = sin(_tempo * velocidade_flutuacao) * amplitude_flutuacao
	visual.rotation.y += delta


## Multiplicador da velocidade do cachorro enquanto carrega este graveto.
func fator_velocidade() -> float:
	return 1.0 / (1.0 + maxf(peso - 1.0, 0.0) * 0.3)


## Volta a ficar disponível no chão (quem posiciona é o jogo).
func soltar() -> void:
	ja_pego = false
	_barrado_por_passaro = false
	_bloqueio = tempo_para_repegar
	area.set_deferred("monitoring", true)


func _on_body_entered(body: Node3D) -> void:
	if ja_pego or _bloqueio > 0.0 or not body is Dachshund:
		return
	for passaro in get_tree().get_nodes_in_group(&"passaros"):
		if (passaro as Passaro).guarda(global_position):
			_barrado_por_passaro = true
			if _espera_aviso <= 0.0:
				_espera_aviso = 2.0
				protegido.emit()
			return
	ja_pego = true
	_barrado_por_passaro = false
	# Não dá para mudar o monitoring dentro do próprio callback de física.
	area.set_deferred("monitoring", false)
	visual.position = Vector3.ZERO
	visual.rotation = Vector3.ZERO
	pego.emit(body)


func _atualizar_forma() -> void:
	if not is_node_ready():
		return
	# Malha e forma são "local_to_scene" na cena: cada graveto tem as suas.
	(($Visual/Haste as MeshInstance3D).mesh as BoxMesh).size.z = comprimento
	($Visual/Galhinho as Node3D).position.z = comprimento * 0.22
	(($AreaPegar/Colisao as CollisionShape3D).shape as BoxShape3D).size.z = comprimento + 0.1

@tool
class_name Bolinha
extends ObjetoFase
## A bolinha do parque: o cachorro pega encostando (vai para a boca, como um brinquedo) e larga
## com a tecla de largar. Levada ao dono sentado no banco, ele joga longe (ver ObjetivoParque).

## Raio (m). A origem do nó é o ponto de baixo da bolinha (no chão).
const RAIO := 0.07
## Depois de largada, por quantos segundos ela ignora o cachorro.
const TEMPO_PARA_REPEGAR := 0.6

## Na boca do cachorro ou na mão do dono: não dá para pegar.
var presa := false
var _bloqueio := 0.0

@onready var area_pegar: Area3D = $AreaPegar


func nome_no_editor() -> String:
	return "Bolinha"


func categoria_no_editor() -> String:
	return "Parque"


func _ready() -> void:
	if not Engine.is_editor_hint():
		area_pegar.body_entered.connect(_on_corpo_entrou)


func _physics_process(delta: float) -> void:
	_bloqueio = maxf(_bloqueio - delta, 0.0)


func _on_corpo_entrou(corpo: Node3D) -> void:
	var cachorro := corpo as Dachshund
	if cachorro == null or presa or _bloqueio > 0.0 or cachorro.boca_ocupada() \
			or cachorro.entrada_bloqueada or not cachorro.pode_brincar:
		return
	presa = true
	area_pegar.set_deferred("monitoring", false)
	# Reparent fora do callback de física da Area3D.
	cachorro.pegar_brinquedo.call_deferred(self)


## Largada no chão em `ponto` (global). Só um encostar novo pega de novo (senão a bolinha
## largada embaixo do focinho voltaria sozinha para a boca).
func soltar(ponto: Vector3) -> void:
	global_position = ponto
	_bloqueio = TEMPO_PARA_REPEGAR
	_liberar()


## Na mão do dono (ou em outro lugar sem poder pegar), em `ponto` (global).
func segurar(ponto: Vector3) -> void:
	presa = true
	area_pegar.set_deferred("monitoring", false)
	global_position = ponto


## Jogada num arco até `alvo` (no chão, global), quicando um pouco no fim. Aguarde com `await`.
func jogar(alvo: Vector3) -> void:
	presa = true
	var de := global_position
	var ate := alvo
	var distancia := Vector2(ate.x - de.x, ate.z - de.z).length()
	var duracao := clampf(distancia / 9.0, 0.5, 1.2)
	var altura := 1.0 + distancia * 0.25
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		global_position = de.lerp(ate, t) + Vector3.UP * altura * 4.0 * t * (1.0 - t), 0.0, 1.0, duracao)
	# Dois quiques, cada vez mais baixos, rolando um pouco para a frente.
	var frente := Vector3(ate.x - de.x, 0.0, ate.z - de.z).normalized()
	var ponto := ate
	for quique: float in [0.35, 0.12]:
		var inicio := ponto
		var fim := ponto + frente * quique * 1.5
		tween.tween_method(func(t: float) -> void:
			global_position = inicio.lerp(fim, t) + Vector3.UP * quique * 4.0 * t * (1.0 - t),
			0.0, 1.0, 0.18 + quique * 0.5)
		ponto = fim
	await tween.finished
	_liberar()


## Pode ser pega de novo. Religar a área avisa de quem já está em cima (body_entered): logo
## depois de largada, o bloqueio ignora esse aviso.
func _liberar() -> void:
	presa = false
	area_pegar.set_deferred("monitoring", true)

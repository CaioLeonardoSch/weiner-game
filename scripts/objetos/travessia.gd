@tool
class_name Travessia
extends ObjetoFase
## Ação de contexto (ver docs/DESIGN.md, "Ações"): passar um obstáculo com uma animação. Perto
## de uma das pontas do caminho (`caminho_local`, do primeiro ao último ponto), olhando para o
## obstáculo, F faz o cachorro passar sozinho até a outra ponta. O aviso mostra só a tecla.
## As subclasses dizem o caminho e animam (`_animar`).

signal atravessou(cachorro: Dachshund)

## Até onde (m) da ponta do caminho o cachorro pode estar para a ação aparecer.
const ALCANCE := 0.9
## O ponto da ação fica a isso (m) da ponta, para o lado do obstáculo.
const DIANTE_DA_PONTA := 0.4

var _ocupada := false


func categoria_no_editor() -> String:
	return "Ações"


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group(&"com_acao")


## Pontos (locais) do caminho, de uma ponta à outra, no chão. O cachorro começa numa ponta e
## termina na outra.
func caminho_local() -> PackedVector3Array:
	return PackedVector3Array([Vector3(0, 0, -1), Vector3(0, 0, 1)])


## A ponta mais perto do cachorro, se ele estiver nela: 0 (a primeira), 1 (a última) ou -1.
func ponta_perto(cachorro: Dachshund) -> int:
	var caminho := caminho_local()
	var melhor := -1
	var melhor_distancia := ALCANCE
	for i in 2:
		var ponto := to_global(caminho[0] if i == 0 else caminho[caminho.size() - 1])
		var distancia := Vector2(ponto.x - cachorro.global_position.x, ponto.z - cachorro.global_position.z).length()
		if distancia < melhor_distancia:
			melhor = i
			melhor_distancia = distancia
	return melhor


func acao_da_boca(cachorro: Dachshund) -> String:
	if _ocupada or ponta_perto(cachorro) < 0:
		return ""
	return "atravessar"


## Um pouco depois da ponta do cachorro, na direção do obstáculo: ele precisa olhar para lá.
func ponto_da_acao(cachorro: Dachshund) -> Vector3:
	var caminho := caminho_local()
	var ponta := ponta_perto(cachorro)
	if ponta < 0 or caminho.size() < 2:
		return global_position
	var de := to_global(caminho[0] if ponta == 0 else caminho[caminho.size() - 1])
	var para := to_global(caminho[1] if ponta == 0 else caminho[caminho.size() - 2])
	para.y = de.y
	return de + (para - de).normalized() * DIANTE_DA_PONTA


func executar_acao(cachorro: Dachshund) -> void:
	var ponta := ponta_perto(cachorro)
	var jogo := get_tree().current_scene
	if ponta < 0 or _ocupada or cachorro.atravessando or (jogo and jogo.get(&"concluida") == true):
		return
	_ocupada = true
	var pontos := PackedVector3Array()
	for ponto in caminho_local():
		pontos.append(to_global(ponto))
	if ponta == 1:
		pontos.reverse()
	await _animar(cachorro, pontos)
	cachorro.terminar_travessia()
	_ocupada = false
	atravessou.emit(cachorro)


## Leva o cachorro pelos `pontos` (globais; o primeiro é a ponta de onde ele sai). Aguarde com
## `await`. Padrão: andando.
func _animar(cachorro: Dachshund, pontos: PackedVector3Array) -> void:
	var de := cachorro.global_position
	var distancia := 0.0
	for ponto in pontos:
		distancia += de.distance_to(ponto)
		de = ponto
	await cachorro.atravessar(pontos, distancia / 2.0, Travessia.yaw_para(pontos[pontos.size() - 1] - pontos[0]))


## Yaw (rad) do cachorro olhando na `direcao` (o modelo do cachorro olha para +X).
static func yaw_para(direcao: Vector3) -> float:
	return atan2(-direcao.z, direcao.x)


# --- Montagem (visual provisório, feito por código) ----------------------------------------

## Apaga o que `_montar` fez da última vez (os filhos feitos por código não têm dono e não são
## salvos na cena).
func _limpar() -> void:
	for filho in get_children():
		if filho.owner == null:
			remove_child(filho)
			filho.queue_free()


static func material(cor: Color) -> StandardMaterial3D:
	var novo := StandardMaterial3D.new()
	novo.albedo_color = cor
	return novo


## Caixa sólida (camada de objetos) com `tamanho` e centro em `centro` (local), filha de `pai`.
static func caixa_solida(pai: Node3D, tamanho: Vector3, centro: Vector3) -> StaticBody3D:
	var corpo := StaticBody3D.new()
	corpo.collision_layer = 4
	corpo.collision_mask = 0
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = tamanho
	forma.shape = caixa
	forma.position = centro
	corpo.add_child(forma)
	pai.add_child(corpo)
	return corpo

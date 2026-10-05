@tool
class_name EsquiloDoGalho
extends ObjetoFase
## Esquilo comendo uma noz perto de uma árvore. Quando o cachorro aparece perto, ele se assusta,
## corre e sobe na árvore; lá em cima quebra um galho, que cai no chão. O galho é o graveto mais
## perto do esquilo (até ALCANCE): ponha o graveto onde ele deve cair — no começo da fase ele vai
## para a árvore (com cara de galho comum) e só fica dourado ao cair, se for lendário.
## A árvore é a mais perto do esquilo (até ALCANCE).

## O cachorro a menos disso (m) assusta o esquilo.
@export_range(2.0, 12.0, 0.5) var distancia_susto := 5.0
## Altura (m) do galho que quebra.
@export_range(1.0, 4.0, 0.1) var altura_galho := 1.8

## Até onde (m) o esquilo procura a árvore e o galho.
const ALCANCE := 8.0
const VELOCIDADE := 4.0
const DURACAO_SUBIDA := 0.8
const DURACAO_QUEDA := 0.75

var _bicho: Node3D
var _noz: MeshInstance3D
var _arvore: Arvore
var galho: Graveto
var _chao_do_galho := Vector3.ZERO
var _yaw_do_galho := 0.0
var _assustado := false
var _tempo := 0.0


func nome_no_editor() -> String:
	return "Esquilo na árvore (derruba o galho)"


func categoria_no_editor() -> String:
	return "Bichos"


func propriedades_editaveis() -> Array[StringName]:
	return [&"distancia_susto", &"altura_galho"]


func caixa_editor() -> AABB:
	return AABB(Vector3(-0.3, 0, -0.2), Vector3(0.6, 0.5, 0.4))


func _ready() -> void:
	_montar()
	if not Engine.is_editor_hint():
		_preparar.call_deferred()


## Acha a árvore e o galho e põe o galho lá em cima.
func _preparar() -> void:
	var fase := fase_do_objeto()
	if fase == null:
		return
	_arvore = _mais_perto(fase.todos(Arvore)) as Arvore
	galho = _mais_perto(fase.todos(Graveto)) as Graveto
	if galho == null:
		return
	_chao_do_galho = galho.global_position
	# `largar_do_bicho` gira o graveto em yaw + 90°: assim ele cai do jeito que foi posto.
	_yaw_do_galho = galho.global_rotation.y - PI * 0.5
	galho.levar_por(self)
	galho.disfarcado = galho.lendario
	galho.global_transform = Transform3D(Basis(Vector3.UP, galho.global_rotation.y), _ponto_do_galho())


func _mais_perto(lista: Array) -> ObjetoFase:
	var melhor: ObjetoFase = null
	var melhor_distancia := ALCANCE
	for objeto: ObjetoFase in lista:
		var distancia := _plano(objeto.global_position - global_position).length()
		if distancia < melhor_distancia:
			melhor = objeto
			melhor_distancia = distancia
	return melhor


## Onde o galho fica na árvore: no tronco, para o lado onde ele vai cair.
func _ponto_do_galho() -> Vector3:
	var tronco := _tronco()
	var para_fora := _plano(_chao_do_galho - tronco)
	var lado := para_fora.normalized() * minf(para_fora.length(), 0.6) if para_fora.length() > 0.01 else Vector3.ZERO
	return tronco + lado + Vector3.UP * altura_galho


func _tronco() -> Vector3:
	return _arvore.global_position if _arvore else global_position


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _bicho == null or _assustado:
		return
	# Comendo: a cabeça sobe e desce, o rabo mexe devagar.
	_tempo += delta
	var modelo := _bicho.get_node(^"Modelo") as Node3D
	modelo.rotation.z = maxf(sin(_tempo * 7.0), 0.0) * 0.12
	(_bicho.get_node(^"Modelo/Rabo") as Node3D).rotation.z = sin(_tempo * 2.5) * 0.18
	for cachorro in get_tree().get_nodes_in_group(&"cachorro"):
		var dachshund := cachorro as Dachshund
		if dachshund.visible and _plano(dachshund.global_position - _bicho.global_position).length() < distancia_susto:
			_assustar(dachshund)
			return


## "!", corre até a árvore e sobe; lá em cima o galho quebra e cai. Some na copa.
func _assustar(cachorro: Dachshund) -> void:
	_assustado = true
	var modelo := _bicho.get_node(^"Modelo") as Node3D
	modelo.rotation.z = 0.0
	_olhar(cachorro.global_position)
	var susto := Esquilo.exclamacao(self, _bicho.global_position + Vector3.UP * 0.6)
	var tween := create_tween()
	tween.tween_property(susto, "global_position:y", susto.global_position.y + 0.4, 0.2)
	tween.tween_interval(0.3)
	tween.tween_callback(susto.queue_free)
	await tween.finished
	var tronco := _tronco()
	var base := tronco + _plano(_bicho.global_position - tronco).normalized() * 0.3
	base.y = global_position.y
	_olhar(base)
	tween = create_tween()
	tween.tween_property(_bicho, "global_position", base, _bicho.global_position.distance_to(base) / VELOCIDADE)
	await tween.finished
	# Subindo: o esquilo de pé no tronco, cabeça para cima.
	modelo.rotation.z = PI * 0.5
	tween = create_tween()
	tween.tween_property(_bicho, "global_position:y", tronco.y + altura_galho, DURACAO_SUBIDA)
	await tween.finished
	_quebrar_galho()
	tween = create_tween()
	tween.tween_property(_bicho, "global_position:y", tronco.y + altura_galho + 1.2, 0.5)
	tween.tween_callback(_bicho.hide)


func _quebrar_galho() -> void:
	if galho == null or not is_instance_valid(galho) or galho.com_bicho != self:
		return
	var de := galho.global_position
	# Cai acelerando, girando um pouco; no meio do caminho entra na luz e fica dourado.
	var cair := func(t: float) -> void:
		galho.global_position = de.lerp(_chao_do_galho + Vector3.UP * 0.08, t * t)
		galho.rotation.x = sin(t * PI) * 0.6
		if t > 0.5 and galho.disfarcado:
			galho.disfarcado = false
	var tween := create_tween()
	tween.tween_method(cair, 0.0, 1.0, DURACAO_QUEDA)
	await tween.finished
	galho.rotation.x = 0.0
	Efeitos.terra(get_parent(), _chao_do_galho + Vector3.UP * 0.1)
	galho.largar_do_bicho(_chao_do_galho, _yaw_do_galho)


func _olhar(ponto: Vector3) -> void:
	var ate := _plano(ponto - _bicho.global_position)
	if ate.length() > 0.01:
		_bicho.global_rotation.y = atan2(-ate.z, ate.x)


static func _plano(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _montar() -> void:
	for filho in get_children():
		if filho.owner == null:
			remove_child(filho)
			filho.queue_free()
	_bicho = Esquilo.montar_bicho()
	add_child(_bicho)
	# A noz na boca.
	_noz = MeshInstance3D.new()
	var bolinha := SphereMesh.new()
	bolinha.radius = 0.035
	bolinha.height = 0.07
	bolinha.radial_segments = 6
	bolinha.rings = 3
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("6b4423")
	bolinha.material = material
	_noz.mesh = bolinha
	_noz.position = Vector3(5.6, 3.6, 0.0) / 16.0
	_bicho.get_node(^"Modelo").add_child(_noz)

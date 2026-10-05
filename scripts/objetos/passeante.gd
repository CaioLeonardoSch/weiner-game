@tool
class_name Passeante
extends ObjetoFase
## Uma pessoa passeando com o cachorro dela pela guia, em volta da origem (um círculo de raio
## `raio`). Só enfeita o parque: não late nem reage.
## Visual provisório (o modelo do dono com outras cores), até a arte do parque.

## Raça (id de assets/racas/*.tres) e pelagem do cachorro da pessoa.
@export var raca := &"pug":
	set(valor):
		raca = valor
		_montar()
@export_range(0, 7) var indice_pelagem := 0:
	set(valor):
		indice_pelagem = valor
		_montar()
@export_range(2.0, 20.0, 0.5) var raio := 6.0:
	set(valor):
		raio = valor
		_posicionar()
## m/s.
@export_range(0.3, 2.0, 0.1) var velocidade := 0.9
@export var sentido_horario := false

## Distância (m) do cachorro atrás da pessoa, no círculo.
const ATRAS := 1.1
## O cachorro anda um pouco por fora do círculo da pessoa.
const POR_FORA := 0.5

var _angulo := 0.0
var _pessoa: AnimatableBody3D
var _cao: AnimatableBody3D
var _modelo_cao: ModeloCachorro
var _guia: Guia


func nome_no_editor() -> String:
	return "Passeante"


func categoria_no_editor() -> String:
	return "Parque"


func propriedades_editaveis() -> Array[StringName]:
	return [&"raca", &"indice_pelagem", &"raio", &"velocidade", &"sentido_horario"]


func _validate_property(propriedade: Dictionary) -> void:
	if propriedade.name == &"raca":
		propriedade.hint = PROPERTY_HINT_ENUM
		propriedade.hint_string = ",".join(Racas.ids())


func _ready() -> void:
	_montar()


func _montar() -> void:
	if not is_node_ready():
		return
	for filho in get_children():
		remove_child(filho)
		filho.queue_free()
	_pessoa = _corpo("Pessoa", 0.3, 1.75)
	var modelo := ModeloVoxel.new()
	modelo.arquivo = "res://assets/voxel/passeante.txt"
	_pessoa.add_child(modelo)
	var dados_raca := Racas.por_id(raca)
	_cao = _corpo("Cao", dados_raca.raio_colisao if dados_raca else 0.3,
		dados_raca.altura_colisao if dados_raca else 0.8)
	_modelo_cao = ModeloCachorro.new()
	_cao.add_child(_modelo_cao)
	_modelo_cao.montar(dados_raca, indice_pelagem)
	_guia = Guia.new()
	_guia.name = "Guia"
	_guia.de = func() -> Vector3: return _pessoa.to_global(Vector3(-0.44, 0.7, 0.08))
	_guia.ate = _modelo_cao.ponto_da_coleira
	add_child(_guia)
	_posicionar()


func _corpo(nome: String, raio_forma: float, altura: float) -> AnimatableBody3D:
	var corpo := AnimatableBody3D.new()
	corpo.name = nome
	corpo.collision_layer = 4
	corpo.collision_mask = 0
	var forma := CapsuleShape3D.new()
	forma.radius = raio_forma
	forma.height = maxf(altura, raio_forma * 2.0)
	var colisao := CollisionShape3D.new()
	colisao.shape = forma
	colisao.position.y = forma.height * 0.5
	corpo.add_child(colisao)
	add_child(corpo)
	return corpo


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _pessoa == null:
		return
	_angulo += _sentido() * velocidade / raio * delta
	_posicionar()


func _sentido() -> float:
	return -1.0 if sentido_horario else 1.0


func _posicionar() -> void:
	if _pessoa == null:
		return
	var angulo_cao := _angulo - _sentido() * ATRAS / raio
	_pessoa.position = Vector3(cos(_angulo), 0.0, sin(_angulo)) * raio
	_cao.position = Vector3(cos(angulo_cao), 0.0, sin(angulo_cao)) * (raio + POR_FORA)
	# Andando na tangente do círculo: a pessoa olha para +Z, o cachorro para +X.
	var tangente_pessoa := Vector3(-sin(_angulo), 0.0, cos(_angulo)) * _sentido()
	var tangente_cao := Vector3(-sin(angulo_cao), 0.0, cos(angulo_cao)) * _sentido()
	_pessoa.rotation.y = atan2(tangente_pessoa.x, tangente_pessoa.z)
	_cao.rotation.y = atan2(-tangente_cao.z, tangente_cao.x)
	_modelo_cao.velocidade = 0.0 if Engine.is_editor_hint() else velocidade * (raio + POR_FORA) / raio

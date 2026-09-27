@tool
class_name CaoVizinho
extends ObjetoFase
## Um cachorro da vizinhança (atrás de uma cerca, num quintal...). Não sai do lugar, mas
## responde a latidos: ouviu um, late de volta logo depois — e o latido dele alcança o que
## está perto DELE (pássaros, o dono dormindo, outro cão vizinho, que passa adiante).
## É o jeito de latir onde o cachorro não chega, ou com o graveto na boca.

## Raça (id de assets/racas/*.tres) e pelagem.
@export var raca := &"border_collie":
	set(valor):
		raca = valor
		_montar()
@export_range(0, 7) var indice_pelagem := 0:
	set(valor):
		indice_pelagem = valor
		_montar()

## Espera entre ouvir e responder (s), e o tempo até responder de novo.
const DEMORA := 0.5
const DESCANSO := 2.0

var _descanso := 0.0
var _modelo: ModeloCachorro


func nome_no_editor() -> String:
	return "Cão vizinho"


func categoria_no_editor() -> String:
	return "Bichos"


func propriedades_editaveis() -> Array[StringName]:
	return [&"raca", &"indice_pelagem"]


func _validate_property(propriedade: Dictionary) -> void:
	if propriedade.name == &"raca":
		propriedade.hint = PROPERTY_HINT_ENUM
		propriedade.hint_string = ",".join(Racas.ids())


func caixa_editor() -> AABB:
	return AABB(Vector3(-0.5, 0, -0.3), Vector3(1.0, 0.9, 0.6))


func _ready() -> void:
	_montar()


func _process(delta: float) -> void:
	_descanso = maxf(_descanso - delta, 0.0)


func ao_ouvir_latido(_origem: Vector3) -> void:
	if _descanso > 0.0 or Engine.is_editor_hint():
		return
	_descanso = DESCANSO + DEMORA
	# Tween do próprio nó: se a fase for reiniciada no meio, ele morre junto.
	var tween := create_tween()
	tween.tween_interval(DEMORA)
	tween.tween_callback(latir)


func latir() -> void:
	var cabeca := global_position + global_basis * (_modelo.boca if _modelo else Vector3(0.5, 0.5, 0))
	Efeitos.latido(get_parent(), cabeca)
	Som.latido(get_parent(), cabeca, Som.tom_da_raca(Racas.por_id(raca)))
	if _modelo:
		var tween := create_tween()
		tween.tween_property(_modelo, "rotation:z", 0.25, 0.08)
		tween.tween_property(_modelo, "rotation:z", 0.0, 0.15)
	var fase := fase_do_objeto()
	if fase:
		fase.espalhar_latido(global_position, self)


func _montar() -> void:
	if not is_node_ready():
		return
	for filho in get_children():
		remove_child(filho)
		filho.queue_free()
	var dados_raca := Racas.por_id(raca)
	_modelo = ModeloCachorro.new()
	_modelo.name = "Modelo"
	add_child(_modelo)
	_modelo.montar(dados_raca, indice_pelagem)
	var corpo := StaticBody3D.new()
	corpo.name = "Corpo"
	corpo.collision_layer = 4
	corpo.collision_mask = 0
	var forma := CapsuleShape3D.new()
	forma.radius = dados_raca.raio_colisao if dados_raca else 0.3
	forma.height = maxf(dados_raca.altura_colisao if dados_raca else 0.8, forma.radius * 2.0)
	var colisao := CollisionShape3D.new()
	colisao.shape = forma
	colisao.position.y = forma.height * 0.5
	corpo.add_child(colisao)
	add_child(corpo)

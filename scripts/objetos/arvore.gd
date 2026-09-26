@tool
class_name Arvore
extends ObjetoFase
## Árvore voxel gerada por código (ver Voxel.arvore). Cada `variante` é uma árvore
## diferente; o editor sorteia a variante, o giro e a escala ao colocar.

@export var tipo := Voxel.TipoArvore.PINHEIRO:
	set(valor):
		tipo = valor
		_atualizar()
@export_range(0, 7) var variante := 0:
	set(valor):
		variante = valor
		_atualizar()

## Uma forma de colisão por tipo, compartilhada entre as árvores.
static var _formas := {}


func nome_no_editor() -> String:
	return "Árvore"


func propriedades_editaveis() -> Array[StringName]:
	return [&"tipo", &"variante"]


func ao_colocar_no_editor(rng: RandomNumberGenerator) -> void:
	variante = rng.randi_range(0, 7)
	rotation.y = rng.randf_range(-PI, PI)
	scale = Vector3.ONE * rng.randf_range(0.85, 1.2)


func _ready() -> void:
	_atualizar()


func _atualizar() -> void:
	if not is_node_ready():
		return
	($Visual as MeshInstance3D).mesh = Voxel.arvore(tipo, variante)
	if not Engine.is_editor_hint():
		($Corpo/Colisao as CollisionShape3D).shape = _forma(tipo)
		# Arbusto: colisão da moita inteira; árvores: só o tronco.
		($Corpo/Colisao as CollisionShape3D).position.y = (_forma(tipo) as BoxShape3D).size.y * 0.5


static func _forma(tipo_arvore: int) -> Shape3D:
	if not _formas.has(tipo_arvore):
		var forma := BoxShape3D.new()
		forma.size = Vector3(1.0, 0.8, 1.0) if tipo_arvore == Voxel.TipoArvore.ARBUSTO else Vector3(0.5, 2.2, 0.5)
		_formas[tipo_arvore] = forma
	return _formas[tipo_arvore]

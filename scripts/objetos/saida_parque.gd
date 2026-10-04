@tool
class_name SaidaParque
extends ObjetoFase
## O portão por onde o dono e o cachorro chegam ao parque e vão embora (o lado de fora é o +Z).
## Durante o dia, uma parede invisível entre os postes não deixa o cachorro sair sozinho.
## Visual provisório (dois postes), até a arte do parque.

@export_range(1.0, 4.0, 0.5) var largura := 2.0:
	set(valor):
		largura = valor
		_montar()


func nome_no_editor() -> String:
	return "Saída do parque"


func categoria_no_editor() -> String:
	return "Parque"


func propriedades_editaveis() -> Array[StringName]:
	return [&"largura"]


func unico_na_fase() -> bool:
	return true


## Um ponto do lado de fora, na frente do portão (global): onde o dia começa e termina.
func ponto_de_fora() -> Vector3:
	return to_global(Vector3(0.0, 0.0, 1.5))


func _ready() -> void:
	_montar()


func _montar() -> void:
	if not is_node_ready():
		return
	for filho in get_children():
		remove_child(filho)
		filho.queue_free()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("5a3d24")
	for lado in [-1.0, 1.0]:
		var poste := MeshInstance3D.new()
		var caixa := BoxMesh.new()
		caixa.size = Vector3(0.25, 1.6, 0.25)
		caixa.material = material
		poste.mesh = caixa
		poste.position = Vector3(lado * (largura * 0.5 + 0.125), 0.8, 0.0)
		add_child(poste)
	var corpo := StaticBody3D.new()
	corpo.name = "Fechada"
	corpo.collision_layer = 2
	corpo.collision_mask = 0
	var colisao := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = Vector3(largura + 0.5, 2.0, 0.3)
	colisao.shape = forma
	colisao.position.y = 1.0
	corpo.add_child(colisao)
	add_child(corpo)

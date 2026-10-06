@tool
class_name Alavanca
extends ObjetoFase
## Alavanca de madeira presa num toco: o cachorro morde (botão de ação) e ela vira para o outro
## lado, ligando ou desligando o canal (a cor da manopla) — ao contrário da placa, fica como
## está depois que o cachorro sai. Com `ligada`, a fase começa com ela ligada.

@export_enum("Amarelo", "Azul", "Vermelho", "Verde", "Roxo", "Laranja", "Ciano", "Rosa") var canal := 0:
	set(valor):
		canal = valor
		_montar()
## Começa ligada.
@export var ligada := false:
	set(valor):
		ligada = valor
		_montar()

const INCLINACAO := 0.6

var _fase: Fase
var _haste: Node3D


func nome_no_editor() -> String:
	return "Alavanca"


func categoria_no_editor() -> String:
	return "Mecanismos"


func propriedades_editaveis() -> Array[StringName]:
	return [&"canal", &"ligada"]


func papel_no_canal() -> String:
	return "aciona"


func _ready() -> void:
	_montar()
	if not Engine.is_editor_hint():
		add_to_group(&"com_acao")
		_fase = fase_do_objeto()
		if _fase:
			_fase.definir_fonte(canal, self, ligada)


func acao_da_boca(cachorro: Dachshund) -> String:
	if cachorro.tem_graveto:
		return ""
	return "desligar a alavanca" if ligada else "ligar a alavanca"


func executar_acao(cachorro: Dachshund) -> void:
	if cachorro.tem_graveto:
		return
	ligada = not ligada
	if _fase:
		_fase.definir_fonte(canal, self, ligada)
	Som.estalo(get_parent(), global_position)


## Toco com a base na cor do canal e a haste que tomba para um lado (desligada) ou para o
## outro (ligada), com a manopla colorida na ponta.
func _montar() -> void:
	if not is_node_ready():
		return
	var giro_anterior := _haste.rotation.z if _haste and is_instance_valid(_haste) else INCLINACAO * (-1.0 if ligada else 1.0)
	for filho in get_children():
		remove_child(filho)
		filho.queue_free()
	var cor := Canais.cor(canal)
	var base := {}
	var casca := [Color("6b4428"), Color("5b3920"), Color("744b2c")]
	for x in range(-4, 4):
		for z in range(-3, 3):
			for y in 4:
				base[Vector3i(x, y, z)] = casca[posmod(x * 3 + z + y, casca.size())]
			base[Vector3i(x, 4, z)] = cor.darkened(0.15 if (x + z) % 2 == 0 else 0.0) \
				if absi(x * 2 + 1) >= 5 or absi(z * 2 + 1) >= 5 else Color("3b2718")
	var modelo := MeshInstance3D.new()
	modelo.mesh = Voxel.malha(base, 1.0 / 16.0)
	add_child(modelo)
	var haste := {}
	for y in range(0, 11):
		haste[Vector3i(-1, y, -1)] = Color("c89a5f") if y % 4 else Color("a87c48")
		haste[Vector3i(0, y, -1)] = Color("c89a5f") if y % 4 else Color("a87c48")
		haste[Vector3i(-1, y, 0)] = Color("b88b54")
		haste[Vector3i(0, y, 0)] = Color("b88b54")
	for x in range(-2, 2):
		for y in range(11, 14):
			for z in range(-2, 2):
				haste[Vector3i(x, y, z)] = cor.lightened(0.1 if y == 13 else 0.0)
	_haste = Node3D.new()
	_haste.name = "Haste"
	_haste.position.y = 4.0 / 16.0
	var modelo_haste := MeshInstance3D.new()
	modelo_haste.mesh = Voxel.malha(haste, 1.0 / 16.0)
	_haste.add_child(modelo_haste)
	add_child(_haste)
	var alvo := INCLINACAO * (-1.0 if ligada else 1.0)
	_haste.rotation.z = giro_anterior
	if Engine.is_editor_hint() or not is_inside_tree() or is_equal_approx(giro_anterior, alvo):
		_haste.rotation.z = alvo
	else:
		create_tween().tween_property(_haste, "rotation:z", alvo, 0.18).set_trans(Tween.TRANS_BACK)
	var corpo := StaticBody3D.new()
	corpo.collision_layer = 4
	corpo.collision_mask = 0
	var forma := BoxShape3D.new()
	forma.size = Vector3(0.5, 0.3, 0.4)
	var colisao := CollisionShape3D.new()
	colisao.shape = forma
	colisao.position.y = 0.15
	corpo.add_child(colisao)
	add_child(corpo)

@tool
class_name Mirante
extends ObjetoFase
## Mirante: um graveto fincado num toco, que não sai do lugar. Mordendo (botão de ação), a
## câmera vai para o 3D em volta dele e mostra a fase COMO ELA FICA NA VOLTA — o que é "só
## isométrico" some e o "só 3D" aparece, só no visual. É o jeito de o jogador descobrir antes
## que a ponte vai sumir, e planejar. Ação de novo (ou Esc) volta.

var _ponto: Marker3D


func nome_no_editor() -> String:
	return "Mirante"


func categoria_no_editor() -> String:
	return "Mecanismos"


func _ready() -> void:
	_montar()
	if not Engine.is_editor_hint():
		add_to_group(&"com_acao")


## Ponto em volta do qual a câmera gira.
func ponto_de_vista() -> Node3D:
	return _ponto


func acao_da_boca(cachorro: Dachshund) -> String:
	if cachorro.tem_graveto:
		return ""
	return "morder o mirante (ver a volta)"


func executar_acao(cachorro: Dachshund) -> void:
	var jogo := get_tree().current_scene
	if jogo and jogo.has_method("entrar_no_mirante") and not cachorro.tem_graveto:
		jogo.entrar_no_mirante(self)


## Toco de madeira com um graveto em pé e uma fitinha vermelha na ponta.
func _montar() -> void:
	for filho in get_children():
		remove_child(filho)
		filho.queue_free()
	var voxels := {}
	var casca := [Color("6b4428"), Color("5b3920"), Color("744b2c")]
	for x in range(-3, 3):
		for z in range(-3, 3):
			if absi(x * 2 + 1) + absi(z * 2 + 1) > 9:
				continue
			for y in 5:
				voxels[Vector3i(x, y, z)] = casca[(x * 3 + z + y) % casca.size()]
			voxels[Vector3i(x, 5, z)] = Color("c49a6c") if absi(x * 2 + 1) + absi(z * 2 + 1) < 6 else casca[0]
	for y in range(6, 20):
		for x in [-1, 0]:
			voxels[Vector3i(x, y, 0)] = Color("c89a5f") if y % 5 else Color("a87c48")
	for i in 4:
		voxels[Vector3i(1 + i / 2, 18 - i, 0)] = Color("e0433a")
	var modelo := MeshInstance3D.new()
	modelo.mesh = Voxel.malha(voxels, 1.0 / 16.0, Vector3(0, 0, 0.5))
	add_child(modelo)
	var corpo := StaticBody3D.new()
	corpo.collision_layer = 4
	corpo.collision_mask = 0
	var forma := CylinderShape3D.new()
	forma.radius = 0.2
	forma.height = 0.4
	var colisao := CollisionShape3D.new()
	colisao.shape = forma
	colisao.position.y = 0.2
	corpo.add_child(colisao)
	add_child(corpo)
	_ponto = Marker3D.new()
	_ponto.position.y = 1.4
	add_child(_ponto)

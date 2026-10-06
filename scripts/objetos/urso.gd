@tool
class_name Urso
extends Bicho
## Urso: grande e lento, passeia até `raio` m de onde foi colocado e, parado, balança a cabeça
## farejando. Ele bloqueia a passagem (tem colisão). O medo do cachorro e a revelação no fim
## ainda vão ser encaixados (ver docs/DESIGN.md, "Personagens que voltam").


func nome_no_editor() -> String:
	return "Urso"


func velocidade() -> float:
	return 0.8


func pausa() -> Vector2:
	return Vector2(3.0, 6.0)


## O urso precisa de mais espaço que um bicho pequeno: confere o corpo todo.
func _pode_estar(ponto: Vector3) -> bool:
	for lado in [Vector3.ZERO, Vector3(0.5, 0, 0), Vector3(-0.5, 0, 0), Vector3(0, 0, 0.5), Vector3(0, 0, -0.5)]:
		if not super(ponto + lado):
			return false
	return true


func _animar(_delta: float, andando: bool) -> void:
	var modelo := bicho.get_node(^"Modelo") as Node3D
	balancar_pernas(modelo, tempo * 5.0, 0.35 if andando else 0.0)
	modelo.position.y = absf(sin(tempo * 5.0)) * 0.03 if andando else 0.0
	var cabeca := modelo.get_node(^"Cabeca") as Node3D
	cabeca.rotation.y = 0.0 if andando else sin(tempo * 0.8) * 0.4
	cabeca.rotation.z = sin(tempo * 5.0) * 0.05 if andando else -0.15 + sin(tempo * 2.2) * 0.05


## Urso marrom grande: corpo com corcova, cabeça redonda com focinho claro e orelhas redondas.
func _montar_modelo() -> Node3D:
	var modelo := Node3D.new()
	var pelo := Color("5a3a22")
	var corpo := {}
	for x in range(-12, 12):
		for y in range(8, 23):
			for z in range(-7, 8):
				var corcova := 1.6 if x > 2 else 0.0
				if Vector3(x / 12.0, (y - 15.0 - corcova) / 7.0, z / 7.5).length() <= 1.0:
					corpo[Vector3i(x, y, z)] = pelo.darkened(0.1 if (x + y * 2 + z) % 5 == 0 else 0.0)
	peca(modelo, "Corpo", corpo)
	var cabeca := {}
	for x in range(-4, 5):
		for y in range(-4, 5):
			for z in range(-5, 6):
				if Vector3(x / 4.5, y / 4.5, z / 5.0).length() <= 1.0:
					cabeca[Vector3i(x, y, z)] = pelo
	caixa(cabeca, Vector3i(4, -3, -2), Vector3i(7, 0, 2), Color("a07a52"))
	caixa(cabeca, Vector3i(8, -1, -1), Vector3i(8, 0, 1), Color("141010"))
	cabeca[Vector3i(4, 2, -3)] = Color("141010")
	cabeca[Vector3i(4, 2, 3)] = Color("141010")
	for z in [-4, 4]:
		caixa(cabeca, Vector3i(-1, 4, z - 1), Vector3i(0, 6, z + 1), pelo.darkened(0.15))
	peca(modelo, "Cabeca", cabeca, Vector3(13, 18, 0))
	pernas(modelo, 9, 5, pelo.darkened(0.2), 7.0, -8.0, 4.0)
	var corpo_fisico := StaticBody3D.new()
	corpo_fisico.name = "Colisao"
	corpo_fisico.collision_layer = 4
	corpo_fisico.collision_mask = 0
	var forma := BoxShape3D.new()
	forma.size = Vector3(1.6, 1.3, 0.9)
	var colisao := CollisionShape3D.new()
	colisao.shape = forma
	colisao.position = Vector3(0.1, 0.65, 0.0)
	corpo_fisico.add_child(colisao)
	modelo.add_child(corpo_fisico)
	return modelo

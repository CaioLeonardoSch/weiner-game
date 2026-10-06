@tool
class_name Castor
extends Bicho
## Castor: anda no chão e nada na água, até `raio` m de onde foi colocado. A represa e o que os
## castores fazem no dia 8 ainda vão ser encaixados (ver docs/DESIGN.md, "Personagens que
## voltam").


func nome_no_editor() -> String:
	return "Castor"


func meio() -> Meio:
	return Meio.CHAO_E_AGUA


func velocidade() -> float:
	return 1.1


## Na água, nada com a cabeça e as costas de fora.
func altura_em(ponto: Vector3) -> float:
	var superficie := superficie_agua(ponto)
	return 0.0 if is_nan(superficie) else superficie - global_position.y - 0.18


func _animar(_delta: float, andando: bool) -> void:
	var modelo := bicho.get_node(^"Modelo") as Node3D
	balancar_pernas(modelo, tempo * 9.0, 0.5 if andando else 0.0)
	# Gingado do corpo andando; o rabo chato acompanha.
	modelo.position.y = absf(sin(tempo * 9.0)) * 0.02 if andando else 0.0
	(modelo.get_node(^"Rabo") as Node3D).rotation.z = sin(tempo * (9.0 if andando else 1.5)) * 0.12
	(modelo.get_node(^"Cabeca") as Node3D).rotation.y = 0.0 if andando else sin(tempo * 0.9) * 0.35


## Corpo marrom roliço, dentes da frente laranja, rabo chato e largo escuro.
func _montar_modelo() -> Node3D:
	var modelo := Node3D.new()
	var pelo := Color("7a4e2c")
	var corpo := {}
	for x in range(-4, 5):
		for y in range(2, 9):
			for z in range(-3, 4):
				if Vector3((x) / 4.5, (y - 5) / 3.5, z / 3.5).length() <= 1.0:
					corpo[Vector3i(x, y, z)] = pelo if (x + y + z) % 5 else pelo.darkened(0.12)
	peca(modelo, "Corpo", corpo)
	var cabeca := {}
	caixa(cabeca, Vector3i(0, 0, -2), Vector3i(3, 3, 2), pelo)
	caixa(cabeca, Vector3i(4, 0, -1), Vector3i(4, 2, 1), Color("4a3020"))
	cabeca[Vector3i(4, -1, 0)] = Color("e08a2c")
	cabeca[Vector3i(2, 3, -2)] = Color("16100c")
	cabeca[Vector3i(2, 3, 2)] = Color("16100c")
	cabeca[Vector3i(0, 4, -2)] = pelo.darkened(0.2)
	cabeca[Vector3i(0, 4, 2)] = pelo.darkened(0.2)
	peca(modelo, "Cabeca", cabeca, Vector3(4, 4, 0))
	var rabo := {}
	caixa(rabo, Vector3i(-6, 0, -2), Vector3i(-1, 0, 2), Color("3a3330"))
	peca(modelo, "Rabo", rabo, Vector3(-4, 2, 0))
	pernas(modelo, 2, 2, pelo.darkened(0.3), 2.5, -2.5, 2.5)
	return modelo

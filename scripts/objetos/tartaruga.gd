@tool
class_name Tartaruga
extends Bicho
## Tartaruga: nada devagar na água, com o casco de fora, até `raio` m de onde foi colocada (fora
## da água, fica parada). O que ela faz no córrego (servir de pedra, afundar e ir embora) ainda
## vai ser encaixado (ver docs/DESIGN.md, "Personagens que voltam").


func nome_no_editor() -> String:
	return "Tartaruga"


func meio() -> Meio:
	return Meio.AGUA


func velocidade() -> float:
	return 0.5


func pausa() -> Vector2:
	return Vector2(2.0, 5.0)


## Na superfície, com o casco um pouco afundado.
func altura_em(ponto: Vector3) -> float:
	var superficie := superficie_agua(ponto)
	return 0.0 if is_nan(superficie) else superficie - global_position.y - 0.12


func _animar(_delta: float, andando: bool) -> void:
	var modelo := bicho.get_node(^"Modelo") as Node3D
	# Boiando: sobe e desce devagar; nadando, as nadadeiras remam.
	modelo.position.y = sin(tempo * 1.6) * 0.015
	var remada := sin(tempo * (5.0 if andando else 1.2)) * (0.6 if andando else 0.1)
	for nome in ["NadadeiraFE", "NadadeiraTD"]:
		(modelo.get_node(NodePath(nome)) as Node3D).rotation.y = remada
	for nome in ["NadadeiraFD", "NadadeiraTE"]:
		(modelo.get_node(NodePath(nome)) as Node3D).rotation.y = -remada
	(modelo.get_node(^"Cabeca") as Node3D).rotation.y = sin(tempo * 0.7) * 0.3


## Casco abaulado verde-escuro com placas mais claras, cabeça e quatro nadadeiras.
func _montar_modelo() -> Node3D:
	var modelo := Node3D.new()
	var casco := {}
	var escuro := Color("4d5a2e")
	var claro := Color("6f7d3c")
	for x in range(-5, 6):
		for z in range(-4, 5):
			var r := Vector2(x / 5.5, z / 4.5).length()
			if r > 1.0:
				continue
			var altura := 1 + int((1.0 - r * r) * 3.0)
			for y in range(0, altura + 1):
				var placa := (absi(x) + absi(z)) % 4 == 0
				casco[Vector3i(x, y, z)] = Color("c9b98a") if y == 0 else (claro if placa else escuro)
	peca(modelo, "Casco", casco)
	var pele := Color("8c9a5b")
	var cabeca := {}
	caixa(cabeca, Vector3i(0, 0, -1), Vector3i(3, 2, 1), pele)
	cabeca[Vector3i(3, 2, -1)] = Color("1a1a14")
	cabeca[Vector3i(3, 2, 1)] = Color("1a1a14")
	peca(modelo, "Cabeca", cabeca, Vector3(5, 0.5, 0))
	var nadadeira := {}
	caixa(nadadeira, Vector3i(-1, 0, -1), Vector3i(1, 0, 1), pele)
	nadadeira[Vector3i(0, 0, 2)] = pele
	for dados in [["NadadeiraFE", 3, -4], ["NadadeiraFD", 3, 4], ["NadadeiraTE", -3, -4], ["NadadeiraTD", -3, 4]]:
		var vox := nadadeira.duplicate()
		if dados[2] < 0:
			vox.erase(Vector3i(0, 0, 2))
			vox[Vector3i(0, 0, -2)] = pele
		peca(modelo, dados[0], vox, Vector3(dados[1], 0.5, dados[2]))
	return modelo

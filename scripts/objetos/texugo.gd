@tool
class_name Texugo
extends Bicho
## Texugo: passeia até `raio` m de onde foi colocado e, se o cachorro chega perto, corre para
## longe dele (é o começo da perseguição brincalhona; ver docs/DESIGN.md, "Personagens que
## voltam"). Ninguém se machuca: ele só foge.

## Perto assim (m) do cachorro, o texugo corre.
@export_range(1.0, 8.0, 0.5) var distancia_de_fuga := 3.0

## Fugindo agora?
var fugindo := false


func nome_no_editor() -> String:
	return "Texugo"


func propriedades_editaveis() -> Array[StringName]:
	return [&"raio", &"distancia_de_fuga"]


func velocidade() -> float:
	return 3.4 if fugindo else 1.2


func _process(delta: float) -> void:
	if not Engine.is_editor_hint() and bicho != null and distancia_do_cachorro() < distancia_de_fuga:
		_fugir()
	elif fugindo and estado == Estado.PARADO:
		fugindo = false
	super(delta)


## Corre para o lado oposto ao cachorro (o ponto mais longe dele que der, até o dobro do raio).
func _fugir() -> void:
	var cachorro := cachorro_mais_perto()
	var longe := _plano(bicho.global_position - cachorro.global_position)
	if longe.length() < 0.01:
		longe = Vector3.RIGHT
	longe = longe.normalized()
	if fugindo and estado == Estado.ANDANDO and _plano(destino - bicho.global_position).normalized().dot(longe) > 0.3:
		return
	# Tenta reto para longe; depois de lado, cada vez mais.
	for angulo in [0.0, 0.5, -0.5, 1.0, -1.0, 1.5, -1.5]:
		var direcao := longe.rotated(Vector3.UP, angulo)
		var ponto := bicho.global_position + direcao * 3.0
		if _plano(ponto - global_position).length() <= maxf(raio * 2.0, 3.0) \
				and _caminho_livre(bicho.global_position, ponto):
			fugindo = true
			ir_para(ponto)
			return


func _animar(_delta: float, andando: bool) -> void:
	var modelo := bicho.get_node(^"Modelo") as Node3D
	var ritmo := 18.0 if fugindo else 10.0
	balancar_pernas(modelo, tempo * ritmo, 0.6 if andando else 0.0)
	modelo.position.y = absf(sin(tempo * ritmo)) * 0.025 if andando else 0.0
	(modelo.get_node(^"Cabeca") as Node3D).rotation.y = 0.0 if andando else sin(tempo * 1.3) * 0.4


## Corpo baixo e largo, cinza com a barriga escura, cara branca com a listra preta nos olhos.
func _montar_modelo() -> Node3D:
	var modelo := Node3D.new()
	var cinza := Color("8a8682")
	var corpo := {}
	for x in range(-5, 5):
		for y in range(2, 7):
			for z in range(-3, 4):
				if absi(z) == 3 and (y == 6 or y == 2):
					continue
				corpo[Vector3i(x, y, z)] = Color("2a2624") if y == 2 else cinza.darkened(0.1 if (x * 3 + z) % 4 == 0 else 0.0)
	caixa(corpo, Vector3i(-7, 4, -1), Vector3i(-6, 5, 1), cinza)
	peca(modelo, "Corpo", corpo)
	var cabeca := {}
	caixa(cabeca, Vector3i(0, 0, -2), Vector3i(4, 3, 2), Color("eeeae2"))
	for x in range(0, 5):
		for y in range(1, 4):
			cabeca[Vector3i(x, y, -2)] = Color("1c1a18")
			cabeca[Vector3i(x, y, 2)] = Color("1c1a18")
	caixa(cabeca, Vector3i(5, 0, -1), Vector3i(6, 1, 1), Color("eeeae2"))
	cabeca[Vector3i(7, 1, 0)] = Color("1c1a18")
	cabeca[Vector3i(0, 4, -2)] = Color("1c1a18")
	cabeca[Vector3i(0, 4, 2)] = Color("1c1a18")
	peca(modelo, "Cabeca", cabeca, Vector3(5, 3, 0))
	pernas(modelo, 2, 2, Color("1c1a18"), 3.0, -3.5, 2.5)
	return modelo

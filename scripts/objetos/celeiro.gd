@tool
class_name Celeiro
extends ObjetoFase
## Celeiro: o abrigo das ovelhas nas fases de pastoreio (como o Cercado, mas fechado e coberto).
## A porta (larga, sempre aberta) fica no meio do lado +X — gire o objeto para mudar o lado; para
## uma porta que abre e fecha, ponha um Portão na frente dela e ligue a uma placa.
## Uma ovelha que entra fica guardada (calma, não sai mais). Dentro é quentinho: nas fases com
## frio, o cachorro se esquenta aqui. Com o cachorro perto, o telhado e a parte de cima das
## paredes somem (só o visual: a colisão continua inteira), para dar para ver lá dentro.
## As paredes e o telhado são gerados pelo `tamanho`.

## Largura (X, o lado da porta fica em +X) e profundidade (Z), em metros.
@export var tamanho := Vector2i(5, 4):
	set(valor):
		tamanho = Vector2i(maxi(valor.x, 3), maxi(valor.y, 3))
		_montar()

const ALTURA := 2.0
const ESPESSURA := 0.2
const PORTA := 2.0
## Folga (m) das paredes para contar como "dentro": na soleira da porta ainda não vale.
const MARGEM := 0.4
## A esta distância (m) das paredes o telhado some, para ver o cachorro lá dentro.
const DISTANCIA_TELHADO := 2.5

var _telhado: Node3D
## Parte de cima das paredes (some junto com o telhado).
var _paredes_altas: MeshInstance3D
## Altura (voxels de 1/8 m) das paredes que ficam quando o telhado some.
const CORTE := 4


func nome_no_editor() -> String:
	return "Celeiro"


func categoria_no_editor() -> String:
	return "Regras"


func propriedades_editaveis() -> Array[StringName]:
	return [&"tamanho"]


func caixa_editor() -> AABB:
	return AABB(Vector3(-tamanho.x * 0.5, 0.0, -tamanho.y * 0.5), Vector3(tamanho.x, ALTURA + 1.2, tamanho.y))


func _ready() -> void:
	_montar()
	if not Engine.is_editor_hint():
		add_to_group(&"abrigos")
		add_to_group(&"fontes_de_calor")


func ao_mudar_bioma() -> void:
	_montar()


## O ponto (global) está bem dentro do celeiro (longe das paredes e da porta)?
func contem(ponto: Vector3) -> bool:
	var local := to_local(ponto)
	return absf(local.x) < tamanho.x * 0.5 - MARGEM and absf(local.z) < tamanho.y * 0.5 - MARGEM \
		and local.y > -0.6 and local.y < ALTURA


## Dentro das paredes é quentinho (a soleira já conta).
func aquece(ponto: Vector3) -> bool:
	if not visible:
		return false
	var local := to_local(ponto)
	return absf(local.x) < tamanho.x * 0.5 and absf(local.z) < tamanho.y * 0.5 - ESPESSURA \
		and local.y > -0.6 and local.y < ALTURA


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or _telhado == null:
		return
	var perto := false
	for cachorro in get_tree().get_nodes_in_group(&"cachorro"):
		var local := to_local((cachorro as Node3D).global_position)
		if absf(local.x) < tamanho.x * 0.5 + DISTANCIA_TELHADO and absf(local.z) < tamanho.y * 0.5 + DISTANCIA_TELHADO:
			perto = true
	_telhado.visible = not perto
	_paredes_altas.visible = not perto


# --- Visual e colisão --------------------------------------------------------------------------

func _montar() -> void:
	if not is_node_ready():
		return
	for filho in get_children():
		remove_child(filho)
		filho.queue_free()
	var nevado := bioma_da_fase() == Biomas.NEVE
	# Voxel de 1/8 m (a mesma densidade dos texels do terreno).
	var meia_x := tamanho.x * 4
	var meia_z := tamanho.y * 4
	var altura := int(ALTURA * 8)
	var meia_porta := int(PORTA * 4)
	var vermelhos := [Color("a8322b"), Color("9a2c26"), Color("b53a31")]
	var branco := Color("ece6da")
	var paredes := {}
	for y in altura:
		for x in range(-meia_x, meia_x):
			for z in [-meia_z, meia_z - 1]:
				paredes[Vector3i(x, y, z)] = _cor_parede(x, y, z, meia_x, meia_z, vermelhos, branco)
		for z in range(-meia_z, meia_z):
			paredes[Vector3i(-meia_x, y, z)] = _cor_parede(-meia_x, y, z, meia_x, meia_z, vermelhos, branco)
			var na_porta := absi(z * 2 + 1) < meia_porta * 2 and y < altura - 3
			if not na_porta:
				paredes[Vector3i(meia_x - 1, y, z)] = _cor_parede(meia_x - 1, y, z, meia_x, meia_z, vermelhos, branco)
	# Moldura branca da porta e o "X" das folhas abertas encostadas na parede.
	for y in altura - 2:
		for z in [-meia_porta - 1, meia_porta]:
			paredes[Vector3i(meia_x - 1, y, z)] = branco
	for z in range(-meia_porta - 1, meia_porta + 1):
		paredes[Vector3i(meia_x - 1, altura - 3, z)] = branco
	for lado in [-1, 1]:
		for i in meia_porta:
			for y in altura - 3:
				var z: int = lado * (meia_porta + 1 + i) + (0 if lado > 0 else -1)
				if absi(z) >= meia_z - 1:
					continue
				var diagonal := absi(i * (altura - 3) / meia_porta - y) <= 1 or absi((meia_porta - 1 - i) * (altura - 3) / meia_porta - y) <= 1
				var borda := i == 0 or i == meia_porta - 1 or y == 0 or y == altura - 4
				paredes[Vector3i(meia_x, y, z)] = branco if diagonal or borda else vermelhos[(i + y) % 3]
	# Feno num canto lá dentro.
	var fenos := [Color("d9b34a"), Color("c9a23d"), Color("e3c35e")]
	for x in range(-meia_x + 2, -meia_x + 8):
		for z in range(-meia_z + 2, -meia_z + 7):
			for y in 3:
				paredes[Vector3i(x, y, z)] = fenos[posmod(x * 3 + z + y, 3)]
	var baixas := {}
	var altas := {}
	for p: Vector3i in paredes:
		(baixas if p.y < CORTE else altas)[p] = paredes[p]
	var modelo := MeshInstance3D.new()
	modelo.name = "Paredes"
	modelo.mesh = Voxel.malha(baixas, 1.0 / 8.0)
	add_child(modelo)
	_paredes_altas = MeshInstance3D.new()
	_paredes_altas.name = "ParedesAltas"
	_paredes_altas.mesh = Voxel.malha(altas, 1.0 / 8.0)
	add_child(_paredes_altas)

	# Telhado de duas águas (cumeeira ao longo de X), com neve em cima no bioma de neve.
	_telhado = Node3D.new()
	_telhado.name = "Telhado"
	add_child(_telhado)
	var telhas := {}
	var marrons := [Color("5a3a2a"), Color("4e3224"), Color("65422f")]
	var beiral := meia_z + 2
	for z in range(-beiral, beiral):
		var distancia := absi(z * 2 + 1) / 2
		var y := altura + (beiral - distancia)
		for x in range(-meia_x - 1, meia_x + 1):
			var cor: Color = marrons[posmod(x + z, 3)]
			if nevado and (x + z * 7) % 5 != 0:
				cor = Biomas.CORES_NEVE[posmod(x * 5 + z, 3)]
			telhas[Vector3i(x, y, z)] = cor
			telhas[Vector3i(x, y - 1, z)] = marrons[posmod(x + z + 1, 3)]
	# Oitões (os triângulos das pontas) em vermelho.
	for x in [-meia_x, meia_x - 1]:
		for z in range(-meia_z, meia_z):
			var distancia := absi(z * 2 + 1) / 2
			for y in range(altura, altura + (beiral - distancia) - 1):
				telhas[Vector3i(x, y, z)] = vermelhos[posmod(y + z, 3)]
	var malha_telhado := MeshInstance3D.new()
	malha_telhado.mesh = Voxel.malha(telhas, 1.0 / 8.0)
	_telhado.add_child(malha_telhado)

	# Colisão: três paredes inteiras e a da porta em dois pedaços.
	var corpo := StaticBody3D.new()
	corpo.name = "Corpo"
	corpo.collision_layer = 4
	corpo.collision_mask = 0
	add_child(corpo)
	var largura := float(tamanho.x)
	var fundo := float(tamanho.y)
	_caixa(corpo, Vector3(0, 0, -fundo * 0.5 + ESPESSURA * 0.5), Vector3(largura, ALTURA, ESPESSURA))
	_caixa(corpo, Vector3(0, 0, fundo * 0.5 - ESPESSURA * 0.5), Vector3(largura, ALTURA, ESPESSURA))
	_caixa(corpo, Vector3(-largura * 0.5 + ESPESSURA * 0.5, 0, 0), Vector3(ESPESSURA, ALTURA, fundo))
	var pedaco := (fundo - PORTA) * 0.5
	if pedaco > 0.01:
		for lado in [-1.0, 1.0]:
			_caixa(corpo, Vector3(largura * 0.5 - ESPESSURA * 0.5, 0, lado * (PORTA + pedaco) * 0.5),
				Vector3(ESPESSURA, ALTURA, pedaco))
	# O feno também é sólido.
	_caixa(corpo, Vector3(-largura * 0.5 + 0.6, 0, -fundo * 0.5 + 0.55), Vector3(0.75, 0.375, 0.625))


func _cor_parede(x: int, y: int, z: int, meia_x: int, meia_z: int, vermelhos: Array, branco: Color) -> Color:
	# Cantos e rodapé brancos; tábuas verticais vermelhas com frestas mais escuras.
	var canto := (x <= -meia_x + 1 or x >= meia_x - 2) and (z <= -meia_z + 1 or z >= meia_z - 2)
	if canto or y == 0:
		return branco
	var tabua: Color = vermelhos[posmod(x + z, 3)]
	return tabua.darkened(0.25) if posmod(x + z, 4) == 0 else tabua


func _caixa(corpo: StaticBody3D, centro: Vector3, medidas: Vector3) -> void:
	var forma := BoxShape3D.new()
	forma.size = medidas
	var colisao := CollisionShape3D.new()
	colisao.shape = forma
	colisao.position = centro + Vector3.UP * medidas.y * 0.5
	corpo.add_child(colisao)

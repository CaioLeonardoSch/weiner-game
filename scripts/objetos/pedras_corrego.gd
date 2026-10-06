@tool
class_name PedrasCorrego
extends Travessia
## Pedras atravessando um córrego fundo (ao longo do Z local, de margem a margem). Na margem,
## olhando para as pedras, F faz o cachorro pular de pedra em pedra até a outra margem.
## Na margem, perto das pedras, Espaço também faz o cachorro pular por elas.
## As pedras não têm colisão, mas perto delas uma barreira invisível na beira da água não deixa o
## cachorro cair (nem passar andando por cima delas); longe das pedras, ele cai (e volta para a
## margem).
## Ponha sobre água funda (o tile Água): a margem fica a `espacamento` da primeira pedra.

## Quantas pedras.
@export_range(1, 6) var quantidade := 3:
	set(valor):
		quantidade = valor
		_montar()
## Distância (m) entre as pedras (e da margem à primeira e à última).
@export_range(0.8, 1.6, 0.1) var espacamento := 1.2:
	set(valor):
		espacamento = valor
		_montar()

## Altura (m) do topo das pedras: um pouco abaixo do chão, acima da água.
const TOPO := -0.05
const RAIO := 0.32
const COR := Color(0.55, 0.55, 0.52)
## Altura (m) do arco de cada pulo, a duração (s) e a pausa (s) em cada pedra.
const ALTURA_PULO := 0.35
const DURACAO_PULO := 0.4
const PAUSA := 0.15
## Largura (m, em X) da beira bloqueada dos dois lados, em volta das pedras.
const LARGURA_BEIRA := 3.0


func nome_no_editor() -> String:
	return "Pedras do córrego (pular)"


func propriedades_editaveis() -> Array[StringName]:
	return [&"quantidade", &"espacamento"]


func caixa_editor() -> AABB:
	var meio := _meio()
	return AABB(Vector3(-0.5, -0.6, -meio), Vector3(1.0, 0.7, meio * 2.0))


func _ready() -> void:
	super()
	_montar()


## Meio comprimento (m) do caminho, da pedra do meio até a margem.
func _meio() -> float:
	return (quantidade - 1) * 0.5 * espacamento + espacamento


func com_pulo() -> bool:
	return true


func caminho_local() -> PackedVector3Array:
	var pontos := PackedVector3Array([Vector3(0, 0, -_meio())])
	for i in quantidade:
		pontos.append(Vector3(0, TOPO, (i - (quantidade - 1) * 0.5) * espacamento))
	pontos.append(Vector3(0, 0, _meio()))
	return pontos


func _montar() -> void:
	if not is_node_ready():
		return
	_limpar()
	var caminho := caminho_local()
	for i in range(1, caminho.size() - 1):
		var pedra := MeshInstance3D.new()
		var cilindro := CylinderMesh.new()
		# Cada pedra um pouco diferente, sempre igual entre uma vez e outra.
		var raio := RAIO * (1.0 + 0.12 * sin(i * 2.3))
		cilindro.top_radius = raio * 0.85
		cilindro.bottom_radius = raio
		cilindro.height = 0.6
		cilindro.radial_segments = 7
		cilindro.material = Travessia.material(COR.darkened(0.08 * (i % 2)))
		pedra.mesh = cilindro
		pedra.position = caminho[i] + Vector3(0.0, -0.3, 0.0)
		pedra.rotation.y = i * 0.9
		add_child(pedra)
	# A beira da água, dos dois lados: entre a margem e a pedra da ponta.
	for lado in [-1.0, 1.0]:
		var beira: float = lado * (_meio() - espacamento * 0.5)
		Travessia.caixa_solida(self, Vector3(LARGURA_BEIRA, 1.0, 0.2), Vector3(0.0, 0.5, beira))


func _animar(cachorro: Dachshund, pontos: PackedVector3Array) -> void:
	var yaw := Travessia.yaw_para(pontos[pontos.size() - 1] - pontos[0])
	var ate_a_margem := cachorro.global_position.distance_to(pontos[0])
	await cachorro.atravessar(PackedVector3Array([pontos[0]]), maxf(ate_a_margem / 2.0, 0.15), yaw)
	for i in range(1, pontos.size()):
		await _esperar(PAUSA)
		await cachorro.saltar(pontos[i], ALTURA_PULO, DURACAO_PULO, yaw)


func _esperar(segundos: float) -> Signal:
	return get_tree().create_timer(segundos).timeout

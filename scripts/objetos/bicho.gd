@tool
class_name Bicho
extends ObjetoFase
## Base dos animais que andam sozinhos por uma área (tartaruga, peixe-cuspidor, castor, texugo,
## urso): o bicho passeia até `raio` metros de onde foi colocado, parando um pouco entre um
## passeio e outro. Cada um diz por onde pode andar (`_pode_estar`: chão, água ou os dois), monta
## o próprio modelo (`_montar_modelo`, olhando para o +X) e anima as partes (`_animar`).
## Por enquanto só se movimentam: o que cada um faz na história ainda vai ser encaixado (ver
## docs/DESIGN.md, "Personagens que voltam").
##
## O objeto fica parado onde foi colocado (é o centro da área); quem anda é o filho "Bicho".

enum Estado { PARADO, ANDANDO }
enum Meio { CHAO, AGUA, CHAO_E_AGUA }

## Até onde (m, de onde foi colocado) o bicho passeia (0 = fica parado).
@export_range(0.0, 15.0, 0.5) var raio := 4.0

var estado := Estado.PARADO
## Onde o bicho está agora (o modelo).
var bicho: Node3D
## Para onde está indo (vale em ANDANDO).
var destino := Vector3.ZERO
## Tempo (s) desde o começo, para as animações.
var tempo := 0.0
var _espera := 0.0
var _rng := RandomNumberGenerator.new()


func categoria_no_editor() -> String:
	return "Bichos"


func propriedades_editaveis() -> Array[StringName]:
	return [&"raio"]


func ao_colocar_no_editor(rng: RandomNumberGenerator) -> void:
	rotation.y = rng.randf_range(-PI, PI)


## Por onde anda (ver `_pode_estar`).
func meio() -> Meio:
	return Meio.CHAO


## Velocidade (m/s) passeando.
func velocidade() -> float:
	return 1.0


## Quanto tempo (s) fica parado entre um passeio e outro: [mínimo, máximo].
func pausa() -> Vector2:
	return Vector2(1.5, 4.0)


## Altura do modelo em relação ao objeto num ponto: na água, os que nadam ficam na superfície.
func altura_em(_ponto: Vector3) -> float:
	return 0.0


func _ready() -> void:
	_montar()
	if not Engine.is_editor_hint():
		add_to_group(&"bichos")
		# Sempre o mesmo passeio para o mesmo lugar (as rotas de teste repetem igual).
		_rng.seed = hash(Vector3i(global_position.round()))
		_espera = _rng.randf_range(0.3, pausa().y)


func _montar() -> void:
	for filho in get_children():
		remove_child(filho)
		filho.queue_free()
	bicho = Node3D.new()
	bicho.name = "Bicho"
	add_child(bicho)
	var modelo := _montar_modelo()
	modelo.name = "Modelo"
	bicho.add_child(modelo)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or bicho == null:
		return
	tempo += delta
	match estado:
		Estado.PARADO:
			_espera -= delta
			if _espera <= 0.0:
				_escolher_destino()
		Estado.ANDANDO:
			if _andar_ate(destino, velocidade(), delta):
				_parar()
	_animar(delta, estado == Estado.ANDANDO)


## Passeio novo: um ponto dentro do raio aonde dá para ir em linha reta.
func _escolher_destino() -> void:
	for tentativa in 10:
		var angulo := _rng.randf_range(-PI, PI)
		var distancia := _rng.randf_range(raio * 0.3, raio)
		var ponto := global_position + Vector3(cos(angulo), 0.0, sin(angulo)) * distancia
		if raio > 0.0 and _caminho_livre(bicho.global_position, ponto):
			ir_para(ponto)
			return
	_parar()


## Vai até `ponto` (no plano do objeto).
func ir_para(ponto: Vector3) -> void:
	destino = Vector3(ponto.x, global_position.y, ponto.z)
	estado = Estado.ANDANDO


func _parar() -> void:
	estado = Estado.PARADO
	_espera = _rng.randf_range(pausa().x, pausa().y)


## Dá para ir de `de` até `ate` em linha reta (pontos a cada 0,4 m)?
func _caminho_livre(de: Vector3, ate: Vector3) -> bool:
	var plano := _plano(ate - de)
	var passos := maxi(1, ceili(plano.length() / 0.4))
	for i in range(1, passos + 1):
		if not _pode_estar(de + plano * (float(i) / passos)):
			return false
	return true


## O bicho cabe em `ponto` (na altura do objeto)? Chão: chão firme embaixo e nada na altura do
## corpo (mato, pedra, parede). Água: água embaixo.
func _pode_estar(ponto: Vector3) -> bool:
	var fase := fase_do_objeto()
	if fase == null:
		return true
	var ponto_no_plano := Vector3(ponto.x, global_position.y, ponto.z)
	var embaixo := fase.tile_em(ponto_no_plano + Vector3.DOWN * 0.3)
	var na_altura := fase.tile_em(ponto_no_plano + Vector3.UP * 0.3)
	var agua := Tiles.eh_agua(embaixo)
	match meio():
		Meio.AGUA:
			return agua
		Meio.CHAO_E_AGUA:
			if agua:
				return true
	return embaixo != GridMap.INVALID_CELL_ITEM and not agua and not Tiles.eh_buraco(embaixo) \
		and na_altura == GridMap.INVALID_CELL_ITEM


## Anda em linha reta, virando aos poucos para onde vai. Verdadeiro ao chegar.
func _andar_ate(ponto: Vector3, quanto: float, delta: float) -> bool:
	var ate := _plano(ponto - bicho.global_position)
	if ate.length() < 0.08:
		return true
	var rumo := atan2(-ate.z, ate.x) - global_rotation.y
	bicho.rotation.y = lerp_angle(bicho.rotation.y, rumo, 1.0 - exp(-8.0 * delta))
	var passo := ate.normalized() * minf(quanto * delta, ate.length())
	bicho.global_position += passo
	var y := global_position.y + altura_em(bicho.global_position)
	bicho.global_position.y = lerpf(bicho.global_position.y, y, 1.0 - exp(-6.0 * delta))
	return false


## Distância (no plano) do cachorro mais perto, ou INF.
func distancia_do_cachorro() -> float:
	var menor := INF
	for cachorro in get_tree().get_nodes_in_group(&"cachorro"):
		menor = minf(menor, _plano((cachorro as Node3D).global_position - bicho.global_position).length())
	return menor


## O cachorro mais perto, ou nulo.
func cachorro_mais_perto() -> Node3D:
	var melhor: Node3D = null
	for cachorro in get_tree().get_nodes_in_group(&"cachorro"):
		var no := cachorro as Node3D
		if melhor == null or no.global_position.distance_to(bicho.global_position) \
				< melhor.global_position.distance_to(bicho.global_position):
			melhor = no
	return melhor


## Superfície da água (y global) embaixo de `ponto`, ou NAN fora da água.
func superficie_agua(ponto: Vector3) -> float:
	var fase := fase_do_objeto()
	if fase == null:
		return NAN
	var celula := fase.terreno.local_to_map(fase.terreno.to_local(ponto + Vector3.DOWN * 0.3))
	var id := fase.terreno.get_cell_item(celula)
	if not Tiles.eh_agua(id):
		return NAN
	var topo := Tiles.SUPERFICIE_AGUA_RASA if id == Tiles.AGUA_RASA else Tiles.SUPERFICIE_AGUA
	return fase.terreno.to_global(fase.terreno.map_to_local(celula)).y + topo


static func _plano(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


# --- Visual (cada bicho faz o seu) -----------------------------------------------------------

## O modelo, olhando para o +X, com a base no y = 0.
func _montar_modelo() -> Node3D:
	return Node3D.new()


## Anima as partes do modelo (`bicho.get_node("Modelo/...")`) a cada quadro.
func _animar(_delta: float, _andando: bool) -> void:
	pass


## Uma peça do modelo: voxels (cubinhos de 1/16 m) num nó filho de `pai`, em `posicao` (em
## voxels). Para animar uma parte (perna, cabeça, rabo), gire o nó que esta função devolve.
static func peca(pai: Node3D, nome: String, voxels: Dictionary, posicao := Vector3.ZERO) -> Node3D:
	var no := Node3D.new()
	no.name = nome
	no.position = posicao / 16.0
	var malha := MeshInstance3D.new()
	malha.mesh = Voxel.malha(voxels, 1.0 / 16.0)
	no.add_child(malha)
	pai.add_child(no)
	return no


## Caixa de voxels de `de` até `ate` (inclusive) com a cor `cor`, em `voxels`.
static func caixa(voxels: Dictionary, de: Vector3i, ate: Vector3i, cor: Color) -> void:
	for x in range(de.x, ate.x + 1):
		for y in range(de.y, ate.y + 1):
			for z in range(de.z, ate.z + 1):
				voxels[Vector3i(x, y, z)] = cor


## Quatro pernas ("PernaFE", "PernaFD", "PernaTE", "PernaTD"): blocos de `largura` × `altura`
## voxels pendurados do quadril, nas posições (x frente/trás, z lados) dadas, em voxels.
static func pernas(pai: Node3D, altura: int, largura: int, cor: Color, x_frente: float, x_tras: float, z_lado: float) -> void:
	var vox := {}
	caixa(vox, Vector3i(0, -altura, 0), Vector3i(largura - 1, -1, largura - 1), cor)
	var centro := (largura - 1) * 0.5
	for dados in [["PernaFE", x_frente, -z_lado], ["PernaFD", x_frente, z_lado],
			["PernaTE", x_tras, -z_lado], ["PernaTD", x_tras, z_lado]]:
		var perna := peca(pai, dados[0], vox, Vector3(dados[1], altura, dados[2]))
		(perna.get_child(0) as MeshInstance3D).position = Vector3(-centro, 0.0, -centro) / 16.0


## Passo das quatro pernas (diagonais juntas), `fase` em radianos, `amplitude` em radianos.
static func balancar_pernas(modelo: Node3D, fase_do_passo: float, amplitude: float) -> void:
	for dados in [["PernaFE", 0.0], ["PernaTD", 0.0], ["PernaFD", PI], ["PernaTE", PI]]:
		var perna := modelo.get_node_or_null(NodePath(dados[0])) as Node3D
		if perna:
			perna.rotation.z = sin(fase_do_passo + dados[1]) * amplitude

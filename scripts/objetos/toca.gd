@tool
class_name Toca
extends ObjetoFase
## Toca de texugo: um monte de terra com um buraco. O cachorro entra (andando para dentro do
## buraco ou com o botão de ação) e sai pela outra toca da MESMA COR — um atalho por baixo da
## terra, que qualquer raça usa. A tela escurece no caminho.
## Com o graveto na boca: `so_ao_comprido` só deixa entrar com ele ao comprido, e
## `comprimento_maximo` (m, 0 = qualquer) barra os compridos demais.
## O buraco fica para a frente (+Z local): gire o objeto para escolher o lado.

@export_enum("Amarelo", "Azul", "Vermelho", "Verde", "Roxo", "Laranja", "Ciano", "Rosa") var canal := 0:
	set(valor):
		canal = valor
		_montar()
## O graveto só entra ao comprido (atravessado, não cabe no buraco).
@export var so_ao_comprido := true
## Graveto mais comprido que isto (m) não entra; 0 = qualquer comprimento.
@export_range(0.0, 3.0, 0.05) var comprimento_maximo := 0.0

## Até onde a frente do buraco chama o cachorro para dentro (m, no eixo +Z local).
const ALCANCE := 0.95
const DURACAO_ENTRAR := 0.45
const DURACAO_SAIR := 0.45
const TEMPO_EMBAIXO := 0.35

var _ocupada := false


func nome_no_editor() -> String:
	return "Toca de texugo"


func categoria_no_editor() -> String:
	return "Mecanismos"


func propriedades_editaveis() -> Array[StringName]:
	return [&"canal", &"so_ao_comprido", &"comprimento_maximo"]


func _ready() -> void:
	_montar()
	if not Engine.is_editor_hint():
		add_to_group(&"com_acao")
		add_to_group(&"tocas")


## A outra toca da mesma cor (a primeira que existir e estiver ativa), ou null.
func par() -> Toca:
	var fase := fase_do_objeto()
	if fase == null:
		return null
	for objeto in fase.todos(Toca):
		var outra := objeto as Toca
		if outra != self and outra.canal == canal and outra.visible:
			return outra
	return null


## Ponto na frente do buraco (onde o cachorro para para entrar).
func ponto_da_entrada() -> Vector3:
	return global_transform * Vector3(0, 0, 0.6)


## Onde o cachorro fica "dentro" (escondido) e para onde sai.
func ponto_de_dentro() -> Vector3:
	return global_transform * Vector3(0, 0, -0.05)


func ponto_de_saida() -> Vector3:
	return global_transform * Vector3(0, 0, 0.95)


func ponto_da_acao(_cachorro: Dachshund) -> Vector3:
	return ponto_da_entrada()


func acao_da_boca(cachorro: Dachshund) -> String:
	if _ocupada or not _na_frente(cachorro):
		return ""
	return "entrar na toca"


func executar_acao(cachorro: Dachshund) -> void:
	_tentar_entrar(cachorro)


func _na_frente(cachorro: Dachshund) -> bool:
	var local := to_local(cachorro.global_position)
	return absf(local.x) < 0.4 and local.z > 0.15 and local.z < _alcance(cachorro) + 0.3 and absf(local.y) < 0.6


## Até onde o buraco chama este cachorro: com o graveto ao comprido apontado para a toca, a ponta
## bate no monte antes, então conta a partir dela.
func _alcance(cachorro: Dachshund) -> float:
	return ALCANCE + cachorro.alcance_extra_do_graveto(-global_basis.z)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or _ocupada:
		return
	for no in get_tree().get_nodes_in_group(&"cachorro"):
		var cachorro := no as Dachshund
		if cachorro == null or cachorro.atravessando or not _na_frente(cachorro):
			continue
		if to_local(cachorro.global_position).z > _alcance(cachorro):
			continue
		# Andando para dentro do buraco (contra o monte).
		var para_dentro := -global_basis.z
		para_dentro.y = 0.0
		if cachorro.direcao_desejada().dot(para_dentro.normalized()) > 0.7:
			_tentar_entrar(cachorro)


func _tentar_entrar(cachorro: Dachshund) -> void:
	var jogo := get_tree().current_scene
	if _ocupada or cachorro.atravessando or (jogo and jogo.get(&"concluida") == true):
		return
	var outra := par()
	if outra == null:
		return
	if not cachorro.graveto_passa(so_ao_comprido, comprimento_maximo):
		return
	_atravessar(cachorro, outra)


func _atravessar(cachorro: Dachshund, outra: Toca) -> void:
	_ocupada = true
	outra._ocupada = true
	var jogo := get_tree().current_scene
	var altura := cachorro.global_position.y - global_position.y
	var entrada := ponto_da_entrada()
	entrada.y = cachorro.global_position.y
	var dentro := ponto_de_dentro()
	dentro.y = cachorro.global_position.y
	var para_dentro := dentro - entrada
	await cachorro.atravessar(PackedVector3Array([entrada, dentro]), DURACAO_ENTRAR,
		atan2(-para_dentro.z, para_dentro.x), true)
	if jogo and jogo.has_method("escurecer"):
		await jogo.escurecer(true, 0.2)
	var saindo := outra.ponto_de_dentro() + Vector3.UP * altura
	cachorro.global_position = saindo
	await get_tree().create_timer(TEMPO_EMBAIXO).timeout
	if jogo and jogo.has_method("escurecer"):
		jogo.escurecer(false, 0.25)
	cachorro.show()
	var saida := outra.ponto_de_saida() + Vector3.UP * altura
	var para_fora := saida - saindo
	await cachorro.atravessar(PackedVector3Array([saida]), DURACAO_SAIR, atan2(-para_fora.z, para_fora.x))
	cachorro.terminar_travessia()
	# Um tempinho antes de poder voltar (senão, ainda segurando a tecla, entraria de novo).
	await get_tree().create_timer(0.4).timeout
	_ocupada = false
	outra._ocupada = false


## Monte de terra com o buraco escuro na frente, contornado de pedrinhas na cor do canal (a
## outra toca da mesma cor é a saída), tufos de grama em cima e terra solta na boca.
func _montar() -> void:
	if not is_node_ready():
		return
	for filho in get_children():
		remove_child(filho)
		filho.queue_free()
	var voxels := {}
	var terras := [Color("7a5534"), Color("6e4b2d"), Color("85603b"), Color("735031")]
	var cor := Canais.cor(canal)
	var neve := bioma_da_fase() == Biomas.NEVE
	for x in range(-8, 8):
		for z in range(-8, 6):
			var nx := (x + 0.5) / 8.0
			var nz := (z + 1.0) / 7.0
			var d := nx * nx + nz * nz
			if d > 1.0:
				continue
			var altura := int(14.0 * sqrt(1.0 - d)) + 1
			for y in altura:
				var voxel := Vector3i(x, y, z)
				var arco := _no_arco(x, y, 0.0)
				if arco and z >= 0:
					continue # o túnel
				var cor_terra: Color = terras[posmod(x * 5 + y * 3 + z * 7, terras.size())]
				if y == altura - 1:
					cor_terra = Color("eef3f7") if neve else Color("5f9b3c").darkened(0.08 if (x + z) % 3 == 0 else 0.0)
				elif _no_arco(x, y, 1.6) and z >= -1:
					# Borda do buraco: pedrinhas na cor do canal na frente, terra escura dentro.
					cor_terra = cor.darkened(0.1 if (x + y) % 2 == 0 else 0.0) if z >= 4 else Color("3b2718")
				voxels[voxel] = cor_terra
	# Fundo do túnel, bem escuro (parece que continua).
	for x in range(-4, 4):
		for y in range(0, 6):
			if _no_arco(x, y, 0.0):
				voxels[Vector3i(x, y, -1)] = Color("140d08")
	# Terra solta na boca.
	for p in [Vector3i(-5, 0, 6), Vector3i(-4, 0, 6), Vector3i(3, 0, 6), Vector3i(4, 0, 7), Vector3i(-2, 0, 7),
			Vector3i(1, 0, 7), Vector3i(5, 0, 6), Vector3i(-6, 0, 5)]:
		voxels[p] = terras[p.x & 3].lightened(0.05)
	var modelo := MeshInstance3D.new()
	modelo.name = "Modelo"
	modelo.mesh = Voxel.malha(voxels, 1.0 / 16.0)
	add_child(modelo)
	var corpo := StaticBody3D.new()
	corpo.collision_layer = 4
	corpo.collision_mask = 0
	var forma := BoxShape3D.new()
	forma.size = Vector3(0.95, 0.8, 0.75)
	var colisao := CollisionShape3D.new()
	colisao.shape = forma
	colisao.position = Vector3(0, 0.4, -0.08)
	corpo.add_child(colisao)
	add_child(corpo)


## (x, y) está dentro do arco do buraco (meia-elipse de 7 × 6 voxels), com `folga` a mais?
static func _no_arco(x: int, y: int, folga: float) -> bool:
	var ax := (x + 0.5) / (3.5 + folga)
	var ay := (y + 0.5) / (5.5 + folga)
	return ax * ax + ay * ay <= 1.0


func ao_mudar_bioma() -> void:
	_montar()

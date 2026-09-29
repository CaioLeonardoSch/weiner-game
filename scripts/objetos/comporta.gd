@tool
class_name Comporta
extends ObjetoFase
## Comporta de madeira ligada a um canal (a cor dos postes): com o canal ligado, a tábua sobe e
## a água do trecho à frente (+Z local, `largura` × `comprimento` células) baixa — a água
## funda vira rasa e dá para atravessar a pé. Com `encher`, faz o contrário: a água rasa vira
## funda (e fecha um caminho). Com `de_vez`, a mudança fica mesmo quando o canal desliga;
## senão, volta ao desligar — mas nunca com o cachorro dentro do trecho.

@export_enum("Amarelo", "Azul", "Vermelho", "Verde", "Roxo", "Laranja", "Ciano", "Rosa") var canal := 0:
	set(valor):
		canal = valor
		_montar()
## Células de largura do trecho de água (ao longo do X local).
@export_range(1, 12) var largura := 3:
	set(valor):
		largura = valor
		_montar()
## Células de comprimento do trecho (para a frente, +Z local).
@export_range(1, 16) var comprimento := 4:
	set(valor):
		comprimento = valor
		_montar()
## Enche em vez de baixar: a água rasa do trecho vira funda.
@export var encher := false
## A mudança fica, mesmo que o canal desligue depois.
@export var de_vez := false
## Com várias placas da mesma cor: qualquer uma (OU) ou todas (E).
@export_enum("Qualquer placa (OU)", "Todas as placas (E)") var regra := 0

const ALTURA := 1.0
const ESPESSURA := 0.375

var aberta := false
var _fase: Fase
var _tabua: Node3D
## Células de água do trecho → [tile, orientação] originais.
var _originais := {}
var _quer_abrir := false
var _tween: Tween
var _tween_agua: Tween


func nome_no_editor() -> String:
	return "Comporta"


func categoria_no_editor() -> String:
	return "Mecanismos"


func propriedades_editaveis() -> Array[StringName]:
	return [&"canal", &"regra", &"largura", &"comprimento", &"encher", &"de_vez"]


func papel_no_canal() -> String:
	return "reage"


func caixa_editor() -> AABB:
	return AABB(Vector3(-0.5, 0.0, -ESPESSURA * 0.5), Vector3(1.0, ALTURA + 0.25, ESPESSURA))


func _ready() -> void:
	_montar()
	if Engine.is_editor_hint():
		return
	_fase = fase_do_objeto()
	if _fase == null:
		return
	# Numa cena de fase salva, os objetos ficam prontos antes da fase (e do seu terreno).
	if not _fase.is_node_ready():
		await _fase.ready
	_guardar_trecho()
	_fase.canal_mudou.connect(_on_canal_mudou)
	_quer_abrir = _fase.canal_ligado(canal, regra == Portao.REGRA_TODAS)
	if _quer_abrir:
		_abrir(true)


## Centro (global) de cada célula do trecho, da mais perto da comporta para a mais longe.
func _pontos_do_trecho() -> Array[Vector3]:
	var pontos: Array[Vector3] = []
	for z in comprimento:
		for x in largura:
			pontos.append(global_transform * Vector3(x - (largura - 1) * 0.5, 0.0, 1.0 + z))
	return pontos


## Guarda as células de água (funda ou rasa) do trecho, na camada da comporta e na de baixo.
func _guardar_trecho() -> void:
	var terreno := _fase.terreno
	for ponto in _pontos_do_trecho():
		for descida: float in [-0.1, -0.6, 0.4]:
			var celula := terreno.local_to_map(terreno.to_local(ponto + Vector3.UP * descida))
			var id := terreno.get_cell_item(celula)
			if id == Tiles.AGUA or id == Tiles.AGUA_RASA:
				_originais[celula] = [id, terreno.get_cell_item_orientation(celula)]


func _on_canal_mudou(qual: int) -> void:
	if qual != canal:
		return
	_quer_abrir = _fase.canal_ligado(canal, regra == Portao.REGRA_TODAS)
	if _quer_abrir and not aberta:
		_abrir(false)


func _physics_process(_delta: float) -> void:
	# Voltar a água espera o cachorro sair do trecho.
	if Engine.is_editor_hint() or not aberta or _quer_abrir or de_vez or _fase == null:
		return
	if not _cachorro_no_trecho():
		_fechar()


func _cachorro_no_trecho() -> bool:
	var terreno := _fase.terreno
	for no in get_tree().get_nodes_in_group(&"cachorro"):
		var cachorro := no as Node3D
		for descida: float in [0.1, 0.6]:
			var celula := terreno.local_to_map(terreno.to_local(cachorro.global_position + Vector3.DOWN * descida))
			if _originais.has(celula):
				return true
	return false


func _abrir(na_hora: bool) -> void:
	aberta = true
	_animar_tabua(0.55, 0.0 if na_hora else 0.4)
	_trocar_agua(true, na_hora)
	if not na_hora:
		Som.rangido(get_parent(), global_position)


func _fechar() -> void:
	aberta = false
	_animar_tabua(0.0, 0.4)
	_trocar_agua(false, false)
	Som.rangido(get_parent(), global_position)


func _animar_tabua(altura: float, duracao: float) -> void:
	if _tween:
		_tween.kill()
	if duracao <= 0.0:
		_tabua.position.y = altura
		return
	_tween = create_tween()
	_tween.tween_property(_tabua, "position:y", altura, duracao).set_trans(Tween.TRANS_SINE)


## Troca a água do trecho, célula por célula a partir da comporta (a água "corre").
## `mudar`: aplica a mudança; senão, volta aos tiles originais.
func _trocar_agua(mudar: bool, na_hora: bool) -> void:
	var terreno := _fase.terreno
	var celulas: Array = _originais.keys()
	var perto := terreno.local_to_map(terreno.to_local(global_position))
	celulas.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		return Vector3(a - perto).length_squared() < Vector3(b - perto).length_squared())
	var de := Tiles.AGUA_RASA if encher else Tiles.AGUA
	var para := Tiles.AGUA if encher else Tiles.AGUA_RASA
	if _tween_agua:
		_tween_agua.kill()
	var tween: Tween = null if na_hora else create_tween()
	_tween_agua = tween
	var anterior := 0.0
	for celula: Vector3i in celulas:
		var original: Array = _originais[celula]
		if original[0] != de:
			continue
		var novo: int = para if mudar else de
		var troca := terreno.set_cell_item.bind(celula, novo, original[1])
		if tween == null:
			troca.call()
			continue
		var distancia := Vector3(celula - perto).length()
		tween.tween_interval(maxf((distancia - anterior) * 0.08, 0.0))
		anterior = distancia
		tween.tween_callback(troca)


## Dois postes com o topo na cor do canal, a tábua que desliza para cima e uma manivela.
func _montar() -> void:
	if not is_node_ready():
		return
	for filho in get_children():
		remove_child(filho)
		filho.queue_free()
	var cor := Canais.cor(canal)
	var postes := {}
	var altura_vox := int(ALTURA * 16) + 4
	for x: int in [-8, -7, 6, 7]:
		for y in altura_vox:
			for z in range(-3, 3):
				postes[Vector3i(x, y, z)] = cor.darkened(0.12 if (y + z) % 2 == 0 else 0.0) \
					if y >= altura_vox - 3 else Color("6b4a2c").darkened(0.1 if z == -3 or z == 2 else 0.0)
	# Travessa em cima, com a manivela.
	for x in range(-6, 6):
		for z in range(-2, 2):
			postes[Vector3i(x, altura_vox - 2, z)] = Color("5b3d24")
			postes[Vector3i(x, altura_vox - 1, z)] = Color("5b3d24")
	for y in range(altura_vox, altura_vox + 3):
		postes[Vector3i(-1, y, 0)] = Color("3d3d42")
	for x in range(-3, 2):
		postes[Vector3i(x, altura_vox + 3, 0)] = cor
	var modelo := MeshInstance3D.new()
	modelo.mesh = Voxel.malha(postes, 1.0 / 16.0)
	add_child(modelo)

	var tabua := {}
	for x in range(-6, 6):
		for y in range(-4, int(ALTURA * 16) - 3):
			for z in range(-2, 1):
				var borda := y % 4 == 3
				tabua[Vector3i(x, y, z)] = Color("7a5230") if borda else Color("94693f")
	_tabua = Node3D.new()
	_tabua.name = "Tabua"
	var modelo_tabua := MeshInstance3D.new()
	modelo_tabua.mesh = Voxel.malha(tabua, 1.0 / 16.0)
	_tabua.add_child(modelo_tabua)
	add_child(_tabua)
	if aberta:
		_tabua.position.y = 0.55

	var corpo := StaticBody3D.new()
	corpo.collision_layer = 4
	corpo.collision_mask = 0
	var forma := BoxShape3D.new()
	forma.size = Vector3(1.0, ALTURA, ESPESSURA)
	var colisao := CollisionShape3D.new()
	colisao.shape = forma
	colisao.position = Vector3(0, ALTURA * 0.5, 0)
	corpo.add_child(colisao)
	add_child(corpo)

	# No editor: o trecho de água que a comporta controla.
	mostrar_volume_no_editor(Vector3(largura, 0.6, comprimento), Color(0.3, 0.6, 1.0, 0.16))
	var volume := get_node_or_null(^"VolumeEditor") as Node3D
	if volume:
		volume.position = Vector3(0.0, -0.3, 0.5 + comprimento * 0.5)

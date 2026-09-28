@tool
class_name Ponte
extends ObjetoFase
## Ponte de tábuas. Atravessa no sentido X local (`tamanho.x`: de uma margem à outra) e tem a
## largura `tamanho.z`; o topo fica na altura da origem (rente ao chão) e as tábuas não passam do
## `tamanho` — do tamanho do vão, sem invadir a grama das margens.
##
## `tipo`:
## - **Firme**: uma ponte comum.
## - **Cede com o tempo**: velha — aguenta alguém passando, mas quem fica em cima por mais de
##   `tempo_para_ceder` segundos faz ela ranger, tremer e quebrar.
## - **Quebra num gatilho**: cai quando o canal (a cor) liga — por exemplo um *Gatilho* ao pegar
##   o graveto, ou ao passar por algum lugar. Ligue com a ferramenta Ligar do editor.
## Quebrada, as tábuas caem na água e a correnteza leva (se não houver correnteza, descem o rio no
## sentido da largura da ponte).

signal quebrou

enum Tipo { FIRME, CEDE, GATILHO }

@export var tamanho := Vector3(1.0, 0.12, 2.0):
	set(valor):
		tamanho = Vector3(maxf(valor.x, 0.5), maxf(valor.y, 0.06), maxf(valor.z, 0.5))
		_montar()
@export_enum("Firme", "Cede com o tempo", "Quebra num gatilho") var tipo: int = Tipo.FIRME:
	set(valor):
		tipo = valor
		_montar()
## Cede com o tempo: quantos segundos com alguém em cima até quebrar.
@export_range(0.3, 10.0, 0.1) var tempo_para_ceder := 1.5
@export_enum("Amarelo", "Azul", "Vermelho", "Verde", "Roxo", "Laranja", "Ciano", "Rosa") var canal := 0
## O aviso que aparece quando ela quebra (vazio: "A ponte caiu!"). Pode ter teclas, como nas
## zonas de dica: {acao}, {virar_graveto}...
@export_multiline var aviso_ao_quebrar := ""

const LARGURA_TABUA := 3  # voxels de 1/16 m
const MADEIRAS := [Color("a8773f"), Color("9a6a35"), Color("b5834a"), Color("8f6232")]

var quebrada := false
var _peso := 0.0
var _rangeu := false
var _tabuas: Array[MeshInstance3D] = []
var _corpo: StaticBody3D
var _fase: Fase


func nome_no_editor() -> String:
	return "Ponte de madeira"


func propriedades_editaveis() -> Array[StringName]:
	return [&"tamanho", &"tipo", &"tempo_para_ceder", &"canal", &"aviso_ao_quebrar"]


func papel_no_canal() -> String:
	return "reage" if tipo == Tipo.GATILHO else ""


func caixa_editor() -> AABB:
	return AABB(Vector3(-tamanho.x * 0.5, -tamanho.y, -tamanho.z * 0.5), tamanho)


func _ready() -> void:
	_montar()
	if Engine.is_editor_hint():
		return
	_fase = fase_do_objeto()
	if _fase and tipo == Tipo.GATILHO:
		_fase.canal_mudou.connect(_on_canal_mudou)


func _on_canal_mudou(canal_mudado: int) -> void:
	if canal_mudado == canal and _fase.canal_ativo(canal):
		quebrar()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or quebrada or tipo != Tipo.CEDE:
		return
	if _alguem_em_cima():
		_peso += delta
		if not _rangeu:
			_rangeu = true
			Som.rangido(get_parent(), global_position)
		# Treme cada vez mais até quebrar.
		var forca := clampf(_peso / tempo_para_ceder, 0.0, 1.0)
		for tabua in _tabuas:
			tabua.position.y = tabua.get_meta(&"y") + sin(Time.get_ticks_msec() * 0.05 + tabua.get_index()) * 0.015 * forca
		if _peso >= tempo_para_ceder:
			quebrar()
	elif _peso > 0.0:
		_peso = maxf(_peso - delta * 2.0, 0.0)
		_rangeu = false
		for tabua in _tabuas:
			tabua.position.y = tabua.get_meta(&"y")


func _alguem_em_cima() -> bool:
	for cachorro in get_tree().get_nodes_in_group(&"cachorro"):
		var local := to_local((cachorro as Node3D).global_position)
		if absf(local.x) < tamanho.x * 0.5 and absf(local.z) < tamanho.z * 0.5 and local.y > -0.3 and local.y < 0.8:
			return true
	return false


## Quebra: a colisão some na hora e as tábuas caem na água, levadas pela correnteza.
func quebrar() -> void:
	if quebrada:
		return
	quebrada = true
	if _corpo:
		_corpo.process_mode = Node.PROCESS_MODE_DISABLED
	Som.estalo(get_parent(), global_position)
	var sentido := _sentido_da_agua()
	for i in _tabuas.size():
		var tabua := _tabuas[i]
		var atraso := i * 0.04
		var tween := tabua.create_tween()
		tween.tween_interval(atraso)
		tween.tween_property(tabua, "position:y", -0.35, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(tabua, "rotation", Vector3(randf_range(-0.3, 0.3), randf_range(-0.8, 0.8), randf_range(-0.3, 0.3)), 0.3)
		var longe := tabua.position + to_local(global_position + sentido * randf_range(5.0, 8.0)) - to_local(global_position)
		longe.y = -0.35
		tween.tween_property(tabua, "position", longe, randf_range(2.5, 3.5)).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(tabua, "scale", Vector3(1.0, 0.2, 1.0), randf_range(2.5, 3.5)).set_delay(1.5)
		tween.tween_callback(tabua.hide)
		Efeitos.respingo(get_parent(), tabua.global_position + Vector3.DOWN * 0.3)
	quebrou.emit()


## Para onde a água leva as tábuas: a correnteza embaixo da ponte ou, sem ela, ao longo da
## largura da ponte (o sentido do rio).
func _sentido_da_agua() -> Vector3:
	if _fase:
		var terreno := _fase.terreno
		var celula := terreno.local_to_map(terreno.to_local(global_position + Vector3.DOWN * 0.3))
		var chao := terreno.get_cell_item(celula)
		if Tiles.definicao(chao).get("correnteza", 0.0) > 0.0:
			var sentido := terreno.global_basis * terreno.get_cell_item_basis(celula).x
			sentido.y = 0.0
			return sentido.normalized()
	var ao_longo := global_basis.z
	ao_longo.y = 0.0
	return ao_longo.normalized()


# --- Visual e colisão --------------------------------------------------------------------------

## Tábuas atravessadas (cada uma um pedaço, para cair sozinha), com frestas entre elas e duas
## vigas embaixo nas bordas — tudo dentro do `tamanho`. Pontes fracas têm tábuas mais escuras,
## rachadas e com falhas.
func _montar() -> void:
	if not is_node_ready():
		return
	for filho in get_children():
		remove_child(filho)
		filho.queue_free()
	_tabuas.clear()
	var comprimento := maxi(roundi(tamanho.x * 16.0), 2)
	var largura := maxi(roundi(tamanho.z * 16.0), 2)
	var altura := maxi(roundi(tamanho.y * 16.0), 1)
	var fraca := tipo != Tipo.FIRME
	var rng := RandomNumberGenerator.new()
	rng.seed = comprimento * 131 + largura * 7 + tipo
	var z := 0
	var indice := 0
	while z < largura:
		var fim := mini(z + LARGURA_TABUA, largura)
		var voxels := {}
		var cor: Color = MADEIRAS[rng.randi() % MADEIRAS.size()]
		if fraca:
			cor = cor.darkened(0.25)
		for x in comprimento:
			for zz in range(z, fim):
				for y in altura:
					var c := cor.darkened(0.12 if (x + zz * 3) % 7 == 0 else 0.0)
					# Rachaduras e falhas nas pontes velhas.
					if fraca and y == altura - 1 and (x * 5 + zz * 11 + indice) % 23 == 0:
						continue
					if fraca and y == altura - 1 and (x + indice * 3) % 9 == 0:
						c = c.darkened(0.35)
					voxels[Vector3i(x, y, zz)] = c
		var tabua := MeshInstance3D.new()
		tabua.name = "Tabua%d" % indice
		tabua.mesh = Voxel.malha(voxels, 1.0 / 16.0, Vector3(comprimento * 0.5, altura, largura * 0.5))
		tabua.set_meta(&"y", 0.0)
		add_child(tabua)
		_tabuas.append(tabua)
		z = fim + (1 if fim < largura - 1 else 0)
		indice += 1
	# Vigas nas duas bordas, embaixo das tábuas (dentro do tamanho).
	var vigas := {}
	for x in comprimento:
		for zz in [0, largura - 1]:
			for y in range(-2, 0):
				vigas[Vector3i(x, y, zz)] = Color("5e3d22").darkened(0.15 if fraca else 0.0)
	var malha_vigas := MeshInstance3D.new()
	malha_vigas.name = "Vigas"
	malha_vigas.mesh = Voxel.malha(vigas, 1.0 / 16.0, Vector3(comprimento * 0.5, altura, largura * 0.5))
	add_child(malha_vigas)
	_tabuas.append(malha_vigas)
	malha_vigas.set_meta(&"y", 0.0)

	_corpo = StaticBody3D.new()
	_corpo.name = "Corpo"
	_corpo.collision_layer = 4
	_corpo.collision_mask = 0
	var forma := BoxShape3D.new()
	forma.size = tamanho
	var colisao := CollisionShape3D.new()
	colisao.shape = forma
	colisao.position.y = -tamanho.y * 0.5
	_corpo.add_child(colisao)
	add_child(_corpo)

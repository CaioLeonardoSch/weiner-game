@tool
class_name Portao
extends ObjetoFase
## Portão de madeira ligado a um canal (a cor dos postes): abre enquanto o canal está ativo
## (ou fecha, com `inverter`). Com várias placas da cor, `regra` diz se basta uma (OU) ou se
## precisa de todas (E). Aberto, desce para dentro do chão e deixa passar.
## Com `atraso`, continua aberto uns segundos depois que o canal desliga (dá tempo de correr
## da placa até o portão). Na regra E, lampadinhas em cima mostram quantas placas já estão
## acionadas.
## Nunca fecha em cima de ninguém: espera o vão ficar livre. Com `travar_aberto`, uma vez
## aberto fica aberto (bom para as primeiras fases).
## Largura em células, ao longo do X local (gire o objeto para mudar a direção).

@export_enum("Amarelo", "Azul", "Vermelho", "Verde", "Roxo", "Laranja", "Ciano", "Rosa") var canal := 0:
	set(valor):
		canal = valor
		_montar()
@export_range(1, 4) var largura := 1:
	set(valor):
		largura = valor
		_montar()
## Abre quando o canal DESLIGA (e fecha quando liga).
@export var inverter := false
## Uma vez aberto, não fecha mais.
@export var travar_aberto := false
## Com várias placas da mesma cor: abre com qualquer uma acionada (OU) ou só com todas (E).
@export_enum("Qualquer placa (OU)", "Todas as placas (E)") var regra := 0
## Segundos que fica aberto depois que o canal desliga (0 = fecha logo).
@export_range(0.0, 30.0, 0.5) var atraso := 0.0

const REGRA_TODAS := 1

const ALTURA := 1.0
const ESPESSURA := 0.375
const _MADEIRAS := [Color("8a6038"), Color("7a5230"), Color("94693f")]

var aberto := false
var _fase: Fase
var _corpo: StaticBody3D
var _visual: Node3D
var _quer_abrir := false
var _tween: Tween
## Tempo que ainda falta para poder fechar (o `atraso`).
var _espera := 0.0
var _luzes: Array[MeshInstance3D] = []


func nome_no_editor() -> String:
	return "Portão"


func categoria_no_editor() -> String:
	return "Mecanismos"


func propriedades_editaveis() -> Array[StringName]:
	return [&"canal", &"regra", &"largura", &"inverter", &"travar_aberto", &"atraso"]


func papel_no_canal() -> String:
	return "reage"


func caixa_editor() -> AABB:
	return AABB(Vector3(-largura * 0.5, 0.0, -ESPESSURA * 0.5), Vector3(largura, ALTURA, ESPESSURA))


func _ready() -> void:
	_montar()
	if Engine.is_editor_hint():
		return
	_fase = fase_do_objeto()
	if _fase:
		_fase.canal_mudou.connect(_on_canal_mudou)
		_quer_abrir = _deve_abrir()
		if _quer_abrir:
			_abrir(true)
		_atualizar_luzes.call_deferred()


func _on_canal_mudou(qual: int) -> void:
	if qual != canal:
		return
	var queria := _quer_abrir
	_quer_abrir = _deve_abrir()
	if queria and not _quer_abrir:
		_espera = atraso
	if _quer_abrir and not aberto:
		_abrir(false)
	_atualizar_luzes()


func _deve_abrir() -> bool:
	return _fase.canal_ligado(canal, regra == REGRA_TODAS) != inverter


func _physics_process(delta: float) -> void:
	# Fechar espera o atraso e o vão ficar livre (cachorro, bloco, ovelha...).
	if Engine.is_editor_hint() or not aberto or _quer_abrir or travar_aberto:
		return
	if _espera > 0.0:
		_espera -= delta
		# No último segundo e meio, o portão pisca avisando que vai fechar.
		_visual.visible = _espera > 1.5 or fmod(_espera, 0.3) > 0.1
		return
	_visual.visible = true
	if _vao_livre():
		_fechar()


## Lampadinhas da regra E: uma por placa da cor, acesas as que estão acionadas.
func _atualizar_luzes() -> void:
	if _fase == null or _visual == null or not is_node_ready():
		return
	var contagem := _fase.fontes_do_canal(canal)
	var total := contagem.y if regra == REGRA_TODAS and contagem.y >= 2 else 0
	if _luzes.size() != total:
		for luz in _luzes:
			if is_instance_valid(luz):
				luz.queue_free()
		_luzes.clear()
		var cubo := BoxMesh.new()
		cubo.size = Vector3.ONE * 3.0 / 16.0
		for i in total:
			var luz := MeshInstance3D.new()
			luz.mesh = cubo
			luz.position = Vector3((i - (total - 1) * 0.5) * 0.25, ALTURA + 0.1, 0.0)
			_visual.add_child(luz)
			_luzes.append(luz)
	var cor := Canais.cor(canal)
	for i in _luzes.size():
		var acesa := i < contagem.x
		var material := StandardMaterial3D.new()
		material.albedo_color = cor.lightened(0.35) if acesa else Color("2b2620")
		material.emission_enabled = acesa
		material.emission = cor
		material.emission_energy_multiplier = 1.5
		_luzes[i].material_override = material


func _abrir(na_hora: bool) -> void:
	aberto = true
	_corpo.process_mode = Node.PROCESS_MODE_DISABLED
	_animar(-ALTURA + 0.02, 0.0 if na_hora else 0.35)


func _fechar() -> void:
	aberto = false
	_corpo.process_mode = Node.PROCESS_MODE_INHERIT
	_animar(0.0, 0.35)


func _animar(altura: float, duracao: float) -> void:
	if _tween:
		_tween.kill()
	if duracao <= 0.0:
		_visual.position.y = altura
		return
	_tween = create_tween()
	_tween.tween_property(_visual, "position:y", altura, duracao).set_trans(Tween.TRANS_SINE)


func _vao_livre() -> bool:
	var forma := BoxShape3D.new()
	forma.size = Vector3(largura - 0.05, ALTURA - 0.1, ESPESSURA + 0.3)
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma
	consulta.transform = global_transform * Transform3D(Basis.IDENTITY, Vector3(0, ALTURA * 0.5, 0))
	consulta.collision_mask = 4 | 8
	consulta.exclude = [_corpo.get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(consulta, 1).is_empty()


## Portão grosso (0,375 m), para aparecer bem de cima na câmera isométrica: tábuas de madeira,
## o topo inteiro na cor do canal e postes mais altos nas pontas, também com a cor.
func _montar() -> void:
	if not is_node_ready():
		return
	for filho in get_children():
		remove_child(filho)
		filho.queue_free()
	var voxels := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = largura * 13 + canal
	var meia := largura * 8
	var cor := Canais.cor(canal)
	var altura_vox := int(ALTURA * 16)
	for x in range(-meia, meia):
		var poste := x < -meia + 2 or x >= meia - 2
		var topo := altura_vox + (2 if poste else 0)
		for y in topo:
			for z in range(-3, 3):
				var madeira: Color = _MADEIRAS[rng.randi() % _MADEIRAS.size()]
				var borda_tabua := (x + meia) % 4 == 3 and (z == -3 or z == 2)
				if y >= topo - 2:
					voxels[Vector3i(x, y, z)] = cor.darkened(0.12 if (x + z) % 2 == 0 else 0.0)
				elif poste:
					voxels[Vector3i(x, y, z)] = _MADEIRAS[0].darkened(0.2)
				else:
					voxels[Vector3i(x, y, z)] = madeira.darkened(0.25) if borda_tabua else madeira
	_visual = Node3D.new()
	_visual.name = "Visual"
	var modelo := MeshInstance3D.new()
	modelo.mesh = Voxel.malha(voxels, 1.0 / 16.0)
	_visual.add_child(modelo)
	add_child(_visual)
	_luzes.clear()
	_atualizar_luzes.call_deferred()

	_corpo = StaticBody3D.new()
	_corpo.name = "Corpo"
	_corpo.collision_layer = 4
	_corpo.collision_mask = 0
	var forma := BoxShape3D.new()
	forma.size = Vector3(largura, ALTURA, ESPESSURA)
	var colisao := CollisionShape3D.new()
	colisao.shape = forma
	colisao.position = Vector3(0, ALTURA * 0.5, 0)
	_corpo.add_child(colisao)
	add_child(_corpo)
	if aberto:
		_visual.position.y = -ALTURA + 0.02
		_corpo.process_mode = Node.PROCESS_MODE_DISABLED

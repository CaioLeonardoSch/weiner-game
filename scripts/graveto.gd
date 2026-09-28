@tool
class_name Graveto
extends ObjetoFase
## Graveto no chão. Quando o cachorro encosta, emite `pego`.
##
## Toda fase de buscar tem um graveto **lendário** (dourado, com brilho): é o único que o dono
## aceita. Os **comuns** (marrons) também trocam a perspectiva ao serem pegos, mas servem de
## ferramenta: peso numa placa, algo para trocar. Com a boca cheia, não se pega outro.
##
## `comprimento` e `peso` variam o graveto: o comprimento decide por onde ele passa (a colisão
## dele vai na boca) e o peso deixa o cachorro mais lento na volta.

signal pego(cachorro: Dachshund)
## O cachorro encostou, mas um passarinho está guardando o graveto (no máximo 1 vez a cada 2 s).
signal protegido
## O cachorro encostou já com outro graveto na boca (no máximo 1 vez a cada 2 s).
signal boca_cheia

const MATERIAL_LENDARIO := preload("res://assets/materiais/graveto_lendario.tres")
const MATERIAL_COMUM := preload("res://assets/materiais/graveto_comum.tres")

## O lendário (dourado) é o que o dono quer; os comuns são ferramentas.
@export var lendario := true:
	set(valor):
		lendario = valor
		_atualizar_visual()

## Amplitude (m) e velocidade da flutuação enquanto está no chão, só para chamar atenção.
@export var amplitude_flutuacao := 0.05
@export var velocidade_flutuacao := 3.0
## Depois de largado, por quantos segundos o graveto ignora o cachorro
## (senão ele seria pego de novo na hora).
@export var tempo_para_repegar := 0.5
## Comprimento em metros (atravessado na boca do cachorro).
@export_range(0.4, 3.0, 0.05) var comprimento := 0.8:
	set(valor):
		comprimento = valor
		_atualizar_forma()
## 1 = normal. Mais pesado, mais devagar o cachorro anda carregando.
@export_range(0.5, 3.0, 0.1) var peso := 1.0
## Enterrado: só aparece um montinho de terra (com a pontinha do graveto); o cachorro cava
## (C, com a habilidade Cavar) de frente para ele para desenterrar.
@export var enterrado := false:
	set(valor):
		enterrado = valor
		_atualizar_enterrado()

var ja_pego := false
var _tempo := 0.0
var _bloqueio := 0.0
var _espera_aviso := 0.0
## Um passarinho barrou o cachorro encostado: quando ele for embora, o graveto é pego sem o
## cachorro precisar sair e encostar de novo. Fora disso, só um encostar novo pega (senão o
## graveto recém-largado embaixo do focinho voltaria sozinho para a boca).
var _barrado_por_passaro := false
## Um bicho (esquilo) está levando o graveto: não dá para pegar e não pesa em placa.
var com_bicho: Node = null
var _montinho: MeshInstance3D

@onready var visual: Node3D = $Visual
@onready var area: Area3D = $AreaPegar


func nome_no_editor() -> String:
	return "Graveto lendário" if lendario else "Graveto comum"


func categoria_no_editor() -> String:
	return "Regras"


func propriedades_editaveis() -> Array[StringName]:
	return [&"lendario", &"comprimento", &"peso", &"enterrado"]


func _ready() -> void:
	_atualizar_forma()
	_atualizar_visual()
	_atualizar_enterrado()
	if not Engine.is_editor_hint():
		area.body_entered.connect(_on_body_entered)
		add_to_group(&"pesos")


## Largado no chão, pesa na placa; na boca, o peso entra no do cachorro.
func peso_na_placa() -> float:
	return 0.0 if ja_pego or enterrado or com_bicho else peso


func _process(delta: float) -> void:
	if ja_pego or enterrado or com_bicho or Engine.is_editor_hint():
		return
	_bloqueio = maxf(_bloqueio - delta, 0.0)
	_espera_aviso = maxf(_espera_aviso - delta, 0.0)
	# O cachorro pode já estar encostado quando o passarinho vai embora.
	if _barrado_por_passaro and _bloqueio <= 0.0 and area.monitoring:
		for corpo in area.get_overlapping_bodies():
			_on_body_entered(corpo)
	_tempo += delta
	visual.position.y = sin(_tempo * velocidade_flutuacao) * amplitude_flutuacao
	visual.rotation.y += delta


## Multiplicador da velocidade do cachorro enquanto carrega este graveto.
func fator_velocidade() -> float:
	return 1.0 / (1.0 + maxf(peso - 1.0, 0.0) * 0.3)


## Volta a ficar disponível no chão (quem posiciona é o jogo).
func soltar() -> void:
	ja_pego = false
	_barrado_por_passaro = false
	_bloqueio = tempo_para_repegar
	area.set_deferred("monitoring", true)


func _on_body_entered(body: Node3D) -> void:
	if ja_pego or _bloqueio > 0.0 or not body is Dachshund:
		return
	if (body as Dachshund).tem_graveto:
		if _espera_aviso <= 0.0:
			_espera_aviso = 2.0
			boca_cheia.emit()
		return
	# Passarinhos pousados perto e esquilos na porta da toca não deixam pegar.
	for guarda in get_tree().get_nodes_in_group(&"passaros") + get_tree().get_nodes_in_group(&"guardas"):
		if guarda.guarda(global_position):
			_barrado_por_passaro = true
			if _espera_aviso <= 0.0:
				_espera_aviso = 2.0
				protegido.emit()
			return
	ja_pego = true
	_barrado_por_passaro = false
	# Não dá para mudar o monitoring dentro do próprio callback de física.
	area.set_deferred("monitoring", false)
	visual.position = Vector3.ZERO
	visual.rotation = Vector3.ZERO
	pego.emit(body)


func _atualizar_forma() -> void:
	if not is_node_ready():
		return
	# Malha e forma são "local_to_scene" na cena: cada graveto tem as suas.
	(($Visual/Haste as MeshInstance3D).mesh as BoxMesh).size.z = comprimento
	($Visual/Galhinho as Node3D).position.z = comprimento * 0.22
	(($AreaPegar/Colisao as CollisionShape3D).shape as BoxShape3D).size.z = comprimento + 0.1


## Dourado com brilho (lendário) ou marrom (comum).
func _atualizar_visual() -> void:
	if not is_node_ready():
		return
	var material: Material = MATERIAL_LENDARIO if lendario else MATERIAL_COMUM
	($Visual/Haste as MeshInstance3D).material_override = material
	($Visual/Galhinho as MeshInstance3D).material_override = material
	var brilho := get_node_or_null(^"Visual/Brilho")
	if lendario and brilho == null:
		$Visual.add_child(_criar_brilho())
	elif not lendario and brilho:
		brilho.queue_free()


## Faíscas douradas (cubinhos, combinando com o pixelado) subindo devagar.
static func _criar_brilho() -> CPUParticles3D:
	var faiscas := CPUParticles3D.new()
	faiscas.name = "Brilho"
	var cubo := BoxMesh.new()
	cubo.size = Vector3.ONE * 0.045
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("ffe58a")
	cubo.material = material
	faiscas.mesh = cubo
	faiscas.amount = 7
	faiscas.lifetime = 1.3
	faiscas.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	faiscas.emission_sphere_radius = 0.35
	faiscas.direction = Vector3.UP
	faiscas.spread = 25.0
	faiscas.gravity = Vector3(0, 0.25, 0)
	faiscas.initial_velocity_min = 0.05
	faiscas.initial_velocity_max = 0.2
	faiscas.scale_amount_min = 0.6
	faiscas.scale_amount_max = 1.2
	faiscas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return faiscas


# --- Enterrado e bichos --------------------------------------------------------------------

## Desenterra (o cachorro cavou): o graveto pula para fora do montinho.
func desenterrar() -> void:
	if not enterrado:
		return
	enterrado = false
	Efeitos.terra(get_parent(), global_position + Vector3.UP * 0.1)
	visual.position.y = -0.3
	var tween := create_tween()
	tween.tween_property(visual, "position:y", 0.25, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "position:y", 0.0, 0.2).set_trans(Tween.TRANS_BOUNCE)


func _atualizar_enterrado() -> void:
	if not is_node_ready():
		return
	($Visual/Haste as Node3D).visible = not enterrado
	($Visual/Galhinho as Node3D).visible = not enterrado
	var brilho := get_node_or_null(^"Visual/Brilho") as CPUParticles3D
	if brilho:
		brilho.emitting = not enterrado
	if enterrado and _montinho == null:
		_montinho = MeshInstance3D.new()
		_montinho.name = "Montinho"
		_montinho.mesh = _malha_montinho(lendario, bioma_da_fase() == Biomas.NEVE)
		add_child(_montinho)
	elif not enterrado and _montinho:
		_montinho.queue_free()
		_montinho = null
	if not Engine.is_editor_hint():
		area.monitoring = not enterrado and com_bicho == null
		if enterrado:
			add_to_group(&"enterrados")
		else:
			remove_from_group(&"enterrados")


func ao_mudar_bioma() -> void:
	if _montinho:
		_montinho.mesh = _malha_montinho(lendario, bioma_da_fase() == Biomas.NEVE)


## Montinho de terra (ou de neve) com a pontinha do graveto de fora (dourada, no lendário).
static func _malha_montinho(dourado: bool, de_neve := false) -> ArrayMesh:
	var voxels := {}
	for x in range(-5, 5):
		for z in range(-5, 5):
			var r := Vector2(x + 0.5, z + 0.5).length()
			var altura := int(3.2 - r * 0.6)
			for y in range(0, altura):
				var cor: Color = Biomas.CORES_NEVE[posmod(x * 3 + z + y, 3)] if de_neve else Color("7a5230")
				voxels[Vector3i(x, y, z)] = cor.darkened(0.12 if (x * 3 + z + y) % 4 == 0 else 0.0)
	var ponta := Color("e8b93c") if dourado else Color("8a6038")
	for y in range(2, 6):
		voxels[Vector3i(1 + y / 3, y, 0)] = ponta
	return Voxel.malha(voxels, 1.0 / 16.0)


## Um bicho pegou o graveto (ele passa a posicionar o graveto a cada quadro).
func levar_por(bicho: Node) -> void:
	com_bicho = bicho
	area.set_deferred("monitoring", false)
	visual.position = Vector3.ZERO
	visual.rotation = Vector3.ZERO


## O bicho largou o graveto em `posicao` (no chão), atravessado na direção `yaw`.
func largar_do_bicho(posicao: Vector3, yaw: float) -> void:
	com_bicho = null
	global_transform = Transform3D(Basis(Vector3.UP, yaw + PI * 0.5), posicao + Vector3.UP * 0.08)
	soltar()


## Foi para a fogueira: some da fase (não pesa, não é pego, não é levado por bichos).
func queimar() -> void:
	ja_pego = true
	for grupo in [&"pesos", &"enterrados"]:
		remove_from_group(grupo)
	hide()
	queue_free()

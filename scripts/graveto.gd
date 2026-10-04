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
## A ponta pegou fogo (encostada numa fogueira acesa) / o fogo acabou.
signal acendeu
signal apagou

const MATERIAL_LENDARIO := preload("res://assets/materiais/graveto_lendario.tres")
const MATERIAL_COMUM := preload("res://assets/materiais/graveto_comum.tres")
## Segundos que a ponta acesa dura sem chuva nem vento.
const DURACAO_CHAMA := 25.0
## Distância (em XZ) da ponta até o meio de uma fogueira para pegar fogo (ou acender a fogueira).
const ALCANCE_FOGO := 0.75
## Segundos com a ponta no fogo até ela pegar.
const TEMPO_PARA_PEGAR_FOGO := 0.4
## Quanto do fogo cada bloco de neve derretido gasta.
const GASTO_DERRETER := 0.25

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
## Graveto aceso: um graveto comum encostado no fogo leva uma chama na ponta. Ela derrete a neve
## que encosta, acende fogueiras montadas (ver Fogueira.acende_com_fogo) e vai se acabando —
## mais rápido na chuva e no vento forte.
var aceso := false
## Quanto resta da chama (1 = acabou de acender, 0 = apagou).
var chama := 0.0
## Qual ponta está acesa (+1 ou -1, ao longo do Z do graveto).
var _lado_aceso := 1.0
var _no_fogo := 0.0
var _espera_derreter := 0.0
var _fogo: Node3D

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


## Pontos ao longo do comprimento (no máximo meio metro entre eles): um graveto comprido pesa na
## placa com qualquer parte em cima dela, não só com o meio.
func pontos_de_apoio() -> PackedVector3Array:
	var meio := maxf(comprimento * 0.5 - 0.1, 0.0)
	var partes := maxi(ceili(meio * 2.0 / 0.5), 1)
	var pontos := PackedVector3Array()
	for i in partes + 1:
		pontos.append(to_global(Vector3(0.0, 0.0, -meio + meio * 2.0 * float(i) / float(partes))))
	return pontos


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if aceso:
		_arder(delta)
	elif ja_pego and not lendario and com_bicho == null and is_inside_tree():
		_pegar_fogo(delta)
	if ja_pego or enterrado or com_bicho:
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
	if (body as Dachshund).boca_ocupada():
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
	if _fogo:
		_fogo.position = Vector3(0.0, 0.03, _lado_aceso * comprimento * 0.5)


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


# --- Graveto aceso -------------------------------------------------------------------------

## Ponta do graveto (lado +1 ou -1), no mundo.
func ponta(lado: float) -> Vector3:
	return visual.global_transform * Vector3(0.0, 0.0, lado * comprimento * 0.5)


## Acende a ponta `lado` (o lendário não pega fogo).
func acender(lado := 1.0) -> void:
	if lendario or aceso or not is_node_ready():
		return
	aceso = true
	chama = 1.0
	_lado_aceso = signf(lado) if lado != 0.0 else 1.0
	_fogo = Node3D.new()
	_fogo.name = "Fogo"
	var labareda := MeshInstance3D.new()
	labareda.name = "Chama"
	labareda.mesh = Fogueira._malha_chama(0)
	labareda.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fogo.add_child(labareda)
	var luz := OmniLight3D.new()
	luz.name = "Luz"
	luz.light_color = Color(1.0, 0.62, 0.3)
	luz.omni_range = 2.5
	luz.light_energy = 0.9
	luz.position.y = 0.2
	_fogo.add_child(luz)
	var faiscas := _criar_brilho()
	faiscas.name = "Faiscas"
	(faiscas.mesh.surface_get_material(0) as StandardMaterial3D).albedo_color = Color("ffb347")
	faiscas.emission_sphere_radius = 0.06
	faiscas.amount = 5
	faiscas.gravity = Vector3(0, 0.8, 0)
	faiscas.position.y = 0.12
	_fogo.add_child(faiscas)
	visual.add_child(_fogo)
	_atualizar_forma()
	_escalar_fogo()
	acendeu.emit()


## A chama acabou (ou foi apagada): uma fumacinha e o graveto volta a ser comum.
func apagar() -> void:
	if not aceso:
		return
	aceso = false
	chama = 0.0
	if is_inside_tree():
		Efeitos.vapor(get_parent(), ponta(_lado_aceso) + Vector3.UP * 0.1)
	if _fogo:
		_fogo.queue_free()
		_fogo = null
	apagou.emit()


## Com a ponta na chama de uma fogueira acesa por um instante, o graveto pega fogo.
func _pegar_fogo(delta: float) -> void:
	for fogueira: Fogueira in get_tree().get_nodes_in_group(&"fogueiras"):
		if not fogueira.acesa or not fogueira.visible:
			continue
		for lado: float in [1.0, -1.0]:
			if fogueira.alcanca(ponta(lado), ALCANCE_FOGO):
				_no_fogo += delta
				if _no_fogo >= TEMPO_PARA_PEGAR_FOGO:
					_no_fogo = 0.0
					acender(lado)
					_avisar("A ponta do graveto pegou fogo!")
				return
	_no_fogo = 0.0


## A chama vai se acabando (chuva e vento aceleram), derrete a neve em que encosta e acende
## fogueiras montadas.
func _arder(delta: float) -> void:
	var ponta_acesa := ponta(_lado_aceso)
	var gasto := 1.0 / DURACAO_CHAMA
	var jogo := get_tree().current_scene
	var clima: Variant = jogo.get(&"clima") if jogo else null
	if clima is Clima:
		gasto *= 1.0 + (clima as Clima).chuva * 2.0
	gasto += Vento.total_em(self, ponta_acesa).length() * 0.016
	chama -= gasto * delta
	if chama <= 0.0:
		apagar()
		_avisar("O graveto apagou")
		return
	_escalar_fogo()
	for fogueira: Fogueira in get_tree().get_nodes_in_group(&"fogueiras"):
		if fogueira.precisa_de_fogo() and fogueira.visible and fogueira.alcanca(ponta_acesa, ALCANCE_FOGO):
			fogueira.acender_com_fogo()
	_espera_derreter = maxf(_espera_derreter - delta, 0.0)
	if _espera_derreter <= 0.0:
		_derreter_na_ponta(ponta_acesa)


## Derrete o bloco de neve em que a ponta encosta (na altura dela; o chão fica).
func _derreter_na_ponta(ponta_acesa: Vector3) -> void:
	# Na boca, o graveto fica fora da fase (no cachorro): a fase vem do jogo.
	var fase := fase_do_objeto()
	if fase == null:
		var jogo := get_tree().current_scene
		fase = jogo.get(&"fase") as Fase if jogo else null
	if fase == null:
		return
	var terreno := fase.terreno
	var para_fora := (ponta_acesa - visual.global_position)
	para_fora.y = 0.0
	var pontos: Array[Vector3] = [ponta_acesa, ponta_acesa + para_fora.normalized() * 0.2]
	var dono := get_parent() as Node3D
	if ja_pego and dono:
		var frente := dono.global_basis.x
		frente.y = 0.0
		pontos.append(ponta_acesa + frente.normalized() * 0.3)
	for ponto in pontos:
		var celula := terreno.local_to_map(terreno.to_local(ponto))
		var id := terreno.get_cell_item(celula)
		if not Tiles.derrete(id):
			continue
		var novo: int = Tiles.definicao(id).derrete_em
		terreno.set_cell_item(celula, novo if novo >= 0 else GridMap.INVALID_CELL_ITEM,
			terreno.get_cell_item_orientation(celula))
		Efeitos.vapor(fase.objetos, terreno.to_global(terreno.map_to_local(celula)) + Vector3.UP * 0.3)
		chama -= GASTO_DERRETER
		_espera_derreter = 0.3
		if chama <= 0.0:
			apagar()
			_avisar("O graveto apagou")
		return


## Chama menor conforme se acaba, tremulando.
func _escalar_fogo() -> void:
	if _fogo == null:
		return
	var tamanho := 0.18 + 0.2 * clampf(chama, 0.0, 1.0)
	var pulso := sin(Time.get_ticks_msec() * 0.013 + get_instance_id()) * 0.5 + 0.5
	# A chama fica em pé, qualquer que seja o jeito do graveto.
	_fogo.global_rotation = Vector3.ZERO
	_fogo.scale = Vector3(1.0 - pulso * 0.12, 0.85 + pulso * 0.3, 1.0 - pulso * 0.12) * tamanho
	var luz := _fogo.get_node_or_null(^"Luz") as OmniLight3D
	if luz:
		luz.light_energy = 0.5 + 0.6 * chama + pulso * 0.15


func _avisar(texto: String) -> void:
	var jogo := get_tree().current_scene
	if jogo and jogo.has_method(&"mostrar_aviso") and ja_pego:
		jogo.mostrar_aviso(texto)


## Foi para a fogueira: some da fase (não pesa, não é pego, não é levado por bichos).
func queimar() -> void:
	ja_pego = true
	for grupo in [&"pesos", &"enterrados"]:
		remove_from_group(grupo)
	hide()
	queue_free()

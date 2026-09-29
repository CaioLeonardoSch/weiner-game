@tool
class_name Fogueira
extends ObjetoFase
## Fogueira: um círculo de pedras que se acende com gravetos. Cada graveto comum trazido na boca
## (F perto da fogueira, ou largado junto dela) entra na pilha; com `gravetos_para_acender`, ela
## acende. Acesa, esquenta quem está perto (fases com frio), derrete a neve em volta (tiles com
## `derrete_em`: neve fofa vira terra, montes de neve somem) e revela o que estava enterrado na
## neve. Cada graveto a mais aumenta o fogo: o raio cresce até `raio_maximo`.
## O graveto lendário não vai para o fogo. Acesa, também aciona o canal (a cor): dá para ligar
## um portão a ela com a ferramenta Ligar — ou deixar sem ligação nenhuma.
##
## Com `acende_com_fogo`, a pilha completa fica só montada: falta trazer fogo — um graveto aceso
## (a ponta encostada em outra fogueira acesa) encostado na lenha, ou F perto dela.

signal acendeu
signal cresceu
## Um graveto entrou na pilha, com a fogueira ainda apagada.
signal recebeu(gravetos: int, faltam: int)

## Gravetos para acender (0 = já começa acesa).
@export_range(0, 8) var gravetos_para_acender := 3:
	set(valor):
		gravetos_para_acender = valor
		_montar()
## Raio (m) do calor e do derretimento ao acender.
@export_range(1.0, 8.0, 0.5) var raio_inicial := 2.5
## Quanto o raio cresce a cada graveto a mais, depois de acesa.
@export_range(0.0, 3.0, 0.25) var raio_por_graveto := 1.0
@export_range(1.0, 12.0, 0.5) var raio_maximo := 6.0
@export_enum("Amarelo", "Azul", "Vermelho", "Verde", "Roxo", "Laranja", "Ciano", "Rosa") var canal := 0
## A pilha completa não acende sozinha: precisa de um graveto aceso.
@export var acende_com_fogo := false:
	set(valor):
		acende_com_fogo = valor
		_montar()

## Gravetos já na pilha.
var gravetos := 0
var acesa := false
var raio := 0.0
var _fase: Fase
var _chamas: Array[MeshInstance3D] = []
var _luz: OmniLight3D
var _faiscas: CPUParticles3D
var _fumaca: CPUParticles3D
var _lenha: MeshInstance3D
var _tempo := 0.0


func nome_no_editor() -> String:
	return "Fogueira"


func categoria_no_editor() -> String:
	return "Mecanismos"


func propriedades_editaveis() -> Array[StringName]:
	return [&"gravetos_para_acender", &"acende_com_fogo", &"raio_inicial", &"raio_por_graveto", &"raio_maximo", &"canal"]


func papel_no_canal() -> String:
	return "aciona"


func canal_opcional() -> bool:
	return true


func caixa_editor() -> AABB:
	return AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1.0, 0.6, 1.0))


func _ready() -> void:
	_montar()
	if Engine.is_editor_hint():
		return
	add_to_group(&"com_acao")
	add_to_group(&"fontes_de_calor")
	add_to_group(&"fogueiras")
	_fase = fase_do_objeto()
	if _fase:
		_fase.definir_fonte(canal, self, false)
	if gravetos_para_acender == 0 and not acende_com_fogo:
		_acender_no_inicio.call_deferred()


## Esquenta este ponto? (Dachshund: fases com frio.)
func aquece(ponto: Vector3) -> bool:
	if not acesa or not visible:
		return false
	var ate := ponto - global_position
	return absf(ate.y) < 3.0 and Vector2(ate.x, ate.z).length() <= raio


## Este ponto está no fogo (a até `alcance` m do meio, em XZ, e na altura das chamas)?
func alcanca(ponto: Vector3, alcance: float) -> bool:
	var ate := ponto - global_position
	return ate.y > -0.3 and ate.y < 1.0 and Vector2(ate.x, ate.z).length() <= alcance


## A pilha está completa, mas falta o fogo (`acende_com_fogo`).
func precisa_de_fogo() -> bool:
	return acende_com_fogo and not acesa and gravetos >= gravetos_para_acender


## Um graveto aceso encostou na lenha montada.
func acender_com_fogo() -> void:
	if precisa_de_fogo():
		_acender()


## Aceita este graveto na pilha? (Comum, e o fogo ainda pode crescer. Com a pilha montada
## esperando fogo, só o graveto aceso — que acende a fogueira.)
func aceita(graveto: Graveto) -> bool:
	if graveto == null or graveto.lendario:
		return false
	if precisa_de_fogo():
		return graveto.aceso
	return not acesa or raio < raio_maximo - 0.01


func acao_da_boca(cachorro: Dachshund) -> String:
	if not cachorro.tem_graveto or not aceita(cachorro.graveto):
		return ""
	if precisa_de_fogo():
		return "acender a fogueira"
	if acesa:
		return "pôr o graveto no fogo"
	return "pôr o graveto na fogueira (%d de %d)" % [gravetos + 1, gravetos_para_acender]


func executar_acao(cachorro: Dachshund) -> void:
	if acao_da_boca(cachorro).is_empty():
		return
	# Com o graveto aceso, a fogueira montada acende e o graveto continua na boca.
	if precisa_de_fogo():
		_acender()
		return
	var jogo := get_tree().current_scene
	if jogo and jogo.has_method("entregar_graveto"):
		jogo.entregar_graveto(self)


## O graveto veio para a fogueira (quem tirou da boca foi o jogo): some e entra na pilha.
func receber_graveto(graveto: Graveto) -> void:
	var trouxe_fogo := graveto.aceso
	graveto.queimar()
	gravetos += 1
	if precisa_de_fogo() and trouxe_fogo:
		_acender()
	elif acesa:
		raio = minf(raio + raio_por_graveto, raio_maximo)
		_atualizar_fogo()
		_derreter()
		cresceu.emit()
	elif gravetos >= gravetos_para_acender and not acende_com_fogo:
		_acender()
	else:
		recebeu.emit(gravetos, gravetos_para_acender - gravetos)
	_montar_lenha()


## Já começa acesa. No editor de fases (a fase fica parada lá) só o visual: derreter a neve ali
## iria para o arquivo da fase ao salvar.
func _acender_no_inicio() -> void:
	if can_process():
		_acender()
	else:
		acesa = true
		raio = raio_inicial
		_atualizar_fogo()


## "gravetos / pedidos" enquanto apagada (o jogo mostra em cima da fogueira); "" acesa.
func texto_do_contador() -> String:
	if precisa_de_fogo():
		return "precisa de fogo"
	if acesa or gravetos_para_acender <= 0:
		return ""
	return "%d / %d" % [gravetos, gravetos_para_acender]


func _acender() -> void:
	if acesa:
		return
	acesa = true
	raio = raio_inicial
	_atualizar_fogo()
	_derreter()
	if _fase:
		_fase.definir_fonte(canal, self, true)
	acendeu.emit()


func definir_ativo(ligado: bool) -> void:
	super(ligado)
	if _fase and acesa:
		_fase.definir_fonte(canal, self, ligado)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not acesa:
		return
	_tempo += delta
	# Chamas tremulando e a luz piscando junto.
	for i in _chamas.size():
		var chama := _chamas[i]
		var pulso := sin(_tempo * (9.0 + i * 2.3) + i) * 0.5 + 0.5
		chama.scale = Vector3(1.0 - pulso * 0.15, 0.8 + pulso * 0.4, 1.0 - pulso * 0.15) * _tamanho_do_fogo()
	if _luz:
		_luz.light_energy = 1.6 + sin(_tempo * 13.0) * 0.2 + sin(_tempo * 7.3) * 0.15


## O fogo cresce com o raio: acesa com o raio inicial = 1.
func _tamanho_do_fogo() -> float:
	return clampf(0.8 + (raio - raio_inicial) * 0.12, 0.8, 1.6)


# --- Derreter -------------------------------------------------------------------------------

## Derrete a neve até `raio`, de dentro para fora (um anel por vez), e revela o que estava
## enterrado nela.
func _derreter() -> void:
	if _fase == null:
		return
	var terreno := _fase.terreno
	var centro := terreno.local_to_map(terreno.to_local(global_position + Vector3.UP * 0.3))
	var alcance := ceili(raio)
	var celulas: Array = []
	for x in range(-alcance, alcance + 1):
		for z in range(-alcance, alcance + 1):
			for y in range(-2, 3):
				var celula := centro + Vector3i(x, y, z)
				if not Tiles.derrete(terreno.get_cell_item(celula)):
					continue
				var mundo := terreno.to_global(terreno.map_to_local(celula))
				var distancia := Vector2(mundo.x - global_position.x, mundo.z - global_position.z).length()
				if distancia <= raio:
					celulas.append([distancia, celula])
	var enterrados: Array = []
	if _fase.bioma == Biomas.NEVE:
		for objeto in _fase.todos(Graveto):
			var graveto := objeto as Graveto
			var ate := graveto.global_position - global_position
			if graveto.enterrado and Vector2(ate.x, ate.z).length() <= raio:
				enterrados.append([Vector2(ate.x, ate.z).length(), graveto])
	celulas.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	enterrados.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	if celulas.is_empty() and enterrados.is_empty():
		return
	var tween := create_tween()
	var anterior := 0.0
	var i := 0
	var j := 0
	while i < celulas.size() or j < enterrados.size():
		var usar_celula: bool = j >= enterrados.size() or (i < celulas.size() and celulas[i][0] <= enterrados[j][0])
		var proximo: Array = celulas[i] if usar_celula else enterrados[j]
		tween.tween_interval(maxf((proximo[0] - anterior) * 0.12, 0.0))
		anterior = proximo[0]
		if usar_celula:
			tween.tween_callback(_derreter_celula.bind(proximo[1]))
			i += 1
		else:
			tween.tween_callback((proximo[1] as Graveto).desenterrar)
			j += 1


func _derreter_celula(celula: Vector3i) -> void:
	var terreno := _fase.terreno
	var id := terreno.get_cell_item(celula)
	if not Tiles.derrete(id):
		return
	var novo: int = Tiles.definicao(id).derrete_em
	terreno.set_cell_item(celula, novo if novo >= 0 else GridMap.INVALID_CELL_ITEM,
		terreno.get_cell_item_orientation(celula))
	Efeitos.vapor(get_parent(), terreno.to_global(terreno.map_to_local(celula)) + Vector3.UP * 0.4)


# --- Visual ---------------------------------------------------------------------------------

## Pedras em anel, a lenha (o que já foi trazido) e, acesa, as chamas, a luz, as faíscas e a
## fumaça. Quantos gravetos faltam aparece no HUD do jogo (`texto_do_contador`), em 2D: um texto
## 3D passaria pelo pixelado e ficaria ilegível.
func _montar() -> void:
	if not is_node_ready():
		return
	for filho in get_children():
		remove_child(filho)
		filho.queue_free()
	_chamas.clear()
	_luz = null
	_faiscas = null
	_fumaca = null
	var pedras := {}
	var cinzas := [Color("7d8089"), Color("8e9199"), Color("6c6f77")]
	for i in 9:
		var angulo := i * TAU / 9.0
		var cx := roundi(cos(angulo) * 6.0)
		var cz := roundi(sin(angulo) * 6.0)
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				for y in 3:
					if y == 2 and absi(dx) + absi(dz) > 1:
						continue
					pedras[Vector3i(cx + dx, y, cz + dz)] = cinzas[posmod(i + dx + y, 3)]
	# Cinza e brasas no meio.
	for x in range(-4, 5):
		for z in range(-4, 5):
			if x * x + z * z <= 16:
				pedras[Vector3i(x, 0, z)] = Color("3a3230") if (x + z) % 3 else Color("5a4a40")
	var anel := MeshInstance3D.new()
	anel.name = "Pedras"
	anel.mesh = Voxel.malha(pedras, 1.0 / 16.0)
	add_child(anel)
	_lenha = MeshInstance3D.new()
	_lenha.name = "Lenha"
	add_child(_lenha)
	_montar_lenha()

	var corpo := StaticBody3D.new()
	corpo.name = "Corpo"
	corpo.collision_layer = 4
	corpo.collision_mask = 0
	var forma := CylinderShape3D.new()
	forma.radius = 0.45
	forma.height = 0.35
	var colisao := CollisionShape3D.new()
	colisao.shape = forma
	colisao.position.y = 0.175
	corpo.add_child(colisao)
	add_child(corpo)

	if acesa:
		_atualizar_fogo()


## Um graveto por unidade trazida, em cone (como uma fogueira de acampamento).
func _montar_lenha() -> void:
	if _lenha == null:
		return
	var voxels := {}
	var quantos := maxi(gravetos, 0)
	# Montada à espera de fogo sem pedir gravetos: já vem com a lenha.
	if acende_com_fogo and gravetos_para_acender == 0:
		quantos = maxi(quantos, 4)
	var madeira := [Color("7a5230"), Color("6b4428"), Color("8a6038")]
	for i in mini(quantos, 10):
		var angulo := i * TAU / maxf(mini(quantos, 10), 1) + 0.4
		var base := Vector2(cos(angulo), sin(angulo)) * 4.5
		for passo in 9:
			var t := passo / 8.0
			var p := base.lerp(Vector2.ZERO, t * 0.85)
			voxels[Vector3i(roundi(p.x), 1 + passo, roundi(p.y))] = madeira[(i + passo) % 3]
	_lenha.mesh = Voxel.malha(voxels, 1.0 / 16.0) if not voxels.is_empty() else null


## Chamas (três labaredas voxel), luz laranja, faíscas e fumaça — do tamanho do fogo.
func _atualizar_fogo() -> void:
	if _chamas.is_empty():
		for i in 3:
			var chama := MeshInstance3D.new()
			chama.name = "Chama%d" % i
			chama.mesh = _malha_chama(i)
			chama.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var angulo := i * TAU / 3.0
			chama.position = Vector3(cos(angulo), 0.0, sin(angulo)) * 0.08 + Vector3.UP * 0.1
			add_child(chama)
			_chamas.append(chama)
		_luz = OmniLight3D.new()
		_luz.name = "Luz"
		_luz.light_color = Color(1.0, 0.62, 0.3)
		_luz.position = Vector3.UP * 0.7
		_luz.shadow_enabled = false
		add_child(_luz)
		_faiscas = _particulas(Color("ffb347"), 14, 1.2, 0.035, Vector3(0, 1.2, 0))
		_faiscas.name = "Faiscas"
		add_child(_faiscas)
		_fumaca = _particulas(Color(0.55, 0.55, 0.58, 0.55), 10, 3.0, 0.14, Vector3(0.15, 0.35, 0))
		_fumaca.name = "Fumaca"
		_fumaca.position.y = 0.8
		add_child(_fumaca)
	_luz.omni_range = raio + 2.0
	var tamanho := _tamanho_do_fogo()
	for chama in _chamas:
		chama.scale = Vector3.ONE * tamanho
	_faiscas.emission_sphere_radius = 0.2 * tamanho


func _particulas(cor: Color, quantidade: int, vida: float, tamanho: float, gravidade: Vector3) -> CPUParticles3D:
	var particulas := CPUParticles3D.new()
	var cubo := BoxMesh.new()
	cubo.size = Vector3.ONE * tamanho
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = cor
	if cor.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cubo.material = material
	particulas.mesh = cubo
	particulas.amount = quantidade
	particulas.lifetime = vida
	particulas.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particulas.emission_sphere_radius = 0.2
	particulas.direction = Vector3.UP
	particulas.spread = 20.0
	particulas.gravity = gravidade
	particulas.initial_velocity_min = 0.3
	particulas.initial_velocity_max = 0.8
	particulas.scale_amount_min = 0.6
	particulas.scale_amount_max = 1.4
	particulas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particulas.position.y = 0.3
	return particulas


## Labareda: base laranja, meio amarelo, ponta clarinha; cada uma um pouco diferente.
static func _malha_chama(variante: int) -> ArrayMesh:
	var voxels := {}
	var altura := 9 + variante * 2
	for y in altura:
		var t := float(y) / altura
		var raio_chama := (1.0 - t) * 2.6 + 0.4
		var cor := Color("ff7a1a").lerp(Color("ffd23f"), t * 1.4).lerp(Color("fff3b0"), maxf(t - 0.6, 0.0) * 2.0)
		var r := ceili(raio_chama)
		for x in range(-r, r + 1):
			for z in range(-r, r + 1):
				if x * x + z * z <= raio_chama * raio_chama:
					voxels[Vector3i(x, y, z)] = cor
	var malha := Voxel.malha(voxels, 1.0 / 16.0)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	malha.surface_set_material(0, material)
	return malha

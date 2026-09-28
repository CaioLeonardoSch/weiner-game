@tool
class_name TroncoRolante
extends ObjetoFase
## Tronco deitado de `comprimento` células: esta e as seguintes no +X local (gire de 90 em 90 graus).
##
## No chão:
## - empurrado **de lado**, rola uma célula; empurrado **ao comprido**, desliza uma célula;
## - **mordendo a ponta** (segurar F de frente para uma das pontas, sem graveto): andando para o
##   lado, o tronco gira 90° em volta da outra ponta, como uma porta; andando para trás, o
##   cachorro puxa o tronco ao comprido.
## Pode ficar com uma parte para fora do chão (sobre um vão, se a maior parte estiver apoiada; sobre
## a água, basta uma ponta na margem — dá para ir deslizando o tronco rio adentro).
##
## Vira **pinguela** — passagem estreita e redonda, com equilíbrio (balança mesmo sem graveto) —
## quando as duas pontas se apoiam em chão e o meio fica sobre água ou um vão, ou quando afunda
## inteiro na água funda (fica rente às margens).
## Na **água rasa** ele boia (também dá para andar em cima); na correnteza, desce o rio uma célula
## por vez até parar num objeto (uma pedra no rio, por exemplo), encaixar entre as margens ou
## afundar na água funda. Se encalhar na margem ou a correnteza o levar para fora do mapa, ele volta
## para onde começou.

signal voltou_ao_inicio

enum Estado { TERRA, BOIANDO, PINGUELA }

@export_range(2, 5) var comprimento := 3:
	set(valor):
		comprimento = valor
		_montar()

const DURACAO := 0.45
const RAIO := 0.22
## Tempo (s) para descer uma célula na correnteza.
const TEMPO_DERIVA := 0.8
## Um tronco é redondo: balança mesmo com o cachorro sem graveto (ver Dachshund).
const INSTABILIDADE := 0.6
const MEIA_LARGURA := 0.2
## Como pinguela (entre margens ou afundado na água funda) o tronco fica meio afundado: o topo
## rente ao chão das margens.
const ALTURA_NA_AGUA := -0.14
## Boiando na água rasa (cuja superfície fica um pouco acima do chão) ele sobe um pouco, para
## aparecer; o topo da colisão fica em ALTURA_TOPO_BOIANDO.
const ALTURA_BOIANDO := -0.03
const ALTURA_TOPO_BOIANDO := 0.08

var estado := Estado.TERRA
var em_movimento := false
var _corpo: AnimatableBody3D
var _colisao: CollisionShape3D
var _visual: Node3D
var _deriva := 0.0
var _inicio: Transform3D


func nome_no_editor() -> String:
	return "Tronco (rola, gira, boia)"


func propriedades_editaveis() -> Array[StringName]:
	return [&"comprimento"]


func caixa_editor() -> AABB:
	return AABB(Vector3(-0.5, 0, -0.3), Vector3(comprimento, 0.5, 0.6))


func _ready() -> void:
	_montar()
	if Engine.is_editor_hint():
		return
	add_to_group(&"pesos")
	add_to_group(&"com_acao")
	add_to_group(&"passagens_estreitas")
	_inicio = transform
	_assentar.call_deferred()


## Na placa, só no chão (na água ou como pinguela não pesa em placa nenhuma).
func peso_na_placa() -> float:
	return 2.5 if estado == Estado.TERRA else 0.0


## Pesado: aciona até a placa de pedra.
func pesado_para_placa() -> bool:
	return estado == Estado.TERRA


## As células que o tronco ocupa (na camada do chão + 1), da ponta 0 à ponta `comprimento - 1`.
func celulas() -> Array[Vector3i]:
	var terreno := _terreno()
	var inicio := terreno.local_to_map(terreno.to_local(global_position + Vector3.UP * 0.3))
	var lista: Array[Vector3i] = []
	for i in comprimento:
		lista.append(inicio + _eixo() * i)
	return lista


func _eixo() -> Vector3i:
	var x := global_basis.x
	return Vector3i(roundi(x.x), 0, roundi(x.z))


## Centro (global, na altura do chão) de uma célula.
func _centro(celula: Vector3i) -> Vector3:
	var terreno := _terreno()
	var centro := terreno.to_global(terreno.map_to_local(celula))
	centro.y = global_position.y
	return centro


# --- Empurrar, puxar e girar -------------------------------------------------------------

## O cachorro empurrou: de lado rola, ao comprido desliza. Só no chão.
func empurrar(direcao: Vector3i) -> bool:
	if em_movimento or estado != Estado.TERRA:
		return false
	var rolar := direcao != _eixo() and direcao != -_eixo()
	return await _mover(direcao, rolar, true)


## Mordendo uma ponta e andando para trás: o tronco vem uma célula ao comprido (o cachorro recua
## junto, então o lugar dele não conta).
func puxar(direcao: Vector3i) -> bool:
	if em_movimento or estado != Estado.TERRA:
		return false
	return await _mover(direcao, false, false)


func pode_puxar(direcao: Vector3i) -> bool:
	return not em_movimento and estado == Estado.TERRA and _classificar(_deslocadas(direcao), false) in ["terra", "ponte", "funda"]


## A ponta (0 ou comprimento - 1) que o cachorro em `ponto` pode morder — perto dela, do lado de
## fora do tronco —, ou -1.
func ponta_perto(ponto: Vector3) -> int:
	if estado != Estado.TERRA:
		return -1
	var eixo := Vector3(_eixo())
	var lista := celulas()
	for indice in [0, comprimento - 1]:
		var centro := _centro(lista[indice])
		var para_fora := -eixo if indice == 0 else eixo
		var ate := ponto - centro
		ate.y = 0.0
		if ate.length() < 1.25 and ate.dot(para_fora) > 0.35:
			return indice
	return -1


## Ponto (global) da ponta, para o botão de ação.
func ponto_da_ponta(indice: int) -> Vector3:
	return _centro(celulas()[indice])


## A ponta agora, no meio de um giro (não arredonda para a grade).
func ponto_da_ponta_agora(indice: int) -> Vector3:
	return to_global(Vector3(0.0 if indice == 0 else comprimento - 1.0, 0.0, 0.0))


## Onde fica quem segura a ponta com a boca: uma célula depois dela, para fora do tronco.
func onde_segurar(indice: int) -> Vector3:
	return to_global(Vector3(-1.0 if indice == 0 else float(comprimento), 0.0, 0.0))


## Gira 90° em volta da ponta oposta à mordida, levando a ponta mordida para o lado `lado` (uma
## direção da grade, perpendicular ao tronco). Precisa de espaço livre no caminho do giro.
## Devolve onde o cachorro fica depois (na frente da nova ponta), ou null se não dá.
func girar(ponta: int, lado: Vector3i) -> Variant:
	if em_movimento or estado != Estado.TERRA or ponta < 0:
		return null
	var lista := celulas()
	var pivo_indice := 0 if ponta == comprimento - 1 else comprimento - 1
	var pivo := lista[pivo_indice]
	var ida := (lista[ponta] - pivo) / (comprimento - 1)
	if lado == ida or lado == -ida or lado == Vector3i.ZERO:
		return null
	var n := comprimento - 1
	# Novas células e o arco varrido (um quarto de círculo) precisam estar livres.
	var novas: Array[Vector3i] = [pivo]
	for i in range(1, n + 1):
		novas.append(pivo + lado * i)
	if _classificar(novas, true) != "terra":
		return null
	for a in range(1, n + 1):
		for b in range(1, n + 1):
			if a * a + b * b <= n * n + 1 and not _celula_livre(pivo + ida * a + lado * b, true):
				return null
	var destino_cachorro := _centro(pivo + lado * (n + 1))
	if not _celula_livre(pivo + lado * (n + 1), true) or not _tem_chao(pivo + lado * (n + 1)):
		return null
	_girar_em_volta(_centro(pivo), Vector3(ida), Vector3(lado))
	return destino_cachorro


func _girar_em_volta(pivo: Vector3, de: Vector3, para: Vector3) -> void:
	em_movimento = true
	var angulo := de.signed_angle_to(para, Vector3.UP)
	var antes := global_transform
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_method(func(a: float) -> void:
		var giro := Transform3D(Basis(Vector3.UP, a), pivo) * Transform3D(Basis.IDENTITY, -pivo)
		global_transform = giro * antes, 0.0, angulo, DURACAO * 1.3).set_trans(Tween.TRANS_SINE)
	await tween.finished
	# Encaixa na grade (sem restos de ponto flutuante no giro).
	var base := global_basis.orthonormalized()
	var x := base.x
	global_transform = Transform3D(Basis(Vector3.UP, atan2(-roundf(x.z), roundf(x.x))), Vector3(
		floorf(global_position.x) + 0.5, global_position.y, floorf(global_position.z) + 0.5))
	em_movimento = false


# --- Movimento na grade --------------------------------------------------------------------

func _deslocadas(direcao: Vector3i) -> Array[Vector3i]:
	var lista: Array[Vector3i] = []
	for celula in celulas():
		lista.append(celula + direcao)
	return lista


## O que acontece com o tronco nessas células:
## "terra" — no chão (ou com parte para fora: a maior parte apoiada, ou uma ponta ainda na margem
##   e o resto sobre a água);
## "ponte" — as duas pontas no chão e o meio sobre água ou vão: vira pinguela;
## "agua" — inteiro na água, com alguma rasa: boia;
## "funda" — inteiro na água funda: afunda e vira pinguela;
## "" — não dá (algo no caminho, pouco apoio).
func _classificar(lista: Array[Vector3i], contar_cachorro: bool) -> String:
	var tipos: Array[String] = []
	for celula in lista:
		if not _celula_livre(celula, contar_cachorro):
			return ""
		tipos.append(_tipo_do_chao(celula))
	var em_terra := tipos.count("chao")
	if em_terra == tipos.size():
		return "terra"
	if tipos[0] == "chao" and tipos[-1] == "chao" and em_terra == 2:
		return "ponte"
	if em_terra == 0 and not tipos.has("vazio"):
		return "agua" if tipos.has("rasa") else "funda"
	if em_terra * 2 > tipos.size():
		return "terra"
	# Entrando na água de ponta (deslizado ao comprido): a ponta de trás ainda apoiada.
	if em_terra >= 1 and (tipos[0] == "chao" or tipos[-1] == "chao") and not tipos.has("vazio"):
		return "terra"
	return ""


## "chao", "rasa", "funda" ou "vazio" (sem nada embaixo) na camada abaixo da célula.
func _tipo_do_chao(celula: Vector3i) -> String:
	var chao := _terreno().get_cell_item(celula + Vector3i.DOWN)
	if chao == GridMap.INVALID_CELL_ITEM:
		return "vazio"
	if Tiles.eh_agua(chao):
		return "funda"
	if Tiles.definicao(chao).get("rasa", false):
		return "rasa"
	return "chao"


func _tem_chao(celula: Vector3i) -> bool:
	return _tipo_do_chao(celula) == "chao"


## Sem bloco do terreno na célula e sem objeto sólido (nem o cachorro, se `contar_cachorro`).
func _celula_livre(celula: Vector3i, contar_cachorro: bool) -> bool:
	if _terreno().get_cell_item(celula) != GridMap.INVALID_CELL_ITEM:
		return false
	return not _ocupado(_centro(celula), contar_cachorro)


func _mover(direcao: Vector3i, rolar: bool, contar_cachorro: bool) -> bool:
	var destino := _classificar(_deslocadas(direcao), contar_cachorro)
	if destino.is_empty():
		return false
	em_movimento = true
	var alvo := global_position + Vector3(direcao)
	var duracao := DURACAO if contar_cachorro or estado == Estado.TERRA else TEMPO_DERIVA * 0.8
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, "global_position", alvo, duracao).set_trans(Tween.TRANS_SINE)
	if rolar:
		# Gira em volta do próprio eixo o quanto andou (1 m / raio).
		var giro := Vector3(direcao).cross(Vector3.UP).normalized() * (-1.0 / RAIO)
		var local := global_basis.inverse() * giro
		tween.parallel().tween_property(_visual, "rotation", _visual.rotation + local, DURACAO)
	await tween.finished
	_entrar(destino)
	em_movimento = false
	return true


func _entrar(destino: String) -> void:
	match destino:
		"agua":
			estado = Estado.BOIANDO
		"ponte", "funda":
			estado = Estado.PINGUELA
		_:
			estado = Estado.TERRA
	_ajustar_corpo(true)


## No começo da fase: já na água ou entre margens?
func _assentar() -> void:
	var destino := _classificar(celulas(), false)
	_entrar(destino if not destino.is_empty() else "terra")


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or estado != Estado.BOIANDO or em_movimento:
		return
	_deriva += delta
	if _deriva < TEMPO_DERIVA:
		return
	_deriva = 0.0
	var sentido := _sentido_da_correnteza()
	if sentido == Vector3i.ZERO:
		return
	var destino := _classificar(_deslocadas(sentido), false)
	if destino in ["agua", "ponte", "funda"]:
		_mover(sentido, false, false)
	elif _sai_do_mapa(sentido) or not _algum_objeto_no_caminho(sentido):
		# Levado para fora do mapa ou encalhado na margem: volta para onde começou.
		_voltar_ao_inicio()
	# Senão parou num objeto (uma pedra no rio): fica ali, boiando.


## Algum objeto (uma pedra, outro tronco) segura o tronco nessa direção?
func _algum_objeto_no_caminho(sentido: Vector3i) -> bool:
	for celula in _deslocadas(sentido):
		if _terreno().get_cell_item(celula) == GridMap.INVALID_CELL_ITEM and _ocupado(_centro(celula), false):
			return true
	return false


## A correnteza levaria alguma parte para onde não há terreno nenhum (fora do mapa)?
func _sai_do_mapa(sentido: Vector3i) -> bool:
	for celula in _deslocadas(sentido):
		if _tipo_do_chao(celula) == "vazio":
			return true
	return false


## Sentido da correnteza embaixo do tronco (Vector3i.ZERO se não houver).
func _sentido_da_correnteza() -> Vector3i:
	var terreno := _terreno()
	for celula in celulas():
		var chao := celula + Vector3i.DOWN
		if Tiles.definicao(terreno.get_cell_item(chao)).get("correnteza", 0.0) > 0.0:
			var sentido := terreno.global_basis * terreno.get_cell_item_basis(chao).x
			return Vector3i(roundi(sentido.x), 0, roundi(sentido.z))
	return Vector3i.ZERO


## Levado para longe: some e volta para onde começou (dá para tentar de novo sem reiniciar).
func _voltar_ao_inicio() -> void:
	# Some achatando (só o visual: o corpo de física não aceita escala) e reaparece.
	em_movimento = true
	var tween := create_tween()
	tween.tween_property(_visual, "scale", Vector3(1.0, 0.05, 1.0), 0.25)
	await tween.finished
	transform = _inicio
	_assentar()
	var volta := create_tween()
	volta.tween_property(_visual, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	await volta.finished
	em_movimento = false
	voltou_ao_inicio.emit()


## Algum objeto (ou o cachorro) no lugar?
func _ocupado(alvo: Vector3, contar_cachorro: bool) -> bool:
	var forma := BoxShape3D.new()
	forma.size = Vector3(0.8, 0.6, 0.8)
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma
	consulta.transform = Transform3D(Basis.IDENTITY, alvo + Vector3.UP * 0.4)
	consulta.collision_mask = 2 | 4 | (8 if contar_cachorro else 0)
	consulta.exclude = [_corpo.get_rid()]
	return not get_world_3d().direct_space_state.intersect_shape(consulta, 1).is_empty()


func _terreno() -> GridMap:
	return fase_do_objeto().terreno


# --- Pinguela ------------------------------------------------------------------------------

## Passagem estreita (Fase.passagem_estreita_em) na água ou entre margens: redonda, instável.
func passagem_em(posicao: Vector3) -> Dictionary:
	if estado == Estado.TERRA:
		return {}
	var local := to_local(posicao)
	if local.x < -0.5 or local.x > comprimento - 0.5 or absf(local.z) > 0.6 or local.y < -0.4 or local.y > 0.9:
		return {}
	# Nas pontas apoiadas na margem (ou ao lado do tronco, em terra firme) é chão comum.
	var terreno := _terreno()
	if _tipo_do_chao(terreno.local_to_map(terreno.to_local(posicao + Vector3.UP * 0.3))) == "chao":
		return {}
	var lado := global_basis.z
	lado.y = 0.0
	return {desvio = local.z, lado = lado.normalized(), meia_largura = MEIA_LARGURA, instabilidade = INSTABILIDADE}


# --- Botão de ação (morder a ponta) --------------------------------------------------------

func acao_da_boca(cachorro: Dachshund) -> String:
	if cachorro.tem_graveto or ponta_perto(cachorro.global_position) < 0:
		return ""
	return "segurar: morder a ponta (de lado gira, para trás puxa)"


func ponto_da_acao(cachorro: Dachshund) -> Vector3:
	var ponta := ponta_perto(cachorro.global_position)
	return ponto_da_ponta(ponta) if ponta >= 0 else global_position


# --- Visual e corpo -------------------------------------------------------------------------

## Casca marrom com anéis nas pontas; corpo que carrega quem está em cima (AnimatableBody).
func _montar() -> void:
	if not is_node_ready():
		return
	for filho in get_children():
		remove_child(filho)
		filho.queue_free()
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	var voxels := {}
	var casca := [Color("6b4428"), Color("5b3920"), Color("7a4f2e")]
	var fim := 16 * comprimento - 8
	for x in range(-8, fim):
		for y in range(-4, 4):
			for z in range(-4, 4):
				var r := Vector2(y + 0.5, z + 0.5).length()
				if r > 3.6:
					continue
				var ponta := x == -8 or x == fim - 1
				if ponta:
					voxels[Vector3i(x, y, z)] = Color("c9a36a") if int(r) % 2 == 0 else Color("a8844f")
				else:
					voxels[Vector3i(x, y, z)] = casca[posmod(x * 7 + y * 3 + z, 3)]
	var malha := MeshInstance3D.new()
	malha.mesh = Voxel.malha(voxels, 1.0 / 16.0)
	_visual.add_child(malha)

	_corpo = AnimatableBody3D.new()
	_corpo.name = "Corpo"
	_corpo.collision_layer = 4
	_corpo.collision_mask = 0
	# Movido junto com o nó (tween no passo da física): sem sync_to_physics, que ignoraria o pai.
	_corpo.sync_to_physics = false
	add_child(_corpo)
	_colisao = CollisionShape3D.new()
	_corpo.add_child(_colisao)
	_ajustar_corpo(false)


## No chão: cilindro deitado (bloqueia e dá para empurrar). Na água ou entre margens: meio afundado,
## com o topo rente ao chão, e uma colisão estreita e reta por cima (a pinguela).
func _ajustar_corpo(animar: bool) -> void:
	if _visual == null:
		return
	var meio := (comprimento - 1) * 0.5
	var na_agua := estado != Estado.TERRA
	var altura := RAIO
	if estado == Estado.BOIANDO:
		altura = ALTURA_BOIANDO
	elif estado == Estado.PINGUELA:
		altura = ALTURA_NA_AGUA
	var topo := ALTURA_TOPO_BOIANDO if estado == Estado.BOIANDO else 0.0
	if animar:
		var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		tween.tween_property(_visual, "position:y", altura, 0.3).set_trans(Tween.TRANS_BACK)
	else:
		_visual.position.y = altura
	if na_agua:
		var forma := BoxShape3D.new()
		forma.size = Vector3(comprimento, 0.2, MEIA_LARGURA * 2.0)
		_colisao.shape = forma
		_colisao.rotation = Vector3.ZERO
		_colisao.position = Vector3(meio, topo - 0.1, 0)
	else:
		var forma := CylinderShape3D.new()
		forma.radius = RAIO
		forma.height = comprimento
		_colisao.shape = forma
		_colisao.rotation = Vector3(0, 0, PI * 0.5)
		_colisao.position = Vector3(meio, RAIO, 0)

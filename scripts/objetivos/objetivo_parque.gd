class_name ObjetivoParque
extends Objetivo
## A área central do parque (o "lobby" do capítulo, ver docs/DESIGN.md): não termina. O dia começa
## com o dono chegando pela saída com o cachorro na guia, tirando a guia e sentando no banco; aí
## o cachorro brinca à vontade (rolar na grama, buscar a bolinha que o dono joga) e entra na
## região do dia (EntradaDia) para jogar a fase dele. Concluída a fase, o jogo volta para cá no
## fim do dia: o cachorro chega ao dono, ele põe a guia e os dois vão embora — e começa o dia
## seguinte.
## O dia é o número de dias (EntradaDia com fase) já concluídos + 1: as regiões se abrem pelo
## número de gravetos lendários encontrados.
## Animações e falas provisórias (deslizar, um balão), até a arte do parque.

enum Momento { CHEGANDO, BRINCANDO, ENTRANDO, INDO_EMBORA }

## Frase do dono ao soltar o cachorro, se a entrada do dia não tiver uma.
const FRASE_PADRAO := "Vai lá, garotão, pode brincar"
## m/s do dono andando (e do cachorro do lado dele).
const VELOCIDADE_ANDANDO := 1.3
## Até onde (m, na frente do banco) o cachorro trota quando o dono solta a guia.
const TROTE_SOLTO := 4.5
## Distância (m) da bolinha jogada, a partir do banco, e o espalhamento (rad) para os lados.
const ARREMESSO_MINIMO := 7.0
const ARREMESSO_MAXIMO := 12.0
const ARREMESSO_ABERTURA := 0.9
## Na volta de um dia, de quão longe (m) do dono o cachorro aparece.
const ULTIMOS_PASSOS := 3.0

var momento := Momento.CHEGANDO
var cachorro: Dachshund
var dono: Dono
var banco: Banco
var saida: SaidaParque
var bolinha: Bolinha
var entradas: Array[EntradaDia] = []
## O dia de hoje (1 a 10).
var dia := 1
var guia: Guia
var _fases: Node
var _jogando_bolinha := false
var _rng := RandomNumberGenerator.new()


func faltando(fase: Fase) -> PackedStringArray:
	var lista: PackedStringArray = []
	_falta(fase, InicioCachorro, "o Início do cachorro", lista)
	_falta(fase, Dono, "o Dono", lista)
	_falta(fase, Banco, "o Banco", lista)
	_falta(fase, SaidaParque, "a Saída do parque", lista)
	return lista


func avisos(fase: Fase) -> PackedStringArray:
	var lista: PackedStringArray = []
	var todas := fase.todos(EntradaDia)
	if todas.is_empty():
		lista.append("Nenhuma Entrada do dia: o cachorro não tem para onde ir.")
	var dias := {}
	var sem_fase: PackedStringArray = []
	for objeto in todas:
		var entrada := objeto as EntradaDia
		if dias.has(entrada.dia):
			lista.append("Há mais de uma Entrada do dia %d." % entrada.dia)
		dias[entrada.dia] = true
		if entrada.caminho_fase.is_empty():
			sem_fase.append(str(entrada.dia))
	if not sem_fase.is_empty():
		lista.append("Dias ainda sem fase (ficam fechados): %s." % ", ".join(sem_fase))
	return lista


## "Dia N" no começo do dia; nada no fim dele.
func titulo(_fase: Fase) -> String:
	return "" if momento == Momento.INDO_EMBORA else "Dia %d" % dia


func preparar(novo_jogo: Node) -> void:
	super(novo_jogo)
	# Do sorteio global: a rota de teste fixa a semente e o arremesso sai sempre igual.
	_rng.seed = randi()
	_fases = jogo.get_node_or_null(^"/root/Fases")
	cachorro = jogo.cachorro
	cachorro.pode_brincar = true
	dono = jogo.dono
	banco = jogo.fase.primeiro(Banco) as Banco
	saida = jogo.fase.primeiro(SaidaParque) as SaidaParque
	bolinha = jogo.fase.primeiro(Bolinha) as Bolinha
	for objeto in jogo.fase.todos(EntradaDia):
		entradas.append(objeto as EntradaDia)
	dia = dia_atual()
	for entrada in entradas:
		entrada.aberta = aberta(entrada)
		entrada.cachorro_entrou.connect(_entrar)
	guia = Guia.new()
	guia.name = "Guia"
	guia.de = dono.ponto_da_guia
	guia.ate = cachorro.voxel.ponto_da_coleira
	jogo.add_child(guia)
	var voltando_de := ""
	if _fases and not _fases.parque_voltando_de.is_empty():
		voltando_de = _fases.parque_voltando_de
		_fases.parque_voltando_de = ""
	if _fases and _fases.testando:
		# Testando no editor: direto para a brincadeira, sem a chegada.
		_sentar_no_banco()
		guia.hide()
		momento = Momento.BRINCANDO
	elif not voltando_de.is_empty():
		momento = Momento.INDO_EMBORA
		_fim_do_dia(voltando_de)
	else:
		_comeco_do_dia()


## Quantos dias (com fase) já foram concluídos, + 1 (até o último dia que existe).
func dia_atual() -> int:
	var concluidos := 0
	var ultimo := 1
	for entrada in entradas:
		ultimo = maxi(ultimo, entrada.dia)
		if _fases and not entrada.caminho_fase.is_empty() and _fases.concluida(entrada.caminho_fase):
			concluidos += 1
	return mini(concluidos + 1, ultimo)


## A entrada se abre quando o dia dela chegou (e se ela já tem fase).
func aberta(entrada: EntradaDia) -> bool:
	return entrada.dia <= dia and not entrada.caminho_fase.is_empty()


func processar(_delta: float) -> void:
	if momento != Momento.BRINCANDO or bolinha == null or _jogando_bolinha:
		return
	# Trouxe a bolinha ao dono: ele joga longe.
	if cachorro.brinquedo == bolinha and dono.sentado and dono.contem(cachorro):
		_jogar_bolinha()


# --- O dia ---------------------------------------------------------------------------------

## O dono chega com o cachorro na guia, tira a guia, diz a frase do dia e senta no banco.
func _comeco_do_dia() -> void:
	momento = Momento.CHEGANDO
	cachorro.entrada_bloqueada = true
	await jogo.escurecer(true, 0.0)
	var fora := saida.ponto_de_fora()
	var lugar := banco.lugar_em_pe()
	dono.sentado = false
	dono.global_position = fora
	dono.olhar_para(lugar)
	cachorro.posicionar(_ao_lado_do_dono(fora), _yaw_cachorro(lugar - fora))
	jogo.camera_controller.comecar_em_3d(_yaw_camera())
	jogo.escurecer(false, 0.8)
	await _andar_juntos(lugar)
	if momento != Momento.CHEGANDO:
		return
	dono.olhar_para(cachorro.global_position)
	await _esperar(0.4)
	guia.hide()
	jogo.mostrar_balao(_frase_do_dia(), 2.6, dono, 2.1)
	await _esperar(1.2)
	_sentar_no_banco()
	# Solto, o cachorro trota para a área central (para onde o banco olha): a câmera atrás dele
	# fica na frente do banco, não atrás do encosto.
	var solto := banco.to_global(Vector3(banco.to_local(cachorro.global_position).x, 0.0, TROTE_SOLTO))
	await cachorro.atravessar(PackedVector3Array([solto]), 1.0, _yaw_cachorro(banco.global_basis.z))
	cachorro.terminar_travessia()
	if momento != Momento.CHEGANDO:
		return
	jogo.camera_controller.comecar_em_3d(_yaw_camera())
	cachorro.entrada_bloqueada = false
	momento = Momento.BRINCANDO
	jogo.atualizar_dica()


## Volta de uma fase concluída: o cachorro aparece já perto do banco, vindo da região do dia, e
## chega ao dono, que levanta, põe a guia, e os dois vão embora pela saída. Aí começa o dia
## seguinte.
func _fim_do_dia(caminho: String) -> void:
	cachorro.entrada_bloqueada = true
	await jogo.escurecer(true, 0.0)
	_sentar_no_banco()
	var de_onde := saida.ponto_de_fora()
	for entrada in entradas:
		if entrada.caminho_fase == caminho:
			de_onde = entrada.to_global(Vector3(0.0, 0.0, 2.0))
	var chegada := banco.to_global(Vector3(0.0, 0.0, 1.4))
	# O resto do caminho o fade cortou: só os últimos passos.
	var vindo := chegada - de_onde
	vindo.y = 0.0
	de_onde = chegada - vindo.normalized() * minf(vindo.length(), ULTIMOS_PASSOS)
	cachorro.posicionar(de_onde, _yaw_cachorro(chegada - de_onde))
	jogo.camera_controller.comecar_em_3d(_yaw_camera())
	jogo.escurecer(false, 0.8)
	await cachorro.atravessar(PackedVector3Array([chegada]),
		de_onde.distance_to(chegada) / (cachorro.velocidade * 0.8), _yaw_cachorro(chegada - de_onde))
	cachorro.terminar_travessia()
	dono.sentado = false
	dono.global_position = banco.lugar_em_pe()
	dono.olhar_para(cachorro.global_position)
	await _esperar(0.5)
	guia.show()
	await _esperar(0.6)
	var fora := saida.ponto_de_fora()
	dono.olhar_para(fora)
	await _andar_juntos(fora)
	await jogo.escurecer(true, 0.8)
	if _fases:
		_fases.jogar_parque()


## O dono anda até `destino` e o cachorro vai do lado dele (sem colisão, como numa travessia).
func _andar_juntos(destino: Vector3) -> void:
	var duracao := dono.global_position.distance_to(destino) / VELOCIDADE_ANDANDO
	dono.olhar_para(destino)
	var tween: Tween = jogo.create_tween()
	tween.tween_property(dono, "global_position", destino, duracao)
	var lado := _ao_lado_do_dono(destino)
	await cachorro.atravessar(PackedVector3Array([lado]), duracao,
		_yaw_cachorro(destino - dono.global_position))
	cachorro.terminar_travessia()


## Entrou numa região aberta: anda mais um pouco para dentro, a tela escurece e começa a fase.
func _entrar(entrada: EntradaDia) -> void:
	if momento != Momento.BRINCANDO or not aberta(entrada):
		return
	momento = Momento.ENTRANDO
	cachorro.entrada_bloqueada = true
	if cachorro.brinquedo:
		var solta := cachorro.largar_brinquedo()
		if solta is Bolinha:
			(solta as Bolinha).soltar(cachorro.global_position)
	var dentro := entrada.to_global(Vector3(0.0, 0.0, 3.0))
	jogo.escurecer(true, 0.7)
	await cachorro.atravessar(PackedVector3Array([dentro]), 0.8,
		_yaw_cachorro(dentro - cachorro.global_position))
	await _esperar(0.1)
	if _fases:
		_fases.jogar_dia(entrada.caminho_fase)


# --- A bolinha -----------------------------------------------------------------------------

## O dono pega a bolinha da boca do cachorro e joga longe, para a frente do banco.
func _jogar_bolinha() -> void:
	_jogando_bolinha = true
	cachorro.largar_brinquedo()
	bolinha.segurar(dono.ponto_da_guia())
	await _esperar(0.6)
	if momento == Momento.BRINCANDO:
		await bolinha.jogar(_ponto_para_jogar())
	else:
		bolinha.soltar(banco.lugar_em_pe())
	_jogando_bolinha = false


## Um ponto de chão aberto na frente do banco (a área central), sorteado.
func _ponto_para_jogar() -> Vector3:
	var espaco: PhysicsDirectSpaceState3D = cachorro.get_world_3d().direct_space_state
	var frente := banco.global_basis.z
	var base := banco.global_position
	for tentativa in 12:
		var direcao := frente.rotated(Vector3.UP, _rng.randf_range(-ARREMESSO_ABERTURA, ARREMESSO_ABERTURA))
		var ponto := base + direcao * _rng.randf_range(ARREMESSO_MINIMO, ARREMESSO_MAXIMO)
		var raio := PhysicsRayQueryParameters3D.create(ponto + Vector3.UP * 4.0, ponto + Vector3.DOWN * 2.0, 1 | 2 | 4)
		var chao := espaco.intersect_ray(raio)
		# Só no chão da área central (não em cima do mato, de um tronco ou de uma árvore).
		if not chao.is_empty() and chao.collider is GridMap and absf(chao.position.y - base.y) < 0.2:
			return chao.position
	return base + frente * ARREMESSO_MINIMO


# --- Ajudantes -----------------------------------------------------------------------------

func _sentar_no_banco() -> void:
	dono.sentado = true
	dono.global_position = banco.global_position
	dono.global_rotation.y = banco.global_rotation.y


func _frase_do_dia() -> String:
	for entrada in entradas:
		if entrada.dia == dia and not entrada.frase_do_dono.is_empty():
			return entrada.frase_do_dono
	return FRASE_PADRAO


## Onde o cachorro anda, do lado da mão da guia (o -X do dono), com o dono em `ponto`.
func _ao_lado_do_dono(ponto: Vector3) -> Vector3:
	var mao := dono.global_basis.x * -1.0
	return ponto + Vector3(mao.x, 0.0, mao.z).normalized() * 0.9


## Yaw (rad) do cachorro olhando na `direcao` (o modelo do cachorro olha para +X).
static func _yaw_cachorro(direcao: Vector3) -> float:
	return atan2(-direcao.z, direcao.x)


## Yaw (graus) da câmera atrás do cachorro, olhando para onde ele olha.
func _yaw_camera() -> float:
	return rad_to_deg(cachorro.modelo.rotation.y) - 90.0


## Espera `segundos` num tween do jogo (morre junto se a cena trocar).
func _esperar(segundos: float) -> Signal:
	var tween: Tween = jogo.create_tween()
	tween.tween_interval(segundos)
	return tween.finished

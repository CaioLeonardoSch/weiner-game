extends SceneTree
## Gera a área central do parque (scenes/parque/area_central.tscn): uma clareira oval cercada de
## mato, com as 10 entradas dos dias em volta, a saída embaixo (+Z), o banco do dono perto dela,
## a bolinha, dois passeantes e árvores do lado de fora.
##   godot --headless --path . --script res://ferramentas/gerar_parque.gd
## Sobrescreve a cena: mudanças feitas no editor se perdem.
## Provisório até a arte do parque: o formato e as fases dos dias (1 a 3 usam fases da esteira de
## teste; 4 a 10 ainda não têm fase e ficam fechados).

const OBJ := "res://scenes/objetos/%s.tscn"
const ARQUIVO := "res://scenes/parque/area_central.tscn"
## Semieixos da clareira (m) e a espessura do mato em volta (em fração do raio).
const RX := 13.0
const RZ := 10.0
const MATO_ATE := 1.22
## As fases dos dias, por enquanto.
const FASES_DOS_DIAS := {
	1: "res://scenes/fases/floresta_01_andar.tscn",
	2: "res://scenes/fases/floresta_03_pular.tscn",
	3: "res://scenes/fases/floresta_04_rampas.tscn",
}
const LARGURA_ENTRADA := 3.0
## Comprimento (m) do corredor de cada entrada, além da clareira.
const CORREDOR := 5.5

var fase: Fase
var t: GridMap
var rng := RandomNumberGenerator.new()
var ocupado := {}


func _initialize() -> void:
	rng.seed = 2026
	fase = Fase.nova("O Parque")
	fase.id = "parque_area_central"
	fase.name = "AreaCentral"
	fase.objetivo = Fase.OBJETIVO_PARQUE
	fase.terceira_pessoa = true
	fase.habilidades = Fase.HABILIDADE_LATIR
	fase.raca = &"salsicha"
	fase.raca_fixa = true
	fase.regiao = &"floresta"
	t = fase.get_node("Terreno")
	_chao()
	var entradas := _entradas()
	_mato(entradas)
	_saida()
	_objetos()
	_arvores()
	DirAccess.make_dir_recursive_absolute(ARQUIVO.get_base_dir())
	var cena := PackedScene.new()
	var erro := cena.pack(fase)
	if erro == OK:
		erro = ResourceSaver.save(cena, ARQUIVO)
	print(ARQUIVO, ": ", error_string(erro))
	fase.free()
	quit()


func obj(nome: String, pos: Vector3, yaw := 0.0) -> ObjetoFase:
	return fase.adicionar_objeto(load(OBJ % nome), pos, yaw)


## Distância "oval" do centro: 1 na borda da clareira.
static func _oval(x: float, z: float) -> float:
	return sqrt(pow(x / RX, 2.0) + pow(z / RZ, 2.0))


func _chao() -> void:
	for x in range(-34, 34):
		for z in range(-30, 26):
			t.set_cell_item(Vector3i(x, -1, z), Tiles.GRAMA)


## As 10 entradas na borda da clareira, do sudoeste, passando pelo norte, até o sudeste. O +Z de
## cada uma aponta para fora.
func _entradas() -> Array[Transform3D]:
	var lista: Array[Transform3D] = []
	for i in 10:
		var angulo := deg_to_rad(-144.0 + 32.0 * i)
		var ponto := Vector3(RX * sin(angulo), 0.0, -RZ * cos(angulo))
		var normal := Vector3(ponto.x / (RX * RX), 0.0, ponto.z / (RZ * RZ)).normalized()
		var yaw := atan2(normal.x, normal.z)
		lista.append(Transform3D(Basis(Vector3.UP, yaw), ponto))
		var entrada := obj("entrada_dia", ponto, yaw) as EntradaDia
		entrada.dia = i + 1
		entrada.largura = LARGURA_ENTRADA
		entrada.caminho_fase = FASES_DOS_DIAS.get(i + 1, "")
		# O fundo do corredor: ninguém passa (a fase do dia começa antes).
		var parede := obj("parede_invisivel", ponto + normal * CORREDOR, yaw) as ParedeInvisivel
		parede.tamanho = Vector3(LARGURA_ENTRADA + 1.0, 3.0, 0.6)
	return lista


## O anel de mato em volta da clareira, com as passagens das entradas (e as paredes dos
## corredores, de mato, até o fundo).
func _mato(entradas: Array[Transform3D]) -> void:
	for x in range(-34, 34):
		for z in range(-30, 26):
			var centro := Vector3(x + 0.5, 0.0, z + 0.5)
			var oval := _oval(centro.x, centro.z)
			if oval < 1.35:
				ocupado[Vector2i(x, z)] = true
			var mato := oval >= 1.0 and oval < MATO_ATE
			for entrada in entradas:
				var local := entrada.affine_inverse() * centro
				if local.z > -1.0 and local.z < CORREDOR + 0.5:
					if absf(local.x) < LARGURA_ENTRADA * 0.5 + 0.2:
						mato = false
						ocupado[Vector2i(x, z)] = true
					elif absf(local.x) < LARGURA_ENTRADA * 0.5 + 1.2 and local.z > 0.0:
						mato = true
						ocupado[Vector2i(x, z)] = true
			# A passagem da saída, embaixo.
			if absf(centro.x) < 1.5 and centro.z > 0.0:
				mato = false
			if mato:
				t.set_cell_item(Vector3i(x, 0, z), Tiles.MATO)


## A saída embaixo (+Z) e o caminho de fora, por onde o dono chega e vai embora.
func _saida() -> void:
	obj("saida_parque", Vector3(0.0, 0.0, RZ + 0.5))
	for z in range(int(RZ), int(RZ) + 8):
		for x in [-2, 1]:
			t.set_cell_item(Vector3i(x, 0, z), Tiles.MATO)
		for x in range(-4, 4):
			ocupado[Vector2i(x, z)] = true


func _objetos() -> void:
	# O banco perto da saída, olhando para o meio da clareira (-Z); o dono sentado nele.
	var banco_pos := Vector3(-3.5, 0.0, 7.5)
	obj("banco", banco_pos, PI)
	var dono := obj("dono", banco_pos, PI) as Dono
	dono.sentado = true
	obj("inicio_cachorro", Vector3(-3.5, 0.0, 5.5), PI * 0.5)
	obj("bolinha", Vector3(-1.8, 0.0, 4.2))
	var passeante := obj("passeante", Vector3(0.0, 0.0, -1.0)) as Passeante
	passeante.raca = &"pug"
	passeante.raio = 5.5
	var outro := obj("passeante", Vector3(1.0, 0.0, -1.0)) as Passeante
	outro.raca = &"border_collie"
	outro.raio = 8.0
	outro.velocidade = 1.1
	outro.sentido_horario = true
	for i in 9:
		var angulo := rng.randf_range(-PI, PI)
		var raio := rng.randf_range(0.55, 0.92)
		var ponto := Vector3(sin(angulo) * RX * raio, 0.0, -cos(angulo) * RZ * raio)
		if ponto.distance_to(banco_pos) < 2.5:
			continue
		var flores := obj("flores", ponto, rng.randf_range(-PI, PI)) as Flores
		flores.variante = rng.randi_range(0, 7)


func _arvores() -> void:
	for tentativa in 2600:
		var x := rng.randi_range(-33, 32)
		var z := rng.randi_range(-29, 24)
		if ocupado.has(Vector2i(x, z)):
			continue
		var arvore := obj("arvore", Vector3(x + rng.randf_range(0.2, 0.8), 0, z + rng.randf_range(0.2, 0.8))) as Arvore
		var sorteio := rng.randf()
		arvore.tipo = Voxel.TipoArvore.PINHEIRO if sorteio < 0.35 else (Voxel.TipoArvore.REDONDA if sorteio < 0.85 else Voxel.TipoArvore.ARBUSTO)
		arvore.ao_colocar_no_editor(rng)
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				ocupado[Vector2i(x + dx, z + dz)] = true

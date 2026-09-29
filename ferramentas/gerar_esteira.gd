extends SceneTree
## Gera a esteira de fases de teste (uma mecânica por fase), em scenes/fases/.
##   godot --headless --path . --script res://ferramentas/gerar_esteira.gd [-- nome ...]
## Sem nomes, refaz todas. Sobrescreve as cenas: mudanças feitas no editor se perdem.

const OBJ := "res://scenes/objetos/%s.tscn"
const PASTA := "res://scenes/fases/"

var fase: Fase
var t: GridMap
var rng := RandomNumberGenerator.new()
var ocupado := {}
var _arquivo := ""


func caixa(tile: int, x0: int, x1: int, y0: int, y1: int, z0: int, z1: int) -> void:
	for x in range(x0, x1):
		for y in range(y0, y1):
			for z in range(z0, z1):
				t.set_cell_item(Vector3i(x, y, z), tile)


func obj(nome: String, pos: Vector3, yaw := 0.0) -> ObjetoFase:
	ocupado[Vector2i(floori(pos.x), floori(pos.z))] = true
	return fase.adicionar_objeto(load(OBJ % nome), pos, yaw)


func dica(pos: Vector3, tamanho: Vector3, texto: String) -> void:
	var zona := obj("zona_dica", pos) as ZonaDica
	zona.tamanho = tamanho
	zona.texto = texto


## A dica do começo (em volta do Início).
func dica_inicial(texto: String) -> void:
	dica(Vector3(-1.5, 0, -3.5), Vector3(2.4, 1.5, 3.0), texto)


func graveto(pos: Vector3, lendario := true, comprimento := 0.8, peso := 1.0, yaw := deg_to_rad(20)) -> Graveto:
	var g := obj("graveto" if lendario else "graveto_comum", pos, yaw) as Graveto
	g.position.y = pos.y
	g.comprimento = comprimento
	g.peso = peso
	return g


func girado(tile: int, celula: Vector3i, sentido: Vector3) -> void:
	# Gira o tile para o +X dele apontar para 'sentido'.
	t.set_cell_item(celula, tile, t.get_orthogonal_index_from_basis(Basis(Vector3.UP, atan2(-sentido.z, sentido.x))))


## Trilha padrão: gramado, cercas vivas em volta (x -5 e `comprimento`, z -7), mato baixo e
## parede invisível na frente (z 0). O caminho livre é x -4..comprimento-1, z -6..-1.
func base(arquivo: String, nome: String, comprimento: int, habilidades := 0) -> void:
	_arquivo = arquivo
	rng.seed = hash(arquivo)
	ocupado.clear()
	fase = Fase.nova(nome)
	fase.id = arquivo
	fase.name = arquivo.to_pascal_case()
	fase.habilidades = habilidades
	t = fase.get_node("Terreno")
	caixa(Tiles.GRAMA, -18, comprimento + 12, -1, 0, -14, 8)
	caixa(Tiles.MATO, -5, comprimento + 1, 0, 1, -7, -6)
	caixa(Tiles.MATO, -5, -4, 0, 1, -6, 0)
	caixa(Tiles.MATO, comprimento, comprimento + 1, 0, 1, -6, 0)
	caixa(Tiles.MATO_BAIXO, -5, comprimento + 1, 0, 1, 0, 1)
	for x in range(-6, comprimento + 2):
		for z in range(-8, 2):
			ocupado[Vector2i(x, z)] = true
	var parede := obj("parede_invisivel", Vector3(comprimento * 0.5 - 2.0, 0, 0.5)) as ParedeInvisivel
	parede.tamanho = Vector3(comprimento + 7.0, 4.0, 1.0)
	obj("inicio_cachorro", Vector3(-1.5, 0, -2.5))
	obj("dono", Vector3(-3.3, 0, -3.3), deg_to_rad(-60))


func dono() -> Dono:
	for filho in fase.get_node("Objetos").get_children():
		if filho is Dono:
			return filho
	return null


func neve(arquivo: String, nome: String, comprimento: int, habilidades := 0) -> void:
	base(arquivo, nome, comprimento, habilidades)
	fase.regiao = &"neve"
	fase.bioma = Biomas.NEVE


func floresta_em_volta(comprimento: int) -> void:
	for p in [Vector3(-3.2, 0, -5.6), Vector3(-2.3, 0, -0.5)]:
		obj("flores", p, rng.randf_range(-PI, PI)).set("variante", rng.randi_range(0, 7))
	for tentativa in 1400:
		var x := rng.randi_range(-17, comprimento + 11)
		var z := rng.randi_range(-13, 7)
		if ocupado.has(Vector2i(x, z)):
			continue
		var arvore := obj("arvore", Vector3(x + rng.randf_range(0.2, 0.8), 0, z + rng.randf_range(0.2, 0.8))) as Arvore
		var sorteio := rng.randf()
		arvore.tipo = Voxel.TipoArvore.PINHEIRO if sorteio < 0.4 else (Voxel.TipoArvore.REDONDA if sorteio < 0.88 else Voxel.TipoArvore.ARBUSTO)
		arvore.ao_colocar_no_editor(rng)
		if z >= 1 and x >= -7 and x <= comprimento + 2:
			arvore.visibilidade = ObjetoFase.Visibilidade.SO_3D
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				ocupado[Vector2i(x + dx, z + dz)] = true


func salvar(comprimento: int) -> void:
	floresta_em_volta(comprimento)
	var cena := PackedScene.new()
	var erro := cena.pack(fase)
	if erro == OK:
		erro = ResourceSaver.save(cena, PASTA + _arquivo + ".tscn")
	print(_arquivo, ": ", error_string(erro), " — ", fase.nome)
	fase.free()


## Um muro (cerca viva) atravessando a trilha em x, com vãos nas fileiras `vaos`.
func muro(x: int, vaos := [], altura := 1, tile := Tiles.MATO) -> void:
	for z in range(-6, 0):
		if z not in vaos:
			for y in altura:
				t.set_cell_item(Vector3i(x, y, z), tile)


func muro_com_portao(x: int, canal: int) -> Portao:
	muro(x, [-3])
	var portao := obj("portao", Vector3(x + 0.5, 0, -2.5), PI * 0.5) as Portao
	portao.canal = canal
	return portao


## Um riacho (tile `tile`, na camada do chão) de x0 a x1 (inclusive), a trilha toda.
func riacho(x0: int, x1: int, tile := Tiles.AGUA) -> void:
	for x in range(x0, x1 + 1):
		for z in range(-6, 0):
			t.set_cell_item(Vector3i(x, -1, z), tile)


func _initialize() -> void:
	var pedidas := OS.get_cmdline_user_args()
	for metodo in get_script().get_script_method_list():
		var nome: String = metodo.name
		if (nome.begins_with("floresta_") or nome.begins_with("neve_")) and nome != "floresta_em_volta":
			if pedidas.is_empty() or nome in pedidas:
				call(nome)
	quit()


# === Floresta ==================================================================================

func floresta_01_andar() -> void:
	base("floresta_01_andar", "F01 — Andar e pegar", 12)
	dica_inicial("Ande até o graveto dourado, pegue e traga ao dono.")
	graveto(Vector3(8.5, 0.08, -3.5))
	salvar(12)


## Barranco de mão única (ida pela rampa, 1 m para descer) e a trilha escondida por folhagem que
## só existe na visão isométrica — na volta (3D) ela some. Mirante antes do barranco.
func floresta_02_perspectiva() -> void:
	base("floresta_02_perspectiva", "F02 — A outra perspectiva", 16)
	caixa(Tiles.TERRA, 7, 9, 0, 1, -6, 0)
	caixa(Tiles.GRAMA, 7, 9, 0, 1, -3, -2)
	t.set_cell_item(Vector3i(7, 0, -3), -1)
	t.set_cell_item(Vector3i(8, 0, -3), -1)
	for z in [-6, -5]:
		t.set_cell_item(Vector3i(5, 0, z), Tiles.RAMPA_BAIXA)
		t.set_cell_item(Vector3i(6, 0, z), Tiles.RAMPA_ALTA)
	obj("tampa_folhagem", Vector3(6.5, 0, -2.5))
	obj("tampa_folhagem", Vector3(9.5, 0, -2.5))
	obj("mirante", Vector3(3.5, 0, -1.5))
	dica_inicial("Na ida a câmera é isométrica; com o graveto na boca, vira 3D e a fase muda.")
	dica(Vector3(3.5, 0, -2.5), Vector3(2.0, 1.5, 3.0), "Mirante: {acao} mostra como a fase fica na volta.")
	graveto(Vector3(12.5, 0.08, -3.5))
	salvar(16)


func floresta_03_pular() -> void:
	base("floresta_03_pular", "F03 — Pular", 14, Fase.HABILIDADE_PULAR)
	caixa(Tiles.MEIO_BLOCO, 5, 6, 0, 1, -6, 0)
	caixa(Tiles.TERRA, 6, 8, 0, 1, -6, 0)
	caixa(Tiles.MEIO_BLOCO, 8, 9, 0, 1, -6, 0)
	dica_inicial("{pular} pula: primeiro o meio bloco, depois o bloco inteiro.")
	graveto(Vector3(10.5, 0.08, -3.5))
	salvar(14)


func floresta_04_rampas() -> void:
	base("floresta_04_rampas", "F04 — Rampas e escadas", 16)
	caixa(Tiles.TERRA, 6, 12, 0, 1, -6, 0)
	for z in [-6, -5, -4]:
		t.set_cell_item(Vector3i(4, 0, z), Tiles.RAMPA_BAIXA)
		t.set_cell_item(Vector3i(5, 0, z), Tiles.RAMPA_ALTA)
	for z in [-3, -2, -1]:
		girado(Tiles.ESCADA_ALTA, Vector3i(12, 0, z), Vector3.LEFT)
		girado(Tiles.ESCADA_BAIXA, Vector3i(13, 0, z), Vector3.LEFT)
	dica_inicial("Sem pular: suba pela rampa, desça pela escada — e volte.")
	graveto(Vector3(14.5, 0.08, -2.5))
	salvar(16)


func floresta_05_degrau_alto() -> void:
	base("floresta_05_degrau_alto", "F05 — Degrau alto", 14, Fase.HABILIDADE_PULAR)
	caixa(Tiles.DEGRAU_ALTO, 6, 10, 0, 1, -6, 0)
	dica_inicial("Degrau alto: só pulando ({pular}). Com graveto na boca, o pulo não chega.")
	graveto(Vector3(8.5, 0.8, -3.5))
	salvar(14)


## Rampa lisa: o graveto pesado (1,6) escorrega nela; a escada do lado leste é a saída.
func floresta_06_rampa_lisa() -> void:
	base("floresta_06_rampa_lisa", "F06 — Rampa lisa", 16)
	caixa(Tiles.TERRA, 7, 11, 0, 1, -6, 0)
	for z in range(-6, 0):
		t.set_cell_item(Vector3i(5, 0, z), Tiles.RAMPA_LISA_BAIXA)
		t.set_cell_item(Vector3i(6, 0, z), Tiles.RAMPA_LISA_ALTA)
	for z in [-6, -5, -4]:
		girado(Tiles.RAMPA_LISA_ALTA, Vector3i(11, 0, z), Vector3.LEFT)
		girado(Tiles.RAMPA_LISA_BAIXA, Vector3i(12, 0, z), Vector3.LEFT)
	for z in [-3, -2, -1]:
		girado(Tiles.ESCADA_ALTA, Vector3i(11, 0, z), Vector3.LEFT)
		girado(Tiles.ESCADA_BAIXA, Vector3i(12, 0, z), Vector3.LEFT)
	dica_inicial("Rampa lisa: com um graveto pesado na boca, o cachorro escorrega nela.")
	graveto(Vector3(14.5, 0.08, -4.5), true, 1.0, 1.6)
	salvar(16)


func floresta_07_ponte() -> void:
	base("floresta_07_ponte", "F07 — A ponte", 14)
	riacho(6, 7)
	var ponte := obj("ponte", Vector3(7.0, 0, -3.5)) as Ponte
	ponte.tamanho = Vector3(2.0, 0.12, 1.4)
	dica_inicial("Água funda não dá pé: atravesse pela ponte.")
	graveto(Vector3(10.5, 0.08, -3.5))
	salvar(14)


## Tábua (ida) e tronco caído como pinguela (volta): passagens estreitas. O graveto comprido
## (1,4) faz balançar — devagar e ao comprido.
func floresta_08_tabua_e_pinguela() -> void:
	base("floresta_08_tabua_e_pinguela", "F08 — Tábua e pinguela", 16)
	riacho(7, 7)
	t.set_cell_item(Vector3i(7, 0, -5), Tiles.TABUA)
	(obj("tronco_caido", Vector3(7.5, 0, -2.5)) as TroncoCaido).pinguela = true
	dica_inicial("Tábua e pinguela são estreitas: com carga, o cachorro balança.")
	dica(Vector3(10.5, 0, -3.5), Vector3(2.0, 1.5, 5.6),
		"Graveto comprido: devagar ({andar_devagar}) e ao comprido ({virar_graveto}) balança menos.")
	graveto(Vector3(12.5, 0.08, -3.5), true, 1.4, 1.0)
	salvar(16)


## Correnteza (leva para a água funda ao norte) e o vau de água rasa ao sul.
func floresta_09_correnteza() -> void:
	base("floresta_09_correnteza", "F09 — Correnteza e vau", 16)
	for x in [6, 7]:
		t.set_cell_item(Vector3i(x, -1, -6), Tiles.AGUA)
		for z in [-5, -4, -3]:
			girado(Tiles.CORRENTEZA, Vector3i(x, -1, z), Vector3.FORWARD)
		for z in [-2, -1]:
			t.set_cell_item(Vector3i(x, -1, z), Tiles.AGUA_RASA)
	dica_inicial("A correnteza leva quem entra. A água rasa (vau) dá pé.")
	graveto(Vector3(11.5, 0.08, -3.5))
	salvar(16)


## Monte de terra fofa (cavar através) e terra fofa no chão (vira buraco).
func floresta_10_cavar() -> void:
	base("floresta_10_cavar", "F10 — Cavar", 14, Fase.HABILIDADE_CAVAR)
	muro(7, [], 1, Tiles.TERRA_FOFA)
	caixa(Tiles.TERRA_FOFA, 2, 4, -1, 0, -6, -4)
	dica_inicial("Terra fofa: de frente para ela, {cavar} cava. No chão, vira um buraco.")
	graveto(Vector3(10.5, 0.08, -3.5))
	salvar(14)


func floresta_11_cerca() -> void:
	base("floresta_11_cerca", "F11 — Debaixo da cerca", 14, Fase.HABILIDADE_CAVAR)
	var cerca := obj("cerca", Vector3(6.5, 0, -3.0), PI * 0.5) as Cerca
	cerca.comprimento = 6
	cerca.terra_fofa = true
	dica_inicial("A cerca tem terra fofa embaixo: de frente para ela, {cavar} abre um vão.")
	dica(Vector3(9.5, 0, -3.5), Vector3(2.0, 1.5, 5.6), "Graveto comprido: pelo vão, só ao comprido ({virar_graveto}).")
	graveto(Vector3(11.5, 0.08, -3.5), true, 1.3)
	salvar(14)


func floresta_12_enterrado() -> void:
	base("floresta_12_enterrado", "F12 — Graveto enterrado", 12, Fase.HABILIDADE_CAVAR)
	dica_inicial("Um montinho de terra... tem algo enterrado. {cavar} de frente para ele.")
	graveto(Vector3(8.5, 0.08, -3.5)).enterrado = true
	salvar(12)


func floresta_13_empurrar() -> void:
	base("floresta_13_empurrar", "F13 — Empurrar o bloco", 14)
	riacho(8, 8)
	obj("bloco_empurravel", Vector3(5.5, 0, -3.5))
	dica_inicial("Empurre o bloco de pedra para dentro do riacho: ele afunda e vira passagem.")
	graveto(Vector3(11.5, 0.08, -3.5))
	salvar(14)


## O bloco está num canto (cerca viva a leste): só puxando (segure {acao} e ande para trás).
func floresta_14_puxar() -> void:
	base("floresta_14_puxar", "F14 — Puxar o bloco", 16)
	riacho(10, 10)
	caixa(Tiles.MATO, 7, 8, 0, 1, -6, -4)
	obj("bloco_empurravel", Vector3(6.5, 0, -5.5))
	dica_inicial("O bloco está preso no canto: segure {acao} de frente para ele e ande para trás.")
	graveto(Vector3(13.5, 0.08, -3.5))
	salvar(16)


func floresta_15_placa_madeira() -> void:
	base("floresta_15_placa_madeira", "F15 — Placa de madeira", 16)
	muro_com_portao(9, 0)
	(obj("placa", Vector3(6.5, 0, -5.5)) as Placa).canal = 0
	graveto(Vector3(3.5, 0.08, -5.5), false, 0.8, 1.0, deg_to_rad(90))
	dica_inicial("A placa de madeira abre o portão da mesma cor enquanto tiver algo em cima.")
	dica(Vector3(6.5, 0, -4.5), Vector3(2.0, 1.5, 3.0), "Largue ({largar_graveto}) o graveto comum em cima da placa.")
	graveto(Vector3(13.5, 0.08, -3.5))
	salvar(16)


func floresta_16_placa_pedra() -> void:
	base("floresta_16_placa_pedra", "F16 — Placa de pedra", 16)
	muro_com_portao(10, 2)
	var placa := obj("placa", Vector3(7.5, 0, -5.5)) as Placa
	placa.canal = 2
	placa.tipo = Placa.PEDRA
	obj("bloco_empurravel", Vector3(5.5, 0, -5.5))
	dica_inicial("Placa de pedra: só algo pesado aciona — o cachorro não.")
	graveto(Vector3(13.5, 0.08, -3.5))
	salvar(16)


func floresta_17_regra_e() -> void:
	base("floresta_17_regra_e", "F17 — Duas placas (regra E)", 16)
	var portao := muro_com_portao(10, 1)
	portao.regra = Portao.REGRA_TODAS
	for z in [-5.5, -1.5]:
		(obj("placa", Vector3(6.5, 0, z)) as Placa).canal = 1
	obj("bloco_empurravel", Vector3(4.5, 0, -1.5))
	graveto(Vector3(3.5, 0.08, -5.5), false, 0.8, 1.0, deg_to_rad(90))
	dica_inicial("Regra E: o portão só abre com as duas placas acionadas (veja as lampadinhas).")
	graveto(Vector3(13.5, 0.08, -3.5))
	salvar(16)


func floresta_18_atraso() -> void:
	base("floresta_18_atraso", "F18 — Portão com atraso", 16)
	var portao := muro_com_portao(9, 5)
	portao.atraso = 3.0
	(obj("placa", Vector3(5.5, 0, -5.5)) as Placa).canal = 5
	(obj("placa", Vector3(12.5, 0, -5.5)) as Placa).canal = 5
	dica_inicial("Portão com atraso: pise na placa e corra — ele fica aberto uns segundos.")
	graveto(Vector3(13.5, 0.08, -2.5))
	salvar(16)


func floresta_19_alavanca() -> void:
	base("floresta_19_alavanca", "F19 — Alavanca", 16)
	muro_com_portao(9, 4)
	(obj("alavanca", Vector3(6.5, 0, -5.5)) as Alavanca).canal = 4
	dica_inicial("Alavanca: {acao} vira para o outro lado — e fica.")
	graveto(Vector3(13.5, 0.08, -3.5))
	salvar(16)


## Pegar o graveto derruba a ponte (Gatilho); a volta é empurrando o bloco no riacho.
func floresta_20_ponte_que_cai() -> void:
	base("floresta_20_ponte_que_cai", "F20 — A ponte que cai", 18)
	riacho(8, 8)
	var ponte := obj("ponte", Vector3(8.5, 0, -4.5)) as Ponte
	ponte.tamanho = Vector3(1.0, 0.12, 1.4)
	ponte.tipo = Ponte.Tipo.GATILHO
	ponte.canal = 4
	ponte.aviso_ao_quebrar = "A ponte caiu! Empurre a pedra para dentro do riacho."
	obj("bloco_empurravel", Vector3(10.5, 0, -2.5))
	var gatilho := obj("gatilho", Vector3(14.5, 0, -3.5)) as Gatilho
	gatilho.tamanho = Vector3(1.6, 1.5, 1.6)
	gatilho.quando = 2
	gatilho.canal = 4
	dica_inicial("Gatilho: pegar o graveto derruba a ponte.")
	graveto(Vector3(14.5, 0.08, -3.5))
	salvar(18)


func floresta_21_ponte_que_cede() -> void:
	base("floresta_21_ponte_que_cede", "F21 — A ponte que cede", 14)
	riacho(7, 8)
	var ponte := obj("ponte", Vector3(8.0, 0, -3.5)) as Ponte
	ponte.tamanho = Vector3(2.0, 0.12, 1.4)
	ponte.tipo = Ponte.Tipo.CEDE
	ponte.tempo_para_ceder = 1.2
	dica_inicial("Ponte velha: não pare em cima dela!")
	graveto(Vector3(11.5, 0.08, -3.5))
	salvar(14)


## A alavanca liga a comporta: a água funda do trecho baixa e vira rasa.
func floresta_22_comporta() -> void:
	base("floresta_22_comporta", "F22 — Comporta", 16)
	riacho(7, 9)
	caixa(Tiles.AGUA, 7, 10, -1, 0, -8, -6)
	caixa(Tiles.GRAMA, 7, 10, 0, 1, -7, -6)
	for x in range(7, 10):
		t.set_cell_item(Vector3i(x, 0, -7), -1)
	var parede := obj("parede_invisivel", Vector3(8.5, 0, -7.5)) as ParedeInvisivel
	parede.tamanho = Vector3(3.0, 4.0, 1.0)
	var comporta := obj("comporta", Vector3(8.5, 0, -6.5)) as Comporta
	comporta.canal = 3
	comporta.largura = 3
	comporta.comprimento = 6
	(obj("alavanca", Vector3(5.5, 0, -5.5)) as Alavanca).canal = 3
	dica_inicial("A alavanca abre a comporta: a água funda baixa e dá pé.")
	graveto(Vector3(13.5, 0.08, -3.5))
	salvar(16)


func floresta_23_toca() -> void:
	base("floresta_23_toca", "F23 — Toca de texugo", 16)
	muro(8, [], 2)
	(obj("toca", Vector3(6.0, 0, -3.5), -PI * 0.5) as Toca).canal = 5
	(obj("toca", Vector3(11.0, 0, -3.5), PI * 0.5) as Toca).canal = 5
	dica_inicial("A toca leva à outra da mesma cor, por baixo da terra.")
	dica(Vector3(12.5, 0, -3.5), Vector3(2.0, 1.5, 5.6), "Com o graveto, só ao comprido ({virar_graveto}).")
	graveto(Vector3(13.5, 0.08, -3.5), true, 1.2)
	salvar(16)


func floresta_24_portinhola() -> void:
	base("floresta_24_portinhola", "F24 — Portinhola", 16)
	muro(8, [-3], 2)
	obj("portinhola", Vector3(8.5, 0, -2.5), PI * 0.5)
	dica_inicial("Portinhola: o cachorro passa; o graveto, só ao comprido ({virar_graveto}).")
	graveto(Vector3(12.5, 0.08, -3.5), true, 1.2)
	salvar(16)


func floresta_25_passarinho() -> void:
	base("floresta_25_passarinho", "F25 — Passarinhos", 16, Fase.HABILIDADE_LATIR)
	muro(9, [-3])
	(obj("passaro", Vector3(9.5, 0, -2.5)) as Passaro).bloqueia_passagem = true
	graveto(Vector3(13.5, 0.08, -3.5))
	obj("passaro", Vector3(13.5, 0.12, -3.5), PI)
	dica_inicial("Passarinho no caminho? Um latido ({latir}) e ele voa.")
	salvar(16)


## Um passarinho pousado na placa segura o portão (invertido) fechado; latiu, ele voa por 5 s.
func floresta_26_contrapeso() -> void:
	base("floresta_26_contrapeso", "F26 — O passarinho na placa", 16, Fase.HABILIDADE_LATIR)
	var portao := muro_com_portao(10, 6)
	portao.inverter = true
	(obj("placa", Vector3(9.5, 0, -5.5)) as Placa).canal = 6
	(obj("passaro", Vector3(9.5, 0.1, -5.5), PI * 0.5) as Passaro).volta_depois = 5.0
	dica_inicial("O passarinho na placa segura o portão fechado. Late ({latir}) e corra!")
	dica(Vector3(12.5, 0, -3.5), Vector3(2.0, 1.5, 5.6), "Com o graveto não dá para latir: largue ({largar_graveto}) antes.")
	graveto(Vector3(13.5, 0.08, -3.5))
	salvar(16)


func floresta_27_esquilo() -> void:
	base("floresta_27_esquilo", "F27 — O esquilo", 18, Fase.HABILIDADE_LATIR)
	var esquilo := obj("esquilo", Vector3(13.5, 0, -5.0)) as Esquilo
	graveto(esquilo.position + Vector3(0.6, 0.08, 0.0), true, 0.8, 1.0, deg_to_rad(80))
	dica_inicial("O esquilo guarda o graveto na porta da toca. Um latido ({latir}) assusta — mas ele volta.")
	salvar(18)


## O passarinho só da volta (3D) fecha o vão, onde não dá para largar o graveto; o cão vizinho
## late de ciúme quando o cachorro passa com o graveto, e o latido dele espanta o passarinho.
func floresta_28_vizinho() -> void:
	base("floresta_28_vizinho", "F28 — O cão vizinho", 16, Fase.HABILIDADE_LATIR)
	muro(8, [-3])
	var passaro := obj("passaro", Vector3(8.5, 0, -2.5), PI) as Passaro
	passaro.bloqueia_passagem = true
	passaro.visibilidade = ObjetoFase.Visibilidade.SO_3D
	(obj("zona_sem_largar", Vector3(8.5, 0, -2.5)) as ZonaSemLargar).tamanho = Vector3(6.0, 1.2, 6.0)
	(obj("cerca", Vector3(10.5, 0, -4.5)) as Cerca).comprimento = 3
	obj("cao_vizinho", Vector3(10.5, 0, -5.5), deg_to_rad(-90)).set("raca", &"border_collie")
	dica_inicial("O cão vizinho late de ciúme de quem passa com um graveto.")
	graveto(Vector3(13.5, 0.08, -2.5))
	salvar(16)


func floresta_29_dono_dormindo() -> void:
	base("floresta_29_dono_dormindo", "F29 — O dono cochilou", 12, Fase.HABILIDADE_LATIR)
	dono().dormindo = true
	dica_inicial("O dono cochilou! Largue o graveto ({largar_graveto}), late ({latir}) e entregue.")
	graveto(Vector3(8.5, 0.08, -3.5))
	salvar(12)


## Tronco: empurrado de lado rola; ao comprido desliza — até atravessar o riacho (pinguela).
func floresta_30_tronco_rola() -> void:
	base("floresta_30_tronco_rola", "F30 — O tronco rola", 18)
	riacho(11, 11)
	obj("tronco_rolante", Vector3(6.5, 0, -3.5))
	dica_inicial("O tronco: de lado ele rola, ao comprido desliza. Atravessado no riacho, vira pinguela.")
	graveto(Vector3(15.5, 0.08, -2.5))
	salvar(18)


## Tronco ao longo do riacho: mordendo a ponta ({acao}) e andando de lado, gira 90°.
func floresta_31_tronco_gira() -> void:
	base("floresta_31_tronco_gira", "F31 — Girar o tronco", 18)
	riacho(11, 11)
	obj("tronco_rolante", Vector3(8.5, 0, -5.5), -PI * 0.5)
	dica_inicial("Mordendo a ponta do tronco ({acao}) e andando de lado, ele gira.")
	graveto(Vector3(15.5, 0.08, -3.5))
	salvar(18)


## Como a antiga Fase 11: empurrado ao comprido, o tronco cai na correnteza larga (rasa), boia e
## desce o rio até onde ele fica fundo: afunda atravessado e vira pinguela. A pé não dá: a
## correnteza leva o cachorro para a água funda.
func floresta_32_tronco_no_rio() -> void:
	base("floresta_32_tronco_no_rio", "F32 — O tronco no rio", 16)
	for z in range(-6, 0):
		for x in range(6, 9):
			if z <= -3:
				girado(Tiles.CORRENTEZA, Vector3i(x, -1, z), Vector3.BACK)
			else:
				t.set_cell_item(Vector3i(x, -1, z), Tiles.AGUA)
	# A margem de lá, ao lado da correnteza, é mato: só se chega pela água funda.
	caixa(Tiles.MATO, 9, 10, 0, 1, -6, -2)
	obj("tronco_rolante", Vector3(3.5, 0, -5.5))
	dica_inicial("Empurre o tronco ao comprido para a correnteza: ele boia e desce o rio...")
	graveto(Vector3(12.5, 0.08, -3.5))
	salvar(16)


func floresta_33_chuva() -> void:
	base("floresta_33_chuva", "F33 — Dia de tempestade", 14)
	fase.clima = 5
	caixa(Tiles.GRAMA_COM_POCAS, 1, 5, -1, 0, -6, 0)
	caixa(Tiles.LAMA, 6, 9, -1, 0, -6, 0)
	dica_inicial("Tempestade: chuva, vento, raios. Poças e lama no caminho.")
	graveto(Vector3(11.5, 0.08, -3.5))
	salvar(14)


# === Neve ======================================================================================

func neve_01_neve_fofa() -> void:
	neve("neve_01_neve_fofa", "N01 — Neve fofa", 14)
	caixa(Tiles.NEVE_FOFA, 3, 10, -1, 0, -6, 0)
	dica_inicial("Neve fofa: o cachorro anda devagar, demora a arrancar e a parar.")
	graveto(Vector3(11.5, 0.08, -3.5))
	salvar(14)


func neve_02_gelo() -> void:
	neve("neve_02_gelo", "N02 — Gelo", 16)
	caixa(Tiles.GELO, 4, 11, -1, 0, -6, 0)
	dica_inicial("Gelo: solte a tecla e o cachorro continua deslizando.")
	graveto(Vector3(13.5, 0.08, -3.5))
	salvar(16)


## Gelo liso: desliza em linha reta até bater. Entrando na fileira z = -3, para na pedra; dali
## para o sul (até o mato baixo) e para o leste, saindo do gelo.
func neve_03_gelo_liso() -> void:
	neve("neve_03_gelo_liso", "N03 — Gelo liso", 16)
	caixa(Tiles.GELO_LISO, 3, 11, -1, 0, -6, 0)
	t.set_cell_item(Vector3i(8, 0, -3), Tiles.PEDRA)
	t.set_cell_item(Vector3i(5, 0, -6), Tiles.PEDRA)
	dica_inicial("Gelo liso: pisou, desliza em linha reta até bater em algo.")
	graveto(Vector3(13.5, 0.08, -1.5))
	salvar(16)


func neve_04_monte_de_neve() -> void:
	neve("neve_04_monte_de_neve", "N04 — Monte de neve", 14, Fase.HABILIDADE_CAVAR)
	muro(7, [], 1, Tiles.MONTE_DE_NEVE)
	dica_inicial("Monte de neve: {cavar} cava através dele.")
	graveto(Vector3(10.5, 0.08, -3.5))
	salvar(14)


func neve_05_frio_e_fogueira() -> void:
	neve("neve_05_frio_e_fogueira", "N05 — Frio e fogueira", 20)
	fase.frio = true
	fase.tempo_de_frio = 30.0
	(obj("fogueira", Vector3(8.5, 0, -3.5)) as Fogueira).gravetos_para_acender = 2
	graveto(Vector3(4.5, 0.08, -5.5), false, 0.8, 1.0, deg_to_rad(90))
	graveto(Vector3(5.5, 0.08, -1.5), false, 0.8, 1.0, deg_to_rad(90))
	dica_inicial("Frio: longe do fogo o calor cai. Traga 2 gravetos comuns para a fogueira ({acao}).")
	graveto(Vector3(17.5, 0.08, -3.5))
	salvar(20)


## A fogueira acesa derrete o monte de neve que fecha a trilha.
func neve_06_fogo_derrete() -> void:
	neve("neve_06_fogo_derrete", "N06 — O fogo derrete", 16)
	var fogueira := obj("fogueira", Vector3(6.5, 0, -3.5)) as Fogueira
	fogueira.gravetos_para_acender = 1
	muro(8, [], 1, Tiles.MONTE_DE_NEVE)
	graveto(Vector3(3.5, 0.08, -5.5), false, 0.8, 1.0, deg_to_rad(90))
	dica_inicial("Sem cavar: acenda a fogueira e o monte de neve derrete.")
	graveto(Vector3(11.5, 0.08, -3.5))
	salvar(16)


## Graveto aceso: encoste a ponta do graveto comum na fogueira acesa e leve o fogo à outra
## (que só acende com fogo); ela abre o portão.
func neve_07_graveto_aceso() -> void:
	neve("neve_07_graveto_aceso", "N07 — Graveto aceso", 18)
	var acesa := obj("fogueira", Vector3(4.5, 0, -5.5)) as Fogueira
	acesa.gravetos_para_acender = 0
	# Outro canal: toda fogueira acesa aciona o seu (esta não pode abrir o portão).
	acesa.canal = 1
	var apagada := obj("fogueira", Vector3(9.5, 0, -5.5)) as Fogueira
	apagada.gravetos_para_acender = 0
	apagada.acende_com_fogo = true
	apagada.canal = 0
	muro_com_portao(12, 0)
	graveto(Vector3(2.5, 0.08, -2.5), false, 1.0, 1.0, deg_to_rad(90))
	dica_inicial("Encoste a ponta do graveto comum na fogueira acesa e leve o fogo à outra.")
	graveto(Vector3(15.5, 0.08, -3.5))
	salvar(18)


## Vento forte soprando contra a ida (para -X), em rajadas; pedras servem de abrigo.
func neve_08_vento() -> void:
	neve("neve_08_vento", "N08 — Vento forte", 18)
	var vento := obj("vento", Vector3(15.5, 0, -3.5), -PI * 0.5) as Vento
	vento.largura = 6
	vento.comprimento = 14
	vento.forca = 0.8
	vento.forca_rajada = 5.0
	vento.intervalo = 4.0
	vento.duracao_rajada = 1.6
	for celula in [Vector3i(11, 0, -5), Vector3i(8, 0, -2), Vector3i(5, 0, -5)]:
		t.set_cell_item(celula, Tiles.PEDRA)
	dica_inicial("Vento forte: nas rajadas, abrigue-se atrás das pedras.")
	graveto(Vector3(14.5, 0.08, -3.5))
	salvar(18)


func neve_09_pastoreio() -> void:
	neve("neve_09_pastoreio", "N09 — O rebanho", 20, Fase.HABILIDADE_LATIR)
	fase.objetivo = Fase.OBJETIVO_PASTOREIO
	fase.raca = &"border_collie"
	fase.raca_fixa = true
	# O cercado fecha o fim da trilha de lado a lado: não sobra canto atrás dele para uma ovelha
	# se enfiar (o cachorro não teria como ficar atrás dela).
	(obj("cercado", Vector3(18.5, 0, -3.0), PI) as Cercado).tamanho = Vector2i(3, 6)
	for p in [Vector3(4.5, 0, -5.0), Vector3(6.0, 0, -3.0), Vector3(4.0, 0, -1.5)]:
		obj("ovelha", p, rng.randf_range(-PI, PI))
	dica_inicial("Leve as ovelhas ao cercado: fique atrás delas. Um latido ({latir}) espanta.")
	salvar(20)


func neve_10_celeiro() -> void:
	neve("neve_10_celeiro", "N10 — O celeiro", 20)
	fase.objetivo = Fase.OBJETIVO_PASTOREIO
	fase.raca = &"border_collie"
	fase.raca_fixa = true
	fase.frio = true
	fase.tempo_de_frio = 90.0
	obj("celeiro", Vector3(16.0, 0, -3.5), PI)
	for p in [Vector3(4.5, 0, -4.5), Vector3(6.0, 0, -2.0)]:
		obj("ovelha", p, rng.randf_range(-PI, PI))
	dica_inicial("Frio: leve as ovelhas ao celeiro — dentro é quente.")
	salvar(20)

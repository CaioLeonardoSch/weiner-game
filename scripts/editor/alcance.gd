class_name AlcanceEditor
extends RefCounted
## Validação do editor: o cachorro consegue ir do Início até o graveto e voltar com ele ao dono?
##
## Uma busca em largura sobre as colunas do mapa (sem física: no editor a fase fica parada e os
## corpos saem da simulação). Cada coluna (x, z) tem "chãos": topos de blocos ou de objetos
## sólidos com espaço livre em cima. De um chão para o da coluna vizinha:
## - descer sempre dá; subir até PASSO anda (rampa, escada); até o pulo, só com a habilidade
##   Pular (mais baixo com o graveto na boca, ver SALTO_*); do buraco se sai escalando;
## - rampas e cantos têm a altura de cada borda (a rampa sobe para +X local do tile);
## - água funda não é chão; terra fofa e monte de neve acima do chão somem com Cavar;
## - objetos com colisão (pedra, árvore, cerca, parede invisível...) viram chão onde cobrem o
##   centro da célula (a ponte, a pinguela) e barram a passagem entre duas células quando o
##   caminho cruza a colisão e ela é alta demais para pular;
## - portões e mecanismos que reagem contam como abertos: a água funda do trecho de uma comporta
##   conta como rasa se algo aciona o canal dela; o dono, o bloco e o tronco em terra
##   (que rolam) não barram — o tronco na água (boiando ou de pinguela) é chão; pássaros não barram com Latir; a cerca com terra fofa não barra com Cavar;
## - a portinhola deixa passar pelo meio (na volta, só se o graveto não for comprido demais para
##   ela; a mão única não entra);
## - as tocas da mesma cor ligam as duas entradas.
## Ida: sem graveto; volta: com o graveto.
## É uma estimativa (gelo liso, vento e correnteza não entram): o resultado é só um aviso.

## Subida (m) que o cachorro vence andando.
const PASSO := 0.12
## Maior subida pulando, sem e com o graveto na boca (medido: ~0,75 e ~0,65 m).
const SALTO_SEM_GRAVETO := 0.75
const SALTO_COM_GRAVETO := 0.65
## Do buraco (meio metro fundo) o cachorro sai escalando, sem pular.
const SAIDA_DO_BURACO := 0.55
## Espaço livre (m) que o cachorro precisa em cima do chão.
const ALTURA_CACHORRO := 0.45
## Folga (m) do corpo do cachorro nas colisões dos objetos.
const RAIO_CACHORRO := 0.12
## Até onde (m, no plano) do dono o cachorro precisa chegar para entregar.
const ALCANCE_DO_DONO := 1.6

const _RAMPAS := {
	Tiles.RAMPA_BAIXA: Vector2(0.0, 0.5), Tiles.RAMPA_ALTA: Vector2(0.5, 1.0),
	Tiles.ESCADA_BAIXA: Vector2(0.0, 0.5), Tiles.ESCADA_ALTA: Vector2(0.5, 1.0),
	Tiles.RAMPA_LISA_BAIXA: Vector2(0.0, 0.5), Tiles.RAMPA_LISA_ALTA: Vector2(0.5, 1.0),
}
const _CANTOS := {
	Tiles.CANTO_RAMPA_BAIXA: Vector2(0.0, 0.5), Tiles.CANTO_RAMPA_ALTA: Vector2(0.5, 1.0),
	Tiles.CANTO_INTERNO_BAIXA: Vector2(0.0, 0.5), Tiles.CANTO_INTERNO_ALTA: Vector2(0.5, 1.0),
}
const _TOPO := {
	Tiles.MEIO_BLOCO: 0.5, Tiles.MATO_BAIXO: 0.5, Tiles.BURACO: 0.5, Tiles.DEGRAU_ALTO: 0.72,
	Tiles.AGUA: 0.85, Tiles.TABUA: 0.0,
}
const _DIRECOES: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var fase: Fase
var com_graveto := false
## Vector2i(x, z) → Array[Dictionary] de chãos: {topo, teto, bordas: {Vector2i: Vector2}, buraco}.
var _colunas := {}
## Colisões dos objetos: [{xf: Transform3D (global → local da caixa), caixa: AABB, topo, base}].
var _caixas: Array[Dictionary] = []
## Vector2i → índices em _caixas cujas colisões passam por perto da célula.
var _caixas_por_celula := {}
## Vector3i(x, i, z) → lista de Vector3i ligados pelas tocas.
var _tocas := {}


## Avisos da validação (vazio se está tudo certo ou se a fase não é de levar o graveto).
static func avisos(fase_analisada: Fase) -> PackedStringArray:
	var resultado: PackedStringArray = []
	if fase_analisada.objetivo != Fase.OBJETIVO_GRAVETO:
		return resultado
	var inicio := fase_analisada.primeiro(InicioCachorro)
	var graveto := fase_analisada.primeiro(Graveto)
	var dono := fase_analisada.primeiro(Dono)
	if inicio == null or graveto == null or dono == null:
		return resultado
	var empurraveis := not fase_analisada.todos(Empurravel).is_empty() or not fase_analisada.todos(TroncoRolante).is_empty()
	var ressalva := " (sem contar blocos e troncos empurráveis)" if empurraveis else ""
	var ida := AlcanceEditor.new(fase_analisada, false)
	var partida: Variant = ida.chao_perto(inicio.global_position)
	if partida == null:
		return resultado
	var alcancados := ida.alcancaveis([partida])
	var no_graveto: Array[Vector3i] = ida.chaos_do_graveto(graveto.global_position).filter(
		func(chao: Vector3i) -> bool: return alcancados.has(chao))
	if no_graveto.is_empty():
		resultado.append("O graveto parece fora do alcance do cachorro a partir do Início%s." % ressalva)
		return resultado
	var volta := AlcanceEditor.new(fase_analisada, true)
	var de_volta := volta.alcancaveis(volta.chaos_do_graveto(graveto.global_position))
	if not volta.chega_perto(de_volta, dono.global_position):
		resultado.append("Com o graveto na boca, o cachorro parece não conseguir voltar até o dono%s." % ressalva)
	return resultado


func _init(fase_analisada: Fase, levando_graveto: bool) -> void:
	fase = fase_analisada
	com_graveto = levando_graveto
	_juntar_caixas()
	_montar_colunas()
	_ligar_tocas()


## Todos os chãos a que se chega a partir de `origens` (conjunto: Vector3i → true).
func alcancaveis(origens: Array) -> Dictionary:
	var visitados := {}
	var fila: Array[Vector3i] = []
	for origem: Vector3i in origens:
		if not visitados.has(origem):
			visitados[origem] = true
			fila.append(origem)
	var i := 0
	while i < fila.size():
		var atual := fila[i]
		i += 1
		for vizinho in _vizinhos(atual):
			if not visitados.has(vizinho):
				visitados[vizinho] = true
				fila.append(vizinho)
	return visitados


## O chão (Vector3i(x, índice, z)) mais perto da posição, na coluna dela, ou null.
func chao_perto(posicao: Vector3) -> Variant:
	var coluna := Vector2i(floori(posicao.x), floori(posicao.z))
	var melhor: Variant = null
	var menor := 1.5
	var chaos: Array = _colunas.get(coluna, [])
	for i in chaos.size():
		var diferenca := absf(float(chaos[i].topo) - posicao.y)
		if diferenca < menor:
			menor = diferenca
			melhor = Vector3i(coluna.x, i, coluna.y)
	return melhor


## Chãos de onde o cachorro pega o graveto: a coluna dele e as vizinhas (o graveto comprido
## ou encostado numa parede se pega de lado).
func chaos_do_graveto(posicao: Vector3) -> Array[Vector3i]:
	var lista: Array[Vector3i] = []
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			var coluna := Vector2i(floori(posicao.x) + dx, floori(posicao.z) + dz)
			var chaos: Array = _colunas.get(coluna, [])
			for i in chaos.size():
				if absf(float(chaos[i].topo) - posicao.y) <= 1.0:
					lista.append(Vector3i(coluna.x, i, coluna.y))
	return lista


func chega_perto(alcancados: Dictionary, ponto: Vector3) -> bool:
	for chao: Vector3i in alcancados:
		var centro := Vector2(chao.x + 0.5, chao.z + 0.5)
		var topo: float = _colunas[Vector2i(chao.x, chao.z)][chao.y].topo
		if centro.distance_to(Vector2(ponto.x, ponto.z)) <= ALCANCE_DO_DONO and absf(topo - ponto.y) <= 1.0:
			return true
	return false


# --- Montagem -----------------------------------------------------------------------------

## Colisões (StaticBody3D) dos objetos que ficam no caminho nesta metade do trajeto.
func _juntar_caixas() -> void:
	for objeto in fase.lista_objetos():
		if not _barra(objeto):
			continue
		if objeto is Portinhola and _passa_pela_portinhola(objeto as Portinhola):
			_juntar_laterais_da_portinhola(objeto as Portinhola)
			continue
		for corpo in objeto.find_children("*", "StaticBody3D", true, false):
			for filho in corpo.get_children():
				var colisao := filho as CollisionShape3D
				if colisao == null or colisao.disabled or colisao.shape == null:
					continue
				_juntar_caixa(colisao.global_transform, _caixa_da_forma(colisao.shape))


func _juntar_caixa(xf: Transform3D, caixa: AABB) -> void:
	var global_aabb := xf * caixa
	var indice := _caixas.size()
	_caixas.append({xf = xf.affine_inverse(), caixa = caixa,
		topo = global_aabb.end.y, base = global_aabb.position.y})
	var folga := RAIO_CACHORRO + 1.0
	for x in range(floori(global_aabb.position.x - folga), floori(global_aabb.end.x + folga) + 1):
		for z in range(floori(global_aabb.position.z - folga), floori(global_aabb.end.z + folga) + 1):
			var celula := Vector2i(x, z)
			if not _caixas_por_celula.has(celula):
				_caixas_por_celula[celula] = []
			_caixas_por_celula[celula].append(indice)


## Na ida sempre; na volta, se o graveto não for comprido demais para ela.
func _passa_pela_portinhola(portinhola: Portinhola) -> bool:
	if not com_graveto or portinhola.comprimento_maximo <= 0.0:
		return true
	var graveto := fase.primeiro(Graveto) as Graveto
	return graveto == null or graveto.comprimento <= portinhola.comprimento_maximo


## Só as tábuas dos lados barram: a célula do meio (as duas do meio, com largura par) fica livre.
func _juntar_laterais_da_portinhola(portinhola: Portinhola) -> void:
	var meia := portinhola.largura * 0.5
	var livre := 0.5 if portinhola.largura % 2 == 1 else 1.0
	if meia <= livre:
		return
	for lado: float in [-1.0, 1.0]:
		var centro := Vector3(lado * (livre + meia) * 0.5, Portinhola.ALTURA * 0.5, 0.0)
		var tamanho := Vector3(meia - livre, Portinhola.ALTURA, Portinhola.ESPESSURA)
		_juntar_caixa(portinhola.global_transform * Transform3D(Basis(), centro), AABB(-tamanho * 0.5, tamanho))


static func _caixa_da_forma(forma: Shape3D) -> AABB:
	if forma is BoxShape3D:
		var tamanho := (forma as BoxShape3D).size
		return AABB(-tamanho * 0.5, tamanho)
	if forma is CylinderShape3D:
		var cilindro := forma as CylinderShape3D
		return AABB(Vector3(-cilindro.radius, -cilindro.height * 0.5, -cilindro.radius),
			Vector3(cilindro.radius * 2.0, cilindro.height, cilindro.radius * 2.0))
	if forma is CapsuleShape3D:
		var capsula := forma as CapsuleShape3D
		return AABB(Vector3(-capsula.radius, -capsula.height * 0.5, -capsula.radius),
			Vector3(capsula.radius * 2.0, capsula.height, capsula.radius * 2.0))
	if forma is SphereShape3D:
		var raio := (forma as SphereShape3D).radius
		return AABB(-Vector3.ONE * raio, Vector3.ONE * raio * 2.0)
	return forma.get_debug_mesh().get_aabb()


func _barra(objeto: ObjetoFase) -> bool:
	if objeto is Dono or objeto is Empurravel:
		return false
	if objeto is TroncoRolante and (objeto as TroncoRolante).estado == TroncoRolante.Estado.TERRA:
		return false
	if objeto is Passaro and fase.tem_habilidade(Fase.HABILIDADE_LATIR):
		return false
	if objeto is Cerca and (objeto as Cerca).terra_fofa and fase.tem_habilidade(Fase.HABILIDADE_CAVAR):
		return false
	return objeto is Ponte or objeto.papel_no_canal() != "reage"


func _montar_colunas() -> void:
	var cavar := fase.tem_habilidade(Fase.HABILIDADE_CAVAR)
	var terreno := fase.terreno
	var baixadas := _aguas_das_comportas()
	# Vector2i → lista de faixas sólidas {base, topo, tile, celula}.
	var faixas := {}
	for celula in terreno.get_used_cells():
		var tile := terreno.get_cell_item(celula)
		if tile == Tiles.AGUA and baixadas.has(celula):
			tile = Tiles.AGUA_RASA
		if cavar and celula.y >= 0 and Tiles.eh_cavavel(tile):
			continue
		var coluna := Vector2i(celula.x, celula.z)
		if not faixas.has(coluna):
			faixas[coluna] = []
		var topo := float(celula.y) + _topo_do_tile(tile)
		var base := float(celula.y) - (0.08 if tile == Tiles.TABUA else 0.0)
		faixas[coluna].append({base = base, topo = topo, tile = tile, celula = celula})
	# Objetos: a colisão que cobre o centro da célula vira uma faixa sólida dela.
	for celula: Vector2i in _caixas_por_celula:
		var centro := Vector3(celula.x + 0.5, 0.0, celula.y + 0.5)
		for indice: int in _caixas_por_celula[celula]:
			var c: Dictionary = _caixas[indice]
			if _cobre_no_plano(c, centro, 0.0):
				if not faixas.has(celula):
					faixas[celula] = []
				faixas[celula].append({base = c.base, topo = c.topo, tile = -1, celula = Vector3i.ZERO})
	for coluna: Vector2i in faixas:
		var lista: Array = faixas[coluna]
		lista.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.topo < b.topo)
		var chaos: Array[Dictionary] = []
		for i in lista.size():
			var faixa: Dictionary = lista[i]
			if faixa.tile != -1 and Tiles.eh_agua(faixa.tile):
				continue
			var teto := INF
			var coberto := false
			for j in lista.size():
				var outra: Dictionary = lista[j]
				if j == i:
					continue
				if outra.topo > faixa.topo + 0.01:
					teto = minf(teto, maxf(outra.base, faixa.topo))
				elif outra.topo >= faixa.topo - 0.01 and outra.base < faixa.base:
					# Duas faixas com o mesmo topo (a ponte rente à margem): fica a de baixo.
					coberto = true
			if coberto or teto - faixa.topo < ALTURA_CACHORRO:
				continue
			chaos.append({topo = faixa.topo, teto = teto, bordas = _bordas(faixa),
				buraco = faixa.tile != -1 and Tiles.eh_buraco(faixa.tile)})
		if not chaos.is_empty():
			_colunas[coluna] = chaos


## Células de água funda que uma comporta baixa (vira rasa), se algo aciona o canal dela.
func _aguas_das_comportas() -> Dictionary:
	var canais_acionados := {}
	for objeto in fase.lista_objetos():
		if objeto.papel_no_canal() == "aciona":
			canais_acionados[objeto.get(&"canal")] = true
	var celulas := {}
	for objeto in fase.todos(Comporta):
		var comporta := objeto as Comporta
		if comporta.encher or not canais_acionados.has(comporta.canal):
			continue
		for celula in comporta.celulas_do_trecho(fase.terreno):
			celulas[celula] = true
	return celulas


static func _topo_do_tile(tile: int) -> float:
	if _RAMPAS.has(tile):
		return _RAMPAS[tile].y
	if _CANTOS.has(tile):
		return _CANTOS[tile].y
	return _TOPO.get(tile, 1.0)


## Altura (mínima, máxima) de cada borda do chão, por direção no mapa.
func _bordas(faixa: Dictionary) -> Dictionary:
	var bordas := {}
	var tile: int = faixa.tile
	var base := float(faixa.celula.y) if tile != -1 else 0.0
	for direcao in _DIRECOES:
		var altura := Vector2(faixa.topo, faixa.topo)
		if _CANTOS.has(tile):
			altura = Vector2(base + _CANTOS[tile].x, base + _CANTOS[tile].y)
		elif _RAMPAS.has(tile):
			var giro := fase.terreno.get_cell_item_basis(faixa.celula)
			var local := giro.inverse() * Vector3(direcao.x, 0, direcao.y)
			var faixa_rampa: Vector2 = _RAMPAS[tile]
			if local.x > 0.5:
				altura = Vector2(base + faixa_rampa.y, base + faixa_rampa.y)
			elif local.x < -0.5:
				altura = Vector2(base + faixa_rampa.x, base + faixa_rampa.x)
			else:
				altura = Vector2(base + faixa_rampa.x, base + faixa_rampa.y)
		bordas[direcao] = altura
	return bordas


func _ligar_tocas() -> void:
	var graveto := fase.primeiro(Graveto) as Graveto
	for objeto in fase.todos(Toca):
		var toca := objeto as Toca
		var outra := toca.par()
		if outra == null:
			continue
		if com_graveto and graveto and toca.comprimento_maximo > 0.0 and graveto.comprimento > toca.comprimento_maximo:
			continue
		var de: Variant = chao_perto(toca.ponto_da_entrada())
		var para: Variant = chao_perto(outra.ponto_de_saida())
		if de == null or para == null:
			continue
		if not _tocas.has(de):
			_tocas[de] = []
		_tocas[de].append(para)


# --- Passagens ----------------------------------------------------------------------------

func _vizinhos(chao: Vector3i) -> Array[Vector3i]:
	var lista: Array[Vector3i] = []
	var coluna := Vector2i(chao.x, chao.z)
	var atual: Dictionary = _colunas[coluna][chao.y]
	var salto := 0.0
	if fase.tem_habilidade(Fase.HABILIDADE_PULAR):
		salto = SALTO_COM_GRAVETO if com_graveto else SALTO_SEM_GRAVETO
	if atual.buraco:
		salto = maxf(salto, SAIDA_DO_BURACO)
	for direcao in _DIRECOES:
		var vizinha := coluna + direcao
		var chaos: Array = _colunas.get(vizinha, [])
		var daqui: Vector2 = atual.bordas[direcao]
		for i in chaos.size():
			var outro: Dictionary = chaos[i]
			var dali: Vector2 = outro.bordas[-direcao]
			var subida := dali.x - daqui.y
			if subida > PASSO and subida > salto:
				continue
			# A altura em que o corpo passa de uma célula para a outra.
			var passagem := maxf(daqui.y, dali.x) if subida > 0.0 else maxf(daqui.x, dali.x)
			if outro.teto - passagem < ALTURA_CACHORRO or atual.teto - maxf(passagem, dali.x) < ALTURA_CACHORRO:
				continue
			if _barrado(coluna, vizinha, passagem, salto):
				continue
			lista.append(Vector3i(vizinha.x, i, vizinha.y))
	for ligado: Vector3i in _tocas.get(chao, []):
		lista.append(ligado)
	return lista


## Uma colisão de objeto no meio do caminho entre os centros das duas células, alta demais
## para pular por cima?
func _barrado(de: Vector2i, para: Vector2i, altura: float, salto: float) -> bool:
	var indices: Array = _caixas_por_celula.get(de, [])
	if indices.is_empty():
		return false
	var a := Vector3(de.x + 0.5, 0.0, de.y + 0.5)
	var b := Vector3(para.x + 0.5, 0.0, para.y + 0.5)
	for indice: int in indices:
		var c: Dictionary = _caixas[indice]
		if c.topo <= altura + maxf(salto, PASSO) or c.base >= altura + ALTURA_CACHORRO:
			continue
		if _cobre_no_plano(c, a, 0.0) or _cobre_no_plano(c, b, 0.0):
			continue  # já virou chão (ou parede) de uma das células
		for passo in range(1, 10):
			if _cobre_no_plano(c, a.lerp(b, passo / 10.0), RAIO_CACHORRO):
				return true
	return false


## O ponto (só X e Z contam) cai dentro da caixa, com `folga` (m) em volta?
static func _cobre_no_plano(c: Dictionary, ponto: Vector3, folga: float) -> bool:
	var xf: Transform3D = c.xf
	var caixa: AABB = c.caixa
	var centro_y := (xf.affine_inverse() * caixa.get_center()).y
	var local := xf * Vector3(ponto.x, centro_y, ponto.z)
	return local.x >= caixa.position.x - folga and local.x <= caixa.end.x + folga \
		and local.z >= caixa.position.z - folga and local.z <= caixa.end.z + folga

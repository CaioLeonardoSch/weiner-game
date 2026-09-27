class_name Entorno
extends Node3D
## Chão e floresta gerados em volta da fase, na hora de jogar (não são salvos na fase).
##
## Em monitores largos a câmera isométrica mostra muito mundo dos lados; sem isto, apareceria
## o fim do chão. O entorno é uma moldura de chão em volta da área usada pelo terreno e árvores
## voxel em MultiMesh (milhares de árvores custam pouco): perto da fase, densas e com sombra;
## mais longe, esparsas e sem sombra. Não tem colisão — cercas e paredes invisíveis da fase já
## seguram o cachorro. O chão e as árvores seguem o bioma da fase (neve: chão branco, árvores
## nevadas).
##
## Mapas de qualquer formato: num mapa em L (ou que se espalha para vários lados), o que sobra do
## retângulo em volta dele também ganha chão e árvores — as colunas vazias ligadas à borda do
## retângulo. Um vazio cercado pelo mapa (um abismo de propósito) continua vazio.

## Largura (m) da moldura em volta da fase.
const MARGEM := 36.0
## Faixa perto da fase: árvores mais juntas e com sombra.
const FAIXA_PERTO := 12.0
const ESPACO_PERTO := 2.1
const ESPACO_LONGE := 3.4


## Monta o entorno em volta do terreno da fase (retângulo das células usadas).
func montar(fase: Fase) -> void:
	for filho in get_children():
		filho.queue_free()
	var terreno := fase.terreno if fase.is_node_ready() else fase.get_node("Terreno") as GridMap
	var celulas := terreno.get_used_cells()
	if celulas.is_empty():
		return
	# Colunas (x, z) usadas, em coordenadas do mundo (o terreno fica na origem, células de 1 m).
	var usadas := {}
	var minimo := Vector2i(1 << 30, 1 << 30)
	var maximo := -minimo
	for celula in celulas:
		var mundo := terreno.to_global(terreno.map_to_local(celula))
		var coluna := Vector2i(floori(mundo.x), floori(mundo.z))
		usadas[coluna] = true
		minimo = minimo.min(coluna)
		maximo = maximo.max(coluna)
	var dentro := Rect2(Vector2(minimo), Vector2(maximo - minimo + Vector2i.ONE))
	var fora := dentro.grow(MARGEM)
	var sobras := _sobras(usadas, minimo, maximo)
	var material: Material = load(Biomas.dados(fase.bioma).chao)
	_chao(dentro, fora, sobras, material)
	_arvores(dentro, fora, usadas, sobras, hash(fase.nome), fase.bioma == Biomas.NEVE)


## Colunas vazias dentro do retângulo do mapa ligadas à borda dele (o "lado de fora" de um mapa
## que não é retangular). Busca em largura a partir das colunas vazias da borda.
static func _sobras(usadas: Dictionary, minimo: Vector2i, maximo: Vector2i) -> Dictionary:
	var sobras := {}
	var fila: Array[Vector2i] = []
	for x in range(minimo.x, maximo.x + 1):
		for z in [minimo.y, maximo.y]:
			fila.append(Vector2i(x, z))
	for z in range(minimo.y, maximo.y + 1):
		for x in [minimo.x, maximo.x]:
			fila.append(Vector2i(x, z))
	while not fila.is_empty():
		var coluna: Vector2i = fila.pop_back()
		if sobras.has(coluna) or usadas.has(coluna) or coluna.x < minimo.x or coluna.y < minimo.y \
				or coluna.x > maximo.x or coluna.y > maximo.y:
			continue
		sobras[coluna] = true
		for passo in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			fila.append(coluna + passo)
	return sobras


## Quatro retângulos de chão em volta (sem cobrir a fase: por baixo dela há água e buracos),
## mais um quadrado por coluna de sobra (juntos numa malha só).
func _chao(dentro: Rect2, fora: Rect2, sobras: Dictionary, material: Material) -> void:
	var pedacos := [
		Rect2(fora.position.x, fora.position.y, fora.size.x, dentro.position.y - fora.position.y),
		Rect2(fora.position.x, dentro.end.y, fora.size.x, fora.end.y - dentro.end.y),
		Rect2(fora.position.x, dentro.position.y, dentro.position.x - fora.position.x, dentro.size.y),
		Rect2(dentro.end.x, dentro.position.y, fora.end.x - dentro.end.x, dentro.size.y),
	]
	for pedaco: Rect2 in pedacos:
		var plano := PlaneMesh.new()
		plano.size = pedaco.size
		var chao := MeshInstance3D.new()
		chao.mesh = plano
		chao.material_override = material
		chao.position = Vector3(pedaco.get_center().x, 0.0, pedaco.get_center().y)
		chao.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(chao)
	if sobras.is_empty():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for coluna: Vector2i in sobras:
		var a := Vector3(coluna.x, 0.0, coluna.y)
		for v in [a, a + Vector3(1, 0, 0), a + Vector3(1, 0, 1), a, a + Vector3(1, 0, 1), a + Vector3(0, 0, 1)]:
			st.add_vertex(v)
	var malha := MeshInstance3D.new()
	malha.mesh = st.commit()
	malha.material_override = material
	malha.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(malha)


func _arvores(dentro: Rect2, fora: Rect2, usadas: Dictionary, sobras: Dictionary, semente: int,
		nevadas: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	# (tipo, variante, com sombra) → transforms
	var grupos := {}
	for passo_e_faixa in [[ESPACO_PERTO, true], [ESPACO_LONGE, false]]:
		var passo: float = passo_e_faixa[0]
		var perto: bool = passo_e_faixa[1]
		var x := fora.position.x
		while x < fora.end.x:
			var z := fora.position.y
			while z < fora.end.y:
				var ponto := Vector2(x, z) + Vector2(rng.randf_range(-0.45, 0.45), rng.randf_range(-0.45, 0.45)) * passo
				z += passo
				var distancia := _distancia_fora(dentro, ponto)
				if distancia <= 0.0:
					# Dentro do retângulo do mapa: só nas sobras, longe das colunas usadas.
					if not perto or not _livre_nas_sobras(ponto, usadas, sobras):
						continue
				# Deixa um respiro junto da fase (ela já tem as árvores dela na borda).
				elif distancia < 0.8 or (perto and distancia > FAIXA_PERTO) or (not perto and distancia <= FAIXA_PERTO):
					continue
				var sorteio := rng.randf()
				var tipo := Voxel.TipoArvore.PINHEIRO if sorteio < 0.42 else (
					Voxel.TipoArvore.REDONDA if sorteio < 0.9 else Voxel.TipoArvore.ARBUSTO)
				var chave := [tipo, rng.randi_range(0, 7), perto]
				if not grupos.has(chave):
					grupos[chave] = []
				var escala := rng.randf_range(0.85, 1.25) * (1.0 if perto else 1.15)
				var base := Basis(Vector3.UP, rng.randi_range(0, 3) * PI * 0.5).scaled(Vector3.ONE * escala)
				(grupos[chave] as Array).append(Transform3D(base, Vector3(ponto.x, 0.0, ponto.y)))
			x += passo
	for chave: Array in grupos:
		var lista: Array = grupos[chave]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = Voxel.arvore(chave[0], chave[1], nevadas)
		multi.instance_count = lista.size()
		for i in lista.size():
			multi.set_instance_transform(i, lista[i])
		var instancia := MultiMeshInstance3D.new()
		instancia.multimesh = multi
		instancia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if chave[2] \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instancia)


## O ponto cai numa coluna de sobra sem nenhuma coluna usada em volta (1 m de respiro)?
static func _livre_nas_sobras(ponto: Vector2, usadas: Dictionary, sobras: Dictionary) -> bool:
	var coluna := Vector2i(floori(ponto.x), floori(ponto.y))
	if not sobras.has(coluna):
		return false
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			if usadas.has(coluna + Vector2i(dx, dz)):
				return false
	return true


## Distância de um ponto (fora do retângulo) até ele; 0 se estiver dentro.
static func _distancia_fora(retangulo: Rect2, ponto: Vector2) -> float:
	var dx := maxf(maxf(retangulo.position.x - ponto.x, 0.0), ponto.x - retangulo.end.x)
	var dz := maxf(maxf(retangulo.position.y - ponto.y, 0.0), ponto.y - retangulo.end.y)
	return Vector2(dx, dz).length()

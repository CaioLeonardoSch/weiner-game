class_name Voxel
## Modelos voxel (pixel art em 3D): cada voxel é um cubinho colorido.
##
## Dois jeitos de criar um modelo:
## - Arquivo de texto em assets/voxel/*.txt (formato descrito em assets/voxel/LEIA-ME.md),
##   usado pelo nó ModeloVoxel.
## - Gerador em código (árvores, pedras, flores), com variantes por semente.
## Ambos viram uma ArrayMesh só com as faces visíveis, com cor por vértice e um pouco de
## oclusão de ambiente nas quinas (cantos entre voxels ficam mais escuros).
## As malhas ficam em cache: cem árvores iguais usam a mesma malha.

const MATERIAL := preload("res://assets/materiais/voxel.tres")

## Brilho do vértice conforme quantos vizinhos cobrem o canto (0 a 3).
const _AO := [1.0, 0.84, 0.7, 0.58]

const _DIRECOES: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]

static var _cache := {}


# --- Malha -------------------------------------------------------------------------------

## `voxels`: Vector3i → Color (sRGB). `tamanho`: metros por voxel.
## `origem`: ponto (em unidades de voxel) que vira a origem da malha.
static func malha(voxels: Dictionary, tamanho: float, origem: Vector3 = Vector3.ZERO) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normais := PackedVector3Array()
	var cores := PackedColorArray()
	var indices := PackedInt32Array()

	for p: Vector3i in voxels:
		var cor: Color = voxels[p]
		cor = cor.srgb_to_linear()
		for d in _DIRECOES:
			if voxels.has(p + d):
				continue
			var eixo := 0 if d.x != 0 else (1 if d.y != 0 else 2)
			var eixo_a := (eixo + 1) % 3
			var eixo_b := (eixo + 2) % 3
			var fora := 1 if (d.x + d.y + d.z) > 0 else 0
			var cantos: Array[Vector3i] = []
			for c in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var canto := Vector3i.ZERO
				canto[eixo] = fora
				canto[eixo_a] = c.x
				canto[eixo_b] = c.y
				cantos.append(canto)

			var base := vertices.size()
			var ao: Array[int] = []
			for canto in cantos:
				vertices.append((Vector3(p + canto) - origem) * tamanho)
				normais.append(Vector3(d))
				var n := _ocupacao_do_canto(voxels, p + d, canto, eixo_a, eixo_b)
				ao.append(n)
				var brilho: float = _AO[n]
				cores.append(Color(cor.r * brilho, cor.g * brilho, cor.b * brilho))

			# Diagonal escolhida conforme a oclusão, para o degradê não ficar torto.
			var tris: Array[int] = [0, 1, 2, 0, 2, 3]
			if ao[0] + ao[2] > ao[1] + ao[3]:
				tris = [1, 2, 3, 1, 3, 0]
			for t in range(0, 6, 3):
				var a := tris[t]
				var b := tris[t + 1]
				var c := tris[t + 2]
				# Godot desenha a face da frente com os vértices em sentido horário.
				var va := vertices[base + a]
				if (vertices[base + b] - va).cross(vertices[base + c] - va).dot(Vector3(d)) > 0.0:
					var troca := b
					b = c
					c = troca
				indices.append_array([base + a, base + b, base + c])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normais
	arrays[Mesh.ARRAY_COLOR] = cores
	arrays[Mesh.ARRAY_INDEX] = indices
	var resultado := ArrayMesh.new()
	if vertices.is_empty():
		return resultado
	resultado.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	resultado.surface_set_material(0, MATERIAL)
	return resultado


## Quantos voxels cobrem o canto de uma face (0 a 3), olhando a camada logo à frente dela.
static func _ocupacao_do_canto(voxels: Dictionary, frente: Vector3i, canto: Vector3i, eixo_a: int, eixo_b: int) -> int:
	var passo_a := Vector3i.ZERO
	passo_a[eixo_a] = 1 if canto[eixo_a] == 1 else -1
	var passo_b := Vector3i.ZERO
	passo_b[eixo_b] = 1 if canto[eixo_b] == 1 else -1
	var lado_a := voxels.has(frente + passo_a)
	var lado_b := voxels.has(frente + passo_b)
	if lado_a and lado_b:
		return 3
	return int(lado_a) + int(lado_b) + int(voxels.has(frente + passo_a + passo_b))


# --- Arquivos de texto -------------------------------------------------------------------

## Malha de um arquivo .txt (com cache). Veja assets/voxel/LEIA-ME.md.
static func carregar(caminho: String) -> ArrayMesh:
	if _cache.has(caminho):
		return _cache[caminho]
	var texto := FileAccess.get_file_as_string(caminho)
	if texto.is_empty():
		push_error("Modelo voxel não encontrado ou vazio: %s" % caminho)
		return ArrayMesh.new()
	var dados := interpretar(texto, caminho)
	var resultado := malha(dados.voxels, dados.tamanho, dados.origem)
	_cache[caminho] = resultado
	return resultado


## Lê o formato de texto. Devolve {voxels, tamanho, origem}.
static func interpretar(texto: String, nome := "modelo") -> Dictionary:
	var paleta := {}
	var voxels := {}
	var tamanho := 0.125
	var origem = null
	var camadas := Vector2i(-1, -1)
	var linha_z := 0

	var numero := 0
	for linha_bruta in texto.split("\n"):
		numero += 1
		var linha := linha_bruta.get_slice("#", 0).strip_edges()
		if linha.is_empty():
			continue
		var partes := linha.split(" ", false)
		match partes[0]:
			"voxel":
				tamanho = partes[1].to_float()
			"origem":
				origem = Vector3(partes[1].to_float(), partes[2].to_float(), partes[3].to_float())
			"cor":
				paleta[partes[1]] = Color(partes[2])
			"camada":
				var faixa := partes[1].split("-")
				camadas = Vector2i(faixa[0].to_int(), faixa[-1].to_int())
				linha_z = 0
			_:
				if camadas.x < 0:
					push_error("%s:%d: linha de voxels antes de 'camada'" % [nome, numero])
					continue
				var x := 0
				for letra in linha.replace(" ", ""):
					if letra != ".":
						if not paleta.has(letra):
							push_error("%s:%d: cor '%s' não definida" % [nome, numero, letra])
						else:
							for y in range(camadas.x, camadas.y + 1):
								voxels[Vector3i(x, y, linha_z)] = paleta[letra]
					x += 1
				linha_z += 1

	if origem == null:
		origem = _origem_padrao(voxels)
	return {voxels = voxels, tamanho = tamanho, origem = origem}


## Centro da base: o modelo fica de pé sobre a origem.
static func _origem_padrao(voxels: Dictionary) -> Vector3:
	if voxels.is_empty():
		return Vector3.ZERO
	var minimo := Vector3i(1 << 30, 1 << 30, 1 << 30)
	var maximo := -minimo
	for p: Vector3i in voxels:
		minimo = minimo.min(p)
		maximo = maximo.max(p)
	return Vector3((minimo.x + maximo.x + 1) * 0.5, minimo.y, (minimo.z + maximo.z + 1) * 0.5)


# --- Geradores ---------------------------------------------------------------------------

enum TipoArvore { PINHEIRO, REDONDA, ARBUSTO }

const _VERDES_PINHEIRO := [Color("2c6b3f"), Color("245c36"), Color("33784a"), Color("1f5030")]
const _VERDES_COPA := [Color("3f8f3a"), Color("4b9e42"), Color("367f34"), Color("58a947")]
const _CASCA := [Color("6b4428"), Color("5b3920"), Color("744b2c")]


static func arvore(tipo: TipoArvore, variante: int) -> ArrayMesh:
	var chave := "arvore_%d_%d" % [tipo, variante]
	if not _cache.has(chave):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(chave)
		var voxels := {}
		match tipo:
			TipoArvore.PINHEIRO:
				_gerar_pinheiro(voxels, rng)
			TipoArvore.REDONDA:
				_gerar_redonda(voxels, rng)
			TipoArvore.ARBUSTO:
				_gerar_arbusto(voxels, rng)
		_clarear_topos(voxels, 1.18)
		# Voxel de 0,25 m; o tronco 2x2 fica centrado na origem.
		_cache[chave] = malha(voxels, 0.25, Vector3(0.0, 0.0, 0.0))
	return _cache[chave]


static func _tronco(voxels: Dictionary, rng: RandomNumberGenerator, altura: int) -> void:
	for y in altura:
		for x in [-1, 0]:
			for z in [-1, 0]:
				voxels[Vector3i(x, y, z)] = _CASCA[rng.randi() % _CASCA.size()]


static func _gerar_pinheiro(voxels: Dictionary, rng: RandomNumberGenerator) -> void:
	var inicio := rng.randi_range(2, 3)
	var altura_copa := rng.randi_range(12, 16)
	var raio_base := rng.randf_range(3.6, 4.6)
	_tronco(voxels, rng, inicio + altura_copa - 2)
	for i in altura_copa:
		var t := float(i) / altura_copa
		# Andares: dentro de cada andar o raio diminui, depois volta a abrir um pouco.
		var andar := fmod(i, 4.0) / 4.0
		var raio := raio_base * (1.0 - t) * (1.0 - andar * 0.35) + 0.6
		_disco(voxels, rng, inicio + i, raio, _VERDES_PINHEIRO)


static func _gerar_redonda(voxels: Dictionary, rng: RandomNumberGenerator) -> void:
	var altura_tronco := rng.randi_range(5, 7)
	_tronco(voxels, rng, altura_tronco + 3)
	var centro := Vector3(-0.5, altura_tronco + rng.randf_range(3.5, 4.5), -0.5)
	var bolhas: Array[Vector4] = [Vector4(centro.x, centro.y, centro.z, rng.randf_range(3.6, 4.4))]
	for i in rng.randi_range(2, 4):
		var desvio := Vector3(rng.randf_range(-2.5, 2.5), rng.randf_range(-1.0, 1.8), rng.randf_range(-2.5, 2.5))
		bolhas.append(Vector4(centro.x + desvio.x, centro.y + desvio.y, centro.z + desvio.z, rng.randf_range(2.2, 3.2)))
	_bolhas(voxels, rng, bolhas, _VERDES_COPA)


static func _gerar_arbusto(voxels: Dictionary, rng: RandomNumberGenerator) -> void:
	var bolhas: Array[Vector4] = [Vector4(-0.5, 1.2, -0.5, rng.randf_range(1.9, 2.3))]
	for i in rng.randi_range(1, 2):
		bolhas.append(Vector4(rng.randf_range(-1.8, 0.8), 1.0, rng.randf_range(-1.8, 0.8), rng.randf_range(1.3, 1.8)))
	_bolhas(voxels, rng, bolhas, _VERDES_COPA)
	# Nada abaixo do chão.
	for p: Vector3i in voxels.keys():
		if p.y < 0:
			voxels.erase(p)


static func _disco(voxels: Dictionary, rng: RandomNumberGenerator, y: int, raio: float, cores: Array) -> void:
	var r := ceili(raio)
	for x in range(-r - 1, r + 1):
		for z in range(-r - 1, r + 1):
			# Centro do disco entre os 4 voxels do tronco (x, z = 0).
			var dx := x + 0.5
			var dz := z + 0.5
			if dx * dx + dz * dz <= raio * raio + rng.randf_range(-1.5, 1.5):
				voxels[Vector3i(x, y, z)] = cores[rng.randi() % cores.size()]


static func _bolhas(voxels: Dictionary, rng: RandomNumberGenerator, bolhas: Array[Vector4], cores: Array) -> void:
	for b in bolhas:
		var r := ceili(b.w) + 1
		for x in range(floori(b.x) - r, ceili(b.x) + r + 1):
			for y in range(floori(b.y) - r, ceili(b.y) + r + 1):
				for z in range(floori(b.z) - r, ceili(b.z) + r + 1):
					var dist := Vector3(x, y, z).distance_to(Vector3(b.x, b.y, b.z))
					if dist <= b.w + rng.randf_range(-0.6, 0.4):
						voxels[Vector3i(x, y, z)] = cores[rng.randi() % cores.size()]


## Voxels sem nada em cima pegam mais sol: cor um pouco mais clara.
static func _clarear_topos(voxels: Dictionary, fator: float) -> void:
	for p: Vector3i in voxels.keys():
		if not voxels.has(p + Vector3i.UP):
			var c: Color = voxels[p]
			voxels[p] = Color(minf(c.r * fator, 1.0), minf(c.g * fator, 1.0), minf(c.b * fator, 1.0))


const _CINZAS := [Color("8e9199"), Color("7d8089"), Color("9ea1a8"), Color("73767e")]
const _MUSGO := [Color("5f8f3e"), Color("6d9d45")]


## Pedra arredondada (voxel de 0,125 m) com um pouco de musgo em cima.
static func pedra(variante: int) -> ArrayMesh:
	var chave := "pedra_%d" % variante
	if not _cache.has(chave):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(chave)
		var raio := Vector3(rng.randf_range(2.6, 3.8), rng.randf_range(2.0, 3.0), rng.randf_range(2.6, 3.8))
		var voxels := {}
		for x in range(-5, 5):
			for y in range(0, 6):
				for z in range(-5, 5):
					var p := Vector3(x + 0.5, y + 0.5 - raio.y * 0.35, z + 0.5) / raio
					if p.length() <= 1.0 + rng.randf_range(-0.12, 0.08):
						voxels[Vector3i(x, y, z)] = _CINZAS[rng.randi() % _CINZAS.size()]
		for p: Vector3i in voxels.keys():
			if not voxels.has(p + Vector3i.UP) and rng.randf() < 0.35:
				voxels[p] = _MUSGO[rng.randi() % _MUSGO.size()]
		_cache[chave] = malha(voxels, 0.125)
	return _cache[chave]


const _CORES_FLORES := [Color("e8514a"), Color("f2c945"), Color("f4f1ea"), Color("a46be0"), Color("ef8fc1")]
const _VERDES_CAPIM := [Color("4f9a3a"), Color("5fae45"), Color("3f8a33")]


## Tufo de capim com algumas flores (voxel de 0,125 m). Decoração rasteira, sem colisão.
static func flores(variante: int) -> ArrayMesh:
	var chave := "flores_%d" % variante
	if not _cache.has(chave):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(chave)
		var voxels := {}
		for i in rng.randi_range(5, 9):
			var x := rng.randi_range(-3, 3)
			var z := rng.randi_range(-3, 3)
			var altura := rng.randi_range(1, 3)
			for y in altura:
				voxels[Vector3i(x, y, z)] = _VERDES_CAPIM[rng.randi() % _VERDES_CAPIM.size()]
			if rng.randf() < 0.55:
				voxels[Vector3i(x, altura, z)] = _CORES_FLORES[rng.randi() % _CORES_FLORES.size()]
		_cache[chave] = malha(voxels, 0.125)
	return _cache[chave]

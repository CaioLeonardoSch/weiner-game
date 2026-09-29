class_name Som
## Sons gerados por código, sem arquivos de áudio (como os modelos voxel): cada som é um
## AudioStreamWAV montado uma vez, na primeira vez que toca, e guardado. Tocam no barramento
## "Efeitos" (volume nas opções).

const TAXA := 22050

static var _cache := {}


## Latido ("au!") em `posicao`. `tom`: 1 = médio; maior = cachorro pequeno (mais agudo).
static func latido(pai: Node, posicao: Vector3, tom := 1.0) -> void:
	var chave := "latido_%.2f" % tom
	if not _cache.has(chave):
		_cache[chave] = _gerar_latido(tom)
	var jogador := AudioStreamPlayer3D.new()
	jogador.stream = _cache[chave]
	jogador.bus = &"Efeitos"
	jogador.unit_size = 8.0
	jogador.max_distance = 60.0
	jogador.pitch_scale = randf_range(0.95, 1.05)
	pai.add_child(jogador)
	jogador.global_position = posicao
	jogador.play()
	jogador.finished.connect(jogador.queue_free)


## Balido ("béé") em `posicao`. `tom`: 1 = ovelha comum.
static func balido(pai: Node, posicao: Vector3, tom := 1.0) -> void:
	var chave := "balido_%.2f" % tom
	if not _cache.has(chave):
		_cache[chave] = _gerar_balido(tom)
	var jogador := AudioStreamPlayer3D.new()
	jogador.stream = _cache[chave]
	jogador.bus = &"Efeitos"
	jogador.unit_size = 6.0
	jogador.max_distance = 45.0
	jogador.pitch_scale = randf_range(0.96, 1.04)
	pai.add_child(jogador)
	jogador.global_position = posicao
	jogador.play()
	jogador.finished.connect(jogador.queue_free)


## Rangido de madeira velha (a ponte fraca cedendo).
static func rangido(pai: Node, posicao: Vector3) -> void:
	_tocar(pai, posicao, "rangido", _gerar_rangido, 6.0)


## Estalo de madeira quebrando.
static func estalo(pai: Node, posicao: Vector3) -> void:
	_tocar(pai, posicao, "estalo", _gerar_estalo, 8.0)


static func _tocar(pai: Node, posicao: Vector3, chave: String, gerar: Callable, alcance: float) -> void:
	if not _cache.has(chave):
		_cache[chave] = gerar.call()
	var jogador := AudioStreamPlayer3D.new()
	jogador.stream = _cache[chave]
	jogador.bus = &"Efeitos"
	jogador.unit_size = alcance
	jogador.max_distance = 50.0
	jogador.pitch_scale = randf_range(0.93, 1.07)
	pai.add_child(jogador)
	jogador.global_position = posicao
	jogador.play()
	jogador.finished.connect(jogador.queue_free)


## Tom do latido pelo tamanho da raça: salsicha e pug agudos, border collie mais grave.
static func tom_da_raca(raca: Raca) -> float:
	return clampf(0.75 / raca.altura_colisao, 0.7, 1.3) if raca else 1.0


## "Au!": um tom que sobe rápido e cai, com harmônicos (a voz) e um pouco de ruído no ataque
## (o sopro), saturado de leve para ficar rouco.
static func _gerar_latido(tom: float) -> AudioStreamWAV:
	var duracao := 0.24
	var total := int(TAXA * duracao)
	var dados := PackedByteArray()
	dados.resize(total * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var fase := 0.0
	for i in total:
		var t := float(i) / TAXA
		var p := t / duracao
		var frequencia := (330.0 + 280.0 * sin(minf(p * 4.0, 1.0) * PI * 0.5) - 330.0 * p) * tom
		fase += TAU * frequencia / TAXA
		var voz := sin(fase) + 0.55 * sin(fase * 2.0) + 0.3 * sin(fase * 3.0) + 0.15 * sin(fase * 4.0)
		var sopro := rng.randf_range(-1.0, 1.0) * maxf(1.0 - p * 3.0, 0.0)
		var envelope := minf(t / 0.01, 1.0) * pow(1.0 - p, 1.8)
		var amostra := tanh((voz * 0.5 + sopro * 0.35) * envelope * 1.8) * 0.75
		dados.encode_s16(i * 2, int(clampf(amostra, -1.0, 1.0) * 32767.0))
	var som := AudioStreamWAV.new()
	som.format = AudioStreamWAV.FORMAT_16_BITS
	som.mix_rate = TAXA
	som.stereo = false
	som.data = dados
	return som


## "Béé": um tom anasalado (harmônicos fortes) com o tremido típico da ovelha (a voz falha umas
## 12 vezes por segundo) e um vibrato leve; cai um pouco no fim.
static func _gerar_balido(tom: float) -> AudioStreamWAV:
	var duracao := 0.6
	var total := int(TAXA * duracao)
	var dados := PackedByteArray()
	dados.resize(total * 2)
	var fase := 0.0
	for i in total:
		var t := float(i) / TAXA
		var p := t / duracao
		var frequencia := (360.0 - 60.0 * p * p) * tom * (1.0 + 0.03 * sin(TAU * 6.5 * t))
		fase += TAU * frequencia / TAXA
		var voz := sin(fase) * 0.6 + sin(fase * 2.0) * 0.8 + sin(fase * 3.0) * 0.5 + sin(fase * 4.0) * 0.3 \
			+ sin(fase * 5.0) * 0.15
		var tremido := 0.65 + 0.35 * sin(TAU * 12.0 * t)
		var envelope := minf(t / 0.04, 1.0) * clampf((duracao - t) / 0.18, 0.0, 1.0)
		var amostra := tanh(voz * tremido * envelope * 0.9) * 0.6
		dados.encode_s16(i * 2, int(clampf(amostra, -1.0, 1.0) * 32767.0))
	var som := AudioStreamWAV.new()
	som.format = AudioStreamWAV.FORMAT_16_BITS
	som.mix_rate = TAXA
	som.stereo = false
	som.data = dados
	return som


## Rangido: um tom grave que oscila devagar, com atrito (ruído) modulado — madeira sob peso.
static func _gerar_rangido() -> AudioStreamWAV:
	var duracao := 0.7
	var total := int(TAXA * duracao)
	var dados := PackedByteArray()
	dados.resize(total * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var fase := 0.0
	for i in total:
		var t := float(i) / TAXA
		var p := t / duracao
		var frequencia := 140.0 + 60.0 * sin(TAU * 1.3 * t) + 25.0 * sin(TAU * 7.0 * t)
		fase += TAU * frequencia / TAXA
		var atrito := rng.randf_range(-1.0, 1.0) * (0.5 + 0.5 * sin(TAU * 23.0 * t))
		var voz := sin(fase) * 0.6 + sin(fase * 2.0) * 0.3 + atrito * 0.35
		var envelope := minf(t / 0.05, 1.0) * clampf((duracao - t) / 0.2, 0.0, 1.0)
		var amostra := tanh(voz * envelope * 1.4) * 0.45 * (1.0 - p * 0.3)
		dados.encode_s16(i * 2, int(clampf(amostra, -1.0, 1.0) * 32767.0))
	return _wav(dados)


## Estalo: um estouro de ruído curto e seco, seguido de uns estalinhos.
static func _gerar_estalo() -> AudioStreamWAV:
	var duracao := 0.5
	var total := int(TAXA * duracao)
	var dados := PackedByteArray()
	dados.resize(total * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var anterior := 0.0
	for i in total:
		var t := float(i) / TAXA
		var ruido := rng.randf_range(-1.0, 1.0)
		# Ruído um pouco filtrado (mais "madeira", menos chiado).
		anterior = lerpf(anterior, ruido, 0.35)
		var envelope := exp(-t * 18.0)
		for estalinho in [0.12, 0.2, 0.31]:
			if t > estalinho:
				envelope += exp(-(t - estalinho) * 60.0) * 0.5
		var amostra := clampf(anterior * envelope * 1.6, -1.0, 1.0) * 0.7
		dados.encode_s16(i * 2, int(amostra * 32767.0))
	return _wav(dados)



## Laços do clima (ver scripts/clima.gd): tocam sem parar, sem posição, com o volume pela
## intensidade. Chiado da chuva: ruído agudo com pingos soltos.
static func chuva_laco() -> AudioStreamWAV:
	if not _cache.has("chuva"):
		_cache["chuva"] = _gerar_laco(_amostra_chuva, 3.0, 21)
	return _cache["chuva"]


## Vento: ruído grave que sobe e desce devagar (o uivo vem do filtro que muda).
static func vento_laco() -> AudioStreamWAV:
	if not _cache.has("vento"):
		_cache["vento"] = _gerar_laco(_amostra_vento, 4.0, 22)
	return _cache["vento"]


## Trovão ao longe: um estouro abafado e um ronco que rola por uns segundos.
static func trovao(pai: Node, volume_db := 0.0) -> void:
	if not _cache.has("trovao"):
		_cache["trovao"] = _gerar_trovao()
	var jogador := AudioStreamPlayer.new()
	jogador.stream = _cache["trovao"]
	jogador.bus = &"Efeitos"
	jogador.volume_db = volume_db
	jogador.pitch_scale = randf_range(0.85, 1.1)
	pai.add_child(jogador)
	jogador.play()
	jogador.finished.connect(jogador.queue_free)


## Monta um laço de `duracao` segundos com `amostra(t, rng, estado)`: o fim se funde no começo
## (0,3 s de mistura), então a emenda não estala.
static func _gerar_laco(amostra: Callable, duracao: float, semente: int) -> AudioStreamWAV:
	var total := int(TAXA * duracao)
	var mistura := int(TAXA * 0.3)
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var estado := {}
	var bruto := PackedFloat32Array()
	bruto.resize(total + mistura)
	for i in total + mistura:
		bruto[i] = amostra.call(float(i) / TAXA, rng, estado)
	var dados := PackedByteArray()
	dados.resize(total * 2)
	for i in total:
		var valor := bruto[i]
		if i < mistura:
			var peso := float(i) / mistura
			valor = lerpf(bruto[total + i], valor, peso)
		dados.encode_s16(i * 2, int(clampf(valor, -1.0, 1.0) * 32767.0))
	var som := _wav(dados)
	som.loop_mode = AudioStreamWAV.LOOP_FORWARD
	som.loop_begin = 0
	som.loop_end = total
	return som


static func _amostra_chuva(t: float, rng: RandomNumberGenerator, estado: Dictionary) -> float:
	var ruido := rng.randf_range(-1.0, 1.0)
	var grave: float = lerpf(estado.get("grave", 0.0), ruido, 0.08)
	estado["grave"] = grave
	var chiado: float = lerpf(estado.get("chiado", 0.0), ruido - grave, 0.5)
	estado["chiado"] = chiado
	# Pingos: de vez em quando um "tic" curto que some rápido.
	var pingo: float = estado.get("pingo", 0.0) * 0.992
	if rng.randf() < 0.0012:
		pingo = rng.randf_range(0.3, 0.8)
		estado["tom"] = rng.randf_range(1800.0, 2600.0)
	estado["pingo"] = pingo
	var tic := sin(t * TAU * float(estado.get("tom", 2000.0))) * pingo * 0.25
	return chiado * (0.28 + 0.04 * sin(t * TAU * 0.5)) + tic


static func _amostra_vento(t: float, rng: RandomNumberGenerator, estado: Dictionary) -> float:
	var ruido := rng.randf_range(-1.0, 1.0)
	# Força que sobe e desce (ciclos inteiros no laço de 4 s, para a emenda casar).
	var forca := 0.55 + 0.3 * sin(t * TAU * 0.25) + 0.15 * sin(t * TAU * 0.75 + 1.0)
	var corte := 0.01 + 0.03 * forca
	var um: float = lerpf(estado.get("um", 0.0), ruido, corte)
	var dois: float = lerpf(estado.get("dois", 0.0), um, corte)
	estado["um"] = um
	estado["dois"] = dois
	return dois * 9.0 * forca


static func _gerar_trovao() -> AudioStreamWAV:
	var duracao := 3.2
	var total := int(TAXA * duracao)
	var dados := PackedByteArray()
	dados.resize(total * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var um := 0.0
	var dois := 0.0
	for i in total:
		var t := float(i) / TAXA
		var ruido := rng.randf_range(-1.0, 1.0)
		um = lerpf(um, ruido, 0.05)
		dois = lerpf(dois, um, 0.05)
		# Estouro no começo e roncos que rolam e somem.
		var envelope := minf(t / 0.04, 1.0) * (exp(-t * 3.0) * 0.8 + 0.5 * exp(-t * 0.9) \
			* (0.6 + 0.4 * sin(t * TAU * 1.7) * sin(t * TAU * 0.6)))
		envelope *= clampf((duracao - t) / 0.5, 0.0, 1.0)
		var amostra := tanh(dois * 14.0 * envelope) * 0.8
		dados.encode_s16(i * 2, int(amostra * 32767.0))
	return _wav(dados)

static func _wav(dados: PackedByteArray) -> AudioStreamWAV:
	var som := AudioStreamWAV.new()
	som.format = AudioStreamWAV.FORMAT_16_BITS
	som.mix_rate = TAXA
	som.stereo = false
	som.data = dados
	return som

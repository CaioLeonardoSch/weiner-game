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

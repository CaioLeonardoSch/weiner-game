extends Node
## Piloto automático de teste da Fase 05 (pastoreio): leva as ovelhas uma a uma até o cercado,
## ficando atrás delas em relação ao objetivo (como um jogador faria), atravessando o riacho
## pelo vau e latindo quando uma ovelha emperra. Conhece o mapa da Fase 05 (vau e cercado).

var jogo: Node
var alvo_atual: Node3D
var tempo := 0.0
var travado := 0.0
var ultima_dist := 999.0
var log_tempo := 0.0
var parado := 0.0
var desvio := 0.0
var desvio_dir := Vector3.ZERO
var ultima_pos := Vector3.ZERO

static func iniciar(j) -> String:
	var p = load("res://ferramentas/testes/piloto_fase_05.gd").new()
	p.jogo = j
	j.add_child(p)
	return "piloto ligado"

func _meta(pos: Vector3) -> Vector3:
	if pos.x < 8.0:
		return Vector3(8.5, 0, -5.0) if pos.x < 7.0 else Vector3(11.0, 0, -5.0)
	if pos.x < 18.3:
		return Vector3(18.5, 0, -5.0)
	return Vector3(21.0, 0, -5.0)

func _soltar() -> void:
	for a in ["mover_direita", "mover_esquerda", "mover_frente", "mover_tras"]:
		Input.action_release(a)

func _andar(d: Vector3) -> void:
	_soltar()
	d.y = 0
	if d.length() < 0.05:
		return
	d = d.normalized()
	if d.x > 0.05: Input.action_press("mover_direita", d.x)
	if d.x < -0.05: Input.action_press("mover_esquerda", -d.x)
	if d.z < -0.05: Input.action_press("mover_frente", -d.z)
	if d.z > 0.05: Input.action_press("mover_tras", d.z)

func _physics_process(delta: float) -> void:
	if jogo.concluida:
		_soltar()
		return
	tempo += delta
	var cachorro: Node3D = jogo.cachorro
	var livres: Array = jogo._ovelhas.filter(func(o): return not o.guardada)
	if livres.is_empty():
		_soltar()
		return
	# A ovelha mais longe do cercado (pelo caminho), para não espalhar as que já estão perto.
	if alvo_atual == null or alvo_atual.guardada:
		livres.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
		alvo_atual = livres[0]
		travado = 0.0
		ultima_dist = 999.0
	var ov: Vector3 = alvo_atual.global_position
	var meta := _meta(ov)
	var para_meta := (meta - ov)
	para_meta.y = 0
	var atras := ov - para_meta.normalized() * 1.5
	var dc := cachorro.global_position
	var do_ov := dc - ov
	do_ov.y = 0
	var desejado := atras - ov
	var ang := do_ov.angle_to(desejado)
	var dir: Vector3
	if ang > deg_to_rad(70) and do_ov.length() < 4.0:
		# Contorna a ovelha por fora (raio 3) pelo lado mais curto.
		var tangente := Vector3(-do_ov.z, 0, do_ov.x).normalized()
		if tangente.dot(desejado) < 0:
			tangente = -tangente
		dir = tangente + do_ov.normalized() * (3.0 - do_ov.length()) * 0.5
	elif (atras - dc).length() > 0.6 and do_ov.length() > 1.2:
		dir = atras - dc
	else:
		dir = para_meta.normalized()
	# Do outro lado do riacho: vai pelo vau.
	var vau := Vector3(8.5, 0, -5.0)
	var oeste_o := ov.x < 8.5
	var no_riacho := dc.x >= 7.5 and dc.x <= 9.9
	if no_riacho and absf(dc.z - vau.z) < 1.2:
		dir = Vector3(-1.0 if oeste_o else 1.0, 0, (vau.z - dc.z) * 2.0)
	elif no_riacho:
		dir = Vector3(0, 0, vau.z - dc.z)
	elif (dc.x < 8.5) != oeste_o:
		var entrada := Vector3(6.8 if dc.x < 8.5 else 10.2, 0, vau.z)
		if absf(dc.z - vau.z) < 0.5 and absf(dc.x - entrada.x) < 0.9:
			dir = Vector3(1.0 if dc.x < 8.5 else -1.0, 0, (vau.z - dc.z) * 2.0)
		else:
			dir = entrada - dc
	# Emperrado num obstáculo: dá um passo de lado por um tempinho.
	if desvio > 0.0:
		desvio -= delta
		dir = desvio_dir
	elif dc.distance_to(ultima_pos) < 0.02 and dir.length() > 0.1:
		parado += delta
		if parado > 0.4:
			parado = 0.0
			desvio = 0.8
			desvio_dir = Vector3(-dir.z, 0, dir.x).normalized() * (1.0 if randf() < 0.5 else -1.0) - dir.normalized() * 0.3
	else:
		parado = 0.0
	ultima_pos = dc
	_andar(dir)
	# Emperrou? Late.
	var dist := para_meta.length()
	if dist < ultima_dist - 0.05:
		ultima_dist = dist
		travado = 0.0
	else:
		travado += delta
	if travado > 3.0 and do_ov.length() < 3.0 and ang < deg_to_rad(40):
		jogo.cachorro.latir()
		travado = 0.0
		ultima_dist = 999.0
	log_tempo += delta
	if log_tempo > 10.0:
		log_tempo = 0.0
		print("t=%d guardadas=%d alvo=%s cachorro=%s" % [tempo, jogo._ovelhas.size() - livres.size(), ov.snapped(Vector3.ONE*0.1), dc.snapped(Vector3.ONE*0.1)])

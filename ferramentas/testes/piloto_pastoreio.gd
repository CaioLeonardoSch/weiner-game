extends Node
## Piloto automático de teste do pastoreio: leva as ovelhas uma a uma até a entrada do abrigo
## (cercado ou celeiro, porta no +X local), ficando atrás delas em relação ao objetivo (como um
## jogador faria) e latindo quando uma ovelha emperra. Serve para fases de terreno aberto (sem
## riacho no caminho). As teclas são em relação à câmera, como o jogador vê a tela.
##   chamar res://ferramentas/testes/piloto_pastoreio.gd iniciar

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


static func iniciar(j: Node) -> String:
	var p: Node = load("res://ferramentas/testes/piloto_pastoreio.gd").new()
	p.set(&"jogo", j)
	j.add_child(p)
	return "piloto ligado"


## O abrigo mais perto da ovelha.
func _abrigo(ovelha: Vector3) -> Node3D:
	var melhor: Node3D = null
	for abrigo: Node3D in jogo.objetivo.abrigos:
		if melhor == null or abrigo.global_position.distance_to(ovelha) < melhor.global_position.distance_to(ovelha):
			melhor = abrigo
	return melhor


## Para onde empurrar a ovelha: primeiro para a frente da porta; alinhada com ela, para dentro.
func _meta(ovelha: Vector3) -> Vector3:
	var abrigo := _abrigo(ovelha)
	var tamanho: Vector2i = abrigo.get(&"tamanho")
	var fora := abrigo.global_transform.basis.x.normalized()
	var porta := abrigo.global_position + fora * tamanho.x * 0.5
	var local := ovelha - porta
	local.y = 0.0
	var na_frente := local.dot(fora)
	var de_lado := (local - fora * na_frente).length()
	if na_frente > 0.3 and de_lado > 0.4:
		return porta + fora * 1.8
	return abrigo.global_position


func _soltar() -> void:
	for a: String in ["mover_direita", "mover_esquerda", "mover_frente", "mover_tras"]:
		Input.action_release(a)


func _andar(d: Vector3) -> void:
	_soltar()
	d.y = 0
	var camera: Camera3D = jogo.cachorro.get(&"camera_referencia")
	if d.length() < 0.05 or camera == null:
		return
	d = d.normalized()
	var direita := camera.global_basis.x
	direita.y = 0.0
	var frente := -camera.global_basis.z
	frente.y = 0.0
	var x := d.dot(direita.normalized())
	var y := d.dot(frente.normalized())
	if x > 0.05: Input.action_press("mover_direita", x)
	if x < -0.05: Input.action_press("mover_esquerda", -x)
	if y > 0.05: Input.action_press("mover_frente", y)
	if y < -0.05: Input.action_press("mover_tras", -y)


func _physics_process(delta: float) -> void:
	if jogo.concluida:
		_soltar()
		return
	tempo += delta
	var cachorro: Node3D = jogo.cachorro
	var livres: Array = jogo.objetivo.ovelhas.filter(func(o: Node) -> bool: return not o.get(&"guardada"))
	if livres.is_empty():
		_soltar()
		return
	# A ovelha mais longe do abrigo, para não espalhar as que já estão perto.
	if alvo_atual == null or alvo_atual.get(&"guardada"):
		livres.sort_custom(func(a: Node3D, b: Node3D) -> bool:
			return a.global_position.distance_to(_meta(a.global_position)) > b.global_position.distance_to(_meta(b.global_position)))
		alvo_atual = livres[0]
		travado = 0.0
		ultima_dist = 999.0
	var ov: Vector3 = alvo_atual.global_position
	var meta := _meta(ov)
	var para_meta := meta - ov
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
		print("t=%d guardadas=%d alvo=%s cachorro=%s" % [tempo, jogo.objetivo.ovelhas.size() - livres.size(), ov.snapped(Vector3.ONE * 0.1), dc.snapped(Vector3.ONE * 0.1)])

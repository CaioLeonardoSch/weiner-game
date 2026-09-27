extends SceneTree
## Roteiro de teste: joga uma fase com entradas simuladas e confere o resultado.
##
##   godot --headless --path . --fixed-fps 60 --script res://ferramentas/testes/roteiro.gd -- @rota.txt
##   godot --path . --script res://ferramentas/testes/roteiro.gd -- "fase res://...; esperar 20; ..."
##
## Passos separados por ";" ou por linha ("#" começa um comentário). "jogo" é a cena atual.
##   fase <caminho>          joga a fase
##   esperar N               espera N quadros (60 por segundo)
##   apertar <ação> [N]      segura a ação por N quadros (padrão 2) — não espera
##   teleportar x y z        põe o cachorro nesse ponto
##   eval <expressão>        mostra o valor
##   checar <expressão>      falha o teste se a expressão der falso
##   chamar <script> <func>  chama func(jogo) de um script (ex.: um piloto automático)
##   foto <arquivo.png>      salva a tela (não funciona com --headless)
##   cena <caminho>, mouse x y, clique b x y, segurar b x y 0|1, sair
## Sai com código 0 se todas as checagens passaram, 1 se alguma falhou.
## Nada é lido nem gravado nos arquivos do jogador: as opções são as de fábrica e o progresso
## fica só na memória. Se o save real (user://progresso.cfg) mudar durante o teste, é falha.

var _passos: PackedStringArray = []
var _i := 0
var _espera := 0
var _soltar := {}
var _eventos_depois: Array = []
var _falhas := 0
## Impressão digital do save real no começo (ver _encerrar).
var _save_antes := ""


func _initialize() -> void:
	for argumento in OS.get_cmdline_user_args():
		var texto := argumento
		if argumento.begins_with("@"):
			texto = FileAccess.get_file_as_string(argumento.substr(1))
		for linha in texto.split("\n"):
			for passo in linha.get_slice("#", 0).split(";", false):
				if not passo.strip_edges().is_empty():
					_passos.append(passo.strip_edges())
	# Testes sempre com as opções de fábrica (sem tela cheia, teclas padrão...) e sem tocar no
	# progresso do jogador (fases concluídas, pelagens).
	var opcoes := root.get_node_or_null("Opcoes")
	if opcoes and opcoes.has_method("usar_padrao_sem_salvar"):
		opcoes.usar_padrao_sem_salvar()
	var fases := root.get_node_or_null("Fases")
	if fases and fases.has_method("usar_progresso_em_memoria"):
		fases.usar_progresso_em_memoria()
	_save_antes = _impressao_do_save()
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))


func _process(_d: float) -> bool:
	for ev in _eventos_depois:
		Input.parse_input_event(ev)
	_eventos_depois.clear()
	for acao in _soltar.keys():
		_soltar[acao] -= 1
		if _soltar[acao] <= 0:
			var ev := InputEventAction.new()
			ev.action = acao
			ev.pressed = false
			Input.parse_input_event(ev)
			_soltar.erase(acao)
	if _espera > 0:
		_espera -= 1
		return false
	while _i < _passos.size():
		var p := _passos[_i].split(" ", false)
		_i += 1
		match p[0]:
			"esperar":
				_espera = int(p[1])
				return false
			"foto":
				root.get_texture().get_image().save_png(p[1])
				print("foto: ", p[1])
			"apertar":
				var ev := InputEventAction.new()
				ev.action = p[1]
				ev.pressed = true
				Input.parse_input_event(ev)
				_soltar[p[1]] = int(p[2]) if p.size() > 2 else 2
			"mouse":
				var m := InputEventMouseMotion.new()
				m.position = Vector2(float(p[1]), float(p[2]))
				m.global_position = m.position
				Input.warp_mouse(m.position)
				Input.parse_input_event(m)
			"clique":
				var b := InputEventMouseButton.new()
				b.button_index = int(p[1]) as MouseButton
				b.position = Vector2(float(p[2]), float(p[3]))
				b.global_position = b.position
				b.pressed = true
				Input.warp_mouse(b.position)
				Input.parse_input_event(b)
				var solta := b.duplicate()
				solta.pressed = false
				_eventos_depois.append(solta)
			"segurar":
				var b := InputEventMouseButton.new()
				b.button_index = int(p[1]) as MouseButton
				b.position = Vector2(float(p[2]), float(p[3]))
				b.global_position = b.position
				b.pressed = p[4] == "1"
				Input.warp_mouse(b.position)
				Input.parse_input_event(b)
			"teleportar":
				var c := current_scene.get_node("Dachshund") as CharacterBody3D
				c.global_position = Vector3(float(p[1]), float(p[2]), float(p[3]))
			"cena":
				change_scene_to_file(p[1])
				_espera = 5
				return false
			"eval":
				print("eval: ", _avaliar(" ".join(p.slice(1))))
			"checar":
				var expressao := " ".join(p.slice(1))
				var valor: Variant = _avaliar(expressao)
				if valor:
					print("ok: ", expressao)
				else:
					_falhas += 1
					print("FALHOU: ", expressao, " → ", valor)
			"chamar":
				print("chamar: ", load(p[1]).call(p[2], current_scene))
			"fase":
				root.get_node("Fases").jogar(p[1])
				_espera = 5
				return false
			"sair":
				_encerrar()
				return true
	_encerrar()
	return true


func _avaliar(texto: String) -> Variant:
	var e := Expression.new()
	if e.parse(texto, ["jogo"]) != OK:
		return "erro: " + e.get_error_text()
	return e.execute([current_scene], self)


func _impressao_do_save() -> String:
	return FileAccess.get_md5("user://progresso.cfg") if FileAccess.file_exists("user://progresso.cfg") else "-"


func _encerrar() -> void:
	if _impressao_do_save() != _save_antes:
		_falhas += 1
		print("FALHOU: o teste mexeu no save do jogador (user://progresso.cfg)")
	print("RESULTADO: ", "passou" if _falhas == 0 else "%d falha(s)" % _falhas)
	quit(1 if _falhas > 0 else 0)

extends Node
## Opções do jogador (autoload "Opcoes"): tela, gráficos, áudio e controles.
##
## Tudo fica em user://opcoes.cfg. `definir(secao, chave, valor)` muda, aplica e salva; quem
## depende de uma opção lê com `valor(secao, chave)` e escuta o sinal `mudou`.
## A tela das opções é montada em scripts/ui/tela_opcoes.gd.

signal mudou(secao: String, chave: String)

const ARQUIVO := "user://opcoes.cfg"

## Valores de fábrica.
const PADRAO := {
	"tela": {
		# "janela", "tela_cheia" (sem borda, na resolução do monitor) ou "exclusiva".
		"modo": "tela_cheia",
		"tamanho_janela": Vector2i(1600, 900),
		"vsync": true,
		# 0 = sem limite.
		"fps_max": 0,
		"escala_interface": 1.0,
	},
	"graficos": {
		# Linhas de pixel na vertical (menos = pixels maiores); 0 = sem pixelado.
		"pixel": 240,
		"contorno": true,
		# 0 = sem sombras, 1 = baixa, 2 = alta.
		"sombras": 2,
		"brilho": 1.0,
	},
	"audio": {
		"geral": 1.0,
		"musica": 0.8,
		"efeitos": 1.0,
		"ambiente": 0.8,
		"mudo": false,
	},
	"controles": {
		"sensibilidade": 1.0,
		"inverter_y": false,
	},
}

## Limites do tamanho da interface. O jogo inteiro já acompanha a resolução (base 1152 × 648
## esticada até a tela), então a escala é por cima disso: acima de 125% os menus (pausa,
## opções) não cabem mais na altura da tela 16:9. O editor de fases ignora a escala.
const ESCALA_MINIMA := 0.75
const ESCALA_MAXIMA := 1.25

## Barramentos de áudio que as opções controlam (criados se o projeto não tiver).
const BARRAMENTOS := {"geral": "Master", "musica": "Musica", "efeitos": "Efeitos", "ambiente": "Ambiente"}

var _config := ConfigFile.new()
## Eventos de fábrica de cada ação remapeável (para "restaurar padrão").
var _teclas_padrao := {}
## Sem salvar em disco (testes automáticos).
var _so_memoria := false


## Fechando o jogo: a fase sai da árvore antes dos autoloads e para os sons em laço. O
## AudioServer só solta um playback parado na mixagem seguinte (na thread de áudio), então
## espera um pouco antes de soltar os sons guardados: senão eles vazam ao sair.
func _exit_tree() -> void:
	OS.delay_msec(100)
	Som.limpar()


func _ready() -> void:
	for item in Teclas.REMAPEAVEIS:
		_teclas_padrao[item[0]] = InputMap.action_get_events(item[0])
	_criar_barramentos()
	if not _so_memoria:
		_config.load(ARQUIVO)
	get_tree().node_added.connect(_on_no_adicionado)
	aplicar_tudo()


## F11 (em qualquer tela): alterna entre janela e tela cheia, e guarda a escolha nas opções.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("tela_cheia") and not event.is_echo():
		var cheia := String(valor("tela", "modo")) != "janela"
		definir("tela", "modo", "janela" if cheia else "tela_cheia")
		get_viewport().set_input_as_handled()


## Opções de fábrica, sem ler nem gravar o arquivo (usado pelos testes automáticos).
func usar_padrao_sem_salvar() -> void:
	_so_memoria = true
	_config = ConfigFile.new()
	_config.set_value("tela", "modo", "janela")
	if is_inside_tree():
		aplicar_tudo()


func valor(secao: String, chave: String) -> Variant:
	return _config.get_value(secao, chave, PADRAO[secao][chave])


func definir(secao: String, chave: String, novo: Variant) -> void:
	_config.set_value(secao, chave, novo)
	_aplicar(secao, chave)
	salvar()
	mudou.emit(secao, chave)


func salvar() -> void:
	if not _so_memoria:
		_config.save(ARQUIVO)


func restaurar_secao(secao: String) -> void:
	if _config.has_section(secao):
		_config.erase_section(secao)
	if secao == "teclas":
		for acao in _teclas_padrao:
			_trocar_eventos(acao, _teclas_padrao[acao])
	else:
		for chave in PADRAO[secao]:
			_aplicar(secao, chave)
	salvar()
	mudou.emit(secao, "")


func aplicar_tudo() -> void:
	for secao in PADRAO:
		for chave in PADRAO[secao]:
			_aplicar(secao, chave)
	_aplicar_teclas()


# --- Teclas --------------------------------------------------------------------------------

## Troca a tecla principal (teclado/mouse) da ação; o controle continua como está.
## Se outra ação remapeável usava essa tecla, as duas trocam de tecla. Devolve a ação que
## trocou junto (ou &"").
func trocar_tecla(acao: StringName, evento: InputEvent) -> StringName:
	var antigo := _evento_principal(acao)
	var trocada := &""
	for item in Teclas.REMAPEAVEIS:
		var outra: StringName = item[0]
		if outra != acao and _mesma_tecla(_evento_principal(outra), evento):
			trocada = outra
			_definir_principal(outra, antigo)
	_definir_principal(acao, evento)
	salvar()
	mudou.emit("teclas", acao)
	return trocada


func _evento_principal(acao: StringName) -> InputEvent:
	for evento in InputMap.action_get_events(acao):
		if evento is InputEventKey or evento is InputEventMouseButton:
			return evento
	return null


func _definir_principal(acao: StringName, evento: InputEvent) -> void:
	var eventos := InputMap.action_get_events(acao)
	var indice := -1
	for i in eventos.size():
		if eventos[i] is InputEventKey or eventos[i] is InputEventMouseButton:
			indice = i
			break
	if evento == null:
		if indice >= 0:
			eventos.remove_at(indice)
	elif indice >= 0:
		eventos[indice] = evento
	else:
		eventos.insert(0, evento)
	_trocar_eventos(acao, eventos)
	_config.set_value("teclas", String(acao), var_to_str(eventos.filter(
		func(e: InputEvent) -> bool: return e is InputEventKey or e is InputEventMouseButton)))


func _trocar_eventos(acao: StringName, eventos: Array) -> void:
	InputMap.action_erase_events(acao)
	for evento in eventos:
		InputMap.action_add_event(acao, evento)


func _aplicar_teclas() -> void:
	for item in Teclas.REMAPEAVEIS:
		var acao: StringName = item[0]
		var eventos: Array = _teclas_padrao[acao].duplicate()
		if _config.has_section_key("teclas", String(acao)):
			var salvos: Variant = str_to_var(_config.get_value("teclas", String(acao)))
			if salvos is Array:
				# Troca os de teclado/mouse de fábrica pelos salvos; mantém os do controle.
				eventos = eventos.filter(func(e: InputEvent) -> bool:
					return not (e is InputEventKey or e is InputEventMouseButton))
				for i in (salvos as Array).size():
					eventos.insert(i, salvos[i])
		_trocar_eventos(acao, eventos)


static func _mesma_tecla(a: InputEvent, b: InputEvent) -> bool:
	if a == null or b == null:
		return false
	if a is InputEventKey and b is InputEventKey:
		var ka := a as InputEventKey
		var kb := b as InputEventKey
		return (ka.physical_keycode != KEY_NONE and ka.physical_keycode == kb.physical_keycode) \
			or (ka.keycode != KEY_NONE and ka.keycode == kb.keycode)
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return (a as InputEventMouseButton).button_index == (b as InputEventMouseButton).button_index
	return false


# --- Aplicar -------------------------------------------------------------------------------

func _aplicar(secao: String, chave: String) -> void:
	var v: Variant = valor(secao, chave)
	match [secao, chave]:
		["tela", "modo"], ["tela", "tamanho_janela"]:
			_aplicar_janela()
		["tela", "vsync"]:
			if _tem_janela():
				DisplayServer.window_set_vsync_mode(
					DisplayServer.VSYNC_ENABLED if v else DisplayServer.VSYNC_DISABLED)
		["tela", "fps_max"]:
			Engine.max_fps = int(v)
		["tela", "escala_interface"]:
			aplicar_escala()
		["graficos", "pixel"], ["graficos", "contorno"]:
			var visual := get_node_or_null(^"/root/Visual")
			if visual:
				visual.configurar(int(valor("graficos", "pixel")), bool(valor("graficos", "contorno")))
		["graficos", "sombras"]:
			RenderingServer.directional_shadow_atlas_set_size(2048 if int(v) == 1 else 4096, true)
			for luz in get_tree().root.find_children("*", "DirectionalLight3D", true, false):
				_aplicar_sombra(luz as DirectionalLight3D)
		["graficos", "brilho"]:
			for ambiente in get_tree().root.find_children("*", "WorldEnvironment", true, false):
				_aplicar_brilho(ambiente as WorldEnvironment)
		["audio", _]:
			_aplicar_audio()
		["controles", _]:
			pass  # A câmera lê direto (valor()).


## Aplica o tamanho da interface (dentro dos limites). `ignorar`: usa 100% (editor de fases).
func aplicar_escala(ignorar := false) -> void:
	var escala := clampf(float(valor("tela", "escala_interface")), ESCALA_MINIMA, ESCALA_MAXIMA)
	get_tree().root.content_scale_factor = 1.0 if ignorar else escala


func _tem_janela() -> bool:
	return DisplayServer.get_name() != "headless"


func _aplicar_janela() -> void:
	if not _tem_janela():
		return
	var janela := get_window()
	match String(valor("tela", "modo")):
		"exclusiva":
			janela.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		"tela_cheia":
			janela.mode = Window.MODE_FULLSCREEN
		_:
			if janela.mode != Window.MODE_WINDOWED:
				janela.mode = Window.MODE_WINDOWED
			var tela := DisplayServer.screen_get_usable_rect(janela.current_screen)
			var tamanho: Vector2i = valor("tela", "tamanho_janela")
			tamanho = tamanho.min(tela.size)
			janela.size = tamanho
			janela.position = tela.position + (tela.size - tamanho) / 2


func _aplicar_audio() -> void:
	for chave in BARRAMENTOS:
		var indice := AudioServer.get_bus_index(BARRAMENTOS[chave])
		if indice < 0:
			continue
		var volume := float(valor("audio", chave))
		AudioServer.set_bus_volume_db(indice, linear_to_db(maxf(volume, 0.0001)))
		AudioServer.set_bus_mute(indice, volume <= 0.001)
	AudioServer.set_bus_mute(0, bool(valor("audio", "mudo")) or float(valor("audio", "geral")) <= 0.001)


func _criar_barramentos() -> void:
	for chave in BARRAMENTOS:
		var nome_barramento: String = BARRAMENTOS[chave]
		if AudioServer.get_bus_index(nome_barramento) < 0:
			AudioServer.add_bus()
			var indice := AudioServer.bus_count - 1
			AudioServer.set_bus_name(indice, nome_barramento)
			AudioServer.set_bus_send(indice, "Master")


## Luzes e ambientes que entram em cena (a cada troca de cena) já recebem as opções.
func _on_no_adicionado(no: Node) -> void:
	if no is DirectionalLight3D:
		_aplicar_sombra(no)
	elif no is WorldEnvironment:
		_aplicar_brilho(no)


func _aplicar_sombra(luz: DirectionalLight3D) -> void:
	luz.shadow_enabled = int(valor("graficos", "sombras")) > 0


func _aplicar_brilho(ambiente: WorldEnvironment) -> void:
	if ambiente.environment == null:
		return
	var brilho := float(valor("graficos", "brilho"))
	ambiente.environment.adjustment_enabled = not is_equal_approx(brilho, 1.0)
	ambiente.environment.adjustment_brightness = brilho

class_name Teclas
## Nomes das teclas atuais de cada ação (as teclas podem ser trocadas nas Opções), para os
## textos do jogo nunca dizerem uma tecla errada: `Teclas.nome("virar_graveto")` → "Q".

## Ações que o jogador pode trocar nas Opções, na ordem da tela, com o nome mostrado.
const REMAPEAVEIS := [
	[&"mover_frente", "Andar para cima / frente"],
	[&"mover_tras", "Andar para baixo / trás"],
	[&"mover_esquerda", "Andar para a esquerda"],
	[&"mover_direita", "Andar para a direita"],
	[&"pular", "Pular"],
	[&"acao", "Ação (morder, puxar, pegar)"],
	[&"largar_graveto", "Largar o graveto"],
	[&"virar_graveto", "Virar o graveto"],
	[&"andar_devagar", "Andar devagar"],
	[&"correr", "Correr"],
	[&"cavar", "Cavar"],
	[&"latir", "Latir"],
	[&"reiniciar", "Reiniciar a fase"],
	[&"alternar_editor", "Abrir o editor de fases"],
	[&"alternar_pixel", "Liga/desliga o pixelado"],
]


## Nome da primeira tecla (ou botão do mouse) da ação, ex.: "Q", "Espaço", "Mouse esq.".
static func nome(acao: StringName) -> String:
	if not InputMap.has_action(acao):
		return "?"
	for evento in InputMap.action_get_events(acao):
		var texto := nome_do_evento(evento)
		if not texto.is_empty():
			return texto
	return "—"


## Texto de um evento de teclado ou mouse ("" para outros, como o controle).
static func nome_do_evento(evento: InputEvent) -> String:
	if evento is InputEventKey:
		var tecla := evento as InputEventKey
		var codigo := tecla.keycode
		if codigo == KEY_NONE and tecla.physical_keycode != KEY_NONE:
			# Tecla física: mostra o que está impresso nela no teclado do jogador (sem janela,
			# como nos testes automáticos, fica o nome da posição no teclado americano).
			codigo = tecla.physical_keycode
			if DisplayServer.get_name() != "headless":
				codigo = DisplayServer.keyboard_get_keycode_from_physical(codigo)
		return _traduzir(OS.get_keycode_string(codigo))
	if evento is InputEventMouseButton:
		match (evento as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT: return "Mouse esq."
			MOUSE_BUTTON_RIGHT: return "Mouse dir."
			MOUSE_BUTTON_MIDDLE: return "Mouse meio"
			_: return "Mouse %d" % (evento as InputEventMouseButton).button_index
	return ""


const _NOMES := {
	"Space": "Espaço", "Escape": "Esc", "Enter": "Enter", "Shift": "Shift", "Ctrl": "Ctrl",
	"Alt": "Alt", "Tab": "Tab", "Backspace": "Backspace", "Up": "↑", "Down": "↓",
	"Left": "←", "Right": "→",
}


static func _traduzir(texto: String) -> String:
	return _NOMES.get(texto, texto)

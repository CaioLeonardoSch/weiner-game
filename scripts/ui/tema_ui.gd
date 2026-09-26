class_name TemaUI
## Tema da interface dos menus (menu principal, pausa): botões chapados, sem cantos
## arredondados, com borda amarela no foco (teclado/controle).

const COR_DESTAQUE := Color(1, 0.92, 0.5)


static func criar() -> Theme:
	var tema := Theme.new()
	tema.default_font_size = 20

	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(0.09, 0.1, 0.12, 0.9)
	tema.set_stylebox("panel", "PanelContainer", fundo)

	var cores := {
		normal = Color(0.18, 0.2, 0.23),
		hover = Color(0.25, 0.42, 0.26),
		pressed = Color(0.2, 0.34, 0.21),
		focus = Color(0, 0, 0, 0),
		disabled = Color(0.14, 0.15, 0.17),
	}
	for estado: String in cores:
		var caixa := StyleBoxFlat.new()
		caixa.bg_color = cores[estado]
		caixa.set_content_margin_all(10)
		caixa.content_margin_left = 16
		caixa.border_color = Color(0.05, 0.05, 0.06)
		caixa.set_border_width_all(2)
		if estado == "focus":
			caixa.border_color = COR_DESTAQUE
			caixa.set_border_width_all(3)
		elif estado == "hover":
			caixa.border_color = Color(0.45, 0.7, 0.4)
		tema.set_stylebox(estado, "Button", caixa)
	tema.set_color("font_color", "Button", Color(0.93, 0.93, 0.9))
	tema.set_color("font_hover_color", "Button", Color.WHITE)
	tema.set_color("font_focus_color", "Button", Color.WHITE)
	tema.set_color("font_disabled_color", "Button", Color(0.5, 0.5, 0.5))
	tema.set_constant("h_separation", "Button", 10)
	return tema

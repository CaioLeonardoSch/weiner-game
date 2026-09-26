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
		for tipo in ["Button", "OptionButton"]:
			tema.set_stylebox(estado, tipo, caixa)
	for tipo in ["Button", "OptionButton", "CheckBox"]:
		tema.set_color("font_color", tipo, Color(0.93, 0.93, 0.9))
		tema.set_color("font_hover_color", tipo, Color.WHITE)
		tema.set_color("font_focus_color", tipo, Color.WHITE)
		tema.set_color("font_pressed_color", tipo, Color.WHITE)
		tema.set_color("font_disabled_color", tipo, Color(0.5, 0.5, 0.5))
	tema.set_constant("h_separation", "Button", 10)

	# Abas (tela de opções).
	var painel_abas := StyleBoxFlat.new()
	painel_abas.bg_color = Color(0.12, 0.13, 0.15, 0.95)
	painel_abas.set_content_margin_all(18)
	tema.set_stylebox("panel", "TabContainer", painel_abas)
	var abas := {
		tab_selected = Color(0.12, 0.13, 0.15, 0.95),
		tab_unselected = Color(0.08, 0.09, 0.1, 0.9),
		tab_hovered = Color(0.2, 0.3, 0.2, 0.95),
		tab_focus = Color(0, 0, 0, 0),
	}
	for estado: String in abas:
		var aba := StyleBoxFlat.new()
		aba.bg_color = abas[estado]
		aba.set_content_margin_all(10)
		aba.content_margin_left = 20
		aba.content_margin_right = 20
		if estado == "tab_selected":
			aba.border_color = COR_DESTAQUE
			aba.border_width_top = 3
		elif estado == "tab_focus":
			aba.draw_center = false
			aba.border_color = COR_DESTAQUE
			aba.set_border_width_all(2)
		tema.set_stylebox(estado, "TabBar", aba)
	tema.set_color("font_selected_color", "TabBar", COR_DESTAQUE)
	tema.set_color("font_unselected_color", "TabBar", Color(0.75, 0.77, 0.75))
	tema.set_color("font_hovered_color", "TabBar", Color.WHITE)
	return tema

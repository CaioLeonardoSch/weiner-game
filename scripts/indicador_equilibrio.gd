extends Control
## Barra de equilíbrio do HUD: aparece quando o cachorro balança numa passagem estreita.
## O marcador mostra para que lado ele está pendendo; perto das pontas fica vermelho.

var cachorro: Dachshund


func _process(_delta: float) -> void:
	var ativo := cachorro != null and cachorro.em_passagem_estreita and absf(cachorro.balanco) > 0.02
	modulate.a = move_toward(modulate.a, 1.0 if ativo else 0.0, _delta * 4.0)
	visible = modulate.a > 0.0
	if visible:
		queue_redraw()


func _draw() -> void:
	if cachorro == null:
		return
	var largura := size.x
	var altura := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(Vector2(largura * 0.5 - 1, 0), Vector2(2, altura)), Color(1, 1, 1, 0.5))
	var valor := clampf(cachorro.balanco, -1.0, 1.0)
	var cor := Color(0.5, 1.0, 0.5).lerp(Color(1.0, 0.3, 0.25), absf(valor))
	var x := largura * 0.5 + valor * (largura * 0.5 - 6.0)
	draw_rect(Rect2(Vector2(x - 5, 2), Vector2(10, altura - 4)), cor)
	var fonte := get_theme_default_font()
	draw_string_outline(fonte, Vector2(0, -6), "Equilíbrio", HORIZONTAL_ALIGNMENT_CENTER, largura, 16, 4, Color.BLACK)
	draw_string(fonte, Vector2(0, -6), "Equilíbrio", HORIZONTAL_ALIGNMENT_CENTER, largura, 16, Color.WHITE)

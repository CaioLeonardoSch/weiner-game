class_name IndicadorCalor
extends Control
## Termômetro do HUD nas fases com frio: a barra vai do azul (gelado) ao laranja (quentinho) e
## pisca quando está quase gelando. Perto do fogo mostra uma chaminha.

var cachorro: Dachshund
var _tempo := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(220, 22)


func _process(delta: float) -> void:
	_tempo += delta
	visible = cachorro != null and cachorro.sente_frio
	if visible:
		queue_redraw()


func _draw() -> void:
	var largura := size.x
	var altura := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
	var valor := clampf(cachorro.calor, 0.0, 1.0)
	var cor := Color(0.45, 0.7, 1.0).lerp(Color(1.0, 0.6, 0.2), valor)
	if valor < 0.25 and fmod(_tempo, 0.6) < 0.3:
		cor = Color(0.85, 0.95, 1.0)
	draw_rect(Rect2(Vector2(2, 2), Vector2((largura - 4) * valor, altura - 4)), cor)
	var fonte := get_theme_default_font()
	var texto := "Calor  🔥" if cachorro.aquecendo else ("Calor  ❄ Brrr!" if valor < 0.25 else "Calor")
	draw_string_outline(fonte, Vector2(0, -6), texto, HORIZONTAL_ALIGNMENT_CENTER, largura, 16, 4, Color.BLACK)
	draw_string(fonte, Vector2(0, -6), texto, HORIZONTAL_ALIGNMENT_CENTER, largura, 16, Color.WHITE)

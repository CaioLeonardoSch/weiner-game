class_name IndicadorCalor
extends Control
## Termômetro do HUD nas fases com frio: a barra vai do azul (gelado) ao laranja (quentinho) e
## pisca quando está quase gelando. Perto do fogo mostra uma chaminha.

var cachorro: Dachshund
var _tempo := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(250, 40)


func _process(delta: float) -> void:
	_tempo += delta
	visible = cachorro != null and cachorro.sente_frio
	if visible:
		queue_redraw()


func _draw() -> void:
	var valor := clampf(cachorro.calor, 0.0, 1.0)
	var cor := Color("6fb0ea").lerp(Color("f08a2c"), valor)
	if valor < 0.25 and fmod(_tempo, 0.6) < 0.3:
		cor = Color(0.85, 0.95, 1.0)
	var texto := "Calor 🔥" if cachorro.aquecendo else ("Brrr!" if valor < 0.25 else "Calor")
	Coleira.desenhar_medidor(self, texto, valor, cor, false)

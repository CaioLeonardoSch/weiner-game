extends Control
## Barra de equilíbrio do HUD: aparece quando o cachorro balança numa passagem estreita.
## O marcador mostra para que lado ele está pendendo; perto das pontas fica vermelho. Uma
## pílula do estilo Coleira (ver scripts/ui/coleira.gd).

var cachorro: Dachshund


func _ready() -> void:
	# Começa escondida (senão aparece por um instante ao abrir a fase).
	modulate.a = 0.0
	visible = false


func _process(_delta: float) -> void:
	var ativo := cachorro != null and cachorro.em_passagem_estreita and absf(cachorro.balanco) > 0.02
	modulate.a = move_toward(modulate.a, 1.0 if ativo else 0.0, _delta * 4.0)
	visible = modulate.a > 0.0
	if visible:
		queue_redraw()


func _draw() -> void:
	if cachorro == null:
		return
	var valor := clampf(cachorro.balanco, -1.0, 1.0)
	var cor := Color("3f8f3a").lerp(Coleira.VERMELHO, absf(valor))
	Coleira.desenhar_medidor(self, "Equilíbrio", 0.5 + valor * 0.5, cor, true)

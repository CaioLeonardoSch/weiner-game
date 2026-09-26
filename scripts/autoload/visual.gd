extends Node
## Visual pixelado do jogo (autoload "Visual").
##
## O 3D é renderizado numa resolução baixa e ampliado sem filtro (vizinho mais próximo);
## a interface (HUD, editor) continua na resolução da janela, nítida.
## `alternar_pixel` (F3) liga/desliga para comparar.

signal mudou

## Quantas linhas de pixel, aproximadamente, a imagem 3D tem na vertical.
## Menor = mais pixelado. O tamanho do pixel é sempre um número inteiro de pixels da tela.
const LINHAS_ALVO := 240

var pixelado := true
## Contorno escuro nas silhuetas e realce claro nas quinas (ver shaders/contorno_pixel.gdshader).
var contorno := true


func _ready() -> void:
	get_tree().root.size_changed.connect(_aplicar)
	_aplicar()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("alternar_pixel"):
		pixelado = not pixelado
		_aplicar()
		get_viewport().set_input_as_handled()


## Quantos pixels da tela cada pixel do jogo ocupa (em cada eixo).
func tamanho_pixel() -> int:
	if not pixelado:
		return 1
	return maxi(1, roundi(float(get_tree().root.size.y) / LINHAS_ALVO))


## Altura, em pixels, da imagem 3D renderizada.
func altura_interna() -> float:
	return floorf(float(get_tree().root.size.y) / tamanho_pixel())


func contorno_ativo() -> bool:
	return pixelado and contorno


func _aplicar() -> void:
	var raiz := get_tree().root
	raiz.scaling_3d_mode = Viewport.SCALING_3D_MODE_NEAREST
	raiz.scaling_3d_scale = 1.0 / tamanho_pixel()
	mudou.emit()

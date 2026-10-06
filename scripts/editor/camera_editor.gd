class_name CameraEditor
extends Node3D
## Câmera livre do editor de fases: orbita em volta de um foco.
## WASD/setas movem o foco; botão do meio orbita (com Shift, arrasta); roda dá zoom.
## Na visão isométrica fica ortográfica e travada, vista de cima.

@export var sensibilidade_orbita := 0.006
@export var velocidade := 12.0
@export var distancia_min := 3.0
@export var distancia_max := 80.0
@export var fov := 50.0

var foco := Vector3.ZERO
var distancia := 22.0
var yaw := 0.0
var pitch := deg_to_rad(-65.0)
## Visão isométrica: ortográfica, travada, vista de cima.
var isometrica := false

@onready var camera: Camera3D = $Camera3D


func _process(delta: float) -> void:
	if not Input.is_action_pressed("editor_mod_ctrl") and not _digitando():
		var entrada := Input.get_vector("mover_esquerda", "mover_direita", "mover_frente", "mover_tras")
		var direita := Vector3(cos(yaw), 0.0, -sin(yaw))
		var tras := Vector3(sin(yaw), 0.0, cos(yaw))
		foco += (direita * entrada.x + tras * entrada.y) * velocidade * delta * (distancia / 22.0)
	_aplicar()


## Um campo de texto (nome da fase, painel de propriedades) está com o foco: WASD e as
## setas são do texto. (O estado das ações muda mesmo quando a interface usa a tecla.)
func _digitando() -> bool:
	var foco := get_viewport().gui_get_focus_owner()
	return foco is LineEdit or foco is TextEdit


func orbitar(relativo: Vector2) -> void:
	if isometrica:
		return
	yaw = wrapf(yaw - relativo.x * sensibilidade_orbita, -PI, PI)
	pitch = clampf(pitch - relativo.y * sensibilidade_orbita, deg_to_rad(-89.0), deg_to_rad(-5.0))


## Arrasta o foco junto com o mouse (movimento em pixels da tela).
func arrastar(relativo: Vector2) -> void:
	var escala := distancia * 0.0016
	var direita := Vector3(cos(yaw), 0.0, -sin(yaw))
	var tras := Vector3(sin(yaw), 0.0, cos(yaw))
	foco -= (direita * relativo.x + tras * relativo.y) * escala


func zoom(fator: float) -> void:
	distancia = clampf(distancia * fator, distancia_min, distancia_max)


func estado() -> Dictionary:
	return {foco = foco, distancia = distancia, yaw = yaw, pitch = pitch}


func restaurar(dados: Dictionary) -> void:
	foco = dados.get("foco", foco)
	distancia = dados.get("distancia", distancia)
	yaw = dados.get("yaw", yaw)
	pitch = dados.get("pitch", pitch)


func _aplicar() -> void:
	var y := 0.0 if isometrica else yaw
	var p := deg_to_rad(-55.0) if isometrica else pitch
	var base := Basis.from_euler(Vector3(p, y, 0.0))
	if isometrica:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		# Mesmo enquadramento da câmera do jogo com o zoom padrão (22 → 11 m de altura).
		camera.size = distancia * 0.5
		camera.global_transform = Transform3D(base, foco + base.z * 60.0)
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = fov
		camera.global_transform = Transform3D(base, foco + base.z * distancia)

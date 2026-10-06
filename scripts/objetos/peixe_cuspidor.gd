@tool
class_name PeixeCuspidor
extends Bicho
## Peixe-cuspidor: nada logo abaixo da superfície, até `raio` m de onde foi colocado; parado, sobe
## e cospe um jato de água para cima (`cuspir`). Derrubar frutas e insetos e reagir ao latido
## ainda vão ser encaixados (ver docs/DESIGN.md, "Personagens que voltam").

## Altura (m, acima da água) do cuspe quando ele cospe à toa.
@export_range(0.5, 4.0, 0.1) var altura_cuspe := 1.5

## Quantas vezes já cuspiu (para as rotas de teste).
var cuspes := 0
var _cuspiu_nesta_pausa := false


func nome_no_editor() -> String:
	return "Peixe-cuspidor"


func propriedades_editaveis() -> Array[StringName]:
	return [&"raio", &"altura_cuspe"]


func meio() -> Meio:
	return Meio.AGUA


func velocidade() -> float:
	return 1.4


func pausa() -> Vector2:
	return Vector2(1.5, 3.0)


## Um palmo abaixo da superfície; parado, sobe até a boca ficar de fora.
func altura_em(ponto: Vector3) -> float:
	var superficie := superficie_agua(ponto)
	if is_nan(superficie):
		return 0.0
	return superficie - global_position.y - (0.25 if estado == Estado.ANDANDO else 0.08)


func _process(delta: float) -> void:
	super(delta)
	if Engine.is_editor_hint() or bicho == null:
		return
	if estado == Estado.ANDANDO:
		_cuspiu_nesta_pausa = false
		return
	# Parado: sobe até a superfície e cospe uma vez.
	var y := global_position.y + altura_em(bicho.global_position)
	bicho.global_position.y = lerpf(bicho.global_position.y, y, 1.0 - exp(-5.0 * delta))
	if not _cuspiu_nesta_pausa and absf(bicho.global_position.y - y) < 0.03:
		_cuspiu_nesta_pausa = true
		var boca := _boca()
		cuspir(boca + Vector3.UP * altura_cuspe)


## Cospe um jato de água da boca até `alvo`, num arco, e a água cai de volta.
func cuspir(alvo: Vector3) -> void:
	cuspes += 1
	var de := _boca()
	var gota := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 0.05
	esfera.height = 0.1
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.7, 0.88, 1.0, 0.85)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	esfera.material = material
	gota.mesh = esfera
	add_child(gota)
	gota.global_position = de
	var arco := func(t: float) -> void:
		gota.global_position = de.lerp(alvo, t) + Vector3.UP * 1.2 * t * (1.0 - t)
	var tween := create_tween()
	tween.tween_method(arco, 0.0, 1.0, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(gota, "global_position:y", de.y - 0.1, 0.4) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(gota.queue_free)


func _boca() -> Vector3:
	return bicho.global_position + bicho.global_basis.x * 0.22 + Vector3.UP * 0.08


func _animar(_delta: float, andando: bool) -> void:
	var modelo := bicho.get_node(^"Modelo") as Node3D
	# O rabo abana nadando; parado, devagar. Parado, o corpo se inclina para cima (cuspindo).
	(modelo.get_node(^"Rabo") as Node3D).rotation.y = sin(tempo * (14.0 if andando else 4.0)) * 0.45
	var inclinacao := 0.0 if andando else 0.5
	modelo.rotation.z = lerpf(modelo.rotation.z, inclinacao, 0.1)


## Peixe prateado com o dorso azul, boca de bico (para cuspir) e rabo em leque.
func _montar_modelo() -> Node3D:
	var modelo := Node3D.new()
	var corpo := {}
	for x in range(-3, 4):
		var meia := 2 if absi(x) <= 1 else 1
		for y in range(-meia + 2, meia + 3):
			for z in range(-1, 2):
				corpo[Vector3i(x, y, z)] = Color("3f6f9a") if y >= 3 else Color("c8d2d8")
	caixa(corpo, Vector3i(4, 2, 0), Vector3i(5, 2, 0), Color("a0aab0"))
	corpo[Vector3i(2, 3, -1)] = Color("101418")
	corpo[Vector3i(2, 3, 1)] = Color("101418")
	corpo[Vector3i(0, 5, 0)] = Color("2f5577")
	corpo[Vector3i(-1, 5, 0)] = Color("2f5577")
	peca(modelo, "Corpo", corpo)
	var rabo := {}
	for y in range(-2, 3):
		rabo[Vector3i(-1 - absi(y) / 2, y, 0)] = Color("3f6f9a")
		rabo[Vector3i(-1, y, 0)] = Color("3f6f9a")
	peca(modelo, "Rabo", rabo, Vector3(-3, 2.5, 0.5))
	return modelo

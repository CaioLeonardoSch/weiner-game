@tool
class_name TroncoSemicaido
extends Travessia
## Tronco semicaído atravessado no caminho (ao longo do X local): uma ponta no chão, a outra
## apoiada numa pedra. Embaixo do meio sobra um vão baixo: andando não passa; com F o cachorro
## rasteja por baixo, de um lado (-Z) ao outro (+Z).

## Comprimento (m) do tronco: cubra a largura do caminho.
@export_range(2.0, 8.0, 0.5) var comprimento := 4.0:
	set(valor):
		comprimento = valor
		_montar()

const RAIO := 0.2
## Altura (m) da parte de baixo do tronco no meio: o vão por onde o cachorro rasteja.
const VAO := 0.32
const COR_TRONCO := Color(0.42, 0.29, 0.17)
const COR_PEDRA := Color(0.5, 0.5, 0.48)
## Velocidade (m/s) rastejando.
const VELOCIDADE_RASTEJANDO := 0.8


func nome_no_editor() -> String:
	return "Tronco semicaído (rastejar)"


func propriedades_editaveis() -> Array[StringName]:
	return [&"comprimento"]


func caixa_editor() -> AABB:
	return AABB(Vector3(-comprimento * 0.5, 0, -0.4), Vector3(comprimento, 1.0, 0.8))


func _ready() -> void:
	super()
	_montar()


func caminho_local() -> PackedVector3Array:
	return PackedVector3Array([Vector3(0, 0, -1.0), Vector3(0, 0, -0.45), Vector3(0, 0, 0.45),
		Vector3(0, 0, 1.0)])


func _montar() -> void:
	if not is_node_ready():
		return
	_limpar()
	# A ponta -X no chão; a +X na pedra. No meio (x = 0), a parte de baixo fica a VAO do chão.
	var baixo := Vector3(-comprimento * 0.5, RAIO, 0.0)
	var meio := Vector3(0.0, VAO + RAIO, 0.0)
	var alto := baixo + (meio - baixo) * 2.0
	var tronco := MeshInstance3D.new()
	var cilindro := CylinderMesh.new()
	cilindro.top_radius = RAIO
	cilindro.bottom_radius = RAIO * 1.1
	cilindro.height = comprimento
	cilindro.radial_segments = 8
	cilindro.material = Travessia.material(COR_TRONCO)
	tronco.mesh = cilindro
	var eixo := (alto - baixo).normalized()
	tronco.transform = Transform3D(Basis(Quaternion(Vector3.UP, eixo)), (baixo + alto) * 0.5)
	add_child(tronco)
	var pedra := MeshInstance3D.new()
	var bloco := BoxMesh.new()
	bloco.size = Vector3(0.7, alto.y - RAIO, 0.8)
	bloco.material = Travessia.material(COR_PEDRA)
	pedra.mesh = bloco
	pedra.position = Vector3(alto.x - 0.1, bloco.size.y * 0.5, 0.0)
	add_child(pedra)
	# Sólido do chão até o tronco: andando ninguém passa (rastejando, a colisão desliga).
	Travessia.caixa_solida(self, Vector3(comprimento, 1.0, 0.5), Vector3(0.0, 0.5, 0.0))


func _animar(cachorro: Dachshund, pontos: PackedVector3Array) -> void:
	var yaw := Travessia.yaw_para(pontos[3] - pontos[0])
	var ate_o_tronco := cachorro.global_position.distance_to(pontos[0]) + pontos[0].distance_to(pontos[1])
	await cachorro.atravessar(PackedVector3Array([pontos[0], pontos[1]]), maxf(ate_o_tronco / 2.0, 0.2), yaw)
	await _abaixar(cachorro, 0.65)
	await cachorro.atravessar(PackedVector3Array([pontos[2]]),
		pontos[1].distance_to(pontos[2]) / VELOCIDADE_RASTEJANDO, yaw)
	_abaixar(cachorro, 0.0)
	await cachorro.atravessar(PackedVector3Array([pontos[3]]), pontos[2].distance_to(pontos[3]) / 2.0, yaw)


## Abaixa (patas dobradas, barriga perto do chão) ou levanta. Aguarde com `await`.
func _abaixar(cachorro: Dachshund, quanto: float) -> void:
	var tween := create_tween()
	tween.tween_property(cachorro.voxel, "deitado", quanto, 0.25)
	await tween.finished

@tool
class_name TroncoCaido
extends ObjetoFase
## Tronco caído (`comprimento` m, deitado ao longo do X local, centrado). Normalmente é um obstáculo no chão. Com
## `pinguela`, está atravessado sobre um vão (riacho, buraco), com o topo quase rente ao chão
## das margens: dá para passar por cima — é uma passagem estreita, com o equilíbrio da Tábua.

@export var pinguela := false:
	set(valor):
		pinguela = valor
		_atualizar()
## Comprimento (m). O modelo de 2 m é esticado repetindo a casca do meio (as pontas cortadas ficam).
@export_range(2, 6) var comprimento := 2:
	set(valor):
		comprimento = valor
		_atualizar()

const ALTURA := 0.375
## Meia largura do topo, para o equilíbrio (o tronco é redondo: o topo é estreito).
const MEIA_LARGURA := 0.16
const ARQUIVO := "res://assets/voxel/tronco_caido.txt"

## Malhas por comprimento (o de 2 m é o próprio arquivo).
static var _malhas := {}


func nome_no_editor() -> String:
	return "Tronco caído"


func propriedades_editaveis() -> Array[StringName]:
	return [&"pinguela", &"comprimento"]


func caixa_editor() -> AABB:
	return AABB(Vector3(-comprimento * 0.5, 0, -0.25), Vector3(comprimento, ALTURA, 0.5))


func _ready() -> void:
	_atualizar()


func _atualizar() -> void:
	if not is_node_ready():
		return
	# Pinguela: afundado no vão, topo 3 cm acima das margens (mais alto seria um degrau).
	var descida := -(ALTURA - 0.03) if pinguela else 0.0
	($Modelo as Node3D).position.y = descida
	($Corpo as Node3D).position.y = descida
	($Modelo as MeshInstance3D).mesh = TroncoCaido.malha(comprimento)
	var colisao := $Corpo/Colisao as CollisionShape3D
	var forma := colisao.shape as BoxShape3D
	if not is_equal_approx(forma.size.x, comprimento):
		forma = forma.duplicate()
		forma.size.x = comprimento
		colisao.shape = forma
	if Engine.is_editor_hint():
		return
	if pinguela:
		add_to_group(&"passagens_estreitas")
	else:
		remove_from_group(&"passagens_estreitas")


## Dados de passagem estreita (ver Fase.passagem_estreita_em) se `posicao` está sobre o tronco.
func passagem_em(posicao: Vector3) -> Dictionary:
	if not pinguela:
		return {}
	var local := to_local(posicao)
	if absf(local.x) > comprimento * 0.5 or absf(local.z) > 0.6 or local.y < -0.4 or local.y > 0.9:
		return {}
	var lado := global_basis.z
	lado.y = 0.0
	return {desvio = local.z, lado = lado.normalized(), meia_largura = MEIA_LARGURA}


## A malha do tronco com `metros` de comprimento: as pontas do modelo e a casca do meio repetida.
static func malha(metros: int) -> ArrayMesh:
	if metros == 2:
		return Voxel.carregar(ARQUIVO)
	if not _malhas.has(metros):
		var dados := Voxel.interpretar(FileAccess.get_file_as_string(ARQUIVO), ARQUIVO)
		var original: Dictionary = dados.voxels
		var largura := 0
		for p: Vector3i in original:
			largura = maxi(largura, p.x + 1)
		var novo_largura := roundi(metros / dados.tamanho)
		var voxels := {}
		for p: Vector3i in original:
			var cor: Color = original[p]
			if p.x == 0:
				voxels[p] = cor
			elif p.x == largura - 1:
				voxels[Vector3i(novo_largura - 1, p.y, p.z)] = cor
			else:
				# A casca do meio (colunas 1..largura-2) repetida até preencher.
				var x := p.x
				while x < novo_largura - 1:
					voxels[Vector3i(x, p.y, p.z)] = cor
					x += largura - 2
		_malhas[metros] = Voxel.malha(voxels, dados.tamanho, Voxel._origem_padrao(voxels))
	return _malhas[metros]

@tool
class_name TroncoCaido
extends ObjetoFase
## Tronco caído (2 m, deitado ao longo do X local). Normalmente é um obstáculo no chão. Com
## `pinguela`, está atravessado sobre um vão (riacho, buraco), com o topo quase rente ao chão
## das margens: dá para passar por cima — é uma passagem estreita, com o equilíbrio da Tábua.

@export var pinguela := false:
	set(valor):
		pinguela = valor
		_atualizar()

const ALTURA := 0.375
## Meia largura do topo, para o equilíbrio (o tronco é redondo: o topo é estreito).
const MEIA_LARGURA := 0.16


func nome_no_editor() -> String:
	return "Tronco caído"


func propriedades_editaveis() -> Array[StringName]:
	return [&"pinguela"]


func _ready() -> void:
	_atualizar()


func _atualizar() -> void:
	if not is_node_ready():
		return
	# Pinguela: afundado no vão, topo 3 cm acima das margens (mais alto seria um degrau).
	var descida := -(ALTURA - 0.03) if pinguela else 0.0
	($Modelo as Node3D).position.y = descida
	($Corpo as Node3D).position.y = descida
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
	if absf(local.x) > 1.0 or absf(local.z) > 0.6 or local.y < -0.4 or local.y > 0.9:
		return {}
	var lado := global_basis.z
	lado.y = 0.0
	return {desvio = local.z, lado = lado.normalized(), meia_largura = MEIA_LARGURA}

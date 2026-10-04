@tool
class_name EntradaDia
extends ObjetoFase
## Uma das saídas da área central do parque: o caminho para a região de um dia. A passagem fica
## no meio (largura `largura`, em X) e a região fica para o +Z. Fechada, uma pilha de troncos
## tapa a passagem; aberta (o dia já chegou), o cachorro entra e `cachorro_entrou` avisa
## (ver ObjetivoParque).
## Visual provisório (troncos e um poste com a cor do dia), até a arte do parque.

signal cachorro_entrou(entrada: EntradaDia)

@export_range(1, 10) var dia := 1:
	set(valor):
		dia = valor
		_montar()
## A fase do dia (o que se joga ao entrar). Vazio: o dia ainda não tem fase.
@export_file("*.tscn") var caminho_fase := ""
## O que o dono diz ao soltar o cachorro no começo deste dia ("" = a frase padrão).
@export var frase_do_dono := ""
@export_range(2.0, 6.0, 0.5) var largura := 3.0:
	set(valor):
		largura = valor
		_montar()

## Cores dos postes, uma por dia (provisório).
const CORES := [Color("d94f3d"), Color("e8913a"), Color("e8cc3a"), Color("8cc63f"), Color("3fa96b"),
	Color("3fb8c6"), Color("3f7ec6"), Color("6b4fc6"), Color("b44fc6"), Color("c64f86")]
const COR_TRONCO := Color("7a5230")

var aberta := false:
	set(valor):
		aberta = valor
		_atualizar_troncos()

var _troncos: Node3D
var _corpo_troncos: StaticBody3D
var _area: Area3D


func nome_no_editor() -> String:
	return "Entrada do dia"


func categoria_no_editor() -> String:
	return "Parque"


func propriedades_editaveis() -> Array[StringName]:
	return [&"dia", &"caminho_fase", &"frase_do_dono", &"largura"]


func _ready() -> void:
	_montar()


func _montar() -> void:
	if not is_node_ready():
		return
	for filho in get_children():
		if filho.name in [&"Troncos", &"Poste", &"Area"]:
			remove_child(filho)
			filho.queue_free()
	# Pilha de troncos atravessada na passagem.
	_troncos = Node3D.new()
	_troncos.name = "Troncos"
	var material := StandardMaterial3D.new()
	material.albedo_color = COR_TRONCO
	for i in 3:
		var tronco := MeshInstance3D.new()
		var cilindro := CylinderMesh.new()
		cilindro.top_radius = 0.19
		cilindro.bottom_radius = 0.19
		cilindro.height = largura + 0.4
		cilindro.radial_segments = 8
		cilindro.material = material
		tronco.mesh = cilindro
		tronco.rotation.z = PI * 0.5
		tronco.position = Vector3(0.0, 0.19 + i * 0.37, 0.0)
		_troncos.add_child(tronco)
	_corpo_troncos = StaticBody3D.new()
	_corpo_troncos.collision_layer = 4
	_corpo_troncos.collision_mask = 0
	var colisao := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(largura + 0.4, 1.2, 0.45)
	colisao.shape = caixa
	colisao.position.y = 0.6
	_corpo_troncos.add_child(colisao)
	_troncos.add_child(_corpo_troncos)
	add_child(_troncos)
	# Poste com a cor do dia, do lado da passagem.
	var poste := MeshInstance3D.new()
	poste.name = "Poste"
	var pau := BoxMesh.new()
	pau.size = Vector3(0.18, 1.4, 0.18)
	var madeira := StandardMaterial3D.new()
	madeira.albedo_color = COR_TRONCO
	pau.material = madeira
	poste.mesh = pau
	poste.position = Vector3(largura * 0.5 + 0.35, 0.7, 0.0)
	var topo := MeshInstance3D.new()
	var placa := BoxMesh.new()
	placa.size = Vector3(0.34, 0.34, 0.08)
	var cor := StandardMaterial3D.new()
	cor.albedo_color = CORES[clampi(dia, 1, 10) - 1]
	placa.material = cor
	topo.mesh = placa
	topo.position = Vector3(0.0, 0.6, -0.1)
	poste.add_child(topo)
	add_child(poste)
	# Entrou na passagem (já do outro lado dos troncos).
	_area = Area3D.new()
	_area.name = "Area"
	_area.collision_layer = 0
	_area.collision_mask = 8
	var forma := CollisionShape3D.new()
	var volume := BoxShape3D.new()
	volume.size = Vector3(largura, 1.5, 1.0)
	forma.shape = volume
	forma.position = Vector3(0.0, 0.75, 1.2)
	_area.add_child(forma)
	add_child(_area)
	if not Engine.is_editor_hint():
		_area.body_entered.connect(func(corpo: Node3D) -> void:
			if corpo is Dachshund and aberta:
				cachorro_entrou.emit(self))
	_atualizar_troncos()


func _atualizar_troncos() -> void:
	if _troncos == null:
		return
	_troncos.visible = not aberta
	_corpo_troncos.process_mode = Node.PROCESS_MODE_INHERIT if not aberta else Node.PROCESS_MODE_DISABLED

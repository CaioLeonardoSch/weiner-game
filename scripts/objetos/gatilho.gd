@tool
class_name Gatilho
extends ObjetoFase
## Gatilho: uma área invisível que liga o canal (a cor) uma vez, de vez, quando algo acontece
## dentro dela — o cachorro entra, entra com um graveto na boca, ou pega um graveto que está ali.
## Ligue com a ferramenta Ligar a quem reage: uma ponte fraca que quebra, um portão que fecha
## atrás do cachorro... No editor aparece translúcida (roxa).

const ENTRAR := 0
const ENTRAR_COM_GRAVETO := 1
const PEGAR_GRAVETO := 2

@export var tamanho := Vector3(2.0, 1.5, 2.0):
	set(valor):
		tamanho = valor
		_montar()
@export_enum("O cachorro entra", "O cachorro entra com um graveto", "Um graveto daqui é pego") var quando := ENTRAR
@export_enum("Amarelo", "Azul", "Vermelho", "Verde", "Roxo", "Laranja", "Ciano", "Rosa") var canal := 0

var disparado := false
var _fase: Fase
var _area: Area3D


func nome_no_editor() -> String:
	return "Gatilho"


func categoria_no_editor() -> String:
	return "Mecanismos"


func icone_desenhado() -> String:
	return "gatilho"


func propriedades_editaveis() -> Array[StringName]:
	return [&"tamanho", &"quando", &"canal"]


func papel_no_canal() -> String:
	return "aciona"


func prioridade_no_editor() -> int:
	return 0


func caixa_editor() -> AABB:
	return AABB(Vector3(-tamanho.x * 0.5, 0.0, -tamanho.z * 0.5), tamanho)


func _ready() -> void:
	_montar()
	if Engine.is_editor_hint():
		return
	_fase = fase_do_objeto()
	if _fase:
		_fase.definir_fonte(canal, self, false)
		if quando == PEGAR_GRAVETO:
			_ligar_gravetos.call_deferred()
	_area.body_entered.connect(_on_entrou)


func _ligar_gravetos() -> void:
	for objeto in _fase.todos(Graveto):
		if contem(objeto.global_position):
			(objeto as Graveto).pego.connect(func(_quem: Dachshund) -> void: disparar())


func _on_entrou(corpo: Node3D) -> void:
	var cachorro := corpo as Dachshund
	if cachorro == null:
		return
	if quando == ENTRAR or (quando == ENTRAR_COM_GRAVETO and cachorro.tem_graveto):
		disparar()


## O ponto (global) está dentro da área?
func contem(ponto: Vector3) -> bool:
	var local := to_local(ponto)
	return absf(local.x) <= tamanho.x * 0.5 and absf(local.z) <= tamanho.z * 0.5 and local.y > -0.5 and local.y < tamanho.y


func disparar() -> void:
	if disparado or _fase == null:
		return
	disparado = true
	_fase.definir_fonte(canal, self, true)


func _process(_delta: float) -> void:
	# Entrou com o graveto já estando dentro (pegou o graveto ali): confere enquanto estiver.
	if Engine.is_editor_hint() or disparado or quando != ENTRAR_COM_GRAVETO:
		return
	for corpo in _area.get_overlapping_bodies():
		if corpo is Dachshund and (corpo as Dachshund).tem_graveto:
			disparar()


func _montar() -> void:
	if not is_node_ready():
		return
	if _area == null:
		_area = Area3D.new()
		_area.name = "Area"
		_area.collision_layer = 0
		_area.collision_mask = 8
		add_child(_area)
		var colisao := CollisionShape3D.new()
		colisao.name = "Colisao"
		_area.add_child(colisao)
	var forma := BoxShape3D.new()
	forma.size = tamanho
	var colisao_area := _area.get_node(^"Colisao") as CollisionShape3D
	colisao_area.shape = forma
	colisao_area.position.y = tamanho.y * 0.5
	mostrar_volume_no_editor(tamanho, Color(0.7, 0.45, 1.0, 0.14))

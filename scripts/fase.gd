class_name Fase
extends Node3D
## Uma fase: terreno em grade + objetos. É só conteúdo — as regras ficam em jogo.gd.
##
## Estrutura (o editor de fases, F1, cria e salva assim):
##   Fase (este script)
##   ├─ Terreno  (GridMap com assets/tiles/tiles.tres; células de 1 m, chão na camada -1)
##   └─ Objetos  (Node3D) → instâncias de scenes/objetos/*.tscn
## Dá para editar também no editor do Godot (pintar o GridMap, arrastar objetos).
## Rodar esta cena direto (F6 no editor do Godot) abre o jogo nela.

## Habilidades que o cachorro pode usar (flags). Cada fase escolhe as suas: a Fase 01, por
## exemplo, depende de o cachorro não pular o barranco. Para uma habilidade nova, acrescente
## o nome em @export_flags (no fim) e uma constante com o próximo bit.
const HABILIDADE_PULAR := 1
const HABILIDADE_CAVAR := 2
const HABILIDADE_LATIR := 4

## O que o cachorro precisa fazer para terminar a fase. Para um objetivo novo: acrescente o
## nome em @export_enum (no fim), uma constante e uma classe em scripts/objetivos/.
const OBJETIVO_GRAVETO := 0
const OBJETIVO_PASTOREIO := 1

## Nome mostrado no jogo e no editor.
@export var nome := "Nova fase"
@export_flags("Pular", "Cavar", "Latir") var habilidades := 0
## Giro extra (graus) da câmera 3D ao pegar o graveto. 0 = olhando do cachorro para o dono.
@export_range(-90.0, 90.0) var desvio_camera_3d := 0.0
@export_enum("Trazer o graveto ao dono", "Levar as ovelhas ao cercado") var objetivo := OBJETIVO_GRAVETO
## Raça do cachorro nesta fase (id de assets/racas/*.tres). A raça soma habilidades próprias
## às da fase (ex.: o Border Collie sempre late).
@export var raca := &"salsicha"

## Um canal mudou (algum acionador ligou ou o último desligou). Ver Canais.
signal canal_mudou(canal: int, ativo: bool)

@onready var terreno: GridMap = $Terreno
@onready var objetos: Node3D = $Objetos


func _ready() -> void:
	# Busca o autoload pelo caminho: assim o script também compila em ferramentas de linha
	# de comando (--script), que rodam sem os autoloads.
	var fases := get_node_or_null(^"/root/Fases")
	if fases and get_tree().current_scene == self:
		fases.jogar.call_deferred(scene_file_path)


func _validate_property(propriedade: Dictionary) -> void:
	if propriedade.name == &"raca":
		propriedade.hint = PROPERTY_HINT_ENUM
		propriedade.hint_string = ",".join(Racas.ids())


func tem_habilidade(habilidade: int) -> bool:
	return habilidades_efetivas() & habilidade != 0


# --- Canais -------------------------------------------------------------------------------

## canal → {id da fonte: ativa}
var _fontes := {}


## Uma fonte (placa...) avisa se está acionada. O canal fica ativo se QUALQUER fonte estiver.
func definir_fonte(canal: int, fonte: Object, ativa: bool) -> void:
	var antes := canal_ativo(canal)
	if not _fontes.has(canal):
		_fontes[canal] = {}
	_fontes[canal][fonte.get_instance_id()] = ativa
	var depois := canal_ativo(canal)
	if antes != depois:
		canal_mudou.emit(canal, depois)


func canal_ativo(canal: int) -> bool:
	return _fontes.has(canal) and (_fontes[canal] as Dictionary).values().has(true)


## Habilidades da fase somadas às nativas da raça.
func habilidades_efetivas() -> int:
	var dados_raca := Racas.por_id(raca)
	return habilidades | (dados_raca.habilidades_nativas if dados_raca else 0)


func lista_objetos() -> Array[ObjetoFase]:
	var lista: Array[ObjetoFase] = []
	for filho in objetos.get_children():
		if filho is ObjetoFase:
			lista.append(filho)
	return lista


## Primeiro objeto do tipo pedido (ex.: `primeiro(Graveto)`), ou null.
func primeiro(tipo: Script) -> ObjetoFase:
	for objeto in lista_objetos():
		if is_instance_of(objeto, tipo):
			return objeto
	return null


func todos(tipo: Script) -> Array[ObjetoFase]:
	var lista: Array[ObjetoFase] = []
	for objeto in lista_objetos():
		if is_instance_of(objeto, tipo):
			lista.append(objeto)
	return lista


## Liga/desliga os objetos com a visibilidade dada (SO_ISO / SO_3D).
func ativar(visibilidade: ObjetoFase.Visibilidade, ativo: bool) -> void:
	for objeto in lista_objetos():
		if objeto.visibilidade == visibilidade:
			objeto.definir_ativo(ativo)


## Estado da visão isométrica: tampas e afins presentes, coisas "só 3D" escondidas.
func preparar_isometrica() -> void:
	ativar(ObjetoFase.Visibilidade.SO_ISO, true)
	ativar(ObjetoFase.Visibilidade.SO_3D, false)


## ID do tile na posição (global), ou GridMap.INVALID_CELL_ITEM.
func tile_em(posicao: Vector3) -> int:
	return terreno.get_cell_item(terreno.local_to_map(terreno.to_local(posicao)))


## Numa passagem estreita (tábua): quanto a posição está deslocada da linha do meio
## (m, com sinal) e para que lado. Devolve {} fora de passagens estreitas.
func passagem_estreita_em(posicao: Vector3) -> Dictionary:
	var celula := terreno.local_to_map(terreno.to_local(posicao))
	var id := terreno.get_cell_item(celula)
	if not Tiles.eh_estreita(id):
		return {}
	var lado := terreno.global_basis * terreno.get_cell_item_basis(celula).z
	lado.y = 0.0
	lado = lado.normalized()
	var centro := terreno.to_global(terreno.map_to_local(celula))
	return {desvio = (posicao - centro).dot(lado), lado = lado, meia_largura = Tiles.meia_largura(id)}


## A posição está dentro de um tile de água, abaixo da superfície?
func dentro_da_agua(posicao: Vector3) -> bool:
	var celula := terreno.local_to_map(terreno.to_local(posicao))
	if not Tiles.eh_agua(terreno.get_cell_item(celula)):
		return false
	var superficie := terreno.to_global(terreno.map_to_local(celula)).y + Tiles.SUPERFICIE_AGUA
	return posicao.y < superficie - 0.05


## Fase vazia com a estrutura esperada (Terreno + Objetos), pronta para ser preenchida.
static func nova(nome_fase: String) -> Fase:
	var fase := Fase.new()
	fase.name = "Fase"
	fase.nome = nome_fase
	var terreno := GridMap.new()
	terreno.name = "Terreno"
	terreno.mesh_library = load(Tiles.CAMINHO_BIBLIOTECA)
	terreno.cell_size = Vector3.ONE
	terreno.collision_mask = 0
	fase.add_child(terreno)
	terreno.owner = fase
	var objetos := Node3D.new()
	objetos.name = "Objetos"
	fase.add_child(objetos)
	objetos.owner = fase
	return fase


## Como instanciar cenas que depois serão salvas. Com o estado de edição (só existe em
## builds com editor — rodando pelo Godot), a fase salva guarda apenas o que mudou em cada
## objeto em relação à cena dele; sem ele (jogo exportado) salva tudo, o que também funciona.
static func estado_de_edicao(principal := false) -> PackedScene.GenEditState:
	if not OS.has_feature("editor"):
		return PackedScene.GEN_EDIT_STATE_DISABLED
	return PackedScene.GEN_EDIT_STATE_MAIN if principal else PackedScene.GEN_EDIT_STATE_INSTANCE


## Instancia um objeto (cena de scenes/objetos/) dentro de Objetos, já pronto para salvar.
func adicionar_objeto(cena: PackedScene, posicao: Vector3, yaw := 0.0) -> ObjetoFase:
	var objeto := cena.instantiate(estado_de_edicao()) as ObjetoFase
	get_node("Objetos").add_child(objeto, true)
	objeto.owner = self
	objeto.position = posicao
	objeto.rotation.y = yaw
	return objeto

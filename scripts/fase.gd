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

## Habilidades que o cachorro pode usar (flags). Cada fase escolhe as suas: a F02, por
## exemplo, depende de o cachorro não pular o barranco. Para uma habilidade nova, acrescente
## o nome em @export_flags (no fim) e uma constante com o próximo bit.
const HABILIDADE_PULAR := 1
const HABILIDADE_CAVAR := 2
const HABILIDADE_LATIR := 4

## O que o cachorro precisa fazer para terminar a fase. Para um objetivo novo: acrescente o
## nome em @export_enum (no fim), uma constante e uma classe em scripts/objetivos/.
const OBJETIVO_GRAVETO := 0
const OBJETIVO_PASTOREIO := 1
const OBJETIVO_PARQUE := 2
const OBJETIVO_DIA := 3

## Identidade da fase no save do jogador (fases concluídas). Não muda quando o arquivo é
## renomeado ou movido: é o que mantém o ✓ entre versões. O editor preenche ao salvar uma fase
## nova (o nome do arquivo); vazio = o nome do arquivo. Nunca reaproveite o id de outra fase.
@export var id := ""
## Nome mostrado no jogo e no editor.
@export var nome := "Nova fase"
@export_flags("Pular", "Cavar", "Latir") var habilidades := 0
## Habilidades aprendidas nas fases anteriores (ver Fases.habilidades_anteriores); -1 = ainda
## não calculadas (pelo id da fase).
var habilidades_herdadas := -1
## Giro extra (graus) da câmera 3D ao pegar o graveto. 0 = olhando do cachorro para o dono.
@export_range(-90.0, 90.0) var desvio_camera_3d := 0.0
@export_enum("Trazer o graveto ao dono", "Levar as ovelhas ao abrigo (cercado ou celeiro)",
	"Área central do parque (não termina)", "Dia do parque (achar o lendário e voltar)") var objetivo := OBJETIVO_GRAVETO
## Só terceira pessoa: a câmera começa atrás do cachorro e não vai para a isométrica ao largar o
## graveto (a direção nova do jogo, ver docs/DESIGN.md). Objetos "só isométrico" ficam de fora e
## os "só 3D" valem desde o começo.
@export var terceira_pessoa := false
## Raça do cachorro nesta fase (id de assets/racas/*.tres): só muda o tamanho. Jogando pelo
## menu, vale a raça que o jogador escolheu para a região (Regiao.racas); esta é a do teste no
## editor — e a de sempre, com `raca_fixa`.
@export var raca := &"salsicha"
## A fase é sempre jogada com a `raca` acima, qualquer que seja a escolhida para a região (ex.:
## o rebanho N09 é do Border Collie).
@export var raca_fixa := false
## Região a que a fase pertence (id de assets/regioes/*.tres): o menu agrupa as fases por
## região, na ordem das regiões e, dentro de cada uma, pelo nome do arquivo.
@export var regiao := &"floresta"
## Bioma (ver Biomas): texturas dos tiles, céu, luz e entorno (e o clima padrão, ver `clima`).
@export_enum("Floresta", "Neve") var bioma := Biomas.FLORESTA:
	set(valor):
		bioma = valor
		_aplicar_bioma()
## Clima (ver Clima): chuva, neve caindo, vento e tempestade. "Do bioma": neve no bioma de neve,
## tempo bom nos outros.
@export_enum("Do bioma", "Tempo bom", "Chuva", "Neve", "Ventania", "Tempestade") var clima := 0
## Frio: longe do fogo (fogueira acesa, celeiro) o cachorro perde calor; gelado demais, volta
## para perto do último fogo (ou do começo). Ver Dachshund.calor.
@export var frio := false
## Segundos, bem aquecido, até ficar gelado demais.
@export_range(10.0, 300.0, 5.0) var tempo_de_frio := 60.0

## Um canal mudou (alguma fonte ligou ou desligou). Quem reage confere com `canal_ligado`.
## Ver Canais.
signal canal_mudou(canal: int)

@onready var terreno: GridMap = $Terreno
@onready var objetos: Node3D = $Objetos

## Abaixo desta altura (m) o cachorro caiu no abismo e volta ao último ponto seguro: bem abaixo
## da camada mais funda do terreno (fases podem descer e subir à vontade).
var limite_de_queda := -10.0


func _ready() -> void:
	_aplicar_bioma()
	var celulas := terreno.get_used_cells()
	if not celulas.is_empty():
		var mais_baixa := celulas[0].y
		for celula in celulas:
			mais_baixa = mini(mais_baixa, celula.y)
		limite_de_queda = minf(-10.0, terreno.to_global(terreno.map_to_local(Vector3i(0, mais_baixa, 0))).y - 8.0)
	# Busca o autoload pelo caminho: assim o script também compila em ferramentas de linha
	# de comando (--script), que rodam sem os autoloads.
	var fases := get_node_or_null(^"/root/Fases")
	if fases and get_tree().current_scene == self:
		fases.jogar.call_deferred(scene_file_path)


func _validate_property(propriedade: Dictionary) -> void:
	if propriedade.name == &"raca":
		propriedade.hint = PROPERTY_HINT_ENUM
		propriedade.hint_string = ",".join(Racas.ids())
	elif propriedade.name == &"regiao":
		propriedade.hint = PROPERTY_HINT_ENUM
		propriedade.hint_string = ",".join(Regioes.ids())


## Troca a biblioteca de tiles pela do bioma e avisa os objetos (árvores com neve...).
func _aplicar_bioma() -> void:
	if not is_node_ready():
		return
	terreno.mesh_library = load(Tiles.biblioteca_do_bioma(bioma))
	for objeto in lista_objetos():
		objeto.ao_mudar_bioma()


func tem_habilidade(habilidade: int) -> bool:
	return habilidades_efetivas() & habilidade != 0


# --- Canais -------------------------------------------------------------------------------

## canal → {id da fonte: ativa}
var _fontes := {}


## Uma fonte (placa...) avisa se está acionada. As fontes se registram (desligadas) ao entrar
## na fase, para a regra "todas" saber quantas são.
func definir_fonte(canal: int, fonte: Object, ativa: bool) -> void:
	if not _fontes.has(canal):
		_fontes[canal] = {}
	var id := fonte.get_instance_id()
	if (_fontes[canal] as Dictionary).get(id) == ativa:
		return
	_fontes[canal][id] = ativa
	canal_mudou.emit(canal)


## Regra OU: alguma fonte do canal está acionada.
func canal_ativo(canal: int) -> bool:
	return _fontes.has(canal) and (_fontes[canal] as Dictionary).values().has(true)


## Regra E: todas as fontes do canal estão acionadas (e há pelo menos uma).
func canal_completo(canal: int) -> bool:
	return _fontes.has(canal) and not (_fontes[canal] as Dictionary).is_empty() \
		and not (_fontes[canal] as Dictionary).values().has(false)


## Quantas fontes do canal estão acionadas (x) de quantas existem (y).
func fontes_do_canal(canal: int) -> Vector2i:
	if not _fontes.has(canal):
		return Vector2i.ZERO
	var estados: Array = (_fontes[canal] as Dictionary).values()
	return Vector2i(estados.count(true), estados.size())


## O canal liga quem reage? `todas`: regra E; senão, regra OU.
func canal_ligado(canal: int, todas: bool) -> bool:
	return canal_completo(canal) if todas else canal_ativo(canal)


## Um latido em `origem`: os objetos até Dachshund.ALCANCE_LATIDO ouvem (pássaros voam, o dono
## acorda, um cão vizinho late de volta...). Objetos desativados pela perspectiva (ex.: "só 3D"
## na isométrica) não ouvem; `quem` latiu não ouve a si mesmo.
func espalhar_latido(origem: Vector3, quem: Node) -> void:
	for objeto in lista_objetos():
		if objeto != quem and objeto.visible \
				and objeto.global_position.distance_to(origem) <= Dachshund.ALCANCE_LATIDO:
			objeto.ao_ouvir_latido(origem)


## Habilidades que o cachorro tem nesta fase (iguais para todas as raças): as da fase e as que
## ele aprendeu nas fases anteriores.
func habilidades_efetivas() -> int:
	if habilidades_herdadas < 0:
		habilidades_herdadas = 0
		var arvore := Engine.get_main_loop() as SceneTree
		var fases: Node = arvore.root.get_node_or_null(^"Fases") if arvore else null
		if fases and not Engine.is_editor_hint() and not id.is_empty():
			habilidades_herdadas = fases.habilidades_anteriores(id)
	return habilidades | habilidades_herdadas


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


## Só o visual da volta (mirante): esconde o que é "só isométrico" e mostra o "só 3D", sem
## mexer na física (o cachorro fica parado olhando). `false` volta ao visual da ida.
func previa_da_volta(ligada: bool) -> void:
	for objeto in lista_objetos():
		if objeto.visibilidade == ObjetoFase.Visibilidade.SO_ISO:
			objeto.visible = not ligada
		elif objeto.visibilidade == ObjetoFase.Visibilidade.SO_3D:
			objeto.visible = ligada


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
		return passagem_estreita_de_objeto(posicao)
	var lado := terreno.global_basis * terreno.get_cell_item_basis(celula).z
	lado.y = 0.0
	lado = lado.normalized()
	var centro := terreno.to_global(terreno.map_to_local(celula))
	return {desvio = (posicao - centro).dot(lado), lado = lado, meia_largura = Tiles.meia_largura(id)}


## Passagem estreita feita por um objeto (graveto que virou ponte, tronco caído como pinguela),
## no mesmo formato de `passagem_estreita_em`. Objetos assim ficam no grupo
## "passagens_estreitas" e têm `passagem_em(posicao)`.
func passagem_estreita_de_objeto(posicao: Vector3) -> Dictionary:
	for no in get_tree().get_nodes_in_group(&"passagens_estreitas"):
		var dados: Dictionary = no.passagem_em(posicao)
		if not dados.is_empty():
			return dados
	return {}


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

@tool
class_name ObjetoFase
extends Node3D
## Base de tudo que pode ser colocado numa fase pelo editor (árvores, dono, graveto...).
##
## Para criar um objeto novo: faça uma cena em scenes/objetos/ cuja raiz use um script
## que estende ObjetoFase. Ele aparece sozinho na paleta do editor (F1).
## Sobrescreva `nome_no_editor()`, `categoria_no_editor()`, `ao_colocar_no_editor()` (para
## sortear variações) e, para expor parâmetros no painel do editor, `propriedades_editaveis()`
## (nomes de variáveis @export).
##
## A `visibilidade` liga o objeto à mecânica central do jogo, a mudança de perspectiva:
## um objeto "só isométrico" some (e perde a colisão) quando o cachorro pega o graveto;
## um "só 3D" só existe depois disso.

enum Visibilidade { SEMPRE, SO_ISO, SO_3D }

@export var visibilidade := Visibilidade.SEMPRE


func nome_no_editor() -> String:
	return name


func categoria_no_editor() -> String:
	return "Cenário"


## Variáveis (além de visibilidade, giro e escala) que o painel do editor mostra.
func propriedades_editaveis() -> Array[StringName]:
	return []


## Chamado pelo editor ao preparar um objeto para colocar: sorteie variações aqui
## (variante, giro, escala) para cada árvore ou pedra sair diferente.
func ao_colocar_no_editor(_rng: RandomNumberGenerator) -> void:
	pass


## O cachorro latiu perto (até Dachshund.ALCANCE_LATIDO metros). Pássaros voam, etc.
func ao_ouvir_latido(_origem: Vector3) -> void:
	pass


## Botão de ação (F): o que o cachorro faz com este objeto quando ele está à frente do focinho
## (ex.: "morder o mirante", "pegar o graveto"), ou "" se nada. `executar_acao` faz a ação.
## Objetos com ação entram no grupo "com_acao" (é onde o cachorro procura).
func acao_da_boca(_cachorro: Dachshund) -> String:
	return ""


func executar_acao(_cachorro: Dachshund) -> void:
	pass


## Onde o cachorro precisa estar perto para a ação (padrão: a origem do objeto).
func ponto_da_acao(_cachorro: Dachshund) -> Vector3:
	return global_position


## Quanto este objeto pesa sobre uma placa de pressão (0 = não conta). Objetos com peso entram
## no grupo "pesos" (ver Placa).
func peso_na_placa() -> float:
	return 0.0


## Pesado o bastante para a placa de PEDRA (o bloco de pedra, o tronco). A de madeira aceita
## qualquer coisa com `peso_na_placa()` acima de zero.
func pesado_para_placa() -> bool:
	return false


## Pontos (globais) em que o objeto se apoia: a placa fica acionada se qualquer um deles estiver
## em cima dela. Padrão: só a origem; objetos compridos (o tronco, o graveto) sobrescrevem.
func pontos_de_apoio() -> PackedVector3Array:
	return PackedVector3Array([global_position])


## Mecanismos ligados por canal (a cor, ver Canais): "aciona" (placa...), "reage" (portão...)
## ou "" (não é mecanismo). Mecanismos têm a propriedade `canal`, que a ferramenta Ligar do
## editor troca.
func papel_no_canal() -> String:
	return ""


## Ícone desenhado da paleta (ver IconesDesenhados), para objetos sem modelo para fotografar
## (zonas, parede invisível, início); "" usa uma foto do próprio objeto.
func icone_desenhado() -> String:
	return ""


## Está numa fase aberta no editor de fases do jogo (o editor marca a raiz da árvore)?
func no_editor_de_fases() -> bool:
	return is_inside_tree() and get_tree().root.has_meta(&"editor_de_fases")


## Objetos invisíveis no jogo (paredes, zonas) ganham no editor um volume translúcido do
## `tamanho` deles, para dar para ver onde estão sem atrapalhar. No jogo, nada aparece.
func mostrar_volume_no_editor(tamanho: Vector3, cor: Color) -> void:
	var volume := get_node_or_null(^"VolumeEditor") as MeshInstance3D
	if not no_editor_de_fases():
		if volume:
			volume.queue_free()
		return
	if volume == null:
		volume = MeshInstance3D.new()
		volume.name = "VolumeEditor"
		volume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.albedo_color = cor
		volume.material_override = material
		add_child(volume)
	var caixa := BoxMesh.new()
	caixa.size = tamanho
	volume.mesh = caixa
	volume.position = Vector3(0, tamanho.y * 0.5, 0)


## Só pode haver um na fase (o Início do cachorro): fica de fora dos trechos copiados.
func unico_na_fase() -> bool:
	return false


## Mecanismo que funciona bem sem ligação nenhuma (a fogueira: esquenta mesmo sem portão): a
## validação do editor não reclama se nada da mesma cor reage a ele.
func canal_opcional() -> bool:
	return false


## Bioma da fase (ver Biomas): árvores e pedras ganham neve, por exemplo.
func bioma_da_fase() -> int:
	var fase := fase_do_objeto()
	var valor: Variant = fase.get(&"bioma") if fase else null
	return valor if valor is int else Biomas.FLORESTA


## O bioma da fase mudou (no editor): refaça o visual que depende dele.
func ao_mudar_bioma() -> void:
	pass


## A fase a que este objeto pertence (ou null no editor de cenas do Godot).
func fase_do_objeto() -> Fase:
	var no := get_parent()
	while no and not no is Fase:
		no = no.get_parent()
	return no as Fase


## Objetos que são só volume (zonas, paredes invisíveis) usam 0: o editor só os seleciona
## quando o clique não acerta nenhum objeto "de verdade" (senão atrapalhariam os de dentro).
func prioridade_no_editor() -> int:
	return 1


## Caixa (no espaço local) usada pelo editor para selecionar e desenhar o objeto.
## Por padrão, junta as caixas das malhas visíveis; objetos invisíveis sobrescrevem.
func caixa_editor() -> AABB:
	var caixa := AABB()
	var primeira := true
	for filho in find_children("*", "VisualInstance3D", true, false):
		var visual := filho as VisualInstance3D
		var local := global_transform.affine_inverse() * visual.global_transform * visual.get_aabb()
		caixa = local if primeira else caixa.merge(local)
		primeira = false
	if primeira:
		return AABB(Vector3(-0.3, 0.0, -0.3), Vector3(0.6, 0.6, 0.6))
	return caixa


## Ativa/desativa o objeto. Desativado ele some e também sai da física
## (process_mode desativado remove corpos e áreas da simulação).
func definir_ativo(ativo: bool) -> void:
	visible = ativo
	process_mode = Node.PROCESS_MODE_INHERIT if ativo else Node.PROCESS_MODE_DISABLED

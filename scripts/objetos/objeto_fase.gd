@tool
class_name ObjetoFase
extends Node3D
## Base de tudo que pode ser colocado numa fase pelo editor (árvores, dono, graveto...).
##
## Para criar um objeto novo: faça uma cena em scenes/objetos/ cuja raiz use um script
## que estende ObjetoFase. Ele aparece sozinho na paleta do editor (F1).
## Sobrescreva `nome_no_editor()`, `categoria_no_editor()` e, para expor parâmetros no
## painel do editor, `propriedades_editaveis()` (nomes de variáveis @export).
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

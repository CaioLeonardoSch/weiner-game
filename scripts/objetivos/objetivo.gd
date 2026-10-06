class_name Objetivo
extends RefCounted
## O que a fase pede para terminar (`Fase.objetivo`). Cada objetivo diz do que a fase precisa
## (`faltando`, usado pelo jogo e pela validação do editor), prepara as regras no jogo
## (`preparar`) e confere o andamento (`processar`, a cada quadro).
## Para um objetivo novo: uma classe que estende esta, o nome em `Fase.objetivo` e `criar()`.

## O jogo (scripts/jogo.gd): cachorro, fase, avisos, concluir.
var jogo: Node


static func criar(tipo: int) -> Objetivo:
	match tipo:
		Fase.OBJETIVO_PASTOREIO:
			return ObjetivoPastoreio.new()
		Fase.OBJETIVO_PARQUE:
			return ObjetivoParque.new()
		Fase.OBJETIVO_DIA:
			return ObjetivoDia.new()
		_:
			return ObjetivoGraveto.new()


## O que falta na fase para ela poder ser jogada (ex.: "o Dono").
func faltando(_fase: Fase) -> PackedStringArray:
	return []


## Problemas que não impedem de jogar, mas que o editor deve apontar.
func avisos(_fase: Fase) -> PackedStringArray:
	return []


## O título mostrado ao abrir a fase (padrão: nenhum; ver docs/DESIGN.md, "Textos e dicas").
func titulo(_fase: Fase) -> String:
	return ""


func preparar(novo_jogo: Node) -> void:
	jogo = novo_jogo


func processar(_delta: float) -> void:
	pass


## O cachorro acabou de pegar um graveto (depois da troca de perspectiva).
func ao_pegar_graveto(_graveto: Graveto) -> void:
	pass


static func _falta(fase: Fase, tipo: Script, nome: String, lista: PackedStringArray) -> void:
	if fase.primeiro(tipo) == null:
		lista.append(nome)

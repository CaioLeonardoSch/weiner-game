@tool
class_name Regiao
extends Resource
## Uma região do jogo: agrupa fases com um tema e uma pequena história (ver ROADMAP, "Regiões e
## história"). As regiões ficam em assets/regioes/*.tres; cada fase diz a sua (`Fase.regiao`,
## no painel da fase do editor) e o menu mostra as fases agrupadas, na `ordem` das regiões.
## Antes de jogar, o jogador escolhe a raça entre as `racas` da região.

@export var id := &"floresta"
@export var nome := "Floresta"
@export_multiline var descricao := ""
## Posição da região no menu (e na sequência "próxima fase").
@export var ordem := 0
## Bioma sugerido para as fases novas da região (ver Biomas).
@export_enum("Floresta", "Neve") var bioma := 0
## Raças que podem jogar a região (ids de assets/racas/*.tres), a primeira é a sugerida. Toda
## fase da região precisa ter solução com cada uma delas (ou marcar `Fase.raca_fixa`).
## Vazia = só a raça padrão (salsicha).
@export var racas: Array[StringName] = []


## As raças compatíveis que existem (na ordem de `racas`); nunca vazia.
func racas_compativeis() -> Array[Raca]:
	var lista: Array[Raca] = []
	for id in racas:
		var raca := Racas.por_id(id)
		if raca and raca.id == id and raca not in lista:
			lista.append(raca)
	if lista.is_empty():
		lista.append(Racas.por_id(Racas.PADRAO))
	return lista
